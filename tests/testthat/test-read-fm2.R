test_that("replayr:::.decode_fm2() parses the bundled synthetic NES movie", {
  mv <- replayr:::.decode_fm2(fixture_path("sample.fm2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(n_observations(mv), 3600L)
  expect_equal(n_players(mv), 2L)
  expect_equal(n_buttons(mv), 8L)
  pc <- press_counts(mv, 1L)
  expect_true(any(pc > 0L))
  # The keys, and with them the names, are assigned when the reader configures
  # the decoded movie.
  expect_named(press_counts(read_fm2(fixture_path("sample.fm2")), 1L), button_layout()$key[1:8])
})
test_that("read_movie() dispatches by extension", {
  mv <- read_movie(fixture_path("sample.fm2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "fm2") # FM2 doesn't set _format
})
test_that("malformed FM2 lines are tolerated", {
  text <- c(
    "version 3",
    "emuVersion 22020",
    "romFilename Test.nes",
    "comment first comment",
    "comment second comment",
    "|0|RLDUTSBA|........||",
    "|0|........|RLDUTSBA||",
    "|0|R..UT.BA|.LD..S..||",
    ""
  )
  mv <- replayr:::.parse_fm2_text(text)
  expect_equal(n_observations(mv), 3L)
  expect_equal(n_players(mv), 2L)
  expect_equal(n_buttons(mv), 8L)
  # Comment is merged with newlines.
  expect_equal(mv$header$comment, "first comment\nsecond comment")
  # Frame 0: P1 holds every button, P2 holds none.
  expect_true(all(mv$inputs[1L, 1L, ]))
  expect_false(any(mv$inputs[1L, 2L, ]))
  # Frame 2: third frame shows asymmetric column parsing.
  expect_true(mv$inputs[3L, 1L, 1L]) # R
  expect_false(mv$inputs[3L, 1L, 2L]) # L unset on P1
  expect_true(mv$inputs[3L, 2L, 2L]) # L set on P2
})
test_that("replayr:::.decode_fm2() tolerates non-UTF-8 header bytes", {
  # Metadata can contain non-UTF-8 bytes. Verify that fallback decoding
  # preserves the input log and leaves valid UTF-8 author names unchanged.
  tmp <- tempfile(fileext = ".fm2")
  on.exit(unlink(tmp), add = TRUE)
  con <- file(tmp, "wb")
  writeBin(charToRaw("version 3\n"), con)
  writeBin(charToRaw("emuVersion 22020\n"), con)
  # `romFilename ` + raw Shift-JIS bytes (invalid as UTF-8) + newline.
  writeBin(c(
    charToRaw("romFilename "), as.raw(c(0xe5, 0xbf, 0xcb, 0x33)),
    charToRaw("\n")
  ), con)
  writeBin(charToRaw("comment André\n"), con) # valid UTF-8, must survive
  writeBin(charToRaw("|0|RLDUTSBA|........||\n"), con)
  writeBin(charToRaw("|0|........|RLDUTSBA||\n"), con)
  close(con)
  expect_no_warning(mv <- replayr:::.decode_fm2(tmp))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(n_observations(mv), 2L)
  expect_equal(n_buttons(mv), 8L)
  expect_true(all(mv$inputs[1L, 1L, ])) # P1 holds every button
  expect_equal(mv$header$comment, "André") # valid UTF-8 preserved
})
test_that("an FM2 position is pressed whatever character marks it", {
  # FCEUX reads any character other than '.' or a space as pressed.
  lines <- c("version 3", "port0 1", "port1 0", "port2 0",
             "|0|L..U....|||", "|0|. X.....|||", "|0|R......A|||")
  movie <- replayr:::.parse_fm2_text(lines)
  held <- movie$inputs[, 1L, ]
  expect_identical(which(held[1L, ]), c(1L, 4L))
  expect_identical(which(held[2L, ]), 3L)
  expect_identical(which(held[3L, ]), c(1L, 8L))
})
test_that("an FM2 port declared empty is no controller", {
  # FCEUX leaves the field of an empty port blank; the pad sits on port 1.
  lines <- c("version 3", "port0 0", "port1 1", "port2 0",
             "|0||RLDUTSBA||", "|0||.......A||")
  movie <- replayr:::.parse_fm2_text(lines)
  expect_identical(n_players(movie), 1L)
  expect_identical(movie$header$controllerPorts, 2L)
  expect_true(all(movie$inputs[1L, 1L, ]))
  expect_identical(which(movie$inputs[2L, 1L, ]), 8L)
  both <- replayr:::.parse_fm2_text(c("version 3", "port0 1", "port1 1",
                                      "|0|R.......|.......A||"))
  expect_identical(n_players(both), 2L)
  expect_identical(both$header$controllerPorts, 1:2)
})
