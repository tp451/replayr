# Mednafen-rr MCM header and AddJoy serializer; controller bit order follows
# the input descriptors in src/{pce,pcfx,lynx,ngp,wswan,nes,sms}.
# https://github.com/TASEmulators/mednafen-rr
# https://tasvideos.org/EmulatorResources/Mednafen/MCM
.decode_mcm <- function(path) {
  data <- readBin(path, "raw", n = file.info(path)$size)
  if (length(data) < 256L || !identical(data[1:8], charToRaw("MDFNMOVI"))) stop(path, ": not an MCM file")
  version <- .read_u32_le(data, 12L)
  if (version != 1L) stop(path, ": unsupported MCM version ", version)
  system <- tolower(.read_cstring(data, 116L, 5L))
  descriptor <- switch(system,
    pce = list(ports=5L, bytes=2L, keys=c("a","b","select","start","dpad_up","dpad_right","dpad_down","dpad_left",
                                         "pce_iii","pce_iv","pce_v","pce_vi","pce_six_button_mode")),
    pcfx = list(ports=2L, bytes=2L, keys=c("a","b","pcfx_iii","pcfx_iv","pcfx_v","pcfx_vi","select","start",
                                          "dpad_up","dpad_right","dpad_down","dpad_left")),
    lynx = list(ports=1L, bytes=2L, keys=c("a","b","lynx_option_2","lynx_option_1","dpad_left","dpad_right","dpad_up","dpad_down","start")),
    wswan = list(ports=1L, bytes=2L, keys=c("wswan_x1","wswan_x2","wswan_x3","wswan_x4",
                                           "wswan_y1","wswan_y2","wswan_y3","wswan_y4","start","a","b")),
    ngp = list(ports=1L, bytes=1L, keys=c("dpad_up","dpad_down","dpad_left","dpad_right","a","b","ngp_option")),
    nes = list(ports=4L, bytes=1L, keys=c("a","b","select","start","dpad_up","dpad_down","dpad_left","dpad_right")),
    sms = list(ports=2L, bytes=1L, keys=c("dpad_up","dpad_down","dpad_left","dpad_right","b","a","start")),
    NULL)
  if (is.null(descriptor)) stop(path, ": unsupported MCM system ", system)
  width <- 1L + descriptor$ports * descriptor$bytes
  body <- data[-seq_len(256L)]
  tail_size <- length(body) %% width
  tail <- if (tail_size) utils::tail(body, tail_size) else raw()
  if (tail_size) {
    warning(path, ": MCM ends with ", tail_size, " byte(s) of an incomplete frame; retaining them in source_tail", call. = FALSE)
    body <- utils::head(body, length(body) - tail_size)
  }
  packets <- matrix(as.integer(body), ncol = width, byrow = TRUE)
  keys <- descriptor$keys
  inputs <- array(FALSE, c(nrow(packets), descriptor$ports, length(keys)))
  for (p in seq_len(descriptor$ports)) {
    first <- 2L + (p - 1L) * descriptor$bytes
    words <- packets[, first]
    if (descriptor$bytes == 2L) words <- words + 256L * packets[, first+1L]
    inputs[, p, ] <- .legacy_bits(words, seq_along(keys) - 1L)
  }
  header <- list(`_format`="mcm", system=toupper(system), version=version,
                 emuVersion=.read_u32_le(data, 8L), romMD5Bytes=data[17:48],
                 romFilename=.read_cstring(data,48L,64L), rerecordCount=.read_u32_le(data,112L),
                 author=.read_cstring(data,121L,32L), commandEncoding="Mednafen command: reset=1, power=2")
  movie <- .new_named_movie(header, packets[,1L], inputs, keys, path)
  movie$source_tail <- tail
  movie$source_packets <- packets
  movie
}
