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

--------------------------------------------------------------------------------
-- More shared pieces for the looks below
--------------------------------------------------------------------------------

-- the level in a gold ring (or the skull), as on the Regular card
local function makeRing(f, size)
    local badge = CreateFrame("Frame", nil, f)
    badge:SetSize(size, size)
    local disc = badge:CreateTexture(nil, "BACKGROUND")
    disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    disc:SetVertexColor(0.15, 0.10, 0.07, 1)
    disc:SetPoint("TOPLEFT", 3, -3)
    disc:SetPoint("BOTTOMRIGHT", -3, 3)
    local ring = badge:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(KT.Files.ring)
    ring:SetSize(size * 1.8, size * 1.8)
    ring:SetPoint("TOPLEFT", -size / 15, size / 15)
    f.level = Wg.Text(badge, size >= 26 and 12 or 10, T.gold, "CENTER", "OUTLINE")
    f.level:SetPoint("CENTER", 0, 0)
    f.skull = makeSkull(badge, size * 0.55)
    f.skull:SetPoint("CENTER")
    return badge
end

-- a small icon with a value next to it, for the Icons look
local function makeChip(f, files)
    local chip = CreateFrame("Frame", nil, f)
    chip:SetSize(30, 14)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetSize(13, 13)
    chip.icon:SetPoint("LEFT")
    chip.icon:SetTexture(Wg.FirstFile(files))
    chip.text = Wg.Text(chip, 10, T.text)
    chip.text:SetPoint("LEFT", chip.icon, "RIGHT", 2, 0)
    function chip:Set(value, color)
        if value == nil then return self:Hide() end
        setText(self.text, value)
        self.text:SetTextColor(Wg.rgb(color or T.text))
        self:SetWidth(15 + width(self.text, 24))
        self:Show()
        return true
    end
    return chip
end

-- the difficulty word with the level difference: "Hard (+3)"
local function difficultyText(info)
    if not info.difficulty then return nil end
    if info.diff and info.diff ~= 0 then return ("%s (%+d)"):format(info.difficulty, info.diff) end
    return info.difficulty
end

local function wrap(fs, w)
    fs:SetWordWrap(true)
    fs:SetWidth(w)
end

--------------------------------------------------------------------------------
-- Classic: the game's own tooltip, line by line, in the gold frame
--------------------------------------------------------------------------------

local CL = { PAD = 8, LINE = 15, MIN = 150, MAX = 270 }
Layouts.classic = CL

function CL.Create(f)
    Wg.ThinFrame(f, 0)
    f.name = Wg.Text(f, 13, T.text)
    f.lines = {}
    f.bar = makeBar(f, 8, 9)
end

function CL.Fill(f, info, s)
    local PAD = CL.PAD
    local lines = {}
    local function add(text, color) lines[#lines + 1] = { text, color or T.text } end
    if info.isPlayer and info.guild then add("<" .. info.guild .. ">") end
    if info.subtitle then add(info.subtitle) end
    local level = (info.level and info.level > 0) and tostring(info.level) or "??"
    local what = info.isPlayer and Layouts.Kind(info):gsub(" · ", " ") or (info.family or info.ctype or "")
    local cls = KT.Classification[info.cls]
    add(("Level %s %s%s"):format(level, what, cls and (" (" .. cls:sub(1, 1) .. cls:sub(2):lower() .. ")") or ""))
    if info.difficulty and s.lines.difficulty then add(difficultyText(info), info.difficultyColor) end
    if s.lines.target and info.target then add("Target: " .. tostring(info.target), info.targetColor) end
    if s.lines.friends and info.together then add(("Killed with %s: %d"):format(info.partner or "your friend", info.together), T.teal) end
    for _, q in ipairs(s.lines.quests and info.quests or {}) do add(q[1], q[2] and T.gold or T.text) end

    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    f.name:ClearAllPoints()
    f.name:SetPoint("TOPLEFT", PAD, -7)
    local w = width(f.name, 120)
    local y = 7 + CL.LINE + 2
    for i, l in ipairs(lines) do
        local fs = f.lines[i] or Wg.Text(f, 11, T.text)
        f.lines[i] = fs
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PAD, -y)
        setText(fs, l[1])
        fs:SetTextColor(Wg.rgb(l[2]))
        fs:Show()
        w = math.max(w, width(fs, 100))
        y = y + CL.LINE - 1
    end
    for i = #lines + 1, #f.lines do f.lines[i]:Hide() end
    w = math.max(CL.MIN, math.min(CL.MAX, w + PAD * 2))
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", PAD, -(y + 4))
    f.bar:SetPoint("TOPRIGHT", -PAD, -(y + 4))
    Layouts.SetHealth(f.bar, info, true)
    return w, y + 4 + 8 + PAD
end

--------------------------------------------------------------------------------
-- Wide: a low banner, the ring left, the bar right
--------------------------------------------------------------------------------

local WD = { WIDTH = 330, HEIGHT = 48, PAD = 8, SPLIT = 190 }
Layouts.wide = WD

function WD.Create(f)
    Wg.ThinFrame(f, 0)
    f.badge = makeRing(f, 32)
    f.badge:SetPoint("LEFT", 7, 0)
    f.name = Wg.Title(f, 15)
    f.name:SetPoint("TOPLEFT", 46, -7)
    f.name:SetPoint("RIGHT", f, "LEFT", WD.SPLIT - 6, 0)
    f.sub = Wg.Text(f, 10, T.dim)
    f.sub:SetPoint("TOPLEFT", 46, -27)
    f.tag = makeTag(f, 8)
    f.tag:SetPoint("LEFT", f.sub, "RIGHT", 4, 0)
    f.bar = makeBar(f, 14, 10)
    f.bar:SetPoint("TOPLEFT", WD.SPLIT, -8)
    f.bar:SetPoint("TOPRIGHT", -WD.PAD, -8)
    f.left = Wg.Text(f, 10, T.dim)
    f.left:SetPoint("TOPLEFT", WD.SPLIT, -28)
    f.right = Wg.Text(f, 10, T.text, "RIGHT")
    f.right:SetPoint("TOPRIGHT", -WD.PAD, -28)
    f.quest = Wg.Text(f, 10, T.text)
    f.quest:SetPoint("TOPLEFT", 46, -WD.HEIGHT + 4)
end

function WD.Fill(f, info, s)
    setLevel(f.level, f.skull, info)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    f.sub:SetText(Layouts.Kind(info))
    f.tag:Set(KT.Classification[info.cls])
    Layouts.SetHealth(f.bar, info)
    local diff = s.lines.difficulty and difficultyText(info)
    f.left:SetText(diff or (info.guild and "<" .. info.guild .. ">") or "")
    f.left:SetTextColor(Wg.rgb(diff and info.difficultyColor or T.dim))
    if s.lines.target and info.target then
        setText(f.right, "» " .. tostring(info.target))
        f.right:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.right:Show()
    else
        f.right:Hide()
    end
    local h = WD.HEIGHT
    local objective
    for _, q in ipairs(s.lines.quests and info.quests or {}) do if not q[2] then objective = objective or q[1] end end
    if objective then
        setText(f.quest, objective)
        f.quest:Show()
        h = h + 12
    else
        f.quest:Hide()
    end
    return WD.WIDTH, h
end

--------------------------------------------------------------------------------
-- Plate: like a nameplate, centred and small
--------------------------------------------------------------------------------

local PL = { WIDTH = 170, BAR_H = 10 }
Layouts.plate = PL

function PL.Create(f)
    Wg.ThinFrame(f, 0)
    f.name = Wg.Text(f, 12, T.text, "CENTER")
    f.name:SetPoint("TOP", 0, -5)
    f.name:SetWidth(PL.WIDTH - 12)
    f.level = Wg.Text(f, 10, T.gold, "RIGHT", "OUTLINE")
    f.level:SetPoint("TOPLEFT", 4, -22)
    f.level:SetWidth(22)
    f.skull = makeSkull(f, 11)
    f.skull:SetPoint("TOPLEFT", 12, -21)
    f.bar = makeBar(f, PL.BAR_H, 9)
    f.bar:SetPoint("TOPLEFT", 30, -22)
    f.bar:SetPoint("TOPRIGHT", -8, -22)
    f.target = Wg.Text(f, 10, T.text, "CENTER")
    f.target:SetPoint("TOP", 0, -36)
end

function PL.Fill(f, info, s)
    setLevel(f.level, f.skull, info)
    -- the classic elite mark: a plus after the level
    if info.cls == "elite" or info.cls == "rareelite" or info.cls == "worldboss" then
        if f.level:IsShown() then f.level:SetText(info.level .. "+") end
    end
    local name = info.name
    if info.cls == "rare" or info.cls == "rareelite" then
        local plain = clean(info.name)
        if plain then name = plain .. " (Rare)" end
    end
    setText(f.name, name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    Layouts.SetHealth(f.bar, info, true)
    if s.lines.target and info.target then
        setText(f.target, "» " .. tostring(info.target))
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
        return PL.WIDTH, 52
    end
    f.target:Hide()
    return PL.WIDTH, 38
end

--------------------------------------------------------------------------------
-- Portrait: like the game's target frame, with the unit's face
--------------------------------------------------------------------------------

local PO = { WIDTH = 250, HEIGHT = 64, FACE = 52, PAD = 8 }
Layouts.portrait = PO

function PO.Create(f)
    Wg.ThinFrame(f, 0)
    local face = f:CreateTexture(nil, "ARTWORK")
    face:SetSize(PO.FACE, PO.FACE)
    face:SetPoint("TOPLEFT", 6, -6)
    local mask = f.CreateMaskTexture and f:CreateMaskTexture()
    if mask then
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(face)
        face:AddMaskTexture(mask)
    end
    f.face = face
    local ring = f:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(KT.Files.ring)
    ring:SetSize(PO.FACE * 1.75, PO.FACE * 1.75)
    ring:SetPoint("TOPLEFT", face, "TOPLEFT", -4, 4)
    -- the level in a small ring on the face's lower left, as on the game's frames
    f.badge = makeRing(f, 22)
    f.badge:SetPoint("BOTTOMLEFT", face, "BOTTOMLEFT", -4, -4)
    f.badge:SetFrameLevel((f:GetFrameLevel() or 1) + 2)

    local band = Wg.Solid(f, "BACKGROUND", T.band, nil, 1)
    band:SetPoint("TOPLEFT", PO.FACE + 12, -6)
    band:SetPoint("TOPRIGHT", -PO.PAD, -6)
    band:SetHeight(18)
    f.name = Wg.Title(f, 13)
    f.name:SetPoint("TOPLEFT", PO.FACE + 16, -8)
    f.name:SetPoint("RIGHT", f, "RIGHT", -PO.PAD - 4, 0)
    f.bar = makeBar(f, 13, 10)
    f.bar:SetPoint("TOPLEFT", PO.FACE + 12, -28)
    f.bar:SetPoint("TOPRIGHT", -PO.PAD, -28)
    f.sub = Wg.Text(f, 10, T.dim)
    f.sub:SetPoint("TOPLEFT", PO.FACE + 12, -46)
    f.target = Wg.Text(f, 10, T.text, "RIGHT")
    f.target:SetPoint("TOPRIGHT", -PO.PAD, -46)
    f.quests = {}
end

-- the creature's look as a picture: its face when the game can draw it, an
-- icon for its kind otherwise (the sample, a unit that went away)
local KIND_ICON = {
    Beast = "Ability_Hunter_Pet_Wolf", Humanoid = "INV_Misc_Head_Human_01", Undead = "Spell_Shadow_RaiseDead",
    Demon = "Spell_Shadow_SummonFelHunter", Elemental = "Spell_Frost_SummonWaterElemental", Dragonkin = "INV_Misc_Head_Dragon_01",
    Mechanical = "INV_Gizmo_01", Giant = "Ability_Racial_Avatar", Critter = "Ability_Hunter_Pet_Rat",
}
local function setFace(tex, info)
    local unit = info.unit or info.portraitUnit
    if unit and SetPortraitTexture and pcall(SetPortraitTexture, tex, unit) and KT.call(UnitExists, unit) then return end
    tex:SetTexture("Interface\\Icons\\" .. (KIND_ICON[info.ctype] or "INV_Misc_QuestionMark"))
end

function PO.Fill(f, info, s)
    setFace(f.face, info)
    setLevel(f.level, f.skull, info)
    local name = info.name
    local cls = KT.Classification[info.cls]
    setText(f.name, name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    Layouts.SetHealth(f.bar, info)
    local kind = Layouts.Kind(info)
    if cls then kind = (kind ~= "" and kind .. " · " or "") .. cls:sub(1, 1) .. cls:sub(2):lower() end
    f.sub:SetText(kind)
    if s.lines.target and info.target then
        setText(f.target, "» " .. tostring(info.target))
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
    else
        f.target:Hide()
    end
    local y, n = PO.HEIGHT, 0
    for _, q in ipairs(s.lines.quests and info.quests or {}) do
        if not q[2] then
            n = n + 1
            local fs = f.quests[n] or Wg.Text(f, 10, T.text)
            f.quests[n] = fs
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", PO.FACE + 12, -(y - 2))
            setText(fs, q[1])
            fs:Show()
            y = y + 12
        end
    end
    for i = n + 1, #f.quests do f.quests[i]:Hide() end
    return PO.WIDTH, y + (n > 0 and 2 or 0)
end

--------------------------------------------------------------------------------
-- Column: narrow and tall, everything centred
--------------------------------------------------------------------------------

local CO = { WIDTH = 150, PAD = 8 }
Layouts.column = CO

function CO.Create(f)
    Wg.DialogFrame(f)
    f.badge = makeRing(f, 30)
    f.badge:SetPoint("TOP", 0, -8)
    f.name = Wg.Title(f, 14)
    f.name:SetJustifyH("CENTER")
    wrap(f.name, CO.WIDTH - CO.PAD * 2)
    f.sub = Wg.Text(f, 10, T.dim, "CENTER")
    f.tag = makeTag(f, 8)
    f.bar = makeBar(f, 12, 10)
    f.rows = {}
    f.quests = {}
end

function CO.Fill(f, info, s)
    local PAD, W = CO.PAD, CO.WIDTH
    setLevel(f.level, f.skull, info)
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    local y = 44
    f.name:ClearAllPoints()
    f.name:SetPoint("TOP", 0, -y)
    local nameH = clean(f.name:GetStringHeight())
    y = y + ((type(nameH) == "number" and nameH > 0) and nameH or 16) + 2
    f.sub:ClearAllPoints()
    f.sub:SetPoint("TOP", 0, -y)
    f.sub:SetText(Layouts.Kind(info))
    y = y + 13
    f.tag:Set(KT.Classification[info.cls])
    if f.tag:IsShown() then
        f.tag:ClearAllPoints()
        f.tag:SetPoint("TOP", 0, -y)
        y = y + 15
    end
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", PAD, -(y + 2))
    f.bar:SetPoint("TOPRIGHT", -PAD, -(y + 2))
    Layouts.SetHealth(f.bar, info, true)
    y = y + 20
    -- each line as a small label over its value
    local rows = Layouts.Rows(info, s.lines)
    local n = 0
    local function line(text, size, color)
        n = n + 1
        local fs = f.rows[n] or Wg.Text(f, size, color, "CENTER")
        f.rows[n] = fs
        fs:SetFont(Wg.FONT, size, "")
        fs:ClearAllPoints()
        fs:SetPoint("TOP", 0, -y)
        setText(fs, text)
        fs:SetTextColor(Wg.rgb(color))
        fs:Show()
        y = y + size + 3
    end
    for _, r in ipairs(rows) do
        line(r[1], 9, T.faint)
        line(r[2], 11, r[3] or T.text)
        y = y + 2
    end
    for _, q in ipairs(s.lines.quests and info.quests or {}) do
        if not q[2] then line((strtrim(tostring(clean(q[1]) or "")):gsub("^%-%s*", "")), 10, T.gold) end
    end
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    return W, y + PAD
end

--------------------------------------------------------------------------------
-- Bar: the health bar is the card, the name written on it
--------------------------------------------------------------------------------

local BA = { WIDTH = 230, BAR_H = 22, BOX = 26 }
Layouts.bar = BA

function BA.Create(f)
    Wg.ThinFrame(f, 0)
    f.box = Wg.Solid(f, "BACKGROUND", { 0, 0, 0 }, 0.5, 1)
    f.box:SetPoint("TOPLEFT", 2, -2)
    f.box:SetSize(BA.BOX - 2, BA.BAR_H)
    f.level = Wg.Text(f, 11, T.gold, "CENTER", "OUTLINE")
    f.level:SetPoint("CENTER", f, "TOPLEFT", BA.BOX / 2 + 1, -(BA.BAR_H / 2 + 2))
    f.skull = makeSkull(f, 12)
    f.skull:SetPoint("CENTER", f, "TOPLEFT", BA.BOX / 2 + 1, -(BA.BAR_H / 2 + 2))
    f.bar = makeBar(f, BA.BAR_H - 2, 11)
    f.bar:SetPoint("TOPLEFT", BA.BOX + 2, -3)
    f.bar:SetPoint("TOPRIGHT", -3, -3)
    f.bar.text:ClearAllPoints()
    f.bar.text:SetPoint("RIGHT", -4, 0)
    f.name = Wg.Text(f.bar, 12, T.text, "LEFT", "OUTLINE")
    f.name:SetPoint("LEFT", 5, 0)
    f.name:SetPoint("RIGHT", f.bar.text, "LEFT", -4, 0)
    f.info = Wg.Text(f, 10, T.dim)
    f.info:SetPoint("TOPLEFT", 6, -(BA.BAR_H + 6))
    f.target = Wg.Text(f, 10, T.text, "RIGHT")
    f.target:SetPoint("TOPRIGHT", -6, -(BA.BAR_H + 6))
end

function BA.Fill(f, info, s)
    setLevel(f.level, f.skull, info)
    setText(f.name, info.name)
    -- the name sits on the bar, so it keeps its colour but stays readable
    f.name:SetTextColor(Wg.rgb(info.classColor or (info.reaction == "neutral" and KT.Reaction.neutral) or T.text))
    Layouts.SetHealth(f.bar, info, true)
    local bits = {}
    local cls = KT.Classification[info.cls]
    if cls then bits[#bits + 1] = "|cffffd100" .. cls:sub(1, 1) .. cls:sub(2):lower() .. "|r" end
    local count = s.lines.quests and questCount(info)
    if count then bits[#bits + 1] = "|cffffd100" .. count .. "|r" end
    if info.guild then bits[#bits + 1] = "<" .. info.guild .. ">" end
    f.info:SetText(table.concat(bits, "  "))
    local target = s.lines.target and info.target
    if target then
        setText(f.target, "» " .. tostring(target))
        f.target:SetTextColor(Wg.rgb(info.targetColor or T.text))
        f.target:Show()
    else
        f.target:Hide()
    end
    if #bits == 0 and not target then
        f.info:Hide()
        return BA.WIDTH, BA.BAR_H + 4
    end
    f.info:Show()
    return BA.WIDTH, BA.BAR_H + 20
end

--------------------------------------------------------------------------------
-- Icons: name and bar, then the details as small icons with a value
--------------------------------------------------------------------------------

local IC = { MIN = 190, PAD = 7 }
Layouts.icons = IC

local ICON = {
    target = { "Interface\\CURSOR\\Attack" },
    difficulty = { "Interface\\Icons\\Ability_DualWield", "Interface\\Icons\\INV_Sword_04" },
    quest = { "Interface\\GossipFrame\\ActiveQuestIcon", "Interface\\GossipFrame\\AvailableQuestIcon" },
    friends = { "Interface\\Icons\\Achievement_Reputation_01", "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
    guild = { "Interface\\Icons\\INV_Shirt_GuildTabard_01", "Interface\\Icons\\INV_Misc_Note_01" },
}

function IC.Create(f)
    Wg.ThinFrame(f, 0)
    f.level = Wg.Text(f, 12, T.gold, "LEFT", "OUTLINE")
    f.level:SetPoint("TOPLEFT", IC.PAD, -7)
    f.skull = makeSkull(f, 13)
    f.skull:SetPoint("TOPLEFT", IC.PAD, -6)
    f.name = Wg.Text(f, 13, T.text)
    f.tag = makeTag(f, 8)
    f.bar = makeBar(f, 8, 9)
    f.bar.text:ClearAllPoints()
    f.bar.text:SetPoint("LEFT", f.bar, "RIGHT", 4, 0)
    f.chips = {}
    for _, key in ipairs({ "target", "difficulty", "quest", "friends", "guild" }) do
        f.chips[#f.chips + 1] = makeChip(f, ICON[key])
        f.chips[key] = f.chips[#f.chips]
    end
end

function IC.Fill(f, info, s)
    local PAD = IC.PAD
    local skull = setLevel(f.level, f.skull, info)
    local x = PAD + (skull and 13 or width(f.level, 14)) + 5
    setText(f.name, info.name)
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    f.name:ClearAllPoints()
    f.name:SetPoint("TOPLEFT", x, -6)
    x = x + width(f.name, 110)
    f.tag:Set(KT.Classification[info.cls])
    if f.tag:IsShown() then
        f.tag:ClearAllPoints()
        f.tag:SetPoint("TOPLEFT", x + 5, -8)
        x = x + 5 + f.tag:GetWidth()
    end
    local w = math.max(IC.MIN, x + PAD)

    local c = f.chips
    c.target:Set(s.lines.target and info.target or nil, info.targetColor)
    c.difficulty:Set(s.lines.difficulty and difficultyText(info) or nil, info.difficultyColor)
    c.quest:Set(s.lines.quests and questCount(info) or nil, T.gold)
    c.friends:Set(s.lines.friends and info.together or nil, T.teal)
    c.guild:Set(info.guild and ("<" .. info.guild .. ">") or nil, T.text)
    local cx, any = PAD, false
    for _, chip in ipairs(c) do
        if chip:IsShown() then
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", cx, -40)
            cx = cx + chip:GetWidth() + 8
            any = true
        end
    end
    w = math.max(w, cx - 8 + PAD)

    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", PAD, -25)
    f.bar:SetWidth(w - PAD * 2 - 34)
    Layouts.SetHealth(f.bar, info, true)
    return w, any and 60 or 42
end
