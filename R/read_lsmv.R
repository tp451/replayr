# Sources / attribution:
#
# This reader was developed with reference to the lsnes source
# tree alongside the TASVideos wiki at
# /EmulatorResources/Lsnes/Movieformat.
#
#   Source:    https://github.com/Ilari-Pihlajisto/lsnes
#   License:   GPL v2 or later
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# lsnes (rr) .lsmv movie format. Reference: tasvideos.org wiki at
# /EmulatorResources/Lsnes/Movieformat and the lsnes source tree.
#
# An .lsmv is a ZIP archive whose `input` text file lists one frame per
# line. Each frame is shaped:
#     F<lag>[ <sysflags...>]|<port1>[|<port2>...]
# where the leading 'F' marks an input frame (other prefixes are
# subframe polls and are ignored), <sysflags> are zero or more
# space-separated system fields (reset address, etc.) that vary by lsnes
# version, and each port chunk is a fixed-width button mask.
#
# For an SNES standard gamepad the mask is 12 characters in lsnes button
# order: B Y s S u d l r A X L R (lowercase 's', 'u', 'd', 'l', 'r' avoid
# colliding with uppercase Start / Y / etc.). Inside the mask, '.' means
# unpressed; any other character means pressed.

# lsnes SNES gamepad column position (1-based) -> universal slot (1-based).
# Position order in .lsmv: B, Y, s, S, u, d, l, r, A, X, L, R.
.LSMV_SNES_POS_TO_UNI <- c(
  7L,   # B    -> universal slot 7 (B)
  10L,  # Y    -> slot 10 (Y face)
  6L,   # s    -> slot 6 (Select)
  5L,   # S    -> slot 5 (Start)
  4L,   # u    -> slot 4 (Up)
  3L,   # d    -> slot 3 (Down)
  2L,   # l    -> slot 2 (Left)
  1L,   # r    -> slot 1 (Right)
  8L,   # A    -> slot 8 (A)
  9L,   # X    -> slot 9 (X face)
  11L,  # L    -> slot 11 (L-shoulder)
  12L   # R    -> slot 12 (R-shoulder)
)

# lsnes Game Boy / GBC (libgambatte) gamepad column position -> universal slot.
# Empirically observed column order: A B s S r l u d.
.LSMV_GB_POS_TO_UNI <- c(
  8L,   # A -> slot 8
  7L,   # B -> slot 7
  6L,   # s -> slot 6 (Select)
  5L,   # S -> slot 5 (Start)
  1L,   # r -> slot 1 (Right)
  2L,   # l -> slot 2 (Left)
  4L,   # u -> slot 4 (Up)
  3L    # d -> slot 3 (Down)
)

#' Read an lsnes .lsmv movie file
#'
#' .lsmv is a ZIP archive containing an `input` text member plus various
#' metadata members (gametype, controlsversion, coreversion, systemid,
#' rom.sha256, projectid, rerecords, ...). Currently supports the SNES
#' standard gamepad (12-char masks; 16-char with the lsnes 4-col extension
#' suffix) and Game Boy / GBC (8-char masks via libgambatte). Other port
#' types (mouse, superscope, justifier) raise an error for now.
#'
#' Super Game Boy recordings (gametype starting with `gambatte_sgb`) carry
#' a 12-char SNES-shaped mask but only ever fire the first eight positions
#' -- they're folded down to the GB shape (8 buttons) so SGB and GB pubs
#' share a single in-memory width.
#'
#' @param path Path to an .lsmv file.
#' @return A `replayr_movie` object.
#' @export
read_lsmv <- function(path) {
  con <- unz(description = path, filename = "input", open = "rb")
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  if (inherits(con, "connection")) {
    raw_input <- readBin(con, what = "raw", n = 1e9)
    close(con)
    on.exit()
  } else {
    stop("could not open `input` member of ", path)
  }
  input_text <- rawToChar(raw_input)

  header <- list("_format" = "lsmv")
  meta_members <- c("gametype", "controlsversion", "coreversion", "systemid",
                    "rom.sha256", "rom.hint", "projectid", "rerecords",
                    "starttime.second", "starttime.subsecond", "authors",
                    "branchname.0")
  # Probe the archive's contents once so we can skip metadata members
  # that aren't present (rom.hint and branchname.0 are optional). This
  # avoids the "cannot locate file" warning that R's `unz()` emits.
  zip_listing <- utils::unzip(path, list = TRUE)$Name
  for (m in meta_members) {
    if (!(m %in% zip_listing)) next
    val <- tryCatch(suppressWarnings({
      conm <- unz(path, filename = m, open = "rb")
      on.exit(try(close(conm), silent = TRUE), add = TRUE)
      raw <- readBin(conm, what = "raw", n = 1e6)
      close(conm)
      txt <- rawToChar(raw)
      sub("[[:space:]]+$", "", txt)
    }), error = function(e) NULL)
    if (!is.null(val) && nzchar(val)) header[[m]] <- val
  }

  mv <- .parse_lsmv_input(input_text, header = header)
  mv$source_path <- path
  mv
}

.parse_lsmv_input <- function(text, header = list("_format" = "lsmv")) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  lines <- sub("\r$", "", lines)
  frame_lines <- lines[nzchar(lines) & substr(lines, 1L, 1L) == "F"]

  if (length(frame_lines) == 0L) {
    return(.new_movie(
      header = header,
      commands = integer(0),
      inputs = .empty_inputs(0L, 1L, 12L),
      button_mnemonics = universal_buttons()[1:12],
      button_names = universal_button_names()[1:12]
    ))
  }

  first_pieces <- strsplit(frame_lines[1L], "|", fixed = TRUE)[[1]]
  port_pieces <- if (length(first_pieces) >= 2L) first_pieces[-1L] else character(0)
  if (length(port_pieces) == 0L) {
    stop("lsmv input line has no port data: ", substr(frame_lines[1L], 1L, 80L))
  }
  port_widths <- nchar(port_pieces)

  accepted_widths <- c(8L, 12L, 16L)
  accepted_ports <- which(port_widths %in% accepted_widths)
  if (length(accepted_ports) == 0L) {
    stop(sprintf(
      "unsupported lsmv controller widths %s; only 8- (GB), 12- or 16-char (SNES) gamepad masks are handled",
      paste(port_widths, collapse = ", ")
    ))
  }
  n_players <- length(accepted_ports)
  primary_w <- port_widths[accepted_ports[1L]]

  gametype <- ""
  if (!is.null(header$gametype)) gametype <- tolower(header$gametype)
  is_sgb <- startsWith(gametype, "gambatte_sgb")

  if (primary_w == 8L) {
    pos_to_slot <- .LSMV_GB_POS_TO_UNI
    consume_cols <- 8L
    n_buttons <- 8L
  } else if (is_sgb) {
    pos_to_slot <- .LSMV_SNES_POS_TO_UNI
    consume_cols <- 12L
    n_buttons <- 8L
  } else {
    pos_to_slot <- .LSMV_SNES_POS_TO_UNI
    consume_cols <- 12L
    n_buttons <- 12L
  }

  n_frames <- length(frame_lines)
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)

  for (fi in seq_len(n_frames)) {
    ln <- frame_lines[fi]
    if (nchar(ln) > 1L) {
      ch2 <- substr(ln, 2L, 2L)
      if (ch2 != "." && ch2 != " ") commands[fi] <- 1L
    }
    pieces <- strsplit(ln, "|", fixed = TRUE)[[1]]
    port_data <- if (length(pieces) >= 2L) pieces[-1L] else character(0)
    for (player_idx in seq_along(accepted_ports)) {
      port_idx <- accepted_ports[player_idx]
      if (port_idx > length(port_data)) break
      mask <- port_data[port_idx]
      if (!(nchar(mask) %in% accepted_widths)) next
      chars <- strsplit(mask, "", fixed = TRUE)[[1]]
      cols_to_check <- min(consume_cols, length(chars))
      for (col in seq_len(cols_to_check)) {
        ch <- chars[col]
        if (ch == "." || ch == " ") next
        slot <- pos_to_slot[col]
        if (slot > n_buttons) next
        inputs[fi, player_idx, slot] <- TRUE
      }
    }
  }

  .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    button_mnemonics = universal_buttons()[seq_len(n_buttons)],
    button_names = universal_button_names()[seq_len(n_buttons)]
  )
}
