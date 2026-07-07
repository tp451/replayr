# Read a Snes9x-rerecording .smv movie file

SNES gamepads come out 12 buttons wide (universal slots 1..12) so .smv
publications share the same shape as .lsmv and .bk2 SNES pubs. The
controller mask at offset 0x14 selects which ports the file polls; each
polled port becomes one player in the output.

## Usage

``` r
read_smv(path)
```

## Arguments

- path:

  Path to a .smv file.

## Value

A `replayr_movie` object.
