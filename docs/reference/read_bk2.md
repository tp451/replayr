# Read a BizHawk .bk2 movie file

.bk2 is a ZIP archive whose `Input Log.txt` describes inputs and whose
`Header.txt` carries metadata (Author, Core, Platform, GameName, SHA1,
...). The parser uses the LogKey line to map column positions to
universal-button slots, supporting NES, SNES, Atari 2600, Game Boy / GBC
/ GBA, N64, PSX in one pass. Without a LogKey it falls back to NES
positional UDLRTSBA mapping.

## Usage

``` r
read_bk2(path)
```

## Arguments

- path:

  Path to a .bk2 file.

## Value

A `replayr_movie` object.

## Details

Analog-stick columns (N64 / PSX) are quantised to 8 directions onto
slots 21..28; the c-stick / right stick goes onto slots 17..20.
