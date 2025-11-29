--- @class MPT_NS
local MPT = select(2, ...);
local Main = MPT.Main;
local Util = MPT.Util;

--- @class MPT_ShowOwnRatingOnLFGTooltip: NumyConfig_Module,AceHook-3.0
local Module = Main:NewModule('ShowOwnRatingOnLFGTooltip', 'AceHook-3.0');

local missingActivityIds = {};

function Module:OnEnable()
    self:SecureHook('LFGListUtil_SetSearchEntryTooltip', function(tooltip, resultId) Module:OnTooltipShow(tooltip, resultId); end);
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

--- @param tooltip GameTooltip
--- @param resultId number
function Module:OnTooltipShow(tooltip, resultId)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId);
    local activityID = searchResultInfo.activityIDs[1];
    local mapID, fullName, isMythicPlusActivity = Util:GetMapInfoByLfgActivityID(activityID)
    if not isMythicPlusActivity then return; end
    if not mapID then
        if not missingActivityIds[activityID] then
            missingActivityIds[activityID] = true;
            Main:Print(('LFG Module: no mapId found for activityID %d (%s) please report this on discord or github'):format(activityID, fullName));
        end

        return;
    end
    local overallInfo = Util:GetOverallInfoByMapId(mapID);
    local affixInfo = Util.AFFIX_SPECIFIC_SCORES and Util:GetAffixInfoByMapId(mapID) or nil;

    local linesLeft, linesRight = Util:ExtractTooltipLines(tooltip);

    for i, line in ipairs(linesLeft) do
        if string.find(line.text, MEMBERS_COLON) then
            i = i - 1; -- insert 2 lines before the "Members:" line
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

    Util:ReplaceTooltipLines(tooltip, linesLeft, linesRight);
end
