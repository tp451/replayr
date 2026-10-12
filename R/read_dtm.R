# Sources / attribution:
#
# This reader was developed with reference to Dolphin Emulator's
# `Source/Core/Core/Movie.cpp` (the .dtm format encoder/decoder),
# alongside the TASVideos wiki at /EmulatorResources/Tools/Dolphin.
#
#   Source:    https://github.com/dolphin-emu/dolphin
#   License:   GPL v2 or later
#
# Zelda Edition's extended records are specified in Movie.h at:
# https://github.com/dragonbane0/dolphin/blob/
# a6e66c227c592d09ff09ef9b238d15ff52dd9632/Source/Core/Core/Movie.h
# The extension adds tunerEvent (u8), LinkX and LinkZ (little-endian float32),
# and uses bit 14 for loading instead of the later connection flag.
# See inst/COPYRIGHTS for the full provenance manifest.
#
# Dolphin .dtm GameCube movie format; Wii device reports dispatch to read_wii_dtm.R.
# Reference: Dolphin source (Source/Core/Core/Movie.cpp) and the tasvideos
# wiki at /EmulatorResources/Tools/Dolphin.
#
# Layout (v1):
#   0x00-0x03  4   magic "DTM\x1A"
#   0x04-0x09  6   ROM ID (e.g. "G4BJ")
#   0x0A       1   bWii flag
#   0x0B       1   numControllers (lower 4 bits = GC ports polled)
#   0x0D       u64 frameCount  (game-side VI counter)
#   0x15       u64 inputCount  (emulator input statistic; may differ from body count)
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
# Bit-index 0..15 in the GC button word -> 1-based private decoder slot. Order is the
# Dolphin .dtm PACKED ControllerState bitfield (Start,A,B,X,Y,Z,DPadUp,DPadDown,
# DPadLeft,DPadRight,L,R,...). This differs from GCPadStatus.button, whose constants would
# shift ordinary face-button presses onto unrelated slots.
.DTM_BIT_TO_UNI <- c(
  5L, # bit 0:  Start       -> 5
  8L, # bit 1:  A           -> 8
  7L, # bit 2:  B           -> 7
  9L, # bit 3:  X           -> 9
  10L, # bit 4:  Y           -> 10
  14L, # bit 5:  Z           -> 14
  4L, # bit 6:  D-Up        -> 4
  3L, # bit 7:  D-Down      -> 3
  2L, # bit 8:  D-Left      -> 2
  1L, # bit 9:  D-Right     -> 1
  11L, # bit 10: L-digital   -> 11
  12L, # bit 11: R-digital   -> 12
  NA_integer_, NA_integer_, NA_integer_, NA_integer_ # bits 12-15: disc/reset/is_connected/get_origin
)
.DTM_STICK_DEADZONE <- 16L
# Internal legacy slots for C-stick sectors (E, NE, N, NW, W, SW, S, SE).
# Public layout configuration replaces these with right-stick controls;
# original X/Y channels remain available for either stick.
.DTM_CSTICK_SECTOR_TO_CSLOT <- c(
  17L, # E   -> C-Right
  17L, # NE  -> C-Right
  20L, # N   -> C-Up
  18L, # NW  -> C-Left
  18L, # W   -> C-Left
  18L, # SW  -> C-Left
  19L, # S   -> C-Down
  17L # SE  -> C-Right
)
# Decode GameCube polls or dispatch Wii and mixed-device reports.
# Public stick representations are applied after the source values are decoded.
.decode_dtm <- function(path, controller_order = NULL, analog = c("raw", "quantized"),
                        dtm_variant = c("auto", "standard", "zelda"),
                        wii_variant = "auto", wii_extension = "raw", wii_key = NULL) {
  analog <- match.arg(analog)
  dtm_variant <- match.arg(dtm_variant)
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x100L || !identical(data[1:4], charToRaw("DTM\x1A"))) {
    stop(path, ": not a DTM file")
  }
  rom_id <- rawToChar(data[5:10])
  Encoding(rom_id) <- "latin1"
  rom_id <- enc2utf8(rom_id)
  is_wii <- as.integer(data[0x0BL]) != 0L
  if (bitwAnd(as.integer(data[12L]), 240L))
    return(.decode_wii_dtm(path, data, controller_order, wii_variant, wii_extension, wii_key))
  frame_count <- .read_u64_le(data, 0x0DL)
  input_count <- .read_u64_le(data, 0x15L)
  rerec <- .read_u32_le(data, 0x2DL)
  ctrl_mask <- as.integer(data[0x0CL])
  n_gc_ports <- sum(bitwAnd(bitwAnd(ctrl_mask, 0x0FL), bitwShiftL(1L, 0:3)) != 0L)
  if (n_gc_ports == 0L) stop(path, ": DTM declares no GameCube controllers")
  # DTM records controller polls sequentially and does not tag them with a port
  # number. Games need not poll every connected port once per frame, so fixed
  # grouping would silently assign records to the wrong players.
  enabled_ports <- which(bitwAnd(ctrl_mask, bitwShiftL(1L, 0:3)) != 0L)
  unassigned <- n_gc_ports > 1L && is.null(controller_order)
  supplied_order <- !is.null(controller_order)
  if (is.null(controller_order)) controller_order <- if (unassigned) integer() else enabled_ports
  if (!unassigned && (!is.numeric(controller_order) || anyNA(controller_order) ||
    any(controller_order != as.integer(controller_order)) ||
    anyDuplicated(controller_order) ||
    !identical(sort(as.integer(controller_order)), as.integer(enabled_ports))))
    stop(path, ': controller_order must list every enabled port exactly once')
  controller_order <- as.integer(controller_order)
  body <- if (length(data) > 0x100L) data[(0x100L + 1L):length(data)] else raw(0)
  revision <- paste(sprintf("%02x", as.integer(data[210:229])), collapse = "")
  # DTM has no record-size field. Recognise the source-verified Zelda Edition
  # revision, or let the caller identify another build using the same layout.
  # Inferring a layout from divisibility alone would misread valid standard data.
  if (dtm_variant == "auto") {
    dtm_variant <- if (revision == "a6e66c227c592d09ff09ef9b238d15ff52dd9632") "zelda" else "standard"
  }
  bytes_per_frame <- if (dtm_variant == "zelda") 17L else 8L
  have_frames <- length(body) %/% bytes_per_frame
  if (length(body) %% bytes_per_frame) {
    stop(
      path, ': partial final DTM poll for ', dtm_variant, ' layout (',
      bytes_per_frame, ' bytes per poll)'
    )
  }
  # Dolphin saves the input statistic and byte buffer independently. Playback
  # uses byte/frame/tick boundaries, rather than this statistic as a record count.
  # Retain every complete stored poll and expose the count difference as metadata.
  difference <- input_count - have_frames
  n_frames <- have_frames
  if (length(controller_order) && n_frames %% length(controller_order))
    stop(path, ': incomplete caller-supplied controller cycle')
  # Raw imports need only the physical button slots. Direction slots are used
  # exclusively by the private legacy projection path.
  n_buttons <- if (analog == "raw") 14L else 28L
  inputs <- .empty_inputs(n_frames, 1L, n_buttons)
  commands <- integer(n_frames)
  channels <- c("ltrigger", "rtrigger", "lstick_x", "lstick_y", "rstick_x", "rstick_y")
  # Every channel is an unsigned source byte; integers retain those values
  # exactly while using half the memory of a double matrix.
  numeric_channels <- matrix(0L,
    nrow = n_frames, ncol = length(channels),
    dimnames = list(NULL, channels)
  )
  poll_fields <- if (dtm_variant == "zelda") {
    data.frame(
      loading = logical(n_frames), tuner_event = integer(n_frames),
      link_x = numeric(n_frames), link_z = numeric(n_frames)
    )
  } else NULL
  if (n_frames > 0L) {
    # Bound temporary byte/bit matrices independently of recording length.
    chunk_size <- 65536L
    for (first in seq.int(1L, n_frames, by = chunk_size)) {
      last <- min(first + chunk_size - 1L, n_frames)
      rows <- seq.int(first, last)
      bytes <- body[seq.int((first - 1L) * bytes_per_frame + 1L, last * bytes_per_frame)]
      records <- matrix(as.integer(bytes), ncol = bytes_per_frame, byrow = TRUE)
      word <- records[, 1L] + bitwShiftL(records[, 2L], 8L)
      for (bit in 0:11) {
        slot <- .DTM_BIT_TO_UNI[bit + 1L]
        if (is.na(slot)) next
        inputs[rows, 1L, slot] <- bitwAnd(word, bitwShiftL(1L, bit)) != 0L
      }
      commands[rows] <- bitwAnd(bitwShiftR(word, 12L), 3L)
      numeric_channels[rows, ] <- records[, 3:8, drop = FALSE]
      if (dtm_variant == "zelda") {
        poll_fields$loading[rows] <- bitwAnd(word, 16384L) != 0L
        poll_fields$tuner_event[rows] <- records[, 9L]
        poll_fields$link_x[rows] <- readBin(as.raw(t(records[, 10:13, drop = FALSE])),
          "double",
          n = length(rows), size = 4L,
          endian = "little"
        )
        poll_fields$link_z[rows] <- readBin(as.raw(t(records[, 14:17, drop = FALSE])),
          "double",
          n = length(rows), size = 4L,
          endian = "little"
        )
      }
      if (analog == "quantized") {
        inputs[rows, 1L, 11L] <- inputs[rows, 1L, 11L] | records[, 3L] >= 128L
        inputs[rows, 1L, 12L] <- inputs[rows, 1L, 12L] | records[, 4L] >= 128L
        for (stick in c(5L, 7L)) {
          x <- records[, stick] - 128L
          y <- records[, stick + 1L] - 128L
          active <- which(x * x + y * y >= .DTM_STICK_DEADZONE^2)
          if (!length(active)) next
          sector <- as.integer((atan2(y[active], x[active]) + pi / 8) %/% (pi / 4)) %% 8L
          slots <- if (stick == 5L) .STICK_SECTOR_TO_UNI else .DTM_CSTICK_SECTOR_TO_CSLOT
          inputs[cbind(rows[active], 1L, slots[sector + 1L])] <- TRUE
        }
      }
    }
  }
  analog_values <- list(numeric_channels)
  if (length(controller_order) > 1L) {
    polls <- inputs
    poll_commands <- commands
    poll_analog <- analog_values[[1L]]
    cycles <- n_frames %/% length(controller_order)
    inputs <- .empty_inputs(cycles, max(controller_order), n_buttons)
    commands <- integer(cycles)
    analog_values <- .empty_analog(cycles, max(controller_order))
    for (j in seq_along(controller_order)) {
      ix <- if (cycles) seq.int(j, n_frames, by = length(controller_order)) else integer()
      analog_values[[controller_order[j]]] <- poll_analog[ix, , drop = FALSE]
    }
    if (cycles > 0L) for (j in seq_along(controller_order)) {
      ix <- seq.int(j, n_frames, by = length(controller_order))
      inputs[, controller_order[j], ] <- polls[ix, 1, , drop = FALSE]
      commands <- bitwOr(commands, poll_commands[ix])
    }
  }
  header <- list(
    "_format" = "dtm",
    Platform = if (is_wii) "Wii" else "GameCube",
    romId = rom_id,
    rerecordCount = as.character(rerec),
    frameCount = as.character(frame_count),
    inputCount = as.character(input_count),
    inputCountRole = "emulator input statistic",
    availablePollCount = as.character(have_frames),
    pollCountDifference = as.character(difference),
    dtmVariant = dtm_variant,
    bytesPerPoll = as.character(bytes_per_frame),
    revision = revision,
    controllerMask = sprintf("0x%02x", ctrl_mask),
    enabledPorts = as.integer(enabled_ports),
    controllerOrder = paste(controller_order, collapse = ','),
    controllerAssignment = if (unassigned) 'unassigned' else if (supplied_order) 'caller-supplied repeating order; not stored in DTM' else 'single enabled controller'
  )
  mv <- .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    analog = analog_values, analog_mode = analog,
    button_mnemonics = .legacy_buttons()[seq_len(n_buttons)],
    button_names = .legacy_button_names()[seq_len(n_buttons)]
  )
  mv$source_path <- path
  # Retain source order even when the caller groups polls into player cycles.
  mv$poll_bytes <- matrix(body, ncol = bytes_per_frame, byrow = TRUE)
  colnames(mv$poll_bytes) <- paste0("byte", seq_len(bytes_per_frame) - 1L)
  if (!is.null(poll_fields)) mv$poll_fields <- poll_fields
  mv
}
