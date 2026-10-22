from PIL import Image,ImageDraw
from pathlib import Path
import math
import os
out=Path(os.environ.get('FALCON_MOD_ROOT','mods/CaptainFalcon'))/'assets'
out.mkdir(parents=True,exist_ok=True)
# Original pixel art; no extracted Nintendo sprites, models, or audio.
ink='#15172b';purple='#544787';light='#8076b3';red='#d34243';gold='#f4c65b';boot='#e4a644';white='#eee7d3'
def frame(pose='idle',i=0,n=1):
 im=Image.new('RGBA',(48,48));d=ImageDraw.Draw(im)
 bob=round(math.sin(i/n*math.tau)) if pose in ['idle','run'] else 0
 hip=(23,29+bob);shoulder=(24,19+bob);head=(25,12+bob)
 legs=[((19,34),(18,42)),((27,35),(29,42))]
 arms=[((19,24),(17,28)),((29,23),(31,26))]
 if pose=='run':
  a=math.sin(i/n*math.tau);legs=[((22+round(7*a),34),(23+round(11*a),41)),((22-round(7*a),34),(23-round(11*a),41))];shoulder=(26,19+bob);head=(28,12+bob);arms=[((21-round(7*a),23),(23-round(8*a),27)),((25+round(6*a),23),(25+round(10*a),27))]
 elif pose in ['jump','fall','climb']:
  legs=[((18,33),(21,36)),((29,32),(32,36))];arms=[((18,18),(18,13)),((31,19),(34,15))]
 elif pose=='jab':
  reach=round(10*math.sin(i/max(1,n-1)*math.pi));arms=[((19,24),(18,28)),((31,20),(34+reach,19))]
 elif pose=='knee':
  legs=[((17,34),(17,41)),((32,26),(34,33))];arms=[((19,19),(21,15)),((29,21),(31,17))]
 elif pose in ['raptor','punch']:
  reach=10 if i>=n//2 else -2;arms=[((18,23),(18,28)),((30,20),(31+reach,18))];legs=[((19,35),(14,41)),((29,34),(33,41))]
 elif pose=='kick':
  legs=[((18,34),(14,40)),((32,29),(43,30))];arms=[((18,23),(16,27)),((28,19),(31,15))]
 elif pose=='dive':
  legs=[((19,33),(16,38)),((29,32),(32,37))];arms=[((19,17),(19,12)),((30,14),(33,6))]
 elif pose in ['ftilt','smash','dash']:
  legs=[((18,35),(14,41)),((29,34),(34,41))]
  arms=[((19,24),(20,28)),((31,20),(42 if pose!='dash' else 33,19))]
  if pose=='ftilt': legs=[((19,35),(18,42)),((33,29),(43,29))]
 elif pose in ['utilt','usmash','uair']:
  legs=[((19,35),(17,42)),((29,24),(32,7))]
  arms=[((17,23),(17,28)),((30,20),(33,17))]
 elif pose in ['dtilt','dsmash']:
  hip=(23,34);shoulder=(23,25);head=(25,18)
  legs=[((17,37),(14,42)),((33,38),(44,39))]
  if pose=='dsmash' and i>=n//2:legs=[((12,38),(4,39)),((29,37),(32,42))]
  arms=[((17,29),(13,32)),((29,29),(32,32))]
 elif pose=='nair':
  legs=[((15,29),(6,31)),((32,29),(43,30))] if i<n//2 else [((17,33),(11,37)),((33,28),(44,25))]
  arms=[((18,18),(19,13)),((29,17),(32,13))]
 elif pose=='bair':
  arms=[((15,18),(4,18)),((29,22),(31,25))]
  legs=[((19,34),(17,40)),((29,34),(33,39))]
 elif pose=='dair':
  legs=[((20,34),(20,44)),((26,34),(27,44))]
  arms=[((18,16),(18,11)),((30,16),(32,12))]
 elif pose=='shield':
  hip=(23,33);shoulder=(24,23);head=(25,16)
  legs=[((18,37),(15,42)),((29,37),(33,42))]
  arms=[((20,20),(27,18)),((30,21),(25,18))]
 elif pose in ['dodge','roll']:
  legs=[((18,30),(22,34)),((28,29),(30,34))]
  arms=[((18,22),(23,20)),((30,21),(25,20))]
 elif pose=='taunt':
  arms=[((18,25),(20,30)),((31,16),(34,11))]
 elif pose=='death':
  if i>1:
   base=frame('fall',0,1).rotate(90,expand=False);return base
 # Far limbs, then torso, then near limbs.
 def limb(points,color,width):
  d.line(points,fill=ink,width=width+2);d.line(points,fill=color,width=width)
 for knee,foot in legs:
  limb([hip,knee,foot],purple,5);limb([knee,foot],boot,4);d.rectangle((foot[0]-2,foot[1]-1,foot[0]+4,foot[1]+1),fill=gold)
 d.polygon([(shoulder[0]-6,shoulder[1]-2),(shoulder[0]+5,shoulder[1]-2),(hip[0]+5,hip[1]+2),(hip[0]-5,hip[1]+2)],fill=ink)
 d.polygon([(shoulder[0]-4,shoulder[1]-1),(shoulder[0]+4,shoulder[1]-1),(hip[0]+4,hip[1]),(hip[0]-4,hip[1])],fill=purple)
 d.line([(shoulder[0]-2,shoulder[1]),(hip[0]-1,hip[1]-2)],fill=light,width=2)
 d.rectangle((hip[0]-5,hip[1]-2,hip[0]+5,hip[1]),fill=gold)
 for elbow,hand in arms:
  limb([shoulder,elbow,hand],light,4);d.rectangle((hand[0]-2,hand[1]-2,hand[0]+2,hand[1]+1),fill=white)
 hx,hy=head;d.ellipse((hx-6,hy-7,hx+5,hy+5),fill=ink);d.ellipse((hx-5,hy-6,hx+4,hy+4),fill=red)
 d.polygon([(hx-3,hy-2),(hx+6,hy-2),(hx+4,hy+2),(hx-2,hy+2)],fill=gold)
 d.line((hx-1,hy-1,hx+4,hy-1),fill='#fff2aa');d.rectangle((hx-4,hy-1,hx-2,hy+3),fill=white)
 # Falcon crest and scarf.
 d.polygon([(hx-1,hy-6),(hx+2,hy-4),(hx,hy-3)],fill=gold)
 d.polygon([(hx-4,hy+4),(hx+2,hy+5),(hx-1,hy+8),(hx-11,hy+5),(hx-15,hy+7),(hx-13,hy+3)],fill=gold)
 return im
spec={'idle':4,'run':8,'jump':1,'fall':1,'climb':2,'death':6,'jab':4,'knee':8,'raptor':8,'punch':12,'kick':8,'dive':8,'ftilt':6,'utilt':8,'dtilt':6,'smash':8,'usmash':8,'dsmash':8,'dash':6,'nair':8,'bair':6,'uair':6,'dair':6,'shield':1,'dodge':4,'roll':6,'taunt':6}
for name,n in spec.items():
 sheet=Image.new('RGBA',(16*n,16))
 for i in range(n):sheet.paste(frame(name,i,n).resize((16,16),Image.Resampling.NEAREST),(16*i,0))
 sheet.save(out/f'{name}.png')
Image.new('RGBA',(4,9),(255,255,255,255)).save(out/'mask.png')
portrait=Image.new('RGBA',(64,64));p=frame().resize((96,96),Image.Resampling.NEAREST);portrait.paste(p,(-14,-9));portrait.save(out/'portrait.png')
icons=Image.new('RGBA',(18*4,18));d=ImageDraw.Draw(icons)
for i,label in enumerate(['J','K','L','I']):
 x=i*18;d.rectangle((x,0,x+17,17),fill=ink);d.rectangle((x+1,1,x+16,16),outline=gold);d.text((x+6,3),label,fill=gold)
icons.save(out/'skills.png')
preview=Image.new('RGBA',(48*len(spec),96),(30,29,43,255))
for i,name in enumerate(spec):
 preview.paste(frame(name,2,spec[name]),(i*48,0));ImageDraw.Draw(preview).text((i*48,50),name,fill='white')
preview.resize((48*len(spec),96),Image.Resampling.NEAREST).save(out/'preview.png')
print('Built',len(spec),'animation strips, portrait, and skill icons')
