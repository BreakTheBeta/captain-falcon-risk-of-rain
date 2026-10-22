import json,sys,os
from pathlib import Path
base=Path(__file__).resolve().parents[1]
p=Path(os.environ.get('FALCON_CONFIG',base/'config/local.json'))
if not p.exists():sys.exit('Run ./setup.sh --melee "/path/to/Melee.iso" first.')
d=json.loads(p.read_text())
if not (Path(d['runtime'])/'falcon-ready.json').exists():sys.exit('Setup did not complete. See docs/INSTALL.md.')
for name in ['runtime','wineprefix','logs']:print(d[name])

print(d.get('profile','FalconRain'))
