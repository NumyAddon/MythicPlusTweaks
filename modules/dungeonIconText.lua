local _, MPT = ...;
local Main = MPT.Main;

local Module = Main:NewModule('DungeonIconText', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnInitialize()
    self.font = CreateFont('');
    self.font:CopyFontObject(SystemFont_Huge1_Outline);
    self.minFontSize = 10;
end

function Module:OnEnable()
    if IsAddOnLoaded('Blizzard_ChallengesUI') then
        self:SetupHook();
    else
        self:RegisterEvent('ADDON_LOADED');
    end
end

function Module:OnDisable()
    self:UnhookAll();
    if IsAddOnLoaded('Blizzard_ChallengesUI') then
        ChallengesFrame_Update(ChallengesFrame);
        for i = 1, #ChallengesFrame.DungeonIcons do
            if ChallengesFrame.DungeonIcons[i].CurrentLevel then
                ChallengesFrame.DungeonIcons[i].CurrentLevel:Hide();
            end
        end
    end
end

function Module:GetName()
    return 'Dungeon Icon Text';
end

function Module:GetDescription()
    return 'Changes the text on the dungeon icons, to show "{level} - {score}" on top (level is grey if out of time). And {affix level} - {affix score} on bottom for the current week\'s affix.';
end

function Module:GetOptions(defaultOptionsTable)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Open Mythic+ UI',
        desc = 'Open the Mythic+ UI and the icons are on the bottom of the UI.',
        func = function()
            PVEFrame_ToggleFrame('ChallengesFrame');
        end,
        order = 10,
    };

    return defaultOptionsTable;
end

function Module:ADDON_LOADED(event, addon)
    if addon == 'Blizzard_ChallengesUI' then
        self:SetupHook();
        self:UnregisterEvent('ADDON_LOADED');
    end
end

function Module:SetupHook()
    self:SecureHook('ChallengesFrame_Update', function(frame)
        Module:AddScoresToAllIcons(frame);
    end);
    if ChallengesFrame:IsShown() then
        ChallengesFrame_Update(ChallengesFrame);
    end
end

function Module:AddScoresToAllIcons(challengesFrame)
    local mapInfo = {}
    for _, scoreInfo in pairs(C_ChallengeMode.GetMapScoreInfo()) do
        mapInfo[scoreInfo.mapChallengeModeID] = {
            level = scoreInfo.level,
            score = scoreInfo.dungeonScore,
            completedInTime = scoreInfo.completedInTime,
        };
    end

    for i = 1, #challengesFrame.DungeonIcons do
        Module:AddScoresToIcon(challengesFrame.DungeonIcons[i], mapInfo);
    end
end

function Module:AddScoresToIcon(icon, mapInfo)
    local mapId = icon.mapID;

    local inTimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapId);

    local bestLevel = 0;
    local bestLevelInTime = false
    if (inTimeInfo and overtimeInfo) then
        bestLevelInTime = inTimeInfo.dungeonScore >= overtimeInfo.dungeonScore;
        bestLevel = bestLevelInTime and inTimeInfo.level or overtimeInfo.level;
    elseif (inTimeInfo or overtimeInfo) then
        bestLevelInTime = inTimeInfo ~= nil
        bestLevel = inTimeInfo and inTimeInfo.level or overtimeInfo.level;
    end
    local _, overAllScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapId);

    local bestLevelColor = bestLevelInTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR;
    local overAllScoreColor = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(overAllScore or 0) or HIGHLIGHT_FONT_COLOR;

    if bestLevel and overAllScore then
        icon.HighestLevel:SetText(bestLevelColor:WrapTextInColorCode(bestLevel) .. ' - ' .. overAllScoreColor:WrapTextInColorCode(overAllScore));
        icon.HighestLevel:SetTextColor(1, 1, 1);
        icon.HighestLevel:Show();
        icon.HighestLevel:SetWidth(icon:GetWidth() - 1);
        self:AutoFitText(icon.HighestLevel);
    end

    local currentMapInfo = mapInfo[mapId];
    if (not currentMapInfo.score or not currentMapInfo.level or currentMapInfo.score == 0) then return end

    local currentAffixLevelColor = currentMapInfo.completedInTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR;
    local currentAffixScoreColor = C_ChallengeMode.GetSpecificDungeonScoreRarityColor(currentMapInfo.score) or HIGHLIGHT_FONT_COLOR;

    if (not icon.CurrentLevel) then
        self:InitCurrentLevelText(icon);
    end
    icon.CurrentLevel:SetText(currentAffixLevelColor:WrapTextInColorCode(currentMapInfo.level) .. ' - ' .. currentAffixScoreColor:WrapTextInColorCode(currentMapInfo.score));
    icon.CurrentLevel:Show();
    icon.CurrentLevel:SetWidth(icon:GetWidth() - 1);
    self:AutoFitText(icon.CurrentLevel);
end

function Module:InitCurrentLevelText(icon)
    icon.CurrentLevel = icon:CreateFontString(nil, 'BORDER', 'SystemFont_Huge1_Outline');
    icon.CurrentLevel:SetPoint('BOTTOM', 0, 4);
    icon.CurrentLevel:SetTextColor(1, 1, 1);
    icon.CurrentLevel:SetShadowOffset(1, -1);
    icon.CurrentLevel:SetShadowColor(0, 0, 0);
end

function Module:AutoFitText(text)
    text:SetFontObject(self.font);

    while (true) do
        local difference = text:GetUnboundedStringWidth() - text:GetWidth();
        if (math.abs(difference) < 5) then break; end

        local fontFile, fontSize, fontFlags = self.font:GetFont();
        if (difference < 0 or fontSize == self.minFontSize) then break; end

        if (difference > 0) then
            self.font:SetFont(fontFile, fontSize - 1, fontFlags);
        end
    end
end
