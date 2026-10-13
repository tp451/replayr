# GoldSrc (Half-Life engine) demo. Sources: the frame container as hldemo-rs
# documents it (YaLTeR/hldemo-rs, src/types.rs and src/parse/frame), and the
# command of the public Half-Life SDK (common/usercmd.h, common/in_buttons.h).
#
# Layout, little-endian:
#   0      8   "HLDEMO\0\0"
#   8      4   demo protocol (5)
#   12     4   network protocol
#   16     260 map name
#   276    260 game directory
#   536    4   map CRC
#   540    4   offset of the directory
#   directory: count, then entries of 92 bytes: type, description (64),
#     flags, CD track, track time (float), frame count, offset, length
#   frame: type (1 byte), time (float), frame number (int), then by type
#     0, 1   network message: timestamp (4), view parameters (232), the
#            command (52), movement variables (132), view (12), view model
#            (4), seven sequence numbers (28), length (4), message
#     2      start of the demo, no data        3   console command (64)
#     4      client data (32)                  5   end of the section
#     6      event (84)                        7   weapon animation (8)
#     8      sound: channel, length and sample, four more values (16)
#     9      demo buffer: length and bytes
#   command (usercmd_t): lerp_msec (int16), msec (byte), view angles
#     (3 floats at 4), forwardmove, sidemove, upmove (floats at 16),
#     lightlevel (byte at 28), buttons (uint16 at 30), impulse (byte at 32),
#     weaponselect (byte at 33), impact index and position (at 36).
#
# Engines up to network protocol 43 (2001) write a longer network-message
# frame: 560 bytes before the length where later engines write 464. The
# length of 560 is that of the compLexity Demo Player's parser
# (jpcy/coldemoplayer, demo parser/HalfLifeDemoParser.cs); the place of the
# command was found in demos of that time. Their view parameters hold a copy
# of the command (at 212) and of the 13 movement variables of that engine
# (at 264); the command the client was sending follows at 412, in the same
# layout as later, then the movement variables again (52), the view (12),
# the view model (4) and the sequence numbers (28).
.dem_frame_layout <- function(network_protocol) {
  if (network_protocol <= 43) list(header = 560, command = 412) else list(header = 464, command = 236)
}
.DEM_ACTIONS <- c(
  "attack", "jump", "duck", "forward", "back", "use", "cancel", "turn_left", "turn_right",
  "move_left", "move_right", "attack2", "run", "reload", "alt1", "score"
)
.DEM_ACTION_NAMES <- c(
  "Attack", "Jump", "Duck", "Forward", "Back", "Use", "Cancel", "Turn left", "Turn right",
  "Move left", "Move right", "Attack 2", "Run", "Reload", "Alt 1", "Score"
)
.DEM_FIXED_FRAMES <- c(`2` = 0, `3` = 64, `4` = 32, `5` = 0, `6` = 84, `7` = 8)
# Values of one kind at many places of a file; `at` holds one-based positions.
.dem_values <- function(data, at, what, size, signed = TRUE) {
  if (!length(at)) return(if (what == "numeric") numeric() else integer())
  bytes <- data[as.vector(t(outer(at, seq_len(size) - 1, "+")))]
  readBin(bytes, what, n = length(at), size = size, endian = "little", signed = signed)
}
.dem_int <- function(data, at) {
  value <- sum(as.numeric(data[at + 0:3]) * c(1, 256, 65536, 16777216))
  if (value >= 2147483648) value - 4294967296 else value
}
.dem_text <- function(bytes) {
  end <- which(bytes == as.raw(0L))[1L]
  if (!is.na(end)) bytes <- bytes[seq_len(end - 1L)]
  iconv(rawToChar(bytes), "latin1", "UTF-8")
}
# The frames of one section: their types and the places where their data
# begin. A frame that the file does not hold completely ends the section.
# `header` is the number of bytes before the length of a network message.
.dem_walk <- function(data, offset, path, header = 464) {
  size <- length(data)
  kinds <- integer(1024L)
  starts <- numeric(1024L)
  n <- 0L
  at <- offset + 1
  complete <- FALSE
  repeat {
    if (at + 8 > size) break
    kind <- as.integer(data[at])
    if (kind > 9L) stop(path, ": invalid frame type ", kind, " at byte ", at - 1, call. = FALSE)
    payload <- at + 9
    length <- if (kind %in% 2:7) {
      .DEM_FIXED_FRAMES[[as.character(kind)]]
    } else if (kind == 8L) {
      if (payload + 7 > size) break
      sample <- .dem_int(data, payload + 4)
      if (sample < 0) stop(path, ": invalid sound frame at byte ", at - 1, call. = FALSE)
      24 + sample
    } else if (kind == 9L) {
      if (payload + 3 > size) break
      buffer <- .dem_int(data, payload)
      if (buffer < 0) stop(path, ": invalid demo buffer at byte ", at - 1, call. = FALSE)
      4 + buffer
    } else {
      if (payload + header + 3 > size) break
      message <- .dem_int(data, payload + header)
      if (message < 0 || message > 65536)
        stop(path, ": invalid network message length ", message, " at byte ", at - 1, call. = FALSE)
      header + 4 + message
    }
    if (payload + length - 1 > size) break
    if (n == length(kinds)) {
      kinds <- c(kinds, integer(n))
      starts <- c(starts, numeric(n))
    }
    n <- n + 1L
    kinds[n] <- kind
    starts[n] <- payload
    at <- payload + length
    if (kind == 5L) {
      complete <- TRUE
      break
    }
  }
  list(kind = kinds[seq_len(n)], start = starts[seq_len(n)], complete = complete, end = at - 1)
}
# The sections a demo lists in its directory. A demo without a complete
# directory gives the reason in place of the sections: the engine writes the
# place of the directory when it stops recording, and zero until then; a
# file that was cut short ends before its directory or within it.
.dem_sections <- function(data, path) {
  size <- length(data)
  directory <- .dem_int(data, 541)
  if (directory == 0) return("the demo has no directory of its sections")
  cut <- "the file ends before the end of its directory of sections"
  if (directory >= 544 && directory + 4 > size) return(cut)
  count <- if (directory >= 544) .dem_int(data, directory + 1) else NA
  if (is.na(count) || count < 1 || count > 1024)
    stop(path, ": the directory of the demo is invalid", call. = FALSE)
  if (directory + 4 + 92 * count > size) return(cut)
  base <- directory + 4 + 92 * (seq_len(count) - 1) + 1
  sections <- data.frame(
    type = .dem_values(data, base, "integer", 4L),
    description = vapply(base, function(b) .dem_text(data[b + 4 + 0:63]), character(1)),
    declared_seconds = .dem_values(data, base + 76, "numeric", 4L),
    declared_frames = .dem_values(data, base + 80, "integer", 4L),
    offset = .dem_values(data, base + 84, "integer", 4L),
    stringsAsFactors = FALSE
  )
  if (any(sections$offset < 544 | sections$offset >= size))
    stop(path, ": a section of the demo begins outside the file", call. = FALSE)
  sections
}
.decode_dem <- function(path) {
  data <- readBin(path, "raw", file.info(path)$size)
  if (.starts_with_bytes(path, "HL2DEMO"))
    stop(path, ": this is a demo of the Source engine; the reader takes GoldSrc (Half-Life) demos", call. = FALSE)
  if (!.starts_with_bytes(path, c(charToRaw("HLDEMO"), as.raw(c(0L, 0L)))))
    stop(path, ": not a GoldSrc demo: the file does not begin with HLDEMO. Quake and Source ",
      "demos share the extension .dem and are other formats.", call. = FALSE)
  if (length(data) < 544L) stop(path, ": the header of the demo is incomplete", call. = FALSE)
  demo_protocol <- .dem_int(data, 9)
  if (demo_protocol != 5) {
    # Demos of demo protocol 4 (network protocols 38 and 40, early 2001) hold
    # the messages of the server only: their frames have no command.
    stop(path, ": demo protocol ", demo_protocol, " is not supported; 5 is",
      if (demo_protocol < 5) ". Demos of earlier engines store no command of the player with their frames",
      call. = FALSE)
  }
  layout <- .dem_frame_layout(.dem_int(data, 13))
  sections <- .dem_sections(data, path)
  if (is.character(sections)) {
    # The sections follow one another from the end of the header.
    warning(basename(path), ": ", sections, "; its frames are read from the end of the header", call. = FALSE)
    # They end where the directory would begin, if the file reaches it.
    directory <- .dem_int(data, 541)
    limit <- if (directory >= 544) min(directory, length(data)) else length(data)
    walked <- list()
    offsets <- 544
    repeat {
      last <- .dem_walk(data, offsets[length(offsets)], path, layout$header)
      walked[[length(walked) + 1L]] <- last
      if (!last$complete || last$end + 9 > limit) break
      offsets <- c(offsets, last$end)
    }
    sections <- data.frame(
      type = NA_integer_, description = NA_character_, declared_seconds = NA_real_,
      declared_frames = NA_integer_, offset = offsets, stringsAsFactors = FALSE
    )
  } else {
    walked <- lapply(sections$offset, function(offset) .dem_walk(data, offset, path, layout$header))
  }
  sections$frames <- vapply(walked, function(w) length(w$kind), integer(1))
  sections$command_frames <- vapply(walked, function(w) sum(w$kind < 2L), integer(1))
  sections$complete <- vapply(walked, function(w) w$complete, logical(1))
  if (any(!sections$complete)) {
    warning(basename(path), ": ", sum(!sections$complete), " section(s) end without their closing frame; ",
      "every complete frame is imported", call. = FALSE)
  }
  kind <- unlist(lapply(walked, function(w) w$kind))
  start <- unlist(lapply(walked, function(w) w$start))
  section <- rep(seq_along(walked), sections$frames)
  seconds <- .dem_values(data, start - 8, "numeric", 4L)
  number <- .dem_values(data, start - 4, "integer", 4L)
  # One observation for each network-message frame: the command the client
  # was sending when the frame was recorded.
  net <- which(kind < 2L)
  n <- length(net)
  command <- start[net] + layout$command
  buttons <- .dem_values(data, command + 30, "integer", 2L, signed = FALSE)
  inputs <- array(FALSE, c(n, 1L, length(.DEM_ACTIONS)))
  for (bit in seq_along(.DEM_ACTIONS)) inputs[, 1L, bit] <- bitwAnd(buttons, bitwShiftL(1L, bit - 1L)) != 0L
  channels <- cbind(
    forwardmove = .dem_values(data, command + 16, "numeric", 4L),
    sidemove = .dem_values(data, command + 20, "numeric", 4L),
    upmove = .dem_values(data, command + 24, "numeric", 4L),
    # The angles the client asks to look at, in degrees: the player's aim
    # with the mouse or the turn keys, as the client sends it.
    view_pitch = .dem_values(data, command + 4, "numeric", 4L),
    view_yaw = .dem_values(data, command + 8, "numeric", 4L),
    view_roll = .dem_values(data, command + 12, "numeric", 4L),
    impulse = as.numeric(data[command + 32]),
    weaponselect = as.numeric(data[command + 33]),
    msec = as.numeric(data[command + 2])
  )
  if (!n) channels <- channels[integer(), , drop = FALSE]
  # A client sends no command of zero duration. Where no frame of play has
  # one of some duration, the demo was not recorded by a player.
  played <- kind[net] == 1L
  commands_present <- any(channels[played, "msec"] > 0)
  if (any(played) && !commands_present) {
    warning(basename(path), ": the demo holds no commands of a player; it was recorded by a ",
      "broadcast proxy (HLTV) or without a player in the game", call. = FALSE)
  }
  # Every section counts its seconds anew. The time of an observation runs
  # on from section to section.
  elapsed <- numeric(n)
  carried <- 0
  for (s in unique(section[net])) {
    rows <- which(section[net] == s)
    elapsed[rows] <- carried + seconds[net][rows] - seconds[net][rows[1L]]
    carried <- elapsed[rows[length(rows)]]
  }
  spoken <- which(kind == 3L)
  text <- vapply(start[spoken], function(at) .dem_text(data[at + 0:63]), character(1))
  header <- list(
    "_format" = "dem", demoProtocol = demo_protocol, networkProtocol = .dem_int(data, 13),
    mapName = .dem_text(data[17:276]), gameDir = .dem_text(data[277:536]),
    mapCrc = sum(as.numeric(data[537:540]) * c(1, 256, 65536, 16777216)),
    observationUnit = "demo_frame", sectionCount = nrow(sections), frameCount = n,
    playerCommands = commands_present
  )
  movie <- .new_named_movie(
    header, integer(n), inputs, paste0("action_", .DEM_ACTIONS), path,
    analog = list(channels), names = .DEM_ACTION_NAMES
  )
  movie$timing <- data.frame(
    start_seconds = elapsed, section = section[net], section_seconds = seconds[net],
    frame = number[net], start_frame = kind[net] == 0L
  )
  movie$sections <- sections
  movie$console_commands <- data.frame(
    section = section[spoken], section_seconds = seconds[spoken], frame = number[spoken],
    command = text, key_action = grepl("^[+-][A-Za-z]", text), stringsAsFactors = FALSE
  )
  movie
}
