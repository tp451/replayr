# Locate a bundled sample file. Returns the path or NULL if missing.
fixture_path <- function(filename) {
  p <- system.file("extdata", filename, package = "replayr")
  if (nzchar(p) && file.exists(p)) p else NULL
}

# Locate an optional external fixture under
# `Sys.getenv("REPLAYR_FIXTURE_DIR")`. Returns NULL if env unset
# or file absent.
external_fixture <- function(rel_path) {
  base <- Sys.getenv("REPLAYR_FIXTURE_DIR", unset = "")
  if (!nzchar(base)) return(NULL)
  p <- file.path(base, rel_path)
  if (file.exists(p)) p else NULL
}

# Skip the test if a bundled fixture is missing — useful when the
# package is installed without inst/extdata (e.g. binary-only build).
skip_if_no_fixture <- function(filename) {
  if (is.null(fixture_path(filename))) {
    skip(sprintf("bundled fixture %s missing", filename))
  }
}
