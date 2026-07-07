# Number of frames in a parsed movie

Number of frames in a parsed movie

## Usage

``` r
n_frames(movie)
```

## Arguments

- movie:

  A
  [replayr_movie](https://tp451.github.io/replayr/reference/replayr_movie.md)
  (returned by
  [`read_movie()`](https://tp451.github.io/replayr/reference/read_movie.md)
  or any of the format-specific readers).

## Value

Integer scalar: the first dimension of `movie$inputs`.
