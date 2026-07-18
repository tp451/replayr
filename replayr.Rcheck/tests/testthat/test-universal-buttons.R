test_that("universal_buttons() returns the canonical 40-slot layout", {
  ub <- universal_buttons()
  expect_type(ub, "character")
  expect_length(ub, 40)
  # Slots 1..8 are NES-shaped: R, L, D, U, T, S, B, A.
  expect_equal(ub[1:8], c("R", "L", "D", "U", "T", "S", "B", "A"))
  # Slot 11 is L-shoulder (lowercase 'p' to avoid colliding with NES
  # mnemonics; 12 is R-shoulder 'q').
  expect_equal(ub[11:12], c("p", "q"))
  # Slots 29..30 are PSX L2 / R2.
  expect_equal(ub[29:30], c("[", "]"))
  # Slots 31..40 are the Intellivision / ColecoVision numeric keypad.
  expect_equal(ub[31:40], as.character(0:9))
})

test_that("universal_button_names() is the same length as universal_buttons()", {
  expect_length(universal_button_names(), length(universal_buttons()))
  expect_equal(universal_button_names()[1:8],
               c("Right", "Left", "Down", "Up", "Start", "Select", "B", "A"))
})

test_that("supported_formats() lists exactly 12 extensions", {
  fmt <- supported_formats()
  expect_length(fmt, 12)
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
