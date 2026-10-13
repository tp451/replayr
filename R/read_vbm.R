# Sources / attribution:
#
# This reader was developed with reference to VBA-rerecording's
# `movie.h` source header alongside the TASVideos wiki at
# /EmulatorResources/VBA.
#
#   Source:    https://github.com/TASEmulators/vba-rerecording
#   License:   GPL v2 or later
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# VBA-rerecording .vbm movie format. Used for both Game Boy / GBC
# and Game Boy Advance TAS publications. Reference: VBA-rerecording source
# (`movie.h`).
#
# Layout:
#   0x00-0x03  4   magic "VBM\x1A"
#   0x04-0x07  u32 version (==1)
#   0x08-0x0B  u32 movie UID (timestamp)
#   0x0C-0x0F  u32 number of frames
#   0x10-0x13  u32 rerecord count
#   0x15       1   controller flags (bits 0..3 = controllers 1..4)
#   0x16       1   system flags (bit 0: GBA, bit 1: GBC, bit 2: SGB)
#   0x3C-0x3F  u32 controller-data offset (NOT always 0x100)
#   0x100+     controller data, 2 bytes (uint16 LE) per active controller
#
# Per-frame controller word, *active-high* (bit set == pressed):
#   bit 0: A       bit 1: B       bit 2: Select   bit 3: Start
#   bit 4: Right   bit 5: Left    bit 6: Up       bit 7: Down
#   bit 8: R       bit 9: L       (GBA pad; SNES pad of a Super Game Boy)
#   bit 10: reset (old timing)    bit 11: reset (timing since version 1.1)
#   bits 12-15: motion sensor (deprecated)
# Bits outside the controller's layout are retained in `commands`.
# Bit-index 0..15 -> 1-based private decoder slot, or NA for system / reserved bits.
.VBM_BIT_TO_UNI <- c(
  8L, # bit 0: A           -> slot 8
  7L, # bit 1: B           -> slot 7
  6L, # bit 2: Select      -> slot 6
  5L, # bit 3: Start       -> slot 5
  1L, # bit 4: Right       -> slot 1
  2L, # bit 5: Left        -> slot 2
  4L, # bit 6: Up          -> slot 4
  3L, # bit 7: Down        -> slot 3
  12L, # bit 8: R-shoulder  -> slot 12 (GBA, SGB)
  11L, # bit 9: L-shoulder  -> slot 11 (GBA, SGB)
  NA_integer_, # bit 10: reset, old timing
  NA_integer_, # bit 11: reset, new timing
  NA_integer_, NA_integer_, NA_integer_, NA_integer_ # bits 12-15: motion sensor
)
# Read complete controller records from the declared input offset.
# Preserve the header frame count alongside the stored record count.
.decode_vbm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x100L || !identical(data[1:4], charToRaw("VBM\x1A"))) {
    stop(path, ": not a VBM file")
  }
  version <- .read_u32_le(data, 4L)
  if (version != 1L) stop(path, ": unsupported VBM version ", version)
  uid <- .read_u32_le(data, 8L)
  n_frames <- .read_u32_le(data, 12L)
  rerec <- .read_u32_le(data, 16L)
  controller_flags <- as.integer(data[0x16L])
  system_flags <- as.integer(data[0x17L])
  is_gba <- bitwAnd(system_flags, 0x01L) != 0L
  is_gbc <- bitwAnd(system_flags, 0x02L) != 0L
  is_sgb <- bitwAnd(system_flags, 0x04L) != 0L
  if (sum(c(is_gba, is_gbc, is_sgb)) > 1L) {
    stop(path, ": invalid VBM system flags ", sprintf("0x%02x", system_flags))
  }
  # A Super Game Boy is played with an SNES pad, and the format records its
  # L and R like those of a Game Boy Advance.
  n_buttons <- if (is_gba || is_sgb) 12L else 8L
  active_controllers <- which(bitwAnd(controller_flags, bitwShiftL(1L, 0:3)) != 0L)
  if (length(active_controllers) == 0L) active_controllers <- 1L
  n_players <- length(active_controllers)
  if (is_gba && n_players != 1L) {
    stop(path, ": GBA VBM movies cannot contain multiple controllers")
  }
  controller_data_offset <- .read_u32_le(data, 0x3CL)
  if (controller_data_offset == 0L || controller_data_offset > length(data)) {
    controller_data_offset <- 0x100L
  }
  body <- if (controller_data_offset < length(data)) {
    data[(controller_data_offset + 1L):length(data)]
  } else raw(0)
  bytes_per_frame <- 2L * n_players
  if (length(body) %% bytes_per_frame != 0L) {
    stop(path, ": VBM controller stream has a partial final frame")
  }
  have_frames <- length(body) %/% bytes_per_frame
  # VBA playback derives movie length from the controller stream; the header
  # frame count is metadata and is not authoritative.
  declared_frames <- n_frames
  n_frames <- have_frames
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  if (n_frames > 0L) {
    # One row per frame; every bit of a controller word is tested for all
    # frames at once.
    bytes <- matrix(as.integer(body), ncol = bytes_per_frame, byrow = TRUE)
    for (pi in seq_len(n_players)) {
      words <- bytes[, 2L * pi - 1L] + bitwShiftL(bytes[, 2L * pi], 8L)
      for (bit in 0:15) {
        set <- bitwAnd(words, bitwShiftL(1L, bit)) != 0L
        if (!any(set)) next
        slot <- .VBM_BIT_TO_UNI[bit + 1L]
        if (is.na(slot) || slot > n_buttons) {
          commands[set] <- bitwOr(commands[set], bitwShiftL(1L, bit))
        } else {
          inputs[set, pi, slot] <- TRUE
        }
      }
    }
  }
  rom_name <- .read_cstring(data, 0x24L, 12L)
  author <- .read_cstring(data, 0x40L, 64L)
  header <- list(
    "_format" = "vbm",
    version = as.character(version),
    uid = as.character(uid),
    rerecordCount = as.character(rerec),
    controllerFlags = sprintf("0x%x", controller_flags),
    systemFlags = sprintf("0x%x", system_flags),
    declaredFrameCount = as.character(declared_frames),
    isGBA = if (is_gba) "1" else "0",
    isGBC = if (is_gbc) "1" else "0",
    isSGB = if (is_sgb) "1" else "0",
    romName = rom_name,
    author = author
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
