test_that("read_lmp errors clearly on missing file", {
  expect_error(replayr:::.decode_lmp(tempfile()), "File not found")
})
test_that("replayr:::.decode_lmp() parses the bundled synthetic Doom demo", {
  mv <- replayr:::.decode_lmp(fixture_path("sample.lmp"))
  expect_s3_class(mv, "replayr_movie")
  expect_identical(mv$header[["_format"]], "lmp")
  expect_equal(n_observations(mv), 2100L)
  expect_equal(n_players(mv), 4L)
  expect_equal(n_buttons(mv), 8L)
  expect_gt(sum(press_counts(mv, 1L)), 0L)
})
test_that("read_lmp rejects unsupported demo versions", {
  tf <- tempfile(fileext = ".lmp")
  on.exit(unlink(tf))
  for (version in c(5L, 103L, 112L, 199L, 215L, 220L, 222L, 254L)) {
    writeBin(c(as.raw(version), raw(13L)), tf)
    expect_error(read_lmp(tf), paste0("unsupported Doom demo version ", version))
  }
})

test_that("read_lmp rejects too-small files", {
  tmp <- tempfile(fileext = ".lmp")
  writeBin(as.raw(c(1, 2, 3, 4, 5)), tmp)
  expect_error(replayr:::.decode_lmp(tmp), "too small")
  unlink(tmp)
})
.mk_lmp <- function(records, active = c(1L, 0L, 0L, 0L), end = TRUE) {
  hdr <- as.raw(c(109, 0, 1, 1, 0, 0, 0, 0, 0, active))
  tf <- tempfile(fileext = ".lmp")
  bytes <- c(hdr, as.raw(records), if (end) as.raw(0x80L) else raw(0))
  writeBin(bytes, tf)
  tf
}
.lmp_file <- function(bytes) {
  tf <- tempfile(fileext = ".lmp")
  writeBin(as.raw(bytes), tf)
  tf
}
.lmp_rebuilt <- function(movie) {
  c(movie$source_header, as.vector(t(movie$source_packets)), as.raw(0x80), movie$source_tail)
}
.held <- function(movie, idx = 1L) {
  states <- player(movie, idx)
  matrix(states, nrow = nrow(states), dimnames = list(NULL, movie$button_keys))
}
test_that("replayr:::.decode_lmp() keeps movement as numbers and preserves BT_SPECIAL", {
  tf <- .mk_lmp(c(10, 251, 3, 0x81))
  on.exit(unlink(tf))
  mv <- replayr:::.decode_lmp(tf)
  # Forward 10, and 251 as a signed byte: 5 to the left.
  expect_equal(unname(mv$analog[[1L]][1L, c("forwardmove", "sidemove")]), c(10, -5))
  expect_false(mv$inputs[1L, 1L, 7L])
  expect_false(mv$inputs[1L, 1L, 8L])
  expect_equal(mv$commands, 0x81L)
  expect_equal(mv$header$angleturn[1L, 1L], 3L)
})
test_that("replayr:::.decode_lmp() rejects a truncated multiplayer tic", {
  tf <- .mk_lmp(c(0, 0, 0, 0, 1, 2), active = c(1L, 1L, 0L, 0L), end = FALSE)
  on.exit(unlink(tf))
  expect_error(replayr:::.decode_lmp(tf), "truncated Doom demo")
  writeBin(as.raw(c(109, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0x80)), tf)
  expect_error(read_lmp(tf), "truncated Doom demo in tic 1")
})

test_that("read_movie dispatches .lmp to read_lmp", {
  mv <- read_movie(fixture_path("sample.lmp"))
  expect_identical(mv$header[["_format"]], "lmp")
})
test_that("supported_formats() includes .lmp", {
  expect_true(".lmp" %in% supported_formats())
})
test_that("Doom actions have identities of their own", {
  mv <- read_lmp(fixture_path("sample.lmp"))
  layout <- button_layout(mv)
  expect_identical(layout$id, c("action:attack", "action:use"))
  expect_identical(layout$key, c("action_attack", "action_use"))
  expect_identical(layout$name, c("Attack", "Use"))
  expect_identical(layout$kind, c("action", "action"))
  expect_false(any(layout$id %in% button_layout()$id))
  expect_null(mv$source_layout)
})
.mk_boom <- function(version = 202L, compatibility = 0L, records = c(25, 231, 192, 1),
                     active = c(1L, 0L, 0L, 0L), tail = raw()) {
  options <- raw(if (version == 200L) 256L else 64L)
  options[7:9] <- as.raw(c(1, 0, 1))
  options[11:14] <- as.raw(c(1, 2, 3, 4))
  header <- c(as.raw(c(
    version, 0x1d, 0x42, 0x6f, 0x6f, 0x6d, 0xe6,
    compatibility, 3, 1, 2, 0, 0
  )), options, as.raw(active), raw(28))
  tf <- tempfile(fileext = ".lmp")
  writeBin(c(header, as.raw(records), as.raw(0x80), tail), tf)
  tf
}
test_that("Boom 2.00-2.02 preserves options, commands, and all active players", {
  paths <- character()
  on.exit(unlink(paths))
  records <- c(
    25, 231, 192, 1, 206, 50, 127, 2,
    0, 0, 0, 0x84, 1, 255, 128, 0x1c
  )
  for (version in 200:202) for (compatibility in 0:1) {
    tf <- .mk_boom(version, compatibility, records, c(1, 0, 1, 0), charToRaw("footer"))
    paths <- c(paths, tf)
    mv <- read_lmp(tf)
    expect_equal(n_observations(mv), 2L)
    expect_identical(mv$header$version, as.character(version))
    expect_identical(mv$header$emulator, "Boom")
    expect_identical(mv$header$compatibilityFlag, compatibility)
    expect_identical(mv$header$enabledPorts, c(1L, 3L))
    expect_identical(mv$source_tail, charToRaw("footer"))
    expect_equal(length(mv$source_header), if (version == 200L) 301L else 109L)
    expect_identical(as.vector(t(mv$source_packets)), as.raw(records))
    expect_equal(unname(analog_channels(mv, 1L)), matrix(c(25, -25, -64, 0, 0, 0), ncol = 3L, byrow = TRUE))
    expect_equal(unname(analog_channels(mv, 3L)), matrix(c(-50, 50, 127, 1, -1, -128), ncol = 3L, byrow = TRUE))
    expect_identical(mv$header$gameOptions[7:9], as.raw(c(1, 0, 1)))
    expect_identical(c(mv$header$respawnparm, mv$header$fastparm, mv$header$nomonsters), c("1", "0", "1"))
    expect_true(.held(mv, 1L)[1L, "action_attack"])
    expect_true(.held(mv, 3L)[1L, "action_use"])
    expect_false(any(player(mv, 1L)[2L, ]))
    expect_equal(mv$commands, c(0L, 0x84L))
    expect_equal(mv$header$weaponselect[2L, 3L], 3L)
  }
})
test_that("Boom validates signatures and lengths before reading commands", {
  tf <- .mk_boom()
  on.exit(unlink(tf))
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  bad <- bytes
  bad[3L] <- as.raw(0)
  writeBin(bad, tf)
  expect_error(read_lmp(tf), "signature")
  writeBin(bytes[1:100], tf)
  expect_error(read_lmp(tf), "truncated Doom demo header")
  writeBin(bytes[1:112], tf)
  expect_error(read_lmp(tf), "truncated Doom demo")
  writeBin(bytes[-length(bytes)], tf)
  expect_error(read_lmp(tf), "missing Doom demo end marker")
})
test_that("Doom 1.4 to 1.9, TASDoom and Doom 1.91 share one header and differ in the tic", {
  header <- c(2, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0)
  paths <- character()
  on.exit(unlink(paths))
  for (version in 104:109) {
    tf <- .lmp_file(c(version, header, 25, 251, 9, 1, 0x80))
    paths <- c(paths, tf)
    mv <- read_lmp(tf)
    expect_identical(mv$header$emulator, paste0("Doom 1.", c(4, 5, 666, 7, 8, 9)[version - 103L]))
    expect_equal(unname(analog_channels(mv)[1L, ]), c(25, -5, 9))
    expect_identical(unname(.held(mv)[1L, ]), c(TRUE, FALSE))
  }
  # TASDoom stores the buttons before the movement values.
  tf <- .lmp_file(c(110, header, 2, 25, 251, 9, 0x80))
  paths <- c(paths, tf)
  mv <- read_lmp(tf)
  expect_identical(mv$header$emulator, "TASDoom")
  expect_equal(unname(analog_channels(mv)[1L, ]), c(25, -5, 9))
  expect_identical(unname(.held(mv)[1L, ]), c(FALSE, TRUE))
  # Doom 1.91 stores both bytes of the turn, low byte first: 0xff40 is -192.
  tf <- .lmp_file(c(111, header, 25, 251, 0x40, 0xff, 3, 0, 0, 0x80, 0x00, 0, 0x80))
  paths <- c(paths, tf)
  mv <- read_lmp(tf)
  expect_identical(mv$header$emulator, "Doom 1.91")
  expect_true(mv$header$longtics)
  expect_equal(n_observations(mv), 2L)
  expect_equal(unname(analog_channels(mv)), rbind(c(25, -5, -0.75), c(0, 0, 0.5)))
  expect_identical(unname(.held(mv)[1L, ]), c(TRUE, TRUE))
  expect_identical(.lmp_rebuilt(mv), readBin(tf, "raw", n = 100L))
})
test_that("demos without a version byte need the game", {
  # Doom 1.2: skill, episode, map, four player bytes.
  tf <- .lmp_file(c(3, 1, 2, 1, 0, 0, 0, 25, 0, 2, 1, 0x80))
  on.exit(unlink(tf))
  expect_error(read_lmp(tf), "does not name its game")
  expect_error(read_movie(tf), "game = \"doom\"")
  mv <- read_movie(tf, game = "doom")
  expect_identical(mv$header$emulator, "Doom 1.2 or earlier")
  expect_identical(mv$header$game, "doom")
  expect_true(is.na(mv$header$version))
  expect_identical(c(mv$header$skill, mv$header$episode, mv$header$map), c("3", "1", "2"))
  expect_equal(unname(analog_channels(mv)[1L, ]), c(25, 0, 2))
  expect_identical(unname(.held(mv)[1L, ]), c(TRUE, FALSE))
  expect_error(read_lmp(tf, game = "hexen"), "truncated Doom demo header")
  expect_error(read_lmp(tf, game = "quake"), "should be one of")
  expect_error(read_lmp(.mk_lmp(c(0, 0, 0, 0)), game = "heretic"), "is a Doom layout")
  writeBin(as.raw(c(3, 1, 12, 1, 0, 0, 0, 25, 0, 2, 1, 0x80)), tf)
  expect_error(read_lmp(tf, game = "doom"), "invalid Doom demo header fields for game = \"doom\"")
})
test_that("Heretic demos add look, fly and artifact commands", {
  header <- c(2, 1, 4, 1, 0, 0, 0)
  tics <- c(
    25, 216, 3, 1, 0x23, 5,
    0, 0, 0, 2, 0x88, 0xff
  )
  tf <- .lmp_file(c(header, tics, 0x80))
  on.exit(unlink(tf))
  mv <- read_lmp(tf, game = "heretic")
  expect_identical(mv$header$emulator, "Heretic")
  expect_false(mv$header$longtics)
  expect_equal(n_players(mv), 4L)
  expect_identical(colnames(analog_channels(mv)), c("forwardmove", "sidemove", "angleturn", "look", "fly"))
  expect_equal(unname(analog_channels(mv)), rbind(c(25, -40, 3, 3, 2), c(0, 0, 0, -8, -8)))
  expect_identical(mv$header$artifact[, 1L], c(5L, 255L))
  expect_identical(button_layout(mv)$key, c("action_attack", "action_use"))
  expect_identical(unname(.held(mv)), rbind(c(TRUE, FALSE), c(FALSE, TRUE)))
  expect_identical(.lmp_rebuilt(mv), as.raw(c(header, tics, 0x80)))
  # Flags in the first player byte: 16-bit turning, respawn, no monsters.
  long <- c(
    25, 216, 0x00, 0x01, 1, 0x23, 5,
    0, 0, 0x80, 0xff, 2, 0x88, 0xff
  )
  writeBin(as.raw(c(2, 1, 4, 0x33, 1, 0, 0, long, long, 0x80, 7)), tf)
  mv <- read_lmp(tf, game = "heretic")
  expect_true(mv$header$longtics)
  expect_identical(c(mv$header$respawnparm, mv$header$nomonsters), c("1", "1"))
  expect_identical(mv$header$enabledPorts, 1:2)
  expect_equal(n_observations(mv), 2L)
  expect_equal(unname(analog_channels(mv, 2L)), rbind(c(0, 0, -0.5, -8, -8), c(0, 0, -0.5, -8, -8)))
  expect_equal(unname(analog_channels(mv, 1L)[, "angleturn"]), c(1, 1))
  expect_identical(mv$source_tail, as.raw(7))
  expect_error(read_lmp(tf, game = "heretic", longtics = FALSE), "marks 16-bit turning")
})
test_that("16-bit turning without the header flag is recognised and can be declared", {
  # Heretic+ and Hexen+ wrote 16-bit turning and left the header as it was.
  long <- c(
    25, 216, 0x00, 0x01, 1, 0x23, 5,
    0, 0, 0x80, 0xff, 2, 0x88, 0xff,
    0, 0, 0x10, 0x00, 0, 0x00, 0
  )
  tf <- .lmp_file(c(2, 1, 4, 1, 0, 0, 0, long, 0x80))
  on.exit(unlink(tf))
  expect_error(read_lmp(tf, game = "heretic"), "set longtics = TRUE")
  mv <- read_lmp(tf, game = "heretic", longtics = TRUE)
  expect_true(mv$header$longtics)
  expect_equal(n_observations(mv), 3L)
  expect_equal(unname(analog_channels(mv)[, "angleturn"]), c(1, -0.5, 0.0625))
  expect_identical(.lmp_rebuilt(mv), readBin(tf, "raw", n = 100L))
  expect_error(read_lmp(tf, game = "heretic", longtics = FALSE), "truncated Doom demo")
  # The same holds when the narrow reading meets a marker byte on its way.
  writeBin(as.raw(c(2, 1, 4, 1, 0, 0, 0, long[1:14], 0, 0, 0x10, 0x00, 0x80, 0, 0, 0x80)), tf)
  expect_error(read_lmp(tf, game = "heretic"), "set longtics = TRUE")
  expect_equal(n_observations(read_lmp(tf, game = "heretic", longtics = TRUE)), 3L)
  narrow <- read_lmp(tf, game = "heretic", longtics = FALSE)
  expect_equal(n_observations(narrow), 3L)
  expect_equal(length(narrow$source_tail), 3L)
  expect_error(read_lmp(fixture_path("sample.lmp"), longtics = TRUE), "settles its own turning width")
  expect_error(read_lmp(tf, game = "heretic", longtics = NA), "longtics must be")
})
test_that("Hexen demos have eight player slots, classes and a jump action", {
  header <- c(1, 1, 13, 1, 2, 1, 0, rep(0, 12))
  tics <- c(
    50, 0, 4, 1, 0x00, 0x80,
    0, 24, 0, 2, 0x01, 0x43
  )
  tf <- .lmp_file(c(header, tics, 0x80))
  on.exit(unlink(tf))
  mv <- read_lmp(tf, game = "hexen")
  expect_identical(mv$header$emulator, "Hexen")
  expect_equal(n_players(mv), 8L)
  expect_equal(n_observations(mv), 1L)
  expect_identical(mv$header$enabledPorts, 1:2)
  expect_identical(mv$header$playerClass[1:2], c(3L, 1L))
  expect_identical(mv$header$map, "13")
  expect_identical(button_layout(mv)$id, c("action:attack", "action:use", "action:jump"))
  expect_identical(unname(.held(mv, 1L)[1L, ]), c(TRUE, FALSE, TRUE))
  expect_identical(unname(.held(mv, 2L)[1L, ]), c(FALSE, TRUE, FALSE))
  expect_false(any(player(mv, 3L)))
  expect_identical(mv$header$artifact[1L, 1:2], c(0L, 3L))
  expect_identical(mv$header$suicide[1L, 1:2], c(FALSE, TRUE))
  expect_equal(unname(analog_channels(mv, 2L)[1L, ]), c(0, 24, 0, 1, 0))
  expect_identical(.lmp_rebuilt(mv), as.raw(c(header, tics, 0x80)))
  expect_error(read_lmp(tf, game = "heretic"), "invalid Doom demo header fields")
})
.mk_mbf <- function(version, records, options = NULL, signature = c(0x1d, 0x4d, 0x42, 0x46, 0xe6, 0x00),
                    extra = if (version == 221L) NULL else 0, wrap = NULL, tail = NULL,
                    comp = 25L) {
  if (is.null(options)) {
    options <- numeric(if (version == 221L) 21L + comp else 64L)
    options[if (version == 221L) 4:6 else 7:9] <- c(0, 1, 1)
    if (version == 221L) options[21L] <- comp
  }
  .lmp_file(c(
    wrap, version, signature, extra, 3, 1, 5, 0, 0, options,
    1, 1, 0, 0, numeric(28), records, 0x80, tail
  ))
}
test_that("LxDoom, MBF, PrBoom and MBF21 headers are told apart", {
  short <- c(25, 231, 192, 1, 206, 50, 127, 2)
  long <- c(25, 231, 0x00, 0xc0, 1, 206, 50, 0x80, 0x7f, 2)
  cases <- list(
    list(version = 203L, emulator = "MBF", long = FALSE, bytes = 109L),
    list(version = 210L, emulator = "PrBoom", long = FALSE, bytes = 109L),
    list(version = 213L, emulator = "PrBoom", long = FALSE, bytes = 109L),
    list(version = 214L, emulator = "PrBoom", long = TRUE, bytes = 109L),
    list(version = 221L, emulator = "MBF21", long = TRUE, bytes = 90L)
  )
  paths <- character()
  on.exit(unlink(paths))
  for (case in cases) {
    tf <- .mk_mbf(case$version, if (case$long) long else short, tail = charToRaw("x"))
    paths <- c(paths, tf)
    mv <- read_lmp(tf)
    expect_identical(mv$header$emulator, case$emulator)
    expect_identical(mv$header$longtics, case$long)
    expect_equal(length(mv$source_header), case$bytes)
    expect_identical(mv$header$enabledPorts, 1:2)
    expect_identical(c(mv$header$respawnparm, mv$header$fastparm, mv$header$nomonsters), c("0", "1", "1"))
    expect_identical(c(mv$header$skill, mv$header$map), c("3", "5"))
    expect_equal(unname(analog_channels(mv, 1L)[1L, ]), c(25, -25, -64))
    expect_equal(unname(analog_channels(mv, 2L)[1L, ]), c(-50, 50, if (case$long) 127.5 else 127))
    expect_identical(.lmp_rebuilt(mv), readBin(tf, "raw", n = 1000L))
  }
  # LxDoom wrote version 203 under Boom's signature, without the extra byte.
  tf <- .mk_mbf(203L, short, signature = c(0x1d, 0x42, 0x6f, 0x6f, 0x6d, 0xe6), extra = NULL)
  paths <- c(paths, tf)
  mv <- read_lmp(tf)
  expect_identical(mv$header$emulator, "LxDoom")
  expect_equal(length(mv$source_header), 108L)
  expect_equal(unname(analog_channels(mv, 2L)[1L, ]), c(-50, 50, 127))
  tf <- .mk_mbf(203L, short, signature = c(0x1d, 0x58, 0x6f, 0x6f, 0x6d, 0xe6))
  paths <- c(paths, tf)
  expect_error(read_lmp(tf), "invalid Doom demo signature")
  # MBF21 counts its compatibility options; early builds wrote 23 of them.
  tf <- .mk_mbf(221L, long, comp = 23L)
  paths <- c(paths, tf)
  mv <- read_lmp(tf)
  expect_equal(length(mv$source_header), 88L)
  expect_equal(length(mv$header$gameOptions), 44L)
  expect_equal(unname(analog_channels(mv, 2L)[1L, ]), c(-50, 50, 127.5))
  tf <- .mk_mbf(221L, long, comp = 26L)
  paths <- c(paths, tf)
  expect_error(read_lmp(tf), "unknown MBF21 compatibility options")
})
test_that("the outer headers of dsda-doom and PrBoom+um are read", {
  paths <- character()
  on.exit(unlink(paths))
  # PrBoom+um: one extension naming the map lump; the tics are unchanged.
  um <- c(255, utf8ToInt("PR+UM"), 0, 1, 1, 0, 8, utf8ToInt("UMAPINFO"), utf8ToInt("E1M5"), 0, 0, 0, 0)
  tf <- .mk_mbf(214L, c(25, 231, 0x00, 0xc0, 1, 206, 50, 0x80, 0x7f, 2), wrap = um)
  paths <- c(paths, tf)
  mv <- read_lmp(tf)
  expect_identical(mv$header$outerHeader, "PrBoom+um")
  expect_identical(mv$header$mapLump, "E1M5")
  expect_identical(mv$header$version, "214")
  expect_equal(length(mv$source_header), 27L + 109L)
  expect_equal(unname(analog_channels(mv, 1L)[1L, ]), c(25, -25, -64))
  expect_identical(.lmp_rebuilt(mv), readBin(tf, "raw", n = 1000L))
  # dsda-doom: every command is followed by a byte of extended commands, with
  # operands for save (0x02), load (0x04) and look (0x20); 0x01 is jump.
  dsda <- c(255, 0x1d, utf8ToInt("DSDA"), 0xe6, 3, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0)
  records <- c(
    25, 231, 0x00, 0xc0, 1, 0x01,
    0, 0, 0, 0, 2, 0x22, 7, 0x34, 0xff,
    0, 0, 0, 0, 0, 0x00,
    0, 0, 0, 0, 0, 0x04, 9
  )
  tf <- .mk_mbf(221L, records, wrap = dsda, tail = charToRaw("footer"))
  paths <- c(paths, tf)
  mv <- read_lmp(tf)
  expect_identical(mv$header$outerHeader, "dsda-doom")
  expect_identical(mv$header$emulator, "MBF21")
  expect_equal(mv$header$dsdaHeader$tics, 2)
  expect_identical(mv$header$dsdaHeader$flags, 2L)
  expect_equal(n_observations(mv), 2L)
  expect_identical(button_layout(mv)$id, c("action:attack", "action:use", "action:jump"))
  expect_identical(unname(.held(mv, 1L)), rbind(c(TRUE, FALSE, TRUE), c(FALSE, FALSE, FALSE)))
  expect_identical(unname(.held(mv, 2L)), rbind(c(FALSE, TRUE, FALSE), c(FALSE, FALSE, FALSE)))
  extended <- mv$header$extendedCommands
  expect_identical(extended$actions[, 1:2], rbind(c(0x01L, 0x22L), c(0x00L, 0x04L)))
  expect_identical(extended$saveSlot[1L, 2L], 7L)
  expect_identical(extended$look[1L, 2L], -204L)
  expect_identical(extended$loadSlot[2L, 2L], 9L)
  expect_identical(mv$source_tail, charToRaw("footer"))
  expect_identical(.lmp_rebuilt(mv), readBin(tf, "raw", n = 1000L))
  bytes <- readBin(tf, "raw", n = 1000L)
  writeBin(head(bytes, -8L), tf)
  expect_error(read_lmp(tf), "truncated Doom demo in tic 2")
  bytes[17L] <- as.raw(1)
  writeBin(bytes, tf)
  expect_error(read_lmp(tf), "keyframe")
  bytes[8L] <- as.raw(4)
  writeBin(bytes, tf)
  expect_error(read_lmp(tf), "unsupported dsda-doom demo header version 4")
  bytes[2L] <- as.raw(0)
  writeBin(bytes, tf)
  expect_error(read_lmp(tf), "unknown extended Doom demo header")
})
