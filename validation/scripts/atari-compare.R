# Compare what replayr reads from the tables of the Atari Grand Challenge
# data set and of Atari-HEAD with the output of the separate decoder
# (atari-decode.py), value by value.
# A trial of Atari-HEAD is also held against the data set's own table of
# trials (meta_data.csv): its number of frames and its play time.
# Usage: Rscript atari-compare.R <folder of the data> <folder with the decoder's output>
#          <sources.csv> <result by file.csv> <result by game.csv>
# replayr comes from the library paths of the session (R_LIBS).
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(library(replayr))
sources <- read.csv(args[3], fileEncoding = "UTF-8", stringsAsFactors = FALSE)
listing <- file.path(args[1], "atari-head", "meta_data.csv")
listing <- if (file.exists(listing)) read.csv(listing, stringsAsFactors = FALSE) else NULL
controls <- c(right = "dpad_right", left = "dpad_left", down = "dpad_down", up = "dpad_up", fire = "a")
# Two columns agree where both have the same value or both have none.
differing <- function(ours, theirs) sum(xor(is.na(ours), is.na(theirs)) | (!is.na(ours) & !is.na(theirs) & ours != theirs))
rows <- vector("list", nrow(sources))
for (i in seq_len(nrow(sources))) {
  path <- file.path(args[1], sources$file[i])
  decoded <- file.path(args[2], paste0(sources$file[i], ".csv"))
  if (!file.exists(path) || !file.exists(decoded)) next
  warned <- character()
  # read_movie() has to know the table by its first line.
  movie <- tryCatch(withCallingHandlers(read_movie(path), warning = function(w) {
    warned <<- c(warned, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) conditionMessage(e))
  if (is.character(movie)) {
    # A table that is not read counts as a disagreement and is named.
    message("not read: ", sources$file[i], " - ", movie)
    rows[[i]] <- data.frame(
      file = sources$file[i], data_set = sources$data_set[i],
      game = basename(dirname(sub("/highscore/", "/", sources$file[i]))), bytes = sources$bytes[i],
      sha256 = sources$sha256[i], observations = 0L, control_values = 0, other_values = 0, seconds = NA_real_,
      warnings = movie, equals_listing = NA, differences = NA_real_, status = "NOT READ", stringsAsFactors = FALSE
    )
    next
  }
  other <- read.csv(decoded, stringsAsFactors = FALSE)
  n <- n_observations(movie)
  states <- player(movie)
  channels <- analog_channels(movie)
  head_table <- recording_info(movie)$format == "atari_head"
  differences <- if (nrow(other) != n) NA_real_ else {
    sum(vapply(names(controls), function(k) sum(states[, controls[[k]]] != (other[[k]] == 1L)), numeric(1))) +
      sum(vapply(colnames(channels), function(key) differing(channels[, key], other[[key]]), numeric(1))) +
      if (head_table) {
        sum(abs(observation_time(movie) * 1000 - other$start_ms) > 1e-6) + sum(movie$timing$frame_id != other$frame_id)
      } else {
        sum(movie$timing$frame != other$frame)
      }
  }
  # The number before the first underscore of the file name is the trial's.
  listed <- if (head_table && !is.null(listing)) {
    listing[listing$trial_id == suppressWarnings(as.integer(sub("_.*$", "", basename(path)))), ]
  }
  equals_listing <- if (is.null(listed)) NA else {
    nrow(listed) == 1L && listed$total_frame == n &&
      listed$total_game_play_time == sum(channels[, "duration_ms"], na.rm = TRUE)
  }
  rows[[i]] <- data.frame(
    file = sources$file[i], data_set = sources$data_set[i], game = basename(dirname(sub("/highscore/", "/", sources$file[i]))),
    bytes = sources$bytes[i], sha256 = sources$sha256[i], observations = n,
    control_values = n * length(controls), other_values = n * (ncol(channels) + 1L + head_table),
    seconds = recording_info(movie)$duration, warnings = paste(warned, collapse = " | "),
    equals_listing = equals_listing, differences = differences,
    status = if (identical(differences, 0)) "agrees" else "DISAGREES", stringsAsFactors = FALSE
  )
}
result <- do.call(rbind, rows)
write.csv(result, args[4], row.names = FALSE, fileEncoding = "UTF-8")
by_game <- do.call(rbind, lapply(split(result, paste(result$data_set, result$game), drop = TRUE), function(g) {
  data.frame(
    data_set = g$data_set[1L], game = g$game[1L], tables = nrow(g), observations = sum(g$observations),
    hours = round(sum(g$seconds) / 3600, 2), values = sum(g$control_values, g$other_values),
    differences = sum(g$differences), with_warning = sum(nzchar(g$warnings)),
    equal_to_listing = if (all(is.na(g$equals_listing))) NA_integer_ else sum(g$equals_listing),
    stringsAsFactors = FALSE
  )
}))
write.csv(by_game, args[5], row.names = FALSE, fileEncoding = "UTF-8")
print(by_game, row.names = FALSE)
cat("tables:", nrow(result), "of", nrow(sources), " agree:", sum(result$status == "agrees"),
  " observations:", sum(result$observations), " values:", sum(result$control_values, result$other_values), "\n")
