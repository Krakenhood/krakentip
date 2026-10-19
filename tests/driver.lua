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

local function hover(unit)
    UNITS.mouseover = UNITS[unit]
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
local function isColor(c, r, g, b) return math.abs(c[1] - r) < 0.01 and math.abs(c[2] - g) < 0.01 and math.abs(c[3] - b) < 0.01 end

--------------------------------------------------------------------------------
section("defaults")
check(S.position == "mouse", "next to the mouse by default")
check(S.style == "regular", "regular style by default")
check(S.enabled, "on by default")
check(S.lines.difficulty == false, "difficulty off by default: the level's colour says it")
hover("wolf")
check(rows() == "Targeting: You", "no difficulty line by default: " .. rows())
UNITS.mouseover = nil
for _ = 1, 4 do tick(0.1) end
S.lines.difficulty = true -- the tests below look at it too

section("an enemy: the card, and the game's unit tooltip never shows")
hover("wolf")
check(cardShown(), "card shown")
check(not GameTooltip:IsShown(), "the game's tooltip is hidden, not just see-through")
GameTooltip:Show()
check(not GameTooltip:IsShown(), "and stays hidden when the game shows it again")
check(F().name:GetText() == "Timberling Ravager", "name")
check(F().level:GetText() == 24, "level")
check(F().sub:GetText() == "Beast · Wolf", "type and family: " .. tostring(F().sub:GetText()))
check(F().tag:IsShown() and F().tag.text:GetText() == "ELITE", "elite badge")
check(F().bar:GetValue() == 1116 and F().bar._max == 1800, "health bar")
check(F().bar.text:GetText() == "1,116 / 1,800  62%", "health text: " .. tostring(F().bar.text:GetText()))
check(rows() == "Targeting: You | Difficulty: Hard (+3)", "rows: " .. rows())
check(F().quests[1]:GetText() == "Ravaged Pelts" and F().quests[2]:GetText() == " - Ravaged Pelt: 3/8", "quest lines copied")
check(isColor(F().name._color, 1, 0.29, 0.23), "hostile red name")

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

section("a friendly NPC gets the card too")
hover("innkeeper")
check(cardShown() and not GameTooltip:IsShown(), "card instead of the game's tooltip")
check(F().sub:GetText() == "Innkeeper · Humanoid", "title and type: " .. tostring(F().sub:GetText()))
check(isColor(F().name._color, 0.35, 0.95, 0.35), "green name")
check(rows() == "", "no difficulty for a friend: " .. rows())
check(F().bar.text:GetText() == "100%", "health")
leave()

section("a friendly player: class colour, race and class, guild")
hover("friend")
check(isColor(F().name._color, 0.25, 0.78, 0.92), "mage blue name")
check(F().sub:GetText() == "Night Elf · Mage", "race and class: " .. tostring(F().sub:GetText()))
check(rows() == "Guild: <Krakenhood>", "guild: " .. rows())
check(not F().tag:IsShown(), "no badge")
leave()

section("an enemy player")
hover("rogue")
check(F().sub:GetText() == "Undead · Rogue", "race and class")
check(rows() == "Targeting: You | Difficulty: Even (+2)", "rows: " .. rows())
leave()

section("neutral creature, Classic-style percent health, no target")
hover("boar")
check(isColor(F().name._color, 1, 0.85, 0.20), "neutral yellow name")
check(F().bar.text:GetText() == "40%", "percent only: " .. tostring(F().bar.text:GetText()))
check(rowText(1) == "Difficulty: Trivial (-11)", "difficulty first: " .. tostring(rowText(1)))
check(not F().tag:IsShown(), "no badge for a normal creature")
check(not F().sep:IsShown() and not F().quests[1]:IsShown(), "no quest lines")
leave()

section("a boss with secret health")
hover("boss")
check(cardShown(), "card shown")
check(F().skull:IsShown() and not F().level:IsShown(), "skull instead of a level")
check(rawequal(F().bar:GetValue(), SECRET), "the bar still gets the secret value")
check(F().bar.text:GetText() == "<secret>", "hidden numbers: the game writes the percentage itself")
check(rowText(1) == "Difficulty: Deadly", "deadly: " .. tostring(rowText(1)))
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
check(F().bar:GetValue() == 900 and F().bar.text:GetText() == "900 / 1,800  50%", "health: " .. tostring(F().bar.text:GetText()))
check(rows() == "Difficulty: Hard (+3)", "target line gone: " .. rows())
check(F().quests[2]:GetText() == " - Ravaged Pelt: 3/8", "quest lines kept")
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

section("lines can be turned off")
S.lines.target, S.lines.quests = false, false
hover("wolf")
check(rows() == "Difficulty: Hard (+3)", "no target row")
check(not F().quests[1]:IsShown(), "no quest lines")
S.lines.target, S.lines.quests = true, true
leave()

section("Krakenfriends: kills together")
Krakenfriends = { journey = { partnerName = "Thalianne", pairs = { a = { mobs = { [4521] = { c = 30 } } }, b = { mobs = { [4521] = { c = 12 } } } } } }
hover("wolf")
check(rowText(3) == "Killed with Thalianne: 42", "kills summed over chapters: " .. tostring(rowText(3)))
leave()
Krakenfriends = nil

section("tooltip data without lines: quest lines read from the text")
USE_TOOLTIP_DATA = false
hover("wolf")
check(F().quests[1]:GetText() == "Ravaged Pelts" and F().quests[2]:GetText() == " - Ravaged Pelt: 3/8", "quest lines read from the text")
leave()
USE_TOOLTIP_DATA = true

section("Mid")
SlashCmdList.KRAKENTIP("style mid")
check(S.style == "mid", "saved")
hover("wolf")
check(F() == Card.frames.mid and cardShown(), "the mid card")
check(not Card.frames.regular:IsShown(), "the regular one hidden")
check(F().name:GetText() == "Timberling Ravager" and F().level:GetText() == 24, "level and name")
check(F().sub:GetText() == "Beast · Wolf" and F().target:GetText() == "» You", "type, target: " .. tostring(F().target:GetText()))
check(F().bar.text:GetText() == "62%", "percentage on the thin bar: " .. tostring(F().bar.text:GetText()))
check(F().quests[1]:GetText() == " - Ravaged Pelt: 3/8" and not (F().quests[2] and F().quests[2]:IsShown()), "objectives only")
local mw, mh = F():GetWidth(), F():GetHeight()
check(mw == 214 and mh < 100, ("compact: %sx%s"):format(mw, mh))
leave()
hover("friend")
check(F().sub:GetText() == "Night Elf · Mage · <Krakenhood>", "player: " .. tostring(F().sub:GetText()))
leave()

section("Minimal")
SlashCmdList.KRAKENTIP("style minimal")
hover("wolf")
check(F() == Card.frames.minimal and cardShown(), "the minimal card")
check(F():GetHeight() < 45, "two short lines: " .. F():GetHeight())
check(F().name:GetText() == "Timberling Ravager" and F().tag.text:GetText() == "ELITE", "name, badge")
check(F().pct:GetText() == "62%", "percentage")
check(F().kind:GetText() == "Beast · Wolf", "creature type: " .. tostring(F().kind:GetText()))
check(F().target:GetText() == "» You" and F().quest:GetText() == "3/8", "target and quest count: " .. tostring(F().target:GetText()) .. " " .. tostring(F().quest:GetText()))
check(F():GetWidth() > 150 and F():GetWidth() < 300, "narrower than one long line: " .. F():GetWidth())
leave()
hover("innkeeper")
check(not F().target:IsShown() and not F().quest:IsShown() and not F().tag:IsShown(), "nothing extra for an innkeeper")
leave()
SlashCmdList.KRAKENTIP("style")
check(S.style == "classic", "/kt style goes on to the next look")
SlashCmdList.KRAKENTIP("regular")
check(S.style == "regular", "/kt regular picks a look by its name")

section("all eight looks: every kind of unit, no errors, each its own size")
local sizes, distinct = {}, 0
for _, style in ipairs(KT.STYLES) do
    SlashCmdList.KRAKENTIP("style " .. style)
    for _, unit in ipairs({ "wolf", "boss", "boar", "innkeeper", "friend", "rogue" }) do
        hover(unit)
        check(cardShown() and F() == Card.frames[style], style .. " shows for " .. unit)
        check(F().name:GetText() == UNITS[unit].name or (style == "plate" and F().name:GetText():find(UNITS[unit].name, 1, true)), style .. ": name of " .. unit)
        local w, h = F():GetWidth(), F():GetHeight()
        check(type(w) == "number" and w >= 100 and w <= 400 and type(h) == "number" and h >= 20 and h <= 260, ("%s %s: %sx%s"):format(style, unit, tostring(w), tostring(h)))
        if unit == "wolf" then
            local key = w .. "x" .. h
            if not sizes[key] then sizes[key] = true; distinct = distinct + 1 end
        end
        leave()
    end
end
check(distinct >= 7, distinct .. " different sizes for the wolf")
check(#KT.STYLES == 8 and not KT.Layouts.wide and not KT.Layouts.column, "Wide and Column are gone")

section("every look shows the creature type and the quest progress")
local function texts(f)
    local out = {}
    for _, p in ipairs(f.parts) do
        if p:IsShown() and p.GetText and p:GetText() then out[#out + 1] = tostring(p:GetText()) end
        if p.text and p:IsShown() and p.text.GetText then out[#out + 1] = tostring(p.text:GetText()) end
    end
    return table.concat(out, " | ")
end
for _, style in ipairs(KT.STYLES) do
    SlashCmdList.KRAKENTIP(style)
    hover("wolf")
    local all = texts(F())
    check(all:find("3/8", 1, true), style .. ": quest progress in " .. all)
    check(all:find("Wolf", 1, true) or all:find("Beast", 1, true), style .. ": creature type in " .. all)
    check(not all:find("Hard", 1, true) or style == "regular" or style == "classic", style .. ": no difficulty word outside Regular and Classic")
    leave()
end
SlashCmdList.KRAKENTIP("regular")

section("width and height per look")
hover("wolf")
local w0, h0 = F():GetWidth(), F():GetHeight()
leave()
SlashCmdList.KRAKENTIP("width 0.8")
SlashCmdList.KRAKENTIP("height 0.7")
check(S.dims.regular.w == 0.8 and S.dims.regular.h == 0.7, "saved for this look")
hover("wolf")
check(F():GetWidth() < w0 and F():GetHeight() < h0, ("smaller: %sx%s from %sx%s"):format(F():GetWidth(), F():GetHeight(), w0, h0))
check(F().bar._size[1] < 220 and F().bar._size[2] < 16, "the bar follows")
leave()
SlashCmdList.KRAKENTIP("mid")
hover("wolf")
check(F():GetWidth() == 214, "other looks keep their size")
leave()
SlashCmdList.KRAKENTIP("regular")
SlashCmdList.KRAKENTIP("width 9")
check(S.dims.regular.w == 1.6, "capped at 160%")
SlashCmdList.KRAKENTIP("width 1")
SlashCmdList.KRAKENTIP("height 1")
check(S.dims.regular.w == nil and S.dims.regular.h == nil, "back to as designed")

section("the bar's texture and colour")
SlashCmdList.KRAKENTIP("bar flat")
SlashCmdList.KRAKENTIP("barcolor health")
check(S.bar.texture == "flat" and S.bar.color == "health", "saved")
hover("wolf")
check(F().bar._texture == "flat", "flat texture")
local c = F().bar._color
check(c[1] > 0.5 and c[2] > 0.5, "62% health: yellowish " .. table.concat(c, ","))
leave()
SlashCmdList.KRAKENTIP("barcolor gold")
hover("friend")
check(isColor(F().bar._color, 1, 0.82, 0), "gold")
leave()
SlashCmdList.KRAKENTIP("bar")
check(S.bar.texture == "raid", "/kt bar steps to the next texture")
SlashCmdList.KRAKENTIP("bar smooth")
SlashCmdList.KRAKENTIP("barcolor reaction")

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

section("difficulty off: no word, the level's colour still says it")
S.lines.difficulty = false
hover("wolf")
check(rows() == "Targeting: You", "no Difficulty line: " .. rows())
check(isColor(F().level._color, 1, 0.5, 0.25), "level in orange (hard)")
leave()
S.lines.difficulty = true
check(#ERRORS == 0, "no errors in any look")
SlashCmdList.KRAKENTIP("regular")

section("compare: every look side by side")
SlashCmdList.KRAKENTIP("compare")
local Cmp = KT.Compare
check(Cmp.frame:IsShown() and #Cmp.cells == 8, "eight looks")
check(Cmp.cells[1].card.name:GetText() == "Timberling Ravager", "the sample first")
check(Cmp.cells[1].label:GetText() == "Regular  (in use)", "the look in use is marked: " .. tostring(Cmp.cells[1].label:GetText()))
hover("friend")
check(Cmp.cells[5].card.name:GetText() == "Thalianne", "hovering fills every look with that unit")
leave()
check(Cmp.cells[2].card.name:GetText() == "Thalianne", "and keeps it after the mouse leaves")
check(Cmp.cells[2].card.bar.text:GetText() == "89%", "health kept: " .. tostring(Cmp.cells[2].card.bar.text:GetText()))
hover("boss")
leave()
local reg = Cmp.cells[1].card
check(reg.name:GetText() == "Edwin VanCleef" and reg.bar.text:GetText() == "<secret>", "a unit with hidden health keeps its percentage in Compare: " .. tostring(reg.bar.text:GetText()))
Click(Cmp.cells[6])
check(S.style == "portrait" and Cmp.cells[6].label:GetText() == "Portrait  (in use)", "click a look to use it")
check(Cmp.frame:GetHeight() > 200, "sized to its looks: " .. Cmp.frame:GetHeight())
Cmp.frame:Hide()
SlashCmdList.KRAKENTIP("regular")

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
check(O.styleName:GetText() == "Regular  1/8", "regular shown: " .. tostring(O.styleName:GetText()))
Click(O.styleNext)
check(S.style == "mid" and O.styleName:GetText() == "Mid  2/8", "> steps to the next look")
Click(O.stylePrev); Click(O.stylePrev)
check(S.style == "icons", "< steps back, round the end")
SlashCmdList.KRAKENTIP("regular")
Click(O.widthText.minus); Click(O.widthText.minus)
Click(O.heightText.plus)
check(S.dims.regular.w == 0.8 and S.dims.regular.h == 1.1, "width and height of this look")
check(O.widthText:GetText() == "80%" and O.heightText:GetText() == "110%", "shown: " .. O.widthText:GetText() .. " " .. O.heightText:GetText())
SlashCmdList.KRAKENTIP("mid")
check(O.widthText:GetText() == "100%", "each look its own")
SlashCmdList.KRAKENTIP("regular")
SlashCmdList.KRAKENTIP("width 1"); SlashCmdList.KRAKENTIP("height 1")
Click(O.textureText.plus)
check(S.bar.texture == "flat" and O.textureText:GetText() == "Flat", "bar texture")
Click(O.colorText.minus)
check(S.bar.color == "gold" and O.colorText:GetText() == "Gold", "bar colour, round the end")
SlashCmdList.KRAKENTIP("bar smooth"); SlashCmdList.KRAKENTIP("barcolor reaction")
Click(O.position.buttons[2])
check(S.position == "tooltip", "radio switches to the tooltip spot")
Click(O.sampleButton)
check(Card:IsSampleShown(), "sample card shown")
check(O.sampleButton:GetText() == "Hide the sample card", "button says hide")
check(rowText(3) == "Killed with Thalianne: 42", "sample filled")
SlashCmdList.KRAKENTIP("minimal")
check(S.style == "minimal" and Card:IsSampleShown() and F() == Card.frames.minimal, "the sample switches to minimal")
check(not Card.frames.regular:IsShown(), "the regular sample is gone")
GameTooltip:SetItem("Linen Cloth")
GameTooltip:Hide()
check(Card:IsSampleShown(), "the sample stays while other tooltips come and go")
SlashCmdList.KRAKENTIP("scale 9")
check(S.scale == 1.6 and F():GetScale() == 1.6, "scale capped and applied")
O.frame:Hide()
check(not Card:IsSampleShown(), "closing the options hides the sample")
SlashCmdList.KRAKENTIP("scale 1")
SlashCmdList.KRAKENTIP("regular")
SlashCmdList.KRAKENTIP("mouse")

section("minimap button")
local mm = KrakentipMinimapButton
check(mm and mm:IsShown(), "there")
Click(mm, "RightButton")
check(S.style == "mid", "right-click: next style")
for _ = 1, 7 do Click(mm, "RightButton") end
check(S.style == "regular", "and round again")
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
    for _, p in ipairs(F().parts) do
        if p._kind == "text" then
            local fam = p._family
            local files = {}
            for _, m in ipairs(fam and fam._members or {}) do files[m.alphabet] = m.file end
            check(fam and files.russian and files.korean and files.roman, style .. ": a font family for every text")
            if p._title then check(files.russian == "Fonts\\MORPHEUS_CYR.TTF", style .. ": the fantasy font in Cyrillic too") end
        end
    end
    leave()
end
SlashCmdList.KRAKENTIP("regular")
hover("rogue")
check(rows():find("Иван", 1, true), "the target's name as it is: " .. rows())
leave()
UNITS.rogue.target = "player"
SlashCmdList.KRAKENTIP("regular")
hover("rogue")
local files = {}
for _, m in ipairs(F().name._family._members) do files[m.alphabet] = m.file end
check(files.korean == "Fonts\\K_Pagetext.TTF" and files.simplifiedchinese == "Fonts\\ARHei.ttf", "the game's own Korean and Chinese files, not guessed ones: " .. tostring(files.korean))
check(files.roman == "Fonts\\MORPHEUS.TTF" and files.russian == "Fonts\\MORPHEUS_CYR.TTF", "the name keeps the fantasy font")
leave()
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

section("a party member elsewhere: the zone line from the game's tooltip")
UNITS.party1 = { guid = "Player-1-0000EEEE", name = "Jokke", class = "ROGUE", className = "Rogue", race = "Orc", guild = "Aurora EU", level = 30, player = true, reaction = 5, hp = 900, hpMax = 900,
    questLines = { { leftText = "<Aurora EU>" }, { leftText = "Horde" }, { leftText = "Orgrimmar" } } }
SlashCmdList.KRAKENTIP("regular")
hover("party1")
local others = {}
for _, o in ipairs(F().others) do if o:IsShown() then others[#others + 1] = o:GetText() end end
check(table.concat(others, ",") == "Orgrimmar", "only the zone comes over, not the guild or faction again: " .. table.concat(others, ","))
leave()
SlashCmdList.KRAKENTIP("classic")
hover("party1")
local classic = {}
for _, l in ipairs(F().lines) do if l:IsShown() then classic[#classic + 1] = l:GetText() end end
check(table.concat(classic, "|"):find("Orgrimmar", 1, true), "Classic shows it too: " .. table.concat(classic, "|"))
leave()
S.lines.other = false
SlashCmdList.KRAKENTIP("regular")
hover("party1")
check(not F().others[1] or not F().others[1]:IsShown(), "and it can be turned off")
leave()
S.lines.other = true

section("your group's quest progress, under each member's name")
UNITS.party1.questLines = nil
UNITS.party1.name = "Jokke"
UNITS.wolf.questLines = {
    { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } },
    { leftText = " - Ravaged Pelt: 3/8", type = 8 },
    { leftText = "Jokke", type = 18 },
    { leftText = " - Ravaged Pelt: 5/8", type = 8 },
}
hover("wolf")
local q = {}
for _, fs in ipairs(F().quests) do if fs:IsShown() then q[#q + 1] = fs:GetText() end end
check(table.concat(q, "|") == "Ravaged Pelts| - Ravaged Pelt: 3/8|Jokke| - Ravaged Pelt: 5/8", "every member's lines, as the game shows them: " .. table.concat(q, "|"))
check(isColor(F().quests[3]._color, 0.78, 0.72, 0.60), "the member's name dim")
check(Card.info.quests[4][4] == "Jokke", "their objective knows it's theirs")
leave()
SlashCmdList.KRAKENTIP("minimal")
hover("wolf")
check(F().quest:GetText() == "3/8", "your own count first on the small looks")
leave()
UNITS.wolf.questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = "Jokke", type = 18 }, { leftText = " - Ravaged Pelt: 5/8", type = 8 } }
hover("wolf")
check(F().quest:GetText() == "Jokke 5/8", "a member's count when you have none: " .. tostring(F().quest:GetText()))
leave()
SlashCmdList.KRAKENTIP("mid")
hover("wolf")
check(F().quests[1]:GetText() == "Jokke: Ravaged Pelt: 5/8", "Mid names whose it is: " .. tostring(F().quests[1]:GetText()))
leave()
USE_TOOLTIP_DATA = false
UNITS.wolf.questLines = {
    { leftText = "Ravaged Pelts", color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8" },
    { leftText = "Jokke" }, { leftText = " - Ravaged Pelt: 5/8" },
}
SlashCmdList.KRAKENTIP("regular")
hover("wolf")
q = {}
for _, fs in ipairs(F().quests) do if fs:IsShown() then q[#q + 1] = fs:GetText() end end
check(table.concat(q, "|") == "Ravaged Pelts| - Ravaged Pelt: 3/8|Jokke| - Ravaged Pelt: 5/8", "read from the text too, the name known as a group member: " .. table.concat(q, "|"))
local others2 = {}
for _, o in ipairs(F().others) do if o:IsShown() then others2[#others2 + 1] = o:GetText() end end
check(#others2 == 0, "and the quest lines aren't repeated as other lines: " .. table.concat(others2, ","))
leave()
USE_TOOLTIP_DATA = true
UNITS.wolf.questLines = { { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } }, { leftText = " - Ravaged Pelt: 3/8", type = 8 } }
UNITS.party1 = nil

section("errors")
check(#ERRORS == 0, #ERRORS .. " errors raised")

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("tests failed") end
