local _, KT = ...
local call, clean = KT.call, KT.clean
local Card = KT.Card

--------------------------------------------------------------------------------
-- The hook into the game's tooltip. The game builds unit tooltips (creatures
-- and players, friend or foe) on their own path; items, spells, menus and
-- buttons take others. Only unit tooltips are touched: the game's one is
-- hidden before it's ever drawn, and the card shows instead. Everything else
-- keeps the game's tooltip, unchanged.
--------------------------------------------------------------------------------

local Hook = {}
KT.Hook = Hook

local LINE = Enum and Enum.TooltipDataLineType
local QUEST_TYPES = {}
if LINE then
    for _, key in ipairs({ "QuestTitle", "QuestObjective", "QuestPlayer" }) do
        if LINE[key] then QUEST_TYPES[LINE[key]] = key end
    end
end

local function lineText(tip, i)
    local fs = _G[(tip:GetName() or "GameTooltip") .. "TextLeft" .. i]
    return fs, fs and clean(fs:GetText())
end

-- Quest lines, in the order the game shows them: { text, isTitle, isPlayer,
-- owner }. A title (gold), then your objectives; in a group, each member's
-- name (isPlayer), then their objectives (owner = that name).
local function addQuestLine(out, text, kind)
    if kind == "title" then
        out.owner = nil
        out[#out + 1] = { text, true }
    elseif kind == "player" then
        out.owner = clean(text)
        out[#out + 1] = { text, false, true }
    else
        out[#out + 1] = { text, false, false, out.owner }
    end
end

local function questLinesFromData(data)
    local out = {}
    for _, line in ipairs(data.lines or {}) do
        local kind = QUEST_TYPES[clean(line.type)]
        if kind and line.leftText ~= nil then
            addQuestLine(out, line.leftText, kind == "QuestTitle" and "title" or kind == "QuestPlayer" and "player" or nil)
        end
    end
    out.owner = nil
    return out
end

-- the name of someone in your group, as the game writes it above their objectives
local function isGroupMember(text)
    if type(text) ~= "string" or text == "" then return false end
    for i = 1, 4 do
        if call(UnitName, "party" .. i) == text then return true end
    end
    for i = 1, 40 do
        local name = call(UnitName, "raid" .. i)
        if not name then break end
        if name == text then return true end
    end
    return false
end

-- Clients without tooltip data: read the lines. Objectives start with " - ";
-- the gold line above them is the quest's title, and a group member's name
-- above them says whose they are.
local function questLinesFromText(tip)
    local out, used = {}, {}
    local n = call(tip.NumLines, tip) or 0
    for i = 2, n do
        local _, text = lineText(tip, i)
        if type(text) == "string" and text:find("^%s*%- ") then
            local prev, above = lineText(tip, i - 1)
            if not used[i - 1] and type(above) == "string" and not above:find("^%s*%- ") then
                local r, g, b = call(prev and prev.GetTextColor, prev)
                if r and r > 0.9 and g and g > 0.7 and b and b < 0.2 then
                    addQuestLine(out, above, "title")
                    used[i - 1] = true
                elseif isGroupMember(above) then
                    addQuestLine(out, above, "player")
                    used[i - 1] = true
                end
            end
            addQuestLine(out, text)
            used[i] = true
        end
    end
    out.owner = nil
    return out, used
end

-- An NPC's title ("Innkeeper", "<Weapon Merchant>") is the second line, when
-- that line isn't the level line.
local function subtitle(tip, unit)
    if call(UnitIsPlayer, unit) then return nil end
    local _, text = lineText(tip, 2)
    if type(text) ~= "string" or text == "" then return nil end
    local level = call(UnitLevel, unit)
    if text:find(LEVEL or "Level", 1, true) or (level and text:find(tostring(level), 1, true)) then return nil end
    return text
end

-- The game's other lines, the ones the card doesn't build itself: a party
-- member's zone when they're elsewhere, "Skinnable", "AFK" and the like.
-- Left out: the name, the level line, the title, the guild, the faction and
-- PvP lines, the creature's type, and the quest lines (they come separately).
local function otherLines(tip, unit, data, sub, skip)
    local known = {}
    -- any of these may be missing, so not ipairs (it would stop at the first gap)
    local skipList = { sub, (call(UnitCreatureType, unit)), (call(UnitCreatureFamily, unit)),
        FACTION_HORDE, FACTION_ALLIANCE, PVP, (call(UnitName, unit)) }
    for i = 1, 7 do
        if type(skipList[i]) == "string" then known[skipList[i]] = true end
    end
    local _, faction = call(UnitFactionGroup or function() end, unit)
    if type(faction) == "string" then known[faction] = true end
    local guild = call(GetGuildInfo or function() end, unit)
    if guild then known[guild] = true; known["<" .. guild .. ">"] = true end
    local level = call(UnitLevel, unit)
    local out = {}
    local function consider(text)
        text = clean(text)
        if type(text) ~= "string" or text == "" or text == " " or known[text] then return end
        if text:find(LEVEL or "Level", 1, true) or (level and level > 0 and text:find("^" .. level .. "%f[%D]")) then return end
        out[#out + 1] = text
        known[text] = true
    end
    if data and data.lines then
        for i, line in ipairs(data.lines) do
            if i > 1 and not QUEST_TYPES[clean(line.type)] then consider(line.leftText) end
        end
    else
        for i = 2, call(tip.NumLines, tip) or 0 do
            if not (skip and skip[i]) then
                local _, text = lineText(tip, i)
                consider(text)
            end
        end
    end
    return out
end

-- Action targeting gives the game a "soft" target: the unit you face, not the
-- one under the mouse. Its tooltip comes on the same path.
local SOFT = { "softenemy", "softfriend", "softinteract" }
Hook.SOFT = {}
for _, t in ipairs(SOFT) do Hook.SOFT[t] = true end

-- The game may name the unit by any token it has ("target" when you hover your
-- target, a nameplate), or by none at all (a soft target). Under the mouse we
-- always call it "mouseover", so the card notices the moment the mouse leaves
-- it; otherwise we find a token from the tooltip's unit.
local function unitOf(tip, data)
    local ok, _, unit = pcall(tip.GetUnit, tip)
    unit = ok and clean(unit) or nil
    if call(UnitExists, "mouseover") and (type(unit) ~= "string" or call(UnitIsUnit, unit, "mouseover")) then
        return "mouseover"
    end
    local guid = clean(data and data.guid)
    if type(guid) ~= "string" then guid = nil end
    -- a soft target by its own name, so the card can tell when it changes
    for _, tok in ipairs(SOFT) do
        if call(UnitExists, tok) and ((unit and call(UnitIsUnit, tok, unit)) or (guid and call(UnitGUID, tok) == guid)) then return tok end
    end
    if type(unit) == "string" and call(UnitExists, unit) then return unit end
    if guid then
        local tok = call(UnitTokenFromGUID, guid)
        if type(tok) == "string" and call(UnitExists, tok) then return tok end
    end
    -- no name and no unit to match: the soft target is the one it's about
    if not unit and not guid then
        for _, tok in ipairs(SOFT) do
            if call(UnitExists, tok) then return tok end
        end
    end
    return nil
end

function Hook:Wants(unit)
    local s = KT.db and KT.db.settings
    return (s and s.enabled and unit) and true or false
end

-- A new owner took the tooltip (another unit, an item, a button): the game's
-- tooltip shows as the game made it, and the card makes way.
function Hook:Restore()
    self.owning = nil
    Card:Release(true)
end

function Hook:OnUnit(tip, data)
    if tip ~= GameTooltip then return end
    local unit = unitOf(tip, data)
    if self.owning and not call(UnitExists, "mouseover") and Card.info and Card.info.unit == "mouseover" and not self.SOFT[unit] then
        -- the game redraws the tooltip once more when the mouse leaves: stay hidden
        pcall(tip.Hide, tip)
        return Card:LetGo()
    end
    if not self:Wants(unit) then
        self.owning = nil
        return
    end
    local quests, skip
    if data and data.lines and next(QUEST_TYPES) then
        quests = questLinesFromData(data)
    else
        quests, skip = questLinesFromText(tip)
    end
    local sub = subtitle(tip, unit)
    local owner = unit ~= "mouseover" and call(tip.GetOwner, tip) or nil
    local extra = { quests = quests, subtitle = sub, other = otherLines(tip, unit, (data and data.lines and next(QUEST_TYPES)) and data or nil, sub, skip) }
    Card:ShowFor(Card:Gather(unit, extra), owner)
    self.owning = true
    pcall(tip.Hide, tip)
end

function Hook:Install()
    if self.installed then return end
    self.installed = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip, data)
            KT.dispatch(Hook.OnUnit, Hook, tip, data)
        end)
    else
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tip)
            KT.dispatch(Hook.OnUnit, Hook, tip)
        end)
    end
    -- every tooltip starts with a new owner: from then on it's the game's again
    if hooksecurefunc then
        hooksecurefunc(GameTooltip, "SetOwner", function() KT.dispatch(Hook.Restore, Hook) end)
    end
    -- the game may show its unit tooltip right after building it: it stays hidden
    GameTooltip:HookScript("OnShow", function(tip)
        if Hook.owning then pcall(tip.Hide, tip) end
    end)
end

KT:Listen("SETUP", function() Hook:Install() end)
KT:Listen("SETTINGS", function()
    if not KT.db.settings.enabled then
        Hook.owning = nil
        Card:Release(true)
    end
end)
