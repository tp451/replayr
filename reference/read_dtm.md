# Read a Dolphin .dtm GameCube movie file

13 GC buttons map onto universal slots 1..14 alongside their NES/SNES
counterparts. The analog stick is quantised to 8 cardinal/intercardinal
directions (slots 21..28); the C-stick is quantised more coarsely onto
the four C-button slots (17..20). L/R analog triggers fire the
corresponding shoulder slot when pulled past 50%. Output is 28 buttons
wide. Wii-mode .dtm files raise an error.

## Usage

``` r
read_dtm(path)
```

## Arguments

- path:

  Path to a .dtm file.

## Value

A `replayr_movie` object.
