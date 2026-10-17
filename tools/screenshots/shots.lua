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
UNITS.player = { guid = "Player-1-0000AAAA", name = "Krakenhood", class = "WARRIOR", level = 21, player = true }
UNITS.wolf = {
    guid = "Creature-0-1-2-3-4521-000ABC", name = "Timberling Ravager", level = 24, ctype = "Beast", family = "Wolf",
    cls = "elite", hostile = true, hp = 1116, hpMax = 1800, target = "player",
    questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 } },
}
UNITS.boar = { guid = "Creature-0-1-2-3-113-000DEF", name = "Bristleback Quilboar", level = 19, ctype = "Humanoid", hostile = true, reaction = 4, hp = 76, hpMax = 100 }
UNITS.boss = { guid = "Creature-0-1-2-3-639-000222", name = "Edwin VanCleef", level = 21, boss = true, ctype = "Humanoid", cls = "elite", hostile = true, hp = SECRET, hpMax = SECRET, target = "tank" }
UNITS.tank = { guid = "Player-1-0000CCCC", name = "Thalianne", class = "WARRIOR", player = true }
Krakenfriends = { journey = { partnerName = "Thalianne", pairs = { a = { mobs = { [4521] = { c = 42 } } } } } }
FireEvent("ADDON_LOADED", "Krakentip")
FireEvent("PLAYER_LOGIN")
local Card = KT.Card

local function col(c) return { c[1], c[2], c[3] } end
local function snap()
    local rows, quests = {}, {}
    for _, r in ipairs(Card.rows) do
        if r:IsShown() then rows[#rows + 1] = { r.label:GetText(), tostring(r.value:GetText()), col(r.value._color) } end
    end
    for _, q in ipairs(Card.quests) do
        if q:IsShown() then quests[#quests + 1] = { q:GetText(), col(q._color) } end
    end
    local v, max = Card.bar:GetValue(), Card.bar._max
    return {
        name = Card.name:GetText(), nameColor = col(Card.name._color),
        level = Card.badge.level:IsShown() and Card.badge.level:GetText() or nil, levelColor = col(Card.badge.level._color),
        sub = Card.sub:GetText(), tag = Card.tag:IsShown() and Card.tag.text:GetText() or nil,
        fill = (type(v) == "number" and type(max) == "number" and max > 0) and v / max or 0.62,
        hp = Card.bar.text:GetText(), rows = rows, quests = quests, scale = Card.frame:GetScale(),
    }
end

local function hover(unit)
    UNITS.mouseover = UNITS[unit]
    GameTooltip:SetUnit("mouseover")
    local s = snap()
    UNITS.mouseover = nil
    GameTooltip:Hide()
    return s
end

local out = { cards = {} }
out.cards.wolf = hover("wolf")
out.cards.boar = hover("boar")
out.cards.boss = hover("boss")

-- the options window as it opens
SlashCmdList.KRAKENTIP("")
local O = KT.Options
Click(O.sampleButton)
local checks = {}
for _, cb in ipairs(O.checks) do checks[#checks + 1] = { cb.label:GetText(), cb:GetChecked() and true or false } end
local radio = {}
for _, rb in ipairs(O.position.buttons) do radio[#radio + 1] = { rb.label:GetText(), rb.hint and rb.hint:GetText(), rb:GetChecked() and true or false } end
out.options = { checks = checks, radio = radio, scale = O.scaleText:GetText(), sample = O.sampleButton:GetText() }
out.cards.sample = snap()

out.errors = #ERRORS
SHOT_JSON = json(out)
