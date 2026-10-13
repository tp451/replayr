# The default deadzone follows the controller, not the file format.
test_that("the default deadzone is that of the controller", {
  zone <- function(...) {
    path <- system.file("extdata", ..., package = "replayr")
    unname(suppressWarnings(read_movie(path))$stick_deadzone)
  }
  # Sticks of Nintendo's consoles.
  expect_identical(zone("sample.m64"), c(0.125, 0.125))
  expect_identical(zone("sample.dtm"), c(0.125, 0.125))
  expect_identical(zone("legacy", "buttons.gzm"), c(0.125, 0.125))
  expect_identical(zone("legacy", "devices.ctm"), c(0.125, 0.125))
  expect_identical(zone("expanded", "legacy-n64.bkm"), c(0.125, 0.125))
  # The same console recorded by another emulator has the same default.
  expect_identical(zone("expanded", "two-stick-3ds.bk2"), c(0.125, 0.125))
  for (format in c("bk2", "bkm", "tas", "m64", "gzm")) {
    movie <- list(header = list("_format" = format, Platform = "N64"))
    expect_identical(replayr:::.default_deadzone(movie), 0.125, info = format)
  }
  # Other sticks.
  expect_identical(zone("semantic", "semantic-onehot.pxm"), c(0.25, 0.25))
  expect_identical(zone("semantic", "semantic-onehot.pjm"), c(0.25, 0.25))
  expect_identical(zone("computers", "dual-stick-menu.ltm"), c(0.25, 0.25))
  expect_identical(zone("bk2-variants", "arcade-throttle.bk2"), c(0.25, 0.25))
  for (platform in c("PSX", "SAT", "Arcade")) {
    movie <- list(header = list("_format" = "bk2", Platform = platform))
    expect_identical(replayr:::.default_deadzone(movie), 0.25, info = platform)
  }
})
test_that("a given deadzone replaces the default, and the default decides at its boundary", {
  path <- system.file("extdata", "sample.m64", package = "replayr")
  given <- read_movie(path, analog = "angle", deadzone = c(left = 0.5, right = 0.1))
  expect_identical(given$stick_deadzone, c(left = 0.5, right = 0.1))
  # A stick 16 of 128 units from the centre has a direction, one of 15 has none.
  movie <- replayr:::.decode_m64(path)
  stick <- match(c("lstick_x", "lstick_y"), colnames(movie$analog[[1L]]))
  movie$analog[[1L]][1:2, stick] <- rbind(c(16, 0), c(15, 0))
  angle <- stick_channels(replayr:::.configure_movie(movie, analog = "angle"))[1:2, "left_angle"]
  expect_identical(unname(angle), c(0, NA_real_))
})
