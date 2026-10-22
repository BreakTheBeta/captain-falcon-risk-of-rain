-- Original Melee mesh, textures, and skinned XYZ animation poses.
-- Orthographic 3D projection + per-pixel depth buffer. RoRML draws the result
-- using its documented 2D primitives. Pose/view caching avoids repeat work.
local model=require('melee_model')
local R={model=model}
local clips,cache,colors={},{},{}
-- Cache the same 3D poses as supersampled native textures. This removes
-- triangle rasterization stalls on the first use of each gameplay frame.
local poseSprites={}
if Sprite then
 local frames=require('melee_pose_sprites')
 for name,count in pairs(frames) do poseSprites[name]=Sprite.load('FalconMeleePose_'..name,'assets/melee-poses/'..name,count,32,48) end
end
local floor,ceil,min,max,abs=math.floor,math.ceil,math.min,math.max,math.abs
local byte=string.byte
local function clip(name)
 if not clips[name] then clips[name]=require('melee_clip_'..name) end
 return clips[name]
end
local function signed(a,b) local n=a+b*256;if n>=32768 then n=n-65536 end;return n/256 end
function R.project(name,frame,facing,scale,yaw)
 local poses=clip(name);frame=max(1,min(#poses,floor(frame)+1))
 local data=poses[frame];local points={};local co,si=math.cos(yaw or 0),math.sin(yaw or 0)
 for i=1,model.vertices do
  local n=(i-1)*6+1;local a,b,c,d,e,f=byte(data,n,n+5)
  local x,y,z=signed(a,b),signed(c,d),signed(e,f)
  points[i]={(z*co+x*si)*scale*facing,-y*scale,(-x*co+z*si)*facing}
 end
 return points
end
function R.rasterize(name,frame,facing,scale,yaw)
 local points=R.project(name,frame,facing,scale,yaw)
 local depth,pixels={},{}
 for _,tri in ipairs(model.triangles) do
  local a,b,c=points[tri[1]],points[tri[2]],points[tri[3]]
  local x1,y1,x2,y2,x3,y3=a[1],a[2],b[1],b[2],c[1],c[2]
  local area=(x2-x1)*(y3-y1)-(y2-y1)*(x3-x1)
  if abs(area)>.00001 then
   local left,right=ceil(min(x1,x2,x3)-.5),floor(max(x1,x2,x3)-.5)
   local top,bottom=ceil(min(y1,y2,y3)-.5),floor(max(y1,y2,y3)-.5)
   local tex=model.textures[tri[5]]
   for y=top,bottom do for x=left,right do
    local px,py=x+.5,y+.5
    local w2=((px-x1)*(y3-y1)-(py-y1)*(x3-x1))/area
    local w3=((x2-x1)*(py-y1)-(y2-y1)*(px-x1))/area
    local w1=1-w2-w3
    if w1>=0 and w2>=0 and w3>=0 then
     local z=a[3]*w1+b[3]*w2+c[3]*w3
     local key=(y+256)*512+x+256
     if not depth[key] or z>depth[key] then
      local color=tri[4];local alpha=255
      if tex then
       local u=tri[6]*w1+tri[8]*w2+tri[10]*w3
       local v=tri[7]*w1+tri[9]*w2+tri[11]*w3
       local tx=min(tex.width-1,max(0,floor(u*tex.width)))
       local ty=min(tex.height-1,max(0,floor(v*tex.height)))
       local off=(ty*tex.width+tx)*4+1
       local bl,g,r,al=byte(tex.bgra,off,off+3)
       color=r*65536+g*256+bl;alpha=al
      end
      if alpha>=128 then depth[key]=z;pixels[key]={x,y,color} end
     end
    end
   end end
  end
 end
 local result={};for _,pixel in pairs(pixels) do result[#result+1]=pixel end
 return result
end
function R.getPixels(name,frame,facing)
 local frames=model.clips[name];if not frames then name='idle';frames=model.clips.idle end
 frame=max(0,min(frames-1,floor(frame)))
 local key=name..':'..frame..':'..facing
 if not cache[key] then cache[key]=R.rasterize(name,frame,facing,2/3,0) end
 return cache[key]
end
function R.draw(p)
 local d=p:getData();local s=d.motion;if not s then return end
 local name,frame='idle',d.tick
 if (p:get('dead') or 0)~=0 or p:get('hp')<=0 then
  name=s.grounded and model.clips.deathland and 'deathland' or 'death'
  frame=d.death and (name=='deathland' and d.death.landAge or d.death.age-1) or 0
  frame=frame or 0
 elseif d.attack then
  name=d.attack.name;frame=d.attack.age
  if name=='punch' and d.attack.airborne then name='airpunch' end
  if name=='kick' then
   if d.attack.recovery then name=d.attack.airborne and 'airkickrecovery' or 'kickrecovery';frame=d.attack.motionFrame
   elseif d.attack.airborne then name='airkick' end
  end
  if name=='raptor' and d.attack.airborne then name='airraptor' end
  if name=='raptor' and d.attack.hit then name=d.attack.airborne and 'airraptorhit' or 'raptorhit';frame=d.attack.age-(d.attack.raptorHitFrame or 0) end
 elseif d.shielding then name='shield';frame=0
 elseif s.grounded and d.landedAt and s.lag>0 then name='landing';frame=d.tick-d.landedAt
 elseif not s.grounded then name=s.vy<0 and (d.airAnimation or 'jump') or 'fall';frame=d.airFrame or 0
 elseif abs(s.vx)>.15 then name=abs(s.vx)<.7 and 'walk' or 'run' end
 -- Only cyclic locomotion loops. Jump/recovery/death must hold their end pose.
 if name=='idle' or name=='run' or name=='walk' or name=='fall' then
  frame=frame%model.clips[name]
 else frame=min(frame,model.clips[name]-1) end
 if d.soundMotion and d.soundMotion.name==name and (name=='walk' or name=='run') then frame=d.soundMotion.last end
 frame=max(0,min(model.clips[name]-1,floor(frame)))
 if poseSprites[name] then
  graphics.alpha(1)
  graphics.drawImage{image=poseSprites[name],x=floor(p.x+.5),y=floor(p.y+.5),subimage=frame+1,xscale=s.facing}
  return
 end
 local pixels=R.getPixels(name,frame,s.facing)
 graphics.alpha(1)
 for _,pixel in ipairs(pixels) do
  local c=pixel[3];if not colors[c] then colors[c]=Color.fromHex(c) end
  graphics.color(colors[c]);graphics.rectangle(p.x+pixel[1],p.y+pixel[2],p.x+pixel[1]+1,p.y+pixel[2]+1,false)
 end
end
function R.clearCache() cache={};colors={} end
return R
