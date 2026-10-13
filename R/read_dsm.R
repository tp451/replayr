# DeSmuME movie.cpp and NDSSystem.h are authoritative for the swapped T/S
# mnemonic positions: T activates Select, S activates Start.
# https://github.com/TASEmulators/desmume/tree/master/desmume/src
.decode_dsm <- function(path) {
  source <- .legacy_text(path, "dsm")
  header <- source$header
  if (!header$version %in% c("1", "2")) stop(path, ": unsupported DSM version ", header$version)
  binary <- identical(header$binary, "1")
  if (binary) {
    body <- if (length(source$body)) source$body[-1L] else raw()
    if (length(body) %% 6L) stop(path, ": DSM has a partial binary record")
    packets <- matrix(as.integer(body), ncol = 6L, byrow = TRUE)
    commands <- packets[, 1L]
    pad <- .legacy_bits(packets[, 2L] + 256L * packets[, 3L], 12:0)
    channels <- packets[, 4:6, drop = FALSE]
    colnames(channels) <- c("touch_x", "touch_y", "touch_pressed")
  } else {
    # LoadFM2 reads the next record after its closing delimiter; a newline
    # is optional. Separate adjacent records before the shared field checks.
    if (any(source$body == as.raw(0))) stop(path, ": binary data in DSM text log")
    text <- gsub("\\|[[:space:]]*\\|", "|\n|", rawToChar(source$body))
    rows <- .legacy_rows(charToRaw(text), "dsm")
    fields <- .legacy_fields(rows, 2L, "dsm")
    commands <- .legacy_commands(fields[, 1L], "dsm")
    pad <- .legacy_chars(substr(fields[, 2L], 1L, 13L), 13L, "dsm")
    values <- strsplit(trimws(substring(fields[, 2L], 14L)), "[[:space:]]+")
    # DeSmuME accepts both version labels through the same record parser.
    # Some version-1 files include the newer microphone-sample field.
    widths <- lengths(values)
    if (any(!widths %in% 3:4)) stop(path, ": malformed DSM touch or microphone fields")
    expected <- if (any(widths == 4L)) 4L else 3L
    if (expected == 4L) values <- lapply(values, function(x) {
      if (length(x) == 3L) c(x, NA_character_) else x
    })
    channels <- matrix(suppressWarnings(as.integer(unlist(values))), ncol = expected, byrow = TRUE)
    if (anyNA(channels[, 1:3, drop = FALSE]) ||
      (expected == 4L && anyNA(channels[widths == 4L, 4L])) ||
      any(channels < 0L | channels > 255L, na.rm = TRUE)) stop(path, ": invalid DSM numeric channel")
    colnames(channels) <- c("touch_x", "touch_y", "touch_pressed", "microphone_sample")[seq_len(expected)]
    header$microphoneSampleStored <- expected == 4L
  }
  if (any(!channels[, "touch_pressed"] %in% 0:1)) stop(path, ": invalid DSM touch state")
  # A touch on the screen is L3, the press of a pointing input. The debug
  # button and the lid are not on the pad; they are console controls.
  keys <- c(
    "dpad_right", "dpad_left", "dpad_down", "dpad_up", "select", "start",
    "b", "a", "y", "x", "l1", "r1", "l3", "microphone"
  )
  labels <- c("Right", "Left", "Down", "Up", "Select", "Start", "B", "A", "Y", "X", "L", "R", "Touch", "Microphone")
  states <- cbind(
    pad[, 1:12, drop = FALSE], channels[, "touch_pressed"] != 0L,
    bitwAnd(commands, 1L) != 0L
  )
  header$system <- "DS"
  header$commandEncoding <- "DeSmuME: microphone=1, reset=2, lid=4"
  header$touchUnits <- "screen coordinates: origin top-left, nominal extent 256 by 192"
  if (binary && header$version == "2") header$microphoneSampleStored <- FALSE
  movie <- .new_named_movie(header, commands, array(states, c(nrow(states), 1L, ncol(states))), keys, path,
    analog = list(channels), names = labels
  )
  movie$system_inputs <- data.frame(debug = as.logical(pad[, 13L]), lid_closed = bitwAnd(commands, 4L) != 0L)
  movie
}
