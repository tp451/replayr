#' The `replayr_movie` S3 class
#'
#' The canonical return type of every reader in `replayr`. A
#' `replayr_movie` is a list with the following elements:
#'
#' \describe{
#'   \item{`header`}{Named list of header key-value pairs lifted from
#'     the source file. The synthetic `_format` entry records which
#'     parser produced the movie (one of `"fm2"`, `"bk2"`, `"fcm"`,
#'     `"lsmv"`, `"gmv"`, `"vbm"`, `"m64"`, `"smv"`, `"pxm"`, `"pjm"`,
#'     `"dtm"`).}
#'   \item{`commands`}{Integer vector of length `n_frames`. Per-frame
#'     commands byte (Reset, Power, format-specific bits). Most TAS
#'     frames are 0.}
#'   \item{`inputs`}{Logical 3D array, dimensions
#'     `(n_frames, n_players, n_buttons)`. `TRUE` means the button was
#'     held that frame.}
#'   \item{`source_path`}{Path the movie was loaded from, or `NA`.}
#'   \item{`button_mnemonics`}{Character vector. One single-character
#'     mnemonic per third-dimension slot of `inputs`.}
#'   \item{`button_names`}{Character vector. Friendly labels paired
#'     with `button_mnemonics`.}
#' }
#'
#' Use [n_frames()], [n_players()], [n_buttons()] to read the array
#' shape; [player()] to extract one player's frames as a 2D matrix;
#' [press_counts()] to summarise hold-counts per button.
#'
#' @name replayr_movie
#' @seealso [read_movie()], [universal_buttons()]
NULL
