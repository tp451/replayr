# Sources / attribution:
#
# Doom .lmp demo format. Reference: id Software's GPL Doom source
# (https://github.com/id-Software/DOOM, GPLv2; specifically
# linuxdoom-1.10/g_game.c -- G_BeginRecording / G_DoSaveGame /
# G_RecordDemo) and the canonical DoomWiki spec at
# https://doomwiki.org/wiki/Demo.
#
# Format chosen for v0.3: vanilla Doom 1.9 (12-byte header, 4-byte-
# per-player-per-tic ticcmd_t, 0x80 end marker). Boom / PrBoom+
# extensions (leading 0xFF + signature + complevel + variant
# header + optional 5-byte longtics) are detected and rejected
# with a clear error -- support for those is a v0.4 follow-up
# once we have test fixtures.
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# Vanilla header (12 bytes):
#   0   skill (1-5)
#   1   episode (1-4 for Doom 1 / Ultimate Doom; 1 for Doom 2)
#   2   map (1-9 for Doom 1; 1-32 for Doom 2)
#   3   deathmatch (0=coop, 1=DM, 2=alt-DM)
#   4   respawnparm (0/1)
#   5   fastparm (0/1)
#   6   nomonsters (0/1)
#   7   consoleplayer (0..3 -- which player slot is "us")
#   8-11 playeringame[0..3] (0=absent, 1=present)
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
#' Parses a vanilla Doom 1.9 `.lmp` demo into the standard
#' `replayr_movie` shape. Returns one row per game tic (per the
#' active-player count from `playeringame[]`).
#'
#' @details
#' Doom's input model is fundamentally **digital**: vanilla
#' Doom 1.9 is keyboard-driven, and the signed forwardmove /
#' sidemove bytes in the wire format are just smoothed
#' representations of held-key state (the engine ramps to the
#' cap when a movement key is held and decays when released).
#' Mouse input contributes to **angleturn only** -- never to
#' forward / side movement. The reader therefore exposes inputs
#' two ways:
#'
#' * Universal `inputs` array: action buttons map to the
#'   NES-shaped layout (ATTACK -> slot 8 "A", USE -> slot 7
#'   "B"), and the **sign** of forwardmove / sidemove drives
#'   the D-pad slots (forwardmove > 0 -> U, < 0 -> D;
#'   sidemove > 0 -> R, < 0 -> L). This makes a Doom keypress
#'   look like a Doom keypress and lets cross-format analyses
#'   treat it uniformly with NES / SNES / arcade keyboard data.
#' * Original analog axes are preserved as `n_frames x 4`
#'   integer matrices in `header$forwardmove`,
#'   `header$sidemove`, and `header$angleturn`. Weapon-switch
#'   state lives in `header$weaponselect` and BT_SPECIAL flags
#'   in `header$has_special`.
#'
#' `angleturn` is intentionally **not** thresholded onto a
#' button slot: it is the one channel that can carry mouse
#' input in vanilla Doom, so a binary projection would
#' misrepresent runs that used mouse turning.
#'
#' Boom / PrBoom+ extended demos (leading 0xFF byte) are not
#' yet supported; this reader will error out with a clear
#' message if the file uses that variant.
#'
#' @param path Path to a `.lmp` file.
#' @return A `replayr_movie` object whose `header[["_format"]]`
#'   is `"lmp"`, with extra header columns documented above.
#' @export
#' @seealso [read_movie()], [supported_formats()]
read_lmp <- function(path) {
  if (!file.exists(path)) {
    stop("file not found: ", path, call. = FALSE)
  }
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 13L) {
    stop(path, ": too small to be a Doom demo (", length(data), " bytes)")
  }
  # Format detection. Vanilla Doom 1.9 demos open with the skill
  # byte (1-5). Several extended formats use higher first-byte
  # values and/or distinctive signatures:
  #   0xFF + ...          -- early Boom (complevel 7-9 era)
  #   0xCA / 0xCB + Boom  -- PrBoom+ / dsda-doom (complevel 11+)
  #   anything > 5        -- something unrecognised
  fb <- as.integer(data[1])
  if (fb == 0xFFL || fb == 0xCAL || fb == 0xCBL) {
    sig <- if (length(data) >= 6L) rawToChar(data[3:6]) else ""
    stop(path,
         ": extended-format Doom demo detected (first byte 0x",
         sprintf("%02X", fb),
         if (nzchar(sig)) paste0(" signature '", sig, "'") else "",
         "). Vanilla Doom 1.9 demos only in replayr v0.3; ",
         "support for Boom / PrBoom+ / dsda-doom extended demos ",
         "is a planned v0.4 follow-up.", call. = FALSE)
  }
  if (fb < 1L || fb > 5L) {
    stop(path,
         ": first byte 0x", sprintf("%02X", fb),
         " is not a valid Doom skill (expected 1..5). ",
         "This file does not appear to be a Doom 1.9 demo.",
         call. = FALSE)
  }

  skill         <- as.integer(data[1])
  episode       <- as.integer(data[2])
  map           <- as.integer(data[3])
  deathmatch    <- as.integer(data[4])
  respawnparm   <- as.integer(data[5])
  fastparm      <- as.integer(data[6])
  nomonsters    <- as.integer(data[7])
  consoleplayer <- as.integer(data[8])
  playeringame  <- as.integer(data[9:12])

  active <- which(playeringame == 1L)
  n_active <- length(active)
  if (n_active == 0L) {
    stop(path, ": no active players in playeringame[] (",
         paste(playeringame, collapse = ","), ")")
  }

  body_start <- 13L  # byte 12 (0-based 12 = 1-based 13)
  pos <- body_start
  end <- length(data)
  max_tics <- (end - body_start) %/% (4L * n_active) + 1L

  fwd   <- matrix(0L, nrow = max_tics, ncol = 4L)
  side  <- matrix(0L, nrow = max_tics, ncol = 4L)
  ang   <- matrix(0L, nrow = max_tics, ncol = 4L)
  bts   <- matrix(0L, nrow = max_tics, ncol = 4L)

  tic <- 0L
  while (pos <= end) {
    if (data[pos] == as.raw(0x80)) break  # demo end marker
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
        # truncated mid-tic; the engine would refuse, we just stop.
        tic <- tic - 1L
        pos <- end + 1L
        break
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
  if (n_frames > 0L) {
    for (p in seq_len(n_players)) {
      bp <- bts[, p]
      inputs[, p, 8L] <- bitwAnd(bp, 1L) != 0L     # ATTACK -> A
      inputs[, p, 7L] <- bitwAnd(bp, 2L) != 0L     # USE -> B
      # Vanilla Doom is keyboard-driven for movement; mouse only
      # touches angleturn. Project the sign of forwardmove and
      # sidemove onto the D-pad so keypresses are surfaced
      # uniformly with the other keyboard-shaped formats. The
      # analog values themselves are preserved in header$.
      fp <- fwd[, p]
      sp <- side[, p]
      inputs[, p, 4L] <- fp > 0L                   # forwardmove > 0 -> U
      inputs[, p, 3L] <- fp < 0L                   # forwardmove < 0 -> D
      inputs[, p, 1L] <- sp > 0L                   # sidemove > 0 -> R
      inputs[, p, 2L] <- sp < 0L                   # sidemove < 0 -> L
      ch <- bitwAnd(bp, 4L) != 0L
      weapon_select[ch, p] <-
        bitwAnd(bitwShiftR(bp[ch], 3L), 7L)
      has_special[, p] <- bitwAnd(bp, 128L) != 0L
    }
  }

  header <- list(
    "_format"        = "lmp",
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

  .new_movie(
    header           = header,
    commands         = integer(n_frames),
    inputs           = inputs,
    source_path      = path,
    button_mnemonics = c("R", "L", "D", "U", "T", "S", "B", "A"),
    button_names     = c("Right", "Left", "Down", "Up",
                          "Start", "Select", "USE", "ATTACK")
  )
}
