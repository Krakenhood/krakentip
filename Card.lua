local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets
local call, raw, clean = KT.call, KT.raw, KT.clean

--------------------------------------------------------------------------------
-- The enemy card: level badge, name, creature type with a badge for elites
-- and rares, a big health bar, who it's attacking, how hard it is, quest
-- progress and (with Krakenfriends) how often you've killed it together.
--------------------------------------------------------------------------------

local Card = {}
KT.Card = Card

local WIDTH = 236
local PAD = 8
local HEAD = 42     -- the band with the badge and the name
local BAR_H = 16
local ROW_H = 16
local MOUSE_X, MOUSE_Y = 22, 8 -- how far from the cursor the card sits

--------------------------------------------------------------------------------
-- What we know about a unit, read once per tooltip refresh. Values we only
-- show (name, health) may be secret; values we compare are cleaned first.
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

local function targetLine(unit)
    local t = unit .. "target"
    if not call(UnitExists, t) then return nil end
    if call(UnitIsUnit, t, "player") then return "You", T.bad end
    local name = call(UnitName, t)
    if not name then return nil end
    if call(UnitIsPlayer, t) then
        local _, class = call(UnitClass, t)
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return name, { c.r, c.g, c.b } end
    end
    return name, T.text
end

function Card:Gather(unit, questLines)
    local info = { unit = unit }
    info.name = raw(UnitName, unit)
    info.level = call(UnitLevel, unit)
    if call(UnitIsBossMob or function() end, unit) then info.level = -1 end
    info.cls = call(UnitClassification, unit)
    info.ctype = call(UnitCreatureType, unit)
    info.family = call(UnitCreatureFamily, unit)
    local reaction = call(UnitReaction, unit, "player")
    info.reaction = (reaction and reaction >= 4) and "neutral" or "hostile"
    info.tapped = call(UnitIsTapDenied, unit) and true or false
    info.dead = call(UnitIsDeadOrGhost, unit) and true or false
    info.target, info.targetColor = targetLine(unit)
    local word, color, diff = KT.Difficulty(info.level, call(UnitLevel, "player"), call(GetQuestGreenRange))
    info.difficulty, info.difficultyColor, info.diff = word, color, diff
    info.quests = questLines
    info.together, info.partner = killedTogether(unit)
    return info
end

--------------------------------------------------------------------------------
-- The frame
--------------------------------------------------------------------------------

local function Row(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    r.label = Wg.Text(r, 11, T.dim)
    r.label:SetPoint("LEFT")
    r.value = Wg.Text(r, 11, T.text, "RIGHT")
    r.value:SetPoint("RIGHT")
    return r
end

function Card:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "KrakentipCard", UIParent)
    self.frame = f
    f:SetSize(WIDTH, 120)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    f:Hide()

    Wg.DialogFrame(f)
    local band = Wg.Solid(f, "BACKGROUND", T.band, nil, 1)
    band:SetPoint("TOPLEFT", 2, -2)
    band:SetPoint("TOPRIGHT", -2, -2)
    band:SetHeight(HEAD)

    -- the level in a gold ring, a skull for bosses and creatures far above you
    local badge = CreateFrame("Frame", nil, f)
    badge:SetSize(30, 30)
    badge:SetPoint("TOPLEFT", PAD, -7)
    local disc = badge:CreateTexture(nil, "BACKGROUND")
    disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    disc:SetVertexColor(0.15, 0.10, 0.07, 1)
    disc:SetPoint("TOPLEFT", 3, -3)
    disc:SetPoint("BOTTOMRIGHT", -3, 3)
    local ring = badge:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(KT.Files.ring)
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT", -2, 2)
    badge.level = Wg.Text(badge, 12, T.gold, "CENTER", "OUTLINE")
    badge.level:SetPoint("CENTER", 0, 0)
    badge.skull = badge:CreateTexture(nil, "ARTWORK")
    badge.skull:SetTexture(KT.Files.skull)
    badge.skull:SetSize(16, 16)
    badge.skull:SetPoint("CENTER")
    self.badge = badge

    local name = Wg.Title(f, 16)
    name:SetPoint("TOPLEFT", badge, "TOPRIGHT", 7, 0)
    name:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    self.name = name

    local sub = Wg.Text(f, 11, T.dim)
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    self.sub = sub

    -- the badge for elites, rares and bosses: dark letters on gold
    local tag = CreateFrame("Frame", nil, f)
    tag:SetSize(40, 12)
    tag:SetPoint("LEFT", sub, "RIGHT", 5, 0)
    tag.bg = Wg.Solid(tag, "BACKGROUND", T.gold, 0.95)
    tag.bg:SetAllPoints()
    tag.text = Wg.Text(tag, 9, { 0.10, 0.07, 0.03 }, "CENTER")
    tag.text:SetShadowOffset(0, 0)
    tag.text:SetPoint("CENTER", 0, 0)
    self.tag = tag

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", PAD, -(HEAD + 6))
    bar:SetPoint("TOPRIGHT", -PAD, -(HEAD + 6))
    bar:SetHeight(BAR_H)
    bar:SetStatusBarTexture(Wg.FirstFile(KT.Files.bar))
    bar:SetStatusBarColor(Wg.rgb(T.health))
    bar:SetMinMaxValues(0, 1)
    local barBg = Wg.Solid(bar, "BACKGROUND", { 0, 0, 0 }, 0.65)
    barBg:SetAllPoints()
    local edge = Wg.Solid(bar, "BACKGROUND", T.gold, 0.5, -1)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.text = Wg.Text(bar, 11, T.text, "CENTER", "OUTLINE")
    bar.text:SetPoint("CENTER", 0, 0)
    self.bar = bar

    self.rows = {}
    self.sep = Wg.Solid(f, "ARTWORK", T.line)
    self.sep:SetHeight(1)
    self.quests = {}

    f:SetScript("OnUpdate", function(_, elapsed) Card:OnUpdate(elapsed) end)
    self:ApplySettings()
end

function Card:ApplySettings()
    if not self.frame then return end
    self.frame:SetScale(KT.db.settings.scale or 1)
    if self.frame:IsShown() then self:Place() end
end

--------------------------------------------------------------------------------
-- Filling it
--------------------------------------------------------------------------------

local function setHealth(bar, info)
    local unit = info.unit
    local hp, max
    if unit then
        hp, max = raw(UnitHealth, unit), raw(UnitHealthMax, unit)
    else
        hp, max = info.hp, info.hpMax
    end
    -- status bars take secret values, so the bar fills even when the numbers are hidden
    pcall(bar.SetMinMaxValues, bar, 0, max or 1)
    pcall(bar.SetValue, bar, hp or 0)
    bar:SetStatusBarColor(Wg.rgb(info.tapped and T.tapped or T.health))

    if info.dead then
        bar.text:SetText("Dead")
        return
    end
    local h, m = clean(hp), clean(max)
    if h and m and m > 0 then
        local pct = math.floor(100 * h / m + 0.5)
        -- Classic hands out creature health as a percentage only (max 100)
        if m == 100 then
            bar.text:SetText(pct .. "%")
        else
            bar.text:SetText(("%s / %s  %d%%"):format(BreakUpLargeNumbers(h), BreakUpLargeNumbers(m), pct))
        end
        return
    end
    -- secret: let the game write the percentage it won't show us
    if unit and UnitHealthPercent then
        local p = raw(UnitHealthPercent, unit, true, CurveConstants and CurveConstants.ScaleTo100)
        if p ~= nil and pcall(bar.text.SetFormattedText, bar.text, "%.0f%%", p) then return end
    end
    bar.text:SetText("")
end
Card.SetHealth = setHealth

function Card:Fill(info)
    self:Create()
    local s = KT.db.settings
    local lines = s.lines

    -- head
    local badge = self.badge
    if info.level and info.level > 0 then
        badge.level:SetText(info.level)
        badge.level:SetTextColor(Wg.rgb(info.difficultyColor or T.gold))
        badge.level:Show()
        badge.skull:Hide()
    else
        badge.level:Hide()
        badge.skull:Show()
    end
    if not pcall(self.name.SetText, self.name, info.name) then self.name:SetText("") end
    local nameColor = info.tapped and T.tapped or KT.Reaction[info.reaction] or KT.Reaction.hostile
    self.name:SetTextColor(Wg.rgb(nameColor))

    local kind = info.ctype
    if info.family and info.family ~= info.ctype then kind = (kind and kind .. " · " or "") .. info.family end
    self.sub:SetText(kind or "")
    local tag = KT.Classification[info.cls]
    if tag then
        self.tag.text:SetText(tag)
        self.tag:SetWidth((self.tag.text:GetStringWidth() or 30) + 10)
        self.tag:ClearAllPoints()
        if kind then
            self.tag:SetPoint("LEFT", self.sub, "RIGHT", 5, 0)
        else
            self.tag:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -3)
        end
        self.tag:Show()
    else
        self.tag:Hide()
    end

    setHealth(self.bar, info)

    -- rows
    local rows = {}
    if lines.target and info.target then rows[#rows + 1] = { "Targeting", info.target, info.targetColor } end
    if lines.difficulty and info.difficulty then
        local word = info.difficulty
        if info.diff and info.diff ~= 0 then word = ("%s (%+d)"):format(word, info.diff) end
        rows[#rows + 1] = { "Difficulty", word, info.difficultyColor }
    end
    if lines.friends and info.together then
        rows[#rows + 1] = { info.partner and ("Killed with " .. info.partner) or "Killed together", info.together, T.teal }
    end

    local y = HEAD + 6 + BAR_H + 5
    for i, r in ipairs(rows) do
        local row = self.rows[i] or Row(self.frame)
        self.rows[i] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, -y)
        row.label:SetText(r[1])
        row.value:SetText(r[2])
        row.value:SetTextColor(Wg.rgb(r[3] or T.text))
        row:Show()
        y = y + ROW_H
    end
    for i = #rows + 1, #self.rows do self.rows[i]:Hide() end

    -- quest progress, as the game words it
    local quests = lines.quests and info.quests or {}
    if #quests > 0 then
        y = y + 4
        self.sep:ClearAllPoints()
        self.sep:SetPoint("TOPLEFT", PAD, -y)
        self.sep:SetPoint("TOPRIGHT", -PAD, -y)
        self.sep:Show()
        y = y + 5
    else
        self.sep:Hide()
    end
    for i, q in ipairs(quests) do
        local fs = self.quests[i]
        if not fs then
            fs = Wg.Text(self.frame, 11, T.text)
            fs:SetPoint("RIGHT", self.frame, "RIGHT", -PAD, 0)
            self.quests[i] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PAD, -y)
        fs:SetPoint("RIGHT", self.frame, "RIGHT", -PAD, 0)
        if not pcall(fs.SetText, fs, q[1]) then fs:SetText("") end
        fs:SetTextColor(Wg.rgb(q[2] and T.gold or T.text))
        fs:Show()
        y = y + 14
    end
    for i = #quests + 1, #self.quests do self.quests[i]:Hide() end

    self.frame:SetHeight(y + PAD)
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
    if x + MOUSE_X + WIDTH > right then
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x - MOUSE_X, y + MOUSE_Y)
    else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + MOUSE_X, y + MOUSE_Y)
    end
end

function Card:Place()
    local f = self.frame
    if KT.db.settings.position == "mouse" then return self:FollowMouse() end
    f:ClearAllPoints()
    if self.sample then return defaultSpot(f) end
    -- take the corner the game anchored its (now invisible) tooltip by, so the
    -- card grows the same way from the spot set in Edit Mode
    local ok, point = pcall(GameTooltip.GetPoint, GameTooltip, 1)
    point = ok and clean(point)
    if type(point) ~= "string" or point == "CENTER" then point = "BOTTOMRIGHT" end
    f:SetPoint(point, GameTooltip, point, 0, 0)
end

--------------------------------------------------------------------------------
-- Showing and hiding
--------------------------------------------------------------------------------

function Card:ShowFor(info)
    self.sample = nil
    self:Fill(info)
    self.fading = nil
    self.frame:SetAlpha(1)
    self:Place()
    self.frame:Show()
end

function Card:Release()
    if not self.frame or self.sample then return end
    self.info = nil
    self.frame:Hide()
end

function Card:IsSampleShown()
    return self.sample and self.frame and self.frame:IsShown() or false
end

function Card:ToggleSample(on)
    self:Create()
    if on == nil then on = not self:IsSampleShown() end
    if not on then
        self.sample = nil
        self.frame:Hide()
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

local since = 0
function Card:OnUpdate(elapsed)
    local f = self.frame
    if KT.db.settings.position == "mouse" then self:FollowMouse() end
    if self.sample then return end
    -- the game fades its own tooltip in and out; keep it out of sight while the card stands in
    if KT.Hook.hidden and (GameTooltip:GetAlpha() or 0) > 0 then GameTooltip:SetAlpha(0) end
    local info = self.info
    if not info then return f:Hide() end

    -- the creature went away under the mouse: fade like the game's tooltip does
    if self.fading then
        self.fading = self.fading - elapsed
        if self.fading <= 0 then return self:Release() end
        f:SetAlpha(self.fading / 0.2)
        return
    end
    if info.unit == "mouseover" and not call(UnitExists, "mouseover") then
        self.fading = 0.2
        return
    end

    since = since + elapsed
    if since < 0.1 then return end
    since = 0
    info.dead = call(UnitIsDeadOrGhost, info.unit) and true or false
    info.tapped = call(UnitIsTapDenied, info.unit) and true or false
    setHealth(self.bar, info)
end

KT:Listen("SETTINGS", function()
    if not Card.frame then return end
    Card:ApplySettings()
    if Card.sample then Card:ToggleSample(true) elseif Card.info then Card:Fill(Card.info) end
end)
