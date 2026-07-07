test_that("read_fm2() parses a small NES movie", {
  skip_if_no_fixture("sample.fm2")
  mv <- read_fm2(fixture_path("sample.fm2"))
  expect_s3_class(mv, "replayr_movie")
  expect_gt(n_frames(mv), 100L)
  expect_equal(n_buttons(mv), 8L)
  # NES Tetris uses the d-pad and a/b heavily; nothing fancy in the
  # commands array.
  pc <- press_counts(mv, 1L)
  expect_true(any(pc > 0L))
  expect_named(pc)
})

test_that("read_movie() dispatches by extension", {
  skip_if_no_fixture("sample.fm2")
  mv <- read_movie(fixture_path("sample.fm2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], NULL)  # FM2 doesn't set _format
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
  expect_true(mv$inputs[3L, 1L, 1L])  # R
  expect_false(mv$inputs[3L, 1L, 2L]) # L unset on P1
  expect_true(mv$inputs[3L, 2L, 2L])  # L set on P2
})
