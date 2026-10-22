"""Deploy source edits to the local play folder without rebuilding assets or saves."""
import fcntl,json,shutil,os
from pathlib import Path
base=Path(__file__).resolve().parents[1]
runtime=Path(json.loads(Path(os.environ.get('FALCON_CONFIG',base/'config/local.json')).read_text())['runtime'])
with (runtime/'game.lock').open('a') as lock:
 fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 for name in ['CaptainFalcon','ThreeChoiceCommand']:
  for p in (base/'mods'/name).iterdir():
   if p.is_file() and p.suffix in ['.lua','.json']:shutil.copy2(p,runtime/'mods'/name/p.name)
 print('Updated mod source. Launch again to load it. Assets and saves preserved.')
