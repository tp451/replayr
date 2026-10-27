# Time and memory of read_movie() for chosen TASVideos recordings: for each
# of twelve formats, the recording at the median and the one at the 95th
# percentile of the numbers of observations of that format in the collection.
# Each is read five times in a fresh state of the garbage collector.
# Reported: the median elapsed time, the size of the returned object, the
# size of its logical input array, and the largest amount of memory R held
# during a read beyond what it held before it.
#
# Usage, from the folder validation of the repository, after retrieve-recordings.R:
#   Rscript scripts/timing-recordings.R [output, default tables/timing-recordings.csv]
# Environment: REPLAYR_VALIDATION_ROOT (folder with the recordings),
#   REPLAYR_VALIDATION_MANIFEST (default tables/validation-manifest.csv).
args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args) >= 1L) args[1] else "tables/timing-recordings.csv"
suppressMessages(library(replayr))
root <- Sys.getenv("REPLAYR_VALIDATION_ROOT")
if (!nzchar(root) || !dir.exists(root)) stop("Set REPLAYR_VALIDATION_ROOT to the recording directory.")
manifest <- read.csv(Sys.getenv("REPLAYR_VALIDATION_MANIFEST", "tables/validation-manifest.csv"),
  fileEncoding = "UTF-8")
manifest <- manifest[manifest$status == "ok" & !is.na(manifest$observations) & manifest$observations > 0, ]
has_value <- function(x) length(x) == 1L && !is.na(x) && nzchar(x)
formats <- c("fm2", "bk2", "smv", "vbm", "gmv", "m64", "dtm", "lsmv", "ltm", "pjm", "dsm", "jrsr")
megabytes <- function(x) as.numeric(x) / 1024^2
rows <- list()
for (format in formats) {
  set <- manifest[manifest$format == format, ]
  set <- set[order(set$observations), ]
  for (level in c(0.5, 0.95)) {
    row <- set[max(1L, ceiling(level * nrow(set))), ]
    call <- list(path = file.path(root, row$relative_path))
    if (has_value(row$game)) call$game <- row$game
    seconds <- numeric(5); peak <- numeric(5)
    for (run in 1:5) {
      before <- sum(gc(reset = TRUE)[, 2L])
      seconds[run] <- system.time(movie <- suppressWarnings(do.call(read_movie, call)))[["elapsed"]]
      peak[run] <- sum(gc()[, 6L]) - before
      if (run < 5) rm(movie)
    }
    n <- dim(movie$inputs)
    rows[[length(rows) + 1L]] <- data.frame(
      format = format, level = level, observations = n[1L], controllers = n[2L], controls = n[3L],
      channels = ncol(analog_channels(movie)), file_mb = round(megabytes(file.size(call$path)), 3),
      seconds = round(stats::median(seconds), 3), per_second = round(n[1L] / stats::median(seconds)),
      object_mb = round(megabytes(object.size(movie)), 2), inputs_mb = round(megabytes(object.size(movie$inputs)), 2),
      peak_mb = round(max(peak), 1), unit = observation_unit(movie), file = row$relative_path,
      stringsAsFactors = FALSE
    )
    print(rows[[length(rows)]][, 1:12], row.names = FALSE)
    rm(movie)
  }
}
write.csv(do.call(rbind, rows), output, row.names = FALSE)
cat(R.version.string, "\n")
cat("replayr", as.character(packageVersion("replayr")), "\n")
