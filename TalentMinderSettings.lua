local _, TalentMinder = ...

local VALID_OPTIONS = {
    source = {
        Wowhead = true,
        ["Icy Veins"] = true,
        Archon = true,
        Murlok = true,
    },
    content = {
        ["Mythic+"] = true,
        Raid = true,
        Delve = true,
        PvP = true,
    },
}

local DEFAULT_SELECTION = {
    source = "Wowhead",
    content = "Mythic+",
    variant = "Single Target",
    mode = "Solo",
}

local function GetValidValue(savedValue, key)
    if type(savedValue) == "string" and VALID_OPTIONS[key][savedValue] then
        return savedValue
    end
    return DEFAULT_SELECTION[key]
end

local function GetOptionalValue(savedValue, key)
    if type(savedValue) == "string" and savedValue ~= "" then
        return savedValue
    end
    return DEFAULT_SELECTION[key]
end

function TalentMinder:InitializeSavedSettings()
    if type(TalentMinderDB) ~= "table" then
        TalentMinderDB = {}
    end

    self.buildSelection = {
        source = GetValidValue(TalentMinderDB.source, "source"),
        content = GetValidValue(TalentMinderDB.content, "content"),
        variant = GetOptionalValue(TalentMinderDB.variant, "variant"),
        mode = GetOptionalValue(TalentMinderDB.mode, "mode"),
    }
    self.settingsInitialized = true
    self:SaveBuildSelection()
end

function TalentMinder:SaveBuildSelection()
    if not self.settingsInitialized then
        return
    end

    TalentMinderDB.source = GetValidValue(self.buildSelection.source, "source")
    TalentMinderDB.content = GetValidValue(self.buildSelection.content, "content")
    TalentMinderDB.variant = GetOptionalValue(self.buildSelection.variant, "variant")
    TalentMinderDB.mode = GetOptionalValue(self.buildSelection.mode, "mode")
end
