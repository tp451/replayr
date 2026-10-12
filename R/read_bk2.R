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
  "\u2192" = 1L, "\u2190" = 2L, "\u2193" = 3L, "\u2191" = 4L,
  # Start / Select
  "start" = 5L, "select" = 6L,
  "\u5f00\u59cb" = 5L, "\u9009\u62e9" = 6L,
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
  # Dedicated private slots for PSX stick clicks.
  "l3" = 41L, "r3" = 42L,
  "left stick, button" = 41L, "right stick, button" = 42L,
  "analog" = 15L,
  # Private wire slots for digits 0-9. Named LogKey decoding resolves
  # Enter/Clear and Star/Pound separately in .bk2_control_key().
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
  # Legacy wire-slot fallback. Named LogKey decoding preserves all
  # sixteen disc directions as separate intv_disc_* source controls.
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
  # channels retained alongside the button states.
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
  "button 5" = 11L, "button 6" = 12L,
  "d" = 43L, "attack" = 44L, "jump" = 45L,
  "gun trigger" = 46L, "offscreen shot" = 47L,
  "left button" = 48L, "middle button" = 49L, "right button" = 50L,
  "missile button" = 51L, "view change" = 52L,
  "gun button" = 46L, "viewport change button" = 52L,
  "mouse left" = 48L, "mouse right" = 50L,
  # NESControllers.PowerPad declares these twelve separate floor sensors.
  # Their serial order is supplied by the LogKey, not their numeric labels.
  stats::setNames(53:64, paste0("pp", 1:12)),
  "button 7" = 65L, "jump/start" = 66L, "kick" = 67L, "punch" = 68L,
  # QuickNES calls the Famicom P2 microphone "M"; NesHawk spells it out.
  "microphone" = 69L, "m" = 69L
)

# Substrings that mark analog / sensor / non-button channels. "disc" catches
# the Intellivision control disc when a core logs it as numeric "Disc X|Disc Y"
# axes (rather than the 16 named-direction boolean columns N|NNE|... that other
# INTV bk2s use). Without this the two numeric axis columns are treated as
# unmapped buttons, consuming column positions that the frame parser then
# comma-strips -- shifting every keypad/side button read by two and zeroing the
# whole track.
.BK2_ANALOG_HINTS <- c("axis", "tilt", "sensor", "accel", "gyro", "stick", "disc", "paddle", "motion", "dial")

# Source definitions: BizHawk NESControllers.cs (Zapper, PowerPad),
# SNES/LibsnesControllerDeck.cs (Mouse), and SaturnusControllerDeck.cs v2.2.1
# (3D pad). The latter's shoulder fields are numeric only in its analogue
# controller group; they must not consume Boolean character positions.
.bk2_is_numeric_control <- function(key, group_names) {
  group_keys <- tolower(trimws(sub("^P[0-9]+ ", "", group_names)))
  phaser <- all(c("x", "y", "trigger") %in% group_keys) &&
    all(group_keys %in% c("x", "y", "trigger", "offscreen shot"))
  if (phaser && key %in% c("x", "y")) return(TRUE)
  if (grepl("stick, button$", key) || key == "tilt") return(FALSE)
  if (key %in% c("left shoulder", "right shoulder") &&
      any(grepl("stick horizontal|stick vertical", tolower(group_names)))) return(TRUE)
  any(vapply(.BK2_ANALOG_HINTS, function(h) grepl(h, key, fixed = TRUE), logical(1))) ||
    grepl("^(lightgun|zapper|mouse) [xy]( [0-9]+)?$", key) ||
    key %in% c("disk index", "input cycle", "reset cycle", "reset instruction")
}

# Tag an analog-channel name as 'lstick_x' / 'lstick_y' / 'rstick_x' /
# 'rstick_y' / NA. NA means drop the column entirely (sensors like GBA
# tilt / light, which TAS movies leave at default values).
.classify_analog_pair <- function(name_lower) {
  name_lower <- sub("^p[0-9]+ +", "", name_lower)
  if (name_lower == "stick horizontal") return("lstick_x")
  if (name_lower == "stick vertical") return("lstick_y")
  if (grepl("^p[1-4] paddle$|^paddle$", name_lower)) return("paddle_position")
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
  if (grepl("left stick left / right", name_lower)) return("lstick_x")
  if (grepl("left stick up / down", name_lower)) return("lstick_y")
  if (grepl("right stick left / right", name_lower)) return("rstick_x")
  if (grepl("right stick up / down", name_lower)) return("rstick_y")
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
.parse_bk2_logkey <- function(logkey, inactive_ports = integer()) {
  columns <- strsplit(sub("^LogKey:", "", logkey), "|", fixed = TRUE)[[1L]]
  groups <- list(); current <- character()
  for (name in columns[nzchar(columns)]) {
    if (startsWith(name, "#")) {
      if (length(current)) groups[[length(groups) + 1L]] <- current
      current <- substring(name, 2L)
    } else current <- c(current, name)
  }
  if (length(current)) groups[[length(groups) + 1L]] <- current
  inactive_controls <- character()
  if (length(inactive_ports)) {
    for (i in seq_along(groups)) {
      controls <- groups[[i]]
      ports <- suppressWarnings(as.integer(sub("^P([0-9]+) .*", "\\1", controls)))
      inactive <- !is.na(ports) & ports %in% inactive_ports
      inactive_controls <- c(inactive_controls, controls[inactive])
      groups[[i]] <- controls[!inactive]
    }
    groups <- groups[lengths(groups) > 0L]
  }
  if (!length(groups)) stop("empty bk2 LogKey")
  # LogKeys describe stream order. Global controls can follow a player group
  # (Saturn SMPC reset), or share its group (handheld and MAME controls).
  source <- list(); player_names <- list(); commands <- character()
  command_numeric <- logical(); player_ports <- integer()
  shared <- length(groups) == 1L && !any(grepl("^P[0-9]+ ", groups[[1L]]))
  for (group in groups) {
    entries <- list()
    for (name in group) {
      key <- tolower(trimws(sub("^P[0-9]+ ", "", name)))
      numeric <- .bk2_is_numeric_control(key, group)
      port <- if (grepl("^P[0-9]+ ", name)) as.integer(sub("^P([0-9]+) .*", "\\1", name)) else NA_integer_
      system <- key %in% c("power", "reset", "smpc reset") ||
        grepl("^(coin |service|[1-4] players? start$|tilt$|st-v (test|service|pause)$)", key) ||
        (is.na(port) && !shared)
      if (system) {
        commands <- c(commands, name); command_numeric <- c(command_numeric, numeric)
        destination <- 0L
      } else {
        if (is.na(port)) port <- 1L
        if (!port %in% player_ports) {
          player_ports <- c(player_ports, port)
          player_names[[length(player_ports)]] <- character()
        }
        destination <- match(port, player_ports)
        player_names[[destination]] <- c(player_names[[destination]], name)
      }
      entries[[length(entries) + 1L]] <- list(name = name, numeric = numeric, player = destination)
    }
    # Bk2Controller emits axes before Boolean controls within each group.
    numeric <- vapply(entries, function(e) e$numeric, logical(1))
    source <- c(source, entries[c(which(numeric), which(!numeric))])
  }
  if (!length(player_names)) stop("bk2 LogKey declares no controller controls")
  commands <- commands[c(which(command_numeric), which(!command_numeric))]
  maps <- axes <- unknown <- vector("list", length(player_names))
  analog_count <- button_count <- integer(length(player_names))
  non_stick <- integer()
  psx <- any(grepl("[\u25B3\u25A1\u25CB]", unlist(player_names)))
  for (p in seq_along(player_names)) {
    group <- player_names[[p]]
    gun <- (any(grepl("(^| )([Oo]ffscreen [Ss]hot|[Tt]rigger)$", group)) &&
      any(grepl("[XYxy] Axis$", group))) || any(grepl("[Zz]apper [XYxy]$", group)) ||
      all(c("x", "y", "trigger") %in% tolower(sub("^P[0-9]+ ", "", group)))
    if (gun) non_stick <- c(non_stick, p)
    for (name in group) {
      key <- tolower(trimws(sub("^P[0-9]+ ", "", name)))
      numeric <- .bk2_is_numeric_control(key, group)
      if (numeric) {
        axis <- if (gun) NA_character_ else .classify_analog_pair(tolower(name))
        axes[[p]][[length(axes[[p]]) + 1L]] <- list(int_idx = analog_count[p], axis = axis, name = name)
        analog_count[p] <- analog_count[p] + 1L
      } else {
        slot <- if (psx && key == "x") 7L else if (gun && key %in% c("trigger", "fire")) 46L else unname(.BK2_NAME_TO_UNI[key])
        if (length(slot) == 1L && !is.na(slot)) {
          maps[[p]][[length(maps[[p]]) + 1L]] <- list(col_pos = button_count[p], slot = slot)
        } else if (!grepl("^mode: set [26]-button$", key)) {
          unknown[[p]][[length(unknown[[p]]) + 1L]] <- list(col_pos = button_count[p], name = name)
        }
        button_count[p] <- button_count[p] + 1L
      }
    }
  }
  if (any(vapply(seq_along(maps), function(p) length(unknown[[p]]) > length(maps[[p]]), logical(1))))
    stop("bk2 LogKey is unsupported or too sparse for its input columns")
  list(commands = commands, command_analog_count = sum(command_numeric),
       btn_map = maps, analog_map = axes, unknown_map = unknown,
       analog_count = analog_count, button_count = button_count,
       source = source, player_names = player_names, player_ports = player_ports,
       non_stick_players = non_stick, source_group_lengths = lengths(groups),
       n_logkey_groups = length(groups), inactive_controls = inactive_controls)
}

# BizHawk skips pipes while consuming its declared controls. Decode that stream
# first, then rebuild convenient command/player fields. Never infer a control
# from its pressed-character mnemonic or assign a global dial to a gamepad.
.bk2_normalize_rows <- function(rows, parsed) {
  stream <- gsub("|", "", rows, fixed = TRUE)
  values <- vector("list", length(parsed$source))
  text <- vector("list", length(parsed$source))
  for (i in seq_along(parsed$source)) {
    entry <- parsed$source[[i]]
    if (entry$numeric) {
      lengths <- attr(regexpr("^[[:space:]]*[+-]?[0-9]+,", stream), "match.length")
      bad <- which(lengths < 1L)
      if (length(bad)) stop("bk2 numeric field is invalid at sample ", bad[1L])
      text[[i]] <- substring(stream, 1L, lengths)
      values[[i]] <- as.numeric(sub(",$", "", text[[i]]))
      stream <- substring(stream, lengths + 1L)
    } else {
      bad <- which(!nzchar(stream) | startsWith(stream, ","))
      if (length(bad)) stop("bk2 controller stream is truncated at sample ", bad[1L])
      text[[i]] <- substring(stream, 1L, 1L)
      values[[i]] <- if (entry$player == 0L) !text[[i]] %in% c(".", " ") else text[[i]] != "."
      stream <- substring(stream, 2L)
    }
  }
  permitted <- parsed$command_analog_count > 0L & grepl("^[.[:space:]]*[+-]?[0-9]+,", stream)
  if (any(grepl(",", stream, fixed = TRUE) & !permitted))
    stop("bk2 input columns disagree with their LogKey: unconsumed numeric field")
  destination <- vapply(parsed$source, function(e) e$player, integer(1))
  numeric <- vapply(parsed$source, function(e) e$numeric, logical(1))
  groups <- list()
  targets <- c(if (length(parsed$commands)) 0L, seq_along(parsed$btn_map))
  for (p in targets) {
    indices <- which(destination == p)
    indices <- indices[c(which(numeric[indices]), which(!numeric[indices]))]
    groups[[length(groups) + 1L]] <- if (length(indices)) do.call(paste0, text[indices]) else rep("", length(rows))
  }
  normalized <- paste0("|", do.call(paste, c(groups, sep = "|")), "|")
  original_groups <- split(seq_along(text), rep(seq_along(parsed$source_group_lengths), parsed$source_group_lengths))
  original <- lapply(original_groups, function(indices) do.call(paste0, text[indices]))
  original <- paste0("|", do.call(paste, c(original, sep = "|")), "|")
  system <- data.frame(row.names = seq_along(rows))
  for (i in which(destination == 0L)) system[[parsed$source[[i]]$name]] <- values[[i]]
  list(rows = normalized, system = system, values = values,
       boundary_samples = which(rows != original),
       trailing_samples = which(nzchar(stream)),
       trailing_active_samples = which(grepl("[^.]", stream)))
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

# Bk2Controller consumes LogKey names only if they exist in the configured
# controller definition. NES movies may retain a default P2 LogKey although
# SyncSettings explicitly unplugs that port. Require the complete known NES
# configuration; a short input row alone never implies an inactive player.
.bk2_inactive_nes_ports <- function(settings) {
  if (!is.list(settings) || anyDuplicated(names(settings))) return(integer())
  settings <- settings[["o"]]
  if (!is.list(settings) || anyDuplicated(names(settings))) return(integer())
  controls <- settings[["Controls"]]
  if (!is.list(controls) || anyDuplicated(names(controls))) return(integer())
  if (identical(controls[["Famicom"]], FALSE) &&
      identical(controls[["NesLeftPort"]], "ControllerNES") &&
      identical(controls[["NesRightPort"]], "UnpluggedNES")) 2L else integer()
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
#' NES paddle positions (0..160) become signed changes: increasing position
#' activates Stick-E and decreasing position activates Stick-W for that sample.
#' A stationary paddle activates neither direction. This is movement sampling,
#' not a claim that holding a paddle position is holding a gamepad direction.
#'
#' Analogue values are retained without projection by default. Use
#' `analog = "quantized"` to enable the direction/threshold mappings
#' described above; [analog_channels()] returns numeric values in either mode.
#'
#' @inheritParams read_movie
#' @param path Path to a .bk2 file.
#' @return A `replayr_movie` object.
#' @noRd
.bk2_archive_info <- function(path) {
  header <- list("_format" = "bk2")
  zip_names <- utils::unzip(path, list = TRUE)$Name

  # Header (usually "Header.txt"; some exports nest it or drop the extension)
  hdr_member <- .bk2_find_member(zip_names, "Header.txt")
  if (!is.na(hdr_member)) {
    raw <- .read_zip_member_text(path, hdr_member, allow_metadata_error = TRUE)
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
  platform <- toupper(if (is.null(header$Platform)) "" else header$Platform)
  sync_member <- .bk2_find_member(zip_names, "SyncSettings.json")
  if (platform %in% c("NES", "FDS") && !is.na(sync_member)) {
    settings_text <- .read_zip_member_text(path, sync_member, allow_metadata_error = TRUE)
    # Some BizHawk exports include an empty settings member. It supplies no
    # controller configuration; the LogKey remains authoritative in that case.
    if (nzchar(trimws(settings_text))) {
      settings <- jsonlite::fromJSON(settings_text, simplifyVector = FALSE)
      inactive_ports <- .bk2_inactive_nes_ports(settings)
      if (length(inactive_ports)) header$inactiveControllerPorts <- inactive_ports
    }
  }
  cmt_member <- .bk2_find_member(zip_names, "Comments.txt")
  if (!is.na(cmt_member)) {
    txt <- trimws(.read_zip_member_text(path, cmt_member, allow_metadata_error = TRUE))
    if (nzchar(txt)) header[["comment"]] <- txt
  }
  il_member <- .bk2_find_member(zip_names, "Input Log.txt")
  if (is.na(il_member)) {
    stop(path, ": bk2 missing Input Log.txt")
  }
  listing <- utils::unzip(path, list = TRUE)
  input_bytes <- listing$Length[match(il_member, listing$Name)]
  list(header = header, member = il_member, input_bytes = input_bytes)
}

.decode_bk2 <- function(path, analog = c("raw", "quantized"), max_input_bytes = 256 * 1024^2) {
  analog <- match.arg(analog)
  if (length(max_input_bytes)!=1L || !is.numeric(max_input_bytes) || !is.finite(max_input_bytes) ||
      max_input_bytes<1 || max_input_bytes>.Machine$integer.max)
    stop("max_input_bytes must be positive and no greater than R's single-string limit (2147483647 bytes)")
  info <- .bk2_archive_info(path)
  header <- info$header; il_member <- info$member; input_bytes <- info$input_bytes
  if (is.finite(input_bytes) && input_bytes > max_input_bytes)
    stop(structure(list(message = paste0("BK2 input log expands to ", format(input_bytes, scientific=FALSE),
      " bytes, exceeding max_input_bytes (", format(max_input_bytes, scientific=FALSE),
      "). Use read_bk2_chunks(path, FUN) to process every observation with a callback in bounded chunks. ",
      if (input_bytes <= .Machine$integer.max)
        "You can increase max_input_bytes in read_bk2() if sufficient memory is available." else
        "This log also exceeds R's hard single-string limit."),
      call = NULL, input_bytes = input_bytes, max_input_bytes = max_input_bytes),
      class = c("replayr_resource_limit", "error", "condition")))
  log_text <- .read_zip_member_text(path, il_member)
  mv <- .parse_bk2_input_log(log_text, header = header, analog = analog)
  mv$source_path <- path
  mv
}

# Extract a single regular member with miniz's CRC check. The caller owns the
# private directory so full-text and streaming readers share the same checks.
.extract_bk2_member <- function(path, member, directory, allow_metadata_error = FALSE) {
  listing <- zip::zip_list(path)
  matches <- which(tolower(listing$filename) == tolower(member))
  if (length(matches) != 1L || listing$filename[matches] != member)
    stop("ZIP archive member is missing or ambiguous: ", member, call. = FALSE)
  entry <- listing[matches, , drop = FALSE]
  if (is.na(entry$type) || entry$type != "file")
    stop("ZIP archive member must be a regular file: ", member, call. = FALSE)
  leaf <- basename(member)
  if (grepl("\\\\", member) || !nzchar(leaf) || leaf %in% c(".", "..") ||
      grepl("[[:cntrl:]:]", leaf) ||
      grepl("^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])([.]|$)", leaf, ignore.case = TRUE))
    stop("ZIP archive member has an unsafe file name", call. = FALSE)
  directory <- normalizePath(directory, winslash = "/", mustWork = TRUE)
  failure <- NULL
  extracted <- tryCatch(zip::unzip(path, files = member, junkpaths = TRUE,
                                  exdir = directory, overwrite = FALSE),
                        error = function(e) { failure <<- e; NULL })
  if (!is.null(failure) && !allow_metadata_error) stop(failure)
  target <- file.path(directory, leaf)
  info <- file.info(target)
  if (!file.exists(target) || isTRUE(info$isdir) || is.na(info$size) ||
      info$size != entry$uncompressed_size)
    stop("ZIP archive extraction did not produce a complete regular file: ", member, call. = FALSE)
  target <- normalizePath(target, winslash = "/", mustWork = TRUE)
  if (dirname(target) != directory || basename(target) != leaf ||
      (!is.null(extracted) && (nrow(extracted) != 1L || extracted$type != "file")))
    stop("ZIP archive extraction produced an unexpected file", call. = FALSE)
  if (!is.null(failure)) {
    # Some published files have a bad Header.txt CRC despite a complete input
    # log. Preserve complete metadata with a warning; input data stay strict.
    warning("ZIP metadata integrity check failed for ", member,
            "; complete extracted metadata retained: ", conditionMessage(failure), call. = FALSE)
  }
  target
}

# Read one member as text. Input logs require CRC verification; metadata can
# retain a full-sized extraction after an integrity error, with a warning.
.read_zip_member_text <- function(zip_path, member, allow_metadata_error = FALSE) {
  td <- tempfile("bk2-")
  if (!dir.create(td, mode = "0700")) stop("Cannot create BK2 extraction directory", call. = FALSE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  fp <- .extract_bk2_member(zip_path, member, td, allow_metadata_error)
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

.parse_bk2_input_log <- function(text, header = list("_format" = "bk2"), analog = c("raw", "quantized")) {
  .parse_bk2_input_lines(strsplit(text, "\n", fixed = TRUE)[[1L]], header, analog)
}

.parse_bk2_input_lines <- function(lines, header = list("_format" = "bk2"), analog = c("raw", "quantized")) {
  analog <- match.arg(analog)
  lines <- sub("\r+$", "", lines)
  platform_text <- tolower(paste(
    unlist(header[intersect(names(header), c("Platform", "Core", "SystemID"))],
           use.names = FALSE),
    collapse = " "
  ))
  unsigned_analog <- grepl(
    "psx|playstation|nymashock|octoshock|psxhawk",
    platform_text
  )
  # Nyma's generic 2.8 axis is 16-bit. The PSX-specific AddAxis override
  # introduced in 2.9 makes these four axes 8-bit. Do not infer the range
  # separately for each sample (a low 16-bit value is still 16-bit).
  version_text <- if (is.null(header$emuVersion)) "" else header$emuVersion
  nyma_16bit <- grepl("nymashock", platform_text) &&
    grepl("(^|[^0-9])2\\.8([. ]|$)", version_text)
  analog_center <- if (nyma_16bit) 32768L else 128L
  analog_max <- if (nyma_16bit) 65535L else 255L
  analog_divisor <- if (nyma_16bit) 256 else 1
  # Octoshock casts the logged integer-valued float to byte (conv.u1),
  # without clamping in the movie adapter. A logged 256 therefore becomes
  # zero, not 255. Keep this core-specific; Nyma has a different input path.
  octoshock_byte_axes <- grepl("octoshock", platform_text)
  octoshock_wrapped_axes <- 0L

  logkey_line <- NULL
  for (ln in lines) {
    if (startsWith(ln, "LogKey:")) {
      logkey_line <- ln
      break
    }
  }

  frame_lines <- lines[startsWith(lines, "|")]
  if(!is.null(logkey_line) && !nzchar(trimws(sub('^LogKey:', '', logkey_line)))) {
    # Empty LogKeys occur in otherwise standard NesHawk movies. The
    # platform header AND every row's fixed NES layout must agree.
    if(!grepl('(^| )nes( |$)|neshawk',platform_text) ||
       !all(grepl('^\\|[^|]{2}\\|[^|]{8}\\|[^|]{8}\\|$',frame_lines)))
      stop('empty bk2 LogKey without a verified NES layout')
    logkey_line <- NULL
    header$logKeyFallback <- 'verified NES header and two 8-button ports'
  }
  if (!is.null(logkey_line) && analog == "raw") {
    return(.bk2_named_log(frame_lines, logkey_line, header))
  }
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
    parsed <- .parse_bk2_logkey(logkey_line, inactive_ports = header$inactiveControllerPorts)
    if (length(parsed$inactive_controls))
      header$inactiveLogKeyControls <- parsed$inactive_controls
    if (!is.null(parsed) && length(parsed$btn_map) > 0L) {
      per_player_map <- parsed$btn_map
      per_player_analog <- parsed$analog_map
      has_separate_cmd_group <- length(parsed$commands) > 0L
      no_cmd_coleco_style <- !has_separate_cmd_group
      header$bk2NonStickPlayers <- parsed$non_stick_players
      header$controllerPorts <- parsed$player_ports
      normalized <- .bk2_normalize_rows(frame_lines, parsed)
      frame_lines <- normalized$rows
      if (length(normalized$boundary_samples)) {
        header$logKeyStreamBoundarySamples <- length(normalized$boundary_samples)
        header$unconsumedTrailingSamples <- length(normalized$trailing_samples)
        header$unconsumedTrailingActiveSamples <- length(normalized$trailing_active_samples)
        warning('bk2 LogKey stream parsing: ', length(normalized$boundary_samples),
                ' noncanonical boundaries; ', length(normalized$trailing_active_samples),
                ' samples have active trailing characters not consumed by BizHawk')
      }
      first_parts <- strsplit(frame_lines[1L], '|', fixed=TRUE)[[1L]][-1L]
      n_groups <- length(first_parts)
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
    if (!any(vapply(per_player_map, length, integer(1))) &&
        !any(vapply(per_player_analog, length, integer(1))))
      stop("bk2 LogKey declares no supported controls")
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
  paddle_previous <- rep(80L, n_players)
  analog_values <- .empty_analog(n_frames, n_players)
  if (has_analog) for (pl in seq_len(n_players)) {
    entries <- per_player_analog[[pl]]
    channels <- vapply(entries, function(e) e$name, character(1))
    analog_values[[pl]] <- .empty_analog(n_frames, 1L, channels)[[1L]]
  }

  if (analog == "raw" && !is.null(per_player_map)) {
    # The stream normalizer has already decoded each field into a vector.
    # Reuse those vectors rather than splitting every observation again.
    source_player <- vapply(parsed$source, function(x) x$player, integer(1))
    source_numeric <- vapply(parsed$source, function(x) x$numeric, logical(1))
    global_bits <- which(source_player == 0L & !source_numeric)
    for (j in seq_len(min(length(global_bits), 31L))) {
      on <- normalized$values[[global_bits[j]]]
      commands[on] <- bitwOr(commands[on], bitwShiftL(1L, j - 1L))
    }
    for (p in seq_len(n_players)) {
      numeric_fields <- which(source_player == p & source_numeric)
      button_fields <- which(source_player == p & !source_numeric)
      for (ai in seq_along(per_player_analog[[p]])) {
        entry <- per_player_analog[[p]][[ai]]
        values <- normalized$values[[numeric_fields[entry$int_idx + 1L]]]
        bad <- which(!is.finite(values))
        if (length(bad)) stop("invalid bk2 numeric channel at sample ", bad[1L])
        analog_values[[p]][, ai] <- values
        if (is.na(entry$axis)) next
        if (entry$axis == "paddle_position") {
          platform <- toupper(if (is.null(header$Platform)) "" else header$Platform)
          if (!platform %in% c("NES", "FDS") || any(values < 0 | values > 160))
            stop("unsupported bk2 paddle platform or position outside 0..160")
        } else if (unsigned_analog) {
          if (octoshock_byte_axes) {
            wrapped <- values < 0 | values > 255
            octoshock_wrapped_axes <- octoshock_wrapped_axes + sum(wrapped)
            values[wrapped] <- values[wrapped] %% 256
          }
          bad <- which(values < 0 | values > analog_max)
          if (length(bad)) stop("bk2 PSX axis outside declared encoding range at sample ", bad[1L])
        }
      }
      for (entry in parsed$unknown_map[[p]]) {
        active <- which(normalized$values[[button_fields[entry$col_pos + 1L]]])
        if (length(active))
          stop("unmapped active bk2 control: ", entry$name, " at sample ", active[1L])
      }
      for (entry in per_player_map[[p]]) {
        values <- normalized$values[[button_fields[entry$col_pos + 1L]]]
        inputs[, p, entry$slot] <- inputs[, p, entry$slot] | values
      }
    }
  } else for (fi in seq_len(n_frames)) {
    ln <- frame_lines[fi]
    parts <- strsplit(ln, "|", fixed = TRUE)[[1]]
    if (length(parts) > 0L && parts[1L] == "") parts <- parts[-1L]
    while (length(parts) > 0L && parts[length(parts)] == "") {
      parts <- parts[-length(parts)]
    }
    if (length(parts) == 0L) next
    if (has_separate_cmd_group) {
      cmd_part <- parts[1L]
      # Disk selection is a numeric state, not a row of pressed command bits.
      if (grepl(',', cmd_part, fixed=TRUE)) cmd_part <- sub('^.*,', '', cmd_part)
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
          for (ai in seq_along(per_player_analog[[p_idx]])) {
            entry <- per_player_analog[[p_idx]][[ai]]
            ii <- entry$int_idx + 1L
            if (ii > length(int_strs)) next
            s <- int_strs[ii]
            if (!nzchar(s) || s == "." ) next
            v <- suppressWarnings(as.numeric(s))
            if (!is.finite(v)) stop("invalid bk2 numeric channel at sample ", fi)
            analog_values[[p_idx]][fi, ai] <- v
            if (is.na(entry$axis)) next
            if (entry$axis == "paddle_position") {
              platform <- toupper(if (is.null(header$Platform)) "" else header$Platform)
              if (!platform %in% c("NES", "FDS") || v < 0L || v > 160L)
                stop("unsupported bk2 paddle platform or position outside 0..160")
              # BizHawk's NES paddle is an absolute position, not a centred
              # stick. Do not wrap values above 127 or count a stationary
              # off-centre position as continuous movement.
              if (analog == "quantized" && v != paddle_previous[p_idx])
                inputs[fi, p_idx, if (v > paddle_previous[p_idx]) 21L else 25L] <- TRUE
              paddle_previous[p_idx] <- v
              next
            }
            # PSX cores log unsigned axes (128 is centre); N64 and most other
            # cores log signed axes. Determine the convention from metadata,
            # not from the current sample: unsigned values below 128 are just
            # as important as values above it.
            if (unsigned_analog) {
              if (octoshock_byte_axes && (v < 0L || v > 255L)) {
                v <- v %% 256L
                octoshock_wrapped_axes <- octoshock_wrapped_axes + 1L
              }
              if (v < 0L || v > analog_max)
                stop('bk2 PSX axis outside declared encoding range at sample ', fi)
              v <- (v - analog_center) / analog_divisor
            } else if (v > 127L && v <= 255L) {
              v <- v - 256L
            }
            axis_vals[[entry$axis]] <- v
          }
          # Quantise main stick (lstick) to 8 directions, slots 21..28.
          if (analog == "quantized" &&
              (!is.null(axis_vals$lstick_x) || !is.null(axis_vals$lstick_y))) {
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
          if (analog == "quantized" &&
              (!is.null(axis_vals$rstick_x) || !is.null(axis_vals$rstick_y))) {
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
        if (p_idx <= length(parsed$analog_count) &&
            (length(int_strs) != parsed$analog_count[p_idx] ||
             nchar(col) != parsed$button_count[p_idx]))
          stop('bk2 input columns disagree with their LogKey at sample ', fi,
               ', player ', p_idx)
        if (p_idx <= length(parsed$unknown_map)) for (entry in parsed$unknown_map[[p_idx]]) {
          ch <- substr(col, entry$col_pos + 1L, entry$col_pos + 1L)
          if (nzchar(ch) && ch != '.')
            stop('unmapped active bk2 control: ', entry$name, ' at sample ', fi)
        }
        # Use LogKey-derived mapping.
        if (p_idx <= length(per_player_map)) {
          for (entry in per_player_map[[p_idx]]) {
            cp <- entry$col_pos + 1L
            if (cp <= nchar(col)) {
              ch <- substr(col, cp, cp)
              if (ch != ".") {
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

  if (octoshock_wrapped_axes > 0L) {
    header$octoshockByteWrappedAxisValues <- octoshock_wrapped_axes
    warning('bk2 Octoshock byte conversion applied to ', octoshock_wrapped_axes,
            ' out-of-range axis values', call.=FALSE)
  }
  movie <- .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    analog = analog_values, analog_mode = analog,
    decoded_button_slots = if (is.null(per_player_map)) 1:8 else sort(unique(unlist(lapply(per_player_map, function(m) vapply(m, function(e) e$slot, integer(1)))))),
    button_mnemonics = .legacy_buttons()[seq_len(n_buttons)],
    button_names = .legacy_button_names()[seq_len(n_buttons)]
  )
  if (!is.null(per_player_map)) movie$system_inputs <- normalized$system
  movie
}


# Additional platform controls follow the emulator's declared names. A keyboard
# key, a calculator key, and a controller button with the same printed letter
# are different controls. Punctuation is escaped rather than discarded.
.bk2_key_slug <- function(x) {
  chars <- strsplit(tolower(trimws(x)), "", fixed = TRUE)[[1L]]
  pieces <- vapply(chars, function(ch) {
    if (grepl("^[a-z0-9]$", ch)) ch else if (ch %in% c(" ", "_")) "_" else
      paste0("u", sprintf("%04x", utf8ToInt(ch)))
  }, character(1))
  gsub("_+", "_", paste0(pieces, collapse = ""))
}

.bk2_source_numeric <- function(key, group, platform) {
  # Names from the respective BizHawk controller definitions. Axis values are
  # signed decimal integers followed by a comma; Boolean controls consume one
  # character. LogKey order is retained, including interleaved numeric fields.
  if (grepl("^key |^joystick (up|down|left|right|button)", key)) return(FALSE)
  if (key %in% c("tilt", "mouse relative toggle", "stick, button")) return(FALSE)
  if (grepl("stick, button$", key)) return(FALSE)
  if (key %in% c("touch x", "touch y", "mic volume", "circle pad x", "circle pad y",
                 "c-stick x", "c-stick y", "hpos", "vpos", "disc select",
                 "disk index", "input cycle", "input length", "reset cycle", "reset instruction")) return(TRUE)
  if (platform == "ARCADE" && key == "throttle stick") return(TRUE)
  if (grepl("^mouse (position |speed |scroll )?[xy]$", key)) return(TRUE)
  if (key %in% c("left shoulder", "right shoulder") &&
      any(grepl("stick horizontal|stick vertical",tolower(group)))) return(TRUE)
  group_keys <- tolower(sub("^P[0-9]+ ","",group))
  if (all(c("x","y","trigger") %in% group_keys) && key %in% c("x","y")) return(TRUE)
  grepl("(^| )axis($| )|^(lightgun|zapper) [xy]( [0-9]+)?$",key) ||
    grepl("^(lstick|rstick|ad stick|circle pad|c-stick|trackball) [xy]( [0-9]+)?$",key) ||
    grepl("^(left|right) stick (left / right|up / down)$|^stick (horizontal|vertical)$",key) ||
    grepl("^(tilt|accel|accelerometer|gyro) [xyz]$|(^| )light sensor$",key) ||
    grepl("^disc [xy]$|^paddle( [xy]( [0-9]+)?)?$|^dial( [0-9]+)?$",key) ||
    grepl("^motion (left / right|up / down)$",key)
}

.bk2_keyboard_control <- function(name, platform, unprefixed) {
  if (platform == "TI83") return(TRUE)
  if (grepl("^key ", name)) return(!platform %in% c("COLECO", "INTV"))
  if (!unprefixed) return(FALSE)
  platform %in% c("APPLEII", "MSX", "O2", "TI83") ||
    (platform == "TIC80" && !grepl("^mouse ", name))
}

.bk2_system_control <- function(key, platform, unprefixed, keyboard) {
  if (key %in% c("\u7535\u6e90", "\u91cd\u8bbe")) return(TRUE)
  if (grepl("^(power|reset|smpc reset|input cycle|input length|reset cycle|reset instruction)$", key)) return(TRUE)
  if (keyboard && grepl("^key ", key)) return(FALSE)
  if (platform == "TI83") return(FALSE)
  if (grepl("^(fds |vs coin|insert coin|coin |service|[0-9]+ players? start$|st-v (test|service|pause)$)", key)) return(TRUE)
  if (key %in% c("disc select", "disk index", "previous disk", "next disk", "open", "close",
      "open tray", "close tray", "toggle cable", "next drive", "next slot", "insert disk", "eject disk",
      "next floppy disk", "previous floppy disk", "swap floppy disk", "next cdrom", "rotate",
      "play tape", "stop tape", "rtz tape", "record tape", "insert next tape", "insert previous tape",
      "next tape block", "prev tape block", "get tape status", "insert next disk", "insert previous disk",
      "get disk status", "subframe", "copyright", "interlace mode")) return(TRUE)
  if (grepl("^toggle (left difficulty|right difficulty|tv type)$", key)) return(TRUE)
  if (platform %in% c("A26", "A2600", "A78", "A7800", "SMS", "GG", "SG1000") &&
      unprefixed && key %in% c("select", "pause")) return(TRUE)
  if (platform == "CHANNELF" && unprefixed && key %in% c("time", "mode", "hold", "start")) return(TRUE)
  FALSE
}

.bk2_control_key <- function(name, platform, group, keyboard) {
  key <- tolower(trimws(sub("^P[0-9]+ ", "", name)))
  if (keyboard) {
    prefix <- if (platform == "TI83") "ti83_" else "keyboard_"
    return(paste0(prefix, .bk2_key_slug(sub("^key ", "", key))))
  }
  if (platform == "INTV" && key == "top") return("intv_top")
  if (platform == "INTV" && key %in% c("n", "nne", "ne", "ene", "e", "ese", "se", "sse",
       "s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw")) return(paste0("intv_disc_", key))
  if (platform == "COLECO" && grepl("^key[0-9]$", key)) return(paste0("keypad_",substring(key,4L)))
  if (platform %in% c("INTV", "COLECO") && key %in% c("enter", "clear", "star", "pound"))
    return(paste0("keypad_", key))
  if (platform %in% c("JAGUAR", "JAGUARCD") && grepl("^[0-9]$", key)) return(paste0("keypad_", key))
  if (platform %in% c("JAGUAR", "JAGUARCD") && key %in% c("asterisk", "pound"))
    return(paste0("keypad_", if (key == "asterisk") "star" else key))
  if (platform %in% c("VB", "VBOY") && grepl("^[lr]_(up|down|left|right)$", key))
    return(paste0(if (startsWith(key, "l_")) "left_dpad_" else "right_dpad_", substring(key, 3L)))
  if (platform == "WSWAN" && grepl("^[xy][1-4]$", key)) return(paste0("wswan_", key))
  if (platform == "CHANNELF" && key %in% c("forward", "back", "ccw", "cw", "pull", "push"))
    return(paste0("channelf_", key))
  if (grepl("^joystick (up|down|left|right)$", key)) return(paste0("dpad_", sub("^joystick ", "", key)))
  if (grepl("^joystick button [0-9]+$", key)) return(paste0("joystick_button_", sub("^joystick button ", "", key)))
  if (key %in% c("mouse left button", "mouse left click")) return("mouse_left")
  if (key %in% c("mouse middle button", "mouse middle click")) return("mouse_middle")
  if (key %in% c("mouse right button", "mouse right click")) return("mouse_right")
  if (key == "fourth button" && platform == "3DO") return("mouse_fourth")
  if (key == "touch") return("touch_contact")
  if (key == "zl") return("l2")
  if (key == "zr") return("r2")
  if (key == "f" && platform == "O2") return("a")
  group_keys <- tolower(sub("^P[0-9]+ ", "", group))
  # Neo Geo's four-button row corresponds to A/B/X/Y. Six-button pads
  # retain C because their independently recorded X button is also present.
  if (platform == "ARCADE" && all(c("a", "b", "c", "d") %in% group_keys) &&
      !any(c("x", "y") %in% group_keys) && key == "c") return("x")
  gun <- any(grepl("zapper|lightgun|hpos|vpos", group_keys)) ||
    ("trigger" %in% group_keys && any(group_keys %in% c("x", "y", "x axis", "y axis")))
  if (gun && key %in% c("trigger", "fire")) return("gun_trigger")
  if (key %in% c("gun trigger", "gun button")) return("gun_trigger")
  # GunCon has a primary trigger plus two separately recorded side buttons.
  if (platform == "PSX" && gun && key %in% c("a","b"))
    return(if(key == "a") "b" else "x")
  if (platform == "PSX" && key == "x") return("b")
  slot <- unname(.BK2_NAME_TO_UNI[key])
  if (length(slot) == 1L && !is.na(slot)) {
    return(.legacy_control_keys()[slot])
  }
  paste0(tolower(platform %||% "bk2"), "_", .bk2_key_slug(key))
}

.bk2_named_log <- function(rows, logkey, header) {
  platform <- toupper(header$Platform %||% "BK2")
  sections <- strsplit(sub("^LogKey:", "", logkey), "#", fixed = TRUE)[[1L]]
  groups <- lapply(sections[nzchar(sections)], function(x) {
    fields <- strsplit(x, "|", fixed = TRUE)[[1L]]
    fields[nzchar(fields)]
  })
  groups <- groups[lengths(groups) > 0L]
  if (!length(groups)) stop("empty bk2 LogKey")
  # BizHawk 2.9.1's MelonDS definition has no Boolean Microphone field.
  # Its Bk2Controller consumes only names present in BoolButtons or Axes,
  # even when a stale LogKey lists a control from another core version.
  # Source: BizHawk/2.9.1, MelonDS.cs:293 and Bk2Controller.cs:80.
  ignored <- character()
  legacy_nds_mic <- platform %in% c("NDS","DS") &&
    identical(tolower(header$Core %||% ""),"melonds") &&
    grepl("(^|[^0-9])2\\.9\\.1([^0-9]|$)",header$emuVersion %||% "")
  entries <- list(); inactive <- character()
  for (gi in seq_along(groups)) for (name in groups[[gi]]) {
    if (legacy_nds_mic && name == "Microphone") {
      ignored <- c(ignored,name)
      next
    }
    unprefixed <- !grepl("^P[0-9]+ ", name)
    port <- if (unprefixed) 1L else as.integer(sub("^P([0-9]+) .*", "\\1", name))
    if (!unprefixed && port %in% header$inactiveControllerPorts) { inactive <- c(inactive, name); next }
    key <- tolower(trimws(sub("^P[0-9]+ ", "", name)))
    keyboard <- .bk2_keyboard_control(key, platform, unprefixed)
    system <- .bk2_system_control(key, platform, unprefixed, keyboard) ||
      (platform == "ARCADE" && unprefixed && length(groups)>1L)
    numeric <- .bk2_source_numeric(key, groups[[gi]], platform)
    entries[[length(entries) + 1L]] <- list(name=name, key=key, port=if(system) 0L else port,
      numeric=numeric, system=system, group=gi, shared=unprefixed && !system,
      identity=if (system || numeric) NA_character_ else .bk2_control_key(name,platform,groups[[gi]],keyboard),
      kind=if(keyboard) "keyboard" else if(grepl("touch|mouse|mic|lid",key)) "peripheral" else "button")
  }
  if (length(inactive)) header$inactiveLogKeyControls <- inactive
  if (length(ignored)) {
    header$ignoredLogKeyControls <- ignored
    header$ignoredLogKeyControlReason <- "Absent from BizHawk 2.9.1 MelonDS controller definition"
    header$sourceLogKey <- logkey
  }
  n <- length(rows)
  stream <- gsub("|", "", rows, fixed=TRUE)
  values <- vector("list",length(entries)); field_text <- vector("list",length(entries))
  for (i in seq_along(entries)) {
    entry <- entries[[i]]
    if (entry$numeric) {
      width <- attr(regexpr("^[[:space:]]*[+-]?[0-9]+,",stream),"match.length")
      bad <- which(width < 1L)
      if(length(bad)) stop("bk2 numeric field '",entry$name,"' is invalid at sample ",bad[1L])
      field_text[[i]] <- substring(stream,1L,width)
      values[[i]] <- as.numeric(sub(",$","",field_text[[i]]))
      stream <- substring(stream,width+1L)
    } else {
      bad <- which(!nzchar(stream))
      if(length(bad)) stop("bk2 controller stream is truncated at '",entry$name,"', sample ",bad[1L])
      field_text[[i]] <- substring(stream,1L,1L)
      values[[i]] <- field_text[[i]] != "."
      stream <- substring(stream,2L)
    }
  }
  # Axis names are supplied by the core, not typed in LogKey. A comma consumed
  # as an ordinary button can therefore reveal an unknown numeric field even
  # when a stale declaration happens to consume the whole row. Preserve the
  # ambiguous source rows instead of silently calling those commas presses.
  comma_rows <- integer(); comma_fields <- character()
  for(i in seq_along(entries)) if(!entries[[i]]$numeric &&
      !entries[[i]]$key %in% c(",","comma","key comma")) {
    at <- which(field_text[[i]] == ",")
    comma_rows <- c(comma_rows,at)
    comma_fields <- c(comma_fields,rep(entries[[i]]$name,length(at)))
  }
  if(length(comma_rows)) {
    header$ambiguousBooleanCommaSamples <- length(unique(comma_rows))
    warning("bk2 comma consumed as a Boolean control in ",length(unique(comma_rows)),
      " samples; the controller schema may contain an unknown numeric field; ",
      "source rows retained in ambiguous_input",call.=FALSE)
  }
  numeric_system <- any(vapply(entries,function(e)e$system && e$numeric,logical(1)))
  if(any(grepl(",",stream,fixed=TRUE)) && !numeric_system)
    stop("bk2 input columns disagree with their LogKey: unconsumed numeric field")
  source_groups <- split(seq_along(entries),vapply(entries,function(e)e$group,integer(1)))
  canonical <- lapply(source_groups,function(ix)do.call(paste0,field_text[ix]))
  canonical <- paste0("|",do.call(paste,c(canonical,sep="|")),"|")
  boundary <- which(rows != canonical)
  if(length(boundary)) {
    header$logKeyStreamBoundarySamples <- length(boundary)
    # Both legacy and current Bk2Controller skip pipe separators between fields.
    # Empty groups and moved display boundaries are valid source syntax.
    header$logKeyBoundaryInterpretation <- "Pipe separators do not delimit controller consumption"
  }
  # Old exports can append a stale, unused group. Preserve the original text
  # and report it instead of interpreting it as a second controller.
  if (any(nzchar(stream))) {
    header$unconsumedTrailingSamples <- sum(nzchar(stream))
    header$unconsumedTrailingActiveSamples <- sum(grepl("[^.]",stream))
    # Bk2Controller stops when it has read the declared controls. Empty
    # unused pads and whitespace-prefixed words are ignored source suffixes,
    # rather than extra inputs. Keep their text and report their counts.
    padding <- nzchar(stream) & !grepl("[^.]",stream)
    annotation <- grepl("^[[:space:]]+[[:alpha:]]{2,}[[:alnum:] _./:-]*$",stream)
    header$sourceTrailingPaddingSamples <- sum(padding)
    header$sourceTrailingAnnotationSamples <- sum(annotation)
    unbound <- nzchar(stream) & !padding & !annotation
    header$sourceTrailingUnboundSamples <- sum(unbound)
    if(any(unbound)) warning("bk2 LogKey leaves trailing source text resembling unbound controls in ",
      sum(unbound)," samples; retained in source_trailing",call.=FALSE)
  }
  ports <- sort(unique(vapply(entries,function(e)e$port,integer(1))))
  ports <- ports[ports>0L]; if(!length(ports)) ports <- 1L
  header$controllerPorts <- ports
  header$bk2NonStickPlayers <- which(vapply(ports,function(p) {
    k <- vapply(entries[vapply(entries,function(e)e$port==p,logical(1))],function(e)e$key,character(1))
    any(grepl("zapper|lightgun|hpos|vpos",k)) ||
      ("trigger" %in% k && any(k %in% c("x","y","x axis","y axis")))
  },logical(1)))
  header$sharedInputControls <- vapply(entries[vapply(entries,function(e)e$shared,logical(1))],function(e)e$name,character(1))
  digital <- which(vapply(entries,function(e)!e$system && !e$numeric,logical(1)))
  # N64 Boolean stick overrides feed the effective analogue vector. Preserve
  # them separately; no invented pressed directions are added in raw mode.
  override <- if(platform == "N64") digital[vapply(entries[digital],function(e)e$key %in% c("a right","a up","a left","a down"),logical(1))] else integer()
  digital <- setdiff(digital,override)
  keys <- unique(vapply(entries[digital],function(e)e$identity,character(1)))
  registry <- .controller_registry(); keys <- c(registry$key[registry$key %in% keys],sort(setdiff(keys,registry$key)))
  labels <- kinds <- character(length(keys))
  inputs <- array(FALSE,c(n,length(ports),length(keys)))
  for(i in digital) {
    e <- entries[[i]]; p <- match(e$port,ports); k <- match(e$identity,keys)
    inputs[,p,k] <- inputs[,p,k] | values[[i]]
    labels[k] <- sub("^P[0-9]+ ","",e$name); kinds[k] <- e$kind
    registered <- match(keys[k], .controller_registry()$key)
    if (!is.na(registered)) kinds[k] <- .controller_registry()$kind[registered]
  }
  raw <- .empty_analog(n,length(ports))
  for(p in seq_along(ports)) {
    fields <- which(vapply(entries,function(e)e$port==ports[p] && e$numeric,logical(1)))
    if(length(fields)) {
      raw[[p]] <- matrix(unlist(values[fields],use.names=FALSE),nrow=n,ncol=length(fields))
      colnames(raw[[p]]) <- vapply(entries[fields],function(e)e$name,character(1))
    }
  }
  if(platform == "PSX") {
    old16 <- grepl("nymashock",tolower(header$Core %||% "")) &&
      grepl("(^|[^0-9])2\\.8([. ]|$)",header$emuVersion %||% "")
    wrapped <- 0L
    for(p in setdiff(seq_along(ports),header$bk2NonStickPlayers)) {
      roles <- vapply(tolower(colnames(raw[[p]])),.classify_analog_pair,character(1))
      axes <- raw[[p]][,!is.na(roles) & roles != "paddle_position",drop=FALSE]
      if(grepl("octoshock",tolower(header$Core %||% ""))) wrapped <- wrapped+sum(axes<0 | axes>255) else
        if(any(axes<0 | axes>if(old16)65535 else 255)) stop("bk2 PSX axis outside declared encoding range")
    }
    if(wrapped) {
      header$octoshockByteWrappedAxisValues <- wrapped
      warning("bk2 Octoshock byte conversion applied to ",wrapped," out-of-range axis values",call.=FALSE)
    }
  }
  system <- which(vapply(entries,function(e)e$system,logical(1)))
  sys <- data.frame(row.names=seq_len(n)); commands <- integer(n); bit <- 0L
  for(i in system) {
    sys[[entries[[i]]$name]] <- values[[i]]
    if(!entries[[i]]$numeric) {
      if(bit<31L) commands[values[[i]]] <- bitwOr(commands[values[[i]]],bitwShiftL(1L,bit))
      bit <- bit+1L
    }
  }
  calibration <- NULL
  # Encore.IInputPollable: both 3DS sticks are -128..127, centre 0,
  # with positive Y pointing up; the core divides both axes by 128.
  if(platform == "3DS") {
    calibration <- lapply(raw,function(ch) {
      out <- list()
      for(side in c("left","right")) {
        prefix <- if(side=="left") "Circle Pad" else "C-Stick"
        pair <- paste(prefix,c("X","Y"))
        if(all(pair %in% colnames(ch))) out[[side]] <- list(x=pair[1L],y=pair[2L],center=c(0,0),scale=c(128,128),sign=c(1,1))
      };out
    })
  }
  movie <- .new_named_movie(header,commands,inputs,keys,analog=raw,names=labels,kinds=kinds,stick_calibration=calibration)
  movie$system_inputs <- sys
  movie$source_controls <- data.frame(name=vapply(entries,function(e)e$name,character(1)),
    type=vapply(entries,function(e)if(e$numeric)"integer" else "logical",character(1)),
    port=vapply(entries,function(e)e$port,integer(1)),
    key=vapply(entries,function(e)e$identity,character(1)),stringsAsFactors=FALSE)
  if(any(nzchar(stream))) movie$source_trailing <- stream
  if(length(comma_rows)) movie$ambiguous_input <- data.frame(
    observation=comma_rows,field=comma_fields,source_input=rows[comma_rows],
    stringsAsFactors=FALSE)
  movie$stick_overrides <- lapply(ports,function(p) {
    out <- matrix(FALSE,n,4L,dimnames=list(NULL,c("right","up","left","down")))
    for(i in override) if(entries[[i]]$port==p) out[,sub("^a ","",entries[[i]]$key)] <- values[[i]]
    out
  })
  movie
}


#' Process a BizHawk recording in bounded chunks
#'
#' The input member is decompressed once to a temporary file and its ZIP checksum
#' is verified before any callback runs. The temporary file needs disk space equal
#' to the uncompressed log and is removed on exit. It is read sequentially, keeping
#' memory use bounded. Each callback receives a configured movie containing at
#' most `chunk_size` observations. Its header
#' includes `firstObservation` and `lastObservation`, using one-based positions
#' in the original recording. Return a small summary from `FUN` to keep memory
#' use bounded; returning the movie itself retains every chunk in memory.
#'
#' @inheritParams read_movie
#' @param FUN Function called with one movie chunk. Additional arguments in
#'   `...` are passed to this function.
#' @param chunk_size Maximum observations passed to each callback.
#' @param ... Additional arguments for `FUN`.
#' @return A list of callback results, with `observations` and `chunks`
#'   attributes giving the total processed. An empty recording gives a list
#'   with no callback results and zero observations.
#' @examples
#' path <- system.file('extdata', 'expanded', 'two-stick-3ds.bk2', package='replayr')
#' counts <- read_bk2_chunks(path, function(chunk) n_frames(chunk), chunk_size=2L)
#' sum(unlist(counts))
#' attr(counts, 'observations')
#' @export
read_bk2_chunks <- function(path, FUN, chunk_size = 100000L, analog = "raw",
                            deadzone = NULL, triggers = "raw", ...) {
  if (!is.function(FUN)) stop("FUN must be a function")
  if (length(chunk_size)!=1L || !is.numeric(chunk_size) || !is.finite(chunk_size) ||
      chunk_size<1 || chunk_size!=floor(chunk_size) || chunk_size>.Machine$integer.max)
    stop("chunk_size must be a positive integer")
  .stick_modes(analog)
  info <- .bk2_archive_info(path)
  scratch <- tempfile("bk2-chunks-")
  if (!dir.create(scratch, mode = "0700")) stop("Cannot create BK2 extraction directory", call. = FALSE)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  input_path <- .extract_bk2_member(path, info$member, scratch)
  con <- file(input_path, open = "r", encoding = "UTF-8")
  on.exit(close(con), add = TRUE, after = FALSE)
  results <- list(); total <- 0; logkey <- NULL; pending <- character()
  repeat {
    lines <- readLines(con, n=as.integer(chunk_size), warn=FALSE)
    if (!length(lines)) break
    lines <- sub("\r+$", "", lines)
    keys <- lines[startsWith(lines,"LogKey:")]
    if (length(keys)) {
      if (!is.null(logkey) && any(keys != logkey)) stop("BK2 LogKey changes within recording")
      if (is.null(logkey)) logkey <- keys[1L]
      if (any(keys != logkey)) stop("BK2 LogKey changes within recording")
    }
    pending <- c(pending, lines[startsWith(lines,"|")])
    while (length(pending)>=chunk_size) {
      rows <- pending[seq_len(chunk_size)]
      pending <- pending[-seq_len(chunk_size)]
      h <- info$header; h$firstObservation <- total+1; h$lastObservation <- total+length(rows)
      movie <- .parse_bk2_input_lines(c(logkey, rows), h, "raw")
      movie$source_path <- path
      movie <- .configure_movie(movie, analog, deadzone, triggers)
      results[length(results)+1L] <- list(FUN(movie, ...))
      total <- total+length(rows)
    }
  }
  if (length(pending)) {
    h <- info$header; h$firstObservation <- total+1; h$lastObservation <- total+length(pending)
    movie <- .parse_bk2_input_lines(c(logkey, pending), h, "raw")
    movie$source_path <- path
    movie <- .configure_movie(movie, analog, deadzone, triggers)
    results[length(results)+1L] <- list(FUN(movie, ...))
    total <- total+length(pending)
  }
  attr(results,"observations") <- total
  attr(results,"chunks") <- length(results)
  results
}
