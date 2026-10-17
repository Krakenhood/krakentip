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

UNITS.player = { guid = "Player-1-0000AAAA", name = "Krakenhood", class = "WARRIOR", level = 21, player = true }
UNITS.wolf = {
    guid = "Creature-0-1-2-3-4521-000ABC", name = "Timberling Ravager", level = 24, ctype = "Beast", family = "Wolf",
    cls = "elite", hostile = true, hp = 1116, hpMax = 1800, target = "player",
    questLines = {
        { leftText = "Ravaged Pelts", type = 17, color = { 1, 0.82, 0 } },
        { leftText = " - Ravaged Pelt: 3/8", type = 8 },
    },
}
UNITS.boar = { guid = "Creature-0-1-2-3-113-000DEF", name = "Bristleback", level = 10, ctype = "Beast", family = "Boar", hostile = true, reaction = 4, hp = 40, hpMax = 100 }
UNITS.guard = { guid = "Creature-0-1-2-3-68-000111", name = "Stormwind Guard", level = 55, ctype = "Humanoid", hostile = false, hp = 5000, hpMax = 5000 }
UNITS.rogue = { guid = "Player-1-0000BBBB", name = "Sneakystab", class = "MAGE", level = 21, player = true, hostile = true, hp = 900, hpMax = 900 }
UNITS.boss = { guid = "Creature-0-1-2-3-639-000222", name = "Edwin VanCleef", level = 21, boss = true, ctype = "Humanoid", cls = "elite", hostile = true, hp = SECRET, hpMax = SECRET }

FireEvent("ADDON_LOADED", "Krakentip")
FireEvent("PLAYER_LOGIN")
local Card = KT.Card

local function hover(unit)
    UNITS.mouseover = UNITS[unit]
    GameTooltip:SetUnit("mouseover")
end
local function leave()
    UNITS.mouseover = nil
    GameTooltip:Hide()
end
local function cardShown() return Card.frame and Card.frame:IsShown() end
local function rowText(i) local r = Card.rows[i]; return r and r:IsShown() and (r.label:GetText() .. ": " .. tostring(r.value:GetText())) end

--------------------------------------------------------------------------------
section("defaults")
check(KrakentipDB.settings.position == "mouse", "next to the mouse by default")
check(KrakentipDB.settings.enabled, "on by default")

section("an enemy gets the card, the game's tooltip goes invisible")
hover("wolf")
check(cardShown(), "card shown")
check(GameTooltip:GetAlpha() == 0, "game tooltip invisible")
check(GameTooltip:IsShown(), "game tooltip still there (it keeps its lifecycle)")
check(Card.name:GetText() == "Timberling Ravager", "name")
check(Card.badge.level:GetText() == 24, "level " .. tostring(Card.badge.level:GetText()))
check(Card.sub:GetText() == "Beast · Wolf", "type and family: " .. tostring(Card.sub:GetText()))
check(Card.tag:IsShown() and Card.tag.text:GetText() == "ELITE", "elite badge")
check(Card.bar:GetValue() == 1116 and Card.bar._max == 1800, "health bar")
check(Card.bar.text:GetText() == "1,116 / 1,800  62%", "health text: " .. tostring(Card.bar.text:GetText()))
check(rowText(1) == "Targeting: You", "targeting row: " .. tostring(rowText(1)))
check(rowText(2) == "Difficulty: Hard (+3)", "difficulty row: " .. tostring(rowText(2)))
check(Card.quests[1]:GetText() == "Ravaged Pelts" and Card.quests[2]:GetText() == " - Ravaged Pelt: 3/8", "quest lines copied")
check(Card.name._color[1] == 1 and Card.name._color[2] < 0.5, "hostile red name")

section("next to the mouse")
CURSOR[1], CURSOR[2] = 400, 300
Card:OnUpdate(0.01)
local p, _, _, x, y = Card.frame:GetPoint(1)
check(p == "BOTTOMLEFT" and x == 422 and y == 308, ("right of the cursor: %s %s %s"):format(tostring(p), tostring(x), tostring(y)))
CURSOR[1] = 1850
Card:OnUpdate(0.01)
p, _, _, x = Card.frame:GetPoint(1)
check(p == "BOTTOMRIGHT" and x == 1828, "left of the cursor near the right edge: " .. tostring(p) .. " " .. tostring(x))

section("an item afterwards: the game's tooltip, untouched")
GameTooltip:SetItem("Linen Cloth")
check(not cardShown(), "card gone")
check(GameTooltip:GetAlpha() == 1, "game tooltip visible again")

section("friendly creature: the game's tooltip")
hover("guard")
check(not cardShown() and GameTooltip:GetAlpha() == 1, "no card for a guard")

section("enemy players only when asked")
hover("rogue")
check(not cardShown() and GameTooltip:GetAlpha() == 1, "no card for an enemy player by default")
KrakentipDB.settings.players = true
hover("rogue")
check(cardShown(), "card for an enemy player when turned on")
KrakentipDB.settings.players = false

section("neutral, Classic-style percent health, no target")
hover("boar")
check(Card.name._color[2] > 0.8 and Card.name._color[3] < 0.3, "neutral yellow name")
check(Card.bar.text:GetText() == "40%", "percent only: " .. tostring(Card.bar.text:GetText()))
check(rowText(1) == "Difficulty: Easy (-11)" or rowText(1) == "Difficulty: Trivial (-11)", "no target row, difficulty first: " .. tostring(rowText(1)))
check(not Card.tag:IsShown(), "no badge for a normal creature")
check(not Card.sep:IsShown() and not Card.quests[1]:IsShown(), "no quest lines")

section("a boss with secret health")
hover("boss")
check(cardShown(), "card shown")
check(Card.badge.skull:IsShown() and not Card.badge.level:IsShown(), "skull instead of a level")
check(rawequal(Card.bar:GetValue(), SECRET), "the bar still gets the secret value")
check(Card.bar.text:GetText() == "", "no numbers when they're secret")
check(rowText(1) == "Difficulty: Deadly", "deadly: " .. tostring(rowText(1)))
check(Card.tag.text:GetText() == "ELITE", "badge")

section("leaving the creature: fade, then the game's tooltip is restored")
hover("wolf")
UNITS.mouseover = nil
Card:OnUpdate(0.05)
check(Card.fading, "fading")
Card:OnUpdate(0.1); Card:OnUpdate(0.1)
check(not cardShown(), "card gone after the fade")
GameTooltip:Hide()
check(GameTooltip:GetAlpha() == 1, "game tooltip alpha restored on hide")

section("health updates while hovering")
hover("wolf")
UNITS.wolf.hp = 900
Card:OnUpdate(0.2)
check(Card.bar:GetValue() == 900 and Card.bar.text:GetText() == "900 / 1,800  50%", "health refreshed: " .. tostring(Card.bar.text:GetText()))
leave()

section("where the game puts tooltips")
SlashCmdList.KRAKENTIP("tooltip")
check(KrakentipDB.settings.position == "tooltip", "setting saved")
hover("wolf")
p, rel = Card.frame:GetPoint(1)
check(p == "BOTTOMRIGHT" and rel == GameTooltip, "anchored on the game's tooltip spot: " .. tostring(p))
CURSOR[1] = 100
Card:OnUpdate(0.01)
p, rel = Card.frame:GetPoint(1)
check(rel == GameTooltip, "doesn't follow the mouse")
leave()
SlashCmdList.KRAKENTIP("mouse")
check(KrakentipDB.settings.position == "mouse", "back to the mouse")

section("lines can be turned off")
KrakentipDB.settings.lines.target = false
KrakentipDB.settings.lines.quests = false
hover("wolf")
check(rowText(1) == "Difficulty: Hard (+3)", "no target row")
check(not Card.quests[1]:IsShown(), "no quest lines")
KrakentipDB.settings.lines.target = true
KrakentipDB.settings.lines.quests = true
leave()

section("Krakenfriends: kills together")
Krakenfriends = { journey = { partnerName = "Thalianne", pairs = { a = { mobs = { [4521] = { c = 30 } } }, b = { mobs = { [4521] = { c = 12 } } } } } }
hover("wolf")
check(rowText(3) == "Killed with Thalianne: 42", "kills summed over chapters: " .. tostring(rowText(3)))
leave()
Krakenfriends = nil

section("tooltip data without lines: read them from the text")
USE_TOOLTIP_DATA = false
hover("wolf")
check(cardShown(), "card shown")
check(Card.quests[1]:GetText() == "Ravaged Pelts" and Card.quests[2]:GetText() == " - Ravaged Pelt: 3/8", "quest lines read from the text")
leave()
USE_TOOLTIP_DATA = true

section("off")
SlashCmdList.KRAKENTIP("off")
hover("wolf")
check(not cardShown() and GameTooltip:GetAlpha() == 1, "game tooltip for enemies when off")
leave()
SlashCmdList.KRAKENTIP("on")

section("options window and the sample card")
SlashCmdList.KRAKENTIP("")
local O = KT.Options
check(O.frame:IsShown(), "options open")
check(O.position.buttons[1]:GetChecked() and not O.position.buttons[2]:GetChecked(), "mouse picked")
Click(O.position.buttons[2])
check(KrakentipDB.settings.position == "tooltip", "radio switches to the tooltip spot")
check(O.position.buttons[2]:GetChecked() and not O.position.buttons[1]:GetChecked(), "radio shows it")
Click(O.sampleButton)
check(Card:IsSampleShown(), "sample card shown")
check(O.sampleButton:GetText() == "Hide the sample card", "button says hide")
check(Card.name:GetText() == "Timberling Ravager" and rowText(3) == "Killed with Thalianne: 42", "sample filled")
GameTooltip:SetItem("Linen Cloth")
GameTooltip:Hide()
check(Card:IsSampleShown(), "the sample stays while other tooltips come and go")
SlashCmdList.KRAKENTIP("scale 1.3")
check(Card.frame:GetScale() == 1.3, "scale applies to the card")
SlashCmdList.KRAKENTIP("scale 9")
check(KrakentipDB.settings.scale == 1.6, "scale capped")
O.frame:Hide()
check(not Card:IsSampleShown(), "closing the options hides the sample")

section("errors")
check(#ERRORS == 0, #ERRORS .. " errors raised")

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then error("tests failed") end
