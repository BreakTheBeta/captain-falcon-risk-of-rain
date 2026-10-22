"""Audit Git's publishable index, never local generated game folders."""
import re,struct,subprocess,sys
from pathlib import Path
base=Path(__file__).resolve().parents[1]
files=subprocess.check_output(['git','ls-files','-z'],cwd=base).decode().split('\0')
errors=[]
allowed={'.cs','.csproj','.py','.lua','.md','.txt','.json','.sh','.yml','.yaml','.example','.gitignore','.gitattributes'}
for name in filter(None,files):
 p=base/name
 if not p.is_file():continue
 # Reviewed gameplay video and its animated README preview are the only media exceptions.
 if name in {'docs/media/falcon-showcase.mp4','docs/media/falcon-showcase-preview.gif'}:
  data=subprocess.check_output(['git','show',':'+name],cwd=base)
  valid=(len(data)>=12 and data[4:8]==b'ftyp') if p.suffix=='.mp4' else data[:6] in {b'GIF87a',b'GIF89a'}
  if not valid or len(data)>25*1024*1024:errors.append('Invalid or oversized gameplay showcase: '+name)
  continue
 # Only explicitly reviewed documentation captures may contain binary images.
 screenshot = name in {
  'docs/screenshots/survivor-selection.png',
  'docs/screenshots/falcon-gameplay.png',
  'docs/screenshots/falcon-punch-flames.png',
 }
 if screenshot:
  data=subprocess.check_output(['git','show',':'+name],cwd=base)
  if len(data)<33 or data[:8]!=b'\x89PNG\r\n\x1a\n' or data[8:16]!=b'\x00\x00\x00\x0dIHDR':
   errors.append('Invalid screenshot PNG: '+name)
  else:
   width,height=struct.unpack('>II',data[16:24])
   if not (640<=width<=3840 and 360<=height<=2160 and len(data)<=8*1024*1024):
    errors.append('Unexpected screenshot dimensions/size: '+name)
  continue
 if p.suffix not in allowed and p.name not in {'LICENSE','POD-LICENSE','.gitignore','.gitattributes'}:errors.append('Unexpected tracked format: '+name)
 if name.startswith(('build/','melee-source/','runtime/','downloads/','.venv/','.tools/')):errors.append('Local/private data: '+name)
 if name.startswith('mods/CaptainFalcon/melee_clip_') or p.name in {'melee_model.lua','melee_motion_data.lua','melee_sound_events.lua','melee_pose_sprites.lua','melee_effect_data.lua','melee-effect-audit.json','melee-import.json','melee-sound-audit.json'}:errors.append('Generated disc asset: '+name)
 # Inspect staged contents, since those are what the commit would publish.
 data=subprocess.check_output(['git','show',':'+name],cwd=base)
 if b'\0' in data:errors.append('Binary data: '+name);continue
 text=data.decode('utf-8-sig')
 if re.search(r'gh[oprsu]_[A-Za-z0-9]{30,}',text):errors.append('Possible credential: '+name)
 if '/home/'+'will/' in text or '100.104.'+'138.104' in text:errors.append('Machine-specific private path/address: '+name)
if errors:
 print('\n'.join(errors));sys.exit(1)
print('Source audit passed:',len(list(filter(None,files))),'tracked source/documentation files including reviewed gameplay media; no extracted game assets or machine-specific paths')
