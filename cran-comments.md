## Resubmission

This is a resubmission of the new package replayr 0.4.0. In this version I
have:

* Replaced the relative links to `COMPATIBILITY.md` and `CONTROLLERS.md` in
  `README.md` with their addresses in the GitHub repository, as these two
  files are not part of the package.
* Added the package website to the `URL` field.

## Test environments

* Windows 11 x64, R 4.6.0 (local).
* Ubuntu 24.04.4 under WSL, R-devel 4.7.0 (2026-10-08 r90650) (local).
* GitHub Actions: macOS (release), Windows (release), and Ubuntu (devel,
  release, and oldrel-1).

Both local environments ran `R CMD check --as-cran` on the same source
archive, with remote CRAN incoming, URL and file URI checks enabled:
0 errors, 0 warnings, and 1 NOTE ("New submission").
Tests, examples, vignettes, and PDF/HTML manual checks passed.

The GitHub Actions checks run `R CMD check --as-cran` without the manual on
every push: 0 errors and 0 warnings on all five platforms.

## Examples and bundled files

The package includes original artificial input recordings and their generators.
No third-party recordings, game images, save states, or audiovisual data are
bundled. All examples are run; the tests need no file from outside the package
and write only to the session's temporary directory.
