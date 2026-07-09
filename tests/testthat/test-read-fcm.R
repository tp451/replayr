test_that("read_fcm() parses an FCEU NES movie", {
  skip_if_no_fixture("sample.fcm")
  mv <- read_fcm(fixture_path("sample.fcm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "fcm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 8L)
  expect_equal(n_players(mv), 4L)  # FCM reserves 4 ports
})

test_that("read_fcm() accepts version 1 and decodes it like version 2", {
  skip_if_no_fixture("sample.fcm")
  fp <- fixture_path("sample.fcm")
  raw <- readBin(fp, "raw", n = file.info(fp)$size)
  ref <- read_fcm(fp)
  # force the version u32 (offset 0x04) to 1 in a temp copy; v1 and v2 share
  # the header layout and body, so the decoded input must be identical.
  raw[5:8] <- as.raw(c(1L, 0L, 0L, 0L))
  tf <- tempfile(fileext = ".fcm")
  writeBin(raw, tf)
  v1 <- read_fcm(tf)
  expect_equal(v1$header[["version"]], "1")
  expect_identical(v1$inputs, ref$inputs)
  expect_identical(v1$commands, ref$commands)
})

test_that("read_fcm() parses a real version-1 movie when fixture is available", {
  fp <- external_fixture("raw_nes/power_blade/193.fcm")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable the FCM v1 test")
  mv <- read_fcm(fp)
  expect_equal(mv$header[["version"]], "1")
  expect_equal(n_frames(mv), 61842L)
  pc <- press_counts(mv, 1L)
  expect_true(all(pc <= n_frames(mv)))  # sane: nothing above 100% held
  expect_gt(sum(pc), 0L)
})
