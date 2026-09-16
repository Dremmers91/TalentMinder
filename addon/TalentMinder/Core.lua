local addonName, TalentMinder = ...

TalentMinder.name = addonName
TalentMinder.events = CreateFrame("Frame")
TalentMinder.theme = {
    gold = { 1.00, 0.78, 0.18 },
    text = { 0.92, 0.86, 0.72 },
    panel = { 0.055, 0.035, 0.020, 0.97 },
    inset = { 0.075, 0.045, 0.022, 0.98 },
    selected = { 0.20, 0.125, 0.025, 1 },
    border = { 0.42, 0.27, 0.08, 1 },
}

TalentMinder.events:RegisterEvent("PLAYER_LOGIN")
TalentMinder.events:RegisterEvent("ADDON_LOADED")
TalentMinder.events:RegisterEvent("PLAYER_REGEN_ENABLED")
TalentMinder.events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
TalentMinder.events:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
TalentMinder.events:RegisterEvent("TRAIT_CONFIG_UPDATED")
TalentMinder.events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "PLAYER_LOGIN" then
        TalentMinder:InitializeSavedSettings()
        TalentMinder:RefreshPlayerContext()
        TalentMinder:TryAttachToTalentWindow()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if loadedAddon == "player" then
            TalentMinder:RefreshPlayerContext()
        end
        return
    end

    if event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        TalentMinder:RefreshPlayerContext()
        return
    end

    if event == "TRAIT_CONFIG_UPDATED" then
        if TalentMinder.OnActiveHeroTalentUpdated then
            TalentMinder:OnActiveHeroTalentUpdated()
        end
        return
    end

    if loadedAddon == "Blizzard_PlayerSpells" then
        TalentMinder:TryAttachToTalentWindow()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and TalentMinder.pendingAttachment then
        TalentMinder:TryAttachToTalentWindow()
    end
end)
