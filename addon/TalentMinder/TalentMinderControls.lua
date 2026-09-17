local _, TalentMinder = ...

local PANEL_PADDING = 23
local SELECTOR_WIDTH = 74
local SELECTOR_HEIGHT = 44
local SELECTOR_GAP = 6
local ACTION_WIDTH = 112
local ACTION_HEIGHT = 28

local NORMAL_BACKGROUND = { 0.075, 0.045, 0.022, 0.98 }
local SELECTED_BACKGROUND = { 0.20, 0.125, 0.025, 1 }
local SELECTED_BORDER = { 1, 0.78, 0.18, 1 }

TalentMinder.accentTitles = {}
TalentMinder.accentDividers = {}
TalentMinder.accentButtons = {}

local function GetAccentColor()
    return unpack(TalentMinder.theme.gold)
end

local function SetButtonAppearance(button, selected)
    local background = selected and SELECTED_BACKGROUND or NORMAL_BACKGROUND
    local border = selected and SELECTED_BORDER

    button:SetBackdropColor(unpack(background))
    if border then
        button:SetBackdropBorderColor(unpack(border))
    else
        local red, green, blue = GetAccentColor()
        button:SetBackdropBorderColor(TalentMinder.theme.border[1], TalentMinder.theme.border[2], TalentMinder.theme.border[3], 1)
    end
    if selected then
        button.label:SetTextColor(unpack(TalentMinder.theme.gold))
    else
        button.label:SetTextColor(unpack(TalentMinder.theme.text))
    end
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
    table.insert(TalentMinder.accentButtons, button)

    button:SetScript("OnEnter", function(self)
        if not self.selected then
            local red, green, blue = GetAccentColor()
            self:SetBackdropBorderColor(red, green, blue, 1)
            self:SetBackdropColor(0.13, 0.08, 0.035, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        SetButtonAppearance(self, self.selected)
    end)

    SetButtonAppearance(button, false)
    return button
end

local function CreateSectionTitle(parent, text, yOffset)
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, yOffset)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    header:SetBackdropColor(unpack(TalentMinder.theme.inset))
    header:SetBackdropBorderColor(unpack(TalentMinder.theme.border))
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", 8, 0)
    title:SetText(text)
    local red, green, blue = GetAccentColor()
    title:SetTextColor(red, green, blue)
    table.insert(TalentMinder.accentTitles, title)
    function header:SetText(value)
        title:SetText(value)
    end
    return header
end

local function CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    local red, green, blue = GetAccentColor()
    divider:SetColorTexture(red, green, blue, 0.28)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, yOffset)
    table.insert(TalentMinder.accentDividers, divider)
    return divider
end

local function SelectOption(group, value)
    TalentMinder.selection[group] = value
    TalentMinder:SetBuildSelection(group, value)

    local buttons = TalentMinder.optionButtons[group]
    if buttons then
        for optionValue, button in pairs(buttons) do
            button.selected = optionValue == value
            SetButtonAppearance(button, button.selected)
        end
    end

    local dropdown = TalentMinder.conditionalDropdown
    if dropdown and dropdown.selectionKey == group then
        UIDropDownMenu_SetSelectedValue(dropdown, value)
        UIDropDownMenu_SetText(dropdown, (dropdown.optionLabels and dropdown.optionLabels[value]) or value)
    end

    if group == "source" then
        TalentMinder:UpdateContentAvailability(value)
    elseif group == "content" then
        TalentMinder:UpdateConditionalOptions(value)
    end

    TalentMinder:UpdateImportButtonState()
end

local function ContainsOption(options, value)
    for _, option in ipairs(options) do
        if option == value then
            return true
        end
    end
    return false
end

local function CreateOptionRow(parent, group, options, yOffset)
    TalentMinder.optionButtons[group] = {}
    TalentMinder.optionOrder = TalentMinder.optionOrder or {}
    TalentMinder.optionOrder[group] = options

    for index, option in ipairs(options) do
        local button = CreateTextButton(parent, option, SELECTOR_WIDTH, SELECTOR_HEIGHT)
        button:SetScript("OnClick", function()
            SelectOption(group, option)
        end)
        TalentMinder.optionButtons[group][option] = button
    end
end

local function LayoutOptionRow(parent, group, yOffset)
    local buttons = TalentMinder.optionButtons[group]
    local shown = {}
    for _, option in ipairs(TalentMinder.optionOrder[group]) do
        local button = buttons[option]
        if button:IsShown() then
            table.insert(shown, button)
        end
    end

    local count = #shown
    local columns = math.min(count, 4)
    local availableWidth = 314
    local width = columns > 0 and math.floor((availableWidth - SELECTOR_GAP * (columns - 1)) / columns) or SELECTOR_WIDTH
    for index, button in ipairs(shown) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        button:ClearAllPoints()
        button:SetSize(width, SELECTOR_HEIGHT)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", PANEL_PADDING + column * (width + SELECTOR_GAP), yOffset - row * (SELECTOR_HEIGHT + SELECTOR_GAP))
    end
end

local function CreateConditionalDropdown(parent)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 9, -34)
    UIDropDownMenu_SetWidth(dropdown, 286)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, option in ipairs(self.options or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = (self.optionLabels and self.optionLabels[option]) or option
            info.value = option
            info.checked = TalentMinder.selection[self.selectionKey] == option
            info.func = function()
                SelectOption(self.selectionKey, option)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return dropdown
end

local function LayoutActions(self, showConditional)
    local titleOffset = showConditional and -398 or -312
    local buttonOffset = showConditional and -424 or -338

    self.actionDivider:SetShown(showConditional)
    self.actionDivider:ClearAllPoints()
    self.actionDivider:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 18, titleOffset + 24)
    self.actionDivider:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -18, titleOffset + 24)
    self.actionTitle:ClearAllPoints()
    self.actionTitle:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 18, titleOffset)
    self.actionTitle:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -18, titleOffset)

    for _, button in ipairs(self.actionButtons) do
        button:ClearAllPoints()
        button:SetPoint("TOP", self.frame, "TOP", 0, buttonOffset)
    end

    self.statsDivider:ClearAllPoints()
    self.statsDivider:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 18, buttonOffset - ACTION_HEIGHT - 16)
    self.statsDivider:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -18, buttonOffset - ACTION_HEIGHT - 16)

    self.statPrioritySection:ClearAllPoints()
    self.statPrioritySection:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PANEL_PADDING, buttonOffset - ACTION_HEIGHT - 28)
    self.statPrioritySection:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PANEL_PADDING, buttonOffset - ACTION_HEIGHT - 28)
    local hasStats, statsHeight = self:UpdateStatPriorityControls()
    self.statsDivider:SetShown(hasStats)
    local contentHeight = math.abs(buttonOffset) + ACTION_HEIGHT + (hasStats and (statsHeight + 42) or 30)
    self.frame:SetHeight(contentHeight)
end

function TalentMinder:CreateControls(frame)
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
    CreateOptionRow(frame, "source", { "Wowhead", "Icy Veins" }, -100)
    CreateDivider(frame, -170)

    CreateSectionTitle(frame, "CONTENT", -194)
    CreateOptionRow(frame, "content", { "Delves", "Raid", "M+", "PVP" }, -218)
    CreateDivider(frame, -288)

    self.conditionalSection = CreateFrame("Frame", nil, frame)
    self.conditionalSection:SetSize(360, 86)
    self.conditionalSection:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -288)
    self.conditionalTitle = CreateSectionTitle(self.conditionalSection, "", -24)
    self.conditionalDropdown = CreateConditionalDropdown(self.conditionalSection)
    self.conditionalSection:Hide()

    self.actionDivider = CreateDivider(frame, -406)
    self.actionTitle = CreateSectionTitle(frame, "ACTION", -312)
    self.actionButtons = {}

    local importButton = CreateTextButton(frame, "Import Build", ACTION_WIDTH, ACTION_HEIGHT)
    importButton:SetPoint("TOP", frame, "TOP", 0, -338)
    importButton:SetScript("OnClick", function()
        TalentMinder:OnActionRequested("import-talents")
    end)
    self.importButton = importButton

    self.actionButtons = { importButton }

    self.statsDivider = CreateDivider(frame, -382)
    self:CreateStatPriorityControls(frame)

    self:UpdateSourceAvailability()
    self:UpdateImportButtonState()
end

function TalentMinder:UpdateImportButtonState()
    if not self.importButton then
        return
    end

    local build = self:GetSelectedBuild()
    local enabled = build and type(build.talentImportString) == "string" and build.talentImportString ~= ""
    self.importButton:SetEnabled(enabled)
    self.importButton:SetAlpha(enabled and 1 or 0.45)
end

function TalentMinder:UpdateContentAvailability(source)
    if not self.optionButtons or not self.optionButtons.content then
        return
    end

    local availableContent = self:GetAvailableContent(source)
    local availableLookup = {}
    for _, content in ipairs(availableContent) do
        availableLookup[content] = true
    end
    for content, button in pairs(self.optionButtons.content) do
        button:SetShown(availableLookup[content] == true)
    end
    LayoutOptionRow(self.frame, "content", -218)

    local selectedContentButton = self.optionButtons.content[self.selection.content]
    if not selectedContentButton or not selectedContentButton:IsShown() then
        if #availableContent > 0 then
            SelectOption("content", availableContent[1])
        else
            self:UpdateConditionalOptions(nil)
        end
        return
    end

    self:UpdateConditionalOptions(self.selection.content)
end

function TalentMinder:UpdateSourceAvailability()
    if not self.optionButtons or not self.optionButtons.source then
        return
    end

    local availableSources = self:GetAvailableSources()
    local availableLookup = {}
    for _, source in ipairs(availableSources) do
        availableLookup[source] = true
    end
    for source, button in pairs(self.optionButtons.source) do
        button:SetShown(availableLookup[source] == true)
    end
    LayoutOptionRow(self.frame, "source", -100)

    local selectedSourceButton = self.optionButtons.source[self.selection.source]
    if not selectedSourceButton or not selectedSourceButton:IsShown() then
        if #availableSources > 0 then
            SelectOption("source", availableSources[1])
        else
            self:UpdateContentAvailability(nil)
        end
        return
    end

    SelectOption("source", self.selection.source)
end

function TalentMinder:OnPlayerContextUpdated()
    self:UpdateAccentColor()
    self:UpdatePlayerContextText()
    if self.frame and self.frame.controlsCreated then
        self:UpdateSourceAvailability()
    end
    self:UpdateImportButtonState()
end

function TalentMinder:UpdateAccentColor()
    local red, green, blue = GetAccentColor()
    for _, title in ipairs(self.accentTitles) do
        title:SetTextColor(red, green, blue)
    end
    for _, divider in ipairs(self.accentDividers) do
        divider:SetColorTexture(red, green, blue, 0.4)
    end
    for _, button in ipairs(self.accentButtons) do
        SetButtonAppearance(button, button.selected)
    end
end

function TalentMinder:OnBuildDataUpdated()
    if self.frame and self.frame.controlsCreated then
        self:UpdateSourceAvailability()
    end
    self:UpdateImportButtonState()
end

function TalentMinder:OnStatPriorityDataUpdated()
    self:RefreshStatPriorityLayout()
end

function TalentMinder:OnActiveHeroTalentUpdated()
    self:RefreshStatPriorityLayout()
end

function TalentMinder:UpdateConditionalOptions(content)
    local definition = self:GetConditionalOptions()
    if not definition then
        self.conditionalSection:Hide()
        LayoutActions(self, false)
        return
    end

    local dropdown = self.conditionalDropdown
    dropdown.selectionKey = definition.key
    dropdown.options = definition.options
    dropdown.optionLabels = definition.labels
    if not ContainsOption(definition.options, self.selection[definition.key]) then
        self.selection[definition.key] = definition.default
    end
    self.conditionalTitle:SetText(definition.title)
    UIDropDownMenu_SetSelectedValue(dropdown, self.selection[definition.key])
    UIDropDownMenu_SetText(dropdown, definition.labels[self.selection[definition.key]] or self.selection[definition.key])
    self.conditionalSection:Show()
    SelectOption(definition.key, self.selection[definition.key])
    LayoutActions(self, true)
end

-- Actions currently record intent only; their actual content is a later phase.
function TalentMinder:OnActionRequested(action)
    if action == "import-talents" then
        self:ImportSelectedBuild()
        return
    end

    self.lastRequestedAction = {
        action = action,
        build = self:GetSelectedBuild(),
    }
end
