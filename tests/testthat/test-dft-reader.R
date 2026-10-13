.dft_fixture <- function() system.file("extdata", "computers", "menu-double-tap.dft",
  package = "replayr", mustWork = TRUE
)
test_that("Dustmod expands scripts while retaining directional double taps and commands", {
  x <- .configure_movie(.decode_dft(.dft_fixture()), analog = "raw")
  keys <- button_layout(x)$key
  expect_identical(x$header[["_format"]], "dft")
  expect_identical(x$header$observation_unit, "scripted frame")
  expect_equal(n_observations(x), 14L)
  expect_equal(x$header$include_count, 3L)
  expect_false(x$header$runtime_duration_known)
  expect_equal(which(x$inputs[, 1L, match("dpad_right", keys)]), c(1L, 3L, 11L, 13L))
  expect_equal(which(x$double_tapped[, "right"]), c(3L, 13L))
  expect_equal(which(x$double_tapped[, "down"]), c(4L, 14L))
  expect_equal(unname(x$source_values[3L, "right"]), 2L)
  expect_true(is.na(x$source_values[1L, "taunt"]))
  expect_equal(which(x$inputs[, 1L, match("action_restart", keys)]), 10L)
  # Dustforce's verbs are game actions; jump is the action Doom also records.
  layout <- button_layout(x)
  verbs <- layout[layout$kind == "action", ]
  expect_setequal(verbs$id, paste0("action:", c("jump", "dash", "light", "heavy", "taunt", "restart")))
  expect_false(any(c("a", "b", "x", "y") %in% setdiff(layout$key, x$source_layout$universal_key)))
  expect_equal(x$source_locations$line[c(1, 3, 5, 10, 11)], c(2L, 4L, 6L, 5L, 2L))
  expect_identical(
    x$source_scripts[["demo/move.txt"]],
    "# Move and jump right, release, then double tap right and down.\n0 1 0 0 1 0 0 0 0\n000000000\n0200000000\n0002000000\n"
  )
  expect_equal(
    x$source_commands$command,
    c("LOAD", "STATS", "INCLUDE", "MOUSE", "SYNCLOAD", "INCLUDE", "INCLUDE", "MOUSE")
  )
  expect_equal(x$source_commands$before_row, c(1, 1, 1, 5, 7, 7, 11, 15))
  expect_equal(x$commands, integer(14))
})
test_that("Dustmod mouse observations apply only to the addressed script row", {
  x <- .decode_dft(.dft_fixture())
  expect_equal(which(x$mouse_observed), 5L)
  expect_equal(x$analog[[1]][5L, ], c(mouse_x = 75, mouse_y = -25))
  expect_true(all(is.na(x$analog[[1]][-5L, ])))
  expect_equal(which(x$mouse_button_observed[, 1L]), 5L)
  expect_equal(x$mouse_source_state[5L], "10001")
  keys <- x$decoded_layout$key
  expect_equal(which(x$inputs[, 1L, match("mouse_left", keys)]), 5L)
  expect_equal(which(x$inputs[, 1L, match("mouse_scroll_down", keys)]), 5L)
  expect_false(any(x$inputs[, 1L, match("mouse_right", keys)]))
  expect_equal(tail(x$source_commands$before_row, 1L), 15L)
})
test_that("Dustmod rejects broken include graphs and ambiguous entry scripts", {
  run <- function(scripts, pattern, entry = NULL) {
    path <- .computer_test_tar(scripts)
    on.exit(unlink(path))
    expect_error(.decode_dft(path, entry), pattern)
  }
  run(list("main.txt" = "INCLUDE:missing.txt\n"), "Missing DFT included")
  run(list("main.txt" = "INCLUDE:loop.txt\n", "loop.txt" = "INCLUDE:main.txt\n"), "Recursive")
  run(list("one/main.txt" = "", "two/main.txt" = ""), "exactly one")
  run(list("main.txt" = ""), "entry must", character())
  run(list("main.txt" = ""), "Missing DFT entry", "other.txt")
  run(list("main.txt" = "INCLUDE:../outside.txt\n"), "Unsafe")
  run(list("main.txt" = "000020000\n"), "Invalid DFT input")
  run(list("main.txt" = "00000000\n"), "Invalid DFT input")
  run(list("main.txt" = "SYSTEM:execute-me\n"), "Unknown DFT command")
  run(list("main.txt" = "MOUSE:NaN:2:1\n000000000\n"), "Invalid DFT mouse")
  run(list("main.txt" = "MOUSE:1:2:2\n000000000\n"), "Invalid DFT mouse")
})
test_that("Dustmod accepts idle and command-only scripts without inventing frames", {
  path <- .computer_test_tar(list("main.txt" = "# A pause marker.\nSYNCLOAD\n"))
  on.exit(unlink(path))
  x <- .decode_dft(path)
  expect_equal(dim(x$inputs), c(0L, 1L, 9L))
  expect_equal(nrow(x$source_locations), 0L)
  expect_equal(x$source_commands$before_row, 1L)
  expect_false(x$header$runtime_duration_known)
  path2 <- .computer_test_tar(list("main.txt" = "MOUSE:1:2:1\n000000000\n000000000\n"))
  on.exit(unlink(path2), add = TRUE)
  y <- .decode_dft(path2)
  expect_equal(y$mouse_button_observed[1, ], c(TRUE, FALSE, FALSE, FALSE, FALSE), ignore_attr = TRUE)
  expect_equal(y$mouse_observed, c(TRUE, FALSE))
  expect_true(y$header$runtime_duration_known)
})
test_that("Dustmod validates tar members without extracting paths or following links", {
  bad <- function(scripts, pattern, types = rep("0", length(scripts)), checksum = FALSE) {
    path <- .computer_test_tar(scripts, types, checksum)
    on.exit(unlink(path))
    expect_error(.decode_dft(path), pattern)
  }
  bad(list("../main.txt" = "000000000\n"), "Unsafe")
  bad(list("C:/main.txt" = "000000000\n"), "Unsafe")
  bad(list("main.txt" = "", "MAIN.TXT" = ""), "Duplicate")
  bad(stats::setNames(list("", ""), c("main.txt", "main.txt")), "Duplicate")
  bad(list("main.txt" = ""), "member type", "2")
  bad(list("main.txt" = ""), "member type", "1")
  bad(list("main.txt" = "000000000\n"), "checksum", checksum = TRUE)
  path <- .computer_test_tar(list("main.txt" = "000000000\n"))
  on.exit(unlink(path))
  bytes <- readBin(path, "raw", file.info(path)$size)
  writeBin(bytes[seq_len(length(bytes) - 12L)], path)
  expect_error(.decode_dft(path), "Truncated|compressed|terminator")
})
