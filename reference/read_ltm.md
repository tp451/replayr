# Read a libTAS recording

Reads native LTM archives containing `config.ini` and `inputs`. Supports
the positional input format through libTAS 1.3.5 and the later tagged
format, including ordered input events and up to four controllers.

## Usage

``` r
read_ltm(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

A [replayr_movie](replayr_movie.md) with frame timing, source inputs,
and metadata.

## Details

Each row is a recorded frame. `movie$timing` contains `framerate_num`,
`framerate_den`, `duration_seconds`, `realtime_sec`, and
`realtime_nsec`. Frame durations follow the recorded rate changes.
`movie$input_events` retains each frame's ordered events, and
`movie$flags` retains emulator flags.

`source_input_log` retains the original input lines and their row index.
Keyboard keys use their hexadecimal X KeySym in
[`button_layout()`](button_layout.md), such as `keysym_ff53` for Right.
Keyboard and mouse inputs occupy player 1 alongside controller 1.
Controller buttons retain gamepad identities, including L3 and R3.
[`analog_channels()`](analog_channels.md) includes `left_x`, `left_y`,
`right_x`, `right_y`, `trigger_left`, and `trigger_right` as signed
16-bit source values. Both sticks support the representations selected
by `analog`. Mouse channels are `mouse_x`, `mouse_y`, `mouse_wheel`, and
`mouse_mode`; mode 0 denotes absolute coordinates and mode 1 denotes
relative movement. The complete configuration remains in
`movie$header$configuration`.
