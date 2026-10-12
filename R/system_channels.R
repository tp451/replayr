#' Global emulator and cabinet controls
#'
#' Returns named global BK2 controls separately from player input. Numeric
#' channels include disk selection and cabinet dials; Boolean channels include
#' reset, coins and service controls. Original LogKey names and source units are
#' retained. These controls never create gaps in a player's button layout.
#'
#' @param movie A [replayr_movie].
#' @return Data frame with one row per observation; zero columns for formats
#'   without separately decoded global controls.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.bk2", package = "replayr")
#' head(system_channels(read_movie(path)))
system_channels <- function(movie) {
  stopifnot(.is_recording(movie))
  if (is.null(movie$system_inputs)) return(data.frame(row.names = seq_len(n_frames(movie))))
  movie$system_inputs
}
