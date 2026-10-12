test_that("replayr:::.decode_fm2() parses the bundled synthetic NES movie", {
  mv <- replayr:::.decode_fm2(fixture_path("sample.fm2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 2L)
  expect_equal(n_buttons(mv), 8L)
  pc <- press_counts(mv, 1L)
  expect_true(any(pc > 0L))
  expect_named(pc)
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
    "|0|RR.UT.BA|.LD..S..||",
    ""
  )
  mv <- replayr:::.parse_fm2_text(text)
  expect_equal(n_frames(mv), 3L)
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
  expect_equal(n_frames(mv), 2L)
  expect_equal(n_buttons(mv), 8L)
  expect_true(all(mv$inputs[1L, 1L, ])) # P1 holds every button
  expect_equal(mv$header$comment, "André") # valid UTF-8 preserved
})
