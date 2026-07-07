# Per-frame button presses for one player

Per-frame button presses for one player

## Usage

``` r
player(movie, idx = 1L)
```

## Arguments

- movie:

  A
  [replayr_movie](https://tp451.github.io/replayr/reference/replayr_movie.md)
  (returned by
  [`read_movie()`](https://tp451.github.io/replayr/reference/read_movie.md)
  or any of the format-specific readers).

- idx:

  Player index, 1-based. Defaults to 1 (player 1).

## Value

Logical matrix, `n_frames(movie)` rows by `n_buttons(movie)` columns.
Column names are the universal-button mnemonics.

## Examples

``` r
if (FALSE) { # \dontrun{
  mv <- read_movie("data/raw_nes/super_mario_bros/1349.fm2")
  p1 <- player(mv)
  colSums(p1)        # number of frames each button was held
} # }
```
