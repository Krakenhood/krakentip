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

-- The game may name the unit by any token it has ("target" when you hover your
-- target, a nameplate). Under the mouse we always call it "mouseover", so the
-- card notices the moment the mouse leaves it.
local function unitOf(tip)
    local ok, _, unit = pcall(tip.GetUnit, tip)
    unit = ok and clean(unit)
    if call(UnitExists, "mouseover") and (type(unit) ~= "string" or call(UnitIsUnit, unit, "mouseover")) then
        return "mouseover"
    end
    return unit
end

function Hook:Wants(unit)
    local s = KT.db and KT.db.settings
    if not (s and s.enabled and unit) then return false end
    if not call(UnitCanAttack, "player", unit) then return false end
    if call(UnitIsPlayer, unit) and not s.players then return false end
    return true
end

-- Makes the game's tooltip visible again, for whatever it shows next.
function Hook:Reveal()
    self.cleared = nil
    if self.hidden then
        GameTooltip:SetAlpha(1)
        self.hidden = nil
    end
    Card:Release()
end

-- A new owner took the tooltip (another unit, an item, a button): it's the
-- game's again, and nothing we let go of earlier holds anymore.
function Hook:Restore()
    self.gone = nil
    self:Reveal()
end

-- The enemy left the mouse. The game would redraw its tooltip and fade it for
-- seconds; instead it goes now, and stays gone until a new owner takes it.
function Hook:Dismiss()
    self.gone = true
    pcall(GameTooltip.Hide, GameTooltip)
end

-- The tooltip was emptied. Often that's the game redrawing the same enemy
-- (OnUnit follows at once and decides); if nothing follows in this frame, the
-- tooltip shows something else now and it's the game's again.
function Hook:OnCleared()
    if not self.hidden then return end
    if not (C_Timer and C_Timer.After) then return self:Reveal() end
    self.cleared = true
    C_Timer.After(0, function()
        if Hook.cleared then KT.dispatch(Hook.Reveal, Hook) end
    end)
end

function Hook:OnUnit(tip, data)
    if tip ~= GameTooltip then return end
    self.cleared = nil
    if self.gone then return end -- the redraw of the enemy we let go of
    -- the enemy under the mouse is gone and this is the game's redraw: let go
    if Card:Following() and not call(UnitExists, "mouseover") then return Card:LetGo() end
    local unit = unitOf(tip)
    if not self:Wants(unit) then return self:Reveal() end
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
    if hooksecurefunc then
        hooksecurefunc(GameTooltip, "SetOwner", function() KT.dispatch(Hook.Restore, Hook) end)
    end
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function() KT.dispatch(Hook.OnCleared, Hook) end)
    GameTooltip:HookScript("OnHide", function() KT.dispatch(Hook.Reveal, Hook) end)
    -- the game may show its tooltip again after its redraw; it stays gone
    GameTooltip:HookScript("OnShow", function(tip)
        if Hook.gone then pcall(tip.Hide, tip) end
    end)
end

KT:Listen("SETUP", function() Hook:Install() end)
KT:Listen("SETTINGS", function()
    if not KT.db.settings.enabled then Hook:Restore() end
end)
