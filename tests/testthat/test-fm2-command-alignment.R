test_that("FM2 commands stay aligned across headers, blank lines, and empty records", {
  movie <- replayr:::.parse_fm2_text(c(
    "version 3", "", "||", "|1|R.......|.......A||",
    "comment between records", "|invalid|.L......|......B.||",
    "||", "|4|..D.....|.....S..||", "comment after records"))
  expect_identical(movie$commands, c(1L, 0L, 4L))
  expect_identical(dim(movie$inputs), c(3L, 2L, 8L))
  expect_equal(movie$inputs[,1,1:3],diag(3)==1)
  expect_equal(movie$inputs[,2,6:8],diag(3)[,3:1]==1)
  expect_identical(movie$header$comment,"between records\nafter records")
  empty <- replayr:::.parse_fm2_text(c("version 3", "", "||"))
  expect_identical(empty$commands,integer())
  expect_identical(dim(empty$inputs),c(0L,1L,8L))
})
