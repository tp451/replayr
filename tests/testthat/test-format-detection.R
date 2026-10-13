# read_movie(format = ) and recognition of a format by the content of a file.
detect_fixture <- function(file) system.file("extdata", file, package = "replayr", mustWork = TRUE)
renamed <- function(file, ext, directory) {
  path <- file.path(directory, paste0(tools::file_path_sans_ext(basename(file)), "-copy", ext))
  file.copy(detect_fixture(file), path, overwrite = TRUE)
  path
}
same_recording <- function(a, b) {
  a$source_path <- b$source_path <- NA_character_
  identical(a, b)
}
test_that("no bundled recording shows another format than its extension", {
  files <- list.files(system.file("extdata", package = "replayr"), recursive = TRUE, full.names = TRUE)
  registry <- replayr:::.FORMAT_REGISTRY
  shown <- 0L
  for (file in files) {
    ext <- tolower(tools::file_ext(file))
    if (!ext %in% registry$extension) next
    sign <- replayr:::.sniff_format(file)
    if (is.na(sign)) next
    shown <- shown + 1L
    expect_true(replayr:::.same_format_family(ext, sign), info = paste(basename(file), "shows", sign))
  }
  expect_gt(shown, 50L)
  expect_true(all(names(replayr:::.FORMAT_SIGNATURES) %in% registry$extension))
  # Signatures do not contain one another, so the first match is the only one.
  signatures <- replayr:::.FORMAT_SIGNATURES
  for (a in names(signatures)) for (b in setdiff(names(signatures), a)) {
    shorter <- min(length(signatures[[a]]), length(signatures[[b]]))
    expect_false(identical(signatures[[a]][seq_len(shorter)], signatures[[b]][seq_len(shorter)]), info = paste(a, b))
  }
})
test_that("a recording under another extension is known by its signature", {
  directory <- tempfile("detect-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  cases <- c(
    smv = "sample.smv", fcm = "sample.fcm", vbm = "sample.vbm", m64 = "sample.m64", dtm = "sample.dtm",
    gmv = "sample.gmv", pxm = "sample.pxm", pjm = "sample.pjm", fm2 = "sample.fm2", bk2 = "sample.bk2",
    lsmv = "sample.lsmv", fmv = "legacy/buttons.fmv", mmv = "legacy/sms.mmv", mcm = "legacy/pce.mcm",
    zmv = "legacy/holds.zmv", ctm = "legacy/devices.ctm", ctas = "computers/two-player-actions.ctas",
    wtf = "computers/keyboard-jump.wtf", jrsr = "computers/keyboard-mouse.jrsr",
    omr = "computers/keyboard-joystick.omr", mar = "expanded/arcade-dual-joysticks.mar",
    bkm = "expanded/legacy-n64.bkm"
  )
  for (format in names(cases)) {
    expected <- suppressWarnings(read_movie(detect_fixture(cases[[format]])))
    for (ext in c(".dat", "")) {
      path <- renamed(cases[[format]], ext, directory)
      expect_identical(replayr:::.sniff_format(path), format, info = format)
      expect_true(same_recording(suppressWarnings(read_movie(path)), expected), info = paste(format, ext))
    }
  }
  # A BizHawk archive that was named .zip is a recording, not a download.
  zipped <- renamed("sample.bk2", ".zip", directory)
  expect_true(same_recording(read_movie(zipped), read_movie(detect_fixture("sample.bk2"))))
  # An archive of recordings is still searched.
  archive <- file.path(directory, "two.zip")
  zip::zip(archive, detect_fixture(c("sample.fm2", "sample.smv")), mode = "cherry-pick")
  expect_identical(replayr:::.sniff_format(archive), NA_character_)
  expect_error(read_movie(archive), "Archive contains 2 recording members")
  expect_identical(read_movie(archive, member = "sample.smv")$header[["_format"]], "smv")
})
test_that("format names what the content does not show", {
  directory <- tempfile("detect-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  # Doom demos, gz macros and the text movies of DeSmuME have no signature.
  for (file in c("sample.lmp", "legacy/buttons.gzm", "legacy/touch-v2.dsm", "computers/dual-stick-menu.ltm")) {
    format <- tools::file_ext(file)
    path <- renamed(file, ".dat", directory)
    expect_identical(replayr:::.sniff_format(path), NA_character_, info = file)
    expect_error(read_movie(path), "unsupported movie format: .dat .* name its format with `format`", info = file)
    expected <- suppressWarnings(read_movie(detect_fixture(file)))
    expect_true(same_recording(suppressWarnings(read_movie(path, format = format)), expected), info = file)
  }
  path <- renamed("sample.lmp", ".dat", directory)
  expect_true(same_recording(read_movie(path, format = ".LMP"), read_movie(path, format = "lmp")))
  expect_error(read_movie(path, format = "xyz"), "format must be one of the extensions of supported_formats")
  expect_error(read_movie(path, format = c("lmp", "fm2")), "format must be one of the extensions")
  expect_error(read_movie(path, format = NA), "format must be one of the extensions")
  # The named format is what the reader then requires.
  expect_error(read_movie(path, format = "smv"), "not an SMV file")
  # Reader arguments pass through with a named format.
  n64 <- renamed("sample.m64", ".bin", directory)
  expect_gt(n_buttons(read_movie(n64, analog = "cardinal8")), n_buttons(read_movie(n64)))
})
test_that("an extension that contradicts the content is refused with the format shown", {
  directory <- tempfile("detect-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  wrong <- renamed("sample.smv", ".fm2", directory)
  expect_error(
    read_movie(wrong),
    "sample-copy.fm2 has the extension .fm2 but the signature of a .smv recording. Use format = \"smv\" to read it as one.",
    fixed = TRUE
  )
  expect_identical(read_movie(wrong, format = "smv")$header[["_format"]], "smv")
  expect_error(read_movie(renamed("sample.bk2", ".lsmv", directory)), "the signature of a .bk2 recording")
  expect_error(read_movie(renamed("sample.m64", ".dtm", directory)), "the signature of a .m64 recording")
  # Extensions that name one layout do not contradict each other.
  expect_s3_class(read_movie(renamed("expanded/gba-input.gbmv", ".bk2", directory)), "replayr_movie")
  expect_s3_class(read_movie(renamed("computers/keyboard-jump.wtf", ".hgm", directory)), "replayr_movie")
  expect_s3_class(read_movie(renamed("expanded/legacy-sms.tas", ".bkm", directory)), "replayr_movie")
})
