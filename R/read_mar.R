# MAME-rr MAR v1 records timestamps and source input-port values. Its digital
# words hold pressed bits before the emulator combines active-low defaults.
# The format is described at https://tasvideos.org/EmulatorResources/Mamerr/Mar.
.decode_mar <- function(path, input_schema = NULL) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 64L || !identical(data[1:8], c(charToRaw("MAMETAS"), as.raw(0))))
    stop("Not a MAME-rr MAR recording")
  if (as.integer(data[9L]) != 1L) stop("Unsupported MAR version")
  game <- .read_cstring(data, 12L, 12L)
  build <- .read_cstring(data, 24L, 24L)
  rate <- readBin(data[49:56], "double", n = 1L, size = 8L, endian = "little")
  declared <- .read_u32_le(data, 56L)
  if (is.null(input_schema)) {
    path_schema <- system.file("extdata", "mar-layouts.json", package = "replayr")
    schemas <- jsonlite::fromJSON(path_schema, simplifyVector = FALSE)
    input_schema <- schemas[[game]]
    if (is.null(input_schema)) stop("MAR game '", game, "' requires a source-verified input_schema")
  }
  ports <- input_schema$ports
  if (!is.list(ports) || !length(ports)) stop("MAR input_schema must contain an ordered ports list")
  fields <- list()
  width <- 12L
  for (p in ports) {
    if (!is.character(p$name) || length(p$name) != 1L || !nzchar(p$name)) stop("Invalid MAR port name")
    width <- width + 8L
    for (f in p$fields) {
      if (!is.list(f) || !all(c("mask", "key", "player", "type") %in% names(f)) ||
        !f$type %in% c("button", "analog") || length(f$mask) != 1L || !is.finite(f$mask) ||
        f$mask < 1 || f$mask > 2^32 - 1 || f$mask != floor(f$mask) ||
        length(f$key) != 1L || !nzchar(f$key) || length(f$player) != 1L ||
        !is.finite(f$player) || f$player < 0 || f$player != floor(f$player)) stop("Invalid MAR input field")
      if (f$type == "analog") width <- width + 13L
      f$port <- p$name
      fields[[length(fields) + 1L]] <- f
    }
  }
  body <- length(data) - 64L
  if (body %% width) stop("MAR length disagrees with the supplied input-port schema")
  n <- body / width
  if (declared != n) stop("MAR frame count disagrees with input data and schema")
  bytes <- matrix(as.integer(data[-seq_len(64L)]), nrow = width, ncol = n)
  word <- function(offset, signed = FALSE) {
    value <- colSums(bytes[offset + seq_len(4L), , drop = FALSE] * c(1, 256, 65536, 16777216))
    if (signed) value[value >= 2^31] <- value[value >= 2^31] - 2^32
    value
  }
  sys <- data.frame(time_seconds = word(0L), time_attoseconds_low = word(4L), time_attoseconds_high = word(8L))
  player_ids <- sort(unique(vapply(fields, function(f) f$player, numeric(1))))
  player_ids <- player_ids[player_ids > 0]
  if (!length(player_ids)) player_ids <- 1L
  digital <- fields[vapply(fields, function(f) f$type == "button" && f$player > 0, logical(1))]
  keys <- unique(vapply(digital, function(f) f$key, character(1)))
  inputs <- array(FALSE, c(n, length(player_ids), length(keys)))
  channels <- lapply(player_ids, function(p) list())
  labels <- vapply(keys, function(key) {
    f <- digital[[which(vapply(digital, function(f) f$key == key, logical(1)))[1L]]]
    f$name %||% gsub("_", " ", key, fixed = TRUE)
  }, character(1))
  offset <- 12L
  for (port in ports) {
    slug <- .bk2_key_slug(port$name)
    sys[[paste0("port_", slug, "_default")]] <- word(offset)
    value <- word(offset + 4L)
    sys[[paste0("port_", slug, "_digital")]] <- value
    offset <- offset + 8L
    for (f in port$fields) {
      if (f$type == "button") {
        # Arithmetic bit extraction keeps unsigned bit 31 intact in R.
        bits <- which(as.integer(intToBits(as.integer(f$mask %% 2^31))) != 0L) - 1L
        if (f$mask >= 2^31) bits <- c(bits, 31L)
        on <- rep(FALSE, n)
        for (bit in bits) on <- on | (floor(value / 2^bit) %% 2 != 0)
        if (f$player == 0L) {
          name <- paste0("input_", f$key)
          sys[[name]] <- if (is.null(sys[[name]])) on else sys[[name]] | on
        } else {
          p <- match(f$player, player_ids)
          k <- match(f$key, keys)
          inputs[, p, k] <- inputs[, p, k] | on
        }
      } else {
        vals <- list(
          accumulator = word(offset, TRUE), previous = word(offset + 4L, TRUE),
          sensitivity = word(offset + 8L), reverse = bytes[offset + 13L, ]
        )
        for (name in names(vals)) {
          key <- paste(f$key, slug, name, sep = "_")
          if (f$player == 0L) sys[[key]] <- vals[[name]] else channels[[match(f$player, player_ids)]][[key]] <- vals[[name]]
        }
        offset <- offset + 13L
      }
    }
  }
  analog <- lapply(channels, function(x) {
    if (!length(x)) return(matrix(numeric(), nrow = n, ncol = 0L))
    out <- do.call(cbind, x)
    storage.mode(out) <- "double"
    out
  })
  header <- list(
    "_format" = "mar", Platform = "Arcade", game = game, emulatorVersion = build,
    frameRate = rate, frameCount = n, rerecordCount = .read_u32_le(data, 60L), controllerPorts = player_ids,
    inputSchemaSource = input_schema$source %||% "caller-supplied"
  )
  movie <- .new_named_movie(header, integer(n), inputs, keys, source_path = path, analog = analog, names = labels)
  movie$system_inputs <- sys
  movie$input_schema <- input_schema
  movie
}
