# Read the text after the input of every published FinalBurn recording, for
# comparison with a separate reading of the same bytes (fbm-text-compare.py).
# Usage: Rscript fbm-text-read.R <folder with .fbm files> <validation-manifest.csv> <result.csv>
# replayr comes from the library paths of the session (R_LIBS).
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(library(replayr))
manifest <- read.csv(args[2], fileEncoding = "UTF-8", stringsAsFactors = FALSE)
manifest <- manifest[manifest$format == "fbm", ]
rows <- lapply(seq_len(nrow(manifest)), function(i) {
  path <- file.path(args[1], basename(manifest$relative_path[i]))
  warned <- character()
  movie <- withCallingHandlers(read_fbm(path, game = manifest$game[i]), warning = function(w) {
    warned <<- c(warned, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  data.frame(file = basename(path), observations = n_observations(movie),
    metadata = if (is.null(movie$header$metadata)) NA_character_ else movie$header$metadata,
    tail = length(movie$source_tail), warnings = paste(warned, collapse = " | "), stringsAsFactors = FALSE)
})
result <- do.call(rbind, rows)
write.csv(result, args[3], row.names = FALSE, fileEncoding = "UTF-8")
cat("recordings:", nrow(result), " with a text:", sum(!is.na(result$metadata)), " with bytes kept:", sum(result$tail > 0),
  " with a warning:", sum(nzchar(result$warnings)), "\n")
print(utils::head(result[!is.na(result$metadata), c("file", "metadata")], 12), row.names = FALSE)
cat("longest text:", max(nchar(result$metadata), na.rm = TRUE), "characters; texts with characters outside ASCII:",
  sum(grepl("[^ -~]", result$metadata), na.rm = TRUE), "\n")
