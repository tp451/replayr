# Dustmod Nexus scripts: developer guide and Dusted's MIT-licensed exporter.
# https://dustkidblog.wordpress.com/2016/08/07/nexus-tasing-with-dustmod/
# https://github.com/AlexMorson/dusted/blob/af0a8f57a12f5b6986c9791c64bef7578e192acb/src/dusted/nexus_script.py
# https://tasvideos.org/10584S (restart column, Dustmod 26.7.1)
.dft_archive <- function(path) {
  if (!identical(readBin(path, "raw", 2L), as.raw(c(31L, 139L))))
    stop("DFT must be a gzip-compressed tar archive", call. = FALSE)
  archive <- .computer_tar_regular(path)
  scripts <- lapply(names(archive$members), function(name) {
    data <- archive$members[[name]]
    if (any(data == as.raw(0L))) stop("DFT script contains a NUL byte: ", name, call. = FALSE)
    text <- rawToChar(data)
    Encoding(text) <- "UTF-8"
    if (!validUTF8(text)) stop("DFT script is not UTF-8: ", name, call. = FALSE)
    sub("^\ufeff", "", text)
  })
  if (!length(scripts)) stop("DFT archive contains no scripts", call. = FALSE)
  list(scripts = stats::setNames(scripts, names(archive$members)), metadata = archive$metadata)
}
.decode_dft <- function(path, entry = NULL) {
  archive <- .dft_archive(path)
  scripts <- archive$scripts
  if (is.null(entry)) {
    entry <- names(scripts)[basename(names(scripts)) == "main.txt"]
    if (length(entry) != 1L) stop("DFT needs exactly one main.txt entry script", call. = FALSE)
  } else {
    if (!is.character(entry) || length(entry) != 1L || is.na(entry))
      stop("entry must be one DFT script path", call. = FALSE)
    entry <- .computer_tar_path(entry)
    if (!entry %in% names(scripts)) stop("Missing DFT entry script: ", entry, call. = FALSE)
  }
  parsed <- lapply(scripts, function(text) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    clean <- trimws(sub("#.*$", "", lines))
    keep <- which(nzchar(clean))
    data.frame(line = keep, text = clean[keep], stringsAsFactors = FALSE)
  })
  rows <- list()
  locations <- list()
  commands <- list()
  row_count <- 0L
  command_count <- 0L
  visited <- character()
  expand <- function(member, stack = character()) {
    if (member %in% stack) stop("Recursive DFT include: ", member, call. = FALSE)
    if (length(stack) >= 100L) stop("DFT include nesting exceeds 100 levels", call. = FALSE)
    if (!member %in% names(parsed)) stop("Missing DFT included script: ", member, call. = FALSE)
    visited <<- union(visited, member)
    script <- parsed[[member]]
    for (i in seq_len(nrow(script))) {
      line <- script$text[i]
      if (grepl("^[012]", line)) {
        digits <- gsub("[[:space:]]", "", line)
        if (!grepl("^[012]{4}[01]{5,7}$", digits))
          stop("Invalid DFT input at ", member, ":", script$line[i], call. = FALSE)
        row_count <<- row_count + 1L
        if (row_count > 10000000L) stop("DFT expansion exceeds ten million scripted frames", call. = FALSE)
        rows[[row_count]] <<- digits
        locations[[row_count]] <<- c(member, as.character(script$line[i]))
      } else {
        parts <- strsplit(line, ":", fixed = TRUE)[[1L]]
        kind <- parts[1L]
        if (!kind %in% c("INCLUDE", "MOUSE", "LOAD", "STATS", "SYNCLOAD"))
          stop("Unknown DFT command at ", member, ":", script$line[i], ": ", kind, call. = FALSE)
        count <- c(INCLUDE = 2L, MOUSE = 4L, LOAD = 4L, STATS = 2L, SYNCLOAD = 1L)[kind]
        if (length(parts) != count || any(!nzchar(parts)))
          stop("Invalid DFT ", kind, " command at ", member, ":", script$line[i], call. = FALSE)
        if (kind == "INCLUDE") parts[2L] <- .computer_tar_path(parts[2L])
        if (kind == "MOUSE") {
          .computer_number(parts[2:3], "DFT mouse coordinates", whole = FALSE)
          if (!grepl("^[01]{1,5}$", parts[4L])) stop("Invalid DFT mouse button state", call. = FALSE)
        }
        if (kind == "LOAD") .computer_number(parts[2L], "DFT character ID", 0, 3)
        if (kind == "STATS") .computer_number(parts[2L], "DFT stats ID", 0)
        command_count <<- command_count + 1L
        if (command_count > 1000000L) stop("DFT expansion exceeds one million commands", call. = FALSE)
        commands[[command_count]] <<- data.frame(
          order = command_count,
          before_row = row_count + 1L, member = member, line = script$line[i],
          command = kind, text = line, stringsAsFactors = FALSE
        )
        if (kind == "INCLUDE") expand(parts[2L], c(stack, member))
      }
    }
    invisible(NULL)
  }
  expand(entry)
  source_digits <- as.character(unlist(rows, use.names = FALSE))
  width <- nchar(source_digits)
  n <- length(source_digits)
  nc <- if (n) max(width) else 9L
  action_names <- c("left", "right", "up", "down", "jump", "dash", "light", "heavy", "escape", "taunt",
    "restart")[seq_len(nc)]
  source_values <- matrix(NA_integer_, n, nc, dimnames = list(NULL, action_names))
  for (j in seq_len(nc)) {
    available <- which(width >= j)
    source_values[available, j] <- as.integer(substr(source_digits[available], j, j))
  }
  source_commands <- if (length(commands)) do.call(rbind, commands) else
    data.frame(
      order = integer(), before_row = integer(), member = character(),
      line = integer(), command = character(), text = character(), stringsAsFactors = FALSE
    )
  mouse_commands <- which(source_commands$command == "MOUSE")
  mouse <- matrix(NA_real_, n, 2L, dimnames = list(NULL, c("mouse_x", "mouse_y")))
  mouse_observed <- logical(n)
  mouse_buttons <- matrix(FALSE, n, 5L, dimnames = list(
    NULL,
    c("mouse_left", "mouse_right", "mouse_middle", "mouse_scroll_up", "mouse_scroll_down")
  ))
  mouse_button_observed <- mouse_buttons
  mouse_source_state <- rep(NA_character_, n)
  for (i in mouse_commands) {
    row <- source_commands$before_row[i]
    if (row > n) next # Commands after the final input remain in source_commands.
    parts <- strsplit(source_commands$text[i], ":", fixed = TRUE)[[1L]]
    mouse[row, ] <- as.numeric(parts[2:3])
    mouse_observed[row] <- TRUE
    state <- utf8ToInt(parts[4L]) - 48L
    mouse_buttons[row, ] <- FALSE
    mouse_button_observed[row, ] <- FALSE
    mouse_buttons[row, seq_along(state)] <- state == 1L
    mouse_button_observed[row, seq_along(state)] <- TRUE
    mouse_source_state[row] <- parts[4L]
  }
  # Jump, dash, the two attacks, taunt and restart are what the game is
  # asked to do, not buttons: they are game actions. Escape opens the menu
  # and is Start.
  verbs <- action_names[-(1:4)]
  action_keys <- c(
    "dpad_left", "dpad_right", "dpad_up", "dpad_down",
    ifelse(verbs == "escape", "dustforce_escape", paste0("action_", verbs))
  )
  mouse_present <- length(mouse_commands) > 0L
  keys <- c(action_keys, if (mouse_present) colnames(mouse_buttons))
  inputs <- array(FALSE, c(n, 1L, length(keys)))
  inputs[, 1L, seq_len(nc)] <- !is.na(source_values) & source_values > 0L
  if (mouse_present) inputs[, 1L, nc + seq_len(5L)] <- mouse_buttons
  sync <- any(source_commands$command == "SYNCLOAD")
  header <- list(
    format = "dft", emulator = "Dustmod", game = "Dustforce DX",
    entry_script = entry, observation_unit = "scripted frame", frame_count = n,
    frame_rate = 60, runtime_duration_known = !sync,
    input_semantics = "0 released; 1 held; directional 2 held with double-tap event",
    mouse_coordinates = "absolute positions relative to the display centre",
    mouse_semantics = "MOUSE addresses the next scripted input row; consult mouse_observed",
    include_count = sum(source_commands$command == "INCLUDE"),
    referenced_scripts = visited
  )
  header[["_format"]] <- "dft"
  movie <- .new_named_movie(header, integer(n), inputs, keys, path,
    analog = if (mouse_present) list(mouse) else NULL
  )
  movie$source_digits <- source_digits
  movie$source_values <- source_values
  movie$double_tapped <- source_values[, 1:4, drop = FALSE] == 2L
  movie$source_locations <- if (n) {
    loc <- do.call(rbind, locations)
    data.frame(member = loc[, 1L], line = as.integer(loc[, 2L]), stringsAsFactors = FALSE)
  } else data.frame(member = character(), line = integer(), stringsAsFactors = FALSE)
  movie$source_commands <- source_commands
  movie$mouse_observed <- mouse_observed
  movie$mouse_button_observed <- mouse_button_observed
  movie$mouse_source_state <- mouse_source_state
  movie$source_scripts <- scripts
  movie$source_archive <- archive$metadata
  movie
}
