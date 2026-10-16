# Nominal video frame rates of consoles, by platform and video standard, in
# frames per second. These are the values with which BizHawk times its
# recordings (PlatformFrameRates in BizHawk.Client.Common); each is the
# console's master clock divided by the clock cycles of one frame. A platform
# whose rate does not depend on a video standard has one value. A platform
# without an entry has no nominal rate here: none is assumed for it.
.NOMINAL_FRAME_RATES <- list(
  NES = c(NTSC = 60.098813897440515, PAL = 50.00697796826829),
  FDS = c(NTSC = 60.098813897440515, PAL = 50.00697796826829),
  SNES = c(NTSC = 21477272 / (4 * 341 * 262 - 2), PAL = 21281370 / (4 * 341 * 312)),
  SGB = c(NTSC = 21477272 / (4 * 341 * 262 - 2), PAL = 21281370 / (4 * 341 * 312)),
  GB = 262144 / 4389, GBC = 262144 / 4389, GBA = 262144 / 4389,
  NDS = 33513982 / 560190, `3DS` = 268111856 / 4481136,
  GEN = c(NTSC = 53693175 / (3420 * 262), PAL = 53203424 / (3420 * 313)),
  SMS = c(NTSC = 3579545 / 262 / 228, PAL = 3546893 / 313 / 228),
  GG = c(NTSC = 3579545 / 262 / 228, PAL = 3546893 / 313 / 228),
  SG = c(NTSC = 3579545 / 262 / 228, PAL = 3546893 / 313 / 228),
  PCE = 2250000 / 37609, PCECD = 2250000 / 37609,
  PSX = c(NTSC = 502813668 / 8388608, PAL = 419432765 / 8388608),
  SAT = c(NTSC = 8734090909 / 145852525, PAL = 62500 / 1251),
  A26 = c(NTSC = 1640625 / 27379, PAL = 3546895 / 71136),
  A78 = 1640625 / 27379, Coleco = 1640625 / 27379, INTV = 1498 / 25,
  NGP = 6144000 / (515 * 198), VB = 20000000 / (259 * 384 * 4),
  Lynx = 16000000 / (16 * 105 * 159), WSWAN = 3072000 / (159 * 256),
  `3DO` = c(NTSC = 60, PAL = 50), Jaguar = c(NTSC = 60, PAL = 50),
  Amiga = c(NTSC = 2250000 / 37609, PAL = 3546895 / 71051),
  O2 = c(NTSC = 89478485 / 1495643, PAL = 89478485 / 1800319),
  ChannelF = c(NTSC = 234375 / 3872, PAL = 15625 / 312),
  ZXSpectrum = c(PAL = 15625 / 312), AmstradCPC = c(PAL = 15625 / 312),
  UZE = 1125000 / 18733, VEC = 50, TIC80 = 60
)
# One code for each platform. Readers of BizHawk recordings report BizHawk's
# own system codes; the names other emulators use are brought to the same
# codes, and a format that serves one console implies its platform (see the
# format registry). The second row holds the names Gym Retro writes for the
# platforms it has no BizHawk code for (openai/retro, src/movie-bk2.cpp).
.PLATFORM_SYNONYMS <- c(
  SATURN = "SAT", VBOY = "VB", LYNX = "Lynx", DS = "NDS", GAMECUBE = "GC", WII = "Wii",
  A2600 = "A26", A7800 = "A78", GENESIS = "GEN", GBAL = "GBA", GBL = "GB", SGX = "PCE",
  GAMEBOY = "GB", GBCOLOR = "GBC", GBADVANCE = "GBA", SMS = "SMS", GAMEGEAR = "GG", PCENGINE = "PCE"
)
.header_value <- function(header, keys) {
  for (key in keys) {
    value <- header[[key]]
    if (length(value) == 1L && !is.na(value) && nzchar(as.character(value))) return(value)
  }
  NULL
}
.recording_platform <- function(movie) {
  header <- movie$header
  format <- header[["_format"]] %||% "fm2"
  standard <- NA_character_
  platform <- .header_value(header, c("Platform", "system"))
  if (identical(format, "vbm")) {
    platform <- if (isTRUE(as.logical(header$isGBA))) "GBA" else if (isTRUE(as.logical(header$isSGB))) "SGB" else
      if (isTRUE(as.logical(header$isGBC))) "GBC" else "GB"
  } else if (identical(format, "lsmv") && !is.null(header$gametype)) {
    # lsnes names the system and its video standard in one word.
    type <- tolower(header$gametype)
    platform <- if (grepl("^sgb", type)) "SGB" else if (type %in% c("ggbc", "ggbca")) "GBC" else
      if (type == "gdmg") "GB" else "SNES"
    if (grepl("_pal$", type)) standard <- "PAL" else if (!platform %in% c("GB", "GBC")) standard <- "NTSC"
  }
  if (is.null(platform)) platform <- .FORMAT_REGISTRY$platform[match(format, .FORMAT_REGISTRY$extension)]
  platform <- as.character(platform)
  if (!is.na(platform) && toupper(platform) %in% names(.PLATFORM_SYNONYMS))
    platform <- .PLATFORM_SYNONYMS[[toupper(platform)]]
  # The video standard, where the recording has a flag for it.
  flag <- .header_value(header, c("palFlag", "PAL", "isPal"))
  if (!is.null(flag)) {
    standard <- if (tolower(as.character(flag)) %in% c("1", "true")) "PAL" else "NTSC"
  } else if (format %in% c("fm2", "fm3")) {
    # FCEUX plays a movie without a palFlag line as NTSC: the flag defaults
    # to false (MovieData in movie.cpp) and selects the video system on load.
    standard <- "NTSC"
  } else if (format %in% c("bk2", "bkm", "tas", "tasproj", "gbmv") &&
    "PAL" %in% names(.NOMINAL_FRAME_RATES[[platform %||% ""]])) {
    # BizHawk writes its PAL entry for PAL recordings only.
    standard <- "NTSC"
  } else if (format %in% c("gmv", "m64") && !is.null(.header_value(header, "fps"))) {
    # GMV and M64 store the standard as 50 or 60 fields per second.
    standard <- if (identical(as.numeric(header$fps), 50)) "PAL" else "NTSC"
  }
  # A handheld has no video standard.
  if (!is.na(platform) && is.null(names(.NOMINAL_FRAME_RATES[[platform]])) &&
    !is.null(.NOMINAL_FRAME_RATES[[platform]])) standard <- NA_character_
  list(platform = platform, standard = standard)
}
.fallback_frame_rate <- function(fallback_rate) {
  if (length(fallback_rate) != 1L || !(is.na(fallback_rate) ||
    (is.numeric(fallback_rate) && is.finite(fallback_rate) && fallback_rate > 0))) {
    stop("fallback_rate must be NA or one positive number of frames per second, such as 60 or 50.", call. = FALSE)
  }
  as.numeric(fallback_rate)
}
# Recordings of events carry a time with every observation and have no frames.
.has_event_times <- function(movie) {
  !is.null(movie$events$timestamp_ns) || !is.null(movie$events$timestamp_seconds)
}
.recording_frame_rate <- function(movie, platform = .recording_platform(movie), fallback_rate = NA_real_) {
  header <- movie$header
  format <- header[["_format"]] %||% "fm2"
  none <- list(rate = NA_real_, source = NA_character_)
  # A rate the recording states.
  stated <- switch(format,
    mar = .header_value(header, "frameRate"), wtf = .header_value(header, "fps"),
    dft = .header_value(header, "frame_rate"), m64 = .header_value(header, "fps"), NULL
  )
  if (!is.null(stated) && is.finite(suppressWarnings(as.numeric(stated))))
    return(list(rate = as.numeric(stated), source = "recording"))
  # BizHawk stores the length of one frame of an arcade machine.
  vsync <- suppressWarnings(as.numeric(.header_value(header, "VsyncAttoseconds") %||% NA))
  if (is.finite(vsync) && vsync > 0) return(list(rate = 1e18 / vsync, source = "recording"))
  if (identical(format, "ltm") && !is.null(movie$timing)) {
    # libTAS stores a rate with every frame; one value describes the
    # recording only where it never changes.
    rates <- unique(movie$timing$framerate_num / movie$timing$framerate_den)
    if (length(rates) == 1L && is.finite(rates)) return(list(rate = rates, source = "recording"))
    return(none)
  }
  # Doom engines run 35 tics per second, and the Atari Grand Challenge data
  # set was recorded at 60 frames per second.
  if (identical(format, "lmp")) return(list(rate = 35, source = "format"))
  if (identical(format, "atari_gc")) return(list(rate = 60, source = "format"))
  if (.has_event_times(movie)) return(none)
  # Where neither the recording nor its platform gives a rate, the one the
  # caller names is used and reported as such.
  if (!is.na(fallback_rate)) none <- list(rate = fallback_rate, source = "fallback")
  rates <- .NOMINAL_FRAME_RATES[[platform$platform %||% ""]]
  if (is.null(rates) || is.na(platform$platform)) return(none)
  if (is.null(names(rates))) return(list(rate = rates, source = "platform"))
  if (is.na(platform$standard) || !platform$standard %in% names(rates)) return(none)
  list(rate = rates[[platform$standard]], source = "platform")
}
#' Time of each observation
#'
#' Returns the time, in seconds from the start of the recording, at which each
#' observation begins. A recording with its own times is read from them:
#' libTAS stores the length of every frame, and JPC-RR and openMSX store a
#' timestamp with every event. A recording of frames or game tics without
#' times is placed on the frame rate of [recording_info()], where it has one. Observations that
#' are controller polls or game updates have no time in the file, and their
#' number per frame is not fixed; they return `NA`.
#'
#' After a selection with `[`, times still count from the start of the file.
#' A frame rate that [recording_info()] reports as nominal for the platform is
#' that of the original console; an emulator that ran at another speed, or a
#' game that lags, does not change the times returned here.
#'
#' @inheritParams n_observations
#' @param fallback_rate Frame rate, in frames per second, to use where neither
#'   the recording nor its platform gives one, such as 60 or 50 for a
#'   Nintendo 64 recording. The default `NA` assumes none.
#' @return Numeric vector with one entry per observation, in seconds; `NA`
#'   where the recording fixes no time.
#' @seealso [recording_info()], [observation_unit()]
#' @examples
#' movie <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' range(observation_time(movie))
#' # Seconds for which A is held.
#' sum(diff(observation_time(movie))[player(movie)[-1, "a"]])
#' @export
observation_time <- function(movie, fallback_rate = NA) {
  stopifnot(.is_recording(movie))
  fallback_rate <- .fallback_frame_rate(fallback_rate)
  n <- as.integer(dim(movie$inputs)[1L])
  if (!is.null(movie$timing$start_seconds) && nrow(movie$timing) == n) return(movie$timing$start_seconds)
  if (!is.null(movie$events$timestamp_ns) && nrow(movie$events) == n) return(movie$events$timestamp_ns / 1e9)
  if (!is.null(movie$events$timestamp_seconds) && nrow(movie$events) == n)
    return(as.numeric(movie$events$timestamp_seconds))
  rate <- .recording_frame_rate(movie, fallback_rate = fallback_rate)$rate
  unit <- observation_unit(movie)
  if (is.na(rate)) return(rep(NA_real_, n))
  # lsnes can store several input samples in one frame; all begin with it.
  if (unit == "input subframe" && !is.null(movie$subframes$source_frame) && nrow(movie$subframes) == n)
    return((movie$subframes$source_frame - 1) / rate)
  if (!unit %in% c("frame", "scripted frame", "game tic")) return(rep(NA_real_, n))
  ((movie$observation_index %||% seq_len(n)) - 1) / rate
}
#' Platform, timing and rerecord count of a recording
#'
#' Formats name these properties differently and keep them in different
#' places (`Platform`, `system`, `palFlag`, `isPal`, `fps`, `frameRate`,
#' `rerecordCount`, `rerecords`); `movie$header` holds them under the names of
#' the format. This function reports them under one name each.
#'
#' `platform` is BizHawk's code for the system (`NES`, `SNES`, `GB`, `GBC`,
#' `GBA`, `N64`, `PSX`, `SAT`, `GEN`, `SMS`, `GG`, `PCE`, `NDS`, `3DS`, `A26`
#' and so on), also for recordings of other emulators, with `GC` and `Wii` for
#' Dolphin and `PC` for recordings of computer programs. A format that serves
#' one console implies its platform.
#'
#' `frame_rate` is in video frames per second, and `frame_rate_source` says
#' where it comes from: `"recording"` for a rate the file states,
#' `"format"` for the 35 tics per second of Doom engines and the 60 frames
#' per second of the Atari Grand Challenge data set, and `"platform"`
#' for the nominal rate of the console and video standard, as BizHawk uses
#' it to time recordings. The nominal rate is that of the original hardware.
#' No rate is assumed where the platform or, for a console sold in both
#' standards, the video standard is not known, unless `fallback_rate` names
#' one; the source is then `"fallback"`.
#'
#' @inheritParams observation_time
#' @return A data frame with one row: `format`, `platform`, `video_standard`
#'   (`"NTSC"`, `"PAL"` or `NA`), `unit` (see [observation_unit()]),
#'   `observations`, `frame_rate`, `frame_rate_source`, `duration` in seconds
#'   (from the first observation to the end of the last; `NA` where
#'   [observation_time()] is) and `rerecords`.
#' @seealso [observation_time()]
#' @examples
#' movie <- read_movie(system.file("extdata", "sample.fm2", package = "replayr"))
#' recording_info(movie)
#' # A Nintendo 64 recording in BizHawk's older format names no rate.
#' n64 <- read_movie(system.file("extdata", "expanded", "legacy-n64.bkm", package = "replayr"))
#' recording_info(n64)[c("frame_rate", "frame_rate_source", "duration")]
#' recording_info(n64, fallback_rate = 60)[c("frame_rate", "frame_rate_source", "duration")]
#' @export
recording_info <- function(movie, fallback_rate = NA) {
  stopifnot(.is_recording(movie))
  fallback_rate <- .fallback_frame_rate(fallback_rate)
  n <- as.integer(dim(movie$inputs)[1L])
  platform <- .recording_platform(movie)
  rate <- .recording_frame_rate(movie, platform, fallback_rate)
  times <- observation_time(movie, fallback_rate)
  duration <- NA_real_
  if (n && !anyNA(times)) {
    if (!is.null(movie$timing$duration_seconds) && nrow(movie$timing) == n) {
      duration <- sum(movie$timing$duration_seconds)
    } else if (.has_event_times(movie) || !is.null(movie$timing$start_seconds)) {
      duration <- diff(range(times))
    } else if (!is.na(rate$rate)) {
      # Observations that share a frame count once.
      duration <- length(unique(times)) / rate$rate
    }
  }
  rerecords <- .header_value(movie$header, c("rerecordCount", "rerecord_count", "rerecords"))
  rerecords <- if (is.null(rerecords)) NA_real_ else suppressWarnings(as.numeric(rerecords))
  data.frame(
    format = movie$header[["_format"]] %||% "fm2", platform = platform$platform,
    video_standard = platform$standard, unit = observation_unit(movie), observations = n,
    frame_rate = rate$rate, frame_rate_source = rate$source, duration = duration,
    rerecords = rerecords, stringsAsFactors = FALSE
  )
}
