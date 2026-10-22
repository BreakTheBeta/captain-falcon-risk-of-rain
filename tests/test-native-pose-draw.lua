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
local p={x=100.3,y=200.7,getData=function()return d end,get=function()return 0 end}
R.draw(p);assert(drawn.subimage==53 and drawn.x==100 and drawn.y==201 and drawn.xscale==-1)
print('PASS: all cached native animation strips; gameplay draw avoids rasterization; correct frame, facing and pixel alignment')

d.attack={name='raptor',age=18,airborne=true};R.draw(p)
assert(drawn.image.name=='FalconMeleePose_airraptor','Air Raptor uses its own native clip')
d.attack={name='kick',age=35,airborne=true,recovery=true,motionFrame=5};R.draw(p)
assert(drawn.image.name=='FalconMeleePose_airkickrecovery' and drawn.subimage==6,'Kick recovery uses its own native clip and phase frame')
print('PASS: aerial special and recovery animations match movement phase')
