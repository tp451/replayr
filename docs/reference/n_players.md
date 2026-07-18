# Number of players (controller ports) in a parsed movie

Number of players (controller ports) in a parsed movie

## Usage

``` r
n_players(movie)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md) (returned by
  [`read_movie()`](read_movie.md) or any of the format-specific
  readers).

## Value

Integer scalar: the second dimension of `movie$inputs`.
