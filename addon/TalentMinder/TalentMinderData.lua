local _, TalentMinder = ...

local GetCurrentSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
local GetSpecializationDetails = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo

-- Live build data is loaded from TalentMinderGeneratedData.lua.
local MOCK_BUILDS = {
    default = {
        default = {
            default = {
                default = {
                    talentImportString = "",
                    rotationPlaceholder = "No approved TalentMinder build data is installed yet.",
                },
            },
        },
    },
}

TalentMinder.playerContext = {}
TalentMinder.buildSelection = {
    source = "Wowhead",
    content = "M+",
}
TalentMinder.buildData = MOCK_BUILDS
TalentMinder.statPriorityData = {}

local EMPTY_BUILD = {
    talentImportString = "",
    rotationPlaceholder = "No TalentMinder build is available for this selection.",
}

-- These are display labels. CONTENT_KEYS maps them to the canonical generated
-- data categories without changing the panel's labels.
local CONTENT_ORDER = { "Delves", "Raid", "M+", "PVP" }
local CONTENT_KEYS = {
    Delves = { "Delves" },
    Raid = { "Raid" },
    ["M+"] = { "Mythic+" },
    PVP = { "PvP" },
}
local SOURCE_ORDER = { "Wowhead", "Icy Veins" }
local PVP_SOURCES = { ["Icy Veins"] = true }

local function GetSpecBuilds(buildData, context)
    if type(buildData) ~= "table" or not context.class or not context.spec then
        return nil
    end

    local classBuilds = buildData[context.class]
    return classBuilds and classBuilds[context.spec] or nil
end

local function GetSourceBuilds(buildData, context, source)
    local specBuilds = GetSpecBuilds(buildData, context)
    if not specBuilds then
        return nil
    end

    return specBuilds[source]
end

local function FindContentBuild(buildData, context, selection)
    local sourceBuilds = GetSourceBuilds(buildData, context, selection.source)
    if not sourceBuilds then
        return EMPTY_BUILD
    end

    for _, key in ipairs(CONTENT_KEYS[selection.content] or { selection.content }) do
        if sourceBuilds[key] then
            return sourceBuilds[key]
        end
    end
    return EMPTY_BUILD
end

local function GetOptionList(options, preferredOrder)
    local list = {}
    if preferredOrder then
        for _, option in ipairs(preferredOrder) do
            if options[option] then
                table.insert(list, option)
            end
        end
    else
        for option in pairs(options) do
            table.insert(list, option)
        end
        table.sort(list)
    end
    return list
end

local function GetVariantOptions(contentBuild, source)
    return GetOptionList(contentBuild.variants, contentBuild.variantOrder)
end

function TalentMinder:GetShortVariantName(variant)
    local value = type(variant) == "string" and variant or ""
    local firstWord = value:match("^%s*([%a%d]+)")
    return firstWord or "Build"
end

local function GetVariantSuffix(variant)
    local suffix = type(variant) == "string" and variant:match(".*%s%-%s*(.+)$") or nil
    if not suffix then
        return nil
    end
    return suffix:match("^%s*([%a%d]+)")
end

function TalentMinder:GetCompactVariantLabels(options)
    local labels = {}
    local occurrences = {}
    for _, option in ipairs(options) do
        local shortName = self:GetShortVariantName(option)
        occurrences[shortName] = (occurrences[shortName] or 0) + 1
        labels[option] = shortName
    end

    local usedLabels = {}
    for index, option in ipairs(options) do
        local shortName = labels[option]
        if occurrences[shortName] > 1 then
            local suffix = GetVariantSuffix(option)
            labels[option] = suffix and (shortName .. " — " .. suffix) or (shortName .. " " .. index)
        end
        usedLabels[labels[option]] = (usedLabels[labels[option]] or 0) + 1
        if usedLabels[labels[option]] > 1 then
            labels[option] = labels[option] .. " " .. usedLabels[labels[option]]
        end
    end
    return labels
end

local function ResolveBuild(contentBuild, selection)
    if contentBuild.variants then
        local options = GetVariantOptions(contentBuild, selection.source)
        local selectionKey = selection.content == "PVP" and "mode" or "variant"
        local selectedOption
        for _, option in ipairs(options) do
            if option == selection[selectionKey] then
                selectedOption = option
                break
            end
        end
        local resolvedOption = selectedOption or options[1]
        return contentBuild.variants[resolvedOption] or EMPTY_BUILD, #options > 1 and selectionKey or nil, resolvedOption
    end
    if contentBuild.modes then
        local options = GetOptionList(contentBuild.modes, contentBuild.modeOrder)
        local resolvedOption = contentBuild.modes[selection.mode] and selection.mode or options[1]
        return contentBuild.modes[resolvedOption] or EMPTY_BUILD, #options > 1 and "mode" or nil, resolvedOption
    end
    return contentBuild, nil
end

local function HasImportString(build, source)
    if type(build) ~= "table" then
        return false
    end
    if type(build.talentImportString) == "string" and build.talentImportString ~= "" then
        return true
    end
    for groupName, group in pairs({ variants = build.variants, modes = build.modes }) do
        if type(group) == "table" then
            for option, nestedBuild in pairs(group) do
                if HasImportString(nestedBuild, source) then
                    return true
                end
            end
        end
    end
    return false
end

function TalentMinder:RefreshPlayerContext()
    local className, classFile, classID = UnitClass("player")
    local specIndex = GetCurrentSpecialization and GetCurrentSpecialization()
    local specID, specName
    if specIndex and GetSpecializationDetails then
        specID, specName = GetSpecializationDetails(specIndex)
    end

    self.playerContext = {
        class = classFile,
        className = className,
        classID = classID,
        spec = specID,
        specName = specName,
    }

    if self.OnPlayerContextUpdated then
        self:OnPlayerContextUpdated(self.playerContext)
    end
end

function TalentMinder:SetBuildSelection(key, value)
    self.buildSelection[key] = value
    self:SaveBuildSelection()
end

function TalentMinder:SetBuildData(buildData)
    self.buildData = buildData or MOCK_BUILDS
    if self.OnBuildDataUpdated then
        self:OnBuildDataUpdated()
    end
end

function TalentMinder:SetStatPriorityData(statPriorityData)
    self.statPriorityData = type(statPriorityData) == "table" and statPriorityData or {}
    if self.OnStatPriorityDataUpdated then
        self:OnStatPriorityDataUpdated()
    end
end

function TalentMinder:GetCurrentStatPriorityData()
    local context = self.playerContext or {}
    local byClass = context.class and self.statPriorityData[context.class]
    return byClass and byClass[context.spec] or nil
end

function TalentMinder:GetAvailableContent(source)
    local sourceBuilds = source and GetSourceBuilds(self.buildData, self.playerContext, source)
    local availableContent = {}
    if not sourceBuilds then
        return availableContent
    end

    for _, content in ipairs(CONTENT_ORDER) do
        local contentBuild = FindContentBuild(self.buildData, self.playerContext, {
            source = source,
            content = content,
        })
        if HasImportString(contentBuild, source) and (content ~= "PVP" or PVP_SOURCES[source]) then
            table.insert(availableContent, content)
        end
    end
    return availableContent
end

function TalentMinder:GetAvailableSources()
    local availableSources = {}
    for _, source in ipairs(SOURCE_ORDER) do
        if #self:GetAvailableContent(source) > 0 then
            table.insert(availableSources, source)
        end
    end
    return availableSources
end

function TalentMinder:GetConditionalOptions()
    local contentBuild = FindContentBuild(self.buildData, self.playerContext, self.buildSelection)
    if contentBuild.variants then
        local options = GetVariantOptions(contentBuild, self.buildSelection.source)
        if #options > 1 then
            local isPvP = self.buildSelection.content == "PVP"
            return {
                key = isPvP and "mode" or "variant",
                title = isPvP and "MODE" or "VARIANT",
                options = options,
                labels = self:GetCompactVariantLabels(options),
                default = options[1],
            }
        end
    elseif contentBuild.modes then
        local options = GetOptionList(contentBuild.modes, contentBuild.modeOrder)
        if #options > 1 then
            return { key = "mode", title = "MODE", options = options, labels = self:GetCompactVariantLabels(options), default = options[1] }
        end
    end
    return nil
end

function TalentMinder:GetSelectedBuild()
    local context = self.playerContext
    local selection = self.buildSelection
    local contentBuild = FindContentBuild(self.buildData, context, selection)
    local build, conditionalKey, resolvedVariant = ResolveBuild(contentBuild, selection)
    if not build then
        return nil
    end

    return {
        spec = context.spec,
        source = selection.source,
        content = selection.content,
        variant = conditionalKey == "variant" and selection.variant or nil,
        mode = conditionalKey == "mode" and selection.mode or nil,
        variantName = resolvedVariant,
        talentImportString = build.talentImportString,
        rotationPlaceholder = build.rotationPlaceholder,
    }
end
