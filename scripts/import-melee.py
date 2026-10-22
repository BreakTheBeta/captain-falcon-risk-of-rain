#!/usr/bin/env python3
"""Import a user's local GALP/GALE disc into the Falcon mod. No game asset downloads."""
import sys,os,argparse,base64,hashlib,json,math,re,shutil,struct,subprocess,wave,zipfile,tempfile,fcntl
from pathlib import Path
import numpy as np
from melee_sound_import import import_audio
BASE=Path(__file__).resolve().parents[1]
def lua_bytes(data):return '"'+''.join('\\%03d'%b for b in data)+'"'
def extract(iso,out):
 with iso.open('rb') as f:
  game=f.read(6).decode('ascii');assert game.startswith(('GALP','GALE','GALJ')),f'Not a Melee disc: {game}'
  f.seek(0x424);off,size=struct.unpack('>II',f.read(8));f.seek(off);fst=f.read(size);count=struct.unpack_from('>I',fst,8)[0];stack=[];found={}
  for i in range(1,count):
   while stack and i>=stack[-1][1]:stack.pop()
   flags,offset,length=struct.unpack_from('>III',fst,12*i);p=12*count+(flags&0xffffff);name=fst[p:fst.index(b'\0',p)].decode();path='/'.join([s[0] for s in stack]+[name])
   if flags>>24:stack.append((name,length));continue
   if name in ['PlCa.dat','PlCaNr.dat','PlCaAJ.dat'] or path in ['audio/captain.ssm','audio/main.ssm','audio/smash2.sem']:
    f.seek(offset);data=f.read(length);assert len(data)==length
    (out/name).write_bytes(data);found[path]={'bytes':length,'sha256':hashlib.sha256(data).hexdigest()}
  assert len(found)==6,found
 return game,found
def decode_ssm(path):
 d=path.read_bytes();header,_,count,start=struct.unpack_from('>IIII',d);header+=16;pos=16;result=[]
 for _ in range(count):
  nch,rate=struct.unpack_from('>II',d,pos);pos+=8;channels=[]
  for _ in range(nch):
   loop,fmt,lo,end,current=struct.unpack_from('>HHIII',d,pos);co=struct.unpack_from('>16h',d,pos+16);h1,h2=struct.unpack_from('>hh',d,pos+52)
   offset=header+math.ceil(current/2)-1;nibbles=end-current
   raw=d[offset:offset+math.ceil(nibbles/2)+1];samples=[]
   for n in range(0,len(raw)-7,8):
    block=raw[n:n+8];pred=block[0]>>4;scale=1<<(block[0]&15)
    if pred>7:raise ValueError('Invalid DSP predictor')
    a,b=co[pred*2:pred*2+2]
    for byte in block[1:]:
     for v in [byte>>4,byte&15]:
      if v>=8:v-=16
      value=max(-32768,min(32767,((v*scale<<11)+a*h1+b*h2+1024)>>11));h2,h1=h1,value;samples.append(value)
   channels.append(samples);pos+=64
  result.append((rate,np.array(channels,dtype='<i2').T.copy()))
 return result

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);ap.add_argument('--mod-root',type=Path,required=True);ap.add_argument('--use-converted',action='store_true');ap.add_argument('--audio-only',action='store_true');args=ap.parse_args()
 (BASE/'tmp').mkdir(exist_ok=True)
 source=BASE/'melee-source';files=source/'files';converted=source/'converted';files.mkdir(parents=True,exist_ok=True)
 target=args.mod_root.resolve();target.mkdir(parents=True,exist_ok=True)
 lock=(target.parents[1]/'game.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 staging=tempfile.TemporaryDirectory(prefix='melee-import-',dir=BASE/'tmp');root=Path(staging.name)
 if not args.use_converted:
  disc=args.source
  if disc.suffix.lower()=='.zip':
   with zipfile.ZipFile(disc) as z:
    names=[n for n in z.namelist() if Path(n).suffix.lower() in ['.iso','.gcm','.rvz']];assert len(names)==1,'Expected one disc in zip';n=names[0];disc=source/('melee-input'+Path(n).suffix.lower())
    with z.open(n) as src,disc.open('wb') as dst:shutil.copyfileobj(src,dst)
  if disc.suffix.lower()=='.rvz':
   digest=hashlib.file_digest(disc.open('rb'),'sha256').hexdigest()
   iso=source/('disc-'+digest[:20]+'.iso')
   if not iso.exists():subprocess.run([shutil.which('dolphin-tool') or shutil.which('DolphinTool') or '/usr/games/dolphin-tool','convert','-i',str(disc),'-o',str(iso),'-f','iso'],check=True)
   disc=iso
  game,assets=extract(disc,files);(source/'provenance.json').write_text(json.dumps({'disc_id':game,'assets':assets},indent=2))
  dotnet=Path(os.environ.get('FALCON_DOTNET') or shutil.which('dotnet') or BASE/'.tools/dotnet/dotnet');subprocess.run([str(dotnet),'build',str(BASE/'tools/FalconImport'),'-o',str(BASE/'tools/FalconImport/bin')],check=True)
  subprocess.run([str(dotnet),str(BASE/'tools/FalconImport/bin/FalconImport.dll'),str(files),str(converted)],check=True)
 if not args.audio_only:
  subprocess.run([str(Path(os.environ.get('FALCON_DOTNET') or shutil.which('dotnet') or BASE/'.tools/dotnet/dotnet')),str(BASE/'tools/FalconImport/bin/FalconImport.dll'),'--motion',str(files),str(converted/'motion.json')],check=True)
  subprocess.run([sys.executable,str(BASE/'scripts/import-melee-motion.py'),'--target',str(root)],check=True)
 model=json.loads((converted/'mesh.json').read_text());clips=model['clips'];n=model['vertices']
 if not args.audio_only:assert model.get('rootMotion','').startswith('TransN translation removed'),'Re-export model to remove duplicate animation root travel'
 if not args.audio_only:
  # Pack actual skinned XYZ geometry, not rendered image frames. Subpixel quantization: 1/256 Melee unit.
  for name,clip in clips.items():
   positions=np.fromfile(converted/(name+'.bin'),dtype='<f4').reshape(clip['frames'],n,3)
   if name=='shield':positions=positions[:1]
   assert np.isfinite(positions).all() and abs(positions).max()<120,'Invalid mesh geometry'
   packed=np.rint(positions*256).astype('<i2');(root/('melee_clip_'+name+'.lua')).write_text('return {\n'+',\n'.join(lua_bytes(frame.tobytes()) for frame in packed)+'\n}\n')
  triangles=model['triangles'];textures=model['textures']
  with (root/'melee_model.lua').open('w') as f:
   f.write('return {vertices='+str(n)+',bones='+str(model['bones'])+',triangles={\n')
   for t in triangles:f.write('{'+','.join(format(x,'.7g') for x in t)+'},\n')
   f.write('},textures={\n')
   for t in textures:f.write('{width=%d,height=%d,bgra=%s},\n'%(t['width'],t['height'],lua_bytes(base64.b64decode(t['bgra']))))
   f.write('},clips={'+','.join('['+json.dumps(k)+']='+str(min(v['frames'],1) if k=='shield' else v['frames']) for k,v in clips.items())+'}}\n')
 needed,audit=import_audio(root,source,converted,clips,decode_ssm,BASE)
 triangles=model['triangles']
 report={'version':1,'vertices':n,'triangles':len(triangles),'bones':model['bones'],'clips':{k:v['frames'] for k,v in clips.items()},'sounds':sorted(needed),'sound_mapping':'Exact disc SEM lookup; initial pitch/volume preserved','source':str(args.source),'root_motion':model.get('rootMotion','legacy uncorrected'),'runtime':'Live XYZ mesh projection and depth-buffered texturing; geometry poses sampled at 60 Hz','provenance':json.loads((source/'provenance.json').read_text())}
 (root/'melee-import.json').write_text(json.dumps(report,indent=2))
 for p in root.iterdir():
  if p.is_dir():shutil.copytree(p,target/p.name,dirs_exist_ok=True)
  else:shutil.copy2(p,target/p.name)
 staging.cleanup()
 if not args.audio_only:
  subprocess.run([sys.executable,str(BASE/'scripts/bake-melee-poses.py')],env={**__import__('os').environ,'FALCON_MOD_ROOT':str(target)},check=True)
 print('Imported',n,'vertices,',len(triangles),'triangles,',len(clips),'animation clips and',len(needed),'sounds')
if __name__=='__main__':main()
