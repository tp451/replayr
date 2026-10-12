# List input recordings in a ZIP archive

Some published downloads contain several recordings. Inspect their
member names, then pass one as `member` to
[`read_movie()`](read_movie.md). ZIP-based emulator formats such as BK2
use their normal extension and format-specific reader.

## Usage

``` r
movie_members(path)
```

## Arguments

- path:

  ZIP archive path.

## Value

Data frame with member, format, and uncompressed byte count.
