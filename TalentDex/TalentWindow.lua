local _, TalentDex = ...

local button
local attachedTalentFrame

local function CreateToggleButton(talentFrame)
    if button then
        return
    end

    button = CreateFrame("Button", "TalentDexToggleButton", talentFrame, "UIPanelButtonTemplate")
    button:SetSize(130, 22)
    -- 12.1 reserves the right edge of BottomBar for War Mode and PvP talents.
    button:SetPoint("RIGHT", talentFrame.BottomBar, "RIGHT", -250, 3)
    button:SetText("Open TalentDex")
    button:SetScript("OnClick", function()
        TalentDex:ToggleFrame()
    end)
end

local function UpdateButtonText()
    if button then
        button:SetText(TalentDex.frame and TalentDex.frame:IsShown() and "Close TalentDex" or "Open TalentDex")
    end
end

function TalentDex:OnTalentWindowShown()
    self:AnchorFrame()
    UpdateButtonText()
end

function TalentDex:OnTalentWindowHidden()
    if self.frame then
        self:HideFrame()
    end
    UpdateButtonText()
end

function TalentDex:TryAttachToTalentWindow()
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
    self:CreateTalentDexFrame(talentFrame)
    CreateToggleButton(talentFrame)

    talentFrame:HookScript("OnShow", function()
        TalentDex:OnTalentWindowShown()
    end)
    talentFrame:HookScript("OnHide", function()
        TalentDex:OnTalentWindowHidden()
    end)

    if talentFrame:IsShown() then
        self:OnTalentWindowShown()
    end
end

function TalentDex:UpdateToggleButton()
    UpdateButtonText()
end
