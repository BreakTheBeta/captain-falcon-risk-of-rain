"""Import native TransN movement and command-var gates (ft_80085134).
Run FalconImport --motion first. No mesh or sound conversion is needed.
"""
import base64,json,re,struct,argparse
from pathlib import Path
from melee_sound_import import lua
base=Path(__file__).resolve().parents[1];converted=base/'melee-source/converted'
m=json.loads((converted/'motion.json').read_text())
src=(base/'tools/HSDLib/HSDRaw/Tools/Melee/ActionCommon.cs').read_text()
sizes={int(c,16):max(32,6+sum(int(x.lstrip('x')) for x in bits.split('|')[1::2]))//8 for c,_,bits in re.findall(r'new MeleeCMDAction\(0x([0-9A-Fa-f]+),\s*"([^"]+)",\s*"([^"]*)"',src)}
# Runtime table begins at opcode 10 (ftAction_803C0870).
words=[5,5,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,1,1,7,4,1,1,1,1,1,1,1,1,1,1,1,1,1,1,3,3,2,1,4]
sizes.update({10+i:n*4 for i,n in enumerate(words)})
def variables(name):
 nodes=json.loads(next(converted.glob('*_'+name+'_*.graph.json')).read_text());node=off=frame=0;calls=[];seen=set();events=[]
 while (node,off) not in seen:
  seen.add((node,off));data=base64.b64decode(nodes[node]['data'])
  if off>=len(data):break
  word=int.from_bytes(data[off:off+4],'big');code=word>>26;start=off
  if code==0:
   if not calls:break
   node,off=calls.pop();continue
  off+=sizes[code]
  if code==1:frame+=word&0x3ffffff
  elif code==2:frame=max(frame,word&0x3ffffff)
  elif code in (5,7):
   target=nodes[node]['refs'].get(str(start+4));assert target is not None
   if code==5:calls.append((node,off))
   node,off=target,0
  elif code==6:
   if not calls:break
   node,off=calls.pop()
  elif code==19:events.append([frame,(word>>24)&3,word&0xffffff])
 return events
attrs=base64.b64decode(m['attributes'])
out={'source':'PlCaAJ.dat TransN deltas; PlCa.dat command vars and special attributes','gravity':struct.unpack_from('>f',attrs,0x18)[0],'terminal':struct.unpack_from('>f',attrs,0x1c)[0],'missLanding':struct.unpack_from('>f',attrs,0x38)[0],'hitLanding':struct.unpack_from('>f',attrs,0x3c)[0],'kickLandingRate':struct.unpack_from('>f',attrs,0x80)[0],'clips':{}}
for name,points in m['curves'].items():
 out['clips'][name]={'velocity':[[round(p[1]-prev[1],7),round(-(p[0]-prev[0]),7)] for prev,p in zip(points,points[1:])],'vars':variables(name)}
parser=argparse.ArgumentParser();parser.add_argument('--target',type=Path,default=base/'mods/CaptainFalcon');args=parser.parse_args()
root=args.target;(root/'melee_motion_data.lua').write_text('return '+lua(out)+'\n')
for n,c in out['clips'].items():print(n,len(c['velocity']),c['vars'])
