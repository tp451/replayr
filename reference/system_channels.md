# Global emulator and cabinet controls

Returns named global BK2 controls separately from player input. Numeric
channels include disk selection and cabinet dials; Boolean channels
include reset, coins and service controls. Original LogKey names and
source units are retained. These controls never create gaps in a
player's button layout.

## Usage

``` r
system_channels(movie)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md).

## Value

Data frame with one row per observation; zero columns for formats
without separately decoded global controls.

## Examples

``` r
path <- system.file("extdata", "sample.bk2", package = "replayr")
head(system_channels(read_movie(path)))
#>   Reset Power
#> 1 FALSE FALSE
#> 2 FALSE FALSE
#> 3 FALSE FALSE
#> 4 FALSE FALSE
#> 5 FALSE FALSE
#> 6 FALSE FALSE
```
