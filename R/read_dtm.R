# Sources / attribution:
#
# This reader was developed with reference to Dolphin Emulator's
# `Source/Core/Core/Movie.cpp` (the .dtm format encoder/decoder),
# alongside the TASVideos wiki at /EmulatorResources/Tools/Dolphin.
#
#   Source:    https://github.com/dolphin-emu/dolphin
#   License:   GPL v2 or later
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# Dolphin .dtm GameCube movie format. Wii .dtm files are not supported.
# Reference: Dolphin source (Source/Core/Core/Movie.cpp) and the tasvideos
# wiki at /EmulatorResources/Tools/Dolphin.
#
# Layout (v1):
#   0x00-0x03  4   magic "DTM\x1A"
#   0x04-0x09  6   ROM ID (e.g. "G4BJ")
#   0x0A       1   bWii flag
#   0x0B       1   numControllers (lower 4 bits = GC ports polled)
#   0x0D       u64 frameCount  (game-side VI counter)
#   0x15       u64 inputCount  (controller-poll count, == body frames)
#   0x2D       u32 numRerecords
#   0x100+     controller data, 8 bytes per controller poll:
#       byte 0  buttons low  (Start, A, B, X, Y, Z, D-Up, D-Down) -- the packed
#                            Dolphin ControllerState bitfield (NOT GCPadStatus order)
#       byte 1  buttons high (D-Left, D-Right, L-dig, R-dig, disc, reset,
#                            is_connected, get_origin)
#       byte 2  L analog trigger (0-255)
#       byte 3  R analog trigger (0-255)
#       byte 4  analog stick X (0-255, 128=center)
#       byte 5  analog stick Y
#       byte 6  C-stick X
#       byte 7  C-stick Y

# Bit-index 0..15 in the GC button word -> 1-based universal slot. Order is the
# Dolphin .dtm PACKED ControllerState bitfield (Start,A,B,X,Y,Z,DPadUp,DPadDown,
# DPadLeft,DPadRight,L,R,...), NOT the GCPadStatus.button flag order (which the
# GCPadStatus order. These layouts differ, so GCPadStatus constants would
# shift ordinary face-button presses onto unrelated slots.
.DTM_BIT_TO_UNI <- c(
  5L,             # bit 0:  Start       -> 5
  8L,             # bit 1:  A           -> 8
  7L,             # bit 2:  B           -> 7
  9L,             # bit 3:  X           -> 9
  10L,            # bit 4:  Y           -> 10
  14L,            # bit 5:  Z           -> 14
  4L,             # bit 6:  D-Up        -> 4
  3L,             # bit 7:  D-Down      -> 3
  2L,             # bit 8:  D-Left      -> 2
  1L,             # bit 9:  D-Right     -> 1
  11L,            # bit 10: L-digital   -> 11
  12L,            # bit 11: R-digital   -> 12
  NA_integer_, NA_integer_, NA_integer_, NA_integer_  # bits 12-15: disc/reset/is_connected/get_origin
)

.DTM_STICK_DEADZONE <- 16L

# C-stick directions reuse the N64 C-button slots 17..20 (1-based).
# Mapping for sectors (E, NE, N, NW, W, SW, S, SE): the GC c-stick is
# the spiritual successor to the N64 C-buttons (camera / item / look
# directions), so we coalesce diagonals onto whichever cardinal C-button
# best matches the sector's primary axis.
.DTM_CSTICK_SECTOR_TO_CSLOT <- c(
  17L,  # E   -> C-Right
  17L,  # NE  -> C-Right
  20L,  # N   -> C-Up
  18L,  # NW  -> C-Left
  18L,  # W   -> C-Left
  18L,  # SW  -> C-Left
  19L,  # S   -> C-Down
  17L   # SE  -> C-Right
)

#' Read a Dolphin .dtm GameCube movie file
#'
#' 13 GC buttons map onto universal slots 1..14 alongside their
#' NES/SNES counterparts. The analog stick is quantised to 8
#' cardinal/intercardinal directions (slots 21..28); the C-stick is
#' quantised more coarsely onto the four C-button slots (17..20). L/R
#' analog triggers fire the corresponding shoulder slot when pulled
#' past 50%. Output is 28 buttons wide. Wii-mode .dtm files raise an
#' error.
#'
#' @param path Path to a .dtm file.
#' @return A `replayr_movie` object.
#' @export
read_dtm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x100L || !identical(data[1:4], charToRaw("DTM\x1A"))) {
    stop(path, ": not a DTM file")
  }
  rom_id <- rawToChar(data[5:10])
  Encoding(rom_id) <- "latin1"
  rom_id <- enc2utf8(rom_id)
  is_wii <- as.integer(data[0x0BL]) != 0L
  if (is_wii) stop(path, ": Wii DTM movies are not supported")

  frame_count <- .read_u64_le(data, 0x0DL)
  input_count <- .read_u64_le(data, 0x15L)
  rerec <- .read_u32_le(data, 0x2DL)
  ctrl_mask <- as.integer(data[0x0CL])
  n_gc_ports <- sum(bitwAnd(bitwAnd(ctrl_mask, 0x0FL), bitwShiftL(1L, 0:3)) != 0L)
  if (n_gc_ports == 0L) stop(path, ": DTM declares no GameCube controllers")
  # DTM records controller polls sequentially and does not tag them with a port
  # number. Games need not poll every connected port once per frame, so fixed
  # grouping would silently assign records to the wrong players.
  if (n_gc_ports != 1L) {
    stop(path, ": multi-controller DTM poll streams are not supported")
  }

  body <- if (length(data) > 0x100L) data[(0x100L + 1L):length(data)] else raw(0)
  bytes_per_frame <- 8L
  have_frames <- length(body) %/% bytes_per_frame
  if (input_count > have_frames) {
    stop(path, ": truncated DTM input stream (declares ", input_count,
         " polls, has ", have_frames, ")")
  }
  n_frames <- if (input_count > 0) as.integer(input_count) else have_frames
  DTM_FRAME_LIMIT <- 2000000L
  if (n_frames > DTM_FRAME_LIMIT) {
    stop(path, ": DTM input stream exceeds the supported two-million-poll limit")
  }

  n_buttons <- 28L
  inputs <- .empty_inputs(n_frames, 1L, n_buttons)
  commands <- integer(n_frames)

  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- (fi - 1L) * bytes_per_frame
      word <- as.integer(body[off + 1L]) +
              bitwShiftL(as.integer(body[off + 2L]), 8L)
      for (bit in 0:11) {
        if (bitwAnd(word, bitwShiftL(1L, bit)) == 0L) next
        slot <- .DTM_BIT_TO_UNI[bit + 1L]
        if (is.na(slot)) next
        inputs[fi, 1L, slot] <- TRUE
      }
      if (bitwAnd(word, bitwShiftL(1L, 12L)) != 0L) commands[fi] <- 1L
      if (bitwAnd(word, bitwShiftL(1L, 13L)) != 0L) {
        commands[fi] <- bitwOr(commands[fi], 2L)
      }
      # Analog L / R triggers -- threshold at >=50% pull.
      if (as.integer(body[off + 3L]) >= 128L) inputs[fi, 1L, 11L] <- TRUE
      if (as.integer(body[off + 4L]) >= 128L) inputs[fi, 1L, 12L] <- TRUE
      # Analog stick: sign-center (128) and quantise.
      sx <- as.integer(body[off + 5L]) - 128L
      sy <- as.integer(body[off + 6L]) - 128L
      mag2 <- sx * sx + sy * sy
      if (mag2 >= .DTM_STICK_DEADZONE * .DTM_STICK_DEADZONE) {
        angle <- atan2(sy, sx)
        sector <- as.integer((angle + pi / 8) %/% (pi / 4)) %% 8L
        inputs[fi, 1L, .STICK_SECTOR_TO_UNI[sector + 1L]] <- TRUE
      }
      # C-stick: same deadzone, route to N64-C slots 17..20.
      cx <- as.integer(body[off + 7L]) - 128L
      cy <- as.integer(body[off + 8L]) - 128L
      cmag2 <- cx * cx + cy * cy
      if (cmag2 >= .DTM_STICK_DEADZONE * .DTM_STICK_DEADZONE) {
        cangle <- atan2(cy, cx)
        csector <- as.integer((cangle + pi / 8) %/% (pi / 4)) %% 8L
        inputs[fi, 1L, .DTM_CSTICK_SECTOR_TO_CSLOT[csector + 1L]] <- TRUE
      }
    }
  }

  header <- list(
    "_format" = "dtm",
    romId = rom_id,
    rerecordCount = as.character(rerec),
    frameCount = as.character(frame_count),
    inputCount = as.character(input_count),
    controllerMask = sprintf("0x%02x", ctrl_mask)
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
