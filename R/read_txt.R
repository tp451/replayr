# Tables of two published data sets of human play on the Atari 2600: the
# Atari Grand Challenge data set (Kurin et al. 2017, arXiv:1705.10998) and
# Atari-HEAD (Zhang et al. 2020, doi:10.1609/aaai.v34i04.6161). Both are text
# files with one row per frame and an action number in each row. Sources: the
# files themselves, the loader of the first data set
# (yobibyte/atarigrandchallenge, agc/dataset.py and agc/util.py), and the
# description and action_enums.txt of the second (Zenodo record 3451402).
#
# Atari Grand Challenge, one file per episode:
#   db traj id : 2530
#   frame,reward,score,terminal, action
#   0,0, 0, False, 0
# Atari-HEAD, one file per trial; the gaze positions (where on the screen
# the player was looking, from an eye tracker) are a list of x and y of any
# length, or null, and a field without a value is null:
#   frame_id,episode_id,score,duration(ms),unclipped_reward,action,gaze_positions
#   RZ_9847886_1,0,0,1061,0,4,80.40,104.80,80.46,104.88
#
# The action is one of the 18 actions of the Arcade Learning Environment,
# which are the states of one joystick: 0 nothing, 1 fire, 2 up, 3 right,
# 4 left, 5 down, 6 up-right, 7 up-left, 8 down-right, 9 down-left, and 10 to
# 17 the same eight directions with fire.
.ALE_CONTROLS <- list(
  dpad_right = c(3L, 6L, 8L, 11L, 14L, 16L), dpad_left = c(4L, 7L, 9L, 12L, 15L, 17L),
  dpad_down = c(5L, 8L, 9L, 13L, 16L, 17L), dpad_up = c(2L, 6L, 7L, 10L, 14L, 15L),
  a = c(1L, 10:17)
)
.ALE_CONTROL_NAMES <- c("Right", "Left", "Down", "Up", "Fire")
# The first line by which read_movie() knows each table.
.TABLE_FIRST_LINES <- c(
  atari_gc = "^db traj id *:",
  atari_head = "^frame_id,episode_id,score,duration\\(ms\\),unclipped_reward,action(,|$)"
)
.table_format <- function(first_line) {
  for (format in names(.TABLE_FIRST_LINES)) {
    if (grepl(.TABLE_FIRST_LINES[[format]], first_line, useBytes = TRUE)) return(format)
  }
  NA_character_
}
# The table a text file shows by its first line, or NA. The line is looked
# at as bytes, so that a file of another kind is not read as text.
.table_shown <- function(path) {
  start <- readBin(path, "raw", 4096L)
  if (!length(start) || any(start == as.raw(0L))) return(NA_character_)
  .table_format(strsplit(rawToChar(start), "\r?\n", useBytes = TRUE)[[1L]][1L])
}
# The lines of a table without its line ends and without empty lines at the
# end of the file.
.table_lines <- function(path) {
  lines <- sub("\r$", "", readLines(path, warn = FALSE), useBytes = TRUE)
  lines[seq_len(max(grep("[^[:space:]]", lines, useBytes = TRUE)))]
}
# A text file is read as the table that its first line shows.
.decode_txt <- function(path) {
  shown <- .table_shown(path)
  if (is.na(shown)) {
    stop(path, ": not a table of the Atari Grand Challenge data set or of Atari-HEAD: the first line is ",
      "neither \"db traj id\" with a number nor the column names of a trial (frame_id, episode_id, score, ",
      "duration(ms), unclipped_reward, action)", call. = FALSE)
  }
  if (shown == "atari_gc") .decode_atari_gc(path) else .decode_atari_head(path)
}
# The first fields of every row as a character matrix. A last row that the
# file does not hold completely is left out, with a warning; any other row
# with too few fields is an error.
.table_fields <- function(rows, n_fields, first_row_line, path) {
  parts <- strsplit(rows, ",", fixed = TRUE, useBytes = TRUE)
  short <- which(lengths(parts) < n_fields)
  if (length(short) && short[length(short)] == length(rows) && length(short) == 1L) {
    warning(basename(path), ": the last row is incomplete and is left out", call. = FALSE)
    parts <- parts[-short]
    short <- integer()
  }
  if (length(short)) {
    stop(path, ": line ", short[1L] + first_row_line - 1L, " has fewer than ", n_fields, " fields", call. = FALSE)
  }
  fields <- vapply(parts, function(x) x[seq_len(n_fields)], character(n_fields))
  matrix(trimws(fields), ncol = n_fields, byrow = TRUE)
}
# The numbers of one column; `null` is a missing value where the table has them.
.table_numbers <- function(values, column, first_row_line, path, null = FALSE) {
  missing <- null & values == "null"
  numbers <- suppressWarnings(as.numeric(values))
  bad <- which(!missing & !grepl("^-?[0-9]+([.][0-9]+)?$", values))
  if (length(bad)) {
    stop(path, ": line ", bad[1L] + first_row_line - 1L, " has \"", values[bad[1L]], "\" as ", column, call. = FALSE)
  }
  numbers
}
# The joystick controls that each action number stands for.
.ale_inputs <- function(action, first_row_line, path) {
  known <- is.na(action) | action %in% 0:17
  if (any(!known)) {
    stop(path, ": line ", which(!known)[1L] + first_row_line - 1L, " has the action ", action[!known][1L],
      "; the actions of the Arcade Learning Environment are 0 to 17", call. = FALSE)
  }
  inputs <- array(FALSE, c(length(action), 1L, length(.ALE_CONTROLS)))
  for (k in seq_along(.ALE_CONTROLS)) inputs[, 1L, k] <- action %in% .ALE_CONTROLS[[k]]
  inputs
}
.decode_atari_gc <- function(path) {
  lines <- .table_lines(path)
  columns <- c("frame", "reward", "score", "terminal", "action")
  if (length(lines) < 2L ||
    !identical(trimws(strsplit(lines[2L], ",", fixed = TRUE, useBytes = TRUE)[[1L]]), columns)) {
    stop(path, ": the second line does not name the columns ", paste(columns, collapse = ", "), call. = FALSE)
  }
  fields <- .table_fields(lines[-(1:2)], 5L, 3L, path)
  number <- function(j, column) .table_numbers(fields[, j], column, 3L, path)
  # Reward, score and the end of the episode are states of the game and not
  # input: they are not read.
  action <- number(5L, "action")
  channels <- cbind(action = action)
  header <- list(
    "_format" = "atari_gc", Platform = "A26",
    trajectoryId = as.numeric(sub("^db traj id *: *", "", lines[1L])), observationUnit = "frame"
  )
  movie <- .new_named_movie(
    header, integer(nrow(fields)), .ale_inputs(action, 3L, path), names(.ALE_CONTROLS), path,
    analog = list(channels), names = .ALE_CONTROL_NAMES
  )
  movie$timing <- data.frame(frame = number(1L, "frame"))
  movie
}
.decode_atari_head <- function(path) {
  lines <- .table_lines(path)
  # The gaze positions follow the sixth field and are not read. Neither are
  # the episode, the score and the reward: states of the game, not input.
  rows <- sub("^((?:[^,]*,){5}[^,]*).*$", "\\1", lines[-1L], perl = TRUE, useBytes = TRUE)
  fields <- .table_fields(rows, 6L, 2L, path)
  number <- function(j, column) .table_numbers(fields[, j], column, 2L, path, null = TRUE)
  action <- number(6L, "action")
  duration <- number(4L, "duration(ms)")
  channels <- cbind(action = action, `duration(ms)` = duration)
  header <- list(
    "_format" = "atari_head", Platform = "A26",
    recordingId = if (nrow(fields)) sub("_[0-9]+$", "", fields[1L, 1L]) else NA_character_,
    observationUnit = "frame"
  )
  movie <- .new_named_movie(
    header, integer(nrow(fields)), .ale_inputs(action, 2L, path), names(.ALE_CONTROLS), path,
    analog = list(channels), names = .ALE_CONTROL_NAMES
  )
  # A frame stays on screen for its duration; a row without one takes no time.
  shown <- ifelse(is.na(duration), 0, duration) / 1000
  movie$timing <- data.frame(
    start_seconds = cumsum(c(0, shown[-length(shown)]))[seq_along(shown)],
    frame_id = fields[, 1L], stringsAsFactors = FALSE
  )
  movie
}
