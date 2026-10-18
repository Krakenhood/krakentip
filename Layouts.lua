local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets
local raw, clean = KT.raw, KT.clean

--------------------------------------------------------------------------------
-- The looks of the card. Each builds its parts on a frame once (Create) and
-- places and fills them for a unit (Fill), returning the size it needs. Where
-- things go is worked out at fill time, so every look can be made wider,
-- narrower, taller or lower (settings.dims) and the bar can change its
-- texture and colour (settings.bar).
--
-- Every part is placed from the card's top left corner (at()), and listed in
-- f.parts: that's all the screenshot tool needs to draw a card as it is.
--------------------------------------------------------------------------------

local Layouts = {}
KT.Layouts = Layouts

local DARK = { 0.10, 0.07, 0.03 } -- letters on the gold badge
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

local function bar(f)
    local b = CreateFrame("StatusBar", nil, f)
    b:SetMinMaxValues(0, 1)
    local bg = Wg.Solid(b, "BACKGROUND", { 0, 0, 0 }, 0.65)
    bg:SetAllPoints()
    local edge = Wg.Solid(b, "BACKGROUND", T.gold, 0.5, -1)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    part(f, b, "bar")
    b.text = text(f, 11, T.text, { outline = "OUTLINE", top = true })
    return b
end

local function placeBar(f, b, x, y, w, h)
    at(f, b, "TOPLEFT", x, y)
    b:SetSize(w, h)
    b._size = { w, h }
end

-- the text on the bar, centred, as big as the bar allows (none on a thin bar)
local function barText(f, b, x, y, w, h)
    if h < 8 then return b.text:Hide() end
    local size = min(11, max(8, h - 3))
    b.text:SetFont(Wg.FONT, size, "OUTLINE")
    b.text._size = size
    at(f, b.text, "TOP", x + w / 2, y + floor((h - size) / 2))
    b.text:Show()
end

-- the badge for elites, rares and bosses: dark letters on gold
local function tag(f, size)
    local t = CreateFrame("Frame", nil, f)
    t:SetSize(40, size + 3)
    t.bg = Wg.Solid(t, "BACKGROUND", T.gold, 0.95)
    t.bg:SetAllPoints()
    t.text = Wg.Text(t, size, DARK, "CENTER")
    t.text:SetShadowOffset(0, 0)
    t.text:SetPoint("CENTER", 0, 0)
    t._size = size
    function t:Set(label)
        if not label then return self:Hide() end
        self.text:SetText(label)
        self:SetWidth(width(self.text, 30) + 8)
        self:Show()
    end
    return part(f, t, "tag")
end

local function skull(f, size)
    local s = f:CreateTexture(nil, "ARTWORK")
    s:SetTexture(KT.Files.skull)
    s:SetSize(size, size)
    s._size = size
    return part(f, s, "skull")
end

-- the level in a gold ring (or the skull); sets f.level and f.skull
local function ring(f, size)
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(size, size)
    local disc = r:CreateTexture(nil, "BACKGROUND")
    disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    disc:SetVertexColor(0.15, 0.10, 0.07, 1)
    disc:SetPoint("TOPLEFT", 3, -3)
    disc:SetPoint("BOTTOMRIGHT", -3, 3)
    local edge = r:CreateTexture(nil, "OVERLAY")
    edge:SetTexture(KT.Files.ring)
    edge:SetSize(size * 1.8, size * 1.8)
    edge:SetPoint("TOPLEFT", -size / 15, size / 15)
    f.level = Wg.Text(r, size >= 26 and 12 or 10, T.gold, "CENTER", "OUTLINE")
    f.level:SetPoint("CENTER", 0, 0)
    f.skull = r:CreateTexture(nil, "ARTWORK")
    f.skull:SetTexture(KT.Files.skull)
    f.skull:SetSize(size * 0.55, size * 0.55)
    f.skull:SetPoint("CENTER")
    r._size = size
    r.level, r.skull = f.level, f.skull
    return part(f, r, "ring")
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

-- a small icon with a value next to it, for the Icons look
local function chip(f)
    local c = CreateFrame("Frame", nil, f)
    c:SetSize(30, 14)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(13, 13)
    c.icon:SetPoint("LEFT")
    c.text = Wg.Text(c, 10, T.text)
    c.text:SetPoint("LEFT", c.icon, "RIGHT", 2, 0)
    function c:Set(file, value, color)
        if value == nil then return self:Hide() end
        self.icon:SetTexture(file)
        self._icon = file
        setText(self.text, value)
        self.text:SetTextColor(Wg.rgb(color or T.text))
        self:SetWidth(15 + width(self.text, 24))
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

-- "Beast · Wolf", "Innkeeper · Humanoid", "Night Elf · Mage"
function Layouts.Kind(info)
    local parts = {}
    local function add(s) if type(s) == "string" and s ~= "" then parts[#parts + 1] = s end end
    if info.isPlayer then
        add(info.race); add(info.className)
    else
        add(info.subtitle); add(info.ctype)
        if info.family ~= info.ctype then add(info.family) end
    end
    return table.concat(parts, " · ")
end

-- "Elite", "Rare elite", "Boss"
local function rank(info)
    local cls = KT.Classification[info.cls]
    return cls and (cls:sub(1, 1) .. cls:sub(2):lower()) or nil
end

-- The lines of the Regular card, as { label, value, colour }.
function Layouts.Rows(info, lines)
    local rows = {}
    if lines.target and info.target then rows[#rows + 1] = { "Targeting", info.target, info.targetColor } end
    if lines.difficulty and info.difficulty then
        local word = info.difficulty
        if info.diff and info.diff ~= 0 then word = ("%s (%+d)"):format(word, info.diff) end
        rows[#rows + 1] = { "Difficulty", word, info.difficultyColor }
    end
    if info.guild then rows[#rows + 1] = { "Guild", "<" .. info.guild .. ">", T.text } end
    if lines.friends and info.together then
        rows[#rows + 1] = { info.partner and ("Killed with " .. info.partner) or "Killed together", info.together, T.teal }
    end
    return rows
end

-- "3/8" from the first quest objective that counts something
function Layouts.QuestCount(info, lines)
    if not lines.quests then return nil end
    for _, q in ipairs(info.quests or {}) do
        local t = clean(q[1])
        local n = type(t) == "string" and not q[2] and t:match("(%d+%s*/%s*%d+)")
        if n then return (n:gsub("%s", "")) end
    end
end

-- the quest objectives (titles left out), for the looks with little room
local function objectives(info, lines)
    local out = {}
    if not lines.quests then return out end
    for _, q in ipairs(info.quests or {}) do
        if not q[2] then out[#out + 1] = q[1] end
    end
    return out
end

local function difficultyText(info, lines)
    if not (lines.difficulty and info.difficulty) then return nil end
    if info.diff and info.diff ~= 0 then return ("%s (%+d)"):format(info.difficulty, info.diff) end
    return info.difficulty
end

local function targetText(info, lines)
    if lines.target and info.target then return "» " .. tostring(info.target) end
end

--------------------------------------------------------------------------------
-- Health on the bar: the numbers and the percentage, or (short) just the
-- percentage. Status bars take secret values, so the bar fills even when the
-- game hides the numbers from us.
--------------------------------------------------------------------------------

KT.BarTextures = {
    { key = "smooth", label = "Smooth", files = { "Interface\\TargetingFrame\\UI-StatusBar" } },
    { key = "flat", label = "Flat", files = { "Interface\\Buttons\\WHITE8X8" } },
    { key = "raid", label = "Raid", files = { "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", "Interface\\TargetingFrame\\UI-StatusBar" } },
    { key = "skill", label = "Skill bar", files = { "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar", "Interface\\TargetingFrame\\UI-StatusBar" } },
}
KT.BarColors = {
    { key = "reaction", label = "Foe or friend" },  -- red for what you can attack, green for the rest
    { key = "health", label = "By health" },        -- green, to yellow, to red as it drops
    { key = "gold", label = "Gold" },
}
local TEXTURE = {}
for _, t in ipairs(KT.BarTextures) do TEXTURE[t.key] = t end

local function healthColor(p)
    -- green at full, yellow at half, red when low
    if p > 0.5 then return { 2 * (1 - p) * 0.9 + 0.1, 0.75, 0.15 } end
    return { 0.9, 1.5 * p, 0.12 }
end

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
    local tex = TEXTURE[look.texture] or TEXTURE.smooth
    b:SetStatusBarTexture(Wg.FirstFile(tex.files))
    b._texture = tex.key
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
    if unit and UnitHealthPercent then
        local p = raw(UnitHealthPercent, unit, true, CurveConstants and CurveConstants.ScaleTo100)
        if p ~= nil and pcall(t.SetFormattedText, t, "%.0f%%", p) then return end
    end
    t:SetText("")
end

--------------------------------------------------------------------------------
-- Making a look's frame
--------------------------------------------------------------------------------

function Layouts.Build(f, key)
    f.parts = {}
    f.look = Layouts[key].frame
    if f.look == "dialog" then Wg.DialogFrame(f) else Wg.ThinFrame(f, 0) end
    -- texts that sit on the bar go on a layer above it
    f.top = CreateFrame("Frame", nil, f)
    f.top:SetAllPoints()
    f.top:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
    Layouts[key].Create(f)
end

function Layouts.Fill(f, key, info, s)
    local L = Layouts[key]
    local wk, hk = dims(s, key)
    return L.Fill(f, info, s, wk, hk)
end

--------------------------------------------------------------------------------
-- Regular: the full card in the gold dialog frame
--------------------------------------------------------------------------------

local R = { frame = "dialog", WIDTH = 236 }
Layouts.regular = R

function R.Create(f)
    f.band = solid(f, T.band)
    f.ring = ring(f, 30)
    f.name = text(f, 16, nil, { title = true })
    f.sub = text(f, 11, T.dim)
    f.tag = tag(f, 9)
    f.bar = bar(f)
    f.rows = pool(function() return { label = text(f, 11, T.dim), value = text(f, 11),
        Show = function(r) r.label:Show(); r.value:Show() end, Hide = function(r) r.label:Hide(); r.value:Hide() end,
        IsShown = function(r) return r.label:IsShown() end } end)
    f.sep = solid(f, T.line)
    f.quests = pool(function() return text(f, 11) end)
end

function R.Fill(f, info, s, wk, hk)
    local PAD = 8
    local W = max(170, min(420, floor(R.WIDTH * wk + 0.5)))
    at(f, f.band, "TOPLEFT", 2, 2)
    f.band:SetSize(W - 4, 42)
    at(f, f.ring, "TOPLEFT", PAD, 7)
    setLevel(f, info)
    at(f, f.name, "TOPLEFT", 45, 7)
    f.name:SetWidth(W - 45 - PAD)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    at(f, f.sub, "TOPLEFT", 45, 27)
    local kind = Layouts.Kind(info)
    f.sub:SetText(kind)
    f.tag:Set(KT.Classification[info.cls])
    at(f, f.tag, "TOPLEFT", kind ~= "" and 45 + width(f.sub, 60) + 5 or 45, 27)

    local y, bh = 48, V(16, hk, 6)
    placeBar(f, f.bar, PAD, y, W - PAD * 2, bh)
    barText(f, f.bar, PAD, y, W - PAD * 2, bh)
    Layouts.SetHealth(f.bar, info, s)
    y = y + bh + V(5, hk, 3)

    local rowH = V(16, hk, 13)
    local rows = Layouts.Rows(info, s.lines)
    for i, r in ipairs(rows) do
        local row = f.rows:Get(i)
        at(f, row.label, "TOPLEFT", PAD, y + 1)
        row.label:SetText(r[1])
        at(f, row.value, "TOPRIGHT", W - PAD, y + 1)
        setText(row.value, r[2])
        row.value:SetTextColor(Wg.rgb(r[3] or T.text))
        y = y + rowH
    end
    f.rows:HideFrom(#rows + 1)

    -- quest progress, as the game words it
    local quests = s.lines.quests and info.quests or {}
    if #quests > 0 then
        y = y + V(4, hk, 2)
        at(f, f.sep, "TOPLEFT", PAD, y)
        f.sep:SetSize(W - PAD * 2, 1)
        f.sep:Show()
        y = y + V(5, hk, 3)
    else
        f.sep:Hide()
    end
    for i, q in ipairs(quests) do
        local fs = f.quests:Get(i)
        at(f, fs, "TOPLEFT", PAD, y)
        fs:SetWidth(W - PAD * 2)
        setText(fs, q[1])
        fs:SetTextColor(Wg.rgb(q[2] and T.gold or T.text))
        y = y + V(14, hk, 12)
    end
    f.quests:HideFrom(#quests + 1)
    return W, y + PAD
end

--------------------------------------------------------------------------------
-- Mid: two lines of text and a thin bar, in a thin gold frame
--------------------------------------------------------------------------------

local M = { frame = "thin", WIDTH = 214 }
Layouts.mid = M

function M.Create(f)
    f.level = text(f, 12, T.gold, { outline = "OUTLINE" })
    f.skull = skull(f, 13)
    f.tag = tag(f, 8)
    f.name = text(f, 14, nil, { title = true })
    f.sub = text(f, 10, T.dim)
    f.target = text(f, 10)
    f.bar = bar(f)
    f.quests = pool(function() return text(f, 10) end)
end

function M.Fill(f, info, s, wk, hk)
    local PAD = 7
    local W = max(150, min(400, floor(M.WIDTH * wk + 0.5)))
    local isSkull = setLevel(f, info)
    at(f, f.level, "TOPLEFT", PAD, 7)
    at(f, f.skull, "TOPLEFT", PAD, 6)
    f.tag:Set(KT.Classification[info.cls])
    at(f, f.tag, "TOPRIGHT", W - PAD, 7)
    local nameX = isSkull and PAD + 17 or PAD + width(f.level, 14) + 5
    at(f, f.name, "TOPLEFT", nameX, 5)
    f.name:SetWidth(W - nameX - PAD - (f.tag:IsShown() and f.tag:GetWidth() + 4 or 0))
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))

    local y = 5 + V(20, hk, 17)
    local kind = Layouts.Kind(info)
    if info.guild then kind = (kind ~= "" and kind .. " · " or "") .. "<" .. info.guild .. ">" end
    at(f, f.sub, "TOPLEFT", PAD, y)
    f.sub:SetText(kind)
    local target = targetText(info, s.lines)
    if target then
        at(f, f.target, "TOPRIGHT", W - PAD, y)
        setText(f.target, target)
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
    else
        f.target:Hide()
    end

    y = y + V(15, hk, 13)
    local bh = V(9, hk, 4)
    placeBar(f, f.bar, PAD, y, W - PAD * 2, bh)
    barText(f, f.bar, PAD, y, W - PAD * 2, bh)
    Layouts.SetHealth(f.bar, info, s, true)
    y = y + bh + V(4, hk, 2)

    local list = objectives(info, s.lines)
    for i, q in ipairs(list) do
        local fs = f.quests:Get(i)
        at(f, fs, "TOPLEFT", PAD, y)
        fs:SetWidth(W - PAD * 2)
        setText(fs, q)
        y = y + V(12, hk, 11)
    end
    f.quests:HideFrom(#list + 1)
    return W, y + PAD - 2
end

--------------------------------------------------------------------------------
-- Minimal: two short lines. Level, name, badge; then the bar, type, quest
-- count and target.
--------------------------------------------------------------------------------

local N = { frame = "thin", BAR_W = 60 }
Layouts.minimal = N

function N.Create(f)
    f.level = text(f, 11, T.gold, { outline = "OUTLINE" })
    f.skull = skull(f, 12)
    f.name = text(f, 12)
    f.tag = tag(f, 8)
    f.bar = bar(f)
    f.pct = f.bar.text
    f.kind = text(f, 10, T.dim)
    f.quest = text(f, 11, T.gold)
    f.target = text(f, 11)
end

function N.Fill(f, info, s, wk, hk)
    local PAD, GAP = 6, 6
    -- first line
    local x, y = PAD, 4
    if setLevel(f, info) then
        at(f, f.skull, "TOPLEFT", x, y + 1)
        x = x + 12 + GAP
    else
        at(f, f.level, "TOPLEFT", x, y + 1)
        x = x + width(f.level, 14) + GAP
    end
    at(f, f.name, "TOPLEFT", x, y)
    f.name:SetWidth(0)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    x = x + width(f.name, 110)
    f.tag:Set(KT.Classification[info.cls])
    if f.tag:IsShown() then
        at(f, f.tag, "TOPLEFT", x + GAP, y + 2)
        x = x + GAP + f.tag:GetWidth()
    end
    local w1 = x + PAD

    -- second line: the bar with its percentage, then what's left
    y = y + V(17, hk, 15)
    local bw, bh = max(30, floor(N.BAR_W * wk + 0.5)), V(8, hk, 4)
    x = PAD
    placeBar(f, f.bar, x, y + floor((12 - bh) / 2), bw, bh)
    Layouts.SetHealth(f.bar, info, s, true)
    f.pct:SetFont(Wg.FONT, 10, "OUTLINE")
    f.pct._size = 10
    at(f, f.pct, "TOPLEFT", x + bw + 4, y)
    f.pct:Show()
    x = x + bw + 4 + max(width(f.pct, 24), 24) + GAP
    local kind = Layouts.Kind(info)
    if kind ~= "" then
        at(f, f.kind, "TOPLEFT", x, y + 1)
        f.kind:SetText(kind)
        f.kind:Show()
        x = x + width(f.kind, 60) + GAP
    else
        f.kind:Hide()
    end
    local count = Layouts.QuestCount(info, s.lines)
    if count then
        at(f, f.quest, "TOPLEFT", x, y)
        f.quest:SetText(count)
        f.quest:Show()
        x = x + width(f.quest, 24) + GAP
    else
        f.quest:Hide()
    end
    local target = targetText(info, s.lines)
    if target then
        at(f, f.target, "TOPLEFT", x, y)
        setText(f.target, target)
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
        x = x + width(f.target, 40) + GAP
    else
        f.target:Hide()
    end
    local w2 = x - GAP + PAD
    return max(w1, w2), y + 12 + 5
end

--------------------------------------------------------------------------------
-- Classic: the game's own tooltip, line by line, in the gold frame
--------------------------------------------------------------------------------

local CL = { frame = "thin", MIN = 150, MAX = 280 }
Layouts.classic = CL

function CL.Create(f)
    f.name = text(f, 13)
    f.lines = pool(function() return text(f, 11) end)
    f.bar = bar(f)
end

function CL.Fill(f, info, s, wk, hk)
    local PAD = 8
    local lines = {}
    local function add(t, color) lines[#lines + 1] = { t, color or T.text } end
    if info.isPlayer and info.guild then add("<" .. info.guild .. ">") end
    local level = (info.level and info.level > 0) and tostring(info.level) or "??"
    local what = Layouts.Kind(info)
    if info.isPlayer then what = what:gsub(" · ", " ") end
    local r = rank(info)
    add(("Level %s %s%s"):format(level, what, r and (" (" .. r .. ")") or ""))
    local diff = difficultyText(info, s.lines)
    if diff then add(diff, info.difficultyColor) end
    if s.lines.target and info.target then add("Target: " .. tostring(info.target), info.targetColor) end
    if s.lines.friends and info.together then add(("Killed with %s: %d"):format(info.partner or "your friend", info.together), T.teal) end
    for _, q in ipairs(s.lines.quests and info.quests or {}) do add(q[1], q[2] and T.gold or T.text) end

    at(f, f.name, "TOPLEFT", PAD, 7)
    f.name:SetWidth(0)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    local w = width(f.name, 120)
    local y, step = 7 + V(16, hk, 14), V(14, hk, 12)
    for i, l in ipairs(lines) do
        local fs = f.lines:Get(i)
        at(f, fs, "TOPLEFT", PAD, y)
        fs:SetWidth(0)
        setText(fs, l[1])
        fs:SetTextColor(Wg.rgb(l[2]))
        w = max(w, width(fs, 100))
        y = y + step
    end
    f.lines:HideFrom(#lines + 1)
    local W = max(floor(CL.MIN * wk + 0.5), min(floor(CL.MAX * wk + 0.5), w + PAD * 2))
    -- long lines end in "..." at the card's edge
    f.name:SetWidth(W - PAD * 2)
    for i = 1, #lines do f.lines[i]:SetWidth(W - PAD * 2) end
    local bh = V(8, hk, 4)
    y = y + V(3, hk, 2)
    placeBar(f, f.bar, PAD, y, W - PAD * 2, bh)
    barText(f, f.bar, PAD, y, W - PAD * 2, bh)
    Layouts.SetHealth(f.bar, info, s, true)
    return W, y + bh + PAD
end

--------------------------------------------------------------------------------
-- Plate: like a nameplate, centred and small
--------------------------------------------------------------------------------

local PL = { frame = "thin", WIDTH = 170 }
Layouts.plate = PL

function PL.Create(f)
    f.name = text(f, 12)
    f.level = text(f, 10, T.gold, { outline = "OUTLINE" })
    f.skull = skull(f, 11)
    f.bar = bar(f)
    f.info = text(f, 10)
end

function PL.Fill(f, info, s, wk, hk)
    local W = max(130, min(340, floor(PL.WIDTH * wk + 0.5)))
    local name = info.name
    if info.cls == "rare" or info.cls == "rareelite" then
        local plain = clean(info.name)
        if plain then name = plain .. " (Rare)" end
    end
    at(f, f.name, "TOP", W / 2, 5)
    f.name:SetWidth(W - 12)
    f.name:SetJustifyH("CENTER")
    setText(f.name, name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))

    local y, bh = 5 + V(17, hk, 15), V(10, hk, 5)
    placeBar(f, f.bar, 30, y, W - 38, bh)
    barText(f, f.bar, 30, y, W - 38, bh)
    Layouts.SetHealth(f.bar, info, s, true)
    setLevel(f, info)
    -- the classic elite mark: a plus after the level
    if f.level:IsShown() and (info.cls == "elite" or info.cls == "rareelite" or info.cls == "worldboss") then
        f.level:SetText(info.level .. "+")
    end
    at(f, f.level, "TOPRIGHT", 26, y + floor((bh - 10) / 2))
    at(f, f.skull, "TOPLEFT", 13, y + floor((bh - 11) / 2))
    y = y + bh + V(4, hk, 3)

    -- what it is, its quest count and its target, on one centred line
    local bits = {}
    local kind = Layouts.Kind(info)
    if kind ~= "" then bits[#bits + 1] = paint(kind, T.dim) end
    local count = Layouts.QuestCount(info, s.lines)
    if count then bits[#bits + 1] = paint(count, T.gold) end
    local target = targetText(info, s.lines)
    if target then bits[#bits + 1] = paint(target, info.targetColor or T.text) end
    if #bits == 0 then
        f.info:Hide()
        return W, y + 2
    end
    at(f, f.info, "TOP", W / 2, y)
    f.info:SetWidth(W - 8)
    f.info:SetJustifyH("CENTER")
    f.info:SetText(table.concat(bits, "  "))
    f.info:Show()
    return W, y + 13 + 4
end

--------------------------------------------------------------------------------
-- Portrait: like the game's target frame, with the unit's face
--------------------------------------------------------------------------------

local PO = { frame = "thin", WIDTH = 250, FACE = 52 }
Layouts.portrait = PO

-- an icon for the creature's kind, when the game can't draw its face
local KIND_ICON = {
    Beast = "Ability_Hunter_Pet_Wolf", Humanoid = "INV_Misc_Head_Human_01", Undead = "Spell_Shadow_RaiseDead",
    Demon = "Spell_Shadow_SummonFelHunter", Elemental = "Spell_Frost_SummonWaterElemental", Dragonkin = "INV_Misc_Head_Dragon_01",
    Mechanical = "INV_Gizmo_01", Giant = "Ability_Racial_Avatar", Critter = "Ability_Hunter_Pet_Rat",
}
Layouts.KIND_ICON = KIND_ICON

function PO.Create(f)
    local face = f:CreateTexture(nil, "ARTWORK")
    face:SetSize(PO.FACE, PO.FACE)
    local mask = f.CreateMaskTexture and f:CreateMaskTexture()
    if mask then
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(face)
        face:AddMaskTexture(mask)
    end
    f.face = part(f, face, "face")
    f.face._size = PO.FACE
    local edge = f:CreateTexture(nil, "OVERLAY")
    edge:SetTexture(KT.Files.ring)
    edge:SetSize(PO.FACE * 1.75, PO.FACE * 1.75)
    edge:SetPoint("TOPLEFT", face, "TOPLEFT", -4, 4)
    -- the level in a small ring on the face's lower left, as on the game's frames
    f.ring = ring(f, 22)
    f.ring:SetFrameLevel((f:GetFrameLevel() or 1) + 3)
    f.band = solid(f, T.band)
    f.name = text(f, 13, nil, { title = true })
    f.quest = text(f, 11, T.gold)
    f.bar = bar(f)
    f.sub = text(f, 10, T.dim)
    f.target = text(f, 10)
    f.quests = pool(function() return text(f, 10) end)
end

local function setFace(tex, info)
    local unit = info.unit or info.portraitUnit
    tex._unit = nil
    if unit and SetPortraitTexture and KT.call(UnitExists, unit) and pcall(SetPortraitTexture, tex, unit) then
        tex._unit = info.ctype or (info.isPlayer and "player") or "unit"
        return
    end
    local icon = "Interface\\Icons\\" .. (KIND_ICON[info.ctype] or "INV_Misc_QuestionMark")
    tex:SetTexture(icon)
    tex._tex = icon
end

function PO.Fill(f, info, s, wk, hk)
    local FACE, X = PO.FACE, PO.FACE + 12
    local W = max(200, min(420, floor(PO.WIDTH * wk + 0.5)))
    at(f, f.face, "TOPLEFT", 6, 6)
    setFace(f.face, info)
    at(f, f.ring, "TOPLEFT", 2, 40)
    setLevel(f, info)

    at(f, f.band, "TOPLEFT", X, 6)
    f.band:SetSize(W - X - 8, 18)
    local count = Layouts.QuestCount(info, s.lines)
    if count then
        at(f, f.quest, "TOPRIGHT", W - 12, 8)
        f.quest:SetText(count)
        f.quest:Show()
    else
        f.quest:Hide()
    end
    at(f, f.name, "TOPLEFT", X + 4, 8)
    f.name:SetWidth(W - X - 16 - (count and width(f.quest, 24) + 6 or 0))
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))

    local y, bh = 28, V(13, hk, 6)
    placeBar(f, f.bar, X, y, W - X - 8, bh)
    barText(f, f.bar, X, y, W - X - 8, bh)
    Layouts.SetHealth(f.bar, info, s)
    y = y + bh + V(5, hk, 3)

    local kind = Layouts.Kind(info)
    local r = rank(info)
    if r then kind = (kind ~= "" and kind .. " · " or "") .. r end
    at(f, f.sub, "TOPLEFT", X, y)
    f.sub:SetText(kind)
    local target = targetText(info, s.lines)
    if target then
        at(f, f.target, "TOPRIGHT", W - 8, y)
        setText(f.target, target)
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
    else
        f.target:Hide()
    end
    y = y + 13 + V(3, hk, 2)

    local list = objectives(info, s.lines)
    for i, q in ipairs(list) do
        local fs = f.quests:Get(i)
        at(f, fs, "TOPLEFT", X, y)
        fs:SetWidth(W - X - 8)
        setText(fs, q)
        y = y + V(12, hk, 11)
    end
    f.quests:HideFrom(#list + 1)
    return W, max(FACE + 12, y + 3)
end

--------------------------------------------------------------------------------
-- Bar: the health bar is the card, the name written on it
--------------------------------------------------------------------------------

local BA = { frame = "thin", WIDTH = 230, BOX = 26 }
Layouts.bar = BA

function BA.Create(f)
    f.box = solid(f, { 0, 0, 0 }, 0.5)
    f.level = text(f, 11, T.gold, { outline = "OUTLINE" })
    f.skull = skull(f, 12)
    f.bar = bar(f)
    f.name = text(f, 12, nil, { outline = "OUTLINE", top = true })
    f.info = text(f, 10, T.dim)
    f.target = text(f, 10)
end

function BA.Fill(f, info, s, wk, hk)
    local BOX = BA.BOX
    local W = max(160, min(400, floor(BA.WIDTH * wk + 0.5)))
    local bh = V(22, hk, 14)
    at(f, f.box, "TOPLEFT", 2, 2)
    f.box:SetSize(BOX - 2, bh)
    setLevel(f, info)
    at(f, f.level, "TOP", BOX / 2 + 1, 2 + floor((bh - 11) / 2))
    at(f, f.skull, "TOPLEFT", BOX / 2 - 5, 2 + floor((bh - 12) / 2))

    placeBar(f, f.bar, BOX + 2, 3, W - BOX - 5, bh - 2)
    Layouts.SetHealth(f.bar, info, s, true)
    local size = min(11, max(8, bh - 8))
    f.bar.text:SetFont(Wg.FONT, size, "OUTLINE")
    f.bar.text._size = size
    at(f, f.bar.text, "TOPRIGHT", W - 7, 3 + floor((bh - 2 - size) / 2))
    f.bar.text:Show()
    local nsize = min(12, max(9, bh - 8))
    f.name:SetFont(Wg.FONT, nsize, "OUTLINE")
    f.name._size = nsize
    at(f, f.name, "TOPLEFT", BOX + 7, 3 + floor((bh - 2 - nsize) / 2))
    f.name:SetWidth(W - BOX - 7 - 46)
    setText(f.name, info.name)
    -- the name sits on the bar, so it keeps its colour but stays readable
    f.name:SetTextColor(Wg.rgb(info.classColor or (info.reaction == "neutral" and KT.Reaction.neutral) or T.text))

    -- below: what it is, its rank, quest count and guild; the target on the right
    local bits = {}
    local kind = Layouts.Kind(info)
    if kind ~= "" then bits[#bits + 1] = kind end
    local r = rank(info)
    if r then bits[#bits + 1] = paint(r, T.gold) end
    local count = Layouts.QuestCount(info, s.lines)
    if count then bits[#bits + 1] = paint(count, T.gold) end
    if info.guild then bits[#bits + 1] = "<" .. info.guild .. ">" end
    local target = targetText(info, s.lines)
    local y = bh + 6
    if target then
        at(f, f.target, "TOPRIGHT", W - 6, y)
        setText(f.target, target)
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
    else
        f.target:Hide()
    end
    if #bits == 0 and not target then
        f.info:Hide()
        return W, bh + 4
    end
    at(f, f.info, "TOPLEFT", 6, y)
    f.info:SetWidth(W - 12 - (target and width(f.target, 40) + 8 or 0))
    f.info:SetText(table.concat(bits, " · "))
    f.info:Show()
    return W, y + 13 + 3
end

--------------------------------------------------------------------------------
-- Icons: name and bar, then the details as small icons with a value
--------------------------------------------------------------------------------

local IC = { frame = "thin", MIN = 190 }
Layouts.icons = IC

local ICON = {
    target = { "Interface\\CURSOR\\Attack" },
    quest = { "Interface\\GossipFrame\\ActiveQuestIcon", "Interface\\GossipFrame\\AvailableQuestIcon" },
    friends = { "Interface\\Icons\\Achievement_Reputation_01", "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
    guild = { "Interface\\Icons\\INV_Shirt_GuildTabard_01", "Interface\\Icons\\INV_Misc_Note_01" },
}

function IC.Create(f)
    f.level = text(f, 12, T.gold, { outline = "OUTLINE" })
    f.skull = skull(f, 13)
    f.name = text(f, 13)
    f.tag = tag(f, 8)
    f.bar = bar(f)
    f.chips = {}
    for _, key in ipairs({ "target", "kind", "quest", "friends", "guild" }) do
        local c = chip(f)
        f.chips[#f.chips + 1] = c
        f.chips[key] = c
    end
end

function IC.Fill(f, info, s, wk, hk)
    local PAD = 7
    local x = PAD
    if setLevel(f, info) then
        at(f, f.skull, "TOPLEFT", x, 6)
        x = x + 13 + 5
    else
        at(f, f.level, "TOPLEFT", x, 7)
        x = x + width(f.level, 14) + 5
    end
    at(f, f.name, "TOPLEFT", x, 6)
    f.name:SetWidth(0)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    x = x + width(f.name, 110)
    f.tag:Set(KT.Classification[info.cls])
    if f.tag:IsShown() then
        at(f, f.tag, "TOPLEFT", x + 5, 8)
        x = x + 5 + f.tag:GetWidth()
    end
    local W = max(floor(IC.MIN * wk + 0.5), x + PAD)

    local c = f.chips
    local kindIcon = info.isPlayer and "INV_Misc_Head_Human_01" or KIND_ICON[info.ctype] or "INV_Misc_QuestionMark"
    c.target:Set(Wg.FirstFile(ICON.target), targetText(info, s.lines) and tostring(info.target) or nil, info.targetColor)
    local kind = info.isPlayer and info.className or info.family or info.ctype
    c.kind:Set("Interface\\Icons\\" .. kindIcon, kind, T.dim)
    c.quest:Set(Wg.FirstFile(ICON.quest), Layouts.QuestCount(info, s.lines), T.gold)
    c.friends:Set(Wg.FirstFile(ICON.friends), s.lines.friends and info.together or nil, T.teal)
    c.guild:Set(Wg.FirstFile(ICON.guild), info.guild and ("<" .. info.guild .. ">") or nil, T.text)
    local cx, any = PAD, false
    for _, chipFrame in ipairs(c) do
        if chipFrame:IsShown() then any = true; cx = cx + chipFrame:GetWidth() + 8 end
    end
    W = max(W, cx - 8 + PAD)

    local y, bh = 6 + V(19, hk, 16), V(8, hk, 4)
    local bw = W - PAD * 2 - 34
    placeBar(f, f.bar, PAD, y, bw, bh)
    Layouts.SetHealth(f.bar, info, s, true)
    f.bar.text:SetFont(Wg.FONT, 9, "OUTLINE")
    f.bar.text._size = 9
    at(f, f.bar.text, "TOPLEFT", PAD + bw + 4, y + floor((bh - 9) / 2))
    f.bar.text:Show()
    y = y + bh + V(6, hk, 4)

    cx = PAD
    for _, chipFrame in ipairs(c) do
        if chipFrame:IsShown() then
            at(f, chipFrame, "TOPLEFT", cx, y)
            cx = cx + chipFrame:GetWidth() + 8
        end
    end
    return W, any and y + 14 + 5 or y + 2
end
