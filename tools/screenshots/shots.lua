-- Hovers the concept page's units headless in every look and records what the
-- card shows, as JSON for shots.js to draw. Runs on tests/mock.lua.

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
RAID_CLASS_COLORS.ROGUE = RAID_CLASS_COLORS.ROGUE or { r = 1, g = 0.96, b = 0.41 }
RAID_CLASS_COLORS.PRIEST = RAID_CLASS_COLORS.PRIEST or { r = 1, g = 1, b = 1 }
RAID_CLASS_COLORS.HUNTER = RAID_CLASS_COLORS.HUNTER or { r = 0.67, g = 0.83, b = 0.45 }

-- you: Krakenhood, a level 21 warrior, in a party with Jokke, Thalianne, Mira and Brokk
UNITS.player = { guid = "Player-1-0000AAAA", name = "Krakenhood", class = "WARRIOR", className = "Warrior", level = 21, player = true }
UNITS.party1 = { guid = "Player-1-0000EEEE", name = "Jokke", class = "ROGUE", player = true, reaction = 5 }
UNITS.party2 = { guid = "Player-1-0000EEEF", name = "Thalianne", class = "WARRIOR", player = true, reaction = 5 }
UNITS.party3 = { guid = "Player-1-0000EEF0", name = "Mira", class = "PRIEST", player = true, reaction = 5 }
UNITS.party4 = { guid = "Player-1-0000EEF1", name = "Brokk", class = "HUNTER", player = true, reaction = 5 }
UNITS.thalianne = UNITS.party2
UNITS.sneakystab = { guid = "Player-1-0000CCCC", name = "Sneakystab", class = "ROGUE", player = true, hostile = true }

local pelts = function(...)
    local q = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 } }
    for _, m in ipairs({ ... }) do
        q[#q + 1] = { leftText = m[1], type = 18 }
        q[#q + 1] = { leftText = " - Ravaged Pelt: " .. m[2] .. "/8", type = 8 }
    end
    q[#q + 1] = { leftText = "Skinnable" }
    return q
end

-- the concept page's eight situations (docs/clean-slate.html)
local CASES = {
    { "wolf", { guid = "Creature-0-1-2-3-4521-000ABC", name = "Timberling Ravager", level = 24, ctype = "Beast", family = "Wolf",
        cls = "elite", hostile = true, hp = 1116, hpMax = 1800, target = "player", questLines = pelts() } },
    { "party", { guid = "Creature-0-1-2-3-4523-000ABE", name = "Timberling Ravager", level = 24, ctype = "Beast", family = "Wolf",
        cls = "elite", hostile = true, hp = 1116, hpMax = 1800, target = "player",
        questLines = pelts({ "Jokke", 5 }, { "Thalianne", 8 }, { "Mira", 1 }, { "Brokk", 6 }) } },
    { "tapped", { guid = "Creature-0-1-2-3-113-000DEF", name = "Bristleback Thornweaver", level = 19, ctype = "Humanoid", family = "Quilboar",
        hostile = true, tapDenied = true, hp = 41, hpMax = 100, target = "sneakystab" } },
    { "rare", { guid = "Creature-0-1-2-3-14266-000123", name = "Ressan the Needler", level = 11, ctype = "Beast", family = "Spider",
        cls = "rare", hostile = true, hp = 262, hpMax = 262 } },
    { "boss", { guid = "Creature-0-1-2-3-639-000222", name = "Edwin VanCleef", level = 21, boss = true, ctype = "Humanoid", cls = "elite",
        hostile = true, hp = SECRET, hpMax = SECRET, target = "thalianne" } },
    { "inn", { guid = "Creature-0-1-2-3-6747-000111", name = "Innkeeper Boorand Plainswind", subtitle = "Innkeeper", level = 30,
        ctype = "Humanoid", reaction = 5, hp = 100, hpMax = 100 } },
    { "jokke", { guid = "Player-1-0000EEEE", name = "Jokke", class = "ROGUE", className = "Rogue", race = "Orc", guild = "Aurora EU",
        faction = "Horde", level = 30, player = true, reaction = 5, hp = 640, hpMax = 900, inParty = true,
        questLines = { { leftText = "<Aurora EU>" }, { leftText = "Horde" }, { leftText = "Orgrimmar" } } }, noPlate = true },
    { "enemy", { guid = "Player-1-0000CCCD", name = "Sneakystab", class = "ROGUE", className = "Rogue", race = "Human", guild = "Shadow Council",
        faction = "Alliance", pvp = true, level = 23, player = true, hostile = true, hp = 1040, hpMax = 1040, target = "player" } },
}

Krakenfriends = nil
SECRET_STANDIN = 85 -- what the game writes for the boss's hidden health
FireEvent("ADDON_LOADED", "Krakentip")
FireEvent("PLAYER_LOGIN")
local Card = KT.Card
local S = KrakentipDB.settings

local function col(c) return c and { c[1], c[2], c[3] } or nil end

-- A card as the screenshot tool draws it: its frame and each part that shows,
-- where it sits from the card's top left corner, and what it shows.
local function snap()
    local f = Card.frame
    local out = { style = Card.shownStyle, w = f:GetWidth(), h = f:GetHeight(), parts = {}, edge = col(f._edge), glow = f._glow and true or false }
    for _, p in ipairs(f.parts) do
        if p:IsShown() and p._at then
            local e = { kind = p._kind, point = p._at[1], x = p._at[2], y = p._at[3] }
            local k = p._kind
            if k == "text" then
                e.text = tostring(p:GetText() or "")
                e.size, e.color, e.display, e.outline = p._size, col(p._color), p._display and true or false, p._outline and true or false
                if (p._w or 0) > 0 then e.width = p._w end
                e.justify = p._justify
            elseif k == "solid" then
                e.w, e.h, e.rgba = p._w, p._h, p._rgba
            elseif k == "bar" then
                e.w, e.h = p._size[1], p._size[2]
                local v, m = p:GetValue(), p._max
                e.fill = (type(v) == "number" and type(m) == "number" and m > 0) and v / m or 0.85
                e.color, e.texture = col(p._color), p._texture
                e.edge = p._edge and p.edge:IsShown() and col(p._edge) or nil
            elseif k == "skull" then
                e.size = p._size
            elseif k == "tex" then
                e.file, e.w, e.h, e.tint = p._file, p._w, p._h, p._tint
            elseif k == "qring" then
                e.size, e.frac, e.done, e.text = p._size, p._frac, p._done and true or false, p._text
            elseif k == "chip" then
                e.icon, e.text, e.w = p._icon, tostring(p.text:GetText()), p:GetWidth()
            end
            out.parts[#out.parts + 1] = e
        end
    end
    return out
end

local PLATE = CreateFrame("Frame", "ShotNamePlate")
local function hover(unit, noPlate)
    UNITS.mouseover = UNITS[unit]
    PLATES.mouseover = (S.style == "banner" and not noPlate) and PLATE or nil
    GameTooltip:SetUnit("mouseover")
    local s = snap()
    UNITS.mouseover = nil
    for _ = 1, 4 do Card.frame:GetScript("OnUpdate")(Card.frame, 0.1) end
    return s
end

local out = { cards = {}, cases = {}, variants = {} }
for _, case in ipairs(CASES) do
    UNITS[case[1]] = case[2]
    out.cases[#out.cases + 1] = case[1]
end
for _, style in ipairs(KT.STYLES) do
    S.style = style
    local c = {}
    for _, case in ipairs(CASES) do c[case[1]] = hover(case[1], case.noPlate) end
    out.cards[style] = c
end
-- what the nameplate above a Banner shows: name, its colour, the health
out.plates = {}
for _, case in ipairs(CASES) do
    local u = case[2]
    local info = Card:Gather(case[1], {})
    local hp = (type(u.hp) == "number" and type(u.hpMax) == "number") and u.hp / u.hpMax or 0.85
    out.plates[case[1]] = { name = u.name, color = col(KT.Layouts.NameColor(info)), hp = hp, tapped = info.tapped,
        bar = col(info.tapped and { 0.48, 0.48, 0.48 } or info.reaction == "friendly" and { 0.16, 0.65, 0.16 } or info.reaction == "neutral" and { 0.85, 0.7, 0 } or { 0.77, 0.12, 0.12 }),
        npc = not info.isPlayer and not info.canAttack }
end

-- the same card at other widths and heights, and with other bars
local function variant(name, style, dims, bar)
    S.style = style
    S.dims[style] = dims
    S.bar = bar or { texture = "slate", color = "health" }
    out.variants[name] = hover("wolf")
    S.dims[style] = nil
end
variant("glance", "glance")
variant("glanceSmall", "glance", { w = 0.8, h = 0.7 })
variant("glanceWide", "glance", { w = 1.3, h = 1.2 })
variant("ledgerNarrow", "ledger", { w = 0.8 })
for _, t in ipairs(KT.BarTextures) do variant("tex_" .. t.key, "glance", nil, { texture = t.key, color = "health" }) end
for _, c in ipairs(KT.BarColors) do variant("col_" .. c.key, "glance", nil, { texture = "slate", color = c.key }) end
S.bar = { texture = "slate", color = "health" }
out.barLabels = {}
for _, t in ipairs(KT.BarTextures) do out.barLabels["tex_" .. t.key] = t.label end
for _, c in ipairs(KT.BarColors) do out.barLabels["col_" .. c.key] = c.label end
S.style = "glance"

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
