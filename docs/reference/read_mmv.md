# Read a Dega recording

Imports Master System and Game Gear input, including older MMV headers.
Each row represents one complete stored frame. Master System recordings
have two controller ports; Game Gear recordings have one player.
[`button_layout()`](button_layout.md) retains the source labels 1, 2,
and Pause or Start.

## Usage

``` r
read_mmv(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

The header includes `declaredFrameCount`, `availableFrameCount`,
`frameCountDifference`, `frameCount`, and region flags. Following Dega's
playback rule, all complete packets through the end of the file are
imported. `source_packets` retains packet bytes, including padding. An
incomplete final packet produces a warning and remains in `source_tail`.
