bk2_variant_fixture <- function(name) system.file('extdata', 'bk2-variants', name, package = 'replayr', mustWork = TRUE)
test_that('Gambatte input length is numeric timing and leaves button positions intact', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('subframe-gb.bk2')))
  expect_equal(system_channels(m)[['Input Length']], c(35112, 1, 5758, 0))
  expect_identical(system_channels(m)$Power, c(FALSE, FALSE, FALSE, TRUE))
  keys <- button_layout(m)$key
  expect_setequal(keys[player(m)[1, ]], 'dpad_up')
  expect_setequal(keys[player(m)[2, ]], 'a')
  expect_setequal(keys[player(m)[3, ]], c('dpad_right', 'b'))
  expect_false(any(player(m)[4, ]))
  expect_null(m$source_trailing)
  expect_false(any(grepl('input_length', keys)))
})
test_that('mGBA input length precedes independent tilt and light axes', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('subframe-gba.bk2')))
  expect_equal(system_channels(m)[['Input Length']], c(280896, 12345))
  channels <- analog_channels(m)
  expect_equal(channels[, 'Tilt X'], c(17, -31))
  expect_equal(channels[, 'Tilt Y'], c(-23, 47))
  expect_equal(channels[, 'Tilt Z'], c(41, -59))
  expect_equal(channels[, 'Light Sensor'], c(99, 83))
  keys <- button_layout(m)$key
  expect_setequal(keys[player(m)[1, ]], c('dpad_right', 'a'))
  expect_setequal(keys[player(m)[2, ]], 'b')
  expect_identical(system_channels(m)$Power, c(FALSE, TRUE))
  expect_null(m$source_trailing)
})
test_that('MAME throttle remains a numeric axis independently of stick X and Y', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('arcade-throttle.bk2')))
  channels <- analog_channels(m)
  expect_equal(channels[, 'AD Stick X'], c(321, 654))
  expect_equal(channels[, 'AD Stick Y'], c(432, 567))
  expect_equal(channels[, 'Throttle Stick'], c(345, 456))
  expect_null(m$source_trailing)
  expect_false(any(grepl('throttle', button_layout(m)$key)))
})
test_that('BizHawk pipe separators may be empty or moved between Boolean fields', {
  expect_no_warning(m <- read_bk2(bk2_variant_fixture('empty-separators.bk2')))
  keys <- button_layout(m)$key
  expect_setequal(keys[player(m)[1, ]], 'dpad_up')
  expect_setequal(keys[player(m)[2, ]], c('dpad_up', 'a'))
  expect_setequal(keys[player(m)[3, ]], c('dpad_right', 'b'))
  expect_equal(m$header$logKeyStreamBoundarySamples, 3)
  expect_null(m$source_trailing)
  parts <- read_bk2_chunks(bk2_variant_fixture('subframe-gba.bk2'), identity, chunk_size = 1L)
  expect_equal(unlist(lapply(parts, function(x) system_channels(x)[['Input Length']])), c(280896, 12345))
})
test_that('genuine unconsumed source text remains visible and warned', {
  input <- 'LogKey:#Power|Reset|#P1 A|\n|..|A|orphan|'
  expect_warning(m <- replayr:::.parse_bk2_input_log(input, list(Platform = 'NES'), analog = 'raw'), 'trailing source text')
  expect_equal(m$source_trailing, 'orphan')
  expect_equal(n_frames(m), 1)
  expect_true(player(m)[1, 1])
})
test_that('an unrecognized numeric field cannot silently disappear into Boolean columns', {
  log <- 'LogKey:#Unfamiliar Control|Fire|\n|1,|'
  expect_warning(
    m <- replayr:::.parse_bk2_input_log(log, list(Platform = 'Arcade'), analog = 'raw'),
    'comma consumed as a Boolean'
  )
  expect_equal(m$ambiguous_input$source_input, '|1,|')
  expect_equal(m$ambiguous_input$field, 'Fire')
  expect_equal(m$header$ambiguousBooleanCommaSamples, 1)
  expect_null(m$source_trailing)
  expect_no_warning(key <- replayr:::.parse_bk2_input_log(
    'LogKey:#,|\n|,|', list(Platform = 'AppleII'),
    analog = 'raw'
  ))
  expect_true(player(key)[1, 1])
})
test_that('ignored padding and readable suffix notes remain available without false warnings', {
  log <- 'LogKey:#Power|Reset|#P1 A|\n|..|A|........|\n|..|.| Level 2-1\n'
  expect_no_warning(m <- replayr:::.parse_bk2_input_log(log, list(Platform = 'NES'), analog = 'raw'))
  expect_equal(m$source_trailing, c('........', ' Level 2-1'))
  expect_equal(m$header$sourceTrailingPaddingSamples, 1)
  expect_equal(m$header$sourceTrailingAnnotationSamples, 1)
  expect_equal(m$header$sourceTrailingUnboundSamples, 0)
  expect_identical(as.vector(player(m)), c(TRUE, FALSE))
  expect_warning(
    replayr:::.parse_bk2_input_log(
      'LogKey:#Power|Reset|#P1 A|\n|..|A||..|A|', list(Platform = 'NES'),
      analog = 'raw'
    ),
    'unbound controls'
  )
})
