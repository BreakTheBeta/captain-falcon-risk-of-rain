local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local R=require('melee_renderer')
assert(R.model.vertices>2000 and R.model.bones==63,'Original Falcon mesh/skeleton expected')
local function hash(p) local h=0;for _,v in ipairs(p) do h=(h+v[1]*97+v[2]*131+v[3])%1000000007 end;return h end
local idle=R.rasterize('idle',0,1,2/3,0)
local top,bottom=1000,-1000
for _,v in ipairs(idle) do top=math.min(top,v[2]);bottom=math.max(bottom,v[2]) end
assert(#idle>30 and bottom-top>=10 and bottom-top<=15,'Imported model must match native survivor height')
local rotated=R.rasterize('idle',0,1,2/3,1.2)
assert(hash(idle)~=hash(rotated),'Changing 3D camera angle must change the rendered geometry')
local t=os.clock();local count=0
for name,frames in pairs(R.model.clips) do
 for _,f in ipairs({0,math.floor(frames/2),frames-1}) do
  local pixels=R.getPixels(name,f,1);assert(#pixels>10,'Empty mesh pose: '..name..' '..f);count=count+1
 end
end
print('PASS: original XYZ mesh, native-size silhouette, live camera rotation, all '..count..' sampled animation poses; CPU seconds='..(os.clock()-t))
local spec=require('melee_sound_events')
assert(#spec.events.punch>=3 and #spec.events.taunt>0,'Original Punch and taunt sound events must import')
local played={};Sound={load=function(name,path)return {play=function()played[#played+1]=name end,stop=function()end}end}
local A=require('melee_audio');local d={};A.begin(d,'punch');assert(#played==1,'Punch startup voice')
A.step(d,51);assert(#played==1,'Impact sound must wait for original event frame')
A.step(d,52);assert(#played>=4,'Punch impact sound events at frame 52')
local n=#played;A.step(d,52);assert(#played==n,'Hitstop must not replay sound events')
A.begin(d,'taunt');assert(#played==n+1,'Original taunt voice')
print('PASS: original startup/impact/taunt sound mapping; no repeated sounds on frozen frames')
