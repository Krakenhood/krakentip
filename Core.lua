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

local DEFAULTS = {
    settings = {
        enabled = true,
        position = "mouse", -- "mouse": next to the cursor; "tooltip": where the game puts tooltips (Edit Mode moves it)
        scale = 1,
        players = false,    -- enemy players too, not just creatures
        lines = {
            target = true,  -- who it's attacking
            difficulty = true,
            quests = true,  -- quest progress from the game's tooltip
            friends = true, -- kills together, from Krakenfriends
        },
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
    { "/kt scale 1.2", "make the card bigger or smaller (0.6 to 1.6)" },
    { "/kt sample", "show or hide a sample card, to try the settings" },
    { "/kt off", "give enemies the game's own tooltip again (/kt on undoes it)" },
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
    self:Print(on and "Enemies get the Kraken card." or "Enemies get the game's own tooltip.")
    self:Fire("SETTINGS")
end

local commands = {
    mouse = function() KT:SetPosition("mouse") end,
    cursor = function() KT:SetPosition("mouse") end,
    tooltip = function() KT:SetPosition("tooltip") end,
    on = function() KT:SetEnabled(true) end,
    off = function() KT:SetEnabled(false) end,
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
    else
        commands.help()
    end
end

function Krakentip_OnAddonCompartmentClick()
    SlashCmdList.KRAKENTIP("")
end
