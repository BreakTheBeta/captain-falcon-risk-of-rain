import sys
from pathlib import Path
from PIL import Image,ImageDraw
import struct,subprocess,os
b=Path(__file__).resolve().parents[1];root=Path(os.environ.get('FALCON_MOD_ROOT',b/'mods/CaptainFalcon'))
(b/'tmp').mkdir(exist_ok=True)
os.environ['FALCON_BUILD_TMP']=str(b/'tmp')
subprocess.run([sys.executable,str(b/'scripts/run-lua.py'),str(b/'scripts/build-falcon-selection.lua')],check=True)
data=(b/'tmp/selection-poses.bin').read_bytes();off=0;sheet=Image.new('RGBA',(28*13,74))
for frame in range(13):
 n=struct.unpack_from('<I',data,off)[0];off+=4;im=Image.new('RGBA',(56,148))
 for i in range(n):
  x,y,c=struct.unpack_from('<hhI',data,off);off+=8;x+=28;y+=124
  assert 0<=x<56 and 0<=y<148,(frame,x,y)
  im.putpixel((x,y),(c>>16,(c>>8)&255,c&255,255))
 sheet.paste(im.resize((28,74),Image.Resampling.BOX),(frame*28,0))
sheet.save(root/'assets/select.png')
# Selection/HUD icons describe actions and work with either input device.
icons=Image.new('RGBA',(72,18));d=ImageDraw.Draw(icons)
for i,name in enumerate(['jab1','punch','shield','taunt']):
 x=i*18;d.rounded_rectangle((x,0,x+17,17),radius=2,fill='#171827',outline='#9d824e')
 atlas=Image.open(root/'assets/melee-poses'/f'{name}.png');frame={'jab1':4,'punch':52,'shield':0,'taunt':20}[name];im=atlas.crop((frame*64,0,(frame+1)*64,64));bbox=im.getbbox();im=im.crop(bbox);im.thumbnail((14,14),Image.Resampling.LANCZOS);icons.alpha_composite(im,(x+(18-im.width)//2,(18-im.height)//2))
icons.save(root/'assets/skills.png')
print('Built native 28x74 selection frames and input-neutral skill icons')
