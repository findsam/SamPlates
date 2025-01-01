local _, addon = ...

local ICON_SIZE = 30
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

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()

    -- Create cooldown frame
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetDrawEdge(true)
    icon.cooldown:SetDrawSwipe(true)
    icon.cooldown:SetDrawBling(false)
    icon.cooldown:SetReverse(false)
    
    -- Set up the cooldown count text
    icon.cooldown:SetHideCountdownNumbers(false)
    icon.cooldown.Text = icon.cooldown:GetRegions()
    if icon.cooldown.Text then
        icon.cooldown.Text:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
        icon.cooldown.Text:SetTextColor(0, 0.75, 1)
    end

    -- Remove the manual timer update since we're using cooldown's built-in text
    icon:SetScript("OnUpdate", nil)

    icon.anchor = CreateFrame("Frame", nil, icon)
    icon.anchor:SetPoint("CENTER", icon)
    return icon
end

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
    if icon.cooldown then
        icon.cooldown:Clear()
    end
    tinsert(self.iconPool, icon)
end

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

function addon:UpdateNameplateAuras(nameplate, unit)
    if not nameplate or not unit then return end
    
    self:HideDefaultAuras(nameplate)
    
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
    local ICON_SPACING = ICON_SIZE + 2
    
    while auraIndex <= 40 and iconCount < MAX_DEBUFFS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, auraIndex, AuraUtil.AuraFilters.Harmful)
        if not aura then break end
        
        if aura.sourceUnit == "player" and aura.nameplateShowPersonal then
            iconCount = iconCount + 1
            
            local icon = self:GetIcon(nameplate)
            icon.texture:SetTexture(aura.icon)
            
            -- Set cooldown
            if icon.cooldown and aura.duration and aura.duration > 0 then
                icon.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                -- Update text color based on remaining time
                if icon.cooldown.Text then
                    local remaining = aura.expirationTime - GetTime()
                    if remaining < 5 then
                        icon.cooldown.Text:SetTextColor(1, 0, 0) -- Red for < 5 seconds
                    else
                        icon.cooldown.Text:SetTextColor(0, 0.75, 1) -- Default blue
                    end
                end
            end
            
            local xOffset = (iconCount - 1) * ICON_SPACING
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", nameplate.UnitFrame.BuffFrame, "LEFT", xOffset, DEBUFF_ICON_OFFSET_Y)
            
            tinsert(nameplate.auraIcons, icon)
        end
        
        auraIndex = auraIndex + 1
    end
end

-- Event handlers remain the same
function addon:PLAYER_ENTERING_WORLD(event, ...)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF99CC33%s|r", 'SamPlates successfully initialised.'))
end

function addon:NAME_PLATE_UNIT_ADDED(_, unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        self:DisableDefaultAuras(nameplate)
        self:UpdateNameplateAuras(nameplate, unit)
    end
end

function addon:UNIT_AURA(_, unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        self:DisableDefaultAuras(nameplate)
        self:UpdateNameplateAuras(nameplate, unit)
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
