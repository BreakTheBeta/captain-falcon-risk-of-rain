local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
package.path=root..'/?.lua;'..package.path
local C=require('controller');local K=require('keyboard');local combat=require('combat')
local axes,buttons={},{}
local api={getPlayerGamepad=function()return 0 end,getGamepadAxis=function(k)return axes[k] or 0 end,checkGamepad=function(k)return buttons[k] and 2 or 0 end}
local prev={}
local function step(a,b)
 axes=a or {};buttons=b or {};local pad=C.read(api,{},prev);local i;i,prev=K.read(function()return 0 end,prev,pad);return i
end
step();local i=step({lh=1},{face1=true})
assert(combat.choose(i,{grounded=true,facing=1,vx=0},0)=='fsmash','Fast left-stick flick + A must smash')
step();step({lh=.4});for n=1,8 do step({lh=.4}) end;i=step({lh=.4},{face1=true})
assert(combat.choose(i,{grounded=true,facing=1,vx=.2},0)=='ftilt','Slow stick + A must tilt')
step();i=step({lv=-1,rh=1})
assert(i.x==1 and i.y==0,'C-stick attack direction must ignore the movement stick')
assert(i.moveY==-1,'C-stick must preserve movement stick independently')
print('PASS: flick smash, slow tilt, independent C-stick attack/movement direction')
local physics=require('physics')
local s=physics.new()
for n=1,20 do physics.step(s,{direction=1,analog=true,analogX=n/20,dashPressed=false}) end
assert(s.vx<=physics.constants.walk+.001,'Slow stick ramp stays a walk')
physics.step(s,{direction=-1,analog=true,analogX=-1,dashPressed=true})
assert(s.vx< -physics.constants.dash and s.facing==-1,'Flick turnaround enters dash with correct facing')
local soft=physics.new();soft.grounded=false;soft.jumps=0
local hard=physics.new();hard.grounded=false;hard.jumps=0
physics.step(soft,{direction=1,analog=true,analogX=.3});physics.step(hard,{direction=1,analog=true,analogX=1})
assert(soft.vx<hard.vx,'Aerial acceleration follows stick magnitude')
print('PASS: slow ramp walks, flick turnaround dashes, analog aerial drift')
prev={};step();step({lh=.35});step({lh=.72});i=step({lh=1})
assert(i.dashPressed,'A stick flick crossing the dash threshold over three frames must dash')
prev={};step();step({lh=1});i=step({lh=-1})
assert(i.dashPressed,'Direct full-stick reversal must dash dance without a neutral sample')
print('PASS: multi-frame flick and direct reversal dash detection')
prev={};step();local walkState=physics.new()
for n=1,20 do
 local input=step({lh=n/20})
 physics.step(walkState,{direction=input.moveX,analog=true,analogX=input.analogX,dashPressed=input.dashPressed})
end
assert(not walkState.dashing and walkState.vx<=physics.constants.walk+.001,'Slow real stick ramp must remain walking')
print('PASS: controller-to-physics slow walk remains distinct from dash')
prev={};step();local digital=physics.new()
for n=1,20 do
 local input=step({},{padr=true})
 physics.step(digital,{direction=input.moveX,walk=input.walk,analog=input.analog,analogX=input.analogX,dashPressed=input.dashPressed})
end
assert(digital.vx>.3,'D-pad movement must not be scaled by a neutral analog stick')
print('PASS: digital pad movement is independent of analog stick magnitude')
