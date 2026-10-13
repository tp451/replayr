# Sources / attribution:
#
# This reader was developed with reference to the PSXjin source
# tree alongside the TASVideos wiki at
# /EmulatorResources/Tools/Psxjin.
#
#   Source:    https://github.com/Nitrofski/psxjin/blob/master/psxjin/movie.cpp
#   License:   GPL v2 or later
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# PSXjin .pjm movie format. Reference: tasvideos.org wiki at
# /EmulatorResources/Tools/Psxjin and the PSXjin source tree.
#
# Header: 4-byte ASCII magic "PJM ", u32 version (==2), a small fixed binary
# header, then ASCII description / platform metadata, optionally followed by
# an embedded savestate (movies recorded "from savestate" carry a full PSX
# state here, which can be large and contains NUL / arbitrary bytes).
#
# Body -- one of several layouts, all version 2:
#
#   TEXT (the common case).  Each frame is one CRLF-terminated line
#
#       <port1>|<port2>|...|<cmd>|\r\n
#
#   where each <port> is a 14-character digital mask (`.` = released, any
#   other glyph = pressed) OPTIONALLY followed by space-padded decimal
#   analogue-stick values (e.g. " 128 127 128 128"). Movies with one
#   controller render an empty second port, giving the historical
#   `<port1>||0|\r\n` (20-byte) line; two-controller movies give
#   `<port1>|<port2>|0|\r\n` (34-byte); analogue movies are wider (52-byte).
#   Header fields specify the body offset and controller widths. Standard
#   ports have 14 button characters; analogue ports have 16 followed by four
#   unsigned axis values. A terminator scan handles incomplete headers.
#
#   BINARY. Header-defined input offset and controller types determine record
#   width: two bytes per standard pad, six per analogue pad, then one command
#   byte. The old five-byte/end-of-file fallback is for legacy synthetic
#   fixtures without a controller-data offset, not ordinary movie parsing.
#
# PSX DualShock 14-button text column order:
#   1 Square  2 Cross  3 Circle  4 Triangle  5 R1  6 L1  7 R2  8 L2
#   9 Left    10 Down  11 Right  12 Up        13 Start  14 Select
#
# Face-button mapping into private decoder slots follows the geometric diamond
# convention used elsewhere: Triangle (top) -> X slot, Square (left) -> Y,
# Cross (bottom) -> B, Circle (right) -> A.
# 1-based PJM text column position -> 1-based private decoder slot.
.PJM_POS_TO_UNI <- c(
  10L, # 1: Square    -> slot 10 (Y face)
  7L, # 2: Cross     -> slot 7 (B)
  8L, # 3: Circle    -> slot 8 (A)
  9L, # 4: Triangle  -> slot 9 (X face)
  12L, # 5: R1        -> slot 12 (R-shoulder)
  11L, # 6: L1        -> slot 11 (L-shoulder)
  30L, # 7: R2        -> slot 30 (PSX R2)
  29L, # 8: L2        -> slot 29 (PSX L2)
  2L, # 9: Left      -> slot 2 (Left)
  3L, # 10: Down     -> slot 3 (Down)
  1L, # 11: Right    -> slot 1 (Right)
  4L, # 12: Up       -> slot 4 (Up)
  5L, # 13: Start    -> slot 5 (Start)
  6L # 14: Select   -> slot 6 (Select)
)
# DualShock 16-bit binary button word (active-high) bit -> private decoder slot.
# Identical to the .pxm mapping, including DualShock stick clicks.
.PJM_BIT_TO_UNI <- c(
  6L, 41L, 42L, 5L, # Select, L3, R3, Start
  4L, 1L, 3L, 2L, # Up, Right, Down, Left
  29L, 30L, 11L, 12L, # L2, R2, L1, R1
  9L, 8L, 7L, 10L # Triangle, Circle, Cross, Square
)
# MOV_ReadMovieFile replaces the header frame count with the complete-record
# count calculated from file length, input offset, and configured record width.
# Keep that behaviour for both text and binary records, retaining the original
# declared count so callers can inspect any discrepancy.
.pjm_record_counts <- function(header, declared, available, path) {
  difference <- declared - available
  header$declaredFrameCount <- as.character(declared)
  header$availableFrameCount <- as.character(available)
  header$frameCountDifference <- as.character(difference)
  header$trailingFrameShortfall <- as.character(max(0, difference))
  # PSXjin replaces this metadata count with the physical record count in
  # MOV_ReadMovieFile. A discrepancy does not make a complete stream invalid.
  header
}
# Decode text or binary input using the header offset and controller
# types. Complete-record counts follow PSXjin playback rules.
.decode_pjm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 24L || !identical(data[1:4], charToRaw("PJM "))) {
    stop(path, ": not a PJM file")
  }
  version <- .read_u32_le(data, 4L)
  if (version != 2L) stop(path, ": unsupported PJM version ", version)
  n_frames_field <- .read_u32_le(data, 16L)
  rerec <- .read_u32_le(data, 20L)
  controller_types <- as.integer(data[c(0x0EL, 0x0FL) + 1L])
  body_off <- if (length(data) >= 0x30L) .read_u32_le(data, 0x2CL) else 0L
  if (body_off != 0L && (body_off < 0x34L || body_off > length(data))) stop(path, ": invalid PJM input offset")
  desc <- .read_cstring(data, 0x39L, 0xC8L)
  sz <- length(data)
  n_buttons <- 42L
  header <- list(
    "_format" = "pjm",
    version = as.character(version),
    rerecordCount = as.character(rerec),
    description = desc,
    controllerType1 = as.character(controller_types[1L]),
    controllerType2 = as.character(controller_types[2L])
  )
  # MOVIE_FLAG_IS_TEXT and SetBytesPerFrame define the ordinary layout.
  # Separator bytes are skipped by PSXjin, so they must not determine whether
  # a declared text movie can be read. Old incomplete headers retain the
  # historical terminator-based fallback below.
  flags <- .read_u16_le(data, 12L)
  # Bit 2 of the movie flags, as in PXM: PAL timing.
  header$isPal <- bitwAnd(flags, 4L) != 0L
  if (body_off > 0L && bitwAnd(flags, 64L) != 0L) {
    types <- rep(controller_types, 1L + 3L * as.integer(bitwAnd(flags, c(128L, 256L)) != 0L))
    widths <- c("0" = 1L, "8" = 1L, "4" = 15L, "5" = 33L, "7" = 33L)[as.character(types)]
    if (anyNA(widths)) stop(path, ": unsupported PJM text controller type")
    if (!any(widths > 1L)) stop(path, ": PJM has no connected controller")
    n_players <- max(which(widths > 1L))
    layout <- list(
      first = body_off, stride = as.integer(sum(widths) + 4L),
      port_off = as.integer(c(0L, utils::head(cumsum(widths), -1L))[seq_len(n_players)]),
      port_width = as.integer(widths[seq_len(n_players)] - 1L),
      pipe = as.integer(c(cumsum(widths), sum(widths) + 2L)),
      n_players = n_players, cmd_off = as.integer(sum(widths)), cmd_width = 1L
    )
  } else {
    term <- as.raw(c(0x7c, 0x0d, 0x0a))
    search_start <- if (body_off > 0L) body_off else 0L
    t1 <- .find_raw(data[seq.int(search_start + 1L, sz)], term)
    if (!is.na(t1)) t1 <- t1 + search_start
    layout <- .pjm_text_layout(data, t1, sz, if (body_off > 0L) body_off else NULL)
  }
  if (!is.null(layout)) {
    mv <- .read_pjm_text(data, layout, n_frames_field, n_buttons, header, path)
  } else {
    mv <- .read_pjm_binary(
      data, n_frames_field, sz, n_buttons, header,
      controller_types, body_off, path
    )
  }
  mv$source_path <- path
  mv
}
# Validate a candidate text body starting near `t1` (0-based offset of the
# first `|`CRLF). Confirms a second terminator at a consistent small stride
# and walks back to the first frame. Returns a list(first, stride, port_off,
# n_players) with 0-based `first` (frame-1 start) and per-player 0-based
# column offsets, or NULL if this is not a coherent text body (e.g. an
# incidental `|`CRLF inside a binary savestate).
.pjm_text_layout <- function(data, t1, sz, body_off = NULL) {
  if (is.na(t1) || t1 < 20L) return(NULL)
  if (!is.null(body_off)) {
    stride <- t1 + 3L - body_off
    if (stride < 8L || stride > 2000L) return(NULL)
    e <- t1
  } else {
    # second terminator within a plausible line-length window. The first
    # terminator occupies 0-based [t1, t1+2]; start the search one byte past it
    # (1-based data index t1+4 == 0-based t1+3) so the recovered stride is exact.
    # Include the file's final CRLF: short synthetic and real two-frame movies
    # may place the second terminator at end-of-file.
    win <- data[(t1 + 4L):min(sz, t1 + 2006L)]
    t2rel <- .find_raw(win, as.raw(c(0x7c, 0x0d, 0x0a)))
    if (is.na(t2rel)) return(NULL)
    stride <- (t1 + 3L + t2rel) - t1
    if (stride < 8L || stride > 2000L) return(NULL)
    # walk back in `stride` steps while |CRLF holds -> first frame's `|`
    e <- t1
    repeat {
      p <- e - stride
      if (p < 0L) break
      if (identical(data[(p + 1L):(p + 3L)], as.raw(c(0x7c, 0x0d, 0x0a)))) e <- p else break
    }
  }
  first <- e - stride + 3L # 0-based start of frame 1
  if (first < 0L) return(NULL)
  # derive per-port column offsets from frame 1. The line is
  # `<port1>|<port2>|...|<cmd>|` -- one `|` after every field including the
  # final <cmd>, so `m` pipes delimit `m` fields (field m is <cmd>) and the
  # ports are fields 1..(m-1).
  line <- data[(first + 1L):(first + stride - 2L)] # drop trailing CRLF
  pipe <- which(line == as.raw(0x7c)) # 1-based positions of `|`
  m <- length(pipe)
  if (m < 2L) return(NULL) # need >=1 port + <cmd>
  starts <- c(1L, pipe[-m] + 1L) # start of each of the m fields
  ends <- pipe - 1L # end of each field (before its `|`)
  n_ports <- m - 1L # last field is <cmd>
  port_off <- starts[seq_len(n_ports)] - 1L # 0-based within a frame
  port_w <- ends[seq_len(n_ports)] - starts[seq_len(n_ports)] + 1L
  # drop trailing empty ports (one-controller movies have an empty port 2)
  keep <- rev(cumsum(rev(port_w > 0L)) > 0L)
  n_players <- max(1L, sum(keep))
  cmd_width <- max(0L, ends[m] - starts[m] + 1L)
  list(
    first = first, stride = stride,
    port_off = port_off[seq_len(n_players)], port_width = port_w[seq_len(n_players)],
    pipe = pipe, n_players = n_players,
    cmd_off = starts[m] - 1L, cmd_width = cmd_width
  )
}
.read_pjm_text <- function(data, lay, n_frames_field, n_buttons, header, path) {
  sz <- length(data)
  have <- (sz - lay$first) %/% lay$stride
  remainder <- (sz - lay$first) %% lay$stride
  missing_newline <- 0L
  if (remainder %in% c(lay$stride - 2L, lay$stride - 1L)) {
    tail_start <- lay$first + have * lay$stride
    last <- data[tail_start + seq_len(remainder)]
    complete <- identical(which(last == as.raw(0x7c)), lay$pipe) &&
      (remainder == lay$stride - 2L || utils::tail(last, 1L) == as.raw(0x0d))
    if (complete) {
      missing_newline <- lay$stride - remainder
      have <- have + 1L
      remainder <- 0L
    }
  }
  if (remainder != 0L) {
    stop(
      path, ": PJM text body has a partial final frame (",
      remainder, " of ", lay$stride, " bytes)"
    )
  }
  n_frames <- have
  header <- .pjm_record_counts(header, n_frames_field, have, path)
  header$terminalNewlineBytesMissing <- as.character(missing_newline)
  n_players <- lay$n_players
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  analog_values <- .empty_analog(n_frames, n_players)
  if (n_frames > 0L) {
    frame0 <- lay$first + lay$stride * (seq_len(n_frames) - 1L) # 0-based frame starts
    # PSXjin MOV_ReadJoy regards any non-dot byte as pressed, including
    # NUL. A few archived movies contain complete all-NUL records. Preserve
    # that deterministic interpretation; never silently replace them by idle.
    zero <- rep(FALSE, n_frames)
    suspect <- which(data[frame0 + lay$pipe[1L]] == as.raw(0))
    for (fi in suspect) if (frame0[fi] + lay$stride <= sz)
      zero[fi] <- all(data[frame0[fi] + seq_len(lay$stride)] == as.raw(0))
    header$allNulRecordCount <- as.character(sum(zero))
    # MOV_ReadJoy tests each fixed-width button byte against '.', including
    # NUL bytes. Retain their defined pressed state and diagnostic count.
    noncanonical <- rep(FALSE, n_frames)
    for (column in lay$pipe)
      noncanonical <- noncanonical | (!zero & data[frame0 + column] != as.raw(0x7c))
    complete <- which(!zero & seq_len(n_frames) <= n_frames - as.integer(missing_newline > 0))
    noncanonical[complete] <- noncanonical[complete] |
      data[frame0[complete] + lay$stride - 1L] != as.raw(13L) |
      data[frame0[complete] + lay$stride] != as.raw(10L)
    header$noncanonicalSeparatorRecords <- as.character(sum(noncanonical))
    # PSXjin advances over separator positions without inspecting their
    # contents. The count is metadata; such bytes do not alter input fields.
    dot <- as.raw(0x2e)
    for (pl in seq_len(n_players)) {
      poff <- lay$port_off[pl]
      width <- lay$port_width[pl]
      if (width == 0L) next
      if (!width %in% c(14L, 32L)) stop(path, ": unsupported PJM text controller width ", width)
      # PSXjin writes bits 15..3 then Select for standard pads; analogue pads
      # write all bits 15..0, so Select is column 16, not column 14.
      slots <- if (width == 14L) .PJM_POS_TO_UNI else rev(.PJM_BIT_TO_UNI)
      for (k in seq_along(slots)) {
        if (is.na(slots[k])) next
        b <- data[frame0 + poff + (k - 1L) + 1L] # 1-based fetch, vectorised
        pressed <- b != dot
        # '#' is PSXjin's Square mnemonic, NOT a reset marker.
        if (any(pressed)) inputs[pressed, pl, slots[k]] <- TRUE
      }
      if (width == 32L) {
        axes <- vapply(0:3, function(axis) {
          chars <- lapply(1:4, function(k) rawToChar(data[frame0 + poff + 16L + 4L * axis + k],
            multiple = TRUE
          ))
          value <- suppressWarnings(as.integer(do.call(paste0, chars)))
          if (anyNA(value) || any(value < 0L | value > 255L)) stop(path, ": invalid PJM analogue axis")
          value
        }, integer(n_frames))
        axes <- matrix(axes, nrow = n_frames, ncol = 4L)
        colnames(axes) <- c("lstick_x", "lstick_y", "rstick_x", "rstick_y")
        analog_values[[pl]] <- axes
      }
    }
    if (lay$cmd_width > 0L) {
      # atoi() of a NUL command field is zero in PSXjin, so all-NUL records
      # keep command 0. A recording holds few distinct command fields: each
      # is parsed once, at the first record that has it, and the value is
      # given to every record with the same bytes.
      rows <- which(!zero)
      if (length(rows)) {
        width <- lay$cmd_width
        bytes <- matrix(
          as.integer(data[rep(frame0[rows] + lay$cmd_off, each = width) + seq_len(width)]),
          ncol = width, byrow = TRUE
        )
        key <- if (width <= 6L) as.vector(bytes %*% 256^(seq_len(width) - 1L)) else
          do.call(paste, c(lapply(seq_len(width), function(k) bytes[, k]), sep = " "))
        distinct <- !duplicated(key)
        parsed <- vapply(rows[distinct], function(fi) {
          txt <- trimws(rawToChar(data[frame0[fi] + lay$cmd_off + seq_len(width)]))
          if (!nzchar(txt) || txt == ".") return(0L)
          value <- suppressWarnings(as.integer(txt))
          if (is.na(value) || value < 0L || value > 255L) {
            stop("PJM text command is not a byte value: ", txt)
          }
          value
        }, integer(1))
        commands[rows] <- parsed[match(key, key[distinct])]
      }
    }
  }
  .new_movie(
    header = header, commands = commands, inputs = inputs,
    analog = analog_values,
    button_mnemonics = .legacy_buttons()[seq_len(n_buttons)],
    button_names = .legacy_button_names()[seq_len(n_buttons)]
  )
}
.read_pjm_binary <- function(data, n_frames_field, sz, n_buttons, header,
                             controller_types = c(0L, 0L), body_offset = 0L,
                             path = "PJM recording") {
  if (body_offset > 0L) {
    widths <- c("0" = 0L, "8" = 0L, "4" = 2L, "5" = 6L, "7" = 6L)[as.character(controller_types)]
    if (anyNA(widths)) stop("PJM binary peripheral type is not supported")
    stride <- sum(widths) + 1L
    if (sum(widths) == 0L || (sz - body_offset) %% stride != 0L)
      stop("PJM binary body has a partial final frame or no controllers")
    n_frames <- (sz - body_offset) %/% stride
    header <- .pjm_record_counts(header, n_frames_field, n_frames, path)
    n_players <- max(which(widths > 0L))
    inputs <- .empty_inputs(n_frames, n_players, n_buttons)
    analog_values <- .empty_analog(n_frames, n_players)
    frames <- body_offset + (seq_len(n_frames) - 1L) * stride
    offsets <- c(0L, widths[1L])
    reserved_digital_bits <- integer(n_players)
    for (pl in which(widths > 0L)) {
      pos <- frames + offsets[pl]
      words <- as.integer(data[pos + 1L]) + 256L * as.integer(data[pos + 2L])
      if (controller_types[pl] == 4L)
        reserved_digital_bits[pl] <- sum(bitwAnd(words, 2L) != 0L) + sum(bitwAnd(words, 4L) != 0L)
      for (bit in 0:15) {
        if (controller_types[pl] == 4L && bit %in% c(1L, 2L)) next
        slot <- .PJM_BIT_TO_UNI[bit + 1L]
        if (!is.na(slot)) inputs[, pl, slot] <- bitwAnd(words, 2^bit) != 0L
      }
      if (widths[pl] == 6L) {
        axes <- vapply(3:6, function(k) as.integer(data[pos + k]), integer(n_frames))
        axes <- matrix(axes, nrow = n_frames, ncol = 4L)
        colnames(axes) <- c("lstick_x", "lstick_y", "rstick_x", "rstick_y")
        analog_values[[pl]] <- axes
      }
    }
    header$reservedDigitalPadBitCounts <- reserved_digital_bits
    return(.new_movie(
      header = header, commands = as.integer(data[frames + stride]), inputs = inputs,
      analog = analog_values,
      button_mnemonics = .legacy_buttons()[seq_len(n_buttons)],
      button_names = .legacy_button_names()[seq_len(n_buttons)]
    ))
  }
  # Compatibility for old headerless synthetic fixtures only. Real movies
  # provide the controller-data offset and use their actual configured widths.
  if (n_frames_field > .Machine$integer.max) {
    stop("PJM frame count is too large for R")
  }
  n_frames <- as.integer(n_frames_field)
  bpf <- 5L
  body_off <- sz - n_frames * bpf
  if (body_off < 24L) {
    stop(
      "PJM binary body truncated or unknown stride ",
      sprintf("(file=%d, n_frames=%d)", sz, n_frames)
    )
  }
  if (any(!(controller_types %in% 0:7))) {
    stop("PJM contains an unknown controller type")
  }
  if (any(controller_types %in% c(1L, 2L, 3L, 5L, 6L, 7L))) {
    stop("PJM binary non-digital controller variants are not supported")
  }
  has_p2 <- controller_types[2L] == 4L
  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- body_off + (fi - 1L) * bpf
      if (data[off + 3L] != as.raw(0L) || data[off + 4L] != as.raw(0L)) {
        has_p2 <- TRUE
        break
      }
    }
  }
  n_players <- if (has_p2) 2L else 1L
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  analog_values <- .empty_analog(n_frames, n_players)
  reserved_digital_bits <- integer(n_players)
  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- body_off + (fi - 1L) * bpf
      for (pl in seq_len(n_players)) {
        po <- off + (pl - 1L) * 2L
        word <- as.integer(data[po + 1L]) + bitwShiftL(as.integer(data[po + 2L]), 8L)
        reserved_digital_bits[pl] <- reserved_digital_bits[pl] +
          as.integer(bitwAnd(word, 2L) != 0L) + as.integer(bitwAnd(word, 4L) != 0L)
        for (bit in 0:15) {
          if (bit %in% c(1L, 2L)) next
          if (bitwAnd(word, bitwShiftL(1L, bit)) == 0L) next
          slot <- .PJM_BIT_TO_UNI[bit + 1L]
          if (is.na(slot)) next
          inputs[fi, pl, slot] <- TRUE
        }
      }
      commands[fi] <- as.integer(data[off + 5L])
    }
  }
  header$reservedDigitalPadBitCounts <- reserved_digital_bits
  .new_movie(
    header = header, commands = commands, inputs = inputs,
    analog = analog_values,
    button_mnemonics = .legacy_buttons()[seq_len(n_buttons)],
    button_names = .legacy_button_names()[seq_len(n_buttons)]
  )
}
