-- Minimal WoW API mock for headless testing of Krakentip (runs on fengari / Lua 5.3)
unpack = table.unpack
ERRORS = {}
CHAT = {}

local function noop() end

-- secrets -------------------------------------------------------------------
SECRET = setmetatable({}, { __tostring = function() error("touched a secret") end,
    __eq = function() error("compared a secret") end, __concat = function() error("concat secret") end,
    __lt = function() error("compared a secret") end, __le = function() error("compared a secret") end,
    __add = function() error("added a secret") end, __div = function() error("divided a secret") end })
function issecretvalue(v) return rawequal(v, SECRET) end

-- frames ---------------------------------------------------------------------
local eventFrames = {}
local Object = {}
Object.__index = function(t, k)
    local m = Object[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") then return noop end
    return nil
end
local function new(kind, parent, name)
    return setmetatable({ _kind = kind, _parent = parent, _name = name, _shown = true, _w = 0, _h = 0, _alpha = 1, _scale = 1,
        _scripts = {}, _events = {}, _points = {} }, Object)
end
function Object:SetSize(w, h) rawset(self, "_w", w); rawset(self, "_h", h) end
function Object:SetWidth(w) rawset(self, "_w", w) end
function Object:SetHeight(h) rawset(self, "_h", h) end
function Object:GetWidth() return self._w end
function Object:GetHeight() return self._h end
function Object:GetName() return self._name end
function Object:Show() local was = self._shown; rawset(self, "_shown", true); local s = self._scripts.OnShow; if s and not was then s(self) end end
function Object:Hide() local was = self._shown; rawset(self, "_shown", false); local s = self._scripts.OnHide; if s and was then s(self) end end
function Object:SetShown(v) if v then self:Show() else self:Hide() end end
function Object:IsShown() return self._shown end
function Object:IsVisible() return self._shown end
function Object:SetScript(name, fn) self._scripts[name] = fn end
function Object:GetScript(name) return self._scripts[name] end
function Object:HookScript(name, fn)
    local old = self._scripts[name]
    self._scripts[name] = old and function(...) old(...); fn(...) end or fn
end
function Object:RegisterEvent(e)
    if not KNOWN_EVENTS[e] then error("unknown event " .. e) end
    self._events[e] = true
    eventFrames[self] = true
end
function Object:CreateTexture() return new("Texture", self) end
function Object:CreateFontString() local fs = new("FontString", self); rawset(fs, "_text", ""); rawset(fs, "_color", { 1, 1, 1 }); return fs end
function Object:GetParent() return self._parent end
function Object:SetText(t)
    if t ~= nil and type(t) ~= "string" and type(t) ~= "number" and not rawequal(t, SECRET) then error("SetText wants text, got " .. type(t)) end
    rawset(self, "_text", t)
end
function Object:SetFormattedText(fmt, ...)
    for i = 1, select("#", ...) do if rawequal(select(i, ...), SECRET) then rawset(self, "_text", "<secret>"); return end end
    rawset(self, "_text", fmt:format(...))
end
function Object:GetText() return self._text end
function Object:SetTextColor(r, g, b) rawset(self, "_color", { r, g, b }) end
function Object:GetTextColor() local c = self._color or { 1, 1, 1 }; return c[1], c[2], c[3] end
-- about as wide as the game's font draws it: half the size per letter, colour codes left out
function Object:GetStringWidth()
    if rawequal(self._text, SECRET) then return SECRET end
    local t = tostring(self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return math.floor(utf8.len(t) * (self._size or 12) * 0.52 + 0.5)
end
function Object:SetAlpha(a) rawset(self, "_alpha", a) end
function Object:GetAlpha() return self._alpha end
function Object:SetScale(s) rawset(self, "_scale", s) end
function Object:GetScale() return self._scale end
function Object:GetEffectiveScale() return self._scale end
function Object:ClearAllPoints() rawset(self, "_points", {}) end
function Object:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, point, rel, relPoint end
    table.insert(self._points, { point, rel, relPoint, x or 0, y or 0 })
end
function Object:GetPoint(i)
    local p = self._points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Object:SetMinMaxValues(a, b) rawset(self, "_min", a); rawset(self, "_max", b) end
function Object:SetValue(v) rawset(self, "_value", v) end
function Object:SetStatusBarColor(r, g, b) rawset(self, "_color", { r, g, b }) end
function Object:GetValue() return self._value end
function Object:SetChecked(v) rawset(self, "_checked", v) end
function Object:GetChecked() return self._checked end
function Object:SetFont(_, size) rawset(self, "_size", size); return true end
function Object:SetTexture(t) rawset(self, "_tex", t) end
-- font families: one file per alphabet, as the game builds them
FONT_FAMILIES = {}
function CreateFontFamily(name, members)
    if FONT_FAMILIES[name] then error("a font family called " .. name .. " exists already") end
    local f = { _name = name, _members = members, _size = members[1].height }
    FONT_FAMILIES[name] = f
    return f
end
function Object:SetFontObject(f) rawset(self, "_size", f._size); rawset(self, "_family", f) end
-- the game's own text object, a family whose Korean file isn't the one we'd guess
GAME_ALPHABET_FILES = { roman = "Fonts\\FRIZQT__.TTF", russian = "Fonts\\FRIZQT___CYR.TTF", korean = "Fonts\\K_Pagetext.TTF",
    simplifiedchinese = "Fonts\\ARHei.ttf", traditionalchinese = "Fonts\\bHEI01B.TTF" }
GameFontHighlight = { _size = 12, GetFontObjectForAlphabet = function(_, a)
    return { GetFont = function() return GAME_ALPHABET_FILES[a], 12, "" end }
end }
GameFontHighlightSmall = { _size = 10 }

function CreateFrame(kind, name, parent, template)
    local f = new(kind or "Frame", parent, name)
    if kind ~= "GameTooltip" then rawset(f, "_shown", true) end
    if name then _G[name] = f end
    return f
end
function FireEvent(e, ...)
    for f in pairs(eventFrames) do
        if f._events[e] and f._scripts.OnEvent then f._scripts.OnEvent(f, e, ...) end
    end
end
function Click(btn, which)
    local s = btn._scripts.OnClick
    if s then s(btn, which or "LeftButton") end
end

UIParent = CreateFrame("Frame", "UIParent"); UIParent:SetSize(1920, 1080)
Minimap = CreateFrame("Frame", "Minimap"); Minimap:SetSize(140, 140)
function Object:GetCenter() return 100, 100 end
function Object:GetFrameLevel() return 1 end
function Object:IsMouseOver() return self._over or false end
function Object:SetJustifyH(j) rawset(self, "_justify", j) end
DEFAULT_CHAT_FRAME = CreateFrame("Frame")
function DEFAULT_CHAT_FRAME:AddMessage(msg)
    msg = tostring(msg):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    CHAT[#CHAT + 1] = msg
    print("  [chat] " .. msg)
end
UISpecialFrames = {}
SlashCmdList = {}
function geterrorhandler() return function(err) ERRORS[#ERRORS + 1] = err; print("  !! ERROR: " .. tostring(err)) end end
function PlaySound() end
SOUNDKIT = { IG_CHARACTER_INFO_OPEN = 1, IG_CHARACTER_INFO_CLOSE = 2 }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function GetFileIDFromPath(p) return 100000 + #p end
CURSOR = { 400, 300 }
function GetCursorPosition() return CURSOR[1], CURSOR[2] end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return table.unpack(out)
end
function BreakUpLargeNumbers(n)
    local s, k = tostring(math.floor(n)), nil
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, ROGUE = { r = 1, g = 0.96, b = 0.41 } }
C_AddOns = { GetAddOnMetadata = function() return "0.1.0-test" end }
function GetQuestGreenRange() return 8 end
SHIFT = false
function IsShiftKeyDown() return SHIFT end
function SetPortraitTexture(tex, unit) if not UnitExists(unit) then error("no unit") end tex:SetTexture("portrait:" .. unit) end

-- timers: C_Timer.After(0) runs on the next frame, NextFrame() plays it
TIMERS = {}
C_Timer = { After = function(sec, fn) TIMERS[#TIMERS + 1] = fn end }
function NextFrame()
    local due = TIMERS
    TIMERS = {}
    for _, fn in ipairs(due) do fn() end
end
function hooksecurefunc(t, name, fn)
    local old = t[name]
    rawset(t, name, function(...) local a, b, c = old(...); fn(...); return a, b, c end)
end

-- the game's tooltip ------------------------------------------------------------
-- SetUnit/SetItem act like the game: clear, fill lines, run the post-calls, show.
Enum = {
    TooltipDataType = { Item = 0, Spell = 1, Unit = 2 },
    TooltipDataLineType = { None = 0, QuestObjective = 8, QuestTitle = 17, QuestPlayer = 18 },
}
local postCalls = {}
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn) postCalls[kind] = postCalls[kind] or {}; table.insert(postCalls[kind], fn) end,
}
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
rawset(GameTooltip, "_shown", false)
rawset(GameTooltip, "_lines", {})
function GameTooltip:NumLines() return #self._lines end
-- TIP_TOKEN: the token the game reports, when it names the unit differently ("target")
function GameTooltip:GetUnit() if self._unit then return UnitName(self._unit), TIP_TOKEN or self._unit end end
local function clearTip(tip)
    rawset(tip, "_unit", nil)
    rawset(tip, "_lines", {})
    local s = tip._scripts.OnTooltipCleared
    if s then s(tip) end
end
function GameTooltip:SetOwner(owner)
    rawset(self, "_owner", owner)
    clearTip(self)
end
function GameTooltip:GetOwner() return self._owner end
function GameTooltip:IsOwned(f) return self._owner == f end
function GameTooltip:AddLine(text)
    local i = #self._lines + 1
    local fs = _G["GameTooltipTextLeft" .. i] or CreateFrame("FontString", "GameTooltipTextLeft" .. i)
    fs:SetText(text)
    self._lines[i] = { leftText = text }
end
local function setLines(tip, lines)
    for i, l in ipairs(lines) do
        local fs = _G["GameTooltipTextLeft" .. i] or CreateFrame("FontString", "GameTooltipTextLeft" .. i)
        fs:SetText(l.leftText)
        fs:SetTextColor(table.unpack(l.color or { 1, 1, 1 }))
        tip._lines[i] = l
    end
end
-- the default anchor (GameTooltip_SetDefaultAnchor) takes the tooltip first
function GameTooltip:SetUnit(unit)
    self:SetOwner(UIParent)
    self:FillUnit(unit)
end
-- what the game does when it redraws the tooltip of the unit it already shows,
-- as it does once more when the mouse leaves the creature: no new owner
function GameTooltip:Refresh()
    local unit = self._unit
    clearTip(self)
    self:FillUnit(unit)
end
function GameTooltip:FillUnit(unit)
    rawset(self, "_unit", unit)
    -- the default anchor: bottom right, where Edit Mode puts tooltips
    self:ClearAllPoints()
    self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -95, 110)
    local u = UNITS[unit] or LAST_UNIT
    LAST_UNIT = u
    local lines = { { leftText = u.name, type = 2 } }
    if u.subtitle then lines[#lines + 1] = { leftText = u.subtitle } end
    lines[#lines + 1] = { leftText = "Level " .. tostring(u.level) .. " " .. tostring(u.ctype or ""), type = 0 }
    for _, q in ipairs(u.questLines or {}) do lines[#lines + 1] = q end
    setLines(self, lines)
    local data = { type = 2, lines = USE_TOOLTIP_DATA and lines or nil }
    for _, fn in ipairs(postCalls[2] or {}) do fn(self, data) end
    self:Show()
end
function GameTooltip:SetItem(name)
    self:SetOwner(UIParent)
    setLines(self, { { leftText = name } })
    for _, fn in ipairs(postCalls[0] or {}) do fn(self, { type = 0 }) end
    self:Show()
end
USE_TOOLTIP_DATA = true

-- world state --------------------------------------------------------------
UNITS = {}
local function U(unit)
    if not unit then return nil end
    local u = UNITS[unit]
    if u then return u end
    local base = unit:match("^(.-)target$")
    local b = base and base ~= "" and UNITS[base]
    return b and b.target and UNITS[b.target] or nil
end
function UnitExists(u) return U(u) ~= nil end
function UnitGUID(u) local x = U(u); return x and x.guid end
function UnitName(u) local x = U(u); if x then return x.name, x.realm end end
function UnitClass(u) local x = U(u); if x and x.class then return x.className or x.class, x.class, 1 end end
function UnitLevel(u) local x = U(u); return x and x.level or 0 end
function UnitIsPlayer(u) local x = U(u); return x and x.player or false end
function UnitCanAttack(a, u) local x = U(u); return x and x.hostile or false end
function UnitReaction(u, other) local x = U(u); return x and (x.reaction or (x.hostile and 2 or 5)) end
function UnitCreatureType(u) local x = U(u); return x and x.ctype end
function UnitCreatureFamily(u) local x = U(u); return x and x.family end
function UnitClassification(u) local x = U(u); return x and x.cls or "normal" end
function UnitIsBossMob(u) local x = U(u); return x and x.boss or false end
function UnitIsTapDenied(u) local x = U(u); return x and x.tapDenied or false end
function UnitIsDeadOrGhost(u) local x = U(u); return x and x.dead or false end
function UnitHealth(u) local x = U(u); return x and x.hp or 0 end
function UnitHealthMax(u) local x = U(u); return x and x.hpMax or 0 end
function UnitRace(u) local x = U(u); return x and x.race end
function GetGuildInfo(u) local x = U(u); return x and x.guild end
LEVEL = "Level"
function UnitIsUnit(a, b)
    local x, y = U(a), U(b)
    return x ~= nil and y ~= nil and x.guid == y.guid
end

KNOWN_EVENTS = { ADDON_LOADED = true, PLAYER_LOGIN = true }
