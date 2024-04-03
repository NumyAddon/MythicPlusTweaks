local _, MPT = ...
--- @class MPT_Util
local Util = {};
MPT.Util = Util;

local scoreRarityColors = {
    colors = {ITEM_STANDARD_COLOR, ITEM_GOOD_COLOR, ITEM_SUPERIOR_COLOR, ITEM_EPIC_COLOR, ITEM_LEGENDARY_COLOR},
    overallScore = {0, 1000, 1500, 1800, 2200},
    level = {0, 4, 7, 10, 15},
    dungeonAffixScore = {0, 63, 94, 113, 138},
    dungeonOverallScore = {0, 125, 188, 225, 275},
};

--- @return ColorMixin
function Util:GetRarityColorOverallScore(score)
    return C_ChallengeMode.GetDungeonScoreRarityColor(score) or self:GetRarityColor(score, 'overallScore');
end

--- @return ColorMixin
function Util:GetRarityColorDungeonAffixScore(score)
    return C_ChallengeMode.GetSpecificDungeonScoreRarityColor(score) or self:GetRarityColor(score, 'dungeonAffixScore');
end

--- @return ColorMixin
function Util:GetRarityColorDungeonOverallScore(score)
    return C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score) or self:GetRarityColor(score, 'dungeonOverallScore');
end

--- @return ColorMixin
function Util:GetRarityColorLevel(level)
    return C_ChallengeMode.GetKeystoneLevelRarityColor(level) or self:GetRarityColor(level, 'level');
end

--- @return ColorMixin
function Util:GetRarityColor(score, scoreType)
    local colors = scoreRarityColors.colors;
    local scoreValues = scoreRarityColors[scoreType];
    assert(scoreValues, 'Invalid score type: ' .. scoreType);

    for i = #scoreValues, 1, -1 do
        if score >= scoreValues[i] then
            return colors[i];
        end
    end
    return colors[#colors];
end

function Util:ExtractTooltipLines(tooltip)
    local linesLeft, linesRight = {}, {};
    local i = 0;
    while i < 100 do -- hard cap to 100 lines, just in case :)
        i = i + 1;
        local lineLeft = _G[tooltip:GetName() .. 'TextLeft' .. i];
        local lineRight = _G[tooltip:GetName() .. 'TextRight' .. i];

        local left, leftWrap, right;
        if lineLeft then
            left = lineLeft:GetText();
            leftWrap = abs(lineLeft:GetWrappedWidth() - lineLeft:GetUnboundedStringWidth()) > 5;
        end
        if lineRight then right = lineRight:GetText(); end

        if not left and not right then break; end
        local leftR, leftG, leftB, _ = lineLeft:GetTextColor();
        local rightR, rightG, rightB, _ = lineRight:GetTextColor();
        table.insert(linesLeft, {text=left, r=leftR, g=leftG, b=leftB, wrap=leftWrap});
        table.insert(linesRight, {text=right, r=rightR, g=rightG, b=rightB});
    end
    return linesLeft, linesRight;
end

function Util:ReplaceTooltipLines(tooltip, linesLeft, linesRight)
    tooltip:ClearLines()
    for i = 1, max(#linesLeft, #linesRight) do
        local left = linesLeft[i];
        local right = linesRight[i];
        if not right or not right.text or string.len(right.text) == 0 then
            tooltip:AddLine(left.text, left.r, left.g, left.b, left.wrap);
        else
            tooltip:AddDoubleLine(left.text, right.text, left.r, left.g, left.b, right.r, right.g, right.b);
        end
    end

    tooltip:Show();
end

function Util:GetOverallInfoByMapId(mapId, includeAffixInfo)
    local inTimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapId);

    local bestLevel = 0;
    local bestLevelInTime = false
    if (inTimeInfo and overtimeInfo) then
        bestLevelInTime = inTimeInfo.dungeonScore >= overtimeInfo.dungeonScore;
        bestLevel = bestLevelInTime and inTimeInfo.level or overtimeInfo.level;
    elseif (inTimeInfo or overtimeInfo) then
        bestLevelInTime = inTimeInfo ~= nil
        bestLevel = (inTimeInfo and inTimeInfo.level) or (overtimeInfo and overtimeInfo.level) or 0;
    end
    local affixInfos, overAllScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapId);
    overAllScore = overAllScore or 0
    local currentAffixInfo;
    local secondaryAffixInfo;
    if affixInfos and includeAffixInfo then
        local localizedAffixName = self:GetLocalizedAffixName();
        for _, affixInfo in pairs(affixInfos) do
            if affixInfo then
                local isCurrentAffix = affixInfo.name == localizedAffixName;
                if isCurrentAffix then
                    currentAffixInfo = {
                       level = affixInfo.level,
                       levelColor = affixInfo.overTime and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR,
                       score = affixInfo.score,
                       scoreColor = self:GetRarityColorDungeonAffixScore(affixInfo.score or 0),
                   };
                else
                    secondaryAffixInfo = {
                       level = affixInfo.level,
                       levelColor = affixInfo.overTime and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR,
                       score = affixInfo.score,
                       scoreColor = self:GetRarityColorDungeonAffixScore(affixInfo.score or 0),
                   };
                end
            end
        end
    end
    if includeAffixInfo then
        currentAffixInfo = currentAffixInfo or {
            level = 0,
            levelColor = GRAY_FONT_COLOR,
            score = 0,
            scoreColor = GRAY_FONT_COLOR,
        };
        secondaryAffixInfo = secondaryAffixInfo or {
            level = 0,
            levelColor = GRAY_FONT_COLOR,
            score = 0,
            scoreColor = GRAY_FONT_COLOR,
        };
    end

    local bestLevelColor = bestLevelInTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR;
    local overAllScoreColor = self:GetRarityColorDungeonOverallScore(overAllScore) or HIGHLIGHT_FONT_COLOR;

    return {
        level = bestLevel,
        levelColor = bestLevelColor,
        inTimeLevel = inTimeInfo and inTimeInfo.level or 0,
        overTimeLevel = overtimeInfo and overtimeInfo.level or 0,
        score = overAllScore,
        scoreColor = overAllScoreColor,
        currentAffixInfo = currentAffixInfo,
        secondaryAffixInfo = secondaryAffixInfo,
    };
end

function Util:GetLocalizedAffixName()
    local affixIDs = C_MythicPlus.GetCurrentAffixes();
    if not affixIDs then return nil; end
    local tyrannicalOrFortifiedAffix = affixIDs[1];
    if not tyrannicalOrFortifiedAffix or not tyrannicalOrFortifiedAffix.id then return nil; end
    local name = C_ChallengeMode.GetAffixInfo(tyrannicalOrFortifiedAffix.id);
    return name;
end

function Util:GetAffixInfoByMapId(mapId)
    local localizedAffixName = self:GetLocalizedAffixName();
    local affixInfos = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapId);
    if not affixInfos then return nil; end
    for _, affixInfo in pairs(affixInfos) do
        if affixInfo and affixInfo.name == localizedAffixName then
            return {
                level = affixInfo.level,
                levelColor = affixInfo.overTime and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR,
                score = affixInfo.score,
                scoreColor = self:GetRarityColorDungeonAffixScore(affixInfo.score or 0),
            };
        end
    end
    return nil;
end
