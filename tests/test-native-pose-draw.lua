local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local count=0
Sprite={load=function(name,path,frames,x,y)count=count+1;assert(frames>0 and x==32 and y==48);return {name=name}end}
local R=require('melee_renderer');local expected=0;for name in pairs(R.model.clips) do expected=expected+1 end;assert(count==expected,'All original animation strips load')
R.getPixels=function()error('Gameplay draw must not rasterize mesh triangles')end
R.rasterize=R.getPixels
local drawn
local noop=function()end
graphics={alpha=noop,drawImage=function(args)drawn=args end}
local d={motion={grounded=true,vx=0,facing=-1},tick=10,attack={name='punch',age=52}}
local p={x=100.3,y=200.7,getData=function()return d end,get=function(_,key)return key=='hp' and 125 or 0 end}
R.draw(p);assert(drawn.subimage==53 and drawn.x==100 and drawn.y==201 and drawn.xscale==-1)
print('PASS: all cached native animation strips; gameplay draw avoids rasterization; correct frame, facing and pixel alignment')

d.attack={name='raptor',age=18,airborne=true};R.draw(p)
assert(drawn.image.name=='FalconMeleePose_airraptor','Air Raptor uses its own native clip')
d.attack={name='kick',age=35,airborne=true,recovery=true,motionFrame=5};R.draw(p)
assert(drawn.image.name=='FalconMeleePose_airkickrecovery' and drawn.subimage==6,'Kick recovery uses its own native clip and phase frame')
print('PASS: aerial special and recovery animations match movement phase')

-- Death recognizes HP reaching zero before the native flag, and all flag values.
d.attack=nil;d.tick=5000;d.motion.grounded=false;d.death={age=1}
for _,dead in ipairs({0,1,2}) do
 p.get=function(_,key)return key=='dead' and dead or 0 end
 R.draw(p)
 assert(drawn.image.name=='FalconMeleePose_death' and drawn.subimage==1,'Death must draw the original model from its own first frame')
end
d.death.age=10;R.draw(p);assert(drawn.subimage==10,'Death animation must advance from time of death')
d.death.age=1000;R.draw(p);assert(drawn.subimage==R.model.clips.death,'Death animation must hold its last frame')
print('PASS: HP-zero and native dead flags render the original model with a death-relative animation clock')

d.motion.grounded=true;d.death.landAge=0;R.draw(p)
assert(drawn.image.name=='FalconMeleePose_deathland' and drawn.subimage==1,'Grounded corpse must use original Melee knockdown pose')
d.death.landAge=1000;R.draw(p)
assert(drawn.subimage==R.model.clips.deathland,'Grounded corpse must hold its final lying-down pose')
print('PASS: grounded corpse plays and holds the original Melee knockdown animation')
