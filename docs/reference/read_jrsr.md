# Read a JPC-RR recording

Reads JRSR text archives containing an `events` section. Keyboard edges,
mouse buttons and movement, joystick events, and reset commands are
decoded. Other emulator events remain in `movie$events` with their
arguments and original source lines. Initialization sections remain in
`movie$header$initialization` and `movie$event_sections`.

## Usage

``` r
read_jrsr(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

A [replayr_movie](replayr_movie.md) with event times, reconstructed
states, and source events.

## Details

Each row follows one timestamped event. `movie$events$timestamp_ns`
gives absolute time in nanoseconds after applying recorded `RELATIVE`
and `ABSOLUTE` options. `timestamp_source` retains the source timestamp
text. Keyboard and button states persist until the next relevant event;
mouse movement channels record the displacement at that event.

Keyboard identities use `jpcrr_key_<number>`, preserving JPC-RR's
key-code namespace. The Pause event appears as a `jpcrr_pause` pulse.
Keyboard and mouse inputs occupy player 1.
[`analog_channels()`](analog_channels.md) exposes `mouse_dx`,
`mouse_dy`, and `mouse_wheel`, and the joystick channels
`joystick_x_hold_ns` and `joystick_y_hold_ns`. Joystick values are
recorded game-port hold times in nanoseconds and remain `NA` before
their first update.
