"""Melee sound IDs address SEM scripts, which select SSM PCM samples.
Source: HSDLib/Sound/SEM.cs and doldecomp/melee axdriver.c / ftaction.c.
"""
import base64,hashlib,json,math,re,struct,subprocess,wave
from pathlib import Path
SILENT=540000
class SemTable:
 def __init__(self,path,banks):
  self.data=Path(path).read_bytes();n=struct.unpack_from('>I',self.data,8)[0]
  self.starts=struct.unpack_from('>'+str(n+1)+'I',self.data,12);self.offsets=12+(n+1)*4;self.banks=banks
 def resolve(self,id):
  bank,local=divmod(id,10000)
  if bank not in self.banks or local>=self.starts[bank+1]-self.starts[bank]:return None
  a,b=struct.unpack_from('>II',self.data,self.offsets+(self.starts[bank]+local)*4);raw=self.data[a:b or len(self.data)]
  ops=[(raw[i],int.from_bytes(raw[i+1:i+4],'big')) for i in range(0,len(raw),4)]
  samples=[v&65535 for op,v in ops if op==1]
  if len(samples)!=1:raise ValueError(f'Unsupported SEM sample program {id}: {samples}')
  start,count=self.banks[bank];sample=samples[0]-start
  if not 0<=sample<count:raise ValueError(f'Invalid SEM sample {id}: {sample}')
  pitch=0;volume=255
  for op,v in ops:
   if op==12:pitch=(v&65535)-65536 if v&32768 else v&65535
   if op==6:volume=v&255
   if op in [0,7,13,14,15]:break
  return {'bank':bank,'sample':sample,'global_sample':samples[0],'pitch_cents':pitch,'pitch':2**(pitch/1200),'volume':volume/255,'dynamic_pitch':any(op==13 for op,_ in ops),'dynamic_volume':any(op==7 for op,_ in ops),'sem_ops':ops}
def compile_events(data,command_sizes,smash,graph=None,max_frame=1000):
 nodes=[{'bytes':base64.b64decode(n['data']),'refs':n['refs']} for n in graph] if graph else [{'bytes':data,'refs':{}}]
 events=[];off=0;frame=0;loops=[];warnings=[];node=0;calls=[];seen=set()
 for _ in range(4096):
  if frame>max_frame:break
  data=nodes[node]['bytes']
  if off>=len(data):break
  state=(node,off)
  if state in seen:break # animation cycles are repeated by the runtime
  seen.add(state)
  code=data[off]>>2
  if code==0:
   if calls:node,off=calls.pop();continue
   break
  size=command_sizes.get(code)
  if not size or off+size>len(data):warnings.append({'offset':off,'opcode':code,'reason':'unparsed command'});break
  block=data[off:off+size];word=int.from_bytes(block[:4],'big');start=off;off+=size
  if code==1:frame+=word&0x3ffffff
  elif code==2:frame=max(frame,word&0x3ffffff)
  elif code==3:loops.append([off,word&0x3ffffff])
  elif code==4:
   if loops:
    loops[-1][1]-=1
    if loops[-1][1]>0:off=loops[-1][0]
    else:loops.pop()
  elif code in [5,7]:
   target=nodes[node]['refs'].get(str(start+4))
   if target is None:warnings.append({'offset':start,'opcode':code,'reason':'unresolved command pointer'});break
   if code==5:calls.append((node,off))
   node,off=target,0
  elif code==6:
   if calls:node,off=calls.pop()
   else:break
  elif code==17:
   behavior=(word>>18)&255;id=int.from_bytes(block[4:8],'big');vol=block[10];pan=block[11]
   events.append({'frame':frame,'ids':[id],'volume':vol/127,'pan':pan,'behavior':behavior})
  elif code==18:events.append({'frame':frame,'ids':smash,'volume':1,'pan':64,'behavior':2})
  elif code==38:
   count=word&63;assert 1<=count<=6
   choices=[int.from_bytes(block[i:i+4],'big') for i in range(4,4+count*4,4)]
   events.append({'frame':frame,'ids':choices,'volume':((word>>18)&255)/127,'pan':(word>>10)&255,'behavior':(word>>6)&15})
  elif code in [54,55]:
   # RoR has no Melee stage-material metadata; use the script's own fallback.
   if size>=12:events.append({'frame':frame,'ids':[int.from_bytes(block[4:8],'big')],'volume':block[10]/127,'pan':block[11],'behavior':0,'material_fallback':True})
 else:warnings.append({'reason':'script iteration limit'})
 return events,warnings

def lua(obj):
 if isinstance(obj,dict):return '{'+','.join('['+json.dumps(str(k))+']='+lua(v) for k,v in obj.items())+'}'
 if isinstance(obj,(list,tuple)):return '{'+','.join(lua(v) for v in obj)+'}'
 if isinstance(obj,bool):return 'true' if obj else 'false'
 if obj is None:return 'nil'
 return str(obj) if isinstance(obj,(int,float)) else json.dumps(obj)
def import_audio(root,source,converted,clips,decode_ssm,base):
 files=source/'files';banks={};bankinfo={}
 for bank,name in [(0,'main'),(6,'captain')]:
  path=files/f'{name}.ssm';banks[bank]=decode_ssm(path);bankinfo[bank]=(struct.unpack_from('>I',path.read_bytes(),12)[0],len(banks[bank]))
 sem=SemTable(files/'smash2.sem',bankinfo);common=json.loads((converted/'common-sounds.json').read_text())
 src=(base/'tools/HSDLib/HSDRaw/Tools/Melee/ActionCommon.cs').read_text();sizes={int(code,16):max(32,6+sum(int(x.lstrip('x')) for x in bits.split('|')[1::2]))//8 for code,_,bits in re.findall(r'new MeleeCMDAction\(0x([0-9A-Fa-f]+),\s*"([^"]+)",\s*"([^"]*)"',src)}
 # Native command sizes from ftAction_803C0870; HSDLib's names/sizes
 # after opcode 0x34 are outdated for these fighter scripts.
 native_words=[5, 5, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 7, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 2, 1, 4]
 sizes.update({10+i:n*4 for i,n in enumerate(native_words)})
 events={};warnings={};needed=set()
 for name,clip in clips.items():
  path=converted/(clip['symbol']+'.cmd');graphpath=path.with_suffix('.graph.json')
  graph=json.loads(graphpath.read_text()) if graphpath.exists() else None
  ev,warn=compile_events(path.read_bytes() if path.exists() else b'',sizes,common['smash'],graph,clip['frames']);events[name]=ev
  if warn:warnings[name]=warn
  for event in ev:
   if event['behavior']<=6:
    for id in event['ids']:
     if id not in [540000,540001]:
      if sem.resolve(id) is None:raise ValueError(f'Unsupported sound bank: {id} for {name}')
      needed.add(id)
 # Engine-level shield cues, from ftCo_Guard.c. Frame scripts contain no cues.
 engine={'shield_on':110,'shield_off':127,'shield_break':129}
 needed.update(engine.values());needed.update(id for id in common['smash'] if sem.resolve(id))
 for name,id in common.items():
  if isinstance(id,int) and sem.resolve(id):needed.add(id)
 definitions={};out=root/'assets/melee-sounds';out.mkdir(parents=True,exist_ok=True)
 for id in sorted(needed):
  definition=sem.resolve(id);rate,pcm=banks[definition['bank']][definition['sample']];definition.update({'rate':rate,'samples':len(pcm),'pcm_sha256':hashlib.sha256(pcm.tobytes()).hexdigest()});definitions[str(id)]=definition
  wav=out/f'{id}.wav';ogg=wav.with_suffix('.ogg')
  with wave.open(str(wav),'wb') as w:w.setnchannels(pcm.shape[1]);w.setsampwidth(2);w.setframerate(rate);w.writeframes(pcm.tobytes())
  # Retain exact PCM for auditing; this GameMaker loader requires Ogg playback.
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','10',str(ogg)],check=True)
  definition['audio_format']='ogg';definition['audit_format']='wav'
 spec={'ids':sorted(needed),'definitions':definitions,'events':events,'common':common,'engine':engine,'lengths':{name:clip['frames'] for name,clip in clips.items()}}
 (root/'melee_sound_events.lua').write_text('return '+lua(spec)+'\n')
 report={'sem_sha256':hashlib.sha256((files/'smash2.sem').read_bytes()).hexdigest(),'definitions':definitions,'actions':events,'warnings':warnings,'limitations':['SEM pitch/volume automation and reverb buses are not emulated; initial pitch/volume are preserved.','Footsteps use script fallback sounds because RoR lacks Melee stage-material data.','RoR collision/hit/hurt audio remains RoR audio; full Melee hit/shield-impact mixing is not reproduced.']}
 (root/'melee-sound-audit.json').write_text(json.dumps(report,indent=2)+'\n');return sorted(needed),report
