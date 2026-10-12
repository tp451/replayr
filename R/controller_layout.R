# Representation layer. Decoders retain their private wire-slot numbering;
# every public reader converts that representation once, at its boundary.
.controller_registry <- function() {
  directions <- c("E", "NE", "N", "NW", "W", "SW", "S", "SE")
  keys <- c("dpad_right", "dpad_left", "dpad_down", "dpad_up", "start", "select",
            "b", "a", "x", "y", "l1", "r1", "l2", "r2", "l3", "r3",
            "c", "z", "mode", "c_right", "c_left", "c_down", "c_up",
            paste0("left_", tolower(directions)), paste0("right_", tolower(directions)),
            paste0("numbered_", 0:12), "microphone")
  data.frame(
    id = seq_along(keys), key = keys,
    mnemonic = c("R", "L", "D", "U", "T", "S", "B", "A", "x", "y", "p", "q",
                 "[", "]", "j", "k", "C", "Z", "M", ">", "<", "v", "^",
                 "e", "f", "n", "g", "w", "h", "s", "i",
                 "a", "b", "c", "d", "l", "m", "o", "r", as.character(0:9),
                 "!", "@", "#", "~"),
    name = c("Right", "Left", "Down", "Up", "Start", "Select", "B", "A", "X", "Y",
             "L1", "R1", "L2", "R2", "L3", "R3", "C", "Z", "Mode",
             "C-Right", "C-Left", "C-Down", "C-Up",
             paste0("Left stick ", directions), paste0("Right stick ", directions),
             paste("Number", 0:12), "Microphone"),
    kind = c(rep("button", 23), rep("left_direction", 8), rep("right_direction", 8),
             rep("numbered", 13), "peripheral"), stringsAsFactors = FALSE)
}

# Wire slots are private to the binary decoders, independent of registry IDs.
.legacy_control_keys <- function() {
  c("dpad_right", "dpad_left", "dpad_down", "dpad_up", "start", "select",
    "b", "a", "x", "y", "l1", "r1", "c", "z", "mode", "extra",
    "c_right", "c_left", "c_down", "c_up",
    paste0("left_", c("e", "ne", "n", "nw", "w", "sw", "s", "se")),
    "l2", "r2", paste0("keypad_", 0:9), "l3", "r3", "d", "attack", "jump",
    "gun_trigger", "offscreen_shot", "mouse_left", "mouse_middle", "mouse_right",
    "missile", "view_change", paste0("power_pad_", 1:12), "arcade_button_7",
    "jump_start", "kick", "punch", "microphone")
}

.canonical_control_keys <- function(keys) {
  aliases <- c(
    attack="a", d="y", doom_attack="a", doom_use="b", gun_trigger="a", guide="mode",
    intv_top="x", jump="b", jump_start="b", keypad_clear="select", keypad_enter="start", kick="x",
    lsnes_scope_cursor="b", lsnes_scope_pause="start", lsnes_scope_turbo="mode",
    missile="b", mouse_left="a", mouse_middle="x", mouse_right="b",
    mouse_button_4="l1", mouse_fourth="l1", mouse_button_5="r1",
    offscreen_shot="y", punch="a", view_change="select",
    wii_home="mode", wii_one="x", wii_two="y",
    ufo50_fire1="a", ufo50_fire2="b", dustforce_light="a", dustforce_jump="b",
    dustforce_heavy="x", dustforce_dash="y", dustforce_escape="start",
    stats::setNames(c("a", "b", "x", "y", "l1", "r1", "l2", "r2"), paste0("arcade_button_", 1:8)),
    stats::setNames(c("a", "b", "x", "y", "l1", "r1", "l2", "r2"), paste0("joystick_button_", 1:8)),
    stats::setNames(paste0("numbered_", 0:9), paste0("keypad_", 0:9)),
    stats::setNames(paste0("numbered_", 1:12), paste0("power_pad_", 1:12)))
  matched <- match(keys, names(aliases))
  found <- which(!is.na(matched))
  keys[found] <- unname(aliases[matched[found]])
  keys
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
#' Equivalent device buttons share registered IDs: Wii Home and libTAS Guide
#' use Mode (19), Wii 1/2 use X/Y (9/10), and light-gun triggers use A (8).
#' Arcade Attack/Punch use A, Jump and Doom Use use B, Kick uses X, and D uses Y.
#' Mouse left/right/middle use A/B/X, and buttons 4/5 use L1/R1.
#' GunCon trigger, side A, side B, and
#' offscreen shot use A/B/X/Y. Keypad Enter/Clear use Start/Select; Star/Pound
#' retain qualified source IDs. Device-qualified openMSX controls also remain
#' distinct because multiple devices can occupy the same input stream.
#' A shared ID groups comparable controller roles; game actions can differ.
#' When aliases are present, `source_inputs` retains the decoded input array and
#' `source_layout` identifies its columns and their `universal_key` mapping.
#' If several source buttons map to one ID, that column is active whenever
#' any of them is pressed.
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
#' Returns the mnemonic column of [button_layout()]. A movie's compact columns
#' use these registered mnemonics where applicable. Named source controls use
#' additional mnemonics such as `{key_space}`. Use [button_layout()] on a movie
#' to obtain its complete layout.
#' @return Character vector.
#' @export
universal_buttons <- function() .controller_registry()$mnemonic

#' Universal controller names
#' @return Character vector in stable registry order.
#' @export
#' @seealso [button_layout()]
universal_button_names <- function() .controller_registry()$name

.stick_modes <- function(analog) {
  allowed <- c("raw", "cardinal4", "cardinal8", "angle", "angle+magnitude")
  if (!is.character(analog) || !length(analog) || length(analog) > 2L ||
      anyNA(analog) || any(!analog %in% allowed)) {
    stop("analog must be raw, cardinal4, cardinal8, angle, or angle+magnitude; ",
         "supply one mode or c(left = ..., right = ...).", call. = FALSE)
  }
  if (length(analog) == 1L) return(stats::setNames(rep(unname(analog), 2L), c("left", "right")))
  if (is.null(names(analog)) || !setequal(names(analog), c("left", "right"))) {
    stop("Two analogue modes must be named left and right.", call. = FALSE)
  }
  analog[c("left", "right")]
}

.stick_deadzones <- function(deadzone, format) {
  default <- if (format %in% c("bk2", "pxm", "pjm")) 0.25 else 0.125
  if (is.null(deadzone)) return(stats::setNames(rep(default, 2L), c("left", "right")))
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
        toupper(movie$header$Platform %||% "") == "N64") slots <- setdiff(slots,21:28)
    return(slots)
  }
  format <- movie$header[["_format"]]
  width <- dim(movie$inputs)[3L]
  slots <- switch(format,
    fm2 = 1:8, fcm = 1:8,
    smv = seq_len(width), lsmv = seq_len(width),
    vbm = if (width > 8L) c(1:8, 11:12) else 1:8,
    gmv = c(1:5, 7:8, 13L, if (any(c(movie$header$p1PadType, movie$header$p2PadType) != "3")) c(9:10, 14:15)),
    m64 = c(1:5, 7:8, 11:12, 14L, 17:20),
    dtm = c(1:5, 7:12, 14L),
    pxm = c(1:12, 29:30, if (any(c(movie$header$controllerType1, movie$header$controllerType2) %in% c("5", "7")) || any(vapply(movie$analog, ncol, integer(1)) > 0L)) 41:42),
    pjm = c(1:12, 29:30, if (any(c(movie$header$controllerType1, movie$header$controllerType2) %in% c("5", "7")) || any(vapply(movie$analog, ncol, integer(1)) > 0L)) 41:42),
    lmp = 7:8,
    seq_len(width))
  slots[slots <= width]
}

.n64_override_channels <- function(movie, idx) {
  if (!is.null(movie$stick_overrides)) return(movie$stick_overrides[[idx]])
  n <- n_frames(movie)
  if (!identical(movie$header[["_format"]], "bk2") ||
      toupper(movie$header$Platform %||% "") != "N64") return(matrix(FALSE,n,0L))
  slots <- c(21L,23L,25L,27L)
  out <- matrix(FALSE,n,4L,dimnames=list(NULL,c("right","up","left","down")))
  found <- which(slots %in% movie$decoded_button_slots)
  if (length(found)) out[,found] <- movie$inputs[,idx,slots[found],drop=FALSE]
  out
}

.n64_effective_axes <- function(axes, movie, idx) {
  overrides <- .n64_override_channels(movie,idx)
  if (!ncol(overrides) || !any(overrides)) return(axes)
  text <- movie$header$emuVersion %||% ""
  version <- regmatches(text,regexpr("[0-9]+[.][0-9]+([.][0-9]+)*",text))
  if (!length(version)) return(structure(axes,unsupported="Active N64 stick overrides require a known BizHawk emuVersion."))
  # Official N64Input.cs: before 2.3 minima were -127, from 2.3 -128.
  # Left takes precedence over right, and up over down. Numeric log axes
  # remain unchanged in analog_channels(), even where a Boolean overrides them.
  minimum <- if (utils::compareVersion(version,"2.3") < 0L) -127 else -128
  axes[overrides[,"right"],1L] <- 127
  axes[overrides[,"left"],1L] <- minimum
  axes[overrides[,"down"],2L] <- minimum
  axes[overrides[,"up"],2L] <- 127
  axes
}

.stick_vectors <- function(movie, idx) {
  if (!is.null(movie$stick_calibration) || !is.null(movie$decoded_stick_vectors)) return(.calibrated_stick_vectors(movie, idx))
  raw <- analog_channels(movie, idx)
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
    platform <- tolower(paste(unlist(movie$header[intersect(names(movie$header),
                                      c("Platform", "Core", "SystemID"))]), collapse = " "))
    psx <- grepl("psx|playstation|nymashock|octoshock|psxhawk", platform)
    n64 <- grepl("n64|nintendo64|mupen", platform)
    saturn <- grepl("(^| )(sat|saturn|saturnus)( |$)", platform) &&
      all(c("stick horizontal", "stick vertical") %in% channels)
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
        axes <- .n64_effective_axes(axes,movie,idx)
        if (!is.null(attr(axes,"unsupported"))) {
          result$unsupported <- attr(axes,"unsupported")
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
.configure_movie <- function(movie, analog = "raw", deadzone = NULL, triggers = "raw") {
  if (is.null(movie$header[["_format"]])) movie$header[["_format"]] <- "fm2"
  modes <- .stick_modes(analog)
  zones <- .stick_deadzones(deadzone, movie$header[["_format"]])
  triggers <- match.arg(triggers, c("raw", "digital"))
  registry <- .controller_registry()
  if (!is.null(movie$decoded_layout)) {
    layout <- movie$decoded_layout
    old_slots <- seq_len(nrow(layout))
  } else {
    old_slots <- sort(unique(.decoded_slots(movie)))
    keys <- .legacy_control_keys()[old_slots]
    if (identical(movie$header[["_format"]], "lmp")) keys <- c("doom_use", "doom_attack")
    layout <- .control_identity_layout(keys)
  }
  canonical <- .canonical_control_keys(layout$key)
  alias <- which(canonical != layout$key)
  if (length(alias)) {
    movie$source_inputs <- movie$inputs[, , old_slots, drop = FALSE]
    movie$source_layout <- layout
    movie$source_layout$universal_key <- canonical
    layout[alias, ] <- registry[match(canonical[alias], registry$key), ]
  }
  registry <- rbind(registry, layout[!layout$id %in% registry$id, , drop = FALSE])
  matched <- match(layout$id, registry$id)
  registry$name[matched] <- layout$name
  registry$kind[matched] <- layout$kind
  old_to_new <- rep(NA, max(c(0L, old_slots)))
  old_to_new[old_slots] <- layout$id
  ids <- layout$id
  if (anyNA(ids)) stop("Invalid decoded controller identity", call. = FALSE)
  n <- n_frames(movie); np <- n_players(movie)
  numeric_values <- .empty_analog(n, np)
  direction_values <- vector("list", np)
  ready <- logical(np)
  if (all(modes == "raw")) {
    # Availability depends on channel definitions, so raw import only needs
    # a zero-row probe. Full normalized axis copies can be very large.
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
           vectors[[p]]$unsupported, ". Use analog = 'raw'.", call. = FALSE)
    }
    derived <- list(); fields <- list()
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
        all(c("ltrigger", "rtrigger") %in% colnames(analog_channels(movie, p)))) {
      raw <- analog_channels(movie, p)
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
  }
  for (p in seq_len(np)) for (derived in direction_values[[p]]) {
    positions <- match(as.integer(colnames(derived)), ids)
    existing <- matrix(inputs[, p, positions, drop = FALSE], nrow = n, ncol = length(positions))
    inputs[, p, positions] <- existing | derived
  }
  movie$stick_overrides <- lapply(seq_len(np),function(p) .n64_override_channels(movie,p))
  movie$inputs <- inputs
  selected <- registry[match(ids,registry$id),,drop=FALSE]
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
  movie$analog_mode <- if (all(modes == "raw")) "raw" else if (all(modes %in% c("cardinal4", "cardinal8"))) "cardinal" else "continuous"
  movie$trigger_mode <- triggers
  movie$layout_version <- 3L
  movie$decoded_button_slots <- NULL
  if (identical(movie$header$controllerAssignment, "unassigned")) {
    class(movie) <- "replayr_poll_stream"
  }
  movie
}

#' Selected stick directions, angles and magnitudes
#'
#' Angles are degrees counterclockwise from right: right = 0, up = 90,
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
