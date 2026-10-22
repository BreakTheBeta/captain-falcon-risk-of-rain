"""Reap Wine service children owned by this Gamescope launch after the game exits.
Only fixed helper names, the current prefix and this reaper's descendants match.
"""
import os,signal,time
from pathlib import Path
prefix=os.environ.get('WINEPREFIX')
helpers={'winedevice.exe','services.exe','explorer.exe','rpcss.exe','svchost.exe','wineboot.exe','conhost.exe','plugplay.exe'}
def parent(pid):
 try:
  text=(Path('/proc')/str(pid)/'stat').read_text();return int(text[text.rfind(')')+2:].split()[1])
 except (OSError,ValueError):return 0
reaper=0;pid=os.getppid()
while pid>1:
 try:
  if (Path('/proc')/str(pid)/'comm').read_text().strip().startswith('gamescopereape'):reaper=pid;break
 except OSError:break
 pid=parent(pid)
def owned(pid):
 try:
  p=Path('/proc')/str(pid)
  if (p/'comm').read_text().strip().lower() not in helpers:return False
  if ('WINEPREFIX='+prefix).encode() not in (p/'environ').read_bytes().split(b'\0'):return False
  q=parent(pid)
  for _ in range(64):
   if q==reaper:return True
   if q<=1:return False
   q=parent(q)
 except OSError:pass
 return False
if prefix and reaper:
 pids=[int(p.name) for p in Path('/proc').iterdir() if p.name.isdigit() and owned(int(p.name))]
 for pid in pids:
  try:os.kill(pid,signal.SIGTERM)
  except ProcessLookupError:pass
 if pids:time.sleep(.15)
 for pid in pids:
  if owned(pid):
   try:os.kill(pid,signal.SIGKILL)
   except ProcessLookupError:pass
