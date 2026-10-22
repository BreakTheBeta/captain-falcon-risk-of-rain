-- Merge keyboard and assigned controller before detecting action edges.
-- A held button cannot repeat an attack or retrigger during device handoff.
local K = {}
local bindings={left='a',right='d',up='w',down='s',jump='space',attack='j',special='k',defend='l',taunt='i',help='h',smash='shift',walk='control'}
K.bindings=bindings
function K.read(check,previous,pad)
    local i={};previous=previous or {};pad=pad or {}
    for action,key in pairs(bindings) do
        local down=not pad.calibrating and (check(key)>=2 or pad[action]==true)
        i[action]=down
        i[action..'Pressed']=down and not previous[action]
        i[action..'Released']=not down and previous[action] or false
        previous[action]=down
    end
    i.x=(i.right and 1 or 0)-(i.left and 1 or 0)
    i.y=(i.down and 1 or 0)-(i.up and 1 or 0)
    local keyboardMove=check(bindings.left)>=2 or check(bindings.right)>=2
    if pad.connected and not keyboardMove and not pad.calibrating then
      i.moveX=pad.moveX;i.moveY=pad.moveY;i.analogX=pad.analogX;i.analog=pad.analog;i.dashPressed=pad.dashPressed
      i.dodgeX=pad.dodgeX;i.dodgeY=pad.dodgeY
      i.downPressed=pad.fastFallPressed or false
      i.cstick=pad.cstick;i.attackPressed=i.attackPressed or pad.cstickPressed
      i.chargeHeld=pad.chargeHeld or check(bindings.attack)>=2
    end
    i.calibrating=pad.calibrating
    return i,previous
end
return K
