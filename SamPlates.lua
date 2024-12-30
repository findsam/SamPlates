
local AceAddon = LibStub("AceAddon-3.0")
local SamPlates = AceAddon:NewAddon("SamPlates", "AceEvent-3.0", "AceTimer-3.0")

-- Configuration
local ICON_SIZE = 26
local DEBUFF_ICON_OFFSET_Y = 10
local MAX_DEBUFFS = 10
local UPDATE_INTERVAL = 0.1  -- Update timers every 0.1 seconds

-- Create icon pool
function SamPlates:CreateAuraIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints()
    
    icon.timer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon.timer:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE") 
    icon.timer:SetTextColor(0, 0.75, 1)
    
    return icon
end

-- Update timer display
function SamPlates:UpdateAuraTimers(namePlateFrame)
    if not namePlateFrame or not namePlateFrame.UnitFrame then return end
    
    if namePlateFrame.debuffIcons then
        for _, icon in ipairs(namePlateFrame.debuffIcons) do
            if icon:IsShown() and icon.expirationTime then
                local remaining = math.max(icon.expirationTime - GetTime(), 0)
                if remaining > 0 then
                    icon.timer:SetText(string.format("%.1f", remaining))
                    icon.timer:Show()
                    icon.timer:SetTextColor(0, 0.75, 1)
                    if remaining < 10 then 
                        icon.timer:SetTextColor(1, 0, 0)
                    end
                else
                    icon.timer:Hide()
                end
            end
        end
    end
end

-- Update auras for a specific nameplate
function SamPlates:UpdateNameplateAuras(namePlateFrame)
    if not namePlateFrame or not namePlateFrame.UnitFrame then return end
    
    local unit = namePlateFrame.UnitFrame.unit
    if not unit then return end
    
    -- Hide default auras
    if namePlateFrame.UnitFrame.BuffFrame then
        namePlateFrame.UnitFrame.BuffFrame:Hide()
    end
    
    -- Initialize icon container for debuffs
    if not namePlateFrame.debuffIcons then
        namePlateFrame.debuffIcons = {}
    end
    
    -- Process Debuffs
    local debuffIndex = 1
    for i = 1, 40 do
        -- local auraData = C_UnitAuras.GetDebuffDataByIndex(unit, i)
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, AuraUtil.AuraFilters.Harmful)
        if not auraData or debuffIndex > MAX_DEBUFFS then break end
        
        -- Check if the debuff was cast by the player
        local isPlayerCast = auraData.sourceUnit == "player" and auraData.nameplateShowPersonal
        -- local isPlayerCast = auraData.sourceUnit == 'player' and auraData.isNameplateOnly == true

        if isPlayerCast then
            local icon = namePlateFrame.debuffIcons[debuffIndex] or self:CreateAuraIcon(namePlateFrame.UnitFrame)
            namePlateFrame.debuffIcons[debuffIndex] = icon
            
            icon:SetPoint("BOTTOMLEFT", namePlateFrame.UnitFrame, "TOPLEFT", (debuffIndex - 1) * (ICON_SIZE + 2), DEBUFF_ICON_OFFSET_Y)
            icon.texture:SetTexture(auraData.icon)
            
            -- Store expiration time for timer
            if auraData.duration and auraData.duration > 0 then
                icon.expirationTime = auraData.expirationTime
                local remaining = math.max(auraData.expirationTime - GetTime(), 0)
                icon.timer:SetText(string.format("%.1f", remaining))
                icon.timer:Show()
            else
                icon.expirationTime = nil
                icon.timer:Hide()
            end
            
            icon:Show()
            debuffIndex = debuffIndex + 1
        end
    end
    
    -- Hide unused debuff icons
    for i = debuffIndex, #namePlateFrame.debuffIcons do
        namePlateFrame.debuffIcons[i]:Hide()
    end
end

-- Event handler for nameplate updates
function SamPlates:NAME_PLATE_UNIT_ADDED(_, unitID)
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitID)
    if namePlate then
        self:UpdateNameplateAuras(namePlate)
    end
end

-- Event handler for unit aura changes
function SamPlates:UNIT_AURA(_, unitID)
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitID)
    if namePlate then
        self:UpdateNameplateAuras(namePlate)
    end
end

-- Hide default nameplates on initial load
function SamPlates:HideDefaultNameplateAuras()
    for _, namePlate in ipairs(C_NamePlate.GetNamePlates()) do
        if namePlate.UnitFrame and namePlate.UnitFrame.BuffFrame then
            namePlate.UnitFrame.BuffFrame:Hide()
        end
    end
end

-- Periodic timer update for all nameplates
function SamPlates:UpdateAllNameplateTimers()
    for _, namePlate in ipairs(C_NamePlate.GetNamePlates()) do
        self:UpdateAuraTimers(namePlate)
    end
end

-- Addon initialization
function SamPlates:OnEnable()
    -- Register events
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("UNIT_AURA")
    
    -- Hide default auras on login
    self:HideDefaultNameplateAuras()
    
    -- Start periodic timer update
    self.timerUpdater = self:ScheduleRepeatingTimer("UpdateAllNameplateTimers", UPDATE_INTERVAL)

    -- Add custom logic for handling BuffFrame visibility
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnNamePlateUnitAdded")
end

-- Event handler to hide the BuffFrame when nameplate is added
function SamPlates:OnNamePlateUnitAdded(_, unitID)
    local namePlate = C_NamePlate.GetNamePlateForUnit(unitID)
    local frame = namePlate and namePlate.UnitFrame
    if not frame or frame:IsForbidden() then return end
    
    -- Hide the BuffFrame by clearing its position and setting alpha to 0
    if frame.BuffFrame then
        frame.BuffFrame:ClearAllPoints()
        frame.BuffFrame:SetAlpha(0)
    end
end

-- Addon cleanup
function SamPlates:OnDisable()
    -- Stop the timer when addon is disabled
    if self.timerUpdater then
        self:CancelTimer(self.timerUpdater)
    end
end
