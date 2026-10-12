# The `replayr_movie` S3 class

An imported recording with assigned input streams. Recordings whose
polls have unassigned ports use
[replayr_poll_stream](replayr_poll_stream.md). A `replayr_movie` is a
list with the following elements:

## Details

- `header`:

  Named list of header key-value pairs lifted from the source file. The
  synthetic `_format` entry records which parser produced the movie,
  such as `"fm2"`, `"bk2"`, or `"ltm"`.

- `commands`:

  Integer vector of length `n_frames`. Per-observation emulator command
  bits, where the format uses them.

- `inputs`:

  Logical 3D array, dimensions `(n_frames, n_players, n_buttons)`.
  `TRUE` means the button was held at that observation.

- `analog`:

  List of numeric channel matrices, one per player. Rows align with
  `inputs`; channel names and units depend on the format.

- `analog_mode`:

  Selected representation label. Numeric source values are retained in
  every mode.

- `stick_modes`:

  Named left/right choices: `"raw"`, `"cardinal4"`, `"cardinal8"`,
  `"angle"`, or `"angle+magnitude"`.

- `button_ids`, `button_keys`, `layout_version`:

  Stable control identities and registry version for the compact input
  columns.

- `stick_values`:

  Selected numeric stick channels, one matrix per player; accessed with
  [`stick_channels()`](stick_channels.md).

- `source_path`:

  Path the movie was loaded from, or `NA`. ZIP imports also retain the
  selected `source_member`.

- `events`, `timing`, `input_events`:

  Where present, source-specific event records and timing. See the
  format-specific reader.

- `button_mnemonics`:

  Character vector. One mnemonic per third-dimension slot of `inputs`;
  source-defined controls may use multi-character labels.

- `button_names`:

  Character vector. Friendly labels paired with `button_mnemonics`.

Use [`n_frames()`](n_frames.md), [`n_players()`](n_players.md),
[`n_buttons()`](n_buttons.md) to read the array shape;
[`player()`](player.md) to extract one player's frames as a 2D matrix;
[`press_counts()`](press_counts.md) to summarise hold-counts per button.

## See also

[`read_movie()`](read_movie.md),
[`universal_buttons()`](universal_buttons.md)
