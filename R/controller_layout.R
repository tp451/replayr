# Representation layer. Decoders retain their private wire-slot numbering;
# every public reader converts that representation once, at its boundary.
.controller_registry <- function() {
  directions <- c("E", "NE", "N", "NW", "W", "SW", "S", "SE")
  keys <- c(
    "dpad_right", "dpad_left", "dpad_down", "dpad_up", "start", "select",
    "b", "a", "x", "y", "l1", "r1", "l2", "r2", "l3", "r3",
    "c", "z", "mode", "c_right", "c_left", "c_down", "c_up",
    paste0("left_", tolower(directions)), paste0("right_", tolower(directions)),
    paste0("numbered_", 0:12), "microphone"
  )
  data.frame(
    id = seq_along(keys), key = keys,
    mnemonic = c(
      "R", "L", "D", "U", "T", "S", "B", "A", "x", "y", "p", "q",
      "[", "]", "j", "k", "C", "Z", "M", ">", "<", "v", "^",
      "e", "f", "n", "g", "w", "h", "s", "i",
      "a", "b", "c", "d", "l", "m", "o", "r", as.character(0:9),
      "!", "@", "#", "~"
    ),
    name = c(
      "Right", "Left", "Down", "Up", "Start", "Select", "B", "A", "X", "Y",
      "L1", "R1", "L2", "R2", "L3", "R3", "C", "Z", "Mode",
      "C-Right", "C-Left", "C-Down", "C-Up",
      paste0("Left stick ", directions), paste0("Right stick ", directions),
      paste("Number", 0:12), "Microphone"
    ),
    kind = c(
      rep("button", 23), rep("left_direction", 8), rep("right_direction", 8),
      rep("numbered", 13), "peripheral"
    ), stringsAsFactors = FALSE
  )
}
# Wire slots are private to the binary decoders, independent of registry IDs.
.legacy_control_keys <- function() {
  c(
    "dpad_right", "dpad_left", "dpad_down", "dpad_up", "start", "select",
    "b", "a", "x", "y", "l1", "r1", "c", "z", "mode", "extra",
    "c_right", "c_left", "c_down", "c_up",
    paste0("left_", c("e", "ne", "n", "nw", "w", "sw", "s", "se")),
    "l2", "r2", paste0("keypad_", 0:9), "l3", "r3", "d", "attack", "jump",
    "gun_trigger", "offscreen_shot", "mouse_left", "mouse_middle", "mouse_right",
    "missile", "view_change", paste0("power_pad_", 1:12), "arcade_button_7",
    "jump_start", "kick", "punch", "microphone"
  )
}
.canonical_control_keys <- function(keys) {
  aliases <- c(
    attack = "a", d = "y", gun_trigger = "a", guide = "mode",
    intv_top = "x", jump = "b", jump_start = "b", keypad_clear = "select", keypad_enter = "start",
    keypad_pound = "start", keypad_star = "select", kick = "x",
    lsnes_scope_cursor = "b", lsnes_scope_pause = "start", lsnes_scope_turbo = "mode",
    missile = "b", mouse_left = "a", mouse_middle = "x", mouse_right = "b",
    mouse_button_4 = "l1", mouse_fourth = "l1", mouse_button_5 = "r1",
    mouse_scroll_down = "c_down", mouse_scroll_up = "c_up",
    offscreen_shot = "y", pce_mode_set_2_button = "mode", pce_mode_set_6_button = "mode",
    pcfx_mode_1 = "mode", pcfx_mode_2 = "mode",
    punch = "a", view_change = "select",
    wii_home = "mode", wii_one = "x", wii_two = "y",
    ufo50_fire1 = "a", ufo50_fire2 = "b", dustforce_escape = "start",
    # The Intellivision disc has sixteen directions and the left stick eight.
    # Each takes the nearest of the eight going clockwise from north; a
    # direction between two of them also sets the second (see below).
    intv_disc_n = "left_n", intv_disc_nne = "left_n", intv_disc_ne = "left_ne", intv_disc_ene = "left_ne",
    intv_disc_e = "left_e", intv_disc_ese = "left_e", intv_disc_se = "left_se", intv_disc_sse = "left_se",
    intv_disc_s = "left_s", intv_disc_ssw = "left_s", intv_disc_sw = "left_sw", intv_disc_wsw = "left_sw",
    intv_disc_w = "left_w", intv_disc_wnw = "left_w", intv_disc_nw = "left_nw", intv_disc_nnw = "left_nw",
    stats::setNames(c("a", "b", "x", "y", "l1", "r1", "l2", "r2"), paste0("arcade_button_", 1:8)),
    stats::setNames(c("a", "b", "x", "y", "l1", "r1", "l2", "r2"), paste0("joystick_button_", 1:8)),
    stats::setNames(paste0("numbered_", 0:9), paste0("keypad_", 0:9)),
    stats::setNames(paste0("numbered_", 1:12), paste0("power_pad_", 1:12))
  )
  matched <- match(keys, names(aliases))
  found <- which(!is.na(matched))
  keys[found] <- unname(aliases[matched[found]])
  keys
}
# A disc direction between two of the left stick's eight sets both, so that
# all sixteen stay distinguishable: NNE is N and NE together.
.second_control_keys <- function(keys) {
  between <- c(
    intv_disc_nne = "left_ne", intv_disc_ene = "left_e", intv_disc_ese = "left_se", intv_disc_sse = "left_s",
    intv_disc_ssw = "left_sw", intv_disc_wsw = "left_w", intv_disc_wnw = "left_nw", intv_disc_nnw = "left_n"
  )
  unname(between[keys])
}
#' Stable controller identities and compact movie columns
#'
#' Without a movie, returns the fixed gamepad and peripheral registry. With a movie, returns only
#' its controller's columns, in matrix order. `column` is a local matrix index;
#' `id` and `key` identify the same control across recordings. Unpressed controls
#' supported by the controller are retained. Matrices omit registry entries
#' outside that controller's layout.
#' The registry contains 53 consecutive IDs. Keypad digits and equally numbered
#' Power Pad sensors share `numbered_0` through `numbered_12` (IDs 40-52),
#' with kind `numbered`. Microphone is ID 53. Serial positions in a BK2 LogKey
#' are decoded independently of those sensor numbers.
#'
#' Additional named controls, such as keyboard keys, have character IDs of the
#' form `control:<key>`. These are stable within their source key namespace.
#' They appear in the movie's layout without expanding unrelated controllers.
#'
#' @section Which controls share an ID:
#' The same rules apply in every reader, so a console has the same IDs
#' whichever emulator recorded it. `name` shows the label on the device;
#' `key` and `id` are the shared identity. A column that holds several
#' controls of a recording shows their labels joined by a slash, and no two
#' columns of a layout share a name.
#' \itemize{
#'   \item \strong{By label.} A button that carries one of the registry's
#'     letters or words (A, B, C, X, Y, Z, L, R, Start, Select, Mode) has
#'     that ID. The ID follows the letter, not the place on the pad: A is the
#'     right-hand button of a Nintendo pad, the left one of a Genesis pad,
#'     and the lower one of an Xbox-style pad, which is what a libTAS
#'     recording of an SDL game controller holds.
#'   \item \strong{By place, for PlayStation pads.} Their buttons carry shapes.
#'     They have the IDs of the SNES buttons in the same places: Cross is B,
#'     Circle is A, Triangle is X and Square is Y.
#'   \item \strong{In order, for numbered buttons.} The first is A, then B, X,
#'     Y, L1, R1, L2 and R2. This covers arcade and joystick buttons, Master
#'     System 1 and 2, and PC Engine I to VI. The Neo Geo's row of A, B, C
#'     and D is read the same way, so its C and D are X and Y. A device's
#'     only fire button or trigger is A.
#'   \item \strong{By role, for the rest.} The button that starts or pauses
#'     play is Start (PC Engine Run, the Lynx's Pause, the Neo Geo Pocket's
#'     Option, keypad Enter, Wii Plus); keypad Clear, Wii Minus, the Lynx's
#'     Option 1 and an arcade View Change are Select; Wii Home, libTAS
#'     Guide, the Lynx's Option 2 and the PC Engine's switch between two and
#'     six buttons are Mode (19); Wii 1 and 2 are X and Y.
#'     Mouse left, right and middle are A, B and X, and buttons 4 and 5 are
#'     L1 and R1. A light-gun trigger is A; GunCon side A, side B and
#'     offscreen shot are B, X and Y.
#' }
#'
#' Arcade buttons that BizHawk shows under the name a cabinet gives them
#' follow one table for the whole platform: Attack and Punch are A, Jump and
#' Missile are B, Kick is X.
#'
#' Of two direction pads, the left one is the direction pad (IDs 1-4) and
#' the right one has the IDs of the N64's C-buttons (20-23): the Virtual
#' Boy's pads and the WonderSwan's X and Y crosses. An arcade cabinet's two
#' joysticks have the direction IDs of the left and the right analogue
#' stick (N, E, S and W of 24-31 and of 32-39). Controls without a
#' counterpart keep IDs of their own; these are keyboard keys, in the code
#' set of their source. The Intellivision disc has the direction IDs of
#' the left stick: one for each of its eight main directions, and the two
#' neighbours together for a direction between them, such as N and NE for
#' NNE. A disc that a core logs as two axes has the directions the console
#' reads from them. Keypad Star and Pound are Select and Start, like Clear and Enter in
#' the same places. On the Channel F stick, forward and back are Up and
#' Down, the twist is L1 and R1, pushing down is A and pulling up is B. A
#' mouse wheel turned up or down is C-Up or C-Down. A touch on a screen or
#' pad is L3, the press of a pointing input.
#' Each device of an openMSX recording is a controller of its own, with the
#' IDs of its kind. Buttons on the console itself,
#' such as Reset, the Master System's Pause or the lid of a DS, are not part
#' of a pad; they are returned by [system_channels()].
#'
#' A shared ID says that two buttons are the same control, not that they do
#' the same thing: what a button does depends on the game. Some recordings
#' store what the game was asked to do, not which button was pressed: a Doom
#' demo holds attack, use and jump, whatever keys or buttons the player had
#' bound to them. These game actions are kept apart from device buttons.
#' They have kind `action` and IDs of the form `action:<name>`, shared by
#' every game that records the same action.
#'
#' @section Several source controls under one ID:
#' When the rules place several source controls of one recording under one
#' ID, `source_inputs` retains the decoded input array and `source_layout`
#' identifies its columns and their `universal_key` mapping. That column is
#' active whenever any of them is pressed. Reading with `aliases = FALSE`
#' keeps every control of the recording in a column of its own instead: a
#' control that would be placed under another control's ID keeps the key of
#' its source and an ID of the form `control:<key>`.
#'
#' @details
#' Registered controls use fixed numeric IDs; a mixed layout represents all
#' IDs as character strings. Use keys or IDs for matching, rather than coercing
#' the complete ID column to integers. Source keyboard code sets remain distinct.
#' @param movie An imported recording, or `NULL` for the fixed registry.
#' @return Data frame with column, id, key, mnemonic, name and kind.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.m64", package = "replayr")
#' button_layout(read_movie(path))
button_layout <- function(movie = NULL) {
  registry <- .controller_registry()
  if (is.null(movie)) return(cbind(column = seq_len(nrow(registry)), registry))
  stopifnot(.is_recording(movie))
  if (!identical(movie$layout_version, 3L) || is.null(movie$button_ids)) {
    stop("This movie uses an older layout; re-read its recording.", call. = FALSE)
  }
  result <- if (!is.null(movie$control_layout)) movie$control_layout else
    registry[match(movie$button_ids, registry$id), , drop = FALSE]
  result$name <- movie$button_names
  rownames(result) <- NULL
  cbind(column = seq_len(nrow(result)), result)
}
#' Universal controller mnemonics
#'
#' Returns the mnemonic column of [button_layout()]: one character for each
#' registered control, for writing a controller state as compact text. Controls
#' outside the registry have mnemonics such as `{key_space}`. The accessors
#' name their columns by key, not by mnemonic; use [button_layout()] on a movie
#' to obtain its complete layout.
#' @return Character vector.
#' @export
#' @examples
#' head(universal_buttons(), 12)
#' # A controller state as text: Right, B and A held.
#' layout <- button_layout()
#' paste(layout$mnemonic[match(c("dpad_right", "b", "a"), layout$key)], collapse = "")
universal_buttons <- function() .controller_registry()$mnemonic
#' Universal controller names
#' @return Character vector in stable registry order.
#' @export
#' @seealso [button_layout()]
#' @examples
#' head(universal_button_names(), 12)
#' # The registry, with the ID and key of each name.
#' head(button_layout()[, c("id", "key", "name")], 12)
universal_button_names <- function() .controller_registry()$name
.stick_modes <- function(analog) {
  allowed <- c("raw", "cardinal4", "cardinal8", "angle", "angle+magnitude")
  if (!is.character(analog) || !length(analog) || length(analog) > 2L ||
    anyNA(analog) || any(!analog %in% allowed)) {
    stop("analog must be raw, cardinal4, cardinal8, angle, or angle+magnitude; ",
      "supply one mode or c(left = ..., right = ...).",
      call. = FALSE
    )
  }
  if (length(analog) == 1L) return(stats::setNames(rep(unname(analog), 2L), c("left", "right")))
  if (is.null(names(analog)) || !setequal(names(analog), c("left", "right"))) {
    stop("Two analogue modes must be named left and right.", call. = FALSE)
  }
  analog[c("left", "right")]
}
# Without a value the threshold follows the controller, whichever emulator
# recorded it. The sticks of Nintendo's consoles have a small central region:
# the controller library of the GameCube discards 15 of 128 units on each
# axis (PAD_Clamp in libogc's pad.c). Other sticks get a quarter: a released
# PlayStation stick rests up to about 32 of 128 units from the centre
# (psx-spx, "Analog Joypad Range"), and Microsoft gives 7849 and 8689 of
# 32767 for the two thumbsticks of a PC gamepad (XInput).
.default_deadzone <- function(movie) {
  format <- movie$header[["_format"]]
  platform <- .recording_platform(movie)$platform
  nintendo <- format %in% c("m64", "gzm", "dtm", "ctm") || platform %in% c("N64", "GC", "Wii", "3DS")
  if (nintendo) 0.125 else 0.25
}
.stick_deadzones <- function(deadzone, movie) {
  if (is.null(deadzone)) return(stats::setNames(rep(.default_deadzone(movie), 2L), c("left", "right")))
  if (!is.numeric(deadzone) || !length(deadzone) || length(deadzone) > 2L ||
    anyNA(deadzone) || any(!is.finite(deadzone) | deadzone < 0 | deadzone > 1)) {
    stop("deadzone must be one value in [0, 1], or named left/right values.", call. = FALSE)
  }
  if (length(deadzone) == 1L) return(stats::setNames(rep(unname(deadzone), 2L), c("left", "right")))
  if (is.null(names(deadzone)) || !setequal(names(deadzone), c("left", "right"))) {
    stop("Two deadzones must be named left and right.", call. = FALSE)
  }
  deadzone[c("left", "right")]
}
# Explicit controller capabilities, rather than columns observed as active.
.decoded_slots <- function(movie) {
  if (!is.null(movie$decoded_button_slots)) {
    slots <- movie$decoded_button_slots
    if (identical(movie$header[["_format"]], "bk2") &&
      toupper(movie$header$Platform %||% "") == "N64") slots <- setdiff(slots, 21:28)
    return(slots)
  }
  format <- movie$header[["_format"]]
  width <- dim(movie$inputs)[3L]
  slots <- switch(format,
    fm2 = 1:8,
    fcm = 1:8,
    smv = seq_len(width),
    lsmv = seq_len(width),
    vbm = if (width > 8L) c(1:8, 11:12) else 1:8,
    gmv = c(1:5, 7:8, 13L, if (any(c(movie$header$p1PadType, movie$header$p2PadType) != "3")) c(9:10, 14:15)),
    m64 = c(1:5, 7:8, 11:12, 14L, 17:20),
    dtm = c(1:5, 7:12, 14L),
    pxm = c(
      1:12, 29:30,
      if (any(c(movie$header$controllerType1, movie$header$controllerType2) %in% c("5", "7")) ||
        any(vapply(movie$analog, ncol, integer(1)) > 0L)) 41:42
    ),
    pjm = c(
      1:12, 29:30,
      if (any(c(movie$header$controllerType1, movie$header$controllerType2) %in% c("5", "7")) ||
        any(vapply(movie$analog, ncol, integer(1)) > 0L)) 41:42
    ),
    lmp = 7:9,
    seq_len(width)
  )
  slots[slots <= width]
}
# MAME records the raw value of an analogue joystick. Its centre and range
# differ from cabinet to cabinet and are not in the file, so both are
# estimated from the recording: the middle and half the span of the values
# on the joystick axes of that controller. The estimate is exact when the
# recording reaches both ends of an axis. A smaller Y value is up, as in
# MAME's default key assignment.
.arcade_stick_vectors <- function(movie, raw, roles) {
  result <- list()
  sides <- list(left = match(c("lstick_x", "lstick_y"), roles), right = match(c("rstick_x", "rstick_y"), roles))
  sides <- sides[!vapply(sides, anyNA, logical(1))]
  if (!length(sides)) return(result)
  if (!nrow(raw)) {
    for (side in names(sides)) result[[side]] <- matrix(numeric(), 0L, 2L, dimnames = list(NULL, c("x", "y")))
    return(result)
  }
  if (!is.null(movie$header$firstObservation)) {
    result$unsupported <- "an arcade joystick in a chunk (its centre and range are estimated from the whole recording)"
    return(result)
  }
  span <- range(raw[, unlist(sides)], na.rm = TRUE)
  center <- mean(span)
  reach <- diff(span) / 2
  warning(
    if (!is.na(movie$source_path %||% NA)) paste0(basename(movie$source_path), ": "),
    "the recording does not hold the centre and range of its arcade joystick; ",
    "estimated from its values as centre ", format(center), " and reach ", format(reach),
    ". Directions and magnitudes rest on that estimate.",
    call. = FALSE
  )
  if (reach == 0) reach <- 1
  for (side in names(sides)) {
    axes <- (raw[, sides[[side]], drop = FALSE] - center) / reach
    axes[, 2L] <- -axes[, 2L]
    colnames(axes) <- c("x", "y")
    result[[side]] <- axes
  }
  result
}
.n64_override_channels <- function(movie, idx) {
  if (!is.null(movie$stick_overrides)) return(movie$stick_overrides[[idx]])
  n <- n_observations(movie)
  if (!identical(movie$header[["_format"]], "bk2") ||
    toupper(movie$header$Platform %||% "") != "N64") return(matrix(FALSE, n, 0L))
  slots <- c(21L, 23L, 25L, 27L)
  out <- matrix(FALSE, n, 4L, dimnames = list(NULL, c("right", "up", "left", "down")))
  found <- which(slots %in% movie$decoded_button_slots)
  if (length(found)) out[, found] <- movie$inputs[, idx, slots[found], drop = FALSE]
  out
}
.n64_effective_axes <- function(axes, movie, idx) {
  overrides <- .n64_override_channels(movie, idx)
  if (!ncol(overrides) || !any(overrides)) return(axes)
  text <- movie$header$emuVersion %||% ""
  version <- regmatches(text, regexpr("[0-9]+[.][0-9]+([.][0-9]+)*", text))
  if (!length(version))
    return(structure(axes, unsupported = "Active N64 stick overrides require a known BizHawk emuVersion."))
  # Official N64Input.cs: before 2.3 minima were -127, from 2.3 -128.
  # Left takes precedence over right, and up over down. Numeric log axes
  # remain unchanged in analog_channels(), even where a Boolean overrides them.
  minimum <- if (utils::compareVersion(version, "2.3") < 0L) -127 else -128
  axes[overrides[, "right"], 1L] <- 127
  axes[overrides[, "left"], 1L] <- minimum
  axes[overrides[, "down"], 2L] <- minimum
  axes[overrides[, "up"], 2L] <- 127
  axes
}
.stick_vectors <- function(movie, idx) {
  if (!is.null(movie$stick_calibration) || !is.null(movie$decoded_stick_vectors))
    return(.calibrated_stick_vectors(movie, idx))
  raw <- .source_channels(movie, idx)
  format <- movie$header[["_format"]]
  result <- list()
  if (!ncol(raw) || !format %in% c("m64", "dtm", "pxm", "pjm", "bk2")) return(result)
  if (format == "bk2") {
    if (idx %in% movie$header$bk2NonStickPlayers) return(result)
    channels <- tolower(sub("^P[0-9]+ +", "", colnames(raw), ignore.case = TRUE))
    roles <- vapply(channels, function(name) {
      if (grepl("disc|paddle|mouse|sensor|tilt|gyro", name)) return(NA_character_)
      role <- .classify_analog_pair(name)
      if (is.null(role)) NA_character_ else role
    }, character(1))
    platform <- tolower(paste(unlist(movie$header[intersect(
      names(movie$header),
      c("Platform", "Core", "SystemID")
    )]), collapse = " "))
    psx <- grepl("psx|playstation|nymashock|octoshock|psxhawk", platform)
    n64 <- grepl("n64|nintendo64|mupen", platform)
    saturn <- grepl("(^| )(sat|saturn|saturnus)( |$)", platform) &&
      all(c("stick horizontal", "stick vertical") %in% channels)
    if (grepl("arcade", platform) && any(!is.na(roles))) return(.arcade_stick_vectors(movie, raw, roles))
    if (!psx && !n64 && !saturn && any(!is.na(roles))) {
      result$unsupported <- platform
      return(result)
    }
    old16 <- psx && grepl("nymashock", platform) &&
      grepl("(^|[^0-9])2\\.8([. ]|$)", movie$header$emuVersion %||% "")
    # SaturnusControllerDeck (BizHawk 2.2.1) declares 0..255, neutral 128.
    # SatSchema/AnalogStickPanel maps larger Y values down the screen.
    center <- if (old16) 32768 else if (psx || saturn) 128 else 0
    scale <- if (old16) 32768 else 128
    for (side in c("left", "right")) {
      prefix <- if (side == "left") "lstick" else "rstick"
      positions <- match(paste0(prefix, c("_x", "_y")), roles)
      if (anyNA(positions)) next
      axes <- raw[, positions, drop = FALSE]
      if ((psx && grepl("octoshock", platform)) || saturn) axes <- axes %% 256
      if (n64) axes[axes > 127 & axes <= 255] <- axes[axes > 127 & axes <= 255] - 256
      if (n64) {
        axes <- .n64_effective_axes(axes, movie, idx)
        if (!is.null(attr(axes, "unsupported"))) {
          result$unsupported <- attr(axes, "unsupported")
          return(result)
        }
      }
      axes <- (axes - center) / scale
      if (psx || saturn) axes[, 2L] <- -axes[, 2L]
      colnames(axes) <- c("x", "y")
      result[[side]] <- axes
    }
    return(result)
  }
  for (side in c("left", "right")) {
    prefix <- if (side == "left") "lstick" else "rstick"
    positions <- match(paste0(prefix, c("_x", "_y")), colnames(raw))
    if (anyNA(positions)) next
    axes <- raw[, positions, drop = FALSE]
    if (format != "m64") axes <- axes - 128
    axes <- axes / 128
    if (format %in% c("pxm", "pjm")) axes[, 2L] <- -axes[, 2L]
    colnames(axes) <- c("x", "y")
    result[[side]] <- axes
  }
  result
}
# The registry does not depend on frame content, so silent or short recordings
# have the same columns as active recordings of that controller type.
.configure_movie <- function(movie, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE) {
  if (!is.logical(aliases) || length(aliases) != 1L || is.na(aliases))
    stop("aliases must be TRUE or FALSE", call. = FALSE)
  if (is.null(movie$header[["_format"]])) movie$header[["_format"]] <- "fm2"
  modes <- .stick_modes(analog)
  zones <- .stick_deadzones(deadzone, movie)
  triggers <- match.arg(triggers, c("raw", "digital"))
  registry <- .controller_registry()
  if (!is.null(movie$decoded_layout)) {
    layout <- movie$decoded_layout
    old_slots <- seq_len(nrow(layout))
  } else {
    old_slots <- sort(unique(.decoded_slots(movie)))
    layout <- if (identical(movie$header[["_format"]], "lmp")) {
      .action_layout(c("attack", "use", "jump")[seq_along(old_slots)])
    } else {
      .control_identity_layout(.legacy_control_keys()[old_slots])
    }
    # PlayStation pads carry shapes, not letters. Their columns keep the shape
    # as name, under the identity of the SNES button in the same place.
    if (movie$header[["_format"]] %in% c("pxm", "pjm")) {
      shapes <- c(b = "Cross", a = "Circle", x = "Triangle", y = "Square")
      found <- match(names(shapes), layout$key)
      layout$name[found[!is.na(found)]] <- shapes[!is.na(found)]
    }
  }
  # Without aliases every decoded control keeps the key of its source.
  canonical <- if (aliases) .canonical_control_keys(layout$key) else layout$key
  second <- if (aliases) .second_control_keys(layout$key) else rep(NA_character_, nrow(layout))
  alias <- which(canonical != layout$key)
  # The labels of the device's controls, one for each decoded control.
  labels <- layout$name
  if (length(alias)) {
    movie$source_inputs <- movie$inputs[, , old_slots, drop = FALSE]
    movie$source_layout <- layout
    movie$source_layout$universal_key <- canonical
    if (any(!is.na(second))) movie$source_layout$second_key <- second
    layout[alias, ] <- registry[match(canonical[alias], registry$key), ]
  }
  registry <- rbind(registry, layout[!layout$id %in% registry$id, , drop = FALSE])
  matched <- match(layout$id, registry$id)
  registry$kind[matched] <- layout$kind
  old_to_new <- rep(NA, max(c(0L, old_slots)))
  old_to_new[old_slots] <- layout$id
  ids <- layout$id
  if (anyNA(ids)) stop("Invalid decoded controller identity", call. = FALSE)
  second_ids <- registry$id[match(second, registry$key)]
  ids <- union(ids, second_ids[!is.na(second_ids)])
  # A column is named after the control of the device that it holds; where it
  # holds several, their labels are joined.
  for (id in unique(ids)) {
    held <- which(layout$id == id | (!is.na(second_ids) & second_ids == id))
    registry$name[match(id, registry$id)] <- paste(unique(labels[held]), collapse = " / ")
  }
  n <- n_observations(movie)
  np <- n_players(movie)
  numeric_values <- .empty_analog(n, np)
  direction_values <- vector("list", np)
  ready <- logical(np)
  if (all(modes == "raw")) {
    # Availability depends on channel definitions, so raw import only needs
    # a zero-row probe. Full normalised axis copies can be very large.
    probe <- movie
    probe$inputs <- movie$inputs[integer(), , , drop = FALSE]
    probe$analog <- lapply(movie$analog, function(x) x[integer(), , drop = FALSE])
    if (!is.null(movie$decoded_stick_vectors))
      probe$decoded_stick_vectors <- lapply(movie$decoded_stick_vectors, function(player)
        lapply(player, function(x) x[integer(), , drop = FALSE]))
    if (!is.null(movie$stick_overrides))
      probe$stick_overrides <- lapply(movie$stick_overrides, function(x) x[integer(), , drop = FALSE])
    vectors <- lapply(seq_len(np), function(p) .stick_vectors(probe, p))
  } else {
    vectors <- lapply(seq_len(np), function(p) .stick_vectors(movie, p))
  }
  for (p in seq_len(np)) {
    if (!is.null(vectors[[p]]$unsupported) && any(modes != "raw")) {
      stop("No stick calibration is defined for this BK2 controller: ",
        vectors[[p]]$unsupported, ". Use analog = 'raw'.",
        call. = FALSE
      )
    }
    derived <- list()
    fields <- list()
    present <- intersect(names(vectors[[p]]), c("left", "right"))
    ready[p] <- length(present) > 0L && all(modes[present] %in% c("cardinal4", "cardinal8"))
    for (side in present) {
      axes <- vectors[[p]][[side]]
      mode <- modes[[side]]
      if (mode == "raw") next
      magnitude <- sqrt(rowSums(axes * axes))
      angle <- (atan2(axes[, 2L], axes[, 1L]) * 180 / pi) %% 360
      active <- !is.na(magnitude) & magnitude > 0 & magnitude >= zones[[side]]
      angle[!active] <- NA_real_
      if (anyNA(axes)) ready[p] <- FALSE
      if (mode %in% c("angle", "angle+magnitude")) {
        fields[[paste0(side, "_angle")]] <- angle
        if (mode == "angle+magnitude") fields[[paste0(side, "_magnitude")]] <- magnitude
      } else {
        count <- if (mode == "cardinal4") 4L else 8L
        width <- 360 / count
        sector <- floor((angle + width / 2) / width) %% count
        fields[[paste0(side, "_direction")]] <- sector * width
        offset <- if (side == "left") 24L else 32L
        side_ids <- offset + if (count == 4L) c(0L, 2L, 4L, 6L) else 0:7
        ids <- union(ids, side_ids)
        directions <- matrix(FALSE, n, count, dimnames = list(NULL, as.character(side_ids)))
        on <- which(active)
        if (length(on)) directions[cbind(on, as.integer(sector[on]) + 1L)] <- TRUE
        derived[[side]] <- directions
      }
    }
    if (length(fields)) numeric_values[[p]] <- do.call(cbind, fields)
    if (triggers == "digital" && identical(movie$header[["_format"]], "dtm") &&
      all(c("ltrigger", "rtrigger") %in% colnames(.source_channels(movie, p)))) {
      raw <- .source_channels(movie, p)
      trigger_values <- raw[, c("ltrigger", "rtrigger"), drop = FALSE] >= 128
      trigger_values[is.na(trigger_values)] <- FALSE
      colnames(trigger_values) <- c("13", "14")
      derived$triggers <- trigger_values
      ids <- union(ids, 13:14)
    }
    direction_values[[p]] <- derived
  }
  ids <- registry$id[registry$id %in% ids]
  inputs <- array(FALSE, c(n, np, length(ids)))
  if (length(old_slots)) {
    positions <- match(old_to_new[old_slots], ids)
    for (p in seq_len(np)) for (j in seq_along(old_slots))
      inputs[, p, positions[j]] <- inputs[, p, positions[j]] | movie$inputs[, p, old_slots[j]]
    also <- match(second_ids, ids)
    for (p in seq_len(np)) for (j in which(!is.na(also)))
      inputs[, p, also[j]] <- inputs[, p, also[j]] | movie$inputs[, p, old_slots[j]]
  }
  for (p in seq_len(np)) for (derived in direction_values[[p]]) {
    positions <- match(as.integer(colnames(derived)), ids)
    existing <- matrix(inputs[, p, positions, drop = FALSE], nrow = n, ncol = length(positions))
    inputs[, p, positions] <- existing | derived
  }
  movie$stick_overrides <- lapply(seq_len(np), function(p) .n64_override_channels(movie, p))
  movie$inputs <- inputs
  selected <- registry[match(ids, registry$id), , drop = FALSE]
  # No two columns share a name. Where two controls of a device carry the same
  # label, each is told apart by the name of its shared control.
  repeated <- selected$name %in% selected$name[duplicated(selected$name)]
  if (any(repeated)) {
    shared <- .controller_registry()
    usual <- shared$name[match(selected$key[repeated], shared$key)]
    usual[is.na(usual)] <- selected$key[repeated][is.na(usual)]
    selected$name[repeated] <- paste0(selected$name[repeated], " (", usual, ")")
  }
  movie$button_ids <- ids
  movie$button_keys <- selected$key
  movie$button_mnemonics <- selected$mnemonic
  movie$button_names <- selected$name
  movie$control_layout <- selected
  movie$decoded_layout <- NULL
  movie$stick_values <- numeric_values
  movie$stick_modes <- modes
  movie$stick_deadzone <- zones
  movie$stick_available <- lapply(vectors, function(x) intersect(names(x), c("left", "right")))
  movie$analysis_ready <- ready
  movie$analog_mode <- if (all(modes == "raw")) {
    "raw"
  } else if (all(modes %in% c("cardinal4", "cardinal8"))) {
    "cardinal"
  } else {
    "continuous"
  }
  movie$trigger_mode <- triggers
  movie$layout_version <- 3L
  movie$decoded_button_slots <- NULL
  movie <- .name_system(.name_channels(movie))
  if (identical(movie$header$controllerAssignment, "unassigned")) {
    class(movie) <- "replayr_poll_stream"
  }
  movie
}
#' Selected stick directions, angles and magnitudes
#'
#' Angles are degrees anticlockwise from right: right = 0, up = 90,
#' left = 180, down = 270. Neutral angles and missing observations are `NA`.
#' Cardinal columns contain the nearest direction's centre angle. Magnitude
#' is Euclidean length after dividing each centred source axis by its declared
#' half-range; diagonal magnitudes can exceed one. It is not a calibrated force
#' measurement. `angle` excludes magnitude; `angle+magnitude` includes it.
#' Raw source X/Y values remain in [analog_channels()] for every mode.
#' The Saturn BK2 3D-pad fields `Stick Horizontal` and `Stick Vertical`
#' use unsigned byte axes centred at 128, with smaller vertical values up.
#' Analogue shoulder values remain separate source channels.
#'
#' @inheritParams analog_channels
#' @return Numeric matrix with selected fields. Absent sticks have no columns.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.m64", package = "replayr")
#' movie <- read_movie(path, analog = "angle+magnitude")
#' head(stick_channels(movie))
stick_channels <- function(movie, idx = 1L) {
  analog_channels(movie, idx) # validate player index
  if (is.null(movie$stick_values)) {
    stop("This movie uses an older representation; re-read its recording.", call. = FALSE)
  }
  movie$stick_values[[as.integer(idx)]]
}
`%||%` <- function(x, y) if (is.null(x)) y else x
