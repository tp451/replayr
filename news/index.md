# Changelog

## replayr 0.3.3

### Bug fixes

- Corrected header offsets, frame/sample counts, controller flags,
  multiplayer handling, reset markers, controller record widths, and
  command-byte decoding across the M64, VBM, SMV, GMV, PXM, PJM, DTM,
  FCM, BK2, LSMV, and LMP readers.
- `.pxm` is now correctly identified and decoded as the PCSX-rerecording
  format, including both controller ports, digital and analog controller
  widths, 128-centred axes, and per-frame control bytes.
- Ambiguous M64 and DTM multiplayer poll streams, and variable-width
  peripherals not implemented by a reader, now raise explicit errors
  instead of returning misassigned or misaligned input.
- BK2 PlayStation analog axes now use their unsigned 0..255 convention
  for all values, and an unsupported sparse `LogKey` can no longer fall
  back to an NES positional interpretation.
- Doom movement documentation now describes the recorded composite
  movement commands rather than inferring a physical input device;
  BT_SPECIAL values are retained in `commands`.
- Reader outputs are validated for array shape, command length, and
  button metadata consistency. Tests can no longer silently skip when
  `testthat` is absent, and generated edge-case fixtures cover all
  twelve readers.
- Replaced third-party publication fixtures with reproducible,
  approximately one-minute synthetic controller streams for all twelve
  supported formats. The package now ships no published movie data.

## replayr 0.3.2

### Bug fixes

- [`read_pjm()`](../reference/read_pjm.md) now handles every PSXjin body
  layout, not just the one-controller `<mask>||0|` text line. PSXjin
  renders each frame as `<port1>|<port2>|...|<cmd>|`, where a port is a
  14-character digital mask optionally trailed by space-padded decimal
  analog-stick values. One-controller movies leave port 2 empty (the
  historical 20-byte line); two-controller movies fill it (34-byte
  line); analog movies are wider (52-byte). The reader locates the body
  by its `|`CRLF frame terminator, derives the stride and per-port
  column offsets from the first frame, and reads each port’s digital
  mask (analog decimals are ignored); two-controller movies yield a
  two-player movie. Binary-body movies (no text terminator; 5
  bytes/frame at the end of the file) are decoded via the shared
  DualShock bit layout. This fixes the previously-unreadable Metal Gear
  Solid, Spyro 1 / 2, Klonoa, Pepsiman, Bishi Bashi and Mega Man X4
  movies. One-controller decoding is byte-for-byte unchanged.
  Regression + synthetic tests added.
- [`read_fcm()`](../reference/read_fcm.md) accepts format version 1 as
  well as 2. The two versions share this header layout and delta-encoded
  body (the bump only added savestate metadata); verified on real v1
  movies (Dragon’s Lair, Power Blade) whose decoded frame counts and
  press rates are correct. Test added.
- [`read_bk2()`](../reference/read_bk2.md) no longer aborts on archives
  whose `Header.txt` carries a NUL-padded fixed-width field
  (e.g. `BoardName NULL\0\0...`, written by some Gambatte-core Game Boy
  movies such as Kwirk and the 4-in-1 Fun Pak titles). Embedded NULs are
  stripped before the member is decoded as text. Test added.

### Known limitations

- One rare PSXjin binary variant with per-frame analog records (~9
  bytes/frame, e.g. Final Fantasy VIII) is detected and rejected with a
  clear message rather than silently mis-decoded.

## replayr 0.3.1

### Bug fixes

- [`read_fm2()`](../reference/read_fm2.md) no longer aborts on `.fm2`
  headers that contain non-UTF-8 bytes – e.g. a Shift-JIS `romFilename`
  for a Japanese ROM (忍者龍剣伝…), or an 8-bit `subtitle`. Previously
  the first regex to touch such a line raised “unable to translate ‘’ to
  a wide string”. Offending header lines are now re-decoded as latin1
  (the fields that carry these bytes are non-essential metadata); valid
  UTF-8 lines such as accented author names are left untouched.
  Regression test added.

## replayr 0.3.0

### New format

- **Doom `.lmp`** – vanilla Doom 1.9 demo format. New
  [`read_lmp()`](../reference/read_lmp.md) entry point. Adds Doom (the
  historically most influential FPS) to the input-pattern stylometry
  corpus. Format: 12-byte header (skill / episode / map / dm / respawn /
  fast / nomonsters / consoleplayer / playeringame\[4\]) followed by
  4-byte-per-tic-per-active-player ticcmd_t records and a 0x80 end
  marker. Doom’s analog axes (forwardmove / sidemove / angleturn) and
  the weapon-select state are surfaced as extra per-frame integer
  matrices in the `header` slot; ATTACK and USE buttons map to A and B
  in the universal-buttons array.
- [`read_movie()`](../reference/read_movie.md) dispatcher and
  [`supported_formats()`](../reference/supported_formats.md) updated to
  include `.lmp`.

### Format detection

- Boom / PrBoom+ / dsda-doom extended-format demos (leading `0xFF`,
  `0xCA`, or `0xCB`) are detected and rejected with a clear error.
- Sub-vanilla files (first byte outside skill range 1..5) are also
  rejected with a clear diagnostic message.

## replayr 0.1.0

Initial release.

### Features

- Pure-R decoders for eleven emulator movie file formats: `.fm2`
  (FCEUX), `.bk2` (BizHawk), `.fcm` (FCEU), `.lsmv` (lsnes), `.gmv`
  (Gens-rerecording), `.vbm` (VBA-rerecording), `.m64` (Mupen64), `.smv`
  (Snes9x-rerecording), `.pxm` (PCSX-rerecording), `.pjm` (PSXjin), and
  `.dtm` (Dolphin GameCube).
- [`read_movie()`](../reference/read_movie.md) dispatches on file
  extension; per-format readers
  ([`read_fm2()`](../reference/read_fm2.md),
  [`read_bk2()`](../reference/read_bk2.md), etc.) are also exported for
  callers who already know the format.
- Every parser returns the same `replayr_movie` S3 object: a per- frame
  `(n_frames, n_players, n_buttons)` logical input array, a per-frame
  integer commands vector, and a header list. The third array dimension
  is always indexed against a single 40-slot universal-button layout
  ([`universal_buttons()`](../reference/universal_buttons.md) /
  [`universal_button_names()`](../reference/universal_button_names.md)).
- Helpers: [`n_frames()`](../reference/n_frames.md),
  [`n_players()`](../reference/n_players.md),
  [`n_buttons()`](../reference/n_buttons.md),
  [`player()`](../reference/player.md),
  [`press_counts()`](../reference/press_counts.md), plus `print` and
  `format` methods for `replayr_movie`.
- Eight bundled fixtures under `inst/extdata/`, one per smaller format,
  used by the test suite.
- Optional analog-stick handling: N64, GameCube, and PSX analog sticks
  are quantised to eight directions and routed into universal slots
  21..28; GameCube C-stick / PSX right stick maps onto the N64-style
  C-button slots 17..20.

### Known limitations

- `.dtm` Wii and multi-controller poll streams are not supported.
- Multi-controller `.m64` poll streams are not supported because records
  do not identify their source controller.
- `.lsmv` controller types other than the SNES standard gamepad (12-char
  masks; 16-char with the lsnes extension suffix) and the Game Boy / GBC
  libgambatte gamepad (8-char masks) raise an error.
- Variable-width SMV peripherals, PXM mouse/light-gun input, and binary
  PJM analog-controller records are rejected rather than approximated.
- Boom, PrBoom+, and dsda-doom extended `.lmp` demos are not supported.
