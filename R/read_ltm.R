# libTAS native archive. Format and semantics are defined by:
# https://tasvideos.org/EmulatorResources/LibTAS/LTMFormat
# https://github.com/clementgallet/libTAS/blob/master/src/program/movie/InputSerialization.cpp
# https://github.com/clementgallet/libTAS/blob/master/src/shared/inputs/SingleInput.h
.ltm_controller_keys <- c(
  "a", "b", "x", "y", "select", "guide", "start", "l3", "r3",
  "l1", "r1", "dpad_up", "dpad_down", "dpad_left", "dpad_right"
)
.ltm_axis_names <- c("left_x", "left_y", "right_x", "right_y", "trigger_left", "trigger_right")
.ltm_mouse_keys <- c("mouse_left", "mouse_middle", "mouse_right", "mouse_button_4", "mouse_button_5")
.ltm_frame <- function(line, config, legacy) {
  out <- list(
    keyboard = character(), mouse = c(x = 0, y = 0, wheel = 0, mode = 0), mouse_buttons = rep(FALSE, 5),
    controllers = vector("list", 4), flags = "", rate = NULL, realtime = c(0, 0), events = list()
  )
  fields <- strsplit(paste0(line, "!"), "|", fixed = TRUE)[[1L]]
  fields <- fields[-c(1L, length(fields))]
  if (legacy) {
    nc <- as.integer(config$nb_controllers %||% 0L)
    tags <- c(
      "K", if (tolower(config$mouse_support %||% "false") %in% c("true", "1")) "M",
      if (nc) paste0("C", seq_len(nc)), "F", "T"
    )
    if (length(fields) > length(tags)) stop("Unexpected legacy libTAS fields", call. = FALSE)
    fields <- paste0(tags[seq_along(fields)], fields)
  }
  for (field in fields) {
    if (!nzchar(field)) next
    tag <- substr(field, 1, 1)
    body <- substring(field, 2)
    parts <- strsplit(body, ":", fixed = TRUE)[[1L]]
    if (tag == "K") {
      if (nzchar(body)) {
        if (any(!grepl("^[[:xdigit:]]{1,8}$", parts))) stop("Invalid libTAS KeySym", call. = FALSE)
        # Hex strings retain unsigned 32-bit symbols without signed conversion.
        symbols <- sub("^0+", "", tolower(parts))
        symbols <- symbols[nzchar(symbols)]
        out$keyboard <- unique(paste0("keysym_", symbols))
      }
    } else if (tag == "M") {
      if (length(parts) < 3L) stop("Incomplete libTAS mouse record", call. = FALSE)
      out$mouse[1:2] <- .computer_number(parts[1:2], "libTAS mouse coordinates", -2147483648, 2147483647)
      has_mode <- parts[3L] %in% c("A", "R")
      at <- if (has_mode) 4L else 3L
      if (has_mode) out$mouse["mode"] <- as.numeric(parts[3L] == "R")
      if (length(parts) < at || nchar(parts[at]) != 5L) stop("Invalid libTAS mouse buttons", call. = FALSE)
      out$mouse_buttons <- strsplit(parts[at], "", fixed = TRUE)[[1]] != "."
      if (length(parts) > at) out$mouse["wheel"] <- .computer_number(parts[at + 1L], "libTAS wheel")
    } else if (tag == "C") {
      p <- suppressWarnings(as.integer(substr(body, 1, 1)))
      if (is.na(p) || !p %in% 1:4) stop("Invalid libTAS controller index", call. = FALSE)
      cp <- strsplit(substring(body, 2), ":", fixed = TRUE)[[1L]]
      if (length(cp) != 7L || nchar(cp[7L]) != 15L) stop("Invalid libTAS controller record", call. = FALSE)
      out$controllers[[p]] <- list(
        axes = .computer_number(cp[1:6], "libTAS controller axis", -32768, 32767),
        buttons = strsplit(cp[7L], "", fixed = TRUE)[[1]] != "."
      )
    } else if (tag == "F") {
      out$flags <- body
    } else if (tag == "T") {
      if (nzchar(body)) {
        if (length(parts) != 2L) stop("Invalid libTAS frame rate", call. = FALSE)
        out$rate <- .computer_number(parts, "libTAS frame rate", 0, 4294967295)
      }
    } else if (tag == "D") {
      if (length(parts) != 2L) stop("Invalid libTAS real time", call. = FALSE)
      out$realtime <- .computer_number(parts, "libTAS real time")
    } else if (tag == "E") {
      if (length(parts) != 3L) stop("Invalid libTAS input event", call. = FALSE)
      e <- .computer_number(parts, "libTAS input event")
      out$events[[length(out$events) + 1L]] <- e
    } else stop("Unknown libTAS input section: ", tag, call. = FALSE)
  }
  # libTAS clears every frame before applying its ordered event list. Preserve
  # that list as well as the state after its final event.
  for (e in out$events) {
    type <- e[1]
    which <- e[2]
    value <- e[3]
    if (type == 0) {
      if (which < 0 || which > 4294967295) stop("Invalid event KeySym", call. = FALSE)
      hex <- paste0(sprintf("%x", as.integer(floor(which / 65536))), sprintf("%04x", as.integer(which %% 65536)))
      key <- paste0("keysym_", sub("^0+", "", hex))
      out$keyboard <- setdiff(out$keyboard, key)
      if (value != 0 && which != 0) out$keyboard <- c(out$keyboard, key)
    } else if (type %in% 1:4) out$mouse[type] <- value
    else if (type == 5 && which %in% 0:4) out$mouse_buttons[which + 1L] <- value != 0
    else if (type == 10 && which %in% 0:5) {
      f <- c("R", "1", "2", "3", "4", "F")[which + 1L]
      out$flags <- gsub(f, "", out$flags, fixed = TRUE)
      if (value != 0) out$flags <- paste0(out$flags, f)
    } else if (type %in% 11:12) {
      if (is.null(out$rate)) out$rate <- c(0, 0)
      out$rate[type - 10L] <- value
    } else if (type %in% 13:14) out$realtime[type - 12L] <- value
    else if (type %in% 15:22) {
      p <- (type - 15L) %/% 2L + 1L
      if (is.null(out$controllers[[p]])) out$controllers[[p]] <- list(axes = rep(0, 6), buttons = rep(FALSE, 15))
      if ((type - 15L) %% 2L == 0L && which %in% 0:14) out$controllers[[p]]$buttons[which + 1L] <- value != 0
      else if ((type - 15L) %% 2L == 1L && which %in% 0:5) out$controllers[[p]]$axes[which + 1L] <- value
      else stop("Invalid libTAS controller event", call. = FALSE)
    } else stop("Unsupported libTAS event type/index: ", type, "/", which, call. = FALSE)
  }
  out
}
.decode_ltm <- function(path) {
  contents <- .computer_tar_text(path, c("config.ini", "inputs"))
  ini <- .computer_ini(contents[["config.ini"]])
  cfg <- ini$General
  if (is.null(cfg)) stop("Missing libTAS General configuration", call. = FALSE)
  lines <- contents$inputs[startsWith(contents$inputs, "|")]
  n <- length(lines)
  unique_lines <- unique(lines)
  row_id <- match(lines, unique_lines)
  major <- as.integer(cfg$libtas_major_version %||% 1)
  minor <- as.integer(cfg$libtas_minor_version %||% 0)
  patch <- as.integer(cfg$libtas_patch_version %||% 0)
  legacy <- major == 1 && (minor < 3 || (minor == 3 && patch <= 5))
  rows <- lapply(unique_lines, .ltm_frame, config = cfg, legacy = legacy)
  nk <- sort(unique(unlist(lapply(rows, `[[`, "keyboard"), use.names = FALSE)))
  nc <- .computer_number(cfg$nb_controllers %||% 0, "libTAS controller count", 0, 4)
  seen <- which(vapply(seq_len(4L), function(p) any(vapply(rows, function(r) !is.null(r$controllers[[p]]), logical(1))), logical(1)))
  if (length(seen)) nc <- max(nc, seen)
  mouse <- tolower(cfg$mouse_support %||% "false") %in% c("true", "1") ||
    any(grepl("\\|M", unique_lines)) || any(vapply(rows, function(r) any(r$mouse != 0) || any(r$mouse_buttons), logical(1)))
  keys <- as.character(c(nk, if (mouse) .ltm_mouse_keys, if (nc) .ltm_controller_keys))
  nu <- length(rows)
  np <- max(1L, nc)
  compact <- array(FALSE, c(nu, np, length(keys)))
  analog_names <- c(if (mouse) c("mouse_x", "mouse_y", "mouse_wheel", "mouse_mode"), if (nc) .ltm_axis_names)
  analog <- lapply(seq_len(np), function(p) matrix(0, nu, length(analog_names), dimnames = list(NULL, analog_names)))
  timing <- matrix(0, nu, 4L, dimnames = list(NULL, c("framerate_num", "framerate_den", "realtime_sec", "realtime_nsec")))
  default_rate <- .computer_number(c(cfg$framerate_num %||% 60, cfg$framerate_den %||% 1), "libTAS default frame rate", 1)
  for (i in seq_along(rows)) {
    r <- rows[[i]]
    if (length(r$keyboard)) compact[i, 1L, match(r$keyboard, keys)] <- TRUE
    if (mouse) {
      compact[i, 1L, match(.ltm_mouse_keys, keys)] <- r$mouse_buttons
      analog[[1]][i, 1:4] <- r$mouse
    }
    if (nc) for (p in seq_len(nc)) if (!is.null(r$controllers[[p]])) {
      compact[i, p, match(.ltm_controller_keys, keys)] <- r$controllers[[p]]$buttons
      analog[[p]][i, match(.ltm_axis_names, analog_names)] <- r$controllers[[p]]$axes
    }
    rate <- r$rate
    if (is.null(rate)) rate <- default_rate else rate[rate == 0] <- default_rate[rate == 0]
    timing[i, ] <- c(rate, r$realtime)
  }
  inputs <- compact[row_id, , , drop = FALSE]
  analog <- lapply(seq_len(np), function(p) {
    channels <- c(if (mouse && p == 1) c("mouse_x", "mouse_y", "mouse_wheel", "mouse_mode"), if (nc) .ltm_axis_names)
    analog[[p]][row_id, channels, drop = FALSE]
  })
  flags <- vapply(rows, `[[`, character(1), "flags")[row_id]
  commands <- as.integer(grepl("R", flags, fixed = TRUE))
  declared <- as.numeric(cfg$frame_count %||% NA_real_)
  .computer_count_note(declared, n, "libTAS configuration")
  header <- list(
    format = "ltm", emulator = "libTAS", configuration = ini, observation_unit = "frame",
    frame_count = n, declared_frame_count = declared, legacy_input_format = legacy,
    keyboard_mouse_player = 1L, controller_count = nc,
    mouse_modes = c(absolute = 0, relative = 1)
  )
  calibration <- lapply(seq_len(np), function(p) if (p <= nc) list(
    left = list(x = "left_x", y = "left_y", center = c(0, 0), scale = c(32768, 32768), sign = c(1, -1)),
    right = list(x = "right_x", y = "right_y", center = c(0, 0), scale = c(32768, 32768), sign = c(1, -1))
  ) else list())
  header[["_format"]] <- "ltm"
  movie <- .new_named_movie(header, commands, inputs, keys, path,
    analog = analog,
    kinds = c(rep("keyboard", length(nk)), if (mouse) rep("peripheral", 5), if (nc) rep("button", 15)),
    stick_calibration = calibration
  )
  movie$timing <- as.data.frame(timing[row_id, , drop = FALSE])
  movie$timing$duration_seconds <- movie$timing$framerate_den / movie$timing$framerate_num
  movie$flags <- flags
  movie$input_events <- lapply(rows, `[[`, "events")[row_id]
  movie$source_input_log <- list(lines = unique_lines, row = row_id)
  movie
}
