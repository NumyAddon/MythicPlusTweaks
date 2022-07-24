local _, MPT = ...;
local Main = MPT.Main;

local Module = Main:NewModule('ShowOwnRatingOnLFGTooltip', 'AceHook-3.0', 'AceEvent-3.0');

-- there is currently no in-game way to get the ChallengeModeMapId from the ActivityID, so we have to resort to a hardcoded map
Module.ChallengeModeMapId_to_activityId_map = {
    [703] = 375,  -- Mists of Tirna Scithe
    [713] = 376,  -- The Necrotic Wake
    [695] = 377,  -- De Other Side
    [699] = 378,  -- Halls of Atonement
    [691] = 379,  -- Plaguefall
    [705] = 380,  -- Sanguine Depths
    [709] = 381,  -- Spires of Ascension
    [717] = 382,  -- Theater of Pain
    [1017] = 392, -- Tazavesh Gambit (Mythic Keystone)
    [1016] = 391, -- Tazavesh Streets (Mythic Keystone)
    [683] = 370, -- Mechagon Workshop (Mythic Keystone)
    [679] = 369, -- Mechagon Junkyard (Mythic Keystone)
    [473] = 234, -- Upper Karazhan (Mythic Keystone)
    [471] = 227, -- Lower Karazhan (Mythic Keystone)
    [180] = 169, -- Iron Docks (Mythic Keystone)
    [183] = 166, -- Grimrail Depot (Mythic Keystone)
};

function Module:OnEnable()
    self:SecureHook(GameTooltip, 'Show', function(tooltip) Module:OnTooltipShow(tooltip); end);
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetDescription()
    return 'Adds your own M+ score info to LFG search result tooltips.';
end

function Module:GetName()
    return 'Show Own Rating On LFG Tooltip';
end

function Module:OnTooltipShow(tooltip)
    if self.skipOnTooltipShow then return; end
    local owner = tooltip.GetOwner and tooltip:GetOwner() or nil;
    if not owner then return; end

    local parent = owner.GetParent and owner:GetParent() or nil;
    if parent ~= LFGListSearchPanelScrollFrameScrollChild or not owner.resultID then return; end

    local searchResultInfo = C_LFGList.GetSearchResultInfo(owner.resultID);
    local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID, nil, searchResultInfo.isWarMode);
    if not activityInfo.isMythicPlusActivity then return; end

    local mapId = self.ChallengeModeMapId_to_activityId_map[searchResultInfo.activityID];
    if not mapId then
        Main:Print('LFG Module: no mapId found for activityID', searchResultInfo.activityID, 'please report this on curse or github');
        return;
    end
    local overallInfo = self:GetOverallInfoByMapId(mapId);
    local affixInfo = self:GetAffixScoreInfoByMapId(mapId);

    local linesLeft, linesRight = self:ExtractTooltipLines(tooltip);

    local createdAtLine = string.sub(LFG_LIST_TOOLTIP_AGE, 1, string.find(LFG_LIST_TOOLTIP_AGE, ':'));
    for i, line in ipairs(linesLeft) do
        if string.find(line.text, createdAtLine) then
            if (overallInfo and overallInfo.score > 0) then
                table.insert(linesLeft, i, {
                    text = 'Your Overall: |cffffffff'
                            .. overallInfo.scoreColor:WrapTextInColorCode(overallInfo.score)
                            .. ' (' .. overallInfo.levelColor:WrapTextInColorCode(overallInfo.level) .. ')|r',
                });
                table.insert(linesRight, i, { text = '' });
                if (affixInfo and affixInfo.score > 0) then
                    table.insert(linesLeft, i + 1, {
                        text = 'Your Affix score: |cffffffff'
                                .. affixInfo.scoreColor:WrapTextInColorCode(affixInfo.score)
                                .. ' (' .. affixInfo.levelColor:WrapTextInColorCode(affixInfo.level) .. ')|r',
                    });
                    table.insert(linesRight, i + 1, { text = '' });
                end
            else
                table.insert(linesLeft, i, { text = 'Your Overall: ' .. GRAY_FONT_COLOR:WrapTextInColorCode('-never completed-') });
                table.insert(linesRight, i, { text = '' });
            end
            break;
        end
    end

    tooltip:ClearLines()
    for i = 1, max(#linesLeft, #linesRight) do
        local left = linesLeft[i] or '';
        local right = linesRight[i] or '';

        tooltip:AddDoubleLine(left.text, right.text, left.r, left.g, left.b, right.r, right.g, right.b);
    end

    self.skipOnTooltipShow = true;
    tooltip:Show();
    self.skipOnTooltipShow = nil;
end

function Module:GetOverallInfoByMapId(mapId)
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
    overAllScore = overAllScore or 0

    local bestLevelColor = bestLevelInTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR;
    local overAllScoreColor = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(overAllScore) or HIGHLIGHT_FONT_COLOR;

    return {
        level = bestLevel,
        levelColor = bestLevelColor,
        score = overAllScore,
        scoreColor = overAllScoreColor,
    };
end

function Module:GetAffixScoreInfoByMapId(mapId)
    for _, scoreInfo in pairs(C_ChallengeMode.GetMapScoreInfo()) do
        if scoreInfo.mapChallengeModeID == mapId then
            return {
                level = scoreInfo.level,
                levelColor = scoreInfo.completedInTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR,
                score = scoreInfo.dungeonScore,
                scoreColor = C_ChallengeMode.GetSpecificDungeonScoreRarityColor(scoreInfo.dungeonScore or 0) or HIGHLIGHT_FONT_COLOR,
            };
        end
    end
    return nil;
end

function Module:ExtractTooltipLines(tooltip)
    local linesLeft, linesRight = {}, {};
    for i = 1, 15 do
        local lineLeft = _G[tooltip:GetName() .. 'TextLeft' .. i];
        local lineRight = _G[tooltip:GetName() .. 'TextRight' .. i];

        local left, right;
        if lineLeft then left = lineLeft:GetText(); end
        if lineRight then right = lineRight:GetText(); end

        if not left and not right then break; end
        local leftR, leftG, leftB, _ = lineLeft:GetTextColor();
        local rightR, rightG, rightB, _ = lineRight:GetTextColor();
        table.insert(linesLeft, {text=left, r=leftR, g=leftG, b=leftB});
        table.insert(linesRight, {text=right, r=rightR, g=rightG, b=rightB});
    end
    return linesLeft, linesRight;
end
