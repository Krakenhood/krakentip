local ADDON, KT = ...
Krakentip = KT -- global handle, handy for /dump Krakentip.card

KT.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "0.1.0"

--------------------------------------------------------------------------------
-- Secret-value safety
--
-- Forever runs the Midnight "secret values" system: some reads come back as
-- opaque values that throw on arithmetic, comparison and even ==. The only
-- safe test is issecretvalue(), so every value we look at goes through clean()
-- and API calls go through call(). A secret read is treated as "don't know":
-- the line that needed it stays hidden. Values we only hand on to the game
-- (a status bar's value, a font string's text) may stay secret.
--------------------------------------------------------------------------------

local issecretvalue = issecretvalue

local function clean(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
KT.clean = clean

function KT.IsSecret(v) return issecretvalue and issecretvalue(v) or false end

function KT.call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return nil end
    return clean(a), clean(b), clean(c), clean(d), clean(e), clean(f)
end

-- Like call, but hands back the raw values, secrets included.
function KT.raw(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

--------------------------------------------------------------------------------
-- Chat output
--------------------------------------------------------------------------------

local PREFIX = "|cff4fd1c5Kraken|rtip:"

function KT:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. " " .. tostring(msg))
end

function KT:Printf(fmt, ...)
    self:Print(fmt:format(...))
end

--------------------------------------------------------------------------------
-- Events and internal messages
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local events, listeners, reported = {}, {}, {}

function KT:ReportError(err)
    err = tostring(clean(err) or "?")
    if reported[err] then return end
    reported[err] = true
    local handler = geterrorhandler and geterrorhandler()
    if handler then pcall(handler, err) end
end

local function dispatch(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then KT:ReportError(err) end
end
KT.dispatch = dispatch

-- RegisterEvent on an event this client doesn't have raises, so every
-- registration is protected.
function KT:On(event, fn)
    if not events[event] then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        events[event] = {}
    end
    table.insert(events[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = events[event]
    if not list then return end
    for i = 1, #list do dispatch(list[i], ...) end
end)

function KT:Listen(msg, fn)
    listeners[msg] = listeners[msg] or {}
    table.insert(listeners[msg], fn)
end

function KT:Fire(msg, ...)
    local list = listeners[msg]
    if not list then return end
    for i = 1, #list do dispatch(list[i], ...) end
end

--------------------------------------------------------------------------------
-- SavedVariables: KrakentipDB (account-wide) holds the settings.
--------------------------------------------------------------------------------

local function fill(t, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            fill(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
    return t
end

KT.POSITIONS = { "mouse", "tooltip" }

-- What a card can show, beyond the name, the level and the bar. Each look has
-- its own choice, saved in settings.fields where it differs from the default.
-- `off` lists the looks where a field starts switched off.
KT.FIELDS = {
    { key = "type", label = "Type, or race and class", hint = "\"Beast · Wolf\", \"Night Elf · Mage\"." },
    { key = "title", label = "NPC title", hint = "\"Innkeeper\", \"Weapon Merchant\"." },
    { key = "rank", label = "Elite, rare, boss", hint = "The badge, or the + after the level on Plate." },
    { key = "health", label = "Health numbers", hint = "The numbers or the percentage on the bar. The bar itself always shows." },
    { key = "target", label = "Who it's attacking", hint = "\"You\" in red when it's coming for you." },
    { key = "quests", label = "Your quest progress", hint = "Your objectives for this creature, or your count (\"3/8\") on the small looks." },
    { key = "group", label = "Your group's quests", hint = "Each group member's progress for this creature, under their name (\"Jokke 5/8\")." },
    { key = "other", label = "Zone and other lines", hint = "What else the game's tooltip says: a party member's zone when they're elsewhere, \"Skinnable\", \"AFK\"." },
    { key = "guild", label = "Guild", hint = "A player's guild.", off = { minimal = true, plate = true, bar = true, icons = true } },
    { key = "difficulty", label = "Difficulty in words", hint = "Trivial, Easy, Even, Hard, Very hard or Deadly. The level's colour says it anyway.", off = "all" },
    { key = "friends", label = "Krakenfriends kills", hint = "How often you and your Krakenfriends partner have killed this creature. Only with Krakenfriends loaded." },
}

-- This look's fields, every key true or false.
function KT:Fields(style)
    style = style or self.db.settings.style
    local chosen = self.db.settings.fields[style] or {}
    local out = {}
    for _, f in ipairs(self.FIELDS) do
        local v = chosen[f.key]
        if v == nil then v = not (f.off == "all" or (type(f.off) == "table" and f.off[style])) end
        out[f.key] = v
    end
    return out
end

function KT:SetField(key, on, style)
    style = style or self.db.settings.style
    local fields = self.db.settings.fields
    fields[style] = fields[style] or {}
    fields[style][key] = on and true or false
    self:Fire("SETTINGS")
end

-- Every field of this look back to its default.
function KT:ResetFields(style)
    self.db.settings.fields[style or self.db.settings.style] = nil
    self:Fire("SETTINGS")
end
KT.STYLES = { "regular", "mid", "minimal", "classic", "plate", "portrait", "bar", "icons" }

local DEFAULTS = {
    settings = {
        enabled = true,     -- false: units get the game's own tooltip
        style = "regular",  -- one of KT.STYLES (Layouts.lua)
        position = "mouse", -- "mouse": next to the cursor; "tooltip": where the game puts tooltips (Edit Mode moves it)
        scale = 1,
        minimap = { angle = 200, hide = false },
        dims = {},          -- per look: { w = 1, h = 1 }, its width and height factors
        bar = { texture = "smooth", color = "reaction" }, -- KT.BarTextures, KT.BarColors
        fields = {},        -- per look: { [field key] = true/false }, where it differs from KT.FIELDS' defaults
        window = {},
    },
}

function KT:LoadDB()
    local db = type(KrakentipDB) == "table" and KrakentipDB or {}
    fill(db, DEFAULTS)
    KrakentipDB = db
    self.db = db
    local s = db.settings
    if s.position ~= "mouse" and s.position ~= "tooltip" then s.position = "mouse" end
    if not KT.STYLE_LABEL[s.style] then s.style = "regular" end
    s.players = nil -- from 0.1.0: every unit gets the card now
    -- up to 0.5: one set of ticks for every look; what was switched off stays off in each
    if type(s.lines) == "table" then
        for _, style in ipairs(KT.STYLES) do
            local f = s.fields[style] or {}
            for _, key in ipairs({ "target", "quests", "friends", "other" }) do
                if s.lines[key] == false then f[key] = false end
            end
            if s.lines.quests == false then f.group = false end
            if s.lines.difficulty == true then f.difficulty = true end
            if next(f) then s.fields[style] = f end
        end
        s.lines = nil
    end
    s.scale = math.max(0.6, math.min(1.6, tonumber(s.scale) or 1))
end

KT:On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    KT:LoadDB()
end)

KT:On("PLAYER_LOGIN", function()
    if not KT.db then KT:LoadDB() end
    KT:Fire("SETUP")
end)

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local HELP = {
    { "/kt", "open or close the options" },
    { "/kt mouse", "show the card next to the mouse" },
    { "/kt tooltip", "show the card where the game puts tooltips (move that in Edit Mode)" },
    { "/kt style", "switch to the next look (or /kt style plate, see /kt styles)" },
    { "/kt styles", "list the looks" },
    { "/kt show group", "show or hide a field on this look (type, title, rank, health, target, quests, group, other, guild, difficulty, friends)" },
    { "/kt compare", "see every look side by side; hover a unit to fill them" },
    { "/kt width 1.2", "make this look wider or narrower (0.6 to 1.6)" },
    { "/kt height 0.8", "make this look taller or lower (0.6 to 1.6)" },
    { "/kt bar flat", "the bar's texture: smooth, flat, raid, skill" },
    { "/kt barcolor health", "the bar's colour: reaction, health, gold" },
    { "/kt scale 1.2", "make the card bigger or smaller (0.6 to 1.6)" },
    { "/kt sample", "show or hide a sample card, to try the settings" },
    { "/kt blizzard", "switch between the card and the game's own unit tooltips" },
    { "/kt minimap", "show or hide the minimap button" },
}

KT.STYLE_LABEL = {
    regular = "Regular", mid = "Mid", minimal = "Minimal", classic = "Classic",
    plate = "Plate", portrait = "Portrait", bar = "Bar", icons = "Icons",
}
KT.STYLE_HINT = {
    regular = "The full card: a big bar and a line for each thing.",
    mid = "Name, type and target at a glance, a thin bar.",
    minimal = "Two short lines: name, then bar, type, quest and target.",
    classic = "The game's own tooltip, line by line, in gold.",
    plate = "Small and centred, like a nameplate.",
    portrait = "Like the target frame, with the unit's face.",
    bar = "The health bar is the card, the name on it.",
    icons = "Name and bar, the details as small icons.",
}

KT.POSITION_LABEL = {
    mouse = "next to the mouse",
    tooltip = "where the game puts tooltips",
}

function KT:SetPosition(where)
    self.db.settings.position = where
    self:Printf("Enemy card %s.", self.POSITION_LABEL[where])
    self:Fire("SETTINGS")
end

function KT:SetEnabled(on)
    self.db.settings.enabled = on
    self:Print(on and "Units get the Kraken card." or "Units get the game's own tooltip (/kt blizzard switches back).")
    self:Fire("SETTINGS")
end

-- This look's width or height factor ("w" or "h"), 0.6 to 1.6.
function KT:Dim(which, style)
    local d = self.db.settings.dims[style or self.db.settings.style]
    return d and d[which] or 1
end

function KT:SetDim(which, value, style)
    style = style or self.db.settings.style
    local dims = self.db.settings.dims
    dims[style] = dims[style] or {}
    value = math.floor(math.max(0.6, math.min(1.6, value)) * 10 + 0.5) / 10
    dims[style][which] = value ~= 1 and value or nil
    self:Fire("SETTINGS")
end

-- The bar's texture or colour: `field` "texture" or "color", `key` from
-- KT.BarTextures or KT.BarColors; nil steps to the next one.
function KT:SetBar(field, key, step)
    local list = field == "texture" and self.BarTextures or self.BarColors
    local bar = self.db.settings.bar
    local now = 1
    for i, it in ipairs(list) do if it.key == bar[field] then now = i end end
    if not key then key = list[(now - 1 + (step or 1)) % #list + 1].key end
    for _, it in ipairs(list) do
        if it.key == key then
            bar[field] = key
            return self:Fire("SETTINGS")
        end
    end
    local keys = {}
    for _, it in ipairs(list) do keys[#keys + 1] = it.key end
    self:Print("Choose one of: " .. table.concat(keys, ", ") .. ".")
end

-- `style` nil: the next look in line
function KT:SetStyle(style)
    local s = self.db.settings
    if not style then
        for i, st in ipairs(self.STYLES) do
            if st == s.style then style = self.STYLES[i % #self.STYLES + 1] end
        end
    end
    if not self.STYLE_LABEL[style] then return self:Print("Styles: " .. table.concat(self.STYLES, ", ") .. ".") end
    s.style = style
    self:Printf("Card style: %s.", self.STYLE_LABEL[style])
    self:Fire("SETTINGS")
end

local commands = {
    mouse = function() KT:SetPosition("mouse") end,
    cursor = function() KT:SetPosition("mouse") end,
    tooltip = function() KT:SetPosition("tooltip") end,
    on = function() KT:SetEnabled(true) end,
    off = function() KT:SetEnabled(false) end,
    blizzard = function() KT:SetEnabled(not KT.db.settings.enabled) end,
    -- /kt show group: switch a field of this look on or off
    show = function(arg)
        for _, f in ipairs(KT.FIELDS) do
            if f.key == arg then
                local on = not KT:Fields()[arg]
                KT:SetField(arg, on)
                return KT:Printf("%s: %s on %s.", f.label, on and "shown" or "hidden", KT.STYLE_LABEL[KT.db.settings.style])
            end
        end
        local keys = {}
        for _, f in ipairs(KT.FIELDS) do keys[#keys + 1] = f.key end
        KT:Print("/kt show <field>, one of: " .. table.concat(keys, ", ") .. ".")
    end,
    style = function(arg) KT:SetStyle(arg ~= "" and arg or nil) end,
    styles = function()
        KT:Print("looks (/kt style <name>):")
        for _, st in ipairs(KT.STYLES) do
            KT:Print(("  |cffffd100%s|r%s  %s"):format(st, st == KT.db.settings.style and " (now)" or "", KT.STYLE_HINT[st]))
        end
    end,
    compare = function() KT.Compare:Toggle() end,
    fonts = function()
        KT:Print("fonts:")
        for _, line in ipairs(KT.Widgets.FontReport()) do KT:Print("  " .. line) end
    end,
    width = function(arg)
        local n = tonumber(arg)
        if not n then return KT:Printf("Width of this look: %d%%. Use /kt width 0.6 to 1.6.", KT:Dim("w") * 100) end
        KT:SetDim("w", n)
    end,
    height = function(arg)
        local n = tonumber(arg)
        if not n then return KT:Printf("Height of this look: %d%%. Use /kt height 0.6 to 1.6.", KT:Dim("h") * 100) end
        KT:SetDim("h", n)
    end,
    bar = function(arg) KT:SetBar("texture", arg ~= "" and arg or nil) end,
    barcolor = function(arg) KT:SetBar("color", arg ~= "" and arg or nil) end,
    minimap = function()
        local m = KT.db.settings.minimap
        m.hide = not m.hide
        KT:Fire("SETTINGS")
    end,
    scale = function(arg)
        local n = tonumber(arg)
        if not n then return KT:Printf("Card scale is %.2f. Use /kt scale 0.6 to 1.6.", KT.db.settings.scale) end
        KT.db.settings.scale = math.max(0.6, math.min(1.6, n))
        KT:Printf("Card scale %.2f.", KT.db.settings.scale)
        KT:Fire("SETTINGS")
    end,
    sample = function() KT.Card:ToggleSample() end,
    help = function()
        KT:Print("commands:")
        for _, h in ipairs(HELP) do KT:Print(("  |cffffd100%s|r  %s"):format(h[1], h[2])) end
    end,
}

SLASH_KRAKENTIP1 = "/kt"
SLASH_KRAKENTIP2 = "/krakentip"
SlashCmdList.KRAKENTIP = function(msg)
    if not KT.db then return KT:Print("not ready yet.") end
    msg = strtrim(tostring(msg or "")):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" then
        KT.Options:Toggle()
    elseif commands[cmd] then
        commands[cmd](arg)
    elseif KT.STYLE_LABEL[cmd] then
        KT:SetStyle(cmd) -- /kt plate, /kt minimal
    else
        commands.help()
    end
end

function Krakentip_OnAddonCompartmentClick()
    SlashCmdList.KRAKENTIP("")
end
