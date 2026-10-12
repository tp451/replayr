# Import an emulator input recording

Dispatches by extension to the format-specific reader. Every reader
returns compact digital columns, a stable cross-controller ID map, and
original numeric channels. A row may be a frame, poll, input event, or
tic depending on the format.

## Usage

``` r
read_movie(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

A [replayr_movie](replayr_movie.md), or a
[replayr_poll_stream](replayr_poll_stream.md) for unassigned controller
ports or heterogeneous device polls, as in CTM. Use
[`button_layout()`](button_layout.md) for column identities,
[`player()`](player.md) for logical states, and
[`stick_channels()`](stick_channels.md) for selected stick fields.

## Examples

``` r
path <- system.file("extdata", "sample.m64", package = "replayr")
movie <- read_movie(path, analog = "angle+magnitude")
button_layout(movie)
#>    column id        key mnemonic    name   kind
#> 1       1  1 dpad_right        R   Right button
#> 2       2  2  dpad_left        L    Left button
#> 3       3  3  dpad_down        D    Down button
#> 4       4  4    dpad_up        U      Up button
#> 5       5  5      start        T   Start button
#> 6       6  7          b        B       B button
#> 7       7  8          a        A       A button
#> 8       8 11         l1        p      L1 button
#> 9       9 12         r1        q      R1 button
#> 10     10 18          z        Z       Z button
#> 11     11 20    c_right        > C-Right button
#> 12     12 21     c_left        <  C-Left button
#> 13     13 22     c_down        v  C-Down button
#> 14     14 23       c_up        ^    C-Up button
head(stick_channels(movie))
#>      left_angle left_magnitude
#> [1,]   0.000000      0.5468750
#> [2,]   1.636577      0.5470982
#> [3,]   3.270488      0.5477671
#> [4,]   4.085617      0.5482683
#> [5,]   5.710593      0.5496026
#> [6,]   7.431408      0.5436288
```
