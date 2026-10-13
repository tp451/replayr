# summary(), as.data.frame() and `[` for recordings.
method_movie <- function(file, ...) {
  suppressWarnings(read_movie(system.file("extdata", file, package = "replayr", mustWork = TRUE), ...))
}
bundled_recordings <- function() {
  files <- list.files(system.file("extdata", package = "replayr"), recursive = TRUE, full.names = TRUE)
  files[!grepl("[.](md|json|csv|txt)$", files)]
}
leading <- function(x) if (is.data.frame(x)) nrow(x) else if (is.null(dim(x))) length(x) else dim(x)[1L]
test_that("a selection is a recording of the same class with the same accessors", {
  movie <- method_movie("sample.dtm", analog = c(left = "angle+magnitude", right = "cardinal8"))
  part <- movie[901:905]
  expect_s3_class(part, "replayr_movie")
  expect_identical(n_observations(part), 5L)
  expect_identical(part$inputs, movie$inputs[901:905, , , drop = FALSE])
  expect_identical(colnames(player(part)), colnames(player(movie)))
  expect_identical(analog_channels(part), analog_channels(movie)[901:905, ])
  expect_identical(stick_channels(part), stick_channels(movie)[901:905, ])
  expect_identical(part$commands, movie$commands[901:905])
  expect_identical(button_layout(part), button_layout(movie))
  expect_identical(part$observation_index, 901:905)
  # Positions leave out, a logical vector selects, and selections compose.
  expect_identical(n_observations(movie[-(1:3000)]), 600L)
  held <- player(movie)[, "a"]
  expect_identical(n_observations(movie[held]), sum(held))
  expect_true(all(player(movie[held])[, "a"]))
  expect_identical(movie[901:905][2:3]$observation_index, 902:903)
  expect_identical(movie[], movie)
  expect_identical(n_observations(movie[integer()]), 0L)
  expect_error(movie[1, 2], "selected by observation only")
  expect_error(movie[99999], "beyond the recording")
  expect_error(movie[c(TRUE, FALSE)], "one entry per observation")
  expect_error(movie["a"], "by position or by a logical vector")
  expect_error(movie[c(1, NA)], "missing values")
})
test_that("everything stored once per observation is cut together", {
  # A component of a layout can have as many entries as a short recording has
  # observations; these describe controls, not observations.
  layout <- c(
    "button_ids", "button_keys", "button_mnemonics", "button_names", "control_layout",
    "source_layout", "source_controls", "channel_source", "stick_available", "stick_calibration",
    "stick_deadzone", "stick_modes", "analysis_ready", "source_archive", "source_commands",
    "source_scripts", "source_input_log", "system_events", "observation_index", "header"
  )
  checked <- 0L
  for (file in bundled_recordings()) {
    movie <- tryCatch(suppressWarnings(read_movie(file)), error = function(e) NULL)
    if (is.null(movie) || !inherits(movie, c("replayr_movie", "replayr_poll_stream"))) next
    n <- dim(movie$inputs)[1L]
    if (n < 4L) next
    keep <- seq_len(n - 2L) + 1L
    part <- movie[keep]
    checked <- checked + 1L
    expect_identical(class(part), class(movie), info = basename(file))
    expect_identical(dim(part$inputs)[1L], n - 2L, info = basename(file))
    for (name in setdiff(names(movie), layout)) {
      x <- movie[[name]]
      leaves <- if (is.list(x) && !is.data.frame(x)) x else list(x)
      now <- if (is.list(x) && !is.data.frame(x)) part[[name]] else list(part[[name]])
      for (k in seq_along(leaves)) {
        if (is.null(leaves[[k]]) || is.list(leaves[[k]]) && !is.data.frame(leaves[[k]])) next
        if (!isTRUE(leading(leaves[[k]]) == n) || n <= 2L) next
        if (is.null(dim(leaves[[k]])) && name %in% c("analog", "stick_values", "stick_overrides")) next
        expect_identical(leading(now[[k]]), n - 2L, info = paste(basename(file), name))
      }
    }
    # The accessors agree with the same rows of the whole recording.
    for (p in seq_len(dim(movie$inputs)[2L])) {
      expect_identical(analog_channels(part, p), analog_channels(movie, p)[keep, , drop = FALSE], info = basename(file))
      expect_identical(stick_channels(part, p), stick_channels(movie, p)[keep, , drop = FALSE], info = basename(file))
    }
    expect_identical(unname(as.matrix(system_channels(part))), unname(as.matrix(system_channels(movie))[keep, , drop = FALSE]), info = basename(file))
    if (inherits(movie, "replayr_poll_stream")) {
      whole <- polls(movie)[keep, , drop = FALSE]
      rownames(whole) <- NULL
      cut <- polls(part)
      expect_identical(cut, whole, info = basename(file))
      expect_identical(cut$poll, keep, info = basename(file))
    }
  }
  expect_gt(checked, 60L)
  # Doom demos keep further fields of every tic in the header.
  doom <- method_movie("sample.lmp")
  expect_identical(nrow(doom[1:10]$header$forwardmove), 10L)
  expect_identical(nrow(doom[1:10]$source_packets), 10L)
})
test_that("a recording becomes a data frame with one row per observation", {
  movie <- method_movie("sample.dtm", analog = c(left = "angle+magnitude", right = "cardinal8"))
  frame <- as.data.frame(movie)
  expect_s3_class(frame, "data.frame")
  expect_identical(nrow(frame), n_observations(movie))
  expect_identical(names(frame), c(
    "observation", button_layout(movie)$key, channel_layout(movie)$key,
    colnames(stick_channels(movie)), "commands"
  ))
  expect_identical(frame$observation, seq_len(n_observations(movie)))
  expect_identical(frame$a, unname(player(movie)[, "a"]))
  expect_identical(frame$left_x, unname(analog_channels(movie)[, "left_x"]))
  expect_identical(as.data.frame(movie[901:905])$observation, 901:905)
  two <- method_movie("sample.fm2")
  expect_identical(as.data.frame(two, idx = 2L)$a, unname(player(two, 2L)[, "a"]))
  expect_error(as.data.frame(two, idx = 3L), "idx must identify one player")
  # A channel named as a button is kept apart from it.
  clash <- two
  clash$analog[[1L]] <- cbind(a = seq_len(n_observations(two)) + 0)
  clash$channel_source[[1L]] <- "a"
  expect_true(all(c("a", "a_value") %in% names(as.data.frame(clash))))
  for (file in bundled_recordings()) {
    movie <- tryCatch(suppressWarnings(read_movie(file)), error = function(e) NULL)
    if (is.null(movie) || !inherits(movie, c("replayr_movie", "replayr_poll_stream"))) next
    frame <- as.data.frame(movie)
    expect_identical(nrow(frame), dim(movie$inputs)[1L], info = basename(file))
    expect_false(anyDuplicated(names(frame)) > 0L, info = basename(file))
    if (inherits(movie, "replayr_poll_stream")) expect_identical(frame, polls(movie), info = basename(file))
  }
})
test_that("summary counts held observations and activations", {
  hold <- summary(method_movie("paper/hold.fm2"))
  expect_s3_class(hold, "summary.replayr_movie")
  expect_identical(c(hold$format, hold$unit), c("fm2", "frame"))
  expect_identical(c(hold$observations, hold$controllers), c(3600L, 1L))
  active <- hold$controls[hold$controls$held > 0L, ]
  expect_identical(active$key, c("dpad_right", "start", "b", "a"))
  expect_identical(active$held, c(3240L, 1L, 3240L, 308L))
  expect_identical(active$activations, c(1L, 1L, 1L, 77L))
  expect_identical(nrow(hold$channels), 0L)
  output <- capture.output(print(hold))
  expect_match(output[1L], "fm2 recording hold.fm2: 3600 frames, 1 controller, 8 controls", fixed = TRUE)
  expect_true(any(grepl("dpad_right +Right +3240 +1$", output)))
  sticks <- summary(method_movie("sample.dtm"))
  expect_identical(sticks$unit, "controller poll")
  expect_identical(sticks$channels$key, channel_layout(method_movie("sample.dtm"))$key)
  expect_identical(sticks$channels$min[sticks$channels$key == "left_x"], 58)
  expect_match(capture.output(print(sticks))[1L], "3600 controller polls", fixed = TRUE)
  # The held count is that of press_counts(); every bundled recording has a summary.
  for (file in bundled_recordings()) {
    movie <- tryCatch(suppressWarnings(read_movie(file)), error = function(e) NULL)
    if (is.null(movie) || !inherits(movie, c("replayr_movie", "replayr_poll_stream"))) next
    described <- summary(movie)
    expect_identical(nrow(described$controls), dim(movie$inputs)[2L] * dim(movie$inputs)[3L], info = basename(file))
    expect_true(all(described$controls$activations <= described$controls$held), info = basename(file))
    expect_identical(sum(described$controls$held), sum(movie$inputs), info = basename(file))
    expect_silent(capture.output(print(described)))
    if (inherits(movie, "replayr_movie")) {
      first <- described$controls[described$controls$controller == 1L, ]
      expect_identical(first$held, unname(press_counts(movie)), info = basename(file))
    }
  }
  # An empty selection still has a summary.
  expect_identical(sum(summary(method_movie("sample.fm2")[integer()])$controls$held), 0L)
})
