test_that("different controller matrices align by stable identity", {
  paths <- system.file("extdata", c("sample.fm2", "sample.m64"), package = "replayr")
  movies <- lapply(paths, read_movie)
  names(movies) <- c("nes", "n64")
  aligned <- align_buttons(movies)
  expect_identical(names(aligned), names(movies))
  expect_identical(attr(aligned[[1]], "button_ids"), attr(aligned[[2]], "button_ids"))
  for (i in seq_along(movies)) {
    ids <- attr(aligned[[i]], "button_ids")
    positions <- match(movies[[i]]$button_ids, ids)
    expect_equal(
      unname(aligned[[i]][, positions, drop = FALSE]),
      unname(matrix(movies[[i]]$inputs[, 1, , drop = FALSE], nrow = n_observations(movies[[i]])))
    )
    absent <- which(!ids %in% movies[[i]]$button_ids)
    expect_false(any(aligned[[i]][, absent, drop = FALSE]))
  }
  selected <- align_buttons(movies, ids = c(8L, 1L))
  expect_equal(colnames(selected[[1]]), c("a", "dpad_right"))
  expect_identical(attr(selected[[1]], "button_names"), c("A", "Right"))
  expect_equal(as.vector(selected[[1]]), as.vector(player(movies[[1]])[, c(8, 1)]))
  expect_error(align_buttons(movies, ids = c(1, 1)), "distinct")
  expect_error(align_buttons(movies, idx = 99), "player")
})
