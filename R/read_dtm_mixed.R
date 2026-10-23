# Historical Dolphin 5.0 uses two zero reserved bits in GC ControllerState.
# Its HID marker (0xA1 in the second byte) sets one of those bits, so valid
# legacy GC records and Wii HID packets have disjoint prefixes.
# Source: dolphin-emu/dolphin tag 5.0, Source/Core/Core/Movie.h and Movie.cpp.
# In the following source revisions, GCPad::GetInput returns zero buttons and
# axes when disconnected. Movie::CheckPadStatus adds only disc/reset commands.
# Connected records have bit 14 set. Their prefixes are disjoint from the
# length + report-ID prefixes written by DataReportBuilder and RecordWiimote.
# TAS input overrides force a connected status; NetPlay transports that same
# GCPadStatus. GCAdapter statuses use the default connected flag.
# Sources at each revision: HW/GCPadEmu.cpp, InputCommon/GCPadStatus.h,
# Movie.cpp, HW/SI/SI_DeviceGCController.cpp, NetPlayClient.cpp, and
# HW/WiimoteCommon/DataReport.cpp (under Source/Core/Core unless stated).
.dtm_native_mixed_revisions <- c(
  "7eb02ecfa452578d9596501cc097d26b80a15931", # Dolphin 5.0-20571
  "b92e354389bb7c0bd114a8631b8af110d3cb3a14" # Dolphin 2407
)
.decode_dtm_mixed_hid <- function(path, data, wii_extension = "raw", wii_key = NULL,
                                  connected = FALSE, native = FALSE, aliases = TRUE) {
  mask <- as.integer(data[12L])
  body <- data[-seq_len(256L)]
  gc_ports <- which(bitwAnd(mask, bitwShiftL(1L, 0:3)) != 0L)
  wii_ports <- which(bitwAnd(mask, bitwShiftL(1L, 4:7)) != 0L)
  if (!length(gc_ports) || !length(wii_ports)) stop("mixed-hid needs both controller families enabled")
  markerless <- connected || native
  capacity <- max(1L, ceiling(length(body) / 4L))
  starts <- sizes <- integer(capacity)
  devices <- logical(capacity)
  pos <- 1L
  n <- 0L
  while (pos <= length(body)) {
    if (pos + 1L > length(body)) stop(path, ": incomplete mixed DTM record")
    second <- as.integer(body[pos + 1L])
    if (native) {
      # Disconnected native records contain no controller data. Disc/reset
      # flags may still be set by Movie::CheckPadStatus.
      disconnected <- body[pos] == as.raw(0L) && second %in% c(0L, 16L, 32L, 48L) &&
        pos + 7L <= length(body) && all(body[(pos + 2L):(pos + 7L)] == as.raw(0L))
      is_wii <- bitwAnd(second, 64L) == 0L && !disconnected
    } else is_wii <- if (connected) bitwAnd(second, 64L) == 0L else second == 161L
    if (is_wii) {
      size <- as.integer(body[pos])
      id <- as.integer(body[pos + if (markerless) 1L else 2L])
      expected <- .wii_hid_sizes[as.character(id)] - as.integer(markerless)
      if (is.na(expected) || size != expected) stop(path, ": invalid HID packet in mixed DTM")
      size <- size + 1L
    } else {
      if (!markerless && bitwAnd(as.integer(body[pos + 1L]), 192L) != 0L)
        stop(path, ": mixed-hid requires the historical GC reserved bits to be zero")
      size <- 8L
    }
    if (pos + size - 1L > length(body)) stop(path, ": incomplete mixed DTM record")
    n <- n + 1L
    starts[n] <- pos
    sizes[n] <- size
    devices[n] <- is_wii
    pos <- pos + size
  }
  starts <- starts[seq_len(n)]
  sizes <- sizes[seq_len(n)]
  devices <- devices[seq_len(n)]
  packets <- matrix(as.raw(0), n, if (n) max(sizes) else 0L)
  for (j in seq_len(ncol(packets))) {
    rows <- which(sizes >= j)
    packets[rows, j] <- body[starts[rows] + j - 1L]
  }
  groups <- list(gc = which(!devices), wii = which(devices))
  movies <- list()
  for (device in names(groups)) {
    rows <- groups[[device]]
    header <- data[seq_len(256L)]
    header[12L] <- as.raw(if (device == "gc") bitwAnd(mask, 15L) else bitwAnd(mask, 240L))
    # The original input count mixes device families. For this internal split,
    # set it to the exact source record count; retain the original on the result.
    header[22:29] <- as.raw(floor(length(rows) / 256^(0:7)) %% 256)
    flattened <- if (length(rows)) as.vector(t(packets[rows, , drop = FALSE])) else raw()
    if (length(rows)) {
      flattened <- flattened[as.vector(t(
        matrix(seq_len(ncol(packets)), length(rows), ncol(packets), byrow = TRUE) <= sizes[rows]
      ))]
    }
    split_data <- c(header, flattened)
    if (device == "gc") {
      temporary <- tempfile(fileext = ".dtm")
      on.exit(unlink(temporary), add = TRUE)
      writeBin(split_data, temporary)
      movies[[device]] <- .configure_movie(.decode_dtm(temporary, dtm_variant = "standard"), aliases = aliases)
    } else {
      movies[[device]] <- .configure_movie(
        .decode_wii_dtm(
          path, split_data, wii_variant = if (markerless) "hid-nomarker" else "hid",
          wii_extension = wii_extension, wii_key = wii_key
        ),
        aliases = aliases
      )
    }
  }
  keys <- unique(unlist(lapply(movies, `[[`, "button_keys")))
  channel_names <- unique(unlist(lapply(movies, function(m) colnames(.source_channels(m, 1L)))))
  inputs <- array(FALSE, c(n, 1L, length(keys)))
  channels <- matrix(NA_real_, n, length(channel_names), dimnames = list(NULL, channel_names))
  commands <- integer(n)
  vectors <- list()
  valid <- rep(TRUE, n)
  for (device in names(groups)) {
    rows <- groups[[device]]
    movie <- movies[[device]]
    inputs[rows, 1L, match(movie$button_keys, keys)] <- movie$inputs[, 1L, , drop = FALSE]
    a <- .source_channels(movie, 1L)
    channels[rows, match(colnames(a), channel_names)] <- a
    commands[rows] <- movie$commands
    v <- .stick_vectors(movie, 1L)
    for (side in intersect(names(v), c("left", "right"))) {
      if (is.null(vectors[[side]])) vectors[[side]] <- matrix(NA_real_, n, 2L)
      vectors[[side]][rows, ] <- v[[side]]
    }
    if (!is.null(movie$poll_fields$valid_report)) valid[rows] <- movie$poll_fields$valid_report
  }
  header <- list(
    `_format` = "dtm", Platform = "Wii",
    dtmVariant = if (native) "mixed-hid-nomarker" else if (connected) "mixed-hid-connected" else "mixed-hid",
    controllerAssignment = "unassigned",
    assignmentReason = "interleaved controller families",
    enabledPorts = c(paste0("gc", gc_ports), paste0("wii", wii_ports)),
    frameCount = .read_u64_le(data, 13L), inputCount = .read_u64_le(data, 21L), availablePollCount = n,
    observationUnit = "controller poll", controllerMask = mask, romId = rawToChar(data[5:10]),
    romMD5 = .dtm_disc_md5(data)
  )
  header$pollCountDifference <- as.character(header$inputCount - n)
  header$inputCountRole <- "emulator input statistic"
  header$sourceRevision <- paste(sprintf("%02x", as.integer(data[210:229])), collapse = "")
  if (native) header$framingRule <- "native GameCube connection state and Wii report ID/length"
  if (connected) header$framingAssumption <- "caller confirms all GameCube records have is_connected set"
  movie <- .new_named_movie(header, commands, inputs, keys, path, analog = list(channels))
  movie$decoded_stick_vectors <- list(vectors)
  movie$poll_bytes <- packets
  movie$poll_lengths <- sizes
  physical <- rep(NA_integer_, n)
  if (length(gc_ports) == 1L) physical[!devices] <- gc_ports
  if (length(wii_ports) == 1L) physical[devices] <- wii_ports
  gc_connected <- gc_get_origin <- rep(NA, n)
  if (markerless && length(groups$gc)) {
    gc_connected[groups$gc] <- bitwAnd(as.integer(packets[groups$gc, 2L]), 64L) != 0L
    gc_get_origin[groups$gc] <- bitwAnd(as.integer(packets[groups$gc, 2L]), 128L) != 0L
  }
  # Preserve the source zero coordinates, while treating disconnected sticks
  # as unobserved when deriving directions, angles, or magnitudes.
  if (native && any(gc_connected %in% FALSE))
    for (side in names(movie$decoded_stick_vectors[[1L]]))
      movie$decoded_stick_vectors[[1L]][[side]][which(gc_connected %in% FALSE), ] <- NA_real_
  movie$poll_fields <- data.frame(
    device = ifelse(devices, "wii", "gc"), physical_port = physical,
    observed_gc = !devices, observed_wii = devices, valid_report = valid,
    gc_connected = gc_connected, gc_get_origin = gc_get_origin
  )
  wii_fields <- movies$wii$poll_fields
  for (key in grep("^wii_(remote|classic)_", names(wii_fields), value = TRUE)) {
    movie$poll_fields[[key]] <- rep(NA, n)
    movie$poll_fields[[key]][groups$wii] <- wii_fields[[key]]
  }
  movie
}
