local _, KT = ...

--------------------------------------------------------------------------------
-- The look: the game's own style, like the rest of the Kraken family. Gold on
-- dark stone, the fantasy font for the name.
--------------------------------------------------------------------------------

KT.Theme = {
    panel  = { 0, 0, 0, 0.30 },
    band   = { 0, 0, 0, 0.45 },   -- behind the card's head
    hover  = { 1, 0.82, 0, 0.10 },
    line   = { 1, 0.82, 0, 0.22 },
    gold   = { 1, 0.82, 0 },
    text   = { 1, 1, 1 },
    dim    = { 0.78, 0.72, 0.60 },
    faint  = { 0.50, 0.46, 0.38 },
    good   = { 0.36, 0.86, 0.47 },
    warn   = { 0.95, 0.72, 0.30 },
    bad    = { 1.00, 0.36, 0.30 },
    teal   = { 0.31, 0.82, 0.77 }, -- Krakenfriends' colour
    health = { 0.78, 0.12, 0.10 },
    tapped = { 0.55, 0.55, 0.55 },
}

-- Gold-border and stone files, the first one the client has wins.
KT.Files = {
    edge = { "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", "Interface\\DialogFrame\\UI-DialogBox-Border" },
    back = { "Interface\\FrameGeneral\\UI-Background-Rock", "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
    bar = { "Interface\\TargetingFrame\\UI-StatusBar" },
    ring = "Interface\\Minimap\\MiniMap-TrackingBorder",
    skull = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    titleFont = "Fonts\\MORPHEUS.TTF",
}

-- The badge next to the creature type.
KT.Classification = {
    elite = "ELITE",
    rareelite = "RARE ELITE",
    rare = "RARE",
    worldboss = "BOSS",
}

-- Name colour by how the creature feels about you (UnitReaction: 1-3 hostile, 4 neutral).
KT.Reaction = {
    hostile = { 1.00, 0.29, 0.23 },
    neutral = { 1.00, 0.85, 0.20 },
}

-- How hard a creature is for you, by the level difference. `range` is how far
-- below you a creature still gives experience; below that it's trivial.
function KT.Difficulty(level, mine, range)
    if not level or level < 0 then return "Deadly", { 1.00, 0.10, 0.10 }, nil end
    if not mine then return nil end
    local diff = level - mine
    range = range or 5
    if diff >= 5 then return "Very hard", { 1.00, 0.10, 0.10 }, diff end
    if diff >= 3 then return "Hard", { 1.00, 0.50, 0.25 }, diff end
    if diff >= -2 then return "Even", { 1.00, 0.82, 0.00 }, diff end
    if diff >= -range then return "Easy", { 0.25, 0.75, 0.25 }, diff end
    return "Trivial", { 0.55, 0.55, 0.55 }, diff
end

-- The pretend creature for the sample card.
KT.Sample = {
    name = "Timberling Ravager", level = 24, cls = "elite", reaction = "hostile",
    ctype = "Beast", family = "Wolf", hp = 1116, hpMax = 1800,
    target = "You", quests = { { "Ravaged Pelts", true }, { " - Ravaged Pelt: 3/8" } }, together = 42, partner = "Thalianne",
}
