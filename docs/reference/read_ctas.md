# Read a CoffeeTools recording

Reads CTAS versions 3 and 4 for UFO 50. Each row contains one frame's
input for both players: four directions, `ufo50_fire1`, `ufo50_fire2`,
and Start. The Start column records a press event; the other six columns
record held states.

## Usage

``` r
read_ctas(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

A [replayr_movie](replayr_movie.md) with held states, press/release
flags, and randomization data.

## Details

`movie$pressed` and `movie$released` retain the six controls' separate
press and release flags as frame-by-player-by-control logical arrays.
For example, `movie$pressed[, 1, "ufo50_fire1"]` selects player 1's
first action-button press events. These flags are read from the file
alongside held states, allowing a game's press and hold behaviour to be
compared.

`movie$randomization` contains the recorded `input_frame` and `seed`
pairs in source units. `movie$source_words` retains both players' input
words, and `movie$source_header` retains the original header. Version 4
adds `rerecord_count` and `current_time` to `movie$header`; those fields
are `NA` for version 3. Rows use the file's frame index; randomization
frame numbers are retained exactly as stored.
