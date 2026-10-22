#!/usr/bin/env python3
"""Build a private playable installation from the owner's games (Linux/Wine)."""
import argparse,ctypes.util,fcntl,hashlib,importlib.util,json,os,shutil,struct,subprocess,sys,tarfile,urllib.request,zipfile
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
DOWNLOADS=BASE/'downloads'
RORMl_URL='https://cdn.rainfusion.net/game-download'
RORMl_SHA='2e43a0f3fce6557204e61d282b13f1a3180cb7aeea7d48fc0c22328b15a6e0a5'
DXVK_URL='https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1.tar.gz'
DXVK_SHA='d85ce7c79f57ecd765aaa1b9e7007cb875e6fde9f6d331df799bce73d513ce87'

def run(args,**kwargs):subprocess.run([str(a) for a in args],check=True,**kwargs)
def download(url,path,sha=None):
 path.parent.mkdir(parents=True,exist_ok=True)
 if not path.exists():
  print('Downloading',url,flush=True);tmp=path.with_suffix(path.suffix+'.part')
  with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'FalconRain-Setup'}),timeout=60) as src,tmp.open('wb') as out:shutil.copyfileobj(src,out)
  tmp.replace(path)
 if sha and hashlib.sha256(path.read_bytes()).hexdigest()!=sha:raise ValueError(f'Checksum mismatch: {path}. Remove this file and retry.')
 return path

def doctor():
 if sys.platform!='linux':raise ValueError('Automated setup currently supports Linux/Wine. See docs/INSTALL.md.')
 missing=[name for name in ['wine','winepath','ffmpeg','flock'] if not shutil.which(name)]
 if not ctypes.util.find_library('lua5.4'):missing.append('liblua5.4')
 if missing:raise ValueError('Missing '+', '.join(missing)+'. See the prerequisite command in README.md.')
 print('System tools found. You also need a working Vulkan driver, including 32-bit support.')

def game_data(directory):
 directory=Path(directory).expanduser().resolve()
 for p in [directory/'data.win',directory/'game.unx',directory/'assets/game.unx',directory/'assets/data.win']:
  if p.is_file():return p
 raise ValueError(f'No original Risk of Rain data.win or assets/game.unx in {directory}. Returns and RoR2 are not supported.')

def find_game():
 for root in [Path.home()/'.steam/steam/steamapps',Path.home()/'.local/share/Steam/steamapps',Path.home()/'.steam/debian-installation/steamapps']:
  roots=[root]
  manifest=root/'libraryfolders.vdf'
  if manifest.exists():
   import re
   roots += [Path(x.replace('\\\\','\\'))/'steamapps' for x in re.findall(r'"path"\s*"([^"]+)"',manifest.read_text())]
  for library in roots:
   candidate=library/'common/Risk of Rain'
   try:game_data(candidate);return candidate
   except ValueError:pass
 raise ValueError('Steam game folder not found. Supply --game-dir "/path/to/Risk of Rain".')

def dotnet():
 path=os.environ.get('FALCON_DOTNET') or shutil.which('dotnet')
 if path:return path
 path=BASE/'.tools/dotnet/dotnet'
 if not path.exists():
  installer=download('https://dot.net/v1/dotnet-install.sh',BASE/'.tools/dotnet-install.sh')
  run(['bash',installer,'--version','8.0.426','--install-dir',path.parent])
 return str(path)

def unpack_loader(archive,output):
 # Loader runtime is downloaded locally, never committed or bundled in releases.
 with zipfile.ZipFile(archive) as z:
  for info in z.infolist():
   rel=Path(info.filename)
   if rel.is_absolute() or '..' in rel.parts or '\\' in info.filename:raise ValueError('Unsafe loader archive path')
  z.extractall(output)
 if not (output/'RoRML.exe').is_file():raise ValueError('Loader archive is missing RoRML.exe')

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--melee',type=Path,help='Your local Melee ISO/GCM/RVZ or ZIP containing one disc')
 parser.add_argument('--game-dir',type=Path,help='Original Steam Risk of Rain folder (auto-detected if omitted)')
 parser.add_argument('--output',type=Path,default=BASE/'build/play',help='New private play folder')
 parser.add_argument('--rorml-zip',type=Path,help='Optional local RoRML 1.0.1 ZIP (pinned checksum checked)')
 parser.add_argument('--dxvk-archive',type=Path,help='Optional local DXVK 2.7.1 archive')
 parser.add_argument('--check',action='store_true',help='Check system prerequisites only')
 args=parser.parse_args();doctor()
 if args.check:return
 if not args.melee:
  if sys.stdin.isatty():args.melee=Path(input('Path to your Melee disc dump: ').strip().strip('"'))
  else:parser.error('--melee is required; e.g. ./setup.sh --melee "/path/to/Melee.iso"')
 if not args.melee.expanduser().is_file():raise ValueError('Melee disc file does not exist')
 data=game_data(args.game_dir or find_game());output=args.output.expanduser().resolve()
 # Never overwrite a game installation or a previous play folder/save.
 if output.exists():raise ValueError(f'{output} already exists. Launch it, or choose a new --output folder for a fresh build.')
 if output==data.parent or data.is_relative_to(output):raise ValueError('Choose a separate output folder, outside the Steam game folder')
 DOWNLOADS.mkdir(exist_ok=True);(BASE/'build').mkdir(exist_ok=True)
 with (BASE/'build/install.lock').open('w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  loader=args.rorml_zip or download(RORMl_URL,DOWNLOADS/'RoRML-1.0.1.zip',RORMl_SHA)
  if hashlib.sha256(loader.read_bytes()).hexdigest()!=RORMl_SHA:raise ValueError('Expected the tested RoRML 1.0.1 ZIP; checksum differs')
  dxvk=args.dxvk_archive or download(DXVK_URL,DOWNLOADS/'dxvk-2.7.1.tar.gz',DXVK_SHA)
  if hashlib.sha256(dxvk.read_bytes()).hexdigest()!=DXVK_SHA:raise ValueError('Expected DXVK 2.7.1; checksum differs')
  sdk=dotnet();output.mkdir(parents=True)
  unpack_loader(loader,output)
  spec=importlib.util.spec_from_file_location('extract_ror',BASE/'scripts/extract-ror.py');extractor=importlib.util.module_from_spec(spec);spec.loader.exec_module(extractor)
  print('Extracting sound resources from your Steam installation...',flush=True)
  count=extractor.extract(data,output/'resources/sound');print('Extracted',count,'sound resources',flush=True)
  with tarfile.open(dxvk) as t:
   for name in ['d3d11.dll','dxgi.dll']:
    member=t.getmember('dxvk-2.7.1/x32/'+name)
    with t.extractfile(member) as src,(output/name).open('wb') as dst:shutil.copyfileobj(src,dst)
  (output/'dxvk.conf').write_text('dxgi.customRefreshRate = 60\ndxgi.maxFrameRate = 60\ndxgi.syncInterval = 0\n')
  for name in ['CaptainFalcon','ThreeChoiceCommand']:shutil.copytree(BASE/'mods'/name,output/'mods'/name,ignore=shutil.ignore_patterns('__pycache__'))
  env={**os.environ,'FALCON_DOTNET':str(sdk),'FALCON_MOD_ROOT':str(output/'mods/CaptainFalcon'),'DOTNET_CLI_TELEMETRY_OPTOUT':'1'}
  run([sys.executable,BASE/'scripts/build-falcon-art.py'],env=env)
  run([sys.executable,BASE/'scripts/import-melee.py','--source',args.melee.expanduser().resolve(),'--mod-root',output/'mods/CaptainFalcon'],env=env)
  profile=output/'profiles/FalconRain';profile.mkdir(parents=True,exist_ok=True)
  (profile/'profile.json').write_text(json.dumps({'mods':['Three-Choice Command','Captain Falcon'],'flags':[]},indent=2)+'\n')
  shutil.copy2(BASE/'config/prefs.json',output/'prefs.json')
  (output/'launchersettings.ini').write_text('[launcher]\nprofile=FalconRain\n')
  config={'runtime':str(output),'wineprefix':str(output.parent/'wineprefix'),'logs':str(output.parent/'logs'),'game_source_sha256':hashlib.sha256(data.read_bytes()).hexdigest()}
  (BASE/'config/local.json').write_text(json.dumps(config,indent=2)+'\n')
  (output/'falcon-ready.json').write_text(json.dumps({'version':'0.4.5','disc':json.loads((output/'mods/CaptainFalcon/melee-import.json').read_text())['provenance']['disc_id']}))
  print('\nReady. Run ./launch.sh, or add that script to Steam as a non-Steam game.')

if __name__=='__main__':
 try:main()
 except (ValueError,OSError,subprocess.CalledProcessError) as e:print('Setup stopped:',e,file=sys.stderr);sys.exit(1)
