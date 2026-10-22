-- Melee input semantics over the canonical XInput host layout.
local C={};local dz=.23;local mapping={attack='face1',special='face2',jump1='face3',jump2='face4'}
-- Sunshine normalizes PS4 clients to XInput. Use one canonical layout.
-- Face-only remapping cannot fix a DirectInput axis/trigger layout mismatch.
function C.read(api,p,previous)
 previous=previous or {};local h=previous.controller or {};previous.controller=h
 if not api.getPlayerGamepad then return {} end
 local id=api.getPlayerGamepad(p) or api.getPlayerGamepad()
 if id==nil then return {} end
 local function down(key)return api.checkGamepad(key,id)>=2 end
 local function axis(key)return api.getGamepadAxis(key,id) or 0 end
 local x,y=axis('lh'),axis('lv');local rx,ry=axis('rh'),axis('rv')
 local cx,cy=0,0
 if math.max(math.abs(rx),math.abs(ry))>=.55 then
  if math.abs(rx)>=math.abs(ry) then cx=rx>0 and 1 or -1 else cy=ry>0 and 1 or -1 end
 end
 local cstick=cx~=0 or cy~=0
 -- Keep the neutral crossing for a short tap window. Real sticks often
 -- traverse .65 .. .8 over separate samples; a single-frame edge misses it.
 local sign=x>0 and 1 or (x<0 and -1 or 0)
 if math.abs(x)<.3 or sign~=(h.sign or 0) then h.tapX=0 else h.tapX=math.min(99,(h.tapX or 99)+1) end
 local flickX=math.abs(x)>=.8 and (h.tapX or 99)<=3 and (math.abs(h.x or 0)<.8 or sign~=(h.sign or 0))
 local flickY=math.abs(y)>=.8 and math.abs(h.y or 0)<.65
 if flickX then h.flickX=x>0 and 1 or -1;h.windowX=3 else h.windowX=math.max(0,(h.windowX or 0)-1) end
 if flickY then h.flickY=y>0 and 1 or -1;h.windowY=3 else h.windowY=math.max(0,(h.windowY or 0)-1) end
 local mx=(down('padr') or x>dz) and 1 or ((down('padl') or x< -dz) and -1 or 0)
 local my=(down('padd') or y>dz) and 1 or (y< -dz and -1 or 0)
 local ax,ay=mx,my
 if cstick then ax,ay=cx,cy
 elseif math.abs(x)>.35 and math.abs(y)>.35 then
  if math.abs(x)>math.abs(y)*1.3 then ay=0 elseif math.abs(y)>math.abs(x)*1.3 then ax=0 end
 end
 local a=down(mapping.attack);local b=down(mapping.special)
 local smash=cstick or (a and ((h.windowX or 0)>0 and mx==h.flickX or (h.windowY or 0)>0 and my==h.flickY))
 local out={connected=true,attack=a or cstick,special=b,jump=down(mapping.jump1) or down(mapping.jump2),
  defend=down('shoulderlb') or down('shoulderrb'),
  taunt=down('padu'),help=down('select'),smash=smash,cstick=cstick,
  left=ax<0,right=ax>0,up=ay<0,down=ay>0,moveX=mx,moveY=my,analogX=x,analogY=y,analog=not (mx~=0 and math.abs(x)<=dz),dashPressed=flickX,
  walk=math.abs(x)<.8,active=mx~=0 or my~=0 or a or b or cstick,
  dodgeX=math.abs(x)>dz and x or 0,dodgeY=math.abs(y)>dz and y or 0}
 -- Re-arm C-stick at neutral, including direction changes while A stays held.
 out.cstickPressed=cstick and not h.cstick
 out.fastFallPressed=y>.65 and (h.y or 0)<=.65
 out.chargeHeld=a and not cstick
 h.x=x;h.y=y;h.sign=sign;h.cstick=cstick
 out.active=out.active or out.jump or out.defend or out.taunt or out.help
 return out
end
return C
