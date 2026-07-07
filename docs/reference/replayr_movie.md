# The `replayr_movie` S3 class

The canonical return type of every reader in `replayr`. A
`replayr_movie` is a list with the following elements:

## Details

- `header`:

  Named list of header key-value pairs lifted from the source file. The
  synthetic `_format` entry records which parser produced the movie (one
  of `"fm2"`, `"bk2"`, `"fcm"`, `"lsmv"`, `"gmv"`, `"vbm"`, `"m64"`,
  `"smv"`, `"pxm"`, `"pjm"`, `"dtm"`).

- `commands`:

  Integer vector of length `n_frames`. Per-frame commands byte (Reset,
  Power, format-specific bits). Most TAS frames are 0.

- `inputs`:

  Logical 3D array, dimensions `(n_frames, n_players, n_buttons)`.
  `TRUE` means the button was held that frame.

- `source_path`:

  Path the movie was loaded from, or `NA`.

- `button_mnemonics`:

  Character vector. One single-character mnemonic per third-dimension
  slot of `inputs`.

- `button_names`:

  Character vector. Friendly labels paired with `button_mnemonics`.

Use
[`n_frames()`](https://tp451.github.io/replayr/reference/n_frames.md),
[`n_players()`](https://tp451.github.io/replayr/reference/n_players.md),
[`n_buttons()`](https://tp451.github.io/replayr/reference/n_buttons.md)
to read the array shape;
[`player()`](https://tp451.github.io/replayr/reference/player.md) to
extract one player's frames as a 2D matrix;
[`press_counts()`](https://tp451.github.io/replayr/reference/press_counts.md)
to summarise hold-counts per button.

## See also

[`read_movie()`](https://tp451.github.io/replayr/reference/read_movie.md),
[`universal_buttons()`](https://tp451.github.io/replayr/reference/universal_buttons.md)
