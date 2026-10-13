make_recording_archive <- function(names = "one.fm2", payload = NULL) {
  root <- tempfile("archive-source-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  if (is.null(payload)) payload <- paste0("version 3\nport0 1\nport1 0\n|0|R.......|||\n")
  for (name in names) {
    dir.create(dirname(file.path(root, name)), recursive = TRUE, showWarnings = FALSE)
    writeBin(charToRaw(payload), file.path(root, name))
  }
  path <- tempfile(fileext = ".zip")
  zip::zip(path, files = names, root = root, compression_level = 0L)
  path
}
replace_archive_bytes <- function(path, from, to) {
  bytes <- readBin(path, "raw", file.info(path)$size)
  from <- charToRaw(from)
  to <- charToRaw(to)
  stopifnot(length(from) == length(to))
  for (at in grepRaw(from, bytes, fixed = TRUE, all = TRUE))
    bytes[seq.int(at, length.out = length(from))] <- to
  writeBin(bytes, path)
}
test_that("ZIP selection preserves source identity and requires an unambiguous member", {
  path <- make_recording_archive(c("one.fm2", "two.fm2"))
  on.exit(unlink(path))
  expect_identical(movie_members(path)$member, c("one.fm2", "two.fm2"))
  expect_error(read_movie(path), "Archive contains 2")
  movie <- read_movie(path, member = "two.fm2")
  expect_identical(n_observations(movie), 1L)
  expect_true(player(movie)[1, "dpad_right"])
  expect_identical(movie$source_path, path)
  expect_identical(movie$source_member, "two.fm2")
  for (bad in list("", character(), NA_character_, c("one.fm2", "two.fm2"), 1L, "missing.fm2"))
    expect_error(read_movie(path, member = bad), "member must name")
  replace_archive_bytes(path, "two.fm2", "one.fm2")
  expect_error(read_movie(path, member = "one.fm2"), "Duplicate archive")
})
test_that("ZIP checksums are verified and extraction directories are cleaned", {
  path <- make_recording_archive()
  on.exit(unlink(path))
  before <- list.dirs(tempdir(), recursive = FALSE)
  expect_identical(n_observations(read_movie(path)), 1L)
  expect_setequal(list.dirs(tempdir(), recursive = FALSE), before)
  replace_archive_bytes(path, "R.......", "L.......")
  expect_error(read_movie(path), "corrupt|extract|CRC|checksum")
  expect_setequal(list.dirs(tempdir(), recursive = FALSE), before)
})
test_that("ZIP member type and case collisions are checked before extraction", {
  paths <- character()
  on.exit(unlink(paths))
  for (type in c("symlink", "directory")) {
    path <- make_recording_archive()
    paths <- c(paths, path)
    bytes <- readBin(path, "raw", file.info(path)$size)
    central <- grepRaw(as.raw(c(80, 75, 1, 2)), bytes, fixed = TRUE)[1L]
    bytes[central + 5L] <- as.raw(3L) # Unix creator, with source file type in st_mode.
    bytes[central + 38:41] <- if (type == "symlink") as.raw(c(0, 0, 255, 161)) else as.raw(c(16, 0, 192, 65))
    writeBin(bytes, path)
    expect_error(read_movie(path, member = "one.fm2"), "regular file")
  }
  path <- make_recording_archive(c("one.fm2", "two.fm2"))
  paths <- c(paths, path)
  replace_archive_bytes(path, "two.fm2", "ONE.FM2")
  expect_error(read_movie(path, member = "one.fm2"), "Duplicate archive")
})
test_that("ZIP imports handle absent recordings and flatten directory paths", {
  path <- make_recording_archive("notes.txt")
  nested <- make_recording_archive("folder/one.fm2")
  on.exit(unlink(c(path, nested)))
  expect_identical(nrow(movie_members(path)), 0L)
  expect_error(read_movie(path), "Archive contains 0")
  expect_error(read_movie(path, member = "notes.txt"), "member must name")
  movie <- read_movie(nested)
  expect_identical(n_observations(movie), 1L)
  expect_identical(movie$source_member, "folder/one.fm2")
  replace_archive_bytes(nested, "folder", "../xxx")
  movie <- read_movie(nested)
  expect_identical(n_observations(movie), 1L)
  expect_identical(movie$source_member, "../xxx/one.fm2")
})
test_that("ZIP imports reject corrupt sizes and Windows-special file names", {
  path <- make_recording_archive()
  special <- make_recording_archive()
  on.exit(unlink(c(path, special)))
  bytes <- readBin(path, "raw", file.info(path)$size)
  central <- grepRaw(as.raw(c(80, 75, 1, 2)), bytes, fixed = TRUE)[1L]
  bytes[central + 24L] <- as.raw(as.integer(bytes[central + 24L]) + 1L)
  writeBin(bytes, path)
  expect_error(read_movie(path), "corrupt|extract|header")
  replace_archive_bytes(special, "one.fm2", "C:o.fm2")
  expect_error(read_movie(special), "unsafe file name")
})
