local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets
local raw, clean = KT.raw, KT.clean

--------------------------------------------------------------------------------
-- What the looks (Slate.lua) are made of. Each look builds its parts on a
-- frame once (Create) and places and fills them for a unit (Fill), returning
-- the size it needs. Where things go is worked out at fill time, so every
-- look can be made wider, narrower, taller or lower (settings.dims) and the
-- bar can change its texture and colour (settings.bar).
--
-- Every part is placed from the card's top left corner (at()), and listed in
-- f.parts: that's all the screenshot tool needs to draw a card as it is.
--------------------------------------------------------------------------------

local Layouts = {}
KT.Layouts = Layouts

local floor, max, min = math.floor, math.max, math.min

-- a font string's width, or a guess when the game won't say (secret text)
local function width(fs, guess)
    local w = clean(fs:GetStringWidth())
    return type(w) == "number" and w or guess
end

local function setText(fs, text)
    if not pcall(fs.SetText, fs, text) then fs:SetText("") end
end

local function hex(c)
    return ("%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end
local function paint(text, c) return "|cff" .. hex(c) .. text .. "|r" end

-- this look's width and height factors (1 = as designed)
local function dims(s, key)
    local d = s.dims and s.dims[key]
    return (d and d.w) or 1, (d and d.h) or 1
end

-- a vertical size times the height factor, never under `least`
local function V(n, hk, least) return max(least or 0, floor(n * hk + 0.5)) end

--------------------------------------------------------------------------------
-- Parts
--------------------------------------------------------------------------------

local function part(f, region, kind)
    region._kind = kind
    f.parts[#f.parts + 1] = region
    return region
end

-- `point` is the part's corner that sits at (x, y) from the card's top left:
-- TOPLEFT for text that reads from there, TOPRIGHT for text that ends there,
-- TOP for text centred on x.
local function at(f, region, point, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, f, "TOPLEFT", x, -y)
    region._at = { point, x, y }
end

local function text(f, size, color, opts)
    opts = opts or {}
    local parent = opts.top and f.top or f
    local fs = opts.title and Wg.Title(parent, size) or Wg.Text(parent, size, color or T.text, "LEFT", opts.outline)
    if color then fs:SetTextColor(Wg.rgb(color)) end
    fs._size, fs._title, fs._outline = size, opts.title, opts.outline
    return part(f, fs, "text")
end

local function solid(f, color, alpha)
    local t = Wg.Solid(f, "BACKGROUND", color, alpha, 1)
    t._rgba = { color[1], color[2], color[3], alpha or color[4] or 1 }
    return part(f, t, "solid")
end

-- the health bar: a dark track with a thin edge, the fill, a shine over it
local TRACK, BAR_EDGE = { 0.02, 0.024, 0.047 }, { 0.17, 0.19, 0.26 }
local function bar(f)
    local b = CreateFrame("StatusBar", nil, f)
    b:SetMinMaxValues(0, 1)
    local bg = Wg.Solid(b, "BACKGROUND", TRACK, 1)
    bg:SetAllPoints()
    local edge = Wg.Solid(b, "BACKGROUND", BAR_EDGE, 1, -1)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    b.gloss = b:CreateTexture(nil, "OVERLAY")
    b.gloss:SetTexture(KT.Media("gloss"))
    b.gloss:Hide()
    part(f, b, "bar")
    b.edge, b._edge = edge, BAR_EDGE
    b.text = text(f, 11, T.text, { outline = "OUTLINE", top = true })
    return b
end

local function placeBar(f, b, x, y, w, h)
    at(f, b, "TOPLEFT", x, y)
    b:SetSize(w, h)
    b._size = { w, h }
end

-- the text on the bar, centred, as big as the bar allows (none on a thin bar)
local function barText(f, b, x, y, w, h, lines)
    if h < 8 or (lines and not lines.health) then return b.text:Hide() end
    local size = min(11, max(8, h - 3))
    Wg.SetFont(b.text, size, "OUTLINE")
    b.text._size = size
    at(f, b.text, "TOP", x + w / 2, y + floor((h - size) / 2))
    b.text:Show()
end

local function skull(f, size)
    local s = f:CreateTexture(nil, "ARTWORK")
    s:SetTexture(KT.Files.skull)
    s:SetSize(size, size)
    s._size = size
    return part(f, s, "skull")
end

-- The level in its difficulty colour, or the skull. True when it's the skull.
local function setLevel(f, info)
    if info.level and info.level > 0 then
        f.level:SetText(info.level)
        f.level:SetTextColor(Wg.rgb(info.difficultyColor or T.gold))
        f.level:Show()
        f.skull:Hide()
        return false
    end
    f.level:Hide()
    f.skull:Show()
    return true
end

-- what an NPC does, as a small boxed label with its icon ("Hearthstone")
local CHIP_EDGE, CHIP_GROUND = { 0.19, 0.21, 0.29 }, { 0.04, 0.045, 0.09 }
local function chip(f)
    local c = CreateFrame("Frame", nil, f)
    c:SetSize(30, 16)
    c.edge = Wg.Solid(c, "BACKGROUND", CHIP_EDGE, 1, 0)
    c.edge:SetAllPoints()
    c.ground = Wg.Solid(c, "BACKGROUND", CHIP_GROUND, 1, 1)
    c.ground:SetPoint("TOPLEFT", 1, -1)
    c.ground:SetPoint("BOTTOMRIGHT", -1, 1)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(12, 12)
    c.icon:SetPoint("LEFT", 5, 0)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.text = Wg.Text(c, 11, { 0.85, 0.84, 0.80 })
    c.text:SetPoint("LEFT", c.icon, "RIGHT", 4, 0)
    function c:Set(file, value, color)
        if value == nil then return self:Hide() end
        self.icon:SetTexture(file)
        self._icon = file
        setText(self.text, value)
        if color then self.text:SetTextColor(Wg.rgb(color)) end
        self:SetWidth(5 + 12 + 4 + width(self.text, 40) + 6)
        self:Show()
    end
    return part(f, c, "chip")
end

-- A pool of parts made on demand: pool:Get(i), pool:HideFrom(i).
local function pool(make)
    local p = {}
    function p:Get(i)
        local it = self[i] or make()
        self[i] = it
        it:Show()
        return it
    end
    function p:HideFrom(i)
        for n = i, #self do self[n]:Hide() end
    end
    return p
end

--------------------------------------------------------------------------------
-- What the looks say
--------------------------------------------------------------------------------

function Layouts.NameColor(info)
    if info.tapped then return T.tapped end
    if info.classColor then return info.classColor end
    return KT.Reaction[info.reaction] or KT.Reaction.hostile
end

-- Quest lines as the game words them ({ text, isTitle, isPlayer, owner }):
-- yours when `quests` is on, your group's when `group` is; a quest's title
-- only when something under it shows.
function Layouts.QuestLines(info, lines)
    local out, title = {}, nil
    for _, q in ipairs(info.quests or {}) do
        if q[2] then
            title = q
        elseif (q[3] or q[4]) and lines.group or not (q[3] or q[4]) and lines.quests then
            if title then out[#out + 1] = title; title = nil end
            out[#out + 1] = q
        end
    end
    return out
end

-- the game's other lines (a party member's zone, "Skinnable"), when wanted
local function otherLines(info, lines)
    return lines.other and info.other or {}
end

--------------------------------------------------------------------------------
-- Health on the bar: the numbers and the percentage, or (short) just the
-- percentage. Status bars take secret values, so the bar fills even when the
-- game hides the numbers from us.
--------------------------------------------------------------------------------

KT.BarTextures = {
    { key = "slate", label = "Slate", files = { "Interface\\Buttons\\WHITE8X8" }, gloss = true },
    { key = "smooth", label = "Smooth", files = { "Interface\\TargetingFrame\\UI-StatusBar" } },
    { key = "flat", label = "Flat", files = { "Interface\\Buttons\\WHITE8X8" } },
    { key = "raid", label = "Raid", files = { "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", "Interface\\TargetingFrame\\UI-StatusBar" } },
    { key = "skill", label = "Skill bar", files = { "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar", "Interface\\TargetingFrame\\UI-StatusBar" } },
}
KT.BarColors = {
    { key = "health", label = "By health" },        -- green, to yellow, to red as it drops
    { key = "reaction", label = "Foe or friend" },  -- red for what you can attack, green for the rest
    { key = "gold", label = "Gold" },
}
local TEXTURE = {}
for _, t in ipairs(KT.BarTextures) do TEXTURE[t.key] = t end

-- green at full, yellow at half, red when low (p from 0 to 1)
local GREEN, YELLOW, RED = { 0.25, 0.78, 0.25 }, { 1, 0.84, 0 }, { 0.90, 0.16, 0.12 }
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function healthColor(p)
    p = max(0, min(1, p))
    if p >= 0.5 then return mix(YELLOW, GREEN, (p - 0.5) * 2) end
    return mix(RED, YELLOW, p * 2)
end
Layouts.HealthColor = healthColor

function Layouts.SetHealth(b, info, s, short)
    local unit = info.unit
    local hp, hpMax
    if unit then
        hp, hpMax = raw(UnitHealth, unit), raw(UnitHealthMax, unit)
    else
        hp, hpMax = info.hp, info.hpMax
    end
    pcall(b.SetMinMaxValues, b, 0, hpMax or 1)
    pcall(b.SetValue, b, hp or 0)

    local look = s.bar or {}
    local tex = TEXTURE[look.texture] or TEXTURE.slate
    b:SetStatusBarTexture(Wg.FirstFile(tex.files))
    b._texture = tex.key
    -- the Slate bar: flat, with a shine over the fill that follows it
    if b.gloss then
        local fill = b:GetStatusBarTexture()
        if fill and not b.gloss._on then
            b.gloss:SetAllPoints(fill)
            b.gloss._on = true
        end
        b.gloss:SetShown(tex.gloss and true or false)
    end
    local h, m = clean(hp), clean(hpMax)
    local color = info.canAttack and T.health or T.friendly
    if look.color == "gold" then
        color = T.gold
    elseif look.color == "health" and h and m and m > 0 then
        color = healthColor(h / m)
    end
    if info.tapped then color = T.tapped end
    b:SetStatusBarColor(Wg.rgb(color))
    b._color = color

    local t = b.text
    if info.dead then return t:SetText("Dead") end
    if h and m and m > 0 then
        local pct = floor(100 * h / m + 0.5)
        -- Classic hands out creature health as a percentage only (max 100)
        if short or m == 100 then
            t:SetText(pct .. "%")
        else
            t:SetText(("%s / %s  %d%%"):format(BreakUpLargeNumbers(h), BreakUpLargeNumbers(m), pct))
        end
        return
    end
    -- secret: let the game write the percentage it won't show us
    -- (a copy of a card, as in Compare, keeps the percentage it was given)
    local p = info.hpPct
    if unit and UnitHealthPercent then p = raw(UnitHealthPercent, unit, true, CurveConstants and CurveConstants.ScaleTo100) end
    if p ~= nil and pcall(t.SetFormattedText, t, "%.0f%%", p) then return end
    t:SetText("")
end

--------------------------------------------------------------------------------
-- Making a look's frame
--------------------------------------------------------------------------------

function Layouts.Build(f, key)
    f.parts = {}
    f.look = Layouts[key].frame
    f.backdrop = Wg.TipFrame(f)
    -- texts that sit on the bar go on a layer above it
    f.top = CreateFrame("Frame", nil, f)
    f.top:SetAllPoints()
    f.top:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
    Layouts[key].Create(f)
end

function Layouts.Fill(f, key, info, s)
    local L = Layouts[key]
    local wk, hk = dims(s, key)
    -- the look reads its own fields as s.lines; everything else as it is
    local view = setmetatable({ lines = KT:Fields(key) }, { __index = s })
    return L.Fill(f, info, view, wk, hk)
end


-- the parts, for the looks in Slate.lua
Layouts.kit = {
    width = width, setText = setText, paint = paint, V = V, part = part, at = at, text = text, solid = solid,
    bar = bar, placeBar = placeBar, barText = barText, skull = skull, setLevel = setLevel, chip = chip,
    pool = pool, otherLines = otherLines,
}
