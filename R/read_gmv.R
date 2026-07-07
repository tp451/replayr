# Gens-rerecording .gmv movie format. Reference: tasvideos.org wiki at
# /EmulatorResources/Gens.
#
# Layout:
#   0x00-0x0F  16  magic "Gens Movie TESTA" (last byte = version letter)
#   0x10-0x13  u32 LE rerecord count
#   0x14       1   ASCII '6' (NTSC) or '5' (PAL)
#   0x15       1   ASCII '3' (3-button pads) or '6' (6-button pads)
#   0x16       1   per-port controller config flags
#   0x18-0x3F  40  ASCII description / savestate name
#   0x40+      controller data, 3 bytes per frame
#
# Per-frame layout (active-low; bit clear == button pressed):
#   byte 0  P1 std buttons:
#     bit 0 Up   bit 1 Down   bit 2 Left   bit 3 Right
#     bit 4 B    bit 5 C      bit 6 A      bit 7 Start
#   byte 1  P2 std buttons (same bit layout)
#   byte 2  6-button extras (only meaningful when 0x15 == '6'):
#     bit 0 P1 Mode  bit 1 P1 X  bit 2 P1 Y  bit 3 P1 Z
#     bit 4 P2 Mode  bit 5 P2 X  bit 6 P2 Y  bit 7 P2 Z

# Bit-index 0..7 in std byte -> 1-based universal slot.
.GMV_STD_BIT_TO_UNI <- c(
  4L,   # bit 0: Up    -> 4
  3L,   # bit 1: Down  -> 3
  2L,   # bit 2: Left  -> 2
  1L,   # bit 3: Right -> 1
  7L,   # bit 4: B     -> 7
  13L,  # bit 5: C     -> 13
  8L,   # bit 6: A     -> 8
  5L    # bit 7: Start -> 5
)

# Bit-index 0..7 in 6-button extras byte -> (player_idx_1based, slot_1based).
.GMV_6B_BIT_TO_PLAYER_SLOT <- list(
  c(1L, 15L),  # bit 0: P1 Mode -> slot 15
  c(1L, 9L),   # bit 1: P1 X    -> slot 9
  c(1L, 10L),  # bit 2: P1 Y    -> slot 10
  c(1L, 14L),  # bit 3: P1 Z    -> slot 14
  c(2L, 15L),  # bit 4: P2 Mode
  c(2L, 9L),   # bit 5: P2 X
  c(2L, 10L),  # bit 6: P2 Y
  c(2L, 14L)   # bit 7: P2 Z
)

#' Read a Gens-rerecording .gmv movie file
#'
#' Genesis controllers map onto universal slots 1..4 (d-pad), 5 (Start),
#' 7/8 (B/A; Genesis has no Select), 9/10 (X/Y), 13 (C), 14 (Z), 15
#' (Mode). Output is 15 buttons wide so every Genesis-relevant column
#' sits at its canonical universal slot.
#'
#' @param path Path to a .gmv file.
#' @return A `replayr_movie` object.
#' @export
read_gmv <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x40L || !identical(data[1:15], charToRaw("Gens Movie TEST"))) {
    stop(path, ": not a GMV file")
  }
  version <- rawToChar(data[16])
  rerec <- .read_u32_le(data, 0x10L)
  fps_char <- rawToChar(data[0x15L])
  pad_char <- rawToChar(data[0x16L])
  is_six_button <- pad_char == "6"
  ctrl_cfg <- as.integer(data[0x17L])
  desc <- .read_cstring(data, 0x18L, 40L)

  body <- data[(0x40L + 1L):length(data)]
  bytes_per_frame <- 3L
  n_frames <- length(body) %/% bytes_per_frame
  n_players <- 2L
  n_buttons <- 15L

  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)

  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      base <- (fi - 1L) * 3L
      b0 <- as.integer(body[base + 1L])
      b1 <- as.integer(body[base + 2L])
      b2 <- as.integer(body[base + 3L])
      for (bit in 0:7) {
        # active-low: bit clear means pressed
        if (bitwAnd(b0, bitwShiftL(1L, bit)) == 0L) {
          inputs[fi, 1L, .GMV_STD_BIT_TO_UNI[bit + 1L]] <- TRUE
        }
        if (bitwAnd(b1, bitwShiftL(1L, bit)) == 0L) {
          inputs[fi, 2L, .GMV_STD_BIT_TO_UNI[bit + 1L]] <- TRUE
        }
      }
      if (is_six_button) {
        for (bit in 0:7) {
          if (bitwAnd(b2, bitwShiftL(1L, bit)) == 0L) {
            ps <- .GMV_6B_BIT_TO_PLAYER_SLOT[[bit + 1L]]
            inputs[fi, ps[1L], ps[2L]] <- TRUE
          }
        }
      }
    }
  }

  header <- list(
    "_format" = "gmv",
    version = version,
    rerecordCount = as.character(rerec),
    fps = fps_char,
    padType = pad_char,
    ctrlConfig = as.character(ctrl_cfg),
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
