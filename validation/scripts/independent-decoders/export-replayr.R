# Export replayr's imported values for comparison with independent decoders.
#
# Usage: Rscript export-replayr.R <formats, comma separated> <output directory>
# Environment: REPLAYR_VALIDATION_ROOT (recording directory),
#   REPLAYR_VALIDATION_MANIFEST (validation-manifest.csv),
#   REPLAYR_SOURCE (optional package source to load in place of the installed
#   package).
#
# For each distinct recording, <sha256>.json describes the layout and
# <sha256>.bin holds, in order: one n x k byte matrix of button states per
# controller, one n x c float64 matrix of numeric channels per controller,
# n int32 command values, one n x s float64 matrix of system channels, one
# n x t float64 matrix of timing columns, one n x u float64 matrix of the
# subframe table, and one float64 matrix of the numeric and logical columns
# of the per-poll fields and of the event table. Matrices are stored column by column. Per-observation
# flag strings are listed in the description for the observations where they
# are not empty.
args <- commandArgs(trailingOnly = TRUE)
formats <- strsplit(args[1], ",", fixed = TRUE)[[1]]
out <- args[2]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source_dir <- Sys.getenv("REPLAYR_SOURCE")
if (nzchar(source_dir)) pkgload::load_all(source_dir, quiet = TRUE) else library(replayr)
root <- Sys.getenv("REPLAYR_VALIDATION_ROOT")
manifest <- read.csv(Sys.getenv("REPLAYR_VALIDATION_MANIFEST"), fileEncoding = "UTF-8")
manifest <- manifest[!duplicated(manifest$sha256) & manifest$format %in% formats, ]
has_value <- function(x) length(x) == 1L && !is.na(x) && nzchar(x)
# Doom keeps weapon, artifact and extended commands as tic x player matrices
# in the header; they are exported with the numeric channels.
header_channels <- function(movie, p) {
  if (!identical(movie$header[["_format"]], "lmp")) return(NULL)
  h <- movie$header
  x <- h$extendedCommands
  parts <- list(
    weaponselect = h$weaponselect, has_special = h$has_special,
    artifact = h$artifact, suicide = h$suicide, excmd_actions = x$actions,
    excmd_save_slot = x$saveSlot, excmd_load_slot = x$loadSlot, excmd_look = x$look
  )
  parts <- parts[!vapply(parts, is.null, logical(1))]
  do.call(cbind, lapply(parts, function(m) as.numeric(m[, p])))
}
write_columns <- function(frame, con) {
  for (column in names(frame)) {
    writeBin(as.double(frame[[column]]), con, size = 8L, endian = "little")
  }
}

for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, ]
  stem <- file.path(out, row$sha256)
  if (file.exists(paste0(stem, ".json"))) next
  arguments <- list(path = file.path(root, row$relative_path))
  if (has_value(row$game)) arguments$game <- row$game
  if ("longtics" %in% names(row) && has_value(row$longtics)) arguments$longtics <- as.logical(row$longtics)
  notes <- character()
  movie <- withCallingHandlers(do.call(read_movie, arguments), warning = function(w) {
    notes <<- c(notes, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  layout <- button_layout(movie)
  assigned <- inherits(movie, "replayr_movie")
  players <- if (assigned) n_players(movie) else 1L
  system <- system_channels(movie)
  timing <- if (is.data.frame(movie$timing)) movie$timing else data.frame()
  subframes <- if (is.data.frame(movie$subframes)) movie$subframes else data.frame()
  poll_fields <- if (is.data.frame(movie$poll_fields)) movie$poll_fields else data.frame()
  poll_fields <- poll_fields[vapply(poll_fields, function(x) is.numeric(x) || is.logical(x), logical(1))]
  events <- if (is.data.frame(movie$events)) movie$events else data.frame()
  events <- events[vapply(events, function(x) is.numeric(x) || is.logical(x), logical(1))]
  flags <- if (is.character(movie$flags)) movie$flags else character()
  con <- file(paste0(stem, ".bin"), "wb")
  channels <- vector("list", players)
  for (p in seq_len(players)) {
    states <- if (assigned) player(movie, p) else
      matrix(movie$inputs[, 1L, ], nrow = n_observations(movie))
    writeBin(as.raw(states), con)
  }
  for (p in seq_len(players)) {
    # The decoders name a numeric field as its format does, so the fields are
    # exported under the names of their reader. analog_channels() returns the
    # same matrix under shared keys, which is checked for every recording.
    numeric <- replayr:::.source_channels(movie, p)
    stopifnot(
      identical(unname(numeric), unname(analog_channels(movie, p))),
      identical(as.character(colnames(analog_channels(movie, p))), channel_layout(movie, p)$key)
    )
    extra <- header_channels(movie, p)
    if (!is.null(extra)) numeric <- cbind(numeric, extra)
    channels[p] <- list(as.character(colnames(numeric)))
    writeBin(as.double(numeric), con, size = 8L, endian = "little")
  }
  writeBin(as.integer(movie$commands), con, size = 4L, endian = "little")
  write_columns(system, con)
  write_columns(timing, con)
  write_columns(subframes, con)
  write_columns(poll_fields, con)
  write_columns(events, con)
  close(con)
  flagged <- which(nzchar(flags))
  jsonlite::write_json(list(
    sha256 = row$sha256, publication_id = row$publication_id, format = row$format,
    relative_path = row$relative_path, class = class(movie)[1L],
    arguments = arguments[-1L],
    controllers = I(as.character(movie$header$controllers)),
    n = n_observations(movie), players = players, keys = I(layout$key),
    names = I(layout$name), channels = lapply(channels, I), warnings = I(notes),
    system = I(names(system)), timing = I(names(timing)),
    subframes = I(names(subframes)), poll_fields = I(names(poll_fields)),
    poll_rows = nrow(poll_fields),
    events = I(names(events)), event_rows = nrow(events),
    flag_rows = I(flagged), flag_values = I(flags[flagged]),
    header = movie$header[vapply(movie$header, function(x) is.atomic(x) && length(x) == 1L, logical(1))]
  ), paste0(stem, ".json"), auto_unbox = TRUE, null = "null", digits = NA)
  if (i %% 25L == 0L || i == nrow(manifest)) cat(i, "/", nrow(manifest), "\n")
}
