# openMSX serialised replay events. Source schemas:
# https://github.com/openMSX/openMSX/blob/f07bee985b8e2102c47913c217ad0365638bf8ae/src/input/StateChange.hh
# https://github.com/openMSX/openMSX/blob/master/src/EmuDuration.hh
# Event time is in 3579545 * 960 ticks/second, independent of video frames.
#
# Every device of a recording is one controller: the keyboard first, then the
# devices on the joystick ports. Their controls follow the rules of every
# other reader. The bits of a joystick port are those of JoystickDevice.hh at
# the revision above: up, down, left, right, button A, button B. A mouse and
# a trackball send their left and right button as A and B (Mouse.cc,
# Trackball.cc); the JoyMega pad adds C, Start, X, Y, Z and Mode.
.omr_text <- function(node, name, default = "") {
  value <- xml2::xml_text(xml2::xml_find_first(node, name, ns = character()))
  if (is.na(value)) default else value
}
# The text of the first element at each path below every event, or NA. One
# search returns the events and these elements in document order, where each
# element follows the event it belongs to.
.omr_fields <- function(replay, n, paths) {
  found <- xml2::xml_find_all(replay, paste(c("events/item", paste0("events/item/", paths)), collapse = " | "),
    ns = character())
  name <- xml2::xml_name(found)
  event <- cumsum(name == "item")
  stopifnot(max(c(0L, event)) == n)
  lapply(paths, function(path) {
    at <- which(name == basename(path))
    at <- at[!duplicated(event[at])]
    value <- rep(NA_character_, n)
    value[event[at]] <- xml2::xml_text(found[at])
    value
  })
}
.OMR_DEVICE_TYPES <- c(
  "KeyJoyState", "MSXJoyState", "JoyMegaState", "JoyHandleState", "MouseState",
  "TrackballState", "ArkanoidState", "PaddleState", "TouchpadState", "LightGunState"
)
# The controls of a device, in the order of the bits or fields that carry
# them. A bit without a control is NA.
.omr_controls <- function(type, device) {
  pad <- c("dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "b")
  if (type %in% c("KeyJoyState", "MSXJoyState", "JoyHandleState")) return(pad)
  if (type == "JoyMegaState") return(c(pad, "c", "start", "x", "y", "z", "mode"))
  if (type == "MouseState") return(c(NA, NA, NA, NA, "mouse_left", "mouse_right"))
  if (type == "TrackballState") return(c(NA, NA, NA, NA, "a", "b"))
  if (type == "ArkanoidState") return("a")
  # A touch on the pad is L3, the press of a pointing input.
  if (type == "TouchpadState") return(c("l3", "a"))
  # The light sensor of a gun is not a button.
  if (type == "LightGunState" && device %in% c("lightgunstate_0", "lightgunstate_1"))
    return(c("gun_trigger", "light_sensor"))
  character()
}
.decode_omr <- function(path) {
  # NONET prevents loading the external openmsx-serialize DTD. Entity expansion
  # is not enabled, and only serialised replay nodes are read.
  if (!.is_gzip_file(path))
    stop(path, ": not an openMSX replay: a gzip-compressed XML document is expected", call. = FALSE)
  con <- gzfile(path, "rb")
  on.exit(close(con), add = TRUE)
  doc <- tryCatch(xml2::read_xml(con, options = c("NONET", "NOBLANKS")), error = function(e) {
    stop(path, ": not an openMSX replay: its content is not an XML document", call. = FALSE)
  })
  replay <- xml2::xml_find_first(doc, "/serial/replay", ns = character())
  if (inherits(replay, "xml_missing")) stop("Invalid openMSX replay document", call. = FALSE)
  nodes <- xml2::xml_find_all(replay, "events/item", ns = character())
  types <- xml2::xml_attr(nodes, "type")
  n <- length(nodes)
  known <- c("EndLog", "KeyMatrixState", "MSXCommandEvent", "AutofireStateChange", .OMR_DEVICE_TYPES)
  if (anyNA(types) || any(!types %in% known))
    stop("Unsupported openMSX event type: ", paste(setdiff(types, known), collapse = ", "), call. = FALSE)
  text <- .omr_fields(replay, n, c(
    time = "StateChange/time/time", row = "row", press = "press", release = "release", name = "name",
    id = "id", status = "status", touch = "touch", button = "button", delta = "delta", deltaX = "deltaX",
    deltaY = "deltaY", x = "x", y = "y", value = "value", analog = "analog"
  ))
  or <- function(x, default) {
    x[is.na(x)] <- default
    x
  }
  time_source <- or(text$time, "")
  ticks <- .computer_number(time_source, "openMSX timestamp", 0, 2^53)
  if (any(diff(ticks) < 0)) stop("Unordered openMSX events", call. = FALSE)
  device <- tolower(sub("State$", "", types))
  device[types == "KeyMatrixState"] <- "keyboard"
  named <- types == "KeyJoyState"
  device[named] <- or(text$name[named], "keyjoystick")
  numbered <- types %in% c("MSXJoyState", "JoyMegaState", "JoyHandleState", "LightGunState")
  device[numbered] <- paste0(tolower(types[numbered]), "_", or(text$id[numbered], "0"))
  bitwise <- types %in% c("KeyMatrixState", "KeyJoyState", "MSXJoyState", "JoyMegaState", "JoyHandleState",
    "MouseState", "TrackballState")
  keyboard <- types == "KeyMatrixState"
  pointer <- types %in% c("MouseState", "TrackballState")
  paddle <- types %in% c("ArkanoidState", "PaddleState")
  touchpad <- types == "TouchpadState"
  gun <- types == "LightGunState"
  autofire <- types == "AutofireStateChange"
  # A missing number is 0; a gun status has no default.
  number <- function(name) suppressWarnings(as.numeric(or(text[[name]], "0")))
  row <- number("row")
  press <- number("press")
  release <- number("release")
  delta_x <- number("deltaX")
  delta_y <- number("deltaY")
  delta <- number("delta")
  touch_x <- number("x")
  touch_y <- number("y")
  setting <- number("value")
  status <- suppressWarnings(as.numeric(or(text$status, "")))
  # Reading stops at the first event that cannot be read; within an event the
  # fields are checked in the order of the assignments from last to first.
  fault <- rep(NA_character_, n)
  fault[autofire & !.computer_valid(setting)] <- "Invalid openMSX value"
  fault[gun & !.computer_valid(status, 0, 255)] <- "Invalid openMSX gun status"
  fault[touchpad & !.computer_valid(touch_y)] <- "Invalid openMSX y"
  fault[touchpad & !.computer_valid(touch_x)] <- "Invalid openMSX x"
  fault[paddle & !.computer_valid(delta)] <- "Invalid openMSX delta"
  fault[pointer & !.computer_valid(delta_y)] <- "Invalid openMSX deltaY"
  fault[pointer & !.computer_valid(delta_x)] <- "Invalid openMSX deltaX"
  fault[bitwise & !.computer_valid(release)] <- "Invalid openMSX release"
  fault[bitwise & !.computer_valid(press)] <- "Invalid openMSX press"
  fault[keyboard & .computer_valid(row) & (row < 0 | row > 15)] <- "Invalid openMSX keyboard matrix row"
  fault[keyboard & !.computer_valid(row)] <- "Invalid openMSX row"
  if (any(!is.na(fault))) stop(fault[!is.na(fault)][1L], call. = FALSE)
  # Every control that an event sets: the event, the control, whether it is
  # pressed and whether it is released. Keyboard rows have eight keys; a
  # device keeps every bit of its masks, and a bit without a control has its
  # own key.
  set_event <- integer()
  set_control <- character()
  set_press <- set_release <- logical()
  add_sets <- function(events, controls, pressed, released) {
    if (!length(events)) return(invisible(NULL))
    set_event <<- c(set_event, events)
    set_control <<- c(set_control, controls)
    set_press <<- c(set_press, pressed)
    set_release <<- c(set_release, released)
  }
  mask_bits <- function(mask, events, width) {
    bitwAnd(rep(as.integer(mask[events]), each = width), rep(bitwShiftL(1L, seq_len(width) - 1L), length(events))) != 0
  }
  at <- which(keyboard)
  matrix_keys <- paste0("openmsx_key_r", rep(0:15, each = 8L), "_b", 0:7)
  add_sets(rep(at, each = 8L), matrix_keys[rep(row[at] * 8L, each = 8L) + rep(1:8, length(at))],
    mask_bits(press, at, 8L), mask_bits(release, at, 8L))
  pads <- which(bitwise & !keyboard)
  for (at in split(pads, paste(types[pads], device[pads]))) {
    dev <- device[at[1L]]
    controls <- .omr_controls(types[at[1L]], dev)
    controls <- c(controls, rep(NA, max(0L, 8L - length(controls))))
    blank <- is.na(controls)
    controls[blank] <- paste0("openmsx_", dev, "_bit", which(blank) - 1L)
    width <- length(controls)
    add_sets(rep(at, each = width), rep(controls, length(at)), mask_bits(press, at, width),
      mask_bits(release, at, width))
  }
  at <- which(types == "ArkanoidState")
  add_sets(at, rep("a", length(at)), or(text$press[at], "") %in% c("true", "1"),
    or(text$release[at], "") %in% c("true", "1"))
  at <- which(touchpad)
  touched <- as.vector(rbind(or(text$touch[at], "") %in% c("true", "1"), or(text$button[at], "") %in% c("true", "1")))
  add_sets(rep(at, each = 2L), rep(c("l3", "a"), length(at)), touched, !touched)
  # Gunstick and Terminator Laser use different pins and light polarity.
  # openMSX f07bee985b8e2102c47913c217ad0365638bf8ae:
  # Gunstick.cc, TerminatorLaser.cc, and JoystickDevice.hh.
  at <- which(gun & device %in% c("lightgunstate_0", "lightgunstate_1"))
  pins <- as.integer(status[at])
  stick <- device[at] == "lightgunstate_0"
  aimed <- as.vector(rbind(
    ifelse(stick, bitwAnd(pins, 16L) == 0L, bitwAnd(pins, 32L) == 0L),
    ifelse(stick, bitwAnd(pins, 2L) == 0L, bitwAnd(pins, 16L) != 0L)
  ))
  add_sets(rep(at, each = 2L), rep(c("gun_trigger", "light_sensor"), length(at)), aimed, !aimed)
  set_keyboard <- keyboard[set_event]
  changed <- (set_press | set_release) %in% TRUE
  # The numeric fields of each event, in event order and, within an event, in
  # the order of its fields.
  update_event <- integer()
  update_name <- character()
  update_value <- numeric()
  add_updates <- function(events, names, values) {
    if (!length(events)) return(invisible(NULL))
    update_event <<- c(update_event, events)
    update_name <<- c(update_name, names)
    update_value <<- c(update_value, values)
  }
  at <- which(pointer)
  add_updates(rep(at, each = 2L), paste0("openmsx_", rep(device[at], each = 2L), c("_dx", "_dy")),
    as.vector(rbind(delta_x[at], delta_y[at])))
  at <- which(paddle)
  add_updates(at, paste0("openmsx_", device[at], "_delta"), delta[at])
  at <- which(touchpad)
  add_updates(rep(at, each = 2L), rep(c("openmsx_touchpad_x", "openmsx_touchpad_y"), length(at)),
    as.vector(rbind(touch_x[at], touch_y[at])))
  at <- which(types == "JoyHandleState")
  add_updates(at, paste0("openmsx_", device[at], "_analog"), vapply(or(text$analog[at], ""), as.numeric, numeric(1),
    USE.NAMES = FALSE))
  at <- which(gun)
  add_updates(at, paste0("openmsx_", device[at], "_status"), status[at])
  at <- which(autofire)
  add_updates(at, paste0("openmsx_autofire_", or(text$name[at], "unknown")), setting[at])
  in_order <- order(update_event)
  update_event <- update_event[in_order]
  update_name <- update_name[in_order]
  update_value <- update_value[in_order]
  # The keyboard is the first controller; each other device follows by name.
  on_device <- types %in% .OMR_DEVICE_TYPES
  controllers <- c("keyboard", sort(unique(device[on_device])))
  owner <- match(ifelse(types == "KeyMatrixState" | on_device, device, NA), controllers)
  # Only keyboard keys exercised by this recording are included; source matrix
  # positions are retained because MSX, SVI, and Coleco keyboard layouts
  # differ. A device keeps all its controls, pressed or not.
  active_keys <- set_control[set_keyboard & changed]
  initial <- xml2::xml_find_all(replay, "snapshots/item[1]//keyboard/userKeyMatrix/item", ns = character())
  initial_values <- if (length(initial)) {
    .computer_number(xml2::xml_text(initial), "openMSX initial keyboard", 0, 255)
  } else {
    numeric()
  }
  initial_keys <- character()
  for (row in seq_along(initial_values)) {
    bits <- which(bitwAnd(as.integer(initial_values[row]), bitwShiftL(1L, 0:7)) == 0) - 1L
    if (length(bits)) initial_keys <- c(initial_keys, paste0("openmsx_key_r", row - 1L, "_b", bits))
  }
  keyboard_keys <- sort(unique(c(active_keys, initial_keys)))
  spare <- grepl("_bit[0-9]$", set_control)
  device_keys <- unique(set_control[!set_keyboard & (!spare | changed)])
  listed <- c(
    "dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "b", "c", "start", "x", "y", "z", "mode",
    "mouse_left", "mouse_right", "l3", "gun_trigger", "light_sensor"
  )
  device_keys <- c(intersect(listed, device_keys), sort(setdiff(device_keys, listed)))
  keys <- c(keyboard_keys, device_keys)
  inputs <- array(FALSE, c(n, length(controllers), length(keys)))
  held <- keys %in% initial_keys & seq_along(keys) <= length(keyboard_keys)
  inputs[, 1L, held] <- TRUE
  # A control keeps the state of the last event that set it; a release
  # overrides a press in the same event. Keyboard keys and device controls are
  # looked up in their own part.
  column <- ifelse(set_keyboard, match(set_control, keyboard_keys), length(keyboard_keys) + match(set_control, device_keys))
  state <- ifelse(set_release %in% TRUE, FALSE, ifelse(set_press %in% TRUE, TRUE, NA))
  use <- which(!is.na(state) & !is.na(column))
  use <- use[order(set_event[use])]
  set_owner <- owner[set_event]
  for (at in split(use, (set_owner[use] - 1L) * length(keys) + column[use])) {
    p <- set_owner[at[1L]]
    k <- column[at[1L]]
    inputs[, p, k] <- c(p == 1L && held[k], state[at])[findInterval(seq_len(n), set_event[at]) + 1L]
  }
  # A movement belongs to its event; other values persist until the next
  # event of the same channel. A gun status is unknown until its first event,
  # rather than an all-low port.
  channels <- unique(update_name)
  values <- matrix(0, n, length(channels), dimnames = list(NULL, channels))
  persistent <- !grepl("_(dx|dy|delta)$", channels)
  start <- ifelse(grepl("^openmsx_lightgunstate_.*_status$", channels), NA_real_, 0)
  for (j in seq_along(channels)) {
    at <- which(update_name == channels[j])
    if (persistent[j]) {
      values[, j] <- c(start[j], update_value[at])[findInterval(seq_len(n), update_event[at]) + 1L]
    } else {
      values[update_event[at], j] <- update_value[at]
    }
  }
  commands <- integer(n)
  for (i in which(types == "MSXCommandEvent")) {
    tokens <- xml2::xml_text(xml2::xml_find_all(nodes[[i]], "tokens/item", ns = character()))
    if (length(tokens) && tokens[1L] == "reset") commands[i] <- 1L
  }
  # Numeric channels belong to their device; autofire speeds to the machine.
  channel_owner <- match(sub("^openmsx_(.*)_(dx|dy|delta|analog|status|x|y)$", "\\1", channels), controllers)
  analog <- lapply(seq_along(controllers), function(p) values[, which(channel_owner == p), drop = FALSE])
  machine <- is.na(channel_owner)
  header <- list(
    format = "omr", emulator = "openMSX", observation_unit = "event", time_unit = "master_clock_tick",
    ticks_per_second = 3579545 * 960, replay_version = xml2::xml_attr(replay, "version"),
    machine = .omr_text(replay, "snapshots/item[1]/name"),
    initial_snapshot_time = .omr_text(replay, "snapshots/item[1]/scheduler/currentTime/time"),
    initial_keyboard = initial_values,
    controllers = controllers,
    device_identity = paste(
      "Each device of the recording is one controller, in the order of header$controllers;",
      "devices are not human players"
    )
  )
  unknown_guns <- unique(device[types == "LightGunState" &
    !device %in% c("lightgunstate_0", "lightgunstate_1")])
  if (length(unknown_guns)) {
    header$unknown_gun_devices <- unknown_guns
    warning("Unrecognised openMSX light-gun device: ", paste(unknown_guns, collapse = ", "),
      "; the raw status channel is retained",
      call. = FALSE
    )
  }
  header[["_format"]] <- "omr"
  movie <- .new_named_movie(header, commands, inputs, keys, path,
    analog = analog,
    kinds = ifelse(startsWith(keys, "openmsx_key_r"), "keyboard",
      ifelse(keys == "light_sensor" | grepl("_bit[0-9]$", keys), "peripheral", "button"))
  )
  if (any(machine)) movie$system_inputs <- as.data.frame(values[, machine, drop = FALSE])
  movie$events <- data.frame(
    timestamp_source = time_source, timestamp_ticks = ticks,
    timestamp_seconds = ticks / header$ticks_per_second, event_type = types,
    source_device = device, stringsAsFactors = FALSE
  )
  movie$events$source_xml <- vapply(nodes, as.character, character(1))
  movie
}
