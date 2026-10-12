#' Ordered controller and device polls
#'
#' Multi-controller M64 and DTM files store ordered samples without per-sample
#' port IDs. The S3 class `replayr_poll_stream` retains the decoded controls and
#' original bytes. [polls()] returns one row per poll, with `port = NA_integer_`,
#' digital controls, source numeric channels, selected stick fields, and command
#' bits. DTM and CTM streams also expose format-specific poll flags. [button_layout()]
#' maps digital keys to stable IDs. [analog_channels()] and [stick_channels()]
#' select the single stored stream with `idx = 1`.
#'
#' [n_frames()] counts polls; [n_players()] returns `NA_integer_`. [player()]
#' requires an assigned controller and therefore directs callers to [polls()].
#' If emulator evidence establishes a repeating polling order, supply
#' `controller_order` to [read_m64()] or [read_dtm()] to construct a
#' [replayr_movie]. The format-specific help explains how player indices map
#' to physical controller ports.
#'
#' CTM stores separate pad, touch, and auxiliary-device events. Its observation
#' flags identify which controls were sampled; `observed_inputs` provides the
#' per-control mask. Mixed DTM adds device family and physical port when known.
#' Wii reports marked `valid_report = FALSE` preserve missing source payloads.
#'
#' @name replayr_poll_stream
#' @seealso read_m64, read_dtm
NULL

.is_recording <- function(x) inherits(x, c("replayr_movie", "replayr_poll_stream"))

#' Extract an unassigned controller-poll stream
#'
#' @param x A [replayr_poll_stream].
#' @return Data frame in source order. Digital column names use stable control
#'   keys. For M64, `commands` uses bit 0 for reset. For DTM, bit 0 is disc
#'   change and bit 1 is reset. Standard DTM exposes `is_connected` and
#'   `get_origin`; Zelda Edition exposes `loading`, `tuner_event`, `link_x`,
#'   and `link_z` (see [read_dtm()]). The object's `poll_bytes` component
#'   contains four original bytes per M64 poll, eight per standard DTM poll,
#'   or seventeen per Zelda Edition poll, in source order. CTM stores seven
#'   bytes per device event. Wii stores padded report bytes with `poll_lengths`;
#'   mixed HID records include the length byte. `source_tail` retains incomplete
#'   final Wii records. Use observation flags before analysing device-specific fields.
#' @export
polls <- function(x) {
  stopifnot(inherits(x, "replayr_poll_stream"))
  n <- n_frames(x)
  buttons <- matrix(x$inputs[, 1L, , drop = FALSE], nrow = n, ncol = n_buttons(x))
  colnames(buttons) <- x$button_keys
  result <- data.frame(poll = seq_len(n), port = rep(NA_integer_, n), buttons,
                       analog_channels(x), stick_channels(x), commands = x$commands,
                       check.names = FALSE)
  if (!is.null(x$poll_fields)) result <- cbind(result, x$poll_fields)
  if (identical(x$header[["_format"]], "dtm") &&
      identical(x$header$dtmVariant, "standard")) {
    high <- as.integer(x$poll_bytes[, 2L])
    result$is_connected <- bitwAnd(high, 64L) != 0L
    result$get_origin <- bitwAnd(high, 128L) != 0L
  }
  result
}

#' @export
format.replayr_poll_stream <- function(x, ...) {
  sprintf("<replayr_poll_stream [%s] polls=%d buttons=%d enabled_ports=%s assignment=%s>",
          x$header[["_format"]], n_frames(x), n_buttons(x),
          paste(x$header$enabledPorts, collapse = ","),
          x$header$assignmentReason %||% x$header$controllerAssignment %||% "device polls")
}

#' @export
print.replayr_poll_stream <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}
