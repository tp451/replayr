# Independently implemented FGK adaptive Huffman coding. The tree update follows
# the mathematical algorithm discussed by Vitter (1987), section 2, pp. 830-831,
# doi:10.1145/31846.42227. No emulator decompressor code is incorporated here.
# FBM stores the resulting bitstream most-significant-bit first in LE32 words.
.fbm_fgk_decode <- function(packed, count) {
  if (!is.raw(packed) || length(packed) %% 4L || length(count) != 1L ||
    !is.finite(count) || count < 0 || count != floor(count) || count > 2^28)
    stop("Invalid or excessively large FBM Huffman payload")
  if (!count) return(raw())
  bits <- as.integer(matrix(rawToBits(packed), nrow = 32L)[32:1, , drop = FALSE])
  pos <- 1L
  # At most 256 symbol leaves, 256 internal nodes, and one not-yet-seen leaf.
  weight <- numeric(513L)
  order <- parent <- left <- right <- integer(513L)
  symbol <- rep.int(-1L, 513L)
  seen <- rep.int(FALSE, 256L)
  order[1L] <- 512L
  used <- nyt <- 1L
  answer <- raw(count)
  for (i in seq_len(count)) {
    node <- 1L
    while (left[node] != 0L) {
      if (pos > length(bits)) stop("Truncated FBM Huffman bitstream")
      node <- if (bits[pos]) right[node] else left[node]
      pos <- pos + 1L
    }
    # The not-yet-seen leaf is followed by an eight-bit literal. Split it
    # into the symbol leaf and a new not-yet-seen leaf.
    if (node == nyt) {
      if (pos + 7L > length(bits)) stop("Truncated FBM Huffman literal")
      value <- sum(bits[pos:(pos + 7L)] * c(128L, 64L, 32L, 16L, 8L, 4L, 2L, 1L))
      pos <- pos + 8L
      if (seen[value + 1L]) stop("FBM Huffman literal repeats an existing symbol")
      seen[value + 1L] <- TRUE
      leaf <- used + 1L
      fresh <- used + 2L
      used <- fresh
      parent[c(leaf, fresh)] <- node
      order[leaf] <- order[node] - 1L
      order[fresh] <- order[node] - 2L
      weight[leaf] <- weight[node] <- 1
      symbol[leaf] <- value
      left[node] <- fresh
      right[node] <- leaf
      nyt <- fresh
      node <- parent[node]
    } else {
      value <- symbol[node]
    }
    answer[i] <- as.raw(value)
    # Restore the FGK sibling order by swapping with the highest-ordered
    # equal-weight node, then increment weights along the path to the root.
    while (node != 0L) {
      candidates <- which(weight[seq_len(used)] == weight[node])
      candidates <- candidates[candidates != parent[node]]
      if (parent[node] == parent[nyt] && node != nyt)
        candidates <- candidates[left[candidates] == 0L]
      leader <- candidates[which.max(order[candidates])]
      if (leader != node) {
        pa <- parent[node]
        pb <- parent[leader]
        if (!pa || !pb) stop("Invalid FBM Huffman tree")
        a_left <- left[pa] == node
        b_left <- left[pb] == leader
        if (a_left) left[pa] <- leader else right[pa] <- leader
        if (b_left) left[pb] <- node else right[pb] <- node
        parent[node] <- pb
        parent[leader] <- pa
        old_order <- order[node]
        order[node] <- order[leader]
        order[leader] <- old_order
      }
      weight[node] <- weight[node] + 1
      node <- parent[node]
    }
  }
  answer
}
# Input schemas record facts about the driver's ordered input fields. They do
# not contain emulator code. A byte input is unsigned; analogue inputs use BE16.
.fbm_input_schema <- function(game = NULL, input_schema = NULL) {
  if (!is.null(game) && !is.null(input_schema))
    stop("Supply either game or input_schema for FBM, not both")
  if (is.null(input_schema)) {
    if (!is.character(game) || length(game) != 1L || is.na(game) || !nzchar(game))
      stop("FBM does not identify its input layout: supply a verified game ROM identifier or input_schema")
    schemas <- jsonlite::fromJSON(system.file("extdata", "fbm-layouts.json", package = "replayr"),
      simplifyVector = FALSE)
    input_schema <- schemas[[game]]
    if (is.null(input_schema)) stop("FBM game '", game, "' requires a source-verified input_schema")
  }
  fields <- input_schema$fields
  if (!is.list(fields) || !length(fields) || length(fields) > 255L)
    stop("FBM input_schema must contain an ordered fields list of 1 to 255 inputs")
  for (f in fields) {
    if (!is.list(f) || !all(c("key", "player", "type") %in% names(f)) ||
      length(f$key) != 1L || !is.character(f$key) || is.na(f$key) || !nzchar(f$key) ||
      length(f$player) != 1L || !is.numeric(f$player) || !is.finite(f$player) ||
      f$player < 0 || f$player != floor(f$player) || f$player > 32L ||
      length(f$type) != 1L || !f$type %in% c("button", "byte", "analog"))
      stop("Invalid FBM input field: expected key, player, and type (button, byte, or analog)")
    encoding <- f$button_encoding %||% "binary"
    if (length(encoding) != 1L || !encoding %in% c("binary", "bit0", "nonzero"))
      stop("Invalid FBM button_encoding: expected binary, bit0, or nonzero")
  }
  identifiers <- vapply(fields, function(f) paste(f$player, f$key, sep = ":"), character(1))
  if (anyDuplicated(identifiers)) stop("FBM schema has duplicate player/key fields")
  input_schema
}
.fbm_frame_values <- function(bytes, n, fields) {
  widths <- vapply(fields, function(f) if (f$type == "analog") 2L else 1L, integer(1))
  if (!is.finite(n) || n < 0 || n != floor(n) || n * length(fields) > 2^28)
    stop("FBM decoded input matrix exceeds the supported memory limit")
  if (length(bytes) < sum(widths) + n) stop("FBM input data is shorter than its frame count and schema")
  bytes <- as.integer(bytes)
  current <- integer(length(fields))
  pos <- 1L
  read_value <- function(field) {
    width <- widths[field]
    if (pos + width - 1L > length(bytes)) stop("Truncated FBM input value")
    value <- bytes[pos]
    if (width == 2L) {
      value <- value * 256L + bytes[pos + 1L]
      if (value >= 32768L) value <- value - 65536L
    }
    pos <<- pos + width
    if (fields[[field]]$type == "button" &&
      (fields[[field]]$button_encoding %||% "binary") == "binary" && !value %in% c(0L, 1L))
      stop("FBM button value disagrees with the supplied input schema")
    value
  }
  for (j in seq_along(fields)) current[j] <- read_value(j)
  result <- matrix(0L, nrow = n, ncol = length(fields))
  for (i in seq_len(n)) {
    repeat {
      if (pos > length(bytes)) stop("Truncated FBM frame; check the supplied input schema")
      id <- bytes[pos]
      pos <- pos + 1L
      if (id == 255L) break
      if (id >= length(fields)) stop("FBM input index exceeds the supplied input schema")
      current[id + 1L] <- read_value(id + 1L)
    }
    result[i, ] <- current
  }
  if (pos <= length(bytes))
    stop("FBM input data remains after the declared frame count; check the supplied input schema")
  result
}
# What follows the input chunk. The emulator writes there the text that the
# author of a recording entered in its recording dialog, as a chunk FRM1: the
# length of the text in bytes, then two bytes for each character, the low
# byte first (fbarr, src/burner/win32/replay.cpp). Bytes that are no such
# chunk, or that follow it, are returned as they are.
.fbm_trailer <- function(data, end, path) {
  out <- list(metadata = NULL, tail = raw())
  if (end >= length(data)) return(out)
  rest <- data[(end + 1L):length(data)]
  if (length(rest) < 8L || !identical(rest[1:4], charToRaw("FRM1"))) {
    out$tail <- rest
    return(out)
  }
  size <- .read_u32_le(rest, 4L)
  available <- length(rest) - 8L
  if (size > available) {
    warning(basename(path), ": the text after the input is cut short; ", available, " of its ", size,
      " bytes are read", call. = FALSE)
  }
  take <- min(size, available)
  units <- matrix(rest[8L + seq_len(take - take %% 2L)], nrow = 2L)
  # The text ends at a character of value zero, as it does for the emulator.
  ended <- which(units[1L, ] == as.raw(0L) & units[2L, ] == as.raw(0L))
  if (length(ended)) units <- units[, seq_len(ended[1L] - 1L), drop = FALSE]
  out$metadata <- if (length(units)) iconv(list(as.vector(units)), "UTF-16LE", "UTF-8", sub = "?") else ""
  if (available > size) out$tail <- rest[(8L + size + 1L):length(rest)]
  out
}
.decode_fbm <- function(path, game = NULL, input_schema = NULL) {
  # The file is looked at before the layout is asked for, so that a file of
  # another format is not answered with a request for an input schema.
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 45L || !identical(data[1:4], charToRaw("FB1 ")))
    stop("Not a FinalBurn Alpha FBM recording")
  schema <- .fbm_input_schema(game, input_schema)
  flags <- as.integer(data[5L])
  offset <- 5L
  if (identical(data[offset + 1:4], charToRaw("FS1 "))) {
    size <- .read_u32_le(data, offset + 4L)
    offset <- offset + 8L + size
  }
  if (offset + 40L > length(data) || !identical(data[offset + 1:4], charToRaw("FR1 ")))
    stop("FBM recording has no valid FR1 input chunk")
  chunk_size <- .read_u32_le(data, offset + 4L)
  n <- .read_u32_le(data, offset + 8L)
  rerecords <- .read_u32_le(data, offset + 12L)
  start <- offset + 24L
  packed_size <- .read_u32_le(data, start)
  count <- .read_u32_le(data, start + 4L)
  resets <- .read_u32_le(data, start + 8L)
  if (resets != 0) stop("FBM Huffman streams with frequency-counter resets are not supported")
  if (packed_size < 16L || packed_size %% 4L || start + packed_size > length(data) ||
    packed_size + 16L > chunk_size || offset + 8L + chunk_size > length(data))
    stop("FBM compressed chunk size is invalid")
  packed <- if (packed_size > 16L) data[(start + 17L):(start + packed_size)] else raw()
  decoded <- .fbm_fgk_decode(packed, count)
  fields <- schema$fields
  values <- .fbm_frame_values(decoded, n, fields)
  players <- sort(unique(vapply(fields, function(f) f$player, numeric(1))))
  players <- players[players > 0L]
  if (!length(players)) players <- 1L
  digital <- fields[vapply(fields, function(f) f$player > 0 && f$type == "button", logical(1))]
  keys <- unique(vapply(digital, function(f) f$key, character(1)))
  labels <- vapply(keys, function(key) {
    f <- digital[[which(vapply(digital, function(f) f$key == key, logical(1)))[1L]]]
    f$name %||% gsub("_", " ", key, fixed = TRUE)
  }, character(1))
  inputs <- array(FALSE, c(n, length(players), length(keys)))
  analog <- lapply(players, function(p) list())
  system <- data.frame(row.names = seq_len(n))
  for (j in seq_along(fields)) {
    f <- fields[[j]]
    raw_key <- paste0("raw_", if (f$player == 0L) "system" else paste0("p", f$player), "_", f$key)
    system[[raw_key]] <- values[, j]
    on <- if ((f$button_encoding %||% "binary") == "bit0") values[, j] %% 2L != 0L else values[, j] != 0L
    if (f$player == 0L) {
      system[[f$key]] <- if (f$type == "button") on else values[, j]
    } else if (f$type == "button") {
      inputs[, match(f$player, players), match(f$key, keys)] <- on
    } else {
      analog[[match(f$player, players)]][[f$key]] <- values[, j]
    }
  }
  analog <- lapply(analog, function(channels) {
    if (!length(channels)) return(matrix(numeric(), nrow = n, ncol = 0L))
    x <- do.call(cbind, channels)
    storage.mode(x) <- "double"
    x
  })
  header <- list(
    "_format" = "fbm", Platform = "Arcade", game = game %||% "caller-supplied schema",
    frameCount = n, rerecordCount = rerecords, sourceFlags = flags, controllerPorts = players,
    inputSchemaSource = schema$source %||% "caller-supplied", huffmanDecodedBytes = count
  )
  trailer <- .fbm_trailer(data, offset + 8L + chunk_size, path)
  header$metadata <- trailer$metadata
  plain <- labels == gsub("_", " ", keys, fixed = TRUE)
  labels[plain] <- .control_identity_layout(keys[plain])$name
  movie <- .new_named_movie(header, integer(n), inputs, keys, source_path = path, analog = analog, names = labels)
  movie$system_inputs <- system
  movie$input_schema <- schema
  if (length(trailer$tail)) {
    warning(basename(path), ": ", length(trailer$tail), " byte(s) follow the recording that are no text of its ",
      "author; retaining them in source_tail", call. = FALSE)
    movie$source_tail <- trailer$tail
  }
  movie
}
