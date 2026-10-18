local _, KT = ...
local T = KT.Theme
local call, raw, clean = KT.call, KT.raw, KT.clean
local Layouts = KT.Layouts

--------------------------------------------------------------------------------
-- The card that stands in for the game's unit tooltip: what it knows about
-- the unit, which look it wears (Layouts.lua), where it goes, and when it
-- lets go.
--------------------------------------------------------------------------------

local Card = {}
KT.Card = Card

local MOUSE_X, MOUSE_Y = 22, 8 -- how far from the cursor the card sits
local FADE = 0.2

--------------------------------------------------------------------------------
-- What we know about a unit. Values we only show (the name) may be secret;
-- values we compare are cleaned first.
--------------------------------------------------------------------------------

local function npcID(guid)
    guid = clean(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

-- Kills of this creature in your Krakenfriends journey, over all its chapters.
local function killedTogether(unit)
    local KF = Krakenfriends
    local j = type(KF) == "table" and KF.journey
    if type(j) ~= "table" or type(j.pairs) ~= "table" then return nil end
    local id = npcID(call(UnitGUID, unit))
    if not id then return nil end
    local n = 0
    for _, pair in pairs(j.pairs) do
        local m = type(pair) == "table" and type(pair.mobs) == "table" and (pair.mobs[id] or pair.mobs[tostring(id)])
        if type(m) == "table" and type(m.c) == "number" then n = n + m.c end
    end
    if n == 0 then return nil end
    return n, j.partnerName
end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and { c.r, c.g, c.b } or nil
end

local function targetLine(unit)
    local t = unit .. "target"
    if not call(UnitExists, t) then return nil end
    if call(UnitIsUnit, t, "player") then return "You", T.bad end
    local name = call(UnitName, t)
    if not name then return nil end
    if call(UnitIsPlayer, t) then
        local _, class = call(UnitClass, t)
        return name, classColor(class) or T.text
    end
    return name, T.text
end

-- `extra` carries what only the game's tooltip knows: quest lines, an NPC's title.
function Card:Gather(unit, extra)
    extra = extra or {}
    local info = { unit = unit, quests = extra.quests, subtitle = extra.subtitle }
    info.guid = call(UnitGUID, unit)
    info.name = raw(UnitName, unit)
    info.level = call(UnitLevel, unit)
    if call(UnitIsBossMob or function() end, unit) then info.level = -1 end
    info.isPlayer = call(UnitIsPlayer, unit) and true or false
    info.canAttack = call(UnitCanAttack, "player", unit) and true or false
    local reaction = call(UnitReaction, unit, "player")
    if not reaction then
        info.reaction = info.canAttack and "hostile" or "friendly"
    else
        info.reaction = reaction >= 5 and "friendly" or reaction == 4 and "neutral" or "hostile"
    end
    info.tapped = call(UnitIsTapDenied, unit) and true or false
    info.dead = call(UnitIsDeadOrGhost, unit) and true or false
    info.target, info.targetColor = targetLine(unit)
    if info.isPlayer then
        local className, class = call(UnitClass, unit)
        info.className, info.classColor = className, classColor(class)
        info.race = call(UnitRace, unit)
        info.guild = call(GetGuildInfo or function() end, unit)
    else
        info.cls = call(UnitClassification, unit)
        info.ctype = call(UnitCreatureType, unit)
        info.family = call(UnitCreatureFamily, unit)
        info.together, info.partner = killedTogether(unit)
    end
    -- how hard it is only matters for what you can fight
    if info.canAttack then
        local word, color, diff = KT.Difficulty(info.level, call(UnitLevel, "player"), call(GetQuestGreenRange))
        info.difficulty, info.difficultyColor, info.diff = word, color, diff
    end
    return info
end

--------------------------------------------------------------------------------
-- The frames: one per look, built when first needed
--------------------------------------------------------------------------------

Card.frames = {}

function Card:Style()
    local style = KT.db.settings.style
    return Layouts[style] and style or "regular"
end

function Card:FrameFor(style)
    local f = self.frames[style]
    if f then return f end
    f = CreateFrame("Frame", "KrakentipCard_" .. style, UIParent)
    f:SetSize(200, 40)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    f:Hide()
    Layouts.Build(f, style)
    f:SetScript("OnUpdate", function(_, elapsed) Card:OnUpdate(elapsed) end)
    self.frames[style] = f
    return f
end

function Card:Fill(info)
    local style = self:Style()
    local f = self:FrameFor(style)
    if self.frame and self.frame ~= f then self.frame:Hide() end
    self.frame = f
    f:SetScale(KT.db.settings.scale or 1)
    local w, h = Layouts.Fill(f, style, info, KT.db.settings)
    f:SetSize(w, h)
    self.info = info
end

--------------------------------------------------------------------------------
-- Where it goes
--------------------------------------------------------------------------------

-- Where the game puts tooltips when nothing else asks: the Edit Mode tooltip
-- spot where the client has one, the bottom right corner otherwise.
local function defaultSpot(f)
    local box = GameTooltipDefaultContainer
    if box then
        f:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    else
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X or 13) - 82, (CONTAINER_OFFSET_Y or 0) + 110)
    end
end

function Card:FollowMouse()
    local f = self.frame
    local x, y = GetCursorPosition()
    local scale = f:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    x, y = x / scale, y / scale
    f:ClearAllPoints()
    -- right of the cursor, or left of it near the right edge of the screen
    local right = (UIParent:GetWidth() or 0) / (f:GetScale() or 1)
    if x + MOUSE_X + (f:GetWidth() or 0) > right then
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x - MOUSE_X, y + MOUSE_Y)
    else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + MOUSE_X, y + MOUSE_Y)
    end
end

-- The spot the game just anchored its tooltip to (the default anchor, set in
-- Edit Mode), taken over with the same corner, so the card grows the same way.
-- The game's tooltip is hidden right after, so the spot is copied, not shared.
local function tooltipSpot(f)
    local ok, point, rel, relPoint, x, y = pcall(GameTooltip.GetPoint, GameTooltip, 1)
    if not ok then return false end
    point, relPoint, x, y = clean(point), clean(relPoint), clean(x), clean(y)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return false end
    local k = (GameTooltip:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1)
    f:SetPoint(point, rel or UIParent, relPoint or point, x * k, y * k)
    return true
end

-- A soft target (action targeting) isn't under the mouse, so its card goes
-- where the game puts tooltips.
function Card:AtMouse()
    return KT.db.settings.position == "mouse" and not (self.info and KT.Hook.SOFT[self.info.unit])
end

function Card:Place()
    local f = self.frame
    if self:AtMouse() then return self:FollowMouse() end
    f:ClearAllPoints()
    if self.sample or not tooltipSpot(f) then defaultSpot(f) end
end

--------------------------------------------------------------------------------
-- Showing and hiding
--------------------------------------------------------------------------------

-- `owner` is the frame the game's tooltip belonged to (a unit frame, a
-- nameplate): for units that aren't "mouseover", the card goes when the
-- mouse leaves it.
function Card:ShowFor(info, owner)
    self.sample = nil
    info.owner = owner
    self:Fill(info)
    self.fading = nil
    self.frame:SetAlpha(1)
    self:Place()
    self.frame:Show()
    KT:Fire("CARD", info)
end

-- `force` ends a fade that's still running; without it the fade finishes first.
function Card:Release(force)
    if not self.frame or self.sample then return end
    if self.fading and not force then return end
    self.fading = nil
    self.info = nil
    self.frame:Hide()
end

-- The unit left the mouse: the card fades out quickly.
function Card:LetGo()
    if self.fading or self.sample or not (self.frame and self.frame:IsShown()) then return end
    self.fading = FADE
end

function Card:IsSampleShown()
    return self.sample and self.frame and self.frame:IsShown() or false
end

function Card:ToggleSample(on)
    if on == nil then on = not self:IsSampleShown() end
    if not on then
        if self.sample and self.frame then self.frame:Hide() end
        self.sample = nil
        return
    end
    local info = {}
    for k, v in pairs(KT.Sample) do info[k] = v end
    info.targetColor = T.bad
    info.difficulty, info.difficultyColor, info.diff = "Hard", { 1.00, 0.50, 0.25 }, 3
    info.quests = {}
    for i, q in ipairs(KT.Sample.quests) do info.quests[i] = q end
    self:Fill(info)
    self.sample = true
    self.fading = nil
    self.frame:SetAlpha(1)
    self:Place()
    self.frame:Show()
    KT:Fire("SAMPLE")
end

local function stillHovered(info)
    if info.unit == "mouseover" then return call(UnitExists, "mouseover") end
    -- a soft target: as long as you still face that same unit
    if KT.Hook.SOFT[info.unit] then
        if not call(UnitExists, info.unit) then return false end
        local guid = call(UnitGUID, info.unit)
        return not (guid and info.guid) or guid == info.guid
    end
    local owner = info.owner
    if owner and owner ~= UIParent and owner.IsMouseOver then
        local ok, over = pcall(owner.IsMouseOver, owner)
        return ok and clean(over) ~= false
    end
    return call(UnitExists, info.unit)
end

local since = 0
function Card:OnUpdate(elapsed)
    local f = self.frame
    if self:AtMouse() then self:FollowMouse() end
    if self.sample then return end
    local info = self.info
    if not info then return f:Hide() end

    if self.fading then
        self.fading = self.fading - elapsed
        if self.fading <= 0 then return self:Release(true) end
        f:SetAlpha(self.fading / FADE)
        return
    end
    if not stillHovered(info) then return self:LetGo() end

    -- the game's tooltip is hidden and won't redraw, so the card keeps itself
    -- up to date: health, who it's attacking, dead or tagged
    since = since + elapsed
    if since < 0.2 then return end
    since = 0
    local fresh = self:Gather(info.unit, info)
    fresh.owner = info.owner
    self:Fill(fresh)
    KT:Fire("CARD", fresh)
end

KT:Listen("SETTINGS", function()
    if Card.sample then
        Card:ToggleSample(true)
    elseif Card.info and Card.frame and Card.frame:IsShown() and not Card.fading then
        Card:Fill(Card.info)
        Card.frame:Show()
        Card:Place()
    end
end)
