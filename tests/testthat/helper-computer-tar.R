# Construct small original archives without depending on an external tar program.
.computer_test_tar <- function(scripts, types = rep("0", length(scripts)), bad_checksum = FALSE) {
  data <- raw()
  put <- function(block, at, value) {
    bytes <- charToRaw(value)
    block[at + seq_along(bytes) - 1L] <- bytes
    block
  }
  for (i in seq_along(scripts)) {
    bytes <- charToRaw(scripts[[i]])
    block <- raw(512L)
    block <- put(block, 1L, names(scripts)[i])
    block <- put(block, 125L, sprintf("%011o", length(bytes)))
    block[149:156] <- as.raw(32L)
    block <- put(block, 157L, types[i])
    checksum <- sum(as.integer(block)) + as.integer(bad_checksum)
    block <- put(block, 149L, sprintf("%06o", checksum))
    block[155L] <- as.raw(0L)
    data <- c(data, block, bytes, raw((-length(bytes)) %% 512L))
  }
  data <- c(data, raw(1024L))
  path <- tempfile(fileext = ".dft")
  con <- gzfile(path, "wb")
  writeBin(data, con)
  close(con)
  path
}
