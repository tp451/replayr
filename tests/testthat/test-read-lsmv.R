test_that("read_lsmv() parses the bundled synthetic SNES movie", {
  mv <- read_lsmv(fixture_path("sample.lsmv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "lsmv")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 2L)
  # SNES gamepad is 12 buttons wide.
  expect_equal(n_buttons(mv), 12L)
})

test_that("lsmv parser rejects unsupported and mixed controller widths", {
  expect_error(
    replayr:::.parse_lsmv_input("F.|............|.....\n"),
    "unsupported lsmv controller widths"
  )
  expect_error(
    replayr:::.parse_lsmv_input("F.|........|............\n"),
    "mixed lsmv controller widths"
  )
})
