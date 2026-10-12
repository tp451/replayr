test_that("replayr:::.decode_gmv() parses the bundled synthetic Genesis movie", {
  mv <- replayr:::.decode_gmv(fixture_path("sample.gmv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "gmv")
  expect_equal(n_frames(mv), 3600L)
  # The private Genesis decoder reserves 15 button slots
  # (slots 1..4 d-pad, 5 Start, 7/8 B/A, 9/10 X/Y, 13 C, 14 Z, 15 Mode).
  expect_equal(n_buttons(mv), 15L)
  expect_equal(n_players(mv), 2L)
})
test_that('TESTJ uses the post-TESTA controller and flag layout', {
  hdr <- raw(64L)
  hdr[1:16] <- charToRaw('Gens Movie TESTJ')
  hdr[21:22] <- charToRaw('66')
  hdr[23] <- as.raw(128)
  tf <- tempfile(fileext = '.gmv')
  on.exit(unlink(tf))
  writeBin(c(hdr, as.raw(c(255, 255, 254))), tf)
  mv <- replayr:::.decode_gmv(tf)
  expect_true(mv$inputs[1, 1, 9])
  expect_identical(mv$header$fps, '50')
  expect_identical(mv$header$p1PadType, '6')
})
test_that("replayr:::.decode_gmv() decodes six-button extras and three-player mode", {
  hdr <- raw(64L)
  hdr[1:15] <- charToRaw("Gens Movie TEST")
  hdr[16] <- charToRaw("A")
  hdr[21:22] <- charToRaw("66")
  tf <- tempfile(fileext = ".gmv")
  on.exit(unlink(tf))
  # P1 X (extra bit 0) and P2 Mode (extra bit 7), active-low.
  writeBin(c(hdr, as.raw(c(0xff, 0xff, 0x7e))), tf)
  mv <- replayr:::.decode_gmv(tf)
  expect_true(mv$inputs[1L, 1L, 9L])
  expect_true(mv$inputs[1L, 2L, 15L])
  hdr[23] <- as.raw(0xa0L) # PAL + three-player
  writeBin(c(hdr, as.raw(c(0xff, 0xff, 0xef))), tf)
  mv3 <- replayr:::.decode_gmv(tf)
  expect_equal(n_players(mv3), 3L)
  expect_true(mv3$inputs[1L, 3L, 8L])
  expect_equal(mv3$header$fps, "50")
})
test_that("replayr:::.decode_gmv() maps the three face bits to canonical slots", {
  # A 3-button Gens .gmv is a 64-byte header + 3 bytes/frame (P1, P2,
  # extra data), active-low. Face bits 4/5/6 are A/B/C.
  hdr <- raw(64)
  hdr[1:15] <- charToRaw("Gens Movie TEST")
  hdr[16] <- charToRaw("A")
  hdr[21] <- charToRaw("6")
  hdr[22] <- charToRaw("3") # NTSC, 3-button pads
  fr <- function(p1) as.raw(c(p1, 0xFF, 0xFF)) # P1, P2 (idle), extras
  body <- c(
    fr(0xEF), # bit4 clear: A -> slot 8
    fr(0xDF), # bit5 clear: B -> slot 7
    fr(0xBF)
  ) # bit6 clear: C -> slot 13
  tf <- tempfile(fileext = ".gmv")
  on.exit(unlink(tf))
  writeBin(c(hdr, body), tf)
  mv <- replayr:::.decode_gmv(tf)
  expect_identical(which(mv$inputs[1, 1, ]), 8L)
  expect_identical(which(mv$inputs[2, 1, ]), 7L)
  expect_identical(which(mv$inputs[3, 1, ]), 13L)
})
