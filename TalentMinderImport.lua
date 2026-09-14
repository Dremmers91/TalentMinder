local _, TalentMinder = ...

local RAID_VARIANT_LABELS = {
    ["Single Target"] = "ST",
    Cleave = "Cleave",
}

function TalentMinder:BuildLoadoutName(build)
    local parts = { "TD", build.source }

    if build.content == "Raid" then
        table.insert(parts, "Raid")
        if build.variant then
            table.insert(parts, RAID_VARIANT_LABELS[build.variant] or build.variant)
        end
    elseif build.content == "PvP" then
        table.insert(parts, build.mode or "PvP")
    else
        table.insert(parts, build.content)
    end

    return string.sub(table.concat(parts, " - "), 1, 36)
end

local function ShowMessage(message)
    UIErrorsFrame:AddMessage(message, 1, 0.2, 0.2)
end

function TalentMinder:ImportSelectedBuild()
    local build = self:GetSelectedBuild()
    if not build or type(build.talentImportString) ~= "string" or build.talentImportString == "" then
        ShowMessage("TalentMinder: No import string is available for this build.")
        return false
    end

    if InCombatLockdown() then
        ShowMessage("TalentMinder: Talent imports are unavailable during combat.")
        return false
    end

    local dialog = _G.ClassTalentLoadoutImportDialog
    if not dialog or not dialog.ShowDialog then
        ShowMessage("TalentMinder: Blizzard's import dialog is not available.")
        return false
    end

    dialog:ShowDialog()
    dialog.ImportControl:GetEditBox():SetText(build.talentImportString)
    dialog.NameControl:GetEditBox():SetText(self:BuildLoadoutName(build))
    dialog:UpdateAcceptButtonEnabledState()
    return true
end

function TalentMinder:CopySelectedBuild()
    local build = self:GetSelectedBuild()
    if not build or type(build.talentImportString) ~= "string" or build.talentImportString == "" then
        ShowMessage("TalentMinder: No build code is available to copy.")
        return false
    end

    if not CopyToClipboard then
        ShowMessage("TalentMinder: Clipboard support is unavailable.")
        return false
    end

    CopyToClipboard(build.talentImportString)
    DEFAULT_CHAT_FRAME:AddMessage("|cffF8C44FTalentMinder:|r Build code copied to the clipboard.")
    return true
end
