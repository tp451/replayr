# Number of universal-button slots in a parsed movie

Varies per platform: 8 for NES / GB, 12 for SNES / GBA, 15 for Genesis,
28 for N64 / GameCube, 30 for PSX. Slots are always a prefix of the
[`universal_buttons()`](https://tp451.github.io/replayr/reference/universal_buttons.md)
alphabet.

## Usage

``` r
n_buttons(movie)
```

## Arguments

- movie:

  A
  [replayr_movie](https://tp451.github.io/replayr/reference/replayr_movie.md)
  (returned by
  [`read_movie()`](https://tp451.github.io/replayr/reference/read_movie.md)
  or any of the format-specific readers).

## Value

Integer scalar.
