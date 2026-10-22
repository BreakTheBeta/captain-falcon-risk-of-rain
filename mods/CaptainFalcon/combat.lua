-- Frame counts are nominal 60-Hz fighter frames. Recovery replaces the old
-- seconds-long Risk of Rain ability cooldowns. Hitboxes use game pixels.
local C={}
C.moves={
 jab1={duration=17,sprite='jab',hits={{3,1.0,9,13,10}}},
 jab2={duration=19,sprite='jab',hits={{3,1.1,10,14,10}}},
 gentleman={duration=29,sprite='jab',hits={{6,2.4,12,17,12}}},
 ftilt={duration=29,sprite='ftilt',hits={{9,2.0,10,19,12}}},
 utilt={duration=38,sprite='utilt',hits={{17,2.8,4,18,26}}},
 dtilt={duration=31,sprite='dtilt',hits={{10,2.2,11,21,9}}},
 dashattack={duration=34,sprite='dash',hits={{7,2.6,9,17,13}}},
 fsmash={duration=57,sprite='smash',chargeFrame=5,hits={{18,4.0,11,23,17}}},
 usmash={duration=45,sprite='usmash',chargeFrame=6,hits={{22,2.0,3,18,27},{28,2.8,4,20,28}}},
 dsmash={duration=49,sprite='dsmash',chargeFrame=4,hits={{19,3.5,12,23,11},{29,3.5,-12,23,11}}},
 nair={duration=41,sprite='nair',aerial=true,landing=15,hits={{7,1.0,4,22,16},{13,1.8,8,23,17}}},
 knee={duration=39,sprite='knee',aerial=true,landing=19,hits={}},
 bair={duration=35,sprite='bair',aerial=true,landing=18,hits={{10,3.0,-9,21,17}}},
 uair={duration=33,sprite='uair',aerial=true,landing=15,hits={{6,2.6,3,21,26}}},
 dair={duration=44,sprite='dair',aerial=true,landing=24,hits={{16,3.6,0,17,15,0}}},
 punch={duration=80,sprite='punch',special=true,hits={{53,12,14,29,22}}},
 raptor={duration=38,sprite='raptor',special=true,hits={}},
 dive={duration=46,sprite='dive',special=true,hits={{13,2.0,3,19,23},{20,2.4,3,19,23}}},
 kick={duration=48,sprite='kick',special=true,hits={}},
 airdodge={duration=49,sprite='dodge',defensive=true,hits={}},
 roll={duration=31,sprite='roll',defensive=true,hits={}},
 spotdodge={duration=24,sprite='shield',defensive=true,hits={}},
 taunt={duration=60,sprite='taunt',hits={}}
}
function C.choose(i,s,combo)
    if i.specialPressed then
        if i.y<0 then return 'dive' end
        if i.y>0 then return 'kick' end
        if i.x~=0 then return 'raptor' end
        return 'punch'
    end
    if i.attackPressed then
        if not s.grounded then
            if i.y<0 then return 'uair' end
            if i.y>0 then return 'dair' end
            if i.x*s.facing>0 then return 'knee' end
            if i.x*s.facing<0 then return 'bair' end
            return 'nair'
        end
        if i.smash and (i.x~=0 or i.y~=0) then return i.y<0 and 'usmash' or (i.y>0 and 'dsmash' or 'fsmash') end
        if i.y<0 then return 'utilt' end
        if i.y>0 then return 'dtilt' end
        if not i.walk and math.abs(s.vx)>1.7*(2/3) then return 'dashattack' end
        if i.x~=0 then return 'ftilt' end
        return ({'jab1','jab2','gentleman'})[(combo or 0)%3+1]
    end
    if i.tauntPressed then return 'taunt' end
end
return C
