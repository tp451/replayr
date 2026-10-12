# Maintainer compatibility checks

These checks use recordings stored separately from the repository. They are
excluded from the CRAN source package and run only when explicitly requested.
The regular suite in `tests/testthat` uses bundled artificial recordings and
temporary files created by the tests; it requires no downloaded recordings.

Run the regular suite from the repository root:

```r
testthat::test_local()
```

Maintainers with the external collection can run:

```sh
Rscript tools/compatibility-tests/run.R /path/to/recordings
```

The directory must contain the relative paths named in the tests, including
the `raw_*` folders and `doom_demos/lmp`. The runner loads the current source
checkout and fails if a required file is missing. It does not download files.
External recordings must remain outside the repository and package archive.
