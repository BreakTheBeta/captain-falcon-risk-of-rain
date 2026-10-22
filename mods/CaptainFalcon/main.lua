local physics=require('physics')
local specialMotion=require('special_motion')
local keyboard=require('keyboard')
local controller=require('controller')
local combat=require('combat')
local mesh=require('melee_renderer')
local meleeAudio=require('melee_audio')
local falcon=Survivor.new('Captain Falcon')
local qa=modloader.checkFlag('falcon_test')
local S=physics.constants.scale
local sprites={}
for name,n in pairs({idle=4,run=8,jump=1,fall=1,climb=2,death=6,jab=4,knee=8,raptor=8,punch=12,kick=8,dive=8,ftilt=6,utilt=8,dtilt=6,smash=8,usmash=8,dsmash=8,dash=6,nair=8,bair=6,uair=6,dair=6,shield=1,dodge=4,roll=6,taunt=6}) do
 sprites[name]=Sprite.load('Falcon_'..name,'assets/'..name,n,8,14)
end
local mask=Sprite.load('FalconMask','assets/mask',1,2,9)
local icons=Sprite.load('FalconSkills','assets/skills',4,0,0)
local gold=Color.fromHex(0xF4C65B)
local white=Color.fromHex(0xF0EDE3)
local ink=Color.fromHex(0x171827)
local blue=Color.fromHex(0x79BEFF)
local selection=Sprite.load('FalconSelection','assets/select',13,2,0)
falcon.loadoutSprite=selection;falcon.idleSprite=sprites.idle;falcon.titleSprite=sprites.idle
falcon.loadoutColor=gold
falcon.endingQuote='...and so he left, looking for a worthy rival.'
falcon:setLoadoutInfo('Captain Falcon fights up close with Melee-style movement.\nCross attacks; Circle uses specials; Square/Triangle jump.\nAim with the stick. L2/R2 defend. Share opens controls.\nKeyboard: WASD, Space, J/K/L. H opens the full guide.',icons)
falcon:setLoadoutSkill(1,'Normals','J / Cross: jab, tilt, dash attack or aerial.\nFlick + attack, or right stick, for smash attacks.')
falcon:setLoadoutSkill(2,'Specials','K / Circle: Punch. Side: Raptor Boost.\nUp: Falcon Dive. Down: Falcon Kick.')
falcon:setLoadoutSkill(3,'Defence','L / L2 or R2: shield on ground; dodge in air.\nShield + direction: roll or spot dodge.')
falcon:setLoadoutSkill(4,'Taunt','I / D-pad up: show your moves.\nH / Share: full controls.')
local enemies=ParentObject.find('enemies','vanilla')
local effects={}
local function isFalcon(p) return isa(p,'PlayerInstance') and p:getSurvivor()==falcon end
local function data(p) return p:getData() end
local function clearActivity(p)
 p:set('activity',0);p:set('activity_type',0)
end
local function finish(p,landed)
 local d=data(p);local a=d.attack
 if a and not landed and (a.name=='airdodge' or a.name=='raptor' or (a.name=='dive' and not a.hit)) and not d.motion.grounded then d.specialFall=true end
 d.attack=nil;d.meleeSound=nil;clearActivity(p)
end
local function canAct(p)
 local d=data(p)
 return not d.attack and not d.specialFall and d.motion.lag<=0 and d.motion.squat==0 and d.stunned<=0 and p:get('activity')==0
end
local function begin(p,name,i)
 local d=data(p);local s=d.motion;local def=combat.moves[name]
 if not canAct(p) then return false end
 if name=='air dodge' then name='airdodge';def=combat.moves[name] end
 if name=='airdodge' and d.airDodgeUsed then return false end
 if name=='dive' and d.recoveryUsed then return false end
 if (s.grounded or def.special) and i.x~=0 then s.facing=i.x end
 local button=def.special and 2 or (def.defensive and 3 or (name=='taunt' and 4 or 1))
 d.attack={cstick=i.cstick,name=name,definition=def,age=0,charge=0,fired={},hit=false,airborne=not s.grounded,button=button}
 specialMotion.begin(d.attack,s)
 d.shielding=false
 local soundName=name
 if name=='punch' and not s.grounded then soundName='airpunch' end
 if name=='kick' and not s.grounded then soundName='airkick' end
 if name=='raptor' and not s.grounded then soundName='airraptor' end
 meleeAudio.begin(d,soundName)
 p:survivorActivityState(button,sprites[def.sprite],0,false,false)
 if name=='dive' then s.vy=-3.5*S;s.grounded=false;s.fast=false;d.recoveryUsed=true end
 if name=='airdodge' then
  local dx,dy=i.dodgeX or i.x,i.dodgeY or i.y
  local mag=math.sqrt(dx*dx+dy*dy)
  s.vx=mag>0 and dx/mag*3.1*S or 0;s.vy=mag>0 and dy/mag*3.1*S or 0
  s.fast=false;d.airDodgeUsed=true;d.attack.dx=s.vx;d.attack.dy=s.vy
 end
 if name=='roll' then
  d.attack.direction=i.x~=0 and i.x or s.facing
  p:set('invincible',math.max(p:get('invincible'),2))
 end
 if name=='jab1' or name=='jab2' or name=='gentleman' then d.combo=({jab1=1,jab2=2,gentleman=0})[name];d.comboTimer=48 end
 if qa then log('[Falcon QA] ACTION '..name) end
 return true
end
local function burst(p,size,color,x,y)
 effects[#effects+1]={x=x or p.x+data(p).motion.facing*8*S,y=y or p.y-8*S,size=size*S,ttl=10,color=color or gold}
end
local function targetIn(p,offset,w,h,yoffset)
 local s=data(p).motion
 w=w*S;h=h*S
 local x=p.x+s.facing*offset*S;local y=p.y+(yoffset or -8)*S
 return enemies:findRectangle(x-w/2,y-h/2,x+w/2,y+h/2),x,y
end
local function hit(p,event,charged)
 local d=data(p);local a=d.attack
 local target,x,y=targetIn(p,event[3],event[4],event[5],event[6])
 local amount=event[2]*(charged and (1+.4*a.charge/60) or 1)
 local b=p:fireExplosion(x,y,event[4]*S/19,event[5]*S/4,amount,nil,nil)
 if b then b:set('stun',amount>=4 and .4 or .15);b:set('knockback',math.min(10,amount));b:set('knockback_direction',d.motion.facing) end
 burst(p,amount>=4 and 11 or 5,amount>=4 and gold or white,x,y)
 if target then d.hitstop=amount>=5 and 7 or 3;a.hit=true end
 if qa then log('[Falcon QA] HIT '..a.name..' frame='..a.age..' damage='..amount..' target='..tostring(target~=nil)) end
end
falcon:addCallback('init',function(p)
 p:setAnimations({idle=sprites.idle,walk=sprites.run,jump=sprites.jump,climb=sprites.climb,death=sprites.death,decoy=sprites.idle})
 p.mask=mask;p.alpha=0;p:survivorSetInitialStats(125,12,.012);p:set('pHmax',physics.constants.run)
 p:setSkill(1,'Attack (J / A)','Direction + J: normals. Shift + direction + J: smash.',icons,1,0)
 p:setSkill(2,'Special (K / B)','Neutral Punch / side Raptor / up Dive / down Kick.',icons,2,0)
 p:setSkill(3,'Defend (L / triggers)','Hold shield; directional air dodge in the air.',icons,3,0)
 p:setSkill(4,'Taunt (I / D-pad up)','H / View: complete controls.',icons,4,0)
 local d=data(p)
 d.nativeGravity=p:get('pGravity1');d.nativeLaunch=nil;d.frameInput=nil;d.framePad=nil
 d.lCancelUntil=nil;d.landedAt=nil;d.inputDevice=nil
 d.motion=physics.new();d.keys={};d.combo=0;d.comboTimer=0;d.tick=0;d.attack=nil;d.pending=nil
 d.ropeDetach=0;d.shieldNativeOwned=false;d.arrivalInput=nil
 d.hitstop=0;d.shield=60;d.shielding=false;d.stunned=0;d.help=false;d.airDodgeUsed=false;d.recoveryUsed=false;d.specialFall=false
 log('[Falcon] Initialized 0.4.7: keyboard + controller; native-size artwork; no skill cooldowns')
end)
falcon:addCallback('levelUp',function(p) p:survivorLevelUpStats(30,3,.002,2) end)
-- Host skill dispatch is deliberately inert. The merged input interpreter below
-- handles edge-triggered attacks, so holding a key cannot auto-cast abilities.
falcon:addCallback('useSkill',function() end)

local syncShieldImmunity
callback.register('onDamage',function(p,amount)
 if not isFalcon(p) then return end
 local d=data(p)
 -- Cover every roll frame, including damage paths which bypass the native
 -- invincible counter. Shield still spends health and can break.
 if d.attack and d.attack.name=='roll' then return true end
 if d.shielding and d.stunned==0 then
  d.shield=math.max(0,d.shield-amount*.65);d.motion.lag=math.max(d.motion.lag,3)
  burst(p,13,blue,p.x,p.y-8)
  if d.shield<=0 then d.shielding=false;d.stunned=120;d.motion.lag=120;meleeAudio.shieldBreak(d);syncShieldImmunity(p) end
  if qa then log('[Falcon QA] SHIELD blocked '..amount..' remaining='..d.shield) end
  return true
 end
end)
local function readInput(p,d)
 local pad=controller.read(input,p,d.keys)
 local i;i,d.keys=keyboard.read(input.checkKeyboard,d.keys,pad)
 return i,pad
end
syncShieldImmunity=function(p)
 local d=data(p);local inv=p:get('invincible') or 0
 if d.shielding then
  if inv<2 then p:set('invincible',2);d.shieldNativeOwned=true end
 elseif d.shieldNativeOwned then
  if inv<=2 and not (d.attack and d.attack.name=='roll') then p:set('invincible',0) end
  d.shieldNativeOwned=false
 end
end
local function breakShield(p)
 local d=data(p)
 d.shield=0;d.shielding=false;d.stunned=120;d.motion.lag=120;meleeAudio.shieldBreak(d)
end
local function updateShield(p,i)
 local d=data(p);local s=d.motion
 d.shielding=i.defend and p:get('activity')==0 and s.grounded and not d.attack and d.shield>0 and d.stunned==0 and s.squat==0 and not i.jumpPressed
 syncShieldImmunity(p)
end
local function startGroundDodge(p,i)
 local d=data(p)
 if not d.shielding or not canAct(p) then return end
 if i.leftPressed or i.rightPressed or (i.defendPressed and i.x~=0) then begin(p,'roll',i)
 elseif i.downPressed or (i.defendPressed and i.y>0) then begin(p,'spotdodge',i) end
end
callback.register('preStep',function()
 for _,p in ipairs(misc.players) do
  if isFalcon(p) then
   local d=data(p);d.beforeX=p.x;d.beforeY=p.y
   -- Sample once before native enemy/damager updates. Reuse these edges in
   -- postStep so a first-frame shield/roll is already protecting the actor.
   d.frameInput,d.framePad=readInput(p,d)
   if d.ropeDetach>0 then
    d.ropeDetach=d.ropeDetach-1
    p:set('canrope',d.ropeDetach==0 and 1 or 0)
   end
   if p:get('activity')==30 then
    d.motion.grounded=false
    if d.frameInput.jumpPressed and d.stunned==0 and (p:get('dead') or 0)==0 and p:get('hp')>0 then
     clearActivity(p);p:set('rope_parent',-1);p:set('ropeUp',0);p:set('ropeDown',0);p:set('canrope',0);p:set('free',1)
     d.ropeDetach=12;d.frameInput.ropeJump=true
     local s=d.motion;s.vy=-physics.constants.jump;s.vx=(d.frameInput.moveX or d.frameInput.x)*physics.constants.dash
     s.jumps=1+(p:get('feather') or 0);s.fast=false;s.squat=0;s.lag=0;s.launchGravity=nil
     d.specialFall=false;d.airDodgeUsed=false;d.recoveryUsed=false;d.airFrame=0;d.airAnimation='jump';meleeAudio.jump(d)
    end
   end
   if (p:get('dead') or 0)==0 and p:get('hp')>0 then
    updateShield(p,d.frameInput);startGroundDodge(p,d.frameInput)
    if d.attack and d.attack.name=='roll' then p:set('invincible',math.max(p:get('invincible'),2)) end
   else d.shielding=false;syncShieldImmunity(p) end
   -- Map objects may apply their launch either side of the global step hooks.
   local gravity=p:get('pGravity1')
   if gravity and gravity>0 then d.nativeGravity=gravity end
   local nativeV=p:get('pVspeed') or 0
   -- Native Space also writes -3; only the native pad strengths (-6/-12)
   -- belong to the environmental launch path.
   if nativeV<=-5 then d.nativeLaunch=nativeV end
   p:set('pGravity1',0);p:set('pGravity2',0);p:set('pVspeed',0);p:set('pHspeed',0)
  end
 end
end)
local function land(p)
 local d=data(p);local a=d.attack
 if not d.motion.grounded then meleeAudio.land(d);d.landedAt=d.tick end
 local specialLag=specialMotion.landingLag(a)
 local lag=specialLag or (a and (a.name=='airdodge' and 10 or a.definition.landing) or 4)
 if a and a.definition.aerial and d.lCancelUntil and d.tick<=d.lCancelUntil then lag=math.floor((lag or 4)/2) end
 d.lCancelUntil=nil
 physics.land(d.motion,lag or 4)
 d.airDodgeUsed=false;d.recoveryUsed=false;d.specialFall=false
 if a and (specialLag or a.definition.aerial or a.name=='airdodge') then finish(p,true) end
end
local function moveAxis(p,amount,vertical)
 local s=data(p).motion
 while math.abs(amount)>.0001 do
  local step=math.max(-1,math.min(1,amount))
  local x=p.x+(vertical and 0 or step);local y=p.y+(vertical and step or 0)
  if p:collidesMap(x,y) then
   if vertical then if step>0 then land(p) end;s.vy=0 else s.vx=0 end
   return
  end
  p.x=x;p.y=y;amount=amount-step
 end
end
local function updateAttack(p,i)
 local d=data(p);local a=d.attack;if not a then return end
 local def=a.definition;local s=d.motion
 if not a.cstick and def.chargeFrame and a.age==def.chargeFrame and (i.chargeHeld==nil and i.attack or i.chargeHeld) and a.charge<60 then
  a.charge=a.charge+1;s.vx=s.vx*.7
  if a.charge%12==0 then burst(p,6,gold) end
 else a.age=a.age+1 end
 local t=a.age
 meleeAudio.step(d,t)
 for n,event in ipairs(def.hits) do
  if t>=event[1] and not a.fired[n] then a.fired[n]=true;hit(p,event,def.chargeFrame~=nil) end
 end
 if a.name=='knee' and t>=14 and t<=30 and not a.hit then
  if targetIn(p,9,19,17) then hit(p,{t,t<=16 and 6 or 1.5,9,19,17}) end
 elseif specialMotion.owns(a) then
  a.motionDone=specialMotion.step(a,s)
  if a.activeHit and not a.hit and targetIn(p,11,23,18) then
   hit(p,{t,a.name=='raptor' and 4 or 3.8,11,23,18})
   if a.name=='raptor' then
    a.raptorHitFrame=t;meleeAudio.begin(d,a.airborne and 'airraptorhit' or 'raptorhit',t);specialMotion.hit(a)
   end
  end
 elseif a.name=='punch' or a.name=='jab1' or a.name=='jab2' or a.name=='gentleman' then s.vx=s.vx*.72
 elseif a.name=='dashattack' and t<15 then s.vx=s.facing*2.2*S
 elseif a.name=='airdodge' then
  if t<=20 then
   p:set('invincible',math.max(p:get('invincible'),2));s.vx=a.dx*.94^(t-1);s.vy=a.dy*.94^(t-1)
  end
 elseif a.name=='roll' then
  p:set('invincible',math.max(p:get('invincible'),2))
  if t>=4 and t<=20 then s.vx=a.direction*2.2*S else s.vx=s.vx*.7 end
 elseif a.name=='spotdodge' then
  s.vx=0;if t>=2 and t<=16 then p:set('invincible',math.max(p:get('invincible'),2)) end
 end
 if t%4==0 and (a.name=='punch' and t>=40 or a.name=='kick' or a.name=='dive') then burst(p,4,Color.fromHex(0xFF853A)) end
 p.sprite=sprites[def.sprite];p.subimage=math.min(p.sprite.frames,1+math.floor(t/def.duration*p.sprite.frames));p.spriteSpeed=0
 if (specialMotion.owns(a) and a.motionDone) or (not specialMotion.owns(a) and t>=def.duration) then finish(p,false) end
end
callback.register('postStep',function()
 for _,p in ipairs(misc.players) do
  if isFalcon(p) then
   local d=data(p);local s=d.motion;d.tick=d.tick+1
   local i,pad=d.frameInput,d.framePad
   if not i then i,pad=readInput(p,d) end
   d.frameInput=nil;d.framePad=nil
   if pad.active then d.inputDevice='controller'
   else for _,key in pairs(keyboard.bindings) do if input.checkKeyboard(key)>=2 then d.inputDevice='keyboard';break end end end
   if i.helpPressed then d.help=not d.help end
   if i.defendPressed and not s.grounded and d.attack and d.attack.definition.aerial then d.lCancelUntil=d.tick+7 end
   local activity=p:get('activity')
   if d.ropeDetach>0 and activity==30 then
    clearActivity(p);p:set('rope_parent',-1);p:set('canrope',0);activity=0
   end
   local alive=(p:get('dead') or 0)==0 and p:get('hp')>0
   -- Native arrival owns activity 99. Edges sampled during its last frames
   -- would otherwise be consumed without ever reaching the fighter. Keep a
   -- six-frame handoff buffer, never an indefinite held-button retry.
   local arriving=alive and activity==99 and not d.attack
   local actionable=alive and (activity==0 or d.attack)
   local pressed=i.attackPressed or i.specialPressed or i.jumpPressed or i.defendPressed or i.tauntPressed
   if d.arrivalInput then
    d.arrivalInput.life=d.arrivalInput.life-1
    if d.arrivalInput.life<=0 or not (arriving or actionable) then d.arrivalInput=nil end
   end
   if arriving and pressed then d.arrivalInput={input=i,life=7}
   elseif actionable and d.arrivalInput then
    if not pressed then
     local buffered=d.arrivalInput.input
     for _,action in ipairs({'attack','special','jump','defend','taunt'}) do i[action..'Pressed']=buffered[action..'Pressed'] end
     if buffered.attackPressed or buffered.specialPressed then
      i.x=buffered.x;i.y=buffered.y;i.smash=buffered.smash;i.cstick=buffered.cstick
     end
    end
    d.arrivalInput=nil
   end
   if alive and d.beforeX and (activity==0 or d.attack) then
    local nativeV=p:get('pVspeed') or 0
    local launch=nativeV<=-5 and nativeV or d.nativeLaunch;d.nativeLaunch=nil
    p.x=d.beforeX;p.y=d.beforeY
    local ground=p:collidesMap(p.x,p.y+1)
    if ground and s.vy>=0 then land(p) elseif not ground then s.grounded=false end
    if launch then
     if d.attack then finish(p,true) end
     physics.launch(s,launch,d.nativeGravity,p:get('feather') or 0)
     d.shielding=false;d.specialFall=false;d.airDodgeUsed=false;d.recoveryUsed=false;d.hitstop=0;d.pending=nil
     if qa then log('[Falcon QA] PAD LAUNCH vy='..launch..' gravity='..s.launchGravity) end
    end
    if d.stunned>0 then d.stunned=d.stunned-1 end
    if d.comboTimer>0 then d.comboTimer=d.comboTimer-1 else d.combo=0 end
    if d.hitstop>0 then
     d.hitstop=d.hitstop-1
    else
     if i.attackPressed or i.specialPressed or i.tauntPressed then d.pending={input=i,life=6} end
     -- Allow deliberate button presses to link the grounded jab sequence.
     if d.attack and (d.attack.name=='jab1' or d.attack.name=='jab2') and d.attack.age>=8 and d.pending and d.pending.input.attackPressed and i.x==0 and i.y==0 then finish(p,false) end
     updateShield(p,i)
     if canAct(p) and not (i.jumpPressed and s.grounded) then
      if i.defendPressed and not s.grounded then begin(p,'airdodge',i)
      elseif d.shielding and (i.leftPressed or i.rightPressed or (i.defendPressed and i.x~=0)) then begin(p,'roll',i)
      elseif d.shielding and (i.downPressed or (i.defendPressed and i.y>0)) then begin(p,'spotdodge',i)
      elseif d.pending and not d.shielding then
       local name=combat.choose(d.pending.input,s,d.combo)
       if name and begin(p,name,d.pending.input) then d.pending=nil end
      end
     end
     if d.pending then d.pending.life=d.pending.life-1;if d.pending.life<=0 then d.pending=nil end end
     if d.shielding then
      d.shield=math.max(0,d.shield-.16);if d.shield<=0 then breakShield(p) end
     else d.shield=math.min(60,d.shield+.1) end
     syncShieldImmunity(p)
     local events=physics.step(s,{ownedMotion=specialMotion.owns(d.attack),direction=i.moveX or i.x,walk=i.walk,analog=i.analog,analogX=i.analogX,dashPressed=i.dashPressed,blockMovement=d.shielding or (d.attack~=nil and (s.grounded or not d.attack.definition.aerial)) or d.stunned>0,
      jumpPressed=i.jumpPressed and not i.ropeJump and not d.attack and not d.specialFall and d.stunned==0,jumpHeld=i.jump,
      downPressed=i.downPressed,extraJumps=p:get('feather') or 0})
     if qa then
      if events.jump then log('[Falcon QA] JUMP') end
      if events.doubleJump then log('[Falcon QA] DOUBLE JUMP') end
      if events.fastFall then log('[Falcon QA] FAST FALL') end
     end
     if events.doubleJump then meleeAudio.doubleJump(d);d.airFrame=0;d.airAnimation='doublejump' end
     if events.jump then meleeAudio.jump(d);d.airFrame=0;d.airAnimation='jump' end
     if not s.grounded then d.airFrame=(d.airFrame or 0)+1 else d.airFrame=0;d.airAnimation=nil end
     updateAttack(p,i)
     local speed=math.max(.25,(p:get('pHmax') or physics.constants.run)/physics.constants.run)
     moveAxis(p,s.vx*speed,false);moveAxis(p,s.vy,true)
    end
    p:set('free',s.grounded and 0 or 1);p:set('pVspeed',0);p:set('pHspeed',0);p.xscale=s.facing
    if not d.attack then
     local sprite=d.shielding and sprites.shield or (not s.grounded and (s.vy<0 and sprites.jump or sprites.fall) or (math.abs(s.vx)>.2 and sprites.run or sprites.idle))
     p.sprite=sprite;p.subimage=1+math.floor(d.tick/6)%sprite.frames;p.spriteSpeed=0
    end
   else d.shielding=false;d.pending=nil;s.vx=0;s.vy=0;d.attack=nil end
   meleeAudio.update(p)
  end
 end
end)
callback.register('onDraw',function()
 for _,p in ipairs(misc.players) do if isFalcon(p) then mesh.draw(p) end end
 for i=#effects,1,-1 do
  local e=effects[i];graphics.color(e.color);graphics.alpha(e.ttl/12);graphics.circle(e.x,e.y,e.size*(11-e.ttl)/10,true)
  e.ttl=e.ttl-1;if e.ttl<=0 then table.remove(effects,i) end
 end
 for _,p in ipairs(misc.players) do
  if isFalcon(p) and data(p).shielding then
   local d=data(p);graphics.color(d.shield>20 and blue or Color.fromHex(0xFF7777));graphics.alpha(.35)
   graphics.circle(p.x,p.y-8*S,(9+d.shield/15)*S);graphics.alpha(.9);graphics.circle(p.x,p.y-8*S,(9+d.shield/15)*S,true)
  end
 end
 graphics.alpha(1)
end)
local helpLeft={
 'MOVEMENT','W A S D   Move / aim attacks','Space     Jump; tap for short hop','Space x2  Double jump','S falling Fast fall','Ctrl      Hold to walk','',
 'NORMAL ATTACKS (J)','J         Jab combo (press 3 times)','Moving J  Dash attack','W / S + J Up / down tilt','Ctrl+A/D+J Side tilt',
 'Shift + direction + J: smash','Hold J to charge a smash','',
 'AERIAL ATTACKS (J)','No direction: neutral air','Forward: Knee of Justice','Back: back air; W: up air','S: down-air stomp'
}
local helpRight={
 'SPECIALS (K)','K         Falcon Punch','A / D + K Raptor Boost','W + K     Falcon Dive','S + K     Falcon Kick','',
 'DEFENCE (L)','Hold L    Shield on the ground','L + A/D   Roll while shielding','L + S     Spot dodge','Air L     Directional air dodge','Air S+A/D+L: wavedash to floor','',
 'OTHER CONTROLS','E         Interact / take item','A / D     Choose between items','Q         Use equipment','F         Swap equipment','I         Taunt','H         Toggle this guide','Esc       Pause'
}
local helpPadLeft={
 'PS4 CONTROLLER / MOONLIGHT','Left stick Tilt to walk; flick to dash','Square / Triangle: jump / double jump','Down falling: fast fall','',
 'NORMAL ATTACKS','Cross     Jab combo','Stick + Cross: normal / aerial','Right stick: smash / aerial','Flick stick + Cross: smash / charge','Hold Cross: charge; release: strike','',
 'SPECIALS','Circle    Falcon Punch','Left/right + Circle: Raptor Boost','Up + Circle: Falcon Dive','Down + Circle: Falcon Kick'
}
local helpPadRight={
 'DEFENCE','L2 / R2   Hold shield','Shield + left/right: roll','Shield + down: spot dodge','Air trigger: directional air dodge','Air down+side+trigger: wavedash','Trigger before landing: L-cancel','',
 'OTHER CONTROLS','R1        Interact / take item','Left stick Choose between items','L1        Use equipment','L3        Swap equipment','D-pad up  Taunt','Share     Toggle guide','Options   Pause','',
 'PS: A=Cross, B=Circle','X=Square, Y=Triangle','LT/RT=L2/R2; LB/RB=L1/R1'
}
callback.register('onHUDDraw',function()
 local p=misc.players[1];if not p or not isFalcon(p) then return end
 local d=data(p);local w,h=graphics.getHUDResolution()
 if d.help then
  local width=math.min(w-20,680);local x=(w-width)/2;local y=math.max(8,(h-390)/2)
  graphics.color(ink);graphics.alpha(.97);graphics.rectangle(x,y,x+width,y+390);graphics.alpha(1)
  graphics.color(gold);graphics.rectangle(x,y,x+width,y+390,true)
  graphics.print(d.inputDevice=='controller' and 'CAPTAIN FALCON - CONTROLLER' or 'CAPTAIN FALCON - KEYBOARD',w/2,y+12,graphics.FONT_LARGE,graphics.ALIGN_MIDDLE)
  for column,lines in ipairs(d.inputDevice=='controller' and {helpPadLeft,helpPadRight} or {helpLeft,helpRight}) do
   for n,line in ipairs(lines) do
    graphics.color((line==string.upper(line) and #line>0) and gold or white)
    graphics.print(line,x+16+(column-1)*width/2,y+44+(n-1)*14,graphics.FONT_DEFAULT)
   end
  end
  graphics.color(white);graphics.print(d.inputDevice=='controller' and 'Share: close guide   |   Options: pause' or 'H: close guide   |   Esc: pause the game',w/2,y+370,graphics.FONT_SMALL,graphics.ALIGN_MIDDLE)
 elseif d.tick<480 then
  graphics.color(gold);graphics.print(d.inputDevice=='controller' and 'Cross Attack | Circle Special | Square/Triangle Jump | Share Controls' or 'WASD  |  J Attack  K Special  L Defend  |  H Controls',w/2,44,graphics.FONT_DEFAULT,graphics.ALIGN_MIDDLE)
 end
end)
log('[Falcon] Loaded 0.4.7: WASD + JKL; fighter attacks/specials; QA='..tostring(qa))


