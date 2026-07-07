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
#   0x1C-0x1F  u32 controller-data offset
#
# Per-frame controller word, *active-high*:
#   bit  4: R-shoulder   bit  5: L-shoulder
#   bit  6: X            bit  7: A
#   bit  8: Right        bit  9: Left
#   bit 10: Down         bit 11: Up
#   bit 12: Start        bit 13: Select
#   bit 14: Y            bit 15: B
#   bits 0-3: reserved.

# Bit-index 0..15 -> 1-based universal slot, NA for reserved.
.SMV_BIT_TO_UNI <- c(
  NA_integer_, NA_integer_, NA_integer_, NA_integer_,  # bits 0-3 reserved
  12L,  # bit  4: R-shoulder -> slot 12
  11L,  # bit  5: L-shoulder -> slot 11
  9L,   # bit  6: X          -> slot 9
  8L,   # bit  7: A          -> slot 8
  1L,   # bit  8: Right      -> slot 1
  2L,   # bit  9: Left       -> slot 2
  3L,   # bit 10: Down       -> slot 3
  4L,   # bit 11: Up         -> slot 4
  5L,   # bit 12: Start      -> slot 5
  6L,   # bit 13: Select     -> slot 6
  10L,  # bit 14: Y          -> slot 10
  7L    # bit 15: B          -> slot 7
)

#' Read a Snes9x-rerecording .smv movie file
#'
#' SNES gamepads come out 12 buttons wide (universal slots 1..12) so
#' .smv publications share the same shape as .lsmv and .bk2 SNES pubs.
#' The controller mask at offset 0x14 selects which ports the file polls;
#' each polled port becomes one player in the output.
#'
#' @param path Path to a .smv file.
#' @return A `replayr_movie` object.
#' @export
read_smv <- function(path) {
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

  # Count polled ports from ctrl_mask bits.
  polled <- sum(bitwAnd(ctrl_mask, bitwShiftL(1L, 0:7)) != 0L)
  if (polled == 0L) {
    stop(sprintf("%s: SMV with no polled controllers (mask=0x%x)", path, ctrl_mask))
  }

  body <- data[(ctrl_off + 1L):length(data)]
  bytes_per_frame <- 2L * polled
  have_frames <- length(body) %/% bytes_per_frame
  n_frames <- if (n_frames_field > 0L) min(n_frames_field, have_frames) else have_frames

  n_buttons <- 12L
  n_players <- polled

  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)

  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- (fi - 1L) * bytes_per_frame
      for (pi in seq_len(polled)) {
        po <- off + (pi - 1L) * 2L
        word <- as.integer(body[po + 1L]) +
                bitwShiftL(as.integer(body[po + 2L]), 8L)
        for (bit in 0:15) {
          if (bitwAnd(word, bitwShiftL(1L, bit)) == 0L) next
          slot <- .SMV_BIT_TO_UNI[bit + 1L]
          if (is.na(slot) || slot > n_buttons) next
          inputs[fi, pi, slot] <- TRUE
        }
      }
    }
  }

  # Best-effort ROM name extraction. Different SMV versions push the
  # name to different offsets; scan the 0x23..0x60 region for the first
  # run of printable ASCII bytes >= 4 chars long.
  rom_name <- ""
  scan_chunk <- data[(0x23L + 1L):min(length(data), 0x60L)]
  ascii_mask <- as.integer(scan_chunk) >= 0x20L &
                as.integer(scan_chunk) <= 0x7EL
  if (any(ascii_mask)) {
    # Find first run of 4+ TRUE values.
    rl <- rle(ascii_mask)
    starts <- cumsum(c(1L, utils::head(rl$lengths, -1L)))
    good <- which(rl$values & rl$lengths >= 4L)
    if (length(good) > 0L) {
      s <- starts[good[1L]]
      e <- s + rl$lengths[good[1L]] - 1L
      rom_name <- rawToChar(scan_chunk[s:e])
      Encoding(rom_name) <- "latin1"
      rom_name <- enc2utf8(rom_name)
      rom_name <- sub("[[:space:]]+$", "", rom_name)
    }
  }

  header <- list(
    "_format" = "smv",
    version = as.character(version),
    uid = as.character(uid),
    rerecordCount = as.character(rerec),
    ctrlMask = sprintf("0x%x", ctrl_mask),
    opts = sprintf("0x%x", opts),
    sync = sprintf("0x%x", sync),
    romName = rom_name
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
