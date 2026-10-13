# These original fixtures contain neutral samples, individual physical buttons,
# and distinct stick positions. Expectations below come from emulator masks and
# serialization order, independently of replayr's decoder and private slots.
# Source revisions and fixture construction: tools/make-semantic-fixtures.py.
.semantic_movie <- function(extension, analog = "raw") {
  path <- fixture_path(paste0("semantic/semantic-onehot.", extension))
  expect_false(is.null(path), info = paste("missing original", extension, "fixture"))
  read_movie(path, analog = analog)
}
.semantic_buttons <- function(movie, keys, player_index = 1L) {
  positions <- match(keys, button_layout(movie)$key)
  expect_false(anyNA(positions))
  mat <- player(movie, player_index)[, positions, drop = FALSE]
  matrix(as.logical(mat), nrow = nrow(mat))
}
test_that("NES binary formats preserve their different physical button orders", {
  orders <- list(
    fmv = c("dpad_right", "dpad_left", "dpad_up", "dpad_down", "b", "a", "select", "start"),
    fcm = c("a", "b", "select", "start", "dpad_up", "dpad_down", "dpad_left", "dpad_right")
  )
  for (extension in names(orders)) {
    keys <- orders[[extension]]
    movie <- .semantic_movie(extension)
    expected <- matrix(FALSE, 10L, 8L)
    expected[2:9, ] <- diag(8L) != 0L
    expected[10L, match(c("dpad_right", "b", "a"), keys)] <- TRUE
    expect_setequal(button_layout(movie)$key, keys)
    expect_identical(.semantic_buttons(movie, keys), expected, info = extension)
    expect_equal(sum(movie$inputs), 11L)
    if (extension == "fcm") {
      expect_equal(n_players(movie), 4L)
      for (p in 2:4) expect_false(any(player(movie, p)))
    }
  }
})
test_that("SMV separates jump, spin jump, run, and the other SNES controls", {
  # SNES word bits 4..15: R,L,X,A,Right,Left,Down,Up,Start,Select,Y,B.
  keys <- c(
    "r1", "l1", "x", "a", "dpad_right", "dpad_left", "dpad_down", "dpad_up",
    "start", "select", "y", "b"
  )
  movie <- .semantic_movie("smv")
  expected <- matrix(FALSE, 14L, 12L)
  expected[2:13, ] <- diag(12L) != 0L
  expected[14L, match(c("dpad_right", "y", "b"), keys)] <- TRUE
  expect_setequal(button_layout(movie)$key, keys)
  expect_identical(.semantic_buttons(movie, keys), expected)
  expect_equal(sum(movie$inputs), 15L)
})
test_that("GMV distinguishes A/B/C and both six-button controller nibbles", {
  keys <- c(
    "dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "b", "c", "start",
    "x", "y", "z", "mode"
  )
  movie <- .semantic_movie("gmv")
  p1 <- p2 <- matrix(FALSE, 18L, 12L)
  p1[2:9, 1:8] <- diag(8L) != 0L
  p1[10:13, 9:12] <- diag(4L) != 0L
  p2[14:17, 9:12] <- diag(4L) != 0L
  p1[18L, match(c("dpad_right", "c"), keys)] <- TRUE
  expect_equal(n_players(movie), 2L)
  expect_setequal(button_layout(movie)$key, keys)
  expect_identical(.semantic_buttons(movie, keys, 1L), p1)
  expect_identical(.semantic_buttons(movie, keys, 2L), p2)
  expect_equal(sum(movie$inputs), 18L)
})
test_that("M64 separates D-pad, C buttons, shoulders, and A/B/Z", {
  # CoreButtons low-word bits 0..13; stick coordinates follow the word.
  keys <- c(
    "dpad_right", "dpad_left", "dpad_down", "dpad_up", "start", "z", "b", "a",
    "c_right", "c_left", "c_down", "c_up", "r1", "l1"
  )
  movie <- .semantic_movie("m64")
  expected <- matrix(FALSE, 20L, 14L)
  expected[2:15, ] <- diag(14L) != 0L
  expected[16L, match(c("a", "z"), keys)] <- TRUE
  expect_setequal(button_layout(movie)$key, keys)
  expect_identical(.semantic_buttons(movie, keys), expected)
  expect_equal(sum(movie$inputs), 16L)
  axes <- matrix(0, 20L, 2L)
  axes[16:20, ] <- rbind(c(80, 0), c(0, 80), c(-80, 0), c(0, -80), c(60, 60))
  expect_equal(unname(analog_channels(movie)), axes)
})
test_that("PlayStation binary face buttons follow physical geometry, with distinct L3/R3", {
  # PSX source bits 0..15: Select,L3,R3,Start,U,R,D,L,L2,R2,L1,R1,
  # Triangle,Circle,Cross,Square. Canonical face positions are top=x, right=a,
  # bottom=b, left=y; their letters are not PlayStation button labels.
  keys <- c(
    "select", "l3", "r3", "start", "dpad_up", "dpad_right", "dpad_down", "dpad_left",
    "l2", "r2", "l1", "r1", "x", "a", "b", "y"
  )
  for (extension in c("pjm", "pxm")) {
    movie <- .semantic_movie(extension)
    expected <- matrix(FALSE, 25L, 16L)
    expected[2:17, ] <- diag(16L) != 0L
    expect_equal(n_players(movie), 1L)
    expect_setequal(button_layout(movie)$key, keys)
    expect_identical(.semantic_buttons(movie, keys), expected, info = extension)
    expect_equal(sum(movie$inputs), 16L)
    axes <- matrix(128, 25L, 4L)
    axes[18:25, ] <- rbind(
      c(255, 128, 128, 128), c(128, 0, 128, 128),
      c(0, 128, 128, 128), c(128, 255, 128, 128),
      c(128, 128, 255, 128), c(128, 128, 128, 0),
      c(128, 128, 0, 128), c(128, 128, 128, 255)
    )
    expect_equal(colnames(analog_channels(movie)), c("left_x", "left_y", "right_x", "right_y"))
    expect_equal(unname(analog_channels(movie)), axes)
  }
})
test_that("N64 stick modes preserve signed axes and distinguish diagonal directions", {
  for (mode in c("cardinal4", "cardinal8", "angle", "angle+magnitude")) {
    movie <- .semantic_movie("m64", mode)
    sticks <- stick_channels(movie)
    if (mode %in% c("cardinal4", "cardinal8")) {
      directions <- if (mode == "cardinal4") c("left_e", "left_n", "left_w", "left_s") else
        c("left_e", "left_ne", "left_n", "left_nw", "left_w", "left_sw", "left_s", "left_se")
      expected <- matrix(FALSE, 20L, length(directions))
      final_direction <- if (mode == "cardinal4") "left_n" else "left_ne"
      active <- match(c("left_e", "left_n", "left_w", "left_s", final_direction), directions)
      expected[cbind(16:20, active)] <- TRUE
      expect_identical(.semantic_buttons(movie, directions), expected)
    } else {
      expect_equal(sticks[, "left_angle"], c(rep(NA_real_, 15L), 0, 90, 180, 270, 45))
      if (mode == "angle+magnitude") {
        expect_equal(sticks[, "left_magnitude"], c(rep(0, 15L), rep(80 / 128, 4L), sqrt(2) * 60 / 128))
      } else expect_false("left_magnitude" %in% colnames(sticks))
    }
  }
})
test_that("PlayStation stick modes retain separate left/right axes and invert source Y", {
  for (extension in c("pjm", "pxm")) {
    for (mode in c("cardinal4", "cardinal8", "angle", "angle+magnitude")) {
      movie <- .semantic_movie(extension, mode)
      sticks <- stick_channels(movie)
      for (side in c("left", "right")) {
        rows <- if (side == "left") 18:21 else 22:25
        if (mode %in% c("cardinal4", "cardinal8")) {
          suffixes <- if (mode == "cardinal4") c("e", "n", "w", "s") else
            c("e", "ne", "n", "nw", "w", "sw", "s", "se")
          keys <- paste(side, suffixes, sep = "_")
          expected <- matrix(FALSE, 25L, length(keys))
          expected[cbind(rows, match(c("e", "n", "w", "s"), suffixes))] <- TRUE
          expect_identical(.semantic_buttons(movie, keys), expected)
        } else {
          angles <- rep(NA_real_, 25L)
          angles[rows] <- c(0, 90, 180, 270)
          expect_equal(sticks[, paste0(side, "_angle")], angles)
          if (mode == "angle+magnitude") {
            magnitude <- rep(0, 25L)
            magnitude[rows] <- c(127 / 128, 1, 1, 127 / 128)
            expect_equal(sticks[, paste0(side, "_magnitude")], magnitude)
          } else expect_false(paste0(side, "_magnitude") %in% colnames(sticks))
        }
      }
    }
  }
})
