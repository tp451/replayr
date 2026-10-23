# Snes9x-rerecording .smv movie format. Reference: tasvideos.org wiki at
# /EmulatorResources/Snes9x/SMV. Versions 1, 4, 5 share the same body
# layout (uint16 LE button-words at `ctrl_off`, 2 bytes per polled
# controller per frame); only the metadata-block size between header
# and body changes.
#
# Layout:
#   0x00-0x03  4   magic "SMV\x1A"
#   0x04-0x07  u32 version (1, 4 or 5)
#   0x10-0x13  u32 frame count
#   0x14       1   controller mask (bits 0..4 = ports 1..5 polled)
#   0x17       1   sync flags (bit 6: ROM information present)
#   0x18-0x1B  u32 savestate offset
#   0x1C-0x1F  u32 controller-data offset
#   0x20-0x23  u32 input-sample count (versions 4 and 5)
#   0x24-0x25  controller types for ports 1 and 2 (versions 4 and 5)
#
# ROM information, when present, is the 30 bytes before the savestate: three
# zero bytes, the CRC32 of the ROM (u32), and its internal name (23 bytes,
# JIS X 0201 as in the cartridge header).
#
# Per-frame controller word, *active-high*:
#   bit  4: R-shoulder   bit  5: L-shoulder
#   bit  6: X            bit  7: A
#   bit  8: Right        bit  9: Left
#   bit 10: Down         bit 11: Up
#   bit 12: Start        bit 13: Select
#   bit 14: Y            bit 15: B
#   bits 0-3: reserved.
# Bit-index 0..15 -> 1-based private decoder slot, NA for reserved.
.SMV_BIT_TO_UNI <- c(
  NA_integer_, NA_integer_, NA_integer_, NA_integer_, # bits 0-3 reserved
  12L, # bit  4: R-shoulder -> slot 12
  11L, # bit  5: L-shoulder -> slot 11
  9L, # bit  6: X          -> slot 9
  8L, # bit  7: A          -> slot 8
  1L, # bit  8: Right      -> slot 1
  2L, # bit  9: Left       -> slot 2
  3L, # bit 10: Down       -> slot 3
  4L, # bit 11: Up         -> slot 4
  5L, # bit 12: Start      -> slot 5
  6L, # bit 13: Select     -> slot 6
  10L, # bit 14: Y          -> slot 10
  7L # bit 15: B          -> slot 7
)
# Decode standard-pad records, including the initial state before frame
# zero. Reset markers become commands rather than pressed controls.
.decode_smv <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x20L || !identical(data[1:4], charToRaw("SMV\x1A"))) {
    stop(path, ": not an SMV file")
  }
  version <- .read_u32_le(data, 4L)
  if (!(version %in% c(1L, 4L, 5L))) {
    stop(path, ": unsupported SMV version ", version)
  }
  uid <- .read_u32_le(data, 8L)
  rerec <- .read_u32_le(data, 12L)
  n_frames_field <- .read_u32_le(data, 16L)
  ctrl_mask <- as.integer(data[0x15L])
  opts <- as.integer(data[0x16L])
  sync <- as.integer(data[0x17L])
  ctrl_off <- .read_u32_le(data, 0x1CL)
  if (ctrl_off < 0x20L || ctrl_off > length(data)) {
    stop(path, ": invalid SMV controller-data offset")
  }
  input_sample_count <- NA_real_
  controller_types <- integer(0)
  if (version >= 4L) {
    if (length(data) < 0x26L) stop(path, ": truncated SMV v4/v5 header")
    input_sample_count <- .read_u32_le(data, 0x20L)
    controller_types <- as.integer(data[0x25L:0x26L])
    # Joypads and multitaps use the ordinary two-byte controller words.
    # Mouse, Super Scope and Justifier records have different widths and are
    # rejected instead of silently shifting every subsequent frame.
    unsupported <- controller_types[!(controller_types %in% c(0L, 1L, 5L))]
    if (length(unsupported)) {
      stop(
        path, ": unsupported SMV peripheral type(s): ",
        paste(unique(unsupported), collapse = ", ")
      )
    }
  }
  # Count polled ports from ctrl_mask bits.
  polled <- sum(bitwAnd(ctrl_mask, bitwShiftL(1L, 0:7)) != 0L)
  if (polled == 0L) {
    stop(sprintf("%s: SMV with no polled controllers (mask=0x%x)", path, ctrl_mask))
  }
  body <- if (ctrl_off < length(data)) data[(ctrl_off + 1L):length(data)] else raw(0)
  bytes_per_frame <- 2L * polled
  have_frames <- length(body) %/% bytes_per_frame
  # SMV stores an initial state before frame zero, so standard-pad movies have
  # frame_count + 1 input samples. Never silently truncate a declared movie.
  required_frames <- n_frames_field + 1
  # Versions 4 and 5 also count input samples. Snes9x stores that count plus
  # one records; when it exceeds the frame count and the stream holds them,
  # they are recorded input as well.
  if (version >= 4L && input_sample_count > n_frames_field &&
    input_sample_count + 1 <= have_frames) {
    required_frames <- input_sample_count + 1
  }
  # A rerecorded SMV can retain unused bytes after its declared input range.
  # Only an incomplete sample INSIDE that range is truncation. Do not decode
  # stale tail bytes, or reject a complete movie because its unused tail is odd.
  if (have_frames < required_frames && length(body) %% bytes_per_frame)
    stop(path, ": partial final SMV sample")
  shortfall <- max(0, required_frames - have_frames)
  if (shortfall > 1L) {
    stop(
      path, ": truncated SMV input stream (needs ", required_frames,
      " samples, has ", have_frames, ")"
    )
  }
  if (shortfall)
    warning(path, ": SMV header exceeds the complete stream by one sample; no input invented", call. = FALSE)
  n_frames <- min(required_frames, have_frames)
  n_buttons <- 12L
  n_players <- polled
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  if (n_frames > 0L) {
    # One row per sample; every bit of a controller word is tested for all
    # samples at once.
    bytes <- matrix(as.integer(body[seq_len(n_frames * bytes_per_frame)]), ncol = bytes_per_frame, byrow = TRUE)
    reset <- rep(TRUE, n_frames)
    for (pi in seq_len(polled)) {
      words <- bytes[, 2L * pi - 1L] + bitwShiftL(bytes[, 2L * pi], 8L)
      reset <- reset & words == 0xffffL
      for (bit in 0:15) {
        slot <- .SMV_BIT_TO_UNI[bit + 1L]
        if (is.na(slot) || slot > n_buttons) next
        inputs[bitwAnd(words, bitwShiftL(1L, bit)) != 0L, pi, slot] <- TRUE
      }
    }
    # An all-ones sample is Snes9x's reset marker, not every button pressed.
    inputs[reset, , ] <- FALSE
    commands[reset] <- 1L
  }
  # The ROM information lies between the author's text and the savestate.
  # Snes9x reads it 30 bytes before the savestate whenever the flag is set,
  # and so does this reader. Movies of early versions have none; their fields
  # stay empty.
  rom_crc32 <- ""
  rom_name <- ""
  state_off <- .read_u32_le(data, 0x18L)
  if (bitwAnd(as.integer(data[0x18L]), 0x40L) != 0L && state_off >= 30 && state_off <= length(data)) {
    rom_crc32 <- .hex_u32_le(data, state_off - 27L)
    rom_name <- .read_jis_x0201(data, state_off - 23L, 23L)
  }
  header <- list(
    "_format" = "smv",
    version = as.character(version),
    uid = as.character(uid),
    rerecordCount = as.character(rerec),
    ctrlMask = sprintf("0x%x", ctrl_mask),
    opts = sprintf("0x%x", opts),
    # Bit 1 of the movie options: PAL timing.
    isPal = bitwAnd(opts, 2L) != 0L,
    sync = sprintf("0x%x", sync),
    inputSampleCount = if (is.na(input_sample_count)) "" else as.character(input_sample_count),
    declaredFrameCount = as.character(n_frames_field),
    availableSampleCount = as.character(have_frames),
    trailingSampleShortfall = as.character(shortfall),
    unusedTrailingBytes = as.character(max(0L, length(body) - n_frames * bytes_per_frame)),
    controllerTypes = paste(controller_types, collapse = ","),
    romCRC32 = rom_crc32,
    romName = rom_name
  )
  mv <- .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    button_mnemonics = .legacy_buttons()[seq_len(n_buttons)],
    button_names = .legacy_button_names()[seq_len(n_buttons)]
  )
  mv$source_path <- path
  mv
}
