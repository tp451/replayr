# Read a VBA-rerecording .vbm movie file

GB, GBC, and SGB publications come out 8 buttons wide (universal slots
1..8). GBA publications come out 12 buttons wide (slots 1..12) so the
L/R shoulders land at their canonical universal positions. SGB
multiplayer controller streams are returned with one player dimension
per active controller flag.

## Usage

``` r
read_vbm(path)
```

## Arguments

- path:

  Path to a .vbm file.

## Value

A `replayr_movie` object.
