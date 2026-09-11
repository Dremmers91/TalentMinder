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
                    variants = {
                        ["Single Target"] = {
                            talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMDamZGAAAGAwMz0sssMDAEbAAAmZG2sMjZWmxYmZmZYhZMzMDAwAAAMAzMgZAwwMzA",
                            rotationPlaceholder = "Mock Arcane single-target priority.",
                        },
                        Cleave = {
                            talentImportString = "C4DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMDamZGAAAGAwMz0sssMDAEbAAAmZG2sMjZWmxYmZmZYhZMzMDAwAAAMAzMgZAwwMzA",
                            rotationPlaceholder = "Mock Arcane cleave priority.",
                        },
                    },
                },
                PvP = {
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

local function FindBuild(buildData, context, selection)
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
    if contentBuild.variants then
        return contentBuild.variants[selection.variant] or fallbackBuild
    end
    if contentBuild.modes then
        return contentBuild.modes[selection.mode] or fallbackBuild
    end
    return contentBuild
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
end

function TalentDex:GetSelectedBuild()
    local context = self.playerContext
    local selection = self.buildSelection
    local build = FindBuild(self.buildData, context, selection)
    if not build then
        return nil
    end

    return {
        spec = context.spec,
        source = selection.source,
        content = selection.content,
        variant = selection.content == "Raid" and selection.variant or nil,
        mode = selection.content == "PvP" and selection.mode or nil,
        talentImportString = build.talentImportString,
        rotationPlaceholder = build.rotationPlaceholder,
    }
end
