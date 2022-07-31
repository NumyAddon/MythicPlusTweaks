local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('FixLeadOverallScoreOnLFGTooltip', 'AceHook-3.0');

function Module:OnEnable()
    self:SecureHook('LFGListUtil_SetSearchEntryTooltip', function(tooltip, resultId) Module:OnTooltipShow(tooltip, resultId); end);
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetDescription()
    return 'Fixes a blizzard bug that prevents the leader\'s overall m+ score showing in the LFG tooltip.';
end

function Module:GetName()
    return 'Fix Lead Overall Score On LFG Tooltip';
end

function Module:OnTooltipShow(tooltip, resultId)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId);
    local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID, nil, searchResultInfo.isWarMode);
    if not activityInfo.isMythicPlusActivity then return; end

    local linesLeft, linesRight = Util:ExtractTooltipLines(tooltip);

    local leaderNameLine = string.sub(LFG_LIST_TOOLTIP_LEADER, 1, string.find(LFG_LIST_TOOLTIP_LEADER, ':'));
    for i, line in ipairs(linesLeft) do
        if string.find(line.text, leaderNameLine) then
            if (searchResultInfo.leaderOverallDungeonScore) then
                local color = C_ChallengeMode.GetDungeonScoreRarityColor(searchResultInfo.leaderOverallDungeonScore);
                if(not color) then
                    color = HIGHLIGHT_FONT_COLOR;
                end
                table.insert(linesLeft, i + 1,
                    {
                        text = DUNGEON_SCORE_LEADER:format(color:WrapTextInColorCode(searchResultInfo.leaderOverallDungeonScore)),
                    }
                );
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

    tooltip:Show();
end
