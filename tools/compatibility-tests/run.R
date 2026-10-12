args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !dir.exists(args[[1L]])) {
  stop("Usage: Rscript tools/compatibility-tests/run.R /path/to/recordings", call. = FALSE)
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
suite <- dirname(normalizePath(script, mustWork = TRUE))
repo <- normalizePath(file.path(suite, "../.."), mustWork = TRUE)
Sys.setenv(REPLAYR_FIXTURE_DIR = normalizePath(args[[1L]], mustWork = TRUE))
pkgload::load_all(repo, quiet = TRUE)
stopifnot(normalizePath(getNamespaceInfo("replayr", "path")) == repo)
testthat::set_max_fails(Inf)
results <- testthat::test_dir(
  file.path(suite, "testthat"),
  package = "replayr",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)
results <- as.data.frame(results)
if (any(results$skipped)) stop("Compatibility checks must not be skipped.", call. = FALSE)
cat(sum(results$passed), "assertions passed; no failures, warnings, or skips.\n")
