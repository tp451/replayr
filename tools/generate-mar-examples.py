"""Write original arcade input gestures; no gameplay recordings or ROM data."""
from pathlib import Path
import json,struct
root=Path(__file__).resolve().parents[1]
schemas=json.loads((root/'inst/extdata/mar-layouts.json').read_text())
out=root/'inst/extdata/expanded';out.mkdir(parents=True,exist_ok=True)
def write(name,game,frames):
 header=b'MAMETAS\0'+bytes([1,0,0,0])+game.encode().ljust(12,b'\0')+b'replayr original example'.ljust(24,b'\0')+struct.pack('<dII',60,len(frames),0)
 body=bytearray()
 for i,frame in enumerate(frames):
  body+=struct.pack('<IQ',0,i*16666666666666666)
  for port in schemas[game]['ports']:
   body+=struct.pack('<II',0xffffffff,frame.get(port['name'],0))
   for field in port['fields']:
    if field['type']=='analog':body+=struct.pack('<iiIB',*frame.get(port['name']+'_analog',(0,0,25,0)))
 (out/name).write_bytes(header+body)
write('arcade-dual-joysticks.mar','karatevs',[
 {'SYSTEM':4}, {'P1':0x41,'P2':0x28}, {'P1':0x12}, {}])
write('arcade-dial-shift.mar','dragrace',[
 {'IN2':0x10,'DIAL1_analog':(-1000,0,25,0)},
 {'IN0':1,'P1':1,'DIAL1_analog':(0,-1000,25,0),'DIAL2_analog':(800,0,25,1)},
 {'IN0':1,'P1':2,'DIAL1_analog':(2000,0,25,0),'DIAL2_analog':(-800,800,25,1)},
 {'DIAL1_analog':(0,2000,25,0),'DIAL2_analog':(0,-800,25,1)}])
write('arcade-unsigned-port.mar','tgm2p',[{'INPUTS':0x01000001},{'INPUTS':0x80000000},{'INPUTS':0x00400000},{}])
