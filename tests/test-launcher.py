"""Verify Gamescope wrapping, tracked child status and lock release without a display."""
import json,os,subprocess,tempfile,unittest
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
class LauncherTest(unittest.TestCase):
 def run_launcher(self,status=0):
  with tempfile.TemporaryDirectory(prefix='falcon-launch-') as td:
   root=Path(td);runtime=root/'play folder';runtime.mkdir();bin=root/'bin';bin.mkdir();log=root/'calls.jsonl'
   (runtime/'falcon-ready.json').write_text('{}');(runtime/'prefs.json').write_text('{"video":{}}')
   conf=root/'local.json';conf.write_text(json.dumps({'profile':'ExistingSave','runtime':str(runtime),'wineprefix':str(root/'prefix'),'logs':str(root/'logs')}))
   def executable(name,body):
    p=bin/name;p.write_text('#!/usr/bin/env python3\n'+body);p.chmod(0o755)
   executable('gamescope',"import os,sys,json\nwith open(os.environ['FALCON_TEST_LOG'],'a') as f:f.write(json.dumps(['gamescope',*sys.argv[1:]])+'\\n')\na=sys.argv[sys.argv.index('--')+1:];os.execvp(a[0],a)\n")
   executable('wine',"import os,sys,json\nwith open(os.environ['FALCON_TEST_LOG'],'a') as f:f.write(json.dumps(['wine',*sys.argv[1:]])+'\\n')\nsys.exit(0 if sys.argv[1]=='reg' else int(os.environ['FALCON_TEST_EXIT']))\n")
   executable('winepath',"import sys\nprint('Z:'+sys.argv[-1])\n")
   executable('wineserver','import sys\nsys.exit(0)\n')
   executable('xdotool','import sys\nsys.exit(1)\n')
   env={**os.environ,'PATH':str(bin)+':'+os.environ['PATH'],'FALCON_CONFIG':str(conf),'FALCON_TEST_LOG':str(log),'FALCON_TEST_EXIT':str(status),'FALCON_GAMESCOPE':'1'}
   for name in ['FALCON_INSIDE_GAMESCOPE','GAMESCOPE_WAYLAND_DISPLAY','FALCON_LAUNCH_LOCK']:env.pop(name,None)
   result=subprocess.run([str(BASE/'launch.sh')],env=env,timeout=10,capture_output=True,text=True)
   calls=[json.loads(x) for x in log.read_text().splitlines()]
   scopes=[x for x in calls if x[0]=='gamescope'];self.assertEqual(len(scopes),1)
   self.assertIn('-f',scopes[0]);self.assertEqual(scopes[0][scopes[0].index('-w')+1],'1280')
   games=[x for x in calls if x[0]=='wine' and x[1]!='reg'];self.assertEqual(games,[['wine','Z:'+str(runtime/'RoRML.exe')]])
   self.assertEqual(result.returncode,status,result.stderr)
   self.assertIn('profile=ExistingSave',(runtime/'launchersettings.ini').read_text())
   self.assertEqual(subprocess.run(['flock','-n',str(runtime/'game.lock'),'true']).returncode,0,'Launcher lock must be released')
 def test_gamescope_wraps_actual_game_once(self):self.run_launcher()
 def test_game_failure_propagates_and_releases_lock(self):self.run_launcher(7)
if __name__=='__main__':unittest.main()
