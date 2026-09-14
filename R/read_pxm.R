# PCSX-rerecording .pxm movie format. Reference:
# https://tasvideos.org/EmulatorResources/PCSX/PXM and the PCSX-rr source.
#
# Header fields used here (0-based offsets):
#   0x00  magic "PXM "       0x04  version (2)
#   0x0C  movie flags        0x0E/0x0F controller types for ports 1/2
#   0x10  frame count        0x14 rerecord count
#   0x2C  controller-data offset
#   0x30  author byte length 0x34 author bytes
#
# Each frame contains one record per configured controller followed by one
# command byte. Standard controllers use two bytes; analog controllers use
# those same two button bytes followed by four unsigned stick-axis bytes.

.PXM_CONTROLLER_WIDTH <- c(
  `0` = 0L,  # disconnected
  `1` = 4L,  # mouse (not decoded here)
  `2` = NA,  # NegCon
  `3` = NA,  # Konami gun
  `4` = 2L,  # standard digital controller
  `5` = 6L,  # analog joystick
  `6` = NA,  # Namco GunCon
  `7` = 6L   # analog controller / DualShock
)

# Bit 0..15 in the active-high PSX button word -> universal slot.
.PSX_BIT_TO_UNI <- c(
  6L, 31L, 32L, 5L,
  4L, 1L, 3L, 2L,
  29L, 30L, 11L, 12L,
  9L, 8L, 7L, 10L
)

.pxm_decode_buttons <- function(inputs, frame, player, word) {
  for (bit in 0:15) {
    if (bitwAnd(word, bitwShiftL(1L, bit)) == 0L) next
    slot <- .PSX_BIT_TO_UNI[bit + 1L]
    if (!is.na(slot)) inputs[frame, player, slot] <- TRUE
  }
  inputs
}

.pxm_quantise_sticks <- function(inputs, frame, player, raw_axes,
                                 deadzone = 32L) {
  lx <- as.integer(raw_axes[1L]) - 128L
  ly <- 128L - as.integer(raw_axes[2L])
  rx <- as.integer(raw_axes[3L]) - 128L
  ry <- 128L - as.integer(raw_axes[4L])

  if (lx * lx + ly * ly >= deadzone * deadzone) {
    angle <- atan2(ly, lx)
    sector <- as.integer((angle + pi / 8) %/% (pi / 4)) %% 8L
    inputs[frame, player, .STICK_SECTOR_TO_UNI[sector + 1L]] <- TRUE
  }
  if (rx * rx + ry * ry >= deadzone * deadzone) {
    if (abs(rx) >= abs(ry)) {
      inputs[frame, player, if (rx > 0L) 17L else 18L] <- TRUE
    } else {
      inputs[frame, player, if (ry > 0L) 20L else 19L] <- TRUE
    }
  }
  inputs
}

# Vectorized equivalent of .pxm_quantise_sticks: avoid copying the entire movie
# array for each frame of a long analog recording.
.pxm_stick_matrix <- function(axes, deadzone = 32L) {
  axes <- matrix(axes,ncol=4L)
  result <- matrix(FALSE, nrow(axes), 30L)
  lx <- axes[,1L]-128L; ly <- 128L-axes[,2L]
  rx <- axes[,3L]-128L; ry <- 128L-axes[,4L]
  active <- which(lx*lx+ly*ly >= deadzone*deadzone)
  if(length(active)) {
    sectors <- as.integer((atan2(ly[active],lx[active])+pi/8) %/% (pi/4)) %% 8L
    result[cbind(active,.STICK_SECTOR_TO_UNI[sectors+1L])] <- TRUE
  }
  active <- which(rx*rx+ry*ry >= deadzone*deadzone)
  if(length(active)) {
    slots <- ifelse(abs(rx[active])>=abs(ry[active]),
                    ifelse(rx[active]>0,17L,18L),ifelse(ry[active]>0,20L,19L))
    result[cbind(active,slots)] <- TRUE
  }
  result
}

#' Read a PCSX-rerecording .pxm movie file
#'
#' Reads standard digital and analog-controller PXM movies. Button input maps
#' to the 32-slot PSX universal layout, including L3/R3 on analog devices.
#' Standard digital pad reserved bits are counted in header metadata, not
#' interpreted as stick-click buttons. Analog sticks are quantised in the same
#' way as other replayr PSX readers. The final per-frame control byte is exposed
#' through `movie$commands`. Mouse, NegCon, and light-gun controller types are
#' rejected instead of being silently mis-decoded.
#'
#' @param path Path to a .pxm file.
#' @return A `replayr_movie` object.
#' @export
read_pxm <- function(path) {
  data <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(data) < 0x34L || !identical(data[1:4], charToRaw("PXM "))) {
    stop(path, ": not a PXM file")
  }
  version <- .read_u32_le(data, 4L)
  if (version != 2L) stop(path, ": unsupported PXM version ", version)

  flags <- as.integer(data[0x0CL + 1L])
  controller_types <- as.integer(data[c(0x0EL, 0x0FL) + 1L])
  n_frames_raw <- .read_u32_le(data, 0x10L)
  rerec <- .read_u32_le(data, 0x14L)
  controller_data_offset <- .read_u32_le(data, 0x2CL)
  author_length <- .read_u32_le(data, 0x30L)

  if (n_frames_raw > .Machine$integer.max) {
    stop(path, ": PXM frame count is too large for R")
  }
  n_frames <- as.integer(n_frames_raw)
  if (controller_data_offset < 0x34L || controller_data_offset > length(data)) {
    stop(path, ": invalid PXM controller-data offset ", controller_data_offset)
  }

  widths <- integer(2L)
  for (port in 1:2) {
    type <- controller_types[port]
    key <- as.character(type)
    if (!(key %in% names(.PXM_CONTROLLER_WIDTH)) ||
        is.na(.PXM_CONTROLLER_WIDTH[[key]])) {
      stop(path, ": unsupported PXM controller type ", type,
           " on port ", port)
    }
    if (type == 1L) {
      stop(path, ": PXM mouse input is not supported")
    }
    widths[port] <- .PXM_CONTROLLER_WIDTH[[key]]
  }
  active_ports <- which(widths > 0L)
  if (length(active_ports) == 0L) stop(path, ": PXM has no active controllers")

  stride <- sum(widths) + 1L
  required <- as.numeric(controller_data_offset) + as.numeric(n_frames) * stride
  if (required > length(data)) {
    stop(sprintf("%s: PXM controller data is truncated (need %.0f bytes, have %d)",
                 path, required, length(data)))
  }

  n_players <- max(active_ports)
  n_buttons <- 32L
  inputs <- .empty_inputs(n_frames, n_players, n_buttons)
  commands <- integer(n_frames)
  port_offsets <- c(0L, widths[1L])
  reserved_digital_bits <- integer(n_players)

  if (n_frames > 0L) {
    frame_off <- controller_data_offset + (seq_len(n_frames) - 1L) * stride
    for (port in active_ports) {
      off <- frame_off + port_offsets[port]
      words <- as.integer(data[off+1L])+256L*as.integer(data[off+2L])
      if(controller_types[port]==4L)
        reserved_digital_bits[port] <- sum(bitwAnd(words,2L)!=0L)+sum(bitwAnd(words,4L)!=0L)
      for(bit in 0:15) {
        # Standard digital pads have no stick-click buttons. PXM documents
        # bits 1/2 as unknown for type 4, not as L3/R3.
        if(controller_types[port]==4L && bit %in% c(1L,2L))next
        slot <- .PSX_BIT_TO_UNI[bit+1L]
        if(!is.na(slot))inputs[,port,slot] <- bitwAnd(words,2^bit)!=0L
      }
      if(controller_types[port] %in% c(5L,7L)) {
        axes <- vapply(3:6,function(k)as.integer(data[off+k]),integer(n_frames))
        stick <- .pxm_stick_matrix(axes)
        for(slot in 17:28)inputs[,port,slot] <- stick[,slot]
      }
    }
    commands <- as.integer(data[frame_off + sum(widths) + 1L])
  }

  author <- ""
  if (author_length > 0L) {
    author_end <- 0x34L + author_length
    if (author_end > length(data) || author_end > controller_data_offset) {
      stop(path, ": invalid PXM author length ", author_length)
    }
    author <- .read_cstring(data, 0x34L, author_length)
    Encoding(author) <- "UTF-8"
  }
  header <- list(
    "_format" = "pxm",
    version = as.character(version),
    emulatorVersion = as.character(.read_u32_le(data, 8L)),
    flags = sprintf("0x%x", flags),
    controllerType1 = as.character(controller_types[1L]),
    controllerType2 = as.character(controller_types[2L]),
    reservedDigitalPadBitCounts = reserved_digital_bits,
    rerecordCount = as.character(rerec),
    controllerDataOffset = as.character(controller_data_offset),
    author = author
  )
  .new_movie(
    header = header,
    commands = commands,
    inputs = inputs,
    source_path = path,
    button_mnemonics = universal_buttons()[seq_len(n_buttons)],
    button_names = universal_button_names()[seq_len(n_buttons)]
  )
}
