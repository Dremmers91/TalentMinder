local _, TalentMinder = ...

local SECONDARY_STATS = {
    ["critical strike"] = "Critical Strike",
    ["crit"] = "Critical Strike",
    ["haste"] = "Haste",
    ["mastery"] = "Mastery",
    ["versatility"] = "Versatility",
    ["vers"] = "Versatility",
}

local RANK_COLORS = {
    { 0.78, 0.22, 1.00 },
    { 0.00, 0.44, 0.87 },
    { 0.12, 1.00, 0.00 },
    { 1.00, 1.00, 1.00 },
}

local function Normalize(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:lower():gsub("[^%a%d]", "")
end

local function GetActiveHeroTalentName()
    if not C_ClassTalents or not C_ClassTalents.GetActiveHeroTalentSpec then
        return nil
    end
    local subTreeID = C_ClassTalents.GetActiveHeroTalentSpec()
    if not subTreeID or subTreeID == 0 or not C_Traits or not C_Traits.GetSubTreeInfo then
        return nil
    end

    local ok, info = pcall(C_Traits.GetSubTreeInfo, subTreeID)
    if (not ok or not info) and C_ClassTalents.GetActiveConfigID then
        local configID = C_ClassTalents.GetActiveConfigID()
        if configID then
            ok, info = pcall(C_Traits.GetSubTreeInfo, configID, subTreeID)
        end
    end
    return ok and info and info.name or nil
end

local function GetPriorityOptions(data)
    local options = {}
    if type(data) ~= "table" or type(data.priorities) ~= "table" then
        return options
    end
    for _, name in ipairs(data.priorityOrder or {}) do
        if type(name) == "string" and type(data.priorities[name]) == "table" then
            table.insert(options, name)
        end
    end
    if #options == 0 then
        for name, stats in pairs(data.priorities) do
            if type(name) == "string" and type(stats) == "table" then
                table.insert(options, name)
            end
        end
        table.sort(options)
    end
    return options
end

local function FindHeroPriority(options, activeHero)
    local hero = Normalize(activeHero)
    if hero == "" then
        return nil
    end
    for _, option in ipairs(options) do
        if Normalize(option):find(hero, 1, true) then
            return option
        end
    end
    return nil
end

function TalentMinder:GetResolvedStatPriority()
    local data = self:GetCurrentStatPriorityData()
    local options = GetPriorityOptions(data)
    if #options == 0 then
        return nil
    end

    local heroPriority = FindHeroPriority(options, GetActiveHeroTalentName())
    local priorityName = heroPriority
    if not priorityName then
        local context = self.playerContext or {}
        local saved = self:GetSavedStatPrioritySelection(context.class, context.spec)
        for _, option in ipairs(options) do
            if option == saved then
                priorityName = option
                break
            end
        end
        priorityName = priorityName or options[1]
    end

    local ranks = {}
    local rankCount = 0
    for _, rawStat in ipairs(data.priorities[priorityName]) do
        local stat = SECONDARY_STATS[Normalize(rawStat)]
        if stat and not ranks[stat] then
            rankCount = rankCount + 1
            ranks[stat] = rankCount
        end
    end
    if rankCount == 0 then
        return nil
    end

    return {
        name = priorityName,
        options = options,
        isHeroPriority = heroPriority ~= nil,
        ranks = ranks,
        rankCount = rankCount,
    }
end

local function CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetHeight(24)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    header:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
    header:SetBackdropBorderColor(0.42, 0.42, 0.42, 1)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("Stat Priority")
    title:SetTextColor(1, 0.78, 0.18)
    return header
end

function TalentMinder:CreateStatPriorityControls(parent)
    self.statPrioritySection = CreateFrame("Frame", nil, parent)
    self.statPrioritySection:SetWidth(314)
    self.statPriorityHeader = CreateHeader(self.statPrioritySection)
    self.statPriorityHeader:SetPoint("TOPLEFT")
    self.statPriorityHeader:SetPoint("TOPRIGHT")

    self.statPriorityDropdown = CreateFrame("DropdownButton", nil, self.statPrioritySection, "WowStyle1DropdownTemplate")
    self.statPriorityDropdown:SetHeight(24)
    self.statPriorityDropdown:SetPoint("TOPLEFT", self.statPriorityHeader, "BOTTOMLEFT", 0, -4)
    self.statPriorityDropdown:SetPoint("TOPRIGHT", self.statPriorityHeader, "BOTTOMRIGHT", 0, -4)
    self.statPriorityDropdown:Hide()

    self.statPriorityRows = {}
    for index = 1, 4 do
        local row = CreateFrame("Frame", nil, self.statPrioritySection)
        row:SetHeight(24)
        local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rank:SetPoint("LEFT", 5, 0)
        rank:SetWidth(25)
        rank:SetJustifyH("LEFT")
        row.rank = rank
        local stat = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        stat:SetPoint("LEFT", rank, "RIGHT", 0, 0)
        stat:SetPoint("RIGHT", -4, 0)
        stat:SetJustifyH("LEFT")
        row.stat = stat
        row:Hide()
        self.statPriorityRows[index] = row
    end
    self.statPrioritySection:Hide()
end

function TalentMinder:UpdateStatPriorityControls()
    if not self.statPrioritySection then
        return false, 0
    end
    local resolved = self:GetResolvedStatPriority()
    if not resolved then
        self.statPrioritySection:Hide()
        return false, 0
    end

    local showDropdown = not resolved.isHeroPriority and #resolved.options > 1
    if showDropdown then
        if self.statPriorityDropdown.SetDefaultText then
            self.statPriorityDropdown:SetDefaultText(resolved.name)
        end
        self.statPriorityDropdown:SetupMenu(function(_, rootDescription)
            for _, option in ipairs(resolved.options) do
                rootDescription:CreateRadio(option,
                    function() return option == resolved.name end,
                    function()
                        local context = TalentMinder.playerContext or {}
                        TalentMinder:SaveStatPrioritySelection(context.class, context.spec, option)
                        TalentMinder:RefreshStatPriorityLayout()
                    end,
                    option)
            end
        end)
        self.statPriorityDropdown:Show()
    else
        self.statPriorityDropdown:Hide()
    end

    local rows = 0
    for stat, rankIndex in pairs(resolved.ranks) do
        local row = self.statPriorityRows[rankIndex]
        if row then
            local color = RANK_COLORS[rankIndex] or RANK_COLORS[4]
            row.rank:SetText("#" .. rankIndex)
            row.rank:SetTextColor(color[1], color[2], color[3])
            row.stat:SetText(stat)
            row:ClearAllPoints()
            local yOffset = showDropdown and -54 or -28
            row:SetPoint("TOPLEFT", self.statPrioritySection, "TOPLEFT", 0, yOffset - (rankIndex - 1) * 24)
            row:SetPoint("TOPRIGHT", self.statPrioritySection, "TOPRIGHT", 0, yOffset - (rankIndex - 1) * 24)
            row:Show()
            rows = math.max(rows, rankIndex)
        end
    end
    for index = rows + 1, #self.statPriorityRows do
        self.statPriorityRows[index]:Hide()
    end
    self.statPrioritySection:Show()
    return true, 24 + (showDropdown and 30 or 0) + rows * 24
end

function TalentMinder:RefreshStatPriorityLayout()
    if self.frame and self.frame.controlsCreated then
        self:UpdateConditionalOptions(self.selection.content)
    end
end

local function AddTooltipRanks(tooltip)
    local resolved = TalentMinder:GetResolvedStatPriority()
    if not resolved or not tooltip or not tooltip.GetName then
        return
    end
    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return
    end
    for index = 2, tooltip:NumLines() do
        local line = _G[tooltipName .. "TextLeft" .. index]
        if line and line.GetText and line.SetText and line.GetFont then
            local text = line:GetText()
            local isReadable = text and pcall(string.len, text)
            if isReadable then
                for stat, rankIndex in pairs(resolved.ranks) do
                    if text:find(stat, 1, true) and not text:find("#%d") then
                        local color = RANK_COLORS[rankIndex] or RANK_COLORS[4]
                        local hex = string.format("%02x%02x%02x",
                            math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
                        line:SetText(text .. " |cff" .. hex .. "#" .. rankIndex .. "|r")
                        break
                    end
                end
            end
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddTooltipRanks)
end
