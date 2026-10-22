local spec=require('melee_sound_events')
local A={};local sounds={}
for _,id in ipairs(spec.ids) do sounds[id]=Sound.load('MeleeFalcon'..id,'assets/melee-sounds/'..id) end
local function stop(d,group)
 if not d or not d.soundChannels then return end
 local sound=d.soundChannels[group]
 if sound then sound:stop();d.soundChannels[group]=nil end
end
function A.play(id,volume,d,behavior)
 if id==540000 then return end -- Melee's explicit no-sound sentinel.
 if id==540001 then stop(d,behavior);return end
 local sound=sounds[id];local definition=spec.definitions[tostring(id)]
 if not sound or not definition then return end
 if d and behavior and behavior>0 then
  if behavior==2 or behavior==6 then stop(d,2);stop(d,6) end
  d.soundChannels=d.soundChannels or {};d.soundChannels[behavior]=sound
 end
 sound:play(definition.pitch,.55*definition.volume*(volume or 1))
 if modloader and modloader.checkFlag('falcon_test') then log('[Falcon QA] MELEE SOUND '..id..' sample='..definition.sample..' pitch='..definition.pitch) end
end
local function emit(d,event)
 if event.behavior>=10 then stop(d,event.behavior-9);return end
 if event.behavior>6 then return end
 local ids=event.ids;A.play(ids[#ids==1 and 1 or math.random(#ids)],event.volume,d,event.behavior)
end
local function between(d,name,last,frame)
 for _,event in ipairs(spec.events[name] or {}) do
  if event.frame>last and event.frame<=frame then emit(d,event) end
 end
end
function A.begin(d,name,age)
 d.meleeSound={name=name,last=-1,startAge=age or 0};A.step(d,age or 0)
end
function A.step(d,age)
 local state=d.meleeSound;if not state then return end
 local frame=age-state.startAge
 between(d,state.name,state.last,frame);state.last=frame
end
function A.jump(d) if d then d.soundMotion=nil;A.play(spec.common.jump,1,d,0) end end
function A.doubleJump(d) A.jump(d);A.play(spec.common.doublejump,1,d,2) end
function A.land(d) between(d,'landing',-1,0);d.soundMotion=nil end
function A.shieldBreak(d) A.play(spec.engine.shield_break,1,d,0) end
function A.update(p)
 local d=p:getData();local s=d.motion
 local dead=(p:get('dead') or 0)~=0 or p:get('hp')<=0
 if dead then
  if not d.soundDead then A.play(spec.common.ko,1,d,2);d.soundDead=true end
  return
 end
 if d.shielding and not d.soundShielding then A.play(spec.engine.shield_on,1,d,0)
 elseif d.soundShielding and not d.shielding and not d.attack then A.play(spec.engine.shield_off,1,d,0) end
 d.soundShielding=d.shielding
 if d.attack or d.shielding then d.soundMotion=nil;return end
 local name,frame
 if not s.grounded then name=s.vy<0 and (d.airAnimation or 'jump') or 'fall';frame=d.airFrame or 0
 elseif math.abs(s.vx)>.15 then name=math.abs(s.vx)<.7 and 'walk' or 'run'
 else d.soundMotion=nil;return end
 local state=d.soundMotion
 if not state or state.name~=name then state={name=name,last=-1,tick=0};d.soundMotion=state end
 if not frame then
  state.tick=state.tick+1;frame=(state.tick-1)%spec.lengths[name]+1
 end
 if frame<state.last then state.last=-1 end
 between(d,name,state.last,frame);state.last=frame
end
return A
