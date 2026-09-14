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
    content = "Mythic+",
}
TalentMinder.buildData = MOCK_BUILDS

local EMPTY_BUILD = {
    talentImportString = "",
    rotationPlaceholder = "No TalentMinder build is available for this selection.",
}

local CONTENT_ORDER = { "Mythic+", "Raid", "Delve", "PvP" }
local SOURCE_ORDER = { "Wowhead", "Icy Veins", "Archon", "Murlok" }
local PVP_SOURCES = { ["Icy Veins"] = true, Murlok = true }

local function GetSpecBuilds(buildData, context)
    if type(buildData) ~= "table" or not context.class or not context.spec then
        return nil
    end

    local classBuilds = buildData[context.class]
    return classBuilds and classBuilds[context.spec] or nil
end

local function FindContentBuild(buildData, context, selection)
    local specBuilds = GetSpecBuilds(buildData, context)
    local sourceBuilds = specBuilds and specBuilds[selection.source]
    return (sourceBuilds and sourceBuilds[selection.content]) or EMPTY_BUILD
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

local function ResolveBuild(contentBuild, selection)
    if contentBuild.variants then
        local options = GetOptionList(contentBuild.variants, contentBuild.variantOrder)
        local selectionKey = selection.content == "PvP" and "mode" or "variant"
        return contentBuild.variants[selection[selectionKey]] or contentBuild.variants[options[1]] or EMPTY_BUILD, #options > 1 and selectionKey or nil
    end
    if contentBuild.modes then
        local options = GetOptionList(contentBuild.modes, contentBuild.modeOrder)
        return contentBuild.modes[selection.mode] or contentBuild.modes[options[1]] or EMPTY_BUILD, #options > 1 and "mode" or nil
    end
    return contentBuild, nil
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

function TalentMinder:GetAvailableContent(source)
    local specBuilds = GetSpecBuilds(self.buildData, self.playerContext)
    local sourceBuilds = specBuilds and source and specBuilds[source]
    local availableContent = {}
    if not sourceBuilds then
        return availableContent
    end

    for _, content in ipairs(CONTENT_ORDER) do
        if sourceBuilds[content] and (content ~= "PvP" or PVP_SOURCES[source]) then
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
        local options = GetOptionList(contentBuild.variants, contentBuild.variantOrder)
        if #options > 1 then
            local isPvP = self.buildSelection.content == "PvP"
            return {
                key = isPvP and "mode" or "variant",
                title = isPvP and "MODE" or "VARIANT",
                options = options,
                default = options[1],
            }
        end
    elseif contentBuild.modes then
        local options = GetOptionList(contentBuild.modes, contentBuild.modeOrder)
        if #options > 1 then
            return { key = "mode", title = "MODE", options = options, default = options[1] }
        end
    end
    return nil
end

function TalentMinder:GetSelectedBuild()
    local context = self.playerContext
    local selection = self.buildSelection
    local contentBuild = FindContentBuild(self.buildData, context, selection)
    local build, conditionalKey = ResolveBuild(contentBuild, selection)
    if not build then
        return nil
    end

    return {
        spec = context.spec,
        source = selection.source,
        content = selection.content,
        variant = conditionalKey == "variant" and selection.variant or nil,
        mode = conditionalKey == "mode" and selection.mode or nil,
        talentImportString = build.talentImportString,
        rotationPlaceholder = build.rotationPlaceholder,
    }
end
