local root=os.getenv('FALCON_MOD_ROOT') or 'mods/CaptainFalcon'
local M=dofile(root..'/physics.lua')
local s=M.new()
for i=1,30 do M.step(s,{direction=1}) end
assert(math.abs(s.vx-M.constants.run)<.001,'run speed')
M.step(s,{direction=-1});assert(s.vx<0,'dash dance turnaround')
s=M.new();M.step(s,{jumpPressed=true,jumpHeld=true})
for i=1,4 do M.step(s,{jumpHeld=true}) end
assert(s.vy< -2.5*M.constants.scale and s.jumps==1,'full jump after 4-frame squat')
local full=s.vy
s=M.new();M.step(s,{jumpPressed=true,jumpHeld=true});for i=1,4 do M.step(s,{jumpHeld=false}) end
assert(s.vy>full and s.vy<0,'short hop')
local e=M.step(s,{jumpPressed=true,jumpHeld=true});assert(e.doubleJump and s.jumps==0,'double jump')
e=M.step(s,{jumpPressed=true,jumpHeld=true});assert(not e.doubleJump,'no infinite jumps')
s.vy=.1;M.step(s,{downPressed=true});assert(s.vy==M.constants.fastFall,'fast fall')
M.land(s);assert(s.jumps==2 and s.vy==0 and not s.fast,'landing resets jump and fall')
s=M.new();s.grounded=false;s.vx=M.constants.run;M.step(s,{direction=1});assert(s.vx==M.constants.run,'retain aerial dash momentum')
print('PASS: run, dash dance, jumpsquat, full/short hop, double jump limit, fast fall, landing reset, aerial momentum')

s=M.new();M.step(s,{jumpPressed=true,jumpHeld=true,extraJumps=1})
for i=1,4 do M.step(s,{jumpHeld=true,extraJumps=1}) end
assert(s.jumps==2,'Hopoo Feather adds one aerial jump beyond double jump')
print('PASS: Hopoo Feather extra aerial jump')

s=M.new();for n=1,30 do M.step(s,{direction=1,walk=true}) end
assert(math.abs(s.vx-M.constants.walk)<.001,'Ctrl walk reaches Melee walk speed rather than dash')
assert(math.abs(M.constants.scale-2/3)<.001 and math.abs(M.constants.gravity-.13*M.constants.scale)<.001 and math.abs(M.constants.run-2.3*M.constants.scale)<.001,'native-sized Melee movement constants')
print('PASS: walking and native-size Melee movement scale')
