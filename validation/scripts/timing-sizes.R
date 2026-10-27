# Time and memory of read_movie() as a recording grows: artificial FM2 files
# of one controller with ten thousand to ten million frames, each read three
# times. Reported for each length: the median elapsed time, the sizes of the
# returned object and of its logical input array, the bytes per stored button
# state, and the largest amount of memory R held during a read beyond what it
# held before it. No recording is needed.
#
# Usage, from the folder validation of the repository:
#   Rscript scripts/timing-sizes.R [output, default tables/timing-sizes.csv]
args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args) >= 1L) args[1] else "tables/timing-sizes.csv"
suppressMessages(library(replayr))
megabytes <- function(x) as.numeric(x) / 1024^2
rows <- list()
for (n in c(1e4, 1e5, 1e6, 1e7)) {
  path <- tempfile(fileext = ".fm2")
  # Right held throughout, A pressed every sixth frame.
  records <- rep("|0|R.......|||", n)
  records[seq(1, n, by = 6)] <- "|0|R......A|||"
  writeLines(c("version 3", "emuVersion 22020", "port0 1", "port1 0", "port2 0", records), path)
  rm(records)
  seconds <- numeric(3); peak <- numeric(3)
  for (run in 1:3) {
    before <- sum(gc(reset = TRUE)[, 2L])
    seconds[run] <- system.time(movie <- read_movie(path))[["elapsed"]]
    peak[run] <- sum(gc()[, 6L]) - before
    if (run < 3) rm(movie)
  }
  stopifnot(n_observations(movie) == n, sum(player(movie)[, "a"]) == length(seq(1, n, by = 6)))
  rows[[length(rows) + 1L]] <- data.frame(
    frames = n, file_mb = round(megabytes(file.size(path)), 2), seconds = round(stats::median(seconds), 3),
    per_second = round(n / stats::median(seconds)), object_mb = round(megabytes(object.size(movie)), 2),
    inputs_mb = round(megabytes(object.size(movie$inputs)), 2),
    bytes_per_state = as.numeric(object.size(movie$inputs)) / (n * 8), peak_mb = round(max(peak), 1)
  )
  print(rows[[length(rows)]], row.names = FALSE)
  rm(movie); unlink(path)
}
write.csv(do.call(rbind, rows), output, row.names = FALSE)
cat(R.version.string, "\n")
cat("replayr", as.character(packageVersion("replayr")), "\n")
