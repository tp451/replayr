test_that("read_dtm() parses a GameCube movie when fixture is available", {
  fp <- external_fixture("raw_gc/luigis_mansion/2587.dtm")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable DTM test")
  mv <- read_dtm(fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "dtm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 28L)
})
