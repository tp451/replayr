# Citra/Azahar CTM: a stream of seven-byte tagged device polls.
# https://github.com/azahar-emu/azahar/blob/master/src/core/movie.cpp
# Axis encodings: core/hle/service/hid/hid.cpp, ir/ir_rst.cpp, ir/extra_hid.cpp.
.decode_ctm <- function(path) {
  data <- readBin(path, 'raw', n=file.info(path)$size)
  if(length(data)<256L || !identical(data[1:4],as.raw(c(67,84,77,27)))) stop(path, ': not a CTM file')
  body <- data[-seq_len(256L)]
  if(length(body)%%7L) stop(path, ': CTM has a partial device-poll record')
  packets <- matrix(as.integer(body),ncol=7L,byrow=TRUE)
  n <- nrow(packets);type <- packets[,1L]
  if(any(!type %in% 0:5))stop(path,': unknown CTM device-poll type')
  keys <- c('a','b','select','start','dpad_right','dpad_left','dpad_up','dpad_down',
            'r1','l1','x','y','debug','gpio14','touch','l2','r2')
  inputs <- array(FALSE,c(n,1L,length(keys)))
  observed <- matrix(FALSE,n,length(keys),dimnames=list(NULL,keys))
  channel_names <- c('circle_x','circle_y','touch_x','touch_y','touch_valid',
                      'accelerometer_x','accelerometer_y','accelerometer_z',
                      'gyroscope_x','gyroscope_y','gyroscope_z',
                      'ir_c_stick_x','ir_c_stick_y','extra_c_stick_x','extra_c_stick_y','battery_level')
  channels <- matrix(NA_real_,n,length(channel_names),dimnames=list(NULL,channel_names))
  u16 <- function(rows,column) packets[rows,column]+256L*packets[rows,column+1L]
  s16 <- function(rows,column) {x<-u16(rows,column);ifelse(x>=32768L,x-65536L,x)}
  rows <- which(type==0L)
  inputs[rows,1L,1:14] <- .legacy_bits(u16(rows,2L),0:13)
  observed[rows,1:14] <- TRUE
  channels[rows,c('circle_x','circle_y')] <- cbind(s16(rows,4L),s16(rows,6L))
  rows <- which(type==1L)
  if(any(!packets[rows,6L] %in% 0:1))stop(path,': invalid CTM touch validity')
  inputs[rows,1L,15L] <- packets[rows,6L]!=0L
  observed[rows,15L] <- TRUE
  channels[rows,c('touch_x','touch_y','touch_valid')] <- cbind(u16(rows,2L),u16(rows,4L),packets[rows,6L])
  for(t in 2:3) {
    rows <- which(type==t)
    prefix <- if(t==2L)'accelerometer' else 'gyroscope'
    channels[rows,paste0(prefix,c('_x','_y','_z'))] <- cbind(s16(rows,2L),s16(rows,4L),s16(rows,6L))
  }
  rows <- which(type==4L)
  if(any(!packets[rows,6:7,drop=FALSE] %in% 0:1))stop(path,': invalid CTM IR button state')
  channels[rows,c('ir_c_stick_x','ir_c_stick_y')] <- cbind(s16(rows,2L),s16(rows,4L))
  inputs[rows,1L,16:17] <- packets[rows,6:7,drop=FALSE]!=0L
  observed[rows,16:17] <- TRUE
  rows <- which(type==5L)
  # Decode bit fields without signed 32-bit overflow.
  words <- packets[rows,2L]+256*packets[rows,3L]+65536*packets[rows,4L]+16777216*packets[rows,5L]
  channels[rows,'battery_level'] <- words%%32
  channels[rows,'extra_c_stick_x'] <- floor(words/256)%%4096
  channels[rows,'extra_c_stick_y'] <- floor(words/1048576)%%4096
  inputs[rows,1L,16L] <- floor(words/32)%%2==0
  inputs[rows,1L,17L] <- floor(words/64)%%2==0
  inputs[rows,1L,9L] <- floor(words/128)%%2==0
  observed[rows,c(16L,17L,9L)] <- TRUE
  hex <- function(bytes)paste(sprintf('%02x',as.integer(bytes)),collapse='')
  header <- list(`_format`='ctm',system='3DS',programId=paste0('0x',hex(rev(data[5:12]))),
    revision=hex(data[13:32]),clockInitTime=.read_u64_le(data,32L),movieIdBytes=data[41:48],
    author=.read_cstring(data,48L,32L),rerecordCount=.read_u32_le(data,80L),
    declaredInputCount=.read_u64_le(data,84L),padPollCount=sum(type==0L),pollCount=n,
    timingBaseTicksBytes=data[93:100],controllerAssignment='unassigned',
    assignmentReason='heterogeneous device polls',observationUnit='device_poll',enabledPorts=1L,
    stickEncoding='Circle: signed/154; IR-RST: signed/156; ExtraHID: (unsigned-2048)/2047')
  movie <- .new_named_movie(header,integer(n),inputs,keys,path,analog=list(channels))
  left <- channels[,c('circle_x','circle_y'),drop=FALSE]/154
  right <- channels[,c('ir_c_stick_x','ir_c_stick_y'),drop=FALSE]/156
  right[type==5L,] <- (channels[type==5L,c('extra_c_stick_x','extra_c_stick_y'),drop=FALSE]-2048)/2047
  movie$decoded_stick_vectors <- list(list(left=left,right=right))
  movie$poll_bytes <- matrix(as.raw(body),ncol=7L,byrow=TRUE)
  movie$poll_fields <- data.frame(event_type=c('pad_circle','touch','accelerometer','gyroscope','ir_rst','extra_hid')[type+1L],
    observed_pad=type==0L,observed_touch=type==1L,observed_ir=type==4L,observed_extra_hid=type==5L)
  movie$observed_inputs <- observed
  movie
}
