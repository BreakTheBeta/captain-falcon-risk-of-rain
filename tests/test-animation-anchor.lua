local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local R=require('melee_renderer')
local function center(name,frame)
 local points=R.project(name,frame,1,2/3,0);local x,y=0,0
 for _,p in ipairs(points) do x=x+p[1];y=y+p[2] end
 return x/#points,y/#points
end
local failed=false
for _,name in ipairs({'dashattack','punch','raptor','kick','airkick','dive','roll'}) do
 local firstX,firstY=center(name,0);local drift=0
 for f=1,R.model.clips[name]-1 do local x,y=center(name,f);drift=math.max(drift,math.sqrt((x-firstX)^2+(y-firstY)^2)) end
 print(name..': body drift from fixed actor = '..string.format('%.2f',drift)..' pixels')
 if drift>14 then failed=true end
end
assert(not failed,'Animation displaces body by more than a survivor height while actor remains fixed')
print('PASS: attack/recovery body remains anchored to gameplay position')
-- A completed jump animation must hold its final pose, not restart midair.
local requested
R.getPixels=function(name,frame) requested={name,frame};return {} end
graphics={alpha=function()end,color=function()end,rectangle=function()end}
local d={motion={grounded=false,vy=-1,facing=1,vx=0},tick=200,airAnimation='doublejump',airFrame=R.model.clips.doublejump+3}
local p={x=100,y=100,getData=function()return d end,get=function(_,key)return key=='hp' and 125 or 0 end}
R.draw(p)
assert(requested[1]=='doublejump' and requested[2]==R.model.clips.doublejump-1,'Completed aerial animation restarted while still airborne')
print('PASS: airborne animation holds its last frame instead of wrapping')
