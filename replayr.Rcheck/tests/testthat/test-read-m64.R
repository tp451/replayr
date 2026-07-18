test_that("read_m64() parses the bundled synthetic N64 movie", {
  mv <- read_m64(fixture_path("sample.m64"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "m64")
  expect_equal(n_frames(mv), 3600L)
  # N64 output is 28 buttons wide (buttons + C-buttons + 8-direction
  # quantised stick).
  expect_equal(n_buttons(mv), 28L)
  pc <- press_counts(mv, 1L)
  # The fixture deliberately exercises the synthetic analog-stick pattern.
  expect_true(sum(pc[21:28]) > 0L)
})

.mk_m64 <- function(samples, controllers = 1L, vi_count = 99L) {
  hdr <- raw(0x400L)
  hdr[1:4] <- charToRaw("M64\x1a")
  hdr[5:8] <- writeBin(3L, raw(), size = 4L, endian = "little")
  hdr[13:16] <- writeBin(vi_count, raw(), size = 4L, endian = "little")
  hdr[22] <- as.raw(controllers)
  hdr[25:28] <- writeBin(nrow(samples), raw(), size = 4L, endian = "little")
  tf <- tempfile(fileext = ".m64")
  writeBin(c(hdr, as.raw(as.vector(t(samples)))), tf)
  tf
}

test_that("read_m64() uses the sample-count field and exposes reset markers", {
  samples <- matrix(c(0x01, 0x00, 0x00, 0x00,
                      0x00, 0xc0, 0x00, 0x00), nrow = 2L, byrow = TRUE)
  tf <- .mk_m64(samples)
  on.exit(unlink(tf))
  mv <- read_m64(tf)
  expect_equal(n_frames(mv), 2L)
  expect_equal(mv$header$viCount, "99")
  expect_true(mv$inputs[1L, 1L, 1L])
  expect_equal(mv$commands, c(0L, 1L))
})

test_that("read_m64() rejects ambiguous multiplayer poll streams", {
  tf <- .mk_m64(matrix(c(0, 0, 0, 0), nrow = 1L), controllers = 2L)
  on.exit(unlink(tf))
  expect_error(read_m64(tf), "multi-controller")
})
