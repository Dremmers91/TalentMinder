local _, TalentMinder = ...

local button
local attachedTalentFrame

local function CreateToggleButton(talentFrame)
    if button then
        return
    end

    button = CreateFrame("Button", "TalentMinderToggleButton", talentFrame, "UIPanelButtonTemplate")
    button:SetSize(130, 22)
    -- Keep the toggle in the bottom-bar gap between Blizzard's search and apply controls.
    button:SetPoint("RIGHT", talentFrame.ApplyButton, "LEFT", -20, 0)
    button:SetText("TalentMinder")
    button:SetScript("OnClick", function()
        TalentMinder:ToggleFrame()
    end)
end

local function UpdateButtonText()
    if button then
        button:SetText("TalentMinder")
    end
end

function TalentMinder:OnTalentWindowShown()
    self:AnchorFrame()
    UpdateButtonText()
end

function TalentMinder:OnTalentWindowHidden()
    if self.frame then
        self:HideFrame()
    end
    UpdateButtonText()
end

function TalentMinder:TryAttachToTalentWindow()
    if attachedTalentFrame then
        return
    end

    -- Creating or modifying children of Blizzard UI is deferred while protected
    -- combat state is active. The PLAYER_REGEN_ENABLED event retries this work.
    if InCombatLockdown() then
        self.pendingAttachment = true
        return
    end

    local playerSpellsFrame = _G.PlayerSpellsFrame
    local talentFrame = playerSpellsFrame and playerSpellsFrame.TalentsFrame
    if not talentFrame then
        return
    end

    self.pendingAttachment = nil
    attachedTalentFrame = talentFrame
    self.talentFrame = talentFrame
    self:CreateTalentMinderFrame(talentFrame)
    CreateToggleButton(talentFrame)

    talentFrame:HookScript("OnShow", function()
        TalentMinder:OnTalentWindowShown()
    end)
    talentFrame:HookScript("OnHide", function()
        TalentMinder:OnTalentWindowHidden()
    end)

    if talentFrame:IsShown() then
        self:OnTalentWindowShown()
    end
end

function TalentMinder:UpdateToggleButton()
    UpdateButtonText()
end
