# Number of assigned input streams

Keyboard and mouse controls can share a stream. The format-specific
header describes device grouping; a stream is not evidence of a distinct
person.

## Usage

``` r
n_players(movie)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md) or
  [replayr_poll_stream](replayr_poll_stream.md) returned by
  [`read_movie()`](read_movie.md) or a format-specific reader.

## Value

Integer scalar: the second dimension of `movie$inputs`. An unassigned
poll stream returns `NA_integer_` because the number of participating
players cannot be determined from its records.
