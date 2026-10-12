"""Generate original FBM demonstrations; no published movie data is used.

The encoder below is an independent implementation of the FGK mathematical
algorithm described in Vitter (1987), section 2, doi:10.1145/31846.42227.
It does not incorporate any emulator Huffman implementation.
Run from the repository with: python tools/generate-fbm-examples.py
"""
from pathlib import Path
import json,struct

class Node:
    def __init__(self,number,parent=None,value=None,weight=0):
        self.number=number;self.parent=parent;self.value=value;self.weight=weight
        self.left=None;self.right=None

def fgk_encode(data):
    root=Node(512);unseen=root;nodes=[root];symbols={};bits=[]
    def path(node):
        result=[]
        while node.parent is not None:
            result.append(int(node is node.parent.right));node=node.parent
        return result[::-1]
    def update(node):
        while node is not None:
            group=[n for n in nodes if n.weight==node.weight and n is not node.parent]
            if node.parent is unseen.parent and node is not unseen:
                group=[n for n in group if n.left is None]
            leader=max(group,key=lambda n:n.number)
            if leader is not node:
                pa,pb=node.parent,leader.parent
                sa='left' if pa.left is node else 'right'
                sb='left' if pb.left is leader else 'right'
                setattr(pa,sa,leader);setattr(pb,sb,node)
                node.parent,leader.parent=pb,pa
                node.number,leader.number=leader.number,node.number
            node.weight+=1;node=node.parent
    for value in data:
        if value in symbols:
            node=symbols[value];bits.extend(path(node));update(node)
        else:
            bits.extend(path(unseen));bits.extend((value>>shift)&1 for shift in range(7,-1,-1))
            old=unseen
            old.right=Node(old.number-1,old,value,1)
            old.left=Node(old.number-2,old)
            old.weight=1
            symbols[value]=old.right;unseen=old.left
            nodes.extend([old.right,old.left]);update(old.parent)
    padding=(-len(bits))%32
    bits.extend([0]*padding)
    packed=bytearray()
    for start in range(0,len(bits),32):
        word=0
        for b in bits[start:start+32]:word=(word<<1)|b
        packed.extend(struct.pack('<I',word))
    return struct.pack('<4I',16+len(packed),len(data),0,0)+packed

def movie_bytes(fields,frames,baseline=None):
    baseline=[0]*len(fields) if baseline is None else list(baseline)
    def value(j,v):return struct.pack('>h',v) if fields[j]['type']=='analog' else bytes([v])
    data=b''.join(value(j,v) for j,v in enumerate(baseline))
    state=baseline
    for frame in frames:
        for j,v in enumerate(frame):
            if v!=state[j]:data+=bytes([j])+value(j,v)
        data+=b'\xff';state=list(frame)
    packed=fgk_encode(data)
    result=b'FB1 \x02FR1 '+struct.pack('<4I',len(packed)+16,len(frames),0,0)+bytes(4)+packed
    return result,data

def main():
    root=Path(__file__).resolve().parents[1]
    dest=root/'inst/extdata/expanded';dest.mkdir(parents=True,exist_ok=True)
    schemas=json.loads((root/'inst/extdata/fbm-layouts.json').read_text())
    fields=schemas['ghouls']['fields']
    index={(f['player'],f['key']):j for j,f in enumerate(fields)}
    baseline=[255 if f['type']=='byte' else 0 for f in fields]
    frames=[]
    for t in range(192):
        frame=baseline.copy()
        active=[]
        if t<2:active.append((0,'coin_1'))
        if 8<=t<10:active.append((1,'start'))
        if 16<=t<80 or 100<=t<156:active.append((1,'dpad_right'))
        if 42<=t<56 or 120<=t<134:active.append((1,'arcade_button_2'))
        if 62<=t<68 or 140<=t<146:active.append((1,'arcade_button_1'))
        if 84<=t<96:active.append((1,'dpad_left'))
        if 160<=t<162:active.append((0,'coin_2'))
        if 164<=t<166:active.append((2,'start'))
        if 170<=t<184:active.append((2,'dpad_right'))
        if 176<=t<180:active.append((2,'arcade_button_1'))
        for key in active:frame[index[key]]=1
        frames.append(frame)
    packed,_=movie_bytes(fields,frames,baseline)
    (dest/'synthetic-arcade.fbm').write_bytes(packed)
    custom=dict(source='Original demonstration schema; no game or ROM required.',fields=[
        dict(key='dpad_right',name='Right',player=1,type='button',button_encoding='bit0'),
        dict(key='stick_x',name='Horizontal',player=1,type='analog'),
        dict(key='stick_y',name='Vertical',player=1,type='analog'),
        dict(key='dial',name='Dial',player=2,type='analog'),
        dict(key='dip_a',name='DIP A',player=0,type='byte')])
    frames=[[0,0,0,0,255],[1,1000,0,64,255],[1,2000,1000,128,255],
            [0,0,2000,192,254],[128,-2000,1000,-64,254],[129,-32768,32767,-32768,128],
            [0,0,0,32767,0],[0,0,0,0,255]]
    packed,_=movie_bytes(custom['fields'],frames)
    (dest/'synthetic-arcade-analog.fbm').write_bytes(packed)
    (dest/'synthetic-arcade-analog-schema.json').write_text(json.dumps(custom,indent=2)+'\n')
    # Exercises every symbol, changing frequency blocks, and ties in FGK.
    vector=bytes(range(256))+bytes(range(255,-1,-1))+b'abracadabra'*31+bytes(range(256))*2
    (dest/'synthetic-fgk-alphabet.bin').write_bytes(fgk_encode(vector))

if __name__=='__main__':main()
