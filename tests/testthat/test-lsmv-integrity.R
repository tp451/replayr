make_lsmv_integrity_fixture <- function() {
  root <- tempfile("lsmv-integrity-source-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  writeLines(c("F.|........A...", "F.|B..........."), file.path(root, "input"))
  writeLines("Alice", file.path(root, "authors"))
  path <- tempfile(fileext = ".lsmv")
  zip::zip(path, c("input", "authors"), root = root, compression_level = 0L)
  path
}

alter_lsmv_integrity_bytes <- function(path, from, to) {
  from <- charToRaw(from); to <- charToRaw(to)
  stopifnot(length(from) == length(to))
  data <- readBin(path, "raw", file.info(path)$size)
  for (at in grepRaw(from, data, fixed = TRUE, all = TRUE))
    data[seq.int(at, length.out = length(from))] <- to
  writeBin(data, path)
}

test_that("LSMV verifies all input bytes and keeps a bad metadata CRC visible", {
  path <- make_lsmv_integrity_fixture()
  on.exit(unlink(path))
  movie <- read_lsmv(path)
  expect_identical(n_frames(movie), 2L)
  expect_identical(unname(press_counts(movie)[c("A", "B")]), c(1L, 1L))
  alter_lsmv_integrity_bytes(path, "Alice", "Carol")
  expect_warning(movie <- read_lsmv(path), "metadata integrity check failed for authors")
  expect_identical(movie$header$authors, "Carol")
  expect_identical(unname(press_counts(movie)[c("A", "B")]), c(1L, 1L))
  alter_lsmv_integrity_bytes(path, "........A...", ".........X..")
  before <- list.dirs(tempdir(), recursive = FALSE)
  expect_error(read_lsmv(path), "corrupt|extract|CRC|checksum")
  expect_setequal(list.dirs(tempdir(), recursive = FALSE), before)
})

test_that("LSMV rejects oversized inputs before extraction instead of truncating", {
  path <- make_lsmv_integrity_fixture()
  on.exit(unlink(path))
  before <- list.dirs(tempdir(), recursive = FALSE)
  expect_error(read_lsmv(path, max_input_bytes = 1), class = "replayr_resource_limit")
  expect_setequal(list.dirs(tempdir(), recursive = FALSE), before)
  expect_identical(n_frames(read_movie(path, max_input_bytes = 100)), 2L)
  for (limit in c(0, Inf, NA_real_, 2^31))
    expect_error(read_lsmv(path, max_input_bytes = limit), "max_input_bytes")
  # A central-directory declaration beyond the former 1 GB read cap must be
  # rejected from its size alone. The test does not allocate a giant payload.
  data <- readBin(path, "raw", file.info(path)$size)
  central <- grepRaw(as.raw(c(80, 75, 1, 2)), data, fixed = TRUE)[1L]
  size <- 1000000100
  data[central + 24:27] <- as.raw(floor(size / 256^(0:3)) %% 256)
  writeBin(data, path)
  expect_error(read_lsmv(path), "corrupt|header|exceeding")
  expect_setequal(list.dirs(tempdir(), recursive = FALSE), before)
})
