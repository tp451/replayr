# Common wire-level helpers for the legacy console readers.
.legacy_header <- function(lines, format) {
  header <- list()
  for (line in lines[nzchar(lines)]) {
    pos <- regexpr("[[:space:]]", line)
    if (pos < 1L) stop("Malformed ", toupper(format), " header line: ", line)
    key <- substr(line, 1L, pos - 1L)
    value <- sub("^[[:space:]]+", "", substring(line, pos))
    if (is.null(header[[key]])) header[[key]] <- value
    else header[[key]] <- paste(header[[key]], value, sep = "\n")
  }
  header[["_format"]] <- format
  header
}

.legacy_text <- function(path, format) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  starts <- which(data == as.raw(124L))
  starts <- starts[starts == 1L | data[pmax(1L, starts - 1L)] %in% as.raw(c(10L, 13L))]
  start <- if (length(starts)) starts[1L] else length(data) + 1L
  head <- if (start > 1L) data[seq_len(start - 1L)] else raw()
  if (any(head == as.raw(0))) stop(path, ": binary data in text movie header")
  text <- rawToChar(head)
  text <- iconv(text, "UTF-8", "UTF-8", sub = "byte")
  header <- .legacy_header(strsplit(text, "\r\n|\n|\r")[[1L]], format)
  if (is.null(header$version)) stop(path, ": missing ", toupper(format), " version")
  body <- if (start <= length(data)) data[start:length(data)] else raw()
  list(header = header, body = body)
}

.legacy_rows <- function(body, format) {
  if (!length(body)) return(character())
  if (any(body == as.raw(0))) stop("Unexpected binary data in ", toupper(format), " text log")
  rows <- strsplit(rawToChar(body), "\r\n|\n|\r")[[1L]]
  rows <- rows[nzchar(rows)]
  if (any(!startsWith(rows, "|") | !endsWith(rows, "|"))) {
    stop("Malformed or truncated ", toupper(format), " input row")
  }
  rows
}

.legacy_fields <- function(rows, count, format) {
  if (!length(rows)) return(matrix(character(), 0L, count))
  fields <- strsplit(substring(rows, 2L, nchar(rows) - 1L), "|", fixed = TRUE)
  if (any(lengths(fields) != count)) stop("Unexpected number of ", toupper(format), " input fields")
  matrix(unlist(fields, use.names = FALSE), ncol = count, byrow = TRUE)
}

.legacy_commands <- function(values, format) {
  out <- suppressWarnings(as.integer(values))
  if (anyNA(out) || any(out < 0L)) stop("Invalid ", toupper(format), " command field")
  out
}

.legacy_bits <- function(words, bits) {
  out <- matrix(FALSE, length(words), length(bits))
  for (j in seq_along(bits)) out[, j] <- bitwAnd(words, bitwShiftL(1L, bits[j])) != 0L
  out
}

.legacy_chars <- function(values, width, format) {
  if (any(nchar(values, type = "bytes") != width)) stop("Wrong ", toupper(format), " controller record width")
  out <- matrix(FALSE, length(values), width)
  for (j in seq_len(width)) out[, j] <- !substr(values, j, j) %in% c(".", " ")
  out
}

# Famtasia format: https://tasvideos.org/EmulatorResources/Famtasia/FMV
.decode_fmv <- function(path) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 144L || !identical(data[1:4], as.raw(c(70, 77, 86, 26)))) stop(path, ": not an FMV file")
  flags <- as.integer(data[6L])
  ports <- which(.legacy_bits(flags, c(7L, 6L))[1L, ])
  fds <- bitwAnd(flags, 32L) != 0L
  width <- length(ports) + as.integer(fds)
  if (!length(ports)) stop(path, ": FMV has no enabled controller")
  body <- data[-seq_len(144L)]
  tail_size <- length(body) %% width
  tail <- if (tail_size) utils::tail(body, tail_size) else raw()
  if (tail_size) {
    warning(path, ": FMV ends with ", tail_size, " byte(s) of an incomplete frame; retaining them in source_tail", call. = FALSE)
    body <- utils::head(body, length(body) - tail_size)
  }
  packets <- matrix(as.integer(body), ncol = width, byrow = TRUE)
  keys <- c("dpad_right", "dpad_left", "dpad_up", "dpad_down", "b", "a", "select", "start")
  inputs <- array(FALSE, c(nrow(packets), length(ports), length(keys)))
  for (p in seq_along(ports)) inputs[, p, ] <- .legacy_bits(packets[, p], 0:7)
  header <- list(`_format` = "fmv", system = if (fds) "FDS" else "NES",
                 startsFromSavestate = bitwAnd(as.integer(data[5L]), 128L) != 0L,
                 controllerPorts = ports, rerecordCount = .read_u32_le(data, 10L),
                 emulator = .read_cstring(data, 16L, 64L), title = .read_cstring(data, 80L, 64L))
  commands <- if (fds) packets[, width] else integer(nrow(packets))
  header$commandEncoding <- if (fds) "Famtasia FDS control byte" else "none"
  movie <- .new_named_movie(header, commands, inputs, keys, path)
  movie$source_tail <- tail
  movie$source_packets <- packets
  movie
}
