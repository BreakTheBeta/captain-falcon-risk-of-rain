local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local keys={};local handlers={};local survivor
local function noop() end
package.preload['melee_renderer']=function() return {draw=noop} end

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
local played={}
Sound={load=function(name,path)return {play=function(self,pitch,volume)played[#played+1]={name=name,pitch=pitch,volume=volume}end,stop=noop}end}
dofile(root..'/main.lua')
survivor.callbacks.init(p)
local function fire(name) for _,f in ipairs(handlers[name] or {}) do f() end end
local function frame(pressed)
 keys=pressed or {};fire('preStep')
 -- Simulate the host's native skill dispatch before the real postStep call.
 for i,k in ipairs({'j','k','l','i'}) do if keys[k]==input.PRESSED and p:get('activity')==0 then survivor.callbacks.useSkill(p,i) end end
 fire('postStep')
end

local function contains(id)for _,v in ipairs(played)do if v.name=='MeleeFalcon'..id then return true end end;return false end
local spec=require('melee_sound_events')
assert(spec.definitions['60025'].sample==9,'Punch startup must use SEM sample 9, not guessed sample 8')
assert(spec.definitions['60007'].sample==3,'Taunt must use SEM sample 3')
assert(spec.definitions['60028'].sample==10,'Kick voice must use SEM sample 10')
local A=require('melee_audio')
A.play(60076);assert(math.abs(played[#played].pitch-2^(-400/1200))<.00001,'ground Kick SEM pitch -400 cents')
A.play(60082);assert(math.abs(played[#played].pitch-2^(-500/1200))<.00001,'Dive SEM pitch -500 cents')
played={};frame({l=input.PRESSED});assert(contains(110),'shield activation cue')
frame({});assert(contains(127),'shield release cue')
played={};frame({space=input.PRESSED});assert(not contains(74),'jump sound waits for original jump event')
for n=1,7 do frame({space=input.HELD}) end
assert(contains(74),'jump whoosh is wired into actual airborne movement')
played={};frame({});frame({space=input.PRESSED});assert(contains(spec.common.doublejump),'double-jump voice uses common fighter table')
played={};for n=1,150 do frame({d=input.HELD}) end
assert(contains(371),'landing/footsteps use original script fallback cue')
played={};p:set('hp',0);frame({});assert(contains(spec.common.ko),'death uses fighter KO cue, not an aerial damage grunt')
local n=#played;frame({});assert(#played==n,'KO cue only fires once')
local seen={};math.randomseed(123)
for i=1,40 do local d={};A.begin(d,'usmash');seen[played[#played].name]=true end
local count=0;for _ in pairs(seen)do count=count+1 end;assert(count>=3,'smash voice selects native variants')
print('PASS: exact SEM samples/pitches, shield transitions, timed jump/double jump, landing/footsteps, KO edge, original voice variants')
