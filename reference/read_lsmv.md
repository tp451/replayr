# Read an lsnes .lsmv movie file

.lsmv is a ZIP archive containing an `input` text member plus various
metadata members (gametype, controlsversion, coreversion, systemid,
rom.sha256, projectid, rerecords, ...). Currently supports the SNES
standard gamepad (12-char masks; 16-char with the lsnes 4-col extension
suffix) and Game Boy / GBC (8-char masks via libgambatte). Other port
types (mouse, superscope, justifier) raise an error for now.

## Usage

``` r
read_lsmv(path)
```

## Arguments

- path:

  Path to an .lsmv file.

## Value

A `replayr_movie` object.

## Details

Super Game Boy recordings (gametype starting with `gambatte_sgb`) carry
a 12-char SNES-shaped mask but only ever fire the first eight positions
– they're folded down to the GB shape (8 buttons) so SGB and GB pubs
share a single in-memory width.
