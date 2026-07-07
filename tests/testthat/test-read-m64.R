test_that("read_m64() parses an N64 movie", {
  skip_if_no_fixture("sample.m64")
  mv <- read_m64(fixture_path("sample.m64"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "m64")
  expect_gt(n_frames(mv), 0L)
  # N64 output is 28 buttons wide (buttons + C-buttons + 8-direction
  # quantised stick).
  expect_equal(n_buttons(mv), 28L)
  pc <- press_counts(mv, 1L)
  # Super Mario 64 leans on the analog stick — at least one of the
  # stick-direction slots (21..28) should have non-zero presses.
  expect_true(sum(pc[21:28]) > 0L)
})
