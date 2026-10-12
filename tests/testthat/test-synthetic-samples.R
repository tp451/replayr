test_that("every supported extension has an importable original example", {
  files <- list.files(system.file("extdata", package = "replayr", mustWork = TRUE),
                      recursive = TRUE, full.names = TRUE)
  extensions <- tolower(tools::file_ext(files))
  for (format in sub("^\\.", "", supported_formats())) {
    choices <- files[extensions == format]
    if (format == "fbm") choices <- choices[basename(choices) == "synthetic-arcade.fbm"]
    expect_true(length(choices) > 0L, info = format)
    if (!length(choices)) next
    movie <- if (format == "fbm") read_movie(choices[1L], game = "ghouls") else
      read_movie(choices[1L])
    expect_true(inherits(movie, c("replayr_movie", "replayr_poll_stream")), info = format)
    expect_true(n_frames(movie) > 0L, info = format)
    expect_false(anyNA(movie$inputs), info = format)
  }
})

