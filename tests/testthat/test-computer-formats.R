.computer_fixture <- function(name) system.file('extdata', 'computers', name, package = 'replayr', mustWork = TRUE)
.computer_read <- function(ext, name, analog = 'raw') {
  x <- get(paste0('.decode_', ext))(.computer_fixture(name))
  x$header[['_format']] <- ext
  .configure_movie(x, analog = analog)
}
test_that('libTAS retains independent sticks, keyboard chords, mouse modes, and timing', {
  x <- .computer_read('ltm', 'dual-stick-menu.ltm')
  keys <- button_layout(x)$key
  expect_equal(dim(x$inputs)[1:2], c(5, 2))
  expect_equal(x$inputs[, 1, match('keysym_ff53', keys)], c(TRUE, TRUE, TRUE, TRUE, FALSE))
  expect_equal(x$inputs[, 1, match('keysym_20', keys)], c(FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(analog_channels(x)[, 'mouse_mode'], c(0, 1, 0, 1, 0))
  expect_equal(analog_channels(x)[, 'mouse_wheel'], c(0, 2, 0, 0, 0))
  expect_equal(analog_channels(x)[, 'right_y'], c(-32768, 0, 0, 32767, 0))
  expect_equal(analog_channels(x, 2)[, 'left_y'], c(0, 32767, 0, 0, 0))
  expect_equal(x$timing$duration_seconds, c(1 / 60, 1 / 30, 1 / 60, 1 / 60, 1 / 60))
  expect_equal(x$timing$realtime_sec, c(0, 0, 123, 0, 0))
  expect_equal(x$commands, c(0L, 0L, 1L, 0L, 0L))
  expect_equal(length(x$input_events[[4]]), 10L)
  for (mode in c('cardinal4', 'cardinal8', 'angle', 'angle+magnitude')) {
    y <- .computer_read('ltm', 'dual-stick-menu.ltm', mode)
    expect_identical(analog_channels(y), analog_channels(x))
    expect_identical(analog_channels(y, 2), analog_channels(x, 2))
  }
  y <- .computer_read('ltm', 'dual-stick-menu.ltm', c(left = 'cardinal4', right = 'cardinal8'))
  expect_true(any(grepl('left_', button_layout(y)$key)))
  expect_true(any(grepl('right_', button_layout(y)$key)))
})
test_that('legacy libTAS fields have the same source meaning', {
  x <- .computer_read('ltm', 'legacy-menu.ltm')
  expect_equal(n_observations(x), 2L)
  expect_equal(analog_channels(x)[, 'mouse_x'], c(40, 0))
  expect_equal(analog_channels(x)[, 'left_x'], c(32767, 0))
  expect_true(x$header$legacy_input_format)
})
test_that('Hourglass terminates held-key lists at their first zero', {
  x <- .computer_read('wtf', 'keyboard-jump.wtf')
  expect_equal(n_observations(x), 5L)
  expect_setequal(button_layout(x)$key, c('windows_vk_20', 'windows_vk_27'))
  expect_equal(x$inputs[, 1, match('windows_vk_20', button_layout(x)$key)], c(FALSE, TRUE, TRUE, FALSE, FALSE))
  expect_equal(x$source_keycodes[5, 2], 65L)
  expect_equal(x$header$keyboard_layout, '00000409')
})
test_that('JPC-RR reconstructs edges on its nanosecond event clock', {
  x <- .computer_read('jrsr', 'keyboard-mouse.jrsr')
  expect_equal(x$header$observation_unit, 'event')
  expect_equal(x$events$timestamp_ns, c(0, 100, 150, 175, 200, 250, 300, 300, 320, 400, 425, 450))
  at <- match('jpcrr_key_205', button_layout(x)$key)
  expect_equal(x$inputs[, 1, at], c(FALSE, rep(TRUE, 5), rep(FALSE, 6)))
  expect_equal(analog_channels(x)[, 'mouse_dx'], c(0, 0, 0, -3, rep(0, 8)))
  expect_equal(analog_channels(x, 2)[11:12, 'joystick_x_hold_ns'], c(12000, 12000))
  expect_true(all(is.na(analog_channels(x, 2)[1:10, 'joystick_x_hold_ns'])))
  expect_equal(tail(x$commands, 1), 1L)
  expect_equal(.jrsr_components('DISKNAME 0(disk (sample))'), c('DISKNAME', '0', 'disk (sample)'))
  expect_equal(.jrsr_components('a\\ b c'), c('a b', 'c'))
  expect_error(.jrsr_components('a(b'), 'Incomplete')
})
test_that('openMSX retains event timing, source key matrix, and joystick identity', {
  x <- .computer_read('omr', 'keyboard-joystick.omr')
  keys <- button_layout(x)$key
  expect_equal(x$header$observation_unit, 'event')
  # The keyboard, the joystick and the mouse are three controllers.
  expect_identical(x$header$controllers, c('keyboard', 'keyjoystick1', 'mouse'))
  expect_equal(n_buttons(x), 8L)
  expect_equal(x$events$timestamp_seconds[1:5], c(0, 1, 1, 2, 2))
  expect_equal(x$inputs[, 1, match('openmsx_key_r8_b7', keys)], c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_equal(x$inputs[, 2, match('a', keys)], c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_false(any(x$inputs[, 1, match('a', keys)]))
  expect_equal(analog_channels(x, 3L)[, 'mouse_dx'], c(0, 0, 0, 0, -6, 0, 0))
  expect_equal(ncol(analog_channels(x, 1L)), 0L)
  expect_match(x$events$source_xml[5], '<deltaX>-6</deltaX>')
})
test_that('CoffeeTools retains held states, independent edges, and randomization data', {
  x <- .computer_read('ctas', 'two-player-actions.ctas')
  expect_equal(dim(x$inputs), c(4, 2, 7))
  expect_equal(x$inputs[, 1, match('a', button_layout(x)$key)], c(FALSE, TRUE, TRUE, FALSE))
  expect_equal(x$pressed[, 1, 5], c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(x$released[, 1, 5], c(FALSE, FALSE, FALSE, TRUE))
  expect_equal(x$inputs[, 2, match('start', button_layout(x)$key)], c(FALSE, FALSE, FALSE, TRUE))
  expect_equal(x$randomization$seed, 1234.5)
  expect_equal(x$randomization$input_frame, 2)
})
test_that('idle computer recordings do not invent keyboard controls', {
  x <- read_ltm(.computer_fixture('idle.ltm'))
  expect_equal(dim(player(x)), c(2L, 0L))
  expect_identical(x$header[['_format']], 'ltm')
  p <- tempfile(fileext = '.jrsr')
  on.exit(unlink(p))
  writeLines(c('JRSR', '!BEGIN events', '+0 OPTION RELATIVE', '+1 SAVESTATE fixture 0', '!END'), p)
  y <- read_jrsr(p)
  expect_equal(dim(player(y)), c(2L, 0L))
  expect_identical(y$header[['_format']], 'jrsr')
})
test_that('libTAS Guide shares Mode while source keyboard D and W stay distinct', {
  packet <- function(code, buttons) {
    paste0('|K', code, '|C10:0:0:0:0:0:', buttons, '|F|')
  }
  # libTAS controller index 5 (sixth character) is Guide.
  content <- list(
    'config.ini' = paste('[General]', 'libtas_major_version=1',
      'libtas_minor_version=4', 'libtas_patch_version=5', 'nb_controllers=1',
      'frame_count=2', 'framerate_num=60', 'framerate_den=1',
      sep = '\n'
    ),
    inputs = paste(packet('64', '.....G.........'), packet('77', '...............'), sep = '\n')
  )
  path <- .computer_test_tar(content)
  on.exit(unlink(path))
  m <- read_ltm(path)
  layout <- button_layout(m)
  expect_identical(as.integer(layout$id[match('mode', layout$key)]), 19L)
  expect_identical(unname(player(m)[, 'mode']), c(TRUE, FALSE))
  expect_identical(m$inputs[, 1, match('keysym_64', layout$key)], c(TRUE, FALSE))
  expect_identical(m$inputs[, 1, match('keysym_77', layout$key)], c(FALSE, TRUE))
  expect_false('d' %in% layout$key)
})
test_that('libTAS literal input lines survive universal button normalization', {
  first <- '|K64|C10:0:0:0:0:0:A..............|F|'
  third <- '|K77|C10:0:0:0:0:0:...............|F|'
  lines <- c(first, first, third)
  content <- list(
    'config.ini' = paste('[General]', 'libtas_major_version=1',
      'libtas_minor_version=4', 'libtas_patch_version=5', 'nb_controllers=1',
      'frame_count=3', 'framerate_num=60', 'framerate_den=1',
      sep = '\n'
    ),
    inputs = paste(lines, collapse = '\n')
  )
  path <- .computer_test_tar(content)
  on.exit(unlink(path))
  movie <- read_ltm(path)
  expect_true(is.list(movie$source_input_log))
  expect_identical(movie$source_input_log$lines, c(first, third))
  expect_identical(movie$source_input_log$lines[movie$source_input_log$row], lines)
  expect_true(is.array(movie$source_inputs))
  expect_identical(
    movie$source_inputs[, 1L, match('a', movie$source_layout$key)],
    c(TRUE, TRUE, FALSE)
  )
  expect_identical(unname(player(movie)[, 'a']), c(TRUE, TRUE, FALSE))
})
