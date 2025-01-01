local _, addon = ...

local ICON_SIZE = 26
local DEBUFF_ICON_OFFSET_Y = 5
local MAX_DEBUFFS = 10
local UPDATE_INTERVAL = 0.1 

local frame = CreateFrame("Frame")

-- Consolidated aura frame management
function addon:ManageDefaultAuras(nameplate, shouldShow)
    if not nameplate or not nameplate.UnitFrame then return end
    
    local frames = {
        nameplate.UnitFrame.BuffFrame,
        nameplate.UnitFrame.DebuffFrame
    }
    
    for _, frame in ipairs(frames) do
        if frame and not frame:IsForbidden() then
            if not shouldShow then
                frame:UnregisterAllEvents()
                frame:Hide()
                frame:SetScript("OnUpdate", nil)
                frame:SetAlpha(0)
            else
                frame:Show()
                frame:SetAlpha(1)
            end
        end
    end
end

-- Pre-create icon pool
addon.iconPool = {}
local INITIAL_POOL_SIZE = 20

function addon:InitializeIconPool()
    for i = 1, INITIAL_POOL_SIZE do
        local icon = self:BuildIcon(UIParent)
        icon:Hide()
        tinsert(self.iconPool, icon)
    end
end

function addon:BuildIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()

    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetDrawEdge(true)
    icon.cooldown:SetDrawSwipe(true)
    icon.cooldown:SetDrawBling(false)
    icon.cooldown:SetReverse(false)
    icon.cooldown:SetHideCountdownNumbers(false)
    
    icon.cooldown.Text = icon.cooldown:GetRegions()
    if icon.cooldown.Text then
        icon.cooldown.Text:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
        icon.cooldown.Text:SetTextColor(0, 0.75, 1)
    end

    icon.anchor = CreateFrame("Frame", nil, icon)
    icon.anchor:SetPoint("CENTER", icon)
    return icon
end

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

function addon:UpdateNameplateAuras(nameplate, unit)
    if not nameplate or not unit then return end
    
    self:ManageDefaultAuras(nameplate, false)
    
    if not nameplate.auraIcons then
        nameplate.auraIcons = {}
    end
    
    -- Track current icons to minimize hide/show operations
    local currentIcons = {}
    local iconCount = 0
    local ICON_SPACING = ICON_SIZE + 2
    
    -- First pass: Update existing or add new icons
    local auraIndex = 1
    while auraIndex <= 40 and iconCount < MAX_DEBUFFS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, auraIndex, AuraUtil.AuraFilters.Harmful)
        if not aura then break end
        
        if aura.sourceUnit == "player" and aura.nameplateShowPersonal then
            iconCount = iconCount + 1
            
            local icon = nameplate.auraIcons[iconCount] or self:GetIcon(nameplate)
            icon.texture:SetTexture(aura.icon)
            
            if icon.cooldown and aura.duration and aura.duration > 0 then
                icon.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                if icon.cooldown.Text then
                    local remaining = aura.expirationTime - GetTime()
                    icon.cooldown.Text:SetTextColor(remaining < 5 and 1 or 0, remaining < 5 and 0 or 0.75, remaining < 5 and 0 or 1)
                end
            end
            
            local xOffset = (iconCount - 1) * ICON_SPACING
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", nameplate.UnitFrame.BuffFrame, "LEFT", xOffset, DEBUFF_ICON_OFFSET_Y)
            
            currentIcons[iconCount] = icon
            nameplate.auraIcons[iconCount] = icon
        end
        
        auraIndex = auraIndex + 1
    end
    
    -- Clean up excess icons
    for i = iconCount + 1, #nameplate.auraIcons do
        self:RecycleIcon(nameplate.auraIcons[i])
        nameplate.auraIcons[i] = nil
    end
end

-- Event handlers
function addon:PLAYER_ENTERING_WORLD()
    self:InitializeIconPool()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33SamPlates successfully initialised.|r")
end

function addon:NAME_PLATE_UNIT_ADDED(_, unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        self:UpdateNameplateAuras(nameplate, unit)
    end
end

addon.UNIT_AURA = addon.NAME_PLATE_UNIT_ADDED

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
