# Read a Doom .lmp demo file

Parses a vanilla Doom 1.9 `.lmp` demo into the standard `replayr_movie`
shape. Returns one row per game tic (per the active-player count from
`playeringame[]`).

## Usage

``` r
read_lmp(path)
```

## Arguments

- path:

  Path to a `.lmp` file.

## Value

A `replayr_movie` object whose `header[["_format"]]` is `"lmp"`, with
extra header columns documented above.

## Details

Doom records the resulting `ticcmd_t`, not the physical device events.
Keyboard, mouse and joystick input may all contribute to its signed
movement fields. The reader therefore exposes inputs two ways:

- Universal `inputs` array: action buttons map to the NES-shaped layout
  (ATTACK -\> slot 8 "A", USE -\> slot 7 "B"), and the **sign** of
  forwardmove / sidemove drives the D-pad slots (forwardmove \> 0 -\> U,
  \< 0 -\> D; sidemove \> 0 -\> R, \< 0 -\> L). This makes a Doom
  keypress or other movement command comparable with digital gamepad
  data; it must not be interpreted as evidence that a keyboard key was
  held.

- Original analog axes are preserved as `n_frames x 4` integer matrices
  in `header$forwardmove`, `header$sidemove`, and `header$angleturn`.
  Weapon-switch state lives in `header$weaponselect` and BT_SPECIAL
  flags in `header$has_special`.

`angleturn` is intentionally **not** thresholded onto a button slot,
because its magnitude contains useful turning information that a binary
projection would discard.

Boom / PrBoom+ extended demos (leading 0xFF byte) are not yet supported;
this reader will error out with a clear message if the file uses that
variant.

## See also

[`read_movie()`](read_movie.md),
[`supported_formats()`](supported_formats.md)
