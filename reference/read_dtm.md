# Read a DTM recording

Dolphin GameCube and Wii recordings. Multiple enabled ports return an
ordered [replayr_poll_stream](replayr_poll_stream.md) with unassigned
ports. An optional `controller_order` constructs player streams using a
caller-verified repeating port order.

## Usage

``` r
read_dtm(
  path,
  analog = "raw",
  deadzone = NULL,
  triggers = "raw",
  controller_order = NULL,
  dtm_variant = "auto",
  wii_variant = "auto",
  wii_extension = "raw",
  wii_key = NULL,
  ...
)
```

## Arguments

- path:

  Recording file path.

- analog:

  Stick representation: `"raw"` (default), `"cardinal4"`, `"cardinal8"`,
  `"angle"`, or `"angle+magnitude"`. A scalar applies to both sticks;
  `c(left = "cardinal8", right = "angle")` selects them independently.
  Cardinal modes add separate left/right logical direction columns.
  Continuous modes return numeric fields through
  [`stick_channels()`](stick_channels.md). Original X/Y values remain in
  [`analog_channels()`](analog_channels.md) in every mode. Absent sticks
  add no columns.

- deadzone:

  Radial threshold in centred axis half-range units, from zero to one.
  One value applies to both sticks; named left/right values are allowed.
  `NULL` uses format defaults: 0.25 for BK2/PSX, 0.125 for M64/DTM.
  Neutral observations have no direction and an `NA` angle. Magnitude is
  kept.

- triggers:

  `"raw"` (default) or `"digital"`. For DTM, digital additionally
  projects each analogue trigger at 128/255 into separate L2/R2 columns.
  Hardware L/R click bits remain distinct from thresholded analogue
  triggers.

- controller_order:

  Optional integer sequence listing every enabled controller port once,
  in its verified repeating polling order. Digital columns are compact;
  [`button_layout()`](button_layout.md) gives their stable IDs. Numeric
  source channels are always retained in
  [`analog_channels()`](analog_channels.md).

- dtm_variant:

  `"auto"` (default), `"standard"` (8-byte records), or `"zelda"`
  (17-byte Dolphin Zelda Edition records). Automatic recognition uses
  the verified Zelda Edition revision
  `a6e66c227c592d09ff09ef9b238d15ff52dd9632`; other revisions default to
  the standard layout. Select `"zelda"` explicitly for another build
  whose extended layout has been verified from its source.

- wii_variant:

  `"auto"`, `"hid"`, `"hid-prefix8"`, `"hid-nomarker"`, `"serialized"`,
  `"mixed-hid"`, `"mixed-hid-nomarker"`, or `"mixed-hid-connected"`.
  Automatic selection uses packet structure and, for mixed recordings,
  verified Dolphin revision profiles. `"hid-nomarker"` handles reports
  starting with the Wii report ID. `"mixed-hid-nomarker"` implements the
  native encoder rule: connected GameCube reports set the connection
  flag, disconnected reports have zero controls (with optional
  disc/reset commands), and Wii reports carry a prescribed length and
  report ID. Noncanonical records are rejected. Profiles for Dolphin
  5.0-20571 and 2407 are selected automatically from the stored
  revision. `header$framingRule` records the encoding rule.
  `"mixed-hid-connected"` remains available for externally verified
  files requiring the additional assumption that every GameCube poll is
  connected; that assumption is recorded in `header$framingAssumption`.
  [`polls()`](polls.md) retains device family, connection flags, and
  source order. Individual ports remain unassigned when several
  same-family ports are enabled.

- wii_extension:

  Legacy extension interpretation: `"raw"` (default), `"nunchuk"`, or
  `"classic"`. A selected type assumes unencrypted reports unless an
  encryption key is supplied.

- wii_key:

  Optional 16-byte numeric vector: the eight `ft` bytes followed by the
  eight `sb` bytes of the verified Dolphin extension key.

- ...:

  Reader-specific arguments, such as `controller_order` for M64 or DTM,
  or `member` for a recording inside a ZIP archive (see
  [`movie_members()`](movie_members.md)).

## Value

A [replayr_movie](replayr_movie.md) for assigned ports, or a
[replayr_poll_stream](replayr_poll_stream.md) for a multi-controller
recording with unassigned ports.

## Details

Every complete stored poll is imported. Dolphin's header input statistic
is retained as `header$inputCount`, alongside
`header$availablePollCount` and their signed difference in
`header$pollCountDifference`. Dolphin uses the input count as a
statistic, so differences remain metadata. `header$frameCount` retains
the separate video-frame count.

Zelda Edition extends each poll with a loading flag, a Tingle Tuner
event code, and Link's X/Z coordinates used by the emulator to detect
desyncs. These are available in `poll_fields`, with one row per original
poll, including when `controller_order` groups polls into player cycles.
Columns are `loading`, `tuner_event`, `link_x`, and `link_z`;
coordinates retain the game's source units. `poll_bytes` retains all
original bytes. Wii Remote recordings retain buttons, source motion
values, and IR coordinates. Wii Remote 1/2 use X/Y (IDs 9/10), +/- use
Start/Select (5/6), and Home uses Mode (19). Its D-pad and A/B buttons
share the gamepad IDs. Nunchuk C/Z use 17/18, Classic Controller buttons
use the corresponding gamepad IDs, and libTAS Guide uses Mode. Light-gun
triggers use A (8); GunCon side A/B and offscreen shot use B/X/Y
(7/9/10). Mouse left, right, and middle buttons use A/B/X. See
[`button_layout()`](button_layout.md) for shared identities.

When multiple source buttons share an ID, the column is active if either
is pressed. `source_inputs` and `source_layout` preserve the separate
states and their mapping whenever aliases are combined. Wii device
states also appear in `poll_fields` as `wii_remote_*` and
`wii_classic_*` columns, which [`polls()`](polls.md) includes for
unassigned streams. Legacy HID reports retain extension bytes;
`wii_extension = "nunchuk"` or `"classic"` decodes a caller-identified
extension. Supply `wii_key` when its reports are encrypted. The default
retains the bytes because older DTM files do not store an extension
identity or encryption key. New serialized Dolphin states include their
extension type; Nunchuk and Classic Controller states are decoded
automatically. Other extension payloads remain source bytes. Each row is
a poll. `poll_lengths` gives valid bytes in the padded `poll_bytes`
matrix; historical eight-byte prefixes remain in `poll_prefix_bytes`.
Mixed GameCube/Wii streams from the verified legacy Dolphin layout
retain device family and physical port (when unique) on each poll. They
stay in source order and do not accept `controller_order`. Automatic
mixed recognition uses revision
`7804f388aeb075266ae8c363e0932c355ba6ed5e`; select `mixed-hid`
explicitly only for a build with the same verified record layout. An
incomplete final Wii packet is retained in `source_tail`, with a
warning. Invalid reports retain their raw bytes and have
`valid_report = FALSE`. `poll_fields$report_issue` describes the
problem, and `source_offset` gives the zero-based byte position in the
file. Filter digital fields using the validity flag before analysis.
