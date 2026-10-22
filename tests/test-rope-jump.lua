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

reset(true);p.y=-50;p:set('activity',30);p:set('activity_type',1)
frame({space=input.PRESSED,d=input.HELD})
assert(p:get('activity')==0,'Jump must detach from the native rope activity')
assert(p.data.motion.vy<0 and p.y< -50,'Rope jump must launch upward immediately')
assert(p.data.motion.vx>0,'Rope jump must allow sideways escape')
print('PASS: jump detaches from rope and moves up and sideways')

assert(p:get('canrope')==0 and p:get('rope_parent')==-1,'Jump clears rope reference and prevents immediate regrab')
for n=1,13 do frame({w=input.HELD}) end
assert(p:get('canrope')==1,'Rope grabbing is re-enabled after detach grace period')
print('PASS: rope detach grace period prevents snap-back and then allows climbing again')
reset(true);p.y=-50;p:set('activity',30)
keys={space=input.PRESSED};fire('preStep')
p:set('activity',30) -- host attempts to re-grab while the jump is detaching
fire('postStep')
assert(p:get('activity')==0 and p.data.motion.vy<0,'A native re-grab in the same frame cannot cancel rope jump')
reset(true);p:set('activity',95);frame({space=input.PRESSED})
assert(p:get('activity')==95,'Jump must not cancel item selection or other native activities')
print('PASS: native rope re-grab is rejected during grace without cancelling item menus')
