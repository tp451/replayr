test_that("read_smv() parses the bundled synthetic SNES movie", {
  mv <- read_smv(fixture_path("sample.smv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "smv")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_buttons(mv), 12L)
})

.mk_smv <- function(words, frame_count = length(words) - 1L,
                    controller_type = 1L) {
  hdr <- raw(0x40L)
  hdr[1:4] <- charToRaw("SMV\x1a")
  hdr[5:8] <- writeBin(4L, raw(), size = 4L, endian = "little")
  hdr[17:20] <- writeBin(frame_count, raw(), size = 4L, endian = "little")
  hdr[21] <- as.raw(1L)
  hdr[29:32] <- writeBin(0x40L, raw(), size = 4L, endian = "little")
  hdr[33:36] <- writeBin(length(words), raw(), size = 4L, endian = "little")
  hdr[37] <- as.raw(controller_type)
  body <- unlist(lapply(words, function(w) c(bitwAnd(w, 0xffL), bitwShiftR(w, 8L))))
  tf <- tempfile(fileext = ".smv")
  writeBin(c(hdr, as.raw(body)), tf)
  tf
}

test_that("read_smv() includes the initial sample and recognises reset", {
  tf <- .mk_smv(c(0xffffL, 0x8000L))
  on.exit(unlink(tf))
  mv <- read_smv(tf)
  expect_equal(n_frames(mv), 2L)
  expect_equal(mv$commands, c(1L, 0L))
  expect_equal(sum(mv$inputs[1L, , ]), 0L)
  expect_true(mv$inputs[2L, 1L, 7L])
})

test_that("read_smv() rejects variable-width peripherals", {
  tf <- .mk_smv(c(0L), controller_type = 2L)
  on.exit(unlink(tf))
  expect_error(read_smv(tf), "unsupported SMV peripheral")
})
