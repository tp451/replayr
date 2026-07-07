# Tests for the Doom .lmp reader. Vanilla Doom 1.9 demos are not
# part of the package fixtures because the canonical samples
# (DEMO1.LMP etc.) live inside commercial IWADs that are not
# redistributable. Tests skip gracefully when no .lmp files are
# present in doom_demos/lmp/.
#
# The doom_demos/lmp/extended/ subfolder contains five PrBoom+ /
# dsda-doom test demos that the v0.3 parser is expected to REJECT
# with a clear error -- those serve as format-detection regression
# fixtures.

lmp_dir <- file.path("..", "..", "..", "doom_demos", "lmp")
if (!dir.exists(lmp_dir)) {
  lmp_dir <- file.path("..", "..", "doom_demos", "lmp")
}

# Vanilla demos: any .lmp directly in lmp/ (not in subdirs).
vanilla_files <- list.files(lmp_dir, pattern = "\\.lmp$",
                             full.names = TRUE, ignore.case = TRUE,
                             recursive = FALSE)
extended_files <- list.files(file.path(lmp_dir, "extended"),
                              pattern = "\\.lmp$", full.names = TRUE,
                              ignore.case = TRUE)

test_that("read_lmp errors clearly on missing file", {
  expect_error(read_lmp(tempfile()), "file not found")
})

test_that("read_lmp rejects too-small files", {
  tmp <- tempfile(fileext = ".lmp")
  writeBin(as.raw(c(1, 2, 3, 4, 5)), tmp)
  expect_error(read_lmp(tmp), "too small")
  unlink(tmp)
})

test_that("read_lmp rejects PrBoom+ extended-format demos with a clear message", {
  skip_if_not(length(extended_files) > 0L,
              "Extended-format demo fixtures not available")
  for (f in extended_files) {
    err <- tryCatch(read_lmp(f), error = function(e) conditionMessage(e))
    expect_true(is.character(err), info = paste("file:", basename(f)))
    # We expect either "extended-format" or "not appear to be a Doom 1.9 demo"
    expect_true(grepl("extended-format|Doom 1\\.9 demo", err),
                info = paste("file:", basename(f), "err:", err))
  }
})

test_that("read_lmp parses a vanilla Doom demo into the standard movie shape", {
  skip_if_not(length(vanilla_files) > 0L,
              "Vanilla Doom .lmp not available (drop one in doom_demos/lmp/)")
  for (f in vanilla_files) {
    mv <- read_lmp(f)
    expect_s3_class(mv, "replayr_movie")
    expect_identical(mv$header[["_format"]], "lmp")
    # Skill must be a stringified 1..5
    expect_true(as.integer(mv$header$skill) %in% 1:5,
                info = paste("file:", basename(f)))
    # inputs is (n_frames, 4, 8) -- 4 player slots, 8-button NES-shape
    expect_equal(dim(mv$inputs)[2], 4L)
    expect_equal(dim(mv$inputs)[3], 8L)
    # forwardmove / sidemove / angleturn matrices are n_frames x 4
    expect_equal(dim(mv$header$forwardmove)[2], 4L)
    expect_equal(nrow(mv$header$forwardmove), n_frames(mv))
  }
})

test_that("read_movie dispatches .lmp to read_lmp", {
  skip_if_not(length(vanilla_files) > 0L,
              "Vanilla Doom .lmp not available")
  mv <- read_movie(vanilla_files[1])
  expect_identical(mv$header[["_format"]], "lmp")
})

test_that("supported_formats() includes .lmp", {
  expect_true(".lmp" %in% supported_formats())
})
