# Read a VBA-rerecording .vbm movie file

GB and GBC pubs (typeFlags bit 0 or 1) come out 8 buttons wide
(universal slots 1..8). GBA pubs (typeFlags bit 2) come out 12 buttons
wide (slots 1..12) so the L/R shoulders land at their canonical
universal positions.

## Usage

``` r
read_vbm(path)
```

## Arguments

- path:

  Path to a .vbm file.

## Value

A `replayr_movie` object.
