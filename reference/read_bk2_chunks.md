# Process a BizHawk recording in bounded chunks

The input member is decompressed once to a temporary file and its ZIP
checksum is verified before any callback runs. The temporary file needs
disk space equal to the uncompressed log and is removed on exit. It is
read sequentially, keeping memory use bounded. Each callback receives a
configured movie containing at most `chunk_size` observations. Its
header includes `firstObservation` and `lastObservation`, using
one-based positions in the original recording. Return a small summary
from `FUN` to keep memory use bounded; returning the movie itself
retains every chunk in memory.

## Usage

``` r
read_bk2_chunks(
  path,
  FUN,
  chunk_size = 100000L,
  analog = "raw",
  deadzone = NULL,
  triggers = "raw",
  ...
)
```

## Arguments

- path:

  Recording file path.

- FUN:

  Function called with one movie chunk. Additional arguments in `...`
  are passed to this function.

- chunk_size:

  Maximum observations passed to each callback.

- analog:

  Stick representation: `"raw"` (default), `"cardinal4"`, `"cardinal8"`,
  `"angle"`, or `"angle+magnitude"`. A scalar applies to both sticks;
  `c(left = "cardinal8", right = "angle")` selects them independently.
  Cardinal modes add separate left/right logical direction columns.
  Continuous modes return numeric fields through
  [`stick_channels()`](stick_channels.md). Original X/Y values remain in
  [`analog_channels()`](analog_channels.md) in every mode. Absent sticks
  add no columns.

- deadzone:

  Radial threshold in centred axis half-range units, from zero to one.
  One value applies to both sticks; named left/right values are allowed.
  `NULL` uses format defaults: 0.25 for BK2/PSX, 0.125 for M64/DTM.
  Neutral observations have no direction and an `NA` angle. Magnitude is
  kept.

- triggers:

  `"raw"` (default) or `"digital"`. For DTM, digital additionally
  projects each analogue trigger at 128/255 into separate L2/R2 columns.
  Hardware L/R click bits remain distinct from thresholded analogue
  triggers.

- ...:

  Additional arguments for `FUN`.

## Value

A list of callback results, with `observations` and `chunks` attributes
giving the total processed. An empty recording gives a list with no
callback results and zero observations.

## Examples

``` r
path <- system.file('extdata', 'expanded', 'two-stick-3ds.bk2', package='replayr')
counts <- read_bk2_chunks(path, function(chunk) n_frames(chunk), chunk_size=2L)
sum(unlist(counts))
#> [1] 4
attr(counts, 'observations')
#> [1] 4
```
