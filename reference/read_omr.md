# Read an openMSX replay

Reads gzip-compressed openMSX XML replay files. Supported event schemas
cover keyboard matrices, joysticks, mice, trackballs, paddles,
touchpads, light guns, and autofire settings. The initial keyboard state
is read from the first replay snapshot. Source device names qualify the
control keys, such as `openmsx_keyjoystick1_a`; `openmsx_key_r8_b0`
identifies a keyboard matrix row and bit. All devices share one event
stream.

## Usage

``` r
read_omr(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

A [replayr_movie](replayr_movie.md) with event times, device controls,
and source XML.

## Details

Each row follows one replay event. `movie$events$timestamp_ticks`
retains time in openMSX master-clock ticks (3,579,545 \* 960 ticks per
second), and `timestamp_seconds` expresses the same event times in
seconds. `timestamp_source`, `event_type`, `source_device`, and
`source_xml` retain the event's original time, type, device, and XML.

[`analog_channels()`](analog_channels.md) preserves device-specific
values. Examples include `openmsx_mouse_dx` and `openmsx_mouse_dy` for
movement, `openmsx_touchpad_x` and `openmsx_touchpad_y` for touch
coordinates, and `openmsx_autofire_renshaturbo` for the recorded
autofire setting. Movement deltas apply to their event; coordinates and
settings persist until updated. The replay schema version and machine
name remain in `movie$header$replay_version` and `movie$header$machine`.
