# recording_info() and observation_time(): one name for platform, video
# standard, frame rate and rerecord count, and the time of each observation.
info_movie <- function(file, ...) {
  suppressWarnings(read_movie(system.file("extdata", file, package = "replayr", mustWork = TRUE), ...))
}
with_byte <- function(file, offset, bit, ext) {
  bytes <- readBin(system.file("extdata", file, package = "replayr", mustWork = TRUE), "raw", n = 1e7)
  bytes[offset + 1L] <- as.raw(bitwOr(as.integer(bytes[offset + 1L]), bit))
  path <- tempfile(fileext = ext)
  writeBin(bytes, path)
  path
}
test_that("an NES recording is placed on the console's frame rate", {
  movie <- info_movie("sample.fm2")
  info <- recording_info(movie)
  expect_identical(names(info), c(
    "format", "platform", "video_standard", "unit", "observations", "frame_rate",
    "frame_rate_source", "duration", "rerecords"
  ))
  expect_identical(nrow(info), 1L)
  expect_identical(c(info$format, info$platform, info$video_standard, info$unit), c("fm2", "NES", "NTSC", "frame"))
  expect_equal(info$frame_rate, 39375000 / 655171, tolerance = 1e-12)
  expect_identical(info$frame_rate_source, "platform")
  expect_equal(info$duration, 3600 / info$frame_rate)
  expect_identical(info$rerecords, 0)
  times <- observation_time(movie)
  expect_identical(length(times), 3600L)
  expect_equal(times[1:3], c(0, 1, 2) / info$frame_rate)
  # A selection keeps the times of the file.
  expect_equal(observation_time(movie[601:603]), c(600, 601, 602) / info$frame_rate)
  expect_equal(recording_info(movie[601:603])$duration, 3 / info$frame_rate)
  pal <- tempfile(fileext = ".fm2")
  writeLines(c("version 3", "palFlag 1", "port0 1", "port1 0", "port2 0", "|0|.......A|||", "|0|........|||"), pal)
  on.exit(unlink(pal))
  info <- recording_info(read_movie(pal))
  expect_identical(info$video_standard, "PAL")
  expect_equal(info$frame_rate, 50.00697796826829)
})
test_that("the nominal rates are those BizHawk documents", {
  rates <- replayr:::.NOMINAL_FRAME_RATES
  expect_equal(rates$SNES[["NTSC"]], 60.0988118623, tolerance = 1e-10)
  expect_equal(rates$SNES[["PAL"]], 50.0069789082, tolerance = 1e-10)
  expect_equal(rates$GB, 59.7275005696, tolerance = 1e-10)
  expect_equal(rates$NDS, 59.8260982881, tolerance = 1e-10)
  expect_equal(rates[["3DS"]], 59.8312249394, tolerance = 1e-10)
  expect_equal(rates$PCE, 59.8261054535, tolerance = 1e-10)
  expect_equal(unname(rates$SMS), c(59.9227434043, 49.7014320946), tolerance = 1e-10)
  expect_equal(rates$NGP, 60.2530155928, tolerance = 1e-10)
  expect_equal(rates$VB, 50.2734877735, tolerance = 1e-10)
  expect_equal(rates$WSWAN, 75.4716981132, tolerance = 1e-10)
  expect_equal(rates$Lynx, 59.89817310572028, tolerance = 1e-12)
  expect_equal(unname(rates$SAT), c(59.883028483737256, 49.960031974420467), tolerance = 1e-12)
  expect_equal(unname(rates$PSX), c(59.940060138702392578125, 50.00028192996978759765625), tolerance = 1e-14)
  expect_equal(unname(rates$A26), c(59.922751013550531, 49.860759671614935), tolerance = 1e-12)
  expect_equal(unname(rates$O2), c(59.8260982065907, 49.7014612410356), tolerance = 1e-12)
  expect_equal(unname(rates$Amiga), c(59.826105453481879, 49.920409283472435), tolerance = 1e-12)
  expect_equal(rates$UZE, 60.05444936742646, tolerance = 1e-12)
  expect_equal(unname(rates$GEN), c(53693175 / 896040, 53203424 / 1070460))
  # A console sold in both standards has no rate without one.
  expect_true(all(vapply(rates, function(x) is.null(names(x)) || all(names(x) %in% c("NTSC", "PAL")), logical(1))))
})
test_that("platform and video standard come from the header of each format", {
  expect_identical(recording_info(info_movie("sample.smv"))[c("platform", "video_standard")], data.frame(platform = "SNES", video_standard = "NTSC"))
  expect_identical(recording_info(suppressWarnings(read_movie(with_byte("sample.smv", 0x15, 2L, ".smv"))))$video_standard, "PAL")
  expect_identical(recording_info(info_movie("sample.pxm"))[c("platform", "video_standard")], data.frame(platform = "PSX", video_standard = "NTSC"))
  expect_identical(recording_info(suppressWarnings(read_movie(with_byte("sample.pxm", 0x0C, 4L, ".pxm"))))$video_standard, "PAL")
  pjm <- recording_info(info_movie("sample.pjm"))
  expect_identical(c(pjm$platform, pjm$video_standard), c("PSX", "NTSC"))
  expect_equal(pjm$frame_rate, 502813668 / 8388608)
  expect_identical(recording_info(suppressWarnings(read_movie(with_byte("sample.pjm", 12L, 4L, ".pjm"))))$video_standard, "PAL")
  gmv <- recording_info(info_movie("sample.gmv"))
  expect_identical(c(gmv$platform, gmv$video_standard, gmv$frame_rate_source), c("GEN", "NTSC", "platform"))
  # A handheld has one rate and no video standard.
  vbm <- recording_info(info_movie("sample.vbm"))
  expect_true(vbm$platform %in% c("GB", "GBC", "GBA", "SGB"))
  expect_true(is.na(vbm$video_standard) || vbm$platform == "SGB")
  expect_false(is.na(vbm$frame_rate))
  # Names other emulators use are brought to one code.
  expect_identical(recording_info(info_movie("legacy/vboy.mc2"))$platform, "VB")
  expect_identical(recording_info(info_movie("legacy/lynx.mcm"))$platform, "Lynx")
  expect_identical(recording_info(info_movie("legacy/saturn.ymv"))$platform, "SAT")
  expect_identical(recording_info(info_movie("legacy/touch-binary.dsm"))$platform, "NDS")
  expect_identical(recording_info(info_movie("sample.dtm"))$platform, "GC")
  # BizHawk writes a PAL entry for PAL recordings only, and the frame length
  # of an arcade machine.
  bizhawk <- function(header) {
    log <- paste(c("[Input]", "LogKey:#Reset|Power|#P1 Up|P1 A|", "|..|..|", "|..|.A|"), collapse = "\n")
    recording_info(replayr:::.configure_movie(replayr:::.parse_bk2_input_log(log, c(list("_format" = "bk2"), header))))
  }
  expect_identical(bizhawk(list(Platform = "NES"))$video_standard, "NTSC")
  expect_identical(bizhawk(list(Platform = "NES", PAL = "True"))$video_standard, "PAL")
  expect_identical(bizhawk(list(Platform = "A26", PAL = "1"))$frame_rate, 3546895 / 71136)
  handheld <- bizhawk(list(Platform = "GBC"))
  expect_true(is.na(handheld$video_standard))
  expect_equal(handheld$frame_rate, 262144 / 4389)
  arcade <- bizhawk(list(Platform = "Arcade", VsyncAttoseconds = "16957775139901646"))
  expect_equal(arcade$frame_rate, 1e18 / 16957775139901646)
  expect_identical(arcade$frame_rate_source, "recording")
  # No rate is assumed for a platform that is not in the table.
  unknown <- bizhawk(list(Platform = "Example"))
  expect_true(is.na(unknown$frame_rate) && is.na(unknown$duration))
})
test_that("a fallback rate applies only where no other rate is known", {
  n64 <- info_movie("expanded/legacy-n64.bkm")
  expect_true(is.na(recording_info(n64)$frame_rate))
  expect_true(all(is.na(observation_time(n64))))
  named <- recording_info(n64, fallback_rate = 60)
  expect_identical(c(named$frame_rate, named$frame_rate_source), c("60", "fallback"))
  expect_equal(named$duration, n_observations(n64) / 60)
  expect_equal(observation_time(n64, fallback_rate = 50), (seq_len(n_observations(n64)) - 1) / 50)
  # A recording with a rate of its own, or with its own times, keeps them.
  nes <- info_movie("sample.fm2")
  expect_identical(recording_info(nes, fallback_rate = 50), recording_info(nes))
  expect_identical(observation_time(nes, fallback_rate = 50), observation_time(nes))
  events <- info_movie("computers/keyboard-mouse.jrsr")
  expect_identical(recording_info(events, fallback_rate = 60), recording_info(events))
  varying <- info_movie("computers/dual-stick-menu.ltm")
  expect_identical(recording_info(varying, fallback_rate = 60), recording_info(varying))
  # Controller polls stay without a time: their number per frame is not fixed.
  polls <- info_movie("sample.dtm")
  expect_identical(recording_info(polls, fallback_rate = 60)$frame_rate_source, "fallback")
  expect_true(all(is.na(observation_time(polls, fallback_rate = 60))))
  expect_true(is.na(recording_info(polls, fallback_rate = 60)$duration))
  expect_error(recording_info(nes, fallback_rate = 0), "one positive number")
  expect_error(observation_time(nes, fallback_rate = c(50, 60)), "one positive number")
  expect_error(observation_time(nes, fallback_rate = "60"), "one positive number")
})
test_that("recordings with their own times are read from them", {
  tas <- info_movie("computers/dual-stick-menu.ltm")
  lengths <- tas$timing$framerate_den / tas$timing$framerate_num
  expect_gt(length(unique(lengths)), 1L)
  expect_equal(observation_time(tas), cumsum(c(0, lengths))[seq_along(lengths)])
  info <- recording_info(tas)
  expect_true(is.na(info$frame_rate))
  expect_equal(info$duration, sum(lengths))
  expect_equal(observation_time(tas[3:4]), observation_time(tas)[3:4])
  steady <- recording_info(info_movie("computers/idle.ltm"))
  expect_identical(c(steady$frame_rate, steady$frame_rate_source), c("60", "recording"))
  events <- info_movie("computers/keyboard-mouse.jrsr")
  expect_equal(observation_time(events), events$events$timestamp_ns / 1e9)
  expect_identical(recording_info(events)$unit, "event")
  msx <- info_movie("computers/keyboard-joystick.omr")
  expect_equal(observation_time(msx), as.numeric(msx$events$timestamp_seconds))
  expect_equal(recording_info(msx)$duration, diff(range(msx$events$timestamp_seconds)))
  doom <- recording_info(info_movie("sample.lmp"))
  expect_identical(c(doom$frame_rate, doom$frame_rate_source, doom$unit), c("35", "format", "game tic"))
  expect_equal(doom$duration, doom$observations / 35)
  # Several input samples of one lsnes frame begin with that frame.
  snes <- info_movie("sample.lsmv")
  rate <- recording_info(snes)$frame_rate
  expect_equal(observation_time(snes), (snes$subframes$source_frame - 1) / rate)
  expect_equal(recording_info(snes)$duration, length(unique(snes$subframes$source_frame)) / rate)
})
test_that("controller polls have no time, and every recording has a description", {
  polls <- info_movie("sample.m64")
  info <- recording_info(polls)
  expect_identical(c(info$platform, info$video_standard, info$unit), c("N64", "NTSC", "controller poll"))
  expect_identical(c(info$frame_rate, info$frame_rate_source), c("60", "recording"))
  expect_true(is.na(info$duration))
  expect_true(all(is.na(observation_time(polls))))
  files <- list.files(system.file("extdata", package = "replayr"), recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("[.](md|json|csv|txt)$", files)]
  described <- 0L
  for (file in files) {
    movie <- tryCatch(suppressWarnings(read_movie(file)), error = function(e) NULL)
    if (is.null(movie) || !inherits(movie, c("replayr_movie", "replayr_poll_stream"))) next
    info <- recording_info(movie)
    times <- observation_time(movie)
    described <- described + 1L
    expect_identical(nrow(info), 1L, info = basename(file))
    expect_false(is.na(info$platform), info = basename(file))
    expect_identical(length(times), dim(movie$inputs)[1L], info = basename(file))
    expect_true(all(is.na(times)) || !anyNA(times), info = basename(file))
    if (!anyNA(times)) expect_false(is.unsorted(times), info = basename(file))
    expect_identical(is.na(info$frame_rate), is.na(info$frame_rate_source), info = basename(file))
    if (is.na(info$duration)) expect_true(anyNA(times) || !length(times), info = basename(file))
  }
  expect_gt(described, 60L)
})
