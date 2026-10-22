local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local keys={};local buttons={};local axes={};local padId=0;local handlers={};local survivor
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
function input.getPlayerGamepad()return padId end
function input.checkGamepad(button,id) assert(id==0);return buttons[button] and 2 or 0 end
function input.getGamepadAxis(axis,id) assert(id==0);return axes[axis] or 0 end
local function frame(b,a,k)
 buttons=b or {};axes=a or {};keys=k or {};fire('preStep');fire('postStep')
end
local function reset(air)
 p.vars.activity=0;p.x=0;p.y=air and -30 or 0;survivor.callbacks.init(p)
 if air then p.data.motion.grounded=false end
 buttons={};axes={};keys={};padId=0
end
frame({face2=true});assert(p.data.attack.name=='punch','B neutral special')
for n=1,100 do frame({face2=true}) end
assert(not p.data.attack,'held B must not repeat')
frame();frame({face2=true});assert(p.data.attack.name=='punch')
reset();frame({face2=true},{lh=1});assert(p.data.attack.name=='raptor')
reset();frame({face2=true},{lv=-1});assert(p.data.attack.name=='dive')
reset();frame({face2=true},{lv=1});assert(p.data.attack.name=='kick')
reset();frame({face1=true});assert(p.data.attack.name=='jab1')
reset(true);frame({face1=true},{lh=1});assert(p.data.attack.name=='knee')
reset(true);frame({face1=true},{lh=-1});assert(p.data.attack.name=='bair')
reset();frame({shoulderlb=true});assert(p.data.shielding)
frame({shoulderlb=true},{lh=1});assert(p.data.attack.name=='roll')
reset();frame({shoulderrb=true});assert(p.data.shielding,'RT shields')

reset(true);frame({shoulderlb=true},{lh=1,lv=1});assert(p.data.attack.name=='airdodge')
reset(true);frame({shoulderlb=true},{lh=.9,lv=.3});assert(math.abs(p.data.attack.dx/p.data.attack.dy-3)<.001,'Air dodge preserves analog angle')
reset();frame({face3=true});for n=1,5 do frame({face3=true}) end
assert(not p.data.motion.grounded and p.data.motion.jumps==1,'X jumps')
frame();frame({face4=true});assert(p.data.motion.jumps==0,'Y double jumps')
reset();frame({}, {lh=.1});assert(p.data.motion.vx==0,'deadzone suppresses drift')
for n=1,20 do frame({}, {lh=.5}) end
assert(p.data.motion.vx<1 and p.data.motion.vx>0,'soft stick walks')
reset();frame({}, {rh=1});assert(p.data.attack.name=='fsmash','right stick smash')
assert(p.data.motion.vx==0,'C-stick does not move actor')
for n=1,20 do frame({}, {rh=1}) end
assert(p.data.attack.charge==0,'C-stick smash must not charge')
frame();assert(p.data.attack.age>5,'C-stick smash starts immediately')
reset(true);frame({}, {rv=-1});assert(p.data.attack.name=='uair','C-stick aerial')
reset();frame({select=true});assert(p.data.help)
reset();frame({padu=true});assert(p.data.attack.name=='taunt')
reset();frame({face2=true});frame({face2=true},nil,{k=2})
for n=1,100 do frame(nil,nil,{k=2}) end
assert(not p.data.attack,'device handoff while held must not repeat')
reset();padId=nil;frame(nil,nil,{k=3});assert(p.data.attack.name=='punch','keyboard works without pad')
reset();frame({face2=true});padId=nil;frame();padId=0
for n=1,100 do frame() end
frame({face2=true});assert(p.data.attack.name=='punch','reconnect accepts fresh press')
print('PASS: controller specials, normals, triggers, wavedash, X/Y jumps, deadzone, walking, C-stick smash/charge/aerial, guide/taunt, mixed input and reconnect')

reset(true);frame({face1=true});p.y=-1.1;p.data.motion.vy=1.2
frame({shoulderlb=true});assert(p.data.motion.grounded and p.data.motion.lag==7,'Trigger in aerial landing window L-cancels 15-frame nair lag to 7')
reset(true);frame({face1=true});p.y=-1.1;p.data.motion.vy=1.2
frame();assert(p.data.motion.lag==15,'Aerial without L-cancel retains native landing lag')
print('PASS: L-cancel window halves aerial landing recovery; ordinary landing remains unchanged')

-- Falling/fast-falling entry must be replaced by special-owned motion.
for _,move in ipairs({'raptor','kick'}) do
 reset(true);p.y=-200;p.data.motion.vy=2;p.data.motion.fast=true
 frame({face2=true},move=='raptor' and {lh=1} or {lv=1})
 assert(p.data.attack.name==move)
 assert(not p.data.motion.fast,move..' must clear inherited fast-fall')
 assert(p.y<=-200+.01,move..' startup must arrest falling momentum')
 for n=2,8 do frame() end
 assert(p.y< -199,move..' startup must not inherit ordinary falling gravity')
end
print('PASS: falling and fast-falling special entry stalls instead of plummeting')
reset(true);p.y=-500
frame({face2=true},{lh=1})
local sideStartY=p.y
for n=2,29 do frame() end
assert(math.abs(p.y-sideStartY)<.01,'Side-B suspends gravity until the native frame-30 gate')
frame();assert(p.data.motion.vy>0 and p.data.motion.vy<.04,'Side-B begins its own gentle gravity at frame 30')
for n=31,81 do frame() end
assert(not p.data.attack and p.data.specialFall,'Missed airborne Raptor Boost enters special fall')
reset(true);p.y=-500
frame({face2=true},{lv=1})
for n=2,12 do frame() end
assert(p.y< -502,'Air Falcon Kick has its original startup lift')
for n=13,17 do frame() end
assert(p.data.motion.vy>2.5,'Air Falcon Kick dives at native frame 17')
for n=18,31 do frame() end
assert(p.data.attack and p.data.attack.recovery,'Kick uses a distinct aerial recovery phase')
for n=32,60 do frame() end
assert(not p.data.attack and not p.data.specialFall,'Falcon Kick recovery returns to normal aerial action')
frame({face3=true});assert(p.data.motion.vy<0,'Double jump remains available after kick recovery')
print('PASS: native special startup, gravity gates, dive, recovery and post-move action')
for _,move in ipairs({'raptor','kick'}) do
 reset(true);p.y=-200
 frame({face2=true},move=='raptor' and {lh=1} or {lv=1})
 p.y=-.01;p.data.motion.vy=1
 frame()
 assert(not p.data.attack and p.data.motion.grounded,move..' landing stops airborne special movement')
 assert(p.data.motion.lag>10,move..' landing applies its native recovery instead of allowing instant attacks')
end
print('PASS: special landings stop motion and apply recovery')
reset();p:set('invincible',0)
frame({shoulderlb=true},{lh=1})
assert(p.data.attack and p.data.attack.name=='roll' and p:get('invincible')>0,'Controller roll must be immune on its first frame')
assert(handlers.onDamage[1](p,30)==true,'Roll also cancels damage paths bypassing native invincibility')
for n=2,31 do
 p:set('invincible',math.max(0,p:get('invincible')-1));frame()
 assert(p:get('invincible')>0,'Controller roll immunity must cover frame '..n)
end
print('PASS: controller trigger + direction starts a fully protected roll')
