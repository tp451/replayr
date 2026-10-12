# Read an lsnes LSMV recording

Reads ZIP input logs with `controlsversion` 0: Game Boy/Game Boy Color
pads, SNES 12- and 16-button pads, multitaps, Y-cabled pads, and a
declared Super Scope on port 2. Super Game Boy movies retain their SNES
controller layout. The four extra pad controls have keys `lsnes_ext0` to
`lsnes_ext3`.

## Usage

``` r
read_lsmv(
  path,
  analog = "raw",
  deadzone = NULL,
  triggers = "raw",
  max_input_bytes = 256 * 1024^2,
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

- max_input_bytes:

  Maximum expanded input-log size for a full import, in bytes. The
  default is `256 * 1024^2`. Increase this explicitly when sufficient
  memory is available, up to R's single-string limit of `2147483647`
  bytes. The limit is checked before extracting the input log.

- ...:

  Reader-specific arguments, such as `controller_order` for M64 or DTM,
  or `member` for a recording inside a ZIP archive (see
  [`movie_members()`](movie_members.md)).

## Value

A [replayr_movie](replayr_movie.md) with one observation per input
subframe.

## Details

Every non-empty input row is retained, including subframes between frame
starts. [`n_frames()`](n_frames.md) counts these observations;
`header$frameCount` counts frame starts. `subframes` contains
`source_line`, `frame_start`, `source_frame`, and `subframe` (the row's
one-based position within its source frame). Player indices follow
controller fields in the source log.

`subframes` also retains `reset`, `hard_reset`, `reset_delay_high`, and
`reset_delay_low`. The encoded delay is
`10000 * reset_delay_high + reset_delay_low`. `commands` uses bit 0 for
the reset flag and bit 1 for the hard-reset flag. `source_input`
preserves the complete input text, including blank lines and original
line endings.

Super Scope controls use `gun_trigger`, `lsnes_scope_cursor`,
`lsnes_scope_turbo`, and `lsnes_scope_pause`.
[`analog_channels()`](analog_channels.md) returns its signed source
`gun_x` and `gun_y` coordinates. [`button_layout()`](button_layout.md)
gives stable control IDs. Mouse and Justifier port types raise an error.

The input member's ZIP checksum is verified before parsing. Full imports
default to a 256 MiB expanded-input limit. Damaged controller metadata
raises an error; other complete metadata with an integrity defect is
retained with a warning.
