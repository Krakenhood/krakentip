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

--------------------------------------------------------------------------------
-- Fonts. A single font file only has the letters it was made for: the
-- game's own FRIZQT__.TTF has no Cyrillic, Korean or Chinese, so a Russian
-- name set in it shows as boxes. The game's text uses font families that
-- switch to a matching file for each alphabet; Wg.SetFont makes the same
-- kind of family for every size we use.
--------------------------------------------------------------------------------

local ALPHABET_LIST = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }

-- The file the game itself uses for each alphabet, read from its own font
-- family, so it's the file this client really has. Guessed names only when
-- the game can't say.
local GUESS = {
    roman = Wg.FONT,
    russian = "Fonts\\FRIZQT___CYR.TTF",
    korean = "Fonts\\2002.TTF",
    simplifiedchinese = "Fonts\\ARKai_T.ttf",
    traditionalchinese = "Fonts\\blei00d.TTF",
}
local gameFiles

local function readGameFiles()
    local files, from = {}, {}
    for _, alphabet in ipairs(ALPHABET_LIST) do
        for _, name in ipairs({ "GameFontHighlight", "GameFontNormal", "ChatFontNormal", "SystemFont_Shadow_Med1" }) do
            local base = _G[name]
            if not files[alphabet] and type(base) == "table" and base.GetFontObjectForAlphabet then
                local ok, obj = pcall(base.GetFontObjectForAlphabet, base, alphabet)
                local file = ok and obj and obj.GetFont and obj:GetFont()
                if type(file) == "string" and file ~= "" then files[alphabet], from[alphabet] = file, name end
            end
        end
        if not files[alphabet] then files[alphabet], from[alphabet] = GUESS[alphabet], "guess" end
    end
    return files, from
end

local function filesFor(kind)
    gameFiles = gameFiles or { readGameFiles() }
    local files = {}
    for k, v in pairs(gameFiles[1]) do files[k] = v end
    files.roman = Wg.FONT
    if kind == "title" then
        files.roman = "Fonts\\MORPHEUS.TTF"
        files.russian = "Fonts\\MORPHEUS_CYR.TTF"
    end
    return files
end

local families = {}

local function family(kind, size, flags)
    local key = kind .. size .. flags
    local font = families[key]
    if font ~= nil then return font end
    font = false
    if CreateFontFamily then
        local files, members = filesFor(kind), {}
        for _, alphabet in ipairs(ALPHABET_LIST) do
            members[#members + 1] = { alphabet = alphabet, file = files[alphabet], height = size, flags = flags }
        end
        local ok, f = pcall(CreateFontFamily, "KrakentipFont_" .. key:gsub("%W", ""), members)
        if ok and f then font = f end
    end
    families[key] = font
    return font
end

-- Without font families of our own: the game's text object closest in size,
-- which has every alphabet (the size is near, the outline is lost).
local GAME_SIZES = {
    { 10, "GameFontHighlightSmall" }, { 12, "GameFontHighlight" }, { 14, "GameFontHighlightMedium" }, { 16, "GameFontHighlightLarge" },
}
local function nearestGameFont(size)
    local best, bestD
    for _, g in ipairs(GAME_SIZES) do
        local d = math.abs(g[1] - size)
        if _G[g[2]] and (not bestD or d < bestD) then best, bestD = _G[g[2]], d end
    end
    return best
end

-- `kind` "normal" (the default) or "title" (the fantasy font).
function Wg.SetFont(fs, size, flags, kind)
    kind, flags = kind or "normal", flags or ""
    local font = family(kind, size, flags) or nearestGameFont(size)
    if font and pcall(fs.SetFontObject, fs, font) then return end
    if kind == "title" and pcall(fs.SetFont, fs, "Fonts\\MORPHEUS.TTF", size, flags) then return end
    fs:SetFont(Wg.FONT, kind == "title" and size - 2 or size, flags)
end

-- What /kt fonts prints: which file each alphabet gets, and where it came from.
function Wg.FontReport()
    local files, from = readGameFiles()
    local lines = { ("font families: %s"):format(CreateFontFamily and "yes" or "no (the game's own text objects instead)") }
    for _, alphabet in ipairs(ALPHABET_LIST) do
        lines[#lines + 1] = ("%s: %s (%s)"):format(alphabet, tostring(files[alphabet]), from[alphabet])
    end
    return lines
end

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
    Wg.SetFont(fs, size or 12, outline)
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
    Wg.SetFont(fs, size, "", "title")
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

-- The small look, for the compact cards: dark stone with a thin gold edge.
function Wg.ThinFrame(f, pad)
    pad = pad or 3
    local frame = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetPoint("TOPLEFT", -pad, pad)
    frame:SetPoint("BOTTOMRIGHT", pad, -pad)
    frame:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = Wg.FirstFile(KT.Files.thinEdge), edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(T.stone[1], T.stone[2], T.stone[3], T.stone[4])
        frame:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 0.85)
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
