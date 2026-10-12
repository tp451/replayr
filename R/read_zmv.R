# Enhanced ZSNES ZMV (1.51-era) controller-event stream.
# https://github.com/emillon/zsnes/blob/master/src/zmovie.c
# https://tasvideos.org/OtherEmulators/ZMV
.decode_zmv <- function(path) {
  data<-readBin(path,'raw',n=file.info(path)$size)
  if(length(data)<43L || !identical(data[1:3],charToRaw('ZMV')))stop(path,': not an enhanced ZMV file')
  u24<-function(offset) {
    if(offset+3L>length(data))stop(path,': truncated ZMV state size')
    sum(as.numeric(data[offset+1:3])*c(1,256,65536))
  }
  nf<-.read_u32_le(data,9L);input_flags<-.read_u16_le(data,37L)
  if(bitwAnd(input_flags,1792L)!=0L)stop(path,': ZMV mouse and Super Scope records require a peripheral decoder')
  ports<-which(vapply(15:11,function(bit)bitwAnd(input_flags,bitwShiftL(1L,bit))!=0L,logical(1)))
  if(!length(ports))stop(path,': ZMV has no enabled gamepad')
  chapters<-.read_u16_le(data,30L);author_size<-.read_u16_le(data,32L);state_size<-u24(34L)
  end_count<-length(data)-author_size-2L
  if(end_count<43L)stop(path,': invalid ZMV footer')
  external<-.read_u16_le(data,end_count)
  stream_end<-end_count-external*(state_size+19L)-chapters*4L
  offset<-43L+bitwAnd(u24(40L),8388607L)
  if(offset>stream_end)stop(path,': truncated ZMV initial savestate')
  keys<-c('b','y','select','start','dpad_up','dpad_down','dpad_left','dpad_right','a','x','l1','r1')
  event_states<-list();event_lengths<-integer();reset_frames<-integer()
  state<-matrix(FALSE,5L,12L);frame<-0L;pending_reset<-FALSE;chapter_offsets<-integer()
  need<-function(n)if(offset+n>stream_end)stop(path,': truncated ZMV controller stream')
  while(offset<stream_end) {
    need(1L);flag<-as.integer(data[offset+1L]);offset<-offset+1L
    if(bitwAnd(flag,1L)) {
      command<-bitwShiftR(flag,1L)
      if(command!=0L)stop(path,': unknown ZMV command ',command)
      pending_reset<-TRUE
      next
    }
    if(bitwAnd(flag,2L)) {
      need(4L);until<-.read_u32_le(data,offset);offset<-offset+4L
      if(until<=frame || until>.Machine$integer.max)stop(path,': invalid ZMV repeat endpoint')
      run<-until-frame
    } else if(bitwAnd(flag,4L)) {
      need(3L);chapter_offsets<-c(chapter_offsets,offset)
      bytes<-3L+bitwAnd(u24(offset),8388607L)+15L
      need(bytes);offset<-offset+bytes
      next
    } else {
      changed<-which(vapply(7:3,function(bit)bitwAnd(flag,bitwShiftL(1L,bit))!=0L,logical(1)))
      bytes<-ceiling(length(changed)*12/8);need(bytes)
      if(bytes) {
        packed<-as.integer(data[offset+seq_len(bytes)]);offset<-offset+bytes
        bits<-as.vector(vapply(packed,function(byte)bitwAnd(byte,bitwShiftL(1L,7:0))!=0L,logical(8)))
        state[changed,]<-matrix(bits[seq_len(length(changed)*12L)],ncol=12L,byrow=TRUE)
      }
      run<-1L
    }
    event_states[[length(event_states)+1L]]<-as.vector(state[ports,,drop=FALSE])
    event_lengths<-c(event_lengths,run)
    if(pending_reset){reset_frames<-c(reset_frames,frame+1L);pending_reset<-FALSE}
    frame<-frame+run
  }
  if(offset!=stream_end)stop(path,': unparsed data remains before the ZMV chapter index')
  if(length(chapter_offsets)!=chapters)stop(path,': inconsistent ZMV internal chapter count')
  stored<-if(length(event_states))do.call(rbind,event_states) else matrix(FALSE,0L,length(ports)*length(keys))
  inputs<-array(stored[rep(seq_along(event_lengths),event_lengths),,drop=FALSE],c(frame,length(ports),length(keys)))
  commands<-integer(frame);commands[reset_frames]<-1L
  if(frame!=nf)warning(path,': ZMV header declares ',nf,' frames; importing ',frame,' complete stored frames',call.=FALSE)
  header<-list(`_format`='zmv',system='SNES',zsnesVersion=.read_u16_le(data,3L),romCRC32=.read_u32_le(data,5L),
    declaredFrameCount=nf,frameCount=frame,rerecordCount=.read_u32_le(data,13L),removedFrames=.read_u32_le(data,17L),
    stepAdvancedFrames=.read_u32_le(data,21L),averageFps=as.integer(data[26]),keyCombos=.read_u32_le(data,26L),
    controllerPorts=ports,initialInputFlags=input_flags,startMethod=bitwShiftR(as.integer(data[40]),6L),
    isPal=bitwAnd(as.integer(data[40]),32L)!=0L,internalChapters=chapters,externalChapters=external,
    trailingReset=pending_reset,
    author=if(author_size).read_cstring(data,length(data)-author_size,author_size) else '',commandEncoding='bit 0: reset before observation')
  movie<-.new_named_movie(header,commands,inputs,keys,path)
  movie$chapter_offsets<-chapter_offsets
  movie
}
