# Export digests of replayr's values for BizHawk input logs (BK2, TASPROJ, GBMV).
#
# Usage: Rscript export-bk2.R <output directory> <shard> <shards>
# Environment as for export-replayr.R.
#
# replayr lists every LogKey control of a recording in `source_controls`
# (name, type, port). For each control this script takes the values replayr
# holds for it and writes their MD5 digest and sum: bytes 0/1 for logical
# controls, little-endian int32 for numeric ones. Recordings with more than
# two million observations are read with read_bk2_chunks() and digested per
# chunk; the others are read whole. compare-bk2.py computes the same digests
# from the independent decoder.
args <- commandArgs(trailingOnly = TRUE)
out <- args[1]
shard <- as.integer(args[2])
shards <- as.integer(args[3])
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source_dir <- Sys.getenv("REPLAYR_SOURCE")
if (nzchar(source_dir)) pkgload::load_all(source_dir, quiet = TRUE) else library(replayr)
root <- Sys.getenv("REPLAYR_VALIDATION_ROOT")
manifest <- read.csv(Sys.getenv("REPLAYR_VALIDATION_MANIFEST"), fileEncoding = "UTF-8")
manifest <- manifest[!duplicated(manifest$sha256) &
  manifest$format %in% c("bk2", "tasproj", "gbmv"), ]
# REPLAYR_EXPORT_SAMPLE=<n> restricts a trial run to n recordings.
trial <- as.integer(Sys.getenv("REPLAYR_EXPORT_SAMPLE", "0"))
if (trial > 0L) {
  set.seed(451)
  manifest <- manifest[sample(nrow(manifest), min(trial, nrow(manifest))), ]
}
# Largest first, dealt round-robin, so the shards carry similar loads.
manifest <- manifest[order(-manifest$observations), ]
manifest <- manifest[(seq_len(nrow(manifest)) - 1L) %% shards == shard - 1L, ]

control_values <- function(movie, control) {
  if (control$port == 0L) return(system_channels(movie)[[control$name]])
  player <- match(control$port, movie$header$controllerPorts)
  if (is.na(player)) return(NULL)
  if (control$type != "logical") {
    # A numeric control is found by its LogKey label; its column has a key.
    channels <- analog_channels(movie, player)
    column <- match(control$name, channel_layout(movie, player)$name)
    if (is.na(column)) return(NULL)
    return(channels[, column])
  }
  if (!is.null(movie$source_inputs)) {
    column <- match(control$key, movie$source_layout$key)
    if (is.na(column)) return(NULL)
    return(movie$source_inputs[, player, column])
  }
  column <- match(control$key, movie$button_keys)
  if (!is.na(column)) return(movie$inputs[, player, column])
  # N64 logs can hold Boolean stick directions; replayr keeps them apart.
  held <- movie$stick_overrides[[player]]
  direction <- c(left_n = "up", left_s = "down", left_w = "left", left_e = "right")
  if (!is.null(held) && control$key %in% names(direction) &&
    direction[[control$key]] %in% colnames(held))
    return(held[, direction[[control$key]]])
  NULL
}
digest_block <- function(movie) {
  controls <- movie$source_controls
  if (is.null(controls)) {
    # A log with an empty LogKey is read as the standard NES layout and has
    # no control list; name its pad controls the way BizHawk names them.
    if (!identical(movie$header$logKeyFallback, "verified NES header and two 8-button ports"))
      stop("replayr lists no source controls for this recording")
    layout <- button_layout(movie)
    pads <- seq_len(n_players(movie))
    controls <- data.frame(
      name = paste0("P", rep(pads, each = nrow(layout)), " ", rep(layout$name, length(pads))),
      type = "logical", port = rep(pads, each = nrow(layout)),
      key = rep(layout$key, length(pads)), stringsAsFactors = FALSE)
    movie$header$controllerPorts <- pads
  }
  md5 <- character(nrow(controls))
  total <- numeric(nrow(controls))
  for (i in seq_len(nrow(controls))) {
    values <- control_values(movie, controls[i, ])
    if (is.null(values)) {
      md5[i] <- NA_character_
      total[i] <- NA_real_
    } else if (is.logical(values)) {
      md5[i] <- tools::md5sum(bytes = as.raw(values))
      total[i] <- sum(values)
    } else {
      md5[i] <- tools::md5sum(bytes = writeBin(as.integer(values), raw(),
        size = 4L, endian = "little"))
      total[i] <- sum(as.numeric(values), na.rm = TRUE)
    }
  }
  first <- movie$header$firstObservation
  list(first = if (is.null(first)) 1 else first, n = n_observations(movie),
    names = I(controls$name), types = I(controls$type), ports = I(controls$port),
    md5 = I(md5), total = I(total))
}

for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, ]
  target <- file.path(out, paste0(row$sha256, ".json"))
  if (file.exists(target)) next
  path <- file.path(root, row$relative_path)
  notes <- character()
  failure <- NULL
  blocks <- tryCatch(withCallingHandlers({
    if (row$observations > 2e6) {
      unname(unclass(read_bk2_chunks(path, digest_block, chunk_size = 1000000L)))
    } else {
      list(digest_block(read_movie(path)))
    }
  }, warning = function(w) {
    notes <<- c(notes, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) {
    failure <<- conditionMessage(e)
    list()
  })
  attributes(blocks) <- NULL
  jsonlite::write_json(list(sha256 = row$sha256, publication_id = row$publication_id,
    format = row$format, relative_path = row$relative_path,
    observations = sum(vapply(blocks, function(b) b$n, numeric(1))),
    warnings = I(notes), error = failure, blocks = blocks),
    target, auto_unbox = TRUE, null = "null", digits = NA)
  if (i %% 50L == 0L || i == nrow(manifest)) cat(shard, ":", i, "/", nrow(manifest), "\n")
}
