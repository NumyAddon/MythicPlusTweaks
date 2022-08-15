local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('ShowOwnRatingOnLFGTooltip', 'AceHook-3.0');

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

function Module:OnTooltipShow(tooltip, resultId)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId);
    local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID, nil, searchResultInfo.isWarMode);
    if not activityInfo.isMythicPlusActivity then return; end

    local mapId = self.ChallengeModeMapId_to_activityId_map[searchResultInfo.activityID];
    if not mapId then
        Main:Print('LFG Module: no mapId found for activityID', searchResultInfo.activityID, 'please report this on curse or github');
        return;
    end
    local overallInfo = Util:GetOverallInfoByMapId(mapId);
    local affixInfo = Util:GetAffixInfoByMapId(mapId);

    local linesLeft, linesRight = Util:ExtractTooltipLines(tooltip);

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

    Util:ReplaceTooltipLines(tooltip, linesLeft, linesRight);
end
