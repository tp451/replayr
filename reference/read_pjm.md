# Read a PSXjin .pjm movie file

Parses the PSXjin text-body movie format into the standard
`replayr_movie` shape. PSX gamepad maps onto universal slots 1..12 (NES

- SNES face / shoulder layout) plus 29 / 30 for L2 / R2; the output is
  30 buttons wide.

## Usage

``` r
read_pjm(path)
```

## Arguments

- path:

  Path to a .pjm file.

## Value

A `replayr_movie` object.
