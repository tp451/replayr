# JPC-RR archive and event specifications:
# https://tasvideos.org/EmulatorResources/JPC/JRSRFormat
# https://github.com/antogerva/jpcrr/blob/master/src/main/java/org/jpc/emulator/EventRecorder.java
# Parentheses group whitespace-containing components; backslashes escape
# individual characters. Track nesting so escaped delimiters remain literal.
.jrsr_components <- function(line) {
  if (!grepl("[()\\\\]", line))
    return(strsplit(trimws(line), "[ \\t\u1680\u180e\u2000-\u200a\u2028\u205f\u3000]+", perl = TRUE)[[1]])
  chars <- strsplit(line, "", fixed = TRUE)[[1]]
  depth <- 0L
  escaped <- FALSE
  out <- character()
  token <- character()
  flush <- function() {
    if (length(token)) {
      out <<- c(out, paste0(token, collapse = ""))
      token <<- character()
    }
  }
  for (ch in chars) {
    if (escaped) {
      token <- c(token, ch)
      escaped <- FALSE
      next
    }
    if (ch == "\\") {
      escaped <- TRUE
      next
    }
    if (ch == "(") {
      if (depth == 0L) flush() else token <- c(token, ch)
      depth <- depth + 1L
      next
    }
    if (ch == ")") {
      if (depth == 0L) stop("Unbalanced JRSR component", call. = FALSE)
      depth <- depth - 1L
      if (depth == 0L) flush() else token <- c(token, ch)
      next
    }
    if (depth == 0L && grepl("^[ \\t\u1680\u180e\u2000-\u200a\u2028\u205f\u3000]$", ch, perl = TRUE)) {
      flush()
    } else {
      token <- c(token, ch)
    }
  }
  if (depth != 0L || escaped) stop("Incomplete JRSR component", call. = FALSE)
  flush()
  out
}
# The components of many lines: lines without grouping or escapes are split
# together, the others one by one.
.jrsr_components_of <- function(lines) {
  out <- vector("list", length(lines))
  plain <- !grepl("[()\\\\]", lines)
  out[plain] <- strsplit(trimws(lines[plain]), "[ \\t\u1680\u180e\u2000-\u200a\u2028\u205f\u3000]+", perl = TRUE)
  out[!plain] <- lapply(lines[!plain], .jrsr_components)
  out
}
.decode_jrsr <- function(path) {
  if (!.starts_with_bytes(path, "JRSR")) stop("Invalid JRSR magic", call. = FALSE)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  # JRSR additionally recognises Unicode record separators as line endings.
  lines <- unlist(strsplit(lines, "[\u001c-\u001e\u0085\u2029]", perl = TRUE), use.names = FALSE)
  if (!length(lines) || lines[1L] != "JRSR") stop("Invalid JRSR magic", call. = FALSE)
  starts <- which(startsWith(lines, "!BEGIN ") | startsWith(lines, "!BEGIN\t"))
  ends <- sort(c(starts[-1L] - 1L, length(lines)))
  sections <- list()
  for (k in seq_along(starts)) {
    name <- sub("^!BEGIN[ \\t]+", "", lines[starts[k]])
    block <- if (ends[k] > starts[k]) lines[seq.int(starts[k] + 1L, ends[k])] else character()
    content <- block[startsWith(block, "+")]
    sections[[name]] <- substring(content, 2L)
  }
  if (!"events" %in% names(sections)) stop("Missing JRSR events section", call. = FALSE)
  nonblank <- lines[nzchar(lines)]
  if (tail(nonblank, 1L) != "!END") stop("Unclosed JRSR section", call. = FALSE)
  raw <- sections$events
  raw <- raw[nzchar(trimws(raw))]
  parts <- .jrsr_components_of(raw)
  size <- lengths(parts)
  if (any(size < 2L)) stop("Invalid JRSR event", call. = FALSE)
  n <- length(parts)
  # Component k of event i is at start[i] + k of all components in a row.
  flat <- as.character(unlist(parts, use.names = FALSE))
  start <- cumsum(size) - size
  component <- function(k) {
    out <- rep("", n)
    out[size >= k] <- flat[(start + k)[size >= k]]
    out
  }
  timestamp_source <- component(1L)
  times <- .computer_number(timestamp_source, "JRSR timestamp", 0, 2^53)
  classes <- component(2L)
  args <- lapply(parts, function(x) x[-c(1L, 2L)])
  kind <- component(3L)
  value <- component(4L)
  # Timing directives affect following events; retain original timestamp
  # strings alongside the accumulated nanosecond times. An event is timed in
  # the mode of the last directive before it, and in relative mode adds to
  # the time of the event before it. Events after an unknown directive are
  # not timed, as reading stops there.
  option <- classes == "OPTION"
  unknown <- which(option & !kind %in% c("RELATIVE", "ABSOLUTE"))
  m <- if (length(unknown)) unknown[1L] else n
  if (m > 0L) {
    timed <- seq_len(m)
    directive <- which(option[timed])
    relative <- c(FALSE, kind[directive] == "RELATIVE")[c(0L, cumsum(option[timed])[-m]) + 1L]
    # A run of relative events continues from the event before it.
    run <- cumsum(!relative)
    continued <- which(run %in% run[relative])
    for (at in split(continued, run[continued])) times[at] <- cumsum(times[at])
    if (any(times[timed] < c(0, times[timed])[timed] | times[timed] > 2^53))
      stop("JRSR timestamps are unordered or exceed exact numeric range", call. = FALSE)
  }
  if (length(unknown)) stop("Unknown JRSR timing option", call. = FALSE)
  keyboard <- classes == "org.jpc.emulator.peripheral.Keyboard"
  joystick <- classes == "org.jpc.modules.Joystick"
  has_joystick <- any(joystick)
  edge <- keyboard & kind == "KEYEDGE"
  codes <- sort(unique(.computer_number(value[edge], "JPC-RR key number", 1, 255)))
  keys <- if (length(codes)) paste0("jpcrr_key_", codes) else character()
  mouse <- any(keyboard & grepl("MOUSE", kind))
  pause <- any(keyboard & kind == "PAUSE")
  if (mouse) keys <- c(keys, c("mouse_left", "mouse_right", "mouse_middle", "mouse_button_4", "mouse_button_5"))
  if (pause) keys <- c(keys, "jpcrr_pause")
  if (has_joystick) keys <- c(keys, "a", "b")
  np <- if (any(joystick & kind %in% c("BUTTONC", "BUTTOND", "AXISC", "AXISD"))) 2L else 1L
  inputs <- array(FALSE, c(n, np, length(keys)))
  ch <- c(if (mouse) c("mouse_dx", "mouse_dy", "mouse_wheel"),
    if (has_joystick) c("joystick_x_hold_ns", "joystick_y_hold_ns"))
  analog <- lapply(seq_len(np), function(p) matrix(0, n, length(ch), dimnames = list(NULL, ch)))
  commands <- integer(n)
  commands[classes == "org.jpc.emulator.PC$ResetButton"] <- 1L
  number <- suppressWarnings(as.numeric(value))
  mouse_button <- keyboard & kind == "MOUSEBUTTON"
  motion <- keyboard & kind %in% c("XMOUSEMOTION", "YMOUSEMOTION", "ZMOUSEMOTION")
  index <- match(substr(kind, nchar(kind), nchar(kind)), LETTERS[1:4])
  side <- (index - 1L) %/% 2L + 1L
  button <- joystick & startsWith(kind, "BUTTON")
  axis <- joystick & !button & startsWith(kind, "AXIS")
  # Reading stops at the first event that cannot be read.
  fault <- rep(NA_character_, n)
  fault[mouse_button & !.computer_valid(number, 0, 4)] <- "Invalid JPC-RR mouse button"
  fault[motion & !.computer_valid(number)] <- "Invalid JPC-RR mouse motion"
  other <- keyboard & !(kind %in% c("KEYEDGE", "PAUSE") | mouse_button | motion)
  fault[other] <- paste0("Unsupported JPC-RR keyboard event: ", kind[other])
  # Within an event, the faults are assigned from the last check to the first.
  fault[joystick & !button & !axis] <- "Unsupported JPC-RR joystick event"
  fault[(button | axis) & side > np] <- "Invalid JPC-RR joystick event"
  fault[button & !.computer_valid(number, 0, 1)] <- "Invalid JPC-RR joystick button"
  fault[axis & !.computer_valid(number, 1)] <- "Invalid JPC-RR joystick hold time"
  fault[joystick & is.na(index)] <- "Invalid JPC-RR joystick event"
  if (any(!is.na(fault))) stop(fault[!is.na(fault)][1L], call. = FALSE)
  # Key and mouse-button edges toggle a key, which is held after an odd
  # number of edges. Mouse displacement belongs only to its event, while
  # joystick buttons and axis hold times persist until the next event of the
  # same control.
  toggled <- rep(NA_integer_, n)
  toggled[edge] <- match(paste0("jpcrr_key_", value[edge]), keys)
  toggled[mouse_button] <- match(c("mouse_left", "mouse_right", "mouse_middle", "mouse_button_4",
    "mouse_button_5")[number[mouse_button] + 1L], keys)
  for (key in unique(toggled[!is.na(toggled)])) inputs[, 1L, key] <- cumsum(toggled %in% key) %% 2L == 1L
  if (pause) inputs[keyboard & kind == "PAUSE", 1L, match("jpcrr_pause", keys)] <- TRUE
  if (mouse) {
    at <- which(motion)
    analog[[1]][cbind(at, match(c(XMOUSEMOTION = "mouse_dx", YMOUSEMOTION = "mouse_dy",
      ZMOUSEMOTION = "mouse_wheel")[kind[at]], ch))] <- number[at]
  }
  latest <- function(events, initial) c(initial, number[events])[findInterval(seq_len(n), events) + 1L]
  pair <- (index - 1L) %% 2L + 1L
  if (has_joystick) for (p in seq_len(np)) for (k in 1:2) {
    inputs[, p, match(c("a", "b")[k], keys)] <- latest(which(button & side == p & pair == k), 0) != 0
    analog[[p]][, match(c("joystick_x_hold_ns", "joystick_y_hold_ns")[k], ch)] <-
      latest(which(axis & side == p & pair == k), NA_real_)
  }
  if (mouse && np > 1L)
    for (p in 2:np) analog[[p]] <- analog[[p]][, !startsWith(colnames(analog[[p]]), "mouse_"), drop = FALSE]
  header <- list(
    format = "jrsr", emulator = "JPC-RR", observation_unit = "event", time_unit = "nanosecond",
    keyboard_mouse_player = 1L, initialization = sections[grepl("^initialization", names(sections))],
    metadata = .jrsr_components_of(sections$header),
    initial_joystick_axes = "Unspecified until the first axis event; recorded hold times remain in nanoseconds"
  )
  header[["_format"]] <- "jrsr"
  movie <- .new_named_movie(header, commands, inputs, keys, path,
    analog = analog,
    kinds = ifelse(grepl("^jpcrr_", keys), "keyboard", ifelse(grepl("^mouse_", keys), "peripheral", "button"))
  )
  movie$events <- data.frame(
    timestamp_source = timestamp_source, timestamp_ns = times,
    event_class = classes, operation = kind, stringsAsFactors = FALSE
  )
  movie$events$arguments <- I(args)
  movie$events$source <- raw
  movie$event_sections <- sections[!names(sections) %in% c("events", "savestate", "manifest")]
  movie
}
