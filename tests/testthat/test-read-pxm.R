test_that("read_pxm() parses the bundled synthetic PlayStation movie", {
  mv <- read_pxm(fixture_path("sample.pxm"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "pxm")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_players(mv), 2L)
  expect_equal(n_buttons(mv), 32L)
  expect_gt(sum(press_counts(mv, 1L)), 0L)
})

# Optional external-corpus fixtures complement the bundled synthetic sample.

.mk_pxm <- function(controller_types, frame_bytes, n_frames = 1L) {
  hdr <- raw(0x34L)
  hdr[1:4] <- charToRaw("PXM ")
  hdr[5:8] <- writeBin(2L, raw(), size = 4L, endian = "little")
  hdr[15:16] <- as.raw(controller_types)
  hdr[17:20] <- writeBin(n_frames, raw(), size = 4L, endian = "little")
  hdr[45:48] <- writeBin(0x34L, raw(), size = 4L, endian = "little")
  tf <- tempfile(fileext = ".pxm")
  writeBin(c(hdr, as.raw(frame_bytes)), tf)
  tf
}

test_that("read_pxm() decodes both digital ports and the command byte", {
  # P1 Right, P2 Cross, command 7.
  tf <- .mk_pxm(c(4L, 4L), c(0x20, 0x00, 0x00, 0x40, 0x07))
  on.exit(unlink(tf))
  mv <- read_pxm(tf)
  expect_equal(dim(mv$inputs), c(1L, 2L, 32L))
  expect_true(mv$inputs[1L, 1L, 1L])
  expect_true(mv$inputs[1L, 2L, 7L])
  expect_equal(mv$commands, 7L)
})

test_that("read_pxm() centres unsigned analog axes at 128", {
  # No buttons; left stick west and right stick up; command zero.
  tf <- .mk_pxm(c(7L, 0L), c(0, 0, 0, 128, 128, 0, 0))
  on.exit(unlink(tf))
  mv <- read_pxm(tf)
  expect_true(mv$inputs[1L, 1L, 25L])
  expect_true(mv$inputs[1L, 1L, 20L])
})

test_that("read_pxm() rejects unsupported controller record widths", {
  tf <- .mk_pxm(c(1L, 0L), rep(0, 5L))
  on.exit(unlink(tf))
  expect_error(read_pxm(tf), "mouse input")
})

test_that('PXM preserves L3 and R3 bits separately', {
  tf <- .mk_pxm(c(7L,0L),c(6,0,128,128,128,128,0))
  on.exit(unlink(tf))
  mv <- read_pxm(tf)
  expect_setequal(which(mv$inputs[1,1,]),c(31L,32L))
})

test_that('PXM standard pads do not invent stick-click buttons from reserved bits', {
  tf <- .mk_pxm(c(4L,0L),c(6,0,0))
  on.exit(unlink(tf))
  mv <- read_pxm(tf)
  expect_false(any(mv$inputs))
  expect_equal(mv$header$reservedDigitalPadBitCounts,2L)
})

test_that("read_pxm() parses a PSX binary movie when fixture is available", {
  fp <- external_fixture("raw_psx/mega_man_x4/1439.pxm")
  if (is.null(fp)) skip("set REPLAYR_FIXTURE_DIR to enable PXM test")
  mv <- read_pxm(fp)
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "pxm")
  expect_gt(n_frames(mv), 0L)
  expect_equal(n_buttons(mv), 32L)
})
test_that("vectorized PXM sticks equal the original per-frame implementation", {
  set.seed(902)
  axes<-rbind(matrix(sample(0:255,400,replace=TRUE),ncol=4),
              c(128,128,128,128),c(160,128,128,160),c(255,0,0,255))
  expected<-array(FALSE,c(nrow(axes),1L,30L))
  for(i in seq_len(nrow(axes)))expected<-.pxm_quantise_sticks(expected,i,1L,axes[i,])
  expect_equal(.pxm_stick_matrix(axes),expected[,1,])
})
