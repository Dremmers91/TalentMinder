local _, TalentDex = ...

local PANEL_WIDTH = 360
local PANEL_INITIAL_HEIGHT = 400

local function ApplyBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    frame:SetBackdropColor(0.025, 0.035, 0.055, 0.97)
    frame:SetBackdropBorderColor(0.75, 0.6, 0.15, 1)
end

function TalentDex:CreateTalentDexFrame(talentFrame)
    if self.frame then
        return self.frame
    end

    -- UIParent keeps this companion panel independent from Blizzard's frame.
    local frame = CreateFrame("Frame", "TalentDexFrame", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_INITIAL_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(talentFrame:GetFrameLevel() + 5)
    frame:Hide()
    ApplyBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("TalentDex")
    title:SetTextColor(1, 0.78, 0.18)

    local contextText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    contextText:SetPoint("TOP", title, "BOTTOM", 0, -5)
    frame.contextText = contextText

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.75, 0.6, 0.15, 0.55)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -64)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -64)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        TalentDex:HideFrame()
    end)

    self.frame = frame
    self:CreateControls(frame)
    self:AnchorFrame()
    self:UpdatePlayerContextText()
    return frame
end

function TalentDex:UpdatePlayerContextText()
    if not self.frame or not self.frame.contextText then
        return
    end

    local context = self.playerContext or {}
    local className = context.className or "Unknown Class"
    local specName = context.specName or "No Specialization"
    local classColor = context.class and RAID_CLASS_COLORS[context.class]
    self.frame.contextText:SetText(className .. " - " .. specName)

    if classColor then
        self.frame.contextText:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        self.frame.contextText:SetTextColor(0.8, 0.8, 0.8)
    end
end

function TalentDex:AnchorFrame()
    if not self.frame or not self.talentFrame then
        return
    end

    local talentWindow = self.talentFrame:GetParent()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", talentWindow, "TOPRIGHT", 12, 0)
end

function TalentDex:ShowFrame()
    if not self.frame or not self.talentFrame or not self.talentFrame:IsVisible() then
        return
    end
    self.frame:Show()
    self:UpdateToggleButton()
end

function TalentDex:HideFrame()
    if self.frame then
        self.frame:Hide()
    end
    self:UpdateToggleButton()
end

function TalentDex:ToggleFrame()
    if not self.frame then
        return
    end

    if self.frame:IsShown() then
        self:HideFrame()
    else
        self:ShowFrame()
    end
end
