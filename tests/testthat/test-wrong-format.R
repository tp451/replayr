# A reader refuses a file that is not of its format, and its message names
# the problem; none returns an empty or meaningless recording.
wrong_fixture <- function(file) system.file("extdata", file, package = "replayr", mustWork = TRUE)
wrong_inputs <- function(directory) {
  junk <- c(
    text = file.path(directory, "notes.txt"), empty = file.path(directory, "empty.bin"),
    random = file.path(directory, "random.bin"), zeros = file.path(directory, "zeros.bin")
  )
  writeLines(c("A few lines of ordinary text.", "Nothing here is an input recording."), junk[["text"]])
  file.create(junk[["empty"]])
  writeBin(as.raw((seq_len(4096L) * 131L + 17L) %% 256L), junk[["random"]])
  writeBin(raw(4096L), junk[["zeros"]])
  c(
    junk, fm2 = wrong_fixture("sample.fm2"), smv = wrong_fixture("sample.smv"), bk2 = wrong_fixture("sample.bk2"),
    dtm = wrong_fixture("sample.dtm"), lmp = wrong_fixture("sample.lmp"),
    ltm = wrong_fixture("computers/dual-stick-menu.ltm"), jrsr = wrong_fixture("computers/keyboard-mouse.jrsr"),
    dsm = wrong_fixture("legacy/touch-v2.dsm"), bkm = wrong_fixture("expanded/legacy-n64.bkm")
  )
}
test_that("the FM2 reader requires the signature of FCEUX", {
  directory <- tempfile("wrong-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  inputs <- wrong_inputs(directory)
  for (kind in setdiff(names(inputs), "fm2")) {
    path <- file.path(directory, paste0(kind, ".fm2"))
    file.copy(inputs[[kind]], path)
    expect_error(read_fm2(path), "not an FM2 file: an FCEUX movie begins with \"version 3\"", info = kind)
    # read_movie() names the format the content shows, where it shows one.
    expect_error(read_movie(path), "not an FM2 file|has the extension .fm2 but the signature of", info = kind)
  }
  # A header without the first line is not an FM2 file either.
  headless <- file.path(directory, "headless.fm2")
  writeLines(c("port0 1", "port1 0", "port2 0", "|0|.......A|||"), headless)
  expect_error(read_fm2(headless), "not an FM2 file")
  project <- file.path(directory, "text.fm3")
  file.copy(inputs[["text"]], project)
  expect_error(read_fm3(project), "not an FM3 file")
  expect_s3_class(read_fm2(wrong_fixture("sample.fm2")), "replayr_movie")
})
test_that("every reader refuses files of other formats", {
  directory <- tempfile("wrong-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  inputs <- wrong_inputs(directory)
  # Formats that are one layout under several names.
  same <- list(c("bk2", "tasproj", "gbmv"), c("bkm", "tas"), c("fm2", "fm3"), c("pxm", "pjm"))
  related <- function(a, b) any(vapply(same, function(g) all(c(a, b) %in% g), logical(1)))
  # An error raised by R itself and not by the reader reads like one of these.
  internal <- paste(
    "subscript out of bounds", "missing value where", "argument is of length zero", "embedded nul",
    "input string [0-9]+ is invalid", "cannot open the connection", "non-numeric argument",
    "arguments imply differing", "object '.*' not found", "invalid 'n' argument",
    sep = "|"
  )
  readers <- sub("^read_", "", grep("^read_", getNamespaceExports("replayr"), value = TRUE))
  readers <- setdiff(readers, c("movie", "bk2_chunks"))
  expect_gt(length(readers), 30L)
  tried <- 0L
  for (reader in readers) {
    read <- get(paste0("read_", reader), envir = asNamespace("replayr"))
    for (kind in names(inputs)) {
      if (kind == reader || related(kind, reader)) next
      path <- file.path(directory, paste0(kind, "-as.", reader))
      file.copy(inputs[[kind]], path, overwrite = TRUE)
      outcome <- tryCatch(suppressWarnings(read(path)), error = function(e) conditionMessage(e))
      tried <- tried + 1L
      expect_true(is.character(outcome), info = paste("read_", reader, " accepted a ", kind, " file", sep = ""))
      if (is.character(outcome)) expect_false(grepl(internal, outcome), info = paste(reader, kind, outcome))
    }
  }
  expect_gt(tried, 400L)
})
test_that("readers name what a file is not", {
  directory <- tempfile("wrong-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  text <- wrong_inputs(directory)[["text"]]
  as_format <- function(ext) {
    path <- file.path(directory, paste0("notes.", ext))
    file.copy(text, path, overwrite = TRUE)
    path
  }
  expect_error(read_bk2(as_format("bk2")), "not a BizHawk movie .* a ZIP archive is expected")
  expect_error(read_tasproj(as_format("tasproj")), "a ZIP archive is expected")
  expect_error(read_lsmv(as_format("lsmv")), "not an LSMV file: a ZIP archive is expected")
  expect_error(read_bkm(as_format("bkm")), "not a BizHawk BKM or TAS text movie")
  expect_error(read_omr(as_format("omr")), "not an openMSX replay: a gzip-compressed XML document is expected")
  expect_error(read_jrsr(as_format("jrsr")), "Invalid JRSR magic")
  expect_error(read_ctas(as_format("ctas")), "Invalid CoffeeTools header")
  # The layout of an FBM file is asked for only once the file is one.
  expect_error(read_fbm(as_format("fbm")), "Not a FinalBurn Alpha FBM recording")
  expect_error(read_fbm(wrong_fixture("expanded/synthetic-arcade.fbm")), "does not identify its input layout")
  # Compressed data that is not XML.
  packed <- file.path(directory, "packed.omr")
  con <- gzfile(packed, "wb")
  writeLines("not a document", con)
  close(con)
  expect_error(read_omr(packed), "not an openMSX replay: its content is not an XML document")
})
test_that("a path that is no file is reported as such by every entry point", {
  entries <- sort(c(grep("^read_", getNamespaceExports("replayr"), value = TRUE), "movie_members"))
  expect_gt(length(entries), 35L)
  folder <- tempfile("folder-")
  dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE))
  call_entry <- function(entry, path) {
    f <- get(entry, envir = asNamespace("replayr"))
    warned <- 0L
    message <- tryCatch(withCallingHandlers(
      {
        if (entry == "read_bk2_chunks") f(path, function(chunk) NULL) else f(path)
        "returned"
      },
      warning = function(w) {
        warned <<- warned + 1L
        invokeRestart("muffleWarning")
      }
    ), error = function(e) conditionMessage(e))
    list(message = message, warned = warned)
  }
  for (entry in entries) {
    ext <- if (entry %in% c("read_movie", "read_bk2_chunks")) "bk2" else if (entry == "movie_members") "zip" else sub("^read_", "", entry)
    absent <- file.path(tempdir(), paste0("no-such-recording.", ext))
    result <- call_entry(entry, absent)
    expect_identical(result$message, paste0("File not found: ", absent), info = entry)
    expect_identical(result$warned, 0L, info = entry)
    result <- call_entry(entry, folder)
    expect_identical(result$message, paste0("Not a file but a folder: ", folder), info = entry)
    expect_identical(result$warned, 0L, info = entry)
    for (path in list(NA_character_, 42, c("a.fm2", "b.fm2"), "", NULL)) {
      expect_identical(call_entry(entry, path)$message, "path must be one file path as a character string.", info = entry)
    }
  }
  # A relative path is looked up from the working directory, which is named.
  expect_error(read_movie("no-such-recording.fm2"), "File not found: no-such-recording.fm2 \\(working directory: ")
})
