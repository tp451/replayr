#' replayr: readers for input recordings and demo files of video games
#'
#' Readers for the input recordings and demo files made in tool-assisted
#' speedrunning, reinforcement learning, and research on human-game
#' interaction.
#' S3 outputs contain compact logical controller states, stable control identities,
#' source numeric channels, metadata, and commands. Rows follow each format's
#' frames, controller polls, timestamped events, or game tics.
#' Unassigned controller ports and heterogeneous device observations use a
#' [replayr_poll_stream]. [read_movie()] dispatches to the appropriate reader.
#' [movie_members()] lists movies in a downloaded ZIP archive.
#'
#' @section Controller layout:
#' Each movie uses compact columns. [button_layout()] maps local columns to
#' stable control identities. Use [align_buttons()] for an explicit common
#' matrix layout across controllers. Original numeric values are returned by
#' [analog_channels()], under the keys that [channel_layout()] lists; selected
#' stick representations by [stick_channels()].
#' BK2 N64 Boolean stick overrides are retained in `movie$stick_overrides`
#' (right, up, left, down per player) and applied using the recording's
#' BizHawk version when computing stick angles and directions.
#'
#' @examples
#' path <- system.file("extdata", "sample.fm2", package = "replayr")
#' movie <- read_movie(path)
#' movie
#' summary(movie)
#' recording_info(movie)
#' # Button states of the first controller: observations by controls.
#' states <- player(movie, 1L)
#' dim(states)
#' @importFrom utils head tail
#' @keywords internal
"_PACKAGE"
