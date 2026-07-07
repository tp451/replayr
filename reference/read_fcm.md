# Read a FCEU .fcm movie file

Parses the binary delta-encoded body into the standard `replayr_movie`
shape. Output is 4 player slots x 8 button slots wide; nearly all FCM
publications use only player 1 but the format reserves four ports.

## Usage

``` r
read_fcm(path)
```

## Arguments

- path:

  Path to a .fcm file.

## Value

A `replayr_movie` object.
