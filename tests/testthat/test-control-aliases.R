.alias_movie <- function(keys, states = diag(length(keys)) == 1, players = 1L) {
  input <- array(FALSE, c(nrow(states), players, length(keys)))
  input[, 1L, ] <- states
  wire <- replayr:::.new_named_movie(
    list(`_format` = "fixture"),
    integer(nrow(states)), input, keys
  )
  replayr:::.configure_movie(wire)
}
.alias_states <- function(movie, keys) {
  layout <- button_layout(movie)
  at <- match(keys, layout$key)
  expect_false(anyNA(at))
  unname(player(movie)[, at, drop = FALSE])
}
test_that("shared mouse and gamepad actions retain their independent source states", {
  states <- rbind(
    c(TRUE, FALSE, FALSE, FALSE),
    c(FALSE, TRUE, FALSE, FALSE),
    c(TRUE, TRUE, FALSE, FALSE),
    c(FALSE, FALSE, TRUE, FALSE),
    c(FALSE, FALSE, FALSE, TRUE),
    rep(FALSE, 4)
  )
  keys <- c("a", "mouse_left", "mouse_right", "mouse_middle")
  movie <- .alias_movie(keys, states, players = 2L)
  expect_identical(button_layout(movie)$key, c("b", "a", "x"))
  expect_identical(as.integer(button_layout(movie)$id), c(7L, 8L, 9L))
  expect_identical(
    .alias_states(movie, c("a", "b", "x")),
    cbind(
      c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE),
      c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE),
      c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)
    )
  )
  expect_false(any(player(movie, 2L)))
  expect_identical(movie$source_layout$key, keys)
  expect_identical(movie$source_layout$universal_key, c("a", "a", "b", "x"))
  expect_identical(unname(movie$source_inputs[, 1L, ]), states)
  expect_false(any(movie$source_inputs[, 2L, ]))
})
test_that("numbered devices share equal labels while zero and ten remain distinct", {
  keys <- c("keypad_0", "keypad_1", "power_pad_1", "power_pad_10", "power_pad_12")
  movie <- .alias_movie(keys)
  expect_identical(
    button_layout(movie)$key,
    c("numbered_0", "numbered_1", "numbered_10", "numbered_12")
  )
  expect_identical(as.integer(button_layout(movie)$id), c(40L, 41L, 50L, 52L))
  expect_identical(button_layout(movie)$kind, rep("numbered", 4L))
  expect_identical(
    .alias_states(movie, button_layout(movie)$key),
    rbind(
      c(TRUE, FALSE, FALSE, FALSE), c(FALSE, TRUE, FALSE, FALSE),
      c(FALSE, TRUE, FALSE, FALSE), c(FALSE, FALSE, TRUE, FALSE),
      c(FALSE, FALSE, FALSE, TRUE)
    )
  )
  expect_identical(movie$source_layout$key, keys)
  expect_identical(unname(movie$source_inputs[, 1L, ]), diag(5) == 1)
})
test_that("legacy wire aliases preserve the original states and field identities", {
  input <- array(FALSE, c(4L, 1L, 50L))
  input[1, 1, 43] <- TRUE # D
  input[2, 1, 46] <- TRUE # Gun trigger
  input[3, 1, 50] <- TRUE # Mouse right
  input[4, 1, c(43, 46, 50)] <- TRUE
  wire <- replayr:::.new_movie(
    list(`_format` = "bk2", Platform = "Arcade"),
    integer(4), input
  )
  wire$decoded_button_slots <- c(43L, 46L, 50L)
  movie <- replayr:::.configure_movie(wire)
  expect_identical(button_layout(movie)$key, c("b", "a", "y"))
  expect_identical(movie$source_layout$key, c("d", "gun_trigger", "mouse_right"))
  expect_identical(movie$source_layout$universal_key, c("y", "a", "b"))
  expect_identical(unname(movie$source_inputs), input[, , c(43, 46, 50), drop = FALSE])
  expect_identical(
    .alias_states(movie, c("y", "a", "b")),
    rbind(diag(3) == 1, rep(TRUE, 3))
  )
})
test_that("Doom attack and use are game actions, apart from pad buttons", {
  path <- tempfile(fileext = ".lmp")
  on.exit(unlink(path))
  header <- as.raw(c(109, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0))
  records <- as.raw(c(
    0, 0, 0, 1, 0, 0, 0, 2,
    0, 0, 0, 3, 0, 0, 0, 0
  ))
  writeBin(c(header, records, as.raw(128)), path)
  movie <- read_lmp(path)
  expect_identical(button_layout(movie)$key, c("action_attack", "action_use"))
  expect_identical(button_layout(movie)$id, c("action:attack", "action:use"))
  expect_identical(button_layout(movie)$kind, c("action", "action"))
  expect_identical(
    .alias_states(movie, c("action_attack", "action_use")),
    rbind(c(TRUE, FALSE), c(FALSE, TRUE), c(TRUE, TRUE), c(FALSE, FALSE))
  )
  expect_false(any(c("a", "b") %in% movie$button_keys))
  expect_null(movie$source_layout)
  expect_null(movie$source_inputs)
})
test_that("Neo Geo C and D join the four face actions without changing Genesis C", {
  parse <- function(platform, labels) {
    key <- paste0("LogKey:#P1 ", paste(labels, collapse = "|P1 "), "|")
    states <- vapply(seq_along(labels), function(i) {
      row <- rep(".", length(labels))
      row[i] <- "1"
      paste0("|", paste0(row, collapse = ""), "|")
    }, character(1))
    source <- replayr:::.parse_bk2_input_log(
      paste(c(key, states), collapse = "\n"),
      list(`_format` = "bk2", Platform = platform)
    )
    replayr:::.configure_movie(source)
  }
  arcade <- parse("ARCADE", c("A", "B", "C", "D"))
  expect_identical(.alias_states(arcade, c("a", "b", "x", "y")), diag(4) == 1)
  expect_false("c" %in% button_layout(arcade)$key)
  genesis <- parse("GEN", c("A", "B", "C", "X", "Y", "Z"))
  expect_identical(.alias_states(genesis, c("a", "b", "c", "x", "y", "z")), diag(6) == 1)
  numbered <- .alias_movie(paste0("arcade_button_", 1:8))
  expect_identical(
    .alias_states(numbered, c("a", "b", "x", "y", "l1", "r1", "l2", "r2")),
    diag(8) == 1
  )
})
test_that("keypad symbols and qualified device controls survive consolidation", {
  keys <- c(
    "keypad_enter", "keypad_clear", "keypad_star", "keypad_pound", "extra",
    "openmsx_msxjoystate_0_a", "openmsx_msxjoystate_1_a",
    "openmsx_lightgunstate_0_light", "keysym_64", "keysym_77"
  )
  movie <- .alias_movie(keys)
  # Star and Pound sit where Clear and Enter do and share Select and Start.
  retained <- keys[-(1:4)]
  expected <- diag(10) == 1
  expected <- cbind(expected[, 1L] | expected[, 4L], expected[, 2L] | expected[, 3L], expected[, 5:10])
  expect_identical(.alias_states(movie, c("start", "select", retained)), expected)
  layout <- button_layout(movie)
  expect_identical(as.character(layout$id[match(retained, layout$key)]), paste0("control:", retained))
})
test_that("Dustforce's verbs are game actions and CoffeeTools buttons share face buttons", {
  dustforce <- .alias_movie(c(
    "action_light", "action_jump", "action_heavy",
    "action_dash", "dustforce_escape", "action_taunt", "action_restart"
  ))
  expect_identical(.alias_states(
    dustforce,
    c("action_light", "action_jump", "action_heavy", "action_dash", "start", "action_taunt", "action_restart")
  ), diag(7) == 1)
  expect_identical(
    as.character(button_layout(dustforce)$id[match("action_jump", button_layout(dustforce)$key)]),
    "action:jump"
  )
  coffee <- .alias_movie(c("ufo50_fire1", "ufo50_fire2"))
  expect_identical(.alias_states(coffee, c("a", "b")), diag(2) == 1)
})
test_that("additional mouse buttons share auxiliary controls and retain source labels", {
  keys <- c("mouse_button_4", "mouse_fourth", "mouse_button_5", "l1", "r1")
  movie <- .alias_movie(keys)
  expect_identical(button_layout(movie)$key, c("l1", "r1"))
  expect_identical(as.integer(button_layout(movie)$id), c(11L, 12L))
  expect_identical(
    .alias_states(movie, c("l1", "r1")),
    rbind(
      c(TRUE, FALSE), c(TRUE, FALSE), c(FALSE, TRUE),
      c(TRUE, FALSE), c(FALSE, TRUE)
    )
  )
  expect_identical(movie$source_layout$key, keys)
  expect_identical(unname(movie$source_inputs[, 1L, ]), diag(5) == 1)
})
test_that("stored layouts from before renumbering require rereading their source", {
  current <- .alias_movie("microphone")
  expect_identical(current$layout_version, 3L)
  old <- current
  old$layout_version <- 2L
  old$control_layout <- NULL
  old$button_ids <- 53L
  old$button_keys <- "d"
  old$button_names <- "Arcade D"
  old$button_mnemonics <- "E"
  expect_error(button_layout(old), "re-read")
  expect_error(align_buttons(list(current, old)), "re-read")
  old$layout_version <- NULL
  expect_error(button_layout(old), "re-read")
})
test_that("Intellivision top and numbered joystick actions share existing controls", {
  top <- .alias_movie(c("intv_top", "l1", "r1"))
  expect_identical(.alias_states(top, c("x", "l1", "r1")), diag(3) == 1)
  joystick <- .alias_movie(paste0("joystick_button_", 1:8))
  expect_identical(
    .alias_states(joystick, c("a", "b", "x", "y", "l1", "r1", "l2", "r2")),
    diag(8) == 1
  )
})
