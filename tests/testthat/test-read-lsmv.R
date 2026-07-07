test_that("read_lsmv() parses an SNES movie", {
  skip_if_no_fixture("sample.lsmv")
  mv <- read_lsmv(fixture_path("sample.lsmv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "lsmv")
  expect_gt(n_frames(mv), 0L)
  # SNES gamepad is 12 buttons wide.
  expect_equal(n_buttons(mv), 12L)
})
