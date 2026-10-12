test_that("replayr:::.decode_pxm() parses a published PSX binary movie", {
  fp <- external_fixture("raw_psx/mega_man_x4/1439.pxm")
  mv <- replayr:::.decode_pxm(analog = "quantized", fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "pxm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 42L)
})

