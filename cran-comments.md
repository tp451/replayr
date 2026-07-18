# cran-comments.md

## Submission

This is the initial CRAN submission of `replayr`.

## Test environments

* Local: Windows 11 x64, R 4.6.0 (2026-04-24 ucrt)
* GitHub Actions: ubuntu-latest, macos-latest, windows-latest, each
  on R-release and R-devel. See `.github/workflows/R-CMD-check.yaml`.
* `R CMD check --as-cran`: completed locally on the environment above.

## R CMD check results

0 errors | 0 warnings | 1 note

Expected notes:

* "New submission" — this is the first CRAN release of the package.

## Downstream dependencies

There are currently no downstream dependencies (no reverse imports,
suggests, or depends).

## Reviewer notes

* The package ships one deterministic synthetic example for each of its
  twelve supported formats in `inst/extdata/sample.<ext>`. The files contain
  only generated controller input: no ROMs, savestates, audiovisual content,
  or third-party movie data. `tools/generate_sample_movies.R` reproduces all
  twelve fixtures; `inst/extdata/README.md` documents their contents.
* Optional compatibility checks against a separately obtained local corpus
  run only when `REPLAYR_FIXTURE_DIR` is set. No corpus files are included in
  the package.
* No platform-specific code paths; the package is pure R and uses
  only base + `utils`.
