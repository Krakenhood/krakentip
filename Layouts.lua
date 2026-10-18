local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets
local raw, clean = KT.raw, KT.clean

--------------------------------------------------------------------------------
-- The three looks of the card. Each builds its parts on a frame once
-- (Create) and fills them for a unit (Fill), returning the size it needs.
--
--   regular  the full card: level ring, name, type, a big health bar, a line
--            each for target, difficulty, guild and kills together, quests
--   mid      the same at a glance: two lines of text, a thin bar, quests
--   minimal  one line: level, name, badge, a small bar, target, quest count
--------------------------------------------------------------------------------

local Layouts = {}
KT.Layouts = Layouts

local DARK = { 0.10, 0.07, 0.03 } -- letters on the gold badge

-- a font string's width, or a guess when the game won't say (secret text)
local function width(fs, guess)
    local w = clean(fs:GetStringWidth())
    return type(w) == "number" and w or guess
end

local function setText(fs, text)
    if not pcall(fs.SetText, fs, text) then fs:SetText("") end
end

--------------------------------------------------------------------------------
-- Shared pieces
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

-- The lines under the bar, as { label, value, colour }.
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
local function questCount(info)
    for _, q in ipairs(info.quests or {}) do
        local text = clean(q[1])
        local n = type(text) == "string" and not q[2] and text:match("(%d+%s*/%s*%d+)")
        if n then return (n:gsub("%s", "")) end
    end
end

local function makeBar(f, h, size)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetHeight(h)
    bar:SetStatusBarTexture(Wg.FirstFile(KT.Files.bar))
    bar:SetMinMaxValues(0, 1)
    local bg = Wg.Solid(bar, "BACKGROUND", { 0, 0, 0 }, 0.65)
    bg:SetAllPoints()
    local edge = Wg.Solid(bar, "BACKGROUND", T.gold, 0.5, -1)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.text = Wg.Text(bar, size, T.text, "CENTER", "OUTLINE")
    bar.text:SetPoint("CENTER", 0, 0)
    return bar
end

-- the badge for elites, rares and bosses: dark letters on gold
local function makeTag(f, size)
    local tag = CreateFrame("Frame", nil, f)
    tag:SetSize(40, size + 3)
    tag.bg = Wg.Solid(tag, "BACKGROUND", T.gold, 0.95)
    tag.bg:SetAllPoints()
    tag.text = Wg.Text(tag, size, DARK, "CENTER")
    tag.text:SetShadowOffset(0, 0)
    tag.text:SetPoint("CENTER", 0, 0)
    function tag:Set(text)
        if not text then return self:Hide() end
        self.text:SetText(text)
        self:SetWidth(width(self.text, 30) + 8)
        self:Show()
    end
    return tag
end

local function makeSkull(f, size)
    local skull = f:CreateTexture(nil, "ARTWORK")
    skull:SetTexture(KT.Files.skull)
    skull:SetSize(size, size)
    return skull
end

-- The level as text in its difficulty colour, or the skull.
local function setLevel(fs, skull, info)
    if info.level and info.level > 0 then
        fs:SetText(info.level)
        fs:SetTextColor(Wg.rgb(info.difficultyColor or T.gold))
        fs:Show()
        skull:Hide()
        return false
    end
    fs:Hide()
    skull:Show()
    return true
end

-- Health on the bar: the numbers and the percentage, or (short) just the
-- percentage. Status bars take secret values, so the bar fills even when the
-- game hides the numbers from us.
function Layouts.SetHealth(bar, info, short)
    local unit = info.unit
    local hp, max
    if unit then
        hp, max = raw(UnitHealth, unit), raw(UnitHealthMax, unit)
    else
        hp, max = info.hp, info.hpMax
    end
    pcall(bar.SetMinMaxValues, bar, 0, max or 1)
    pcall(bar.SetValue, bar, hp or 0)
    bar:SetStatusBarColor(Wg.rgb(info.tapped and T.tapped or info.canAttack and T.health or T.friendly))

    if info.dead then
        bar.text:SetText("Dead")
        return
    end
    local h, m = clean(hp), clean(max)
    if h and m and m > 0 then
        local pct = math.floor(100 * h / m + 0.5)
        -- Classic hands out creature health as a percentage only (max 100)
        if short or m == 100 then
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

--------------------------------------------------------------------------------
-- Regular: the full card in the gold dialog frame
--------------------------------------------------------------------------------

local R = { WIDTH = 236, PAD = 8, HEAD = 42, BAR_H = 16, ROW_H = 16 }
Layouts.regular = R

local function Row(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(R.WIDTH - R.PAD * 2, R.ROW_H)
    r.label = Wg.Text(r, 11, T.dim)
    r.label:SetPoint("LEFT")
    r.value = Wg.Text(r, 11, T.text, "RIGHT")
    r.value:SetPoint("RIGHT")
    return r
end

function R.Create(f)
    local PAD, HEAD = R.PAD, R.HEAD
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
    f.level = Wg.Text(badge, 12, T.gold, "CENTER", "OUTLINE")
    f.level:SetPoint("CENTER", 0, 0)
    f.skull = makeSkull(badge, 16)
    f.skull:SetPoint("CENTER")
    f.badge = badge

    f.name = Wg.Title(f, 16)
    f.name:SetPoint("TOPLEFT", badge, "TOPRIGHT", 7, 0)
    f.name:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)

    f.sub = Wg.Text(f, 11, T.dim)
    f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -2)

    f.tag = makeTag(f, 9)

    f.bar = makeBar(f, R.BAR_H, 11)
    f.bar:SetPoint("TOPLEFT", PAD, -(HEAD + 6))
    f.bar:SetPoint("TOPRIGHT", -PAD, -(HEAD + 6))

    f.rows = {}
    f.sep = Wg.Solid(f, "ARTWORK", T.line)
    f.sep:SetHeight(1)
    f.quests = {}
end

function R.Fill(f, info, s)
    local PAD = R.PAD
    setLevel(f.level, f.skull, info)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))

    local kind = Layouts.Kind(info)
    f.sub:SetText(kind)
    f.tag:Set(KT.Classification[info.cls])
    f.tag:ClearAllPoints()
    if kind ~= "" then
        f.tag:SetPoint("LEFT", f.sub, "RIGHT", 5, 0)
    else
        f.tag:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    end

    Layouts.SetHealth(f.bar, info)

    local rows = Layouts.Rows(info, s.lines)
    local y = R.HEAD + 6 + R.BAR_H + 5
    for i, r in ipairs(rows) do
        local row = f.rows[i] or Row(f)
        f.rows[i] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, -y)
        row.label:SetText(r[1])
        setText(row.value, r[2])
        row.value:SetTextColor(Wg.rgb(r[3] or T.text))
        row:Show()
        y = y + R.ROW_H
    end
    for i = #rows + 1, #f.rows do f.rows[i]:Hide() end

    -- quest progress, as the game words it
    local quests = s.lines.quests and info.quests or {}
    if #quests > 0 then
        y = y + 4
        f.sep:ClearAllPoints()
        f.sep:SetPoint("TOPLEFT", PAD, -y)
        f.sep:SetPoint("TOPRIGHT", -PAD, -y)
        f.sep:Show()
        y = y + 5
    else
        f.sep:Hide()
    end
    for i, q in ipairs(quests) do
        local fs = f.quests[i] or Wg.Text(f, 11, T.text)
        f.quests[i] = fs
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PAD, -y)
        fs:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
        setText(fs, q[1])
        fs:SetTextColor(Wg.rgb(q[2] and T.gold or T.text))
        fs:Show()
        y = y + 14
    end
    for i = #quests + 1, #f.quests do f.quests[i]:Hide() end

    return R.WIDTH, y + PAD
end

--------------------------------------------------------------------------------
-- Mid: two lines of text and a thin bar, in a thin gold frame
--------------------------------------------------------------------------------

local M = { WIDTH = 214, PAD = 7, BAR_H = 9 }
Layouts.mid = M

function M.Create(f)
    local PAD = M.PAD
    Wg.ThinFrame(f, 0)
    f.level = Wg.Text(f, 12, T.gold, "LEFT", "OUTLINE")
    f.level:SetPoint("TOPLEFT", PAD, -7)
    f.skull = makeSkull(f, 13)
    f.skull:SetPoint("TOPLEFT", PAD, -6)

    f.tag = makeTag(f, 8)
    f.tag:SetPoint("TOPRIGHT", -PAD, -7)

    f.name = Wg.Title(f, 14)

    f.sub = Wg.Text(f, 10, T.dim)
    f.sub:SetPoint("TOPLEFT", PAD, -25)
    f.target = Wg.Text(f, 10, T.text, "RIGHT")
    f.target:SetPoint("TOPRIGHT", -PAD, -25)

    f.bar = makeBar(f, M.BAR_H, 9)
    f.bar:SetPoint("TOPLEFT", PAD, -40)
    f.bar:SetPoint("TOPRIGHT", -PAD, -40)
    f.quests = {}
end

function M.Fill(f, info, s)
    local PAD = M.PAD
    local skull = setLevel(f.level, f.skull, info)
    f.tag:Set(KT.Classification[info.cls])
    f.name:ClearAllPoints()
    f.name:SetPoint("TOPLEFT", skull and 24 or PAD + width(f.level, 14) + 5, -5)
    f.name:SetPoint("RIGHT", f, "RIGHT", -(PAD + (f.tag:IsShown() and f.tag:GetWidth() + 4 or 0)), 0)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))

    local kind = Layouts.Kind(info)
    if info.guild then kind = (kind ~= "" and kind .. " · " or "") .. "<" .. info.guild .. ">" end
    f.sub:SetText(kind)
    if s.lines.target and info.target then
        setText(f.target, info.target)
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
    else
        f.target:Hide()
    end

    Layouts.SetHealth(f.bar, info, true)

    -- quest objectives only, the titles are left out
    local y = 40 + M.BAR_H + 4
    local n = 0
    for _, q in ipairs(s.lines.quests and info.quests or {}) do
        if not q[2] then
            n = n + 1
            local fs = f.quests[n] or Wg.Text(f, 10, T.text)
            f.quests[n] = fs
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", PAD, -y)
            fs:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
            setText(fs, q[1])
            fs:Show()
            y = y + 12
        end
    end
    for i = n + 1, #f.quests do f.quests[i]:Hide() end
    return M.WIDTH, y + PAD - 3
end

--------------------------------------------------------------------------------
-- Minimal: everything on one line
--------------------------------------------------------------------------------

local N = { HEIGHT = 22, PAD = 6, GAP = 6, BAR_W = 54, BAR_H = 8, PCT_W = 30 }
Layouts.minimal = N
N.short = true

function N.Create(f)
    Wg.ThinFrame(f, 0)
    f.level = Wg.Text(f, 11, T.gold, "LEFT", "OUTLINE")
    f.skull = makeSkull(f, 12)
    f.name = Wg.Text(f, 12, T.text)
    f.tag = makeTag(f, 8)
    f.bar = makeBar(f, N.BAR_H, 10)
    -- the percentage sits right of the bar, not on it
    f.bar.text:ClearAllPoints()
    f.bar.text:SetPoint("LEFT", f.bar, "RIGHT", 4, 0)
    f.bar.text:SetWidth(N.PCT_W)
    f.bar.text:SetJustifyH("LEFT")
    f.target = Wg.Text(f, 11, T.text)
    f.quest = Wg.Text(f, 11, T.gold)
end

function N.Fill(f, info, s)
    local x = N.PAD
    local function place(region, w)
        region:ClearAllPoints()
        region:SetPoint("LEFT", f, "LEFT", x, 0)
        x = x + w + N.GAP
    end
    if setLevel(f.level, f.skull, info) then place(f.skull, 12) else place(f.level, width(f.level, 14)) end
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    place(f.name, width(f.name, 110))
    f.tag:Set(KT.Classification[info.cls])
    if f.tag:IsShown() then place(f.tag, f.tag:GetWidth()) end
    Layouts.SetHealth(f.bar, info, true)
    f.bar:SetWidth(N.BAR_W)
    place(f.bar, N.BAR_W + 4 + N.PCT_W - N.GAP)

    if s.lines.target and info.target then
        setText(f.target, "» " .. tostring(clean(info.target) or ""))
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
        place(f.target, width(f.target, 40))
    else
        f.target:Hide()
    end
    local count = s.lines.quests and questCount(info)
    if count then
        f.quest:SetText(count)
        f.quest:Show()
        place(f.quest, width(f.quest, 24))
    else
        f.quest:Hide()
    end
    return x - N.GAP + N.PAD, N.HEIGHT
end
