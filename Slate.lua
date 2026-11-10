local _, KT = ...
local T = KT.Theme
local Wg = KT.Widgets
local clean, call = KT.clean, KT.call
local Layouts = KT.Layouts
local K = Layouts.kit
local width, setText, paint, V, at, text, solid = K.width, K.setText, K.paint, K.V, K.at, K.text, K.solid
local floor, max, min = math.floor, math.max, math.min

--------------------------------------------------------------------------------
-- The four looks, designed from a blank page (docs/clean-slate.html): one
-- family in the look of the game's own tooltips, in four sizes.
--
--   whisper  two short lines of text at the cursor
--   glance   level, name and the quest ring; the bar; target and type; for fighting
--   ledger   the full read, line by line, like the game's item tooltips
--   banner   hangs under the creature's nameplate, adding what the plate lacks
--
-- All four carry what the game's own tooltip gives: name, level, type (race
-- and class), rank, health, quest progress, target; guild, faction and PvP
-- for players; the title for NPCs. They share the edge on the left (who it
-- is to you), the frame's colour and wing (what kind), and the red glow when
-- a unit is after you. Everything has its place: level top left, quest top
-- right, health in the middle, target below it.
--------------------------------------------------------------------------------

-- the concept's colours
local C = {
    edge = { 0.44, 0.46, 0.53 }, elite = { 0.84, 0.65, 0.20 }, rare = { 0.77, 0.80, 0.86 }, boss = { 0.75, 0.22, 0.17 },
    you = { 1, 0.35, 0.29 }, dim = { 0.65, 0.66, 0.73 }, tapped = { 0.56, 0.56, 0.56 }, quest = { 1, 0.82, 0 },
    done = { 0.28, 0.88, 0.31 }, guild = { 0.49, 0.88, 0.49 }, party = { 0.62, 0.84, 1 }, pvp = { 0.91, 0.30, 0.24 },
    box = { 0.055, 0.063, 0.125 }, boxEdge = { 0.23, 0.24, 0.32 }, track = { 0.11, 0.125, 0.19 }, line = { 0.15, 0.165, 0.24 },
    ground = { 0.027, 0.031, 0.07 }, underline = { 0.106, 0.114, 0.165 }, ringText = { 1, 0.91, 0.63 },
}

local RANK_WORD = { elite = "Elite", rare = "Rare", rareelite = "Rare", boss = "Boss" }
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

-- A small icon inside a line of text (media/), as drawn or tinted.
local ICON_PX = { arrow = 32, pvp = 32, pin = 32, diamond = 16 }
local function icon(name, size, c)
    local px = ICON_PX[name]
    local s = ("|T%s:%d:%d:0:0:%d:%d:0:%d:0:%d"):format(KT.Media(name), size, size, px, px, px, px)
    if c then s = s .. (":%d:%d:%d"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)) end
    return s .. "|t"
end
local function flag(size) return icon("pvp", size or 12) end

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

local function initial(name) return type(name) == "string" and name:match("^[\1-\127\194-\244][\128-\191]*") or "?" end

-- what it is: "Beast · Wolf", "Human Rogue", "<Innkeeper> Humanoid"
local function kindText(info, lines)
    if info.isPlayer then return lines.type and join(" ", info.race, info.className) or "" end
    local title = isService(info) and lines.title and clean(info.subtitle)
    local what = lines.type and join(" · ", info.ctype, info.family ~= info.ctype and info.family or nil) or ""
    return join(" ", title and ("<" .. title .. ">") or nil, what)
end

-- the edge on the left: who it is to you
local function spineColor(info)
    if info.tapped then return C.tapped end
    if info.isPlayer and info.classColor then return info.classColor end
    return KT.Reaction[info.reaction] or KT.Reaction.hostile
end

-- who it's after, with the arrow in its colour; and whether it's you
local function target(info, lines, upper)
    if not (lines.target and info.target) then return nil, false end
    local you = info.target == "You"
    local c = you and C.you or info.targetColor or T.text
    return icon("arrow", 10, c) .. " " .. paint((you and upper) and "YOU" or info.target, c), you
end

-- A group member somewhere else: the game's tooltip names the zone, as the
-- first of its other lines. The zone, and the other lines without it.
local function zoneAndOthers(info, lines)
    local others = K.otherLines(info, lines)
    if info.isPlayer and info.inParty and others[1] then
        local rest = {}
        for i = 2, #others do rest[#rest + 1] = others[i] end
        return clean(others[1]), rest
    end
    return nil, others
end
local function zoneText(zone) return icon("pin", 11) .. " " .. zone end

-- health in numbers we may look at (nil when the game hides them)
local function healthNumbers(info)
    if info.unit then return call(UnitHealth, info.unit), call(UnitHealthMax, info.unit) end
    return clean(info.hp), clean(info.hpMax)
end

local function healthPct(info)
    local h, m = healthNumbers(info)
    if h and m and m > 0 then return floor(100 * h / m + 0.5) end
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
local function countColor(row) return row.have >= row.need and C.done or C.quest end

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

-- What an NPC does, from its title: the role's icon (the game's gossip icons)
-- and what it offers. Titles it doesn't know show as text, without either.
local GOSSIP = "Interface\\GossipFrame\\"
local SERVICES = {
    { "Innkeeper", "BinderGossipIcon", { { "Hearthstone", "INV_Misc_Rune_01" }, { "Food & drink", "INV_Misc_Food_15" } } },
    { "Flight", "TaxiGossipIcon", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Wind Rider", "TaxiGossipIcon", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Gryphon", "TaxiGossipIcon", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Hippogryph", "TaxiGossipIcon", { { "Flights", "Ability_Mount_Wyvern_01" } } },
    { "Banker", "BankerGossipIcon", { { "Bank", "INV_Misc_Bag_10" } } },
    { "Stable", "GossipGossipIcon", { { "Stables", "Ability_Hunter_BeastCall" } } },
    { "Trainer", "TrainerGossipIcon", { { "Training", "INV_Misc_Book_09" } } },
    { "Auctioneer", "BankerGossipIcon", { { "Auctions", "INV_Misc_Coin_02" } } },
    { "Repair", "VendorGossipIcon", { { "Repairs", "Trade_BlackSmithing" } } },
    { "Merchant", "VendorGossipIcon", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Vendor", "VendorGossipIcon", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Supplies", "VendorGossipIcon", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Goods", "VendorGossipIcon", { { "Sells", "INV_Misc_Coin_01" } } },
    { "Provisioner", "VendorGossipIcon", { { "Sells", "INV_Misc_Coin_01" } } },
}
local function role(info)
    local title = clean(info.subtitle)
    if type(title) ~= "string" then return nil, {} end
    for _, s in ipairs(SERVICES) do
        if title:find(s[1], 1, true) then return GOSSIP .. s[2], s[3] end
    end
    return nil, {}
end
local function roleText(file, title, size)
    return (file and ("|T%s:%d:%d|t "):format(file, size, size) or "") .. title
end

--------------------------------------------------------------------------------
-- Shared parts: the edge, the wing, the glow, the quest ring
--------------------------------------------------------------------------------

local function paintSolid(t, c, a)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    t._rgba = { c[1], c[2], c[3], a or 1 }
end

-- a texture of our own (media/), placed like any part
local function tex(f, parent, layer, name, w, h)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture(KT.Media(name))
    t:SetSize(w, h)
    t._file, t._w, t._h = name, w, h
    return K.part(f, t, "tex")
end
local function tint(t, c, a)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
    t._tint = { c[1], c[2], c[3], a or 1 }
end

-- The soft red glow round the frame while the unit is after you: one texture
-- cut in nine, its corners kept and its sides stretched (media/glow.tga, the
-- frame's edge 16 pixels in from each side).
local GLOW = 16
local function glowFrame(f)
    local g = CreateFrame("Frame", nil, f)
    g:SetPoint("TOPLEFT", -GLOW, GLOW)
    g:SetPoint("BOTTOMRIGHT", GLOW, -GLOW)
    g:SetFrameLevel(max(0, f:GetFrameLevel() - 2))
    local q = 0.25
    local function piece(l, r, t, b)
        local p = g:CreateTexture(nil, "BACKGROUND")
        p:SetTexture(KT.Media("glow"))
        p:SetTexCoord(l, r, t, b)
        return p
    end
    -- the corners as they are
    local tl, tr = piece(0, q, 0, q), piece(1 - q, 1, 0, q)
    local bl, br = piece(0, q, 1 - q, 1), piece(1 - q, 1, 1 - q, 1)
    for _, c in ipairs({ { tl, "TOPLEFT" }, { tr, "TOPRIGHT" }, { bl, "BOTTOMLEFT" }, { br, "BOTTOMRIGHT" } }) do
        c[1]:SetSize(GLOW, GLOW)
        c[1]:SetPoint(c[2])
    end
    -- the sides stretched between them
    local top, bottom = piece(q, 1 - q, 0, q), piece(q, 1 - q, 1 - q, 1)
    local left, right = piece(0, q, q, 1 - q), piece(1 - q, 1, q, 1 - q)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    -- it breathes
    local ag = g.CreateAnimationGroup and g:CreateAnimationGroup()
    if ag then
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        if a then
            a:SetFromAlpha(0.5)
            a:SetToAlpha(1)
            a:SetDuration(0.8)
        end
        g:SetScript("OnShow", function() ag:Play() end)
        g:SetScript("OnHide", function() ag:Stop() end)
    end
    g:Hide()
    return g
end

local function frameParts(f, wing)
    f.spine = solid(f, C.edge)
    -- the wing on the corner, gold for elites and silver for rares, as the
    -- target frame's dragon; above the frame's edge
    if wing then
        f.wing = tex(f, f.top, "OVERLAY", "wing-elite", 30, 30)
        f.wing:Hide()
    end
    f.glow = glowFrame(f)
end

-- the bar's track and edge in the tooltip's dark grey
local function slateBar(f)
    local b = K.bar(f)
    b.text:SetShadowOffset(0, 0)
    return b
end

-- The edge, the frame's rank colour, the wing and the glow, once the size is known.
local function finish(f, info, lines, W, H)
    paintSolid(f.spine, spineColor(info))
    at(f, f.spine, "TOPLEFT", 0, 0)
    f.spine:SetSize(3, H)
    local r = rankOf(info, lines)
    local edge = RANK_COLOR[r] or C.edge
    if f.backdrop and f.backdrop.SetBackdropBorderColor then f.backdrop:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1) end
    f._edge = edge
    if f.wing then
        if r and r ~= "boss" then
            local file = r == "elite" and "wing-elite" or "wing-rare"
            f.wing:SetTexture(KT.Media(file))
            f.wing._file = file
            at(f, f.wing, "TOPLEFT", -9, -9)
            f.wing:Show()
        else
            f.wing:Hide()
        end
    end
    local _, you = target(info, lines)
    f.glow:SetShown(you)
    f._glow = you
    return W, H
end

-- Your quest count in a ring that fills as you go (gold; green when done).
-- The arc is one of 32 steps on media/ring-arc.tga.
local function qring(f, size)
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(size, size)
    r.track = r:CreateTexture(nil, "ARTWORK")
    r.track:SetTexture(KT.Media("ring-track"))
    r.track:SetAllPoints()
    r.arc = r:CreateTexture(nil, "OVERLAY")
    r.arc:SetTexture(KT.Media("ring-arc"))
    r.arc:SetAllPoints()
    r.text = Wg.Text(r, size >= 24 and 9 or 8, C.ringText, "CENTER")
    r.text:SetPoint("CENTER", 0.5, 0)
    r._size = size
    function r:Set(row)
        local frac = min(1, max(0, row.have / row.need))
        local step = floor(frac * 32 + 0.5)
        local done = row.have >= row.need
        if step > 0 then
            local i = step - 1
            local col, line = i % 8, floor(i / 8)
            self.arc:SetTexCoord(col / 8, (col + 1) / 8, line / 4, (line + 1) / 4)
            local c = done and C.done or C.quest
            self.arc:SetVertexColor(c[1], c[2], c[3], 1)
            self.arc:Show()
        else
            self.arc:Hide()
        end
        self.text:SetText(row.have .. "/" .. row.need)
        self._frac, self._done, self._text = frac, done, row.have .. "/" .. row.need
    end
    return K.part(f, r, "qring")
end

-- a group member's progress: their initial and count over a short bar
local function pip(f, w)
    local p = { letter = text(f, 10, T.text), count = text(f, 9, C.quest), track = solid(f, C.track), fill = solid(f, C.quest), w = w }
    function p:Show() self.letter:Show(); self.count:Show(); self.track:Show(); self.fill:Show() end
    function p:Hide() self.letter:Hide(); self.count:Hide(); self.track:Hide(); self.fill:Hide() end
    function p:IsShown() return self.letter:IsShown() end
    function p:Place(row, x, y)
        self.letter:SetText(row.you and "Y" or initial(row.name))
        self.letter:SetTextColor(Wg.rgb(row.color))
        self.letter._color = row.color
        at(f, self.letter, "TOPLEFT", x, y)
        local c = countColor(row)
        self.count:SetText(row.have .. "/" .. row.need)
        self.count:SetTextColor(Wg.rgb(c))
        self.count._color = c
        at(f, self.count, "TOPRIGHT", x + self.w, y + 1)
        at(f, self.track, "TOPLEFT", x, y + 12)
        self.track:SetSize(self.w, 4)
        local frac = min(1, row.have / row.need)
        at(f, self.fill, "TOPLEFT", x, y + 12)
        self.fill:SetSize(max(1, floor(self.w * frac + 0.5)), 4)
        paintSolid(self.fill, frac >= 1 and C.done or C.quest)
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

-- the extra line under a look: the rest of the game's lines, kills together
local function extras(info, lines, others)
    local out = {}
    for _, o in ipairs(others) do
        local plain = clean(o)
        if plain then out[#out + 1] = plain end
    end
    if lines.friends and info.together then
        out[#out + 1] = paint(("%d with %s"):format(info.together, info.partner or "your friend"), T.teal)
    end
    return out
end

--------------------------------------------------------------------------------
-- Whisper: two short lines of text at the cursor
--------------------------------------------------------------------------------

local WH = { frame = "tip" }
Layouts.whisper = WH

function WH.Create(f)
    frameParts(f)
    f.level = text(f, 13, T.gold)
    f.skull = K.skull(f, 13)
    f.rare = tex(f, f, "ARTWORK", "diamond", 8, 8)
    f.name = text(f, 13)
    f.name._display = true
    f.you = text(f, 10, C.you)
    f.quest = text(f, 12, C.quest)
    f.pvp = tex(f, f, "ARTWORK", "pvp", 13, 13)
    f.line2 = text(f, 11, C.dim)
    f.under = solid(f, C.underline)
    f.bar = K.bar(f)
    f.bar.edge:Hide()
    f.bar._edge = nil
end

function WH.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local L, R, GAP = 10, 9, 6
    local x, y = L, 3

    -- line one: level, name, and the one thing to act on: it's after you,
    -- your quest count, PvP
    x = x + placeLevel(f, info, lines, x, y + 1, 13) + 5
    local r = rankOf(info, lines)
    if r == "rare" or r == "rareelite" then
        at(f, f.rare, "TOPLEFT", x - 1, y + 5)
        f.rare:Show()
        x = x + 11
    else
        f.rare:Hide()
    end
    at(f, f.name, "TOPLEFT", x, y)
    f.name:SetWidth(0)
    setText(f.name, shortName(info, 18))
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    x = x + width(f.name, 110) + GAP
    local _, you = target(info, lines, true)
    if you then
        f.you:SetText("YOU")
        at(f, f.you, "TOPLEFT", x, y + 3)
        f.you:Show()
        x = x + width(f.you, 22) + GAP
    else
        f.you:Hide()
    end
    local rows = questRows(info, lines)
    local mine = rows[1] and rows[1].you and rows[1]
    if mine then
        f.quest:SetText(mine.have .. "/" .. mine.need)
        f.quest:SetTextColor(Wg.rgb(countColor(mine)))
        f.quest._color = countColor(mine)
        at(f, f.quest, "TOPLEFT", x, y + 1)
        f.quest:Show()
        x = x + width(f.quest, 22) + GAP
    else
        f.quest:Hide()
    end
    if info.isPlayer and info.pvp then
        at(f, f.pvp, "TOPLEFT", x, y + 2)
        f.pvp:Show()
        x = x + 13 + GAP
    else
        f.pvp:Hide()
    end
    local w1 = x - GAP + R

    -- line two, short: rank and type, guild, health, target, zone, the rest
    local bits = {}
    local kind = kindText(info, lines)
    bits[#bits + 1] = join(" ", r and paint(RANK_WORD[r], RANK_COLOR[r]) or nil, kind)
    if info.isPlayer and lines.guild and info.guild then bits[#bits + 1] = "<" .. info.guild .. ">" end
    if not isService(info) and lines.health then
        if info.dead then
            bits[#bits + 1] = paint("dead", C.tapped)
        else
            local p = healthPct(info)
            if p then bits[#bits + 1] = paint(p .. "%", Layouts.HealthColor(p / 100)) end
        end
    end
    local tgt, isYou = target(info, lines)
    if tgt and not isYou then bits[#bits + 1] = tgt end
    local zone = zoneAndOthers(info, lines)
    if zone then bits[#bits + 1] = zoneText(zone) end
    if info.tapped then bits[#bits + 1] = paint("tapped", C.tapped) end
    -- the party: each member's initial in their colour, and their count
    local counts = {}
    for _, row in ipairs(rows) do
        if not row.you then counts[#counts + 1] = paint(initial(row.name), row.color) .. paint(tostring(row.have), countColor(row)) end
    end
    if #counts > 0 then bits[#bits + 1] = table.concat(counts, " ") end
    -- the game's notes ("Skinnable") stay off this short look; kills together come along
    for _, e in ipairs(extras(info, lines, {})) do bits[#bits + 1] = e end
    local two = join(" · ", unpack(bits))
    f.line2:SetWidth(0)
    f.line2:SetText(two)
    at(f, f.line2, "TOPLEFT", L, y + 17)
    local W = max(floor(110 * wk + 0.5), w1, min(width(f.line2, 120) + L + R, floor(260 * wk + 0.5)))
    f.line2:SetWidth(W - L - R)
    f.line2:SetShown(two ~= "")
    local H = (two ~= "" and y + 17 + 13 or y + 17) + V(5, hk, 3)

    -- the health line along the bottom edge
    if isService(info) then
        f.under:Hide()
        f.bar:Hide()
        f.bar.text:Hide()
    else
        at(f, f.under, "TOPLEFT", 3, H - 2)
        f.under:SetSize(W - 3, 2)
        f.under:Show()
        K.placeBar(f, f.bar, 3, H - 2, W - 3, 2)
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
    frameParts(f, true)
    f.boxEdge = solid(f, C.boxEdge)
    f.box = solid(f, C.box)
    f.level = text(f, 12, T.gold)
    f.skull = K.skull(f, 14)
    f.name = text(f, 15)
    f.name._display = true
    f.ring = qring(f, 28)
    f.rank = text(f, 10, C.rare)
    f.pvp = tex(f, f, "ARTWORK", "pvp", 13, 13)
    f.bar = slateBar(f)
    f.num = text(f, 10, T.text, { outline = "OUTLINE", top = true })
    f.chips = K.pool(function() return K.chip(f) end)
    f.left = text(f, 12, C.dim)
    f.right = text(f, 12, C.dim)
    f.left2 = text(f, 12, C.dim)
    f.right2 = text(f, 12, C.dim)
    f.partyLabel = text(f, 12, C.dim)
    f.pips = K.pool(function() return pip(f, 30) end)
    f.extra = text(f, 11, C.dim)
end

function GL.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local L, R, GAP = 11, 8, V(5, hk, 3)
    local W = max(170, min(380, floor(GL.WIDTH * wk + 0.5)))
    local y = 6

    -- level in its box, name, and on the right the quest ring (or the rare
    -- word, or a player's PvP flag)
    local skull = K.setLevel(f, info)
    local boxW = 27
    if not skull then
        f.level:SetText(info.level .. plus(info, lines))
        f.level:SetWidth(0)
        boxW = max(27, floor(width(f.level, 16) + 9))
        f.level:SetWidth(boxW)
        f.level:SetJustifyH("CENTER")
        f.level._justify = "CENTER"
        at(f, f.level, "TOPLEFT", L, y + 8)
    else
        at(f, f.skull, "TOPLEFT", L + floor((boxW - 14) / 2), y + 7)
    end
    at(f, f.boxEdge, "TOPLEFT", L, y + 4)
    f.boxEdge:SetSize(boxW, 19)
    at(f, f.box, "TOPLEFT", L + 1, y + 5)
    f.box:SetSize(boxW - 2, 17)
    local rows = questRows(info, lines)
    local mine = rows[1] and rows[1].you and rows[1]
    local r = rankOf(info, lines)
    local rightW = 0
    f.ring:Hide()
    f.rank:Hide()
    f.pvp:Hide()
    if mine then
        f.ring:Set(mine)
        at(f, f.ring, "TOPLEFT", W - R - 28, y)
        f.ring:Show()
        rightW = 28 + 6
    elseif r == "rare" or r == "rareelite" then
        f.rank:SetText("RARE")
        f.rank:SetTextColor(Wg.rgb(C.rare))
        f.rank._color = C.rare
        at(f, f.rank, "TOPRIGHT", W - R, y + 9)
        f.rank:Show()
        rightW = width(f.rank, 30) + 6
    elseif info.isPlayer and info.pvp then
        at(f, f.pvp, "TOPLEFT", W - R - 13, y + 7)
        f.pvp:Show()
        rightW = 13 + 6
    end
    at(f, f.name, "TOPLEFT", L + boxW + 6, y + 6)
    f.name:SetWidth(W - L - boxW - 6 - R - rightW)
    setText(f.name, shortName(info, 19))
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    y = y + 28 + GAP

    -- the bar, the number on the left and the percentage on the right; an
    -- NPC shows what it does instead
    local zone, others = zoneAndOthers(info, lines)
    local roleIcon, offers = role(info)
    if isService(info) then
        f.bar:Hide()
        f.bar.text:Hide()
        f.num:Hide()
        local cx = L
        for i, sv in ipairs(offers) do
            local c = f.chips:Get(i)
            c:Set("Interface\\Icons\\" .. sv[2], sv[1])
            at(f, c, "TOPLEFT", cx, y)
            cx = cx + c:GetWidth() + 4
        end
        f.chips:HideFrom(#offers + 1)
        if #offers > 0 then y = y + 16 + GAP end
    else
        f.chips:HideFrom(1)
        local bh = V(13, hk, 6)
        K.placeBar(f, f.bar, L, y, W - L - R, bh)
        Layouts.SetHealth(f.bar, info, s, true)
        f.bar:Show()
        if lines.health and bh >= 9 then
            Wg.SetFont(f.bar.text, 10, "OUTLINE")
            f.bar.text._size, f.bar.text._outline = 10, true
            f.bar.text:SetTextColor(1, 1, 1)
            f.bar.text._color = T.text
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
        y = y + bh + GAP
    end

    -- who it's after (or where a group member is, or tapped) on the left,
    -- what it is on the right
    local left, right
    if isService(info) then
        local title = lines.title and clean(info.subtitle)
        left = title and roleText(roleIcon, "<" .. title .. ">", 13) or nil
        right = lines.type and info.ctype or nil
    else
        local tgt = target(info, lines)
        left = tgt or (zone and zoneText(zone)) or nil
        if info.tapped then left = join("  ", left, paint("tapped", C.tapped)) end
        right = kindText(info, lines)
        -- short of room, the type gives way first ("Quilboar" for "Humanoid · Quilboar")
        if left and not info.isPlayer and lines.type and info.family and info.family ~= info.ctype then
            f.left:SetWidth(0); f.left:SetText(left)
            f.right:SetWidth(0); f.right:SetText(right)
            if width(f.left, 80) + 8 + width(f.right, 80) > W - L - R then right = info.family end
        end
    end
    if pair(f, f.left, f.right, left, right, L, W - R, y) then y = y + 15 + GAP end

    -- players: guild on the left, faction on the right
    if info.isPlayer then
        local guild = lines.guild and info.guild and ("<" .. info.guild .. ">") or nil
        if pair(f, f.left2, f.right2, guild, info.faction, L, W - R, y) then y = y + 15 + GAP end
    else
        f.left2:Hide()
        f.right2:Hide()
    end

    -- the party's progress for this creature: one small bar each, yours first
    local group = {}
    for _, row in ipairs(rows) do if not row.you or #rows > 1 then group[#group + 1] = row end end
    if #group > 1 or (#group == 1 and not group[1].you) then
        f.partyLabel:SetText("Party")
        at(f, f.partyLabel, "TOPLEFT", L, y + 3)
        f.partyLabel:Show()
        local step = 30 + 5
        local px = W - R - (#group * step - 5)
        for i, row in ipairs(group) do
            f.pips:Get(i):Place(row, px, y)
            px = px + step
        end
        f.pips:HideFrom(#group + 1)
        y = y + 16 + GAP
    else
        f.partyLabel:Hide()
        f.pips:HideFrom(1)
    end

    -- anything else the game's tooltip says, and kills together
    local extra = extras(info, lines, others)
    if #extra > 0 then
        f.extra:SetText(table.concat(extra, " · "))
        f.extra:SetWidth(W - L - R)
        at(f, f.extra, "TOPLEFT", L, y)
        f.extra:Show()
        y = y + 13 + GAP
    else
        f.extra:Hide()
    end
    return finish(f, info, lines, W, y - GAP + V(7, hk, 4))
end

--------------------------------------------------------------------------------
-- Ledger: the full read, line by line
--------------------------------------------------------------------------------

local LG = { frame = "tip", WIDTH = 254 }
Layouts.ledger = LG

local function qrow(f)
    local r = { name = text(f, 12), track = solid(f, C.track), fill = solid(f, C.quest), count = text(f, 12, C.quest) }
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
    frameParts(f, true)
    f.name = text(f, 17)
    f.name._display = true
    f.rank = text(f, 10)
    f.title = text(f, 12, C.quest)
    f.guild = text(f, 12, C.guild)
    f.levelLine = text(f, 12)
    f.note = text(f, 12, C.dim)
    f.tappedLine = text(f, 11, C.tapped)
    f.bar = slateBar(f)
    f.rows = K.pool(function() return lrow(f) end)
    f.others = K.pool(function() return text(f, 12, C.dim) end)
    f.chips = K.pool(function() return K.chip(f) end)
    f.sep = solid(f, C.line)
    f.qtitle = text(f, 12, C.quest)
    f.qobj = text(f, 12, C.dim)
    f.qrows = K.pool(function() return qrow(f) end)
    f.qlines = K.pool(function() return text(f, 12) end)
end

function LG.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local L, R = 12, 10
    local W = max(190, min(420, floor(LG.WIDTH * wk + 0.5)))
    local y = 8
    local step = V(17, hk, 13)

    -- name, and on the right its rank (or PvP, or Party for players)
    local r = rankOf(info, lines)
    local word, wordColor
    if r then
        word, wordColor = RANK_WORD[r]:upper(), RANK_COLOR[r]
    elseif info.isPlayer and info.pvp then
        word, wordColor = flag(11) .. " PVP", C.pvp
    elseif info.isPlayer and info.inParty then
        word, wordColor = "PARTY", C.party
    end
    if word then
        f.rank:SetText(word)
        f.rank:SetTextColor(Wg.rgb(wordColor))
        f.rank._color = wordColor
        at(f, f.rank, "TOPRIGHT", W - R, y + 5)
        f.rank:Show()
    else
        f.rank:Hide()
    end
    at(f, f.name, "TOPLEFT", L, y)
    f.name:SetWidth(W - L - R - (word and width(f.rank, 40) + 8 or 0))
    setText(f.name, displayName(info))
    f.name:SetTextColor(Wg.rgb(Layouts.NameColor(info)))
    y = y + V(22, hk, 19)

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

    -- "Level 24 Beast · Wolf"; on the right a player's faction, or the first
    -- of the game's other lines ("Skinnable")
    local zone, others = zoneAndOthers(info, lines)
    local lv = (info.level and info.level > 0) and paint(tostring(info.level), info.difficultyColor or T.text) or paint("??", { 1, 0.16, 0.16 })
    local what = info.isPlayer and (lines.type and join(" ", info.race, info.className) or "")
        or (lines.type and join(" · ", info.ctype, info.family ~= info.ctype and info.family or nil) or "")
    f.levelLine:SetText(join(" ", (LEVEL or "Level") .. " " .. lv, what))
    at(f, f.levelLine, "TOPLEFT", L, y)
    local note = info.isPlayer and info.faction or nil
    if not info.isPlayer and others[1] then
        note = clean(others[1])
        local rest = {}
        for i = 2, #others do rest[#rest + 1] = others[i] end
        others = rest
    end
    if note then
        f.note:SetText(note)
        at(f, f.note, "TOPRIGHT", W - R, y)
        f.note:Show()
        f.levelLine:SetWidth(W - L - R - width(f.note, 50) - 8)
    else
        f.note:Hide()
        f.levelLine:SetWidth(W - L - R)
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
        local h, m = healthNumbers(info)
        local p = healthPct(info)
        Layouts.SetHealth(f.bar, info, s)
        local textW = 0
        if lines.health then
            local t = f.bar.text
            Wg.SetFont(t, 11, "")
            t._size, t._outline = 11, nil
            t:SetTextColor(Wg.rgb(C.dim))
            t._color = C.dim
            t:SetWidth(0)
            if info.dead then
                t:SetText("Dead")
            elseif h and m and m ~= 100 and p then
                t:SetText(("%s / %s · %d%%"):format(BreakUpLargeNumbers(h), BreakUpLargeNumbers(m), p))
            elseif p then
                t:SetText(p .. "%")
            else
                -- hidden: the game writes the percentage it won't show us
                local hidden = info.hpPct
                if info.unit and UnitHealthPercent then hidden = KT.raw(UnitHealthPercent, info.unit, true, CurveConstants and CurveConstants.ScaleTo100) end
                if not (hidden ~= nil and pcall(t.SetFormattedText, t, "%.0f%% · numbers hidden", hidden)) then t:SetText("numbers hidden") end
            end
            textW = width(t, 108) + 8
            at(f, t, "TOPRIGHT", W - R, y + 2)
            t:Show()
        else
            f.bar.text:Hide()
        end
        local bh = V(8, hk, 4)
        K.placeBar(f, f.bar, L, y + 4, W - L - R - textW, bh)
        f.bar:Show()
        y = y + max(step, bh + 9)
    end

    -- targeting, zone and kills together, label and value
    local list = {}
    if lines.target and info.target then
        list[#list + 1] = { "Targeting", info.target, info.target == "You" and C.you or info.targetColor }
    end
    if zone then list[#list + 1] = { "Zone", zoneText(zone), T.text } end
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

    -- the rest of the game's other lines
    for i, o in ipairs(others) do
        local fs = f.others:Get(i)
        setText(fs, o)
        fs:SetWidth(W - L - R)
        at(f, fs, "TOPLEFT", L, y)
        y = y + step
    end
    f.others:HideFrom(#others + 1)

    -- what an NPC does
    local _, offers = role(info)
    if not isService(info) then offers = {} end
    local cx = L
    for i, item in ipairs(offers) do
        local c = f.chips:Get(i)
        c:Set("Interface\\Icons\\" .. item[2], item[1])
        at(f, c, "TOPLEFT", cx, y + 1)
        cx = cx + c:GetWidth() + 4
    end
    f.chips:HideFrom(#offers + 1)
    if #offers > 0 then y = y + 20 end

    -- quests: a table when it's one objective each, the game's lines otherwise
    local qlist, asTable, objective = ledgerQuests(info, lines)
    f.qtitle:Hide()
    f.qobj:Hide()
    if #qlist > 0 then
        y = y + 4
        at(f, f.sep, "TOPLEFT", L, y)
        f.sep:SetSize(W - L - R, 1)
        f.sep:Show()
        y = y + 7
    else
        f.sep:Hide()
    end
    local qstep = V(17, hk, 12)
    if asTable then
        local qt
        for _, q in ipairs(qlist) do if q[2] then qt = q[1] end end
        if qt then
            setText(f.qtitle, qt)
            at(f, f.qtitle, "TOPLEFT", L, y)
            f.qtitle:Show()
        end
        f.qobj:SetText(objective)
        at(f, f.qobj, "TOPRIGHT", W - R, y)
        f.qobj:Show()
        y = y + qstep
        local rows = questRows(info, lines)
        for i, row in ipairs(rows) do
            local qr = f.qrows:Get(i)
            local c = countColor(row)
            qr.name:SetText(row.name)
            qr.name:SetTextColor(Wg.rgb(row.color))
            qr.name._color = row.color
            at(f, qr.name, "TOPLEFT", L, y)
            at(f, qr.track, "TOPLEFT", W - R - 30 - 7 - 56, y + 6)
            qr.track:SetSize(56, 4)
            at(f, qr.fill, "TOPLEFT", W - R - 30 - 7 - 56, y + 6)
            qr.fill:SetSize(max(1, floor(56 * min(1, row.have / row.need) + 0.5)), 4)
            paintSolid(qr.fill, c)
            qr.count:SetText(row.have .. "/" .. row.need)
            qr.count:SetTextColor(Wg.rgb(c))
            qr.count._color = c
            at(f, qr.count, "TOPRIGHT", W - R, y)
            y = y + qstep
        end
        f.qrows:HideFrom(#rows + 1)
        f.qlines:HideFrom(1)
    else
        f.qrows:HideFrom(1)
        for i, q in ipairs(qlist) do
            local fs = f.qlines:Get(i)
            setText(fs, q[1])
            local c = q[2] and C.quest or q[3] and C.dim or T.text
            fs:SetTextColor(Wg.rgb(c))
            fs._color = c
            fs:SetWidth(W - L - R)
            at(f, fs, "TOPLEFT", L, y)
            y = y + qstep
        end
        f.qlines:HideFrom(#qlist + 1)
    end
    return finish(f, info, lines, W, y + V(4, hk, 2))
end

--------------------------------------------------------------------------------
-- Banner: hangs under the nameplate, which already shows name and health,
-- so it adds the rest: level, rank, quest, the party's counts, the target;
-- what it is below
--------------------------------------------------------------------------------

local BN = { frame = "tip" }
Layouts.banner = BN

function BN.Create(f)
    frameParts(f)
    -- the notch pointing up at the nameplate, over the frame's edge
    f.notchFill = tex(f, f.top, "ARTWORK", "notch-fill", 16, 8)
    f.notchEdge = tex(f, f.top, "OVERLAY", "notch-edge", 16, 8)
    f.level = text(f, 12, T.gold)
    f.skull = K.skull(f, 13)
    f.rank = text(f, 10)
    f.title = text(f, 11, C.dim)
    f.pvp = tex(f, f, "ARTWORK", "pvp", 13, 13)
    f.ring = qring(f, 22)
    f.members = K.pool(function() return text(f, 11) end)
    f.tappedText = text(f, 11, C.tapped)
    f.target = text(f, 12)
    f.line2 = text(f, 11, C.dim)
end

function BN.Fill(f, info, s, wk, hk)
    local lines = s.lines
    local GAP, TOP = 7, 3
    -- the top row is laid out once to measure it, then centred
    local items = {}
    local function item(w, place) items[#items + 1] = { w = w, place = place } end
    if K.setLevel(f, info) then
        item(13, function(x) at(f, f.skull, "TOPLEFT", x, TOP + 5) end)
    else
        f.level:SetText(info.level .. plus(info, lines))
        item(width(f.level, 16), function(x) at(f, f.level, "TOPLEFT", x, TOP + 5) end)
    end
    local r = rankOf(info, lines)
    if r and r ~= "elite" then
        f.rank:SetText(RANK_WORD[r]:upper())
        f.rank:SetTextColor(Wg.rgb(RANK_COLOR[r]))
        f.rank._color = RANK_COLOR[r]
        f.rank:Show()
        item(width(f.rank, 30), function(x) at(f, f.rank, "TOPLEFT", x, TOP + 6) end)
    else
        f.rank:Hide()
    end
    local title = isService(info) and lines.title and clean(info.subtitle)
    if title then
        f.title:SetText(roleText((role(info)), title, 13))
        f.title:Show()
        item(width(f.title, 60), function(x) at(f, f.title, "TOPLEFT", x, TOP + 6) end)
    else
        f.title:Hide()
    end
    if info.isPlayer and info.pvp then
        f.pvp:Show()
        item(13, function(x) at(f, f.pvp, "TOPLEFT", x, TOP + 4) end)
    else
        f.pvp:Hide()
    end
    local rows = questRows(info, lines)
    local mine = rows[1] and rows[1].you and rows[1]
    if mine then
        f.ring:Set(mine)
        f.ring:Show()
        item(22, function(x) at(f, f.ring, "TOPLEFT", x, TOP) end)
    else
        f.ring:Hide()
    end
    local n = 0
    for _, row in ipairs(rows) do
        if not row.you then
            n = n + 1
            local m = f.members:Get(n)
            m:SetText(paint(initial(row.name), row.color) .. " " .. paint(row.have .. "/" .. row.need, countColor(row)))
            item(width(m, 28), function(x) at(f, m, "TOPLEFT", x, TOP + 6) end)
        end
    end
    f.members:HideFrom(n + 1)
    if info.tapped then
        f.tappedText:SetText("tapped")
        f.tappedText:Show()
        item(width(f.tappedText, 36), function(x) at(f, f.tappedText, "TOPLEFT", x, TOP + 6) end)
    else
        f.tappedText:Hide()
    end
    local tgt = target(info, lines, true)
    if tgt then
        f.target:SetText(tgt)
        f.target:Show()
        item(width(f.target, 40), function(x) at(f, f.target, "TOPLEFT", x, TOP + 5) end)
    else
        f.target:Hide()
    end
    local w1 = -GAP
    for _, it in ipairs(items) do w1 = w1 + it.w + GAP end

    -- the second row: what it is, a player's guild and faction, and the rest
    local zone = zoneAndOthers(info, lines)
    local bits = { isService(info) and (lines.type and info.ctype or "") or kindText(info, lines) }
    if info.isPlayer and lines.guild and info.guild then bits[#bits + 1] = "<" .. info.guild .. ">" end
    if info.isPlayer and info.faction then bits[#bits + 1] = info.faction end
    if zone then bits[#bits + 1] = zoneText(zone) end
    for _, e in ipairs(extras(info, lines, {})) do bits[#bits + 1] = e end
    local two = join(" · ", unpack(bits))
    f.line2:SetWidth(0)
    f.line2:SetText(two)
    local W = max(60, w1 + 16, min(width(f.line2, 100) + 16, floor(280 * wk + 0.5)))
    local x = floor((W - w1) / 2 + 0.5)
    for _, it in ipairs(items) do
        it.place(x)
        x = x + it.w + GAP
    end
    local H = TOP + 22 + 1
    if two ~= "" then
        f.line2:SetWidth(W - 16)
        f.line2:SetJustifyH("CENTER")
        f.line2._justify = "CENTER"
        at(f, f.line2, "TOP", W / 2, H)
        f.line2:Show()
        H = H + 13
    else
        f.line2:Hide()
    end
    H = H + V(4, hk, 3)

    -- the notch, in the frame's ground and edge colours
    local edge = RANK_COLOR[r] or C.edge
    at(f, f.notchFill, "TOPLEFT", floor(W / 2 - 8 + 0.5), -6)
    tint(f.notchFill, C.ground, 1)
    at(f, f.notchEdge, "TOPLEFT", floor(W / 2 - 8 + 0.5), -6)
    tint(f.notchEdge, edge, 1)
    return finish(f, info, lines, W, H)
end
