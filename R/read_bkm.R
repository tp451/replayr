# Legacy BizHawk text movies. Wire order is specified by BizHawk's
# movie/import/bkm/BkmMnemonicConstants.cs and BkmControllerAdapter.cs.
# In BKM, unlike BK2, axes follow the Boolean buttons. The last axis is
# terminated by the group delimiter rather than a comma.
.decode_bkm <- function(path) {
  # A BizHawk text movie is a header of key and value lines that names its
  # platform, followed by the input rows.
  start <- readBin(path, "raw", min(file.info(path)$size, 65536L))
  if (any(start == as.raw(0L)) || !grepl("(^|\n)Platform ", rawToChar(start), useBytes = TRUE))
    stop(path, ": not a BizHawk BKM or TAS text movie: its header has no Platform line", call. = FALSE)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- sub("\r+$", "", lines)
  header <- list("_format" = "bkm")
  rows <- lines[startsWith(lines, "|")]
  for (line in lines[!startsWith(lines, "|")]) {
    if (!nzchar(line)) next
    key <- sub(" .*$", "", line)
    value <- sub("^[^ ]+ ?", "", line)
    header[[key]] <- if (is.null(header[[key]])) value else paste(header[[key]], value, sep = "\n")
  }
  original <- toupper(header$Platform %||% "")
  platform <- switch(original,
    A2600 = "A26",
    A7800 = "A78",
    GENESIS = "GEN",
    SATURN = "SAT",
    GBC = "GB",
    GG = "SMS",
    SG = "SMS",
    SG1000 = "SMS",
    original
  )
  header$sourcePlatform <- header$Platform
  header$Platform <- platform
  orders <- list(
    GB = c("Up", "Down", "Left", "Right", "Select", "Start", "B", "A"),
    GBA = c("Up", "Down", "Left", "Right", "Select", "Start", "B", "A", "L", "R"),
    GEN = c("Up", "Down", "Left", "Right", "A", "B", "C", "Start", "X", "Y", "Z", "Mode"),
    NES = c("Up", "Down", "Left", "Right", "Select", "Start", "B", "A"),
    SNES = c("Up", "Down", "Left", "Right", "Select", "Start", "B", "A", "X", "Y", "L", "R"),
    PCE = c("Up", "Down", "Left", "Right", "Select", "Run", "B2", "B1"),
    SMS = c("Up", "Down", "Left", "Right", "B1", "B2"),
    A26 = c("Up", "Down", "Left", "Right", "Button"),
    A78 = c("Up", "Down", "Left", "Right", "Trigger", "Trigger 2"),
    COLECO = c("Up", "Down", "Left", "Right", "L", "R", paste0("Key", 1:9), "Star", "Key0", "Pound"),
    N64 = c("DPad U", "DPad D", "DPad L", "DPad R", "B", "A", "Z", "Start", "L", "R", "C Up", "C Down", "C Left",
      "C Right", "X Axis", "Y Axis"),
    SAT = c("Up", "Down", "Left", "Right", "Start", "X", "Y", "Z", "A", "B", "C", "L", "R"),
    DGB = c("Power", "Up", "Down", "Left", "Right", "Select", "Start", "B", "A"),
    WSWAN = c("X1", "X3", "X4", "X2", "Y1", "Y3", "Y4", "Y2", "Start", "B", "A"),
    TI83 = c(as.character(0:9), "DOT", "ON", "ENTER", "UP", "DOWN", "LEFT", "RIGHT", "PLUS", "MINUS", "MULTIPLY",
      "DIVIDE", "CLEAR", "EXP", "DASH", "PARAOPEN", "PARACLOSE", "TAN", "VARS", "COS", "PRGM", "STAT", "MATRIX", "X",
      "STO", "LN", "LOG", "SQUARED", "NEG1", "MATH", "ALPHA", "GRAPH", "TRACE", "ZOOM", "WINDOW", "Y", "2ND", "MODE")
  )
  order <- orders[[platform]]
  if (is.null(order)) stop("Unsupported legacy BizHawk platform: ", original)
  if (!length(rows)) stop("Legacy BizHawk movie contains no input rows")
  # The emulator consumes its fixed controller fields and ignores text after
  # the last delimiter (older editor exports can append a marker such as *).
  trailing <- sub("^.*\\|", "", rows)
  rows <- sub("\\|[^|]*$", "|", rows)
  # Empty groups at the end are emitted by some historical Genesis writers.
  # A row is split between its first pipe and its closing pipes.
  parts <- strsplit(sub("[|]+$", "", substring(rows, 2L)), "|", fixed = TRUE)
  counts <- lengths(parts)
  if (length(unique(counts)) != 1L) stop("BKM controller group count changes between samples")
  groups <- lapply(seq_len(counts[1L]), function(i) vapply(parts, `[[`, character(1), i))
  command_names <- character()
  command_rows <- rep("", length(rows))
  if (platform %in% c("GB", "GBA", "GEN", "NES", "SNES", "PCE", "N64", "SAT")) {
    command <- groups[[1L]]
    groups <- groups[-1L]
    if (any(nchar(command) != 1L)) stop("Invalid BKM command field")
    if (platform == "PCE") {
      if (any(command != ".")) stop("Unexpected active BKM PC Engine command")
    } else {
      command_names <- c("Power", "Reset")
      chars <- c("P", "r")
      if (platform == "NES") {
        command_names <- c(command_names, "FDS Eject", paste("FDS Insert", 0:3), "VS Coin 1", "VS Coin 2")
        chars <- c(chars, "E", as.character(0:3), "c", "C")
      }
      if (any(!command %in% c(".", chars))) stop("Unknown BKM command character")
      command_rows <- do.call(paste0, lapply(chars, function(ch) ifelse(command == ch, "!", ".")))
    }
  } else if (platform %in% c("SMS", "WSWAN")) {
    command_rows <- groups[[length(groups)]]
    groups <- head(groups, -1L)
    command_names <- if (platform == "SMS") c("Pause", "Reset") else c("Power", "Rotate")
    if (any(nchar(command_rows) != 2L)) stop("Invalid trailing BKM system controls")
  } else if (platform %in% c("A26", "A78")) {
    command_rows <- groups[[1L]]
    groups <- groups[-1L]
    command_names <- if (platform == "A26") c("Reset", "Select") else c("Power", "Reset", "Select", "Pause")
    if (any(nchar(command_rows) != length(command_names))) stop("Invalid BKM system controls")
  }
  if (!length(groups)) stop("BKM movie has no controller group")
  maximum <- switch(platform,
    NES = 4L,
    SNES = 4L,
    N64 = 4L,
    PCE = 5L,
    GB = 1L,
    GBA = 1L,
    TI83 = 1L,
    2L
  )
  if (length(groups) > maximum) stop("Too many BKM controller groups for ", original)
  # BizHawk 1.4.1 indexes Game Boy buttons at fixed character offsets.
  # Its final delimiter therefore becomes an active A button in a row with
  # seven button characters. Reproduce that documented historical behaviour;
  # newer importers skip delimiters and reject such a truncated record.
  if (platform == "GB" && grepl("(^| )1\\.4\\.1$", header$emuVersion %||% "")) {
    short <- which(nchar(groups[[1L]]) == 7L)
    if (length(short)) {
      groups[[1L]][short] <- paste0(groups[[1L]][short], "!")
      header$legacyDelimiterButtonSamples <- short
    }
  }
  for (p in seq_along(groups)) {
    if (platform == "N64") {
      if (any(!grepl("^.{14}[[:space:]]*[+-]?[0-9]+,[[:space:]]*[+-]?[0-9]+$", groups[[p]])))
        stop("Invalid BKM N64 stick record")
      groups[[p]] <- paste0(groups[[p]], ",")
    } else if (any(nchar(groups[[p]]) != length(order))) {
      stop("BKM button count disagrees with ", original, " controller definition")
    }
  }
  key_groups <- lapply(seq_along(groups),
    function(p) paste0("#", paste(paste0("P", p, " ", order), collapse = "|"), "|"))
  if (length(command_names)) {
    key_groups <- c(list(paste0("#", paste(command_names, collapse = "|"), "|")), key_groups)
    groups <- c(list(command_rows), groups)
  }
  logkey <- paste0("LogKey:", paste0(key_groups, collapse = ""))
  normalized <- paste0("|", do.call(paste, c(groups, sep = "|")), "|")
  movie <- .bk2_named_log(normalized, logkey, header)
  movie$source_path <- path
  if (any(nzchar(trailing))) {
    movie$source_trailing <- trailing
    movie$header$unconsumedTrailingSamples <- sum(nzchar(trailing))
  }
  if (platform == "N64") {
    movie$stick_calibration <- lapply(seq_len(dim(movie$inputs)[2L]), function(p) {
      list(left = list(
        x = paste0("P", p, " X Axis"), y = paste0("P", p, " Y Axis"),
        center = c(0, 0), scale = c(128, 128), sign = c(1, 1)
      ))
    })
  }
  movie
}
.decode_tas <- function(path) {
  movie <- .decode_bkm(path)
  movie$header[["_format"]] <- "tas"
  movie
}
