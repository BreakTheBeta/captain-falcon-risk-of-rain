local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local R=require('melee_renderer')
for name,frames in pairs(R.model.clips) do
 if not os.getenv("FALCON_POSE_ONLY") or os.getenv("FALCON_POSE_ONLY"):find(","..name..",",1,true) then
 local out=assert(io.open(assert(os.getenv('FALCON_BUILD_TMP'))..'/pose-'..name..'.bin','wb'))
 out:write(string.pack('<I4',frames))
 for f=0,frames-1 do
  local pixels=R.rasterize(name,f,1,4/3,0);out:write(string.pack('<I4',#pixels))
  for _,p in ipairs(pixels) do out:write(string.pack('<i2i2I4',p[1],p[2],p[3])) end
 end
 out:close()
 end
end
print('Baked supersampled original-model animation poses')
