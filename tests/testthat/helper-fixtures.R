# Bundled examples are required test data; missing files must fail the test.
fixture_path <- function(filename) {
  system.file("extdata", filename, package = "replayr", mustWork = TRUE)
}
