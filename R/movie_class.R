#' Number of observations in an imported recording
#'
#' Rows represent the source format's observations: video frames, controller
#' polls, timestamped input events, or game tics; [observation_unit()] names
#' the unit of a recording. With an explicit multi-controller polling order,
#' each row is one cycle through that order. Header video-frame counts remain
#' in the recording metadata.
#'
#' @param movie A [replayr_movie] or [replayr_poll_stream] returned by
#'   [read_movie()] or a format-specific reader.
#' @return Integer scalar: the first dimension of `movie$inputs`.
#' @export
#' @examples
#' frames <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' n_observations(frames)
#' observation_unit(frames)
#' # The rows of an M64 file are controller polls; its header counts the frames.
#' polls <- read_movie(system.file("extdata", "sample.m64", package = "replayr"))
#' n_observations(polls)
#' observation_unit(polls)
n_observations <- function(movie) {
  stopifnot(.is_recording(movie))
  as.integer(dim(movie$inputs)[1])
}
#' Number of assigned input streams
#'
#' Keyboard and mouse controls can share a stream. The format-specific header
#' describes device grouping; a stream is not evidence of a distinct person.
#' @inheritParams n_observations
#' @return Integer scalar: the second dimension of `movie$inputs`.
#'   An unassigned poll stream returns `NA_integer_` because the number of
#'   participating players cannot be determined from its records.
#' @export
#' @examples
#' movie <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' n_players(movie)
#' # Polls of two controllers without a known order have no number of players.
#' stream <- read_movie(system.file("extdata", "paper", "unassigned.dtm", package = "replayr"))
#' n_players(stream)
n_players <- function(movie) {
  stopifnot(.is_recording(movie))
  if (inherits(movie, "replayr_poll_stream")) return(NA_integer_)
  as.integer(dim(movie$inputs)[2])
}
#' Number of compact controller columns
#'
#' Use [button_layout()] to map these columns to stable controller IDs.
#'
#' @inheritParams n_observations
#' @return Integer scalar.
#' @export
#' @examples
#' path <- system.file("extdata", "sample.m64", package = "replayr")
#' n_buttons(read_movie(path))
#' # Stick directions selected with `analog` are further columns.
#' n_buttons(read_movie(path, analog = "cardinal8"))
n_buttons <- function(movie) {
  stopifnot(.is_recording(movie))
  as.integer(dim(movie$inputs)[3])
}
#' Unit of observation of an imported recording
#'
#' Names what one row of a recording stands for. Most formats store one row
#' per video frame. Others store controller polls, timestamped events, game
#' tics, or several input samples within a frame. [n_observations()] counts rows
#' whatever their unit, so durations and rates also need this unit and the
#' timing information of the recording.
#'
#' @inheritParams n_observations
#' @return A character string: `"frame"`, `"scripted frame"`,
#'   `"input subframe"`, `"controller poll"`, `"controller polling cycle"`,
#'   `"Wii Remote poll"`, `"device poll"`, `"event"`, `"game tic"` or
#'   `"game update"`.
#' @examples
#' frames <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' observation_unit(frames)
#' polls <- read_movie(system.file("extdata", "sample.m64", package = "replayr"))
#' observation_unit(polls)
#' @export
observation_unit <- function(movie) {
  stopifnot(.is_recording(movie))
  # Readers of formats with another unit name it in the header; a recording
  # without such an entry has one row per video frame.
  unit <- movie$header$observationUnit %||% movie$header$observation_unit %||% "frame"
  gsub("_", " ", as.character(unit)[1L], fixed = TRUE)
}
#' Button states for one controller
#'
#' @inheritParams n_observations
#' @param idx Player index, 1-based. Defaults to 1 (player 1).
#' @return Logical matrix, `n_observations(movie)` rows by `n_buttons(movie)`
#'   columns. Columns are named by the control keys of [button_layout()], as
#'   in [press_counts()], [align_buttons()] and [polls()], so that
#'   `player(movie)[, "a"]` is the A button in every recording. The attributes
#'   `button_ids` and `button_names` hold the IDs and the labels of the
#'   columns; [button_layout()] has the whole layout.
#' @export
#' @examples
#'   path <- system.file("extdata", "sample.fm2", package = "replayr")
#'   mv <- read_movie(path)
#'   p1 <- player(mv)
#'   colSums(p1)        # number of frames each button was held
player <- function(movie, idx = 1L) {
  stopifnot(.is_recording(movie))
  if (inherits(movie, "replayr_poll_stream")) {
    stop("This recording contains unassigned or device-specific polls; use polls() to inspect the ordered stream.",
      call. = FALSE)
  }
  if (!is.numeric(idx) || length(idx) != 1L || is.na(idx) || !is.finite(idx) ||
    idx != floor(idx) || idx < 1L || idx > n_players(movie)) {
    stop("idx must identify one player by its one-based integer index.", call. = FALSE)
  }
  m <- movie$inputs[, idx, , drop = TRUE]
  if (is.null(dim(m))) {
    # n_frames == 0 or n_buttons == 1 collapse case -- re-shape.
    m <- matrix(m, nrow = n_observations(movie), ncol = n_buttons(movie))
  }
  colnames(m) <- movie$button_keys
  attr(m, "button_ids") <- movie$button_ids
  attr(m, "button_names") <- movie$button_names
  m
}
#' Held-observation counts per control
#'
#' @inheritParams n_observations
#' @param idx Player index, 1-based.
#' @return Named integer vector of length `n_buttons(movie)`. Names are
#'   the control keys of [button_layout()], as for the columns of [player()].
#'   Counts give the observations held, rather than the number of off-to-on
#'   transitions.
#' @export
#' @seealso [`summary()`][summary.replayr_movie] for the number of activations.
#' @examples
#' movie <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' press_counts(movie)
#' # As a share of the recording, for the second controller.
#' round(press_counts(movie, 2L) / n_observations(movie), 3)
press_counts <- function(movie, idx = 1L) {
  m <- player(movie, idx)
  out <- as.integer(colSums(m))
  names(out) <- colnames(m)
  out
}
#' @export
format.replayr_movie <- function(x, ...) {
  fmt <- x$header[["_format"]]
  if (is.null(fmt)) fmt <- "fm2"
  sprintf(
    "<replayr_movie [%s] observations=%d players=%d buttons=%d source=%s>",
    fmt, n_observations(x), n_players(x), n_buttons(x),
    if (is.na(x$source_path)) "<in-memory>" else basename(x$source_path)
  )
}
#' @export
print.replayr_movie <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  if (length(x$header) > 0) {
    keys <- names(x$header)
    keys <- keys[keys != "_format"]
    if (length(keys) > 0) {
      cat("Header keys: ", paste(keys[seq_len(min(8L, length(keys)))],
        collapse = ", "
      ),
      if (length(keys) > 8L) ", ..." else "",
      "\n",
      sep = ""
      )
    }
  }
  if (n_observations(x) > 0L) {
    pc <- press_counts(x, 1L)
    pc <- pc[pc > 0L]
    if (length(pc) > 0L) {
      cat("P1 active observations: ",
        paste(sprintf("%s=%d", names(pc), pc), collapse = ", "),
        "\n",
        sep = ""
      )
    }
  }
  invisible(x)
}
