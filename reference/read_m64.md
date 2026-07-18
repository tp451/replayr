# Read a Mupen64 .m64 movie file

The N64 controller has 14 buttons + an analog stick. Buttons map onto
universal slots 1..14 (with C-buttons at 17..20); the analog stick is
quantised to 8 directions and routed to slots 21..28. Output is 28
buttons wide. Stick deflections below ~12.5% magnitude are treated as
neutral. Multi-controller M64 streams are rejected because the format
does not store controller identifiers: samples occur in the order the
game polls its connected controllers, which cannot be reconstructed
reliably without running the game.

## Usage

``` r
read_m64(path)
```

## Arguments

- path:

  Path to a .m64 file.

## Value

A `replayr_movie` object.
