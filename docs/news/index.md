# Changelog

## replayr 0.1.0

Initial release.

### Features

- Pure-R decoders for eleven emulator movie file formats: `.fm2`
  (FCEUX), `.bk2` (BizHawk), `.fcm` (FCEU), `.lsmv` (lsnes), `.gmv`
  (Gens-rerecording), `.vbm` (VBA-rerecording), `.m64` (Mupen64), `.smv`
  (Snes9x-rerecording), `.pxm` and `.pjm` (PSXjin), and `.dtm` (Dolphin
  GameCube).
- [`read_movie()`](https://tp451.github.io/replayr/reference/read_movie.md)
  dispatches on file extension; per-format readers
  ([`read_fm2()`](https://tp451.github.io/replayr/reference/read_fm2.md),
  [`read_bk2()`](https://tp451.github.io/replayr/reference/read_bk2.md),
  etc.) are also exported for callers who already know the format.
- Every parser returns the same `replayr_movie` S3 object: a per- frame
  `(n_frames, n_players, n_buttons)` logical input array, a per-frame
  integer commands vector, and a header list. The third array dimension
  is always indexed against a single 30-slot universal-button layout
  ([`universal_buttons()`](https://tp451.github.io/replayr/reference/universal_buttons.md)
  /
  [`universal_button_names()`](https://tp451.github.io/replayr/reference/universal_button_names.md)).
- Helpers:
  [`n_frames()`](https://tp451.github.io/replayr/reference/n_frames.md),
  [`n_players()`](https://tp451.github.io/replayr/reference/n_players.md),
  [`n_buttons()`](https://tp451.github.io/replayr/reference/n_buttons.md),
  [`player()`](https://tp451.github.io/replayr/reference/player.md),
  [`press_counts()`](https://tp451.github.io/replayr/reference/press_counts.md),
  plus `print` and `format` methods for `replayr_movie`.
- Eight bundled fixtures under `inst/extdata/`, one per smaller format,
  used by the test suite.
- Optional analog-stick handling: N64, GameCube, and PSX analog sticks
  are quantised to eight directions and routed into universal slots
  21..28; GameCube C-stick / PSX right stick maps onto the N64-style
  C-button slots 17..20.

### Known limitations

- `.dtm` Wii movies are not supported (GameCube only for now).
- `.lsmv` controller types other than the SNES standard gamepad (12-char
  masks; 16-char with the lsnes extension suffix) and the Game Boy / GBC
  libgambatte gamepad (8-char masks) raise an error.
- A handful of `.pjm` files in the wild lack the `||0|\r\n` body
  separator the parser scans for; those files raise an error in both the
  upstream Python implementation and in `replayr`.
