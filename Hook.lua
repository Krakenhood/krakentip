local _, KT = ...
local call, clean = KT.call, KT.clean
local Card = KT.Card

--------------------------------------------------------------------------------
-- The hook into the game's tooltip. Only unit tooltips are looked at, and of
-- those only enemies get the card: the game's tooltip stays (invisible) and
-- keeps doing its job, so it still comes and goes as it always did, and the
-- card simply shows in its place. The moment the tooltip shows anything else
-- (an item, a spell, a button) it is visible again, unchanged.
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
        local fs = _G[(tip:GetName() or "GameTooltip") .. "TextLeft" .. i]
        local text = fs and clean(fs:GetText())
        if type(text) == "string" and text:find("^%s*%- ") then
            if #out == 0 or out[#out][2] == nil then
                local prev = _G[(tip:GetName() or "GameTooltip") .. "TextLeft" .. (i - 1)]
                local title = prev and clean(prev:GetText())
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

local function unitOf(tip)
    local ok, _, unit = pcall(tip.GetUnit, tip)
    unit = ok and clean(unit)
    if type(unit) ~= "string" and call(UnitExists, "mouseover") then unit = "mouseover" end
    return unit
end

function Hook:Wants(unit)
    local s = KT.db and KT.db.settings
    if not (s and s.enabled and unit) then return false end
    if not call(UnitCanAttack, "player", unit) then return false end
    if call(UnitIsPlayer, unit) and not s.players then return false end
    return true
end

-- Puts the game's tooltip back the way it was.
function Hook:Restore()
    if self.hidden then
        GameTooltip:SetAlpha(1)
        self.hidden = nil
    end
    Card:Release()
end

function Hook:OnUnit(tip, data)
    if tip ~= GameTooltip then return end
    local unit = unitOf(tip)
    if not self:Wants(unit) then return self:Restore() end
    local quests = (data and data.lines and next(QUEST_TYPES)) and questLinesFromData(data) or questLinesFromText(tip)
    Card:ShowFor(Card:Gather(unit, quests))
    GameTooltip:SetAlpha(0)
    self.hidden = true
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
    -- whatever the tooltip shows next (or nothing at all), it's the game's again
    local function restore() KT.dispatch(Hook.Restore, Hook) end
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", restore)
    GameTooltip:HookScript("OnHide", restore)
end

KT:Listen("SETUP", function() Hook:Install() end)
KT:Listen("SETTINGS", function()
    if not KT.db.settings.enabled then Hook:Restore() end
end)
