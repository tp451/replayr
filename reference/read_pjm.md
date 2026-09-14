# Read a PSXjin .pjm movie file

Parses the PSXjin movie format into the standard `replayr_movie` shape.
Supports the text body in its one-controller (20-byte line),
two-controller (34-byte line) and analog (wider line) variants, plus the
binary bodies with configured standard or analog controller widths. A
text movie whose body ends on a complete record boundary may be up to
two frames shorter than its declared count; the reader warns, returns
only the complete physical records, and preserves both counts in the
movie header. A missing terminal newline is accepted only if every
controller field and delimiter is complete. Larger or partial-record
truncations are errors. Analog text ports retain quantised stick
movement. The PSX gamepad maps onto universal slots 1..12 (NES + SNES
face / shoulder layout) plus 29 / 30 for L2 / R2; the output is 32
buttons wide, including L3/R3 on analog controllers. Standard digital
pads do not turn reserved bits into stick-click actions. Two-controller
movies yield a two-player movie (analysis code that wants player 1
simply reads the first player).

## Usage

``` r
read_pjm(path)
```

## Arguments

- path:

  Path to a .pjm file.

## Value

A `replayr_movie` object.
