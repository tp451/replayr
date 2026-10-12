# Hourglass format: https://tasvideos.org/EmulatorResources/Hourglass/WTF
# Each frame lists at most eight Windows virtual-key codes, terminated by zero.
.decode_wtf <- function(path) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 1024L || !identical(data[1:4], as.raw(c(0x66, 0x54, 0x77, 2))))
    stop("Invalid Hourglass WTF/HGM header", call. = FALSE)
  if ((length(data) - 1024L) %% 8L) stop("Truncated Hourglass input record", call. = FALSE)
  n <- (length(data) - 1024L) %/% 8L
  source <- matrix(as.integer(data[-seq_len(1024L)]), nrow = n, ncol = 8L, byrow = TRUE)
  active <- source != 0L
  if (n) for (i in 2:8) active[, i] <- active[, i] & active[, i-1L]
  codes <- sort(unique(source[active])); keys <- sprintf("windows_vk_%02x", codes)
  inputs <- array(FALSE, c(n, 1L, length(keys)))
  for (k in seq_along(codes)) inputs[, 1L, k] <- rowSums(source == codes[k] & active) > 0L
  names <- sprintf("Windows VK 0x%02X", codes)
  printable <- (codes >= 48 & codes <= 57) | (codes >= 65 & codes <= 90)
  names[printable] <- paste("Keyboard", intToUtf8(codes[printable], multiple = TRUE))
  special <- c(`8`="Backspace", `9`="Tab", `13`="Return", `16`="Shift", `17`="Control",
               `18`="Alt", `27`="Escape", `32`="Space", `37`="Left", `38`="Up", `39`="Right", `40`="Down")
  idx <- match(as.character(codes), names(special)); names[!is.na(idx)] <- paste("Keyboard", special[idx[!is.na(idx)]])
  declared <- .read_u32_le(data, 4L)
  .computer_count_note(declared, n, "Hourglass header")
  header <- list(format="wtf", emulator="Hourglass", observation_unit="frame",
                 declared_frame_count=declared, frame_count=n, rerecord_count=.read_u32_le(data, 8L),
                 keyboard_layout=.read_cstring(data, 12L, 8L), fps=.read_u32_le(data,20L)-1,
                 initial_time=.read_u32_le(data,24L)-1, executable_crc32=.read_u32_le(data,28L),
                 executable_size=.read_u32_le(data,32L), executable=.read_cstring(data,36L,48L),
                 revision=.read_u32_le(data,148L), arguments=.read_cstring(data,152L,160L),
                 clock_checks=vapply(0:15, function(i) .read_u32_le(data,84L+4L*i), numeric(1)))
  header[["_format"]] <- "wtf"
  movie <- .new_named_movie(header, integer(n), inputs, keys, path,
                            names=names, kinds=rep("keyboard", length(keys)))
  movie$source_keycodes <- source
  movie$source_header <- data[seq_len(1024L)]
  movie
}
