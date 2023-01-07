local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('ShowOwnRatingOnLFGTooltip', 'AceHook-3.0');

-- there is currently no in-game way to get the ChallengeModeMapId from the ActivityID, so we have to resort to a hardcoded map
Module.ActivityIdToChallengeMapIdMap = {
    [1193] = 165, -- Shadowmoon Burial Grounds
    [1192] = 2, -- Temple of the Jade Serpent
    [1188] = 403, -- Uldaman: Legacy of Tyr
    [1184] = 400, -- The Nokhud Offensive
    [1180] = 401, -- The Azure Vault
    [1176] = 399, -- Ruby Life Pools
    [1172] = 404, -- Neltharus
    [1168] = 406, -- Halls of Infusion
    [1164] = 405, -- Brackenhide Hollow
    [1160] = 402, -- Algeth'ar Academy
    [1017] = 392, -- Tazavesh: So'leah's Gambit
    [1016] = 391, -- Tazavesh: Streets of Wonder
    [717] = 382, -- Theater of Pain
    [713] = 376, -- The Necrotic Wake
    [709] = 381, -- Spires of Ascension
    [705] = 380, -- Sanguine Depths
    [703] = 375, -- Mists of Tirna Scithe
    [699] = 378, -- Halls of Atonement
    [695] = 377, -- De Other Side
    [691] = 379, -- Plaguefall
    [683] = 370, -- Operation: Mechagon - Workshop
    [679] = 369, -- Operation: Mechagon - Junkyard
    [661] = 249, -- Kings' Rest
    [659] = 353, -- Siege of Boralus
    [534] = 353, -- Siege of Boralus
    [530] = 248, -- Waycrest Manor
    [526] = 246, -- Tol Dagor
    [522] = 252, -- Shrine of the Storm
    [518] = 245, -- Freehold
    [514] = 249, -- Kings' Rest
    [510] = 247, -- The MOTHERLODE!!
    [507] = 251, -- The Underrot
    [504] = 250, -- Temple of Sethraliss
    [502] = 244, -- Atal'Dazar
    [486] = 239, -- Seat of the Triumvirate
    [476] = 233, -- Cathedral of Eternal Night
    [473] = 234, -- Return to Karazhan: Upper
    [471] = 227, -- Return to Karazhan: Lower
    [467] = 209, -- The Arcway
    [466] = 210, -- Court of Stars
    [465] = 208, -- Maw of Souls
    [464] = 207, -- Vault of the Wardens
    [463] = 199, -- Black Rook Hold
    [462] = 206, -- Neltharion's Lair
    [461] = 200, -- Halls of Valor
    [460] = 198, -- Darkheart Thicket
    [459] = 197, -- Eye of Azshara
    [183] = 166, -- Grimrail Depot
    [180] = 169, -- Iron Docks
};
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

function Module:OnTooltipShow(tooltip, resultId)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId);
    local activityInfo = C_LFGList.GetActivityInfoTable(searchResultInfo.activityID, nil, searchResultInfo.isWarMode);
    if not activityInfo.isMythicPlusActivity then return; end

    local mapId = self.ActivityIdToChallengeMapIdMap[searchResultInfo.activityID];
    if not mapId then
        if not missingActivityIds[searchResultInfo.activityID] then
            missingActivityIds[searchResultInfo.activityID] = true;
            Main:Print('LFG Module: no mapId found for activityID', searchResultInfo.activityID, 'please report this on curse or github');
        end
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
