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
-- A native map object applies a launch between the mod's pre/post hooks.
keys={};fire('preStep')
p:set('pVspeed',-12);p.y=p.y-12;p:set('free',1)
fire('postStep')
assert(p.y< -5 and p.data.motion.vy< -5,'jump-pad upward impulse was erased by Falcon movement')
print('PASS: native jump-pad launch transfers into Falcon movement')
for n=1,10 do keys={};fire('preStep');fire('postStep') end
assert(p.y< -80 and p.data.motion.vy< -8,'launch must survive subsequent frames')
-- Pad applied after the previous postStep but before the next preStep.
survivor.callbacks.init(p);p.y=0;p:set('activity',0);p:set('pVspeed',-6)
fire('preStep');fire('postStep')
assert(p.y< -5 and p.data.motion.vy< -5,'late native pad impulse must survive preStep')
-- A pad interrupts an air-dodge trajectory rather than being overwritten by it.
survivor.callbacks.init(p);p.y=-30;p.data.motion.grounded=false;p:set('activity',0)
keys={l=input.PRESSED,s=input.PRESSED,d=input.PRESSED};fire('preStep');fire('postStep')
assert(p.data.attack and p.data.attack.name=='airdodge','air dodge fixture')
keys={};fire('preStep');p:set('pVspeed',-12);fire('postStep')
assert(p.data.attack==nil and p.data.motion.vy< -10 and not p.data.specialFall,'pad cancels defensive trajectory and helpless state')
print('PASS: persistent ascent, late pad impulse, air-dodge interruption')

-- Native jump is separately generated from Space by the host; it must not
-- masquerade as an environmental pad and bypass Falcon's jumpsquat.
survivor.callbacks.init(p);p.y=0;p:set('activity',0);p:set('pVspeed',0)
keys={space=input.PRESSED};fire('preStep');p:set('pVspeed',-3);p.y=-3;fire('postStep')
assert(p.data.motion.squat>0 and p.data.motion.vy==0 and p.y==0,'native Space jump must not override Melee jumpsquat')
print('PASS: native Space jump is ignored; custom jumpsquat remains intact')
