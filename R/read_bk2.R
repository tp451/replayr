# BizHawk .bk2 movie format. A ZIP archive whose `Input Log.txt` member
# describes inputs in a syntax similar to FM2:
#
#     [Input]
#     LogKey:#Reset|Power|#P1 Up|P1 Down|...|P1 A|#P2 Up|...
#     |..|........|........|
#
# The LogKey lists the controls by name in the order of the log, and every
# control keeps the name its core gave it. Without a LogKey only the fixed
# rows of two NES pads (UDLRTSBA) are read.
#
# bk2 covers many platforms: NES, SNES, Atari 2600, Game Boy / GBC,
# GBA, N64, PlayStation, ... -- so the LogKey-driven mapping is the
# reliable way to interpret column data across these systems.
#
# Reference: BizHawk source (BizHawk.Client.Common, MovieControllerAdapter)
# and the tasvideos wiki at /EmulatorResources/BizHawk/Bk2.
# NES positional fallback for a missing LogKey. Header and row checks
# below restrict this interpretation to compatible eight-button records.
.BK2_POS_TO_UNI <- c(
  4L, # 1: U -> universal 4 (Up)
  3L, # 2: D -> universal 3 (Down)
  2L, # 3: L -> universal 2 (Left)
  1L, # 4: R -> universal 1 (Right)
  5L, # 5: T -> universal 5 (Start)
  6L, # 6: S -> universal 6 (Select)
  7L, # 7: B -> universal 7
  8L # 8: A -> universal 8
)
# Map BizHawk button-name (lowercase) -> 1-based private-slot index, from
# which a named control takes its shared identity. Extends the FM2 NES set
# with SNES X/Y, shoulders, Genesis C/Mode, N64 Z and C-buttons, and PSX
# face buttons.
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
  # N64: BizHawk's Boolean columns for the directions of the analogue stick
  "a up" = 23L, # stick-N
  "a down" = 27L, # stick-S
  "a left" = 25L, # stick-W
  "a right" = 21L, # stick-E
  # N64: C-buttons
  "c up" = 20L, "c down" = 19L, "c right" = 17L, "c left" = 18L,
  # PSX BizHawk LogKey extras (word style + digit-suffixed shoulders)
  "triangle" = 9L, "square" = 10L, "cross" = 7L, "circle" = 8L,
  # PSX BizHawk LogKey extras (Unicode-glyph style -- Nymashock)
  "\u25B3" = 9L, # Triangle
  "\u25A1" = 10L, # Square
  "\u25CB" = 8L, # Circle
  "\u2715" = 7L, # Cross
  "l1" = 11L, "r1" = 12L, "l2" = 29L, "r2" = 30L,
  # Dedicated private slots for PSX stick clicks.
  "l3" = 41L, "r3" = 42L,
  "left stick, button" = 41L, "right stick, button" = 42L,
  "analog" = 15L,
  # Private wire slots for digits 0-9. Named LogKey decoding resolves
  # Enter/Clear and Star/Pound separately in .bk2_control_key().
  "key 0" = 31L, "key 1" = 32L, "key 2" = 33L, "key 3" = 34L, "key 4" = 35L,
  "key 5" = 36L, "key 6" = 37L, "key 7" = 38L, "key 8" = 39L, "key 9" = 40L,
  "enter" = 5L, "clear" = 6L, # INTV
  "star" = 5L, "pound" = 6L, # Coleco
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
  # "Button 6", mapped to the SNES face-button layout (A/B for
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
# Identify stick axes by the names BizHawk gives them. NA means that a
# channel is not a stick axis; named imports retain other numeric channels.
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
  # MAME's analogue joysticks; the fields of its second player are the
  # second joystick.
  if (name_lower == "ad stick x") return("lstick_x")
  if (name_lower == "ad stick y") return("lstick_y")
  if (name_lower == "ad stick x 2") return("rstick_x")
  if (name_lower == "ad stick y 2") return("rstick_y")
  if (grepl("x axis", name_lower)) return("lstick_x")
  if (grepl("y axis", name_lower)) return("lstick_y")
  # The Intellivision control disc, where a core logs it as two numeric axes.
  if (grepl("disc x", name_lower)) return("lstick_x")
  if (grepl("disc y", name_lower)) return("lstick_y")
  NA_character_
}
# Locate a bk2 member by its canonical name, tolerating two export
# variants: a leading "<game folder>/" subdirectory prefix (some BizHawk builds
# nest every member under a ROM-named directory) and a missing ".txt" extension
# (older cores wrote "Input Log" / "Header" plain). Returns the actual member
# name for archive extraction, or NA if the member is absent.
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
# BizHawk writes the hash of the game under the key SHA1 whatever it is.
# Several cores write an MD5 there (Genesis, PC Engine, Nintendo DS and
# others), old Master System cores the CRC32 of the ROM, and the PlayStation
# core its own CRC32 of part of the disc. The number of hexadecimal digits
# tells them apart; any other value, such as N/A, is no hash.
.bizhawk_hash_kind <- function(hash) {
  if (!grepl("^[0-9A-Fa-f]+$", hash)) return("")
  switch(as.character(nchar(hash)), "40" = "SHA1", "32" = "MD5", "8" = "CRC32", "")
}
# Read BK2 metadata independently of the input log.
.bk2_archive_info <- function(path) {
  if (!.is_zip_archive(path))
    stop(path, ": not a BizHawk movie (BK2, TASPROJ or GBMV): a ZIP archive is expected", call. = FALSE)
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
        k <- line
        v <- ""
      }
      if (!is.null(header[[k]])) {
        header[[k]] <- paste(header[[k]], v, sep = "\n")
      } else {
        header[[k]] <- v
      }
    }
  }
  if (!is.null(header$SHA1)) header$SHA1Kind <- .bizhawk_hash_kind(header$SHA1)
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
.decode_bk2 <- function(path, max_input_bytes = 256 * 1024^2) {
  if (length(max_input_bytes) != 1L || !is.numeric(max_input_bytes) || !is.finite(max_input_bytes) ||
    max_input_bytes < 1 || max_input_bytes > .Machine$integer.max)
    stop("max_input_bytes must be positive and no greater than R's single-string limit (2147483647 bytes)")
  info <- .bk2_archive_info(path)
  header <- info$header
  il_member <- info$member
  input_bytes <- info$input_bytes
  if (is.finite(input_bytes) && input_bytes > max_input_bytes)
    stop(structure(
      list(
        message = paste0(
          "BK2 input log expands to ", format(input_bytes, scientific = FALSE),
          " bytes, exceeding max_input_bytes (", format(max_input_bytes, scientific = FALSE),
          "). Use read_bk2_chunks(path, FUN) to process every observation with a callback in bounded chunks. ",
          if (input_bytes <= .Machine$integer.max)
            "You can increase max_input_bytes in read_bk2() if sufficient memory is available." else
            "This log also exceeds R's hard single-string limit."
        ),
        call = NULL, input_bytes = input_bytes, max_input_bytes = max_input_bytes
      ),
      class = c("replayr_resource_limit", "error", "condition")
    ))
  log_text <- .read_zip_member_text(path, il_member)
  mv <- .parse_bk2_input_log(log_text, header = header)
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
  extracted <- tryCatch(
    zip::unzip(path,
      files = member, junkpaths = TRUE,
      exdir = directory, overwrite = FALSE
    ),
    error = function(e) {
      failure <<- e
      NULL
    }
  )
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
      "; complete extracted metadata retained: ", conditionMessage(failure),
      call. = FALSE
    )
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
.parse_bk2_input_log <- function(text, header = list("_format" = "bk2")) {
  .parse_bk2_input_lines(strsplit(text, "\n", fixed = TRUE)[[1L]], header)
}
# BizHawk reads a LogKey, and an input row, only at the start of a line. A
# log whose LogKey line is indented still declares its layout there, so the
# layout is taken from it, with a warning. Indented input rows are not
# records for BizHawk and stay excluded.
.bk2_logkey_lines <- function(lines) {
  exact <- which(startsWith(lines, "LogKey:"))
  if (length(exact)) return(list(logkey = lines[exact[1L]], indented = FALSE, indented_rows = 0L))
  spaced <- which(startsWith(lines, " ") | startsWith(lines, "\t"))
  keys <- spaced[grepl("^[[:space:]]+LogKey:", lines[spaced])]
  if (!length(keys)) return(list(logkey = NULL, indented = FALSE, indented_rows = 0L))
  list(
    logkey = sub("^[[:space:]]+", "", lines[keys[1L]]), indented = TRUE,
    indented_rows = sum(grepl("^[[:space:]]+[|]", lines[spaced]))
  )
}
# Gym Retro means to write "LogKey:#Reset|Power|#" before the names of its
# controls, but writes the names over that text (openai/retro,
# src/movie-bk2.cpp, writeHeader()). Its logs therefore name the players'
# controls in a line without the prefix, while every row keeps the group of
# Reset and Power. The LogKey it meant is put together again.
.bk2_retro_logkey <- function(lines, header) {
  if (!identical(header$MovieVersion, "Retro")) return(NULL)
  named <- lines[grepl("^(P[0-9]+ [A-Za-z]+[|])+$", lines)]
  if (length(named) != 1L) return(NULL)
  # On a Master System or Game Gear pad Gym Retro writes B for button 1 and A
  # for button 2 (cores/genesis/libretro/libretro.c, DEVICE_PAD2B). They get
  # the names BizHawk writes for these buttons, so that each has one ID.
  if (toupper(header$Platform %||% "") %in% c("SMS", "GAMEGEAR")) {
    named <- gsub("(P[0-9]+) B[|]", "\\1 B1|", named)
    named <- gsub("(P[0-9]+) A[|]", "\\1 B2|", named)
  }
  paste0("LogKey:#Reset|Power|#", named)
}
.BK2_RETRO_NOTE <- "Gym Retro names its controls in a line without the LogKey prefix"
.bk2_indented_logkey_message <- function(indented_rows) {
  paste0(
    "bk2 LogKey line is indented; its control layout is used",
    if (indented_rows > 0L) paste0(
      "; ", indented_rows,
      " indented input line(s) are not records for BizHawk and are excluded"
    )
  )
}
# The line that declares the controls and the input rows of a log. Without
# named controls only the fixed NES layout can be verified: the platform
# header AND every row must agree. Any other log would be read as
# plausible-looking, incorrect buttons.
.bk2_layout_source <- function(lines, header) {
  platform_text <- tolower(paste(
    unlist(header[intersect(names(header), c("Platform", "Core", "SystemID"))], use.names = FALSE),
    collapse = " "
  ))
  found <- .bk2_logkey_lines(lines)
  logkey_line <- found$logkey
  frame_lines <- lines[startsWith(lines, "|")]
  if (found$indented) {
    header$logKeyIndented <- TRUE
    header$indentedInputLines <- found$indented_rows
    warning(.bk2_indented_logkey_message(found$indented_rows))
  }
  if (is.null(logkey_line)) {
    logkey_line <- .bk2_retro_logkey(lines, header)
    if (!is.null(logkey_line)) header$logKeyRestored <- .BK2_RETRO_NOTE
  }
  verified_nes <- function() grepl("(^| )nes( |$)|neshawk", platform_text) &&
    all(grepl("^\\|[^|]{2}\\|[^|]{8}\\|[^|]{8}\\|$", frame_lines))
  if (!is.null(logkey_line) && !nzchar(trimws(sub("^LogKey:", "", logkey_line)))) {
    # Empty LogKeys occur in otherwise standard NesHawk movies.
    if (!verified_nes()) stop("empty bk2 LogKey without a verified NES layout")
    logkey_line <- NULL
    header$logKeyFallback <- "verified NES header and two 8-button ports"
  } else if (is.null(logkey_line) && length(frame_lines)) {
    if (!verified_nes()) stop("bk2 input log has no LogKey line and no verified NES layout")
    header$logKeyFallback <- "verified NES header and two 8-button ports"
  }
  list(logkey = logkey_line, rows = frame_lines, header = header)
}
.parse_bk2_input_lines <- function(lines, header = list("_format" = "bk2")) {
  declared <- .bk2_layout_source(sub("\r+$", "", lines), header)
  if (!is.null(declared$logkey)) {
    return(.bk2_named_log(declared$rows, declared$logkey, declared$header))
  }
  .bk2_nes_rows(declared$rows, declared$header)
}
# The groups of one input row: the text between its pipes, without the empty
# pieces before the first and after the last pipe.
.bk2_row_groups <- function(row) {
  parts <- strsplit(row, "|", fixed = TRUE)[[1]]
  if (length(parts) > 0L && parts[1L] == "") parts <- parts[-1L]
  while (length(parts) > 0L && parts[length(parts)] == "") {
    parts <- parts[-length(parts)]
  }
  parts
}
# The command bits of a row: one bit for each of the first 31 characters of
# the system group that is not a dot.
.bk2_command_bits <- function(text) {
  bits <- 0L
  if (nzchar(text)) {
    chars <- strsplit(substr(text, 1L, 31L), "", fixed = TRUE)[[1]]
    for (i in seq_along(chars)) if (chars[i] != ".") bits <- bitwOr(bits, bitwShiftL(1L, i - 1L))
  }
  bits
}
# The rows of a log without LogKey: NES pads, read by position.
.bk2_nes_rows <- function(rows, header) {
  if (length(rows) == 0L) {
    return(.new_movie(
      header = header,
      commands = integer(0),
      inputs = .empty_inputs(0L, 1L, 8L),
      button_mnemonics = .NES_BUTTONS,
      button_names = c(
        "Right", "Left", "Down", "Up",
        "Start", "Select", "B", "A"
      )
    ))
  }
  n <- length(rows)
  n_players <- max(length(.bk2_row_groups(rows[1L])) - 1L, 1L)
  inputs <- .empty_inputs(n, n_players, 8L)
  commands <- integer(n)
  for (i in seq_len(n)) {
    parts <- .bk2_row_groups(rows[i])
    if (length(parts) == 0L) next
    # A number before a comma is a state of the system, not a pressed bit.
    commands[i] <- .bk2_command_bits(sub("^.*,", "", parts[1L]))
    pads <- parts[-1L]
    for (p in seq_len(min(n_players, length(pads)))) {
      chars <- strsplit(sub("^.*,", "", pads[p]), "", fixed = TRUE)[[1L]]
      chars <- chars[seq_len(min(length(.BK2_POS_TO_UNI), length(chars)))]
      inputs[i, p, .BK2_POS_TO_UNI[which(chars != ".")]] <- TRUE
    }
  }
  .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    analog = .empty_analog(n, n_players),
    decoded_button_slots = 1:8,
    button_mnemonics = .legacy_buttons()[seq_len(8L)],
    button_names = .legacy_button_names()[seq_len(8L)]
  )
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
  if (key %in% c(
    "touch x", "touch y", "mic volume", "circle pad x", "circle pad y",
    "c-stick x", "c-stick y", "hpos", "vpos", "disc select",
    "disk index", "input cycle", "input length", "reset cycle", "reset instruction"
  )) return(TRUE)
  if (platform == "ARCADE" && key == "throttle stick") return(TRUE)
  if (grepl("^mouse (position |speed |scroll )?[xy]$", key)) return(TRUE)
  if (key %in% c("left shoulder", "right shoulder") &&
    any(grepl("stick horizontal|stick vertical", tolower(group)))) return(TRUE)
  group_keys <- tolower(sub("^P[0-9]+ ", "", group))
  if (all(c("x", "y", "trigger") %in% group_keys) && key %in% c("x", "y")) return(TRUE)
  grepl("(^| )axis($| )|^(lightgun|zapper) [xy]( [0-9]+)?$", key) ||
    grepl("^(lstick|rstick|ad stick|circle pad|c-stick|trackball) [xy]( [0-9]+)?$", key) ||
    grepl("^(left|right) stick (left / right|up / down)$|^stick (horizontal|vertical)$", key) ||
    grepl("^(tilt|accel|accelerometer|gyro) [xyz]$|(^| )light sensor$", key) ||
    grepl("^disc [xy]$|^paddle( [xy]( [0-9]+)?)?$|^dial( [0-9]+)?$", key) ||
    grepl("^motion (left / right|up / down)$", key)
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
  if (grepl("^(fds |vs coin|insert coin|coin |service|[0-9]+ players? start$|st-v (test|service|pause)$)", key))
    return(TRUE)
  if (key %in% c(
    "disc select", "disk index", "previous disk", "next disk", "open", "close",
    "open tray", "close tray", "toggle cable", "next drive", "next slot", "insert disk", "eject disk",
    "next floppy disk", "previous floppy disk", "swap floppy disk", "next cdrom", "rotate",
    "play tape", "stop tape", "rtz tape", "record tape", "insert next tape", "insert previous tape",
    "next tape block", "prev tape block", "get tape status", "insert next disk", "insert previous disk",
    "get disk status", "subframe", "copyright", "interlace mode"
  )) return(TRUE)
  if (grepl("^toggle (left difficulty|right difficulty|tv type)$", key)) return(TRUE)
  if (platform %in% c("A26", "A2600", "A78", "A7800", "SMS", "GG", "SG1000") &&
    unprefixed && key %in% c("select", "pause")) return(TRUE)
  if (platform == "CHANNELF" && unprefixed && key %in% c("time", "mode", "hold", "start")) return(TRUE)
  # Not on a pad: the lid of a DS, the switch that turns touch into tilt on
  # a 3DS, and the cable between two linked Game Boys.
  if (platform %in% c("NDS", "DS") && key %in% c("lidopen", "lidclose", "lid open", "lid close")) return(TRUE)
  if (platform == "3DS" && key %in% c("tilt", "debug", "gpio14")) return(TRUE)
  if (key == "toggle link connection") return(TRUE)
  # The Atari 7800's black-and-white switch is on the console; TIC-80's
  # relative-mouse toggle is a setting of the machine.
  if (platform %in% c("A78", "A7800") && key == "bw") return(TRUE)
  if (platform == "TIC80" && key == "mouse relative toggle") return(TRUE)
  FALSE
}
.bk2_control_key <- function(name, platform, group, keyboard) {
  key <- tolower(trimws(sub("^P[0-9]+ ", "", name)))
  if (keyboard) {
    prefix <- if (platform == "TI83") "ti83_" else "keyboard_"
    return(paste0(prefix, .bk2_key_slug(sub("^key ", "", key))))
  }
  if (platform == "INTV" && key == "top") return("intv_top")
  if (platform == "INTV" && key %in% c(
    "n", "nne", "ne", "ene", "e", "ese", "se", "sse",
    "s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw"
  )) return(paste0("intv_disc_", key))
  if (platform == "COLECO" && grepl("^key[0-9]$", key)) return(paste0("keypad_", substring(key, 4L)))
  if (platform %in% c("INTV", "COLECO") && key %in% c("enter", "clear", "star", "pound"))
    return(paste0("keypad_", key))
  if (platform %in% c("JAGUAR", "JAGUARCD") && grepl("^[0-9]$", key)) return(paste0("keypad_", key))
  if (platform %in% c("JAGUAR", "JAGUARCD") && key %in% c("asterisk", "pound"))
    return(paste0("keypad_", if (key == "asterisk") "star" else key))
  # Of two direction pads, the left one is the direction pad and the right
  # one has the identities of the N64's C-buttons: the Virtual Boy's pads,
  # and the WonderSwan's X and Y crosses, numbered clockwise from the top.
  if (platform %in% c("VB", "VBOY") && grepl("^[lr]_(up|down|left|right)$", key))
    return(paste0(if (startsWith(key, "l_")) "dpad_" else "c_", substring(key, 3L)))
  if (platform == "WSWAN" && grepl("^[xy][1-4]$", key))
    return(paste0(if (startsWith(key, "x")) "dpad_" else "c_",
      c("up", "right", "down", "left")[as.integer(substring(key, 2L))]))
  # Settings and option buttons take Start, Select and Mode. The Lynx has no
  # Start: its Pause takes that identity, like PC Engine's Run, and Option 1
  # and 2 are Select and Mode. The Neo Geo Pocket's only such button, Option,
  # is Start. PC Engine's two controls that switch between two and six
  # buttons are Mode, like the Genesis button with that use.
  if (platform == "LYNX" && key == "pause") return("start")
  if (platform == "LYNX" && key == "option 1") return("select")
  if (platform == "LYNX" && key == "option 2") return("mode")
  if (platform %in% c("NGP", "NGPC") && key == "option") return("start")
  # The 3DO pad's P (play and pause) is Start.
  if (platform == "3DO" && key == "p") return("start")
  # The Jaguar's Pause is Start and its Option is Mode.
  if (platform %in% c("JAGUAR", "JAGUARCD") && key == "pause") return("start")
  if (platform %in% c("JAGUAR", "JAGUARCD") && key == "option") return("mode")
  if (grepl("^mode: set [26]-button$", key)) return(paste0("pce_mode_set_", substring(key, 11L, 11L), "_button"))
  # The Channel F stick: forward and back are up and down, its twist is the
  # two shoulder buttons, pushing it down is A and pulling it up is B.
  if (platform == "CHANNELF" && key %in% c("forward", "back", "ccw", "cw", "pull", "push"))
    return(c(forward = "dpad_up", back = "dpad_down", ccw = "l1", cw = "r1", push = "a", pull = "b")[[key]])
  # The Atari 7800's two triggers are its first and second button.
  if (platform %in% c("A78", "A7800") && key == "trigger 2") return("b")
  if (grepl("^joystick (up|down|left|right)$", key)) return(paste0("dpad_", sub("^joystick ", "", key)))
  if (grepl("^joystick button [0-9]+$", key)) return(paste0("joystick_button_", sub("^joystick button ", "", key)))
  if (key %in% c("mouse left button", "mouse left click")) return("mouse_left")
  if (key %in% c("mouse middle button", "mouse middle click")) return("mouse_middle")
  if (key %in% c("mouse right button", "mouse right click")) return("mouse_right")
  if (key == "fourth button" && platform == "3DO") return("mouse_fourth")
  # A touch on the screen is the press of a pointing input, like a stick click.
  if (key == "touch") return("l3")
  if (key == "zl") return("l2")
  if (key == "zr") return("r2")
  if (key == "f" && platform == "O2") return("a")
  group_keys <- tolower(sub("^P[0-9]+ ", "", group))
  # MAME's two joysticks have the direction identities of the left and the
  # right analogue stick: "Left Stick/Up" is left_n, "Right Stick/Left" right_w.
  if (platform == "ARCADE" && grepl("^(left|right) stick/(up|down|left|right)$", key)) {
    way <- c(up = "n", down = "s", left = "w", right = "e")[[sub("^.*/", "", key)]]
    return(paste0(sub(" .*$", "", key), "_", way))
  }
  # Neo Geo's four-button row corresponds to A/B/X/Y. Six-button pads
  # retain C because their independently recorded X button is also present.
  if (platform == "ARCADE" && all(c("a", "b", "c", "d") %in% group_keys) &&
    !any(c("x", "y") %in% group_keys) && key == "c") return("x")
  gun <- any(grepl("zapper|lightgun|hpos|vpos", group_keys)) ||
    ("trigger" %in% group_keys && any(group_keys %in% c("x", "y", "x axis", "y axis")))
  if (gun && key %in% c("trigger", "fire")) return("gun_trigger")
  if (key %in% c("gun trigger", "gun button")) return("gun_trigger")
  # GunCon has a primary trigger plus two separately recorded side buttons.
  if (platform == "PSX" && gun && key %in% c("a", "b"))
    return(if (key == "a") "b" else "x")
  if (platform == "PSX" && key == "x") return("b")
  slot <- unname(.BK2_NAME_TO_UNI[key])
  if (length(slot) == 1L && !is.na(slot)) {
    return(.legacy_control_keys()[slot])
  }
  paste0(tolower(platform %||% "bk2"), "_", .bk2_key_slug(key))
}
# The controls that a LogKey declares, in the order of the log. Each entry
# has the control's name, its port, whether it is numeric, whether it belongs
# to the system and not to a controller, and its shared identity.
.bk2_logkey_entries <- function(logkey, header, platform) {
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
  legacy_nds_mic <- platform %in% c("NDS", "DS") &&
    identical(tolower(header$Core %||% ""), "melonds") &&
    grepl("(^|[^0-9])2\\.9\\.1([^0-9]|$)", header$emuVersion %||% "")
  entries <- list()
  inactive <- character()
  for (gi in seq_along(groups)) for (name in groups[[gi]]) {
    if (legacy_nds_mic && name == "Microphone") {
      ignored <- c(ignored, name)
      next
    }
    unprefixed <- !grepl("^P[0-9]+ ", name)
    port <- if (unprefixed) 1L else as.integer(sub("^P([0-9]+) .*", "\\1", name))
    if (!unprefixed && port %in% header$inactiveControllerPorts) {
      inactive <- c(inactive, name)
      next
    }
    key <- tolower(trimws(sub("^P[0-9]+ ", "", name)))
    keyboard <- .bk2_keyboard_control(key, platform, unprefixed)
    system <- .bk2_system_control(key, platform, unprefixed, keyboard) ||
      (platform == "ARCADE" && unprefixed && length(groups) > 1L)
    numeric <- .bk2_source_numeric(key, groups[[gi]], platform)
    entries[[length(entries) + 1L]] <- list(
      name = name, key = key, port = if (system) 0L else port,
      numeric = numeric, system = system, group = gi, shared = unprefixed && !system,
      identity = if (system || numeric) NA_character_ else .bk2_control_key(name, platform, groups[[gi]], keyboard),
      kind = if (keyboard) "keyboard" else if (grepl("touch|mouse|mic|lid", key)) "peripheral" else "button"
    )
  }
  if (length(inactive)) header$inactiveLogKeyControls <- inactive
  if (length(ignored)) {
    header$ignoredLogKeyControls <- ignored
    header$ignoredLogKeyControlReason <- "Absent from BizHawk 2.9.1 MelonDS controller definition"
    header$sourceLogKey <- logkey
  }
  list(entries = entries, header = header)
}
# Reads the fields of every row in the order of the entries, as BizHawk does:
# a numeric field up to its comma, a Boolean field of one character. Pipes do
# not delimit fields. Returns the values, the text of each field, and what
# is left of each row.
.bk2_read_fields <- function(rows, entries) {
  stream <- gsub("|", "", rows, fixed = TRUE)
  values <- vector("list", length(entries))
  field_text <- vector("list", length(entries))
  for (i in seq_along(entries)) {
    entry <- entries[[i]]
    if (entry$numeric) {
      width <- attr(regexpr("^[[:space:]]*[+-]?[0-9]+,", stream), "match.length")
      bad <- which(width < 1L)
      if (length(bad)) stop("bk2 numeric field '", entry$name, "' is invalid at sample ", bad[1L])
      field_text[[i]] <- substring(stream, 1L, width)
      values[[i]] <- as.numeric(sub(",$", "", field_text[[i]]))
      stream <- substring(stream, width + 1L)
    } else {
      bad <- which(!nzchar(stream))
      if (length(bad)) stop("bk2 controller stream is truncated at '", entry$name, "', sample ", bad[1L])
      field_text[[i]] <- substring(stream, 1L, 1L)
      values[[i]] <- field_text[[i]] != "."
      stream <- substring(stream, 2L)
    }
  }
  list(values = values, text = field_text, rest = stream)
}
# What the rows show beyond their declared fields: commas read as buttons,
# pipes at other places than the LogKey has them, and text after the last
# field. The findings go to the header; nothing is dropped from the rows.
.bk2_stream_findings <- function(rows, entries, fields, header) {
  # Axis names are supplied by the core, not typed in LogKey. A comma consumed
  # as an ordinary button can therefore reveal an unknown numeric field even
  # when a stale declaration happens to consume the whole row. Preserve the
  # ambiguous source rows instead of silently calling those commas presses.
  comma_rows <- integer()
  comma_fields <- character()
  for (i in seq_along(entries)) if (!entries[[i]]$numeric &&
    !entries[[i]]$key %in% c(",", "comma", "key comma")) {
    at <- which(fields$text[[i]] == ",")
    comma_rows <- c(comma_rows, at)
    comma_fields <- c(comma_fields, rep(entries[[i]]$name, length(at)))
  }
  if (length(comma_rows)) {
    header$ambiguousBooleanCommaSamples <- length(unique(comma_rows))
    warning("bk2 comma consumed as a Boolean control in ", length(unique(comma_rows)),
      " samples; the controller schema may contain an unknown numeric field; ",
      "source rows retained in ambiguous_input",
      call. = FALSE
    )
  }
  stream <- fields$rest
  numeric_system <- any(vapply(entries, function(e) e$system && e$numeric, logical(1)))
  if (any(grepl(",", stream, fixed = TRUE)) && !numeric_system)
    stop("bk2 input columns disagree with their LogKey: unconsumed numeric field")
  source_groups <- split(seq_along(entries), vapply(entries, function(e) e$group, integer(1)))
  canonical <- lapply(source_groups, function(ix) do.call(paste0, fields$text[ix]))
  canonical <- paste0("|", do.call(paste, c(canonical, sep = "|")), "|")
  boundary <- which(rows != canonical)
  if (length(boundary)) {
    header$logKeyStreamBoundarySamples <- length(boundary)
    # Both legacy and current Bk2Controller skip pipe separators between fields.
    # Empty groups and moved display boundaries are valid source syntax.
    header$logKeyBoundaryInterpretation <- "Pipe separators do not delimit controller consumption"
  }
  # Old exports can append a stale, unused group. Preserve the original text
  # and report it instead of interpreting it as a second controller.
  if (any(nzchar(stream))) {
    header$unconsumedTrailingSamples <- sum(nzchar(stream))
    header$unconsumedTrailingActiveSamples <- sum(grepl("[^.]", stream))
    # Bk2Controller stops when it has read the declared controls. Empty
    # unused pads and whitespace-prefixed words are ignored source suffixes,
    # rather than extra inputs. Keep their text and report their counts.
    padding <- nzchar(stream) & !grepl("[^.]", stream)
    annotation <- grepl("^[[:space:]]+[[:alpha:]]{2,}[[:alnum:] _./:-]*$", stream)
    header$sourceTrailingPaddingSamples <- sum(padding)
    header$sourceTrailingAnnotationSamples <- sum(annotation)
    unbound <- nzchar(stream) & !padding & !annotation
    header$sourceTrailingUnboundSamples <- sum(unbound)
    if (any(unbound)) warning("bk2 LogKey leaves trailing source text resembling unbound controls in ",
      sum(unbound), " samples; retained in source_trailing",
      call. = FALSE
    )
  }
  list(header = header, comma_rows = comma_rows, comma_fields = comma_fields)
}
# The button states of the controllers: one column for each shared identity,
# those of the registry first. The Boolean stick overrides of the N64 are
# kept apart.
.bk2_named_buttons <- function(entries, values, ports, n, platform) {
  digital <- which(vapply(entries, function(e) !e$system && !e$numeric, logical(1)))
  # N64 Boolean stick overrides feed the effective analogue vector. Preserve
  # them separately; no invented pressed directions are added in raw mode.
  override <- if (platform == "N64") {
    digital[vapply(entries[digital], function(e) e$key %in% c("a right", "a up", "a left", "a down"), logical(1))]
  } else {
    integer()
  }
  digital <- setdiff(digital, override)
  keys <- unique(vapply(entries[digital], function(e) e$identity, character(1)))
  registry <- .controller_registry()
  keys <- c(registry$key[registry$key %in% keys], sort(setdiff(keys, registry$key)))
  labels <- kinds <- character(length(keys))
  inputs <- array(FALSE, c(n, length(ports), length(keys)))
  for (i in digital) {
    e <- entries[[i]]
    p <- match(e$port, ports)
    k <- match(e$identity, keys)
    inputs[, p, k] <- inputs[, p, k] | values[[i]]
    labels[k] <- sub("^P[0-9]+ ", "", e$name)
    kinds[k] <- e$kind
    registered <- match(keys[k], registry$key)
    if (!is.na(registered)) kinds[k] <- registry$kind[registered]
  }
  list(inputs = inputs, keys = keys, labels = labels, kinds = kinds, override = override)
}
# IntelliHawk logs the disc of its analogue controller as two axes from -127
# to 127 and gives the console one of the disc's sixteen directions
# (CalcDirection in BizHawk's IntellivisionControllers.cs): none within 50 of
# the centre, Y negated so that -127 is up, and otherwise the nearest of the
# sixteen, counted anticlockwise from east. The directions become the controls
# of a disc that the log holds as sixteen buttons; the axes remain numeric
# channels.
.bk2_intv_disc_directions <- function(entries, values) {
  directions <- c("e", "ene", "ne", "nne", "n", "nnw", "nw", "wnw",
    "w", "wsw", "sw", "ssw", "s", "sse", "se", "ese")
  numeric <- vapply(entries, function(e) e$numeric, logical(1))
  keys <- vapply(entries, function(e) e$key, character(1))
  ports <- vapply(entries, function(e) e$port, integer(1))
  out <- list(entries = list(), values = list())
  for (p in unique(ports[numeric & keys == "disc x"])) {
    x <- which(numeric & keys == "disc x" & ports == p)
    y <- which(numeric & keys == "disc y" & ports == p)
    if (length(x) != 1L || length(y) != 1L) next
    x <- values[[x]]
    y <- -values[[y]]
    active <- x * x + y * y >= 50^2
    sector <- round(atan2(y, x) * 8 / pi) %% 16
    for (k in seq_along(directions)) {
      out$entries[[length(out$entries) + 1L]] <- list(
        name = sprintf("P%d %s", p, toupper(directions[k])), key = directions[k],
        port = p, numeric = FALSE, system = FALSE, group = NA_integer_, shared = FALSE,
        identity = paste0("intv_disc_", directions[k]), kind = "button"
      )
      out$values[[length(out$values) + 1L]] <- active & sector == k - 1L
    }
  }
  out
}
# The numeric fields of each controller, under the names of the log.
.bk2_named_channels <- function(entries, values, ports, n) {
  raw <- .empty_analog(n, length(ports))
  for (p in seq_along(ports)) {
    fields <- which(vapply(entries, function(e) e$port == ports[p] && e$numeric, logical(1)))
    if (length(fields)) {
      raw[[p]] <- matrix(unlist(values[fields], use.names = FALSE), nrow = n, ncol = length(fields))
      colnames(raw[[p]]) <- vapply(entries[fields], function(e) e$name, character(1))
    }
  }
  raw
}
# PlayStation stick axes must lie in the range their core declares. Octoshock
# reduces a value outside 0..255 to a byte, which is counted and reported.
.bk2_check_psx_axes <- function(raw, ports, header) {
  old16 <- grepl("nymashock", tolower(header$Core %||% "")) &&
    grepl("(^|[^0-9])2\\.8([. ]|$)", header$emuVersion %||% "")
  wrapped <- 0L
  for (p in setdiff(seq_along(ports), header$bk2NonStickPlayers)) {
    roles <- vapply(tolower(colnames(raw[[p]])), .classify_analog_pair, character(1))
    axes <- raw[[p]][, !is.na(roles) & roles != "paddle_position", drop = FALSE]
    if (grepl("octoshock", tolower(header$Core %||% ""))) {
      wrapped <- wrapped + sum(axes < 0 | axes > 255)
    } else if (any(axes < 0 | axes > if (old16) 65535 else 255)) {
      stop("bk2 PSX axis outside declared encoding range")
    }
  }
  if (wrapped) {
    header$octoshockByteWrappedAxisValues <- wrapped
    warning("bk2 Octoshock byte conversion applied to ", wrapped, " out-of-range axis values", call. = FALSE)
  }
  header
}
# The controls of the system: a table with one column for each, and command
# bits for the first 31 Boolean ones in the order of the log.
.bk2_named_system <- function(entries, values, n) {
  system <- which(vapply(entries, function(e) e$system, logical(1)))
  sys <- data.frame(row.names = seq_len(n))
  commands <- integer(n)
  bit <- 0L
  for (i in system) {
    sys[[entries[[i]]$name]] <- values[[i]]
    if (!entries[[i]]$numeric) {
      if (bit < 31L) commands[values[[i]]] <- bitwOr(commands[values[[i]]], bitwShiftL(1L, bit))
      bit <- bit + 1L
    }
  }
  list(inputs = sys, commands = commands)
}
# Encore.IInputPollable: both 3DS sticks are -128..127, centre 0,
# with positive Y pointing up; the core divides both axes by 128.
.bk2_3ds_calibration <- function(raw) {
  lapply(raw, function(ch) {
    out <- list()
    for (side in c("left", "right")) {
      prefix <- if (side == "left") "Circle Pad" else "C-Stick"
      pair <- paste(prefix, c("X", "Y"))
      if (all(pair %in% colnames(ch)))
        out[[side]] <- list(x = pair[1L], y = pair[2L], center = c(0, 0), scale = c(128, 128), sign = c(1, 1))
    }
    out
  })
}
# A log with named controls: every control keeps the name the core gave it.
.bk2_named_log <- function(rows, logkey, header) {
  platform <- toupper(header$Platform %||% "BK2")
  declared <- .bk2_logkey_entries(logkey, header, platform)
  entries <- declared$entries
  n <- length(rows)
  fields <- .bk2_read_fields(rows, entries)
  values <- fields$values
  findings <- .bk2_stream_findings(rows, entries, fields, declared$header)
  header <- findings$header
  ports <- sort(unique(vapply(entries, function(e) e$port, integer(1))))
  ports <- ports[ports > 0L]
  if (!length(ports)) ports <- 1L
  header$controllerPorts <- ports
  header$bk2NonStickPlayers <- which(vapply(ports, function(p) {
    k <- vapply(entries[vapply(entries, function(e) e$port == p, logical(1))], function(e) e$key, character(1))
    any(grepl("zapper|lightgun|hpos|vpos", k)) ||
      ("trigger" %in% k && any(k %in% c("x", "y", "x axis", "y axis")))
  }, logical(1)))
  header$sharedInputControls <- vapply(entries[vapply(entries, function(e) e$shared, logical(1))], function(e) e$name,
    character(1))
  button_entries <- entries
  button_values <- values
  if (platform == "INTV") {
    disc <- .bk2_intv_disc_directions(entries, values)
    button_entries <- c(entries, disc$entries)
    button_values <- c(values, disc$values)
  }
  buttons <- .bk2_named_buttons(button_entries, button_values, ports, n, platform)
  raw <- .bk2_named_channels(entries, values, ports, n)
  if (platform == "PSX") header <- .bk2_check_psx_axes(raw, ports, header)
  system <- .bk2_named_system(entries, values, n)
  movie <- .new_named_movie(
    header, system$commands, buttons$inputs, buttons$keys,
    analog = raw, names = buttons$labels, kinds = buttons$kinds,
    stick_calibration = if (platform == "3DS") .bk2_3ds_calibration(raw)
  )
  movie$system_inputs <- system$inputs
  movie$source_controls <- data.frame(
    name = vapply(entries, function(e) e$name, character(1)),
    type = vapply(entries, function(e) if (e$numeric) "integer" else "logical", character(1)),
    port = vapply(entries, function(e) e$port, integer(1)),
    key = vapply(entries, function(e) e$identity, character(1)), stringsAsFactors = FALSE
  )
  if (any(nzchar(fields$rest))) movie$source_trailing <- fields$rest
  if (length(findings$comma_rows)) movie$ambiguous_input <- data.frame(
    observation = findings$comma_rows, field = findings$comma_fields, source_input = rows[findings$comma_rows],
    stringsAsFactors = FALSE
  )
  movie$stick_overrides <- lapply(ports, function(p) {
    out <- matrix(FALSE, n, 4L, dimnames = list(NULL, c("right", "up", "left", "down")))
    for (i in buttons$override) if (entries[[i]]$port == p) out[, sub("^a ", "", entries[[i]]$key)] <- values[[i]]
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
#' path <- system.file("extdata", "expanded", "two-stick-3ds.bk2", package = "replayr")
#' counts <- read_bk2_chunks(path, function(chunk) n_observations(chunk), chunk_size = 2L)
#' sum(unlist(counts))
#' attr(counts, "observations")
#' @export
read_bk2_chunks <- function(path, FUN, chunk_size = 100000L, analog = "raw",
                            deadzone = NULL, triggers = "raw", aliases = TRUE, ...) {
  .check_recording_path(path)
  if (!is.function(FUN)) stop("FUN must be a function")
  if (length(chunk_size) != 1L || !is.numeric(chunk_size) || !is.finite(chunk_size) ||
    chunk_size < 1 || chunk_size != floor(chunk_size) || chunk_size > .Machine$integer.max)
    stop("chunk_size must be a positive integer")
  .stick_modes(analog)
  info <- .bk2_archive_info(path)
  scratch <- tempfile("bk2-chunks-")
  if (!dir.create(scratch, mode = "0700")) stop("Cannot create BK2 extraction directory", call. = FALSE)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  input_path <- .extract_bk2_member(path, info$member, scratch)
  con <- file(input_path, open = "r", encoding = "UTF-8")
  on.exit(close(con), add = TRUE, after = FALSE)
  results <- list()
  total <- 0
  logkey <- NULL
  pending <- character()
  repeat {
    lines <- readLines(con, n = as.integer(chunk_size), warn = FALSE)
    if (!length(lines)) break
    lines <- sub("\r+$", "", lines)
    keys <- lines[startsWith(lines, "LogKey:")]
    if (!length(keys) && is.null(logkey)) {
      found <- .bk2_logkey_lines(lines)
      if (found$indented) {
        keys <- found$logkey
        indented_rows <- found$indented_rows
        warning(.bk2_indented_logkey_message(indented_rows))
      }
      if (!length(keys)) {
        keys <- .bk2_retro_logkey(lines, info$header)
        if (length(keys)) info$header$logKeyRestored <- .BK2_RETRO_NOTE
      }
    }
    if (length(keys)) {
      if (!is.null(logkey) && any(keys != logkey)) stop("BK2 LogKey changes within recording")
      if (is.null(logkey)) logkey <- keys[1L]
      if (any(keys != logkey)) stop("BK2 LogKey changes within recording")
    }
    pending <- c(pending, lines[startsWith(lines, "|")])
    while (length(pending) >= chunk_size) {
      rows <- pending[seq_len(chunk_size)]
      pending <- pending[-seq_len(chunk_size)]
      h <- info$header
      h$firstObservation <- total + 1
      h$lastObservation <- total + length(rows)
      movie <- .parse_bk2_input_lines(c(logkey, rows), h)
      movie$source_path <- path
      movie <- .configure_movie(movie, analog, deadzone, triggers, aliases)
      results[length(results) + 1L] <- list(FUN(movie, ...))
      total <- total + length(rows)
    }
  }
  if (length(pending)) {
    h <- info$header
    h$firstObservation <- total + 1
    h$lastObservation <- total + length(pending)
    movie <- .parse_bk2_input_lines(c(logkey, pending), h)
    movie$source_path <- path
    movie <- .configure_movie(movie, analog, deadzone, triggers, aliases)
    results[length(results) + 1L] <- list(FUN(movie, ...))
    total <- total + length(pending)
  }
  attr(results, "observations") <- total
  attr(results, "chunks") <- length(results)
  results
}
