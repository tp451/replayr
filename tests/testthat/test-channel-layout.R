# Numeric channels are named by key; the labels of the recording stay in
# channel_layout().
sample_channels <- function(file, ...) {
  path <- system.file("extdata", file, package = "replayr", mustWork = TRUE)
  suppressWarnings(read_movie(path, ...))
}
test_that("the left stick has one key in every format", {
  files <- c(
    "sample.m64", "sample.dtm", "semantic/semantic-onehot.pxm", "semantic/semantic-onehot.pjm",
    "expanded/legacy-n64.bkm", "expanded/two-stick-3ds.bk2", "legacy/devices.ctm",
    "legacy/buttons.gzm", "computers/dual-stick-menu.ltm"
  )
  for (file in files) {
    keys <- colnames(analog_channels(sample_channels(file)))
    expect_true(all(c("left_x", "left_y") %in% keys), info = file)
  }
  n64 <- replayr:::.configure_movie(replayr:::.parse_bk2_input_log(
    paste(c("[Input]", "LogKey:#Reset|Power|#P1 X Axis|P1 Y Axis|P1 A|", "|..|  30,  40,.|"), collapse = "\n"),
    list("_format" = "bk2", Platform = "N64", emuVersion = "Version 2.9.1")
  ))
  expect_identical(channel_layout(n64), data.frame(
    column = 1:2, key = c("left_x", "left_y"), name = c("P1 X Axis", "P1 Y Axis")
  ))
  # A format without labels describes its fields.
  expect_identical(channel_layout(sample_channels("sample.m64"))$name, c("Left stick X", "Left stick Y"))
  dtm <- channel_layout(sample_channels("sample.dtm"))
  expect_identical(dtm$key, c("left_trigger", "right_trigger", "left_x", "left_y", "right_x", "right_y"))
  expect_identical(dtm$name[1:2], c("Left trigger", "Right trigger"))
})
test_that("pointing devices are told apart by what they measure", {
  mouse <- sample_channels("paper/mouse-drag.bk2")
  expect_identical(channel_layout(mouse), data.frame(
    column = 1:2, key = c("mouse_dx", "mouse_dy"),
    name = c("P1 Motion Left / Right", "P1 Motion Up / Down")
  ))
  # The axes of a light gun are where it points, although BizHawk labels
  # them as it labels the axes of a stick.
  gun <- channel_layout(sample_channels("paper/light-gun.bk2"))
  expect_setequal(gun$key, c("aim_x", "aim_y"))
  expect_identical(gun$name[match(c("aim_x", "aim_y"), gun$key)], c("P1 X Axis", "P1 Y Axis"))
  keys <- function(labels) replayr:::.channel_keys(labels, list(header = list()), 1L)
  expect_identical(keys(c("P2 Zapper X", "P2 Zapper Y")), c("aim_x", "aim_y"))
  expect_identical(keys(c("P1 Mouse X", "P1 Mouse Y")), c("mouse_dx", "mouse_dy"))
  # libTAS and Dustforce store a position under the same letters.
  expect_identical(keys(c("mouse_x", "mouse_y", "mouse_wheel")), c("mouse_x", "mouse_y", "mouse_wheel"))
  expect_identical(keys(c("Touch X", "Touch Y")), c("touch_x", "touch_y"))
  expect_identical(keys(c("openmsx_touchpad_x", "openmsx_touchpad_y")), c("touch_x", "touch_y"))
})
test_that("a channel without a shared key keeps the key of its own name", {
  keys <- function(labels) replayr:::.channel_keys(labels, list(header = list()), 1L)
  expect_identical(
    keys(c("Tilt X", "Light Sensor", "Throttle Stick", "P1 Paddle X 1", "gyro_pitch", "openmsx_paddle_delta")),
    c("tilt_x", "light_sensor", "throttle_stick", "paddle_x_1", "gyro_pitch", "paddle_delta")
  )
  # Two sticks that would both be the left one keep their own names.
  expect_identical(
    keys(c("nunchuk_x", "nunchuk_y", "classic_left_x", "classic_left_y", "classic_right_x", "accel_x")),
    c("nunchuk_x", "nunchuk_y", "classic_left_x", "classic_left_y", "right_x", "accel_x")
  )
  expect_identical(keys(c("nunchuk_x", "nunchuk_y")), c("left_x", "left_y"))
  expect_identical(keys(character()), character())
})
test_that("naming leaves values, projections and poll streams as they were", {
  folder <- system.file("extdata", package = "replayr")
  files <- list.files(folder, recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("[.](md|json|csv|txt)$", files)]
  with_channels <- 0L
  streams <- 0L
  for (file in files) {
    movie <- tryCatch(suppressWarnings(read_movie(file)), error = function(e) NULL)
    if (is.null(movie)) next
    for (p in seq_len(dim(movie$inputs)[2L])) {
      layout <- channel_layout(movie, p)
      values <- analog_channels(movie, p)
      expect_identical(layout$key, as.character(colnames(values)), info = basename(file))
      if (!nrow(layout)) next
      with_channels <- with_channels + 1L
      expect_true(all(grepl("^[a-z0-9_]+$", layout$key)), info = basename(file))
      expect_false(anyDuplicated(layout$key) > 0L, info = basename(file))
      expect_identical(unname(values), unname(replayr:::.source_channels(movie, p)), info = basename(file))
      if (inherits(movie, "replayr_poll_stream")) {
        streams <- streams + 1L
        expect_true(all(layout$key %in% names(polls(movie))), info = basename(file))
      }
    }
  }
  expect_gt(with_channels, 30L)
  expect_gt(streams, 0L)
  raw <- sample_channels("sample.dtm")
  projected <- sample_channels("sample.dtm", analog = "cardinal8", triggers = "digital")
  expect_identical(analog_channels(raw), analog_channels(projected))
  expect_error(channel_layout(raw, 9L), "idx must identify one player")
})
