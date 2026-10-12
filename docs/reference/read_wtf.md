# Read an Hourglass recording

Reads WTF files with the `66 54 77 02` signature and the equivalent HGM
extension. Each frame stores up to eight Windows virtual-key codes; the
first zero ends its list of held keys.

## Usage

``` r
read_wtf(path, analog = "raw", deadzone = NULL, triggers = "raw", ...)
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

A [replayr_movie](replayr_movie.md) with keyboard states and source
metadata.

## Details

Each row is a recorded frame. `movie$header$fps` contains the recorded
nominal frame rate; `initial_time` and `clock_checks` retain the
emulator's clock metadata. The header also includes the keyboard layout,
executable name, and Hourglass revision.

[`button_layout()`](button_layout.md) identifies keys by their
hexadecimal virtual-key code: for example, `windows_vk_25` is Left and
`windows_vk_41` is A. `movie$source_keycodes` retains all eight source
bytes for every frame, and `movie$source_header` retains the original
1024-byte header.
