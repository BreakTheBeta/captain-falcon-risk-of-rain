"""Extract the owner's GameMaker sound bank. Format follows Pod's MIT extractor.
See docs/POD-LICENSE and THIRD_PARTY.md. No textures/game data are redistributed.
"""
import shutil,struct
from pathlib import Path

def extract(data_file,output):
 data=Path(data_file).read_bytes();output=Path(output);output.mkdir(parents=True,exist_ok=True)
 def u32(off):
  if off<0 or off+4>len(data):raise ValueError('Truncated GameMaker resource file')
  return struct.unpack_from('<I',data,off)[0]
 base=data.find(b'FORM');assert base>=0,'Not a GameMaker FORM file'
 end=base+8+u32(base+4);assert end<=len(data),'Truncated FORM'
 chunks={};off=base+8
 while off<end:
  tag=data[off:off+4];size=u32(off+4);assert off+8+size<=end
  chunks[tag]=off+8;off+=8+size
 def pointers(tag):
  start=chunks[tag];count=u32(start);assert count<100000
  return [base+u32(start+4+4*i) for i in range(count)]
 names={}
 for ptr in pointers(b'SOND'):
  start=base+u32(ptr);stop=data.index(b'\0',start);name=data[start:stop].decode('utf-8')
  assert name and Path(name).name==name and '\\' not in name,'Unsafe sound resource name'
  index=struct.unpack_from('<i',data,ptr+32)[0]
  if index>=0:names[index]=name
 count=0
 for i,ptr in enumerate(pointers(b'AUDO')):
  size=u32(ptr);sound=data[ptr+4:ptr+4+size];assert len(sound)==size
  extension='.wav' if sound.startswith(b'RIFF') else '.ogg'
  (output/(names[i]+extension)).write_bytes(sound);count+=1
 # External tracks are also supplied by the owner's installation.
 for p in Path(data_file).parent.iterdir():
  if p.suffix.lower()=='.ogg':shutil.copy2(p,output/p.name);count+=1
 return count
