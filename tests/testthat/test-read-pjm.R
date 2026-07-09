# Build a minimal in-memory PSXjin text .pjm: a 60-byte header (magic +
# version 2 + n_frames) followed by `<port1>|<port2>|<cmd>|CRLF` lines.
# `p2 = NULL` writes an empty second port (the one-controller layout).
.mk_pjm_text <- function(p1, p2 = NULL) {
  hdr <- raw(60)
  hdr[1:4] <- charToRaw("PJM ")
  hdr[5]   <- as.raw(2L)                                   # version u32 LE
  hdr[17:20] <- writeBin(length(p1), raw(), size = 4L, endian = "little")
  lines <- vapply(seq_along(p1), function(i) {
    port2 <- if (is.null(p2)) "" else p2[i]
    paste0(p1[i], "|", port2, "|0|\r\n")
  }, character(1))
  tf <- tempfile(fileext = ".pjm")
  writeBin(c(hdr, charToRaw(paste0(lines, collapse = ""))), tf)
  tf
}

# Build a minimal binary .pjm: 60-byte header + 5 bytes/frame (16-bit
# DualShock word LE in bytes 0-1, bytes 2-4 reserved). `reserved` fills the
# three reserved bytes (0 for the real layout; non-zero to exercise the guard).
.mk_pjm_bin <- function(words, reserved = 0L) {
  hdr <- raw(60)
  hdr[1:4] <- charToRaw("PJM ")
  hdr[5]   <- as.raw(2L)
  hdr[17:20] <- writeBin(length(words), raw(), size = 4L, endian = "little")
  body <- raw(length(words) * 5L)
  for (i in seq_along(words)) {
    o <- (i - 1L) * 5L
    body[o + 1L] <- as.raw(bitwAnd(words[i], 0xffL))
    body[o + 2L] <- as.raw(bitwAnd(bitwShiftR(words[i], 8L), 0xffL))
    if (reserved != 0L) { body[o + 3L] <- as.raw(reserved) }
  }
  tf <- tempfile(fileext = ".pjm")
  writeBin(c(hdr, body), tf)
  tf
}

# 14-char digital mask with the given 1-based column positions pressed.
.pjm_mask <- function(...) {
  s <- rep(".", 14L); s[c(...)] <- "X"; paste(s, collapse = "")
}

test_that("read_pjm() decodes the one-controller text layout", {
  # column 11 == Right (slot 1); one-controller -> single player, empty port 2
  tf <- .mk_pjm_text(c(.pjm_mask(11L), .pjm_mask(), .pjm_mask(11L)))
  mv <- read_pjm(tf)
  expect_equal(mv$header[["_format"]], "pjm")
  expect_equal(dim(mv$inputs), c(3L, 1L, 30L))
  expect_equal(n_players(mv), 1L)
  expect_true(mv$inputs[1L, 1L, 1L])          # Right
  expect_equal(sum(mv$inputs[2L, , ]), 0L)     # released frame
  expect_equal(sum(mv$inputs), 2L)
})

test_that("read_pjm() decodes the two-controller text layout", {
  # frame 2: P1 Cross (col 2 -> slot 7 / B), P2 Square (col 1 -> slot 10 / Y)
  p1 <- c(.pjm_mask(11L), .pjm_mask(2L), .pjm_mask())
  p2 <- c(.pjm_mask(),    .pjm_mask(1L), .pjm_mask())
  mv <- read_pjm(.mk_pjm_text(p1, p2))
  expect_equal(dim(mv$inputs), c(3L, 2L, 30L))
  expect_equal(n_players(mv), 2L)
  expect_true(mv$inputs[1L, 1L, 1L])          # P1 Right
  expect_true(mv$inputs[2L, 1L, 7L])          # P1 Cross -> B
  expect_true(mv$inputs[2L, 2L, 10L])         # P2 Square -> Y
  expect_equal(sum(mv$inputs[2L, , ]), 2L)
  expect_equal(sum(mv$inputs[3L, , ]), 0L)
})

test_that("read_pjm() ignores trailing analog columns in the text mask", {
  # a wide analog port: 14 digital chars + space-padded stick decimals
  p1 <- c(paste0(.pjm_mask(11L), " 128 127 100 090"),
          paste0(.pjm_mask(),    " 128 128 128 128"),
          paste0(.pjm_mask(2L),  " 010 250 128 128"))
  p2 <- c(.pjm_mask(), .pjm_mask(), .pjm_mask())
  mv <- read_pjm(.mk_pjm_text(p1, p2))
  expect_equal(n_players(mv), 2L)
  expect_true(mv$inputs[1L, 1L, 1L])          # Right, analog ignored
  expect_true(mv$inputs[3L, 1L, 7L])          # Cross -> B
  expect_equal(sum(mv$inputs[2L, , ]), 0L)     # centred stick != a press
})

test_that("read_pjm() decodes the binary body", {
  # bit 5 = Right (slot 1); bit 14 = Cross (slot 7 / B)
  tf <- .mk_pjm_bin(c(bitwShiftL(1L, 5L), 0L, bitwShiftL(1L, 14L)))
  mv <- read_pjm(tf)
  expect_equal(dim(mv$inputs), c(3L, 1L, 30L))
  expect_true(mv$inputs[1L, 1L, 1L])
  expect_true(mv$inputs[3L, 1L, 7L])
  expect_equal(sum(mv$inputs[2L, , ]), 0L)
})

test_that("read_pjm() rejects the unsupported analog-binary variant", {
  tf <- .mk_pjm_bin(rep(bitwShiftL(1L, 5L), 20L), reserved = 0x7fL)
  expect_error(read_pjm(tf), "analog/multi-controller")
})

# ---- real-corpus fixtures (set REPLAYR_FIXTURE_DIR) ----

test_that("read_pjm() parses real two-controller / analog / binary movies", {
  cases <- list(
    list("raw_psx/metal_gear_solid/2003.pjm", 2L),  # 34-byte 2-port text
    list("raw_psx/spyro_2_ripto_s_rage/2603.pjm", 2L),  # 52-byte analog text
    list("raw_psx/mega_man_x4/2032.pjm", 1L)         # 5-byte binary
  )
  any_run <- FALSE
  for (cs in cases) {
    fp <- external_fixture(cs[[1]])
    if (is.null(fp)) next
    any_run <- TRUE
    mv <- read_pjm(fp)
    expect_s3_class(mv, "replayr_movie")
    expect_equal(mv$header[["_format"]], "pjm")
    expect_equal(n_players(mv), cs[[2]])
    expect_gt(n_frames(mv), 0L)
    expect_equal(n_buttons(mv), 30L)
    pc <- press_counts(mv, 1L)
    expect_true(all(pc <= n_frames(mv)))        # nothing stuck above 100%
    expect_gt(sum(pc), 0L)
  }
  if (!any_run) skip("set REPLAYR_FIXTURE_DIR to enable real PJM tests")
})
