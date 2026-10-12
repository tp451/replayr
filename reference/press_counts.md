# Held-observation counts per control

Held-observation counts per control

## Usage

``` r
press_counts(movie, idx = 1L)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md) or
  [replayr_poll_stream](replayr_poll_stream.md) returned by
  [`read_movie()`](read_movie.md) or a format-specific reader.

- idx:

  Player index, 1-based.

## Value

Named integer vector of length `n_buttons(movie)`. Names are the control
display names. Counts give the observations held, rather than the number
of off-to-on transitions.
