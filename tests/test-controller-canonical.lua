local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
-- A profile learned through the former PS5/DirectInput path must be ignored.
save={read=function(k) return k=='pad_v2_verified' and true or 'face3' end}
io={open=function()error('Legacy face-only mapping must not be loaded')end}
local C=require('controller');local axes,buttons={},{}
local api={getPlayerGamepad=function()return 0 end,getGamepadAxis=function(k)return axes[k] or 0 end,checkGamepad=function(k)return buttons[k] and 2 or 0 end}
local h={};local function read(a,b)axes=a or {};buttons=b or {};return C.read(api,{},h) end
local n=read();assert(not n.attack and not n.special and not n.jump and n.moveX==0 and n.moveY==0,'Neutral controller must be idle')
local b=read(nil,{face2=true});assert(b.special and not b.attack and not b.jump and not b.up,'Circle/B must be neutral special')
for _,k in ipairs({'shoulderl','shoulderr','shoulderlb','shoulderrb'}) do
 local i=read(nil,{[k]=true});assert(not i.attack and not i.special and not i.jump and not i.up,k..' must not attack or select up special')
end
assert(read(nil,{shoulderlb=true}).defend and read(nil,{shoulderrb=true}).defend,'L2/R2 shield')
for _,a in ipairs({{lh=1},{lh=-1},{lv=1},{lv=-1}}) do local i=read(a,{face2=true});assert(i.special and not i.attack) end
assert(read(nil,{face1=true}).attack,'Cross/A attacks')
assert(read(nil,{face3=true}).jump and read(nil,{face4=true}).jump,'Square/Triangle jump')
print('PASS: corrupt legacy profile ignored; neutral, Circle special, independent shoulders/triggers, directionals and face buttons')
