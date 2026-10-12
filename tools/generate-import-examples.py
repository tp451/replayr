"""Create short original import examples; run from the package root."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'inst'/'extdata'
target=root/'expanded'/'movement-jumps.fm3'
header='version 3\nport0 1\nport1 0\nfourscore 0\nbinary 0\nlength 180\n'
rows=[]
for frame in range(180):
    # Each 60-frame phrase moves right, presses A briefly, and then pauses.
    phase=frame%60
    mask=list('........')
    if phase<40: mask[0]='R'
    if 20<=phase<25: mask[7]='A'
    rows.append('|0|'+''.join(mask)+'|||\n')
target.write_text(header+''.join(rows),encoding='ascii')
# HGM is another extension for the same Hourglass wire format.
(root/'computers'/'keyboard-jump.hgm').write_bytes((root/'computers'/'keyboard-jump.wtf').read_bytes())
