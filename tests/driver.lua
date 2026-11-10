-- Loads the addon in TOC order and hovers things.
local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1; print("  FAIL: " .. label) end
end
local function section(t) print("\n== " .. t) end

local NS = {}
for _, name in ipairs(TOC) do
    local chunk, err = load(FILES[name], "@" .. name)
    if not chunk then error(err) end
    chunk("Krakentip", NS)
end
local KT = NS

UNITS.player = { guid = "Player-1-0000AAAA", name = "Krakenhood", class = "WARRIOR", className = "Warrior", level = 21, player = true }
UNITS.wolf = {
    guid = "Creature-0-1-2-3-4521-000ABC", name = "Timberling Ravager", level = 24, ctype = "Beast", family = "Wolf",
    cls = "elite", hostile = true, hp = 1116, hpMax = 1800, target = "player",
    questLines = {
        { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } },
        { leftText = " - Ravaged Pelt: 3/8", type = 8 },
    },
}
UNITS.boar = { guid = "Creature-0-1-2-3-113-000DEF", name = "Bristleback", level = 10, ctype = "Beast", family = "Boar", hostile = true, reaction = 4, hp = 40, hpMax = 100 }
UNITS.innkeeper = { guid = "Creature-0-1-2-3-295-000111", name = "Innkeeper Farley", subtitle = "Innkeeper", level = 30, ctype = "Humanoid", reaction = 5, hp = 100, hpMax = 100 }
UNITS.friend = { guid = "Player-1-0000BBBB", name = "Thalianne", class = "MAGE", className = "Mage", race = "Night Elf", guild = "Krakenhood", level = 22, player = true, reaction = 5, hp = 800, hpMax = 900 }
UNITS.rogue = { guid = "Player-1-0000CCCC", name = "Sneakystab", class = "ROGUE", className = "Rogue", race = "Undead", level = 23, player = true, hostile = true, hp = 900, hpMax = 900, target = "player" }
UNITS.boss = { guid = "Creature-0-1-2-3-639-000222", name = "Edwin VanCleef", level = 21, boss = true, ctype = "Humanoid", cls = "elite", hostile = true, hp = SECRET, hpMax = SECRET }

FireEvent("ADDON_LOADED", "Krakentip")
FireEvent("PLAYER_LOGIN")
local Card = KT.Card
local S = KrakentipDB.settings

-- the Banner hangs from a nameplate; every hovered unit has one while it's the look
local PLATE = CreateFrame("Frame", "TestNamePlate")
local function hover(unit)
    UNITS.mouseover = UNITS[unit]
    PLATES.mouseover = KrakentipDB.settings.style == "banner" and PLATE or nil
    GameTooltip:SetUnit("mouseover")
end
local function tick(sec) Card.frame:GetScript("OnUpdate")(Card.frame, sec) end
local function leave()
    UNITS.mouseover = nil
    for _ = 1, 4 do tick(0.1) end
end
local function cardShown() return Card.frame and Card.frame:IsShown() end
local function F() return Card.frame end
local function rowText(i)
    local r = F().rows and F().rows[i]
    return r and r:IsShown() and (r.label:GetText() .. ": " .. tostring(r.value:GetText())) or nil
end
local function rows()
    local out = {}
    for i = 1, 8 do local t = rowText(i); if t then out[#out + 1] = t end end
    return table.concat(out, " | ")
end
-- a field on or off in every look
local function field(key, on) for _, st in ipairs(KT.STYLES) do KT:SetField(key, on, st) end end
local function isColor(c, r, g, b) return math.abs(c[1] - r) < 0.01 and math.abs(c[2] - g) < 0.01 and math.abs(c[3] - b) < 0.01 end

-- every text a card shows, colour codes and inline icons left out
local function texts(f)
    local out = {}
    for _, p in ipairs(f.parts) do
        if p:IsShown() and p.GetText and p:GetText() then out[#out + 1] = tostring(p:GetText()) end
        if p:IsShown() and p.text and p.text.GetText and p.text:GetText() then out[#out + 1] = tostring(p.text:GetText()) end
    end
    return (table.concat(out, " | "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t ?", ""))
end
local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t ?", "")) end

--------------------------------------------------------------------------------
section("defaults")
check(S.position == "mouse", "next to the mouse by default")
check(S.style == "glance", "Glance by default")
check(#KT.STYLES == 4 and KT.STYLES[1] == "whisper" and KT.STYLES[4] == "banner", "the four looks")
check(not KT.Layouts.regular and not KT.Layouts.minimal and not KT.Layouts.icons, "the twelve of 0.7 are gone (they live on the legacy branch)")
check(S.enabled and S.shiftLedger and S.combatGlance, "on, Shift for the Ledger, the Ledger shrinks in combat")
check(S.bar.texture == "slate" and S.bar.color == "health", "the Slate bar, coloured by health")
check(KT:Fields("whisper").guild and KT:Fields("glance").guild, "every look shows every field")

section("an enemy: the card, and the game's unit tooltip never shows")
hover("wolf")
check(cardShown() and F() == Card.frames.glance, "the Glance card")
check(not GameTooltip:IsShown(), "the game's tooltip is hidden, not just see-through")
GameTooltip:Show()
check(not GameTooltip:IsShown(), "and stays hidden when the game shows it again")
check(F().name:GetText() == "Timberling Ravager", "name")
check(F().level:GetText() == "24+", "level, + for elite: " .. tostring(F().level:GetText()))
check(isColor(F().level._color, 1, 0.54, 0.24), "the level orange: three above you")
check(F().ring:IsShown() and F().ring.text:GetText() == "3/8", "the quest ring")
check(math.abs(F().ring._frac - 3 / 8) < 0.001 and not F().ring._done, "filled three eighths")
check(F().bar:GetValue() == 1116 and F().bar._max == 1800, "health bar")
check(F().num:GetText() == "1,116" and F().bar.text:GetText() == "62%", "the number left, the percentage right")
check(plain(F().left:GetText()) == "You" and F().left:GetText():find("arrow.tga", 1, true), "who it's after, with the arrow: " .. tostring(F().left:GetText()))
check(F().right:GetText() == "Beast · Wolf", "what it is")
check(F().wing:IsShown() and F().wing._file == "wing-elite", "the gold wing")
check(isColor(F()._edge, 0.84, 0.65, 0.20), "the frame gold")
check(F().glow:IsShown() and F()._glow, "the red glow: it's after you")
check(isColor(F().name._color, 1, 0.29, 0.23), "hostile red name")
check(isColor(F().spine._rgba, 1, 0.29, 0.23), "and the red edge")
check(F().bar._texture == "slate" and F().bar.gloss:IsShown(), "the Slate bar, with its shine")
local c = F().bar._color
check(c[1] > 0.6 and c[2] > 0.6 and c[3] < 0.2, "62% health: yellow-green " .. table.concat(c, ","))

section("next to the mouse")
CURSOR[1], CURSOR[2] = 400, 300
tick(0.01)
local p, _, _, x, y = F():GetPoint(1)
check(p == "BOTTOMLEFT" and x == 422 and y == 308, ("right of the cursor: %s %s %s"):format(tostring(p), tostring(x), tostring(y)))
CURSOR[1] = 1850
tick(0.01)
p, _, _, x = F():GetPoint(1)
check(p == "BOTTOMRIGHT" and x == 1828, "left of the cursor near the right edge: " .. tostring(p) .. " " .. tostring(x))
CURSOR[1] = 400

section("an item right after: the game's tooltip, as it is")
GameTooltip:SetItem("Linen Cloth")
check(GameTooltip:IsShown(), "the item tooltip shows")
check(not cardShown(), "card gone")

section("a button's tooltip right after a creature")
hover("wolf")
UNITS.mouseover = nil
GameTooltip:SetOwner({})
GameTooltip:AddLine("Krakenchat")
GameTooltip:Show()
check(GameTooltip:IsShown(), "the button's tooltip shows")
check(not cardShown(), "no card")
GameTooltip:Hide()

section("a friendly NPC: its role instead of a bar")
hover("innkeeper")
check(cardShown() and not GameTooltip:IsShown(), "card instead of the game's tooltip")
check(F().name:GetText() == "Farley", "the title left out of the name: " .. tostring(F().name:GetText()))
check(isColor(F().name._color, 0.28, 0.88, 0.31), "green name")
local chipTexts = {}
for _, ch in ipairs(F().chips) do if ch:IsShown() then chipTexts[#chipTexts + 1] = ch.text:GetText() end end
check(table.concat(chipTexts, ", ") == "Hearthstone, Food & drink" and not F().bar:IsShown(), "what it offers instead of a bar: " .. table.concat(chipTexts, ", "))
check(plain(F().left:GetText()) == "<Innkeeper>" and F().left:GetText():find("BinderGossipIcon", 1, true), "its role with the game's icon: " .. tostring(F().left:GetText()))
check(F().right:GetText() == "Humanoid", "and its type")
check(not F().glow:IsShown() and not F().wing:IsShown(), "no glow, no wing")
leave()

section("a friendly player: class colour, race and class, guild")
hover("friend")
check(isColor(F().name._color, 0.25, 0.78, 0.92), "mage blue name")
check(isColor(F().spine._rgba, 0.25, 0.78, 0.92), "mage blue edge")
check(F().right:GetText() == "Night Elf Mage", "race and class: " .. tostring(F().right:GetText()))
check(F().left2:GetText() == "<Krakenhood>", "guild")
leave()

section("neutral creature, Classic-style percent health, no target")
hover("boar")
check(isColor(F().name._color, 1, 0.85, 0.20), "neutral yellow name")
check(F().bar.text:GetText() == "76%" or F().bar.text:GetText() == "40%", "percent only: " .. tostring(F().bar.text:GetText()))
check(not F().num:IsShown(), "no number when the game gives a percentage")
check(isColor(F().level._color, 0.62, 0.62, 0.62), "the level grey: trivial")
check(not F().ring:IsShown() and not F().wing:IsShown(), "no ring, no wing")
check(not F().glow:IsShown(), "no glow")
leave()

section("a boss with secret health")
hover("boss")
check(cardShown(), "card shown")
check(F().skull:IsShown() and not F().level:IsShown(), "skull instead of a level")
check(rawequal(F().bar:GetValue(), SECRET), "the bar still gets the secret value")
check(F().bar.text:GetText() == "<secret>" and not F().num:IsShown(), "hidden numbers: the game writes the percentage itself")
check(isColor(F()._edge, 0.75, 0.22, 0.17) and not F().wing:IsShown(), "a red frame, no wing")
leave()

section("leaving: the card fades, the game's tooltip never shows")
hover("wolf")
UNITS.mouseover = nil
tick(0.05)
check(Card.fading and cardShown(), "fading")
tick(0.1); tick(0.15)
check(not cardShown(), "card gone after the fade")
check(not GameTooltip:IsShown(), "the game's tooltip stayed hidden")

section("leaving: the game redraws its tooltip once more")
hover("wolf")
UNITS.mouseover = nil
GameTooltip:Refresh()
check(Card.fading, "the redraw lets the card go")
check(not GameTooltip:IsShown(), "the game's tooltip stays hidden")
tick(0.25)
check(not cardShown(), "card gone")
hover("boar")
check(cardShown(), "the next creature gets its card")
leave()

section("hovering your target: the game names it \"target\"")
UNITS.player.target = "wolf"
UNITS.target = UNITS.wolf
TIP_TOKEN = "target"
hover("wolf")
check(cardShown() and Card.info.unit == "mouseover", "tracked as mouseover: " .. tostring(Card.info and Card.info.unit))
UNITS.mouseover = nil
GameTooltip:Refresh()
GameTooltip:Show()
tick(0.1)
check(Card.fading and not GameTooltip:IsShown(), "let go, the game's tooltip hidden")
tick(0.15)
check(not cardShown(), "card gone")
TIP_TOKEN, UNITS.target, UNITS.player.target = nil, nil, nil

section("a unit frame without mouseover: the card goes when the mouse leaves the frame")
UNITS.party1 = UNITS.friend
local frame = CreateFrame("Button")
rawset(frame, "_over", true)
GameTooltip:SetOwner(frame)
GameTooltip:FillUnit("party1")
check(cardShown() and Card.info.unit == "party1", "card for party1")
tick(0.1)
check(not Card.fading, "stays while the mouse is on the frame")
rawset(frame, "_over", false)
tick(0.1)
check(Card.fading, "fades when it leaves")
tick(0.25)
UNITS.party1 = nil

section("the card keeps itself up to date while hovering")
hover("wolf")
UNITS.wolf.hp = 900
UNITS.wolf.target = nil
tick(0.25)
check(F().bar:GetValue() == 900 and F().bar.text:GetText() == "50%" and F().num:GetText() == "900", "health: " .. tostring(F().bar.text:GetText()))
check(not F().left:IsShown() and not F().glow:IsShown(), "target and glow gone")
check(F().ring.text:GetText() == "3/8", "quest kept")
UNITS.wolf.hp, UNITS.wolf.target = 1116, "player"
leave()

section("where the game puts tooltips")
SlashCmdList.KRAKENTIP("tooltip")
check(S.position == "tooltip", "setting saved")
hover("wolf")
local rel
p, rel, _, x, y = F():GetPoint(1)
check(p == "BOTTOMRIGHT" and rel == UIParent and x == -95 and y == 110, ("the game's spot, copied: %s %s %s"):format(tostring(p), tostring(x), tostring(y)))
CURSOR[1] = 100
tick(0.01)
p, _, _, x = F():GetPoint(1)
check(x == -95, "doesn't follow the mouse")
leave()
SlashCmdList.KRAKENTIP("scale 1.25")
hover("wolf")
p, rel, _, x, y = F():GetPoint(1)
check(x == -95 / 1.25 and y == 110 / 1.25, "the same spot on screen at another size: " .. tostring(x))
leave()
SlashCmdList.KRAKENTIP("scale 1")
SlashCmdList.KRAKENTIP("mouse")
check(S.position == "mouse", "back to the mouse")

section("Ledger: the full read")
SlashCmdList.KRAKENTIP("ledger")
check(S.style == "ledger", "saved")
hover("wolf")
check(F() == Card.frames.ledger and not Card.frames.glance:IsShown(), "the Ledger, Glance hidden")
check(F().name:GetText() == "Timberling Ravager" and F().rank:GetText() == "ELITE", "name and ELITE")
check(plain(F().levelLine:GetText()) == "Level 24 Beast · Wolf", "the level line: " .. plain(F().levelLine:GetText()))
check(F().bar.text:GetText() == "1,116 / 1,800 · 62%", "the numbers beside the bar: " .. tostring(F().bar.text:GetText()))
check(F().bar._size[2] == 8, "a slim bar")
check(rows() == "Targeting: You", "rows: " .. rows())
check(F().sep:IsShown() and F().qtitle:GetText() == "Ravaged Pelts" and F().qobj:GetText() == "Ravaged Pelt", "the quest heads its table")
check(F().qrows[1].name:GetText() == "You" and F().qrows[1].count:GetText() == "3/8", "your row")
check(F().wing:IsShown() and F().glow:IsShown(), "wing and glow")
leave()
UNITS.rogue.guild, UNITS.rogue.faction, UNITS.rogue.pvp = "Shadow Council", "Alliance", true
hover("rogue")
check(plain(F().rank:GetText()) == "PVP" and F().rank:GetText():find("pvp.tga", 1, true), "PVP with the flag: " .. tostring(F().rank:GetText()))
check(F().guild:GetText() == "<Shadow Council>" and F().note:GetText() == "Alliance", "guild and faction")
check(plain(F().levelLine:GetText()):find("Undead Rogue", 1, true), "level, race and class: " .. plain(F().levelLine:GetText()))
leave()
UNITS.rogue.guild, UNITS.rogue.faction, UNITS.rogue.pvp = nil, nil, nil
hover("boss")
check(F().rank:GetText() == "BOSS" and plain(F().levelLine:GetText()):find("Level ??", 1, true), "BOSS, the level as ??")
check(F().bar.text:GetText() == "<secret>", "the game's percentage when it hides the numbers")
leave()
hover("innkeeper")
check(F().title:GetText() == "<Innkeeper>" and not F().bar:IsShown() and F().chips[1]:IsShown(), "title, services, no bar")
leave()

section("lines can be turned off")
field("target", false); field("quests", false); field("group", false)
hover("wolf")
check(rows() == "", "no target row")
check(not F().sep:IsShown() and not F().qrows[1]:IsShown(), "no quest table")
check(not F().glow:IsShown(), "no glow when the target is off")
field("target", true); field("quests", true); field("group", true)
leave()

section("Krakenfriends: kills together")
Krakenfriends = { journey = { partnerName = "Thalianne", pairs = { a = { mobs = { [4521] = { c = 30 } } }, b = { mobs = { [4521] = { c = 12 } } } } } }
hover("wolf")
check(rowText(2) == "Killed with Thalianne: 42", "kills summed over chapters: " .. tostring(rowText(2)))
leave()
Krakenfriends = nil

section("tooltip data without lines: quest lines read from the text")
USE_TOOLTIP_DATA = false
hover("wolf")
check(F().qrows[1]:IsShown() and F().qrows[1].count:GetText() == "3/8", "quest read from the text")
leave()
USE_TOOLTIP_DATA = true

section("Whisper: two short lines")
SlashCmdList.KRAKENTIP("whisper")
hover("wolf")
check(F() == Card.frames.whisper and F().name:GetText() == "Timberling Ravager", "name in full when it fits")
check(F().level:GetText() == "24+" and F().you:IsShown() and F().quest:GetText() == "3/8", "24+, YOU, 3/8 on line one")
check(plain(F().line2:GetText()) == "Elite Beast · Wolf · 62%", "rank, type and health on line two: " .. plain(F().line2:GetText()))
check(F().glow:IsShown(), "the red glow: it's after you")
check(F().bar:IsShown() and F().bar._size[2] == 2 and F().under:IsShown(), "the health line along the bottom")
check(F():GetHeight() < 40, "two short lines: " .. F():GetHeight())
leave()
UNITS.longname = { guid = "Creature-0-1-2-3-77-0000AA", name = "Bristleback Thornweaver", level = 19, ctype = "Humanoid", family = "Quilboar", hostile = true, tapDenied = true, hp = 41, hpMax = 100, target = "rogue" }
hover("longname")
check(F().name:GetText() == "B. Thornweaver", "a long name shortened: " .. tostring(F().name:GetText()))
check(texts(F()):find("tapped", 1, true) and F().spine._rgba[1] < 0.6 and F().spine._rgba[1] == F().spine._rgba[2], "tapped, the edge grey")
check(texts(F()):find("Sneakystab", 1, true), "who it's after on line two: " .. texts(F()))
leave()
SlashCmdList.KRAKENTIP("glance")
hover("longname")
check(plain(F().left:GetText()) == "Sneakystab  tapped" and F().right:GetText() == "Quilboar", "Glance short of room: the type gives way: " .. plain(F().left:GetText()) .. " | " .. tostring(F().right:GetText()))
leave()
SlashCmdList.KRAKENTIP("whisper")
UNITS.rare = { guid = "Creature-0-1-2-3-5-000AB", name = "Ressan the Needler", level = 11, ctype = "Beast", family = "Spider", cls = "rare", hostile = true, hp = 262, hpMax = 262 }
hover("rare")
check(F().rare:IsShown() and F().rare._file == "diamond", "a rare: the silver diamond")
leave()
hover("innkeeper")
check(F().name:GetText() == "Farley" and plain(F().line2:GetText()) == "<Innkeeper> Humanoid", "an NPC: the title as its role: " .. plain(F().line2:GetText()))
check(not F().bar:IsShown(), "no health line for an innkeeper")
leave()

section("Glance: the wing for rares, silver")
SlashCmdList.KRAKENTIP("glance")
hover("rare")
check(F().wing:IsShown() and F().wing._file == "wing-rare" and F().rank:GetText() == "RARE", "silver wing and RARE")
check(isColor(F().level._color, 0.62, 0.62, 0.62), "grey: far below you")
leave()

section("the party on the quest")
UNITS.wolf.questLines = {
    { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 },
    { leftText = "Jokke", type = 18 }, { leftText = " - Ravaged Pelt: 5/8", type = 8 },
    { leftText = "Mira", type = 18 }, { leftText = " - Ravaged Pelt: 8/8", type = 8 },
}
UNITS.party1 = { guid = "Player-1-0000EEEE", name = "Jokke", class = "ROGUE", player = true, reaction = 5 }
hover("wolf")
local pips = {}
for _, pp in ipairs(F().pips) do if pp:IsShown() then pips[#pips + 1] = pp.letter:GetText() .. " " .. pp.count:GetText() end end
check(table.concat(pips, ", ") == "Y 3/8, J 5/8, M 8/8", "Glance: a small bar each, with counts: " .. table.concat(pips, ", "))
check(isColor(F().pips[2].letter._color, 1, 0.96, 0.41), "Jokke in rogue yellow")
check(isColor(F().pips[3].count._color, 0.28, 0.88, 0.31), "Mira's done: green")
leave()
SlashCmdList.KRAKENTIP("whisper")
hover("wolf")
check(plain(F().line2:GetText()):find("J5 M8", 1, true), "Whisper: the party's initials and counts: " .. plain(F().line2:GetText()))
leave()
SlashCmdList.KRAKENTIP("ledger")
hover("wolf")
local qr = {}
for _, r in ipairs(F().qrows) do if r:IsShown() then qr[#qr + 1] = r.name:GetText() .. " " .. r.count:GetText() end end
check(table.concat(qr, ", ") == "You 3/8, Jokke 5/8, Mira 8/8", "Ledger: a short table: " .. table.concat(qr, ", "))
leave()
SlashCmdList.KRAKENTIP("banner")
hover("wolf")
check(texts(F()):find("J 5/8", 1, true) and texts(F()):find("M 8/8", 1, true), "Banner: the members as counts: " .. texts(F()))
leave()
UNITS.wolf.questLines = { { leftText = "Jokke", type = 18 }, { leftText = " - Ravaged Pelt: 5/8", type = 8 } }
SlashCmdList.KRAKENTIP("glance")
hover("wolf")
check(not F().ring:IsShown() and F().pips[1]:IsShown() and F().pips[1].letter:GetText() == "J", "only Jokke on it: no ring, his bar")
leave()
USE_TOOLTIP_DATA = false
UNITS.wolf.questLines = {
    { leftText = "Ravaged Pelts", color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8" },
    { leftText = "Jokke" }, { leftText = " - Ravaged Pelt: 5/8" },
}
SlashCmdList.KRAKENTIP("ledger")
hover("wolf")
qr = {}
for _, r in ipairs(F().qrows) do if r:IsShown() then qr[#qr + 1] = r.name:GetText() .. " " .. r.count:GetText() end end
check(table.concat(qr, ", ") == "You 3/8, Jokke 5/8", "read from the text too, the name known as a group member: " .. table.concat(qr, ", "))
local others2 = {}
for _, o in ipairs(F().others) do if o:IsShown() then others2[#others2 + 1] = o:GetText() end end
check(#others2 == 0 and not F().note:IsShown(), "and the quest lines aren't repeated as other lines: " .. table.concat(others2, ","))
leave()
USE_TOOLTIP_DATA = true
UNITS.wolf.questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 } }
UNITS.party1 = nil

section("a quest done: the ring goes green")
UNITS.wolf.questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 8/8", type = 8 } }
SlashCmdList.KRAKENTIP("glance")
hover("wolf")
check(F().ring._done and F().ring._frac == 1, "done")
leave()
UNITS.wolf.questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 } }

section("a party member elsewhere: the zone, with a pin")
UNITS.party1 = { guid = "Player-1-0000EEEE", name = "Jokke", class = "ROGUE", className = "Rogue", race = "Orc", guild = "Aurora EU", faction = "Horde", level = 30, player = true, reaction = 5, hp = 640, hpMax = 900, inParty = true,
    questLines = { { leftText = "<Aurora EU>" }, { leftText = "Horde" }, { leftText = "Orgrimmar" } } }
for _, style in ipairs(KT.STYLES) do
    SlashCmdList.KRAKENTIP(style)
    hover("party1")
    check(texts(F()):find("Orgrimmar", 1, true), style .. ": the zone: " .. texts(F()))
    leave()
end
SlashCmdList.KRAKENTIP("ledger")
hover("party1")
check(F().rank:GetText() == "PARTY" and plain(rows()) == "Zone: Orgrimmar", "Ledger: PARTY, a Zone row: " .. plain(rows()))
check(F().rows[1].value:GetText():find("pin.tga", 1, true), "with the pin")
check(F().guild:GetText() == "<Aurora EU>" and F().note:GetText() == "Horde", "guild and faction only once")
leave()
SlashCmdList.KRAKENTIP("glance")
hover("party1")
check(plain(F().left:GetText()) == "Orgrimmar" and F().left2:GetText() == "<Aurora EU>" and F().right2:GetText() == "Horde", "Glance: the zone where the target goes, guild and faction below")
leave()
field("other", false)
hover("party1")
check(not texts(F()):find("Orgrimmar", 1, true), "and it can be turned off")
leave()
field("other", true)
UNITS.party1 = nil

section("what's on the card: each look its own fields")
UNITS.wolf.questLines = {
    { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 },
    { leftText = "Jokke", type = 18 }, { leftText = " - Ravaged Pelt: 5/8", type = 8 },
}
for _, style in ipairs(KT.STYLES) do
    SlashCmdList.KRAKENTIP(style)
    hover("wolf")
    local all = texts(F())
    check(all:find(style == "whisper" and "J5" or "5/8", 1, true), style .. ": the group's progress, by default: " .. all)
    check(all:find("3/8", 1, true), style .. ": your quest progress: " .. all)
    check(all:find("Wolf", 1, true), style .. ": the creature type: " .. all)
    check(not all:find("Hard", 1, true) and not all:find("Difficulty", 1, true), style .. ": no difficulty in words")
    leave()
end
SlashCmdList.KRAKENTIP("whisper")
SlashCmdList.KRAKENTIP("show group")
check(KT:Fields("whisper").group == false and KT:Fields("glance").group == true, "/kt show group: only this look")
hover("wolf")
check(not texts(F()):find("J5", 1, true), "Whisper without the group's: " .. texts(F()))
leave()
SlashCmdList.KRAKENTIP("show type")
SlashCmdList.KRAKENTIP("show health")
hover("wolf")
check(plain(F().line2:GetText()) == "Elite", "type and health off: " .. plain(F().line2:GetText()))
check(F().bar:IsShown(), "the bar stays")
leave()
KT:ResetFields("whisper")
check(KT:Fields("whisper").group and KT:Fields("whisper").type, "Defaults puts the look back")
SlashCmdList.KRAKENTIP("glance")
KT:SetField("rank", false)
hover("wolf")
check(F().level:GetText() == "24" and not F().wing:IsShown() and isColor(F()._edge, 0.44, 0.46, 0.53), "rank off: no +, no wing, the plain frame")
leave()
KT:ResetFields("glance")
UNITS.wolf.questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 } }

section("all four looks: every kind of unit, no errors, each its own size")
local sizes, distinct = {}, 0
UNITS.party1 = { guid = "Player-1-0000EEEE", name = "Jokke", class = "ROGUE", className = "Rogue", race = "Orc", guild = "Aurora EU", faction = "Horde", level = 30, player = true, reaction = 5, hp = 640, hpMax = 900, inParty = true,
    questLines = { { leftText = "Orgrimmar" } } }
for _, style in ipairs(KT.STYLES) do
    SlashCmdList.KRAKENTIP("style " .. style)
    for _, unit in ipairs({ "wolf", "boss", "boar", "innkeeper", "friend", "rogue", "rare", "longname", "party1" }) do
        hover(unit)
        local want = style == "banner" and "banner" or style
        if style == "banner" and unit == "party1" then want = "banner" end
        check(cardShown() and F() == Card.frames[want], style .. " shows for " .. unit)
        local w, h = F():GetWidth(), F():GetHeight()
        check(type(w) == "number" and w >= 50 and w <= 400 and type(h) == "number" and h >= 20 and h <= 300, ("%s %s: %sx%s"):format(style, unit, tostring(w), tostring(h)))
        if unit == "wolf" then
            local key = w .. "x" .. h
            if not sizes[key] then sizes[key] = true; distinct = distinct + 1 end
        end
        leave()
    end
end
check(distinct == 4, distinct .. " different sizes for the wolf")
UNITS.party1 = nil

section("width and height per look")
SlashCmdList.KRAKENTIP("glance")
hover("wolf")
local w0, h0 = F():GetWidth(), F():GetHeight()
leave()
SlashCmdList.KRAKENTIP("width 0.8")
SlashCmdList.KRAKENTIP("height 0.7")
check(S.dims.glance.w == 0.8 and S.dims.glance.h == 0.7, "saved for this look")
hover("wolf")
check(F():GetWidth() < w0 and F():GetHeight() < h0, ("smaller: %sx%s from %sx%s"):format(F():GetWidth(), F():GetHeight(), w0, h0))
check(F().bar._size[1] < 200 and F().bar._size[2] < 13, "the bar follows")
leave()
SlashCmdList.KRAKENTIP("ledger")
hover("wolf")
check(F():GetWidth() == 254, "other looks keep their size")
leave()
SlashCmdList.KRAKENTIP("glance")
SlashCmdList.KRAKENTIP("width 9")
check(S.dims.glance.w == 1.6, "capped at 160%")
SlashCmdList.KRAKENTIP("width 1")
SlashCmdList.KRAKENTIP("height 1")
check(S.dims.glance.w == nil and S.dims.glance.h == nil, "back to as designed")

section("the bar's texture and colour")
SlashCmdList.KRAKENTIP("bar flat")
SlashCmdList.KRAKENTIP("barcolor reaction")
check(S.bar.texture == "flat" and S.bar.color == "reaction", "saved")
hover("wolf")
check(F().bar._texture == "flat" and not F().bar.gloss:IsShown(), "flat, no shine")
check(isColor(F().bar._color, 0.78, 0.12, 0.10), "red: you can attack it")
leave()
SlashCmdList.KRAKENTIP("barcolor gold")
hover("friend")
check(isColor(F().bar._color, 1, 0.82, 0), "gold")
leave()
SlashCmdList.KRAKENTIP("bar")
check(S.bar.texture == "raid", "/kt bar steps to the next texture")
SlashCmdList.KRAKENTIP("bar slate")
SlashCmdList.KRAKENTIP("barcolor health")

section("action targeting: a soft target gets the card at the tooltip spot")
UNITS.softenemy = UNITS.wolf
TIP_TOKEN = SECRET
GameTooltip:SetOwner(UIParent)
GameTooltip:FillUnit("softenemy")
check(cardShown() and Card.info.unit == "softenemy", "card for the soft target: " .. tostring(Card.info and Card.info.unit))
check(not GameTooltip:IsShown(), "the game's tooltip hidden")
p = F():GetPoint(1)
check(p == "BOTTOMRIGHT", "at the tooltip spot, not the mouse")
tick(0.1)
check(not Card.fading, "stays while you face it")
UNITS.softenemy = UNITS.boar
tick(0.1)
check(Card.fading, "goes when you face another unit")
tick(0.25)
UNITS.softenemy = nil
TIP_TOKEN = nil

section("compare: the four side by side")
SlashCmdList.KRAKENTIP("compare")
local Cmp = KT.Compare
check(Cmp.frame:IsShown() and #Cmp.cells == 4, "four looks")
check(Cmp.cells[3].card.name:GetText() == "Timberling Ravager", "the sample first")
check(Cmp.cells[2].label:GetText() == "Glance  (in use)", "the look in use is marked: " .. tostring(Cmp.cells[2].label:GetText()))
hover("friend")
check(Cmp.cells[3].card.name:GetText() == "Thalianne", "hovering fills every look with that unit")
leave()
check(Cmp.cells[2].card.name:GetText() == "Thalianne", "and keeps it after the mouse leaves")
check(Cmp.cells[3].card.bar.text:GetText() == "800 / 900 · 89%", "health kept: " .. tostring(Cmp.cells[3].card.bar.text:GetText()))
hover("boss")
leave()
local led = Cmp.cells[3].card
check(led.name:GetText() == "Edwin VanCleef" and led.bar.text:GetText() == "<secret>", "a unit with hidden health keeps its percentage in Compare: " .. tostring(led.bar.text:GetText()))
Click(Cmp.cells[4])
check(S.style == "banner" and Cmp.cells[4].label:GetText() == "Banner  (in use)", "click a look to use it")
check(Cmp.frame:GetHeight() > 150, "sized to its looks: " .. Cmp.frame:GetHeight())
Cmp.frame:Hide()
SlashCmdList.KRAKENTIP("glance")

section("/kt blizzard: the game's own unit tooltips")
SlashCmdList.KRAKENTIP("blizzard")
check(not S.enabled, "off")
hover("wolf")
check(GameTooltip:IsShown() and not cardShown(), "the game's tooltip for units")
GameTooltip:Hide()
UNITS.mouseover = nil
SlashCmdList.KRAKENTIP("blizzard")
hover("wolf")
check(cardShown() and not GameTooltip:IsShown(), "the card again")
leave()

section("options window and the sample card")
SlashCmdList.KRAKENTIP("")
local O = KT.Options
check(O.frame:IsShown(), "options open")
check(O.position.buttons[1]:GetChecked() and not O.position.buttons[2]:GetChecked(), "mouse picked")
check(O.styleName:GetText() == "Glance  2/4", "Glance shown: " .. tostring(O.styleName:GetText()))
Click(O.styleNext)
check(S.style == "ledger" and O.styleName:GetText() == "Ledger  3/4", "> steps to the next look")
Click(O.stylePrev); Click(O.stylePrev)
check(S.style == "whisper", "< steps back")
SlashCmdList.KRAKENTIP("glance")
Click(O.widthText.minus); Click(O.widthText.minus)
Click(O.heightText.plus)
check(S.dims.glance.w == 0.8 and S.dims.glance.h == 1.1, "width and height of this look")
check(O.widthText:GetText() == "80%" and O.heightText:GetText() == "110%", "shown: " .. O.widthText:GetText() .. " " .. O.heightText:GetText())
SlashCmdList.KRAKENTIP("ledger")
check(O.widthText:GetText() == "100%", "each look its own")
SlashCmdList.KRAKENTIP("glance")
SlashCmdList.KRAKENTIP("width 1"); SlashCmdList.KRAKENTIP("height 1")
check(O.textureText:GetText() == "Slate" and O.colorText:GetText() == "By health", "the bar: " .. O.textureText:GetText() .. ", " .. O.colorText:GetText())
Click(O.textureText.plus)
check(S.bar.texture == "smooth" and O.textureText:GetText() == "Smooth", "bar texture")
Click(O.colorText.minus)
check(S.bar.color == "gold" and O.colorText:GetText() == "Gold", "bar colour, round the end")
SlashCmdList.KRAKENTIP("bar slate"); SlashCmdList.KRAKENTIP("barcolor health")
Click(O.position.buttons[2])
check(S.position == "tooltip", "radio switches to the tooltip spot")
Click(O.sampleButton)
check(Card:IsSampleShown(), "sample card shown")
check(O.sampleButton:GetText() == "Hide the sample card", "button says hide")
check(F() == Card.frames.glance and F().ring.text:GetText() == "3/8", "sample filled")
SlashCmdList.KRAKENTIP("ledger")
check(S.style == "ledger" and Card:IsSampleShown() and F() == Card.frames.ledger, "the sample switches to the Ledger")
check(rowText(2) == "Killed with Thalianne: 42", "the sample's kills together")
check(not Card.frames.glance:IsShown(), "the Glance sample is gone")
SHIFT = true
FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
SlashCmdList.KRAKENTIP("whisper")
check(F() == Card.frames.whisper, "Shift leaves the sample as it is")
SHIFT = false
GameTooltip:SetItem("Linen Cloth")
GameTooltip:Hide()
check(Card:IsSampleShown(), "the sample stays while other tooltips come and go")
SlashCmdList.KRAKENTIP("scale 9")
check(S.scale == 1.6 and F():GetScale() == 1.6, "scale capped and applied")
O.frame:Hide()
check(not Card:IsSampleShown(), "closing the options hides the sample")
SlashCmdList.KRAKENTIP("scale 1")
SlashCmdList.KRAKENTIP("glance")
SlashCmdList.KRAKENTIP("mouse")

section("the options show this look's fields")
SlashCmdList.KRAKENTIP("")
local Op = KT.Options
check(#Op.checks == #KT.FIELDS + 3, "a tick for every field, Use the Kraken card, Shift and combat")
check(Op.fieldsHeading:GetText() == "On the card: Glance", "named after the look: " .. tostring(Op.fieldsHeading:GetText()))
SlashCmdList.KRAKENTIP("whisper")
check(Op.fieldsHeading:GetText() == "On the card: Whisper" and Op.fieldChecks.guild:GetChecked(), "switching the look switches the ticks")
Click(Op.fieldChecks.guild)
check(not KT:Fields("whisper").guild and KT:Fields("glance").guild, "a tick changes this look only")
Click(Op.defaultsButton)
check(KT:Fields("whisper").guild, "Defaults")
Op.frame:Hide()
SlashCmdList.KRAKENTIP("glance")

section("minimap button")
local mm = KrakentipMinimapButton
check(mm and mm:IsShown(), "there")
Click(mm, "RightButton")
check(S.style == "ledger", "right-click: next style")
for _ = 1, 3 do Click(mm, "RightButton") end
check(S.style == "glance", "and round again")
SHIFT = true
Click(mm)
check(KT.Compare.frame:IsShown(), "shift-click: compare")
SHIFT = false
KT.Compare.frame:Hide()
Click(mm)
check(O.frame:IsShown(), "click opens the options")
O.frame:Hide()
SlashCmdList.KRAKENTIP("minimap")
check(not mm:IsShown(), "/kt minimap hides it")
SlashCmdList.KRAKENTIP("minimap")

section("names in any alphabet: the fonts are families with a file for each")
UNITS.ivan = { guid = "Player-1-0000DDDD", name = "Иван", class = "WARRIOR", className = "Warrior", race = "Orc", level = 30, player = true, hostile = true, hp = 900, hpMax = 900 }
UNITS.rogue.target = "ivan"
for _, style in ipairs(KT.STYLES) do
    SlashCmdList.KRAKENTIP(style)
    hover("rogue")
    for _, pt in ipairs(F().parts) do
        if pt._kind == "text" then
            local fam = pt._family
            local files = {}
            for _, m in ipairs(fam and fam._members or {}) do files[m.alphabet] = m.file end
            check(fam and files.russian and files.korean and files.roman, style .. ": a font family for every text")
        end
    end
    leave()
end
SlashCmdList.KRAKENTIP("ledger")
hover("rogue")
check(rows():find("Иван", 1, true), "the target's name as it is: " .. rows())
local files = {}
for _, m in ipairs(F().name._family._members) do files[m.alphabet] = m.file end
check(files.korean == "Fonts\\K_Pagetext.TTF" and files.simplifiedchinese == "Fonts\\ARHei.ttf", "the game's own Korean and Chinese files, not guessed ones: " .. tostring(files.korean))
leave()
UNITS.rogue.target = "player"
SlashCmdList.KRAKENTIP("fonts")
check(table.concat(CHAT, "\n", #CHAT - 5):find("traditionalchinese: Fonts\\bHEI01B.TTF (GameFontHighlight)", 1, true), "/kt fonts says where each file came from")
local keep = CreateFontFamily
CreateFontFamily = nil
local probe = UIParent:CreateFontString()
KT.Widgets.SetFont(probe, 23, "OUTLINE")
check(probe._family == GameFontHighlight, "no font families: the game's own text object, with every alphabet")
CreateFontFamily = keep
local count = 0
for _ in pairs(FONT_FAMILIES) do count = count + 1 end
check(count < 40, count .. " font families, one per size and outline")
SlashCmdList.KRAKENTIP("glance")

section("Banner hangs from the nameplate")
SlashCmdList.KRAKENTIP("banner")
hover("wolf")
local p1, rel1 = F():GetPoint(1)
check(F() == Card.frames.banner and p1 == "TOP" and rel1 == PLATE, "under the nameplate")
check(not texts(F()):find("Timberling", 1, true) and texts(F()):find("Beast · Wolf", 1, true), "no name (the plate has it), the type: " .. texts(F()))
check(F().level:GetText() == "24+" and F().ring:IsShown() and plain(F().target:GetText()) == "YOU", "level, ring, YOU")
check(F().notchFill:IsShown() and F().notchEdge:IsShown() and isColor(F().notchEdge._tint, 0.84, 0.65, 0.20), "the notch, in the frame's gold")
leave()
UNITS.mouseover = UNITS.wolf
PLATES.mouseover = nil
GameTooltip:SetUnit("mouseover")
check(F() == Card.frames.glance, "no nameplate: Glance at the cursor")
PLATES.mouseover = PLATE
tick(0.25)
check(F() == Card.frames.banner and cardShown(), "the plate shows up: the Banner takes over")
leave()
hover("innkeeper")
check(plain(F().title:GetText()) == "Innkeeper" and F().title:GetText():find("BinderGossipIcon", 1, true), "an NPC: its role with the icon: " .. tostring(F().title:GetText()))
leave()

section("Shift opens the Ledger, combat shrinks it")
SlashCmdList.KRAKENTIP("glance")
hover("wolf")
SHIFT = true
FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
check(F() == Card.frames.ledger and cardShown(), "Shift: the Ledger, at once")
check(not Card.frames.glance:IsShown(), "and Glance makes way")
SHIFT = false
FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
check(F() == Card.frames.glance and cardShown(), "let go: Glance again")
leave()
SlashCmdList.KRAKENTIP("ledger")
hover("wolf")
COMBAT = true
FireEvent("PLAYER_REGEN_DISABLED")
check(F() == Card.frames.glance, "combat: the Ledger shrinks to Glance")
SHIFT = true
FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
check(F() == Card.frames.ledger, "Shift still opens it, in combat too")
SHIFT = false
FireEvent("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
check(F() == Card.frames.ledger, "the fight ends: the Ledger again")
leave()
SlashCmdList.KRAKENTIP("combat")
check(not S.combatGlance, "/kt combat switches it off")
COMBAT = true
hover("wolf")
check(F() == Card.frames.ledger, "and the Ledger stays in combat")
leave()
COMBAT = false
SlashCmdList.KRAKENTIP("combat")
SlashCmdList.KRAKENTIP("shift")
check(not S.shiftLedger, "/kt shift switches Shift off")
SlashCmdList.KRAKENTIP("glance")
SHIFT = true
hover("wolf")
check(F() == Card.frames.glance, "Shift does nothing then")
leave()
SHIFT = false
SlashCmdList.KRAKENTIP("shift")

section("settings from 0.7 and before")
KrakentipDB.settings.schema = nil
KrakentipDB.settings.style = "minimal"
KrakentipDB.settings.bar = { texture = "smooth", color = "reaction" }
KrakentipDB.settings.dims = { minimal = { w = 1.2 }, glance = { h = 0.9 } }
KrakentipDB.settings.fields = { icons = { guild = true }, ledger = { other = false } }
KT:LoadDB()
S = KrakentipDB.settings
check(S.style == "glance", "a look that's gone becomes Glance")
check(S.bar.texture == "slate" and S.bar.color == "health", "the bar takes the new look")
check(not S.dims.minimal and S.dims.glance.h == 0.9, "sizes of the looks that are gone go with them")
check(not S.fields.icons and S.fields.ledger.other == false, "and their fields")
S.style = "ledger"
KT:LoadDB()
check(S.style == "ledger", "once moved over, a choice stays")
KrakentipDB.settings.lines = { target = false, quests = true, other = false, difficulty = false, friends = true }
KrakentipDB.settings.fields = {}
KT:LoadDB()
check(KT:Fields("whisper").target == false and KT:Fields("glance").other == false and KT:Fields("banner").quests, "the oldest ticks moved over")
check(KrakentipDB.settings.lines == nil, "and gone")
KrakentipDB.settings.fields = {}
S = KrakentipDB.settings
S.dims = {}
SlashCmdList.KRAKENTIP("glance")

section("errors")
check(#ERRORS == 0, #ERRORS .. " errors raised")

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("tests failed") end
