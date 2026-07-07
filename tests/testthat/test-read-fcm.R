test_that("read_fcm() parses an FCEU NES movie", {
  skip_if_no_fixture("sample.fcm")
  mv <- read_fcm(fixture_path("sample.fcm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "fcm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 8L)
  expect_equal(n_players(mv), 4L)  # FCM reserves 4 ports
})
