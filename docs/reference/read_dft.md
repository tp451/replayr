# Read a Dustmod input script archive

Imports DFT archives by following their entry script and INCLUDE
commands. Each row represents one scripted input frame. Directional
double taps are preserved in `double_tapped`; `source_digits` and
`source_values` retain the original 0, 1, and 2 encoding. Optional taunt
and restart columns are retained when present.

## Usage

``` r
read_dft(
  path,
  analog = "raw",
  deadzone = NULL,
  triggers = "raw",
  entry = NULL,
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

- entry:

  Entry script member. `NULL` selects the archive's unique `main.txt`;
  an explicit member resolves archives with several candidates.

- ...:

  Reader-specific arguments, such as `controller_order` for M64 or DTM,
  or `member` for a recording inside a ZIP archive (see
  [`movie_members()`](movie_members.md)).

## Value

A [replayr_movie](replayr_movie.md) with source scripts, commands, and
locations.

## Details

`source_locations` identifies the archive member and line for each row.
`source_commands` preserves loading, synchronization, mouse, statistics,
and include commands in script order. MOUSE coordinates and button
states apply to the next scripted row, with observation masks
identifying those rows. SYNCLOAD can add runtime waiting whose duration
requires execution in the game; the imported rows retain script order.
