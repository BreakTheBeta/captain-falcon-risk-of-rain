"""Audit Git's publishable index, never local generated game folders."""
import re,subprocess,sys
from pathlib import Path
base=Path(__file__).resolve().parents[1]
files=subprocess.check_output(['git','ls-files','-z'],cwd=base).decode().split('\0')
errors=[]
allowed={'.cs','.csproj','.py','.lua','.md','.txt','.json','.sh','.yml','.yaml','.example','.gitignore','.gitattributes'}
for name in filter(None,files):
 p=base/name
 if not p.is_file():continue
 if p.suffix not in allowed and p.name not in {'LICENSE','POD-LICENSE','.gitignore','.gitattributes'}:errors.append('Unexpected tracked format: '+name)
 if name.startswith(('build/','melee-source/','runtime/','downloads/','.venv/','.tools/')):errors.append('Local/private data: '+name)
 if name.startswith('mods/CaptainFalcon/melee_clip_') or p.name in {'melee_model.lua','melee_motion_data.lua','melee_sound_events.lua','melee_pose_sprites.lua','melee-import.json','melee-sound-audit.json'}:errors.append('Generated disc asset: '+name)
 # Inspect staged contents, since those are what the commit would publish.
 data=subprocess.check_output(['git','show',':'+name],cwd=base)
 if b'\0' in data:errors.append('Binary data: '+name);continue
 text=data.decode('utf-8-sig')
 if re.search(r'gh[oprsu]_[A-Za-z0-9]{30,}',text):errors.append('Possible credential: '+name)
 if '/home/'+'will/' in text or '100.104.'+'138.104' in text:errors.append('Machine-specific private path/address: '+name)
if errors:
 print('\n'.join(errors));sys.exit(1)
print('Source audit passed:',len(list(filter(None,files))),'tracked source/documentation files; no game assets or machine-specific paths')
