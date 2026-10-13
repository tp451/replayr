test_that("replayr:::.decode_bk2() tolerates a NUL-padded Header.txt field", {
  # Gambatte can NUL-pad fixed-width metadata such as BoardName. The
  # complete header and input log should remain readable.
  fp <- external_fixture("raw_gb/kwirk/3755.bk2")
  mv <- replayr:::.decode_bk2(analog = "quantized", fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "bk2")
  expect_gt(n_observations(mv), 0L)
  expect_gt(sum(press_counts(mv, 1L)), 0L)
})

test_that("real Arkanoid paddle movie matches its literal position and Fire fields", {
  fp <- external_fixture('raw_nes/arkanoid/6350.bk2')
  con <- unz(fp, 'Input Log.txt')
  on.exit(close(con))
  lines <- readLines(con, warn = FALSE)
  lines <- lines[startsWith(lines, '|')]
  position <- as.integer(sub('^\\|[^|]*\\|\\s*([0-9]+),.*$', '\\1', lines))
  fire <- grepl(',F\\|$', lines)
  motion <- diff(c(80L, position))
  mv <- replayr:::.decode_bk2(analog = "quantized", fp)
  expect_equal(n_observations(mv), 37298L)
  expect_identical(unname(mv$inputs[, 1, 8]), fire)
  expect_identical(unname(mv$inputs[, 1, 21]), motion > 0)
  expect_identical(unname(mv$inputs[, 1, 25]), motion < 0)
  expect_gt(sum(mv$inputs), 0)
})

test_that('published Crash Bandicoot 2 value 256 becomes north through Octoshock', {
  fp <- external_fixture('raw_psx/crash_bandicoot_2/3594.bk2')
  messages <- character()
  mv <- withCallingHandlers(replayr:::.decode_bk2(analog = "quantized", fp), warning = function(w) {
    messages <<- c(messages, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_true(any(grepl("byte conversion applied to 8", messages)))
  expect_true(any(grepl("noncanonical boundaries", messages)))
  samples <- c(62593:62598, 62623:62624)
  expect_true(all(mv$inputs[samples, 1, 23]))
  expect_false(any(mv$inputs[samples, 1, 27]))
  expect_equal(mv$header$octoshockByteWrappedAxisValues, 8L)
})

