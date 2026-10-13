# FCEUX .fm2 movie format. Reference: https://fceux.com/web/FM2.html
#
# An .fm2 file has two parts:
#
# 1. Header. ASCII text. Each line is a `key value` pair separated by the
#    first whitespace. Multi-valued keys (`comment`, `subtitle`) are
#    joined with newlines.
#
# 2. Input log. Every line that starts with `|` is a frame record:
#         |<commands>|<RLDUTSBA>|<RLDUTSBA>||
#    Each gamepad column has 8 character positions; position i is held
#    unless it shows `.` or a space. By convention it shows the mnemonic.
#
# Button column order is RLDUTSBA -- Right, Left, Down, Up, sTart, Select,
# B, A. These occupy private decoder slots 1..8.
# Canonical NES button column order. Single-letter mnemonics indexed
# positionally to match FM2 column character positions.
.NES_BUTTONS <- c("R", "L", "D", "U", "T", "S", "B", "A")
# A gamepad field has eight positions. A position is pressed unless its
# character is `.` or a space, as the FM2 specification states and FCEUX's
# MovieRecord::parseJoy reads it. The mnemonic letter is a convention: a
# hand-edited row can hold another one. A shorter field is filled with `.`.
# Decode FM2 text into the private NES slots. Header and input parsing
# are separate so text records can also be read from FM3 projects.
# FCEUX itself loads a movie only if the file begins with "version 3".
.require_fceux_signature <- function(path, format) {
  if (!.starts_with_bytes(path, "version 3"))
    stop(path, ": not an ", toupper(format), " file: an FCEUX movie begins with \"version 3\"", call. = FALSE)
}
.decode_fm2 <- function(path) {
  .require_fceux_signature(path, "fm2")
  probe <- readBin(path, "raw", min(file.info(path)$size, 65536L))
  delimiters <- which(probe == as.raw(124L))
  if (length(delimiters)) probe <- head(probe, delimiters[1L] - 1L)
  if (!any(probe == as.raw(0L))) {
    text_header <- rawToChar(probe)
    if (grepl("(^|\\n)binary +1|(^|\\n)port[01] +2", text_header, useBytes = TRUE))
      return(.decode_fceux_extended(path, "fm2"))
  }
  text <- readLines(path, warn = FALSE, encoding = "UTF-8")
  # Some headers contain non-UTF-8 bytes in metadata such as ROM filenames.
  # Re-decode only invalid lines as Latin-1; valid UTF-8 metadata is unchanged.
  invalid <- is.na(iconv(text, from = "UTF-8", to = "UTF-8"))
  if (any(invalid)) {
    text[invalid] <- iconv(text[invalid], from = "latin1", to = "UTF-8")
  }
  mv <- .parse_fm2_text(text)
  mv$source_path <- path
  mv
}
# Body of the .fm2 parser: works on a character vector of lines so the
# tests can hit the parser without touching the filesystem.
.parse_fm2_text <- function(lines) {
  header <- list()
  lines <- sub("[\r\n]+$", "", lines)
  lines <- lines[nzchar(lines)]
  is_record <- startsWith(lines, "|")
  for (line in lines[!is_record]) {
    stripped <- sub("^[[:space:]]+", "", line)
    if (!nzchar(stripped)) next
    idx <- regexpr("[ \t]", stripped)
    if (idx[1L] == -1L) {
      key <- stripped
      value <- ""
    } else {
      key <- substr(stripped, 1L, idx[1L] - 1L)
      value <- substr(stripped, idx[1L] + 1L, nchar(stripped))
    }
    if (!is.null(header[[key]])) {
      header[[key]] <- paste(header[[key]], value, sep = "\n")
    } else {
      header[[key]] <- value
    }
  }
  # A record is the text between its first pipe and its closing pipes; a
  # line of pipes alone is no record. All records are split at once.
  body <- sub("[|]+$", "", substring(lines[is_record], 2L))
  parts <- strsplit(body[nzchar(body)], "|", fixed = TRUE)
  n_frames <- length(parts)
  cmd_list <- suppressWarnings(as.integer(vapply(parts, `[`, "", 1L)))
  cmd_list[is.na(cmd_list)] <- 0L
  # The first record sets the number of gamepad fields; a record with fewer
  # is filled with released fields and one with more is cut, so that the
  # array stays rectangular even with malformed lines.
  counts <- lengths(parts) - 1L
  n_players_seen <- if (n_frames) counts[1L] else NA_integer_
  field <- function(j) {
    out <- rep(strrep(".", 8L), n_frames)
    present <- counts >= j
    out[present] <- vapply(parts[present], `[`, "", j + 1L)
    out
  }
  # Controllers follow the port declarations, as FCEUX reads them: a port
  # declared empty has an empty field and is no controller.
  fields <- seq_len(if (is.na(n_players_seen)) 0L else n_players_seen)
  if (!is.na(n_players_seen) && !identical(header$fourscore, "1")) {
    declared <- suppressWarnings(as.integer(c(header$port0 %||% NA, header$port1 %||% NA)))
    keep <- setdiff(fields, which(declared == 0L))
    if (!anyNA(declared) && length(keep)) {
      if (length(keep) < n_players_seen) {
        fields <- keep
        n_players_seen <- length(keep)
      }
      header$controllerPorts <- keep
    }
  }
  n_players <- if (is.na(n_players_seen)) 1L else n_players_seen
  inputs <- .empty_inputs(n_frames, n_players, 8L)
  if (n_frames > 0L) {
    for (pi in seq_along(fields)) {
      column <- substr(paste0(field(fields[pi]), strrep(".", 8L)), 1L, 8L)
      for (position in 1:8) {
        inputs[, pi, position] <- !substr(column, position, position) %in% c(".", " ")
      }
    }
  }
  commands <- cmd_list[seq_len(n_frames)]
  .new_movie(
    header = header, commands = commands, inputs = inputs,
    button_mnemonics = .NES_BUTTONS,
    button_names = c(
      "Right", "Left", "Down", "Up",
      "Start", "Select", "B", "A"
    )
  )
}
