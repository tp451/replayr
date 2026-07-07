# Press counts per universal-button slot

Press counts per universal-button slot

## Usage

``` r
press_counts(movie, idx = 1L)
```

## Arguments

- movie:

  A
  [replayr_movie](https://tp451.github.io/replayr/reference/replayr_movie.md)
  (returned by
  [`read_movie()`](https://tp451.github.io/replayr/reference/read_movie.md)
  or any of the format-specific readers).

- idx:

  Player index, 1-based.

## Value

Named integer vector of length `n_buttons(movie)`. Names are the
universal-button friendly labels.
