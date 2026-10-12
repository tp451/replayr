test_that("universal_buttons() returns the stable identities including named peripherals registry", {
  ub <- universal_buttons()
  expect_type(ub, "character")
  expect_length(ub, 53)
  expect_false(anyDuplicated(ub) > 0L)
  # Slots 1..8 are NES-shaped: R, L, D, U, T, S, B, A.
  expect_equal(ub[1:8], c("R", "L", "D", "U", "T", "S", "B", "A"))
  # Slot 11 is L-shoulder (lowercase 'p' to avoid colliding with NES
  # mnemonics; 12 is R-shoulder 'q').
  expect_equal(ub[11:12], c("p", "q"))
  # IDs 13..14 are L2 / R2.
  expect_equal(ub[13:14], c("[", "]"))
  # IDs 40..49 are the shared numbered controls 0..9.
  expect_equal(ub[40:49], as.character(0:9))
})

test_that("universal_button_names() is the same length as universal_buttons()", {
  expect_length(universal_button_names(), length(universal_buttons()))
  expect_equal(universal_button_names()[1:8],
               c("Right", "Left", "Down", "Up", "Start", "Select", "B", "A"))
})

test_that("supported_formats() lists distinct recording extensions", {
  fmt <- supported_formats()
  expect_gt(length(fmt), 12)
  expect_false(anyDuplicated(fmt)>0L)
  expect_true(all(startsWith(fmt, ".")))
})

test_that("movie constructor enforces array and metadata invariants", {
  expect_error(
    replayr:::.new_movie(list(), integer(0), matrix(FALSE, 0L, 2L)),
    "logical array"
  )
  expect_error(
    replayr:::.new_movie(list(), integer(0), array(FALSE, c(1L, 1L, 8L))),
    "commands.*number"
  )
  expect_error(
    replayr:::.new_movie(list(), 0L, array(FALSE, c(1L, 1L, 8L)),
                         button_mnemonics = letters[1:7]),
    "mnemonic.*dimension"
  )
})

test_that("stick clicks never share keypad identities", {
  expect_equal(universal_buttons()[15:16], c("j", "k"))
  expect_identical(button_layout()$key[40:41], c("numbered_0", "numbered_1"))
  expect_equal(universal_button_names()[15:16], c("L3", "R3"))
  expect_equal(anyDuplicated(universal_buttons()), 0L)
  expect_equal(anyDuplicated(universal_button_names()), 0L)
})
