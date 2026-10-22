local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local spec=require('melee_effect_data');local drawn
Sprite={load=function(name,path,count,x,y)assert(x==44 and y==40 and count>0);return {name=name}end}
graphics={alpha=function()end,drawImage=function(args)drawn=args end}
-- RoRML resolves a module from its immediate Lua caller's source signature.
local nativeRequire=require
require=function(name)
 assert(debug.getinfo(2,'S').what~='C','RoRML require needs a Lua caller')
 local result=nativeRequire(name);return result
end
local F=require('melee_effects');assert(F.available,'Imported effects must load through RoRML caller-context resolution')
local d={motion={facing=1},tick=100,attack={name='punch',age=53}}
local dead=0;local p={x=100,y=200,getData=function()return d end,get=function(_,key)return key=='hp' and 125 or dead end}
local function draw()drawn=nil;F.draw(p);return drawn end
local a=draw();assert(a.image.name=='FalconMeleeEffect_effect0' and a.subimage==53,'Punch must use its imported particle strip at native animation time')
d.tick=800;assert(draw().subimage==a.subimage,'Hitstop cannot advance particles with global time')
d.motion.facing=-1;assert(draw().xscale==-1,'Particle effects must mirror with Falcon')
d.attack.age=65;assert(not draw(),'Native off flag must remove Punch flames')
d.attack={name='kick',age=20};a=draw();assert(a.image.name=='FalconMeleeEffect_effect2' and a.x==math.floor(p.x-spec.anchors.kick[21][1]+.5),'Kick flames must follow the original animated foot')
d.attack.airborne=true;assert(draw().angle==spec.airKickAngle,'Air Kick uses the original flame angle, mirrored with facing');d.attack.airborne=false
d.attack.recovery=true;assert(not draw(),'Kick recovery must not retain flames')
d.attack={name='raptor',hit=true,age=20,raptorHitFrame=17};assert(draw().image.name=='FalconMeleeEffect_effect3')
d.attack.airborne=true;assert(draw().image.name=='FalconMeleeEffect_effect5','Air Raptor has its own original effect')
dead=2;assert(not draw(),'Death must clear flame playback')
dead=0;d.attack=nil;assert(not draw(),'Idle must not retain flames')
print('PASS: original particle strips, action gates, animated foot attachment, facing, hitstop, Raptor variants and death cleanup')
