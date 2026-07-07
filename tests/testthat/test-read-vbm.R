test_that("read_vbm() parses a Game Boy movie", {
  skip_if_no_fixture("sample.vbm")
  mv <- read_vbm(fixture_path("sample.vbm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "vbm")
  expect_gt(n_frames(mv), 0L)
  # Zelda: Link's Awakening is GB; output should be 8 buttons wide.
  expect_equal(n_buttons(mv), 8L)
  expect_equal(mv$header$isGBA, "0")
})
