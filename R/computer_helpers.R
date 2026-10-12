# Readers for computer recordings keep source key identities separate from
# gamepad controls. KeySyms, PC scan codes, and Windows virtual keys are not
# interchangeable keyboard layouts.
.computer_number <- function(x, what, min = -Inf, max = Inf, whole = TRUE) {
  out <- suppressWarnings(as.numeric(x))
  if (anyNA(out) || any(!is.finite(out)) || any(out < min | out > max) ||
    (whole && any(out != trunc(out)))) stop("Invalid ", what, call. = FALSE)
  out
}
.computer_ini <- function(lines) {
  result <- list()
  section <- "General"
  for (line in lines) {
    line <- trimws(line)
    if (!nzchar(line) || startsWith(line, ";") || startsWith(line, "#")) next
    if (grepl("^\\[.*\\]$", line)) {
      section <- substr(line, 2L, nchar(line) - 1L)
      next
    }
    at <- regexpr("=", line, fixed = TRUE)
    if (at < 1L) next
    key <- trimws(substr(line, 1L, at - 1L))
    value <- trimws(substring(line, at + 1L))
    if (is.null(result[[section]])) result[[section]] <- list()
    result[[section]][[key]] <- value
  }
  result
}
.computer_tar_path <- function(x) {
  x <- sub("/$", "", sub("^(\\./)+", "", x))
  bits <- strsplit(x, "/", fixed = TRUE)[[1L]]
  if (!nzchar(x) || startsWith(x, "/") || grepl("[\\\\:\\x00-\\x1f]", x, perl = TRUE) ||
    any(bits %in% c("", ".", "..")))
    stop("Unsafe recording archive or include path: ", x, call. = FALSE)
  x
}
# Read tar members in memory: archive paths are never used for file writes.
.computer_tar_regular <- function(path, files = NULL) {
  con <- gzfile(path, "rb")
  on.exit(close(con), add = TRUE)
  bytes_read <- 0
  account <- function(n) {
    bytes_read <<- bytes_read + n
    if (bytes_read > 512 * 1024^2)
      stop("Recording tar archive exceeds 512 MiB after decompression", call. = FALSE)
  }
  take <- function(n) {
    account(n)
    x <- withCallingHandlers(readBin(con, "raw", n), warning = function(w)
      stop("Invalid recording compressed data: ", conditionMessage(w), call. = FALSE))
    if (length(x) != n) stop("Truncated recording tar archive", call. = FALSE)
    x
  }
  field <- function(x) {
    zero <- match(as.raw(0L), x, nomatch = length(x) + 1L)
    if (zero == 1L) return("")
    value <- rawToChar(x[seq_len(zero - 1L)])
    Encoding(value) <- "UTF-8"
    if (!validUTF8(value)) stop("Invalid UTF-8 recording member name", call. = FALSE)
    value
  }
  octal <- function(x) {
    text <- trimws(field(x))
    if (!nzchar(text)) return(0)
    if (!grepl("^[0-7]+$", text)) stop("Invalid recording tar numeric field", call. = FALSE)
    digits <- utf8ToInt(text) - 48L
    sum(digits * 8^rev(seq_along(digits) - 1L))
  }
  scripts <- list()
  metadata <- list()
  seen <- character()
  total <- 0
  repeat {
    block <- take(512L)
    if (all(block == as.raw(0L))) {
      if (any(take(512L) != as.raw(0L))) stop("Invalid recording tar terminator", call. = FALSE)
      repeat {
        rest <- withCallingHandlers(readBin(con, "raw", 65536L), warning = function(w)
          stop("Invalid recording compressed data: ", conditionMessage(w), call. = FALSE))
        if (!length(rest)) break
        account(length(rest))
        if (any(rest != as.raw(0L))) stop("Unexpected data after recording tar terminator", call. = FALSE)
      }
      break
    }
    check <- octal(block[149:156])
    copy <- block
    copy[149:156] <- as.raw(32L)
    if (sum(as.integer(copy)) != check) stop("Invalid recording tar header checksum", call. = FALSE)
    type <- as.integer(block[157L])
    size <- octal(block[125:136])
    name <- field(block[1:100])
    prefix <- field(block[346:500])
    if (nzchar(prefix)) name <- paste(prefix, name, sep = "/")
    name <- if (type == 53L && name %in% c(".", "./")) "." else .computer_tar_path(name)
    if (tolower(name) %in% seen) stop("Duplicate recording archive member: ", name, call. = FALSE)
    seen <- c(seen, tolower(name))
    if (length(seen) > 10000L) stop("Recording tar archive exceeds 10000 members", call. = FALSE)
    if (!type %in% c(0L, 48L, 53L))
      stop("Unsupported recording tar member type (links and extensions are not accepted): ", name, call. = FALSE)
    if (!is.finite(size) || size > 128 * 1024^2 || total + size > 512 * 1024^2)
      stop("recording archive exceeds the text size limit", call. = FALSE)
    if (type == 53L && size != 0) stop("Invalid recording tar directory size", call. = FALSE)
    data <- take(size)
    if (size %% 512) take(512 - size %% 512)
    total <- total + size
    metadata[[length(metadata) + 1L]] <- data.frame(
      member = name, size = size,
      type = if (type == 53L) "directory" else "file", stringsAsFactors = FALSE
    )
    if (type != 53L && (is.null(files) || name %in% files)) scripts[[name]] <- data
  }
  list(members = scripts, metadata = if (length(metadata)) do.call(rbind, metadata) else
    data.frame(member = character(), size = numeric(), type = character()))
}
# Selected members are decoded only after all tar headers have been checked.
.computer_tar_text <- function(path, files) {
  archive <- .computer_tar_regular(path, files = files)
  missing <- setdiff(files, names(archive$members))
  if (length(missing)) stop("Archive needs exactly one ", missing[1L], call. = FALSE)
  stats::setNames(lapply(files, function(name) {
    bytes <- archive$members[[name]]
    if (any(bytes == as.raw(0L))) stop("Archive text contains a NUL byte: ", name, call. = FALSE)
    text <- rawToChar(bytes)
    Encoding(text) <- "UTF-8"
    if (!validUTF8(text)) stop("Archive text is not UTF-8: ", name, call. = FALSE)
    text <- sub("^\ufeff", "", text)
    strsplit(gsub("\r\n", "\n", text, fixed = TRUE), "\n", fixed = TRUE)[[1L]]
  }), files)
}
.computer_count_note <- function(declared, actual, label) {
  if (!is.null(declared) && !is.na(declared) && declared != actual)
    warning(label, " declares ", declared, " observations but stores ", actual,
      "; all complete observations were retained",
      call. = FALSE
    )
}
