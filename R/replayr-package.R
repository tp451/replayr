#' replayr: parsers for emulator movie ("input log") files
#'
#' Decoders for 11 emulator movie file formats used by the speedrun and
#' tool-assisted-speedrun communities. Every parser produces a uniform
#' in-memory shape (a `replayr_movie` S3 object) with a per-frame logical
#' input matrix indexed against a single 30-slot universal-button layout.
#'
#' Supported formats: .fm2 (FCEUX), .bk2 (BizHawk), .fcm (FCEU),
#' .lsmv (lsnes), .gmv (Gens-rerecording), .vbm (VBA-rerecording),
#' .m64 (Mupen64), .smv (Snes9x-rerecording), .pxm (PSXjin binary),
#' .pjm (PSXjin text), .dtm (Dolphin GameCube).
#'
#' @section Quick start:
#' \preformatted{
#'   library(replayr)
#'   mv <- read_movie("data/raw_nes/super_mario_bros/1349.fm2")
#'   n_frames(mv)                       # frame count
#'   press_counts(mv)                   # per-button press counts
#'   p1 <- player(mv, 1L)               # logical matrix, frames x buttons
#' }
#'
#' @section Universal button layout:
#' Each `replayr_movie` indexes its third dimension against a prefix of
#' the 30-slot universal layout. Slots 1..8 are NES-shaped (R, L, D, U,
#' Start, Select, B, A); higher slots cover SNES, Genesis, GBA, N64,
#' PSX, GameCube. See [universal_buttons()] and [universal_button_names()].
#'
#' @keywords internal
"_PACKAGE"
