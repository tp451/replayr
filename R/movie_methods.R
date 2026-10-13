# Components of a recording that hold one entry per observation. `[` cuts
# them together. A component of one of these names is cut only where its
# length or number of rows is that of the recording.
.OBSERVATION_COMPONENTS <- c(
  "inputs", "commands", "system_inputs", "source_inputs",
  "poll_bytes", "poll_fields", "poll_lengths", "observed_inputs",
  "source_packets", "source_words", "source_keycodes", "source_values", "source_digits",
  "source_locations", "mouse_observed", "mouse_button_observed", "mouse_source_state",
  "double_tapped", "pressed", "released", "frame_fields",
  "flags", "timing", "input_events", "events", "subframes"
)
# Lists with one matrix per controller, or per controller and stick.
.OBSERVATION_LISTS <- c("analog", "stick_values", "stick_overrides", "decoded_stick_vectors")
# Doom-engine demos keep further fields of every tic in their header.
.OBSERVATION_HEADER_FIELDS <- c(
  "forwardmove", "sidemove", "angleturn", "weaponselect", "has_special",
  "artifact", "suicide", "extendedCommands"
)
.cut_observations <- function(x, rows, n) {
  if (is.data.frame(x)) {
    if (nrow(x) != n) return(x)
    x <- x[rows, , drop = FALSE]
    rownames(x) <- NULL
    return(x)
  }
  size <- dim(x)
  if (length(size) == 2L) return(if (size[1L] == n) x[rows, , drop = FALSE] else x)
  if (length(size) == 3L) return(if (size[1L] == n) x[rows, , , drop = FALSE] else x)
  if (is.null(size) && length(x) == n) return(x[rows])
  x
}
# Lists are followed down to their matrices; anything that is not a table of
# observations is left as it is.
.cut_observation_lists <- function(x, rows, n) {
  if (is.list(x) && !is.data.frame(x)) return(lapply(x, .cut_observation_lists, rows, n))
  if (is.null(dim(x))) return(x)
  .cut_observations(x, rows, n)
}
#' Select observations of a recording
#'
#' `movie[i]` keeps the observations `i` and returns a recording of the same
#' class, so that every accessor works on the selection as on the whole
#' recording. Whatever is stored once per observation is cut together: button
#' states, numeric channels, commands, console controls, poll fields, and the
#' tables of a reader that follow the observations (timing, events,
#' subframes, source bytes).
#'
#' The header and the tables that describe the file as a whole stay as they
#' are, so header counts still refer to the file. `observation_index` in the
#' result gives the position in the file of each observation kept.
#'
#' @param x A [replayr_movie] or [replayr_poll_stream].
#' @param i Observations to keep: positions, negative positions to leave out,
#'   or a logical vector with one entry per observation.
#' @param ... Not used. A recording is selected by observation only; use
#'   [player()] for the buttons of one controller.
#' @return A recording of the class of `x`.
#' @examples
#' movie <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' first_ten_seconds <- movie[1:600]
#' n_observations(first_ten_seconds)
#' # The observations with A held.
#' n_observations(movie[player(movie)[, "a"]])
#' @name subset-recording
#' @export
`[.replayr_movie` <- function(x, i, ...) {
  if (...length()) {
    stop("A recording is selected by observation only: movie[i]. Use player() for one controller.", call. = FALSE)
  }
  if (missing(i)) return(x)
  n <- as.integer(dim(x$inputs)[1L])
  if (is.logical(i) && length(i) != n) {
    stop("A logical selection needs one entry per observation.", call. = FALSE)
  }
  if (!is.logical(i) && !is.numeric(i)) stop("Select observations by position or by a logical vector.", call. = FALSE)
  rows <- seq_len(n)[i]
  if (anyNA(rows)) stop("The selection contains missing values or positions beyond the recording.", call. = FALSE)
  for (name in intersect(.OBSERVATION_COMPONENTS, names(x))) {
    x[[name]] <- .cut_observations(x[[name]], rows, n)
  }
  for (name in intersect(.OBSERVATION_LISTS, names(x))) {
    x[[name]] <- .cut_observation_lists(x[[name]], rows, n)
  }
  # libTAS keeps each distinct line of its input log once; only the pointers
  # of the observations are cut.
  if (!is.null(x$source_input_log$row)) x$source_input_log$row <- x$source_input_log$row[rows]
  for (name in intersect(.OBSERVATION_HEADER_FIELDS, names(x$header))) {
    x$header[[name]] <- .cut_observation_lists(x$header[[name]], rows, n)
  }
  x$observation_index <- (x$observation_index %||% seq_len(n))[rows]
  x
}
#' @rdname subset-recording
#' @export
`[.replayr_poll_stream` <- `[.replayr_movie`
#' A recording as a data frame
#'
#' Returns one row per observation of one controller: its position in the
#' file, the button states, the numeric channels, the selected stick
#' representations and the commands. Columns are named by the keys of
#' [button_layout()] and [channel_layout()]. For an unassigned
#' [replayr_poll_stream] the result is that of [polls()].
#'
#' @param x A [replayr_movie] or [replayr_poll_stream].
#' @param row.names,optional As in [base::as.data.frame()]; `optional` is not
#'   used.
#' @param ... Not used.
#' @param idx Player index, 1-based.
#' @return A data frame. `observation` is the position of the row in the
#'   file, which differs from the row number after a selection with `[`. A
#'   numeric channel whose key is also the key of a button has `_value`
#'   appended to its name.
#' @examples
#' movie <- read_movie(system.file("extdata", "sample.dtm", package = "replayr"))
#' head(as.data.frame(movie))
#' @export
as.data.frame.replayr_movie <- function(x, row.names = NULL, optional = FALSE, ..., idx = 1L) {
  buttons <- player(x, idx)
  n <- nrow(buttons)
  channels <- analog_channels(x, idx)
  sticks <- stick_channels(x, idx)
  shared <- colnames(channels) %in% colnames(buttons)
  if (any(shared)) colnames(channels)[shared] <- paste0(colnames(channels)[shared], "_value")
  attributes(buttons) <- attributes(buttons)[c("dim", "dimnames")]
  result <- data.frame(
    observation = x$observation_index %||% seq_len(n), buttons, channels, sticks,
    commands = x$commands, check.names = FALSE
  )
  names(result) <- make.unique(names(result), sep = "_")
  if (!is.null(row.names)) rownames(result) <- row.names
  result
}
#' @rdname as.data.frame.replayr_movie
#' @export
as.data.frame.replayr_poll_stream <- function(x, row.names = NULL, optional = FALSE, ...) {
  result <- polls(x)
  if (!is.null(row.names)) rownames(result) <- row.names
  result
}
#' Summary of a recording
#'
#' Describes each control and numeric channel of a recording. For a control,
#' `held` is the number of observations in which it is active and
#' `activations` the number of times it becomes active, counting a control
#' that is active in the first observation. A button held for a long time has
#' many observations and one activation; a button tapped repeatedly has many
#' activations.
#'
#' @param object A [replayr_movie] or [replayr_poll_stream].
#' @param ... Not used.
#' @return An object of class `summary.replayr_movie`: a list with the
#'   `format`, the `unit` of observation, the number of `observations` and
#'   `controllers`, and two data frames. `controls` has one row per controller
#'   and control (`controller`, `key`, `name`, `held`, `activations`);
#'   `channels` has one row per controller and numeric channel (`controller`,
#'   `key`, `name`, `min`, `max`, `missing`). Printing shows the controls that
#'   are active at least once.
#' @examples
#' movie <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' summary(movie)
#' summary(movie)$controls
#' @export
summary.replayr_movie <- function(object, ...) {
  n <- as.integer(dim(object$inputs)[1L])
  controllers <- as.integer(dim(object$inputs)[2L])
  layout <- button_layout(object)
  controls <- lapply(seq_len(controllers), function(p) {
    states <- matrix(object$inputs[, p, , drop = FALSE], nrow = n, ncol = nrow(layout))
    previous <- matrix(FALSE, n, ncol(states))
    if (n > 1L) previous[-1L, ] <- states[-n, , drop = FALSE]
    data.frame(
      controller = rep(p, nrow(layout)), key = layout$key, name = layout$name,
      held = as.integer(colSums(states)), activations = as.integer(colSums(states & !previous)),
      stringsAsFactors = FALSE
    )
  })
  channels <- lapply(seq_len(controllers), function(p) {
    values <- analog_channels(object, p)
    described <- channel_layout(object, p)
    present <- colSums(!is.na(values)) > 0L
    limit <- function(f) vapply(seq_len(ncol(values)),
      function(j) if (present[j]) f(values[, j], na.rm = TRUE) else NA_real_, numeric(1))
    data.frame(
      controller = rep(p, nrow(described)), key = described$key, name = described$name,
      min = limit(min), max = limit(max), missing = as.integer(colSums(is.na(values))),
      stringsAsFactors = FALSE
    )
  })
  structure(list(
    format = object$header[["_format"]] %||% "fm2", unit = observation_unit(object),
    observations = n, controllers = controllers,
    source = if (is.na(object$source_path %||% NA)) NA_character_ else basename(object$source_path),
    controls = do.call(rbind, controls), channels = do.call(rbind, channels)
  ), class = "summary.replayr_movie")
}
#' @rdname summary.replayr_movie
#' @export
summary.replayr_poll_stream <- summary.replayr_movie
#' @export
print.summary.replayr_movie <- function(x, ...) {
  unit <- if (x$observations == 1L) x$unit else sub("(frame|subframe|poll|cycle|event|tic|update)$", "\\1s", x$unit)
  cat(sprintf(
    "%s recording%s: %d %s, %d %s, %d %s\n", x$format,
    if (is.na(x$source)) "" else paste0(" ", x$source), x$observations, unit,
    x$controllers, if (x$controllers == 1L) "controller" else "controllers",
    length(unique(x$controls$key)), if (length(unique(x$controls$key)) == 1L) "control" else "controls"
  ))
  active <- x$controls[x$controls$held > 0L, , drop = FALSE]
  if (nrow(active)) {
    cat("Controls active at least once:\n")
    print(active, row.names = FALSE)
  } else {
    cat("No control is active in any observation.\n")
  }
  if (nrow(x$channels)) {
    cat("Numeric channels:\n")
    print(x$channels, row.names = FALSE)
  }
  invisible(x)
}
