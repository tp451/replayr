# PXM, PJM, DTM fixtures aren't bundled because they're large
# (~0.3-0.7 MB each). These tests run only when REPLAYR_FIXTURE_DIR
# points at a copy of the corpus's `data/` folder.

test_that("read_pxm() parses a PSX binary movie when fixture is available", {
  fp <- external_fixture("raw_psx/mega_man_x4/1439.pxm")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable PXM test")
  mv <- read_pxm(fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "pxm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 30L)
})

test_that("read_pjm() parses a PSX text movie when fixture is available", {
  fp <- external_fixture("raw_psx/mega_man_x4/2032.pjm")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable PJM test")
  mv <- read_pjm(fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "pjm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 30L)
})
