local _, TalentMinder = ...

function TalentMinder:BuildLoadoutName(build)
    local parts = { "TM", build.content or "Build" }
    local variant = build.variantName or build.variant or build.mode
    if variant then
        table.insert(parts, self:GetShortVariantName(variant))
    end
    return string.sub(table.concat(parts, "_"), 1, 36)
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
