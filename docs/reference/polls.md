# Extract an unassigned controller-poll stream

Extract an unassigned controller-poll stream

## Usage

``` r
polls(x)
```

## Arguments

- x:

  A [replayr_poll_stream](replayr_poll_stream.md).

## Value

Data frame in source order. Digital column names use stable control
keys. For M64, `commands` uses bit 0 for reset. For DTM, bit 0 is disc
change and bit 1 is reset. Standard DTM exposes `is_connected` and
`get_origin`; Zelda Edition exposes `loading`, `tuner_event`, `link_x`,
and `link_z` (see [`read_dtm()`](read_dtm.md)). The object's
`poll_bytes` component contains four original bytes per M64 poll, eight
per standard DTM poll, or seventeen per Zelda Edition poll, in source
order. CTM stores seven bytes per device event. Wii stores padded report
bytes with `poll_lengths`; mixed HID records include the length byte.
`source_tail` retains incomplete final Wii records. Use observation
flags before analysing device-specific fields.
