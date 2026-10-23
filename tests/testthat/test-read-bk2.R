# A BizHawk log is read by the names of its LogKey. These tests give the
# reader small logs and check the controls by their keys.
bk2_log <- function(..., header = list()) {
  header <- utils::modifyList(list("_format" = "bk2"), header)
  replayr:::.parse_bk2_input_log(paste(c(...), collapse = "\n"), header)
}
bk2_pressed <- function(movie, row = 1L, idx = 1L, analog = "raw") {
  states <- player(replayr:::.configure_movie(movie, analog = analog), idx)
  colnames(states)[states[row, ]]
}
test_that("read_bk2() reads the bundled synthetic NES movie", {
  mv <- read_bk2(fixture_path("sample.bk2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "bk2")
  expect_equal(n_observations(mv), 3600L)
  expect_equal(n_players(mv), 1L)
  expect_equal(n_buttons(mv), 8L)
  expect_true(sum(press_counts(mv, 1L)) > 0L)
})
test_that("a LogKey of one group gives a pad and the controls of the system", {
  # A Game Boy LogKey: one group, no P1 prefix.
  movie <- replayr:::.configure_movie(bk2_log(
    "LogKey:#Up|Down|Left|Right|Start|Select|B|A|Power|", "|U......A.|",
    header = list(Platform = "GB")
  ))
  expect_setequal(button_layout(movie)$key,
    c("dpad_up", "dpad_down", "dpad_left", "dpad_right", "start", "select", "b", "a"))
  expect_identical(names(system_channels(movie)), "power")
  expect_setequal(colnames(player(movie))[player(movie)[1L, ]], c("dpad_up", "a"))
})
test_that("the group of system controls is kept apart from the players' groups", {
  movie <- replayr:::.configure_movie(bk2_log(
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|", "|..|U......A|",
    header = list(Platform = "NES")
  ))
  expect_identical(names(system_channels(movie)), c("reset", "power"))
  expect_identical(n_buttons(movie), 8L)
  expect_identical(movie$commands, 0L)
})
test_that("the PlayStation face buttons of Nymashock take the identities of their places", {
  # Mednafen-family PSX cores name the face buttons with Unicode glyphs
  # (Triangle, Square, Circle) plus an ASCII "X" for Cross. Cross is the lower
  # button and has the identity of B, not that of the SNES button X.
  movie <- replayr:::.configure_movie(bk2_log(
    paste0(
      "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Select|P1 Start|",
      "P1 △|P1 X|P1 □|P1 ○|P1 L1|P1 R1|"
    ),
    "|..|.......X....|",
    header = list(Platform = "PSX", Core = "Nymashock")
  ))
  layout <- button_layout(movie)
  expect_identical(layout$key[match(c("X", "○", "△", "□"), layout$name)], c("b", "a", "x", "y"))
  expect_identical(colnames(player(movie))[player(movie)[1L, ]], "b")
})
test_that("read_bk2() decodes a Nymashock PSX movie via its UTF-8 LogKey", {
  td <- tempfile("nyma-")
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  writeLines(
    c("GameName SynthNyma", "Core Nymashock", "Platform PSX"),
    file.path(td, "Header.txt")
  )
  log <- paste0(
    "[Input]\n",
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Select|P1 Start|",
    "P1 △|P1 X|P1 □|P1 ○|P1 L1|P1 R1|\n",
    "|..|.......X....|\n", # column 8 = Cross pressed
    "|..|............|\n"
  )
  writeBin(charToRaw(enc2utf8(log)), file.path(td, "Input Log.txt"))
  bk2 <- tempfile(fileext = ".bk2")
  on.exit(unlink(bk2), add = TRUE)
  zip::zipr(bk2, c("Header.txt", "Input Log.txt"), root = td)
  mv <- read_bk2(bk2)
  expect_identical(unname(player(mv)[, "b"]), c(TRUE, FALSE)) # Cross
  expect_false(any(player(mv)[, "x"])) # not the button in the place of SNES X
})
test_that("BK2 PSX analog axes use unsigned 128-centred values", {
  movie <- bk2_log(
    "[Input]", "LogKey:#Reset|Power|#P1 LStick X|P1 LStick Y|P1 Up|", "|..|0,128,.|",
    header = list(Platform = "PSX", Core = "Nymashock")
  )
  # X = 0 is full west, not neutral.
  expect_identical(bk2_pressed(movie, analog = "cardinal8"), "left_w")
})
test_that("controls without a shared identity keep the name of the log", {
  movie <- bk2_log("[Input]", "LogKey:#Reset|Power|#P1 Unknown One|P1 Unknown Two|P1 Up|", "|..|..U|")
  expect_setequal(button_layout(replayr:::.configure_movie(movie))$key,
    c("dpad_up", "bk2_unknown_one", "bk2_unknown_two"))
  expect_identical(bk2_pressed(movie), "dpad_up")
  # An active control of that kind is kept, not dropped.
  other <- bk2_log("[Input]", "LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Other|", "|..|..X|")
  expect_identical(bk2_pressed(other), "bk2_other")
})
test_that("NES paddle positions are kept beside Fire", {
  movie <- replayr:::.configure_movie(bk2_log(
    "[Input]", "LogKey:#Power|Reset|#P1 Paddle|P1 Fire|",
    "|..|80,F|", "|..|160,.|", "|..|160,F|", "|..|0,.|", "|..|1,.|", "|..|1,.|", "[/Input]",
    header = list(Platform = "NES")
  ))
  expect_identical(unname(analog_channels(movie)[, "paddle"]), c(80, 160, 160, 0, 1, 1))
  expect_identical(which(unname(player(movie)[, "a"])), c(1L, 3L))
})
test_that("a numeric field that the LogKey does not declare is an error", {
  expect_error(
    bk2_log("[Input]", "LogKey:#Power|Reset|#P1 Up|P1 Fire|", "|..|80,F.|"),
    "unconsumed numeric field"
  )
})
test_that("long-form PSX axes, stick buttons and Analog have distinct types", {
  key <- paste0(
    "LogKey:#Power|Reset|#P1 Left Stick Up / Down|P1 Left Stick Left / Right|",
    "P1 Right Stick Up / Down|P1 Right Stick Left / Right|P1 Up|P1 Down|",
    "P1 Left Stick, Button|P1 Right Stick, Button|P1 Analog|"
  )
  for (version in c("Version 2.8", "Version 2.9", "Version 2.10")) {
    # Nymashock 2.8 logs 16-bit axes, later versions 8-bit ones.
    center <- if (version == "Version 2.8") 32768L else 128L
    movie <- bk2_log(key, paste0("|..|", center, ",0,0,", center, ",..<>A|"),
      header = list(Platform = "PSX", Core = "Nymashock", emuVersion = version))
    expect_setequal(bk2_pressed(movie, analog = "cardinal8"), c("l3", "r3", "mode", "left_w", "right_n"))
  }
  expect_error(
    bk2_log(key, "|..|32768,32768,32768,32768,.....|",
      header = list(Platform = "PSX", Core = "Nymashock", emuVersion = "Version 2.10")),
    "outside declared encoding"
  )
})
test_that("BK2 obeys ordered controls across irregular boundaries like BizHawk", {
  key <- paste0(
    "LogKey:#Disc Select|Open|Close|Reset|",
    "#P1 Up|P1 Down|P1 Left|P1 Right|#P2 Up|P2 Down|P2 Left|P2 Right|"
  )
  # The fifth P1 display character is actually consumed as P2 Up.
  expect_no_warning(movie <- bk2_log(key, "||    1,...|...RZ|...|", header = list(Platform = "PSX")))
  expect_identical(bk2_pressed(movie, idx = 1L), "dpad_right")
  expect_identical(bk2_pressed(movie, idx = 2L), "dpad_up")
  expect_equal(movie$commands, 0L)
  expect_equal(movie$header$logKeyStreamBoundarySamples, 1L)
})
test_that("BK2 trailing unbound controls are recorded as unconsumed, not invented players", {
  key <- paste0(
    "LogKey:#Power|Reset|#P1 Up|P1 Down|P1 Left|P1 Right|",
    "P1 A|P1 B|P1 C|P1 Start|"
  )
  expect_warning(
    movie <- bk2_log(key, "|..|...R..C...Z.|............|", "|..|...R..C.|", header = list(Platform = "GEN")),
    "trailing source text resembling unbound controls in 1 samples"
  )
  expect_equal(n_players(movie), 1L)
  expect_setequal(bk2_pressed(movie, row = 1L), c("dpad_right", "c"))
  expect_setequal(bk2_pressed(movie, row = 2L), c("dpad_right", "c"))
  expect_equal(movie$header$unconsumedTrailingActiveSamples, 1L)
})
test_that("controls without a port prefix keep their full name", {
  movie <- bk2_log("LogKey:#D-Pad Up|D-Pad Down|Left Stick, Button|", "|U.<|")
  expect_setequal(button_layout(replayr:::.configure_movie(movie))$key, c("dpad_up", "dpad_down", "l3"))
  expect_setequal(bk2_pressed(movie), c("dpad_up", "l3"))
})
test_that("numeric reset timing does not consume player button positions", {
  for (control in c("Reset Instruction", "Reset Cycle")) {
    movie <- bk2_log(paste0("LogKey:#", control, "|Power|Reset|#P1 Up|P1 Down|"), "|    0,..|U.|",
      header = list(Platform = "NES"))
    expect_identical(bk2_pressed(movie), "dpad_up")
    expect_equal(movie$commands, 0L)
  }
})
test_that("a concatenated PSX suffix is flagged without inventing a second frame", {
  key <- "LogKey:#Disc Select|Open|Close|Reset|#P1 Up|P1 Down|"
  expect_warning(
    movie <- bk2_log(key, "|    1,...|U.|..............||    1,...|.D|", header = list(Platform = "PSX")),
    "trailing source text"
  )
  expect_equal(n_observations(movie), 1L)
  expect_identical(bk2_pressed(movie), "dpad_up")
})
test_that("Octoshock follows its byte cast rather than clamping logged axes", {
  key <- "LogKey:#Disc Select|Open|Close|Reset|#P1 LStick X|P1 LStick Y|P1 Cross|"
  rows <- c("|    1,...|128,256,.|", "|    1,...|-1,128,X|")
  expect_warning(
    movie <- bk2_log(key, rows, header = list(Platform = "PSX", Core = "Octoshock", emuVersion = "Version 1.11.7")),
    "byte conversion applied to 2"
  )
  # 256 becomes 0 (up) and -1 becomes 255 (right).
  expect_identical(bk2_pressed(movie, row = 1L, analog = "cardinal8"), "left_n")
  expect_setequal(bk2_pressed(movie, row = 2L, analog = "cardinal8"), c("b", "left_e"))
  expect_equal(movie$header$octoshockByteWrappedAxisValues, 2L)
  expect_error(
    bk2_log(key, rows, header = list(Platform = "PSX", Core = "Nymashock", emuVersion = "Version 2.10")),
    "outside declared encoding"
  )
})
test_that("read_bk2() says which hash BizHawk wrote under SHA1", {
  # Older archives name their members without .txt, as here.
  bk2 <- function(sha1) {
    directory <- tempfile("bk2-")
    dir.create(directory)
    on.exit(unlink(directory, recursive = TRUE))
    writeLines(c("MovieVersion BizHawk v2.0", "Platform GEN", paste("SHA1", sha1)), file.path(directory, "Header"))
    writeLines(c("[Input]", "LogKey:#P1 Up|P1 Down|", "|..|", "|U.|", "[/Input]"), file.path(directory, "Input Log"))
    path <- tempfile(fileext = ".bk2")
    zip::zipr(path, c("Header", "Input Log"), root = directory)
    path
  }
  cases <- c(
    "6DB8FA65755DB86438ADA3D90F4C39CC288DCF84" = "SHA1",
    "5E332FBFC1E0FC74223D2E73271CE650" = "MD5",
    "838837D4" = "CRC32",
    "N/A" = ""
  )
  for (sha1 in names(cases)) {
    path <- bk2(sha1)
    movie <- read_bk2(path)
    unlink(path)
    expect_identical(movie$header$SHA1, sha1)
    expect_identical(movie$header$SHA1Kind, cases[[sha1]])
    expect_identical(n_observations(movie), 2L)
  }
})
