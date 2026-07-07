# Sources / attribution:
#
# This reader was developed with reference to the PSXjin source
# tree alongside the TASVideos wiki at
# /EmulatorResources/Tools/Psxjin.
#
#   Source:    PSXjin source tree (multiple mirrors after the
#              original Google Code archive shutdown)
#   License:   GPL v2 or later
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# PSXjin .pjm (text-body) movie format. Sibling to .pxm. Reference:
# tasvideos.org wiki at /EmulatorResources/Tools/Psxjin and the PSXjin
# source tree.
#
# Header: 4-byte ASCII magic "PJM ", u32 version (==2), then a small fixed
# binary header followed by ASCII description and platform metadata.
#
# Body: text-formatted FM2-like, each frame rendered as
#       <14 chars button mask>||0|\r\n
# for a constant 20-byte stride. The body offset isn't fixed (depends on
# embedded savestate / metadata length), so we locate it by searching for
# the first `||0|\r\n` separator and backing up 14 bytes.
#
# PSX DualShock 14-button mask in PJM column order:
#   col 1: Square    col 2: Cross     col 3: Circle    col 4: Triangle
#   col 5: L1        col 6: R1        col 7: L2        col 8: R2
#   col 9: Left      col 10: Down     col 11: Right    col 12: Up
#   col 13: Start    col 14: Select
#
# Face-button mapping into universal slots follows the geometric
# diamond convention used elsewhere in the package: Triangle (top) -> X
# slot, Square (left) -> Y, Cross (bottom) -> B, Circle (right) -> A.

# 1-based PJM column position -> 1-based universal slot.
.PJM_POS_TO_UNI <- c(
  10L,  # 1: Square    -> slot 10 (Y face)
  7L,   # 2: Cross     -> slot 7 (B)
  8L,   # 3: Circle    -> slot 8 (A)
  9L,   # 4: Triangle  -> slot 9 (X face)
  11L,  # 5: L1        -> slot 11 (L-shoulder)
  12L,  # 6: R1        -> slot 12 (R-shoulder)
  29L,  # 7: L2        -> slot 29 (PSX L2)
  30L,  # 8: R2        -> slot 30 (PSX R2)
  2L,   # 9: Left      -> slot 2 (Left)
  3L,   # 10: Down     -> slot 3 (Down)
  1L,   # 11: Right    -> slot 1 (Right)
  4L,   # 12: Up       -> slot 4 (Up)
  5L,   # 13: Start    -> slot 5 (Start)
  6L    # 14: Select   -> slot 6 (Select)
)

#' Read a PSXjin .pjm movie file
#'
#' Parses the PSXjin text-body movie format into the standard
#' `replayr_movie` shape. PSX gamepad maps onto universal slots 1..12 (NES
#' + SNES face / shoulder layout) plus 29 / 30 for L2 / R2; the output is
#' 30 buttons wide.
#'
#' @param path Path to a .pjm file.
#' @return A `replayr_movie` object.
#' @export
read_pjm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 24L || !identical(data[1:4], charToRaw("PJM "))) {
    stop(path, ": not a PJM file")
  }
  version <- .read_u32_le(data, 4L)
  if (version != 2L) stop(path, ": unsupported PJM version ", version)

  # Locate the first `||0|\r\n` separator.
  sep <- charToRaw("||0|\r\n")
  first_sep <- .find_raw(data, sep)
  if (is.na(first_sep) || first_sep < 14L) {
    stop(path, ": PJM body separator not found")
  }
  body_off <- first_sep - 14L
  body <- data[(body_off + 1L):length(data)]

  n_frames_field <- .read_u32_le(data, 16L)
  stride <- 14L + length(sep)  # 20 bytes per frame
  have_frames <- length(body) %/% stride
  n_frames <- if (n_frames_field > 0L) min(n_frames_field, have_frames) else have_frames

  n_buttons <- 30L
  inputs <- .empty_inputs(n_frames, 1L, n_buttons)
  commands <- integer(n_frames)
  pos_map <- .PJM_POS_TO_UNI

  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- (fi - 1L) * stride
      mask_len <- min(14L, length(body) - off)
      if (mask_len <= 0L) break
      for (col in seq_len(mask_len)) {
        ch <- as.integer(body[off + col])
        # `.` (0x2e), `\x00`, `\x20` mean unpressed.
        if (ch == 0x2e || ch == 0x00 || ch == 0x20) next
        # `#` at column 1 is a frame-level command (reset / savestate-load).
        if (col == 1L && ch == 0x23) {
          commands[fi] <- bitwOr(commands[fi], 1L)
          next
        }
        slot <- pos_map[col]
        inputs[fi, 1L, slot] <- TRUE
      }
    }
  }

  rerec <- .read_u32_le(data, 20L)
  desc <- .read_cstring(data, 0x39L, 0xC8L)  # 0x38..0x100
  header <- list(
    "_format" = "pjm",
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
