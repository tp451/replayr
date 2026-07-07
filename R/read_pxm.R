# Sources / attribution:
#
# This reader was developed with reference to the PSXjin source
# tree alongside the TASVideos wiki at
# /EmulatorResources/Tools/Psxjin. .pxm is the binary-body sibling
# of .pjm.
#
#   Source:    PSXjin source tree (multiple mirrors after the
#              original Google Code archive shutdown)
#   License:   GPL v2 or later
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# PSXjin .pxm movie format. Sibling to .pjm with a binary body. Reference:
# tasvideos.org wiki at /EmulatorResources/Tools/Psxjin and the PSXjin
# source tree.
#
# Layout:
#   0x00-0x03  4   magic "PXM "
#   0x04-0x07  u32 version (==2)
#   0x10-0x13  u32 number of frames
#   0x14-0x17  u32 rerecord count
#   ...        ASCII description / metadata
#   <body_off>  5 bytes per frame at the END of the file:
#              body_off = file_size - n_frames * 5
#
# Per-frame body bytes:
#   byte 0  P1 button low (PSX 16-bit DualShock word, low byte)
#   byte 1  P1 button high
#   bytes 2-4  reserved (P2 / analog placeholders, ignored)
#
# DualShock 16-bit button word, *active-high*:
#   bit 0: Select       bit 3: Start
#   bit 4: Up           bit 5: Right
#   bit 6: Down         bit 7: Left
#   bit 8: L2           bit 9: R2
#   bit 10: L1          bit 11: R1
#   bit 12: Triangle    bit 13: Circle
#   bit 14: Cross       bit 15: Square

# Bit 0..15 -> 1-based universal slot. NA for reserved bits.
.PSX_BIT_TO_UNI <- c(
  6L,             # bit 0:  Select       -> 6
  NA_integer_,    # bit 1
  NA_integer_,    # bit 2
  5L,             # bit 3:  Start        -> 5
  4L,             # bit 4:  Up           -> 4
  1L,             # bit 5:  Right        -> 1
  3L,             # bit 6:  Down         -> 3
  2L,             # bit 7:  Left         -> 2
  29L,            # bit 8:  L2           -> 29
  30L,            # bit 9:  R2           -> 30
  11L,            # bit 10: L1           -> 11
  12L,            # bit 11: R1           -> 12
  9L,             # bit 12: Triangle     -> 9 (X-face)
  8L,             # bit 13: Circle       -> 8 (A)
  7L,             # bit 14: Cross        -> 7 (B)
  10L             # bit 15: Square       -> 10 (Y-face)
)

#' Read a PSXjin .pxm movie file
#'
#' PSX gamepad maps onto universal slots 1..12 (NES + SNES face / shoulder
#' layout) plus 29 / 30 for L2 / R2. Output is 30 buttons wide. The
#' 5-byte-per-frame body lives at the END of the file (header + savestate
#' take up the rest of the leading bytes); body offset is computed as
#' `file_size - n_frames * 5`.
#'
#' @param path Path to a .pxm file.
#' @return A `replayr_movie` object.
#' @export
read_pxm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x40L || !identical(data[1:4], charToRaw("PXM "))) {
    stop(path, ": not a PXM file")
  }
  version <- .read_u32_le(data, 4L)
  if (version != 2L) stop(path, ": unsupported PXM version ", version)
  n_frames <- .read_u32_le(data, 0x10L)

  bytes_per_frame <- 5L
  body_off <- length(data) - n_frames * bytes_per_frame
  if (body_off < 0L) {
    stop(sprintf("%s: PXM body appears truncated (file=%d, n_frames=%d)",
                 path, length(data), n_frames))
  }
  body <- data[(body_off + 1L):length(data)]

  n_buttons <- 30L
  inputs <- .empty_inputs(n_frames, 1L, n_buttons)
  commands <- integer(n_frames)

  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- (fi - 1L) * bytes_per_frame
      word <- as.integer(body[off + 1L]) +
              bitwShiftL(as.integer(body[off + 2L]), 8L)
      for (bit in 0:15) {
        if (bitwAnd(word, bitwShiftL(1L, bit)) == 0L) next
        slot <- .PSX_BIT_TO_UNI[bit + 1L]
        if (is.na(slot)) next
        inputs[fi, 1L, slot] <- TRUE
      }
    }
  }

  rerec <- .read_u32_le(data, 0x14L)
  desc <- .read_cstring(data, 0x38L, 0xC8L)
  header <- list(
    "_format" = "pxm",
    version = as.character(version),
    rerecordCount = as.character(rerec),
    description = desc
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
