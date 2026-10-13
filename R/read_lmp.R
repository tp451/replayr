# Sources / attribution:
#
# Doom-engine .lmp demo format. References: id Software's GPL Doom source
# (https://github.com/id-Software/DOOM, linuxdoom-1.10/g_game.c); the
# Heretic and Hexen sources as maintained in Chocolate Doom 3.1.0
# (https://github.com/chocolate-doom/chocolate-doom, src/heretic and
# src/hexen: g_game.c, p_user.c, h2def.h); and dsda-doom 0.29.4
# (https://github.com/dsda-org/dsda-doom, prboom2/src/g_game.c:
# G_ReadDemoHeaderEx and G_ReadOneTick, dsda/demo.c, dsda/excmd.c,
# dsda/options.c), which plays every layout read here. All are
# GPL-2.0-or-later.
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# Header layouts; the first byte decides:
#   0..4      no version byte: Doom 1.2 and earlier, Heretic and Hexen.
#             Skill, episode, map, then one byte per player slot. Hexen has
#             eight slots, each with an in-game byte and a class byte. In
#             Heretic and Hexen the first slot byte can also carry the flags
#             0x10 (16-bit turning), 0x20 (respawn) and 0x02 (no monsters).
#             Nothing in these files names the game, so the caller does. The
#             turning flag is a later convention: Heretic+ and Hexen+ wrote
#             16-bit turning without it, and players start them with
#             -longtics.
#   104..111  Doom 1.4 to 1.9: version, skill, episode, map, deathmatch,
#             respawn, fast, no monsters, console player, four player bytes.
#             110 is TASDoom, which stores the buttons first; 111 is Doom
#             1.91 with 16-bit turning.
#   200..214, 221  Boom, LxDoom, MBF, PrBoom and MBF21: version, a six-byte
#             signature, a compatibility byte in most versions, skill,
#             episode, map, deathmatch, console player, a block of game
#             options (64 bytes; 256 in version 200; in version 221, 21
#             bytes and a counted list of up to 25 compatibility options)
#             and 32 player bytes. 214 and 221 store 16-bit turning.
#   255       an outer header of dsda-doom ("DSDA") or PrBoom+um ("PR+UM"),
#             followed by one of the layouts above.
#
# Body, for each tic and each player in the game:
#   forwardmove and sidemove (signed bytes), angleturn (the high byte of a
#   16-bit angle, or both bytes with the low byte first), buttons, and in
#   Heretic and Hexen two more bytes: look and fly as signed nibbles, and
#   the artifact command.
#   Buttons: 0x01 attack, 0x02 use, 0x04 weapon change with the weapon in
#   bits 3-5; 0x80 marks a special command (pause, save) instead of actions.
#   Under dsda-doom's own header a byte of extended commands follows, with
#   operands for save, load and look.
# A byte 0x80 where a command would start ends the demo.
.lmp_signed <- function(x, bits = 8L) {
  half <- 2^(bits - 1L)
  ifelse(x >= half, x - 2 * half, x)
}
# Read the header; returns its fields and the offset of the first command.
.lmp_header <- function(data, path, game, longtics = NULL) {
  at <- 1L
  byte <- function(i) as.integer(data[i])
  need <- function(count) {
    if (at + count - 1L > length(data)) stop(path, ": truncated Doom demo header", call. = FALSE)
  }
  out <- list(
    outer = "none", excmd = FALSE, dsda = NULL, mapLump = NULL, longtics = FALSE,
    tasdoom = FALSE, signature = raw(), compatibility = NA_integer_,
    game_options = raw(), reserved_players = raw(), player_class = NULL,
    deathmatch = 0L, respawnparm = 0L, fastparm = 0L, nomonsters = 0L, consoleplayer = 0L
  )
  version <- byte(1L)
  at <- 2L
  if (version == 255L) {
    need(7L)
    if (identical(data[at + 0:5], as.raw(c(0x1d, 0x44, 0x53, 0x44, 0x41, 0xe6)))) {
      level <- byte(at + 6L)
      if (!level %in% 1:3) stop(path, ": unsupported dsda-doom demo header version ", level, call. = FALSE)
      size <- c(8L, 9L, 10L)[level]
      at <- at + 7L
      need(size + 1L)
      big <- function(i) sum(as.numeric(data[i + 0:3]) * 256^(3:0))
      out$dsda <- list(
        version = level, endMarkerLocation = big(at), tics = big(at + 4L),
        flags = if (level >= 2L) byte(at + 8L) else 0L,
        udmfVersion = if (level >= 3L) byte(at + 9L) else 0L
      )
      at <- at + size
      if (bitwAnd(out$dsda$flags, 1L) != 0L)
        stop(path, ": dsda-doom demos that start from a keyframe are not supported", call. = FALSE)
      out$excmd <- TRUE
      out$outer <- "dsda-doom"
    } else if (identical(data[at + 0:4], charToRaw("PR+UM"))) {
      need(27L)
      if (byte(at + 6L) != 1L || byte(at + 7L) != 1L || byte(at + 8L) != 0L ||
        byte(at + 9L) != 8L || !identical(data[at + 10:17], charToRaw("UMAPINFO")))
        stop(path, ": unknown extended Doom demo header", call. = FALSE)
      lump <- data[at + 18:25]
      out$mapLump <- rawToChar(lump[lump != as.raw(0)])
      at <- at + 26L
      out$outer <- "PrBoom+um"
    } else {
      stop(path, ": unknown extended Doom demo header", call. = FALSE)
    }
    need(1L)
    version <- byte(at)
    at <- at + 1L
  }
  if (!version %in% c(0:4, 104:111, 200:214, 221L)) {
    stop(path, ": unsupported Doom demo version ", version,
      "; expected no version byte (first byte 0-4), 104-111, 200-214 or 221",
      call. = FALSE
    )
  }
  out$version <- version
  out$versionless <- version < 100L
  if (out$versionless) {
    if (is.null(game)) {
      stop(path, ": this demo has no version byte and does not name its game; ",
        "set game = \"doom\" (Doom 1.2 or earlier), \"heretic\" or \"hexen\"",
        call. = FALSE
      )
    }
  } else {
    if (!is.null(game) && game != "doom") {
      stop(path, ": demo version ", version, " is a Doom layout, not game = \"", game, "\"", call. = FALSE)
    }
    game <- "doom"
  }
  out$game <- game
  raven <- game != "doom"
  slots <- if (game == "hexen") 8L else 4L
  if (version < 200L) {
    if (!out$versionless) {
      need(8L)
      fields <- as.integer(data[at + 0:7])
      out$skill <- fields[1L]
      out$episode <- fields[2L]
      out$map <- fields[3L]
      out$deathmatch <- fields[4L]
      out$respawnparm <- fields[5L]
      out$fastparm <- fields[6L]
      out$nomonsters <- fields[7L]
      out$consoleplayer <- fields[8L]
      out$tasdoom <- version == 110L
      out$longtics <- version == 111L
      at <- at + 8L
    } else {
      need(2L)
      out$skill <- version
      out$episode <- byte(at)
      out$map <- byte(at + 1L)
      at <- at + 2L
      if (raven) {
        need(1L)
        flags <- byte(at)
        out$longtics <- bitwAnd(flags, 0x10L) != 0L
        if (out$longtics && identical(longtics, FALSE)) {
          stop(path, ": the header of this demo marks 16-bit turning", call. = FALSE)
        }
        if (isTRUE(longtics)) out$longtics <- TRUE
        out$respawnparm <- as.integer(bitwAnd(flags, 0x20L) != 0L)
        out$nomonsters <- as.integer(bitwAnd(flags, 0x02L) != 0L)
      }
    }
    if (game == "hexen") {
      need(16L)
      pairs <- matrix(as.integer(data[at + 0:15]), ncol = 2L, byrow = TRUE)
      player_bytes <- pairs[, 1L]
      out$player_class <- pairs[, 2L] + 1L
      at <- at + 16L
    } else {
      need(4L)
      player_bytes <- as.integer(data[at + 0:3])
      at <- at + 4L
    }
  } else {
    need(6L)
    out$signature <- data[at + 0:5]
    at <- at + 6L
    boom <- as.raw(c(0x1d, 0x42, 0x6f, 0x6f, 0x6d, 0xe6))
    if (version %in% 200:202) {
      if (!identical(out$signature, boom)) stop(path, ": invalid Boom demo signature", call. = FALSE)
      need(1L)
      out$compatibility <- byte(at)
      if (!out$compatibility %in% 0:1) stop(path, ": invalid Boom compatibility flag", call. = FALSE)
      at <- at + 1L
    } else if (version == 203L) {
      # LxDoom keeps Boom's signature and has no further byte here; MBF has one.
      if (out$signature[2L] == as.raw(0x4d)) {
        need(1L)
        out$compatibility <- byte(at)
        at <- at + 1L
      } else if (out$signature[2L] != as.raw(0x42)) {
        stop(path, ": invalid Doom demo signature", call. = FALSE)
      }
    } else if (version %in% 210:214) {
      need(1L)
      out$compatibility <- byte(at)
      at <- at + 1L
      out$longtics <- version == 214L
    } else {
      out$longtics <- TRUE
    }
    need(5L)
    fields <- as.integer(data[at + 0:4])
    out$skill <- fields[1L]
    out$episode <- fields[2L]
    out$map <- fields[3L]
    out$deathmatch <- fields[4L]
    out$consoleplayer <- fields[5L]
    at <- at + 5L
    block <- if (version == 200L) 256L else 64L
    if (version == 221L) {
      # MBF21 counts its compatibility options; earlier builds wrote fewer.
      need(21L)
      count <- byte(at + 20L)
      if (count > 25L) stop(path, ": unknown MBF21 compatibility options", call. = FALSE)
      block <- 21L + count
    }
    need(block)
    out$game_options <- data[at + seq_len(block) - 1L]
    at <- at + block
    flags <- as.integer(out$game_options[if (version == 221L) 4:6 else 7:9])
    out$respawnparm <- flags[1L]
    out$fastparm <- flags[2L]
    out$nomonsters <- flags[3L]
    need(32L)
    player_bytes <- as.integer(data[at + seq_len(slots) - 1L])
    out$reserved_players <- data[seq.int(at + slots, at + 31L)]
    at <- at + 32L
  }
  # Doom stores 0 or 1 for a player; Heretic and Hexen can add flag bits.
  # Doom 1.2 and Heretic have no map above 9, and a class byte of Hexen in a
  # player slot shows that the file belongs to that game.
  if (!out$skill %in% 0:4 || !out$consoleplayer %in% (seq_len(slots) - 1L) ||
    (!raven && any(!player_bytes %in% 0:1)) ||
    (game == "heretic" && any(!player_bytes[-1L] %in% 0:1)) ||
    (out$versionless && game != "hexen" && out$map > 9L) ||
    (game == "hexen" && any(out$player_class[player_bytes != 0L] > 4L))) {
    stop(path, ": invalid Doom demo header fields",
      if (out$versionless) paste0(" for game = \"", game, "\""),
      call. = FALSE
    )
  }
  if (!is.null(longtics) && longtics != out$longtics) {
    stop(path, ": this demo settles its own turning width; ",
      "longtics applies to Heretic and Hexen demos", call. = FALSE)
  }
  out$playeringame <- as.integer(player_bytes != 0L)
  out$slots <- slots
  out$body_start <- at
  out
}
# Decode Doom tic commands, preserving movement and turning values.
# The public reader returns these numeric commands without direction projection.
.decode_lmp <- function(path, game = NULL, longtics = NULL) {
  if (!is.null(game)) game <- match.arg(game, c("doom", "heretic", "hexen"))
  if (!is.null(longtics) && (!is.logical(longtics) || length(longtics) != 1L || is.na(longtics))) {
    stop("longtics must be TRUE, FALSE or NULL", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 8L) {
    stop(path, ": too small to be a Doom demo (", length(data), " bytes)")
  }
  h <- .lmp_header(data, path, game, longtics)
  game <- h$game
  raven <- game != "doom"
  version <- h$version
  playeringame <- h$playeringame
  n_players <- h$slots
  active <- which(playeringame == 1L)
  n_active <- length(active)
  if (n_active == 0L) {
    stop(
      path, ": no active players in playeringame[] (",
      paste(playeringame, collapse = ","), ")"
    )
  }
  body_start <- h$body_start
  end <- length(data)
  width <- (if (h$longtics) 5L else 4L) + (if (raven) 2L else 0L)
  extended <- NULL
  if (!h$excmd) {
    starts <- if (body_start <= end) seq.int(body_start, end, by = width) else integer()
    marker <- which(data[starts] == as.raw(0x80))[1L]
    clean <- !is.na(marker) && starts[marker] == end && (marker - 1L) %% n_active == 0L
    if (!clean && raven && is.null(longtics) && !h$longtics) {
      # The commands do not run to the last byte of the file. If they do when
      # read with 16-bit turning, the recording used it without the flag.
      wide <- seq.int(body_start, end, by = width + 1L)
      last <- which(data[wide] == as.raw(0x80))[1L]
      if (!is.na(last) && wide[last] == end && (last - 1L) %% n_active == 0L) {
        stop(path, ": the commands of this demo end at the last byte of the file only when ",
          "read with 16-bit turning, which its header does not record; set longtics = TRUE, ",
          "or longtics = FALSE to read it as it stands",
          call. = FALSE
        )
      }
    }
    if (is.na(marker)) {
      complete <- sum(starts + width - 1L <= end)
      if (complete < length(starts) || complete %% n_active != 0L) {
        stop(path, ": truncated Doom demo in tic ", complete %/% n_active + 1L, call. = FALSE)
      }
      stop(path, ": missing Doom demo end marker", call. = FALSE)
    }
    n_commands <- marker - 1L
    if (n_commands %% n_active != 0L) {
      stop(path, ": truncated Doom demo in tic ", n_commands %/% n_active + 1L, call. = FALSE)
    }
    pos <- starts[marker]
    body <- if (n_commands) data[seq.int(body_start, pos - 1L)] else raw()
    cmd <- matrix(as.integer(body), ncol = width, byrow = TRUE)
    packets <- matrix(body, ncol = n_active * width, byrow = TRUE)
  } else {
    # Extended commands vary in length, so the stream is read in order.
    capacity <- max(16L, (end - body_start) %/% (width + 1L) + 1L)
    cmd <- matrix(0L, capacity, width)
    extended <- matrix(0L, capacity, 4L)
    pos <- body_start
    n_commands <- 0L
    ended <- FALSE
    while (pos <= end) {
      if (data[pos] == as.raw(0x80)) {
        ended <- TRUE
        break
      }
      if (pos + width > end) {
        stop(path, ": truncated Doom demo in tic ", n_commands %/% n_active + 1L, call. = FALSE)
      }
      n_commands <- n_commands + 1L
      cmd[n_commands, ] <- as.integer(data[pos + seq_len(width) - 1L])
      pos <- pos + width
      actions <- as.integer(data[pos])
      pos <- pos + 1L
      sizes <- c(
        if (bitwAnd(actions, 0x02L) != 0L) 1L else 0L,
        if (bitwAnd(actions, 0x04L) != 0L) 1L else 0L,
        if (bitwAnd(actions, 0x20L) != 0L) 2L else 0L
      )
      if (pos + sum(sizes) - 1L > end) {
        stop(path, ": truncated Doom demo in tic ", (n_commands - 1L) %/% n_active + 1L, call. = FALSE)
      }
      operands <- c(0L, 0L, 0L)
      if (sizes[1L]) {
        operands[1L] <- as.integer(data[pos])
        pos <- pos + 1L
      }
      if (sizes[2L]) {
        operands[2L] <- as.integer(data[pos])
        pos <- pos + 1L
      }
      if (sizes[3L]) {
        operands[3L] <- as.integer(.lmp_signed(as.integer(data[pos]) + 256L * as.integer(data[pos + 1L]), 16L))
        pos <- pos + 2L
      }
      extended[n_commands, ] <- c(actions, operands)
    }
    if (!ended) stop(path, ": missing Doom demo end marker", call. = FALSE)
    if (n_commands %% n_active != 0L) {
      stop(path, ": truncated Doom demo in tic ", n_commands %/% n_active + 1L, call. = FALSE)
    }
    cmd <- cmd[seq_len(n_commands), , drop = FALSE]
    extended <- extended[seq_len(n_commands), , drop = FALSE]
    body <- if (n_commands) data[seq.int(body_start, pos - 1L)] else raw()
    packets <- matrix(body, ncol = 1L)
  }
  n_frames <- n_commands %/% n_active
  # One row of `cmd` per command: tic by tic, players in slot order.
  if (h$tasdoom) {
    buttons <- cmd[, 1L]
    forward <- .lmp_signed(cmd[, 2L])
    sideways <- .lmp_signed(cmd[, 3L])
    turn <- .lmp_signed(cmd[, 4L])
    after <- 5L
  } else {
    forward <- .lmp_signed(cmd[, 1L])
    sideways <- .lmp_signed(cmd[, 2L])
    if (h$longtics) {
      turn <- .lmp_signed(cmd[, 3L] + 256L * cmd[, 4L], 16L) / 256
      buttons <- cmd[, 5L]
      after <- 6L
    } else {
      turn <- .lmp_signed(cmd[, 3L])
      buttons <- cmd[, 4L]
      after <- 5L
    }
  }
  cell <- cbind(rep(seq_len(n_frames), each = n_active), rep(active, n_frames))
  spread <- function(values, fill = 0L) {
    out <- matrix(fill, nrow = n_frames, ncol = n_players)
    if (n_frames) out[cell] <- values
    out
  }
  fwd <- spread(as.integer(forward))
  side <- spread(as.integer(sideways))
  ang <- if (h$longtics) spread(as.numeric(turn), 0) else spread(as.integer(turn))
  bts <- spread(as.integer(buttons))
  look <- fly <- artifact <- suicide <- jump <- NULL
  if (raven) {
    lookfly <- cmd[, after]
    arti <- cmd[, after + 1L]
    look <- spread(as.integer(.lmp_signed(bitwAnd(lookfly, 15L), 4L)))
    fly <- spread(as.integer(.lmp_signed(bitwShiftR(lookfly, 4L), 4L)))
    if (game == "hexen") {
      artifact <- spread(bitwAnd(arti, 0x3fL))
      jump <- spread(bitwAnd(arti, 0x80L) != 0L, FALSE)
      suicide <- spread(bitwAnd(arti, 0x40L) != 0L, FALSE)
    } else {
      artifact <- spread(arti)
    }
  }
  if (h$excmd) {
    leap <- spread(bitwAnd(extended[, 1L], 0x01L) != 0L, FALSE)
    jump <- if (is.null(jump)) leap else jump | leap
    extended <- list(
      actions = spread(extended[, 1L]), saveSlot = spread(extended[, 2L]),
      loadSlot = spread(extended[, 3L]), look = spread(extended[, 4L])
    )
  }
  # Private slots: 7 attack, 8 use, 9 jump where the layout records it. Slots
  # 1-4 hold the internal direction projection of the movement values.
  n_slots <- if (is.null(jump)) 8L else 9L
  inputs <- .empty_inputs(n_frames, n_players, n_slots)
  weapon_select <- matrix(NA_integer_, nrow = n_frames, ncol = n_players)
  has_special <- matrix(FALSE, nrow = n_frames, ncol = n_players)
  commands <- integer(n_frames)
  if (n_frames > 0L) {
    has_special[] <- bitwAnd(bts, 128L) != 0L
    actions <- bts
    actions[has_special] <- 0L
    inputs[, , 7L] <- bitwAnd(actions, 1L) != 0L
    inputs[, , 8L] <- bitwAnd(actions, 2L) != 0L
    if (!is.null(jump)) inputs[, , 9L] <- jump
    change <- bitwAnd(actions, 4L) != 0L
    weapon_select[change] <- bitwAnd(bitwShiftR(actions[change], 3L), 7L)
    special <- bts
    special[!has_special] <- 0L
    for (p in seq_len(n_players)) commands <- bitwOr(commands, special[, p])
  }
  emulator <- if (h$versionless) {
    c(doom = "Doom 1.2 or earlier", heretic = "Heretic", hexen = "Hexen")[[game]]
  } else if (version == 110L) {
    "TASDoom"
  } else if (version == 111L) {
    "Doom 1.91"
  } else if (version < 200L) {
    paste0("Doom 1.", c(4, 5, 666, 7, 8, 9)[version - 103L])
  } else if (version <= 202L) {
    "Boom"
  } else if (version == 203L) {
    if (h$signature[2L] == as.raw(0x4d)) "MBF" else "LxDoom"
  } else if (version <= 214L) {
    "PrBoom"
  } else {
    "MBF21"
  }
  header <- list(
    "_format" = "lmp",
    version = if (h$versionless) NA_character_ else as.character(version),
    emulator = emulator,
    game = game,
    observationUnit = "game tic",
    fps = "35",
    enabledPorts = active,
    controllerPorts = seq_len(n_players),
    outerHeader = h$outer,
    longtics = h$longtics,
    compatibilityFlag = h$compatibility,
    gameOptions = h$game_options,
    reservedPlayerFlags = h$reserved_players,
    angleturnUnit = "signed 1/256 revolution per tic",
    skill = as.character(h$skill),
    episode = as.character(h$episode),
    map = as.character(h$map),
    deathmatch = as.character(h$deathmatch),
    respawnparm = as.character(h$respawnparm),
    fastparm = as.character(h$fastparm),
    nomonsters = as.character(h$nomonsters),
    consoleplayer = as.character(h$consoleplayer),
    playeringame = paste(playeringame, collapse = ","),
    n_active_players = as.character(n_active),
    n_tics = as.character(n_frames),
    forwardmove = fwd,
    sidemove = side,
    angleturn = ang,
    weaponselect = weapon_select,
    has_special = has_special
  )
  if (length(h$signature)) header$signature <- h$signature
  if (!is.null(h$player_class)) header$playerClass <- h$player_class
  if (!is.null(h$mapLump)) header$mapLump <- h$mapLump
  if (!is.null(h$dsda)) header$dsdaHeader <- h$dsda
  if (raven) header$artifact <- artifact
  if (!is.null(suicide)) header$suicide <- suicide
  if (!is.null(extended)) header$extendedCommands <- extended
  movie <- .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    analog = lapply(seq_len(n_players), function(p) {
      channels <- cbind(forwardmove = fwd[, p], sidemove = side[, p], angleturn = ang[, p])
      if (raven) channels <- cbind(channels, look = look[, p], fly = fly[, p])
      channels
    }),
    source_path = path,
    button_mnemonics = c("R", "L", "D", "U", "T", "S", "A", "B", "J")[seq_len(n_slots)],
    button_names = c(
      "Right", "Left", "Down", "Up",
      "Start", "Select", "ATTACK", "USE", "JUMP"
    )[seq_len(n_slots)]
  )
  movie$source_header <- data[seq_len(body_start - 1L)]
  movie$source_packets <- packets
  movie$source_tail <- if (pos < length(data)) data[seq.int(pos + 1L, length(data))] else raw()
  movie
}
