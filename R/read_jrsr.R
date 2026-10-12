# JPC-RR archive and event specifications:
# https://tasvideos.org/EmulatorResources/JPC/JRSRFormat
# https://github.com/antogerva/jpcrr/blob/master/src/main/java/org/jpc/emulator/EventRecorder.java
.jrsr_components <- function(line) {
  if (!grepl("[()\\\\]",line)) return(strsplit(trimws(line),"[ \\t\u1680\u180e\u2000-\u200a\u2028\u205f\u3000]+",perl=TRUE)[[1]])
  chars <- strsplit(line,"",fixed=TRUE)[[1]]; depth <- 0L; escaped <- FALSE
  out <- character(); token <- character()
  flush <- function() { if(length(token)) { out <<- c(out,paste0(token,collapse="")); token <<- character() } }
  for(ch in chars) {
    if(escaped) { token <- c(token,ch); escaped <- FALSE; next }
    if(ch=="\\") {escaped <- TRUE; next}
    if(ch=="(") { if(depth==0L) flush() else token<-c(token,ch); depth<-depth+1L; next }
    if(ch==")") { if(depth==0L) stop("Unbalanced JRSR component",call.=FALSE); depth<-depth-1L; if(depth==0L)flush() else token<-c(token,ch); next }
    if(depth==0L && grepl("^[ \\t\u1680\u180e\u2000-\u200a\u2028\u205f\u3000]$",ch,perl=TRUE)) flush() else token<-c(token,ch)
  }
  if(depth!=0L || escaped) stop("Incomplete JRSR component",call.=FALSE)
  flush(); out
}

.decode_jrsr <- function(path) {
  lines <- readLines(path,warn=FALSE,encoding="UTF-8")
  # JRSR additionally recognises Unicode record separators as line endings.
  lines <- unlist(strsplit(lines,"[\u001c-\u001e\u0085\u2029]",perl=TRUE),use.names=FALSE)
  if(!length(lines)||lines[1L]!="JRSR") stop("Invalid JRSR magic",call.=FALSE)
  starts <- which(startsWith(lines,"!BEGIN ") | startsWith(lines,"!BEGIN\t"))
  ends <- sort(c(starts[-1L]-1L,length(lines)))
  sections <- list()
  for(k in seq_along(starts)) {
    name <- sub("^!BEGIN[ \\t]+","",lines[starts[k]])
    block <- if(ends[k]>starts[k]) lines[seq.int(starts[k]+1L,ends[k])] else character()
    content <- block[startsWith(block,"+")]
    sections[[name]] <- substring(content,2L)
  }
  if(!"events" %in% names(sections)) stop("Missing JRSR events section",call.=FALSE)
  nonblank <- lines[nzchar(lines)]
  if(tail(nonblank,1L)!="!END") stop("Unclosed JRSR section",call.=FALSE)
  raw <- sections$events; raw <- raw[nzchar(trimws(raw))]
  parts <- lapply(raw,.jrsr_components)
  if(any(lengths(parts)<2L)) stop("Invalid JRSR event",call.=FALSE)
  n <- length(parts)
  timestamp_source <- vapply(parts,`[`,character(1),1L)
  times <- .computer_number(timestamp_source,"JRSR timestamp",0,2^53)
  classes <- vapply(parts,`[`,character(1),2L)
  args <- lapply(parts,function(x)x[-c(1L,2L)])
  kind <- vapply(args,function(x) if(length(x))x[1L] else "",character(1))
  value <- vapply(args,function(x) if(length(x)>1L)x[2L] else "",character(1))
  relative <- FALSE; previous <- 0
  for(i in seq_len(n)) {
    if(relative) times[i] <- times[i]+previous
    if(times[i]<previous || times[i]>2^53) stop("JRSR timestamps are unordered or exceed exact numeric range",call.=FALSE)
    previous <- times[i]
    if(classes[i]=="OPTION") {
      if(!kind[i] %in% c("RELATIVE","ABSOLUTE")) stop("Unknown JRSR timing option",call.=FALSE)
      relative <- kind[i]=="RELATIVE"
    }
  }
  keyboard <- classes=="org.jpc.emulator.peripheral.Keyboard"
  joystick <- classes=="org.jpc.modules.Joystick"
  has_joystick <- any(joystick)
  edge <- keyboard & kind=="KEYEDGE"
  codes <- sort(unique(.computer_number(value[edge],"JPC-RR key number",1,255)))
  keys <- if(length(codes)) paste0("jpcrr_key_",codes) else character()
  mouse <- any(keyboard & grepl("MOUSE",kind))
  pause <- any(keyboard & kind=="PAUSE")
  if(mouse) keys <- c(keys,c("mouse_left","mouse_right","mouse_middle","mouse_button_4","mouse_button_5"))
  if(pause) keys <- c(keys,"jpcrr_pause")
  if(has_joystick) keys <- c(keys,"a","b")
  np <- if(any(joystick & kind %in% c("BUTTONC","BUTTOND","AXISC","AXISD"))) 2L else 1L
  inputs <- array(FALSE,c(n,np,length(keys))); held <- matrix(FALSE,np,length(keys))
  ch <- c(if(mouse)c("mouse_dx","mouse_dy","mouse_wheel"),if(has_joystick)c("joystick_x_hold_ns","joystick_y_hold_ns"))
  analog <- lapply(seq_len(np),function(p)matrix(0,n,length(ch),dimnames=list(NULL,ch)))
  state_axes <- matrix(NA_real_,np,2L)
  commands <- integer(n)
  for(i in seq_len(n)) {
    if(pause) held[1L,match("jpcrr_pause",keys)] <- FALSE
    if(keyboard[i]) {
      k <- kind[i]
      if(k=="KEYEDGE") {
        at <- match(paste0("jpcrr_key_",value[i]),keys); held[1L,at] <- !held[1L,at]
      } else if(k=="MOUSEBUTTON") {
        number <- .computer_number(value[i],"JPC-RR mouse button",0,4)
        at <- match(c("mouse_left","mouse_right","mouse_middle","mouse_button_4","mouse_button_5")[number+1L],keys)
        held[1L,at] <- !held[1L,at]
      } else if(k %in% c("XMOUSEMOTION","YMOUSEMOTION","ZMOUSEMOTION")) {
        analog[[1]][i,match(c(XMOUSEMOTION="mouse_dx",YMOUSEMOTION="mouse_dy",ZMOUSEMOTION="mouse_wheel")[[k]],ch)] <- .computer_number(value[i],"JPC-RR mouse motion")
      } else if(k=="PAUSE") held[1L,match("jpcrr_pause",keys)] <- TRUE
      else stop("Unsupported JPC-RR keyboard event: ",k,call.=FALSE)
    } else if(joystick[i]) {
      k <- kind[i]; index <- match(substr(k,nchar(k),nchar(k)),LETTERS[1:4]); p <- (index-1L)%/%2L+1L
      if(is.na(index)) stop("Invalid JPC-RR joystick event",call.=FALSE)
      if(startsWith(k,"BUTTON")) held[p,match(c("a","b")[(index-1L)%%2L+1L],keys)] <- .computer_number(value[i],"JPC-RR joystick button",0,1)!=0
      else if(startsWith(k,"AXIS")) state_axes[p,(index-1L)%%2L+1L] <- .computer_number(value[i],"JPC-RR joystick hold time",1)
      else stop("Unsupported JPC-RR joystick event",call.=FALSE)
    } else if(classes[i]=="org.jpc.emulator.PC$ResetButton") commands[i] <- 1L
    inputs[i,,] <- held
    if(has_joystick)for(p in seq_len(np)) analog[[p]][i,match(c("joystick_x_hold_ns","joystick_y_hold_ns"),ch)] <- state_axes[p,]
  }
  if(mouse && np>1L)for(p in 2:np) analog[[p]] <- analog[[p]][,!startsWith(colnames(analog[[p]]),"mouse_"),drop=FALSE]
  header <- list(format="jrsr",emulator="JPC-RR",observation_unit="event",time_unit="nanosecond",
                 keyboard_mouse_player=1L,initialization=sections[grepl("^initialization",names(sections))],
                 metadata=lapply(sections$header,.jrsr_components),
                 initial_joystick_axes="Unspecified until the first axis event; recorded hold times remain in nanoseconds")
  header[["_format"]] <- "jrsr"
  movie <- .new_named_movie(header,commands,inputs,keys,path,analog=analog,
                            kinds=ifelse(grepl("^jpcrr_",keys),"keyboard",ifelse(grepl("^mouse_",keys),"peripheral","button")))
  movie$events <- data.frame(timestamp_source=timestamp_source,timestamp_ns=times,
                            event_class=classes,operation=kind,stringsAsFactors=FALSE)
  movie$events$arguments <- I(args)
  movie$events$source <- raw
  movie$event_sections <- sections[!names(sections) %in% c("events","savestate","manifest")]
  movie
}
