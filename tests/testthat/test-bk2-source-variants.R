bk2_variant_fixture <- function(name) system.file('extdata', 'bk2-variants', name, package = 'replayr', mustWork = TRUE)
test_that('Gambatte input length is numeric timing and leaves button positions intact', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('subframe-gb.bk2')))
  expect_equal(system_channels(m)[['input_length']], c(35112, 1, 5758, 0))
  expect_identical(system_channels(m)$power, c(FALSE, FALSE, FALSE, TRUE))
  keys <- button_layout(m)$key
  expect_setequal(keys[player(m)[1, ]], 'dpad_up')
  expect_setequal(keys[player(m)[2, ]], 'a')
  expect_setequal(keys[player(m)[3, ]], c('dpad_right', 'b'))
  expect_false(any(player(m)[4, ]))
  expect_null(m$source_trailing)
  expect_false(any(grepl('input_length', keys)))
})
test_that('mGBA input length precedes independent tilt and light axes', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('subframe-gba.bk2')))
  expect_equal(system_channels(m)[['input_length']], c(280896, 12345))
  channels <- analog_channels(m)
  expect_equal(channels[, 'tilt_x'], c(17, -31))
  expect_equal(channels[, 'tilt_y'], c(-23, 47))
  expect_equal(channels[, 'tilt_z'], c(41, -59))
  expect_equal(channels[, 'light_sensor'], c(99, 83))
  keys <- button_layout(m)$key
  expect_setequal(keys[player(m)[1, ]], c('dpad_right', 'a'))
  expect_setequal(keys[player(m)[2, ]], 'b')
  expect_identical(system_channels(m)$power, c(FALSE, TRUE))
  expect_null(m$source_trailing)
})
test_that('MAME throttle remains a numeric axis independently of stick X and Y', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('arcade-throttle.bk2')))
  channels <- analog_channels(m)
  expect_equal(channels[, 'left_x'], c(321, 654))
  expect_equal(channels[, 'left_y'], c(432, 567))
  expect_equal(channels[, 'throttle_stick'], c(345, 456))
  expect_null(m$source_trailing)
  expect_false(any(grepl('throttle', button_layout(m)$key)))
})
test_that('BizHawk pipe separators may be empty or moved between Boolean fields', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('empty-separators.bk2')))
  keys <- button_layout(m)$key
  expect_setequal(keys[player(m)[1, ]], 'dpad_up')
  expect_setequal(keys[player(m)[2, ]], c('dpad_up', 'a'))
  expect_setequal(keys[player(m)[3, ]], c('dpad_right', 'b'))
  expect_equal(m$header$logKeyStreamBoundarySamples, 3)
  expect_null(m$source_trailing)
  parts <- read_bk2_chunks(bk2_variant_fixture('subframe-gba.bk2'), identity, chunk_size = 1L)
  expect_equal(unlist(lapply(parts, function(x) system_channels(x)[['input_length']])), c(280896, 12345))
})
test_that('genuine unconsumed source text remains visible and warned', {
  input <- 'LogKey:#Power|Reset|#P1 A|\n|..|A|orphan|'
  expect_warning(m <- replayr:::.parse_bk2_input_log(input, list(Platform = 'NES')), 'trailing source text')
  expect_equal(m$source_trailing, 'orphan')
  expect_equal(n_observations(m), 1)
  expect_true(player(m)[1, 1])
})
test_that('an unrecognised numeric field cannot silently disappear into Boolean columns', {
  log <- 'LogKey:#Unfamiliar Control|Fire|\n|1,|'
  expect_warning(
    m <- replayr:::.parse_bk2_input_log(log, list(Platform = 'Arcade')),
    'comma consumed as a Boolean'
  )
  expect_equal(m$ambiguous_input$source_input, '|1,|')
  expect_equal(m$ambiguous_input$field, 'Fire')
  expect_equal(m$header$ambiguousBooleanCommaSamples, 1)
  expect_null(m$source_trailing)
  expect_no_warning(key <- replayr:::.parse_bk2_input_log(
    'LogKey:#,|\n|,|', list(Platform = 'AppleII')
  ))
  expect_true(player(key)[1, 1])
})
test_that('ignored padding and readable suffix notes remain available without false warnings', {
  log <- 'LogKey:#Power|Reset|#P1 A|\n|..|A|........|\n|..|.| Level 2-1\n'
  expect_no_warning(m <- replayr:::.parse_bk2_input_log(log, list(Platform = 'NES')))
  expect_equal(m$source_trailing, c('........', ' Level 2-1'))
  expect_equal(m$header$sourceTrailingPaddingSamples, 1)
  expect_equal(m$header$sourceTrailingAnnotationSamples, 1)
  expect_equal(m$header$sourceTrailingUnboundSamples, 0)
  expect_identical(as.vector(player(m)), c(TRUE, FALSE))
  expect_warning(
    replayr:::.parse_bk2_input_log(
      'LogKey:#Power|Reset|#P1 A|\n|..|A||..|A|', list(Platform = 'NES')
    ),
    'unbound controls'
  )
})
test_that("an indented LogKey still supplies the control layout", {
  log <- paste(c(
    "[Input]",
    "    LogKey:#Tilt X|Light Sensor|Up|Down|Left|Right|Start|Select|B|A|L|R|Power|",
    "    |    0,    0,...........|",
    "|    5,    7,U......A.R.|",
    "|   -3,    0,..........P|",
    "[/Input]"
  ), collapse = "\n")
  header <- list("_format" = "bk2", Platform = "GBA", Core = "mGBA")
  expect_warning(
    wire <- replayr:::.parse_bk2_input_log(log, header),
    "LogKey line is indented"
  )
  movie <- replayr:::.configure_movie(wire)
  # BizHawk reads rows only at the start of a line, so the indented row is excluded.
  expect_identical(n_observations(movie), 2L)
  expect_identical(movie$header$indentedInputLines, 1L)
  keys <- button_layout(movie)$key
  expect_true(all(c("l1", "r1") %in% keys))
  states <- unname(player(movie))
  expect_identical(states[, keys == "dpad_up"], c(TRUE, FALSE))
  expect_identical(states[, keys == "a"], c(TRUE, FALSE))
  expect_identical(states[, keys == "r1"], c(TRUE, FALSE))
  expect_equal(unname(analog_channels(movie)[, "tilt_x"]), c(5, -3))
  expect_identical(system_channels(movie)$power, c(FALSE, TRUE))
})
test_that("a log without a LogKey is read only as a verified NES layout", {
  rows <- c("|    0,    0,U......A.R.|", "|    0,    0,...........|")
  log <- paste(c("[Input]", rows, "[/Input]"), collapse = "\n")
  expect_error(
    replayr:::.parse_bk2_input_log(log, list("_format" = "bk2", Platform = "GBA")),
    "no LogKey line"
  )
  nes <- paste(c("[Input]", "|..|U......A|........|", "[/Input]"), collapse = "\n")
  movie <- replayr:::.parse_bk2_input_log(nes, list("_format" = "bk2", Platform = "NES"))
  expect_identical(n_observations(movie), 1L)
  expect_true(movie$inputs[1L, 1L, 4L])
})
test_that("a BK2 control is held unless its character is a period", {
  # BizHawk's rule applies to every control and every reading path.
  header <- list("_format" = "bk2", Platform = "GB", Core = "Gambatte")
  log <- paste(c(
    "[Input]",
    "LogKey:#Up|Down|Left|Right|Start|Select|B|A|Power|",
    "|x.......!|",
    "| ....... |",
    "|.........|",
    "[/Input]"
  ), collapse = "\n")
  movie <- replayr:::.configure_movie(replayr:::.parse_bk2_input_log(log, header))
  keys <- button_layout(movie)$key
  expect_identical(unname(player(movie, 1L)[, keys == "dpad_up"]), c(TRUE, TRUE, FALSE))
  expect_identical(unname(system_channels(movie)$power), c(TRUE, TRUE, FALSE))
  expect_identical(movie$commands, c(1L, 1L, 0L))
  # Without a LogKey a verified NES log is read by position, by the same rule.
  nes <- list("_format" = "bk2", Platform = "NES", Core = "NesHawk")
  bare <- paste(c(
    "[Input]",
    "|..|x......!|........|",
    "| .| .......|........|",
    "|..|........|........|",
    "[/Input]"
  ), collapse = "\n")
  fallback <- suppressWarnings(replayr:::.parse_bk2_input_log(bare, nes))
  expect_identical(rowSums(fallback$inputs[, 1L, ]), c(2, 1, 0))
  expect_identical(fallback$commands != 0L, c(FALSE, TRUE, FALSE))
})
test_that("each text reader applies its emulator's rule to other marks", {
  rows <- function(lines, ext) {
    path <- tempfile(fileext = ext)
    writeLines(lines, path)
    path
  }
  # DeSmuME, PCEjin and Yabause: held unless '.' or a space.
  dsm <- read_dsm(rows(c("version 1", "|0|x............000 000 0|", "|0| ............000 000 0|"), ".dsm"))
  expect_identical(rowSums(player(dsm, 1L)), c(1, 0))
  mc2 <- read_mc2(rows(c("version 1", "emuVersion 9", "ports 1", "|0|x.......|", "|0| .......|"), ".mc2"))
  expect_identical(rowSums(player(mc2, 1L)), c(1, 0))
  ymv <- read_ymv(rows(c("version 1", "|0|x............|", "|0| ............|"), ".ymv"))
  expect_identical(rowSums(player(ymv, 1L)), c(1, 0))
  # lsnes: held unless '.', a space or a tab.
  lsmv <- replayr:::.parse_lsmv_input(
    "F. 0 0|x...........\n.. 0 0| ...........\n.. 0 0|\t...........\n",
    header = list("_format" = "lsmv", gametype = "snes_ntsc")
  )
  expect_identical(rowSums(lsmv$inputs[, 1L, ]), c(1, 0, 0))
})
