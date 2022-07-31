local _, MPT = ...
--- @class Util
local Util = {};
MPT.Util = Util;

function Util:ExtractTooltipLines(tooltip)
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

function Util:GetOverallInfoByMapId(mapId)
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
                scoreColor = C_ChallengeMode.GetSpecificDungeonScoreRarityColor(affixInfo.score or 0),
            };
        end
    end
    return nil;
end
