test_that("read_smv() parses an SNES movie", {
  skip_if_no_fixture("sample.smv")
  mv <- read_smv(fixture_path("sample.smv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "smv")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 12L)
})
