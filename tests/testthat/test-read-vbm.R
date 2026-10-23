test_that("replayr:::.decode_vbm() parses the bundled synthetic Game Boy movie", {
  mv <- replayr:::.decode_vbm(fixture_path("sample.vbm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "vbm")
  expect_equal(n_observations(mv), 3600L)
  expect_equal(n_buttons(mv), 8L)
  expect_equal(mv$header$isGBA, "0")
})
.mk_vbm <- function(words, controller_flags = 1L, system_flags = 0L) {
  hdr <- raw(0x100L)
  hdr[1:4] <- charToRaw("VBM\x1a")
  hdr[5:8] <- writeBin(1L, raw(), size = 4L, endian = "little")
  hdr[13:16] <- writeBin(1L, raw(), size = 4L, endian = "little")
  hdr[22] <- as.raw(controller_flags)
  hdr[23] <- as.raw(system_flags)
  hdr[61:64] <- writeBin(0x100L, raw(), size = 4L, endian = "little")
  body <- unlist(lapply(words, function(w) c(bitwAnd(w, 0xffL), bitwShiftR(w, 8L))))
  tf <- tempfile(fileext = ".vbm")
  writeBin(c(hdr, as.raw(body)), tf)
  tf
}
test_that("replayr:::.decode_vbm() decodes grouped SGB controllers", {
  tf <- .mk_vbm(c(1L, 2L), controller_flags = 3L, system_flags = 4L)
  on.exit(unlink(tf))
  mv <- replayr:::.decode_vbm(tf)
  expect_equal(dim(mv$inputs), c(1L, 2L, 12L))
  expect_true(mv$inputs[1L, 1L, 8L])
  expect_true(mv$inputs[1L, 2L, 7L])
  expect_equal(mv$header$isSGB, "1")
})
test_that("read_vbm() keeps the L and R buttons of Super Game Boy recordings", {
  # A, then R, then L, then L+R with a new-timing reset.
  tf <- .mk_vbm(c(0x0001L, 0x0100L, 0x0200L, 0x0b00L), system_flags = 4L)
  on.exit(unlink(tf))
  mv <- read_vbm(tf)
  keys <- button_layout(mv)$key
  expect_identical(keys, c("dpad_right", "dpad_left", "dpad_down", "dpad_up",
                           "start", "select", "b", "a", "l1", "r1"))
  states <- unname(player(mv))
  expect_identical(states[, keys == "a"], c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(states[, keys == "r1"], c(FALSE, TRUE, FALSE, TRUE))
  expect_identical(states[, keys == "l1"], c(FALSE, FALSE, TRUE, TRUE))
  expect_identical(mv$commands, c(0L, 0L, 0L, 0x0800L))
})
test_that("read_vbm() retains bits outside a Game Boy layout in commands", {
  tf <- .mk_vbm(c(0x0101L, 0x0400L, 0x1002L), system_flags = 2L)
  on.exit(unlink(tf))
  mv <- read_vbm(tf)
  expect_identical(n_buttons(mv), 8L)
  expect_identical(unname(colSums(player(mv))), c(0, 0, 0, 0, 0, 0, 1, 1))
  expect_identical(mv$commands, c(0x0100L, 0x0400L, 0x1000L))
})
test_that("replayr:::.decode_vbm() reads GBA shoulder buttons from system flags", {
  tf <- .mk_vbm(bitwShiftL(1L, 9L), system_flags = 1L)
  on.exit(unlink(tf))
  mv <- replayr:::.decode_vbm(tf)
  expect_equal(n_buttons(mv), 12L)
  expect_true(mv$inputs[1L, 1L, 11L])
  expect_equal(mv$header$isGBA, "1")
})
# The 20 bytes from 0x24: title, minor version, header checksum, a u16 and
# four bytes of game code.
.vbm_rom_info <- function(tf, title, check, u16_bytes, code) {
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  bytes[0x24 + 1:20] <- c(charToRaw(title), raw(12L - nchar(title)), as.raw(c(1L, check, u16_bytes)), code)
  writeBin(bytes, tf)
}
test_that("VBM keeps the header and global checksums of a Game Boy ROM", {
  tf <- .mk_vbm(1L)
  on.exit(unlink(tf))
  # VBA reads the global checksum big-endian from the ROM, 0x955A, and
  # writes it as a little-endian u16. The four bytes after it are the unit
  # code, not a game code.
  .vbm_rom_info(tf, "AVENGING SPI", 0x8e, c(0x5a, 0x95), as.raw(c(3, 0, 0, 0)))
  h <- replayr:::.decode_vbm(tf)$header
  expect_identical(h$romName, "AVENGING SPI")
  expect_identical(h$romHeaderChecksum, "8e")
  expect_identical(h$romGlobalChecksum, "955a")
  expect_identical(h$romGameCode, "")
  expect_identical(h$biosChecksum, "")
})
test_that("VBM keeps the game code of a Game Boy Advance ROM and the BIOS checksum", {
  tf <- .mk_vbm(1L, system_flags = 1L)
  on.exit(unlink(tf))
  .vbm_rom_info(tf, "SONICADVANC2", 0x81, c(0x7f, 0x18), charToRaw("A2NE"))
  h <- replayr:::.decode_vbm(tf)$header
  expect_identical(h$romName, "SONICADVANC2")
  expect_identical(h$romHeaderChecksum, "81")
  expect_identical(h$romGameCode, "A2NE")
  expect_identical(h$biosChecksum, "187f")
  expect_identical(h$romGlobalChecksum, "")
  # Bytes that are no game code are not reported as one.
  .vbm_rom_info(tf, "SONICADVANC2", 0x81, c(0, 0), as.raw(c(0x41, 0x32, 0, 0)))
  expect_identical(replayr:::.decode_vbm(tf)$header$romGameCode, "")
})
