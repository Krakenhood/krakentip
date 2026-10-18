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
check(F().bar.text:GetText() == "", "no numbers when they're secret")
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
check(F().sub:GetText() == "Beast · Wolf" and F().target:GetText() == "You", "type, target")
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
check(F():GetHeight() == 22, "one line high")
check(F().name:GetText() == "Timberling Ravager" and F().tag.text:GetText() == "ELITE", "name, badge")
check(F().bar.text:GetText() == "62%", "percentage")
check(F().target:GetText() == "» You" and F().quest:GetText() == "3/8", "target and quest count: " .. tostring(F().target:GetText()) .. " " .. tostring(F().quest:GetText()))
check(F():GetWidth() > 200, "as wide as its contents: " .. F():GetWidth())
leave()
hover("innkeeper")
check(not F().target:IsShown() and not F().quest:IsShown() and not F().tag:IsShown(), "nothing extra for an innkeeper")
leave()
SlashCmdList.KRAKENTIP("style")
check(S.style == "regular", "/kt style cycles back to regular")

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
check(O.style.buttons[1]:GetChecked(), "regular picked")
Click(O.position.buttons[2])
check(S.position == "tooltip", "radio switches to the tooltip spot")
Click(O.sampleButton)
check(Card:IsSampleShown(), "sample card shown")
check(O.sampleButton:GetText() == "Hide the sample card", "button says hide")
check(rowText(3) == "Killed with Thalianne: 42", "sample filled")
Click(O.style.buttons[3])
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
Click(mm, "RightButton"); Click(mm, "RightButton")
check(S.style == "regular", "and round again")
Click(mm)
check(O.frame:IsShown(), "click opens the options")
O.frame:Hide()
SlashCmdList.KRAKENTIP("minimap")
check(not mm:IsShown(), "/kt minimap hides it")
SlashCmdList.KRAKENTIP("minimap")

section("errors")
check(#ERRORS == 0, #ERRORS .. " errors raised")

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("tests failed") end
