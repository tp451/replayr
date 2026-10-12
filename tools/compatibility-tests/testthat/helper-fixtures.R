# This suite is run explicitly against a separately stored collection.
external_fixture <- function(rel_path) {
  base <- Sys.getenv("REPLAYR_FIXTURE_DIR", unset = "")
  if (!nzchar(base)) {
    stop("Run this suite with tools/compatibility-tests/run.R and a fixture directory.", call. = FALSE)
  }
  path <- file.path(base, rel_path)
  if (!file.exists(path)) {
    stop("Missing external fixture under REPLAYR_FIXTURE_DIR: ", rel_path, call. = FALSE)
  }
  path
}
