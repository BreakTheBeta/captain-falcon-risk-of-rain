local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local asset=io.open(root..'/melee_motion_data.lua','r')
if asset then asset:close() else package.preload['melee_motion_data']=function()return {clips={}} end end
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

local function damage(amount)
 if p:get('invincible')>0 then return false end
 for _,f in ipairs(handlers.onDamage or {}) do if f(p,amount) then return false end end
 p:set('hp',p:get('hp')-amount);return true
end
reset();p:set('invincible',0);p:set('hp',125)
keys={l=input.PRESSED};fire('preStep')
assert(not damage(20),'Shield must protect before the native enemy step on its first input frame')
fire('postStep')
reset();p:set('invincible',0);p:set('hp',125)
frame({l=input.PRESSED});assert(p:get('invincible')>0,'Shield must use native immunity for damage outside onDamage');assert(not damage(20) and p:get('hp')==125,'Held shield must cancel incoming HP damage')
for n=1,4 do frame({l=input.HELD}) end
frame({l=input.HELD,d=input.PRESSED})
assert(p.data.attack and p.data.attack.name=='roll')
assert(not damage(20) and p:get('hp')==125,'Roll must protect on its first frame')
for n=2,31 do
 p:set('invincible',math.max(0,p:get('invincible')-1))
 frame({})
 assert(not damage(20) and p:get('hp')==125,'Roll must protect through frame '..n)
end
print('PASS: shield and complete roll cancel incoming HP damage')
for n=1,3 do
 p:set('invincible',math.max(0,p:get('invincible')-1));frame({})
end
assert(not p.data.attack and damage(20) and p:get('hp')==105,'Normal vulnerability must return after roll ends')
reset();p:set('invincible',0);p:set('hp',125)
frame({l=input.PRESSED})
keys={};fire('preStep')
assert(damage(20),'Releasing shield must stop protection before native enemy updates')
fire('postStep')
reset();p:set('invincible',0);p:set('hp',125)
frame({l=input.PRESSED});p.data.shield=5
assert(handlers.onDamage[1](p,20)==true and p:get('hp')==125,'The callback hit which breaks shield must still be blocked')
assert(not p.data.shielding and p.data.stunned>0,'Depleted shield must break and stun')
assert(damage(20),'Broken shield must not leave permanent immunity')
print('PASS: shield release, shield break and roll completion restore vulnerability')
reset();p:set('invincible',0);p:set('hp',125)
for n=1,400 do
 p:set('invincible',math.max(0,p:get('invincible')-1));frame({l=input.HELD})
end
assert(p.data.stunned>0 and not p.data.shielding and p:get('invincible')==0,'Holding shield to exhaustion must break it and remove immunity')
reset();p:set('invincible',50);frame({l=input.PRESSED});frame({})
assert(p:get('invincible')==50,'Shield release preserves longer invincibility granted by other game mechanics')
print('PASS: native shield immunity is finite and preserves external invincibility timers')
