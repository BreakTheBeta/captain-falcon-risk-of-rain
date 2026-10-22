"""Offline interpreter for the particle commands present in EfCaData.dat.

The decoded assets stay private. RoR uses baked billboard strips instead of
running Melee's GX renderer and particle engine during gameplay.
Native reference: doldecomp/melee sysdolphin/baselib/{particle,generator,psdisptev}.c.
This is a 2D adaptation: generator cone orientation, AppSRT groups, blend modes
and alpha comparison do not reproduce the full native engine.
"""
import base64, math, random, struct
import numpy as np
from PIL import Image

def emitter_events(emitter):
 """Decode HSD_A_OP_KEY particle IDs, including multiple keys per track."""
 data=bytes.fromhex(emitter['buffer']);pc=0;clock=round(-emitter['start']);events=[]
 def packed():
  nonlocal pc
  value=shift=0
  while True:
   b=data[pc];pc+=1;value|=(b&127)<<shift
   if not b&128:return value
   shift+=7
   if shift>28:raise ValueError('Invalid particle animation key')
 while pc<len(data):
  code=packed()
  if not code:break
  if code&15!=6:raise ValueError('Expected particle KEY animation')
  for _ in range((code>>4)+1):
   value=int.from_bytes(data[pc:pc+4],'little');pc+=4
   events.append((max(0,clock),value&63,value>>6));clock+=packed()
 return events

class Particle:
 def __init__(self, scene, index, matrix, offset=None, curve=None):
  self.curve=curve;self.scene=scene;self.g=scene.spec['generators'][index];self.code=base64.b64decode(self.g['commands']);self.pc=0;self.wait=1;self.loop=0;self.mark=0;self.loop_pc=0
  self.life=self.g['life'];self.size=self.g['size'];self.size_target=self.size;self.size_count=0;self.rotate=0;self.rotate_target=0;self.rotate_count=0
  self.prim=np.array([255.,255.,255.,255.]);self.env=np.zeros(4);self.interp={};self.pose=0;self.textured=False;self.flip=False;self.mirror_s=False;self.mirror_t=False;self.directional=False
  self.matrix=matrix;self.pos=np.array(offset if offset is not None else matrix[9:12],dtype=float)
  self.vel=np.array([self.g['vx'],self.g['vy'],self.g['vz']],dtype=float)@np.array(matrix[:9]).reshape(3,3)
  radius=self.g['radius'];theta=scene.rng.random()*2*math.pi;r=abs(radius)*(scene.rng.random() if radius>=0 else 1)
  self.pos+=np.array([r*math.cos(theta),r*math.sin(theta),0])@np.array(matrix[:9]).reshape(3,3)
 def byte(self):
  if self.pc>=len(self.code):raise ValueError('Truncated particle command')
  v=self.code[self.pc];self.pc+=1;return v
 def count(self):
  v=self.byte();return ((v&127)<<8)+self.byte() if v&128 else v
 def float(self):
  v=struct.unpack_from('>f',self.code,self.pc)[0];self.pc+=4;return v
 def short(self):return self.byte()*256+self.byte()
 def color(self,op):
  name='prim' if op<0xd0 else 'env';arr=getattr(self,name);count=self.count();target=arr.copy()
  for channel in range(4):
   if op&(1<<channel):target[channel]=self.byte()
  if count:self.interp[name]=(target,count)
  else:setattr(self,name,target);self.interp.pop(name,None)
 def tick(self):
  for name,(target,n) in list(self.interp.items()):
   arr=getattr(self,name);arr+=(target-arr)/n
   if n<=1:self.interp.pop(name)
   else:self.interp[name]=(target,n-1)
  if self.size_count:self.size+=(self.size_target-self.size)/self.size_count;self.size_count-=1
  if self.rotate_count:self.rotate+=(self.rotate_target-self.rotate)/self.rotate_count;self.rotate_count-=1
  self.wait-=1
  if self.wait<=0:
   for _ in range(512):
    op=self.byte();wait=0
    if op<0x80:
     wait=op&31
     if op&32:wait=wait*256+self.byte()
     if op&64:self.pose=self.byte();self.textured=True
    elif 0xc0<=op<=0xdf:self.color(op)
    elif op in (0xa0,0xac):
     self.size_count=self.count();self.size_target=self.float()
     if op==0xac:self.size_target+=self.float()*self.scene.rng.random()
     if not self.size_count:self.size=self.size_target
    elif op in (0xa5,0xef):
     idx=self.short()-self.scene.spec['start']
     if op==0xef:self.byte() # GX/AppSRT group flags do not change sprite pixels.
     self.scene.spawn(idx,self.matrix,self.pos.copy(),self.curve)
    elif op==0xbd:
     speed=self.float()+self.float()*self.scene.rng.random();mag=np.linalg.norm(self.vel)
     if mag>1e-10:self.vel*=speed/mag
    elif op==0xb3:
     self.count();self.pc+=3 # Alpha-compare state; RoR uses the baked alpha channel.
    elif op==0xb6:
     self.rotate_count=self.count();self.rotate_target+=self.float()
     if not self.rotate_count:self.rotate=self.rotate_target
    elif op==0xbc:self.pose=self.byte()+int(self.byte()*self.scene.rng.random());self.textured=True
    elif op==0xad:pass # GX primary/environment interpolation is applied below.
    elif op in (0xb0,0xb1):self.mirror_t=True;self.mirror_s=op==0xb1
    elif op==0xb4:pass # Offline resampling replaces GX texture filtering.
    elif op==0xe6:self.directional=True
    elif op==0xe4:
     mode=self.byte()&3
     self.flip=not self.flip if mode==2 else (self.scene.rng.random()<.5 if mode==3 else mode==1)
    elif op==0xfa:self.loop=self.byte();self.loop_pc=self.pc
    elif op==0xfb:
     self.loop-=1
     if self.loop:self.pc=self.loop_pc
    elif op==0xfc:self.mark=self.pc
    elif op==0xfd:self.pc=self.mark
    elif op in (0xfe,0xff):self.life=0;return
    else:raise ValueError(f'Unsupported Captain particle opcode {op:#x} at {self.pc-1}')
    if wait:self.wait=wait;break
   else:raise ValueError('Particle bytecode exceeded command budget')
  self.life-=1
  if self.g['kind']&1:self.vel[1]-=self.g['gravity']
  if self.g['kind']&2:self.vel*=self.g['friction']
  self.pos+=self.vel
 def image(self):
  if not self.textured or self.life<=0 or self.size<=0:return None
  tex=self.scene.textures[self.g['texture']];im=tex[min(self.pose,len(tex)-1)]
  # GX interpolates environment -> primary color using the texture channels.
  pixels=np.asarray(im).astype(float)/255
  pixels=self.env[None,None,:]+(self.prim-self.env)[None,None,:]*pixels
  image=Image.fromarray(np.uint8(np.clip(pixels,0,255)),'RGBA')
  if self.mirror_s:
   pair=Image.new('RGBA',(image.width*2,image.height));pair.paste(image,(0,0));pair.paste(image.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(image.width,0));image=pair
  if self.mirror_t:
   pair=Image.new('RGBA',(image.width,image.height*2));pair.paste(image.transpose(Image.Transpose.FLIP_TOP_BOTTOM),(0,0));pair.paste(image,(0,image.height));image=pair
  side=max(1,min(512,round(self.size*2*self.scene.scale)))
  image=image.resize((side,side),Image.Resampling.BOX)
  if self.flip:image=image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
  rotation=math.degrees(self.rotate)
  if self.directional:rotation+=math.degrees(math.atan2(self.vel[1],self.vel[2]))-90
  if rotation:image=image.rotate(rotation,expand=True,resample=Image.Resampling.BICUBIC)
  return image

class Scene:
 def __init__(self,spec,seed=0):
  self.spec=spec;self.rng=random.Random(seed);self.particles=[];self.generators=[];self.scale=4/3
  self.textures={t['index']:[Image.frombytes('RGBA',(t['width'],t['height']),base64.b64decode(b),'raw','BGRA') for b in t['images']] for t in spec['textures']}
 def spawn(self,index,matrix,offset=None,curve=None):
  if not 0<=index<len(self.spec['generators']):raise ValueError(f'Unknown particle generator {index}')
  self.generators.append({'index':index,'age':0,'count':self.rng.random(),'matrix':matrix,'offset':offset,'curve':curve})
 def frame(self,emitters,frame):
  self.particles=[p for p in self.particles if p.life>0]
  for p in list(self.particles):p.tick()
  for e in emitters:
   for start,bank,id in emitter_events(e):
    if frame==start:
     if bank!=4:raise ValueError('Unexpected particle bank')
     self.spawn(id-self.spec['start'],e['matrices'][min(frame,len(e['matrices'])-1)],curve=e['matrices'])
  # Resolve one-frame wrapper generators in the same frame, with a hard cap.
  queue=list(self.generators);self.generators=[];budget=0
  while queue:
   gen=queue.pop(0);budget+=1
   if budget>2048:raise ValueError('Particle generator budget exceeded')
   g=self.spec['generators'][gen['index']]
   if gen['age']>=max(1,g['genLife']):continue
   gen['count']+=-g['random'] if g['random']<0 else g['random']*self.rng.random()
   matrix=gen['curve'][min(frame,len(gen['curve'])-1)] if gen['curve'] else gen['matrix']
   offset=gen['offset']
   if offset is not None and gen['curve']:offset=offset+np.array(matrix[9:12])-np.array(gen['matrix'][9:12])
   while gen['count']>=1:
    p=Particle(self,gen['index'],matrix,offset,gen['curve']);p.tick()
    if p.life>0:self.particles.append(p)
    gen['count']-=1
   gen['age']+=1
   # New child generators were queued by the particle command interpreter.
   queue.extend(self.generators);self.generators=[]
   if gen['age']<max(1,g['genLife']):self._survivors.append(gen)
  self.generators=self._survivors;self._survivors=[]
  canvas=Image.new('RGBA',(256,256))
  alive=[]
  for p in self.particles:
   image=p.image()
   if image is not None:
    x=round(128+p.pos[2]*self.scale-image.width/2);y=round(160-p.pos[1]*self.scale-image.height/2)
    canvas.alpha_composite(image,(x,y))
   if p.life>0:alive.append(p)
  self.particles=alive
  return canvas.resize((128,128),Image.Resampling.BOX)
 def bake(self,model):
  self._survivors=[]
  result=[]
  for frame in range(math.ceil(model['frames'])+36):
   result.append(self.frame(model['emitters'],frame))
  return result
