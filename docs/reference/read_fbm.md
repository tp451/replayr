# Read a FinalBurn Alpha recording

Imports FinalBurn Alpha FBM input streams using an explicit game input
layout. FBM stores values in driver order, so the recording must be
paired with a verified ROM identifier or an ordered schema. Bundled game
layouts cite their driver sources in `extdata/fbm-layouts.json`.

## Usage

``` r
read_fbm(
  path,
  analog = "raw",
  deadzone = NULL,
  triggers = "raw",
  game = NULL,
  input_schema = NULL,
  ...
)
```

## Arguments

- path:

  Recording file path.

- analog:

  Stick representation: `"raw"` (default), `"cardinal4"`, `"cardinal8"`,
  `"angle"`, or `"angle+magnitude"`. A scalar applies to both sticks;
  `c(left = "cardinal8", right = "angle")` selects them independently.
  Cardinal modes add separate left/right logical direction columns.
  Continuous modes return numeric fields through
  [`stick_channels()`](stick_channels.md). Original X/Y values remain in
  [`analog_channels()`](analog_channels.md) in every mode. Absent sticks
  add no columns.

- deadzone:

  Radial threshold in centred axis half-range units, from zero to one.
  One value applies to both sticks; named left/right values are allowed.
  `NULL` uses format defaults: 0.25 for BK2/PSX, 0.125 for M64/DTM.
  Neutral observations have no direction and an `NA` angle. Magnitude is
  kept.

- triggers:

  `"raw"` (default) or `"digital"`. For DTM, digital additionally
  projects each analogue trigger at 128/255 into separate L2/R2 columns.
  Hardware L/R click bits remain distinct from thresholded analogue
  triggers.

- game:

  A verified ROM identifier matching a bundled input layout, such as
  `"ghouls"`. Supply either `game` or `input_schema`.

- input_schema:

  An ordered schema with a `source` reference and a `fields` list. Each
  field gives `key`, `player` (zero for system inputs), `type`
  (`"button"`, `"byte"`, or `"analog"`), and an optional display `name`.
  Optional `button_encoding` is `"binary"` (default), `"bit0"`, or
  `"nonzero"`, according to the driver's interpretation of the byte.
  Field order must match the emulator driver exactly.

- ...:

  Reader-specific arguments, such as `controller_order` for M64 or DTM,
  or `member` for a recording inside a ZIP archive (see
  [`movie_members()`](movie_members.md)).

## Value

A [replayr_movie](replayr_movie.md) with compact controls and the input
schema.

## Details

[`player()`](player.md) returns game controls,
[`analog_channels()`](analog_channels.md) retains numeric player inputs,
and [`system_channels()`](system_channels.md) returns cabinet and system
inputs. It also retains every raw field under `raw_pN_key` or
`raw_system_key`, including source bytes whose button interpretation
uses only bit zero. Rows follow the stored frame order. The header
retains the frame count, rerecord count, source flags, and input-schema
reference.

## Examples

``` r
path <- system.file("extdata", "expanded", "synthetic-arcade.fbm",
                    package = "replayr")
movie <- read_fbm(path, game = "ghouls")
press_counts(movie)
#> Right  Left  Down    Up Start  Fire  Jump 
#>   120    12     0     0     2    12    28 
```
