"""Bake user-owned Falcon particle textures and scripts into private RoR sprites."""
import argparse,base64,hashlib,json,re,sys,struct
from pathlib import Path
import numpy as np
from PIL import Image
from melee_particles import Scene,emitter_events
from melee_sound_import import lua
BASE=Path(__file__).resolve().parents[1]

def gates(converted,name):
 source=(BASE/'tools/HSDLib/HSDRaw/Tools/Melee/ActionCommon.cs').read_text()
 sizes={int(c,16):max(32,6+sum(int(x.lstrip('x')) for x in bits.split('|')[1::2]))//8 for c,_,bits in re.findall(r'new MeleeCMDAction\(0x([0-9A-Fa-f]+),\s*"([^"]+)",\s*"([^"]*)"',source)}
 words=[5,5,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,3,3,2,1,4,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,3,3,2,1,4]
 sizes.update({10+i:n*4 for i,n in enumerate(words)})
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
   target=nodes[node]['refs'][str(start+4)]
   if code==5:calls.append((node,off))
   node,off=target,0
  elif code==6:
   if not calls:break
   node,off=calls.pop()
  elif code==21:events.append(frame)
 if len(events)!=2:raise ValueError(f'Expected Falcon effect on/off flags: {name}: {events}')
 return events

def build(root,converted):
 spec=json.loads((converted/'effects.json').read_text());out=root/'assets/melee-effects';out.mkdir(parents=True,exist_ok=True)
 clips={};audit={'archive_sha256':hashlib.sha256((BASE/'melee-source/files/EfCaData.dat').read_bytes()).hexdigest(),'models':{},'limitations':['Billboard particle port; the separate polygon effect meshes and the full GX renderer are not emulated.','Particle random seeds are deterministic; camera-facing projection and alpha comparison are adapted to RoR.']}
 for index in [0,2,3,5]:
  frames=Scene(spec,seed=index).bake(spec['models'][index]);nonempty=[n for n,f in enumerate(frames) if f.getbbox()]
  if not nonempty:raise ValueError(f'Empty original particle effect {index}')
  frames=frames[:nonempty[-1]+1]
  for image in frames:
   box=image.getbbox()
   if box and not (20<=box[0] and 40<=box[1] and box[2]<=108 and box[3]<=104):raise ValueError(f'Particle frame exceeds native sprite bounds: {index}: {box}')
  frames=[image.crop((20,40,108,104)) for image in frames]
  atlas=Image.new('RGBA',(88*len(frames),64))
  for n,image in enumerate(frames):atlas.paste(image,(n*88,0))
  name='effect'+str(index);atlas.save(out/(name+'.png'));clips[name]=len(frames)
  audit['models'][name]={'frames':len(frames),'width':88,'height':64,'first_visible':nonempty[0],'particle_events':[event for e in spec['models'][index]['emitters'] for event in emitter_events(e)],'png_sha256':hashlib.sha256((out/(name+'.png')).read_bytes()).hexdigest()}
 # Exact animated fighter joints keep the foot effect anchored through each kick.
 anchors={}
 for name,bone in [('kick',spec['anchors']['rightFoot']),('airkick',spec['anchors']['leftFoot'])]:
  model=json.loads((converted/'mesh.json').read_text());count=model['clips'][name]['frames']
  points=np.fromfile(converted/(name+'.joints.bin'),dtype='<f4').reshape(count,model['bones'],3)[:,bone]
  anchors[name]=[[round(float(p[2])*2/3,5),round(-float(p[1])*2/3,5)] for p in points]
 attrs=base64.b64decode(json.loads((converted/'motion.json').read_text())['attributes'])
 data={'clips':clips,'anchors':anchors,'airKickAngle':struct.unpack_from('>f',attrs,0x70)[0],'gates':{n:gates(converted,a) for n,a in [('punch','SpecialN'),('airpunch','SpecialAirN'),('kick','SpecialLw'),('airkick','SpecialAirLw')]}}
 (root/'melee_effect_data.lua').write_text('return '+lua(data)+'\n')
 (root/'melee-effect-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
 print('Baked original Falcon particles:',clips,'gates:',data['gates'])
 return data,audit
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--mod-root',type=Path,required=True);args=p.parse_args();build(args.mod_root,BASE/'melee-source/converted')
