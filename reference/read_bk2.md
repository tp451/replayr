# Read a BK2 recording

BizHawk ZIP movies. LogKey names determine digital controls and numeric
channels. Known N64 and PlayStation stick encodings can be transformed;
other numeric channels remain raw. Digital columns are compact;
[`button_layout()`](button_layout.md) gives their stable IDs. Numeric
source channels are always retained in
[`analog_channels()`](analog_channels.md). The full import defaults to a
256 MiB limit on the expanded input log to avoid large temporary
allocations. [`read_bk2_chunks()`](read_bk2_chunks.md) processes larger
recordings in bounded memory. The final movie and parsing buffers can
use substantially more memory than the text itself.

## Usage

``` r
read_bk2(
  path,
  analog = "raw",
  deadzone = NULL,
  triggers = "raw",
  max_input_bytes = 256 * 1024^2,
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

- max_input_bytes:

  Maximum expanded input-log size for a full import, in bytes. The
  default is `256 * 1024^2`. Increase this explicitly when sufficient
  memory is available, up to R's single-string limit of `2147483647`
  bytes. The limit is checked before extracting the input log.

- ...:

  Reader-specific arguments, such as `controller_order` for M64 or DTM,
  or `member` for a recording inside a ZIP archive (see
  [`movie_members()`](movie_members.md)).

## Value

A [replayr_movie](replayr_movie.md) with compact digital columns and
selected stick fields.
