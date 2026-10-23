test_that("replayr:::.decode_smv() parses the bundled synthetic SNES movie", {
  mv <- replayr:::.decode_smv(fixture_path("sample.smv"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "smv")
  expect_equal(n_observations(mv), 3600L)
  expect_equal(n_buttons(mv), 12L)
})
.mk_smv <- function(words, frame_count = length(words) - 1L,
                    controller_type = 1L, sample_count = frame_count) {
  hdr <- raw(0x40L)
  hdr[1:4] <- charToRaw("SMV\x1a")
  hdr[5:8] <- writeBin(4L, raw(), size = 4L, endian = "little")
  hdr[17:20] <- writeBin(frame_count, raw(), size = 4L, endian = "little")
  hdr[21] <- as.raw(1L)
  hdr[29:32] <- writeBin(0x40L, raw(), size = 4L, endian = "little")
  # Snes9x writes the same count of frames and input samples for joypads.
  hdr[33:36] <- writeBin(as.integer(sample_count), raw(), size = 4L, endian = "little")
  hdr[37] <- as.raw(controller_type)
  body <- unlist(lapply(words, function(w) c(bitwAnd(w, 0xffL), bitwShiftR(w, 8L))))
  tf <- tempfile(fileext = ".smv")
  writeBin(c(hdr, as.raw(body)), tf)
  tf
}
test_that("replayr:::.decode_smv() includes the initial sample and recognises reset", {
  tf <- .mk_smv(c(0xffffL, 0x8000L))
  on.exit(unlink(tf))
  mv <- replayr:::.decode_smv(tf)
  expect_equal(n_observations(mv), 2L)
  expect_equal(mv$commands, c(1L, 0L))
  expect_equal(sum(mv$inputs[1L, , ]), 0L)
  expect_true(mv$inputs[2L, 1L, 7L])
})
test_that("replayr:::.decode_smv() rejects variable-width peripherals", {
  tf <- .mk_smv(c(0L), controller_type = 2L)
  on.exit(unlink(tf))
  expect_error(replayr:::.decode_smv(tf), "unsupported SMV peripheral")
})
test_that('SMV reports one whole missing sample but rejects partial or larger loss', {
  tf <- .mk_smv(c(0L, 256L), frame_count = 2L)
  on.exit(unlink(tf))
  expect_warning(mv <- replayr:::.decode_smv(tf), 'no input invented')
  expect_equal(n_observations(mv), 2L)
  expect_identical(mv$header$trailingSampleShortfall, '1')
  bytes <- readBin(tf, 'raw', n = file.info(tf)$size)
  writeBin(head(bytes, -1L), tf)
  expect_error(replayr:::.decode_smv(tf), 'partial final')
  writeBin(head(bytes, -2L), tf)
  expect_error(replayr:::.decode_smv(tf), 'truncated SMV')
})
test_that('SMV ignores unused tail bytes after the complete declared range', {
  tf <- .mk_smv(c(0L, 256L))
  on.exit(unlink(tf))
  bytes <- readBin(tf, 'raw', n = file.info(tf)$size)
  writeBin(c(bytes, as.raw(c(255, 255, 255))), tf)
  mv <- replayr:::.decode_smv(tf)
  expect_equal(n_observations(mv), 2L)
  expect_equal(sum(mv$inputs), 1L)
  expect_identical(mv$header$unusedTrailingBytes, '3')
})
test_that("SMV versions 4 and 5 return every declared input sample", {
  # One frame is declared, but three input samples: four records are input.
  tf <- .mk_smv(c(0L, 256L, 512L, 1024L), frame_count = 1L, sample_count = 3L)
  on.exit(unlink(tf))
  mv <- replayr:::.decode_smv(tf)
  expect_equal(n_observations(mv), 4L)
  expect_identical(mv$header$unusedTrailingBytes, "0")
  # A sample count the stream cannot supply leaves the frame count in charge.
  short <- .mk_smv(c(0L, 256L), frame_count = 1L, sample_count = 9L)
  on.exit(unlink(short), add = TRUE)
  expect_equal(n_observations(replayr:::.decode_smv(short)), 2L)
})
# Snes9x writes the ROM information in the 30 bytes before the savestate:
# three zero bytes, the CRC32 and the name in 23 bytes. Bit 6 of the sync
# flags at 0x17 says that it is there.
.with_smv_rom <- function(name, flag = TRUE) {
  tf <- .mk_smv(c(0L, 256L))
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  hdr <- bytes[1:0x40]
  block <- c(raw(3L), as.raw(c(0x8d, 0x35, 0xc3, 0xea)), name, raw(23L - length(name)))
  offset <- writeBin(0x40L + length(block), raw(), size = 4L, endian = "little")
  hdr[25:28] <- offset # savestate
  hdr[29:32] <- offset # controller data
  if (flag) hdr[0x18] <- as.raw(0x40L)
  writeBin(c(hdr, block, bytes[-(1:0x40)]), tf)
  tf
}
test_that("SMV keeps the CRC32 and name of the ROM from the block before the savestate", {
  tf <- .with_smv_rom(charToRaw("ACTRAISER-USA"))
  on.exit(unlink(tf))
  mv <- replayr:::.decode_smv(tf)
  expect_identical(mv$header$romCRC32, "eac3358d")
  expect_identical(mv$header$romName, "ACTRAISER-USA")
  expect_equal(n_observations(mv), 2L)
  expect_true(mv$inputs[2L, 1L, 1L])
})
test_that("SMV reads the katakana of a Japanese ROM name", {
  # Panel de Pon, in JIS X 0201 as the cartridge header has it.
  tf <- .with_smv_rom(as.raw(c(0xca, 0xdf, 0xc8, 0xd9, 0x20, 0xc3, 0xde, 0x20, 0xce, 0xdf, 0xdd)))
  on.exit(unlink(tf))
  expect_identical(
    replayr:::.decode_smv(tf)$header$romName,
    "ﾊﾟﾈﾙ ﾃﾞ ﾎﾟﾝ"
  )
})
test_that("SMV without the ROM flag has no ROM fields, whatever text the header holds", {
  tf <- .with_smv_rom(charToRaw("ACTRAISER-USA"), flag = FALSE)
  on.exit(unlink(tf))
  mv <- replayr:::.decode_smv(tf)
  expect_identical(mv$header$romCRC32, "")
  expect_identical(mv$header$romName, "")
  expect_identical(replayr:::.decode_smv(fixture_path("sample.smv"))$header$romName, "")
})
