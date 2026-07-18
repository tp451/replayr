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
#   analog-stick values (e.g. " 128 127 128 128"). Movies with one
#   controller render an empty second port, giving the historical
#   `<port1>||0|\r\n` (20-byte) line; two-controller movies give
#   `<port1>|<port2>|0|\r\n` (34-byte); analog movies are wider (52-byte).
#   We locate the body by its `|`CRLF frame terminator, derive the stride
#   and the per-port column offsets from the first frame, then read every
#   frame's first 14 mask chars per port (analog decimals are ignored).
#
#   BINARY.  No text terminator; 5 bytes per frame at the END of the file
#   (body_off = file_size - n_frames * 5): P1 and P2 16-bit digital words
#   followed by one command byte.
#
# PSX DualShock 14-button text column order:
#   1 Square  2 Cross  3 Circle  4 Triangle  5 L1  6 R1  7 L2  8 R2
#   9 Left    10 Down  11 Right  12 Up        13 Start  14 Select
#
# Face-button mapping into universal slots follows the geometric diamond
# convention used elsewhere: Triangle (top) -> X slot, Square (left) -> Y,
# Cross (bottom) -> B, Circle (right) -> A.

# 1-based PJM text column position -> 1-based universal slot.
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

# DualShock 16-bit binary button word (active-high) bit -> universal slot.
# Identical to the .pxm mapping; NA for reserved bits.
.PJM_BIT_TO_UNI <- c(
  6L, NA_integer_, NA_integer_, 5L,   # Select, -, -, Start
  4L, 1L, 3L, 2L,                     # Up, Right, Down, Left
  29L, 30L, 11L, 12L,                 # L2, R2, L1, R1
  9L, 8L, 7L, 10L                     # Triangle, Circle, Cross, Square
)

#' Read a PSXjin .pjm movie file
#'
#' Parses the PSXjin movie format into the standard `replayr_movie` shape.
#' Supports the text body in its one-controller (20-byte line),
#' two-controller (34-byte line) and analog (wider line) variants, plus the
#' binary 5-byte-per-frame body. The PSX gamepad maps onto universal slots
#' 1..12 (NES + SNES face / shoulder layout) plus 29 / 30 for L2 / R2; the
#' output is 30 buttons wide. Two-controller movies yield a two-player movie
#' (analysis code that wants player 1 simply reads the first player).
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
  n_frames_field <- .read_u32_le(data, 16L)
  rerec <- .read_u32_le(data, 20L)
  controller_types <- as.integer(data[c(0x0EL, 0x0FL) + 1L])
  desc <- .read_cstring(data, 0x39L, 0xC8L)
  sz <- length(data)
  n_buttons <- 30L
  header <- list(
    "_format" = "pjm",
    version = as.character(version),
    rerecordCount = as.character(rerec),
    description = desc,
    controllerType1 = as.character(controller_types[1L]),
    controllerType2 = as.character(controller_types[2L])
  )

  # --- decide text vs binary by locating a `|`CRLF frame terminator ---
  term <- as.raw(c(0x7c, 0x0d, 0x0a))
  t1 <- .find_raw(data, term)                       # 0-based, or NA
  layout <- .pjm_text_layout(data, t1, sz)          # NULL if not a valid text body

  if (!is.null(layout)) {
    mv <- .read_pjm_text(data, layout, n_frames_field, n_buttons, header)
  } else {
    mv <- .read_pjm_binary(data, n_frames_field, sz, n_buttons, header,
                           controller_types)
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
.pjm_text_layout <- function(data, t1, sz) {
  if (is.na(t1) || t1 < 20L) return(NULL)
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
  first <- e - stride + 3L                  # 0-based start of frame 1
  if (first < 0L) return(NULL)

  # derive per-port column offsets from frame 1. The line is
  # `<port1>|<port2>|...|<cmd>|` -- one `|` after every field including the
  # final <cmd>, so `m` pipes delimit `m` fields (field m is <cmd>) and the
  # ports are fields 1..(m-1).
  line <- data[(first + 1L):(first + stride - 2L)]   # drop trailing CRLF
  pipe <- which(line == as.raw(0x7c))                # 1-based positions of `|`
  m <- length(pipe)
  if (m < 2L) return(NULL)                           # need >=1 port + <cmd>
  starts <- c(1L, pipe[-m] + 1L)                     # start of each of the m fields
  ends   <- pipe - 1L                                # end of each field (before its `|`)
  n_ports <- m - 1L                                  # last field is <cmd>
  port_off <- starts[seq_len(n_ports)] - 1L          # 0-based within a frame
  port_w   <- ends[seq_len(n_ports)] - starts[seq_len(n_ports)] + 1L
  # drop trailing empty ports (one-controller movies have an empty port 2)
  keep <- rev(cumsum(rev(port_w > 0L)) > 0L)
  n_players <- max(1L, sum(keep))
  cmd_width <- max(0L, ends[m] - starts[m] + 1L)
  list(first = first, stride = stride,
       port_off = port_off[seq_len(n_players)], n_players = n_players,
       cmd_off = starts[m] - 1L, cmd_width = cmd_width)
}

.read_pjm_text <- function(data, lay, n_frames_field, n_buttons, header) {
  sz <- length(data)
  have <- (sz - lay$first) %/% lay$stride
  if (n_frames_field > have) {
    stop("PJM text body is truncated (declares ", n_frames_field,
         " frames, has ", have, ")")
  }
  n_frames <- if (n_frames_field > 0L) n_frames_field else have
  n_players <- lay$n_players
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  if (n_frames > 0L) {
    frame0 <- lay$first + lay$stride * (seq_len(n_frames) - 1L)   # 0-based frame starts
    dot <- as.raw(0x2e); spc <- as.raw(0x20); nul <- as.raw(0x00); hash <- as.raw(0x23)
    for (pl in seq_len(n_players)) {
      poff <- lay$port_off[pl]
      for (k in seq_len(14L)) {
        b <- data[frame0 + poff + (k - 1L) + 1L]          # 1-based fetch, vectorised
        pressed <- b != dot & b != spc & b != nul
        if (pl == 1L && k == 1L) {
          hh <- b == hash                                  # `#` = rerecord / reset marker
          if (any(hh)) commands[hh] <- bitwOr(commands[hh], 1L)
          pressed <- pressed & !hh
        }
        if (any(pressed)) inputs[pressed, pl, .PJM_POS_TO_UNI[k]] <- TRUE
      }
    }
    if (lay$cmd_width > 0L) {
      for (fi in seq_len(n_frames)) {
        idx <- frame0[fi] + lay$cmd_off + seq_len(lay$cmd_width)
        txt <- trimws(rawToChar(data[idx]))
        if (!nzchar(txt) || txt == ".") next
        value <- suppressWarnings(as.integer(txt))
        if (is.na(value) || value < 0L || value > 255L) {
          stop("PJM text command is not a byte value: ", txt)
        }
        commands[fi] <- value
      }
    }
  }
  .new_movie(header = header, commands = commands, inputs = inputs,
             button_mnemonics = universal_buttons()[seq_len(n_buttons)],
             button_names = universal_button_names()[seq_len(n_buttons)])
}

.read_pjm_binary <- function(data, n_frames_field, sz, n_buttons, header,
                             controller_types = c(0L, 0L)) {
  if (n_frames_field > .Machine$integer.max) {
    stop("PJM frame count is too large for R")
  }
  n_frames <- as.integer(n_frames_field)
  bpf <- 5L
  body_off <- sz - n_frames * bpf
  if (body_off < 24L) {
    stop("PJM binary body truncated or unknown stride ",
         sprintf("(file=%d, n_frames=%d)", sz, n_frames))
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
  if (n_frames > 0L) {
    for (fi in seq_len(n_frames)) {
      off <- body_off + (fi - 1L) * bpf
      for (pl in seq_len(n_players)) {
        po <- off + (pl - 1L) * 2L
        word <- as.integer(data[po + 1L]) + bitwShiftL(as.integer(data[po + 2L]), 8L)
        for (bit in 0:15) {
          if (bitwAnd(word, bitwShiftL(1L, bit)) == 0L) next
          slot <- .PJM_BIT_TO_UNI[bit + 1L]
          if (is.na(slot)) next
          inputs[fi, pl, slot] <- TRUE
        }
      }
      commands[fi] <- as.integer(data[off + 5L])
    }
  }
  .new_movie(header = header, commands = commands, inputs = inputs,
             button_mnemonics = universal_buttons()[seq_len(n_buttons)],
             button_names = universal_button_names()[seq_len(n_buttons)])
}
