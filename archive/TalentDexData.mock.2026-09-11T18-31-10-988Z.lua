local _, TalentDex = ...

local GetCurrentSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
local GetSpecializationDetails = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo

-- Local mock data only. An external updater can replace this table later
-- without changing any TalentDex UI code.
local MOCK_BUILDS = {
    MAGE = {
        [62] = {
            Wowhead = {
                ["Mythic+"] = {
                    talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA",
                    rotationPlaceholder = "Mock Arcane Mythic+ priority.",
                },
                Delve = {
                    talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA",
                    rotationPlaceholder = "Mock Arcane Delve priority.",
                },
                Raid = {
                    talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMDamZGAAAGAwMz0sssMDAEbAAAmZG2sMjZWmxYmZmZYhZMzMDAwAAAMAzMgZAwwMzA",
                    rotationPlaceholder = "Mock Arcane Raid priority.",
                },
            },
            Murlok = {
                PvP = {
                    modeOrder = { "Solo", "2v2", "3v3", "Blitz", "RBG" },
                    modes = {
                        Solo = {
                            talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAAMzMzMzMzMzMzMmxM",
                            rotationPlaceholder = "Mock Arcane Solo priority.",
                        },
                        ["2v2"] = {
                            talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAAMzMzMzMzMzMmZmxM",
                            rotationPlaceholder = "Mock Arcane 2v2 priority.",
                        },
                        ["3v3"] = {
                            talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAAMzMzMzMzMzMmxmZM",
                            rotationPlaceholder = "Mock Arcane 3v3 priority.",
                        },
                        Blitz = {
                            talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAAMzMzMzMzMmZmZmxM",
                            rotationPlaceholder = "Mock Arcane Blitz priority.",
                        },
                        RBG = {
                            talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAAMzMzMzMzMzMmxMzM",
                            rotationPlaceholder = "Mock Arcane RBG priority.",
                        },
                    },
                },
            },
        },
    },
    default = {
        default = {
            default = {
                default = {
                    talentImportString = "TalentDex-mock-import-string",
                    rotationPlaceholder = "Mock rotation data is not available for this selection yet.",
                },
            },
        },
    },
}

TalentDex.playerContext = {}
TalentDex.buildSelection = {
    source = "Wowhead",
    content = "Mythic+",
}
TalentDex.buildData = MOCK_BUILDS

local function FindContentBuild(buildData, context, selection)
    local fallbackBuild = buildData.default.default.default.default
    local classBuilds = context.class and buildData[context.class] or buildData.default
    local specBuilds = context.spec and classBuilds[context.spec] or classBuilds.default
    if not specBuilds then
        return fallbackBuild
    end

    local sourceBuilds = specBuilds[selection.source] or specBuilds.default
    if not sourceBuilds then
        return fallbackBuild
    end

    local contentBuild = sourceBuilds[selection.content] or sourceBuilds.default

    if not contentBuild then
        return fallbackBuild
    end
    return contentBuild
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
        return contentBuild.variants[selection.variant] or contentBuild.variants[options[1]], "variant"
    end
    if contentBuild.modes then
        local options = GetOptionList(contentBuild.modes, contentBuild.modeOrder)
        return contentBuild.modes[selection.mode] or contentBuild.modes[options[1]], "mode"
    end
    return contentBuild, nil
end

function TalentDex:RefreshPlayerContext()
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

function TalentDex:SetBuildSelection(key, value)
    self.buildSelection[key] = value
    self:SaveBuildSelection()
end

function TalentDex:SetBuildData(buildData)
    self.buildData = buildData or MOCK_BUILDS
    if self.OnBuildDataUpdated then
        self:OnBuildDataUpdated()
    end
end

function TalentDex:GetConditionalOptions()
    local contentBuild = FindContentBuild(self.buildData, self.playerContext, self.buildSelection)
    if contentBuild.variants then
        local options = GetOptionList(contentBuild.variants, contentBuild.variantOrder)
        if #options > 1 then
            return { key = "variant", title = "VARIANT", options = options, default = options[1] }
        end
    elseif contentBuild.modes then
        local options = GetOptionList(contentBuild.modes, contentBuild.modeOrder)
        if #options > 1 then
            return { key = "mode", title = "MODE", options = options, default = options[1] }
        end
    end
    return nil
end

function TalentDex:GetSelectedBuild()
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
