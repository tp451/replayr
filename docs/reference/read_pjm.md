# Read a PSXjin .pjm movie file

Parses the PSXjin movie format into the standard `replayr_movie` shape.
Supports the text body in its one-controller (20-byte line),
two-controller (34-byte line) and analog (wider line) variants, plus the
binary 5-byte-per-frame body. The PSX gamepad maps onto universal slots
1..12 (NES + SNES face / shoulder layout) plus 29 / 30 for L2 / R2; the
output is 30 buttons wide. Two-controller movies yield a two-player
movie (analysis code that wants player 1 simply reads the first player).

## Usage

``` r
read_pjm(path)
```

## Arguments

- path:

  Path to a .pjm file.

## Value

A `replayr_movie` object.
