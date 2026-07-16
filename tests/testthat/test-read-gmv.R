test_that("read_gmv() parses a Genesis movie", {
  skip_if_no_fixture("sample.gmv")
  mv <- read_gmv(fixture_path("sample.gmv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "gmv")
  expect_gt(n_frames(mv), 0L)
  # Genesis controllers are 15 buttons wide in our universal layout
  # (slots 1..4 d-pad, 5 Start, 7/8 B/A, 9/10 X/Y, 13 C, 14 Z, 15 Mode).
  expect_equal(n_buttons(mv), 15L)
  expect_equal(n_players(mv), 2L)
})

test_that("read_gmv() maps the three face bits to BizHawk-consistent slots", {
  # Regression for the face-button rotation fix. A 3-button Gens .gmv is a
  # 64-byte header + 3 bytes/frame (P1, P2, 6-button extras), active-LOW (a bit
  # CLEAR means pressed). The Gens "SACBRLDU" spec labels face bits 4/5/6 B/C/A,
  # but they are the PHYSICAL A/B/C buttons -> universal slots 8/7/13, so a
  # game's attack/jump/magic decode identically from .gmv and BizHawk .bk2.
  hdr <- raw(64)
  hdr[1:15] <- charToRaw("Gens Movie TEST"); hdr[16] <- charToRaw("A")
  hdr[21]   <- charToRaw("6"); hdr[22] <- charToRaw("3")   # NTSC, 3-button pads
  fr <- function(p1) as.raw(c(p1, 0xFF, 0xFF))             # P1, P2 (idle), extras
  body <- c(fr(0xEF),   # bit4 clear (gmv "B") -> physical A -> slot 8
            fr(0xDF),   # bit5 clear (gmv "C") -> physical B -> slot 7
            fr(0xBF))   # bit6 clear (gmv "A") -> physical C -> slot 13
  tf <- tempfile(fileext = ".gmv"); on.exit(unlink(tf))
  writeBin(c(hdr, body), tf)
  mv <- read_gmv(tf)
  expect_identical(which(mv$inputs[1, 1, ]), 8L)
  expect_identical(which(mv$inputs[2, 1, ]), 7L)
  expect_identical(which(mv$inputs[3, 1, ]), 13L)
})
