test_that("read_bk2() parses an Atari 2600 movie", {
  skip_if_no_fixture("sample.bk2")
  mv <- read_bk2(fixture_path("sample.bk2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "bk2")
  expect_gt(n_frames(mv), 0L)
  expect_gte(n_buttons(mv), 8L)
  # Atari 2600 controllers expose at least the d-pad (slots 1..4) and
  # the Fire/Button slot (slot 8 in our universal layout).
  pc <- press_counts(mv, 1L)
  expect_true(sum(pc) > 0L)
})

test_that("read_bk2() tolerates a NUL-padded Header.txt field", {
  # Some Gambatte-core Game Boy movies write `BoardName NULL\0\0...` as a
  # fixed-width NUL-padded field; rawToChar() used to abort on the embedded
  # NUL. Kwirk is the canonical example.
  fp <- external_fixture("raw_gb/kwirk/3755.bk2")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable the NUL-header test")
  mv <- read_bk2(fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "bk2")
  expect_gt(n_frames(mv), 0L)
  expect_gt(sum(press_counts(mv, 1L)), 0L)
})

test_that("LogKey parser handles the NES single-group case correctly", {
  # Synthetic GB-shaped LogKey (single group, no P1 prefix).
  parsed <- replayr:::.parse_bk2_logkey(
    "LogKey:#Up|Down|Left|Right|Start|Select|B|A|Power|"
  )
  expect_length(parsed$btn_map, 1L)
  # All eight buttons map to slots 1..8 (in some order).
  slots <- vapply(parsed$btn_map[[1L]], function(e) e$slot, integer(1))
  expect_setequal(slots, 1:8)
})

test_that("LogKey parser separates command group from player groups", {
  # Multi-group NES LogKey (FCEUX-style).
  parsed <- replayr:::.parse_bk2_logkey(
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|"
  )
  expect_equal(parsed$commands, c("Reset", "Power"))
  expect_length(parsed$btn_map, 1L)
  slots <- vapply(parsed$btn_map[[1L]], function(e) e$slot, integer(1))
  expect_setequal(slots, 1:8)
})
