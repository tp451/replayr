# replayr: parsers for emulator movie ("input log") files

Readers for emulator input recordings used in tool-assisted
speedrunning. S3 outputs contain compact logical controller states,
stable control identities, source numeric channels, metadata, and
commands. Rows follow each format's frames, controller polls,
timestamped events, or game tics. Unassigned controller ports and
heterogeneous device observations use a
[replayr_poll_stream](replayr_poll_stream.md).
[`read_movie()`](read_movie.md) dispatches to the appropriate reader.
[`movie_members()`](movie_members.md) lists movies in a downloaded ZIP
archive.

## Quick start


      library(replayr)
      path <- system.file("extdata", "sample.fm2", package = "replayr")
      mv <- read_movie(path)
      n_frames(mv)                       # observation count
      press_counts(mv)                   # per-button active-observation counts
      p1 <- player(mv, 1L)               # logical matrix, observations x controls

## Controller layout

Each movie uses compact columns. [`button_layout()`](button_layout.md)
maps local columns to stable control identities. Use
[`align_buttons()`](align_buttons.md) for an explicit common matrix
layout across controllers. Original numeric values are returned by
[`analog_channels()`](analog_channels.md); selected stick
representations by [`stick_channels()`](stick_channels.md). BK2 N64
Boolean stick overrides are retained in `movie$stick_overrides` (right,
up, left, down per player) and applied using the recording's BizHawk
version when computing stick angles and directions.

## Author

**Maintainer**: Thorben Pelzer <thorben@pelzer.blog>

Authors:

- Thorben Pelzer <thorben@pelzer.blog>
