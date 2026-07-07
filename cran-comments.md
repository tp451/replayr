# cran-comments.md

## Submission

This is the initial CRAN submission of `replayr`.

## Test environments

* Local: <YOUR-OS> R-release (TODO: fill in `R --version` output)
* GitHub Actions: ubuntu-latest, macos-latest, windows-latest, each
  on R-release and R-devel. See `.github/workflows/R-CMD-check.yaml`.
* `R CMD check --as-cran`: TODO: paste the result summary here once
  it has been run on the maintainer's machine.

## R CMD check results

0 errors | 0 warnings | <N> notes

Expected notes:

* "New submission" — this is the first CRAN release of the package.
* Possibly: spelling-check note for emulator / format names
  (FCEUX, BizHawk, lsnes, Gens, ...) that aren't in the standard
  dictionary. These are correct proper nouns.

## Downstream dependencies

There are currently no downstream dependencies (no reverse imports,
suggests, or depends).

## Reviewer notes

* The package ships eight small example movie files in
  `inst/extdata/sample.{fm2,bk2,fcm,lsmv,gmv,vbm,m64,smv}`. They
  are real publications from tasvideos.org used unchanged. Total
  bundled-data size is ~135 KB. See `inst/extdata/README.md` for
  the per-file source mapping.
* Three formats (`.pxm`, `.pjm`, `.dtm`) have no bundled fixture
  because their typical file sizes (>=300 KB each) would inflate
  the package; the corresponding tests are skipped unless the
  environment variable `REPLAYR_FIXTURE_DIR` is set.
* No platform-specific code paths; the package is pure R and uses
  only base + `utils`.
