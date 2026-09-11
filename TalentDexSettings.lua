local _, TalentDex = ...

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

function TalentDex:InitializeSavedSettings()
    if type(TalentDexDB) ~= "table" then
        TalentDexDB = {}
    end

    self.buildSelection = {
        source = GetValidValue(TalentDexDB.source, "source"),
        content = GetValidValue(TalentDexDB.content, "content"),
        variant = GetOptionalValue(TalentDexDB.variant, "variant"),
        mode = GetOptionalValue(TalentDexDB.mode, "mode"),
    }
    self.settingsInitialized = true
    self:SaveBuildSelection()
end

function TalentDex:SaveBuildSelection()
    if not self.settingsInitialized then
        return
    end

    TalentDexDB.source = GetValidValue(self.buildSelection.source, "source")
    TalentDexDB.content = GetValidValue(self.buildSelection.content, "content")
    TalentDexDB.variant = GetOptionalValue(self.buildSelection.variant, "variant")
    TalentDexDB.mode = GetOptionalValue(self.buildSelection.mode, "mode")
end
