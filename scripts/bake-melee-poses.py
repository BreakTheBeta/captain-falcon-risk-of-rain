import sys
from pathlib import Path
import struct,subprocess,json,os
from PIL import Image
base=Path(__file__).resolve().parents[1]
root=Path(os.environ.get('FALCON_MOD_ROOT',base/'mods/CaptainFalcon'))
(base/'tmp').mkdir(exist_ok=True)
os.environ['FALCON_BUILD_TMP']=str(base/'tmp')
subprocess.run([sys.executable,str(base/'scripts/run-lua.py'),str(base/'scripts/bake-melee-poses.lua')],check=True)
out=root/'assets/melee-poses';out.mkdir(exist_ok=True);clips={}
for path in sorted((base/'tmp').glob('pose-*.bin')):
 data=path.read_bytes();frames=struct.unpack_from('<I',data)[0];off=4;atlas=Image.new('RGBA',(64*frames,64))
 for f in range(frames):
  count=struct.unpack_from('<I',data,off)[0];off+=4;im=Image.new('RGBA',(128,128))
  for n in range(count):
   x,y,c=struct.unpack_from('<hhI',data,off);off+=8;x+=64;y+=96
   assert 0<=x<128 and 0<=y<128,(path,f,x,y)
   im.putpixel((x,y),(c>>16,(c>>8)&255,c&255,255))
  atlas.paste(im.resize((64,64),Image.Resampling.BOX),(64*f,0))
 name=path.stem.removeprefix('pose-');atlas.save(out/(name+'.png'));clips[name]=frames
(root/'melee_pose_sprites.lua').write_text('return {'+','.join('['+json.dumps(k)+']='+str(v) for k,v in clips.items())+'}\n')
print('Wrote',len(clips),'supersampled animation strips;',sum(clips.values()),'frames')

# Refresh menu artwork from the same model whenever imported poses change.
subprocess.run([sys.executable,str(base/"scripts/build-falcon-selection.py")],env={**os.environ,"FALCON_MOD_ROOT":str(root)},check=True)
