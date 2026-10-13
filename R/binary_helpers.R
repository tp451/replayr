# Binary readers use zero-based file offsets. For example,
# .read_u32_le(data, 0x10) reads bytes at file offsets 0x10 through 0x13.
# Read a little-endian unsigned 32-bit int from `data` (raw vector) at the
# 0-based byte offset `off`. Returns an R integer (caveat: values >=
# 2^31 are returned as a numeric / double to avoid overflow).
.read_u32_le <- function(data, off) {
  if (off < 0L || off + 4L > length(data)) {
    stop("u32 read out of bounds (off=", off, ", length=", length(data), ")")
  }
  b <- as.integer(data[(off + 1L):(off + 4L)])
  v <- b[1L] + bitwShiftL(b[2L], 8L) + bitwShiftL(b[3L], 16L)
  # bitwShiftL on b[4L] could overflow R integer; do the high byte in
  # double precision and add.
  v <- v + as.numeric(b[4L]) * 16777216
  if (v <= .Machine$integer.max) as.integer(v) else v
}
# Read a little-endian unsigned 64-bit int from `data` at 0-based `off`.
# Returns a double; integer values up to 2^53 are represented exactly.
.read_u64_le <- function(data, off) {
  if (off < 0L || off + 8L > length(data)) {
    stop("u64 read out of bounds (off=", off, ", length=", length(data), ")")
  }
  b <- as.numeric(data[(off + 1L):(off + 8L)])
  v <- 0
  for (i in 0:7) v <- v + b[i + 1L] * (256^i)
  v
}
# Read a NUL-terminated (or NUL-padded, fixed-length) C string from `data`
# starting at 0-based `off`, of maximum length `len`. Trailing whitespace
# is trimmed. This helper interprets the bytes as Latin-1.
.read_cstring <- function(data, off, len) {
  if (off >= length(data)) return("")
  end <- min(length(data), off + len)
  chunk <- data[(off + 1L):end]
  nul_idx <- which(chunk == as.raw(0L))
  if (length(nul_idx) > 0L) chunk <- chunk[seq_len(nul_idx[1L] - 1L)]
  if (length(chunk) == 0L) return("")
  s <- rawToChar(chunk)
  # Mark the source encoding before converting to UTF-8.
  Encoding(s) <- "latin1"
  s <- enc2utf8(s)
  sub("[[:space:]]+$", "", s)
}
# Locate the first occurrence of the raw pattern `pat` inside `data`.
# Returns a 0-based offset, or NA_integer_ if not found.
.find_raw <- function(data, pat) {
  n <- length(pat)
  if (n == 0L || n > length(data)) return(NA_integer_)
  # Compare the full pattern only at positions matching its first byte.
  cand <- which(data[seq_len(length(data) - n + 1L)] == pat[1L])
  for (c0 in cand) {
    if (all(data[c0:(c0 + n - 1L)] == pat)) return(c0 - 1L)
  }
  NA_integer_
}
# Read a little-endian uint16 at 0-based offset `off` and return as integer.
.read_u16_le <- function(data, off) {
  as.integer(data[off + 1L]) + bitwShiftL(as.integer(data[off + 2L]), 8L)
}
# Signatures: a reader looks at the first bytes of a file before it decodes
# anything, so that a file of another format is refused by name and not
# decoded into an empty or meaningless recording.
.starts_with_bytes <- function(path, signature) {
  if (is.character(signature)) signature <- charToRaw(signature)
  identical(readBin(path, "raw", length(signature)), signature)
}
.is_zip_archive <- function(path) {
  # A local file header, or the end record of an archive without members.
  .starts_with_bytes(path, as.raw(c(0x50, 0x4b, 0x03, 0x04))) ||
    .starts_with_bytes(path, as.raw(c(0x50, 0x4b, 0x05, 0x06)))
}
.is_gzip_file <- function(path) .starts_with_bytes(path, as.raw(c(0x1f, 0x8b)))
# Every entry point is given one existing file. A wrong path is reported as
# such, and not as a failure to open a connection.
.check_recording_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path))
    stop("path must be one file path as a character string.", call. = FALSE)
  if (dir.exists(path)) stop("Not a file but a folder: ", path, call. = FALSE)
  if (!file.exists(path)) {
    # A relative path is looked up from the working directory.
    absolute <- grepl("^(/|~|[A-Za-z]:|\\\\\\\\)", path)
    stop("File not found: ", path, if (!absolute) paste0(" (working directory: ", getwd(), ")"), call. = FALSE)
  }
  invisible(path)
}
