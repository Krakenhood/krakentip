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

-- Quest titles and objectives from the tooltip's data: { text, isTitle }.
local function questLinesFromData(data)
    local out = {}
    for _, line in ipairs(data.lines or {}) do
        local kind = QUEST_TYPES[clean(line.type)]
        if kind then
            local text = line.leftText
            if text ~= nil then out[#out + 1] = { text, kind == "QuestTitle" } end
        end
    end
    return out
end

-- Clients without tooltip data: read the lines. Objectives start with " - ",
-- and the gold line above them is the quest's title.
local function questLinesFromText(tip)
    local out = {}
    local n = call(tip.NumLines, tip) or 0
    for i = 2, n do
        local _, text = lineText(tip, i)
        if type(text) == "string" and text:find("^%s*%- ") then
            if #out == 0 or out[#out][2] == nil then
                local prev, title = lineText(tip, i - 1)
                local r, g, b = call(prev and prev.GetTextColor, prev)
                if type(title) == "string" and r and r > 0.9 and g and g > 0.7 and b and b < 0.2 and (#out == 0 or out[#out][1] ~= title) then
                    out[#out + 1] = { title, true }
                end
            end
            out[#out + 1] = { text }
        end
    end
    return out
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
    local quests = (data and data.lines and next(QUEST_TYPES)) and questLinesFromData(data) or questLinesFromText(tip)
    local owner = unit ~= "mouseover" and call(tip.GetOwner, tip) or nil
    Card:ShowFor(Card:Gather(unit, { quests = quests, subtitle = subtitle(tip, unit) }), owner)
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
