# Gym Retro writes BK2 files whose input log names the controls in a line
# without the LogKey prefix and its Reset and Power group, while every row
# has that group (openai/retro, src/movie-bk2.cpp). The files here are laid
# out as that writer lays them out.
retro_bk2 <- function(rows, version = "MovieVersion Retro",
                      names = "P1 Z|P1 X|P1 Y|P1 C|P1 Right|P1 Left|P1 Down|P1 Up|P1 Start|P1 Mode|P1 A|P1 B|",
                      platform = "GEN") {
  directory <- tempfile("retro-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  writeLines(c(version, "Author ?", "emuVersion ?", paste("Platform", platform),
    "GameName SonicTheHedgehog-Genesis", "SHA1 ?", "Core ?", "rerecordCount 1"), file.path(directory, "Header.txt"))
  writeLines(c("[Input]", names, rows, "[/Input]"), file.path(directory, "Input Log.txt"))
  writeBin(as.raw(1:4), file.path(directory, "Core.bin"))
  path <- tempfile(fileext = ".bk2")
  zip::zipr(path, c("Input Log.txt", "Header.txt", "Core.bin"), root = directory)
  path
}
test_that("read_bk2() reads a recording as Gym Retro writes it", {
  path <- retro_bk2(c("|..|............|", "|..|.X.....U..A.|", "|..|....R.....AB|"))
  on.exit(unlink(path))
  movie <- read_bk2(path)
  expect_identical(n_observations(movie), 3L)
  expect_identical(n_players(movie), 1L)
  expect_setequal(button_layout(movie)$key,
    c("dpad_right", "dpad_left", "dpad_down", "dpad_up", "start", "mode", "a", "b", "c", "x", "y", "z"))
  states <- player(movie)
  pressed <- function(row) colnames(states)[states[row, ]]
  expect_identical(pressed(1L), character())
  expect_setequal(pressed(2L), c("x", "dpad_up", "a"))
  expect_setequal(pressed(3L), c("dpad_right", "a", "b"))
  # The group of two characters before the pad is Reset and Power.
  expect_identical(names(system_channels(movie)), c("reset", "power"))
  expect_false(any(as.matrix(system_channels(movie))))
  expect_match(movie$header$logKeyRestored, "Gym Retro")
  expect_identical(recording_info(movie)$platform, "GEN")
  expect_identical(read_movie(path), movie)
  # In chunks the same states come back.
  parts <- read_bk2_chunks(path, function(chunk) player(chunk), chunk_size = 2L)
  expect_identical(attr(parts, "observations"), 3)
  expect_equal(do.call(rbind, parts), states, ignore_attr = TRUE)
})
test_that("two players of a Gym Retro recording are told apart by their names", {
  both <- paste0(
    "P1 Z|P1 X|P1 Y|P1 C|P1 Right|P1 Left|P1 Down|P1 Up|P1 Start|P1 Mode|P1 A|P1 B|",
    "P2 Z|P2 X|P2 Y|P2 C|P2 Right|P2 Left|P2 Down|P2 Up|P2 Start|P2 Mode|P2 A|P2 B|"
  )
  path <- retro_bk2("|..|Z...........|...........B|", names = both)
  on.exit(unlink(path))
  movie <- read_bk2(path)
  expect_identical(n_players(movie), 2L)
  expect_identical(colnames(player(movie, 1L))[player(movie, 1L)[1L, ]], "z")
  expect_identical(colnames(player(movie, 2L))[player(movie, 2L)[1L, ]], "b")
})
test_that("a pad recorded by Gym Retro has the IDs it has in a BizHawk recording", {
  held <- function(path) {
    movie <- read_bk2(path)
    states <- player(movie)
    layout <- button_layout(movie)
    keys <- lapply(seq_len(nrow(states)), function(i) sort(colnames(states)[states[i, ]]))
    list(movie = movie, keys = keys, ids = lapply(keys, function(k) layout$id[match(k, layout$key)]))
  }
  # Gym Retro lists the controls of a platform from the last to the first
  # and writes the name of its core where it has no code for the platform.
  # Master System: the core's B is button 1 and its A is button 2.
  sms <- retro_bk2(c("|..|.....B|", "|..|A.....|", "|..|.R.D..|"),
    names = "P1 A|P1 Right|P1 Left|P1 Down|P1 Up|P1 B|", platform = "Sms")
  on.exit(unlink(sms))
  ours <- held(sms)
  expect_identical(ours$keys, list("a", "b", c("dpad_down", "dpad_right")))
  expect_identical(recording_info(ours$movie)$platform, "SMS")
  expect_false(is.na(recording_info(ours$movie)$frame_rate))
  # The same three states as BizHawk writes them.
  directory <- tempfile("bizhawk-")
  dir.create(directory)
  writeLines(c("MovieVersion BizHawk v2.0.0", "Platform SMS", "GameName Some Game"),
    file.path(directory, "Header.txt"))
  writeLines(c("[Input]", "LogKey:#Reset|Pause|#P1 Up|P1 Down|P1 Left|P1 Right|P1 B1|P1 B2|#P2 Up|",
    "|..|....1.|.|", "|..|.....2|.|", "|..|.D.R..|.|", "[/Input]"), file.path(directory, "Input Log.txt"))
  bizhawk <- tempfile(fileext = ".bk2")
  zip::zipr(bizhawk, c("Input Log.txt", "Header.txt"), root = directory)
  on.exit(unlink(c(bizhawk, directory), recursive = TRUE), add = TRUE)
  expect_identical(held(bizhawk)$ids, ours$ids)
  # Shoulder buttons and directions of a Super Nintendo pad share letters.
  snes <- retro_bk2("|..|r....L......|", platform = "SNES",
    names = "P1 R|P1 L|P1 X|P1 A|P1 Right|P1 Left|P1 Down|P1 Up|P1 Start|P1 Select|P1 Y|P1 B|")
  on.exit(unlink(snes), add = TRUE)
  expect_identical(held(snes)$keys[[1L]], c("dpad_left", "r1"))
  # A Game Boy recording is given under the name of the core.
  handheld <- retro_bk2("|..|A......B|", platform = "GameBoy",
    names = "P1 A|P1 Right|P1 Left|P1 Down|P1 Up|P1 Start|P1 Select|P1 B|")
  on.exit(unlink(handheld), add = TRUE)
  info <- recording_info(read_bk2(handheld))
  expect_identical(info$platform, "GB")
  expect_equal(info$frame_rate, 262144 / 4389)
})
test_that("only a Gym Retro recording has its key line restored", {
  path <- retro_bk2("|..|............|", version = "MovieVersion BizHawk v2.0.0")
  on.exit(unlink(path))
  expect_error(read_bk2(path), "no LogKey line")
})
