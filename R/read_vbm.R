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
# (typeFlags bits 0/1) and Game Boy Advance (typeFlags bit 2) TAS
# publications. Reference: VBA-rerecording source (movie.h).
#
# Layout:
#   0x00-0x03  4   magic "VBM\x1A"
#   0x04-0x07  u32 version (==1)
#   0x08-0x0B  u32 movie UID (timestamp)
#   0x0C-0x0F  u32 number of frames
#   0x10-0x13  u32 rerecord count
#   0x16       1   typeFlags  (bit 0: GB, bit 1: GBC, bit 2: GBA, ...)
#   0x3C-0x3F  u32 controller-data offset (NOT always 0x100)
#   0x100+     controller data, 2 bytes (uint16 LE) per frame per controller
#
# Per-frame controller word, *active-high* (bit set == pressed):
#   bit 0: A       bit 1: B       bit 2: Select   bit 3: Start
#   bit 4: Right   bit 5: Left    bit 6: Up       bit 7: Down
#   bit 8: R       bit 9: L       (GBA only)
#   bits 10-12: speedup / capture / GBA-reset (system, ignored)

# Bit-index 0..15 -> 1-based universal slot, or NA for system / reserved bits.
.VBM_BIT_TO_UNI <- c(
  8L,   # bit 0: A           -> slot 8
  7L,   # bit 1: B           -> slot 7
  6L,   # bit 2: Select      -> slot 6
  5L,   # bit 3: Start       -> slot 5
  1L,   # bit 4: Right       -> slot 1
  2L,   # bit 5: Left        -> slot 2
  4L,   # bit 6: Up          -> slot 4
  3L,   # bit 7: Down        -> slot 3
  12L,  # bit 8: R-shoulder  -> slot 12 (GBA)
  11L,  # bit 9: L-shoulder  -> slot 11 (GBA)
  NA_integer_,  # bit 10: speedup
  NA_integer_,  # bit 11: capture
  NA_integer_,  # bit 12: GBA reset
  NA_integer_, NA_integer_, NA_integer_  # bits 13-15: reserved
)

#' Read a VBA-rerecording .vbm movie file
#'
#' GB and GBC pubs (typeFlags bit 0 or 1) come out 8 buttons wide
#' (universal slots 1..8). GBA pubs (typeFlags bit 2) come out 12 buttons
#' wide (slots 1..12) so the L/R shoulders land at their canonical
#' universal positions.
#'
#' @param path Path to a .vbm file.
#' @return A `replayr_movie` object.
#' @export
read_vbm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x100L || !identical(data[1:4], charToRaw("VBM\x1A"))) {
    stop(path, ": not a VBM file")
  }
  version <- .read_u32_le(data, 4L)
  if (version != 1L) stop(path, ": unsupported VBM version ", version)
  uid <- .read_u32_le(data, 8L)
  n_frames <- .read_u32_le(data, 12L)
  rerec <- .read_u32_le(data, 16L)
  type_flags <- as.integer(data[0x17L])

  is_gba <- bitwAnd(type_flags, 0x04L) != 0L
  n_buttons <- if (is_gba) 12L else 8L
  n_players <- 1L

  controller_data_offset <- .read_u32_le(data, 0x3CL)
  if (controller_data_offset == 0L || controller_data_offset > length(data)) {
    controller_data_offset <- 0x100L
  }
  body <- data[(controller_data_offset + 1L):length(data)]
  have_frames <- length(body) %/% 2L
  if (have_frames < n_frames) n_frames <- have_frames

  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)

  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- (fi - 1L) * 2L
      word <- as.integer(body[off + 1L]) +
              bitwShiftL(as.integer(body[off + 2L]), 8L)
      for (bit in 0:15) {
        if (bitwAnd(word, bitwShiftL(1L, bit)) == 0L) next
        slot <- .VBM_BIT_TO_UNI[bit + 1L]
        if (is.na(slot)) {
          # System / command bit; pack into commands.
          commands[fi] <- bitwOr(commands[fi], bitwShiftL(1L, bit))
          next
        }
        if (slot > n_buttons) next
        inputs[fi, 1L, slot] <- TRUE
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
    typeFlags = sprintf("0x%x", type_flags),
    isGBA = if (is_gba) "1" else "0",
    romName = rom_name,
    author = author
  )
  mv <- .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    button_mnemonics = universal_buttons()[seq_len(n_buttons)],
    button_names = universal_button_names()[seq_len(n_buttons)]
  )
  mv$source_path <- path
  mv
}
