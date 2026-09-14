# Read a PCSX-rerecording .pxm movie file

Reads standard digital and analog-controller PXM movies. Button input
maps to the 32-slot PSX universal layout, including L3/R3 on analog
devices. Standard digital pad reserved bits are counted in header
metadata, not interpreted as stick-click buttons. Analog sticks are
quantised in the same way as other replayr PSX readers. The final
per-frame control byte is exposed through `movie$commands`. Mouse,
NegCon, and light-gun controller types are rejected instead of being
silently mis-decoded.

## Usage

``` r
read_pxm(path)
```

## Arguments

- path:

  Path to a .pxm file.

## Value

A `replayr_movie` object.
