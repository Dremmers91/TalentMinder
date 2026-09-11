local addonName, TalentDex = ...

TalentDex.name = addonName
TalentDex.events = CreateFrame("Frame")

TalentDex.events:RegisterEvent("PLAYER_LOGIN")
TalentDex.events:RegisterEvent("ADDON_LOADED")
TalentDex.events:RegisterEvent("PLAYER_REGEN_ENABLED")
TalentDex.events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
TalentDex.events:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
TalentDex.events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "PLAYER_LOGIN" then
        TalentDex:InitializeSavedSettings()
        TalentDex:RefreshPlayerContext()
        TalentDex:TryAttachToTalentWindow()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if loadedAddon == "player" then
            TalentDex:RefreshPlayerContext()
        end
        return
    end

    if event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        TalentDex:RefreshPlayerContext()
        return
    end

    if loadedAddon == "Blizzard_PlayerSpells" then
        TalentDex:TryAttachToTalentWindow()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and TalentDex.pendingAttachment then
        TalentDex:TryAttachToTalentWindow()
    end
end)
