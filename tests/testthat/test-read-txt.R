# The tables of the Atari Grand Challenge data set and of Atari-HEAD. The
# bundled examples and the files built here are in the layout of the data
# sets; no row is taken from either.
atari_table <- function(name) system.file("extdata", "tables", name, package = "replayr")
write_table <- function(lines, extension = ".txt") {
  path <- tempfile(fileext = extension)
  con <- file(path, "wb")
  writeLines(lines, con, sep = "\n")
  close(con)
  path
}
held <- function(movie) {
  states <- player(movie)
  vapply(seq_len(nrow(states)), function(i) paste(colnames(states)[states[i, ]], collapse = "+"), character(1))
}
test_that("the 18 action numbers are the states of one joystick", {
  rows <- sprintf("%d,0, 0, False, %d", 0:17, 0:17)
  path <- write_table(c("db traj id : 7", "frame,reward,score,terminal, action", rows))
  on.exit(unlink(path))
  movie <- read_txt(path)
  # NOOP, FIRE, UP, RIGHT, LEFT, DOWN, the four diagonals, and the same
  # eight directions with FIRE, as the Arcade Learning Environment numbers them.
  directions <- c("dpad_up", "dpad_right", "dpad_left", "dpad_down", "dpad_right+dpad_up", "dpad_left+dpad_up",
    "dpad_right+dpad_down", "dpad_left+dpad_down")
  expect_identical(held(movie), c("", "a", directions, paste0(directions, "+a")))
  layout <- button_layout(movie)
  expect_identical(layout$key, c("dpad_right", "dpad_left", "dpad_down", "dpad_up", "a"))
  expect_identical(layout$name, c("Right", "Left", "Down", "Up", "Fire"))
  # The IDs are those of an Atari 2600 joystick in a BizHawk recording.
  directory <- tempfile("a26-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  writeLines(c("MovieVersion BizHawk v2.0.0", "Platform A26", "GameName Some Game"), file.path(directory, "Header.txt"))
  writeLines(c("[Input]", "LogKey:#Reset|Select|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Button|",
    "|...|UDLRB|", "[/Input]"), file.path(directory, "Input Log.txt"))
  bizhawk <- tempfile(fileext = ".bk2")
  zip::zipr(bizhawk, c("Input Log.txt", "Header.txt"), root = directory)
  on.exit(unlink(bizhawk), add = TRUE)
  joystick <- button_layout(read_bk2(bizhawk))
  expect_identical(layout$id, joystick$id[match(layout$key, joystick$key)])
})
test_that("read_txt() returns the columns of a trajectory of the Atari Grand Challenge", {
  movie <- read_txt(atari_table("atari-grand-challenge.txt"))
  expect_s3_class(movie, "replayr_movie")
  expect_identical(n_observations(movie), 18L)
  expect_identical(n_players(movie), 1L)
  expect_identical(held(movie)[c(1, 3, 5, 7, 11, 14, 17)],
    c("", "dpad_right", "dpad_right+a", "a", "dpad_left+a", "dpad_right+dpad_up+a", "dpad_left+dpad_down+a"))
  # Of the columns of the table, the action is input; reward, score and the
  # end of the episode are states of the game and are not returned.
  channels <- analog_channels(movie)
  expect_identical(colnames(channels), "action")
  expect_identical(channels[, "action"], c(0, 0, 3, 3, 11, 11, 1, 0, 4, 4, 12, 2, 6, 14, 5, 9, 17, 0))
  expect_identical(movie$timing$frame, as.numeric(0:17))
  expect_identical(movie$header$trajectoryId, 1)
  info <- recording_info(movie)
  expect_identical(info$platform, "A26")
  expect_identical(info$frame_rate, 60)
  expect_identical(info$frame_rate_source, "format")
  expect_equal(observation_time(movie)[18], 17 / 60)
  # A selection keeps the frame numbers of its rows.
  expect_identical(movie[5:6]$timing$frame, c(4, 5))
  expect_identical(names(as.data.frame(movie)),
    c("observation", "dpad_right", "dpad_left", "dpad_down", "dpad_up", "a", "action", "commands"))
})
test_that("read_txt() returns the columns of a trial of Atari-HEAD and its times", {
  movie <- read_txt(atari_table("atari-head.txt"))
  expect_identical(n_observations(movie), 10L)
  expect_identical(held(movie),
    c("", "dpad_right", "dpad_right", "dpad_right+a", "a", "dpad_left", "dpad_left+dpad_up", "dpad_left+dpad_up+a",
      "dpad_down", ""))
  channels <- analog_channels(movie)
  # The action and the time a frame was shown; episode, score and reward
  # are states of the game and are not returned.
  expect_identical(colnames(channels), c("action", "duration_ms"))
  expect_identical(channel_layout(movie)$name, c("action", "duration(ms)"))
  expect_identical(channels[, "action"], c(0, 3, 3, 11, 1, 4, 7, 15, 5, NA))
  expect_identical(channels[, "duration_ms"], c(900, 50, 50, 51, 49, 50, 350, 50, 50, NA))
  # The last row of a trial has no values: no control is held, and the
  # channels are missing.
  expect_true(all(is.na(channels[10, ])))
  expect_false(any(player(movie)[10, ]))
  # A frame appears when the frames before it have been shown.
  expect_equal(observation_time(movie), c(0, 0.9, 0.95, 1, 1.051, 1.1, 1.15, 1.5, 1.55, 1.6))
  expect_identical(movie$timing$frame_id, paste0("EX_1000_", 1:10))
  expect_identical(movie$header$recordingId, "EX_1000")
  info <- recording_info(movie)
  expect_identical(info$platform, "A26")
  expect_true(is.na(info$frame_rate))
  expect_equal(info$duration, 1.6)
})
test_that("read_movie() knows both tables by their first line", {
  for (name in c("atari-grand-challenge.txt", "atari-head.txt")) {
    path <- atari_table(name)
    reader <- read_txt
    expect_identical(read_movie(path), reader(path))
    # Under another name, and named by format.
    copy <- tempfile(fileext = ".csv")
    file.copy(path, copy)
    expect_identical(player(read_movie(copy)), player(reader(path)))
    format <- if (name == "atari-head.txt") "atari_head" else "atari_gc"
    expect_identical(player(read_movie(copy, format = format)), player(reader(path)))
    unlink(copy)
  }
  # Another text file is not taken for one of them.
  other <- write_table(c("frame,action", "0,1"))
  on.exit(unlink(other))
  expect_error(read_movie(other), "shows none of the formats that are read from .txt files")
  expect_error(read_movie(other, format = "txt"), "shows none of the formats that are read from .txt files")
  expect_identical(recording_info(read_movie(atari_table("atari-head.txt"), format = "txt"))$format, "atari_head")
  expect_error(read_txt(other), "not a table of the Atari Grand Challenge data set or of Atari-HEAD")
  # One reader takes both tables and says which it read.
  expect_identical(recording_info(read_txt(atari_table("atari-grand-challenge.txt")))$format, "atari_gc")
  expect_identical(recording_info(read_txt(atari_table("atari-head.txt")))$format, "atari_head")
  expect_true(".txt" %in% supported_formats())
  listed <- supported_formats(details = TRUE)
  expect_identical(listed$reader[listed$extension == ".txt"], c("read_txt", "read_txt"))
  expect_identical(listed$structure[listed$extension == ".txt"], c("atari_gc", "atari_head"))
  # A recording of another format that was saved as a text file is still
  # read as what its content shows.
  movie <- tempfile(fileext = ".txt")
  on.exit(unlink(movie), add = TRUE)
  file.copy(system.file("extdata", "sample.fm2", package = "replayr"), movie)
  expect_identical(player(read_movie(movie)), player(read_fm2(system.file("extdata", "sample.fm2", package = "replayr"))))
})
test_that("recording_format() says which files are recordings", {
  expect_identical(recording_format(c(atari_table("atari-grand-challenge.txt"), atari_table("atari-head.txt"))),
    c("atari_gc", "atari_head"))
  sample <- system.file("extdata", c("sample.fm2", "sample.smv", "README.md"), package = "replayr")
  expect_identical(recording_format(sample), c("fm2", "smv", NA))
  directory <- tempfile("formats-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  notes <- file.path(directory, "notes.txt")
  writeLines("not a table", notes)
  renamed <- file.path(directory, "movie.dat")
  file.copy(sample[2], renamed)
  archive <- file.path(directory, "two.zip")
  zip::zip(archive, sample[1:2], mode = "cherry-pick")
  # A text file that is no table, a recording under another extension, an
  # archive of recordings, a folder and a path that does not exist.
  expect_identical(recording_format(c(notes, renamed, archive, directory, file.path(directory, "none.fm2"))),
    c(NA, "smv", NA, NA, NA))
  # What it names, read_movie() takes as format.
  expect_identical(player(read_movie(renamed, format = recording_format(renamed))), player(read_movie(sample[2])))
  expect_identical(recording_format(character()), character())
  expect_error(recording_format(1), "path must be a character vector")
})
test_that("the table readers refuse or report what is not a complete table", {
  first <- c("db traj id : 3", "frame,reward,score,terminal, action")
  read_rows <- function(rows, head = first) {
    path <- write_table(c(head, rows))
    on.exit(unlink(path))
    read_txt(path)
  }
  expect_error(read_rows("0,0, 0, False, 18"), "line 3 has the action 18")
  expect_error(read_rows(c("0,0, 0, False, 0", "1,0, 0, False, up")), "line 4 has \"up\" as action")
  expect_error(read_rows(c("0,0, 0, False, 0", "x,0, 0, False, 0")), "line 4 has \"x\" as frame")
  # A column that is not read does not stop the import.
  expect_identical(n_observations(read_rows(c("0,0, 0, False, 0", "1,x, ?, Maybe, 4"))), 2L)
  expect_error(read_rows(c("0,0, 0", "1,0, 0, False, 0")), "line 3 has fewer than 5 fields")
  expect_error(read_rows("0,0, 0, False, 0", head = c(first[1], "frame,score")), "does not name the columns")
  # A last row that was cut off is left out.
  expect_warning(cut <- read_rows(c("0,0, 0, False, 1", "1,0, 0, Fal")), "last row is incomplete")
  expect_identical(n_observations(cut), 1L)
  # Windows line ends and whole numbers for terminal.
  path <- tempfile(fileext = ".txt")
  on.exit(unlink(path))
  writeBin(charToRaw(paste0(c(first, "0,0, 0, 0, 2", "1,5, 5, 1, 0"), "\r\n", collapse = "")), path)
  movie <- read_txt(path)
  expect_identical(held(movie), c("dpad_up", ""))
  columns <- "frame_id,episode_id,score,duration(ms),unclipped_reward,action,gaze_positions"
  bad <- write_table(c(columns, "A_1,0,0,50,0,3,null", "A_2,0,0,fast,0,3,null"))
  on.exit(unlink(bad), add = TRUE)
  expect_error(read_txt(bad), "line 3 has \"fast\" as duration")
  # A trial without gaze positions in a row, and one cut off in the last row.
  plain <- write_table(c(columns, "A_1,0,0,50,0,3", "A_2,0,5,60,5,12", "A_3,0,5"))
  on.exit(unlink(plain), add = TRUE)
  expect_warning(movie <- read_txt(plain), "last row is incomplete")
  expect_identical(held(movie), c("dpad_right", "dpad_left+a"))
  expect_equal(observation_time(movie), c(0, 0.05))
})
