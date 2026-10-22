-- Melee attributes scaled to the native survivor artwork (13px body).
-- Source: BroccoliRaab/meleedb character_attributes.json (local reference).
local M={}
M.constants={scale=1,run=2.3,dash=2,gravity=.13,terminal=2.9,fastFall=3.5,
 jump=3.1,shortHop=1.9,airJump=2.79,airMax=1.12,airAcceleration=.06,
 airFriction=.01,friction=.08,jumpsquat=4,jumpMomentum=.75,walk=.85}
local S=2/3
for _,key in ipairs({"run","dash","gravity","terminal","fastFall","jump","shortHop","airJump","airMax","airAcceleration","airFriction","friction","walk"}) do M.constants[key]=M.constants[key]*S end
M.constants.scale=S
local C=M.constants
local function approach(a,b,d) return a<b and math.min(a+d,b) or math.max(a-d,b) end
function M.new() return {vx=0,vy=0,grounded=true,jumps=2,squat=0,fast=false,lag=0,facing=1,previousDirection=0,short=false} end
function M.step(s,i)
 local events={}
 if i.ownedMotion then return events end
 if s.grounded then s.jumps=2+(i.extraJumps or 0);s.fast=false end
 if s.lag>0 then s.lag=s.lag-1 end
 if s.squat>0 then
  if not i.jumpHeld then s.short=true end
  s.squat=s.squat-1
  if s.squat==0 then
   s.vy=-(s.short and C.shortHop or C.jump);s.vx=s.vx*C.jumpMomentum
   s.grounded=false;s.jumps=1+(i.extraJumps or 0);events.jump=true
  end
 elseif i.jumpPressed and s.lag==0 then
  if s.grounded then s.squat=C.jumpsquat;s.short=false;events.squat=true
  elseif s.jumps>0 then s.vy=-C.airJump;s.launchGravity=nil;s.jumps=s.jumps-1;s.fast=false;events.doubleJump=true end
 end
 local dir=i.direction or 0
 if s.lag==0 and not i.blockMovement then
  if s.grounded then
   if dir~=0 then
    if i.analog then
     local mag=math.min(1,math.abs(i.analogX or dir))
     if i.dashPressed then s.dashing=true;s.vx=dir*C.dash end
     if mag<.62 then s.dashing=false end
     local target=s.dashing and C.run or C.walk*mag
     s.vx=approach(s.vx,dir*target,(s.dashing and .16 or .1)*S)
    elseif i.walk then s.vx=approach(s.vx,dir*C.walk,.1*S)
    else
     if dir~=s.previousDirection or s.vx*dir<0 then s.vx=C.dash*dir end
     s.vx=approach(s.vx,dir*C.run,.16*S)
    end
    s.facing=dir
   else s.dashing=false;s.vx=approach(s.vx,0,C.friction) end
  elseif dir~=0 and s.vx*dir<C.airMax then s.vx=approach(s.vx,dir*C.airMax,C.airAcceleration*(i.analog and math.min(1,math.abs(i.analogX or dir)) or 1))
  elseif dir==0 then s.vx=approach(s.vx,0,C.airFriction) end
 else s.vx=approach(s.vx,0,s.grounded and .2*S or C.airFriction) end
 if not s.grounded then
  if s.vy>=0 and i.downPressed then s.fast=true;events.fastFall=true end
  s.vy=s.fast and C.fastFall or math.min(C.terminal,s.vy+(s.launchGravity or C.gravity))
  if s.vy>=0 then s.launchGravity=nil end
 elseif s.squat==0 then s.vy=0 end
 s.previousDirection=dir
 return events
end
-- Environmental launch speeds use map units, preserving native pad height.
function M.launch(s,velocity,gravity,extraJumps)
 s.vy=velocity;s.grounded=false;s.fast=false;s.squat=0;s.short=false;s.lag=0
 s.jumps=1+(extraJumps or 0)
 s.launchGravity=(gravity and gravity>0) and gravity or .26
end
function M.land(s,lag)
 local airborne=not s.grounded;s.grounded=true;s.vy=0;s.fast=false;s.jumps=2;s.launchGravity=nil
 if airborne then s.lag=math.max(s.lag,lag or 4) end
end
return M
