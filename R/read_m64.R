# Mupen64 / Mupen64-rerecording .m64 movie format. Reference: tasvideos.org
# wiki at /EmulatorResources/Mupen/M64.
#
# Layout (version 3):
#   0x000-0x003  4   magic "M64\x1A"
#   0x004-0x007  u32 version (==3)
#   0x008-0x00B  u32 movie UID
#   0x00C-0x00F  u32 number of vertical interrupts
#   0x010-0x013  u32 rerecord count
#   0x014        u8  VI per second (60 NTSC / 50 PAL)
#   0x015        u8  controller count
#   0x018-0x01B  u32 number of input samples
#   0x0C4-0x0E3  ROM internal name (32 bytes ASCII, NUL-padded)
#   0x222-0x2FF  author (UTF-8)
#   0x300-0x3FF  description (256 bytes)
#   0x400+       input data: 4 bytes per input sample
#
# Per-input layout (4 bytes; controller 1 first):
#   byte 0  buttons low:
#       bit 0: D-pad Right    bit 1: D-pad Left
#       bit 2: D-pad Down     bit 3: D-pad Up
#       bit 4: Start          bit 5: Z
#       bit 6: B              bit 7: A
#   byte 1  buttons high:
#       bit 0: C-Right        bit 1: C-Left
#       bit 2: C-Down         bit 3: C-Up
#       bit 4: R-shoulder     bit 5: L-shoulder
#       bits 6-7: reserved
#   byte 2  signed int8  analog stick X
#   byte 3  signed int8  analog stick Y (+Y == up)
#
# Analog stick is quantised to 8 directions and routed to slots 21..28
# (E, NE, N, NW, W, SW, S, SE in order).

# Bit 0..7 in byte 0 (low) -> 1-based universal slot.
.M64_LOW_BIT_TO_UNI <- c(
  1L,   # bit 0: D-pad Right
  2L,   # bit 1: D-pad Left
  3L,   # bit 2: D-pad Down
  4L,   # bit 3: D-pad Up
  5L,   # bit 4: Start
  14L,  # bit 5: Z
  7L,   # bit 6: B
  8L    # bit 7: A
)

# Bit 0..7 in byte 1 (high) -> 1-based universal slot, NA for reserved.
.M64_HIGH_BIT_TO_UNI <- c(
  17L,            # bit 0: C-Right
  18L,            # bit 1: C-Left
  19L,            # bit 2: C-Down
  20L,            # bit 3: C-Up
  12L,            # bit 4: R-shoulder
  11L,            # bit 5: L-shoulder
  NA_integer_,    # bit 6: reserved
  NA_integer_     # bit 7: reserved
)

# Sector -> 1-based universal slot in (E, NE, N, NW, W, SW, S, SE) order.
.STICK_SECTOR_TO_UNI <- c(21L, 22L, 23L, 24L, 25L, 26L, 27L, 28L)

# Magnitude threshold below which the stick is treated as neutral.
.M64_STICK_DEADZONE <- 16L

#' Read a Mupen64 .m64 movie file
#'
#' The N64 controller has 14 buttons + an analog stick. Buttons map onto
#' universal slots 1..14 (with C-buttons at 17..20); the analog stick is
#' quantised to 8 directions and routed to slots 21..28. Output is 28
#' buttons wide. Stick deflections below ~12.5% magnitude are treated
#' as neutral. Multi-controller M64 streams are rejected because the format
#' does not store controller identifiers: samples occur in the order the game
#' polls its connected controllers, which cannot be reconstructed reliably
#' without running the game.
#'
#' @param path Path to a .m64 file.
#' @return A `replayr_movie` object.
#' @export
read_m64 <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x400L || !identical(data[1:4], charToRaw("M64\x1A"))) {
    stop(path, ": not an M64 file")
  }
  version <- .read_u32_le(data, 4L)
  if (version != 3L) stop(path, ": unsupported M64 version ", version)
  uid <- .read_u32_le(data, 8L)
  vi_count <- .read_u32_le(data, 12L)
  rerec <- .read_u32_le(data, 16L)
  fps <- as.integer(data[0x15L])
  n_ctrl <- as.integer(data[0x16L])
  n_samples_field <- .read_u32_le(data, 0x18L)

  if (n_ctrl < 1L || n_ctrl > 4L) {
    stop(path, ": invalid M64 controller count ", n_ctrl)
  }
  if (n_ctrl != 1L) {
    stop(path, ": multi-controller M64 movies are not supported because ",
         "the input stream does not identify which controller each sample belongs to")
  }

  body <- if (length(data) > 0x400L) data[(0x400L + 1L):length(data)] else raw(0)
  sample_size <- 4L
  have_samples <- length(body) %/% sample_size
  if (n_samples_field > have_samples) {
    stop(sprintf("%s: M64 input stream is truncated (header=%d samples, file=%d)",
                 path, n_samples_field, have_samples))
  }
  n_frames <- if (n_samples_field > 0L) n_samples_field else have_samples

  n_players <- 1L
  n_buttons <- 28L
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  stride <- sample_size

  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- (fi - 1L) * stride
      b_low <- as.integer(body[off + 1L])
      b_high <- as.integer(body[off + 2L])
      sx <- as.integer(body[off + 3L])
      sy <- as.integer(body[off + 4L])
      if (sx >= 0x80L) sx <- sx - 0x100L
      if (sy >= 0x80L) sy <- sy - 0x100L

      # Both reserved button bits set are Mupen64's reset marker.
      if (bitwAnd(b_high, 0xC0L) == 0xC0L) commands[fi] <- 1L

      for (bit in 0:7) {
        if (bitwAnd(b_low, bitwShiftL(1L, bit)) != 0L) {
          inputs[fi, 1L, .M64_LOW_BIT_TO_UNI[bit + 1L]] <- TRUE
        }
        if (bitwAnd(b_high, bitwShiftL(1L, bit)) != 0L) {
          slot <- .M64_HIGH_BIT_TO_UNI[bit + 1L]
          if (!is.na(slot)) inputs[fi, 1L, slot] <- TRUE
        }
      }

      mag2 <- sx * sx + sy * sy
      if (mag2 >= .M64_STICK_DEADZONE * .M64_STICK_DEADZONE) {
        angle <- atan2(sy, sx)  # +Y axis = up
        sector <- as.integer((angle + pi / 8) %/% (pi / 4)) %% 8L
        inputs[fi, 1L, .STICK_SECTOR_TO_UNI[sector + 1L]] <- TRUE
      }
    }
  }

  rom_name <- .read_cstring(data, 0x0C4L, 32L)
  author <- .read_cstring(data, 0x222L, 222L)
  header <- list(
    "_format" = "m64",
    version = as.character(version),
    uid = as.character(uid),
    rerecordCount = as.character(rerec),
    fps = as.character(fps),
    controllerCount = as.character(n_ctrl),
    viCount = as.character(vi_count),
    inputSampleCount = as.character(n_frames),
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
