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

Doom's input model is fundamentally **digital**: vanilla Doom 1.9 is
keyboard-driven, and the signed forwardmove / sidemove bytes in the wire
format are just smoothed representations of held-key state (the engine
ramps to the cap when a movement key is held and decays when released).
Mouse input contributes to **angleturn only** – never to forward / side
movement. The reader therefore exposes inputs two ways:

- Universal `inputs` array: action buttons map to the NES-shaped layout
  (ATTACK -\> slot 8 "A", USE -\> slot 7 "B"), and the **sign** of
  forwardmove / sidemove drives the D-pad slots (forwardmove \> 0 -\> U,
  \< 0 -\> D; sidemove \> 0 -\> R, \< 0 -\> L). This makes a Doom
  keypress look like a Doom keypress and lets cross-format analyses
  treat it uniformly with NES / SNES / arcade keyboard data.

- Original analog axes are preserved as `n_frames x 4` integer matrices
  in `header$forwardmove`, `header$sidemove`, and `header$angleturn`.
  Weapon-switch state lives in `header$weaponselect` and BT_SPECIAL
  flags in `header$has_special`.

`angleturn` is intentionally **not** thresholded onto a button slot: it
is the one channel that can carry mouse input in vanilla Doom, so a
binary projection would misrepresent runs that used mouse turning.

Boom / PrBoom+ extended demos (leading 0xFF byte) are not yet supported;
this reader will error out with a clear message if the file uses that
variant.

## See also

[`read_movie()`](https://tp451.github.io/replayr/reference/read_movie.md),
[`supported_formats()`](https://tp451.github.io/replayr/reference/supported_formats.md)
