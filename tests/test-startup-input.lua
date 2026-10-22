local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
package.preload['melee_motion_data']=function()return {clips={}} end
local keys={};local buttons={};local axes={};local padId=0;local handlers={};local survivor
local function noop() end
package.preload['melee_renderer']=function() return {draw=noop} end
package.preload['melee_audio']=function() return {begin=noop,step=noop,jump=noop,doubleJump=noop,land=noop,shieldBreak=noop,update=noop} end
Color={fromHex=function(x) return x end}
modloader={checkFlag=function(flag) return flag=='falcon_input_trace' end}
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
local traces={}
log=function(line) if line:find('[Falcon input]',1,true) then traces[#traces+1]=line end end
graphics=setmetatable({}, {__index=function() return noop end})
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
-- A press just before the arrival animation ends must survive the handoff.
for _,case in ipairs({{button='face1',move='jab1'},{button='face2',move='punch'},{button='face3',jump=true}}) do
 reset();p:set('activity',99)
 frame({[case.button]=true})
 p:set('activity',0);frame({[case.button]=true})
 if case.jump then
  assert(p.data.motion.squat>0 or p.data.motion.vy<0,'Spawn transition swallowed jump')
 else
  assert(p.data.attack and p.data.attack.name==case.move,'Spawn transition swallowed '..case.move)
 end
end
print('PASS: attack, special and jump survive the spawn handoff')

-- Keyboard goes through the same arrival handoff.
reset();p:set('activity',99);frame(nil,nil,{k=3});p:set('activity',0);frame(nil,nil,{k=2})
assert(p.data.attack and p.data.attack.name=='punch','Keyboard special lost during arrival')
-- A short tap remains useful even when released before arrival completes.
reset();p:set('activity',99);frame({face2=true},{lv=-1});frame();p:set('activity',0);frame()
assert(p.data.attack and p.data.attack.name=='dive','Arrival buffer lost special direction')
-- Menu confirmations and old presses must never auto-cast when play resumes.
reset();p:set('activity',95);frame({face2=true});p:set('activity',0);frame({face2=true})
assert(not p.data.attack,'Item menu confirmation must not cast a special')
reset();p:set('activity',99);frame({face2=true})
for n=1,10 do frame({face2=true}) end
p:set('activity',0);frame({face2=true});assert(not p.data.attack,'Expired arrival input must not auto-cast')
frame();frame({face2=true});assert(p.data.attack and p.data.attack.name=='punch','Fresh press after arrival must work')
for n=1,100 do frame({face2=true}) end
assert(not p.data.attack,'Replayed arrival press must not repeat while held')
print('PASS: keyboard, brief taps, directional specials, menu isolation, expiry and held-button safety')

reset();p:set('activity',99);frame({face2=true});p:set('activity',0)
for n=1,120 do frame({face2=true}) end
assert(not p.data.attack,'Arrival-buffered special must not repeat while held')
reset();p:set('activity',99);frame({shoulderlb=true});p:set('activity',0);frame({shoulderlb=true})
assert(p.data.shielding and p:get('invincible')>=2,'Shield must engage as soon as arrival hands over control')
reset();p:set('activity',99);frame({face2=true});p:set('dead',1);frame();p:set('dead',0);p:set('activity',0);frame()
assert(not p.data.attack,'Death must discard arrival inputs')
print('PASS: replay cannot repeat; held shield activates on arrival; death discards queued actions')

reset();traces={};frame({face2=true})
assert(traces[1]:find('pad=0',1,true) and traces[1]:find('rawAB=false,true',1,true),'Trace must include assigned pad and raw special input')
assert(traces[1]:find('edgesAB=false,true',1,true) and traces[1]:find('action=punch',1,true),'Trace must relate input edges to dispatched actions')
for n=1,1000 do frame({face2=true}) end
assert(#traces==150,'Startup trace must stop after 900 frames without repeating held-button samples')
assert(traces[#traces]:find('frame=895 ',1,true),'Last regular trace sample must stay within the startup window')
print('PASS: optional startup trace records real dispatch and stops after 900 frames')
