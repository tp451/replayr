# Read a M64 recording

Mupen64 version 3 recordings. A single enabled controller returns a
[replayr_movie](replayr_movie.md). Multiple enabled controllers return a
[replayr_poll_stream](replayr_poll_stream.md) with all samples in source
order, because M64 stores no per-sample port IDs. Digital columns are
compact; [`button_layout()`](button_layout.md) gives their stable IDs.
Numeric source channels are always retained in
[`analog_channels()`](analog_channels.md).

## Usage

``` r
read_m64(
  path,
  analog = "raw",
  deadzone = NULL,
  triggers = "raw",
  controller_order = NULL,
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

  Optional sequence of distinct enabled controller ports (1–4) in an
  externally verified repeating polling order. `NULL` preserves an
  unassigned stream when multiple ports are enabled.

- ...:

  Reader-specific arguments, such as `controller_order` for M64 or DTM,
  or `member` for a recording inside a ZIP archive (see
  [`movie_members()`](movie_members.md)).

## Value

A [replayr_movie](replayr_movie.md) for an assigned controller order, or
a [replayr_poll_stream](replayr_poll_stream.md) for multiple controllers
with unassigned ports.

## Details

An externally verified repeating polling order can be supplied to
construct per-player matrices. These use compact player indices in
ascending physical port order; `movie$header$controllerPorts` gives the
physical port for each player index. Enabled ports omitted from that
order are treated as unpolled. Each output row is one supplied polling
cycle, not a video frame. The source poll count and VI count remain in
`header$inputSampleCount` and `header$viCount`; `poll_bytes` retains
four original bytes per source poll. Import stops at the declared sample
count, as Mupen playback does. Legacy writers can leave an extra
terminal record or an older file suffix; these bytes remain in
`source_tail`.
