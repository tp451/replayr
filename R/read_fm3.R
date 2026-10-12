# FCEUX src/movie.cpp: LoadFM2_binarychunk, MovieRecord::parseBinary/parse.
# Source https://github.com/TASEmulators/fceux (GPL-2.0-or-later).
# FM3 stores an FM2 movie followed by editor project data; the length header
# bounds the input log. Binary logs start after a single pipe delimiter.
.decode_fm3 <- function(path) .decode_fceux_extended(path,"fm3")

.decode_fceux_extended <- function(path,format="fm2") {
  data<-readBin(path,"raw",file.info(path)$size)
  pipes<-which(data==as.raw(124L))
  starts<-pipes[pipes==1L | data[pmax(1L,pipes-1L)]%in%as.raw(c(10,13))]
  if(!length(starts))stop(path,": FCEUX input log delimiter is missing")
  first<-starts[1L]
  header_raw<-data[seq_len(first-1L)]
  if(any(header_raw==as.raw(0)))stop(path,": invalid FCEUX text header")
  header_text<-strsplit(rawToChar(header_raw),"\n",fixed=TRUE)[[1L]]
  header_text<-sub("\r$","",header_text)
  header<-list()
  for(line in header_text) {
    key<-sub("[ \t].*$","",line);value<-sub("^[^ \t]+[ \t]*","",line)
    if(nzchar(key))header[[key]]<-if(is.null(header[[key]]))value else paste(header[[key]],value,sep="\n")
  }
  header[["_format"]]<-format
  declared<-if(is.null(header$length))NULL else suppressWarnings(as.integer(header$length))
  if(!is.null(declared)&&(is.na(declared)||declared<0L))stop(path,": invalid FCEUX length header")
  four<-identical(header$fourscore,"1")
  ports<-if(four)rep(1L,4L)else as.integer(c(header$port0%||%"1",header$port1%||%"1"))
  if(anyNA(ports)||any(!ports%in%0:2))stop(path,": unsupported FCEUX controller type")
  active<-which(ports!=0L)
  binary<-identical(header$binary,"1")
  np<-max(1L,length(active))
  keys<-c(if(any(ports==1L))c("dpad_right","dpad_left","dpad_down","dpad_up","start","select","b","a"),
          if(any(ports==2L))c("gun_trigger","offscreen_shot"))
  keys<-as.character(keys)
  if(binary) {
    width<-1L+sum(c(0L,1L,12L)[ports+1L])
    available<-length(data)-first
    n<-if(is.null(declared))available%/%width else min(declared,available%/%width)
    if(!is.null(declared)&&n<declared)warning(path,": input log ends before its declared length",call.=FALSE)
    bytes<-if(n)matrix(as.integer(data[first+seq_len(n*width)]),n,width,byrow=TRUE)else matrix(integer(),0,width)
    commands<-bytes[,1L]
    consumed<-first+n*width
    remainder<-if(consumed<length(data))data[seq.int(consumed+1L,length(data))]else raw()
    if(is.null(declared)&&length(remainder))warning(path,": retained partial final input record",call.=FALSE)
  } else {
    endings<-which(data==as.raw(10));endings<-endings[endings>=first]
    if(length(data)&&data[length(data)]!=as.raw(10))endings<-c(endings,length(data))
    if(!is.null(declared))endings<-head(endings,declared)
    end<-if(length(endings))tail(endings,1L)else first-1L
    body<-if(end>=first)data[first:end]else raw()
    if(any(body==as.raw(0)))stop(path,": binary project data encountered before declared movie length")
    lines<-if(length(body))strsplit(rawToChar(body),"\n",fixed=TRUE)[[1L]]else character()
    lines<-sub("\r$","",lines);lines<-lines[nzchar(lines)]
    if(any(!startsWith(lines,"|")))stop(path,": non-input row within FCEUX log")
    parts<-strsplit(lines,"|",fixed=TRUE)
    n<-length(lines)
    commands<-vapply(parts,function(x)as.integer(x[2L]),integer(1))
    if(anyNA(commands))stop(path,": invalid FCEUX command")
    remainder<-if(end<length(data))data[seq.int(end+1L,length(data))]else raw()
  }
  inputs<-array(FALSE,c(n,np,length(keys)))
  analog<-.empty_analog(n,np)
  hit_source<-vector("list",np)
  cursor<-2L
  for(port in seq_along(ports)) {
    type<-ports[port]
    if(type==0L)next
    player<-match(port,active)
    if(type==1L) {
      if(binary) {
        for(bit in 0:7)inputs[,player,match(c("a","b","select","start","dpad_up","dpad_down","dpad_left","dpad_right")[bit+1L],keys)]<-bitwAnd(bytes[,cursor],bitwShiftL(1L,bit))!=0L
        cursor<-cursor+1L
      } else {
        fields<-vapply(parts,function(x)if(length(x)>=port+2L)x[port+2L]else "",character(1))
        if(any(nchar(fields)!=8L))stop(path,": expected eight FCEUX gamepad positions")
        for(j in 1:8)inputs[,player,j]<-!substr(fields,j,j)%in%c("."," ")
      }
    } else {
      if(binary) {
        z<-bytes[,cursor:(cursor+11L),drop=FALSE]
        ticks<-as.vector(z[,5:12,drop=FALSE]%*%256^(0:7))
        hit_source[[player]]<-matrix(as.raw(z[,5:12]),n,8L)
        ticks[ticks>2^53]<-NA_real_
        z<-cbind(z[,1:4,drop=FALSE],ticks);cursor<-cursor+12L
      } else {
        fields<-lapply(parts,function(x)scan(text=x[port+2L],what=character(),quiet=TRUE))
        if(any(lengths(fields)!=5L))stop(path,": expected five Zapper fields")
        hit_source[[player]]<-vapply(fields,`[`,character(1),5L)
        z<-matrix(as.numeric(unlist(fields)),n,5L,byrow=TRUE)
        if(anyNA(z))stop(path,": invalid numeric Zapper field")
        z[z[,5L]>2^53,5L]<-NA_real_
      }
      colnames(z)<-c("gun_x","gun_y","gun_buttons","trigger_counter","light_hit_ticks")
      analog[[player]]<-z
      inputs[,player,match("gun_trigger",keys)]<-bitwAnd(as.integer(z[,3L]),1L)!=0L
      inputs[,player,match("offscreen_shot",keys)]<-bitwAnd(as.integer(z[,3L]),2L)!=0L
    }
  }
  header$controllerPorts<-active;header$observationUnit<-"frame"
  movie<-.new_named_movie(header,commands,inputs,keys,path,analog=analog)
  movie$zapper_hit_source<-hit_source
  if(format=="fm3")movie$project_bytes<-remainder else movie$trailing_bytes<-remainder
  movie
}
