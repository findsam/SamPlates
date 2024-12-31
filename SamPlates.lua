local _, addon = ...

local ICON_SIZE = 46
local DEBUFF_ICON_OFFSET_Y = 5
local MAX_DEBUFFS = 10
local UPDATE_INTERVAL = 0.1 

local frame = CreateFrame("Frame")

function addon:DisableDefaultAuras(nameplate)
    if nameplate and nameplate.UnitFrame then
        local buffFrame = nameplate.UnitFrame.BuffFrame
        local debuffFrame = nameplate.UnitFrame.DebuffFrame
        if buffFrame and not buffFrame:IsForbidden() then
            buffFrame:UnregisterAllEvents()
            buffFrame:Hide()
            buffFrame:SetScript("OnUpdate", nil)
            buffFrame:SetAlpha(0)
        end

        if debuffFrame and not debuffFrame:IsForbidden() then
            debuffFrame:UnregisterAllEvents()
            debuffFrame:Hide()
            debuffFrame:SetScript("OnUpdate", nil)
            debuffFrame:SetAlpha(0)
        end
    end
end

function addon:BuildIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints()

    -- Timer text for the icon
    icon.timer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon.timer:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    icon.timer:SetTextColor(0, 0.75, 1) 

    -- Add timer update functionality
    icon:SetScript("OnUpdate", function(self, elapsed)
        if not self.expirationTime then return end
        local remaining = self.expirationTime - GetTime()
        if remaining <= 0 then
            self.timer:SetText("")
            return
        end
        self.timer:SetText(math.floor(remaining))
        if remaining < 1 then 
         self.timer:SetText(string.format("%.1f", remaining))
        end
        if remaining <= 5 then 
          ActionButton_ShowOverlayGlow(self)
        end
        if remaining > 5 then 
            ActionButton_HideOverlayGlow(self)
        end
    end)

    -- Create anchor point at center for consistent positioning
    icon.anchor = CreateFrame("Frame", nil, icon)
    icon.anchor:SetPoint("CENTER", icon)
    
    icon:SetScale(0.5)
    return icon
end

-- Icon pool to manage icon frames
addon.iconPool = {}

function addon:GetIcon(parent)
    local icon = tremove(self.iconPool)
    if not icon then
        icon = self:BuildIcon(parent)
    else
        icon:SetParent(parent)
        icon:Show()
    end
    return icon
end

function addon:RecycleIcon(icon)
    icon:Hide()
    icon:ClearAllPoints()
    icon:SetParent(nil)
    tinsert(self.iconPool, icon)
end

-- Function to hide default Blizzard buffs and debuffs
function addon:HideDefaultAuras(nameplate)
    if nameplate and nameplate.UnitFrame then
        -- Hide default buff frame
        if nameplate.UnitFrame.BuffFrame then
            nameplate.UnitFrame.BuffFrame:Hide()
        end
        -- Hide default debuff frame
        if nameplate.UnitFrame.DebuffFrame then
            nameplate.UnitFrame.DebuffFrame:Hide()
        end
    end
end

-- Function to update nameplate auras
function addon:UpdateNameplateAuras(nameplate, unit)
    if not nameplate or not unit then return end
    
    -- Hide default aura frames
    self:HideDefaultAuras(nameplate)
    
    -- Clear existing icons
    if not nameplate.auraIcons then
        nameplate.auraIcons = {}
    else
        for _, icon in ipairs(nameplate.auraIcons) do
            self:RecycleIcon(icon)
        end
        wipe(nameplate.auraIcons)
    end

    local auraIndex = 1
    local iconCount = 0
    local ICON_SPACING = ICON_SIZE + 2  -- Consistent spacing between icons
    
    -- Collect valid auras
    while auraIndex <= 40 and iconCount < MAX_DEBUFFS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, auraIndex, AuraUtil.AuraFilters.Harmful)
        if not aura then break end
        
        if aura.sourceUnit == "player" and aura.nameplateShowPersonal then
            iconCount = iconCount + 1
            
            local icon = self:GetIcon(nameplate)
            icon.texture:SetTexture(aura.icon)
            icon.expirationTime = aura.expirationTime
            
            -- Position the icon using the BuffFrame as the anchor point
            local xOffset = (iconCount - 1) * ICON_SPACING
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", nameplate.UnitFrame.BuffFrame, "LEFT", xOffset,   DEBUFF_ICON_OFFSET_Y)
            
            tinsert(nameplate.auraIcons, icon)
        end
        
        auraIndex = auraIndex + 1
    end
end

-- Event handlers
function addon:PLAYER_ENTERING_WORLD(event, ...)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF99CC33%s|r", 'SamPlates successfully initialised.'))
end


function addon:NAME_PLATE_UNIT_ADDED(_, unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        self:DisableDefaultAuras(nameplate) -- Ensure default auras are disabled
        self:UpdateNameplateAuras(nameplate, unit) -- Add custom auras
    end
end

function addon:UNIT_AURA(_, unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        self:DisableDefaultAuras(nameplate) -- Ensure default auras are disabled on updates
        self:UpdateNameplateAuras(nameplate, unit) -- Refresh custom auras
    end
end

function addon:NAME_PLATE_UNIT_REMOVED(_, unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate and nameplate.auraIcons then
        for _, icon in ipairs(nameplate.auraIcons) do
            self:RecycleIcon(icon)
        end
        wipe(nameplate.auraIcons)
    end
end

-- Initialize the addon
local function Run()
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")    
    frame:SetScript("OnEvent", function(self, event, ...)
        if addon[event] then
            addon[event](addon, event, ...)
        end
    end)
end

Run()
