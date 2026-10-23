# Dolphin Movie.cpp, WiimoteCommon/DataReport.cpp, WiimoteReport.h,
# WiimoteEmu/DesiredWiimoteState.cpp, Camera.h, and Extension/{Nunchuk,Classic}.h.
# Source: https://github.com/dolphin-emu/dolphin (GPL-2.0-or-later).
# Each observation is a recorded Wii Remote poll, not a video frame.
.wii_hid_sizes <- c(
  `48` = 4L, `49` = 7L, `50` = 12L, `51` = 19L,
  `52` = 23L, `53` = 23L, `54` = 23L, `55` = 23L,
  `61` = 23L, `62` = 23L, `63` = 23L
)
.wii_packet_index <- function(body, prefix = 0L, serialized = FALSE, markerless = FALSE) {
  # Record offsets first; avoid allocating a separate R object for every poll.
  capacity <- max(1L, ceiling(length(body) / 5L))
  starts <- lengths <- integer(capacity)
  validity <- logical(capacity)
  pos <- 1L
  n <- 0L
  known_hid <- FALSE
  tail <- raw()
  while (pos <= length(body)) {
    p <- pos + prefix
    if (p > length(body)) return(NULL)
    size <- as.integer(body[p])
    if (size < 1L || size > 30L) return(NULL)
    if (p + size > length(body)) {
      if (!n || (!serialized && !known_hid)) return(NULL)
      tail <- body[seq.int(pos, length(body))]
      break
    }
    valid_record <- TRUE
    if (!serialized && markerless) {
      expected <- .wii_hid_sizes[as.character(as.integer(body[p + 1L]))] - 1L
      valid_record <- !is.na(expected) && size == expected
      if (!valid_record && !size %in% (.wii_hid_sizes - 1L)) return(NULL)
      known_hid <- known_hid || valid_record
    } else if (!serialized) {
      if (as.integer(body[p + 1L]) == 161L && size >= 4L) {
        expected <- .wii_hid_sizes[as.character(as.integer(body[p + 2L]))]
        valid_record <- !is.na(expected) && size == expected
      } else valid_record <- FALSE
      if (!valid_record && !size %in% .wii_hid_sizes) return(NULL)
      known_hid <- known_hid || valid_record
    } else {
      flags <- as.integer(body[p + 1L])
      ext <- flags %/% 16L
      if (ext > 9L) return(NULL)
      buttons <- bitwAnd(flags, 1L) != 0L
      accel <- bitwAnd(flags, 2L) != 0L
      expected <- 1L + if (buttons && accel) 5L else if (buttons) 2L else if (accel) 4L else 0L
      expected <- expected + 12L * (bitwAnd(flags, 4L) != 0L) + 6L * (bitwAnd(flags, 8L) != 0L)
      # All extension DesiredState structures are six bytes except TaTaCon (1) and Shinkansen (4).
      expected <- expected + if (ext == 8L) 1L else if (ext == 9L) 4L else if (ext > 0L) 6L else 0L
      if (size != expected) return(NULL)
    }
    n <- n + 1L
    if (n > length(starts)) {
      length(starts) <- n * 2L
      length(lengths) <- n * 2L
      length(validity) <- n * 2L
    }
    starts[n] <- p + 1L
    lengths[n] <- size
    validity[n] <- valid_record
    pos <- p + size + 1L
  }
  if (!serialized && n && !known_hid) return(NULL)
  list(start = starts[seq_len(n)], length = lengths[seq_len(n)], prefix = prefix, tail = tail,
    valid = validity[seq_len(n)])
}
.decode_wii_dtm <- function(path, data, controller_order = NULL, wii_variant = "auto",
                            wii_extension = "raw", wii_key = NULL, aliases = TRUE) {
  wii_variant <- match.arg(wii_variant, c(
    "auto", "hid", "hid-prefix8", "hid-nomarker", "serialized", "mixed-hid", "mixed-hid-nomarker",
    "mixed-hid-connected"
  ))
  wii_extension <- match.arg(wii_extension, c("raw", "nunchuk", "classic"))
  mask <- as.integer(data[12L])
  if (bitwAnd(mask, 15L)) {
    if (!is.null(controller_order))
      stop("controller_order cannot assign mixed GC/Wii polls; inspect device and physical_port in polls()")
    revision <- paste(sprintf("%02x", as.integer(data[210:229])), collapse = "")
    if (wii_variant == "mixed-hid" || (wii_variant == "auto" &&
      revision == "7804f388aeb075266ae8c363e0932c355ba6ed5e"))
      return(.decode_dtm_mixed_hid(path, data, wii_extension, wii_key, aliases = aliases))
    if (wii_variant == "mixed-hid-nomarker" || (wii_variant == "auto" &&
      revision %in% .dtm_native_mixed_revisions))
      return(.decode_dtm_mixed_hid(path, data, wii_extension, wii_key, native = TRUE, aliases = aliases))
    if (wii_variant == "mixed-hid-connected")
      return(.decode_dtm_mixed_hid(path, data, wii_extension, wii_key, connected = TRUE, aliases = aliases))
    stop(
      path, ": mixed controller framing requires a verified Dolphin revision, ",
      "an explicit mixed-hid/mixed-hid-nomarker variant, or an explicit mixed-hid-connected assumption"
    )
  }
  ports <- which(bitwAnd(mask, bitwShiftL(1L, 4:7)) != 0L)
  if (!length(ports)) stop(path, ": no Wii Remote ports enabled")
  body <- data[-seq_len(256L)]
  modes <- if (wii_variant == "auto") c("hid", "hid-prefix8", "hid-nomarker", "serialized") else wii_variant
  candidates <- lapply(modes, function(mode) .wii_packet_index(
    body,
    if (mode == "hid-prefix8") 8L else 0L, mode == "serialized", mode == "hid-nomarker"
  ))
  valid <- which(!vapply(candidates, is.null, logical(1)))
  if (!length(valid)) stop(path, ": incomplete or unrecognised Wii Remote record; no bytes were dropped")
  if (length(valid) > 1L && length(body)) stop(path, ": ambiguous Wii framing; select wii_variant explicitly")
  index <- candidates[[valid[1L]]]
  variant <- modes[valid[1L]]
  n <- length(index$start)
  if (length(index$tail)) warning(path, ": retained ", length(index$tail),
    " bytes from an incomplete final Wii poll in source_tail",
    call. = FALSE
  )
  packets <- matrix(as.raw(0), n, if (n) max(index$length) else 0L)
  for (j in seq_len(ncol(packets))) {
    rows <- which(index$length >= j)
    packets[rows, j] <- body[index$start[rows] + j - 1L]
  }
  bytes <- matrix(as.integer(packets), n, ncol(packets))
  revision <- paste(sprintf("%02x", as.integer(data[210:229])), collapse = "")
  issues <- rep(NA_character_, n)
  if (variant != "serialized") {
    for (i in which(!index$valid)) {
      issues[i] <- if (all(packets[i, seq_len(index$length[i])] == as.raw(0)))
        "zero_filled_report" else "invalid_hid_report"
    }
    # Dolphin 5.0 / 5.0-424 TASInputDlg::GetValues cleared the report buffer,
    # rather than the IR field, before writing extended IR coordinates.
    # The HID header, buttons, and acceleration were overwritten. Keep these
    # reports unobserved: the original controls cannot be reconstructed.
    # Source: ac267a29405ae768037a8774b84b805a4180d1af and
    # 0015d2e86b76772a57fb4554c84c4b47adce341e, DolphinWX/TASInputDlg.cpp.
    if (variant %in% c("hid", "hid-prefix8") && revision %in% c(
      "ac267a29405ae768037a8774b84b805a4180d1af",
      "0015d2e86b76772a57fb4554c84c4b47adce341e"
    ) && ncol(packets) >= 7L) {
      rows <- which(!index$valid & index$length == 19L)
      for (i in rows) if (all(packets[i, 1:7] == as.raw(255)))
        issues[i] <- "legacy_tas_ir_overwrite_pattern"
    }
  }
  # Newer Dolphin report buffers begin with the report ID. Add the historical
  # HID marker only to the decoding view; poll_bytes retains the exact source.
  if (variant == "hid-nomarker") bytes <- cbind(rep.int(161L, n), bytes)
  keys <- c(
    "dpad_left", "dpad_right", "dpad_down", "dpad_up", "start",
    "wii_two", "wii_one", "b", "a", "select", "wii_home"
  )
  values <- matrix(FALSE, n, length(keys), dimnames = list(NULL, keys))
  channels <- list()
  add <- function(name, rows, x) {
    if (is.null(channels[[name]])) channels[[name]] <<- rep(NA_real_, n)
    channels[[name]][rows] <<- x
  }
  ext_bytes <- matrix(NA_integer_, n, 21L)
  ext_types <- rep(NA_integer_, n)
  core_present <- index$valid
  # Dolphin widens a shorter accelerometer value by repeating its lowest
  # bit in the added low bits (Common::ExpandValue in Common/BitUtils.h).
  expand9 <- function(x) x * 2L + bitwAnd(x, 1L)
  ir_extended <- function(rows, b) {
    for (k in seq_len(ncol(b) %/% 3L)) {
      j <- (k - 1L) * 3L
      add(paste0("ir", k, "_x"), rows, b[, j + 1L] + bitwAnd(bitwShiftR(b[, j + 3L], 4L), 3L) * 256L)
      add(paste0("ir", k, "_y"), rows, b[, j + 2L] + bitwShiftR(b[, j + 3L], 6L) * 256L)
      add(paste0("ir", k, "_size"), rows, bitwAnd(b[, j + 3L], 15L))
    }
  }
  ir_basic <- function(rows, b) {
    for (pair in 0:1) {
      j <- pair * 5L
      k <- pair * 2L
      add(paste0("ir", k + 1L, "_x"), rows, b[, j + 1L] + bitwAnd(bitwShiftR(b[, j + 3L], 4L), 3L) * 256L)
      add(paste0("ir", k + 1L, "_y"), rows, b[, j + 2L] + bitwShiftR(b[, j + 3L], 6L) * 256L)
      add(paste0("ir", k + 2L, "_x"), rows, b[, j + 4L] + bitwAnd(b[, j + 3L], 3L) * 256L)
      add(paste0("ir", k + 2L, "_y"), rows, b[, j + 5L] + bitwAnd(bitwShiftR(b[, j + 3L], 2L), 3L) * 256L)
    }
  }
  if (variant != "serialized") {
    report <- if (n) bytes[, 2L] else integer()
    for (id in unique(report)) {
      rows <- which(report == id & index$valid)
      if (!length(rows)) next
      b <- bytes[rows, , drop = FALSE]
      if (!id %in% c(0L, 61L)) {
        word <- b[, 3L] + 256L * b[, 4L]
        for (k in seq_along(keys)) values[rows, k] <- bitwAnd(word, bitwShiftL(1L, c(0:4, 8:12, 15)[k])) != 0L
      } else core_present[rows] <- FALSE
      if (id %in% c(49L, 51L, 53L, 55L)) {
        add("accel_x", rows, b[, 5L] * 4L + bitwAnd(bitwShiftR(b[, 3L], 5L), 3L))
        add("accel_y", rows, expand9(b[, 6L] * 2L + bitwAnd(bitwShiftR(b[, 4L], 5L), 1L)))
        add("accel_z", rows, expand9(b[, 7L] * 2L + bitwAnd(bitwShiftR(b[, 4L], 6L), 1L)))
      }
      if (id == 51L) ir_extended(rows, b[, 8:19, drop = FALSE])
      if (id == 54L) ir_basic(rows, b[, 5:14, drop = FALSE])
      if (id == 55L) ir_basic(rows, b[, 8:17, drop = FALSE])
      # Interleaved reports contain only one accelerometer axis and half the IR
      # field. Keep those observations separate instead of joining unknown ports.
      if (id %in% c(62L, 63L)) {
        add(if (id == 62L) "accel_x" else "accel_y", rows, b[, 5L] * 4L + 3L * bitwAnd(b[, 5L], 1L))
        add("accel_z_fragment", rows, bitwAnd(bitwShiftR(b[, 3L], 5L), 3L) + bitwAnd(bitwShiftR(b[, 4L], 5L), 3L) * 4L)
        for (j in 1:18) add(paste0("ir_fragment_byte", j), rows, b[, j + 5L])
      }
      start <- switch(as.character(id),
        `50` = 5L,
        `52` = 5L,
        `53` = 8L,
        `54` = 15L,
        `55` = 18L,
        `61` = 3L,
        NULL
      )
      if (!is.null(start)) {
        count <- .wii_hid_sizes[as.character(id)] - start + 1L
        ext_bytes[rows, seq_len(count)] <- b[, seq.int(start, start + count - 1L), drop = FALSE]
      }
    }
    add("report_id", seq_len(n), report)
    if (wii_extension != "raw")
      ext_types[rowSums(!is.na(ext_bytes)) >= 6L] <- if (wii_extension == "nunchuk") 1L else 2L
    if (!is.null(wii_key)) {
      if (!is.numeric(wii_key) || length(wii_key) != 16L || anyNA(wii_key) ||
        any(wii_key < 0 | wii_key > 255 | wii_key != as.integer(wii_key)))
        stop("wii_key must contain eight ft bytes followed by eight sb bytes")
      for (j in seq_len(ncol(ext_bytes))) {
        rows <- which(!is.na(ext_bytes[, j]))
        k <- (j - 1L) %% 8L + 1L
        ext_bytes[rows, j] <- bitwXor((ext_bytes[rows, j] - wii_key[k]) %% 256L, as.integer(wii_key[k + 8L]))
      }
    }
  } else {
    report <- rep(NA_integer_, n)
    for (flags in unique(if (n) bytes[, 1L] else integer())) {
      rows <- which(bytes[, 1L] == flags)
      b <- bytes[rows, , drop = FALSE]
      has_buttons <- bitwAnd(flags, 1L) != 0L
      has_accel <- bitwAnd(flags, 2L) != 0L
      ext <- flags %/% 16L
      ext_types[rows] <- ext
      p <- 2L
      if (has_buttons) {
        button_keys <- c("a", "b", "start", "select", "wii_one", "wii_two", "wii_home")
        for (j in 0:6) values[rows, button_keys[j + 1L]] <- bitwAnd(b[, p], bitwShiftL(1L, j)) != 0L
        for (j in 0:3) {
          values[rows, c("dpad_up", "dpad_down", "dpad_left", "dpad_right")[j + 1L]] <-
            bitwAnd(b[, p + 1L], bitwShiftL(1L, j)) != 0L
        }
        p <- p + 2L
      }
      # Omitted serialised fields have documented default values.
      if (has_accel) {
        if (has_buttons) p <- p - 1L
        low <- bitwShiftR(b[, p], 4L)
        add("accel_x", rows, b[, p + 1L] * 4L + bitwAnd(low, 3L))
        add("accel_y", rows, expand9(b[, p + 2L] * 2L + bitwAnd(bitwShiftR(low, 2L), 1L)))
        add("accel_z", rows, expand9(b[, p + 3L] * 2L + bitwAnd(bitwShiftR(low, 3L), 1L)))
        p <- p + 4L
      } else {
        add("accel_x", rows, 512)
        add("accel_y", rows, 512)
        add("accel_z", rows, 616)
      }
      if (bitwAnd(flags, 4L) != 0L) {
        ir_extended(rows, b[, p:(p + 11L), drop = FALSE])
        p <- p + 12L
      } else for (j in 1:4) {
        add(paste0("ir", j, "_x"), rows, 1023)
        add(paste0("ir", j, "_y"), rows, 1023)
        add(paste0("ir", j, "_size"), rows, 15)
      }
      if (bitwAnd(flags, 8L) != 0L) {
        for (j in 0:2) {
          axis <- c("pitch", "roll", "yaw")[j + 1L]
          add(paste0("gyro_", axis), rows, b[, p + 2L * j] + bitwAnd(b[, p + 2L * j + 1L], 63L) * 256L)
          add(paste0("gyro_", axis, "_slow"), rows, as.integer(bitwAnd(b[, p + 2L * j + 1L], 128L) != 0L))
        }
        p <- p + 6L
      }
      if (ext > 0L) {
        count <- if (ext == 8L) 1L else if (ext == 9L) 4L else 6L
        ext_bytes[rows, seq_len(count)] <- b[, p:(p + count - 1L), drop = FALSE]
      }
    }
    add("extension_type", seq_len(n), ext_types)
  }
  # Raw extension bytes remain available even when a known device is decoded.
  for (j in which(colSums(!is.na(ext_bytes)) > 0L)) add(paste0("extension_byte", j), seq_len(n), ext_bytes[, j])
  # Keep the device-level states alongside the shared control identities.
  source_buttons <- as.data.frame(values)
  names(source_buttons) <- paste0("wii_remote_", names(source_buttons))
  extra <- list()
  calibration <- list()
  press <- function(key, rows, state) {
    if (key %in% colnames(values)) {
      values[rows, key] <<- values[rows, key] | state
    } else {
      if (is.null(extra[[key]])) extra[[key]] <<- rep(FALSE, n)
      extra[[key]][rows] <<- state
    }
  }
  for (type in intersect(c(1L, 2L), unique(ext_types))) {
    rows <- which(ext_types == type)
    b <- ext_bytes[rows, 1:6, drop = FALSE]
    if (type == 1L) {
      press("c", rows, bitwAnd(b[, 6L], 2L) == 0L)
      press("z", rows, bitwAnd(b[, 6L], 1L) == 0L)
      add("nunchuk_x", rows, b[, 1L])
      add("nunchuk_y", rows, b[, 2L])
      for (j in 1:3) {
        add(
          paste0("nunchuk_accel_", c("x", "y", "z")[j]), rows,
          b[, j + 2L] * 4L + bitwAnd(bitwShiftR(b[, 6L], j * 2L), 3L)
        )
      }
      calibration$left <- list(x = "nunchuk_x", y = "nunchuk_y", center = c(128, 128), scale = c(128, 128))
    } else {
      word <- b[, 5L] + b[, 6L] * 256L
      mapping <- c(`1` = "r1", `2` = "start", `3` = "wii_home", `4` = "select", `5` = "l1", `6` = "dpad_down",
        `7` = "dpad_right", `8` = "dpad_up", `9` = "dpad_left", `10` = "r2", `11` = "x", `12` = "a", `13` = "y",
        `14` = "b", `15` = "l2")
      for (j in seq_along(mapping)) {
        state <- bitwAnd(word, bitwShiftL(1L, as.integer(names(mapping)[j]))) == 0L
        key <- unname(mapping[j])
        source_key <- paste0("wii_classic_", key)
        source_buttons[[source_key]] <- rep(NA, n)
        source_buttons[[source_key]][rows] <- state
        press(key, rows, state)
      }
      add("classic_left_x", rows, bitwAnd(b[, 1L], 63L))
      add("classic_left_y", rows, bitwAnd(b[, 2L], 63L))
      add("classic_right_x", rows,
        bitwShiftR(b[, 1L], 6L) * 8L + bitwShiftR(b[, 2L], 6L) * 2L + bitwShiftR(b[, 3L], 7L))
      add("classic_right_y", rows, bitwAnd(b[, 3L], 31L))
      add("classic_ltrigger", rows, bitwAnd(bitwShiftR(b[, 3L], 5L), 3L) * 8L + bitwShiftR(b[, 4L], 5L))
      add("classic_rtrigger", rows, bitwAnd(b[, 4L], 31L))
      calibration$left <- list(x = "classic_left_x", y = "classic_left_y", center = c(32, 32), scale = c(32, 32))
      calibration$right <- list(x = "classic_right_x", y = "classic_right_y", center = c(16, 16), scale = c(16, 16))
    }
  }
  # A recording that switches extension families needs per-observation axes.
  if (all(c(1L, 2L) %in% ext_types)) {
    for (axis in c("x", "y")) {
      normalized <- channels[[paste0("nunchuk_", axis)]]
      normalized <- (normalized - 128) / 128
      classic <- which(ext_types == 2L)
      normalized[classic] <- (channels[[paste0("classic_left_", axis)]][classic] - 32) / 32
      channels[[paste0("extension_left_", axis)]] <- normalized
    }
    calibration$left <- list(x = "extension_left_x", y = "extension_left_y", center = c(0, 0), scale = c(1, 1))
  }
  if (length(extra)) values <- cbind(values, do.call(cbind, extra))
  if (!all(core_present)) add("core_present", seq_len(n), as.integer(core_present))
  numeric_values <- if (length(channels)) do.call(cbind, channels) else matrix(numeric(), n, 0L)
  assignment <- if (length(ports) > 1L && is.null(controller_order)) "unassigned" else "single enabled controller"
  if (variant != "serialized" && any(!index$valid)) {
    assignment <- "unassigned"
    warning(path, ": retained ", sum(!index$valid),
      " unrecognised Wii reports as unobserved polls; poll_bytes preserves their source data", call. = FALSE)
  }
  order <- controller_order
  if (!is.null(order)) {
    if (!is.numeric(order) || anyNA(order) || any(order != as.integer(order)) || anyDuplicated(order) ||
      !length(order) || any(!order %in% ports) || n %% length(order))
      stop("controller_order must contain distinct enabled Wii Remote ports and divide the poll count")
    if (any(!index$valid) && length(order) > 1L)
      stop(
        "unobserved Wii reports prevent grouping into complete controller cycles; ",
        "use polls() without controller_order"
      )
    order <- as.integer(order)
    if (all(index$valid)) assignment <- "caller-supplied repeating order; not stored in DTM"
  } else if (length(ports) == 1L) order <- ports
  players <- if (length(order)) length(order) else 1L
  rows <- if (length(order)) n %/% players else n
  inputs <- array(FALSE, c(rows, players, ncol(values)))
  analog <- vector("list", players)
  for (p in seq_len(players)) {
    take <- if (!n) integer() else if (players > 1L) seq.int(p, n, by = players) else seq_len(n)
    inputs[, p, ] <- values[take, , drop = FALSE]
    analog[[p]] <- numeric_values[take, , drop = FALSE]
  }
  header <- list(
    `_format` = "dtm", Platform = "Wii", romId = rawToChar(data[5:10]), romMD5 = .dtm_disc_md5(data),
    frameCount = as.character(.read_u64_le(data, 13L)), inputCount = as.character(.read_u64_le(data, 21L)),
    rerecordCount = as.character(.read_u32_le(data, 45L)), availablePollCount = as.character(n),
    dtmVariant = paste0("wii-", variant), sourceRevision = revision, controllerMask = mask, enabledPorts = ports,
    controllerPorts = if (length(order)) order else integer(), controllerAssignment = assignment,
    observationUnit = if (players > 1L) "controller polling cycle" else "Wii Remote poll",
    extensionDecoding = if (variant == "serialized") "stored extension type" else wii_extension,
    extensionKeySupplied = !is.null(wii_key)
  )
  header$pollCountDifference <- as.character(.read_u64_le(data, 21L) - n)
  header$inputCountRole <- "emulator input statistic"
  movie <- .new_named_movie(header, integer(rows), inputs, colnames(values), path,
    analog = analog,
    stick_calibration = if (length(calibration)) rep(list(calibration), players) else NULL
  )
  movie$source_tail <- index$tail
  movie$poll_bytes <- packets
  movie$poll_lengths <- index$length
  movie$poll_fields <- data.frame(
    report_id = report, extension_type = ext_types,
    valid_report = index$valid, report_issue = issues,
    source_offset = 254 + index$start - index$prefix
  )
  movie$poll_fields <- cbind(movie$poll_fields, source_buttons)
  if (index$prefix) {
    prefix <- matrix(as.raw(0), n, 8L)
    for (j in 1:8) prefix[, j] <- body[index$start - 10L + j]
    movie$poll_prefix_bytes <- prefix
  }
  movie
}
