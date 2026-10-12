# Sources / attribution:
#
# This reader was developed with reference to the lsnes source
# tree alongside the TASVideos wiki at
# /EmulatorResources/Lsnes/LSMV.
#
#   Source:    https://repo.or.cz/lsnes.git
#   License:   GPL v2 or later
#
# See inst/COPYRIGHTS for the full provenance manifest.
#
# lsnes (rr) .lsmv movie format. Reference: tasvideos.org wiki at
# /EmulatorResources/Lsnes/LSMV and the lsnes source tree.
#
# The input member has one subframe per non-empty line. Its first control is
# the frame-start flag; later polls in the same frame begin with a period or
# whitespace. All source rows are retained. Gamepad16 adds ext0 through ext3.
# Source schemas/loader: rodamaral/lsnes commit
# 7d9b3e93ecd478c68726e276a08f38880ca00c84, src/emulation/{bsnes-legacy,gambatte}/
# ports.json, src/core/moviefile-text-load.cpp, and include/library/portctrl-data.hpp.
# The SGB core schema also matches bb5cd617cb396d11415de7a4af6ab170a7d84136
# (exp/gambatte-bsnes-sgb), controllerjson.hpp and core-freestanding.cpp.
# Decode the input member with the controller schema declared by the
# archive. Each row retains its source frame and subframe indices.
.decode_lsmv <- function(path, max_input_bytes = 256 * 1024^2) {
  if (length(max_input_bytes) != 1L || !is.numeric(max_input_bytes) ||
    !is.finite(max_input_bytes) || max_input_bytes < 1 ||
    max_input_bytes > .Machine$integer.max)
    stop("max_input_bytes must be positive and no greater than R's single-string limit (2147483647 bytes)")
  listing <- zip::zip_list(path)
  input_bytes <- listing$uncompressed_size[match("input", listing$filename)]
  if (is.na(input_bytes)) stop(path, ": lsmv missing input member", call. = FALSE)
  if (input_bytes > max_input_bytes)
    stop(structure(
      list(
        message = paste0(
          "LSMV input expands to ", format(input_bytes, scientific = FALSE),
          " bytes, exceeding max_input_bytes (", format(max_input_bytes, scientific = FALSE), "). ",
          if (input_bytes <= .Machine$integer.max)
            "Increase max_input_bytes in read_lsmv() only when sufficient memory is available." else
            "This input also exceeds R's hard single-string limit."
        ),
        call = NULL, input_bytes = input_bytes, max_input_bytes = max_input_bytes
      ),
      class = c("replayr_resource_limit", "error", "condition")
    ))
  scratch <- tempfile("lsmv-")
  if (!dir.create(scratch, mode = "0700")) stop("Cannot create LSMV extraction directory", call. = FALSE)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  read_member <- function(member, metadata = FALSE) {
    target <- .extract_bk2_member(path, member, scratch, allow_metadata_error = metadata)
    size <- file.info(target)$size
    if (size > .Machine$integer.max) stop("LSMV member exceeds R's single-string limit: ", member)
    raw <- readBin(target, what = "raw", n = size)
    if (length(raw) != size) stop("Incomplete LSMV member read: ", member, call. = FALSE)
    rawToChar(raw)
  }
  input_text <- read_member("input")
  header <- list("_format" = "lsmv")
  meta_members <- c(
    "gametype", "controlsversion", "coreversion", "systemid",
    "rom.sha256", "rom.hint", "projectid", "rerecords",
    "starttime.second", "starttime.subsecond", "authors",
    "branchname.0"
  )
  meta_members <- unique(c(meta_members, grep("^(port[0-9]+|setting[.].+)$", listing$filename, value = TRUE)))
  for (member in intersect(meta_members, listing$filename)) {
    semantic <- member %in% c("gametype", "controlsversion", "coreversion", "systemid") ||
      grepl("^(port[0-9]+|setting[.].+)$", member)
    val <- tryCatch(read_member(member, metadata = !semantic), error = function(e) {
      if (semantic) stop("Cannot read LSMV controller metadata ", member, ": ", conditionMessage(e), call. = FALSE)
      warning("Cannot read LSMV metadata ", member, ": ", conditionMessage(e), call. = FALSE)
      NULL
    })
    if (!is.null(val)) val <- sub("[[:space:]]+$", "", val)
    if (!is.null(val) && nzchar(val)) header[[member]] <- val
  }
  mv <- .parse_lsmv_input(input_text, header = header)
  mv$source_path <- path
  mv
}
# Decode the system field once per distinct value; button fields precede axes.
.lsmv_system_fields <- function(prefix) {
  pressed <- function(x) !x %in% c("", ".", " ", "\t")
  first <- substr(prefix, 1L, 1L)
  second <- substr(prefix, 2L, 2L)
  third <- substr(prefix, 3L, 3L)
  buttons <- if (nchar(prefix) >= 3L && !third %in% c(" ", "\t")) 3L else 2L
  rest <- trimws(substring(prefix, buttons + 1L), whitespace = "[[:blank:]]")
  high <- low <- 0L
  if (nzchar(rest)) {
    if (!grepl("^[+-]?[0-9]+[[:blank:]]+[+-]?[0-9]+$", rest))
      stop("unsupported lsmv system fields: ", prefix)
    values <- as.numeric(strsplit(rest, "[[:blank:]]+")[[1L]])
    if (any(!is.finite(values) | values < -32768 | values > 32767))
      stop("lsmv reset fields exceed their signed 16-bit source range")
    high <- as.integer(values[1L])
    low <- as.integer(values[2L])
  }
  c(
    frame_start = pressed(first), reset = pressed(second), hard_reset = buttons == 3L && pressed(third),
    reset_delay_high = high, reset_delay_low = low
  )
}
.parse_lsmv_input <- function(text, header = list("_format" = "lsmv")) {
  if (!is.null(header$controlsversion) && header$controlsversion != "0")
    stop("unsupported lsmv controlsversion: ", header$controlsversion)
  declared <- unlist(header[grep("^port[0-9]+$", names(header))], use.names = FALSE)
  supported <- c("none", "gamepad", "gamepad16", "ygamepad16", "multitap", "multitap16", "superscope")
  if (any(!declared %in% supported))
    stop("unsupported lsmv controller type: ", paste(setdiff(declared, supported), collapse = ", "))
  lines <- sub("\r$", "", strsplit(text, "\n", fixed = TRUE)[[1L]])
  source_line <- which(nzchar(lines))
  lines <- lines[source_line]
  n <- length(lines)
  snes_keys <- c("b", "y", "select", "start", "dpad_up", "dpad_down", "dpad_left", "dpad_right", "a", "x", "l1", "r1")
  gb_keys <- c("a", "b", "select", "start", "dpad_right", "dpad_left", "dpad_up", "dpad_down")
  if (!n) {
    header$observationUnit <- "input subframe"
    header$frameCount <- 0L
    header$subframeCount <- 0L
    movie <- .new_named_movie(header, integer(), array(FALSE, c(0L, 1L, 12L)), snes_keys)
    movie$source_input <- text
    movie$subframes <- data.frame(
      source_line = integer(), frame_start = logical(), source_frame = integer(),
      subframe = integer(), reset = logical(), hard_reset = logical(), reset_delay_high = integer(), reset_delay_low = integer()
    )
    return(movie)
  }
  if (any(!grepl("|", lines, fixed = TRUE))) stop("lsmv input line has no port data")
  prefix <- sub("[|].*$", "", lines)
  body <- sub("^[^|]*[|]", "", lines)
  # Appending a sentinel keeps an empty final controller field visible.
  pieces <- strsplit(paste0(body[1L], "|!"), "|", fixed = TRUE)[[1L]]
  widths <- nchar(pieces[-length(pieces)], type = "bytes")
  scope <- identical(header$port2, "superscope")
  if ("superscope" %in% declared && !scope) stop("lsmv Super Scope requires port2")
  if (scope) {
    # The schema serializes buttons first, then signed X/Y coordinates.
    pad_count <- switch(header$port1 %||% "gamepad",
      none = 0L,
      multitap = 4L,
      multitap16 = 4L,
      ygamepad16 = 2L,
      1L
    )
    parts <- strsplit(paste0(body, "|!"), "|", fixed = TRUE)
    if (any(lengths(parts) != pad_count + 2L)) stop("lsmv Super Scope controller fields do not match port settings")
    parts <- matrix(unlist(parts, use.names = FALSE), nrow = n, byrow = TRUE)
    pad_width <- if ((header$port1 %||% "gamepad") %in% c("gamepad16", "multitap16", "ygamepad16")) 16L else 12L
    pad_keys <- c(snes_keys, if (pad_width == 16L) paste0("lsnes_ext", 0:3))
    scope_keys <- c("gun_trigger", "lsnes_scope_cursor", "lsnes_scope_turbo", "lsnes_scope_pause")
    keys <- c(if (pad_count) pad_keys, scope_keys)
    inputs <- array(FALSE, c(n, pad_count + 1L, length(keys)))
    for (player in seq_len(pad_count)) {
      if (any(nchar(parts[, player], type = "bytes") != pad_width)) stop("lsmv gamepad layout changes in Super Scope recording")
      for (column in seq_len(pad_width)) inputs[, player, column] <- !substr(parts[, player], column, column) %in% c(".", " ", "\t")
    }
    gun <- parts[, pad_count + 1L]
    if (any(!grepl("^[^|]{4}[[:blank:]]+[+-]?[0-9]+[[:blank:]]+[+-]?[0-9]+$", gun)))
      stop("malformed lsmv Super Scope buttons or coordinates")
    for (column in seq_len(4L)) inputs[, pad_count + 1L, match(scope_keys[column], keys)] <-
      !substr(gun, column, column) %in% c(".", " ", "\t")
    axes <- matrix(as.numeric(unlist(strsplit(trimws(substring(gun, 5L)), "[[:blank:]]+"))),
      ncol = 2L, byrow = TRUE,
      dimnames = list(NULL, c("gun_x", "gun_y"))
    )
    if (any(!is.finite(axes) | axes < -32768 | axes > 32767)) stop("lsmv Super Scope coordinates exceed their signed 16-bit source range")
    analog <- .empty_analog(n, pad_count + 1L)
    analog[[pad_count + 1L]] <- axes
    accepted <- seq_len(pad_count + 1L)
    widths <- c(rep(pad_width, pad_count), 4L)
    header$controllerTypes <- c(rep(if (pad_width == 16L) "gamepad16" else "gamepad", pad_count), "superscope")
  } else {
    accepted <- which(widths > 0L)
    if (!length(accepted) || any(!widths[accepted] %in% c(8L, 12L, 16L)))
      stop("unsupported lsmv controller widths: ", paste(widths, collapse = ", "))
    if (length(unique(widths[accepted])) != 1L) stop("mixed lsmv controller widths are not supported")
    pattern <- paste0("^", paste0("[^|]{", widths, "}", collapse = "[|]"), "$")
    bad <- which(!grepl(pattern, body, perl = TRUE, useBytes = TRUE))
    if (length(bad)) stop("lsmv controller layout changes or is malformed at source line ", source_line[bad[1L]])
    width <- widths[accepted[1L]]
    keys <- if (width == 8L) gb_keys else c(snes_keys, if (width == 16L) paste0("lsnes_ext", 0:3))
    inputs <- array(FALSE, c(n, length(accepted), length(keys)))
    starts <- cumsum(c(1L, head(widths, -1L) + 1L))
    for (player in seq_along(accepted)) for (column in seq_len(width)) {
      at <- starts[accepted[player]] + column - 1L
      ch <- substr(body, at, at)
      inputs[, player, column] <- !ch %in% c(".", " ", "\t")
    }
    analog <- .empty_analog(n, length(accepted))
    header$controllerTypes <- rep(if (width == 8L) "gb_gamepad" else if (width == 16L) "gamepad16" else "gamepad", length(accepted))
  }
  unique_prefix <- unique(prefix)
  fields <- t(vapply(unique_prefix, .lsmv_system_fields, numeric(5L)))
  index <- match(prefix, unique_prefix)
  frame_start <- as.logical(fields[index, "frame_start"])
  if (!frame_start[1L]) stop("the first lsmv subframe must start a new frame")
  frame <- cumsum(frame_start)
  subframe <- seq_len(n) - cummax(ifelse(frame_start, seq_len(n), 0L)) + 1L
  reset <- as.logical(fields[index, "reset"])
  hard <- as.logical(fields[index, "hard_reset"])
  commands <- as.integer(reset) + 2L * as.integer(hard)
  header$observationUnit <- "input subframe"
  header$frameCount <- sum(frame_start)
  header$subframeCount <- n
  header$controllerFields <- accepted
  header$controllerWidths <- widths[accepted]
  movie <- .new_named_movie(header, commands, inputs, keys, analog = analog)
  movie$subframes <- data.frame(
    source_line = source_line, frame_start = frame_start, source_frame = frame,
    subframe = subframe, reset = reset, hard_reset = hard,
    reset_delay_high = as.integer(fields[index, "reset_delay_high"]),
    reset_delay_low = as.integer(fields[index, "reset_delay_low"])
  )
  movie$source_input <- text
  movie
}
