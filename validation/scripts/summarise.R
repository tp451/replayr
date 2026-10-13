# Summarise the tables of the validation in one small table, summary.csv:
# one row for each number that the documentation and the article report.
# Before a number is written, the tables are checked for what the text says
# of them (every comparison agrees, no file is listed twice, and so on), so
# that the summary exists only where these statements hold.
#
# Usage, from the folder validation of the repository:
#   Rscript scripts/summarise.R [folder with the tables] [summary.csv]
# The defaults are tables and summary.csv.
args <- commandArgs(trailingOnly = TRUE)
tables <- if (length(args) >= 1L) args[1] else "tables"
output <- if (length(args) >= 2L) args[2] else "summary.csv"
table_of <- function(name) read.csv(file.path(tables, name), fileEncoding = "UTF-8", stringsAsFactors = FALSE)
present <- function(x) !is.na(x) & nzchar(x)
values_of <- function(x, columns) sum(vapply(columns, function(column) sum(as.numeric(x[[column]])), numeric(1)))
rows <- list()
add <- function(set, measure, value) {
  rows[[length(rows) + 1L]] <<- data.frame(set = set, measure = measure,
    value = format(value, scientific = FALSE, trim = TRUE, digits = 15), stringsAsFactors = FALSE)
}

# The publications of TASVideos: every distinct recording is read, and each
# is compared with a separate decoder.
listing <- jsonlite::fromJSON(file.path(tables, "validation-summary.json"))
manifest <- table_of("validation-manifest.csv")
corpus <- manifest[!duplicated(manifest$sha256), ]
compared <- table_of("independent-comparison.csv")
findings <- table_of("source-warning-findings.csv")
with_argument <- present(corpus$game) | present(corpus$wii_variant)
poll_streams <- corpus$representation == "replayr_poll_stream"
defective <- present(corpus$warnings)
file_defects <- findings[present(findings$remaining_warning), ]
stopifnot(
  nrow(corpus) == listing$distinct_file_hashes, all(corpus$status == "ok"),
  all(compared$status == "agrees"), setequal(compared$sha256, corpus$sha256),
  # Only FinalBurn recordings need an argument: the game, which the file does not name.
  identical(with_argument, corpus$format == "fbm"),
  # A defective file is one whose warning the audit traced to the file itself.
  setequal(file_defects$sha256, corpus$sha256[defective]),
  !any(file_defects$classification %in% c("library_bug", "valid_variant"))
)
add("tasvideos", "recordings", nrow(corpus))
add("tasvideos", "extensions", paste(sort(unique(corpus$format)), collapse = " "))
add("tasvideos", "read_with_an_argument", sum(with_argument))
add("tasvideos", "poll_streams", sum(poll_streams))
add("tasvideos", "extensions_of_poll_streams", paste(sort(unique(corpus$format[poll_streams])), collapse = " "))
add("tasvideos", "defective_files", sum(defective))
add("tasvideos", "compared_recordings", nrow(compared))
add("tasvideos", "compared_values", values_of(compared, c("button_values", "numeric_values", "command_values")))
add("tasvideos", "compared_lmp_recordings", sum(compared$format == "lmp"))

# Doom-engine demos of the Doom Speed Demos Archive.
doom <- table_of("doom-family-comparison.csv")
stopifnot(all(doom$status == "agrees"), !anyDuplicated(doom$sha256))
add("doom", "demos", nrow(doom))
add("doom", "observations", sum(doom$observations))
add("doom", "values", values_of(doom, c("button_values", "numeric_values", "command_values")))

# GoldSrc demos: files that both readers refuse are listed, and are either
# broken on purpose by a parser's tests or of demo protocol 4.
goldsrc <- table_of("goldsrc-comparison.csv")
read <- goldsrc[goldsrc$status == "agrees", ]
key_actions <- table_of("goldsrc-key-actions.csv")
key_actions <- key_actions[key_actions$observations > 0, ]
stopifnot(all(goldsrc$status %in% c("agrees", "refused by both")), !anyDuplicated(goldsrc$sha256))
add("goldsrc", "demos", nrow(read))
add("goldsrc", "observations", sum(read$observations))
add("goldsrc", "values", values_of(read, c("button_values", "numeric_values", "command_values")))
add("goldsrc", "without_player_commands", sum(grepl("no commands of a player", read$warnings)))
add("goldsrc", "refused", sum(goldsrc$status == "refused by both"))
add("goldsrc", "demos_with_key_actions", key_actions$demos_with_key_actions[1L])
add("goldsrc", "actions_with_key_actions", nrow(key_actions))
add("goldsrc", "least_key_action_agreement", min(key_actions$agreement))
add("goldsrc", "greatest_key_action_agreement", max(key_actions$agreement))

# Recordings of Gym Retro: the demonstrations have the number of steps that
# Gym Retro itself counted.
gymretro <- table_of("gymretro-comparison.csv")
demonstrations <- gymretro[!is.na(gymretro$gym_retro_steps), ]
stopifnot(all(gymretro$status == "agrees"), !anyDuplicated(gymretro$sha256),
  all(demonstrations$gym_retro_steps == demonstrations$observations))
add("gymretro", "recordings", nrow(gymretro))
add("gymretro", "demonstrations", nrow(demonstrations))
add("gymretro", "values", values_of(gymretro, c("button_values", "command_values")))

# The tables of the two Atari data sets: every trial of Atari-HEAD has the
# number of frames and the play time that the data set lists for it.
atari <- table_of("atari-comparison.csv")
head_trials <- atari[atari$data_set == "Atari-HEAD", ]
stopifnot(all(atari$differences == 0), all(head_trials$equal_to_listing == head_trials$tables))
add("atari", "grand_challenge_tables", sum(atari$tables) - sum(head_trials$tables))
add("atari", "head_tables", sum(head_trials$tables))
add("atari", "values", sum(atari$values))

# The text of the author in FinalBurn recordings.
texts <- table_of("fbm-text-comparison.csv")
stopifnot(all(texts$status == "agrees"))
add("fbm", "recordings", nrow(texts))
add("fbm", "recordings_with_a_text", sum(present(texts$text)))

summary <- do.call(rbind, rows)
write.csv(summary, output, row.names = FALSE, fileEncoding = "UTF-8")
print(summary, row.names = FALSE)
