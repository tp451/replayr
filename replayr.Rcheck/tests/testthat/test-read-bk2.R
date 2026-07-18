test_that("read_bk2() parses the bundled synthetic NES movie", {
  mv <- read_bk2(fixture_path("sample.bk2"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "bk2")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 1L)
  expect_equal(n_buttons(mv), 8L)
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

test_that("LogKey parser disambiguates the Nymashock PSX face buttons", {
  # Mednafen-family PSX cores name the face buttons with Unicode glyphs
  # (Triangle/Square/Circle) plus an ASCII "X" for Cross. The glyphs mark the
  # LogKey as PSX so "X" resolves to Cross (slot 7), not the SNES X-face (slot 9).
  parsed <- replayr:::.parse_bk2_logkey(paste0(
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Select|P1 Start|",
    "P1 △|P1 X|P1 □|P1 ○|P1 L1|P1 R1|"))
  slots <- vapply(parsed$btn_map[[1L]], function(e) e$slot, integer(1))
  expect_true(7L %in% slots)    # Cross -> slot 7 (disambiguated, not SNES X=9)
  expect_true(9L %in% slots)    # Triangle
  expect_true(10L %in% slots)   # Square
  expect_true(8L %in% slots)    # Circle
})

test_that("read_bk2() decodes a Nymashock PSX movie via its UTF-8 LogKey", {
  # Regression for the mojibake fix: the member must be read as UTF-8 so the
  # Triangle/Square/Circle glyphs survive and the PSX "X"=Cross disambiguation
  # fires. Read as latin1 (double-encoded) the glyphs garble, detection fails,
  # and Cross lands on the SNES X-face slot 9 instead of slot 7.
  td <- tempfile("nyma-"); dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)
  writeLines(c("GameName SynthNyma", "Core Nymashock", "Platform PSX"),
             file.path(td, "Header.txt"))
  log <- paste0(
    "[Input]\n",
    "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Select|P1 Start|",
    "P1 △|P1 X|P1 □|P1 ○|P1 L1|P1 R1|\n",
    "|..|.......X....|\n",   # column 8 = Cross pressed
    "|..|............|\n")
  writeBin(charToRaw(enc2utf8(log)), file.path(td, "Input Log.txt"))
  bk2 <- tempfile(fileext = ".bk2"); on.exit(unlink(bk2), add = TRUE)
  old <- setwd(td)
  zipped <- tryCatch({ utils::zip(bk2, c("Header.txt", "Input Log.txt"),
                                  flags = "-q"); TRUE }, error = function(e) FALSE)
  setwd(old)
  skip_if_not(zipped && file.exists(bk2) && file.info(bk2)$size > 0,
              "zip tool unavailable to build synthetic .bk2")
  mv <- read_bk2(bk2)
  expect_true(mv$inputs[1, 1, 7])    # Cross on slot 7 (B)
  expect_false(mv$inputs[1, 1, 9])   # NOT the SNES X-face slot 9
})

test_that("BK2 PSX analog axes use unsigned 128-centred values", {
  log <- paste0(
    "[Input]\n",
    "LogKey:#Reset|Power|#P1 LStick X|P1 LStick Y|P1 Up|\n",
    "|..|0,128,.|\n"
  )
  mv <- replayr:::.parse_bk2_input_log(
    log,
    header = list("_format" = "bk2", Platform = "PSX", Core = "Nymashock")
  )
  expect_true(mv$inputs[1L, 1L, 25L]) # X=0 is full west, not neutral
})

test_that("BK2 does not reinterpret a sparse LogKey as NES columns", {
  log <- paste0(
    "[Input]\n",
    "LogKey:#Reset|Power|#P1 Unknown One|P1 Unknown Two|P1 Up|\n",
    "|..|..U|\n"
  )
  expect_error(replayr:::.parse_bk2_input_log(log), "too sparse")
})
