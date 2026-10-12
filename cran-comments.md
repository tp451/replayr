## Submission

Initial submission of replayr 0.4.0.

## Test environments

* Windows 11 x64, R 4.6.0.
* Ubuntu 24.04.4 under WSL, R-devel 4.7.0 (2026-10-08 r90650).

Both environments ran `R CMD check --as-cran` on the same source archive,
with remote CRAN incoming and URL checks enabled:
0 errors, 0 warnings, and 1 NOTE ("New submission").
Tests, examples, vignettes, and PDF/HTML manual checks passed.

## Examples and documentation

The package includes original artificial input recordings and their generators.
No third-party recordings, game images, save states, or audiovisual data are
bundled. Tests against separately obtained recordings are optional.

The compatibility catalogue is included as an installed vignette. Package
documentation is available without access to the private development repository.
