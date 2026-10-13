make_stick_movie <- function(format = "m64", two = FALSE) {
  x <- c(0, 64, 64, 0, -64, -64, -64, 0, 64)
  y <- c(0, 0, 64, 64, 64, 0, -64, -64, -64)
  axes <- cbind(lstick_x = x, lstick_y = y)
  width <- 28L
  if (two) {
    axes <- cbind(
      lstick_x = 128 + x, lstick_y = 128 - y,
      rstick_x = 128 - y, rstick_y = 128 - x
    )
    width <- 42L
  }
  input <- array(FALSE, c(9L, 1L, width))
  input[2L, 1L, 1L] <- TRUE
  if (two) input[3L, 1L, 41:42] <- TRUE
  replayr:::.new_movie(list(`_format` = format, controllerType1 = "7"), integer(9), input,
    analog = list(axes)
  )
}
test_that("registry has distinct identities and separate sticks", {
  registry <- button_layout()
  expect_equal(anyDuplicated(registry$id), 0L)
  expect_identical(registry$id, seq_len(53L))
  expect_equal(anyDuplicated(registry$mnemonic), 0L)
  expect_equal(anyDuplicated(registry$key), 0L)
  expect_true(all(nchar(registry$mnemonic) == 1L))
  expect_equal(registry$key[13:16], c("l2", "r2", "l3", "r3"))
  expect_equal(registry$kind[24:31], rep("left_direction", 8))
  expect_equal(registry$kind[32:39], rep("right_direction", 8))
  expect_identical(registry$key[40:52], paste0("numbered_", 0:12))
  expect_identical(registry$kind[40:52], rep("numbered", 13L))
  expect_identical(registry$key[53], "microphone")
})
test_that("continuous modes have known orientation, neutral and magnitude", {
  source <- make_stick_movie()
  expected <- c(NA, 0, 45, 90, 135, 180, 225, 270, 315)
  angle <- replayr:::.configure_movie(source, "angle")
  full <- replayr:::.configure_movie(source, "angle+magnitude")
  expect_equal(colnames(stick_channels(angle)), "left_angle")
  expect_equal(stick_channels(angle)[, 1L], expected)
  expect_equal(stick_channels(full)[, "left_angle"], expected)
  expect_equal(
    stick_channels(full)[, "left_magnitude"],
    c(0, .5, sqrt(.5), .5, sqrt(.5), .5, sqrt(.5), .5, sqrt(.5))
  )
  expect_identical(analog_channels(angle), analog_channels(full))
  expect_equal(n_buttons(angle), 14L)
  expect_false(any(button_layout(angle)$kind %in% c("left_direction", "right_direction")))
})
test_that("four and eight directions are mutually exclusive and separate from C buttons", {
  source <- make_stick_movie()
  four <- replayr:::.configure_movie(source, "cardinal4")
  eight <- replayr:::.configure_movie(source, "cardinal8")
  layout <- button_layout(four)
  expect_equal(layout$id[layout$kind == "left_direction"], c(24L, 26L, 28L, 30L))
  expect_equal(stick_channels(four)[, 1L], c(NA, 0, 90, 90, 180, 180, 270, 270, 0))
  expect_equal(stick_channels(eight)[, 1L], c(NA, 0, 45, 90, 135, 180, 225, 270, 315))
  m <- player(eight)
  expect_equal(rowSums(m[, button_layout(eight)$kind == "left_direction", drop = FALSE]), c(0, rep(1, 8)))
  expect_false(any(m[, button_layout(eight)$kind == "right_direction", drop = FALSE]))
  expect_equal(n_buttons(four), 18L)
  expect_equal(n_buttons(eight), 22L)
  expect_true(all(20:23 %in% layout$id))
})
test_that("both sticks independently support all four selected modes", {
  source <- make_stick_movie("pxm", TRUE)
  for (left in c("cardinal4", "cardinal8", "angle", "angle+magnitude")) {
    for (right in c("cardinal4", "cardinal8", "angle", "angle+magnitude")) {
      movie <- replayr:::.configure_movie(source, c(left = left, right = right))
      expect_identical(unname(analog_channels(movie)), unname(analog_channels(source)))
      expect_identical(colnames(analog_channels(movie)), c("left_x", "left_y", "right_x", "right_y"))
      expect_equal(movie$stick_modes, c(left = left, right = right))
      expect_equal(button_layout(movie)$id[button_layout(movie)$key %in% c("l3", "r3")], 15:16)
      expect_true(all(player(movie)[3, button_layout(movie)$key %in% c("l3", "r3")]))
      expect_false(any(button_layout(movie)$kind == "numbered"))
    }
  }
  angle <- replayr:::.configure_movie(source, "angle")
  expect_equal(stick_channels(angle)[, "right_angle"], c(NA, 90, 135, 180, 225, 270, 315, 0, 45))
  mixed <- replayr:::.configure_movie(source, c(left = "angle+magnitude", right = "angle"))
  expect_equal(colnames(stick_channels(mixed)), c("left_angle", "left_magnitude", "right_angle"))
})
test_that("deadzone, missing data and invalid settings are explicit", {
  source <- make_stick_movie()
  movie <- replayr:::.configure_movie(source, "angle+magnitude", deadzone = .75)
  expect_true(all(is.na(stick_channels(movie)[, "left_angle"])))
  expect_equal(unname(stick_channels(movie)[2L, "left_magnitude"]), .5)
  source$analog[[1L]][2L, 1L] <- NA_real_
  movie <- replayr:::.configure_movie(source, "cardinal8")
  expect_false(movie$analysis_ready[1L])
  expect_error(replayr:::.configure_movie(source, "diagonal"), "analog must")
  expect_error(replayr:::.configure_movie(source, c("angle", "cardinal4")), "named")
  expect_error(replayr:::.configure_movie(source, "angle", deadzone = -1), "deadzone")
})
test_that("core gamepad examples expose compact capabilities and preserve source values", {
  formats <- paste0(".", tools::file_ext(list.files(
    system.file("extdata", package = "replayr", mustWork = TRUE),
    pattern = "^sample[.]", full.names = TRUE
  )))
  for (ext in formats) {
    path <- system.file("extdata", paste0("sample", ext), package = "replayr")
    movie <- read_movie(path)
    layout <- button_layout(movie)
    expect_equal(layout$column, seq_len(n_buttons(movie)))
    expect_identical(attr(player(movie), "button_ids"), movie$button_ids)
    expect_equal(nrow(analog_channels(movie)), n_observations(movie))
    if (!ext %in% c(".bk2", ".lmp")) expect_false(any(layout$kind == "numbered"))
    if (ext %in% c(".m64", ".dtm", ".pxm", ".pjm")) {
      for (mode in c("cardinal4", "cardinal8", "angle", "angle+magnitude")) {
        selected <- read_movie(path, analog = mode)
        expect_identical(analog_channels(selected), analog_channels(movie))
        expect_equal(nrow(stick_channels(selected)), n_observations(movie))
      }
    }
  }
})
test_that("BK2 N64 Boolean directions override axes without becoming physical buttons", {
  log <- paste(c(
    "[Input]", "LogKey:#Reset|Power|#P1 X Axis|P1 Y Axis|P1 A Up|P1 A Down|P1 A Left|P1 A Right|P1 A|",
    "|..|30,40,.....|", "|..|30,40,U....|", "|..|30,40,UDLR.|"
  ), collapse = "\n")
  source <- replayr:::.parse_bk2_input_log(log, list("_format" = "bk2", Platform = "N64", emuVersion = "Version 1.11.6"))
  raw <- replayr:::.configure_movie(source, "raw")
  movie <- replayr:::.configure_movie(source, "angle+magnitude")
  expect_equal(n_buttons(raw), 1L)
  expect_identical(analog_channels(movie), analog_channels(raw))
  expect_equal(analog_channels(movie)[3, ], c(left_x = 30, left_y = 40))
  expect_equal(stick_channels(movie)[3, "left_angle"], c(left_angle = 135))
  expect_equal(stick_channels(movie)[3, "left_magnitude"], c(left_magnitude = sqrt(2) * 127 / 128))
  expect_equal(colSums(movie$stick_overrides[[1]]), c(right = 1, up = 2, left = 1, down = 1))
  source$header$emuVersion <- "Version 2.9.1"
  newer <- replayr:::.configure_movie(source, "angle+magnitude")
  expect_equal(unname(stick_channels(newer)[3, "left_angle"]), atan2(127, -128) * 180 / pi)
  for (mode in c("cardinal4", "cardinal8")) {
    projected <- replayr:::.configure_movie(source, mode)
    ids <- button_layout(projected)$kind == "left_direction"
    expect_equal(rowSums(player(projected)[, ids, drop = FALSE]), rep(1, 3))
  }
})
test_that("unknown N64 override calibration preserves raw data", {
  log <- paste(c("[Input]", "LogKey:#Reset|Power|#P1 X Axis|P1 Y Axis|P1 A Up|P1 A|", "|..|0,0,U.|"), collapse = "\n")
  source <- replayr:::.parse_bk2_input_log(log, list("_format" = "bk2", Platform = "N64"))
  raw <- replayr:::.configure_movie(source, "raw")
  expect_true(raw$stick_overrides[[1]][1, "up"])
  expect_error(replayr:::.configure_movie(source, "angle"), "known BizHawk")
  expect_error(player(raw, 1.5), "integer")
})
