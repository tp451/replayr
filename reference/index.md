# Package index

## Reading movie files

Top-level entry points for parsing emulator movie files.

- [`read_movie()`](read_movie.md) : Read any supported movie file by
  extension
- [`supported_formats()`](supported_formats.md) : Names of the supported
  movie file extensions

## Per-format readers

Direct readers for each supported file format. Useful when you already
know the format.

- [`read_fm2()`](read_fm2.md) : Read an FCEUX .fm2 movie file
- [`read_bk2()`](read_bk2.md) : Read a BizHawk .bk2 movie file
- [`read_fcm()`](read_fcm.md) : Read a FCEU .fcm movie file
- [`read_lsmv()`](read_lsmv.md) : Read an lsnes .lsmv movie file
- [`read_gmv()`](read_gmv.md) : Read a Gens-rerecording .gmv movie file
- [`read_vbm()`](read_vbm.md) : Read a VBA-rerecording .vbm movie file
- [`read_m64()`](read_m64.md) : Read a Mupen64 .m64 movie file
- [`read_smv()`](read_smv.md) : Read a Snes9x-rerecording .smv movie
  file
- [`read_pxm()`](read_pxm.md) : Read a PCSX-rerecording .pxm movie file
- [`read_pjm()`](read_pjm.md) : Read a PSXjin .pjm movie file
- [`read_dtm()`](read_dtm.md) : Read a Dolphin .dtm GameCube movie file
- [`read_lmp()`](read_lmp.md) : Read a Doom .lmp demo file

## Inspecting parsed movies

Helpers for working with the `replayr_movie` S3 object returned by the
readers.

- [`replayr_movie`](replayr_movie.md) :

  The `replayr_movie` S3 class

- [`n_frames()`](n_frames.md) : Number of frames in a parsed movie

- [`n_players()`](n_players.md) : Number of players (controller ports)
  in a parsed movie

- [`n_buttons()`](n_buttons.md) : Number of universal-button slots in a
  parsed movie

- [`player()`](player.md) : Per-frame button presses for one player

- [`press_counts()`](press_counts.md) : Press counts per
  universal-button slot

## Universal button layout

The 40-slot universal-button alphabet that every parser writes into.

- [`universal_buttons()`](universal_buttons.md) : Universal button
  mnemonics
- [`universal_button_names()`](universal_button_names.md) : Universal
  button friendly names

## Package

- [`replayr`](replayr-package.md)
  [`replayr-package`](replayr-package.md) : replayr: parsers for
  emulator movie ("input log") files
