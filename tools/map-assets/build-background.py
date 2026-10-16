"""Read installed satellite textures into a bounded-memory editor cache.
No changes to the source PBO, no game process, no full-world 20k raster.
"""
import sys,struct,io,json,math,time,os
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor/python'))
import lzokay
from PIL import Image

def decode_paa(b):
    kind=struct.unpack_from('<H',b)[0]
    if kind not in (0xff01,0xff05): raise ValueError('Unsupported satellite PAA type')
    p=2
    while b[p:p+4]==b'GGAT':
        n=struct.unpack_from('<I',b,p+8)[0]
        if n>1000000 or p+12+n>len(b): raise ValueError('Invalid PAA tag')
        p+=12+n
    palette=struct.unpack_from('<H',b,p)[0];p+=2+3*palette
    w,h=struct.unpack_from('<HH',b,p);p+=4
    compressed=bool(w&0x8000);w&=0x7fff
    if not 1<=w<=4096 or not 1<=h<=4096: raise ValueError('Excessive texture dimensions')
    n=int.from_bytes(b[p:p+3],'little');p+=3
    if p+n>len(b): raise ValueError('Truncated PAA')
    expected=w*h//2 if kind==0xff01 else w*h
    raw=lzokay.decompress(b[p:p+n],expected) if compressed else b[p:p+n]
    if len(raw)!=expected: raise ValueError('Incorrect texture payload')
    head=bytearray(128);head[:4]=b'DDS '
    for pos,value in [(4,124),(8,0x81007),(12,h),(16,w),(20,len(raw)),(76,32),(80,4),(108,0x1000)]:struct.pack_into('<I',head,pos,value)
    head[84:88]=b'DXT1' if kind==0xff01 else b'DXT5'
    return Image.open(io.BytesIO(head+raw)).convert('RGB')

def expand_lzss(data,expected):
    out=bytearray();p=0
    while len(out)<expected:
        flags=data[p];p+=1
        for bit in range(8):
            if len(out)>=expected:break
            if flags&(1<<bit):out.append(data[p]);p+=1
            else:
                a,b=data[p:p+2];p+=2
                offset=a+((b&240)<<4)
                if offset<1:raise ValueError('Bad LZSS offset')
                for _ in range((b&15)+3):
                    if len(out)>=expected:break
                    idx=len(out)-offset;out.append(32 if idx<0 else out[idx])
    if sum(out)&0xffffffff!=struct.unpack_from('<I',data,len(data)-4)[0]:raise ValueError('LZSS checksum')
    return bytes(out)

def build(manifest):
    folder=Path(manifest).resolve().parent
    m=json.loads(Path(manifest).read_text(encoding='utf-8-sig'))
    if len(m['tiles'])>10000 or m['worldSize']>100000: raise ValueError('Excessive terrain')
    out=folder/'tiles';out.mkdir(exist_ok=True)
    overview_size=4096;ratio=overview_size/m['worldSize']
    overview=Image.new('RGB',(overview_size,overview_size),(25,65,90))
    started=time.monotonic();pixel_size=None
    sources={}
    try:
        for i,t in enumerate(m['tiles']):
            if not 0<t['size']<16000000: raise ValueError('Excessive texture entry')
            source_path=t.get('pbo',m['pbo'])
            if source_path not in sources:sources[source_path]=open(source_path,'rb')
            source=sources[source_path]
            source.seek(t['offset']);payload=source.read(t['size'])
            if t['packing']==0x43707273:payload=expand_lzss(payload,t['original'])
            elif t['packing']!=0:raise ValueError('Unsupported satellite entry compression')
            im=decode_paa(payload)
            current_pixel_size=t['width']/(im.width*t['cropWidth'])
            pixel_size=current_pixel_size if pixel_size is None else min(pixel_size,current_pixel_size)
            x0=round(t['cropLeft']*im.width);y0=round(t['cropTop']*im.height)
            cropped=im.crop((x0,y0,round((t['cropLeft']+t['cropWidth'])*im.width),round((t['cropTop']+t['cropHeight'])*im.height)))
            cropped.save(out/f"{t['x']}_{t['y']}.jpg",quality=94,subsampling=0,optimize=True)
            left=round(t['worldLeft']*ratio);top=round((m['worldSize']-t['worldTop'])*ratio)
            right=round((t['worldLeft']+t['width'])*ratio);bottom=round((m['worldSize']-t['worldTop']+t['height'])*ratio)
            overview.paste(cropped.resize((right-left,bottom-top),Image.Resampling.LANCZOS),(left,top))
            if i%150==0: print(json.dumps({'done':i,'total':len(m['tiles'])}),flush=True)
    finally:
        for source in sources.values():source.close()
    overview.save(folder/'overview.jpg',quality=95,subsampling=0,optimize=True)
    result={k:m[k] for k in ['world','worldSize','strideX','strideY','columns','rows','projectionEvidence','sourceSize','sourceModified','missingTiles']}
    result.update(version=1,ready=True,overviewWidth=overview_size,detailPixelSize=pixel_size,tileCount=len(m['tiles']),seconds=round(time.monotonic()-started,2))
    tmp=folder/'background.json.tmp';tmp.write_text(json.dumps(result,indent=2),encoding='utf-8');os.replace(tmp,folder/'background.json')
    print(json.dumps(result),flush=True)

if __name__=='__main__':build(sys.argv[1])
