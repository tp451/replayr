# One registry of formats serves read_movie(), the listing of ZIP archives,
# supported_formats() and recording_info().
test_that("the registry names an exported reader for every extension", {
  registry <- replayr:::.FORMAT_REGISTRY
  expect_identical(names(registry), c("extension", "reader", "emulator", "platform", "structure"))
  # One extension is that of two formats, which have names of their own.
  expect_false(anyDuplicated(registry[c("extension", "structure")]) > 0L)
  expect_identical(unique(registry$extension[duplicated(registry$extension)]), "txt")
  expect_identical(registry$structure[registry$extension == "txt"], c("atari_gc", "atari_head"))
  expect_identical(registry$extension, tolower(registry$extension))
  expect_false(anyNA(registry$emulator) || any(!nzchar(registry$emulator)))
  exported <- getNamespaceExports("replayr")
  expect_true(all(registry$reader %in% exported))
  # Every format reader of the package is reached through the registry.
  readers <- setdiff(grep("^read_", exported, value = TRUE), c("read_movie", "read_bk2_chunks"))
  expect_setequal(unique(registry$reader), readers)
  # The formats under one extension are the ones known by their first line.
  shared <- registry$extension == "txt"
  expect_identical(registry$structure[shared], names(replayr:::.TABLE_FIRST_LINES))
  for (i in seq_len(nrow(registry))) {
    name <- if (shared[i]) registry$structure[i] else registry$extension[i]
    expect_identical(replayr:::.format_reader(name), get(registry$reader[i], envir = asNamespace("replayr")))
  }
  # One reader takes both formats of the extension and tells them apart.
  expect_identical(replayr:::.format_reader("txt"), read_txt)
  expect_identical(replayr:::.format_reader("FM2"), read_fm2)
  expect_null(replayr:::.format_reader("xyz"))
  # A platform the registry implies is one recording_info() can time or name.
  implied <- registry$platform[!is.na(registry$platform)]
  expect_true(all(implied %in% c(names(replayr:::.NOMINAL_FRAME_RATES), "N64", "Arcade", "MSX", "PC")))
})
test_that("supported_formats() is the registry", {
  registry <- replayr:::.FORMAT_REGISTRY
  expect_identical(supported_formats(), unique(paste0(".", registry$extension)))
  expect_true(".txt" %in% supported_formats())
  details <- supported_formats(details = TRUE)
  expect_s3_class(details, "data.frame")
  expect_identical(details$extension, paste0(".", registry$extension))
  expect_identical(details[c("reader", "emulator", "platform")], registry[c("reader", "emulator", "platform")])
  expect_identical(details$emulator[details$extension == ".fm2"], "FCEUX")
  expect_identical(details$reader[details$extension == ".hgm"], "read_wtf")
  # A structure is shown as the extension it is; the two under .txt are none.
  own <- registry$structure %in% registry$extension
  expect_identical(details$structure[own], paste0(".", registry$structure[own]))
  expect_identical(details$structure[!own], c("atari_gc", "atari_head"))
  expect_identical(details$reader[!own], c("read_txt", "read_txt"))
  expect_error(supported_formats(details = NA), "details must be TRUE or FALSE")
})
test_that("37 extensions have 33 file structures", {
  registry <- replayr:::.FORMAT_REGISTRY
  expect_identical(nrow(registry), 38L)
  expect_identical(length(unique(registry$extension)), 37L)
  expect_identical(length(unique(registry$structure)), 33L)
  tables <- registry$extension == "txt"
  # A structure is named by an extension that has its own structure.
  expect_true(all(registry$structure[!tables] %in% registry$extension[registry$extension == registry$structure]))
  shared <- registry[registry$extension != registry$structure & !tables, ]
  expect_identical(stats::setNames(shared$structure, shared$extension),
    c(tas = "bkm", tasproj = "bk2", gbmv = "bk2", hgm = "wtf", fm3 = "fm2")[shared$extension])
  # The reader of the structure reads a file of the extension to the same values.
  files <- list.files(system.file("extdata", package = "replayr"), recursive = TRUE, full.names = TRUE)
  for (i in seq_len(nrow(shared))) {
    file <- files[match(shared$extension[i], tolower(tools::file_ext(files)))]
    own <- replayr:::.format_reader(shared$extension[i])(file)
    other <- replayr:::.format_reader(shared$structure[i])(file)
    for (part in c("inputs", "analog", "commands")) {
      expect_identical(own[[part]], other[[part]], info = paste(shared$extension[i], part))
    }
    expect_true(replayr:::.same_format_family(shared$extension[i], shared$structure[i]))
  }
  expect_true(replayr:::.same_format_family("tasproj", "gbmv"))
  expect_false(replayr:::.same_format_family("fm2", "bk2"))
  expect_false(replayr:::.same_format_family("fm2", "xyz"))
  # The extension of two formats is of the family of each; they are not of one.
  expect_true(replayr:::.same_format_family("txt", "atari_head"))
  expect_true(replayr:::.same_format_family("atari_gc", "txt"))
  expect_false(replayr:::.same_format_family("atari_gc", "atari_head"))
  expect_false(replayr:::.same_format_family("txt", "fm2"))
})
test_that("the source list of the package names every extension", {
  notice <- readLines(system.file("COPYRIGHTS", package = "replayr"), warn = FALSE)
  for (extension in toupper(replayr:::.FORMAT_REGISTRY$extension)) {
    expect_true(any(grepl(paste0("\\b", extension, "\\b"), notice)), info = extension)
  }
})
test_that("read_movie() and movie_members() know exactly the registered extensions", {
  registry <- replayr:::.FORMAT_REGISTRY
  files <- list.files(system.file("extdata", package = "replayr"), recursive = TRUE, full.names = TRUE)
  extensions <- tolower(tools::file_ext(files))
  # A bundled recording of every format is read by its registered reader.
  shown <- recording_format(files)
  for (i in seq_len(nrow(registry))) {
    extension <- registry$extension[i]
    # Of the formats under one extension, the file that shows the format.
    file <- if (extension == "txt") files[match(registry$structure[i], shown)] else files[match(extension, extensions)]
    expect_false(is.na(file), info = registry$structure[i])
    if (is.na(file) || extension == "fbm") next
    reader <- get(registry$reader[i], envir = asNamespace("replayr"))
    expect_identical(suppressWarnings(read_movie(file)), suppressWarnings(reader(file)), info = extension)
  }
  directory <- tempfile("registry-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  single <- setdiff(unique(registry$extension), "txt")
  members <- file.path(directory, c(paste0("recording.", single), "recording.txt", "notes.txt", "picture.png"))
  for (member in members) writeLines("x", member)
  # A .txt member is a recording where its first line shows one of the tables.
  tables <- files[!is.na(match(shown, c("atari_gc", "atari_head")))]
  file.copy(tables, directory)
  archive <- file.path(directory, "all.zip")
  zip::zip(archive, c(members, file.path(directory, basename(tables))), mode = "cherry-pick")
  listed <- movie_members(archive)
  expect_setequal(listed$format, c(single, "atari_gc", "atari_head"))
  expect_false(any(c("recording.txt", "notes.txt", "picture.png") %in% listed$member))
  expect_identical(listed$format[match(basename(tables), listed$member)], shown[!is.na(match(shown, c("atari_gc", "atari_head")))])
  trial <- tables[basename(tables) == "atari-head.txt"]
  expect_identical(player(read_movie(archive, member = "atari-head.txt")), player(read_txt(trial)))
  expect_error(read_movie(archive, member = "notes.txt"), "member must name an input recording")
  unknown <- file.path(directory, "recording.xyz")
  writeLines("x", unknown)
  expect_error(read_movie(unknown), "unsupported movie format: .xyz \\(recording.xyz\\). supported_formats\\(\\) lists")
  # A format that serves one console implies its platform.
  expect_identical(recording_info(read_movie(system.file("extdata", "sample.m64", package = "replayr")))$platform, "N64")
  expect_identical(recording_info(read_movie(system.file("extdata", "sample.smv", package = "replayr")))$platform, "SNES")
})
