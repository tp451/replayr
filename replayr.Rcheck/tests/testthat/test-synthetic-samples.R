test_that("one bundled synthetic sample exists for every supported format", {
  formats <- supported_formats()
  samples <- paste0("sample", formats)
  paths <- vapply(samples, function(sample) {
    path <- fixture_path(sample)
    if (is.null(path)) "" else path
  }, character(1L))

  expect_true(all(file.exists(paths)))
  expect_setequal(tools::file_ext(paths), sub("^\\.", "", formats))
})
