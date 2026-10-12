test_that("replayr:::.decode_dtm() parses an optional external GameCube movie", {
  fp <- external_fixture("raw_gc/luigis_mansion/2587.dtm")
  mv <- replayr:::.decode_dtm(analog = "quantized", fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "dtm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 28L)
})

