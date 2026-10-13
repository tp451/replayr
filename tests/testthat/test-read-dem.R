# GoldSrc demos. The bundled example has a loading section of two start frames
# without input and 24 frames of play at 100 frames per second, of which
# frame 6 is recorded twice (tools/generate-goldsrc-fixture.R).
dem_example <- function() system.file("extdata", "computers", "goldsrc-moves.dem", package = "replayr")
# The frames of play in which a control is held, counted from frame 0.
dem_frames <- function(movie, key) {
  play <- !movie$timing$start_frame
  sort(unique(movie$timing$frame[play & player(movie)[, key]]))
}
test_that("read_dem() returns the actions of every command", {
  movie <- read_dem(dem_example())
  expect_s3_class(movie, "replayr_movie")
  expect_identical(movie$header[["_format"]], "dem")
  expect_identical(n_observations(movie), 27L)
  expect_identical(n_players(movie), 1L)
  expect_identical(observation_unit(movie), "demo frame")
  layout <- button_layout(movie)
  expect_identical(layout$key, paste0("action_", c(
    "attack", "jump", "duck", "forward", "back", "use", "cancel", "turn_left", "turn_right",
    "move_left", "move_right", "attack2", "run", "reload", "alt1", "score"
  )))
  expect_true(all(layout$kind == "action"))
  expect_identical(layout$id[1:2], c("action:attack", "action:jump"))
  expect_identical(layout$name[c(8, 11, 12)], c("Turn left", "Move right", "Attack 2"))
  expect_identical(dem_frames(movie, "action_forward"), 0:15)
  expect_identical(dem_frames(movie, "action_jump"), c(4L, 5L, 12L, 13L))
  expect_identical(dem_frames(movie, "action_move_right"), 8:11)
  expect_identical(dem_frames(movie, "action_duck"), 16:19)
  expect_identical(dem_frames(movie, "action_attack"), 20:22)
  # Nothing is held while the demo loads, and no other action ever.
  expect_false(any(player(movie)[movie$timing$start_frame, ]))
  expect_identical(sum(colSums(player(movie)) > 0), 5L)
  expect_true(all(movie$commands == 0L))
})
test_that("the actions of Doom and of GoldSrc that are the same have one identity", {
  doom <- button_layout(read_movie(system.file("extdata", "sample.lmp", package = "replayr")))
  goldsrc <- button_layout(read_dem(dem_example()))
  expect_true(all(c("action:attack", "action:use") %in% doom$id))
  expect_true(all(doom$id %in% goldsrc$id))
  expect_identical(goldsrc$key[match(doom$id, goldsrc$id)], doom$key)
})
test_that("read_dem() returns the movement and the view angles a command asks for", {
  movie <- read_dem(dem_example())
  channels <- analog_channels(movie)
  expect_identical(colnames(channels), c(
    "forwardmove", "sidemove", "upmove", "view_pitch", "view_yaw", "view_roll", "impulse", "weaponselect", "msec"
  ))
  play <- which(!movie$timing$start_frame)
  frame <- movie$timing$frame[play]
  expect_equal(channels[play, "forwardmove"], 400 * (frame <= 15), ignore_attr = TRUE)
  expect_equal(channels[play, "sidemove"], 400 * (frame %in% 8:11), ignore_attr = TRUE)
  expect_true(all(channels[, "upmove"] == 0))
  # The player looks along 90 degrees, turns two degrees a frame in frames 8
  # to 15 and looks three degrees up while attacking.
  expect_equal(channels[play, "view_yaw"], 90 + 2 * pmax(0, pmin(frame, 15) - 7), ignore_attr = TRUE)
  expect_equal(channels[play, "view_pitch"], -3 * (frame %in% 20:22), ignore_attr = TRUE)
  expect_true(all(channels[, "view_roll"] == 0))
  expect_equal(channels[play, "impulse"], 100 * (frame == 23), ignore_attr = TRUE)
  expect_equal(channels[play, "weaponselect"], 2 * (frame == 23), ignore_attr = TRUE)
  expect_true(all(channels[play, "msec"] == 10))
  expect_true(all(channels[-play, ] == 0))
  # The turning asked for is the change of the angle.
  expect_identical(sum(diff(channels[play, "view_yaw"]) == 2), 8L)
})
test_that("read_dem() keeps sections, times, frame numbers and console commands", {
  movie <- read_dem(dem_example())
  sections <- movie$sections
  expect_identical(sections$description, c("LOADING", "Playback"))
  expect_identical(sections$type, 0:1)
  expect_identical(sections$command_frames, c(2L, 25L))
  expect_identical(sections$declared_frames, c(0L, 24L))
  expect_true(all(sections$complete))
  timing <- movie$timing
  expect_identical(timing$section, rep(1:2, c(2L, 25L)))
  expect_identical(timing$start_frame, rep(c(TRUE, FALSE), c(2L, 25L)))
  expect_identical(timing$frame, c(40L, 41L, 0:6, 6:23))
  expect_equal(timing$section_seconds, c(3.25, 3.5, c(0:6, 6:23) / 100), tolerance = 1e-6)
  # Time runs on from the loading section into the play.
  expect_equal(observation_time(movie), c(0, 0.25, 0.25 + c(0:6, 6:23) / 100), tolerance = 1e-6)
  expect_false(is.unsorted(observation_time(movie)))
  info <- recording_info(movie)
  expect_identical(info$platform, "PC")
  expect_equal(info$duration, 0.48, tolerance = 1e-6)
  expect_true(is.na(info$frame_rate))
  expect_identical(movie$header$mapName, "replayr_example")
  expect_identical(movie$header$gameDir, "valve")
  expect_identical(movie$header$networkProtocol, 48)
  expect_identical(movie$header$mapCrc, 305419896)
  spoken <- movie$console_commands
  expect_identical(spoken$command, c(
    "+forward", "+jump", "-jump", "+moveright", "-moveright", "+jump", "-jump", "-forward", "+duck",
    "-duck", "+attack", "-attack", "impulse 100"
  ))
  expect_identical(spoken$frame, c(0L, 4L, 6L, 8L, 12L, 12L, 14L, 16L, 16L, 20L, 20L, 23L, 23L))
  expect_identical(spoken$key_action, c(rep(TRUE, 12L), FALSE))
  # Selecting observations keeps their times.
  part <- movie[3:10]
  expect_identical(part$timing$frame, c(0:6, 6L))
  expect_identical(nrow(part$console_commands), 13L)
})
test_that("read_movie() recognises a GoldSrc demo by its signature", {
  expect_identical(read_movie(dem_example()), read_dem(dem_example()))
  directory <- tempfile("dem-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  renamed <- file.path(directory, "recording.bin")
  file.copy(dem_example(), renamed)
  expect_identical(replayr:::.sniff_format(renamed), "dem")
  expect_identical(n_observations(read_movie(renamed)), 27L)
  # Other engines write other files under this extension.
  source <- file.path(directory, "source.dem")
  writeBin(c(charToRaw("HL2DEMO"), raw(600)), source)
  expect_error(read_dem(source), "demo of the Source engine")
  quake <- file.path(directory, "quake.dem")
  writeLines("-1", quake)
  expect_error(read_movie(quake), "not a GoldSrc demo")
})
test_that("read_dem() refuses or reports what is not a complete demo", {
  bytes <- readBin(dem_example(), "raw", file.size(dem_example()))
  directory <- tempfile("dem-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  write <- function(x, name = "changed.dem") {
    path <- file.path(directory, name)
    writeBin(x, path)
    path
  }
  expect_error(read_dem(write(bytes[1:300])), "header of the demo is incomplete")
  other <- bytes
  other[9] <- as.raw(4L)
  expect_error(read_dem(write(other)), "demo protocol 4 is not supported")
  # A frame type that the format does not have.
  first <- 545L
  broken <- bytes
  broken[first] <- as.raw(10L)
  expect_error(read_dem(write(broken)), "invalid frame type 10")
  # A network message longer than the engine allows.
  long <- bytes
  long[first + 9L + 464L + 0:3] <- writeBin(70000L, raw(), size = 4L, endian = "little")
  expect_error(read_dem(write(long)), "invalid network message length 70000")
  # A directory that names no section.
  empty <- bytes
  empty[playback_directory <- sum(as.integer(bytes[541:544]) * c(1, 256, 65536, 16777216)) + 1:4] <- raw(4L)
  expect_error(read_dem(write(empty)), "directory of the demo is invalid")
  # A demo that was not closed: no directory, and the last frame cut off.
  playback <- sum(as.integer(bytes[541:544]) * c(1, 256, 65536, 16777216)) # offset of the directory
  open_end <- bytes[seq_len(playback - 9L - 200L)]
  open_end[541:544] <- raw(4L)
  warned <- character()
  movie <- withCallingHandlers(read_dem(write(open_end)), warning = function(w) {
    warned <<- c(warned, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_true(any(grepl("no directory of its sections", warned)))
  expect_true(any(grepl("end without their closing frame", warned)))
  # Every complete frame is there: all but the last one.
  expect_identical(n_observations(movie), 26L)
  expect_identical(movie$sections$command_frames, c(2L, 24L))
  expect_identical(movie$sections$complete, c(TRUE, FALSE))
  expect_identical(dem_frames(movie, "action_attack"), 20:22)
  # A file that was cut short: its header still names the place of the
  # directory, which the file no longer reaches.
  cut <- bytes[seq_len(playback - 9L - 200L)]
  expect_warning(expect_warning(shorter <- read_dem(write(cut)), "ends before the end of its directory"),
    "end without their closing frame")
  expect_identical(player(shorter), player(movie))
  expect_identical(shorter$sections$complete, c(TRUE, FALSE))
  # Cut within the directory: every frame is there.
  within <- bytes[seq_len(playback + 50L)]
  expect_warning(whole <- read_dem(write(within)), "ends before the end of its directory")
  expect_identical(player(whole), player(read_dem(dem_example())))
})
test_that("read_dem() reports a demo without commands of a player", {
  bytes <- readBin(dem_example(), "raw", file.size(dem_example()))
  movie <- read_dem(dem_example())
  expect_true(movie$header$playerCommands)
  # The same demo as a broadcast proxy records it: every command is empty.
  silent <- bytes
  for (offset in movie$sections$offset) {
    frames <- replayr:::.dem_walk(bytes, offset, dem_example())
    for (start in frames$start[frames$kind < 2L]) silent[start + 236 + 0:51] <- raw(52L)
  }
  path <- tempfile(fileext = ".dem")
  on.exit(unlink(path))
  writeBin(silent, path)
  expect_warning(quiet <- read_dem(path), "holds no commands of a player")
  expect_false(quiet$header$playerCommands)
  expect_identical(n_observations(quiet), 27L)
  expect_false(any(player(quiet)))
  expect_true(all(analog_channels(quiet) == 0))
})
test_that("read_dem() reads the longer frames of engines up to network protocol 43", {
  bytes <- readBin(dem_example(), "raw", file.size(dem_example()))
  int <- function(x) writeBin(as.integer(x), raw(), size = 4L, endian = "little")
  number <- function(at) sum(as.integer(bytes[at + 0:3]) * c(1, 256, 65536, 16777216))
  # The same demo as such an engine writes it: 560 bytes before the length of
  # a network message where the example has 464, with the command at 412
  # and 13 movement variables after it. Where the later layout has its
  # command there is filling, and the copy at 212 is left empty, so that only
  # the command at 412 gives the input back.
  directory <- number(541)
  count <- number(directory + 1)
  out <- bytes[1:544]
  out[13:16] <- int(43L)
  entries <- raw()
  for (i in seq_len(count)) {
    entry <- bytes[directory + 4 + 92 * (i - 1) + 1:92]
    walked <- replayr:::.dem_walk(bytes, number(directory + 4 + 92 * (i - 1) + 85), dem_example())
    begins <- walked$start - 9
    ends <- c(begins[-1] - 1, walked$end)
    section_start <- length(out)
    for (f in seq_along(begins)) {
      frame <- bytes[begins[f]:ends[f]]
      if (walked$kind[f] < 2L) {
        info <- frame[9 + 1:464]
        variables <- info[288 + 1:52]
        frame <- c(frame[1:9], info[1:4], as.raw(rep(0xAA, 208)), raw(52), variables, as.raw(rep(0xAA, 96)),
          info[236 + 1:52], variables, info[420 + 1:16], info[436 + 1:28], frame[-(1:473)])
      }
      out <- c(out, frame)
    }
    entry[85:88] <- int(section_start)
    entry[89:92] <- int(length(out) - section_start)
    entries <- c(entries, entry)
  }
  out[541:544] <- int(length(out))
  path <- tempfile(fileext = ".dem")
  on.exit(unlink(path))
  writeBin(c(out, int(count), entries), path)
  later <- read_dem(dem_example())
  older <- read_dem(path)
  expect_identical(older$header$networkProtocol, 43)
  expect_identical(file.size(path) - file.size(dem_example()), 96 * sum(later$sections$command_frames))
  expect_identical(player(older), player(later))
  expect_identical(analog_channels(older), analog_channels(later))
  expect_identical(older$timing, later$timing)
  expect_identical(older$console_commands, later$console_commands)
  expect_identical(older$sections$command_frames, later$sections$command_frames)
  # Read as a later engine writes its frames, the file falls apart.
  wrong <- out
  wrong[13:16] <- int(48L)
  writeBin(c(wrong, int(count), entries), path)
  expect_error(read_dem(path), "invalid")
})
