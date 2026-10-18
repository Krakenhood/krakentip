-- Hovers a few creatures headless and records what the card shows, as JSON for
-- shots.js to draw. Runs on tests/mock.lua.

local function json(v)
    local t = type(v)
    if t == "table" then
        if #v > 0 or next(v) == nil then
            local out = {}
            for i, x in ipairs(v) do out[i] = json(x) end
            return "[" .. table.concat(out, ",") .. "]"
        end
        local out = {}
        for k, x in pairs(v) do out[#out + 1] = json(tostring(k)) .. ":" .. json(x) end
        return "{" .. table.concat(out, ",") .. "}"
    elseif t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c) return ("\\u%04x"):format(c:byte()) end) .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    end
    return "null"
end

local NS = {}
for _, name in ipairs(TOC) do assert(load(FILES[name], "@" .. name))("Krakentip", NS) end
local KT = NS
UNITS.player = { guid = "Player-1-0000AAAA", name = "Krakenhood", class = "WARRIOR", className = "Warrior", level = 21, player = true }
UNITS.wolf = {
    guid = "Creature-0-1-2-3-4521-000ABC", name = "Timberling Ravager", level = 24, ctype = "Beast", family = "Wolf",
    cls = "elite", hostile = true, hp = 1116, hpMax = 1800, target = "player",
    questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 } },
}
UNITS.boar = { guid = "Creature-0-1-2-3-113-000DEF", name = "Bristleback Quilboar", level = 19, ctype = "Humanoid", hostile = true, reaction = 4, hp = 76, hpMax = 100 }
UNITS.boss = { guid = "Creature-0-1-2-3-639-000222", name = "Edwin VanCleef", level = 21, boss = true, ctype = "Humanoid", cls = "elite", hostile = true, hp = SECRET, hpMax = SECRET, target = "tank" }
UNITS.tank = { guid = "Player-1-0000CCCC", name = "Thalianne", class = "WARRIOR", player = true }
UNITS.innkeeper = { guid = "Creature-0-1-2-3-295-000111", name = "Innkeeper Farley", subtitle = "Innkeeper", level = 30, ctype = "Humanoid", reaction = 5, hp = 100, hpMax = 100 }
UNITS.friend = { guid = "Player-1-0000BBBB", name = "Thalianne", class = "MAGE", className = "Mage", race = "Night Elf", guild = "Krakenhood", level = 22, player = true, reaction = 5, hp = 800, hpMax = 900 }
Krakenfriends = { journey = { partnerName = "Thalianne", pairs = { a = { mobs = { [4521] = { c = 42 } } } } } }
FireEvent("ADDON_LOADED", "Krakentip")
FireEvent("PLAYER_LOGIN")
local Card = KT.Card
local S = KrakentipDB.settings

local function col(c) return c and { c[1], c[2], c[3] } or nil end
local function shown(r) return r and r:IsShown() end
local function snap()
    local f = Card.frame
    local out = { width = f:GetWidth(), height = f:GetHeight(), rows = {}, quests = {} }
    out.name, out.nameColor = f.name:GetText(), col(f.name._color)
    if shown(f.level) then out.level, out.levelColor = f.level:GetText(), col(f.level._color) end
    out.skull = shown(f.skull) and true or false
    out.sub = f.sub and f.sub:GetText()
    out.tag = shown(f.tag) and f.tag.text:GetText() or nil
    local v, max = f.bar:GetValue(), f.bar._max
    out.fill = (type(v) == "number" and type(max) == "number" and max > 0) and v / max or 0.62
    out.barColor = col(f.bar._color)
    out.hp = f.bar.text:GetText()
    for _, r in ipairs(f.rows or {}) do
        if r:IsShown() then
            if r.label then
                out.rows[#out.rows + 1] = { r.label:GetText(), tostring(r.value:GetText()), col(r.value._color) }
            else -- Column: one text per line
                out.rows[#out.rows + 1] = { r:GetText(), r._size, col(r._color) }
            end
        end
    end
    out.lines = {}
    for _, l in ipairs(f.lines or {}) do
        if l:IsShown() then out.lines[#out.lines + 1] = { l:GetText(), col(l._color) } end
    end
    if shown(f.left) then out.left, out.leftColor = f.left:GetText(), col(f.left._color) end
    if shown(f.right) then out.right, out.rightColor = f.right:GetText(), col(f.right._color) end
    if f.info and f.info.GetText and shown(f.info) then out.info = f.info:GetText() end
    out.chips = {}
    for _, chip in ipairs(f.chips or {}) do
        if chip:IsShown() then out.chips[#out.chips + 1] = { chip.icon._tex, chip.text:GetText(), col(chip.text._color) } end
    end
    if f.face then out.face = f.face._tex end
    for _, q in ipairs(f.quests or {}) do
        if q:IsShown() then out.quests[#out.quests + 1] = { q:GetText(), col(q._color) } end
    end
    if shown(f.target) then out.target, out.targetColor = f.target:GetText(), col(f.target._color) end
    if shown(f.quest) then out.quest = f.quest:GetText() end
    out.style = KrakentipDB.settings.style
    return out
end

local function hover(unit)
    UNITS.mouseover = UNITS[unit]
    GameTooltip:SetUnit("mouseover")
    local s = snap()
    UNITS.mouseover = nil
    for _ = 1, 4 do Card.frame:GetScript("OnUpdate")(Card.frame, 0.1) end
    return s
end

local out = { cards = {} }
for _, style in ipairs(KT.STYLES) do
    S.style = style
    local c = {}
    for _, unit in ipairs({ "wolf", "boar", "boss", "innkeeper", "friend" }) do c[unit] = hover(unit) end
    out.cards[style] = c
end
S.style = "regular"

-- the options window as it opens, with the sample card
SlashCmdList.KRAKENTIP("")
local O = KT.Options
Click(O.sampleButton)
local function radio(g)
    local r = {}
    for _, rb in ipairs(g.buttons) do r[#r + 1] = { rb.label:GetText(), rb.hint and rb.hint:GetText(), rb:GetChecked() and true or false } end
    return r
end
local checks = {}
for _, cb in ipairs(O.checks) do checks[#checks + 1] = { cb.label:GetText(), cb:GetChecked() and true or false } end
out.options = { checks = checks, position = radio(O.position), styleName = O.styleName:GetText(), styleHint = O.styleHint:GetText(), scale = O.scaleText:GetText(), sample = O.sampleButton:GetText(), height = O.frame:GetHeight() }
out.sample = snap()

out.styles, out.labels, out.hints = KT.STYLES, KT.STYLE_LABEL, KT.STYLE_HINT
out.errors = #ERRORS
SHOT_JSON = json(out)
