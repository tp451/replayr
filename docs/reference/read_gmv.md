# Read a Gens-rerecording .gmv movie file

Genesis controllers map onto universal slots 1..4 (d-pad), 5 (Start),
7/8 (B/A; Genesis has no Select), 9/10 (X/Y), 13 (C), 14 (Z), 15 (Mode).
Output is 15 buttons wide so every Genesis-relevant column sits at its
canonical universal slot.

## Usage

``` r
read_gmv(path)
```

## Arguments

- path:

  Path to a .gmv file.

## Value

A `replayr_movie` object.
