test_that('the authored Wii sequence retains sensor values and button timing', {
  path <- system.file('extdata', 'paper', 'wii-motion.dtm', package = 'replayr')
  expected <- read.csv(system.file('extdata', 'paper', 'wii-motion-expected.csv',
    package = 'replayr'
  ))
  movie <- read_dtm(path)
  channels <- analog_channels(movie)
  expect_identical(movie$header$dtmVariant, 'wii-serialized')
  expect_equal(n_frames(movie), 180L)
  expect_equal(as.integer(player(movie)[, 'A']), expected$a)
  sensor_names <- setdiff(names(expected), c('poll', 'a'))
  expect_equal(
    unname(channels[, sensor_names]),
    unname(as.matrix(expected[, sensor_names]))
  )
  expect_true(all(channels[, 'ir3_x'] == 1023 & channels[, 'ir3_y'] == 1023))
  expect_true(all(channels[, 'ir3_size'] == 15))
  expect_equal(unname(channels[120, 'ir1_x']), 728)
})
test_that('a source-specified packet separates gyro axes and rate flags', {
  # Dolphin SerializeDesiredState writes pitch, roll, yaw as distinct LE pairs.
  # Values are 0x1234, 0x2345, and 0x3456; slow flags are 1, 0, and 1.
  # Accel low bits deliberately exercise the shared D-pad byte.
  # Expected values follow DeserializeDesiredState / Common::ExpandValue.
  h <- raw(256)
  h[1:4] <- charToRaw('DTM\x1a')
  h[5:10] <- charToRaw('MOTION')
  h[11:12] <- as.raw(c(1, 16))
  h[22] <- as.raw(1)
  packet <- as.raw(c(
    11, 2, 244, 128, 128, 154,
    52, 146, 69, 35, 86, 180
  ))
  path <- tempfile(fileext = '.dtm')
  on.exit(unlink(path))
  writeBin(c(h, as.raw(length(packet)), packet), path)
  movie <- read_dtm(path)
  a <- analog_channels(movie)
  expect_true(player(movie)[1, 'B'])
  expect_true(player(movie)[1, 'L'])
  expect_false(player(movie)[1, 'A'])
  expect_equal(unname(a[1, c('accel_x', 'accel_y', 'accel_z')]), c(515, 515, 619))
  expect_equal(unname(a[1, c('gyro_pitch', 'gyro_roll', 'gyro_yaw')]), c(4660, 9029, 13398))
  expect_equal(unname(a[1, c('gyro_pitch_slow', 'gyro_roll_slow', 'gyro_yaw_slow')]), c(1, 0, 1))
})
test_that('relative mouse motion reconstructs the drag and return path', {
  movie <- read_movie(system.file('extdata', 'paper', 'mouse-drag.bk2', package = 'replayr'))
  a <- analog_channels(movie)
  expect_equal(unname(colSums(a)), c(60, 0))
  expect_equal(unname(colSums(a[61:120, , drop = FALSE])), c(60, -30))
  layout <- button_layout(movie)
  left <- which(layout$key == 'a')
  expect_true('Left Button' %in% movie$source_layout$name)
  expect_length(left, 1L)
  expect_equal(which(player(movie)[, left]), 61:120)
})
