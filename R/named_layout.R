# Compact source-defined layouts for keyboards and additional peripherals.
# Existing registered controls keep their numeric IDs. Additional controls use
# their qualified key as a textual ID; there is no data-dependent numbering.
.new_named_movie <- function(header, commands, inputs, keys, source_path = NA_character_,
                             analog = NULL, names = NULL, kinds = NULL,
                             stick_calibration = NULL) {
  if (is.null(header[["_format"]]) && !is.null(header$format))
    header[["_format"]] <- header$format
  dims <- dim(inputs)
  if (!is.logical(inputs) || length(dims) != 3L || dims[2L] < 1L || anyNA(inputs))
    stop("inputs must be a logical observations x players x controls array without NA")
  if (!is.character(keys) || length(keys) != dims[3L] || anyNA(keys) ||
      any(!nzchar(keys)) || anyDuplicated(keys))
    stop("keys must identify each input column uniquely")
  if (length(commands) != dims[1L] || anyNA(commands))
    stop("commands must have one value per observation")
  if (is.null(analog)) analog <- .empty_analog(dims[1L], dims[2L])
  if (!is.list(analog) || length(analog) != dims[2L] ||
      any(!vapply(analog, function(x) is.matrix(x) && is.numeric(x) &&
        nrow(x) == dims[1L] && (ncol(x) == 0L ||
        (!is.null(colnames(x)) && !anyDuplicated(colnames(x)))), logical(1))))
    stop("analog must contain one named numeric matrix per player")
  if (!is.null(stick_calibration) && (!is.list(stick_calibration) ||
      length(stick_calibration) != dims[2L]))
    stop("stick_calibration must have one entry per player")
  layout <- .control_identity_layout(keys, names, kinds)
  structure(list(header=as.list(header), commands=as.integer(commands), inputs=inputs,
    source_path=source_path, button_mnemonics=layout$mnemonic, button_names=layout$name,
    analog=analog, analog_mode="raw", decoded_layout=layout,
    stick_calibration=stick_calibration), class="replayr_movie")
}

.control_identity_layout <- function(keys, names = NULL, kinds = NULL) {
  base <- .controller_registry()
  index <- match(keys, base$key)
  ids <- base$id[index]
  custom <- which(is.na(index))
  if (length(custom)) {
    ids <- as.character(ids)
    ids[custom] <- paste0("control:", keys[custom])
  }
  mnemonic <- base$mnemonic[index]
  mnemonic[custom] <- paste0("{", keys[custom], "}")
  labels <- base$name[index]
  labels[custom] <- gsub("_", " ", keys[custom], fixed = TRUE)
  types <- base$kind[index]
  types[custom] <- "button"
  if (!is.null(names)) {
    if (length(names) != length(keys) || anyNA(names)) stop("names must match keys")
    labels <- names
  }
  if (!is.null(kinds)) {
    if (length(kinds) != length(keys) || anyNA(kinds)) stop("kinds must match keys")
    types <- kinds
  }
  data.frame(id=ids,key=keys,mnemonic=mnemonic,name=labels,kind=types,
                       stringsAsFactors=FALSE)
}

.calibrated_stick_vectors <- function(movie, idx) {
  if (!is.null(movie$decoded_stick_vectors)) return(movie$decoded_stick_vectors[[idx]])
  specification <- movie$stick_calibration[[idx]]
  result <- list()
  if (is.null(specification)) return(result)
  channels <- analog_channels(movie,idx)
  for (side in intersect(names(specification),c("left","right"))) {
    s <- specification[[side]]
    if (!all(c(s$x,s$y) %in% colnames(channels)) || length(s$center)!=2L ||
        length(s$scale)!=2L || any(!is.finite(s$scale) | s$scale<=0))
      stop("Invalid source stick calibration")
    sign <- s$sign %||% c(1,1)
    if (length(sign)!=2L || any(!sign %in% c(-1,1))) stop("Invalid stick orientation")
    axes <- channels[,c(s$x,s$y),drop=FALSE]
    result[[side]] <- sweep(sweep(axes,2L,s$center,"-"),2L,s$scale/sign,"/")
  }
  result
}
