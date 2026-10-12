# Read a DeSmuME recording

Imports Nintendo DS DSM versions 1 and 2 in text or binary form, with
one row per recorded frame. [`player()`](player.md) includes the pad
buttons, touch state, microphone activation, and lid state.
[`button_layout()`](button_layout.md) identifies the fields.

## Usage

``` r
read_dsm(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

[`analog_channels()`](analog_channels.md) returns `touch_x`, `touch_y`,
and `touch_pressed`. Touch coordinates use the screen's top-left origin,
with a nominal extent of 256 by 192. Text recordings with a fourth
numeric field also provide `microphone_sample`; absent samples are `NA`.
The binary layout stores three touch fields. Stick options leave these
source channels unchanged.

The `commands` component retains the original byte: microphone
activation uses bit 0, reset uses bit 1, and lid state uses bit 2. Text
records may be adjacent or separated by whitespace.
