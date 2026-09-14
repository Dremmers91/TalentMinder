local addonName, TalentMinder = ...

TalentMinder.name = addonName
TalentMinder.events = CreateFrame("Frame")

TalentMinder.events:RegisterEvent("PLAYER_LOGIN")
TalentMinder.events:RegisterEvent("ADDON_LOADED")
TalentMinder.events:RegisterEvent("PLAYER_REGEN_ENABLED")
TalentMinder.events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
TalentMinder.events:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
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

    if loadedAddon == "Blizzard_PlayerSpells" then
        TalentMinder:TryAttachToTalentWindow()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and TalentMinder.pendingAttachment then
        TalentMinder:TryAttachToTalentWindow()
    end
end)
