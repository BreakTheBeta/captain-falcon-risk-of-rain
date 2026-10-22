#!/usr/bin/env python3
"""Run core tests without game files; --assets includes locally imported asset tests."""
import argparse,os,subprocess,sys
from pathlib import Path
base=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--assets',action='store_true');args=p.parse_args()
env={**os.environ,'FALCON_MOD_ROOT':os.environ.get('FALCON_MOD_ROOT',str(base/'mods/CaptainFalcon'))}
tests=['choice-crates','physics','smash-input','controller-canonical','defence-immunity','rope-jump','startup-input','death-state']
if args.assets:tests+=['keyboard-routing','controller-routing','jump-pads','melee-audio','native-pose-draw','animation-anchor','melee-renderer','melee-effects']
for name in tests:
 subprocess.run([sys.executable,str(base/'scripts/run-lua.py'),str(base/'tests'/f'test-{name}.lua')],env=env,cwd=base,check=True)
if args.assets:subprocess.run([sys.executable,str(base/'tests/test-particle-import.py')],env=env,cwd=base,check=True)
subprocess.run([sys.executable,str(base/'tests/test-launcher.py')],cwd=base,check=True)
print(f'Passed {len(tests)} Lua suites and launcher process checks')
