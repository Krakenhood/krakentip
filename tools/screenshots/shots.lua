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

-- A card as the screenshot tool draws it: its frame and each part that shows,
-- where it sits from the card's top left corner, and what it shows.
local function snap()
    local f = Card.frame
    local out = { look = f.look, w = f:GetWidth(), h = f:GetHeight(), parts = {} }
    for _, p in ipairs(f.parts) do
        if p:IsShown() and p._at then
            local e = { kind = p._kind, point = p._at[1], x = p._at[2], y = p._at[3] }
            local k = p._kind
            if k == "text" then
                e.text = tostring(p:GetText() or "")
                e.size, e.color, e.title, e.outline = p._size, col(p._color), p._title and true or false, p._outline and true or false
                if (p._w or 0) > 0 then e.width = p._w end
                e.justify = p._justify
            elseif k == "solid" then
                e.w, e.h, e.rgba = p._w, p._h, p._rgba
            elseif k == "bar" then
                e.w, e.h = p._size[1], p._size[2]
                local v, m = p:GetValue(), p._max
                e.fill = (type(v) == "number" and type(m) == "number" and m > 0) and v / m or 0.62
                e.color, e.texture = col(p._color), p._texture
            elseif k == "tag" then
                e.text, e.size, e.w = p.text:GetText(), p._size, p:GetWidth()
            elseif k == "skull" then
                e.size = p._size
            elseif k == "ring" then
                e.size = p._size
                e.skull = p.skull:IsShown() and true or false
                if p.level:IsShown() then e.level, e.levelColor = tostring(p.level:GetText()), col(p.level._color) end
            elseif k == "face" then
                e.size, e.unit, e.tex = p._size, p._unit, p._tex
            elseif k == "chip" then
                e.icon, e.text, e.color = p._icon, tostring(p.text:GetText()), col(p.text._color)
            end
            out.parts[#out.parts + 1] = e
        end
    end
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

local out = { cards = {}, variants = {} }
for _, style in ipairs(KT.STYLES) do
    S.style = style
    local c = {}
    for _, unit in ipairs({ "wolf", "boar", "boss", "innkeeper", "friend" }) do c[unit] = hover(unit) end
    out.cards[style] = c
end

-- the same card at other widths and heights, and with other bars
local function variant(name, style, dims, bar)
    S.style = style
    S.dims[style] = dims
    S.bar = bar or { texture = "smooth", color = "reaction" }
    out.variants[name] = hover("wolf")
    S.dims[style] = nil
end
variant("regular", "regular")
variant("regularSmall", "regular", { w = 0.8, h = 0.7 })
variant("regularWide", "regular", { w = 1.3, h = 1.2 })
variant("minimalWide", "minimal", { w = 1.6, h = 1.3 })
for _, t in ipairs(KT.BarTextures) do variant("tex_" .. t.key, "mid", nil, { texture = t.key, color = "reaction" }) end
for _, c in ipairs(KT.BarColors) do variant("col_" .. c.key, "mid", nil, { texture = "smooth", color = c.key }) end
S.bar = { texture = "smooth", color = "reaction" }
out.barLabels = {}
for _, t in ipairs(KT.BarTextures) do out.barLabels["tex_" .. t.key] = t.label end
for _, c in ipairs(KT.BarColors) do out.barLabels["col_" .. c.key] = c.label end
-- a party member in another zone, and a wolf both of you have a quest for
UNITS.party1 = { guid = "Player-1-0000EEEE", name = "Jokke", class = "ROGUE", className = "Rogue", race = "Orc", guild = "Aurora EU",
    level = 30, player = true, reaction = 5, hp = 640, hpMax = 900, target = "wolf",
    questLines = { { leftText = "<Aurora EU>" }, { leftText = "Horde" }, { leftText = "Orgrimmar" } } }
UNITS.wolfGroup = {
    guid = "Creature-0-1-2-3-4522-000ABD", name = "Timberling Ravager", level = 24, ctype = "Beast", family = "Wolf",
    cls = "elite", hostile = true, hp = 1116, hpMax = 1800, target = "player",
    questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 },
        { leftText = "Jokke", type = 18 }, { leftText = " - Ravaged Pelt: 5/8", type = 8 }, { leftText = "Skinnable" } },
}
RAID_CLASS_COLORS.ROGUE = RAID_CLASS_COLORS.ROGUE or { r = 1, g = 0.96, b = 0.41 }
out.group = {}
for _, style in ipairs(KT.STYLES) do
    S.style = style
    out.group[style] = { member = hover("party1"), wolf = hover("wolfGroup") }
end
UNITS.party1 = nil
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
out.options = { checks = checks, fieldCount = #KT.FIELDS, fieldsHeading = O.fieldsHeading:GetText(), position = radio(O.position), styleName = O.styleName:GetText(), styleHint = O.styleHint:GetText(),
    width = O.widthText:GetText(), height = O.heightText:GetText(), texture = O.textureText:GetText(), color = O.colorText:GetText(),
    scale = O.scaleText:GetText(), sample = O.sampleButton:GetText(), frameHeight = O.frame:GetHeight() }
out.sample = snap()

out.styles, out.labels, out.hints = KT.STYLES, KT.STYLE_LABEL, KT.STYLE_HINT
out.errors = #ERRORS
SHOT_JSON = json(out)
