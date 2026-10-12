test_that("replayr:::.decode_pjm() parses the bundled synthetic PlayStation movie", {
  mv <- replayr:::.decode_pjm(analog = "quantized", fixture_path("sample.pjm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "pjm")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 2L)
  expect_equal(n_buttons(mv), 42L)
  expect_gt(sum(press_counts(mv, 1L)), 0L)
})
# Build a minimal in-memory PSXjin text .pjm: a 60-byte header (magic +
# version 2 + n_frames) followed by `<port1>|<port2>|<cmd>|CRLF` lines.
# `p2 = NULL` writes an empty second port (the one-controller layout).
.mk_pjm_text <- function(p1, p2 = NULL, commands = rep(0L, length(p1)),
                         declared_frames = length(p1)) {
  hdr <- raw(60)
  hdr[1:4] <- charToRaw("PJM ")
  hdr[5] <- as.raw(2L) # version u32 LE
  hdr[17:20] <- writeBin(declared_frames, raw(), size = 4L, endian = "little")
  lines <- vapply(seq_along(p1), function(i) {
    port2 <- if (is.null(p2)) "" else p2[i]
    paste0(p1[i], "|", port2, "|", commands[i], "|\r\n")
  }, character(1))
  tf <- tempfile(fileext = ".pjm")
  writeBin(c(hdr, charToRaw(paste0(lines, collapse = ""))), tf)
  tf
}
# Build a minimal binary .pjm: P1/P2 digital words plus command byte.
.mk_pjm_bin <- function(words, p2_words = rep(0L, length(words)),
                        commands = rep(0L, length(words)), p2_connected = FALSE) {
  hdr <- raw(60)
  hdr[1:4] <- charToRaw("PJM ")
  hdr[5] <- as.raw(2L)
  hdr[17:20] <- writeBin(length(words), raw(), size = 4L, endian = "little")
  hdr[15:16] <- as.raw(c(4L, if (p2_connected) 4L else 0L))
  body <- raw(length(words) * 5L)
  for (i in seq_along(words)) {
    o <- (i - 1L) * 5L
    body[o + 1L] <- as.raw(bitwAnd(words[i], 0xffL))
    body[o + 2L] <- as.raw(bitwAnd(bitwShiftR(words[i], 8L), 0xffL))
    body[o + 3L] <- as.raw(bitwAnd(p2_words[i], 0xffL))
    body[o + 4L] <- as.raw(bitwAnd(bitwShiftR(p2_words[i], 8L), 0xffL))
    body[o + 5L] <- as.raw(commands[i])
  }
  tf <- tempfile(fileext = ".pjm")
  writeBin(c(hdr, body), tf)
  tf
}
# 14-char digital mask with the given 1-based column positions pressed.
.pjm_mask <- function(...) {
  s <- rep(".", 14L)
  s[c(...)] <- "X"
  paste(s, collapse = "")
}
test_that('complete NUL records retain PSXjin non-dot button semantics', {
  tf <- .mk_pjm_text(rep(.pjm_mask(), 4))
  on.exit(unlink(tf))
  b <- readBin(tf, 'raw', n = file.info(tf)$size)
  b[101:120] <- as.raw(0)
  writeBin(b, tf)
  expect_no_warning(mv <- replayr:::.decode_pjm(analog = "quantized", tf))
  expect_equal(n_frames(mv), 4L)
  expect_equal(sum(mv$inputs[3, 1, ]), 14L)
  expect_equal(mv$commands[3], 0L)
  expect_identical(mv$header$allNulRecordCount, '1')
  b[102] <- as.raw(46)
  writeBin(b, tf)
  expect_no_warning(mv <- replayr:::.decode_pjm(analog = "quantized", tf))
  expect_equal(sum(mv$inputs[3, 1, ]), 13L)
  expect_identical(mv$header$noncanonicalSeparatorRecords, '1')
})
test_that("replayr:::.decode_pjm() decodes the one-controller text layout", {
  # column 11 == Right (slot 1); one-controller -> single player, empty port 2
  tf <- .mk_pjm_text(c(.pjm_mask(11L), .pjm_mask(), .pjm_mask(11L)))
  mv <- replayr:::.decode_pjm(analog = "quantized", tf)
  expect_equal(mv$header[["_format"]], "pjm")
  expect_equal(dim(mv$inputs), c(3L, 1L, 42L))
  expect_equal(n_players(mv), 1L)
  expect_true(mv$inputs[1L, 1L, 1L]) # Right
  expect_equal(sum(mv$inputs[2L, , ]), 0L) # released frame
  expect_equal(sum(mv$inputs), 2L)
})
test_that("replayr:::.decode_pjm() preserves text command values", {
  tf <- .mk_pjm_text(c(.pjm_mask(), .pjm_mask()), commands = c(0L, 7L))
  on.exit(unlink(tf))
  expect_equal(replayr:::.decode_pjm(analog = "quantized", tf)$commands, c(0L, 7L))
})
test_that("PJM retains complete text records when the header count is larger", {
  tf <- .mk_pjm_text(
    c(.pjm_mask(11L), .pjm_mask(), .pjm_mask(2L)),
    declared_frames = 5L
  )
  on.exit(unlink(tf))
  expect_no_warning(mv <- replayr:::.decode_pjm(analog = "quantized", tf))
  expect_equal(n_frames(mv), 3L)
  expect_equal(mv$header[["declaredFrameCount"]], "5")
  expect_equal(mv$header[["availableFrameCount"]], "3")
  expect_equal(mv$header[["trailingFrameShortfall"]], "2")
  expect_true(mv$inputs[1L, 1L, 1L])
  expect_true(mv$inputs[3L, 1L, 7L])
})
test_that("PJM rejects a partial text record regardless of its header count", {
  partial <- .mk_pjm_text(c(.pjm_mask(), .pjm_mask(), .pjm_mask()),
    declared_frames = 3L
  )
  bytes <- readBin(partial, "raw", n = file.info(partial)$size)
  on.exit(unlink(partial))
  for (declared in c(1L, 3L, 8L)) {
    bytes[17:20] <- writeBin(declared, raw(), size = 4L, endian = "little")
    writeBin(head(bytes, -4L), partial)
    expect_error(read_pjm(partial), "partial final frame")
  }
})
test_that("replayr:::.decode_pjm() decodes the two-controller text layout", {
  # frame 2: P1 Cross (col 2 -> slot 7 / B), P2 Square (col 1 -> slot 10 / Y)
  p1 <- c(.pjm_mask(11L), .pjm_mask(2L), .pjm_mask())
  p2 <- c(.pjm_mask(), .pjm_mask(1L), .pjm_mask())
  mv <- replayr:::.decode_pjm(analog = "quantized", .mk_pjm_text(p1, p2))
  expect_equal(dim(mv$inputs), c(3L, 2L, 42L))
  expect_equal(n_players(mv), 2L)
  expect_true(mv$inputs[1L, 1L, 1L]) # P1 Right
  expect_true(mv$inputs[2L, 1L, 7L]) # P1 Cross -> B
  expect_true(mv$inputs[2L, 2L, 10L]) # P2 Square -> Y
  expect_equal(sum(mv$inputs[2L, , ]), 2L)
  expect_equal(sum(mv$inputs[3L, , ]), 0L)
})
test_that("replayr:::.decode_pjm() retains analog stick directions and the 16-column mask", {
  # Actual PSXjin analog ports have 16 digital chars, not 14.
  p1 <- c(
    paste0(.pjm_mask(11L), ".. 255 128 128 000"),
    paste0(.pjm_mask(), ".. 128 128 128 128"),
    paste0(.pjm_mask(2L), ".. 010 250 128 128")
  )
  p2 <- c(.pjm_mask(), .pjm_mask(), .pjm_mask())
  mv <- replayr:::.decode_pjm(analog = "quantized", .mk_pjm_text(p1, p2))
  expect_equal(n_players(mv), 2L)
  expect_true(mv$inputs[1L, 1L, 1L]) # D-pad Right
  expect_true(mv$inputs[1L, 1L, 21L]) # left stick E
  expect_true(mv$inputs[1L, 1L, 20L]) # right stick Up
  expect_true(mv$inputs[3L, 1L, 26L]) # left stick SW
  expect_true(mv$inputs[3L, 1L, 7L]) # Cross -> B
  expect_equal(sum(mv$inputs[2L, , ]), 0L) # centred stick != a press
})
test_that("replayr:::.decode_pjm() decodes the binary body", {
  # bit 5 = Right (slot 1); bit 14 = Cross (slot 7 / B)
  tf <- .mk_pjm_bin(c(bitwShiftL(1L, 5L), 0L, bitwShiftL(1L, 14L)))
  mv <- replayr:::.decode_pjm(analog = "quantized", tf)
  expect_equal(dim(mv$inputs), c(3L, 1L, 42L))
  expect_true(mv$inputs[1L, 1L, 1L])
  expect_true(mv$inputs[3L, 1L, 7L])
  expect_equal(sum(mv$inputs[2L, , ]), 0L)
})
test_that("replayr:::.decode_pjm() decodes binary player two and commands", {
  tf <- .mk_pjm_bin(0L, bitwShiftL(1L, 14L),
    commands = 9L,
    p2_connected = TRUE
  )
  on.exit(unlink(tf))
  mv <- replayr:::.decode_pjm(analog = "quantized", tf)
  expect_equal(n_players(mv), 2L)
  expect_true(mv$inputs[1L, 2L, 7L])
  expect_equal(mv$commands, 9L)
})
test_that('PJM binary standard-pad reserved bits are not stick-click buttons', {
  tf <- .mk_pjm_bin(6L)
  on.exit(unlink(tf))
  mv <- replayr:::.decode_pjm(analog = "quantized", tf)
  expect_false(any(mv$inputs))
  expect_equal(mv$header$reservedDigitalPadBitCounts, 2L)
})
test_that('PJM configured binary pads distinguish real and reserved click bits', {
  for (type in c(4L, 7L)) {
    hdr <- raw(52)
    hdr[1:4] <- charToRaw('PJM ')
    hdr[5] <- as.raw(2)
    hdr[15] <- as.raw(type)
    hdr[17] <- as.raw(1)
    hdr[45] <- as.raw(52)
    bytes <- if (type == 4L) c(6, 0, 0) else c(6, 0, 128, 128, 128, 128, 0)
    tf <- tempfile(fileext = '.pjm')
    writeBin(c(hdr, as.raw(bytes)), tf)
    mv <- replayr:::.decode_pjm(analog = "quantized", tf)
    unlink(tf)
    if (type == 4L) {
      expect_false(any(mv$inputs))
      expect_equal(mv$header$reservedDigitalPadBitCounts, 2L)
    } else expect_setequal(which(mv$inputs[1, 1, ]), c(41L, 42L))
  }
})
test_that("PJM text shoulder order and Square match the PSXjin writer", {
  masks <- vapply(1:14, function(k) {
    x <- rep('.', 14)
    x[k] <- substr('#XO^1234LDRUSs', k, k)
    paste0(x, collapse = '')
  }, character(1))
  mv <- replayr:::.decode_pjm(analog = "quantized", .mk_pjm_text(masks))
  # Independent expectation from bits 15..3 and bit 0 in MOV_WriteJoy.
  slots <- c(10, 7, 8, 9, 12, 11, 30, 29, 2, 3, 1, 4, 5, 6)
  expect_equal(which(mv$inputs[, 1, ], arr.ind = TRUE)[order(which(mv$inputs[, 1, ], arr.ind = TRUE)[, 1]), 2], slots)
  expect_equal(sum(mv$inputs), 14)
  expect_equal(sum(mv$commands), 0L) # '#' is Square, not Reset
})
test_that("PJM accepts only complete terminal records without newline", {
  for (remove in 1:2) {
    tf <- .mk_pjm_text(c(.pjm_mask(), .pjm_mask(2L), .pjm_mask(8L)))
    b <- readBin(tf, 'raw', n = file.info(tf)$size)
    writeBin(head(b, -remove), tf)
    mv <- replayr:::.decode_pjm(analog = "quantized", tf)
    expect_equal(n_frames(mv), 3L)
    expect_true(mv$inputs[3, 1, 29])
    expect_equal(mv$header$terminalNewlineBytesMissing, as.character(remove))
    unlink(tf)
  }
})
test_that("PJM analog Select is column sixteen", {
  p1 <- c('...............s 128 128 128 128', '................ 128 128 128 128')
  mv <- replayr:::.decode_pjm(analog = "quantized", .mk_pjm_text(p1))
  expect_true(mv$inputs[1, 1, 6])
  expect_equal(sum(mv$inputs), 1L)
})
test_that('PJM preserves analog text L3 and R3 separately', {
  mv <- replayr:::.decode_pjm(analog = "quantized", .mk_pjm_text(c(
    '.............<>. 128 128 128 128',
    '................ 128 128 128 128'
  )))
  expect_setequal(which(mv$inputs[1, 1, ]), c(41L, 42L))
  expect_false(any(mv$inputs[2, 1, ]))
})
test_that("PJM uses complete physical records beyond a stale smaller header", {
  tf <- .mk_pjm_text(c(.pjm_mask(), .pjm_mask(), .pjm_mask(2L)), declared_frames = 2L)
  expect_no_warning(mv <- replayr:::.decode_pjm(analog = "quantized", tf))
  expect_equal(n_frames(mv), 3L)
  expect_true(mv$inputs[3, 1, 7])
  expect_identical(mv$header$frameCountDifference, "-1")
})
test_that("PJM header offset permits a single text record and ignores header pipes", {
  tf <- .mk_pjm_text(.pjm_mask(2L))
  b <- readBin(tf, 'raw', n = file.info(tf)$size)
  b[45:48] <- writeBin(60L, raw(), size = 4L, endian = 'little')
  b[25:27] <- charToRaw('|\r\n')
  writeBin(b, tf)
  mv <- replayr:::.decode_pjm(analog = "quantized", tf)
  expect_equal(n_frames(mv), 1L)
  expect_true(mv$inputs[1, 1, 7])
})
test_that("PJM binary uses configured digital or analog record widths", {
  for (analog in c(FALSE, TRUE)) {
    h <- raw(60)
    h[1:4] <- charToRaw('PJM ')
    h[5] <- as.raw(2)
    h[15:16] <- as.raw(c(if (analog) 7 else 4, 8))
    h[17:20] <- writeBin(1L, raw(), size = 4L, endian = 'little')
    h[45:48] <- writeBin(60L, raw(), size = 4L, endian = 'little')
    body <- as.raw(c(0, 64, if (analog) c(255, 128, 128, 0), 3))
    tf <- tempfile(fileext = '.pjm')
    writeBin(c(h, body), tf)
    mv <- replayr:::.decode_pjm(analog = "quantized", tf)
    expect_equal(dim(mv$inputs), c(1L, 1L, 42L))
    expect_true(mv$inputs[1, 1, 7])
    expect_equal(mv$commands, 3L)
    if (analog) {
      expect_true(mv$inputs[1, 1, 21])
      expect_true(mv$inputs[1, 1, 20])
    }
    unlink(tf)
  }
})
test_that("PJM frame-count metadata follows complete text and binary streams", {
  for (binary in c(FALSE, TRUE)) {
    for (declared in c(0, 2, 8, 98, 4294967295)) {
      if (binary) {
        hdr <- raw(60L)
        hdr[1:4] <- charToRaw("PJM ")
        hdr[5] <- as.raw(2L)
        hdr[15:16] <- as.raw(c(7L, 4L))
        hdr[45] <- as.raw(60L)
        records <- rbind(
          c(0, 64, 255, 128, 128, 0, 0, 128, 0),
          c(6, 0, 128, 128, 128, 128, 0, 0, 0),
          c(0, 32, 0, 128, 128, 255, 0, 16, 3)
        )
        tf <- tempfile(fileext = ".pjm")
        writeBin(c(hdr, as.raw(t(records))), tf)
      } else {
        tf <- .mk_pjm_text(c(.pjm_mask(11L), .pjm_mask(), .pjm_mask(2L)))
      }
      bytes <- readBin(tf, "raw", n = file.info(tf)$size)
      bytes[17:20] <- as.raw(floor(declared / 256^(0:3)) %% 256)
      writeBin(bytes, tf)
      for (mode in c("raw", "cardinal4", "cardinal8", "angle", "angle+magnitude")) {
        expect_no_warning(movie <- read_pjm(tf, analog = mode))
        expect_identical(n_frames(movie), 3L)
        expect_identical(movie$header$declaredFrameCount, as.character(declared))
        expect_identical(movie$header$availableFrameCount, "3")
        expect_identical(movie$header$frameCountDifference, as.character(declared - 3))
        expect_identical(movie$header$trailingFrameShortfall, as.character(max(0, declared - 3)))
        if (binary) {
          expect_equal(unname(analog_channels(movie)), records[, 3:6])
          expect_true(player(movie, 1L)[1L, "B"])
          expect_true(player(movie, 2L)[1L, "y"])
          expect_true(player(movie, 1L)[3L, "A"])
          expect_identical(movie$commands, c(0L, 0L, 3L))
        } else {
          expect_true(player(movie)[1L, "R"])
          expect_true(player(movie)[3L, "B"])
        }
      }
      if (binary) {
        writeBin(head(bytes, -1L), tf)
        expect_error(read_pjm(tf), "partial final frame")
      }
      unlink(tf)
    }
  }
})
