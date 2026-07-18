test_that("package metadata identifies the author and maintainer", {
  metadata <- utils::packageDescription("replayr")

  expect_match(metadata$Author, "Thorben Pelzer", fixed = TRUE)
  expect_match(metadata$Maintainer, "Thorben Pelzer", fixed = TRUE)
  expect_match(metadata$Maintainer, "thorben@pelzer.blog", fixed = TRUE)
})
