test_that("M64 parses the bundled original N64 example", {
  mv <- replayr:::.decode_m64(analog = "quantized", fixture_path("sample.m64"))
  expect_s3_class(mv, "replayr_movie")
  expect_equal(mv$header[["_format"]], "m64")
  expect_equal(n_frames(mv), 3600L)
  expect_equal(n_buttons(mv), 28L)
  expect_gt(sum(press_counts(mv, 1L)[21:28]), 0L)
  expect_identical(mv$header$enabledPorts, 1L)
})
.mk_m64 <- function(samples, ports = 1L, vi_count = 99L) {
  hdr <- raw(0x400L)
  hdr[1:4] <- charToRaw("M64\x1a")
  hdr[5:8] <- writeBin(3L, raw(), size = 4L, endian = "little")
  hdr[13:16] <- writeBin(vi_count, raw(), size = 4L, endian = "little")
  hdr[21] <- as.raw(60L)
  hdr[22] <- as.raw(length(ports))
  hdr[25:28] <- writeBin(nrow(samples), raw(), size = 4L, endian = "little")
  hdr[33:36] <- writeBin(as.integer(sum(2^(ports - 1L))), raw(), size = 4L, endian = "little")
  tf <- tempfile(fileext = ".m64")
  writeBin(c(hdr, as.raw(as.vector(t(samples)))), tf)
  tf
}
test_that("M64 keeps input-sample and VI counts separate and exposes reset markers", {
  samples <- matrix(c(
    0x01, 0x00, 0x00, 0x00,
    0x00, 0xc0, 0x00, 0x00
  ), nrow = 2L, byrow = TRUE)
  tf <- .mk_m64(samples)
  on.exit(unlink(tf))
  mv <- read_m64(tf)
  expect_identical(n_frames(mv), 2L)
  expect_identical(mv$header$inputSampleCount, "2")
  expect_identical(mv$header$viCount, "99")
  expect_identical(mv$header$observationUnit, "controller poll")
  expect_true(player(mv)[1L, "R"])
  expect_equal(mv$commands, c(0L, 1L))
})
test_that("M64 handles every enabled-port combination without inventing assignment", {
  samples <- matrix(c(
    0x80, 0x01, 64, 0,
    0x40, 0x02, 0, 64,
    0x01, 0x04, 192, 128
  ), nrow = 3L, byrow = TRUE)
  paths <- character()
  on.exit(unlink(paths))
  for (mask in 1:15) {
    ports <- which(bitwAnd(mask, bitwShiftL(1L, 0:3)) != 0L)
    tf <- .mk_m64(samples, ports = ports)
    paths <- c(paths, tf)
    mv <- read_m64(tf)
    expect_identical(mv$header$enabledPorts, as.integer(ports))
    expect_identical(n_frames(mv), 3L)
    expect_equal(
      unname(analog_channels(mv)),
      matrix(c(64, 0, 0, 64, -64, -128), ncol = 2L, byrow = TRUE)
    )
    expect_identical(as.vector(t(mv$poll_bytes)), as.raw(as.vector(t(samples))))
    if (length(ports) == 1L) {
      expect_s3_class(mv, "replayr_movie")
      expect_identical(n_players(mv), 1L)
      expect_identical(mv$header$controllerPorts, as.integer(ports))
      expect_identical(unname(player(mv)[, "A"]), c(TRUE, FALSE, FALSE))
    } else {
      expect_s3_class(mv, "replayr_poll_stream")
      expect_false(inherits(mv, "replayr_movie"))
      expect_identical(n_players(mv), NA_integer_)
      result <- polls(mv)
      expect_identical(result$port, rep(NA_integer_, 3L))
      expect_identical(result$a, c(TRUE, FALSE, FALSE))
      expect_false(any(c("is_connected", "get_origin") %in% names(result)))
      expect_match(format(mv), "\\[m64\\]")
      expect_error(player(mv), "use polls")
    }
  }
})
test_that("M64 multiplayer polls retain analogue values in every stick mode", {
  samples <- matrix(c(
    0x80, 0x01, 64, 0,
    0x40, 0x02, 64, 64,
    0x00, 0xc0, 0, 0
  ), nrow = 3L, byrow = TRUE)
  tf <- .mk_m64(samples, ports = c(1L, 3L))
  on.exit(unlink(tf))
  for (mode in c("raw", "cardinal4", "cardinal8", "angle", "angle+magnitude")) {
    mv <- read_movie(tf, analog = mode)
    expect_s3_class(mv, "replayr_poll_stream")
    result <- polls(mv)
    expect_identical(result$commands, c(0L, 0L, 1L))
    expect_equal(unname(analog_channels(mv)), samples[, 3:4])
    expect_identical(result$a, c(TRUE, FALSE, FALSE))
    expect_identical(
      mv$button_ids,
      if (mode == "cardinal4") c(1:5, 7:8, 11:12, 18L, 20:24, 26L, 28L, 30L)
      else if (mode == "cardinal8") c(1:5, 7:8, 11:12, 18L, 20:31)
      else c(1:5, 7:8, 11:12, 18L, 20:23)
    )
    if (mode == "cardinal4") expect_equal(result$left_direction, c(0, 90, NA))
    if (mode == "cardinal8") expect_equal(result$left_direction, c(0, 45, NA))
    if (mode %in% c("angle", "angle+magnitude")) expect_equal(result$left_angle, c(0, 45, NA))
    if (mode == "angle+magnitude") expect_equal(result$left_magnitude, c(0.5, sqrt(0.5), 0))
  }
})
test_that("M64 assigns only a caller-supplied repeating polling order", {
  samples <- matrix(c(
    0x80, 0x00, 64, 0,
    0x40, 0xc0, 0, 64,
    0x01, 0x00, 192, 0,
    0x02, 0x00, 0, 192
  ), nrow = 4L, byrow = TRUE)
  tf <- .mk_m64(samples, ports = c(2L, 4L))
  on.exit(unlink(tf))
  mv <- read_m64(tf, controller_order = c(4L, 2L), analog = "angle+magnitude")
  expect_s3_class(mv, "replayr_movie")
  expect_identical(n_frames(mv), 2L)
  expect_identical(n_players(mv), 2L)
  expect_identical(mv$header$controllerPorts, c(2L, 4L))
  expect_identical(mv$header$inputSampleCount, "4")
  expect_identical(mv$header$viCount, "99")
  expect_identical(mv$header$observationUnit, "controller polling cycle")
  expect_match(mv$header$controllerAssignment, "caller-supplied")
  expect_true(player(mv, 1L)[1L, "B"])
  expect_true(player(mv, 2L)[1L, "A"])
  expect_equal(unname(analog_channels(mv, 1L)), matrix(c(0, 64, 0, -64), ncol = 2L, byrow = TRUE))
  expect_equal(unname(analog_channels(mv, 2L)), matrix(c(64, 0, -64, 0), ncol = 2L, byrow = TRUE))
  expect_equal(stick_channels(mv, 1L)[, "left_angle"], c(90, 270))
  expect_equal(mv$commands, c(1L, 0L))
  expect_identical(as.vector(t(mv$poll_bytes)), as.raw(as.vector(t(samples))))
  only_port4 <- read_m64(tf, controller_order = 4L)
  expect_identical(n_players(only_port4), 1L)
  expect_identical(n_frames(only_port4), 4L)
  expect_identical(only_port4$header$controllerPorts, 4L)
  for (order in list(c(2L, 2L), c(1L, 2L), numeric(), NA_real_, Inf, 2.5, "2")) {
    expect_error(read_m64(tf, controller_order = order), "distinct enabled ports")
  }
})
test_that("M64 assigns three and four controllers, including empty streams", {
  paths <- character()
  on.exit(unlink(paths))
  for (ports in list(c(1L, 3L, 4L), 1:4)) {
    for (cycles in c(0L, 2L)) {
      samples <- matrix(0L, nrow = cycles * length(ports), ncol = 4L)
      if (cycles) samples[, 3L] <- rep(seq_along(ports) * 20L, cycles)
      tf <- .mk_m64(samples, ports = ports)
      paths <- c(paths, tf)
      mv <- read_m64(tf, controller_order = rev(ports), analog = "cardinal8")
      expect_identical(n_frames(mv), cycles)
      expect_identical(n_players(mv), as.integer(length(ports)))
      expect_identical(mv$header$controllerPorts, as.integer(ports))
      if (cycles) expect_equal(analog_channels(mv, 1L)[, 1L], rep(length(ports) * 20, cycles))
      unassigned <- read_m64(tf)
      expect_s3_class(unassigned, "replayr_poll_stream")
      expect_equal(nrow(polls(unassigned)), cycles * length(ports))
    }
  }
})
test_that("M64 rejects truncated samples, incomplete cycles, and conflicting port metadata", {
  tf <- .mk_m64(matrix(0L, nrow = 3L, ncol = 4L), ports = c(1L, 2L))
  on.exit(unlink(tf))
  expect_error(read_m64(tf, controller_order = c(1L, 2L)), "incomplete")
  bytes <- readBin(tf, "raw", n = file.info(tf)$size)
  writeBin(head(bytes, -1L), tf)
  expect_error(read_m64(tf), "partial final")
  writeBin(head(bytes, -4L), tf)
  expect_error(read_m64(tf), "truncated")
  bytes[22L] <- as.raw(1L)
  writeBin(bytes, tf)
  expect_error(read_m64(tf), "controller count disagrees")
})
test_that("M64 retains surplus bytes beyond its declared samples", {
  samples <- matrix(c(128, 0, 64, 192, 64, 0, 0, 127), nrow = 2L, byrow = TRUE)
  tf <- .mk_m64(samples)
  on.exit(unlink(tf))
  original <- readBin(tf, "raw", n = file.info(tf)$size)
  for (tail in list(as.raw(1:2), as.raw(1:7), as.raw(1:8))) {
    writeBin(c(original, tail), tf)
    expect_warning(mv <- read_m64(tf), NA)
    expect_equal(n_frames(mv), 2L)
    expect_identical(mv$source_tail, tail)
    expect_identical(as.vector(t(mv$poll_bytes)), as.raw(as.vector(t(samples))))
    expect_identical(mv$header$sourceTailBytes, as.character(length(tail)))
    expect_equal(unname(analog_channels(mv)), matrix(c(64, -64, 0, 127), nrow = 2L, byrow = TRUE))
  }
})
