local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets
local Layouts = KT.Layouts
local raw = KT.raw

--------------------------------------------------------------------------------
-- Every look side by side, to find the one that suits you. It shows the
-- sample creature until you hover a unit; then every look shows that unit.
-- Click a look to use it.
--------------------------------------------------------------------------------

local Compare = {}
KT.Compare = Compare

local PAD, GAP, LABEL = 16, 12, 16
local COL_W = 340 -- the widest looks (Wide, Minimal with a long name) fit
local TOP = 52    -- under the title and the line that says what's shown

local function Cell(parent, style)
    local cell = CreateFrame("Button", nil, parent)
    cell.style = style
    cell.hl = Wg.Solid(cell, "BACKGROUND", T.hover)
    cell.hl:SetAllPoints()
    cell.hl:Hide()
    cell.label = Wg.Text(cell, 12, T.dim)
    cell.label:SetPoint("TOPLEFT", 4, -2)
    cell.hint = Wg.Text(cell, 10, T.faint)
    cell.hint:SetPoint("LEFT", cell.label, "RIGHT", 8, 0)
    cell.hint:SetText(KT.STYLE_HINT[style])
    local card = CreateFrame("Frame", nil, cell)
    card:SetPoint("TOPLEFT", 4, -(LABEL + 10)) -- room for the gold frames that reach out of the card
    Layouts[style].Create(card)
    cell.card = card
    cell:SetScript("OnEnter", function() cell.hl:Show() end)
    cell:SetScript("OnLeave", function() cell.hl:Hide() end)
    cell:SetScript("OnClick", function() KT:SetStyle(style) end)
    return cell
end

function Compare:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "KrakentipCompare", UIParent)
    self.frame = f
    f:SetSize(COL_W * 2 + PAD * 2 + GAP, 600)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScale(0.9)
    f:SetPoint("CENTER")
    f:Hide()
    f:SetScript("OnShow", function() Compare:Fill() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "KrakentipCompare") end

    Wg.DialogFrame(f)
    local band = Wg.Solid(f, "BACKGROUND", T.band, nil, 1)
    band:SetPoint("TOPLEFT", 2, -2)
    band:SetPoint("TOPRIGHT", -2, -2)
    band:SetHeight(26)
    local title = Wg.Title(f, 18)
    title:SetPoint("TOPLEFT", PAD, -7)
    title:SetText("Krakentip")
    local sub = Wg.Text(f, 11, T.dim)
    sub:SetPoint("LEFT", title, "RIGHT", 8, -1)
    sub:SetText("every look side by side. Click one to use it.")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)
    self.showing = Wg.Text(f, 12, T.text)
    self.showing:SetPoint("TOPLEFT", PAD, -32)

    self.cells = {}
    for _, style in ipairs(KT.STYLES) do self.cells[#self.cells + 1] = Cell(f, style) end
end

-- what the looks show: the last unit hovered, or the sample
local function sample()
    local info = {}
    for k, v in pairs(KT.Sample) do info[k] = v end
    info.targetColor = T.bad
    info.difficulty, info.difficultyColor, info.diff = "Hard", { 1.00, 0.50, 0.25 }, 3
    info.quests = {}
    for i, q in ipairs(KT.Sample.quests) do info.quests[i] = q end
    return info
end

function Compare:Fill()
    if not (self.frame and self.frame:IsShown()) then return end
    local info = self.info or sample()
    local s = KT.db.settings
    if self.info then
        self.showing:SetText("Showing the unit you hovered last. Hover another to compare.")
    else
        self.showing:SetText("Showing a sample wolf. Hover any creature or player to see it in every look.")
    end

    -- each look into the shorter of two columns
    local heights = { TOP, TOP }
    for _, cell in ipairs(self.cells) do
        local w, h = Layouts[cell.style].Fill(cell.card, info, s)
        cell.card:SetSize(w, h)
        local now = cell.style == s.style
        cell.label:SetText(KT.STYLE_LABEL[cell.style] .. (now and "  (in use)" or ""))
        cell.label:SetTextColor(Wg.rgb(now and T.gold or T.dim))
        local col = heights[1] <= heights[2] and 1 or 2
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", PAD + (col - 1) * (COL_W + GAP), -heights[col])
        cell:SetSize(COL_W, LABEL + 10 + h + 8)
        heights[col] = heights[col] + LABEL + 10 + h + 8 + GAP
    end
    self.frame:SetHeight(math.max(heights[1], heights[2]) + PAD - GAP)
end

-- A unit's card was filled: keep what it showed, so the looks can show it
-- after the mouse has left the unit.
function Compare:Take(info)
    if not (self.frame and self.frame:IsShown()) then return end
    local copy = {}
    for k, v in pairs(info) do copy[k] = v end
    if info.unit then
        copy.hp, copy.hpMax = raw(UnitHealth, info.unit), raw(UnitHealthMax, info.unit)
        copy.portraitUnit = info.unit
        copy.unit = nil
    end
    self.info = copy
    self:Fill()
end

function Compare:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end

KT:Listen("CARD", function(info) Compare:Take(info) end)
KT:Listen("SETTINGS", function() Compare:Fill() end)
