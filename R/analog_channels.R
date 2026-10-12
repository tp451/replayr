#' Numeric analogue channels for one player
#'
#' Returns the original numeric channels decoded from the recording. These
#' values are retained in every representation mode. No cross-platform
#' normalization is applied: M64 sticks use signed -128..127 values; PXM/PJM
#' sticks and DTM sticks/triggers use unsigned 0..255 values; BK2 keeps its
#' logged numeric values and LogKey column names, including sensors and paddles.
#' Doom channels are signed movement commands and the stored signed angle byte,
#' not physical device events. See the format-specific reader for interpretation.
#'
#' For an unassigned [replayr_poll_stream], `idx = 1` selects the single
#' stored stream.
#'
#' An absent analogue channel has no column. A missing BK2 numeric sample is
#' `NA`, rather than an invented neutral value. Row order matches [player()].
#'
#' @inheritParams player
#' @return Numeric matrix with one row per observation and named channels;
#'   zero columns for a player with no analogue channels.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.m64", package = "replayr")
#' movie <- read_movie(path)
#' head(analog_channels(movie))
#' projected <- read_movie(path, analog = "cardinal8")
#' identical(analog_channels(movie), analog_channels(projected))
analog_channels <- function(movie, idx = 1L) {
  stopifnot(.is_recording(movie))
  if (length(idx) != 1L || !is.numeric(idx) || is.na(idx) ||
      idx != as.integer(idx) || idx < 1L || idx > dim(movie$inputs)[2L]) {
    stop("idx must identify one player", call. = FALSE)
  }
  if (is.null(movie$analog)) return(.empty_analog(n_frames(movie), 1L)[[1L]])
  movie$analog[[as.integer(idx)]]
}
