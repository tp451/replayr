# Read every distinct TASVideos recording once, one after another in one R
# session, and record the time each takes.
#
# Usage, from the folder validation of the repository, after retrieve-recordings.R:
#   Rscript scripts/timing-tasvideos.R [output, default tables/timing-tasvideos.csv] [formats]
# Environment: REPLAYR_VALIDATION_ROOT (folder with the recordings),
#   REPLAYR_VALIDATION_MANIFEST (default tables/validation-manifest.csv).
# With formats, comma separated, only the recordings of these formats are
# read, and their rows replace those of an existing output.
# A recording is read with the arguments of the validation manifest. BizHawk
# recordings of more than two million observations are passed through
# read_bk2_chunks(), as in the validation, because their whole input exceeds
# the default limit of read_movie(); the chunks are counted and discarded.
args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args) >= 1L) args[1] else "tables/timing-tasvideos.csv"
formats <- if (length(args) >= 2L) strsplit(args[2], ",", fixed = TRUE)[[1]] else NULL
suppressMessages(library(replayr))
root <- Sys.getenv("REPLAYR_VALIDATION_ROOT")
if (!nzchar(root) || !dir.exists(root)) stop("Set REPLAYR_VALIDATION_ROOT to the recording directory.")
manifest <- read.csv(Sys.getenv("REPLAYR_VALIDATION_MANIFEST", "tables/validation-manifest.csv"),
  fileEncoding = "UTF-8")
manifest <- manifest[!duplicated(manifest$sha256), ]
if (!is.null(formats)) manifest <- manifest[manifest$format %in% formats, ]
has_value <- function(x) length(x) == 1L && !is.na(x) && nzchar(x)
n <- nrow(manifest)
result <- data.frame(
  relative_path = manifest$relative_path, format = manifest$format,
  bytes = file.size(file.path(root, manifest$relative_path)),
  observations = NA_real_, seconds = NA_real_, object_bytes = NA_real_, how = NA_character_,
  stringsAsFactors = FALSE
)
started <- Sys.time()
for (i in seq_len(n)) {
  row <- manifest[i, ]
  call <- list(path = file.path(root, row$relative_path))
  if (has_value(row$game)) call$game <- row$game
  chunked <- row$format %in% c("bk2", "tasproj", "gbmv") && isTRUE(row$observations > 2e6)
  timing <- system.time(value <- tryCatch(suppressWarnings(
    if (chunked) read_bk2_chunks(call$path, function(chunk) n_observations(chunk), chunk_size = 1000000L)
    else do.call(read_movie, call)
  ), error = function(e) conditionMessage(e)))
  # Elapsed times are counted in hundredths of a second.
  result$seconds[i] <- round(timing[["elapsed"]], 2)
  if (is.character(value)) {
    result$how[i] <- paste("error:", substr(value, 1, 80))
  } else if (chunked) {
    result$how[i] <- "chunks"
    result$observations[i] <- sum(unlist(value))
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
wall_clock <- round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1)
if (!is.null(formats) && file.exists(output)) {
  earlier <- read.csv(output, stringsAsFactors = FALSE)
  at <- match(result$relative_path, earlier$relative_path)
  stopifnot(!anyNA(at), setequal(at, which(earlier$format %in% formats)))
  earlier[at, ] <- result
  result <- earlier
}
write.csv(result, output, row.names = FALSE)
read <- !grepl("^error", result$how)
cat("recordings:", nrow(result), " read:", sum(read), " not read:", sum(!read), "\n")
cat("observations:", format(sum(result$observations, na.rm = TRUE), big.mark = ","), "\n")
cat("time reading (sum of calls):", round(sum(result$seconds) / 60, 1), "min; wall clock of this run:",
  wall_clock, "min\n")
by <- aggregate(cbind(recordings = 1, observations, seconds) ~ format, result[read, ], sum)
by$per_second <- round(by$observations / by$seconds)
print(by[order(-by$seconds), ], row.names = FALSE)
print(table(result$how[!read]))
cat(R.version.string, "\n")
cat("replayr", as.character(packageVersion("replayr")), "\n")
