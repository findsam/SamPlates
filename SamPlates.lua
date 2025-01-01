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

    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints()

    icon.timer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon.timer:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    icon.timer:SetTextColor(0, 0.75, 1) 

    icon:SetScript("OnUpdate", function(self, elapsed)
        if not self.expirationTime then return end
        local remaining = self.expirationTime - GetTime()
        if remaining <= 0 then
            self.timer:SetText("")
            return
        end
        if remaining < 1 then 
            self.timer:SetText(string.format("%.1f", remaining))
        else 
            self.timer:SetText(math.floor(remaining))
        end
        -- Change the text color to red when less than 5 seconds remaining
        if remaining < 5 then
            self.timer:SetTextColor(1, 0, 0) -- Red color (R: 1, G: 0, B: 0)
        else
            self.timer:SetTextColor(0, 0.75, 1) -- Default blue color (R: 0, G: 0.75, B: 1)
        end
    end)

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
            icon.expirationTime = aura.expirationTime
            
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
