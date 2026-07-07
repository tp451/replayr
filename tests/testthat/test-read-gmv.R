test_that("read_gmv() parses a Genesis movie", {
  skip_if_no_fixture("sample.gmv")
  mv <- read_gmv(fixture_path("sample.gmv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "gmv")
  expect_gt(n_frames(mv), 0L)
  # Genesis controllers are 15 buttons wide in our universal layout
  # (slots 1..4 d-pad, 5 Start, 7/8 B/A, 9/10 X/Y, 13 C, 14 Z, 15 Mode).
  expect_equal(n_buttons(mv), 15L)
  expect_equal(n_players(mv), 2L)
})
