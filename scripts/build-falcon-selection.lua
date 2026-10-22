local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local R=require('melee_renderer');local out=assert(io.open(assert(os.getenv('FALCON_BUILD_TMP'))..'/selection-poses.bin','wb'))
for frame=0,12 do
 local pixels=R.rasterize('idle',frame*4,1,3.2,.35);out:write(string.pack('<I4',#pixels))
 for _,p in ipairs(pixels) do out:write(string.pack('<i2i2I4',p[1],p[2],p[3])) end
end
out:close()
