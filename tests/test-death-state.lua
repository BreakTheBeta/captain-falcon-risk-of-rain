local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
package.preload['melee_motion_data']=function()return {clips={}} end
local keys={};local handlers={};local survivor
local function noop() end
package.preload['melee_renderer']=function() return {draw=noop} end
package.preload['melee_audio']=function() return {begin=noop,step=noop,jump=noop,doubleJump=noop,land=noop,shieldBreak=noop,update=noop} end
Color={fromHex=function(x) return x end}
modloader={checkFlag=function() return false end}
Sprite={load=function(name,path,frames) return {name=name,frames=frames} end}
ParentObject={find=function() return setmetatable({}, {__index=function() return function() return nil end end}) end}
Survivor={new=function()
 survivor={callbacks={}}
 function survivor:addCallback(name,f) self.callbacks[name]=f end
 survivor.setLoadoutInfo=noop;survivor.setLoadoutSkill=noop
 return survivor
end}
callback={register=function(name,f) handlers[name]=handlers[name] or {};table.insert(handlers[name],f) end}
input={PRESSED=3,HELD=2,RELEASED=1,NEUTRAL=0}
function input.checkKeyboard(k) return keys[k] or 0 end
local map={left='left',right='right',up='up',down='down',jump='space',ability1='z',ability2='x',ability3='c',ability4='v'}
function input.checkControl(c,p) return keys[map[c]] or 0 end
input.getControlString=function(c) return c end
local p={x=0,y=0,xscale=1,subimage=1,vars={activity=0,dead=0,hp=125,maxhp=125,invincible=0,pHmax=4.6,feather=0},data={}}
function p:getSurvivor() return survivor end
function p:getData() return self.data end
function p:get(k) return self.vars[k] or 0 end
function p:set(k,v) self.vars[k]=v;return self end
p.setAnimations=noop;p.setSkill=noop;p.survivorSetInitialStats=noop;p.survivorLevelUpStats=noop
p.activateSkillCooldown=function(self,index) self.cooldowns=(self.cooldowns or 0)+1 end
p.setAlarm=noop;p.getAlarm=function() return 0 end
function p:survivorActivityState(index,sprite) self.vars.activity=index;self.lastSprite=sprite end
function p:collidesMap(x,y) return y>0 end
function p:fireExplosion() return {set=function(self) return self end} end
p.isValid=function() return true end
misc={players={p},shakeScreen=noop}
isa=function(obj,kind) return obj==p and kind=='PlayerInstance' end
log=noop;graphics=setmetatable({}, {__index=function() return noop end})
dofile(root..'/main.lua')
survivor.callbacks.init(p)
local function fire(name) for _,f in ipairs(handlers[name] or {}) do f() end end
local function frame(pressed)
 keys=pressed or {};fire('preStep')
 -- Simulate the host's native skill dispatch before the real postStep call.
 for i,k in ipairs({'j','k','l','i'}) do if keys[k]==input.PRESSED and p:get('activity')==0 then survivor.callbacks.useSkill(p,i) end end
 fire('postStep')
end
local function reset(air)
 p.vars.activity=0;p.x=0;p.y=air and -30 or 0;survivor.callbacks.init(p)
 if air then p.data.motion.grounded=false end
end

reset(true);p.y=-40;p:set('hp',0);p:set('dead',2);p.alpha=1
frame({});assert(p.y> -40,'Dead Falcon is suspended instead of falling')
assert(p.alpha==0,'Native sprite must stay hidden after death')
local y=p.y
for n=1,120 do frame({space=input.PRESSED,j=input.PRESSED}) end
assert(p.y>y and p.y<=0 and p.data.motion.grounded,'Corpse must settle on the map floor')
assert(not p.data.attack and not p.data.shielding,'Dead Falcon must ignore fighter controls')
y=p.y;for n=1,30 do frame({}) end
assert(p.y==y,'Grounded corpse must remain still')
print('PASS: airborne death falls, lands and stays still; native sprite hidden; dead controls inert')

-- HP can reach zero a frame before the engine raises its dead flag.
reset(true);p:set('dead',0);p:set('hp',0);p.y=-20;frame({})
assert(p.data.death and p.y> -20,'HP-zero transition must immediately enter corpse physics')
-- Dio-style revival must start a new death clock on a subsequent death.
p:set('hp',125);p:set('dead',0);frame({});assert(not p.data.death,'Revival must clear the previous death clock')
p:set('hp',0);p:set('dead',3);frame({});assert(p.data.death.age==1,'Second death must start its animation again')
p.alpha=1;frame({});assert(p.alpha==0,'Native death updates must never reveal the fallback sprite')
print('PASS: early HP-zero death, nonbinary flags, revival and repeated death keep model state consistent')
