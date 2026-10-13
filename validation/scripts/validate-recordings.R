# Compatibility checks for the TASVideos recordings of the manifest.
#
# Usage, from the folder validation of the repository, after retrieve-recordings.R:
#   Rscript scripts/validate-recordings.R
# Environment: REPLAYR_VALIDATION_ROOT (folder with the recordings),
#   REPLAYR_VALIDATION_MANIFEST (default tables/validation-manifest.csv),
#   REPLAYR_VALIDATION_PRESENT_ONLY (set to 1 to check only the recordings
#   that are in the folder, for example after retrieving a part of them).
# No recordings are downloaded here. Every file is checked against its
# SHA-256 hash before it is read.
library(replayr)
if (!requireNamespace("digest", quietly=TRUE)) stop("Install digest for SHA256 verification.")
root <- Sys.getenv("REPLAYR_VALIDATION_ROOT")
if (!nzchar(root) || !dir.exists(root)) stop("Set REPLAYR_VALIDATION_ROOT to the recording directory.")
manifest <- read.csv(Sys.getenv("REPLAYR_VALIDATION_MANIFEST", "tables/validation-manifest.csv"), stringsAsFactors=FALSE)
manifest <- manifest[!duplicated(manifest$sha256),]
if (nzchar(Sys.getenv("REPLAYR_VALIDATION_PRESENT_ONLY")))
  manifest <- manifest[file.exists(file.path(root, manifest$relative_path)),]
candidates <- list.files(root, recursive=TRUE, full.names=TRUE)
hashes <- new.env(parent=emptyenv())
resolve <- function(i) {
  direct <- file.path(root, manifest$relative_path[i])
  name <- paste0(manifest$publication_id[i], ".", manifest$format[i])
  matches <- unique(c(direct, candidates[tolower(basename(candidates))==tolower(name)]))
  for (path in matches[file.exists(matches)]) {
    if (!exists(path,hashes,inherits=FALSE))
      assign(path,digest::digest(file=path,algo="sha256",serialize=FALSE),hashes)
    if (identical(get(path,hashes),manifest$sha256[i])) return(path)
  }
  stop("No matching file and SHA256 for ", name, "; source: ", manifest$source_url[i])
}

check_movie<-function(m,path) {
 n<-n_observations(m);np<-dim(m$inputs)[2L];layout<-button_layout(m)
 stopifnot(is.logical(m$inputs),!anyNA(m$inputs),length(dim(m$inputs))==3L,
    length(m$commands)==n,nrow(layout)==n_buttons(m),!anyDuplicated(layout$id),!anyDuplicated(layout$key))
 for(p in seq_len(np)) {
  a<-analog_channels(m,p)
  stopifnot(is.matrix(a),is.numeric(a),nrow(a)==n,!anyDuplicated(colnames(a)))
  if(inherits(m,'replayr_movie'))stopifnot(identical(attr(player(m,p),'button_ids'),layout$id))
 }
 if(inherits(m,'replayr_poll_stream')) {
  take<-seq_len(min(n,64));probe<-m
  probe$inputs<-m$inputs[take,,,drop=FALSE];probe$commands<-m$commands[take]
  probe$analog<-lapply(m$analog,function(x)x[take,,drop=FALSE])
  probe$stick_values<-lapply(m$stick_values,function(x)x[take,,drop=FALSE])
  if(!is.null(m$poll_bytes))probe$poll_bytes<-m$poll_bytes[take,,drop=FALSE]
  if(!is.null(m$poll_fields))probe$poll_fields<-m$poll_fields[take,,drop=FALSE]
  stopifnot(nrow(polls(probe))==length(take))
 }
 if(!is.null(m$poll_bytes)) {
  format<-m$header[['_format']]
  data<-readBin(path,'raw',file.info(path)$size)
  if(format=='dtm' && m$header$dtmVariant %in% c('mixed-hid','mixed-hid-connected','mixed-hid-nomarker')) {
   pos<-257L
   for(i in seq_len(nrow(m$poll_bytes))) {
    size<-m$poll_lengths[i]
    stopifnot(identical(as.vector(m$poll_bytes[i,seq_len(size)]),data[pos+seq_len(size)-1L]))
    pos<-pos+size
   }
   stopifnot(pos==length(data)+1L)
  } else if(format=='dtm' && startsWith(m$header$dtmVariant,'wii-')) {
   pos<-257L
   for(i in seq_len(nrow(m$poll_bytes))) {
    if(!is.null(m$poll_prefix_bytes)) {
     stopifnot(identical(as.vector(m$poll_prefix_bytes[i,]),data[pos:(pos+7L)]));pos<-pos+8L
    }
    size<-as.integer(data[pos]);stopifnot(size==m$poll_lengths[i])
    stopifnot(identical(as.vector(m$poll_bytes[i,seq_len(size)]),data[pos+seq_len(size)]))
    pos<-pos+size+1L
   }
   tail<-if(is.null(m$source_tail))raw()else m$source_tail
   stopifnot(pos+length(tail)==length(data)+1L)
   if(length(tail))stopifnot(identical(tail,data[seq.int(pos,length(data))]))
  } else if(format%in%c('dtm','ctm','m64')) {
   offset<-if(format=='m64')1024L else 256L
   bytes<-as.vector(t(m$poll_bytes))
   stopifnot(identical(bytes,data[offset+seq_along(bytes)]))
  }
 }
 list(observations=n,players=n_players(m),controls=n_buttons(m),representation=class(m)[1L])
}

has_value <- function(x) length(x)==1L && !is.na(x) && nzchar(x)
results <- list()
for (i in seq_len(nrow(manifest))) {
  f <- manifest[i,]
  row <- list(publication_id=f$publication_id,relative_path=f$relative_path,sha256=f$sha256,
    status="ok",observations=NA_real_,players=NA_real_,controls=NA_real_,representation="",
    warnings="",error="",seconds=0)
  notes <- character(); started <- proc.time()[3]
  tryCatch(withCallingHandlers({
      path <- resolve(i)
      args <- list(path=path)
      if (has_value(f$game)) args$game <- f$game
      if (has_value(f$wii_variant)) args$wii_variant <- f$wii_variant
      if (f$format=="bk2" && max(utils::unzip(path,list=TRUE)$Length)>1e8) {
        checked <- read_bk2_chunks(path,function(movie)check_movie(movie,path))
        row$observations <- sum(vapply(checked,`[[`,numeric(1),"observations"))
        row$players <- checked[[1L]]$players; row$controls <- checked[[1L]]$controls
        row$representation <- "replayr_movie chunks"
      } else {
        movie <- do.call(read_movie,args)
        checked <- check_movie(movie,path); row[names(checked)] <- checked
        rm(movie)
      }
  },warning=function(w){notes<<-c(notes,conditionMessage(w));invokeRestart("muffleWarning")}),
    error=function(e){row$status<<-"error";row$error<<-conditionMessage(e)})
  row$warnings <- paste(unique(notes),collapse=" | ");row$seconds <- unname(proc.time()[3]-started)
  results[[i]] <- as.data.frame(row,stringsAsFactors=FALSE)
  if (i%%10L==0L || i==nrow(manifest) || row$status!="ok") {
    write.csv(do.call(rbind,results),"validation-rerun-results.csv",row.names=FALSE)
    cat(i,"/",nrow(manifest),f$publication_id,row$status,row$error,"\n");flush.console()
  }
  gc(FALSE)
}
saveRDS(list(results=do.call(rbind,results),session=sessionInfo()),"validation-rerun.rds")
