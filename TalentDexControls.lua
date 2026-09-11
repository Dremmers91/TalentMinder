local _, TalentDex = ...

local PANEL_PADDING = 23
local SELECTOR_WIDTH = 74
local SELECTOR_HEIGHT = 50
local SELECTOR_GAP = 6
local ACTION_WIDTH = 112
local ACTION_HEIGHT = 30

local RESTRICTED_CONTENT_SOURCES = {
    PvP = {
        ["Icy Veins"] = true,
        Murlok = true,
    },
}

local NORMAL_BACKGROUND = { 0.05, 0.07, 0.10, 0.98 }
local NORMAL_BORDER = { 0.38, 0.45, 0.50, 1 }
local SELECTED_BACKGROUND = { 0.16, 0.12, 0.035, 1 }
local SELECTED_BORDER = { 1, 0.72, 0.08, 1 }

local function SetButtonAppearance(button, selected)
    local background = selected and SELECTED_BACKGROUND or NORMAL_BACKGROUND
    local border = selected and SELECTED_BORDER or NORMAL_BORDER

    button:SetBackdropColor(unpack(background))
    button:SetBackdropBorderColor(unpack(border))
    button.label:SetTextColor(selected and 1 or 0.9, selected and 0.8 or 0.9, selected and 0.25 or 0.9)
end

local function CreateTextButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button.label:SetJustifyH("CENTER")

    button:SetScript("OnEnter", function(self)
        if not self.selected then
            self:SetBackdropBorderColor(0.7, 0.8, 0.85, 1)
            self:SetBackdropColor(0.08, 0.11, 0.15, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        SetButtonAppearance(self, self.selected)
    end)

    SetButtonAppearance(button, false)
    return button
end

local function CreateSectionTitle(parent, text, yOffset)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", PANEL_PADDING, yOffset)
    title:SetText(text)
    title:SetTextColor(0.35, 0.8, 1)
    return title
end

local function CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.75, 0.6, 0.15, 0.4)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, yOffset)
    return divider
end

local function SelectOption(group, value)
    TalentDex.selection[group] = value
    TalentDex:SetBuildSelection(group, value)

    for optionValue, button in pairs(TalentDex.optionButtons[group]) do
        button.selected = optionValue == value
        SetButtonAppearance(button, button.selected)
    end

    if group == "source" then
        TalentDex:UpdateContentAvailability(value)
    elseif group == "content" then
        TalentDex:UpdateConditionalOptions(value)
    end

    TalentDex:UpdateImportButtonState()
end

local function CreateOptionRow(parent, group, options, yOffset)
    TalentDex.optionButtons[group] = {}

    for index, option in ipairs(options) do
        local button = CreateTextButton(parent, option, SELECTOR_WIDTH, SELECTOR_HEIGHT)
        local xOffset = PANEL_PADDING + (index - 1) * (SELECTOR_WIDTH + SELECTOR_GAP)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        button:SetScript("OnClick", function()
            SelectOption(group, option)
        end)
        TalentDex.optionButtons[group][option] = button
    end
end

local function CreateConditionalButtons(parent, definition)
    local buttons = {}
    local buttonGap = 6
    local availableWidth = 314
    local buttonWidth = math.floor((availableWidth - buttonGap * (#definition.options - 1)) / #definition.options)
    local totalWidth = buttonWidth * #definition.options + buttonGap * (#definition.options - 1)
    local xOffset = math.floor((360 - totalWidth) / 2)

    for index, option in ipairs(definition.options) do
        local button = CreateTextButton(parent, option, buttonWidth, SELECTOR_HEIGHT)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset + (index - 1) * (buttonWidth + buttonGap), -48)
        button:SetScript("OnClick", function()
            SelectOption(definition.key, option)
        end)
        buttons[option] = button
    end

    return buttons
end

local function LayoutActions(self, showConditional)
    local titleOffset = showConditional and -430 or -312
    local buttonOffset = showConditional and -456 or -338

    self.actionDivider:SetShown(showConditional)
    self.actionTitle:ClearAllPoints()
    self.actionTitle:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PANEL_PADDING, titleOffset)

    for _, button in ipairs(self.actionButtons) do
        local _, _, _, xOffset = button:GetPoint()
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOffset, buttonOffset)
    end
end

function TalentDex:CreateControls(frame)
    if frame.controlsCreated then
        return
    end
    frame.controlsCreated = true

    self.selection = {
        source = self.buildSelection.source,
        content = self.buildSelection.content,
        variant = self.buildSelection.variant,
        mode = self.buildSelection.mode,
    }
    self.optionButtons = {}

    CreateSectionTitle(frame, "SOURCE", -76)
    CreateOptionRow(frame, "source", { "Wowhead", "Icy Veins", "Archon", "Murlok" }, -100)
    CreateDivider(frame, -170)

    CreateSectionTitle(frame, "CONTENT", -194)
    CreateOptionRow(frame, "content", { "Mythic+", "Raid", "Delve", "PvP" }, -218)
    CreateDivider(frame, -288)

    self.conditionalSection = CreateFrame("Frame", nil, frame)
    self.conditionalSection:SetSize(360, 118)
    self.conditionalSection:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -288)
    self.conditionalTitle = CreateSectionTitle(self.conditionalSection, "", -24)
    self.conditionalButtons = {}
    self.conditionalSection:Hide()

    self.actionDivider = CreateDivider(frame, -406)
    self.actionTitle = CreateSectionTitle(frame, "ACTION", -312)
    self.actionButtons = {}

    local importButton = CreateTextButton(frame, "Import Talents", ACTION_WIDTH, ACTION_HEIGHT)
    importButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 61, -338)
    importButton:SetScript("OnClick", function()
        TalentDex:OnActionRequested("import-talents")
    end)
    self.importButton = importButton

    local rotationButton = CreateTextButton(frame, "View Rotation", ACTION_WIDTH, ACTION_HEIGHT)
    rotationButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 187, -338)
    rotationButton:SetScript("OnClick", function()
        TalentDex:OnActionRequested("view-rotation")
    end)
    self.actionButtons = { importButton, rotationButton }

    SelectOption("source", self.selection.source)
    SelectOption("content", self.selection.content)
end

function TalentDex:UpdateImportButtonState()
    if not self.importButton then
        return
    end

    local build = self:GetSelectedBuild()
    local enabled = build and type(build.talentImportString) == "string" and build.talentImportString ~= ""
    self.importButton:SetEnabled(enabled)
    self.importButton:SetAlpha(enabled and 1 or 0.45)
end

function TalentDex:UpdateContentAvailability(source)
    if not self.optionButtons or not self.optionButtons.content then
        return
    end

    for content, button in pairs(self.optionButtons.content) do
        local allowedSources = RESTRICTED_CONTENT_SOURCES[content]
        button:SetShown(not allowedSources or allowedSources[source])
    end

    local selectedContentButton = self.optionButtons.content[self.selection.content]
    if not selectedContentButton or not selectedContentButton:IsShown() then
        SelectOption("content", "Mythic+")
        return
    end

    self:UpdateConditionalOptions(self.selection.content)
end

function TalentDex:OnPlayerContextUpdated()
    if self.frame and self.frame.controlsCreated then
        self:UpdateConditionalOptions(self.selection.content)
    end
    self:UpdateImportButtonState()
end

function TalentDex:OnBuildDataUpdated()
    if self.frame and self.frame.controlsCreated then
        self:UpdateContentAvailability(self.selection.source)
    end
    self:UpdateImportButtonState()
end

function TalentDex:UpdateConditionalOptions(content)
    local definition = self:GetConditionalOptions()
    if not definition then
        self.conditionalSection:Hide()
        LayoutActions(self, false)
        return
    end

    for _, buttons in pairs(self.conditionalButtons) do
        for _, button in pairs(buttons) do
            button:Hide()
        end
    end

    local cacheKey = definition.key .. "\031" .. table.concat(definition.options, "\031")
    local buttons = self.conditionalButtons[cacheKey]
    if not buttons then
        buttons = CreateConditionalButtons(self.conditionalSection, definition)
        self.conditionalButtons[cacheKey] = buttons
    end

    self.optionButtons[definition.key] = buttons
    if not buttons[self.selection[definition.key]] then
        self.selection[definition.key] = definition.default
    end
    self.conditionalTitle:SetText(definition.title)
    self.conditionalSection:Show()

    for _, button in pairs(buttons) do
        button:Show()
    end
    SelectOption(definition.key, self.selection[definition.key])
    LayoutActions(self, true)
end

-- Actions currently record intent only; their actual content is a later phase.
function TalentDex:OnActionRequested(action)
    if action == "import-talents" then
        self:ImportSelectedBuild()
        return
    end

    self.lastRequestedAction = {
        action = action,
        build = self:GetSelectedBuild(),
    }
end
