# Compare what replayr reads from GoldSrc demos with the output of the
# separate decoder (goldsrc-decode.py), value by value. The result names
# each demo by its source: a repository with its revision, or a collection
# of the Internet Archive with the file and the member it was taken from.
# Usage: Rscript goldsrc-compare.R <folder with demos> <folder with the decoder's output>
#          <sources.csv> <result.csv>
# replayr comes from the library paths of the session (R_LIBS).
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(library(replayr))
sources <- read.csv(args[3], fileEncoding = "UTF-8", stringsAsFactors = FALSE)
actions <- c("attack", "jump", "duck", "forward", "back", "use", "cancel", "turn_left", "turn_right",
  "move_left", "move_right", "attack2", "run", "reload", "alt1", "score")
rows <- list()
for (path in list.files(args[1], pattern = "[.]dem$", full.names = TRUE)) {
  name <- basename(path)
  refused <- file.exists(file.path(args[2], paste0(name, ".error")))
  warned <- character()
  movie <- tryCatch(withCallingHandlers(read_dem(path), warning = function(w) {
    warned <<- c(warned, sub("^[^:]*: ", "", conditionMessage(w)))
    invokeRestart("muffleWarning")
  }), error = function(e) NULL)
  listed <- match(name, sources$file)
  entry <- data.frame(
    file = name, source = sources$source[listed], container = sources$container[listed],
    member = sources$member[listed], url = sources$url[listed], sha256 = sources$sha256[listed],
    bytes = file.size(path), game = NA_character_, map = NA_character_, network_protocol = NA_integer_,
    player_commands = NA, observations = NA_integer_, seconds = NA_real_, button_values = 0, numeric_values = 0,
    command_values = 0, warnings = paste(warned, collapse = " | "), differences = NA_integer_,
    status = NA_character_, stringsAsFactors = FALSE
  )
  if (!refused && !file.exists(file.path(args[2], paste0(name, ".csv")))) {
    entry$status <- "not decoded separately"
    rows[[length(rows) + 1L]] <- entry
    next
  }
  if (is.null(movie) || refused) {
    # A file that is not a complete demo must be refused by both.
    entry$status <- if (is.null(movie) && refused) "refused by both" else "DISAGREES on refusal"
    rows[[length(rows) + 1L]] <- entry
    next
  }
  other <- read.csv(file.path(args[2], paste0(name, ".csv")), stringsAsFactors = FALSE)
  spoken <- jsonlite::fromJSON(file.path(args[2], paste0(name, ".commands.json")), simplifyVector = FALSE)
  n <- n_observations(movie)
  states <- player(movie)
  channels <- analog_channels(movie)
  differences <- if (nrow(other) != n) NA_integer_ else {
    held <- vapply(seq_along(actions), function(bit) bitwAnd(other$buttons, bitwShiftL(1L, bit - 1L)) != 0L, logical(n))
    sum(unname(states[, paste0("action_", actions), drop = FALSE]) != matrix(held, nrow = n)) +
      sum(vapply(colnames(channels), function(key) sum(channels[, key] != other[[key]]), numeric(1))) +
      sum(movie$timing$section != other$section) + sum(movie$timing$section_seconds != other$seconds) +
      sum(movie$timing$frame != other$frame) + sum(movie$timing$start_frame != (other$start == 1L))
  }
  commands <- movie$console_commands
  command_differences <- if (nrow(commands) != length(spoken)) NA_integer_ else if (!length(spoken)) 0L else {
    sum(commands$section != vapply(spoken, function(x) x[[1L]], numeric(1))) +
      sum(commands$section_seconds != as.numeric(vapply(spoken, function(x) x[[2L]], character(1)))) +
      sum(commands$frame != vapply(spoken, function(x) x[[3L]], numeric(1))) +
      sum(commands$command != vapply(spoken, function(x) x[[4L]], character(1)))
  }
  entry$game <- movie$header$gameDir
  entry$map <- movie$header$mapName
  entry$network_protocol <- movie$header$networkProtocol
  entry$player_commands <- movie$header$playerCommands
  entry$observations <- n
  entry$seconds <- round(recording_info(movie)$duration, 3)
  entry$button_values <- n * length(actions)
  entry$numeric_values <- n * (ncol(channels) + 4L)
  entry$command_values <- nrow(commands) * 4L
  entry$differences <- differences + command_differences
  entry$status <- if (identical(entry$differences, 0L) || identical(entry$differences, 0)) "agrees" else "DISAGREES"
  rows[[length(rows) + 1L]] <- entry
}
result <- do.call(rbind, rows)
# A demo is listed by where it comes from; the name it has in the folder
# stands in where the source gives no member.
listed <- match(result$file, sources$file)
result$revision <- sources$revision[listed]
result$licence <- sources$licence[listed]
result$member <- ifelse(is.na(result$member) | !nzchar(result$member), result$file, result$member)
columns <- c("source", "revision", "container", "member", "licence", "sha256", "bytes", "game", "map",
  "network_protocol", "player_commands", "observations", "seconds", "button_values", "numeric_values",
  "command_values", "warnings", "differences", "status")
write.csv(result[columns], args[4], row.names = FALSE, fileEncoding = "UTF-8", na = "", quote = TRUE)
read <- result[!is.na(result$observations), ]
print(as.data.frame(table(source = result$source, status = result$status)), row.names = FALSE)
print(table(game = read$game, network_protocol = read$network_protocol))
print(table(warnings = substr(gsub("[0-9]+ section", "N section", read$warnings[nzchar(read$warnings)]), 1L, 120L)))
cat("demos read:", nrow(read), " observations:", sum(read$observations), " values:",
  sum(read$button_values, read$numeric_values, read$command_values), " refused by both:",
  sum(result$status == "refused by both"), "\n")
