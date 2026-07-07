# Read an FCEUX .fm2 movie file

Parses the text header into a list and the input log into a logical 3D
array indexed `(frame, player, button)`. Buttons are positional in
RLDUTSBA order so the output's third dimension lines up with the first
eight slots of the universal layout.

## Usage

``` r
read_fm2(path)
```

## Arguments

- path:

  Path to a .fm2 file.

## Value

A `replayr_movie` object.
