# Compare what replayr reads from Gym Retro's BK2 files with the output of
# the separate decoder (gymretro-decode.py), and the number of observations
# with the number of steps that Gym Retro's own script counted.
# Usage: Rscript gymretro-compare.R <folder with recordings> <folder with the decoder's output>
#          <sources.csv> <get_states.results> <result.csv>
# replayr comes from the library paths of the session (R_LIBS).
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(library(replayr))
sources <- read.csv(args[3], fileEncoding = "UTF-8", stringsAsFactors = FALSE)
counted <- readLines(args[4], warn = FALSE)
# The script takes one step before it begins to count.
steps <- stats::setNames(
  as.integer(sub(" steps exist.*", "", grep("steps exist in the movie", counted, value = TRUE))) + 1L,
  sub("^processing ", "", grep("^processing ", counted, value = TRUE))
)
rows <- list()
for (path in list.files(args[1], pattern = "[.]bk2$", full.names = TRUE)) {
  name <- basename(path)
  movie <- read_bk2(path)
  other <- strsplit(readLines(file.path(args[2], paste0(name, ".txt")), warn = FALSE), "\t", fixed = TRUE)
  n <- n_observations(movie)
  differences <- if (length(other) != n) NA_integer_ else {
    system <- system_channels(movie)
    wrong <- sum(vapply(other, function(x) x[1L], character(1)) != ifelse(system$reset | system$power, "!", ".."))
    for (p in seq_len(n_players(movie))) {
      states <- player(movie, p)
      held <- vapply(seq_len(n), function(i) paste(sort(colnames(states)[states[i, ]]), collapse = " "), character(1))
      theirs <- vapply(other, function(x) if (length(x) > p) x[p + 1L] else "", character(1))
      wrong <- wrong + sum(held != theirs)
    }
    wrong
  }
  rows[[length(rows) + 1L]] <- data.frame(
    file = name, repository = sources$repository[match(name, sources$file)],
    url = sources$url[match(name, sources$file)], sha256 = sources$sha256[match(name, sources$file)],
    bytes = file.size(path), game = movie$header$GameName, platform = movie$header$Platform,
    observations = n, controllers = n_players(movie),
    gym_retro_steps = unname(steps[name]), button_values = n * n_players(movie) * n_buttons(movie),
    command_values = n * ncol(system_channels(movie)), differences = differences,
    status = if (identical(differences, 0) || identical(differences, 0L)) "agrees" else "DISAGREES",
    stringsAsFactors = FALSE
  )
}
result <- do.call(rbind, rows)
write.csv(result, args[5], row.names = FALSE, fileEncoding = "UTF-8")
with_steps <- result[!is.na(result$gym_retro_steps), ]
cat("recordings:", nrow(result), " agree:", sum(result$status == "agrees"), " observations:", sum(result$observations),
  " values:", sum(result$button_values, result$command_values), "\n")
cat("with a step count from Gym Retro:", nrow(with_steps), " equal to the observations:",
  sum(with_steps$gym_retro_steps == with_steps$observations), "\n")
print(table(result$game))
