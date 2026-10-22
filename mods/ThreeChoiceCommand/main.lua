-- Each pending crate owns an independent three-item pool. Recycle a pool only
-- after its crate is gone, so opening other boxes cannot change its choices.
local command = Artifact.find("Command", "vanilla")
local sources = {}
local slots = {}
local serial = 0
local testMode = modloader.checkFlag("three_choice_test")

for _, name in ipairs({"common", "uncommon", "rare", "use"}) do
    local pool = ItemPool.find(name, "vanilla")
    sources[#sources + 1] = {name = name, pool = pool, crate = pool:getCrate()}
end

local function getSlot()
    for _, slot in ipairs(slots) do
        if not slot.instance or not slot.instance:isValid() then
            for _, item in ipairs(slot.items) do slot.pool:remove(item) end
            slot.items = {}
            return slot
        end
    end
    serial = serial + 1
    local pool = ItemPool.new("ChoiceSlot" .. serial)
    local slot = {pool = pool, crate = pool:getCrate(), items = {}}
    slots[#slots + 1] = slot
    return slot
end

local function replaceCrate(original, source)
    -- roll() uses the source pool's normal eligibility / weighting rules.
    -- Rejection sampling keeps choices distinct without modifying that pool.
    local options, seen = {}, {}
    local maximum = math.min(3, #source.pool:toList())
    for attempt = 1, 512 do
        local item = source.pool:roll()
        if item and not seen[item] then
            seen[item] = true
            options[#options + 1] = item
        end
        if #options >= maximum then break end
    end
    if #options == 0 then return end
    local slot = getSlot()
    for _, item in ipairs(options) do
        slot.pool:add(item)
        slot.items[#slot.items + 1] = item
    end
    slot.crate.sprite = source.crate.sprite
    local crate = slot.crate:create(original.x, original.y)
    crate.sprite = original.sprite
    crate:set("tx", original.x + 40)
    crate:set("ty", original.y - 45)
    crate.visible = false
    slot.instance = crate
    slot.tier = source.name
    slot.displayItems = slot.pool:toList()
    original:destroy()
    local names = {}
    for _, item in ipairs(options) do names[#names + 1] = item.displayName end
    log("[ThreeChoice] " .. source.name .. ": " .. table.concat(names, " | "))
end

callback.register("onGameStart", function()
    command.active = true
    log("[ThreeChoice] Command enabled; each reward offers up to three distinct same-tier items.")
end)

callback.register("onStep", function()
    for _, source in ipairs(sources) do
        for _, crate in ipairs(source.crate:findAll()) do
            if crate:isValid() then replaceCrate(crate, source) end
        end
    end
end)

-- Opening overlapping native crates can activate several menus on one key.
-- Keep a single owner so an unseen crate cannot consume the same selection.
local focusedCrate
callback.register("postStep", function()
    if focusedCrate and (not focusedCrate:isValid() or focusedCrate:get("active")~=1) then focusedCrate=nil end
    for _,slot in ipairs(slots) do
        local crate=slot.instance
        if crate and crate:isValid() and crate:get("active")==1 then
            if not focusedCrate then focusedCrate=crate
            elseif crate~=focusedCrate then
                crate:set("active",0)
                crate:set("my_player",-4)
            end
        end
    end
end)

-- Native Command still handles interaction, navigation, and awarding exactly
-- one item. Its grid assumes a full item catalogue, so draw a compact HUD here.
local ink = Color.fromHex(0x171827)
local white = Color.fromHex(0xF0EDE3)
local tiers = {common=Color.fromHex(0xE9E9F4), uncommon=Color.fromHex(0x7EDFA7), rare=Color.fromHex(0xFF7F87), use=Color.fromHex(0xF6C56C)}
local function wrap(text, limit)
    text = text:gsub("&.-&", "")
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        if #line + #word + 1 > limit and #line > 0 then lines[#lines+1]=line;line=word
        else line=line=="" and word or line.." "..word end
    end
    lines[#lines+1]=line
    return table.concat(lines,"\n")
end
callback.register("onDraw", function()
    for _,slot in ipairs(slots) do
        local crate=slot.instance
        if crate and crate:isValid() then
            local color=tiers[slot.tier] or white
            graphics.color(ink);graphics.rectangle(crate.x-8,crate.y-7,crate.x+8,crate.y+7)
            graphics.color(color);graphics.rectangle(crate.x-8,crate.y-7,crate.x+8,crate.y+7,true)
            graphics.print("?",crate.x,crate.y-5,graphics.FONT_DEFAULT,graphics.ALIGN_MIDDLE)
            if crate:get("active")==0 then
                local player=misc.players[1]
                if player and math.abs(player.x-crate.x)<24 and math.abs(player.y-crate.y)<32 then
                    graphics.print("["..input.getControlString("enter",player).."] Choose one",crate.x,crate.y-34,graphics.FONT_DEFAULT,graphics.ALIGN_MIDDLE)
                end
            end
        end
    end
end)
callback.register("onHUDDraw", function()
    for _,slot in ipairs(slots) do
        local crate=slot.instance
        if crate and crate:isValid() and crate:get("active")==1 then
            local w,h=graphics.getHUDResolution()
            local options=slot.displayItems
            local count=#options
            local cw=math.min(145,math.floor((w-40)/count)-8)
            local total=count*(cw+8)-8
            local left=(w-total)/2
            local top=math.floor(h/2)-58
            local selection=math.max(1,math.min(count,crate:get("selection")+1))
            local color=tiers[slot.tier] or white
            graphics.color(ink);graphics.alpha(.72);graphics.rectangle(0,0,w,h);graphics.alpha(1)
            graphics.color(color)
            graphics.print("CHOOSE ONE",w/2,top-44,graphics.FONT_LARGE,graphics.ALIGN_MIDDLE)
            graphics.print(string.upper(slot.tier).." / THREE-CHOICE COMMAND",w/2,top-22,graphics.FONT_SMALL,graphics.ALIGN_MIDDLE)
            for i,item in ipairs(options) do
                local x=left+(i-1)*(cw+8)
                graphics.color(ink);graphics.rectangle(x,top,x+cw,top+125)
                graphics.color(i==selection and color or Color.fromHex(0x555669))
                graphics.rectangle(x,top,x+cw,top+125,true)
                if i==selection then graphics.rectangle(x+2,top+2,x+cw-2,top+123,true) end
                graphics.drawImage{image=item.sprite,x=x+cw/2,y=top+28,xscale=1.25,yscale=1.25}
                graphics.color(white)
                graphics.print(wrap(item.displayName,22),x+cw/2,top+55,graphics.FONT_DEFAULT,graphics.ALIGN_MIDDLE)
                graphics.print(wrap(item.pickupText,28),x+8,top+83,graphics.FONT_SMALL)
            end
            graphics.color(white)
            local p=misc.players[1]
            graphics.print("Stick / A / D: choose    ["..input.getControlString("enter",p).."] Take item",w/2,top+143,graphics.FONT_DEFAULT,graphics.ALIGN_MIDDLE)
            if testMode and slot.lastSelection~=selection then
                log("[ThreeChoice QA] SELECTED "..selection.." "..options[selection].displayName)
                slot.lastSelection=selection
            end
            return
        end
    end
end)

-- QA fixtures are restricted to a separate profile flag, never the play profile.
if testMode then
    local frame = 0
    callback.register("onStageEntry", function() frame = 0 end)
    callback.register("onPlayerStep", function(player)
        if not modloader.checkFlag("falcon_v2_combat_test") then player:set("invincible", 120) end
        player:set("hp", player:get("maxhp"))
        player:set("gold", 9999)
    end)
    callback.register("onStep", function()
        frame = frame + 1
        local p = misc.players[1]
        if frame == 90 and p then
            for i, source in ipairs(sources) do
                source.crate:create(p.x + (i - 1) * 55, p.y)
            end
            log("[ThreeChoice QA] Spawned four rarity fixtures at " .. p.x .. "," .. p.y)
        end
        if input.checkKeyboard("f10") == input.PRESSED and p then
            p:dumpVariables(true, true)
            for _, slot in ipairs(slots) do if slot.instance and slot.instance:isValid() then slot.instance:dumpVariables(true, true) end end
        end
        if input.checkKeyboard("f6") == input.PRESSED and p then
            sources[1].crate:create(p.x, p.y)
        end
        if input.checkKeyboard("f7") == input.PRESSED and p then
            sources[2].crate:create(p.x, p.y)
        end
        if input.checkKeyboard("f8") == input.PRESSED and p then
            sources[3].crate:create(p.x, p.y)
        end
        if input.checkKeyboard("f9") == input.PRESSED and p then
            sources[4].crate:create(p.x, p.y)
        end
    end)
    callback.register("onItemPickup", function(item, player)
        log("[ThreeChoice QA] PICKUP " .. item:getItem().displayName)
    end)
end

log("[ThreeChoice] Loaded 1.0.0; QA=" .. tostring(testMode))
