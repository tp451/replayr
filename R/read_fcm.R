# FCEU .fcm movie format. Predecessor to .fm2. Reference:
# https://tasvideos.org/EmulatorResources/FCEU/FCM
#
# Versions 1 and 2 share the first 32 header bytes and input encoding.
# Version 1 stores UCS-2 metadata after byte 32, not the v2 ROM fields.
#
# Header (>= 56 bytes):
#   0x00  4   magic "FCM\x1a"
#   0x04  4   version (1 or 2)
#   0x08  1   flags (bit 1 = reset/power-on, bit 2 = PAL)
#   0x0c  4   number of frames (LE u32)
#   0x10  4   rerecord count (LE u32)
#   0x14  4   length of controller data, bytes (LE u32)
#   0x1c  4   controller data offset (LE u32)
#   0x20 16   ROM MD5
#   0x30  4   emulator version (LE u32)
#   0x34  ?   ROM filename (UTF-8, NUL-terminated)
#
# Body: variable-length records. Each record starts with a "ub" byte:
#   bit 7      command flag (1 = command record, 0 = button toggle)
#   bits 6..5  size of the following delta field (0..3 bytes)
#   bits 4..3  player index (0..3, button records only)
#   bits 2..0  button index (0..7, button records only)
# When the command flag is set, bits 0..4 are a command code (1=reset,
# 2=power; higher format-defined codes also occur). The delta is the WAIT
# BEFORE this record's change, as implemented by FCEUX _addjoy():
# https://github.com/TASEmulators/fceux/blob/master/src/oldmovie.cpp
# Its <=0.98.10 compatibility rule consumes an extra delta byte when a
# one- or two-byte delta is zero. Omitting it desynchronises later records.
# 0-based FCM button slot -> 1-based private decoder slot.
.FCM_BTN_TO_UNI <- c(
  8L, # 0: A      -> slot 8
  7L, # 1: B      -> slot 7
  6L, # 2: Select -> slot 6
  5L, # 3: Start  -> slot 5
  4L, # 4: Up     -> slot 4
  3L, # 5: Down   -> slot 3
  2L, # 6: Left   -> slot 2
  1L # 7: Right  -> slot 1
)
# Expand FCM button-toggle events into per-frame states. Command events
# share the delta stream and are retained separately from button states.
.decode_fcm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 32L || !identical(data[1:4], charToRaw("FCM\x1a"))) {
    stop(path, ": not an FCM file")
  }
  version <- .read_u32_le(data, 4L)
  if (!version %in% c(1L, 2L)) stop(path, ": unsupported FCM version ", version)
  flags <- as.integer(data[9L])
  is_pal <- bitwAnd(flags, 0x04L) != 0L
  n_frames <- .read_u32_le(data, 12L)
  rerec <- .read_u32_le(data, 16L)
  ctrl_len <- .read_u32_le(data, 20L)
  ctrl_off <- .read_u32_le(data, 28L)
  min_header <- if (version == 1L) 32L else 56L
  if (length(data) < min_header || ctrl_off < min_header || ctrl_off > length(data)) {
    stop(path, ": invalid or truncated FCM controller-data range")
  }
  available_len <- min(ctrl_len, length(data) - ctrl_off)
  # Validate every record boundary independently of the requested output
  # length. An overstated byte count is recoverable only when complete
  # physical records already cover the entire declared movie duration.
  scan <- ctrl_off + 1L
  stream_end <- ctrl_off + available_len
  covered <- 0
  terminal_delta_bytes <- 0L
  legacy_delta_extensions <- 0L
  while (scan <= stream_end) {
    nd <- bitwAnd(bitwShiftR(as.integer(data[scan]), 5L), 3L)
    scan <- scan + 1L
    if (scan + nd - 1L > length(data)) stop(path, ': truncated FCM delta record')
    delta <- if (nd) sum(as.integer(data[scan + seq_len(nd) - 1L]) * 256^(seq_len(nd) - 1L)) else 0
    if (nd %in% c(1L, 2L) && delta == 0) {
      nd <- nd + 1L
      if (scan + nd - 1L > length(data)) stop(path, ': truncated FCM legacy delta extension')
      delta <- as.integer(data[scan + nd - 1L]) * 256^(nd - 1L)
      legacy_delta_extensions <- legacy_delta_extensions + 1L
    }
    if (scan + nd - 1L > stream_end) {
      # Some headers stop inside the last delta while its remaining bytes
      # are present in the file. Use only that complete record, and only
      # when it exactly completes the declared duration. Do not consume
      # unrelated stale bytes after the declared movie stream.
      if (covered + delta != n_frames) stop(path, ': FCM boundary delta does not complete declared duration')
      terminal_delta_bytes <- scan + nd - 1L - stream_end
      stream_end <- scan + nd - 1L
      warning(path, ': FCM byte range ends inside a complete final delta; using ', terminal_delta_bytes,
        ' additional recorded byte(s)',
        call. = FALSE
      )
    }
    covered <- covered + delta
    scan <- scan + nd
  }
  if (available_len < ctrl_len) {
    if (covered < n_frames) stop(path, ': truncated FCM stream does not cover declared duration')
    warning(path, ': FCM byte count exceeds available data, but complete records cover the declared duration', call. = FALSE)
  }
  md5 <- if (version == 2L) paste(sprintf("%02x", as.integer(data[33:48])), collapse = "") else NA_character_
  emu_ver <- if (version == 2L) .read_u32_le(data, 48L) else NA_integer_
  rom_name <- if (version == 2L) .read_cstring(data, 0x34L, max(0L, length(data) - 0x34L)) else NA_character_
  header <- list(
    "_format" = "fcm",
    version = as.character(version),
    palFlag = if (is_pal) "1" else "0",
    rerecordCount = as.character(rerec),
    romFilename = rom_name,
    emuVersion = as.character(emu_ver),
    romChecksum = md5
  )
  header$declaredControllerBytes <- as.character(ctrl_len)
  header$availableControllerBytes <- as.character(available_len)
  header$completeRecordDuration <- as.character(covered)
  header$terminalDeltaBytesBeyondHeader <- as.character(terminal_delta_bytes)
  header$legacyDeltaExtensions <- as.character(legacy_delta_extensions)
  n_players <- 4L
  if (n_frames <= 0L) {
    return(.new_movie(
      header = header,
      commands = integer(0),
      inputs = .empty_inputs(0L, n_players, 8L),
      source_path = path,
      button_mnemonics = .NES_BUTTONS,
      button_names = c(
        "Right", "Left", "Down", "Up",
        "Start", "Select", "B", "A"
      )
    ))
  }
  inputs <- .empty_inputs(n_frames, n_players, 8L)
  commands <- integer(n_frames)
  cur_state <- matrix(FALSE, nrow = n_players, ncol = 8L)
  cur_command <- 0L
  pos <- ctrl_off + 1L # 1-based pointer into `data`
  end <- stream_end
  frame <- 0L
  data_len <- length(data)
  while (pos <= end && frame < n_frames) {
    ub <- as.integer(data[pos])
    pos <- pos + 1L
    delta_n <- bitwAnd(bitwShiftR(ub, 5L), 0x03L)
    delta <- 0L
    if (delta_n > 0L) {
      for (i in 0:(delta_n - 1L)) {
        if (pos + i > data_len) break
        delta <- bitwOr(delta, bitwShiftL(as.integer(data[pos + i]), i * 8L))
      }
      pos <- pos + delta_n
    }
    if (delta_n %in% c(1L, 2L) && delta == 0L) {
      delta <- as.integer(data[pos]) * 256^delta_n
      pos <- pos + 1L
    }
    # Keep the OLD state during this event's waiting interval. Zero-delta
    # changes are simultaneous and are all applied before emitting a frame.
    if (delta > 0L) {
      stop_frame <- min(frame + delta, n_frames)
      if (stop_frame > frame) {
        for (f in (frame + 1L):stop_frame) inputs[f, , ] <- cur_state
      }
      commands[frame + 1L] <- cur_command
      cur_command <- 0L
      frame <- stop_frame
    }
    if (frame >= n_frames) break
    if (bitwAnd(ub, 0x80L) != 0L) {
      cmd <- bitwAnd(ub, 0x1fL)
      if (cmd >= 1L && cmd <= 31L) {
        cur_command <- bitwOr(cur_command, bitwShiftL(1L, cmd - 1L))
      }
    } else {
      player <- bitwAnd(bitwShiftR(ub, 3L), 0x03L) + 1L # 1-based
      btn <- bitwAnd(ub, 0x07L) # 0-based
      uni_idx <- .FCM_BTN_TO_UNI[btn + 1L]
      cur_state[player, uni_idx] <- !cur_state[player, uni_idx]
    }
  }
  while (frame < n_frames) {
    inputs[frame + 1L, , ] <- cur_state
    commands[frame + 1L] <- cur_command
    cur_command <- 0L
    frame <- frame + 1L
  }
  mv <- .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    button_mnemonics = .NES_BUTTONS,
    button_names = c(
      "Right", "Left", "Down", "Up",
      "Start", "Select", "B", "A"
    )
  )
  mv$source_path <- path
  mv
}
