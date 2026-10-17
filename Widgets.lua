local _, KT = ...
local call = KT.call
local T = KT.Theme

--------------------------------------------------------------------------------
-- Drawing helpers shared by the card and the options window, all in the game's
-- own look: gold borders, dark stone, the fantasy font for titles.
--------------------------------------------------------------------------------

local Wg = {}
KT.Widgets = Wg

Wg.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function Wg.rgb(c) return c[1], c[2], c[3] end

-- the first file the client actually has (a missing file shows as a green square)
local fileCache = {}
function Wg.FirstFile(list)
    for _, path in ipairs(list) do
        local id = fileCache[path]
        if id == nil then
            id = (not GetFileIDFromPath) and true or (call(GetFileIDFromPath, path) or false)
            fileCache[path] = id
        end
        if id then return path end
    end
    return list[#list]
end

function Wg.Solid(parent, layer, color, alpha, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
    return t
end

function Wg.Text(parent, size, color, justify, outline)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Wg.FONT, size or 12, outline or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    fs:SetTextColor(Wg.rgb(color or T.text))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- A title in the game's fantasy font and gold, with a fallback if the font is missing.
function Wg.Title(parent, size)
    local fs = Wg.Text(parent, size, T.gold)
    if not pcall(fs.SetFont, fs, KT.Files.titleFont, size, "") then fs:SetFont(Wg.FONT, size - 2, "") end
    return fs
end

-- The big look: dark stone inside the gold dialog border, drawn around `f`.
function Wg.DialogFrame(f)
    local frame = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetPoint("TOPLEFT", -7, 7)
    frame:SetPoint("BOTTOMRIGHT", 7, -7)
    frame:SetFrameLevel(math.max(0, f:GetFrameLevel()))
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = Wg.FirstFile(KT.Files.back), tile = true, tileSize = 256,
            edgeFile = Wg.FirstFile(KT.Files.edge), edgeSize = 32,
            insets = { left = 9, right = 9, top = 9, bottom = 9 },
        })
        frame:SetBackdropColor(0.55, 0.55, 0.55, 1)
    end
    return frame
end

-- A flat text button in the gold style (tabs, links).
function Wg.TextButton(parent, label, size)
    local b = CreateFrame("Button", nil, parent)
    b.text = Wg.Text(b, size or 12, T.dim, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetSize(math.max(40, (b.text:GetStringWidth() or 40) + 16), (size or 12) + 10)
    b.hl = Wg.Solid(b, "BACKGROUND", T.hover)
    b.hl:SetAllPoints()
    b.hl:Hide()
    b:SetScript("OnEnter", function() b.hl:Show() end)
    b:SetScript("OnLeave", function() b.hl:Hide() end)
    function b:SetActive(on)
        self.active = on
        self.text:SetTextColor(Wg.rgb(on and T.gold or T.dim))
    end
    return b
end

-- A tick box with a label. `get` and `set` read and write the setting.
function Wg.Check(parent, label, get, set, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb.label = Wg.Text(cb, 12, T.text)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        KT:Fire("SETTINGS")
    end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    cb:SetChecked(get() and true or false)
    return cb
end

-- One choice out of several: round buttons with labels, one row each.
-- `choices` is a list of { value, label, hint }.
function Wg.Radio(parent, choices, get, set)
    local group = { buttons = {} }
    local y = 0
    for _, c in ipairs(choices) do
        local rb = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
        rb:SetSize(18, 18)
        rb.value = c[1]
        rb.label = Wg.Text(rb, 12, T.text)
        rb.label:SetPoint("LEFT", rb, "RIGHT", 4, 0)
        rb.label:SetText(c[2])
        if c[3] then
            rb.hint = Wg.Text(rb, 11, T.dim)
            rb.hint:SetPoint("TOPLEFT", rb.label, "BOTTOMLEFT", 0, -2)
            rb.hint:SetText(c[3])
        end
        rb.offset = y
        y = y + (c[3] and 36 or 22)
        rb:SetScript("OnClick", function()
            set(c[1])
            group:Refresh()
            KT:Fire("SETTINGS")
        end)
        group.buttons[#group.buttons + 1] = rb
    end
    group.height = y
    function group:SetPoint(point, rel, relPoint, x, yy)
        for _, rb in ipairs(self.buttons) do rb:SetPoint(point, rel, relPoint, x, yy - rb.offset) end
    end
    function group:Refresh()
        local v = get()
        for _, rb in ipairs(self.buttons) do rb:SetChecked(rb.value == v) end
    end
    group:Refresh()
    return group
end
