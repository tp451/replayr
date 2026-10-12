# Original wire records; expectations follow Dega's EOF-based playback and
# PSXjin's fixed-width byte rules, independently of header summary counts.
.warning_mmv <- function(declared, packets, tail = raw()) {
  header <- raw(244L)
  header[1:4] <- as.raw(c(77, 77, 86, 0))
  for (item in list(
    c(4L, 0x1160L), c(8L, declared), c(16L, 1L),
    c(24L, 244L), c(28L, 2L)
  )) {
    header[item[1L] + 1:4] <- writeBin(as.integer(item[2L]), raw(), size = 4L, endian = "little")
  }
  path <- tempfile(fileext = ".mmv")
  writeBin(c(header, as.raw(t(packets)), tail), path)
  path
}
test_that("MMV uses complete packets at EOF while preserving a stale header count", {
  packets <- rbind(c(0, 0), c(16, 32), c(8, 1))
  paths <- character()
  on.exit(unlink(paths))
  for (declared in c(0L, 1L, 3L, 99L)) {
    path <- .warning_mmv(declared, packets)
    paths <- c(paths, path)
    expect_no_warning(movie <- read_mmv(path))
    expect_equal(n_frames(movie), 3L)
    expect_equal(as.integer(movie$header$declaredFrameCount), declared)
    expect_equal(as.integer(movie$header$availableFrameCount), 3L)
    expect_equal(as.integer(movie$header$frameCountDifference), declared - 3L)
    keys <- button_layout(movie)$key
    expect_identical(as.logical(player(movie, 1L)[, match("b", keys)]), c(FALSE, TRUE, FALSE))
    expect_identical(as.logical(player(movie, 2L)[, match("a", keys)]), c(FALSE, TRUE, FALSE))
    expect_true(player(movie, 1L)[3L, match("dpad_right", keys)])
    expect_true(player(movie, 2L)[3L, match("dpad_up", keys)])
  }
})
test_that("MMV still warns about incomplete input and preserves the actual byte", {
  path <- .warning_mmv(1L, rbind(c(0, 0), c(16, 32)), as.raw(10))
  on.exit(unlink(path))
  expect_warning(movie <- read_mmv(path), "incomplete frame")
  expect_equal(n_frames(movie), 2L)
  expect_identical(movie$source_tail, as.raw(10))
  expect_equal(sum(movie$inputs), 2L)
})
test_that("PJM ignored separators and NUL button bytes have explicit public identities", {
  header <- raw(60L)
  header[1:4] <- charToRaw("PJM ")
  header[5L] <- as.raw(2L)
  header[13L] <- as.raw(64L) # MOVIE_FLAG_IS_TEXT
  header[15:16] <- as.raw(c(4L, 8L))
  header[17:20] <- writeBin(50L, raw(), size = 4L, endian = "little")
  header[45:48] <- writeBin(60L, raw(), size = 4L, endian = "little")
  # Every record is 20 bytes. Square is the first character, Cross the second;
  # bytes 15,16,18,19,20 are skipped by the source reader. The command is byte17.
  first <- charToRaw("#.............||0|\r\n")
  second <- charToRaw(".X............||0|\r\n")
  first[c(15L, 16L, 18L, 19L, 20L)] <- as.raw(c(1, 2, 3, 4, 5))
  second[2L] <- as.raw(0L)
  path <- tempfile(fileext = ".pjm")
  on.exit(unlink(path))
  writeBin(c(header, first, second), path)
  expect_no_warning(movie <- read_pjm(path))
  expect_equal(n_frames(movie), 2L)
  expect_identical(movie$header$frameCountDifference, "48")
  keys <- button_layout(movie)$key
  expect_identical(as.logical(player(movie)[, match("y", keys)]), c(TRUE, FALSE))
  expect_identical(as.logical(player(movie)[, match("b", keys)]), c(FALSE, TRUE))
  expect_identical(movie$commands, c(0L, 0L))
  expect_equal(sum(movie$inputs), 2L)
  expect_identical(movie$header$noncanonicalSeparatorRecords, "1")
})
test_that("declared PJM text can consist entirely of a NUL record", {
  header <- raw(60L)
  header[1:4] <- charToRaw("PJM ")
  header[5L] <- as.raw(2L)
  header[13L] <- as.raw(64L)
  header[15:16] <- as.raw(c(4L, 8L))
  header[17L] <- as.raw(1L)
  header[45L] <- as.raw(60L)
  path <- tempfile(fileext = ".pjm")
  on.exit(unlink(path))
  writeBin(c(header, raw(20L)), path)
  expect_no_warning(movie <- read_pjm(path))
  expect_equal(n_frames(movie), 1L)
  expect_true(all(player(movie)))
  expect_equal(n_buttons(movie), 14L)
  expect_identical(movie$commands, 0L)
  expect_identical(movie$header$allNulRecordCount, "1")
})
test_that("declared PJM text distinguishes both multitap groups", {
  header <- raw(60L)
  header[1:4] <- charToRaw("PJM ")
  header[5L] <- as.raw(2L)
  header[13:14] <- as.raw(c(192L, 1L)) # Text and both port multitaps.
  header[15:16] <- as.raw(c(4L, 4L))
  header[17L] <- as.raw(1L)
  header[45L] <- as.raw(60L)
  fields <- rep("..............|", 8L)
  fields[1L] <- "#.............|" # Port 1, first pad: Square.
  fields[4L] <- ".X............|" # Port 1, fourth pad: Cross.
  fields[5L] <- "..O...........|" # Port 2, first pad: Circle.
  fields[8L] <- "...^..........|" # Port 2, fourth pad: Triangle.
  path <- tempfile(fileext = ".pjm")
  on.exit(unlink(path))
  writeBin(c(header, charToRaw(paste0(paste0(fields, collapse = ""), "0|\r\n"))), path)
  expect_no_warning(movie <- read_pjm(path))
  expect_equal(n_players(movie), 8L)
  expect_equal(n_frames(movie), 1L)
  keys <- button_layout(movie)$key
  for (pair in list(
    c(1L, match("y", keys)), c(4L, match("b", keys)),
    c(5L, match("a", keys)), c(8L, match("x", keys))
  )) {
    expect_true(movie$inputs[1L, pair[1L], pair[2L]])
  }
  expect_equal(sum(movie$inputs), 4L)
})
