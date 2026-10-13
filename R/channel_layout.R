# Numeric channels are named by key, as buttons are. A reader names its
# channels after the fields of its format, or keeps the labels a recording
# carries; a measurement that several formats record then has one key in all
# of them. The entries are lower-case field names and labels without the
# player prefix of a BizHawk label. A label such as `Mouse X` is a movement
# since the previous observation, whereas the field `mouse_x` of libTAS and
# Dustforce is a position; the two therefore differ in their keys.
.SHARED_CHANNEL_KEYS <- c(
  # analogue sticks
  lstick_x = "left_x", lstick_y = "left_y", rstick_x = "right_x", rstick_y = "right_y",
  stick_x = "left_x", stick_y = "left_y",
  circle_x = "left_x", circle_y = "left_y", ir_c_stick_x = "right_x", ir_c_stick_y = "right_y",
  `circle pad x` = "left_x", `circle pad y` = "left_y", `c-stick x` = "right_x", `c-stick y` = "right_y",
  nunchuk_x = "left_x", nunchuk_y = "left_y",
  classic_left_x = "left_x", classic_left_y = "left_y",
  classic_right_x = "right_x", classic_right_y = "right_y",
  # analogue triggers
  ltrigger = "left_trigger", rtrigger = "right_trigger",
  trigger_left = "left_trigger", trigger_right = "right_trigger",
  classic_ltrigger = "left_trigger", classic_rtrigger = "right_trigger",
  `left shoulder` = "left_trigger", `right shoulder` = "right_trigger",
  # movement of a mouse since the previous observation
  `mouse x` = "mouse_dx", `mouse y` = "mouse_dy",
  `motion left / right` = "mouse_dx", `motion up / down` = "mouse_dy",
  # positions on a touch surface and aim of a light gun
  `touch x` = "touch_x", `touch y` = "touch_y", touchpad_x = "touch_x", touchpad_y = "touch_y",
  gun_x = "aim_x", gun_y = "aim_y", `zapper x` = "aim_x", `zapper y` = "aim_y",
  `lightgun x` = "aim_x", `lightgun y` = "aim_y",
  # motion sensors
  accelerometer_x = "accel_x", accelerometer_y = "accel_y", accelerometer_z = "accel_z",
  gyroscope_x = "gyro_x", gyroscope_y = "gyro_y", gyroscope_z = "gyro_z",
  # how long a frame of an Atari-HEAD trial was shown
  `duration(ms)` = "duration_ms"
)
.SHARED_CHANNEL_LABELS <- c(
  left_x = "Left stick X", left_y = "Left stick Y", right_x = "Right stick X", right_y = "Right stick Y",
  left_trigger = "Left trigger", right_trigger = "Right trigger",
  mouse_dx = "Mouse movement X", mouse_dy = "Mouse movement Y",
  touch_x = "Touch X", touch_y = "Touch Y", aim_x = "Aim X", aim_y = "Aim Y",
  accel_x = "Accelerometer X", accel_y = "Accelerometer Y", accel_z = "Accelerometer Z",
  gyro_x = "Gyroscope X", gyro_y = "Gyroscope Y", gyro_z = "Gyroscope Z"
)
# A field name or label without what only says where it comes from.
.plain_channel_names <- function(names) {
  sub("^openmsx_", "", sub("^p[0-9]+ +", "", tolower(trimws(names))))
}
# The key a channel has when no other format records its measurement.
.own_channel_keys <- function(names) {
  gsub("^_+|_+$", "", gsub("[^a-z0-9]+", "_", .plain_channel_names(names)))
}
.channel_keys <- function(names, movie, idx) {
  if (!length(names)) return(character())
  plain <- .plain_channel_names(names)
  keys <- unname(.SHARED_CHANNEL_KEYS[plain])
  # BizHawk writes the two axes of a stick in several ways.
  roles <- c(lstick_x = "left_x", lstick_y = "left_y", rstick_x = "right_x", rstick_y = "right_y")
  # A light gun reports where it points, also where its axes are labelled as
  # those of a stick are.
  gun <- idx %in% movie$header$bk2NonStickPlayers
  aim <- c(`x axis` = "aim_x", `y axis` = "aim_y", x = "aim_x", y = "aim_y")
  for (i in which(is.na(keys))) {
    if (gun) {
      keys[i] <- unname(aim[plain[i]])
    } else {
      role <- .classify_analog_pair(plain[i])
      if (!is.na(role) && role %in% names(roles)) keys[i] <- roles[[role]]
    }
  }
  own <- .own_channel_keys(names)
  keys[is.na(keys)] <- own[is.na(keys)]
  # A shared key stands for one channel of a controller. Where two channels
  # would take it (the sticks of a Nunchuk and of a Classic Controller in one
  # recording), each keeps the key of its own name.
  repeated <- keys %in% keys[duplicated(keys)]
  keys[repeated] <- own[repeated]
  make.unique(keys, sep = "_")
}
# The label of a field in its recording, or a description of the field where
# the format has none.
.channel_labels <- function(source, keys) {
  labels <- source
  unlabelled <- !grepl("[A-Z ]", source)
  described <- unname(.SHARED_CHANNEL_LABELS[keys])
  plain <- gsub("_", " ", sub("^openmsx_", "", source), fixed = TRUE)
  labels[unlabelled] <- ifelse(is.na(described[unlabelled]), plain[unlabelled], described[unlabelled])
  labels
}
# Readers and the stick projections address channels by the names of their
# format; the keys are assigned once a movie is otherwise complete.
.name_channels <- function(movie) {
  if (is.null(movie$analog) || !is.null(movie$channel_source)) return(movie)
  movie$channel_source <- lapply(movie$analog, function(x) colnames(x) %||% character())
  for (p in seq_along(movie$analog)) {
    if (ncol(movie$analog[[p]])) colnames(movie$analog[[p]]) <- .channel_keys(movie$channel_source[[p]], movie, p)
  }
  movie
}
.source_channels <- function(movie, idx) {
  channels <- analog_channels(movie, idx)
  source <- movie$channel_source[[as.integer(idx)]]
  if (ncol(channels) && length(source) == ncol(channels)) colnames(channels) <- source
  channels
}
#' Names of the numeric channels of one controller
#'
#' [analog_channels()] names its columns by key, as [player()] does for
#' buttons. A measurement that several formats record has one key in all of
#' them, whatever the format calls it:
#'
#' * `left_x`, `left_y`, `right_x`, `right_y`: the axes of the analogue sticks.
#'   The N64 stick, the 3DS Circle Pad and the Nunchuk stick are the left
#'   stick; the 3DS C-stick is the right one.
#' * `left_trigger`, `right_trigger`: analogue triggers.
#' * `mouse_dx`, `mouse_dy`: movement of a mouse since the previous
#'   observation. `mouse_x` and `mouse_y` are positions.
#' * `touch_x`, `touch_y`: position on a touch surface.
#' * `aim_x`, `aim_y`: where a light gun points.
#' * `accel_x`, `accel_y`, `accel_z` and `gyro_x`, `gyro_y`, `gyro_z`: motion
#'   sensors.
#'
#' Every other channel has the key formed from its own name in lower case,
#' such as `tilt_x` for the BizHawk field `Tilt X`. Where two channels of a
#' controller would take one shared key, each keeps the key of its own name.
#' Only the names are shared: values keep the range and unit of their source
#' (see [analog_channels()]).
#'
#' @inheritParams analog_channels
#' @return Data frame with one row per channel: `column`, `key`, and `name`,
#'   the label of the field in the recording or, for formats without labels,
#'   a description of the field.
#' @export
#' @seealso [button_layout()] for the digital controls.
#' @examples
#' path <- system.file("extdata", "paper", "mouse-drag.bk2", package = "replayr")
#' channel_layout(read_movie(path))
channel_layout <- function(movie, idx = 1L) {
  keys <- colnames(analog_channels(movie, idx)) %||% character()
  source <- movie$channel_source[[as.integer(idx)]]
  if (length(source) != length(keys)) source <- keys
  data.frame(
    column = seq_along(keys), key = keys, name = .channel_labels(source, keys),
    stringsAsFactors = FALSE
  )
}
