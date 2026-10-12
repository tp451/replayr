# Button states for one controller

Button states for one controller

## Usage

``` r
player(movie, idx = 1L)
```

## Arguments

- movie:

  A [replayr_movie](replayr_movie.md) or
  [replayr_poll_stream](replayr_poll_stream.md) returned by
  [`read_movie()`](read_movie.md) or a format-specific reader.

- idx:

  Player index, 1-based. Defaults to 1 (player 1).

## Value

Logical matrix, `n_frames(movie)` rows by `n_buttons(movie)` columns.
Column names are the mnemonics from
[`button_layout()`](button_layout.md).

## Examples

``` r
if (FALSE) { # \dontrun{
  path <- system.file("extdata", "sample.fm2", package = "replayr")
  mv <- read_movie(path)
  p1 <- player(mv)
  colSums(p1)        # number of frames each button was held
} # }
```
