# Read every file of the other collections of the validation once, one after
# another in one R session, and record the time each takes: the Doom-engine
# demos, the GoldSrc demos, the Gym Retro recordings and the tables of the
# two Atari data sets. For the Doom-engine demos, the GoldSrc demos and each
# of the two Atari tables, the files at the median and at the 95th percentile
# of length are then read five times each, as timing-recordings.R does for
# the TASVideos formats.
#
# Usage, from the folder validation of the repository, after the retrievals:
#   Rscript scripts/timing-other-collections.R <Doom demos> <GoldSrc demos> <Gym Retro recordings>
#     <Atari data> [every file, default tables/timing-other-collections.csv]
#     [chosen files, default tables/timing-other-recordings.csv]
# Files are found in the folders by their SHA-256 hash, as the tables of the
# comparisons list them; a GoldSrc file that both readers refuse is read and
# its error recorded.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4L) stop("Give the folders of the Doom, GoldSrc, Gym Retro and Atari files.")
every_output <- if (length(args) >= 5L) args[5] else "tables/timing-other-collections.csv"
chosen_output <- if (length(args) >= 6L) args[6] else "tables/timing-other-recordings.csv"
suppressMessages(library(replayr))
table_of <- function(name) read.csv(file.path("tables", name), fileEncoding = "UTF-8", stringsAsFactors = FALSE)
doom <- table_of("doom-family-comparison.csv")
goldsrc <- table_of("goldsrc-comparison.csv")
gymretro <- table_of("gymretro-comparison.csv")
atari <- table_of("atari-comparison-by-file.csv")
listed <- rbind(
  data.frame(collection = "doom", sha256 = doom$sha256, game = doom$game, longtics = doom$longtics),
  data.frame(collection = "goldsrc", sha256 = goldsrc$sha256, game = "", longtics = NA),
  data.frame(collection = "gymretro", sha256 = gymretro$sha256, game = "", longtics = NA),
  data.frame(collection = ifelse(atari$data_set == "Atari-HEAD", "atari_head", "atari_grand_challenge"),
    sha256 = atari$sha256, game = "", longtics = NA)
)
folders <- c(doom = args[1], goldsrc = args[2], gymretro = args[3], atari_grand_challenge = args[4],
  atari_head = args[4])
listed$path <- NA_character_
for (collection in unique(listed$collection)) {
  files <- list.files(folders[[collection]], recursive = TRUE, full.names = TRUE)
  if (startsWith(collection, "atari")) files <- files[grepl("[.]txt$", files)]
  hashes <- vapply(files, digest::digest, character(1), algo = "sha256", file = TRUE, USE.NAMES = FALSE)
  rows <- listed$collection == collection
  listed$path[rows] <- files[match(listed$sha256[rows], hashes)]
}
if (anyNA(listed$path)) stop(sum(is.na(listed$path)), " listed files were not found in the folders.")
present <- function(x) !is.na(x) & nzchar(x)
read_one <- function(i) {
  call <- list(path = listed$path[i])
  if (present(listed$game[i])) call$game <- listed$game[i]
  if (!is.na(listed$longtics[i])) call$longtics <- as.logical(listed$longtics[i])
  suppressWarnings(do.call(read_movie, call))
}
n <- nrow(listed)
result <- data.frame(collection = listed$collection, sha256 = listed$sha256, format = tolower(tools::file_ext(listed$path)),
  bytes = file.size(listed$path), observations = NA_real_, seconds = NA_real_, object_bytes = NA_real_,
  how = NA_character_, stringsAsFactors = FALSE)
started <- Sys.time()
for (i in seq_len(n)) {
  # Elapsed times are counted in hundredths of a second.
  timing <- system.time(value <- tryCatch(read_one(i), error = function(e) conditionMessage(e)))
  result$seconds[i] <- round(timing[["elapsed"]], 2)
  if (is.character(value)) {
    result$how[i] <- paste("error:", substr(value, 1, 80))
  } else {
    result$how[i] <- class(value)[1L]
    result$observations[i] <- dim(value$inputs)[1L]
    result$object_bytes[i] <- as.numeric(object.size(value))
  }
  rm(value)
  if (i %% 500L == 0L) {
    gc(FALSE)
    cat(i, "/", n, " elapsed", round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1), "min\n")
  }
}
write.csv(result, every_output, row.names = FALSE)
read <- !grepl("^error", result$how)
by <- aggregate(cbind(files = 1, observations, seconds) ~ collection, result[read, ], sum)
print(by, row.names = FALSE)
print(table(result$collection[!read]))

# The files at the median and at the 95th percentile of length of each format
# that the TASVideos collection does not hold, read five times each.
megabytes <- function(x) as.numeric(x) / 1024^2
rows <- list()
for (collection in c("doom", "goldsrc", "atari_grand_challenge", "atari_head")) {
  set <- which(result$collection == collection & read)
  set <- set[order(result$observations[set])]
  for (level in c(0.5, 0.95)) {
    i <- set[max(1L, ceiling(level * length(set)))]
    seconds <- numeric(5); peak <- numeric(5)
    for (run in 1:5) {
      before <- sum(gc(reset = TRUE)[, 2L])
      seconds[run] <- system.time(movie <- read_one(i))[["elapsed"]]
      peak[run] <- sum(gc()[, 6L]) - before
      if (run < 5) rm(movie)
    }
    d <- dim(movie$inputs)
    rows[[length(rows) + 1L]] <- data.frame(
      collection = collection, format = result$format[i], level = level, observations = d[1L], controllers = d[2L],
      controls = d[3L], channels = ncol(analog_channels(movie)), file_mb = round(megabytes(result$bytes[i]), 3),
      seconds = round(stats::median(seconds), 3), per_second = round(d[1L] / stats::median(seconds)),
      object_mb = round(megabytes(object.size(movie)), 2), inputs_mb = round(megabytes(object.size(movie$inputs)), 2),
      peak_mb = round(max(peak), 1), unit = observation_unit(movie), sha256 = result$sha256[i],
      stringsAsFactors = FALSE
    )
    print(rows[[length(rows)]][, 1:13], row.names = FALSE)
    rm(movie)
  }
}
write.csv(do.call(rbind, rows), chosen_output, row.names = FALSE)
cat(R.version.string, "\n")
cat("replayr", as.character(packageVersion("replayr")), "\n")
