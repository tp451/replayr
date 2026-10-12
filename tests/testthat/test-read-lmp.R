# Tests for the Doom .lmp reader. The bundled sample is a generated one-minute
# controller stream and contains no IWAD or published-demo data. Optional
# locally supplied demos provide additional compatibility coverage.
#
# The doom_demos/lmp/extended/ subfolder contains five PrBoom+ /
# dsda-doom demos with later extensions that this parser rejects
# with a clear error -- those serve as format-detection regression
# fixtures.

lmp_dir <- file.path("..", "..", "..", "doom_demos", "lmp")
if (!dir.exists(lmp_dir)) {
  lmp_dir <- file.path("..", "..", "doom_demos", "lmp")
}

# Vanilla demos: any .lmp directly in lmp/ (not in subdirs).
vanilla_files <- list.files(lmp_dir, pattern = "\\.lmp$",
                             full.names = TRUE, ignore.case = TRUE,
                             recursive = FALSE)
extended_files <- list.files(file.path(lmp_dir, "extended"),
                              pattern = "\\.lmp$", full.names = TRUE,
                              ignore.case = TRUE)

test_that("read_lmp errors clearly on missing file", {
  expect_error(replayr:::.decode_lmp(analog = "quantized", tempfile()), "file not found")
})

test_that("replayr:::.decode_lmp() parses the bundled synthetic Doom demo", {
  mv <- replayr:::.decode_lmp(analog = "quantized", fixture_path("sample.lmp"))
  expect_s3_class(mv, "replayr_movie")
  expect_identical(mv$header[["_format"]], "lmp")
  expect_equal(n_frames(mv), 2100L)
  expect_equal(n_players(mv), 4L)
  expect_equal(n_buttons(mv), 8L)
  expect_gt(sum(press_counts(mv, 1L)), 0L)
})

test_that("read_lmp rejects too-small files", {
  tmp <- tempfile(fileext = ".lmp")
  writeBin(as.raw(c(1, 2, 3, 4, 5)), tmp)
  expect_error(replayr:::.decode_lmp(analog = "quantized", tmp), "too small")
  unlink(tmp)
})

.mk_lmp <- function(records, active = c(1L, 0L, 0L, 0L), end = TRUE) {
  hdr <- as.raw(c(109, 0, 1, 1, 0, 0, 0, 0, 0, active))
  tf <- tempfile(fileext = ".lmp")
  bytes <- c(hdr, as.raw(records), if (end) as.raw(0x80L) else raw(0))
  writeBin(bytes, tf)
  tf
}

test_that("replayr:::.decode_lmp() projects movement and preserves BT_SPECIAL", {
  tf <- .mk_lmp(c(10, 251, 3, 0x81))
  on.exit(unlink(tf))
  mv <- replayr:::.decode_lmp(analog = "quantized", tf)
  expect_true(mv$inputs[1L, 1L, 4L])
  expect_true(mv$inputs[1L, 1L, 2L])
  expect_false(mv$inputs[1L, 1L, 8L])
  expect_equal(mv$commands, 0x81L)
  expect_equal(mv$header$angleturn[1L, 1L], 3L)
})

test_that("replayr:::.decode_lmp() rejects a truncated multiplayer tic", {
  tf <- .mk_lmp(c(0, 0, 0, 0, 1, 2), active = c(1L, 1L, 0L, 0L), end = FALSE)
  on.exit(unlink(tf))
  expect_error(replayr:::.decode_lmp(analog = "quantized", tf), "truncated Doom demo")
})

test_that("read_lmp rejects PrBoom+ extended-format demos with a clear message", {
  skip_if_not(length(extended_files) > 0L,
              "Extended-format demo fixtures not available")
  for (f in extended_files) {
    err <- tryCatch(replayr:::.decode_lmp(analog = "quantized", f), error = function(e) conditionMessage(e))
    expect_true(is.character(err), info = paste("file:", basename(f)))
    # We expect either "extended-format" or "not appear to be a Doom 1.9 demo"
    expect_true(grepl("extended-format|Doom 1\\.9 demo", err),
                info = paste("file:", basename(f), "err:", err))
  }
})

test_that("read_lmp parses a vanilla Doom demo into the standard movie shape", {
  skip_if_not(length(vanilla_files) > 0L,
              "Vanilla Doom .lmp not available (drop one in doom_demos/lmp/)")
  for (f in vanilla_files) {
    mv <- replayr:::.decode_lmp(analog = "quantized", f)
    expect_s3_class(mv, "replayr_movie")
    expect_identical(mv$header[["_format"]], "lmp")
    # Skill must be a stringified 0..4
    expect_true(as.integer(mv$header$skill) %in% 0:4,
                info = paste("file:", basename(f)))
    # inputs is (n_frames, 4, 8) -- 4 player slots, 8-button NES-shape
    expect_equal(dim(mv$inputs)[2], 4L)
    expect_equal(dim(mv$inputs)[3], 8L)
    # forwardmove / sidemove / angleturn matrices are n_frames x 4
    expect_equal(dim(mv$header$forwardmove)[2], 4L)
    expect_equal(nrow(mv$header$forwardmove), n_frames(mv))
  }
})

test_that("read_movie dispatches .lmp to read_lmp", {
  mv <- read_movie(fixture_path("sample.lmp"))
  expect_identical(mv$header[["_format"]], "lmp")
})

test_that("supported_formats() includes .lmp", {
  expect_true(".lmp" %in% supported_formats())
})


.mk_boom <- function(version = 202L, compatibility = 0L, records = c(25, 231, 192, 1),
                     active = c(1L, 0L, 0L, 0L), tail = raw()) {
  options <- raw(if (version == 200L) 256L else 64L)
  options[7:9] <- as.raw(c(1, 0, 1))
  options[11:14] <- as.raw(c(1, 2, 3, 4))
  header <- c(as.raw(c(version, 0x1d, 0x42, 0x6f, 0x6f, 0x6d, 0xe6,
                      compatibility, 3, 1, 2, 0, 0)), options, as.raw(active), raw(28))
  tf <- tempfile(fileext = ".lmp")
  writeBin(c(header, as.raw(records), as.raw(0x80), tail), tf)
  tf
}

test_that("Boom 2.00-2.02 preserves options, commands, and all active players", {
  paths <- character()
  on.exit(unlink(paths))
  records <- c(25, 231, 192, 1, 206, 50, 127, 2,
               0, 0, 0, 0x84, 1, 255, 128, 0x1c)
  for (version in 200:202) for (compatibility in 0:1) {
    tf <- .mk_boom(version, compatibility, records, c(1, 0, 1, 0), charToRaw("footer"))
    paths <- c(paths, tf)
    mv <- read_lmp(tf)
    expect_equal(n_frames(mv), 2L)
    expect_identical(mv$header$version, as.character(version))
    expect_identical(mv$header$compatibilityFlag, compatibility)
    expect_identical(mv$header$enabledPorts, c(1L, 3L))
    expect_identical(mv$source_tail, charToRaw("footer"))
    expect_equal(length(mv$source_header), if (version == 200L) 301L else 109L)
    expect_identical(as.vector(t(mv$source_packets)), as.raw(records))
    expect_equal(unname(analog_channels(mv, 1L)), matrix(c(25, -25, -64, 0, 0, 0), ncol = 3L, byrow = TRUE))
    expect_equal(unname(analog_channels(mv, 3L)), matrix(c(-50, 50, 127, 1, -1, -128), ncol = 3L, byrow = TRUE))
    expect_identical(mv$header$gameOptions[7:9], as.raw(c(1, 0, 1)))
    expect_true(player(mv, 1L)[1L, match("a", mv$button_keys)])
    expect_true(player(mv, 3L)[1L, match("b", mv$button_keys)])
    expect_false(any(player(mv, 1L)[2L, ]))
    expect_equal(mv$commands, c(0L, 0x84L))
    expect_equal(mv$header$weaponselect[2L, 3L], 3L)
  }
})

test_that("Boom validates signatures and lengths before reading commands", {
  tf <- .mk_boom()
  on.exit(unlink(tf))
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  bad <- bytes; bad[3L] <- as.raw(0)
  writeBin(bad, tf)
  expect_error(read_lmp(tf), "signature")
  writeBin(bytes[1:100], tf)
  expect_error(read_lmp(tf), "truncated Boom demo header")
  writeBin(bytes[1:112], tf)
  expect_error(read_lmp(tf), "truncated Doom demo")
  writeBin(bytes[-length(bytes)], tf)
  expect_error(read_lmp(tf), "missing Doom demo end marker")
})
