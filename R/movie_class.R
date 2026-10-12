#' Number of observations in an imported recording
#'
#' Rows represent the source format's observations: video frames, controller
#' polls, timestamped input events, or game tics. With an explicit multi-controller polling order, each
#' row is one cycle through that order. Header video-frame counts remain in
#' the recording metadata.
#'
#' @param movie A [replayr_movie] or [replayr_poll_stream] returned by
#'   [read_movie()] or a format-specific reader.
#' @return Integer scalar: the first dimension of `movie$inputs`.
#' @export
n_frames <- function(movie) {
  stopifnot(.is_recording(movie))
  as.integer(dim(movie$inputs)[1])
}
#' Number of assigned input streams
#'
#' Keyboard and mouse controls can share a stream. The format-specific header
#' describes device grouping; a stream is not evidence of a distinct person.
#' @inheritParams n_frames
#' @return Integer scalar: the second dimension of `movie$inputs`.
#'   An unassigned poll stream returns `NA_integer_` because the number of
#'   participating players cannot be determined from its records.
#' @export
n_players <- function(movie) {
  stopifnot(.is_recording(movie))
  if (inherits(movie, "replayr_poll_stream")) return(NA_integer_)
  as.integer(dim(movie$inputs)[2])
}
#' Number of compact controller columns
#'
#' Use [button_layout()] to map these columns to stable controller IDs.
#'
#' @inheritParams n_frames
#' @return Integer scalar.
#' @export
n_buttons <- function(movie) {
  stopifnot(.is_recording(movie))
  as.integer(dim(movie$inputs)[3])
}
#' Button states for one controller
#'
#' @inheritParams n_frames
#' @param idx Player index, 1-based. Defaults to 1 (player 1).
#' @return Logical matrix, `n_frames(movie)` rows by `n_buttons(movie)`
#'   columns. Column names are the mnemonics from [button_layout()].
#' @export
#' @examples
#'   path <- system.file("extdata", "sample.fm2", package = "replayr")
#'   mv <- read_movie(path)
#'   p1 <- player(mv)
#'   colSums(p1)        # number of frames each button was held
player <- function(movie, idx = 1L) {
  stopifnot(.is_recording(movie))
  if (inherits(movie, "replayr_poll_stream")) {
    stop("This recording contains unassigned or device-specific polls; use polls() to inspect the ordered stream.", call. = FALSE)
  }
  if (!is.numeric(idx) || length(idx) != 1L || is.na(idx) || !is.finite(idx) ||
    idx != floor(idx) || idx < 1L || idx > n_players(movie)) {
    stop("idx must identify one player by its one-based integer index.", call. = FALSE)
  }
  m <- movie$inputs[, idx, , drop = TRUE]
  if (is.null(dim(m))) {
    # n_frames == 0 or n_buttons == 1 collapse case -- re-shape.
    m <- matrix(m, nrow = n_frames(movie), ncol = n_buttons(movie))
  }
  colnames(m) <- movie$button_mnemonics
  attr(m, "button_ids") <- movie$button_ids
  attr(m, "button_keys") <- movie$button_keys
  attr(m, "button_names") <- movie$button_names
  m
}
#' Held-observation counts per control
#'
#' @inheritParams n_frames
#' @param idx Player index, 1-based.
#' @return Named integer vector of length `n_buttons(movie)`. Names are
#'   the control display names. Counts give the observations held, rather than
#'   the number of off-to-on transitions.
#' @export
press_counts <- function(movie, idx = 1L) {
  m <- player(movie, idx)
  out <- as.integer(colSums(m))
  names(out) <- movie$button_names
  out
}
#' @export
format.replayr_movie <- function(x, ...) {
  fmt <- x$header[["_format"]]
  if (is.null(fmt)) fmt <- "fm2"
  sprintf(
    "<replayr_movie [%s] observations=%d players=%d buttons=%d source=%s>",
    fmt, n_frames(x), n_players(x), n_buttons(x),
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
  if (n_frames(x) > 0L) {
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
