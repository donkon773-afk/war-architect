import sys,struct,io
sys.path.insert(0,'tools/vendor/python')
import lzokay
from PIL import Image
# Probe one actual tile, without allocating a full-world raster.
from pathlib import Path
b=Path('research/australia-tile-probe.paa').read_bytes()
p=2
while b[p:p+4]==b'GGAT':
 n=struct.unpack_from('<I',b,p+8)[0]; p+=12+n
palette=struct.unpack_from('<H',b,p)[0];p+=2+3*palette
w,h=struct.unpack_from('<HH',b,p); p+=4
n=int.from_bytes(b[p:p+3],'little');p+=3
compressed=bool(w&0x8000);w&=0x7fff
raw=lzokay.decompress(b[p:p+n],w*h//2) if compressed else b[p:p+n]
head=bytearray(128);head[:4]=b'DDS '
for pos,value in [(4,124),(8,0x81007),(12,h),(16,w),(20,len(raw)),(76,32),(80,4),(108,0x1000)]:struct.pack_into('<I',head,pos,value)
head[84:88]=b'DXT1'
im=Image.open(io.BytesIO(head+raw)).convert('RGB');im.save('research/australia-tile-probe.png')
print({'size':im.size,'compressed':compressed,'bytes':len(raw)})
