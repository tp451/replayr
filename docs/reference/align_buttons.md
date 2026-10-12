# Align compact controller matrices by stable button identity

Use this explicitly before comparing different controllers. Missing
controls are filled with `FALSE`, which makes an absent control
equivalent to an unpressed one for the subsequent analysis. This is a
modelling choice. For comparisons of game actions, map the aligned
controls to an action vocabulary instead of assuming the same physical
button has the same role.

## Usage

``` r
align_buttons(movies, ids = NULL, idx = 1L)
```

## Arguments

- movies:

  Nonempty list of [replayr_movie](replayr_movie.md) objects.

- ids:

  Numeric or character IDs from [`button_layout()`](button_layout.md) to
  retain, in output order. Defaults to the union of controls present in
  the movies, with registered controls first. Controls outside this
  selection are omitted deliberately.

- idx:

  One-based player index, used for every movie.

## Value

List of logical matrices with matching columns and stable ID metadata.

## Examples

``` r
paths <- system.file("extdata", c("sample.fm2", "sample.smv"), package = "replayr")
movies <- lapply(paths, read_movie)
aligned <- align_buttons(movies)
vapply(aligned, ncol, integer(1))
#> [1] 12 12
```
