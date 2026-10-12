.omr_peripheral_fixture <- function() system.file(
  'extdata', 'computers', 'peripheral-events.omr', package = 'replayr', mustWork = TRUE)

.omr_key_states <- function(movie, keys) {
  layout <- button_layout(movie)
  at <- match(keys, layout$key)
  expect_false(anyNA(at))
  if (anyNA(at)) return(matrix(NA, n_frames(movie), length(keys)))
  unname(player(movie)[, layout$column[at], drop = FALSE])
}

test_that('openMSX relative movement and absolute touch fields keep their meaning', {
  movie <- read_omr(.omr_peripheral_fixture())
  values <- analog_channels(movie)
  expect_equal(n_frames(movie), 58L)
  expect_equal(movie$events$timestamp_ticks, (1:58) * 1234567)
  expect_equal(movie$events$timestamp_seconds, (1:58) * 1234567 / 3436363200)
  expect_equal(values[, 'openmsx_trackball_dx'], c(-7, 0, 2, rep(0, 55)))
  expect_equal(values[, 'openmsx_trackball_dy'], c(3, 0, -5, rep(0, 55)))
  expect_equal(values[, 'openmsx_paddle_delta'], c(0, 13, 0, 0, -9, rep(0, 53)))
  expect_equal(.omr_key_states(movie, c('openmsx_trackball_bit4', 'openmsx_trackball_bit5'))[1:5, ],
               matrix(c(TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE), 5, 2, byrow = TRUE))
  expect_equal(values[, 'openmsx_touchpad_x'], c(rep(0, 5), 23, 211, 87, rep(91, 50)))
  expect_equal(values[, 'openmsx_touchpad_y'], c(rep(0, 5), 201, 47, 139, rep(137, 50)))
  expect_equal(.omr_key_states(movie, c('openmsx_touchpad_touch', 'openmsx_touchpad_button'))[6:9, ],
               matrix(c(TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE), 4, 2, byrow = TRUE))
  # Distinct X/Y values expose swaps; an unrelated event resets only deltas.
  expect_match(movie$events$source_xml[1], '<deltaX>-7</deltaX>')
  expect_match(movie$events$source_xml[6], '<y>201</y>')
})

test_that('openMSX JoyMega follows serialized binding order rather than port-read order', {
  # JoyMega.cc at f07bee985b8e2102c47913c217ad0365638bf8ae defines this
  # binding order and emits one press/release bit per binding. SELECT is Mode.
  labels <- c('up', 'down', 'left', 'right', 'a', 'b', 'c', 'start', 'x', 'y', 'z', 'mode')
  movie <- read_omr(.omr_peripheral_fixture())
  states <- .omr_key_states(movie, paste0('openmsx_joymegastate_2_', labels))
  expected <- matrix(FALSE, 24, 12)
  expected[cbind(seq(1, 23, 2), 1:12)] <- TRUE
  expect_identical(states[10:33, , drop = FALSE], expected)
  expect_false(any(states[-(10:33), ]))
})

test_that('openMSX JoyHandle wheel is independent of its six digital controls', {
  movie <- read_omr(.omr_peripheral_fixture())
  states <- .omr_key_states(movie, paste0('openmsx_joyhandlestate_3_bit', 0:5))
  expected <- matrix(FALSE, 12, 6)
  expected[cbind(seq(1, 11, 2), 1:6)] <- TRUE
  expect_identical(states[34:45, , drop = FALSE], expected)
  wheel <- analog_channels(movie)[, 'openmsx_joyhandlestate_3_analog']
  expect_equal(wheel[34:45], c(-0.75, 0, 0.25, 0, 1, 0, -1, 0, 0.125, 0, -0.5, 0))
  expect_false(any(states[-(34:45), ]))
  expect_equal(wheel[c(1:33, 46:58)], rep(0, 46))
})

test_that('openMSX Arkanoid dial movement remains separate from held-button state', {
  movie <- read_omr(.omr_peripheral_fixture())
  expected <- logical(58); expected[46] <- TRUE
  expect_identical(as.vector(.omr_key_states(movie, 'openmsx_arkanoid_button')), expected)
  delta <- numeric(58); delta[46:47] <- c(-17, 5)
  expect_equal(analog_channels(movie)[, 'openmsx_arkanoid_delta'], delta)
})

test_that('openMSX gun models use their own trigger and light-sensor polarity', {
  # Gunstick: trigger pin6/bit4 low; light pin2/bit1 low.
  # Terminator Laser: trigger pin7/bit5 low; light pin6/bit4 high.
  # The other port bits are retained in status, not invented as held controls.
  movie <- read_omr(.omr_peripheral_fixture())
  values <- analog_channels(movie)
  expected <- matrix(c(FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE),
                     5, 2, byrow = TRUE)
  for (id in 0:1) {
    prefix <- paste0('openmsx_lightgunstate_', id, '_')
    states <- .omr_key_states(movie, paste0(prefix, c('trigger', 'light')))
    rows <- if (id == 0L) 48:52 else 53:57
    expect_identical(states[rows, , drop = FALSE], expected)
    expect_false(any(states[58, ]))
    expect_equal(values[rows, paste0(prefix, 'status')],
                 if (id == 0L) c(63, 47, 61, 45, 63) else c(47, 15, 63, 31, 47))
  }
  expect_false(any(grepl('lightgunstate_.*_bit', button_layout(movie)$key)))
})

test_that('openMSX unknown gun models retain raw status without inventing controls', {
  source <- gzfile(.omr_peripheral_fixture())
  doc <- xml2::read_xml(source, options = 'NONET')
  # read_xml() closes the supplied connection.
  id <- xml2::xml_find_all(doc, '//item[@type="LightGunState"]/id')
  xml2::xml_set_text(id, '7')
  path <- tempfile(fileext = '.omr')
  on.exit(unlink(path))
  con <- gzfile(path, 'wb')
  writeBin(charToRaw(as.character(doc)), con)
  close(con)
  expect_warning(movie <- read_omr(path), 'Unrecognized openMSX light-gun device')
  expect_identical(movie$header$unknown_gun_devices, 'lightgunstate_7')
  expect_false(any(grepl('lightgunstate', button_layout(movie)$key)))
  status <- analog_channels(movie)[, 'openmsx_lightgunstate_7_status']
  expect_true(all(is.na(status[1:47])))
  expect_equal(status[48:58], c(63, 47, 61, 45, 63, 47, 15, 63, 31, 47, 47))
})

