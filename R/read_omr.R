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
.omr_number <- function(node, name, default = 0) {
  .computer_number(.omr_text(node, name, as.character(default)), paste("openMSX", name))
}
.OMR_DEVICE_TYPES <- c(
  "KeyJoyState", "MSXJoyState", "JoyMegaState", "JoyHandleState", "MouseState",
  "TrackballState", "ArkanoidState", "PaddleState", "TouchpadState", "LightGunState"
)
.omr_device <- function(node, type) {
  if (type == "KeyMatrixState") return("keyboard")
  if (type == "KeyJoyState") return(.omr_text(node, "name", "keyjoystick"))
  if (type %in% c("MSXJoyState", "JoyMegaState", "JoyHandleState", "LightGunState"))
    return(paste0(tolower(type), "_", .omr_text(node, "id", "0")))
  tolower(sub("State$", "", type))
}
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
  time_source <- vapply(nodes, .omr_text, character(1), name = "StateChange/time/time")
  ticks <- .computer_number(time_source, "openMSX timestamp", 0, 2^53)
  if (any(diff(ticks) < 0)) stop("Unordered openMSX events", call. = FALSE)
  device <- vapply(seq_len(n), function(i) .omr_device(nodes[[i]], types[i]), character(1))
  bitwise <- c("KeyMatrixState", "KeyJoyState", "MSXJoyState", "JoyMegaState", "JoyHandleState", "MouseState",
    "TrackballState")
  keysets <- vector("list", n)
  releases <- presses <- vector("list", n)
  analog_updates <- vector("list", n)
  for (i in seq_len(n)) {
    node <- nodes[[i]]
    type <- types[i]
    dev <- device[i]
    if (type == "KeyMatrixState") {
      row <- .omr_number(node, "row")
      if (row < 0 || row > 15) stop("Invalid openMSX keyboard matrix row", call. = FALSE)
      keysets[[i]] <- paste0("openmsx_key_r", row, "_b", 0:7)
    } else if (type %in% .OMR_DEVICE_TYPES) {
      controls <- .omr_controls(type, dev)
      if (type %in% bitwise) {
        # Every bit of the masks is kept; one without a control has its own key.
        controls <- c(controls, rep(NA, max(0L, 8L - length(controls))))
        blank <- is.na(controls)
        controls[blank] <- paste0("openmsx_", dev, "_bit", which(blank) - 1L)
      }
      keysets[[i]] <- controls
    }
    if (length(keysets[[i]])) {
      if (type %in% bitwise) {
        press <- .omr_number(node, "press")
        release <- .omr_number(node, "release")
        presses[[i]] <- bitwAnd(as.integer(press), bitwShiftL(1L, seq_along(keysets[[i]]) - 1L)) != 0
        releases[[i]] <- bitwAnd(as.integer(release), bitwShiftL(1L, seq_along(keysets[[i]]) - 1L)) != 0
      } else if (type == "ArkanoidState") {
        presses[[i]] <- .omr_text(node, "press") %in% c("true", "1")
        releases[[i]] <- .omr_text(node, "release") %in% c("true", "1")
      } else if (type == "TouchpadState") {
        presses[[i]] <- c(.omr_text(node, "touch"), .omr_text(node, "button")) %in% c("true", "1")
        releases[[i]] <- !presses[[i]]
      } else if (type == "LightGunState") {
        # Gunstick and Terminator Laser use different pins and light polarity.
        # openMSX f07bee985b8e2102c47913c217ad0365638bf8ae:
        # Gunstick.cc, TerminatorLaser.cc, and JoystickDevice.hh.
        status <- .computer_number(.omr_text(node, "status"), "openMSX gun status", 0, 255)
        presses[[i]] <- if (dev == "lightgunstate_0")
          c(bitwAnd(as.integer(status), 16L) == 0L, bitwAnd(as.integer(status), 2L) == 0L)
        else c(bitwAnd(as.integer(status), 32L) == 0L, bitwAnd(as.integer(status), 16L) != 0L)
        releases[[i]] <- !presses[[i]]
      }
    }
    if (type %in% c("MouseState", "TrackballState")) {
      analog_updates[[i]] <- stats::setNames(
        c(.omr_number(node, "deltaX"), .omr_number(node, "deltaY")), paste0("openmsx_", dev, c("_dx", "_dy"))
      )
    } else if (type %in% c("ArkanoidState", "PaddleState")) {
      analog_updates[[i]] <- stats::setNames(.omr_number(node, "delta"), paste0("openmsx_", dev, "_delta"))
    } else if (type == "TouchpadState") {
      analog_updates[[i]] <- c(openmsx_touchpad_x = .omr_number(node, "x"), openmsx_touchpad_y = .omr_number(node, "y"))
    } else if (type == "JoyHandleState") {
      analog_updates[[i]] <- stats::setNames(as.numeric(.omr_text(node, "analog")), paste0("openmsx_", dev, "_analog"))
    } else if (type == "LightGunState") {
      analog_updates[[i]] <- stats::setNames(
        .computer_number(.omr_text(node, "status"), "openMSX gun status", 0, 255), paste0("openmsx_", dev, "_status")
      )
    } else if (type == "AutofireStateChange") {
      analog_updates[[i]] <- stats::setNames(
        .omr_number(node, "value"), paste0("openmsx_autofire_", .omr_text(node, "name", "unknown"))
      )
    }
  }
  # The keyboard is the first controller; each other device follows by name.
  on_device <- types %in% .OMR_DEVICE_TYPES
  controllers <- c("keyboard", sort(unique(device[on_device])))
  owner <- match(ifelse(types == "KeyMatrixState" | on_device, device, NA), controllers)
  # Only keyboard keys exercised by this recording are included; source matrix
  # positions are retained because MSX, SVI, and Coleco keyboard layouts
  # differ. A device keeps all its controls, pressed or not.
  keyboard <- types == "KeyMatrixState"
  active_keys <- unlist(lapply(which(keyboard), function(i) keysets[[i]][presses[[i]] | releases[[i]]]),
    use.names = FALSE)
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
  device_keys <- unique(unlist(lapply(which(on_device), function(i) {
    spare <- grepl("_bit[0-9]$", keysets[[i]])
    keysets[[i]][!spare | presses[[i]] | releases[[i]]]
  }), use.names = FALSE))
  order <- c(
    "dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "b", "c", "start", "x", "y", "z", "mode",
    "mouse_left", "mouse_right", "l3", "gun_trigger", "light_sensor"
  )
  device_keys <- c(intersect(order, device_keys), sort(setdiff(device_keys, order)))
  keys <- c(keyboard_keys, device_keys)
  inputs <- array(FALSE, c(n, length(controllers), length(keys)))
  held <- matrix(FALSE, length(controllers), length(keys))
  held[1L, keys %in% initial_keys & seq_along(keys) <= length(keyboard_keys)] <- TRUE
  channels <- unique(unlist(lapply(analog_updates, names), use.names = FALSE))
  values <- matrix(0, n, length(channels), dimnames = list(NULL, channels))
  persistent <- !grepl("_(dx|dy|delta)$", channels)
  state <- numeric(length(channels))
  commands <- integer(n)
  # A gun status is unknown until its first event, rather than an all-low port.
  state[grepl("^openmsx_lightgunstate_.*_status$", channels)] <- NA_real_
  for (i in seq_len(n)) {
    ks <- keysets[[i]]
    if (length(ks)) {
      # Keyboard keys and device controls are looked up in their own part.
      part <- if (keyboard[i]) seq_along(keyboard_keys) else length(keyboard_keys) + seq_along(device_keys)
      at <- part[match(ks, keys[part])]
      have <- !is.na(at)
      held[owner[i], at[have & presses[[i]]]] <- TRUE
      held[owner[i], at[have & releases[[i]]]] <- FALSE
    }
    inputs[i, , ] <- held
    state[!persistent] <- 0
    update <- analog_updates[[i]]
    if (length(update)) state[match(names(update), channels)] <- update
    values[i, ] <- state
    if (types[i] == "MSXCommandEvent") {
      tokens <- xml2::xml_text(xml2::xml_find_all(nodes[[i]], "tokens/item", ns = character()))
      if (length(tokens) && tokens[1L] == "reset") commands[i] <- 1L
    }
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
