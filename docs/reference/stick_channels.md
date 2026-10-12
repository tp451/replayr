# Selected stick directions, angles and magnitudes

Angles are degrees counterclockwise from right: right = 0, up = 90, left
= 180, down = 270. Neutral angles and missing observations are `NA`.
Cardinal columns contain the nearest direction's centre angle. Magnitude
is Euclidean length after dividing each centred source axis by its
declared half-range; diagonal magnitudes can exceed one. It is not a
calibrated force measurement. `angle` excludes magnitude;
`angle+magnitude` includes it. Raw source X/Y values remain in
[`analog_channels()`](analog_channels.md) for every mode. The Saturn BK2
3D-pad fields `Stick Horizontal` and `Stick Vertical` use unsigned byte
axes centred at 128, with smaller vertical values up. Analogue shoulder
values remain separate source channels.

## Usage

``` r
stick_channels(movie, idx = 1L)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md) or
  [replayr_poll_stream](replayr_poll_stream.md) returned by
  [`read_movie()`](read_movie.md) or a format-specific reader.

- idx:

  Player index, 1-based. Defaults to 1 (player 1).

## Value

Numeric matrix with selected fields. Absent sticks have no columns.

## Examples

``` r
path <- system.file("extdata", "sample.m64", package = "replayr")
movie <- read_movie(path, analog = "angle+magnitude")
head(stick_channels(movie))
#>      left_angle left_magnitude
#> [1,]   0.000000      0.5468750
#> [2,]   1.636577      0.5470982
#> [3,]   3.270488      0.5477671
#> [4,]   4.085617      0.5482683
#> [5,]   5.710593      0.5496026
#> [6,]   7.431408      0.5436288
```
