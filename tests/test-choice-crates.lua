-- Exercise real replacement/draw callbacks with a floor-level native crate.
local callbacks,objects,draws={},{},{}
local native={width=20,height=18,xorigin=10,yorigin=17,frames=1}
local mask={width=18,height=12,xorigin=9,yorigin=11}
local original={x=100,y=100,sprite=native,mask=mask,valid=true,subimage=1,xscale=1,yscale=1}
function original:isValid() return self.valid end
function original:destroy() self.valid=false end
local items={{displayName='One'},{displayName='Two'},{displayName='Three'}}
local source={}
function source:toList() return items end
local roll=0
function source:roll() roll=roll%3+1;return items[roll] end
local nativeObject={sprite=native}
function nativeObject:findAll() return original.valid and {original} or {} end
function source:getCrate() return nativeObject end
ItemPool={find=function() return source end,new=function()
 local pool={items={}}
 function pool:add(i) self.items[#self.items+1]=i end
 function pool:remove(i) end
 function pool:toList() return self.items end
 local object={}
 function object:create(x,y)
  local c={x=x,y=y,sprite=self.sprite,mask=nil,visible=true,subimage=1,xscale=1,yscale=1,vars={active=0,can_activate=0}}
  function c:isValid() return true end
  function c:get(k) return self.vars[k] or 0 end
  function c:set(k,v) self.vars[k]=v end
  objects[#objects+1]=c;return c
 end
 function pool:getCrate() return object end
 return pool
end}
Artifact={find=function() return {} end};modloader={checkFlag=function() return false end}
callback={register=function(name,f) callbacks[name]=callbacks[name] or {};table.insert(callbacks[name],f) end}
Color={fromHex=function(x) return x end};log=function() end
misc={players={{x=100,y=100}}};input={getControlString=function() return 'E' end}
graphics={FONT_DEFAULT=1,ALIGN_MIDDLE=1,color=function() end,alpha=function() end,
 rectangle=function(x1,y1,x2,y2) draws[#draws+1]={kind='box',bottom=y2} end,
 print=function(text) draws[#draws+1]={kind='text',text=text} end,
 drawImage=function(a) draws[#draws+1]={kind='sprite',image=a.image,bottom=a.y+a.image.height-a.image.yorigin-1} end}
dofile('mods/ThreeChoiceCommand/main.lua')
for _,f in ipairs(callbacks.onStep) do f() end
for _,f in ipairs(callbacks.onDraw) do f() end
local failures={};local function check(ok,why) if not ok then failures[#failures+1]=why end end
local c=objects[1];check(c~=nil,'replacement must exist')
local nativeDraw=false
for _,d in ipairs(draws) do
 if d.kind=='sprite' and d.image==native then nativeDraw=true end
 if d.kind=='box' or d.kind=='sprite' then check(d.bottom<=100,'crate artwork extends below the native floor anchor: '..d.bottom) end
 if d.kind=='text' then check(not d.text:find('Choose one',1,true),'custom interaction prompt shown while native can_activate=0') end
end
check(nativeDraw,'native rarity chest artwork must be drawn, rather than a question-mark placeholder')
check(c.mask==mask,'replacement must retain original collision mask')
if #failures>0 then error(table.concat(failures,'\n')) end
draws={};c.vars.can_activate=1;misc.players[1].x=150
for _,f in ipairs(callbacks.onDraw) do f() end
local prompts=0
for _,d in ipairs(draws) do if d.kind=='text' and d.text:find('Choose one',1,true) then prompts=prompts+1 end end
assert(prompts==1,'native eligibility must not be hidden by the old24px prompt radius')
draws={};c.vars.active=1
for _,f in ipairs(callbacks.onDraw) do f() end
for _,d in ipairs(draws) do assert(d.kind~='text' or not d.text:find('Choose one',1,true),'open menu must not show activation prompt') end
print('PASS: native chest art/feet/mask align; hint follows native eligibility and menu state')
