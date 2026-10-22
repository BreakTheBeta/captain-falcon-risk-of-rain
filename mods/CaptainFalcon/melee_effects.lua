-- Private sprites are baked from the owner's EfCaData.dat textures/scripts.
-- Playback follows fighter animation time, so hitstop never advances flames.
local F={}
-- RoRML's require inspects its immediate Lua caller to find the mod folder.
-- Calling require directly through pcall loses that source context.
local ok,spec=pcall(function()
 local data=require('melee_effect_data')
 return data
end)
local sprites={}
if ok then
 for name,count in pairs(spec.clips) do sprites[name]=Sprite.load('FalconMeleeEffect_'..name,'assets/melee-effects/'..name,count,44,40) end
end
function F.draw(p)
 if not ok or (p:get('dead') or 0)~=0 or p:get('hp')<=0 then return end
 local d=p:getData();local a=d.attack;if not a then return end
 local name,frame,x,y,angle=nil,nil,0,0,0
 if a.name=='punch' or a.name=='kick' and not a.recovery then
  local move=(a.airborne and 'air' or '')..a.name
  local gate=spec.gates[move]
  if a.age<gate[1] or a.age>=gate[2] then return end
  name=a.name=='punch' and 'effect0' or 'effect2';frame=a.age-gate[1]
  if a.name=='kick' then
   local points=spec.anchors[move];local anchor=points[math.min(#points,a.age+1)]
   x,y=anchor[1],anchor[2]
   if a.airborne then angle=-spec.airKickAngle*d.motion.facing end
  end
 elseif a.name=='raptor' and a.hit then
  name=a.airborne and 'effect5' or 'effect3';frame=a.age-(a.raptorHitFrame or a.age)
 end
 if not name or frame<0 or frame>=spec.clips[name] then return end
 graphics.alpha(1)
 graphics.drawImage{image=sprites[name],x=math.floor(p.x+x*d.motion.facing+.5),y=math.floor(p.y+y+.5),subimage=math.floor(frame)+1,xscale=d.motion.facing,angle=angle}
end
F.available=ok
return F
