# The controls of a console or cabinet are named by key, as buttons and
# numeric channels are.
test_that("system controls have one key in every format that records them", {
  keys <- function(...) {
    path <- system.file("extdata", ..., package = "replayr")
    names(system_channels(suppressWarnings(read_movie(path))))
  }
  # Pause of the Master System, from three emulators.
  expect_true("pause" %in% keys("legacy", "sms.mmv"))
  expect_true("pause" %in% keys("legacy", "sms.mcm"))
  expect_true("pause" %in% keys("expanded", "legacy-sms.tas"))
  expect_true(all(c("reset", "power") %in% keys("sample.bk2")))
})
test_that("system keys follow the names of the source", {
  expect_identical(
    replayr:::.system_keys(c("Reset", "Power", "Coin 1", "Disc Select", "Toggle Left Difficulty", "St-V Test")),
    c("reset", "power", "coin_1", "disc_select", "toggle_left_difficulty", "st_v_test")
  )
  # One control written in several ways.
  expect_identical(replayr:::.system_keys(c("input_coin_1", "VS Coin 2")), c("coin_1", "coin_2"))
  expect_identical(replayr:::.system_keys("input_service1"), replayr:::.system_keys("Service 1"))
  expect_identical(replayr:::.system_keys(c("LidOpen", "LidClose")), c("lid_open", "lid_close"))
  expect_identical(replayr:::.system_keys(c("1 Player Start", "2 Players Start")), c("p1_start", "p2_start"))
  # The power switch of one console, and those of a linked pair.
  expect_identical(replayr:::.system_keys("P1 Power"), "power")
  expect_identical(replayr:::.system_keys(c("P1 Power", "P2 Power")), c("p1_power", "p2_power"))
  # Names that are already keys stay as they are.
  expect_identical(replayr:::.system_keys(c("lid_closed", "pad1_ext0", "port_dsw1_default")),
    c("lid_closed", "pad1_ext0", "port_dsw1_default"))
  expect_identical(replayr:::.system_keys(character()), character())
})
test_that("system_layout() keeps the labels of the recording", {
  log <- paste(c("LogKey:#Reset|Power|Coin 1|#P1 Up|P1 Down|", "|.P.|U.|", "|R.C|.D|"), collapse = "\n")
  movie <- replayr:::.configure_movie(replayr:::.parse_bk2_input_log(log, list("_format" = "bk2", Platform = "NES")))
  layout <- system_layout(movie)
  expect_identical(names(layout), c("column", "key", "name"))
  expect_identical(layout$key, c("reset", "power", "coin_1"))
  expect_identical(layout$name, c("Reset", "Power", "Coin 1"))
  expect_identical(layout$key, names(system_channels(movie)))
  expect_identical(system_channels(movie)$coin_1, c(FALSE, TRUE))
  # Selecting observations keeps the keys.
  expect_identical(names(system_channels(movie[2L])), layout$key)
  # A recording without such controls has an empty layout.
  plain <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
  expect_identical(nrow(system_layout(plain)), 0L)
})
