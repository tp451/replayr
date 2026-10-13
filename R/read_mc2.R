# PCEjin and VBjin MovieRecord definitions (text and binary serialisations).
# https://github.com/TASEmulators/pcejin/blob/master/movie.cpp
# https://github.com/TASEmulators/vbjin/blob/master/movie.cpp
.decode_mc2 <- function(path) {
  source <- .legacy_text(path, "mc2")
  header <- source$header
  if (!identical(header$version, "1")) stop(path, ": unsupported MC2 version ", header$version)
  vb <- !is.null(header$emulator) && grepl("vbjin", header$emulator, ignore.case = TRUE)
  # Of two direction pads, the left one is the direction pad and the right
  # one has the identities of the N64's C-buttons. PC Engine buttons I and
  # II take the lettered identities in order.
  keys <- if (vb) c(
    "c_down", "c_left", "select", "start", "dpad_up", "dpad_down",
    "dpad_left", "dpad_right", "c_right", "c_up", "l1", "r1", "b", "a"
  )
  else c("dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "b", "start", "select")
  labels <- if (vb) c(
    "Right pad Down", "Right pad Left", "Select", "Start", "Left pad Up", "Left pad Down",
    "Left pad Left", "Left pad Right", "Right pad Right", "Right pad Up", "L", "R", "B", "A"
  )
  else c("Up", "Down", "Left", "Right", "I", "II", "Run", "Select")
  width <- length(keys)
  ports <- suppressWarnings(as.integer(header$ports))
  if (!length(ports)) ports <- 1L
  if (length(ports) != 1L || is.na(ports) || ports < 1L || ports > 5L) stop(path, ": invalid MC2 port count")
  if (identical(header$binary, "1")) {
    body <- if (length(source$body)) source$body[-1L] else raw()
    record_width <- 1L + 2L * ports
    if (length(body) %% record_width) stop(path, ": MC2 has a partial binary record")
    packets <- matrix(as.integer(body), ncol = record_width, byrow = TRUE)
    commands <- packets[, 1L]
    inputs <- array(FALSE, c(nrow(packets), ports, width))
    for (p in seq_len(ports))
      inputs[, p, ] <- .legacy_bits(packets[, 2L * p] + 256L * packets[, 2L * p + 1L], (width - 1L):0)
  } else {
    rows <- .legacy_rows(source$body, "mc2")
    fields <- .legacy_fields(rows, ports + 1L, "mc2")
    commands <- .legacy_commands(fields[, 1L], "mc2")
    inputs <- array(FALSE, c(nrow(fields), ports, width))
    for (p in seq_len(ports)) inputs[, p, ] <- .legacy_chars(fields[, p + 1L], width, "mc2")
  }
  header$system <- if (vb) {
    "VBOY"
  } else if (identical(header$PCECD, "1") || identical(header$pcecd, "1")) {
    "PCECD"
  } else {
    "PCE"
  }
  header$commandEncoding <- "Mednafen/PCEjin/VBjin command byte"
  .new_named_movie(header, commands, inputs, keys, path, names = labels)
}
