# Helpers shared by the binary parsers (.fcm, .gmv, .vbm, .m64, .smv,
# .pxm, .dtm). All offsets here are 0-based to mirror how the Python
# reference parser indexes byte arrays -- `.read_u32_le(data, 0x10)` reads
# the four bytes at file offset 0x10..0x13.

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
# Returns a numeric (double) -- exact for the file-size scales we deal
# with (DTM input counts are < 2^53).
.read_u64_le <- function(data, off) {
  if (off < 0L || off + 8L > length(data)) {
    stop("u64 read out of bounds (off=", off, ", length=", length(data), ")")
  }
  b <- as.numeric(data[(off + 1L):(off + 8L)])
  v <- 0
  for (i in 0:7) v <- v + b[i + 1L] * (256 ^ i)
  v
}

# Read a NUL-terminated (or NUL-padded, fixed-length) C string from `data`
# starting at 0-based `off`, of maximum length `len`. Trailing whitespace
# is trimmed. Decodes via Latin-1 -- every header field we care about is
# either pure ASCII or has Latin-1-safe encoding.
.read_cstring <- function(data, off, len) {
  if (off >= length(data)) return("")
  end <- min(length(data), off + len)
  chunk <- data[(off + 1L):end]
  nul_idx <- which(chunk == as.raw(0L))
  if (length(nul_idx) > 0L) chunk <- chunk[seq_len(nul_idx[1L] - 1L)]
  if (length(chunk) == 0L) return("")
  s <- rawToChar(chunk)
  # rawToChar treats bytes as Latin-1; ensure the result is marked UTF-8.
  Encoding(s) <- "latin1"
  s <- enc2utf8(s)
  sub("[[:space:]]+$", "", s)
}

# Locate the first occurrence of the raw pattern `pat` inside `data`.
# Returns a 0-based offset, or NA_integer_ if not found.
.find_raw <- function(data, pat) {
  n <- length(pat)
  if (n == 0L || n > length(data)) return(NA_integer_)
  # Naive scan: fine for the small patterns we use (<=8 bytes) on movie
  # files (typically <=10 MB). Vectorised candidate-mask pass keeps it
  # quick.
  cand <- which(data[seq_len(length(data) - n + 1L)] == pat[1L])
  for (c0 in cand) {
    if (all(data[c0:(c0 + n - 1L)] == pat)) return(c0 - 1L)
  }
  NA_integer_
}

# Test whether bit `bit` (0-based) is set in integer `word`.
.bit_set <- function(word, bit) {
  bitwAnd(word, bitwShiftL(1L, bit)) != 0L
}

# Read a little-endian uint16 at 0-based offset `off` and return as integer.
.read_u16_le <- function(data, off) {
  as.integer(data[off + 1L]) + bitwShiftL(as.integer(data[off + 2L]), 8L)
}
