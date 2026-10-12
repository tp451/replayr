# Ordered controller and device polls

Multi-controller M64 and DTM files store ordered samples without
per-sample port IDs. The S3 class `replayr_poll_stream` retains the
decoded controls and original bytes. [`polls()`](polls.md) returns one
row per poll, with `port = NA_integer_`, digital controls, source
numeric channels, selected stick fields, and command bits. DTM and CTM
streams also expose format-specific poll flags.
[`button_layout()`](button_layout.md) maps digital keys to stable IDs.
[`analog_channels()`](analog_channels.md) and
[`stick_channels()`](stick_channels.md) select the single stored stream
with `idx = 1`.

## Details

[`n_frames()`](n_frames.md) counts polls; [`n_players()`](n_players.md)
returns `NA_integer_`. [`player()`](player.md) requires an assigned
controller and therefore directs callers to [`polls()`](polls.md). If
emulator evidence establishes a repeating polling order, supply
`controller_order` to [`read_m64()`](read_m64.md) or
[`read_dtm()`](read_dtm.md) to construct a
[replayr_movie](replayr_movie.md). The format-specific help explains how
player indices map to physical controller ports.

CTM stores separate pad, touch, and auxiliary-device events. Its
observation flags identify which controls were sampled;
`observed_inputs` provides the per-control mask. Mixed DTM adds device
family and physical port when known. Wii reports marked
`valid_report = FALSE` preserve missing source payloads.

## See also

read_m64, read_dtm
