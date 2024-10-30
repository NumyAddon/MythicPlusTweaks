local _, MPT = ...;
--- @type MPT_Main
local Main = MPT.Main;
--- @type MPT_Util
local Util = MPT.Util;

--- @class MPT_ShowOwnRatingOnLFGTooltip: AceModule,AceHook-3.0
local Module = Main:NewModule('ShowOwnRatingOnLFGTooltip', 'AceHook-3.0');

-- there is currently no in-game way to get the ChallengeModeMapId from the ActivityID, so we have to resort to a hardcoded map
Module.ActivityIdToChallengeMapIdMap = {
    [180] = 169, -- Iron Docks
    [183] = 166, -- Grimrail Depot
    [184] = 168, -- The Everbloom
    [459] = 197, -- Eye of Azshara
    [460] = 198, -- Darkheart Thicket
    [461] = 200, -- Halls of Valor
    [462] = 206, -- Neltharion's Lair
    [463] = 199, -- Black Rook Hold
    [464] = 207, -- Vault of the Wardens
    [465] = 208, -- Maw of Souls
    [466] = 210, -- Court of Stars
    [467] = 209, -- The Arcway
    [471] = 227, -- Return to Karazhan: Lower
    [473] = 234, -- Return to Karazhan: Upper
    [476] = 233, -- Cathedral of Eternal Night
    [486] = 239, -- Seat of the Triumvirate
    [502] = 244, -- Atal'Dazar
    [504] = 250, -- Temple of Sethraliss
    [507] = 251, -- The Underrot
    [510] = 247, -- The MOTHERLODE!!
    [514] = 249, -- Kings' Rest
    [518] = 245, -- Freehold
    [522] = 252, -- Shrine of the Storm
    [526] = 246, -- Tol Dagor
    [530] = 248, -- Waycrest Manor
    [534] = 353, -- Siege of Boralus
    [659] = 353, -- Siege of Boralus
    [661] = 249, -- Kings' Rest
    [679] = 369, -- Operation: Mechagon - Junkyard
    [683] = 370, -- Operation: Mechagon - Workshop
    [691] = 379, -- Plaguefall
    [695] = 377, -- De Other Side
    [699] = 378, -- Halls of Atonement
    [703] = 375, -- Mists of Tirna Scithe
    [705] = 380, -- Sanguine Depths
    [709] = 381, -- Spires of Ascension
    [713] = 376, -- The Necrotic Wake
    [717] = 382, -- Theater of Pain
    [1016] = 391, -- Tazavesh: Streets of Wonder
    [1017] = 392, -- Tazavesh: So'leah's Gambit
    [1160] = 402, -- Algeth'ar Academy
    [1164] = 405, -- Brackenhide Hollow
    [1168] = 406, -- Halls of Infusion
    [1172] = 404, -- Neltharus
    [1176] = 399, -- Ruby Life Pools
    [1180] = 401, -- The Azure Vault
    [1184] = 400, -- The Nokhud Offensive
    [1188] = 403, -- Uldaman: Legacy of Tyr
    [1192] = 2, -- Temple of the Jade Serpent
    [1193] = 165, -- Shadowmoon Burial Grounds
    [1195] = 438, -- The Vortex Pinnacle
    [1247] = 463, -- Dawn of the Infinite: Galakrond's Fall
    [1248] = 464, -- Dawn of the Infinite: Murozond's Rise
    [1274] = 456, -- Throne of the Tides
    [1281] = 499, -- Priory of the Sacred Flame
    [1282] = 504, -- Darkflame Cleft
    [1283] = 500, -- The Rookery
    [1284] = 503, -- Ara-Kara, City of Echoes
    [1285] = 505, -- The Dawnbreaker
    [1286] = 506, -- Cinderbrew Meadery
    [1287] = 501, -- The Stonevault
    [1288] = 502, -- City of Threads
    [1290] = 507, -- Grim Batol
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

--- @param tooltip GameTooltip
--- @param resultId number
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
    local affixInfo = Util.AFFIX_SPECIFIC_SCORES and Util:GetAffixInfoByMapId(mapId) or nil;

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
