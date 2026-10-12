# Read a Citra device-poll recording

Imports Nintendo 3DS CTM recordings as ordered device polls. Pad and
Circle Pad, touch, accelerometer, gyroscope, IR C-stick, and extra-HID
polls each occupy their own rows. [`polls()`](polls.md) exposes
`event_type` and flags identifying the observed device.
`observed_inputs` marks the digital controls measured at each poll;
numeric fields for other devices are `NA`.

## Usage

``` r
read_ctm(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

A [replayr_poll_stream](replayr_poll_stream.md) containing ordered
device polls and metadata.

## Details

[`analog_channels()`](analog_channels.md) retains the source
coordinates, motion values, and battery level. The Circle Pad and
C-stick support the four stick modes through `analog`, using their
source-specific centers and scales. `poll_bytes` retains the seven-byte
records. Timing follows device-poll order; CTM provides no video-frame
assignment for these rows.
