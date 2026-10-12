# Sources / attribution:
#
# Doom .lmp demo format. Reference: id Software's GPL Doom source
# (https://github.com/id-Software/DOOM, GPLv2; specifically
# linuxdoom-1.10/g_game.c -- G_BeginRecording / G_DoSaveGame /
# G_RecordDemo) and the canonical DoomWiki spec at
# https://doomwiki.org/wiki/Demo.
#
# Supported layouts: vanilla Doom 1.9 (version 109) and Boom 2.00-2.02
# (versions 200-202). Boom uses a signature, game-option block, and a
# 32-byte player-flag area before the same four-byte tic commands.
# Boom source: coelckers/prboom-plus, prboom2/src/g_game.c:
# G_ReadDemoHeaderEx, G_ReadOptions, G_ReadOneTick (GPL-2.0-or-later).
# https://github.com/coelckers/prboom-plus/blob/master/prboom2/src/g_game.c
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# Vanilla Doom 1.9 header (13 bytes, zero-based offsets):
#   0 version = 109; 1 skill = 0..4; 2 episode; 3 map; 4 deathmatch;
#   5 respawn; 6 fast; 7 no monsters; 8 console player;
#   9..12 playeringame flags for physical ports 0..3.
#
# Body: per tic, per active player:
#   1 byte  forwardmove (signed)
#   1 byte  sidemove    (signed)
#   1 byte  angleturn   (signed, scaled 256/65536 of a circle)
#   1 byte  buttons:
#             bit 0 (0x01)  BT_ATTACK    -- fire
#             bit 1 (0x02)  BT_USE       -- open / activate
#             bit 2 (0x04)  BT_CHANGE    -- weapon-switch flag
#             bits 3-5      weapon index (0-7) when BT_CHANGE set
#             bit 7 (0x80)  BT_SPECIAL   -- engine command (pause / save)
#
# End marker: a single 0x80 byte where the next tic's first
# forwardmove would be.

#' Read a Doom .lmp demo file
#'
#' Parses a Doom 1.9 or Boom 2.00-2.02 `.lmp` demo into the standard
#' `replayr_movie` shape. Returns one row per game tic (per the
#' active-player count from `playeringame[]`).
#'
#' @details
#' Doom records the resulting `ticcmd_t`, not the physical device events.
#' Keyboard, mouse and joystick input may all contribute to its signed
#' movement fields. The reader therefore exposes inputs two ways:
#'
#' * Universal `inputs` array: action buttons map to the
#'   NES-shaped layout (ATTACK -> slot 8 "A", USE -> slot 7
#'   "B"), and the **sign** of forwardmove / sidemove drives
#'   the D-pad slots (forwardmove > 0 -> U, < 0 -> D;
#'   sidemove > 0 -> R, < 0 -> L). This makes a Doom keypress
#'   or other movement command comparable with digital gamepad data; it
#'   must not be interpreted as evidence that a keyboard key was held.
#' * Original analog axes are preserved as `n_frames x 4`
#'   integer matrices in `header$forwardmove`,
#'   `header$sidemove`, and `header$angleturn`. Weapon-switch
#'   state lives in `header$weaponselect` and BT_SPECIAL flags
#'   in `header$has_special`.
#'
#' `angleturn` is intentionally **not** thresholded onto a button slot,
#' because its magnitude contains useful turning information that a binary
#' projection would discard.
#'
#' Boom game options and reserved player flags are retained in the header.
#' Later PrBoom+ extensions and longtics variants require separate layouts.
#'
#' Analogue values are retained without projection by default. Use
#' `analog = "quantized"` to enable the direction/threshold mappings
#' described above; [analog_channels()] returns numeric values in either mode.
#'
#' @inheritParams read_movie
#' @param path Path to a `.lmp` file.
#' @return A `replayr_movie` object whose `header[["_format"]]`
#'   is `"lmp"`, with extra header columns documented above.
#' @noRd
#' @seealso [read_movie()], [supported_formats()]
.decode_lmp <- function(path, analog = c("raw", "quantized")) {
  analog <- match.arg(analog)
  if (!file.exists(path)) {
    stop("file not found: ", path, call. = FALSE)
  }
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 14L) {
    stop(path, ": too small to be a Doom demo (", length(data), " bytes)")
  }
  version <- as.integer(data[1L])
  game_options <- raw()
  reserved_players <- raw()
  compatibility <- NA_integer_
  if (version == 109L) {
    skill         <- as.integer(data[2L])
    episode       <- as.integer(data[3L])
    map           <- as.integer(data[4L])
    deathmatch    <- as.integer(data[5L])
    respawnparm   <- as.integer(data[6L])
    fastparm      <- as.integer(data[7L])
    nomonsters    <- as.integer(data[8L])
    consoleplayer <- as.integer(data[9L])
    playeringame  <- as.integer(data[10:13])
    body_start <- 14L
  } else if (version %in% 200:202) {
    option_size <- if (version == 200L) 256L else 64L
    body_start <- 14L + option_size + 32L
    if (length(data) < body_start) stop(path, ": truncated Boom demo header", call. = FALSE)
    signature <- as.raw(c(0x1d, 0x42, 0x6f, 0x6f, 0x6d, 0xe6))
    if (!identical(data[2:7], signature)) stop(path, ": invalid Boom demo signature", call. = FALSE)
    compatibility <- as.integer(data[8L])
    if (!compatibility %in% 0:1) stop(path, ": invalid Boom compatibility flag", call. = FALSE)
    skill         <- as.integer(data[9L])
    episode       <- as.integer(data[10L])
    map           <- as.integer(data[11L])
    deathmatch    <- as.integer(data[12L])
    consoleplayer <- as.integer(data[13L])
    game_options <- data[seq.int(14L, 13L + option_size)]
    respawnparm <- as.integer(game_options[7L])
    fastparm    <- as.integer(game_options[8L])
    nomonsters  <- as.integer(game_options[9L])
    player_start <- 14L + option_size
    playeringame <- as.integer(data[seq.int(player_start, player_start + 3L)])
    reserved_players <- data[seq.int(player_start + 4L, player_start + 31L)]
  } else {
    stop(path, ": unsupported Doom demo version ", version,
         "; expected a vanilla Doom 1.9 demo (109) or Boom demo (200-202)", call. = FALSE)
  }
  if (!skill %in% 0:4 || !consoleplayer %in% 0:3 ||
      any(!playeringame %in% 0:1)) {
    stop(path, ": invalid Doom demo header fields", call. = FALSE)
  }

  active <- which(playeringame == 1L)
  n_active <- length(active)
  if (n_active == 0L) {
    stop(path, ": no active players in playeringame[] (",
         paste(playeringame, collapse = ","), ")")
  }

  pos <- body_start
  end <- length(data)
  max_tics <- (end - body_start) %/% (4L * n_active) + 1L

  fwd   <- matrix(0L, nrow = max_tics, ncol = 4L)
  side  <- matrix(0L, nrow = max_tics, ncol = 4L)
  ang   <- matrix(0L, nrow = max_tics, ncol = 4L)
  bts   <- matrix(0L, nrow = max_tics, ncol = 4L)

  tic <- 0L
  ended <- FALSE
  while (pos <= end) {
    if (data[pos] == as.raw(0x80)) { ended <- TRUE; break }
    tic <- tic + 1L
    if (tic > max_tics) {
      # overflow -- grow the buffers
      grow <- max_tics
      fwd  <- rbind(fwd,  matrix(0L, grow, 4L))
      side <- rbind(side, matrix(0L, grow, 4L))
      ang  <- rbind(ang,  matrix(0L, grow, 4L))
      bts  <- rbind(bts,  matrix(0L, grow, 4L))
      max_tics <- max_tics + grow
    }
    for (p in active) {
      if (pos + 3L > end) {
        stop(path, ": truncated Doom demo in tic ", tic, call. = FALSE)
      }
      fb <- as.integer(data[pos]);     if (fb >= 128L) fb <- fb - 256L
      sb <- as.integer(data[pos + 1L]); if (sb >= 128L) sb <- sb - 256L
      ab <- as.integer(data[pos + 2L]); if (ab >= 128L) ab <- ab - 256L
      bb <- as.integer(data[pos + 3L])
      fwd[tic, p]  <- fb
      side[tic, p] <- sb
      ang[tic, p]  <- ab
      bts[tic, p]  <- bb
      pos <- pos + 4L
    }
  }

  if (!ended) stop(path, ": missing Doom demo end marker", call. = FALSE)
  n_frames <- tic
  if (n_frames > 0L) {
    fwd  <- fwd[seq_len(n_frames),  , drop = FALSE]
    side <- side[seq_len(n_frames), , drop = FALSE]
    ang  <- ang[seq_len(n_frames),  , drop = FALSE]
    bts  <- bts[seq_len(n_frames),  , drop = FALSE]
  } else {
    fwd  <- fwd[integer(0),  , drop = FALSE]
    side <- side[integer(0), , drop = FALSE]
    ang  <- ang[integer(0),  , drop = FALSE]
    bts  <- bts[integer(0),  , drop = FALSE]
  }

  n_players <- 4L
  inputs <- .empty_inputs(n_frames, n_players, 8L)
  weapon_select <- matrix(NA_integer_, nrow = n_frames, ncol = n_players)
  has_special   <- matrix(FALSE,       nrow = n_frames, ncol = n_players)
  commands <- integer(n_frames)
  if (n_frames > 0L) {
    for (p in seq_len(n_players)) {
      bp <- bts[, p]
      has_special[, p] <- bitwAnd(bp, 128L) != 0L
      actions <- ifelse(has_special[, p], 0L, bp)
      inputs[, p, 8L] <- bitwAnd(actions, 1L) != 0L     # ATTACK -> A
      inputs[, p, 7L] <- bitwAnd(actions, 2L) != 0L     # USE -> B
      # Project the sign of the resulting movement command onto the D-pad.
      # This is a direction projection, not physical-device reconstruction;
      # the original values remain available in the header matrices.
      fp <- fwd[, p]
      sp <- side[, p]
      inputs[, p, 4L] <- analog == "quantized" & fp > 0L                   # forwardmove > 0 -> U
      inputs[, p, 3L] <- analog == "quantized" & fp < 0L                   # forwardmove < 0 -> D
      inputs[, p, 1L] <- analog == "quantized" & sp > 0L                   # sidemove > 0 -> R
      inputs[, p, 2L] <- analog == "quantized" & sp < 0L                   # sidemove < 0 -> L
      ch <- bitwAnd(actions, 4L) != 0L
      weapon_select[ch, p] <-
        bitwAnd(bitwShiftR(actions[ch], 3L), 7L)
      has_special[, p] <- bitwAnd(bp, 128L) != 0L
      special_value <- ifelse(has_special[, p], bp, 0L)
      commands <- bitwOr(commands, as.integer(special_value))
    }
  }

  header <- list(
    "_format"        = "lmp",
    version          = as.character(version),
    emulator         = if (version == 109L) "Doom 1.9" else "Boom",
    observationUnit  = "game tic",
    fps              = "35",
    enabledPorts     = active,
    controllerPorts  = 1:4,
    compatibilityFlag = compatibility,
    gameOptions      = game_options,
    reservedPlayerFlags = reserved_players,
    angleturnUnit    = "signed 1/256 revolution per tic",
    skill            = as.character(skill),
    episode          = as.character(episode),
    map              = as.character(map),
    deathmatch       = as.character(deathmatch),
    respawnparm      = as.character(respawnparm),
    fastparm         = as.character(fastparm),
    nomonsters       = as.character(nomonsters),
    consoleplayer    = as.character(consoleplayer),
    playeringame     = paste(playeringame, collapse = ","),
    n_active_players = as.character(n_active),
    n_tics           = as.character(n_frames),
    forwardmove      = fwd,
    sidemove         = side,
    angleturn        = ang,
    weaponselect     = weapon_select,
    has_special      = has_special
  )

  movie <- .new_movie(
    header           = header,
    commands         = commands,
    inputs           = inputs,
    analog           = lapply(seq_len(n_players), function(p) {
      cbind(forwardmove = fwd[, p], sidemove = side[, p], angleturn = ang[, p])
    }),
    analog_mode      = analog,
    source_path      = path,
    button_mnemonics = c("R", "L", "D", "U", "T", "S", "B", "A"),
    button_names     = c("Right", "Left", "Down", "Up",
                          "Start", "Select", "USE", "ATTACK")
  )
  movie$source_header <- data[seq_len(body_start - 1L)]
  movie$source_packets <- matrix(data[seq.int(body_start, length.out = n_frames * n_active * 4L)],
                                 ncol = n_active * 4L, byrow = TRUE)
  movie$source_tail <- if (pos < length(data)) data[seq.int(pos + 1L, length(data))] else raw()
  movie
}
