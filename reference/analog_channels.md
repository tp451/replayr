# Numeric analogue channels for one player

Returns the original numeric channels decoded from the recording. These
values are retained in every representation mode. No cross-platform
normalization is applied: M64 sticks use signed -128..127 values;
PXM/PJM sticks and DTM sticks/triggers use unsigned 0..255 values; BK2
keeps its logged numeric values and LogKey column names, including
sensors and paddles. Doom channels are signed movement commands and the
stored signed angle byte, not physical device events. See the
format-specific reader for interpretation.

## Usage

``` r
analog_channels(movie, idx = 1L)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md) or
  [replayr_poll_stream](replayr_poll_stream.md) returned by
  [`read_movie()`](read_movie.md) or a format-specific reader.

- idx:

  Player index, 1-based. Defaults to 1 (player 1).

## Value

Numeric matrix with one row per observation and named channels; zero
columns for a player with no analogue channels.

## Details

For an unassigned [replayr_poll_stream](replayr_poll_stream.md),
`idx = 1` selects the single stored stream.

An absent analogue channel has no column. A missing BK2 numeric sample
is `NA`, rather than an invented neutral value. Row order matches
[`player()`](player.md).

## Examples

``` r
path <- system.file("extdata", "sample.m64", package = "replayr")
movie <- read_movie(path)
head(analog_channels(movie))
#>      lstick_x lstick_y
#> [1,]       70        0
#> [2,]       70        2
#> [3,]       70        4
#> [4,]       70        5
#> [5,]       70        7
#> [6,]       69        9
projected <- read_movie(path, analog = "cardinal8")
identical(analog_channels(movie), analog_channels(projected))
#> [1] TRUE
```
