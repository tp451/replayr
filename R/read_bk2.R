# BizHawk .bk2 movie format. A ZIP archive whose `Input Log.txt` member
# describes inputs in a syntax similar to FM2:
#
#     [Input]
#     LogKey:#Reset|Power|#P1 Up|P1 Down|...|P1 A|#P2 Up|...
#     |..|........|........|
#
# The LogKey lists the buttons by name in column order; the parser
# reads it to figure out which char position in each frame line means
# which universal-button slot. Without a LogKey it falls back to the
# NES-positional UDLRTSBA mapping.
#
# bk2 covers many platforms: NES, SNES, Atari 2600, Game Boy / GBC,
# GBA, N64, PlayStation, ... -- so the LogKey-driven mapping is the
# reliable way to interpret column data across these systems.
#
# Reference: BizHawk source (BizHawk.Client.Common, MovieControllerAdapter)
# and the tasvideos wiki at /EmulatorResources/BizHawk/Bk2.

# Deadzone for the bk2 N64 / PSX analog-stick reading. 0..127 scale.
.BK2_STICK_DEADZONE <- 32L

# Default NES positional fallback: when the LogKey is missing or
# unintelligible we assume the file is NES and read columns in
# UDLRTSBA order.
.BK2_POS_TO_UNI <- c(
  4L,   # 1: U -> universal 4 (Up)
  3L,   # 2: D -> universal 3 (Down)
  2L,   # 3: L -> universal 2 (Left)
  1L,   # 4: R -> universal 1 (Right)
  5L,   # 5: T -> universal 5 (Start)
  6L,   # 6: S -> universal 6 (Select)
  7L,   # 7: B -> universal 7
  8L    # 8: A -> universal 8
)

# Map BizHawk button-name (lowercase) -> 1-based universal-slot index.
# Extends the FM2 NES set with SNES X/Y, shoulders, Genesis C/Mode, N64
# Z + C-buttons + analog-stick boolean cols, and PSX face buttons.
.BK2_NAME_TO_UNI <- c(
  # d-pad -- full names disambiguate from L/R shoulder
  "right" = 1L, "left" = 2L, "down" = 3L, "up" = 4L,
  # Start / Select
  "start" = 5L, "select" = 6L,
  # Primary face buttons
  "b" = 7L, "a" = 8L,
  # Atari 2600 single-fire button -> A slot
  "button" = 8L, "fire" = 8L,
  # SNES extras
  "x" = 9L, "y" = 10L,
  # Shoulder buttons (single-letter L / R in BizHawk LogKeys are SHOULDERS,
  # not the d-pad -- d-pad uses the full word forms above).
  "l" = 11L, "r" = 12L,
  # Genesis C / N64 Z / Genesis Mode
  "c" = 13L, "z" = 14L, "mode" = 15L,
  # N64: hardware d-pad columns
  "dpad u" = 4L, "dpad d" = 3L, "dpad l" = 2L, "dpad r" = 1L,
  "d-pad up" = 4L, "d-pad down" = 3L, "d-pad left" = 2L, "d-pad right" = 1L,
  # N64: BizHawk's quantised analog-stick boolean columns
  "a up" = 23L,    # stick-N
  "a down" = 27L,  # stick-S
  "a left" = 25L,  # stick-W
  "a right" = 21L, # stick-E
  # N64: C-buttons
  "c up" = 20L, "c down" = 19L, "c right" = 17L, "c left" = 18L,
  # PSX BizHawk LogKey extras (word style + digit-suffixed shoulders)
  "triangle" = 9L, "square" = 10L, "cross" = 7L, "circle" = 8L,
  # PSX BizHawk LogKey extras (Unicode-glyph style -- Nymashock)
  "\u25B3" = 9L,  # Triangle
  "\u25A1" = 10L, # Square
  "\u25CB" = 8L,  # Circle
  "\u2715" = 7L,  # Cross
  "l1" = 11L, "r1" = 12L, "l2" = 29L, "r2" = 30L,
  # Intellivision / ColecoVision keypad. Both share digits 0-9 (slots
  # 31..40, one-based). INTV's Enter/Clear and Coleco's Star/Pound fold
  # into Start (5) / Select (6) \u2014 they're pressed once at boot, like
  # Start/Select on console controllers.
  "key 0" = 31L, "key 1" = 32L, "key 2" = 33L, "key 3" = 34L, "key 4" = 35L,
  "key 5" = 36L, "key 6" = 37L, "key 7" = 38L, "key 8" = 39L, "key 9" = 40L,
  "enter" = 5L, "clear" = 6L,            # INTV
  "star"  = 5L, "pound" = 6L,            # Coleco
  # INTV side-action buttons. The 4 corner buttons electrically pair
  # into 3 inputs in BizHawk: "Top" (both top buttons), "L" (lower
  # left), "R" (lower right). L and R reuse the shoulder slots 11/12
  # ("l"/"r" mappings above); Top lands in slot 9 (SNES X) since INTV
  # has no SNES-style X/Y.
  "top" = 9L,
  # INTV 16-direction control disc, mapped to the 8-sector stick
  # quantisation (slots 21..28). Inter-intercardinals (NNE, ENE,
  # ESE, SSE, SSW, WSW, WNW, NNW) fold to the nearest cardinal /
  # intercardinal \u2014 INTV games rarely demand the full 16-way precision
  # and aliasing them keeps cross-platform stick features comparable.
  "n" = 23L, "nne" = 23L, "nnw" = 24L,
  "ne" = 22L, "ene" = 22L,
  "e" = 21L, "ese" = 21L,
  "se" = 28L, "sse" = 28L,
  "s" = 27L, "ssw" = 27L,
  "sw" = 26L, "wsw" = 26L,
  "w" = 25L, "wnw" = 25L,
  "nw" = 24L,
  # Sega Master System: B1/B2 are the two action buttons; "Pause" is
  # in the LogKey command group, not a player button. Light Phaser
  # gun games use "Trigger" (single fire button) plus X/Y coordinate
  # ints we don't model.
  "b1" = 8L, "b2" = 7L, "trigger" = 8L,
  # PC Engine / TurboGrafx-16: 6-button face layout (I, II, III, IV,
  # V, VI), Run = Start, Select. The 2-button mode only uses I and II;
  # 6-button mode adds III..VI. Mirrors the SNES face layout: I=A,
  # II=B, III=X, IV=Y, V=L-shoulder, VI=R-shoulder. "Mode: Set
  # N-button" pseudo-columns are not real hardware buttons and stay
  # unmapped (the parser will skip them).
  "i" = 8L, "ii" = 7L, "iii" = 9L, "iv" = 10L, "v" = 11L, "vi" = 12L,
  "run" = 5L,
  # Arcade (BizHawk MAME core). Per-player columns are "Button 1" ..
  # "Button 6"; we map them to the SNES face-button layout (A/B for
  # primary pair, X/Y for secondary, L/R-shoulder for the 5-6th
  # buttons that fighters need). Direction columns ("Up", "Down",
  # "Left", "Right") are already mapped above. Coin / Service /
  # "1 Player Start" appear in the LogKey command group and feed
  # `commands` rather than `inputs`.
  "button 1" = 8L, "button 2" = 7L,
  "button 3" = 9L, "button 4" = 10L,
  "button 5" = 11L, "button 6" = 12L
)

# Substrings that mark analog / sensor / non-button channels. "disc" catches
# the Intellivision control disc when a core logs it as numeric "Disc X|Disc Y"
# axes (rather than the 16 named-direction boolean columns N|NNE|... that other
# INTV bk2s use). Without this the two numeric axis columns are treated as
# unmapped buttons, consuming column positions that the frame parser then
# comma-strips -- shifting every keypad/side button read by two and zeroing the
# whole track.
.BK2_ANALOG_HINTS <- c("axis", "tilt", "sensor", "accel", "gyro", "stick", "disc")

# Tag an analog-channel name as 'lstick_x' / 'lstick_y' / 'rstick_x' /
# 'rstick_y' / NA. NA means drop the column entirely (sensors like GBA
# tilt / light, which TAS movies leave at default values).
.classify_analog_pair <- function(name_lower) {
  if (any(c("tilt", "sensor", "accel", "gyro") %in%
          unlist(strsplit(name_lower, " ")))) {
    return(NA_character_)
  }
  if (grepl("tilt", name_lower) || grepl("sensor", name_lower) ||
      grepl("accel", name_lower) || grepl("gyro", name_lower)) {
    return(NA_character_)
  }
  if (grepl("lstick x", name_lower)) return("lstick_x")
  if (grepl("lstick y", name_lower)) return("lstick_y")
  if (grepl("rstick x", name_lower)) return("rstick_x")
  if (grepl("rstick y", name_lower)) return("rstick_y")
  if (grepl("x axis", name_lower)) return("lstick_x")
  if (grepl("y axis", name_lower)) return("lstick_y")
  # Intellivision control disc logged as numeric axes: quantise onto the same
  # 8 stick-direction slots that the named-direction INTV disc (N|NE|...) uses.
  if (grepl("disc x", name_lower)) return("lstick_x")
  if (grepl("disc y", name_lower)) return("lstick_y")
  NA_character_
}

# Parse a BizHawk `LogKey:#Reset|Power|#P1 Up|...` line.
# Returns a list with: $commands (character), $btn_map (per-player list of
# (col_pos, slot) tuples), $analog_map (per-player list of (int_idx, axis)
# tuples).
.parse_bk2_logkey <- function(logkey) {
  if (startsWith(logkey, "LogKey:")) {
    logkey <- substr(logkey, nchar("LogKey:") + 1L, nchar(logkey))
  }
  columns <- strsplit(logkey, "|", fixed = TRUE)[[1]]
  columns <- columns[nzchar(columns)]

  # Re-group on `#` markers.
  groups <- list()
  cur <- character(0)
  for (c in columns) {
    if (startsWith(c, "#")) {
      if (length(cur) > 0L) groups[[length(groups) + 1L]] <- cur
      cur <- substr(c, 2L, nchar(c))
    } else {
      cur <- c(cur, c)
    }
  }
  if (length(cur) > 0L) groups[[length(groups) + 1L]] <- cur
  if (length(groups) == 0L) return(list(commands = character(0),
                                          btn_map = list(),
                                          analog_map = list()))

  # Single-group LogKey detection: GB / GBC / GBA Gambatte cores list one
  # group with no "P1 " prefix; the only commands are Power / Reset.
  starts_with_pn <- function(s) {
    grepl("^P[1-4] ", s)
  }
  if (length(groups) == 1L && !any(vapply(groups[[1L]], starts_with_pn, logical(1)))) {
    only <- groups[[1L]]
    commands <- only[tolower(trimws(only)) %in% c("power", "reset")]
    player_groups <- list(only)
  } else if (length(groups) > 0L && all(vapply(groups,
                                               function(g) any(vapply(g, starts_with_pn, logical(1))),
                                               logical(1)))) {
    # Coleco bk2s have no command group — every group is a player.
    # (NES/SNES/A2600/Saturn have a separate Reset/Power group up
    # front.) Detection: every group contains at least one name with
    # a "P<digit> " prefix. Treat all groups as player groups.
    commands <- character(0)
    player_groups <- groups
  } else {
    commands <- groups[[1L]]
    player_groups <- groups[-1L]
  }

  # PSX LogKeys come in three naming variants. Nymashock uses Unicode
  # shape glyphs (Triangle Square Circle) plus an ASCII "X" standing in for Cross. Without
  # context, "X" would collide with the SNES X-face button; detect PSX
  # via the presence of any of those Unicode shape glyphs.
  is_psx_logkey <- FALSE
  for (g in player_groups) {
    if (any(grepl("[\u25B3\u25A1\u25CB]", g))) {
      is_psx_logkey <- TRUE
      break
    }
  }

  per_player_btn_map <- list()
  per_player_analog_map <- list()

  for (group in player_groups) {
    btn_map <- list()
    analog_map <- list()
    button_pos <- 0L
    analog_int_pos <- 0L
    for (name in group) {
      stripped <- trimws(name)
      full_lower <- tolower(stripped)
      # Check the analog/sensor hint against the FULL column name BEFORE
      # any "P1 " prefix stripping. Otherwise "Tilt X" reduces to "x" and
      # mismatches as the SNES X-face button.
      hit_analog <- any(vapply(.BK2_ANALOG_HINTS,
                               function(h) grepl(h, full_lower, fixed = TRUE),
                               logical(1)))
      if (hit_analog) {
        axis <- .classify_analog_pair(full_lower)
        if (!is.na(axis)) {
          analog_map[[length(analog_map) + 1L]] <- list(int_idx = analog_int_pos,
                                                         axis = axis)
        }
        analog_int_pos <- analog_int_pos + 1L
        next
      }
      if (grepl(" ", stripped)) {
        rest <- sub("^[^ ]+ ", "", stripped)
      } else {
        rest <- stripped
      }
      key <- tolower(trimws(rest))
      uidx <- if (is_psx_logkey && key == "x") {
        7L
      } else {
        unname(.BK2_NAME_TO_UNI[key])
      }
      if (!is.na(uidx) && length(uidx) == 1L) {
        btn_map[[length(btn_map) + 1L]] <- list(col_pos = button_pos, slot = uidx)
      }
      button_pos <- button_pos + 1L
    }
    per_player_btn_map[[length(per_player_btn_map) + 1L]] <- btn_map
    per_player_analog_map[[length(per_player_analog_map) + 1L]] <- analog_map
  }
  list(commands = commands,
       btn_map = per_player_btn_map,
       analog_map = per_player_analog_map,
       n_logkey_groups = length(groups))
}

# Locate a bk2 member by its canonical name, tolerating two export
# variants: a leading "<game folder>/" subdirectory prefix (some BizHawk builds
# nest every member under a ROM-named directory) and a missing ".txt" extension
# (older cores wrote "Input Log" / "Header" plain). Returns the actual member
# name for utils::unzip, or NA if the member is truly absent.
.bk2_find_member <- function(zip_names, canonical) {
  stem <- sub("\\.txt$", "", canonical)
  bn <- basename(zip_names)
  hit <- which(bn == canonical | bn == stem)
  if (length(hit)) zip_names[[hit[1L]]] else NA_character_
}

#' Read a BizHawk .bk2 movie file
#'
#' .bk2 is a ZIP archive whose `Input Log.txt` describes inputs and
#' whose `Header.txt` carries metadata (Author, Core, Platform, GameName,
#' SHA1, ...). The parser uses the LogKey line to map column positions
#' to universal-button slots, supporting NES, SNES, Atari 2600, Game Boy
#' / GBC / GBA, N64, PSX in one pass. Without a LogKey it falls back
#' to NES positional UDLRTSBA mapping.
#'
#' Analog-stick columns (N64 / PSX) are quantised to 8 directions onto
#' slots 21..28; the c-stick / right stick goes onto slots 17..20.
#'
#' @param path Path to a .bk2 file.
#' @return A `replayr_movie` object.
#' @export
read_bk2 <- function(path) {
  header <- list("_format" = "bk2")
  zip_names <- utils::unzip(path, list = TRUE)$Name

  # Header (usually "Header.txt"; some exports nest it or drop the extension)
  hdr_member <- .bk2_find_member(zip_names, "Header.txt")
  if (!is.na(hdr_member)) {
    raw <- .read_zip_member_text(path, hdr_member)
    for (line in strsplit(raw, "\n", fixed = TRUE)[[1]]) {
      line <- trimws(line)
      if (!nzchar(line)) next
      if (grepl(" ", line)) {
        k <- sub(" .*$", "", line)
        v <- sub("^[^ ]+ ", "", line)
      } else {
        k <- line; v <- ""
      }
      if (!is.null(header[[k]])) {
        header[[k]] <- paste(header[[k]], v, sep = "\n")
      } else {
        header[[k]] <- v
      }
    }
  }
  cmt_member <- .bk2_find_member(zip_names, "Comments.txt")
  if (!is.na(cmt_member)) {
    txt <- trimws(.read_zip_member_text(path, cmt_member))
    if (nzchar(txt)) header[["comment"]] <- txt
  }
  il_member <- .bk2_find_member(zip_names, "Input Log.txt")
  if (is.na(il_member)) {
    stop(path, ": bk2 missing Input Log.txt")
  }
  log_text <- .read_zip_member_text(path, il_member)
  mv <- .parse_bk2_input_log(log_text, header = header)
  mv$source_path <- path
  mv
}

# Read one text member of a zip archive into a single string. We use
# utils::unzip to a temp dir because R's `unz()` connection can mangle
# multi-byte member names (it expects the exact byte sequence inside
# the central directory).
.read_zip_member_text <- function(zip_path, member) {
  td <- tempfile("bk2-")
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  utils::unzip(zip_path, files = member, exdir = td, junkpaths = FALSE)
  fp <- file.path(td, member)
  raw <- readBin(fp, what = "raw", n = file.info(fp)$size)
  # Some BizHawk cores write NUL-padded fixed-width header fields (e.g.
  # `BoardName NULL\0\0...`); strip embedded NULs so rawToChar() -- which
  # errors on them -- can decode the member as text.
  raw <- raw[raw != as.raw(0L)]
  txt <- rawToChar(raw)
  # BizHawk writes members as UTF-8. The LogKey of Mednafen-family PSX cores
  # (Nymashock) names the face buttons with Unicode shape glyphs (Triangle
  # Square Circle) used for PSX-core detection. Prefer UTF-8 and fall back to
  # Latin-1 only when the member is not valid UTF-8.
  if (validUTF8(txt)) {
    Encoding(txt) <- "UTF-8"
    txt
  } else {
    Encoding(txt) <- "latin1"
    enc2utf8(txt)
  }
}

.parse_bk2_input_log <- function(text, header = list("_format" = "bk2")) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  lines <- sub("\r$", "", lines)
  platform_text <- tolower(paste(
    unlist(header[intersect(names(header), c("Platform", "Core", "SystemID"))],
           use.names = FALSE),
    collapse = " "
  ))
  unsigned_analog <- grepl(
    "psx|playstation|nymashock|octoshock|psxhawk",
    platform_text
  )

  logkey_line <- NULL
  for (ln in lines) {
    if (startsWith(ln, "LogKey:")) {
      logkey_line <- ln
      break
    }
  }

  frame_lines <- lines[startsWith(lines, "|")]
  if (length(frame_lines) == 0L) {
    return(.new_movie(
      header = header,
      commands = integer(0),
      inputs = .empty_inputs(0L, 1L, 8L),
      button_mnemonics = .NES_BUTTONS,
      button_names = c("Right", "Left", "Down", "Up",
                       "Start", "Select", "B", "A")
    ))
  }

  # Inspect the first frame line to count player groups.
  first_parts <- strsplit(frame_lines[1L], "|", fixed = TRUE)[[1]]
  if (length(first_parts) > 0L && first_parts[1L] == "") first_parts <- first_parts[-1L]
  while (length(first_parts) > 0L && first_parts[length(first_parts)] == "") {
    first_parts <- first_parts[-length(first_parts)]
  }
  n_groups <- length(first_parts)

  per_player_map <- NULL
  per_player_analog <- NULL
  has_separate_cmd_group <- TRUE
  no_cmd_coleco_style <- FALSE
  if (!is.null(logkey_line)) {
    parsed <- tryCatch(.parse_bk2_logkey(logkey_line),
                       error = function(e) NULL)
    if (!is.null(parsed) && length(parsed$btn_map) > 0L) {
      per_player_map <- parsed$btn_map
      per_player_analog <- parsed$analog_map
      # Detect single-group LogKeys (GB / GBC / GBA): commands and
      # player buttons share one group instead of being split across
      # `#Reset|Power|#P1 ...`.
      lk <- if (startsWith(logkey_line, "LogKey:")) {
        substr(logkey_line, nchar("LogKey:") + 1L, nchar(logkey_line))
      } else logkey_line
      n_logkey_groups <- sum(startsWith(strsplit(lk, "|", fixed = TRUE)[[1]], "#"))
      single_group <- n_logkey_groups == 1L && length(per_player_map) == 1L &&
        length(per_player_map[[1L]]) > 0L
      if (single_group) has_separate_cmd_group <- FALSE
      # Coleco-style LogKey: the splitter returned `commands` empty AND
      # one player_map per `#`-group. Frame lines have no leading cmd
      # chunk; every chunk is a player. Mark this so n_players logic
      # below treats every group as a player.
      if (length(parsed$commands) == 0L &&
          length(per_player_map) == n_logkey_groups &&
          n_logkey_groups >= 1L) {
        has_separate_cmd_group <- FALSE
        no_cmd_coleco_style <- TRUE
      }
    }
  }

  n_players <- if (has_separate_cmd_group) {
    max(n_groups - 1L, 1L)
  } else if (no_cmd_coleco_style) {
    max(n_groups, 1L)
  } else {
    1L
  }

  # Determine player-column width for sanity-check fallback.
  player_col_width <- 0L
  if (length(first_parts) > 0L) {
    ps <- if (has_separate_cmd_group) first_parts[-1L] else first_parts
    if (length(ps) > 0L) {
      col <- ps[1L]
      if (grepl(",", col, fixed = TRUE)) {
        col <- sub("^.*,", "", col)
      }
      player_col_width <- nchar(col)
    }
  }

  # A present but unintelligible LogKey must not silently become an NES movie:
  # that would turn unknown columns into plausible-looking, incorrect buttons.
  if (!is.null(per_player_map)) {
    n_mapped_p0 <- length(per_player_map[[1L]])
    if (n_mapped_p0 == 0L ||
        (player_col_width > 0L && n_mapped_p0 < player_col_width %/% 2L + 1L)) {
      stop("bk2 LogKey is unsupported or too sparse for its input columns")
    }
  } else if (!is.null(logkey_line)) {
    stop("bk2 LogKey could not be parsed")
  }

  if (!is.null(per_player_map)) {
    per_player_map <- per_player_map[seq_len(min(length(per_player_map), n_players))]
    while (length(per_player_map) < n_players) {
      per_player_map[[length(per_player_map) + 1L]] <- list()
    }
  }

  has_analog <- !is.null(per_player_analog) &&
    any(vapply(per_player_analog, function(a) length(a) > 0L, logical(1)))

  # Determine inputs-array width.
  if (!is.null(per_player_map) &&
      any(vapply(per_player_map, function(m) length(m) > 0L, logical(1)))) {
    max_idx <- 8L
    for (m in per_player_map) {
      for (entry in m) max_idx <- max(max_idx, entry$slot)
    }
    n_buttons <- max(8L, max_idx)
  } else {
    n_buttons <- 8L
  }
  if (has_analog) n_buttons <- max(n_buttons, 28L)

  n_frames <- length(frame_lines)
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)

  for (fi in seq_len(n_frames)) {
    ln <- frame_lines[fi]
    parts <- strsplit(ln, "|", fixed = TRUE)[[1]]
    if (length(parts) > 0L && parts[1L] == "") parts <- parts[-1L]
    while (length(parts) > 0L && parts[length(parts)] == "") {
      parts <- parts[-length(parts)]
    }
    if (length(parts) == 0L) next
    if (has_separate_cmd_group) {
      cmd_part <- parts[1L]
      player_parts <- if (length(parts) > 1L) parts[-1L] else character(0)
    } else {
      cmd_part <- ""
      player_parts <- parts
    }
    cmd <- 0L
    if (nzchar(cmd_part)) {
      cmd_chars <- strsplit(substr(cmd_part, 1L, 31L), "", fixed = TRUE)[[1]]
      for (bi in seq_along(cmd_chars)) {
        ch <- cmd_chars[bi]
        if (ch != "." && ch != " ") cmd <- bitwOr(cmd, bitwShiftL(1L, bi - 1L))
      }
    }
    commands[fi] <- cmd
    n_to_loop <- min(n_players, length(player_parts))
    for (p_idx in seq_len(max(0L, n_to_loop))) {
      col <- player_parts[p_idx]
      # N64 / PSX BizHawk player cols are
      # "<int1>,<int2>,...,<button_chars>". Split off the leading ints
      # and parse them as analog channels.
      int_strs <- character(0)
      if (grepl(",", col, fixed = TRUE)) {
        last_comma <- max(gregexpr(",", col, fixed = TRUE)[[1L]])
        head <- substr(col, 1L, last_comma - 1L)
        col <- substr(col, last_comma + 1L, nchar(col))
        int_strs <- trimws(strsplit(head, ",", fixed = TRUE)[[1L]])
        if (has_analog && !is.null(per_player_analog) && p_idx <= length(per_player_analog)) {
          axis_vals <- list()
          for (entry in per_player_analog[[p_idx]]) {
            ii <- entry$int_idx + 1L
            if (ii > length(int_strs)) next
            s <- int_strs[ii]
            if (!nzchar(s) || s == "." ) next
            v <- suppressWarnings(as.integer(s))
            if (is.na(v)) next
            # PSX cores log unsigned axes (128 is centre); N64 and most other
            # cores log signed axes. Determine the convention from metadata,
            # not from the current sample: unsigned values below 128 are just
            # as important as values above it.
            if (unsigned_analog) {
              if (v < 0L || v > 255L) next
              v <- v - 128L
            } else if (v > 127L && v <= 255L) {
              v <- v - 256L
            }
            axis_vals[[entry$axis]] <- v
          }
          # Quantise main stick (lstick) to 8 directions, slots 21..28.
          if (!is.null(axis_vals$lstick_x) || !is.null(axis_vals$lstick_y)) {
            sx <- if (is.null(axis_vals$lstick_x)) 0L else axis_vals$lstick_x
            sy <- if (is.null(axis_vals$lstick_y)) 0L else axis_vals$lstick_y
            if (sx * sx + sy * sy >= .BK2_STICK_DEADZONE * .BK2_STICK_DEADZONE) {
              # Invert Y so up is positive (matches the m64 convention).
              angle <- atan2(-sy, sx)
              sector <- as.integer((angle + pi / 8) %/% (pi / 4)) %% 8L
              inputs[fi, p_idx, .STICK_SECTOR_TO_UNI[sector + 1L]] <- TRUE
            }
          }
          # Quantise right stick (rstick) onto the 4 cardinal C-slots.
          if (!is.null(axis_vals$rstick_x) || !is.null(axis_vals$rstick_y)) {
            rx <- if (is.null(axis_vals$rstick_x)) 0L else axis_vals$rstick_x
            ry <- if (is.null(axis_vals$rstick_y)) 0L else axis_vals$rstick_y
            if (rx * rx + ry * ry >= .BK2_STICK_DEADZONE * .BK2_STICK_DEADZONE) {
              if (abs(rx) >= abs(ry)) {
                inputs[fi, p_idx, if (rx > 0L) 17L else 18L] <- TRUE
              } else {
                inputs[fi, p_idx, if (ry > 0L) 19L else 20L] <- TRUE
              }
            }
          }
        }
      }
      if (!is.null(per_player_map)) {
        # Use LogKey-derived mapping.
        if (p_idx <= length(per_player_map)) {
          for (entry in per_player_map[[p_idx]]) {
            cp <- entry$col_pos + 1L
            if (cp <= nchar(col)) {
              ch <- substr(col, cp, cp)
              if (ch != "." && ch != " ") {
                inputs[fi, p_idx, entry$slot] <- TRUE
              }
            }
          }
        }
      } else {
        # Positional NES fallback.
        col_chars <- strsplit(col, "", fixed = TRUE)[[1L]]
        cols_to_check <- min(length(.BK2_POS_TO_UNI), length(col_chars))
        for (bk_pos in seq_len(cols_to_check)) {
          ch <- col_chars[bk_pos]
          if (ch == "." || ch == " ") next
          inputs[fi, p_idx, .BK2_POS_TO_UNI[bk_pos]] <- TRUE
        }
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
