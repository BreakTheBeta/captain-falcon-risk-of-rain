local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
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
frame({k=input.PRESSED})
assert(p.data.attack and p.data.attack.name=='punch','neutral keyboard K should be Falcon Punch; got '..tostring(p.data.attack and p.data.attack.name))
assert((p.cooldowns or 0)==0,'Melee keyboard actions must use recovery frames rather than RoR skill cooldowns')
print('PASS: keyboard K dispatches neutral special without a skill cooldown')

for n=1,100 do frame({k=input.HELD}) end
assert(p.data.attack==nil,'holding special must not auto-repeat after recovery')
frame({});frame({k=input.PRESSED});assert(p.data.attack.name=='punch','a fresh K press should work immediately after recovery')
print('PASS: no special cooldown and no held-key repeat')
local function reset(air)
 p.vars.activity=0;p.x=0;p.y=air and -30 or 0;survivor.callbacks.init(p)
 if air then p.data.motion.grounded=false end
end
reset();frame({l=input.PRESSED});assert(p.data.shielding,'L holds a ground shield')
local shield=p.data.shield
assert(handlers.onDamage[1](p,30)==true and p.data.shield<shield,'shield cancels incoming damage and consumes shield health')
for n=1,4 do frame({l=input.HELD}) end
frame({l=input.HELD,d=input.PRESSED});assert(p.data.attack.name=='roll','L + D rolls')
print('PASS: shield blocks damage; directional shielding rolls')
reset(true);frame({l=input.PRESSED,s=input.HELD,d=input.HELD});assert(p.data.attack.name=='airdodge','air S+D+L is a wavedash input')
reset(true);frame({a=input.HELD,j=input.PRESSED});assert(p.data.attack.name=='bair','back + J is back air')
reset(true);frame({d=input.HELD,j=input.PRESSED});assert(p.data.attack.name=='knee','forward + J is the knee')
reset();frame({w=input.HELD,k=input.PRESSED});assert(p.data.attack.name=='dive','W + K is up special')
reset();frame({s=input.HELD,k=input.PRESSED});assert(p.data.attack.name=='kick','S + K is down special')
reset();frame({d=input.HELD,k=input.PRESSED});assert(p.data.attack.name=='raptor','D + K is side special')
reset();frame({shift=input.HELD,d=input.HELD,j=input.PRESSED});assert(p.data.attack.name=='fsmash','Shift + D + J is forward smash')
reset();frame({h=input.PRESSED});assert(p.data.help,'H opens keyboard reference')
print('PASS: WASD directional normals/specials, air dodge, smash modifier, and H help')
reset();frame({space=input.PRESSED,j=input.PRESSED})
for n=1,5 do frame({space=input.HELD}) end
assert(p.data.attack and p.data.attack.name=='nair','Space + J buffers a neutral aerial after jumpsquat')
reset(true);frame({j=input.PRESSED});local old=p.data.motion.vx
frame({d=input.PRESSED});assert(p.data.motion.vx>old,'aerial normals retain directional drift')
reset();frame({shift=input.HELD,d=input.HELD,j=input.PRESSED})
for n=1,20 do frame({j=input.HELD}) end
assert(p.data.attack.charge>0 and p.data.attack.age==5,'held smash charges at startup')
frame({});assert(p.data.attack.age>5,'releasing J releases charged smash')
print('PASS: simultaneous jump + attack, aerial drift during normals, hold/release smash charge')
