# Read a PSXjin .pxm movie file

PSX gamepad maps onto universal slots 1..12 (NES + SNES face / shoulder
layout) plus 29 / 30 for L2 / R2. Output is 30 buttons wide. The
5-byte-per-frame body lives at the END of the file (header + savestate
take up the rest of the leading bytes); body offset is computed as
`file_size - n_frames * 5`.

## Usage

``` r
read_pxm(path)
```

## Arguments

- path:

  Path to a .pxm file.

## Value

A `replayr_movie` object.
