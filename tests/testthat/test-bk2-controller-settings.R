test_that("explicit NES controller configuration overrides stale LogKey entries", {
  movie <- read_bk2(test_path("fixtures", "nes-unplugged.bk2"))
  expect_identical(n_players(movie), 1L)
  expect_identical(movie$header$inactiveControllerPorts, 2L)
  expect_length(movie$header$inactiveLogKeyControls, 8L)
  expect_true(all(startsWith(movie$header$inactiveLogKeyControls, "P2 ")))
  expect_identical(unname(player(movie)[, button_layout(movie)$key == "dpad_up"]), c(TRUE, FALSE))
  expect_identical(unname(player(movie)[, button_layout(movie)$key == "a"]), c(FALSE, TRUE))
  expect_identical(system_channels(movie)$Power, c(FALSE, TRUE))
})
test_that("NES port settings use JSON values independent of formatting and key order", {
  cases <- c(
    '{"o":{"Controls":{"Famicom":false,"NesLeftPort":"ControllerNES","NesRightPort":"UnpluggedNES"}}}',
    '{\n "o": { "Controls": { "NesRightPort": "UnpluggedNES",\n "NesLeftPort": "ControllerNES", "Famicom": false } } }'
  )
  for (text in cases) {
    settings <- jsonlite::fromJSON(text, simplifyVector = FALSE)
    expect_identical(replayr:::.bk2_inactive_nes_ports(settings), 2L)
  }
})
test_that("missing or contradictory configuration never invents an absent controller", {
  key <- paste0(
    "LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|",
    "#P2 Up|P2 Down|P2 Left|P2 Right|P2 Start|P2 Select|P2 B|P2 A|"
  )
  text <- paste(c("[Input]", key, "|..|........|", "[/Input]"), collapse = "\n")
  cases <- c(
    '{}',
    '{"o":{"Controls":{"NesRightPort":"UnpluggedNES"}}}',
    '{"o":{"Controls":{"Famicom":true,"NesLeftPort":"ControllerNES","NesRightPort":"UnpluggedNES"}}}',
    '{"o":{"Controls":{"Famicom":false,"NesLeftPort":"ControllerNES","NesRightPort":"ControllerNES"}}}',
    '{"o":{"Controls":{"Famicom":"false","NesLeftPort":"ControllerNES","NesRightPort":"UnpluggedNES"}}}'
  )
  for (json in cases) {
    inactive <- replayr:::.bk2_inactive_nes_ports(jsonlite::fromJSON(json, simplifyVector = FALSE))
    expect_identical(inactive, integer())
    expect_error(replayr:::.parse_bk2_input_log(
      text,
      list("_format" = "bk2", Platform = "NES", inactiveControllerPorts = inactive)
    ), "truncated")
  }
})
test_that("empty settings preserve the controllers declared by the LogKey", {
  original_reader <- replayr:::.read_zip_member_text
  settings <- ""
  key <- paste0(
    "LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|",
    "#P2 Up|P2 Down|P2 Left|P2 Right|P2 Start|P2 Select|P2 B|P2 A|"
  )
  input <- paste(c("[Input]", key, "|..|U.......|.......A|", "[/Input]"), collapse = "\n")
  local_mocked_bindings(.read_zip_member_text = function(path, member, ...) {
    if (basename(member) == "SyncSettings.json") return(settings)
    if (basename(member) == "Input Log.txt") return(input)
    original_reader(path, member, ...)
  }, .package = "replayr")
  fixture <- test_path("fixtures", "nes-unplugged.bk2")
  for (empty in c("", "\r\n", " \t\r\n ")) {
    settings <- empty
    movie <- read_bk2(fixture)
    expect_identical(n_players(movie), 2L)
    expect_null(movie$header$inactiveControllerPorts)
    expect_null(movie$header$inactiveLogKeyControls)
    expect_true(player(movie, 1L)[1L, button_layout(movie)$key == "dpad_up"])
    expect_true(player(movie, 2L)[1L, button_layout(movie)$key == "a"])
  }
  settings <- '{"o":'
  expect_error(read_bk2(fixture), "parse error")
  settings <- "\r\n"
  input <- paste(c("[Input]", key, "|..|U.......|", "[/Input]"), collapse = "\n")
  expect_error(read_bk2(fixture), "truncated")
})
