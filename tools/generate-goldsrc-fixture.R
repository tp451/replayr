# An original GoldSrc (Half-Life engine) demo for the tests and examples. Run
# from replayr's package root. The file is written field by field from the
# layout of the format (frame container as documented by hldemo-rs, command
# as in common/usercmd.h of the Half-Life SDK); it shares no code with the
# reader and holds no recorded play.
#
# Content. A loading section with two start frames without input, then 0.23
# seconds of play at 100 frames per second (frames 0 to 23):
#   forward       frames 0-15, asking for 400 units of forward movement
#   jump          frames 4-5 and 12-13
#   move right    frames 8-11, asking for 400 units of sideways movement
#   duck          frames 16-19
#   attack        frames 20-22, looking 3 degrees up
#   yaw           90 degrees, turning 2 degrees per frame in frames 8-15
#   impulse 100 and weapon 2 in frame 23
# Frame 6 is recorded twice, as happens when two network messages arrive in
# one frame. Each of the other frame types occurs once.
out <- file.path("inst", "extdata", "computers", "goldsrc-moves.dem")
bytes <- raw()
put <- function(...) bytes <<- c(bytes, ...)
int <- function(x) writeBin(as.integer(x), raw(), size = 4L, endian = "little")
float <- function(x) writeBin(as.numeric(x), raw(), size = 4L, endian = "little")
text <- function(x, width) c(charToRaw(x), raw(width - nchar(x)))
frame <- function(type, time, number) put(as.raw(type), float(time), int(number))
command <- function(buttons = 0L, forward = 0, side = 0, yaw = 0, pitch = 0, impulse = 0L, weapon = 0L, msec = 10L) {
  c(
    writeBin(0L, raw(), size = 2L, endian = "little"), as.raw(msec), as.raw(0L), # lerp_msec, msec, padding
    float(c(pitch, yaw, 0)), float(c(forward, side, 0)),                         # view angles, movement
    as.raw(c(0L, 0L)), writeBin(as.integer(buttons), raw(), size = 2L, endian = "little"),
    as.raw(c(impulse, weapon, 0L, 0L)), int(0L), float(c(0, 0, 0))               # impact index and position
  )
}
network <- function(type, time, number, cmd, message = raw()) {
  stopifnot(length(cmd) == 52L)
  frame(type, time, number)
  put(float(0), raw(232L), cmd, raw(132L), float(c(0, 0, 0)), int(0L), raw(28L), int(length(message)), message)
}
console <- function(time, number, line) {
  frame(3L, time, number)
  put(text(line, 64L))
}
put(charToRaw("HLDEMO"), as.raw(c(0L, 0L)), int(5L), int(48L), text("replayr_example", 260L), text("valve", 260L))
put(as.raw(c(0x78, 0x56, 0x34, 0x12)), int(0L)) # map CRC; the directory offset follows below
stopifnot(length(bytes) == 544L)

loading <- length(bytes)
network(0L, 3.25, 40L, command(msec = 0L))
network(0L, 3.5, 41L, command(msec = 0L))
frame(5L, 3.5, 41L)

playback <- length(bytes)
frame(2L, 0, 0L)
keys <- list(
  `0` = "+forward", `4` = "+jump", `6` = "-jump", `8` = "+moveright", `12` = c("-moveright", "+jump"),
  `14` = "-jump", `16` = c("-forward", "+duck"), `20` = c("-duck", "+attack"), `23` = c("-attack", "impulse 100")
)
for (i in 0:23) {
  time <- i / 100
  for (line in keys[[as.character(i)]]) console(time, i, line)
  if (i == 0L) {
    frame(4L, time, i) # client data: origin, view angles, weapon bits, field of view
    put(float(c(0, 0, 0)), float(c(0, 90, 0)), int(0L), float(90))
  }
  if (i == 1L) {
    frame(9L, time, i)
    put(int(4L), as.raw(1:4))
  }
  if (i == 20L) {
    frame(6L, time, i) # event
    put(raw(84L))
    frame(7L, time, i) # weapon animation
    put(int(3L), int(0L))
    frame(8L, time, i) # sound
    put(int(1L), int(15L), charToRaw("weapons/hit.wav"), float(c(0.8, 1)), int(0L), int(100L))
  }
  buttons <- 8L * (i <= 15L) + 2L * (i %in% c(4L, 5L, 12L, 13L)) + 1024L * (i %in% 8:11) +
    4L * (i %in% 16:19) + 1L * (i %in% 20:22)
  cmd <- command(
    buttons = buttons, forward = 400 * (i <= 15L), side = 400 * (i %in% 8:11),
    yaw = 90 + 2 * max(0, min(i, 15L) - 7L), pitch = -3 * (i %in% 20:22),
    impulse = 100L * (i == 23L), weapon = 2L * (i == 23L)
  )
  network(1L, time, i, cmd, message = if (i == 10L) as.raw(c(1, 2, 3, 4, 5)) else raw())
  if (i == 6L) network(1L, time, i, cmd)
}
frame(5L, 0.23, 23L)

directory <- length(bytes)
entry <- function(type, description, seconds, frames, offset, length) {
  put(int(type), text(description, 64L), int(0L), int(-1L), float(seconds), int(frames), int(offset), int(length))
}
put(int(2L))
entry(0L, "LOADING", 0, 0L, loading, playback - loading)
entry(1L, "Playback", 0.23, 24L, playback, directory - playback)
bytes[541:544] <- int(directory)
writeBin(bytes, out)
cat(out, ":", length(bytes), "bytes\n")
