# Read any supported movie file by extension

Dispatches to the appropriate reader based on the file extension: .fm2
-\>
[`read_fm2()`](https://tp451.github.io/replayr/reference/read_fm2.md),
.bk2 -\>
[`read_bk2()`](https://tp451.github.io/replayr/reference/read_bk2.md),
.fcm -\>
[`read_fcm()`](https://tp451.github.io/replayr/reference/read_fcm.md),
.lsmv -\>
[`read_lsmv()`](https://tp451.github.io/replayr/reference/read_lsmv.md),
.gmv -\>
[`read_gmv()`](https://tp451.github.io/replayr/reference/read_gmv.md),
.vbm -\>
[`read_vbm()`](https://tp451.github.io/replayr/reference/read_vbm.md),
.m64 -\>
[`read_m64()`](https://tp451.github.io/replayr/reference/read_m64.md),
.smv -\>
[`read_smv()`](https://tp451.github.io/replayr/reference/read_smv.md),
.pxm -\>
[`read_pxm()`](https://tp451.github.io/replayr/reference/read_pxm.md),
.pjm -\>
[`read_pjm()`](https://tp451.github.io/replayr/reference/read_pjm.md),
.dtm -\>
[`read_dtm()`](https://tp451.github.io/replayr/reference/read_dtm.md),
.lmp -\>
[`read_lmp()`](https://tp451.github.io/replayr/reference/read_lmp.md).

## Usage

``` r
read_movie(path)
```

## Arguments

- path:

  Path to a movie file.

## Value

A `replayr_movie` object.

## Details

Returns a `replayr_movie` regardless of source format. The
`header[["_format"]]` field records which parser ran. The `inputs` array
is `(n_frames, n_players, n_buttons)`; `n_buttons` varies per platform
(8 NES, 12 SNES, 15 Genesis, 28 N64/GC, 30 PSX).

## See also

[`supported_formats()`](https://tp451.github.io/replayr/reference/supported_formats.md)
