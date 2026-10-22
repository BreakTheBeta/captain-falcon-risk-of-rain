-- Melee ft_80085134: TransN Z is forward travel; Y is vertical travel.
-- Root translation stays removed from the rendered mesh: apply it once here.
local data=require('melee_motion_data')
local M={};local S=2/3
local function clip(a)
 if a.name=='raptor' then
  return (a.airborne and 'SpecialAirS' or 'SpecialS')..(a.hit and '' or 'Start')
 elseif a.name=='kick' then
  if a.recovery then return a.airborne and 'SpecialAirLwEndAir' or 'SpecialLwEndAir' end
  return a.airborne and 'SpecialAirLw' or 'SpecialLw'
 end
end
function M.begin(a,s)
 if not clip(a) then return end
 a.motionFrame=0;a.motionGravity=0
 s.vx=0;s.vy=0;s.fast=false;s.launchGravity=nil;s.dashing=false
end
function M.owns(a) return a and (a.name=='raptor' or a.name=='kick') end
function M.step(a,s)
 local name=clip(a);if not name then return end
 local c=data.clips[name];a.motionFrame=(a.motionFrame or 0)+1
 local t=a.motionFrame;local v=c.velocity[math.min(t,#c.velocity)]
 local vars={}
 for _,e in ipairs(c.vars) do if t>=e[1] then vars[e[2]]=e[3] end end
 a.activeHit=vars[0]==1
 -- Aerial kick recovery uses ordinary gravity, without fast-fall input.
 -- Ground kick leaving an edge switches to its own rising recovery curve.
 if a.recovery and a.airborne then
  s.vx=s.vx>0 and math.max(0,s.vx-.01*S) or math.min(0,s.vx+.01*S)
  s.vy=math.min(2.9*S,s.vy+.13*S)
 elseif a.recovery and vars[0]==1 then
  s.vx=s.vx>0 and math.max(0,s.vx-.01*S) or math.min(0,s.vx+.01*S)
  s.vy=math.min(2.9*S,s.vy+.13*S)
 else
  s.vx=v[1]*s.facing*S;s.vy=s.grounded and 0 or v[2]*S
  if a.name=='raptor' and not s.grounded and (a.hit or vars[1]==1) then
   a.motionGravity=math.min(data.terminal*S,(a.motionGravity or 0)+data.gravity*S)
   s.vy=a.motionGravity
  end
 end
 s.fast=false
 if t>=#c.velocity then
  if a.name=='kick' and not a.recovery and not s.grounded then
   a.recovery=true;a.motionFrame=0;return false
  end
  return true
 end
 return false
end
function M.landingLag(a)
 if not a or not a.airborne then return end
 if a.name=='raptor' then return a.hit and data.hitLanding or data.missLanding end
 if a.name=='kick' then return math.ceil(#data.clips.SpecialAirLwEnd.velocity/data.kickLandingRate) end
end
function M.hit(a)
 a.motionFrame=0;a.motionGravity=0
end
return M
