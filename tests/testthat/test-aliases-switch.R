# aliases = FALSE: every control of a recording keeps a column of its own.
sample_movie <- function(file, ...) {
  path <- system.file("extdata", file, package = "replayr", mustWork = TRUE)
  suppressWarnings(read_movie(path, ...))
}
test_that("without aliases a light gun's trigger and buttons stay apart", {
  shared <- sample_movie("paper/light-gun.bk2")
  gun <- sample_movie("paper/light-gun.bk2", aliases = FALSE)
  layout <- button_layout(gun)
  expect_identical(layout$key, c("b", "gun_trigger", "offscreen_shot"))
  expect_identical(as.character(layout$id), c("7", "control:gun_trigger", "control:offscreen_shot"))
  expect_identical(layout$name, c("A", "Trigger", "Offscreen Shot"))
  expect_null(gun$source_inputs)
  expect_null(gun$source_layout)
  # The same states as the source controls kept beside the shared layout.
  at <- match(shared$source_layout$key, layout$key)
  expect_identical(unname(gun$inputs[, , at, drop = FALSE]), unname(shared$source_inputs))
  expect_identical(analog_channels(gun), analog_channels(shared))
})
test_that("a shared column is the union of the separate ones", {
  shared <- sample_movie("computers/dual-stick-menu.ltm")
  apart <- sample_movie("computers/dual-stick-menu.ltm", aliases = FALSE)
  keys <- button_layout(apart)$key
  expect_true(all(c("a", "mouse_left") %in% keys))
  for (p in seq_len(n_players(shared))) {
    pad <- apart$inputs[, p, match("a", keys)]
    mouse <- apart$inputs[, p, match("mouse_left", keys)]
    expect_identical(shared$inputs[, p, match("a", button_layout(shared)$key)], pad | mouse)
  }
  # The Intellivision disc keeps its sixteen directions.
  disc <- sample_movie("expanded/sixteen-direction-disc.bk2", aliases = FALSE)
  expect_equal(sum(startsWith(button_layout(disc)$key, "intv_disc_")), 16L)
  expect_false(any(button_layout(disc)$kind == "left_direction"))
  expect_equal(unname(rowSums(disc$inputs[, 1L, startsWith(button_layout(disc)$key, "intv_disc_")])), rep(1, 16))
})
test_that("every bundled recording reads both ways with the same source controls", {
  folder <- system.file("extdata", package = "replayr")
  files <- list.files(folder, recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("[.](md|json|csv|txt)$", files)]
  read <- 0L
  for (file in files) {
    shared <- tryCatch(suppressWarnings(read_movie(file)), error = function(e) NULL)
    if (is.null(shared)) next
    read <- read + 1L
    apart <- suppressWarnings(read_movie(file, aliases = FALSE))
    layout <- button_layout(apart)
    expect_identical(dim(apart$inputs)[1:2], dim(shared$inputs)[1:2], info = basename(file))
    expect_false(anyDuplicated(layout$key) > 0L, info = basename(file))
    expect_false(anyDuplicated(layout$name) > 0L, info = basename(file))
    if (is.null(shared$source_layout)) {
      # Nothing is shared in this recording: the switch changes nothing.
      expect_identical(apart$inputs, shared$inputs, info = basename(file))
      expect_identical(layout, button_layout(shared), info = basename(file))
    } else {
      at <- match(shared$source_layout$key, layout$key)
      expect_false(anyNA(at), info = basename(file))
      expect_identical(unname(apart$inputs[, , at, drop = FALSE]), unname(shared$source_inputs), info = basename(file))
      expect_null(apart$source_layout)
    }
    expect_identical(apart$analog, shared$analog, info = basename(file))
  }
  expect_gt(read, 60L)
})
test_that("every reader takes the switch", {
  readers <- grep("^read_", getNamespaceExports("replayr"), value = TRUE)
  expect_gt(length(readers), 30L)
  for (reader in readers) {
    expect_true("aliases" %in% names(formals(get(reader, envir = asNamespace("replayr")))), info = reader)
  }
  path <- system.file("extdata", "sample.fm2", package = "replayr")
  expect_error(read_movie(path, aliases = NA), "aliases must be TRUE or FALSE")
  expect_error(read_fm2(path, aliases = "no"), "aliases must be TRUE or FALSE")
  counts <- read_bk2_chunks(
    system.file("extdata", "paper", "light-gun.bk2", package = "replayr"),
    function(chunk) button_layout(chunk)$key, chunk_size = 2L, aliases = FALSE
  )
  expect_true(all(vapply(counts, function(keys) "gun_trigger" %in% keys, logical(1))))
})
