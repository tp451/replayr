# Mednafen-rr MCM header and AddJoy serialiser; controller bit order follows
# the input descriptors in src/{pce,pcfx,lynx,ngp,wswan,nes,sms}.
# https://github.com/TASEmulators/mednafen-rr
# https://tasvideos.org/EmulatorResources/Mednafen/MCM
.decode_mcm <- function(path) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 256L || !identical(data[1:8], charToRaw("MDFNMOVI"))) stop(path, ": not an MCM file")
  version <- .read_u32_le(data, 12L)
  if (version != 1L) stop(path, ": unsupported MCM version ", version)
  system <- tolower(.read_cstring(data, 116L, 5L))
  descriptor <- switch(system,
    # Numbered buttons take the lettered identities in order (I to VI and
    # Fire 1, Fire 2 are A, B, X, Y, L1, R1), as in the other readers.
    # Settings and option buttons take Start, Select and Mode: Run, the
    # Lynx's Pause and the Neo Geo Pocket's Option are Start, the Lynx's
    # Option 1 and 2 are Select and Mode, PC Engine's 2/6 switch is Mode.
    pce = list(ports = 5L, bytes = 2L, keys = c(
      "a", "b", "select", "start", "dpad_up", "dpad_right", "dpad_down", "dpad_left",
      "x", "y", "l1", "r1", "mode"
    ), names = c(
      "I", "II", "Select", "Run", "Up", "Right", "Down", "Left",
      "III", "IV", "V", "VI", "2/6 Mode Select"
    )),
    pcfx = list(ports = 2L, bytes = 2L, keys = c(
      "a", "b", "x", "y", "l1", "r1", "select", "start",
      "dpad_up", "dpad_right", "dpad_down", "dpad_left"
    ), names = c("I", "II", "III", "IV", "V", "VI", "Select", "Run", "Up", "Right", "Down", "Left")),
    lynx = list(ports = 1L, bytes = 2L,
      keys = c("a", "b", "mode", "select", "dpad_left", "dpad_right", "dpad_up", "dpad_down", "start"),
      names = c("A", "B", "Option 2", "Option 1", "Left", "Right", "Up", "Down", "Pause")),
    # The X cross is the direction pad; the Y cross has the identities of the
    # N64's C-buttons, like the right pad of any device with two.
    wswan = list(ports = 1L, bytes = 2L, keys = c(
      "dpad_up", "dpad_right", "dpad_down", "dpad_left",
      "c_up", "c_right", "c_down", "c_left", "start", "a", "b"
    ), names = c("X1", "X2", "X3", "X4", "Y1", "Y2", "Y3", "Y4", "Start", "A", "B")),
    ngp = list(ports = 1L, bytes = 1L,
      keys = c("dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "b", "start"),
      names = c("Up", "Down", "Left", "Right", "A", "B", "Option")),
    nes = list(ports = 4L, bytes = 1L,
      keys = c("a", "b", "select", "start", "dpad_up", "dpad_down", "dpad_left", "dpad_right"),
      names = c("A", "B", "Select", "Start", "Up", "Down", "Left", "Right")),
    sms = list(ports = 2L, bytes = 1L,
      keys = c("dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "b"),
      names = c("Up", "Down", "Left", "Right", "Fire 1", "Fire 2")),
    NULL
  )
  if (is.null(descriptor)) stop(path, ": unsupported MCM system ", system)
  width <- 1L + descriptor$ports * descriptor$bytes
  body <- data[-seq_len(256L)]
  tail_size <- length(body) %% width
  tail <- if (tail_size) utils::tail(body, tail_size) else raw()
  if (tail_size) {
    warning(path, ": MCM ends with ", tail_size, " byte(s) of an incomplete frame; retaining them in source_tail",
      call. = FALSE)
    body <- utils::head(body, length(body) - tail_size)
  }
  packets <- matrix(as.integer(body), ncol = width, byrow = TRUE)
  keys <- descriptor$keys
  inputs <- array(FALSE, c(nrow(packets), descriptor$ports, length(keys)))
  for (p in seq_len(descriptor$ports)) {
    first <- 2L + (p - 1L) * descriptor$bytes
    words <- packets[, first]
    if (descriptor$bytes == 2L) words <- words + 256L * packets[, first + 1L]
    inputs[, p, ] <- .legacy_bits(words, seq_along(keys) - 1L)
  }
  header <- list(
    `_format` = "mcm", system = toupper(system), version = version,
    emuVersion = .read_u32_le(data, 8L), romMD5Bytes = data[17:48],
    romFilename = .read_cstring(data, 48L, 64L), rerecordCount = .read_u32_le(data, 112L),
    author = .read_cstring(data, 121L, 32L), commandEncoding = "Mednafen command: reset=1, power=2"
  )
  movie <- .new_named_movie(header, packets[, 1L], inputs, keys, path, names = descriptor$names)
  # The Master System's Pause sits on the console: Mednafen takes bit 6 of
  # either port as that one button (src/sms/system.cpp).
  if (system == "sms") {
    movie$system_inputs <- data.frame(Pause = bitwAnd(bitwOr(packets[, 2L], packets[, 3L]), 64L) != 0L)
  }
  movie$source_tail <- tail
  movie$source_packets <- packets
  movie
}
