local _, KT = ...
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

--------------------------------------------------------------------------------
-- Minimap button
--------------------------------------------------------------------------------

local button

local function updatePosition()
    local angle = math.rad(KT.db.settings.minimap.angle or 220)
    local radius = Minimap:GetWidth() / 2 + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function updateState()
    if button then button:SetShown(not KT.db.settings.minimap.hide) end
end

local function showTooltip(self)
    local st = KT.db.settings
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff4fd1c5Kraken|rtip")
    GameTooltip:AddDoubleLine("Card", st.enabled and KT.STYLE_LABEL[st.style] or "off (the game's tooltip)", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Where", KT.POSITION_LABEL[st.position], 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: options   Right-click: next style   Drag: move", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

local function createButton()
    if button then return end
    button = CreateFrame("Button", "KrakentipMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 6, -5)
    icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
    local mask = button.CreateMaskTexture and button:CreateMaskTexture()
    if mask then
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function(_, which)
        if which == "RightButton" then
            KT:SetStyle()
            if GameTooltip:IsOwned(button) then showTooltip(button) end
        else
            KT.Options:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            KT.db.settings.minimap.angle = math.deg(atan2(py / scale - my, px / scale - mx))
            updatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    updatePosition()
    updateState()
end

KT:Listen("SETUP", createButton)
KT:Listen("SETTINGS", updateState)
