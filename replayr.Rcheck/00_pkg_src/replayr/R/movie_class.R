#' Number of frames in a parsed movie
#'
#' @param movie A [replayr_movie] (returned by [read_movie()] or any of the
#'   format-specific readers).
#' @return Integer scalar: the first dimension of `movie$inputs`.
#' @export
n_frames <- function(movie) {
  stopifnot(inherits(movie, "replayr_movie"))
  as.integer(dim(movie$inputs)[1])
}

#' Number of players (controller ports) in a parsed movie
#'
#' @inheritParams n_frames
#' @return Integer scalar: the second dimension of `movie$inputs`.
#' @export
n_players <- function(movie) {
  stopifnot(inherits(movie, "replayr_movie"))
  as.integer(dim(movie$inputs)[2])
}

#' Number of universal-button slots in a parsed movie
#'
#' Varies per platform: 8 for NES / GB, 12 for SNES / GBA, 15 for Genesis,
#' 28 for N64 / GameCube, 30 for PSX. Slots are always a prefix of the
#' [universal_buttons()] alphabet.
#'
#' @inheritParams n_frames
#' @return Integer scalar.
#' @export
n_buttons <- function(movie) {
  stopifnot(inherits(movie, "replayr_movie"))
  as.integer(dim(movie$inputs)[3])
}

#' Per-frame button presses for one player
#'
#' @inheritParams n_frames
#' @param idx Player index, 1-based. Defaults to 1 (player 1).
#' @return Logical matrix, `n_frames(movie)` rows by `n_buttons(movie)`
#'   columns. Column names are the universal-button mnemonics.
#' @export
#' @examples
#' \dontrun{
#'   mv <- read_movie("data/raw_nes/super_mario_bros/1349.fm2")
#'   p1 <- player(mv)
#'   colSums(p1)        # number of frames each button was held
#' }
player <- function(movie, idx = 1L) {
  stopifnot(inherits(movie, "replayr_movie"))
  stopifnot(idx >= 1L, idx <= n_players(movie))
  m <- movie$inputs[, idx, , drop = TRUE]
  if (is.null(dim(m))) {
    # n_frames == 0 or n_buttons == 1 collapse case -- re-shape.
    m <- matrix(m, nrow = n_frames(movie), ncol = n_buttons(movie))
  }
  colnames(m) <- movie$button_mnemonics
  m
}

#' Press counts per universal-button slot
#'
#' @inheritParams n_frames
#' @param idx Player index, 1-based.
#' @return Named integer vector of length `n_buttons(movie)`. Names are
#'   the universal-button friendly labels.
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
    "<replayr_movie [%s] frames=%d players=%d buttons=%d source=%s>",
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
                                  collapse = ", "),
          if (length(keys) > 8L) ", ..." else "",
          "\n", sep = "")
    }
  }
  if (n_frames(x) > 0L) {
    pc <- press_counts(x, 1L)
    pc <- pc[pc > 0L]
    if (length(pc) > 0L) {
      cat("P1 presses: ",
          paste(sprintf("%s=%d", names(pc), pc), collapse = ", "),
          "\n", sep = "")
    }
  }
  invisible(x)
}
