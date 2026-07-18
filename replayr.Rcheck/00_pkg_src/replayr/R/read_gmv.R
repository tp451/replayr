# Gens-rerecording .gmv movie format. Reference: tasvideos.org wiki at
# /EmulatorResources/Gens.
#
# Layout:
#   0x00-0x0F  16  magic "Gens Movie TESTA" (last byte = version letter)
#   0x10-0x13  u32 LE rerecord count
#   0x14       1   P1 pad type: ASCII '3' or '6'
#   0x15       1   P2 pad type: ASCII '3' or '6'
#   0x16       1   flags (bit 7 PAL, bit 5 three-player mode)
#   0x18-0x3F  40  ASCII description / savestate name
#   0x40+      controller data, 3 bytes per frame
#
# Per-frame layout (active-low; bit clear == button pressed):
#   byte 0  P1 std buttons:
#     bit 0 Up   bit 1 Down   bit 2 Left   bit 3 Right
#     bit 4 A    bit 5 B      bit 6 C      bit 7 Start
#   byte 1  P2 std buttons (same bit layout)
#   byte 2  two-player mode: P1/P2 6-button extras
#     bit 0 P1 X     bit 1 P1 Y     bit 2 P1 Z     bit 3 P1 Mode
#     bit 4 P2 X     bit 5 P2 Y     bit 6 P2 Z     bit 7 P2 Mode
#           three-player mode: P3 standard buttons (same as bytes 0/1)

# Bit-index 0..7 in std byte -> 1-based universal slot.
# The universal schema uses the Genesis A/B/C buttons in slots 8/7/13.
.GMV_STD_BIT_TO_UNI <- c(
  4L,   # bit 0: Up                     -> 4
  3L,   # bit 1: Down                   -> 3
  2L,   # bit 2: Left                   -> 2
  1L,   # bit 3: Right                  -> 1
  8L,   # bit 4: A                      -> 8
  7L,   # bit 5: B                      -> 7
  13L,  # bit 6: C                      -> 13
  5L    # bit 7: Start                  -> 5
)

# Bit-index 0..7 in 6-button extras byte -> (player_idx_1based, slot_1based).
.GMV_6B_BIT_TO_PLAYER_SLOT <- list(
  c(1L, 9L),   # bit 0: P1 X
  c(1L, 10L),  # bit 1: P1 Y
  c(1L, 14L),  # bit 2: P1 Z
  c(1L, 15L),  # bit 3: P1 Mode
  c(2L, 9L),   # bit 4: P2 X
  c(2L, 10L),  # bit 5: P2 Y
  c(2L, 14L),  # bit 6: P2 Z
  c(2L, 15L)   # bit 7: P2 Mode
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
  p1_pad <- rawToChar(data[0x15L])
  p2_pad <- rawToChar(data[0x16L])
  flags <- as.integer(data[0x17L])
  if (!(p1_pad %in% c("3", "6")) || !(p2_pad %in% c("3", "6"))) {
    stop(path, ": unsupported GMV controller type")
  }
  is_three_player <- bitwAnd(flags, 0x20L) != 0L
  is_pal <- bitwAnd(flags, 0x80L) != 0L
  desc <- .read_cstring(data, 0x18L, 40L)

  body <- if (length(data) > 0x40L) data[(0x40L + 1L):length(data)] else raw(0)
  bytes_per_frame <- 3L
  if (length(body) %% bytes_per_frame != 0L) {
    stop(path, ": GMV controller stream has a partial final frame")
  }
  n_frames <- length(body) %/% bytes_per_frame
  n_players <- if (is_three_player) 3L else 2L
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
      if (is_three_player) {
        for (bit in 0:7) {
          if (bitwAnd(b2, bitwShiftL(1L, bit)) == 0L) {
            inputs[fi, 3L, .GMV_STD_BIT_TO_UNI[bit + 1L]] <- TRUE
          }
        }
      } else {
        for (bit in 0:7) {
          if (bitwAnd(b2, bitwShiftL(1L, bit)) == 0L) {
            ps <- .GMV_6B_BIT_TO_PLAYER_SLOT[[bit + 1L]]
            pad_type <- if (ps[1L] == 1L) p1_pad else p2_pad
            if (pad_type == "6") inputs[fi, ps[1L], ps[2L]] <- TRUE
          }
        }
      }
    }
  }

  header <- list(
    "_format" = "gmv",
    version = version,
    rerecordCount = as.character(rerec),
    fps = if (is_pal) "50" else "60",
    p1PadType = p1_pad,
    p2PadType = p2_pad,
    threePlayer = as.character(is_three_player),
    flags = sprintf("0x%02x", flags),
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
