test_that("player(), press_counts(), n_*() respect array shape", {
  mv <- read_fm2(fixture_path("sample.fm2"))
  p1 <- player(mv, 1L)
  expect_true(is.matrix(p1))
  expect_type(p1, "logical")
  expect_equal(nrow(p1), n_observations(mv))
  expect_equal(ncol(p1), n_buttons(mv))
  # One naming scheme: the keys of the layout, as in polls().
  expect_equal(colnames(p1), button_layout(mv)$key)
  expect_identical(attr(p1, "button_names"), button_layout(mv)$name)
  # Only the IDs and the labels travel with the matrix.
  expect_setequal(names(attributes(p1)), c("dim", "dimnames", "button_ids", "button_names"))
  pc <- press_counts(mv, 1L)
  expect_length(pc, n_buttons(mv))
  expect_equal(names(pc), colnames(p1))
  expect_true(all(pc >= 0L))
  expect_true(all(pc <= n_observations(mv)))
})
test_that("print.replayr_movie produces a single header line", {
  mv <- read_fm2(fixture_path("sample.fm2"))
  out <- capture.output(print(mv))
  expect_true(any(grepl("replayr_movie", out)))
})
