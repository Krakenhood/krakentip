local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets
local clean, call = KT.clean, KT.call
local Layouts = KT.Layouts
local K = Layouts.kit
local width, setText, paint, V, at, text, solid = K.width, K.setText, K.paint, K.V, K.at, K.text, K.solid
local floor, max, min = math.floor, math.max, math.min

--------------------------------------------------------------------------------
-- The Slate looks, designed from a blank page (docs/clean-slate.html): one
-- family in the look of the game's own tooltips, in four sizes.
--
--   whisper  two short lines of text at the cursor
--   glance   level, name and a quest ring; the bar; target and type; for fighting
--   ledger   the full read, line by line, like the game's item tooltips
--   banner   hangs under the creature's nameplate, adding what the plate lacks
--
-- All four carry what the game's own tooltip gives: name, level, type (race
-- and class), rank, health, quest progress, target; guild, faction and PvP
-- for players; the title for NPCs. They share the edge colour on the left,
-- the rank colour of the frame and the red glow when a unit is after you.
--------------------------------------------------------------------------------

local C = {
    edge = { 0.44, 0.46, 0.53 }, elite = { 0.84, 0.65, 0.20 }, rare = { 0.77, 0.80, 0.86 }, boss = { 0.75, 0.22, 0.17 },
    you = { 1, 0.35, 0.29 }, dim = { 0.65, 0.66, 0.73 }, tapped = { 0.56, 0.56, 0.56 }, box = { 0.055, 0.06, 0.125 },
    track = { 0.11, 0.12, 0.18 }, line = { 0.15, 0.16, 0.24 }, guild = { 0.49, 0.88, 0.49 }, party = { 0.62, 0.84, 1 },
    done = { 0.28, 0.88, 0.31 }, barEdge = { 0.17, 0.19, 0.26 },
}

local RANK_WORD = { elite = "Elite", rare = "Rare", rareelite = "Rare elite", boss = "Boss" }
local RANK_COLOR = { elite = C.elite, rare = C.rare, rareelite = C.rare, boss = C.boss }

--------------------------------------------------------------------------------
-- What the looks say
--------------------------------------------------------------------------------

-- the words that are there, joined; any of them may be missing
local function join(sep, ...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" and v ~= "" then out[#out + 1] = v end
    end
    return table.concat(out, sep)
end

-- an NPC that sells, trains or flies you: no health worth showing
local function isService(info) return not info.isPlayer and not info.canAttack end

local function rankOf(info, lines)
    if not lines.rank then return nil end
    if info.isBoss or info.cls == "worldboss" then return "boss" end
    if info.cls == "elite" or info.cls == "rareelite" or info.cls == "rare" then return info.cls end
end

-- the classic elite mark: a plus after the level
local function plus(info, lines)
    local r = rankOf(info, lines)
    return (r == "elite" or r == "rareelite") and "+" or ""
end

-- the name, without the title its role already says ("Innkeeper Boorand
-- Plainswind" is the innkeeper Boorand Plainswind)
local function displayName(info)
    local n = clean(info.name)
    if not n then return info.name end
    local title = clean(info.subtitle)
    if title and n:sub(1, #title + 1) == title .. " " then n = n:sub(#title + 2) end
    return n
end

-- a long name with its earlier words as initials ("B. Thornweaver")
local function shortName(info, most)
    local n = displayName(info)
    if type(n) ~= "string" or (strlenutf8 and strlenutf8(n) or #n) <= most then return n end
    local words = {}
    for w in n:gmatch("%S+") do words[#words + 1] = w end
    if #words < 2 then return n end
    for i = 1, #words - 1 do words[i] = (words[i]:match("^[\1-\127\194-\244][\128-\191]*") or "") .. "." end
    return table.concat(words, " ")
end

-- what it is: "Beast · Wolf", "Human Rogue", "<Innkeeper> Humanoid"
local function kindText(info, lines)
    if info.isPlayer then return lines.type and join(" ", info.race, info.className) or "" end
    local title = isService(info) and lines.title and clean(info.subtitle)
    local what = lines.type and join(" · ", info.ctype, info.family ~= info.ctype and info.family or nil) or ""
    return join(" ", title and ("<" .. title .. ">") or nil, what)
end

local function spineColor(info)
    if info.tapped then return C.tapped end
    if info.isPlayer and info.classColor then return info.classColor end
    return KT.Reaction[info.reaction] or KT.Reaction.hostile
end

-- who it's after, coloured; and whether it's you
local function target(info, lines, upper)
    if not (lines.target and info.target) then return nil, false end
    local you = info.target == "You"
    return paint("» " .. ((you and upper) and "YOU" or info.target), you and C.you or info.targetColor or T.text), you
end

-- health in numbers we may look at (nil when the game hides them)
local function healthNumbers(info)
    if info.unit then return call(UnitHealth, info.unit), call(UnitHealthMax, info.unit) end
    return clean(info.hp), clean(info.hpMax)
end

local function healthPct(info)
    local h, m = healthNumbers(info)
    if h and m and m > 0 then return floor(100 * h / m + 0.5) end
end

-- green when full, yellow at half, red when low
local function hpColor(p)
    if p >= 50 then local t = (p - 50) / 50; return { 1 - 0.75 * t, 0.84 - 0.06 * t, 0.12 * t + 0.0 } end
    local t = p / 50
    return { 0.9 + 0.1 * t, 0.16 + 0.68 * t, 0.12 * (1 - t) }
end

local function classColorOf(name)
    for _, group in ipairs({ { "party", 4 }, { "raid", 40 } }) do
        for i = 1, group[2] do
            local unit = group[1] .. i
            local n = call(UnitName, unit)
            if n == name then
                local _, cls = call(UnitClass, unit)
                local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
                if c then return { c.r, c.g, c.b } end
            elseif not n and group[1] == "raid" then
                break
            end
        end
    end
    return T.text
end

-- you and each group member, with their count for this creature:
-- { name, have, need, color, you }, yours first
local function questRows(info, lines)
    local rows, seen = {}, {}
    for _, q in ipairs(info.quests or {}) do
        if not q[2] and not q[3] then
            local t = clean(q[1])
            local have, need
            if type(t) == "string" then have, need = t:match("(%d+)%s*/%s*(%d+)") end
            local owner = q[4]
            local key = owner or "\1you"
            if have and not seen[key] and ((owner and lines.group) or (not owner and lines.quests)) then
                seen[key] = true
                rows[#rows + 1] = { name = owner or "You", have = tonumber(have), need = tonumber(need), you = not owner,
                    color = owner and classColorOf(owner) or T.text }
            end
        end
    end
    return rows
end

-- The Ledger's quest lines, and whether they make a table: one quest, one
-- counted objective per person. Then its name ("Ravaged Pelt") heads it.
local function ledgerQuests(info, lines)
    local list = Layouts.QuestLines(info, lines)
    local titles, per, objective, simple = 0, {}, nil, true
    for _, q in ipairs(list) do
        if q[2] then
            titles = titles + 1
        elseif not q[3] then
            local key = q[4] or "\1you"
            per[key] = (per[key] or 0) + 1
            local t = clean(q[1])
            if per[key] > 1 or type(t) ~= "string" or not t:match("%d+%s*/%s*%d+") then
                simple = false
            else
                local name = (t:gsub("^%s*%-%s*", "")):gsub(":?%s*%d+%s*/%s*%d+%s*$", "")
                if objective and name ~= objective then simple = false end
                objective = objective or name
            end
        end
    end
    return list, simple and titles <= 1 and objective ~= nil, objective
end

-- What an NPC does, from its title; titles it doesn't know show as text.
local SERVICES = {
    { "Innkeeper", { { "Hearthstone", "INV_Misc_Rune_01" }, { "Food & drink", "INV_Misc_Food_15" } } },
    { "Flight", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Wind Rider", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Gryphon", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Hippogryph", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Banker", { { "Bank", "INV_Misc_Bag_10" } } },
    { "Stable", { { "Stables", "Ability_Hunter_BeastCall" } } },
    { "Trainer", { { "Training", "INV_Misc_Book_09" } } },
    { "Auctioneer", { { "Auctions", "INV_Misc_Coin_02" } } },
    { "Repair", { { "Repairs", "Trade_BlackSmithing" } } },
    { "Merchant", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Vendor", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Supplies", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Goods", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Provisioner", { { "Sells", "INV_Misc_Coin_01" } } },
}
local function services(info)
    local title = clean(info.subtitle)
    if type(title) ~= "string" then return {} end
    for _, s in ipairs(SERVICES) do
        if title:find(s[1], 1, true) then return s[2] end
    end
    return {}
end

--------------------------------------------------------------------------------
-- Shared parts: the edge, the rank corner, the glow, the quest ring
--------------------------------------------------------------------------------

local function paintSolid(t, c, a)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    t._rgba = { c[1], c[2], c[3], a or 1 }
end

local function frameParts(f)
    f.spine = solid(f, C.edge)
    f.cornerH = solid(f, C.elite)
    f.cornerV = solid(f, C.elite)
    -- a red glow round the frame while the unit is after you
    local glow = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    glow:SetPoint("TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", 4, -4)
    glow:SetFrameLevel(math.max(0, f:GetFrameLevel() - 2))
    if glow.SetBackdrop then
        glow:SetBackdrop({ edgeFile = Wg.FirstFile(KT.Files.thinEdge), edgeSize = 14 })
        glow:SetBackdropBorderColor(1, 0.2, 0.12, 0.9)
    end
    local ag = glow.CreateAnimationGroup and glow:CreateAnimationGroup()
    if ag then
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        if a then
            a:SetFromAlpha(0.35)
            a:SetToAlpha(1)
            a:SetDuration(0.8)
        end
        glow:SetScript("OnShow", function() ag:Play() end)
        glow:SetScript("OnHide", function() ag:Stop() end)
    end
    glow:Hide()
    f.glow = glow
end

-- the bar's edge in the tooltip's grey, not the gold of the other looks
local function darkBar(b, c)
    c = c or C.barEdge
    b.edge:SetColorTexture(c[1], c[2], c[3], 1)
    b._edge = c
end

-- The edge, the frame's rank colour and the glow, once the size is known.
local function finish(f, info, lines, W, H)
    paintSolid(f.spine, spineColor(info))
    at(f, f.spine, "TOPLEFT", 0, 0)
    f.spine:SetSize(3, H)
    local r = rankOf(info, lines)
    local edge = RANK_COLOR[r] or C.edge
    if f.backdrop and f.backdrop.SetBackdropBorderColor then f.backdrop:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1) end
    f._edge = edge
    if r and r ~= "boss" then
        -- a corner brace in the rank's colour, as the target frame's dragon
        paintSolid(f.cornerH, edge)
        paintSolid(f.cornerV, edge)
        at(f, f.cornerH, "TOPLEFT", -2, -2)
        f.cornerH:SetSize(14, 3)
        at(f, f.cornerV, "TOPLEFT", -2, -2)
        f.cornerV:SetSize(3, 14)
        f.cornerH:Show()
        f.cornerV:Show()
    else
        f.cornerH:Hide()
        f.cornerV:Hide()
    end
    local _, you = target(info, lines)
    f.glow:SetShown(you)
    f._glow = you
    return W, H
end

-- your quest count in a gold ring (green when it's done)
local function qring(f, size)
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(size, size)
    local disc = r:CreateTexture(nil, "BACKGROUND")
    disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    disc:SetVertexColor(0.06, 0.06, 0.12, 1)
    disc:SetPoint("TOPLEFT", 2, -2)
    disc:SetPoint("BOTTOMRIGHT", -2, 2)
    local edge = r:CreateTexture(nil, "OVERLAY")
    edge:SetTexture(KT.Files.ring)
    edge:SetSize(size * 1.8, size * 1.8)
    edge:SetPoint("TOPLEFT", -size / 15, size / 15)
    r.level = Wg.Text(r, size >= 24 and 9 or 8, T.gold, "CENTER", "OUTLINE")
    r.level:SetPoint("CENTER", 0, 0)
    r.text = r.level
    r.skull = r:CreateTexture(nil, "ARTWORK")
    r.skull:Hide()
    r._size = size
    function r:Set(row)
        local done = row.have >= row.need
        self.level:SetText(row.have .. "/" .. row.need)
        self.level:SetTextColor(Wg.rgb(done and C.done or T.gold))
        self.level._color = done and C.done or T.gold
        edge:SetVertexColor(done and 0.5 or 1, done and 1 or 0.9, done and 0.5 or 0.7)
    end
    return K.part(f, r, "ring")
end

-- a group member's progress: their initial and count over a short bar
local function pip(f, w)
    local p = { letter = text(f, 9, T.text, { outline = "OUTLINE" }), count = text(f, 9, T.gold), track = solid(f, C.track), fill = solid(f, T.gold), w = w }
    function p:Show() self.letter:Show(); self.count:Show(); self.track:Show(); self.fill:Show() end
    function p:Hide() self.letter:Hide(); self.count:Hide(); self.track:Hide(); self.fill:Hide() end
    function p:IsShown() return self.letter:IsShown() end
    function p:Place(row, x, y)
        self.letter:SetText(row.name:match("^[\1-\127\194-\244][\128-\191]*") or "?")
        self.letter:SetTextColor(Wg.rgb(row.color))
        self.letter._color = row.color
        at(f, self.letter, "TOPLEFT", x, y)
        local done = row.have >= row.need
        self.count:SetText(row.have .. "/" .. row.need)
        self.count:SetTextColor(Wg.rgb(done and C.done or T.gold))
        self.count._color = done and C.done or T.gold
        at(f, self.count, "TOPRIGHT", x + self.w, y)
        at(f, self.track, "TOPLEFT", x, y + 11)
        self.track:SetSize(self.w, 4)
        local frac = min(1, row.have / row.need)
        at(f, self.fill, "TOPLEFT", x, y + 11)
        self.fill:SetSize(max(1, floor(self.w * frac + 0.5)), 4)
        paintSolid(self.fill, frac >= 1 and C.done or T.gold)
        self.fill:SetShown(frac > 0)
    end
    return p
end

-- level text with the elite plus, or the skull; returns the width it took
local function placeLevel(f, info, lines, x, y, skullSize)
    if K.setLevel(f, info) then
        at(f, f.skull, "TOPLEFT", x, y)
        return skullSize
    end
    f.level:SetText(info.level .. plus(info, lines))
    at(f, f.level, "TOPLEFT", x, y)
    return width(f.level, 16)
end

--------------------------------------------------------------------------------
-- Whisper: two short lines of text at the cursor
--------------------------------------------------------------------------------

local WH = { frame = "tip" }
Layouts.whisper = WH

function WH.Create(f)
    frameParts(f)
    f.level = text(f, 12, T.gold)
    f.skull = K.skull(f, 12)
    f.name = text(f, 13)
    f.you = text(f, 10, C.you, { outline = "OUTLINE" })
    f.quest = text(f, 11, T.gold)
    f.pvp = text(f, 10, C.you)
    f.line2 = text(f, 11, C.dim)
    f.bar = K.bar(f)
    darkBar(f.bar)
end

function WH.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local L, R, GAP = 10, 9, 6
    local x, y = L, 4

    -- line one: level, name, and what to act on: it's after you, your count, PvP
    x = x + placeLevel(f, info, lines, x, y + 1, 12) + 5
    at(f, f.name, "TOPLEFT", x, y)
    f.name:SetWidth(0)
    setText(f.name, shortName(info, 18))
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    x = x + width(f.name, 110) + GAP
    local _, you = target(info, lines, true)
    if you then
        f.you:SetText("YOU")
        at(f, f.you, "TOPLEFT", x, y + 2)
        f.you:Show()
        x = x + width(f.you, 22) + GAP
    else
        f.you:Hide()
    end
    local rows = questRows(info, lines)
    local mine = rows[1] and rows[1].you and rows[1]
    if mine then
        f.quest:SetText(mine.have .. "/" .. mine.need)
        f.quest:SetTextColor(Wg.rgb(mine.have >= mine.need and C.done or T.gold))
        at(f, f.quest, "TOPLEFT", x, y + 1)
        f.quest:Show()
        x = x + width(f.quest, 22) + GAP
    else
        f.quest:Hide()
    end
    if info.isPlayer and info.pvp then
        f.pvp:SetText("PvP")
        at(f, f.pvp, "TOPLEFT", x, y + 2)
        f.pvp:Show()
        x = x + width(f.pvp, 20) + GAP
    else
        f.pvp:Hide()
    end
    local w1 = x - GAP + R

    -- line two, short: rank and type, guild, health, target, the rest
    local bits = {}
    local r = rankOf(info, lines)
    local kind = kindText(info, lines)
    bits[#bits + 1] = join(" ", r and paint(RANK_WORD[r], RANK_COLOR[r]) or nil, kind)
    if info.isPlayer and lines.guild and info.guild then bits[#bits + 1] = "<" .. info.guild .. ">" end
    if not isService(info) and lines.health then
        if info.dead then
            bits[#bits + 1] = paint("dead", C.tapped)
        else
            local p = healthPct(info)
            if p then bits[#bits + 1] = paint(p .. "%", hpColor(p)) end
        end
    end
    local tgt, isYou = target(info, lines)
    if tgt and not isYou then bits[#bits + 1] = tgt end
    for _, o in ipairs(K.otherLines(info, lines)) do
        local plain = clean(o)
        if plain then bits[#bits + 1] = plain end
    end
    if info.tapped then bits[#bits + 1] = paint("tapped", C.tapped) end
    for _, row in ipairs(rows) do
        if not row.you then bits[#bits + 1] = paint(row.name .. " " .. row.have .. "/" .. row.need, row.have >= row.need and C.done or T.gold) end
    end
    if lines.friends and info.together then
        bits[#bits + 1] = paint(("%d with %s"):format(info.together, info.partner or "your friend"), T.teal)
    end
    local two = join(" · ", unpack(bits))
    f.line2:SetWidth(0)
    f.line2:SetText(two)
    at(f, f.line2, "TOPLEFT", L, y + 16)
    local W = max(floor(120 * wk + 0.5), w1, min(width(f.line2, 120) + L + R, floor(300 * wk + 0.5)))
    f.line2:SetWidth(W - L - R)
    f.line2:SetShown(two ~= "")
    local H = (two ~= "" and y + 16 + 13 or y + 16) + V(5, hk, 3)

    -- the health line along the bottom edge
    if isService(info) then
        f.bar:Hide()
        f.bar.text:Hide()
    else
        K.placeBar(f, f.bar, 3, H - 2, W - 4, 2)
        Layouts.SetHealth(f.bar, info, s, true)
        f.bar:Show()
        f.bar.text:Hide()
    end
    return finish(f, info, lines, W, H)
end

--------------------------------------------------------------------------------
-- Glance: level, name and the quest ring; the bar; target and type
--------------------------------------------------------------------------------

local GL = { frame = "tip", WIDTH = 230 }
Layouts.glance = GL

function GL.Create(f)
    frameParts(f)
    f.box = solid(f, C.box)
    f.level = text(f, 12, T.gold)
    f.skull = K.skull(f, 13)
    f.name = text(f, 15)
    f.ring = qring(f, 26)
    f.rank = text(f, 10, C.rare)
    f.bar = K.bar(f)
    darkBar(f.bar)
    f.num = text(f, 10, T.text, { outline = "OUTLINE", top = true })
    f.chips = K.pool(function() return K.chip(f) end)
    f.left = text(f, 12)
    f.right = text(f, 12, C.dim)
    f.left2 = text(f, 12, C.guild)
    f.right2 = text(f, 12, C.dim)
    f.partyLabel = text(f, 11, C.dim)
    f.pips = K.pool(function() return pip(f, 31) end)
    f.extra = text(f, 11, C.dim)
end

-- two texts on one line, the left one ending in "..." where they'd meet
local function pair(f, left, right, l, r, x, xr, y)
    if l and l ~= "" then
        left:SetWidth(0)
        left:SetText(l)
        at(f, left, "TOPLEFT", x, y)
        left:Show()
    else
        left:Hide()
    end
    if r and r ~= "" then
        right:SetWidth(0)
        right:SetText(r)
        at(f, right, "TOPRIGHT", xr, y)
        right:Show()
    else
        right:Hide()
    end
    if left:IsShown() then
        local room = xr - x - (right:IsShown() and width(right, 60) + 8 or 0)
        if width(left, 60) > room then left:SetWidth(max(20, room)) end
    end
    return left:IsShown() or right:IsShown()
end

function GL.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local L, R = 11, 8
    local W = max(170, min(380, floor(GL.WIDTH * wk + 0.5)))
    local y = 6

    -- level in its box, name, the quest ring (or the rare or boss word)
    at(f, f.box, "TOPLEFT", L, y + 3)
    f.box:SetSize(30, 19)
    if K.setLevel(f, info) then
        at(f, f.skull, "TOPLEFT", L + 8, y + 6)
    else
        f.level:SetText(info.level .. plus(info, lines))
        f.level:SetWidth(30)
        f.level:SetJustifyH("CENTER")
        at(f, f.level, "TOPLEFT", L, y + 6)
    end
    local rows = questRows(info, lines)
    local mine = rows[1] and rows[1].you and rows[1]
    local rightW = 0
    if mine then
        f.ring:Set(mine)
        at(f, f.ring, "TOPRIGHT", W - R, y)
        f.ring:Show()
        rightW = 30
    else
        f.ring:Hide()
    end
    local r = rankOf(info, lines)
    if not mine and r and r ~= "elite" then
        f.rank:SetText(RANK_WORD[r]:upper())
        f.rank:SetTextColor(Wg.rgb(RANK_COLOR[r]))
        f.rank._color = RANK_COLOR[r]
        at(f, f.rank, "TOPRIGHT", W - R, y + 8)
        f.rank:Show()
        rightW = width(f.rank, 30) + 6
    else
        f.rank:Hide()
    end
    at(f, f.name, "TOPLEFT", L + 36, y + 5)
    f.name:SetWidth(W - L - 36 - R - rightW)
    setText(f.name, shortName(info, 24))
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    y = y + 29

    -- the bar, the number on the left and the percentage on the right; an
    -- NPC shows what it does instead
    if isService(info) then
        f.bar:Hide()
        f.bar.text:Hide()
        f.num:Hide()
        local list = services(info)
        local cx = L
        for i, sv in ipairs(list) do
            local c = f.chips:Get(i)
            c:Set("Interface\\Icons\\" .. sv[2], sv[1], T.text)
            at(f, c, "TOPLEFT", cx, y)
            cx = cx + c:GetWidth() + 8
        end
        f.chips:HideFrom(#list + 1)
        if #list > 0 then y = y + 18 end
    else
        f.chips:HideFrom(1)
        local bh = V(13, hk, 6)
        K.placeBar(f, f.bar, L, y, W - L - R, bh)
        Layouts.SetHealth(f.bar, info, s, true)
        f.bar:Show()
        if lines.health and bh >= 9 then
            Wg.SetFont(f.bar.text, 10, "OUTLINE")
            f.bar.text._size = 10
            at(f, f.bar.text, "TOPRIGHT", W - R - 4, y + floor((bh - 10) / 2))
            f.bar.text:Show()
            local h, m = healthNumbers(info)
            if h and m and m ~= 100 and not info.dead then
                f.num:SetText(BreakUpLargeNumbers(h))
                at(f, f.num, "TOPLEFT", L + 4, y + floor((bh - 10) / 2))
                f.num:Show()
            else
                f.num:Hide()
            end
        else
            f.bar.text:Hide()
            f.num:Hide()
        end
        y = y + bh + 4
    end

    -- who it's after (or tapped) on the left, what it is on the right
    local left, right
    if isService(info) then
        local title = lines.title and clean(info.subtitle)
        left = title and paint("<" .. title .. ">", T.gold) or nil
        right = lines.type and info.ctype or nil
    else
        left = target(info, lines) or (info.tapped and paint("tapped", C.tapped)) or nil
        right = kindText(info, lines)
        if info.tapped and left and not left:find("tapped", 1, true) then right = join(" · ", paint("tapped", C.tapped), right) end
    end
    if pair(f, f.left, f.right, left, right, L, W - R, y) then y = y + 15 end

    -- players: guild on the left, faction (and PvP) on the right
    if info.isPlayer then
        local guild = lines.guild and info.guild and ("<" .. info.guild .. ">") or nil
        local faction = join(" · ", info.faction, info.pvp and paint("PvP", C.you) or nil)
        if pair(f, f.left2, f.right2, guild, faction, L, W - R, y) then y = y + 15 end
    else
        f.left2:Hide()
        f.right2:Hide()
    end

    -- the party's progress for this creature: one small bar each
    local group = {}
    for _, row in ipairs(rows) do if not row.you or #rows > 1 then group[#group + 1] = row end end
    if #group > 1 or (#group == 1 and not group[1].you) then
        f.partyLabel:SetText("Party")
        at(f, f.partyLabel, "TOPLEFT", L, y + 3)
        f.partyLabel:Show()
        local px = W - R - (#group * 36 - 5)
        for i, row in ipairs(group) do
            local p = f.pips:Get(i)
            p:Place(row, px, y)
            px = px + 36
        end
        f.pips:HideFrom(#group + 1)
        y = y + 19
    else
        f.partyLabel:Hide()
        f.pips:HideFrom(1)
    end

    -- anything else the game's tooltip says, and kills together
    local extra = {}
    for _, o in ipairs(K.otherLines(info, lines)) do
        local plain = clean(o)
        if plain then extra[#extra + 1] = plain end
    end
    if lines.friends and info.together then
        extra[#extra + 1] = paint(("%d with %s"):format(info.together, info.partner or "your friend"), T.teal)
    end
    if #extra > 0 then
        f.extra:SetText(table.concat(extra, " · "))
        f.extra:SetWidth(W - L - R)
        at(f, f.extra, "TOPLEFT", L, y)
        f.extra:Show()
        y = y + 14
    else
        f.extra:Hide()
    end
    return finish(f, info, lines, W, y + V(4, hk, 2))
end

--------------------------------------------------------------------------------
-- Ledger: the full read, line by line
--------------------------------------------------------------------------------

local LG = { frame = "tip", WIDTH = 254 }
Layouts.ledger = LG

local function qrow(f)
    local r = { name = text(f, 12), track = solid(f, C.track), fill = solid(f, T.gold), count = text(f, 12, T.gold) }
    function r:Show() self.name:Show(); self.track:Show(); self.fill:Show(); self.count:Show() end
    function r:Hide() self.name:Hide(); self.track:Hide(); self.fill:Hide(); self.count:Hide() end
    function r:IsShown() return self.name:IsShown() end
    return r
end

local function lrow(f)
    local r = { label = text(f, 12, C.dim), value = text(f, 12) }
    function r:Show() self.label:Show(); self.value:Show() end
    function r:Hide() self.label:Hide(); self.value:Hide() end
    function r:IsShown() return self.label:IsShown() end
    return r
end

function LG.Create(f)
    frameParts(f)
    f.name = text(f, 16)
    f.rank = text(f, 10)
    f.title = text(f, 12, T.gold)
    f.guild = text(f, 12, C.guild)
    f.levelLine = text(f, 12)
    f.faction = text(f, 12, C.dim)
    f.tappedLine = text(f, 12, C.tapped)
    f.bar = K.bar(f)
    darkBar(f.bar)
    f.rows = K.pool(function() return lrow(f) end)
    f.others = K.pool(function() return text(f, 12, C.dim) end)
    f.chips = K.pool(function() return K.chip(f) end)
    f.sep = solid(f, C.line)
    f.qtitle = text(f, 12, T.gold)
    f.qobj = text(f, 11, C.dim)
    f.qrows = K.pool(function() return qrow(f) end)
    f.qlines = K.pool(function() return text(f, 12) end)
end

function LG.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local L, R = 12, 10
    local W = max(190, min(420, floor(LG.WIDTH * wk + 0.5)))
    local y = 8
    local step = V(15, hk, 13)

    -- name, and on the right its rank (or PvP, or Party for players)
    local r = rankOf(info, lines)
    local word, wordColor
    if r then
        word, wordColor = RANK_WORD[r]:upper(), RANK_COLOR[r]
    elseif info.isPlayer and info.pvp then
        word, wordColor = "PVP", C.you
    elseif info.isPlayer and info.inParty then
        word, wordColor = "PARTY", C.party
    end
    if word then
        f.rank:SetText(word)
        f.rank:SetTextColor(Wg.rgb(wordColor))
        f.rank._color = wordColor
        at(f, f.rank, "TOPRIGHT", W - R, y + 4)
        f.rank:Show()
    else
        f.rank:Hide()
    end
    at(f, f.name, "TOPLEFT", L, y)
    f.name:SetWidth(W - L - R - (word and width(f.rank, 40) + 8 or 0))
    setText(f.name, displayName(info))
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    y = y + V(20, hk, 18)

    -- an NPC's title, a player's guild
    local title = isService(info) and lines.title and clean(info.subtitle)
    if title then
        f.title:SetText("<" .. title .. ">")
        at(f, f.title, "TOPLEFT", L, y)
        f.title:Show()
        y = y + step
    else
        f.title:Hide()
    end
    if info.isPlayer and lines.guild and info.guild then
        f.guild:SetText("<" .. info.guild .. ">")
        at(f, f.guild, "TOPLEFT", L, y)
        f.guild:Show()
        y = y + step
    else
        f.guild:Hide()
    end

    -- "Level 24 Beast · Wolf", a player's faction on the right
    local lv = (info.level and info.level > 0) and paint(tostring(info.level), info.difficultyColor or T.text) or paint("??", { 1, 0.16, 0.16 })
    local what = info.isPlayer and (lines.type and join(" ", info.race, info.className) or "")
        or (lines.type and join(" · ", info.ctype, info.family ~= info.ctype and info.family or nil) or "")
    f.levelLine:SetText(join(" ", (LEVEL or "Level") .. " " .. lv, what))
    at(f, f.levelLine, "TOPLEFT", L, y)
    if info.isPlayer and info.faction then
        f.faction:SetText(info.faction)
        at(f, f.faction, "TOPRIGHT", W - R, y)
        f.faction:Show()
    else
        f.faction:Hide()
    end
    y = y + step
    if info.tapped then
        f.tappedLine:SetText("Tapped by another player")
        at(f, f.tappedLine, "TOPLEFT", L, y)
        f.tappedLine:Show()
        y = y + step
    else
        f.tappedLine:Hide()
    end

    -- health: a slim bar, the numbers beside it
    if isService(info) then
        f.bar:Hide()
        f.bar.text:Hide()
    else
        local textW = lines.health and 108 or 0
        local bh = V(8, hk, 4)
        K.placeBar(f, f.bar, L, y + 4, W - L - R - (textW > 0 and textW + 6 or 0), bh)
        Layouts.SetHealth(f.bar, info, s)
        f.bar:Show()
        if lines.health then
            Wg.SetFont(f.bar.text, 11, "")
            f.bar.text._size = 11
            f.bar.text._outline = nil
            f.bar.text:SetTextColor(Wg.rgb(C.dim))
            f.bar.text._color = C.dim
            at(f, f.bar.text, "TOPRIGHT", W - R, y + 1)
            f.bar.text:Show()
        else
            f.bar.text:Hide()
        end
        y = y + max(step, bh + 8)
    end

    -- targeting and kills together, label and value
    local list = {}
    if lines.target and info.target then
        list[#list + 1] = { "Targeting", info.target, info.target == "You" and C.you or info.targetColor }
    end
    if lines.friends and info.together then
        list[#list + 1] = { info.partner and ("Killed with " .. info.partner) or "Killed together", tostring(info.together), T.teal }
    end
    for i, row in ipairs(list) do
        local fr = f.rows:Get(i)
        fr.label:SetText(row[1])
        at(f, fr.label, "TOPLEFT", L, y)
        setText(fr.value, row[2])
        fr.value:SetTextColor(Wg.rgb(row[3] or T.text))
        fr.value._color = row[3] or T.text
        at(f, fr.value, "TOPRIGHT", W - R, y)
        y = y + step
    end
    f.rows:HideFrom(#list + 1)

    -- the game's other lines: a party member's zone, "Skinnable"
    local others = K.otherLines(info, lines)
    for i, o in ipairs(others) do
        local fs = f.others:Get(i)
        setText(fs, o)
        fs:SetWidth(W - L - R)
        at(f, fs, "TOPLEFT", L, y)
        y = y + step
    end
    f.others:HideFrom(#others + 1)

    -- what an NPC does
    local sv = isService(info) and services(info) or {}
    local cx = L
    for i, item in ipairs(sv) do
        local c = f.chips:Get(i)
        c:Set("Interface\\Icons\\" .. item[2], item[1], T.text)
        at(f, c, "TOPLEFT", cx, y + 1)
        cx = cx + c:GetWidth() + 8
    end
    f.chips:HideFrom(#sv + 1)
    if #sv > 0 then y = y + 19 end

    -- quests: a table when it's one objective each, the game's lines otherwise
    local qlist, asTable, objective = ledgerQuests(info, lines)
    f.qtitle:Hide()
    f.qobj:Hide()
    if #qlist > 0 then
        y = y + 3
        at(f, f.sep, "TOPLEFT", L, y)
        f.sep:SetSize(W - L - R, 1)
        f.sep:Show()
        y = y + 6
    else
        f.sep:Hide()
    end
    if asTable then
        local title
        for _, q in ipairs(qlist) do if q[2] then title = q[1] end end
        if title then
            setText(f.qtitle, title)
            at(f, f.qtitle, "TOPLEFT", L, y)
            f.qtitle:Show()
        end
        f.qobj:SetText(objective)
        at(f, f.qobj, "TOPRIGHT", W - R, y + 1)
        f.qobj:Show()
        y = y + step
        local rows = questRows(info, lines)
        for i, row in ipairs(rows) do
            local qr = f.qrows:Get(i)
            local done = row.have >= row.need
            qr.name:SetText(row.name)
            qr.name:SetTextColor(Wg.rgb(row.color))
            qr.name._color = row.color
            at(f, qr.name, "TOPLEFT", L, y)
            at(f, qr.track, "TOPLEFT", W - R - 36 - 56, y + 5)
            qr.track:SetSize(56, 4)
            at(f, qr.fill, "TOPLEFT", W - R - 36 - 56, y + 5)
            qr.fill:SetSize(max(1, floor(56 * min(1, row.have / row.need) + 0.5)), 4)
            paintSolid(qr.fill, done and C.done or T.gold)
            qr.count:SetText(row.have .. "/" .. row.need)
            qr.count:SetTextColor(Wg.rgb(done and C.done or T.gold))
            qr.count._color = done and C.done or T.gold
            at(f, qr.count, "TOPRIGHT", W - R, y)
            y = y + V(14, hk, 12)
        end
        f.qrows:HideFrom(#rows + 1)
        f.qlines:HideFrom(1)
    else
        f.qrows:HideFrom(1)
        for i, q in ipairs(qlist) do
            local fs = f.qlines:Get(i)
            setText(fs, q[1])
            local c = q[2] and T.gold or q[3] and C.dim or T.text
            fs:SetTextColor(Wg.rgb(c))
            fs._color = c
            fs:SetWidth(W - L - R)
            at(f, fs, "TOPLEFT", L, y)
            y = y + V(14, hk, 12)
        end
        f.qlines:HideFrom(#qlist + 1)
    end
    return finish(f, info, lines, W, y + V(5, hk, 3))
end

--------------------------------------------------------------------------------
-- Banner: hangs under the nameplate, which already shows name and health
--------------------------------------------------------------------------------

local BN = { frame = "tip" }
Layouts.banner = BN

function BN.Create(f)
    frameParts(f)
    f.level = text(f, 12, T.gold)
    f.skull = K.skull(f, 13)
    f.rank = text(f, 10)
    f.title = text(f, 11, C.dim)
    f.pvp = text(f, 10, C.you)
    f.ring = qring(f, 22)
    f.members = K.pool(function() return text(f, 11) end)
    f.tappedText = text(f, 11, C.tapped)
    f.target = text(f, 12)
    f.line2 = text(f, 11, C.dim)
end

function BN.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local GAP = 7
    -- the top row is laid out once to measure it, then centred
    local items = {}
    local function item(w, place) items[#items + 1] = { w = w, place = place } end
    if K.setLevel(f, info) then
        item(13, function(x) at(f, f.skull, "TOPLEFT", x, 8) end)
    else
        f.level:SetText(info.level .. plus(info, lines))
        item(width(f.level, 16), function(x) at(f, f.level, "TOPLEFT", x, 9) end)
    end
    local r = rankOf(info, lines)
    if r and r ~= "elite" then
        f.rank:SetText(RANK_WORD[r]:upper())
        f.rank:SetTextColor(Wg.rgb(RANK_COLOR[r]))
        f.rank._color = RANK_COLOR[r]
        f.rank:Show()
        item(width(f.rank, 30), function(x) at(f, f.rank, "TOPLEFT", x, 10) end)
    else
        f.rank:Hide()
    end
    local title = isService(info) and lines.title and clean(info.subtitle)
    if title then
        f.title:SetText("<" .. title .. ">")
        f.title:Show()
        item(width(f.title, 60), function(x) at(f, f.title, "TOPLEFT", x, 10) end)
    else
        f.title:Hide()
    end
    if info.isPlayer and info.pvp then
        f.pvp:SetText("PvP")
        f.pvp:Show()
        item(width(f.pvp, 20), function(x) at(f, f.pvp, "TOPLEFT", x, 10) end)
    else
        f.pvp:Hide()
    end
    local rows = questRows(info, lines)
    local mine = rows[1] and rows[1].you and rows[1]
    if mine then
        f.ring:Set(mine)
        f.ring:Show()
        item(22, function(x) at(f, f.ring, "TOPLEFT", x, 4) end)
    else
        f.ring:Hide()
    end
    local n = 0
    for _, row in ipairs(rows) do
        if not row.you then
            n = n + 1
            local m = f.members:Get(n)
            local initial = row.name:match("^[\1-\127\194-\244][\128-\191]*") or "?"
            m:SetText(paint(initial, row.color) .. " " .. paint(row.have .. "/" .. row.need, row.have >= row.need and C.done or T.gold))
            item(width(m, 28), function(x) at(f, m, "TOPLEFT", x, 10) end)
        end
    end
    f.members:HideFrom(n + 1)
    if info.tapped then
        f.tappedText:SetText("tapped")
        f.tappedText:Show()
        item(width(f.tappedText, 36), function(x) at(f, f.tappedText, "TOPLEFT", x, 10) end)
    else
        f.tappedText:Hide()
    end
    local tgt = target(info, lines, true)
    if tgt then
        f.target:SetText(tgt)
        f.target:Show()
        item(width(f.target, 40), function(x) at(f, f.target, "TOPLEFT", x, 9) end)
    else
        f.target:Hide()
    end
    local w1 = -GAP
    for _, it in ipairs(items) do w1 = w1 + it.w + GAP end

    -- the second row: what it is, a player's guild and faction, and the rest
    local bits = { kindText(info, lines) }
    if info.isPlayer and lines.guild and info.guild then bits[#bits + 1] = "<" .. info.guild .. ">" end
    if info.isPlayer and info.faction then bits[#bits + 1] = info.faction end
    for _, o in ipairs(K.otherLines(info, lines)) do
        local plain = clean(o)
        if plain then bits[#bits + 1] = plain end
    end
    if lines.friends and info.together then
        bits[#bits + 1] = paint(("%d with %s"):format(info.together, info.partner or "your friend"), T.teal)
    end
    local two = join(" · ", unpack(bits))
    f.line2:SetWidth(0)
    f.line2:SetText(two)
    local W = max(90, w1 + 20, min(width(f.line2, 100) + 20, floor(280 * wk + 0.5)))
    local x = floor((W - w1) / 2 + 0.5)
    for _, it in ipairs(items) do
        it.place(x)
        x = x + it.w + GAP
    end
    local H = 4 + 26
    if two ~= "" then
        f.line2:SetWidth(W - 16)
        f.line2:SetJustifyH("CENTER")
        at(f, f.line2, "TOP", W / 2, H)
        f.line2:Show()
        H = H + 13
    else
        f.line2:Hide()
    end
    return finish(f, info, lines, W, H + V(4, hk, 3))
end
