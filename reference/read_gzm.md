# Read a gz input macro

Imports gz Nintendo 64 macros, with one row per recorded game update.
[`player()`](player.md) returns the N64 buttons.
[`analog_channels()`](analog_channels.md) retains signed `stick_x` and
`stick_y`; `analog` selects a derived stick representation.

## Usage

``` r
read_gzm(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

`frame_fields` retains pad deltas and press/release masks.
`system_events` retains random-seed changes and any ocarina-input,
audio-synchronization, or room-load records. The `commands` component
marks reset events, and `source_packets` retains the six-byte input
records. Game updates provide the observation order; elapsed time
requires the game's update timing.
