make_bk2_integrity_fixture <- function() {
  root <- tempfile("bk2-integrity-source-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  writeLines(
    c("Platform NES", "emuVersion Version 2.9", "Author Alice"),
    file.path(root, "Header.txt")
  )
  writeLines(c(
    "[Input]", "LogKey:#Reset|Power|#P1 Up|P1 Down|P1 Left|P1 Right|P1 Start|P1 Select|P1 B|P1 A|",
    "|..|.......A|", "[/Input]"
  ), file.path(root, "Input Log.txt"))
  path <- tempfile(fileext = ".bk2")
  zip::zip(path, c("Header.txt", "Input Log.txt"), root = root, compression_level = 0L)
  path
}
alter_bk2_integrity_bytes <- function(path, from, to) {
  from <- charToRaw(from)
  to <- charToRaw(to)
  stopifnot(length(from) == length(to))
  data <- readBin(path, "raw", file.info(path)$size)
  for (at in grepRaw(from, data, fixed = TRUE, all = TRUE))
    data[seq.int(at, length.out = length(from))] <- to
  writeBin(data, path)
}
test_that("BK2 input checksums are required before imports or callbacks", {
  path <- make_bk2_integrity_fixture()
  on.exit(unlink(path))
  expect_identical(unname(press_counts(read_bk2(path))["A"]), 1L)
  alter_bk2_integrity_bytes(path, "|..|.......A|", "|..|......B.|")
  before <- list.dirs(tempdir(), recursive = FALSE)
  expect_error(read_bk2(path), "corrupt|extract|CRC|checksum")
  calls <- 0L
  expect_error(
    read_bk2_chunks(path, function(x) calls <<- calls + 1L, chunk_size = 1L),
    "corrupt|extract|CRC|checksum"
  )
  expect_identical(calls, 0L)
  expect_setequal(list.dirs(tempdir(), recursive = FALSE), before)
})
test_that("complete metadata with a bad CRC warns without discarding a valid log", {
  path <- make_bk2_integrity_fixture()
  on.exit(unlink(path))
  alter_bk2_integrity_bytes(path, "Author Alice", "Author Carol")
  expect_warning(movie <- read_bk2(path), "metadata integrity check failed for Header.txt")
  expect_identical(movie$header$Author, "Carol")
  expect_identical(unname(press_counts(movie)["A"]), 1L)
  expect_warning(
    chunks <- read_bk2_chunks(path, press_counts, chunk_size = 1L),
    "metadata integrity check failed for Header.txt"
  )
  expect_identical(unname(chunks[[1L]]["A"]), 1L)
  expect_identical(attr(chunks, "observations"), 1)
})
test_that("BK2 temporary files are removed when a callback fails", {
  path <- make_bk2_integrity_fixture()
  on.exit(unlink(path))
  before <- list.dirs(tempdir(), recursive = FALSE)
  expect_error(
    read_bk2_chunks(path, function(x) stop("callback failure"), chunk_size = 1L),
    "callback failure"
  )
  expect_setequal(list.dirs(tempdir(), recursive = FALSE), before)
})
