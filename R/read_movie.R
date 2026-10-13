#' Import an emulator input recording
#'
#' Dispatches by extension to the format-specific reader. Every reader returns
#' compact digital columns, a stable cross-controller ID map, and original numeric
#' channels. A row may be a frame, poll, input event, or tic depending on the format.
#'
#' The extension decides the reader. A file under another extension, or under
#' none, is recognised by its content where its format has a signature: the
#' first bytes of most binary formats, the `version 3` line of FCEUX, the
#' members of a BizHawk or lsnes archive, the header of a BizHawk text
#' movie or an openMSX replay, and the first line of a table of the Atari
#' Grand Challenge data set or of Atari-HEAD ([read_txt()]). These two
#' share the extension `.txt`, which says
#' too little by itself: a `.txt` file is read as what its content shows.
#' A file whose extension and signature disagree
#' is refused, with the format its content shows. `format` names the format
#' in every other case, for example for a Doom demo that is not called `.lmp`.
#'
#' @param path Recording file path.
#' @param analog Stick representation: `"raw"` (default), `"cardinal4"`,
#'   `"cardinal8"`, `"angle"`, or `"angle+magnitude"`. A scalar applies to both
#'   sticks; `c(left = "cardinal8", right = "angle")` selects them independently.
#'   Cardinal modes add separate left/right logical direction columns. Continuous
#'   modes return numeric fields through [stick_channels()]. Original X/Y values
#'   remain in [analog_channels()] in every mode. Absent sticks add no columns.
#' @param deadzone Radial threshold in centred axis half-range units, from zero
#'   to one. One value applies to both sticks; named left/right values are allowed.
#'   `NULL` uses the default of the controller, whichever emulator recorded
#'   it: 0.125 for the sticks of Nintendo's consoles (Nintendo 64, GameCube,
#'   Wii extensions, 3DS) and 0.25 for all other sticks. The first is close
#'   to the 15 of 128 units that the GameCube's controller library discards
#'   on each axis (`PAD_Clamp` in
#'   [libogc](https://github.com/devkitPro/libogc/blob/58ab796738292a60d4b7a937bc0707bd70f49366/libogc/pad.c)).
#'   The second covers the resting position of a released PlayStation stick,
#'   up to about 32 of 128 units from the centre
#'   ([psx-spx](https://psx-spx.consoledev.net/controllersandmemorycards/)),
#'   and is close to the 7849 and 8689 of 32767 that Microsoft gives for the
#'   thumbsticks of PC gamepads
#'   ([XInput](https://learn.microsoft.com/en-us/windows/win32/xinput/getting-started-with-xinput)).
#'   A game applies a threshold of its own, which the recording does not
#'   store; give that value to study one game.
#'   Neutral observations have no direction and an `NA` angle. Magnitude is kept.
#' @param triggers `"raw"` (default) or `"digital"`. For DTM, digital additionally
#'   projects each analogue trigger at 128/255 into separate L2/R2 columns.
#'   Hardware L/R click bits remain distinct from thresholded analogue triggers.
#' @param aliases `TRUE` (default) places the controls of a recording under
#'   the shared IDs that [button_layout()] describes. With `FALSE`, a control
#'   that would be placed under another control's ID keeps the key of its
#'   source, so every control of the recording has a column of its own and no
#'   two are combined.
#' @param format Format of the file, as one of the extensions of
#'   [supported_formats()] (`"fm2"` or `".fm2"`), or `"atari_gc"` or
#'   `"atari_head"` for a table of these data sets. The default `NULL` takes it
#'   from the extension of `path`, or from the content as described above.
#'   With `format`, a file called `.zip` is read as a recording of that
#'   format and not searched for recordings.
#' @param ... Reader-specific arguments, such as `controller_order` for M64 or DTM,
#'   or `member` for a recording inside a ZIP archive (see [movie_members()]).
#' @return A [replayr_movie], or a [replayr_poll_stream] for unassigned controller ports or
#'   heterogeneous device polls, as in CTM. Use [button_layout()] for column identities,
#'   [player()] for logical states, and [stick_channels()] for selected stick fields.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.m64", package = "replayr")
#' movie <- read_movie(path, analog = "angle+magnitude")
#' button_layout(movie)
#' head(stick_channels(movie))
#' # A recording under another name: an SNES movie is known by its signature,
#' # a Doom demo has none and is named.
#' copy <- tempfile(fileext = ".dat")
#' file.copy(system.file("extdata", "sample.smv", package = "replayr"), copy)
#' read_movie(copy)
#' file.copy(system.file("extdata", "sample.lmp", package = "replayr"), copy, overwrite = TRUE)
#' read_movie(copy, format = "lmp")
#' unlink(copy)
read_movie <- function(path, analog = "raw", deadzone = NULL, triggers = "raw", aliases = TRUE,
                       format = NULL, ...) {
  .check_recording_path(path)
  .stick_modes(analog)
  chosen <- .chosen_format(path, format)
  if (identical(chosen, "zip"))
    return(.read_movie_archive(path, analog, deadzone, triggers, aliases = aliases, ...))
  reader <- .format_reader(chosen)
  reader(path, analog = analog, deadzone = deadzone, triggers = triggers, aliases = aliases, ...)
}
#' Format of a recording file
#'
#' Says as which format [read_movie()] reads a file, without reading it: by
#' its extension, or by its content for a file under another extension and
#' for the extension `.txt`, which two formats share and many files that are
#' no recordings carry. Use it to pick the recordings out of a folder.
#'
#' @param path File paths.
#' @return Character vector with one entry per path: the format as the
#'   argument `format` of [read_movie()] takes it (an extension without its
#'   dot, or `"atari_gc"` or `"atari_head"`), and `NA` for a file that
#'   [read_movie()] does not read as a recording, for a folder and for a
#'   path that does not exist. A ZIP archive that holds recordings is no
#'   recording itself and gives `NA`; see [movie_members()].
#' @seealso [supported_formats()]
#' @export
#' @examples
#' files <- list.files(system.file("extdata", package = "replayr"), full.names = TRUE)
#' data.frame(file = basename(files), format = recording_format(files))
#' # Of the text files, the tables of the two Atari data sets are recordings.
#' texts <- list.files(system.file("extdata", package = "replayr"), "[.]txt$",
#'   recursive = TRUE, full.names = TRUE)
#' data.frame(file = basename(texts), format = recording_format(texts))
recording_format <- function(path) {
  if (!is.character(path)) stop("path must be a character vector of file paths.", call. = FALSE)
  vapply(path, function(file) {
    if (is.na(file) || !file.exists(file) || dir.exists(file)) return(NA_character_)
    chosen <- tryCatch(.chosen_format(file), error = function(e) NA_character_)
    if (identical(chosen, "zip")) NA_character_ else chosen
  }, character(1), USE.NAMES = FALSE)
}
