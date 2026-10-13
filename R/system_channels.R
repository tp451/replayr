# The controls of a console or cabinet are named by key, as buttons and
# numeric channels are: the name of the source in lower case with
# underscores, without the prefix that only says where it comes from. Where
# formats write one control differently, it has one key in all of them.
.SHARED_SYSTEM_KEYS <- c(
  # the lid of a DS, as BizHawk writes its two controls
  lidopen = "lid_open", lidclose = "lid_close",
  # MAME numbers its service buttons without a separator
  service1 = "service_1", service2 = "service_2", service3 = "service_3", service4 = "service_4",
  # the coin slots of the VS. System are coin slots
  `vs coin 1` = "coin_1", `vs coin 2` = "coin_2",
  # the start buttons of a cabinet
  `1 player start` = "p1_start", `2 players start` = "p2_start",
  `3 players start` = "p3_start", `4 players start` = "p4_start",
  start1 = "p1_start", start2 = "p2_start", start3 = "p3_start", start4 = "p4_start"
)
.system_keys <- function(names) {
  if (!length(names)) return(character())
  slug <- function(x) gsub("^_+|_+$", "", gsub("[^a-z0-9]+", "_", x))
  lower <- tolower(trimws(names))
  # MAME-rr marks cabinet inputs with a prefix, BizHawk the console of a
  # linked pair with its number.
  plain <- sub("^p[0-9]+ +", "", sub("^input_", "", lower))
  shared <- unname(.SHARED_SYSTEM_KEYS[plain])
  keys <- ifelse(is.na(shared), slug(plain), shared)
  # Two controls of one recording never share a key: each keeps its own name.
  clash <- keys %in% keys[duplicated(keys)]
  keys[clash] <- slug(lower[clash])
  make.unique(keys, sep = "_")
}
# Readers name system controls after their format; the keys are assigned
# once a movie is otherwise complete.
.name_system <- function(movie) {
  if (is.null(movie$system_inputs) || !ncol(movie$system_inputs) || !is.null(movie$system_source)) return(movie)
  movie$system_source <- names(movie$system_inputs)
  names(movie$system_inputs) <- .system_keys(movie$system_source)
  movie
}
#' Controls of the console or cabinet
#'
#' Returns the controls that belong to the machine and not to a player's
#' controller: reset and power, coin slots and service buttons, disc and tape
#' controls, the lid of a handheld, and numeric settings such as a selected
#' disc. They never take a column in a player's button layout.
#'
#' Columns are named by key, as in [player()] and [analog_channels()]: the
#' name of the source in lower case with underscores, so that `reset`,
#' `power`, `pause` and `coin_1` are the same column in every format that
#' records them. [system_layout()] gives the label each column has in the
#' recording.
#'
#' @param movie A [replayr_movie].
#' @return Data frame with one row per observation; zero columns for formats
#'   without separately decoded controls of the system.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.bk2", package = "replayr")
#' head(system_channels(read_movie(path)))
system_channels <- function(movie) {
  stopifnot(.is_recording(movie))
  if (is.null(movie$system_inputs)) return(data.frame(row.names = seq_len(n_observations(movie))))
  movie$system_inputs
}
#' Names of the controls of the console or cabinet
#'
#' @inheritParams system_channels
#' @return Data frame with one row for each column of [system_channels()]:
#'   `column`, `key` (the column name) and `name` (the label of the recording
#'   or of its format).
#' @export
#' @examples
#' path <- system.file("extdata", "sample.bk2", package = "replayr")
#' system_layout(read_movie(path))
system_layout <- function(movie) {
  keys <- names(system_channels(movie))
  source <- movie$system_source
  if (length(source) != length(keys)) source <- keys
  data.frame(column = seq_along(keys), key = keys, name = source, stringsAsFactors = FALSE)
}
