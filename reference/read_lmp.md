# Read a Doom or Boom demo

Imports vanilla Doom 1.9 demos (version 109) and Boom 2.00-2.02 demos
(versions 200-202). Each row represents a game tic at 35 tics per
second. `header$enabledPorts` identifies the players whose commands were
stored.

## Usage

``` r
read_lmp(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

- ...:

  Reader-specific arguments, such as `controller_order` for M64 or DTM,
  or `member` for a recording inside a ZIP archive (see
  [`movie_members()`](movie_members.md)).

## Value

A [replayr_movie](replayr_movie.md) with compact digital columns and
source metadata.

## Details

[`player()`](player.md) exposes Use and Attack.
[`analog_channels()`](analog_channels.md) returns signed `forwardmove`,
`sidemove`, and `angleturn`; the turning unit is 1/256 of a revolution
per tic. These are game commands assembled from the input devices, so
stick options leave them unchanged. Weapon selection and special-command
flags remain in `header$weaponselect` and `header$has_special`;
`commands` retains the special-command bytes.

Boom options remain in `header$gameOptions`. `source_header` and
`source_packets` preserve the recorded bytes, and `source_tail`
preserves bytes after the demo-end marker. Later extended and longtics
layouts are outside the supported versions.
