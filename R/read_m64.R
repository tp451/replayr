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
#   0x0E4-0x0E7  CRC1 of the ROM header, in the ROM's byte order
#   0x0E8        country code of the ROM (ASCII, such as E or J)
#   0x0E9        version of the ROM
#   0x222-0x2FF  author (UTF-8)
#   0x300-0x3FF  description (256 bytes)
#   0x400+       input data: 4 bytes per input sample
#
# Per-input layout (4 bytes; game-defined controller polling order):
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
#   byte 2  signed int8  analogue stick X
#   byte 3  signed int8  analogue stick Y (+Y == up)
#
# Public readers retain stick coordinates by default and apply the requested
# representation through the shared controller-layout code.
# Bit 0..7 in byte 0 (low) -> 1-based private decoder slot.
.M64_LOW_BIT_TO_UNI <- c(
  1L, # bit 0: D-pad Right
  2L, # bit 1: D-pad Left
  3L, # bit 2: D-pad Down
  4L, # bit 3: D-pad Up
  5L, # bit 4: Start
  14L, # bit 5: Z
  7L, # bit 6: B
  8L # bit 7: A
)
# Bit 0..7 in byte 1 (high) -> 1-based private decoder slot, NA for reserved.
.M64_HIGH_BIT_TO_UNI <- c(
  17L, # bit 0: C-Right
  18L, # bit 1: C-Left
  19L, # bit 2: C-Down
  20L, # bit 3: C-Up
  12L, # bit 4: R-shoulder
  11L, # bit 5: L-shoulder
  NA_integer_, # bit 6: reserved
  NA_integer_ # bit 7: reserved
)
# Decode polls in file order. An explicit controller order groups polls
# into cycles; otherwise multiple enabled ports remain unassigned.
.decode_m64 <- function(path, controller_order = NULL) {
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
  controller_flags <- .read_u32_le(data, 0x20L)
  enabled_ports <- which(bitwAnd(as.integer(data[0x21L]), bitwShiftL(1L, 0:3)) != 0L)
  if (n_ctrl < 1L || n_ctrl > 4L) {
    stop(path, ": invalid M64 controller count ", n_ctrl)
  }
  if (length(enabled_ports) != n_ctrl) {
    stop(path, ": M64 controller count disagrees with the enabled-port flags")
  }
  supplied_order <- !is.null(controller_order)
  unassigned <- n_ctrl > 1L && !supplied_order
  if (supplied_order && (!is.numeric(controller_order) ||
    !length(controller_order) || anyNA(controller_order) ||
    any(!is.finite(controller_order)) ||
    any(!controller_order %in% enabled_ports) || anyDuplicated(controller_order))) {
    stop(path, ": controller_order must list distinct enabled ports in their repeating polling order")
  }
  if (!supplied_order) controller_order <- if (unassigned) integer() else enabled_ports
  controller_order <- as.integer(controller_order)
  controller_ports <- sort(controller_order)
  body <- if (length(data) > 0x400L) data[(0x400L + 1L):length(data)] else raw(0)
  sample_size <- 4L
  have_samples <- length(body) %/% sample_size
  # Mupen64 playback stops at length_samples, including when it is zero.
  # Historical flush_movie writes one extra record and rewrites the file without
  # truncating an older suffix. Those bytes do not extend the playback stream.
  # TASEmulators/mupen64-rr f27a689083c6fdee55801062a46fed25e6496a84,
  # main/vcr.c: flush_movie, truncateMovie, and VCR_getKeys.
  if (n_samples_field > have_samples && length(body) %% sample_size) {
    stop(path, ": partial final M64 input sample within the declared stream")
  }
  if (n_samples_field > have_samples) {
    stop(sprintf(
      "%s: M64 input stream is truncated (header=%d samples, file=%d)",
      path, n_samples_field, have_samples
    ))
  }
  n_samples <- n_samples_field
  used_bytes <- n_samples * sample_size
  source_tail <- if (length(body) > used_bytes) body[seq.int(used_bytes + 1L, length(body))] else raw()
  if (length(controller_order) && n_samples %% length(controller_order)) {
    stop(path, ": incomplete caller-supplied controller cycle")
  }
  n_frames <- n_samples
  n_players <- 1L
  n_buttons <- 28L
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  analog_values <- .empty_analog(n_frames, n_players, c("lstick_x", "lstick_y"))
  poll_bytes <- matrix(body[seq_len(n_samples * sample_size)],
    ncol = sample_size,
    byrow = TRUE, dimnames = list(NULL, paste0("byte", 0:3))
  )
  if (n_samples > 0L) {
    low <- as.integer(poll_bytes[, 1L])
    high <- as.integer(poll_bytes[, 2L])
    sx <- as.integer(poll_bytes[, 3L])
    sy <- as.integer(poll_bytes[, 4L])
    sx[sx >= 128L] <- sx[sx >= 128L] - 256L
    sy[sy >= 128L] <- sy[sy >= 128L] - 256L
    analog_values[[1L]][, ] <- cbind(sx, sy)
    # Both reserved button bits set are Mupen64's reset marker.
    commands <- as.integer(bitwAnd(high, 0xc0L) == 0xc0L)
    for (bit in 0:7) {
      inputs[, 1L, .M64_LOW_BIT_TO_UNI[bit + 1L]] <- bitwAnd(low, bitwShiftL(1L, bit)) != 0L
      slot <- .M64_HIGH_BIT_TO_UNI[bit + 1L]
      if (!is.na(slot)) inputs[, 1L, slot] <- bitwAnd(high, bitwShiftL(1L, bit)) != 0L
    }
  }
  if (length(controller_order) > 1L) {
    poll_inputs <- inputs
    poll_commands <- commands
    poll_analog <- analog_values[[1L]]
    n_frames <- n_samples %/% length(controller_order)
    inputs <- .empty_inputs(n_frames, length(controller_ports), n_buttons)
    analog_values <- .empty_analog(n_frames, length(controller_ports), c("lstick_x", "lstick_y"))
    commands <- integer(n_frames)
    for (j in seq_along(controller_order)) {
      rows <- if (n_frames) seq.int(j, n_samples, by = length(controller_order)) else integer()
      player_index <- match(controller_order[j], controller_ports)
      inputs[, player_index, ] <- poll_inputs[rows, 1L, , drop = FALSE]
      analog_values[[player_index]] <- poll_analog[rows, , drop = FALSE]
      commands <- bitwOr(commands, poll_commands[rows])
    }
  }
  rom_name <- .read_cstring(data, 0x0C4L, 32L)
  # Mupen64 copies the country code and the version byte that follows it in
  # the ROM header; a file without a country code leaves both empty.
  country <- as.integer(data[0x0E9L])
  has_country <- country > 0x20L && country < 0x7FL
  author <- .read_cstring(data, 0x222L, 222L)
  header <- list(
    "_format" = "m64",
    version = as.character(version),
    uid = as.character(uid),
    rerecordCount = as.character(rerec),
    fps = as.character(fps),
    controllerCount = as.character(n_ctrl),
    viCount = as.character(vi_count),
    inputSampleCount = as.character(n_samples),
    declaredInputSampleCount = as.character(n_samples_field),
    availableInputSampleCount = as.character(have_samples),
    sourceTailBytes = as.character(length(source_tail)),
    sourceTailRole = "bytes beyond the declared playback samples",
    controllerFlags = as.character(controller_flags),
    enabledPorts = as.integer(enabled_ports),
    controllerPorts = as.integer(controller_ports),
    controllerOrder = paste(controller_order, collapse = ","),
    controllerAssignment = if (unassigned) "unassigned" else if (supplied_order)
      "caller-supplied repeating order; not stored in M64" else "single enabled controller",
    observationUnit = if (length(controller_order) > 1L) "controller polling cycle" else "controller poll",
    romName = rom_name,
    romHeaderCRC = .hex_bytes(data, 0x0E4L, 4L),
    romCountry = if (has_country) intToUtf8(country) else "",
    romVersion = if (has_country) as.character(as.integer(data[0x0EAL])) else "",
    author = author
  )
  mv <- .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    analog = analog_values,
    button_mnemonics = .legacy_buttons()[seq_len(n_buttons)],
    button_names = .legacy_button_names()[seq_len(n_buttons)]
  )
  mv$source_path <- path
  mv$poll_bytes <- poll_bytes
  mv$source_tail <- source_tail
  mv
}
