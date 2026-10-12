# Number of observations in an imported recording

Rows represent the source format's observations: video frames,
controller polls, timestamped input events, or game tics. With an
explicit multi-controller polling order, each row is one cycle through
that order. Header video-frame counts remain in the recording metadata.

## Usage

``` r
n_frames(movie)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md) or
  [replayr_poll_stream](replayr_poll_stream.md) returned by
  [`read_movie()`](read_movie.md) or a format-specific reader.

## Value

Integer scalar: the first dimension of `movie$inputs`.
