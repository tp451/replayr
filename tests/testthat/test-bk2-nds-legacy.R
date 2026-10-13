test_that("MelonDS 2.9.1 skips a stale Microphone field without shifting Power", {
  controls <- c(
    "Touch X", "Touch Y", "Mic Volume", "GBA Light Sensor",
    "Up", "Down", "Left", "Right", "Start", "Select", "B", "A", "Y", "X", "L", "R",
    "LidOpen", "LidClose", "Touch", "Microphone", "Power"
  )
  logkey <- paste0("LogKey:#", paste(controls, collapse = "|"), "|")
  # These original rows exercise a pressed Power byte and an extra source byte.
  # The 2.9.1 core has 16 Boolean fields; Microphone is not among them.
  rows <- c(
    paste0("| 12, 34, 70, 0,", strrep(".", 14), "TPM||"),
    paste0("| 22, 44, 80, 1,", strrep(".", 14), "T.|")
  )
  header <- list("_format" = "bk2", Platform = "NDS", Core = "MelonDS", emuVersion = "Version 2.9.1")
  movie <- suppressWarnings(replayr:::.parse_bk2_input_lines(c(logkey, rows), header))
  expect_equal(movie$system_inputs$Power, c(TRUE, FALSE))
  expect_equal(movie$source_trailing, c("M", ""))
  expect_equal(movie$header$ignoredLogKeyControls, "Microphone")
  expect_equal(movie$header$sourceLogKey, logkey)
  expect_false("Microphone" %in% movie$source_controls$name)
  expect_true(all(movie$inputs[, 1, match("l3", movie$decoded_layout$key)]))
  expect_equal(movie$analog[[1]][, "Mic Volume"], c(70, 80))
  expect_equal(movie$analog[[1]][, "Touch X"], c(12, 22))
  # Other versions must not receive this source-specific compatibility rule.
  header$emuVersion <- "Version 2.10"
  expect_error(replayr:::.parse_bk2_input_lines(c(logkey, rows), header), "truncated at 'Power'")
})
