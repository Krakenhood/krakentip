local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets

--------------------------------------------------------------------------------
-- The options window: where the card shows, what's on it, how big it is, and a
-- sample card to try it all without a creature under the mouse.
--------------------------------------------------------------------------------

local Options = {}
KT.Options = Options

local WIDTH, HEIGHT = 360, 540 -- the height follows the content
local PAD = 18

-- A label and "- value +" (or "< value >"): returns the font string for the value.
local function stepper(f, label, x, y, valueWidth, onStep, arrows)
    local l = Wg.Text(f, 12, T.text)
    l:SetPoint("TOPLEFT", x, -(y + 4))
    l:SetText(label)
    local minus = Wg.TextButton(f, arrows and "<" or "-", 14)
    minus:SetSize(22, 22)
    minus:SetPoint("TOPLEFT", x + 52, -y)
    local value = Wg.Text(f, 12, T.gold, "CENTER")
    value:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    value:SetWidth(valueWidth)
    local plus = Wg.TextButton(f, arrows and ">" or "+", 14)
    plus:SetSize(22, 22)
    plus:SetPoint("LEFT", value, "RIGHT", 2, 0)
    minus:SetScript("OnClick", function() onStep(-1) end)
    plus:SetScript("OnClick", function() onStep(1) end)
    value.minus, value.plus = minus, plus
    return value
end

local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end

local function heading(f, text, y)
    local h = Wg.Text(f, 13, T.gold)
    h:SetPoint("TOPLEFT", PAD, -y)
    h:SetText(text)
    local line = Wg.Solid(f, "ARTWORK", T.line)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", PAD, -(y + 17))
    line:SetPoint("TOPRIGHT", -PAD, -(y + 17))
    return h
end

function Options:Create()
    if self.frame then return end
    local s = KT.db.settings
    local f = CreateFrame("Frame", "KrakentipOptions", UIParent)
    self.frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint()
        KT.db.settings.window = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    f:SetScript("OnShow", function()
        Options:Refresh()
        if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end
    end)
    f:SetScript("OnHide", function()
        KT.Card:ToggleSample(false)
        if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end
    end)
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "KrakentipOptions") end

    local pos = s.window
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", -120, 40)
    end

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
    sub:SetText("a card for every creature and player")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)

    -- where
    local y = 40
    heading(f, "Where the card shows", y)
    y = y + 26
    self.position = Wg.Radio(f, {
        { "mouse", "Next to the mouse", "Follows the cursor, so your eyes stay on the fight." },
        { "tooltip", "Where the game puts tooltips", "Move that spot in Edit Mode, like any tooltip." },
    }, function() return KT.db.settings.position end, function(v) KT.db.settings.position = v end)
    self.position:SetPoint("TOPLEFT", f, "TOPLEFT", PAD - 2, -y)
    y = y + self.position.height + 8

    -- the look
    heading(f, "Style", y)
    y = y + 26
    -- the looks: step through them here, or see them all in Compare
    local prev = Wg.TextButton(f, "<", 14)
    prev:SetSize(24, 22)
    prev:SetPoint("TOPLEFT", PAD - 4, -y)
    local styleName = Wg.Text(f, 13, T.gold, "CENTER")
    styleName:SetPoint("LEFT", prev, "RIGHT", 2, 0)
    styleName:SetWidth(110)
    local nextB = Wg.TextButton(f, ">", 14)
    nextB:SetSize(24, 22)
    nextB:SetPoint("LEFT", styleName, "RIGHT", 2, 0)
    local function step(d)
        local list, now = KT.STYLES, 1
        for i, st in ipairs(list) do if st == KT.db.settings.style then now = i end end
        KT:SetStyle(list[(now - 1 + d) % #list + 1])
    end
    prev:SetScript("OnClick", function() step(-1) end)
    nextB:SetScript("OnClick", function() step(1) end)
    local compare = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    compare:SetSize(130, 22)
    compare:SetPoint("TOPRIGHT", -PAD, -y)
    compare:SetText("Compare all")
    compare:SetScript("OnClick", function() KT.Compare:Toggle() end)
    local styleHint = Wg.Text(f, 11, T.dim)
    styleHint:SetPoint("TOPLEFT", PAD + 2, -(y + 26))
    self.styleName, self.styleHint, self.compareButton, self.stylePrev, self.styleNext = styleName, styleHint, compare, prev, nextB
    y = y + 46

    -- this look's width and height
    self.widthText = stepper(f, "Width", PAD + 2, y, 44, function(d) KT:SetDim("w", KT:Dim("w") + d / 10) end)
    self.heightText = stepper(f, "Height", PAD + 170, y, 44, function(d) KT:SetDim("h", KT:Dim("h") + d / 10) end)
    y = y + 30

    -- the health bar
    heading(f, "Health bar", y)
    y = y + 26
    self.textureText = stepper(f, "Texture", PAD + 2, y, 110, function(d) KT:SetBar("texture", nil, d) end, true)
    y = y + 26
    self.colorText = stepper(f, "Colour", PAD + 2, y, 110, function(d) KT:SetBar("color", nil, d) end, true)
    y = y + 32

    -- what
    heading(f, "On the card", y)
    y = y + 24
    self.checks = {}
    local function check(label, key, tooltip, t)
        t = t or KT.db.settings.lines
        local cb = Wg.Check(f, label, function() return t[key] end, function(v) t[key] = v end, tooltip)
        cb:SetPoint("TOPLEFT", PAD - 4, -y)
        y = y + 24
        self.checks[#self.checks + 1] = cb
        return cb
    end
    check("Who it's attacking", "target", "\"Targeting: You\" in red when it's coming for you.")
    check("How hard it is, in words", "difficulty", "Trivial, Easy, Even, Hard, Very hard or Deadly, on the Regular and Classic cards. Every look colours the level that way anyway.")
    check("Quest progress", "quests", "The quest lines the game's tooltip shows for this creature, yours and your group's.")
    check("Other lines from the game", "other", "What else the game's tooltip says: a party member's zone when they're elsewhere, \"Skinnable\", \"AFK\". On Regular, Mid, Classic and Portrait.")
    self.friends = check("Kills with your Krakenfriends partner", "friends", "How often you and your Krakenfriends partner have killed this creature. Only shows when Krakenfriends is loaded and you two have killed it.")
    y = y + 6

    -- the card
    heading(f, "The card", y)
    y = y + 24
    check("Use the Kraken card", "enabled", "Off: creatures and players get the game's own tooltip again (/kt blizzard).", KT.db.settings)

    self.scaleText = stepper(f, "Scale", PAD + 2, y, 44, function(d)
        local st = KT.db.settings
        st.scale = math.max(0.6, math.min(1.6, math.floor((st.scale + d / 10) * 10 + 0.5) / 10))
        KT:Fire("SETTINGS")
    end)
    y = y + 34

    -- try it
    local sample = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sample:SetSize(180, 24)
    sample:SetPoint("TOPLEFT", PAD, -y)
    sample:SetScript("OnClick", function()
        KT.Card:ToggleSample()
        Options:Refresh()
    end)
    self.sampleButton = sample
    local note = Wg.Text(f, 11, T.dim)
    note:SetPoint("LEFT", sample, "RIGHT", 10, 0)
    note:SetText("/kt sample does the same")
    self.note = note
    f:SetHeight(y + 24 + PAD)
end

function Options:Refresh()
    if not self.frame then return end
    local s = KT.db.settings
    self.position:Refresh()
    local i = 1
    for n, st in ipairs(KT.STYLES) do if st == s.style then i = n end end
    self.styleName:SetText(("%s  %d/%d"):format(KT.STYLE_LABEL[s.style], i, #KT.STYLES))
    self.styleHint:SetText(KT.STYLE_HINT[s.style])
    for _, cb in ipairs(self.checks) do
        local onShow = cb:GetScript("OnShow")
        if onShow then onShow(cb) end
    end
    local hasFriends = type(Krakenfriends) == "table"
    self.friends.label:SetTextColor(Wg.rgb(hasFriends and T.text or T.faint))
    self.scaleText:SetText(pct(s.scale))
    self.widthText:SetText(pct(KT:Dim("w")))
    self.heightText:SetText(pct(KT:Dim("h")))
    for _, t in ipairs(KT.BarTextures) do if t.key == s.bar.texture then self.textureText:SetText(t.label) end end
    for _, c in ipairs(KT.BarColors) do if c.key == s.bar.color then self.colorText:SetText(c.label) end end
    self.sampleButton:SetText(KT.Card:IsSampleShown() and "Hide the sample card" or "Show a sample card")
end

function Options:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end

KT:Listen("SETTINGS", function() Options:Refresh() end)
KT:Listen("SAMPLE", function() Options:Refresh() end)

--------------------------------------------------------------------------------
-- An entry under Options > AddOns that opens the window.
--------------------------------------------------------------------------------

local function registerPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Krakentip"
    local title = Wg.Title(panel, 18)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Krakentip")
    local text = Wg.Text(panel, 12, T.dim)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetText("Enemies get a card in the game's own style. Every other tooltip stays as it is.")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 24)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
    open:SetText("Open the Krakentip options")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        Options:Create()
        Options.frame:Show()
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Krakentip")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

KT:Listen("SETUP", function() pcall(registerPanel) end)
