local _, MPT = ...;
local Main = MPT.Main;
--- @type MPT_Util
local Util = MPT.Util;

local Module = Main:NewModule('DungeonScoreTooltipFix');

function Module:OnInitialize()
    local DUNGEON_SCORE_LINK_INDEX_START = 11;
    local DUNGEON_SCORE_LINK_ITERATE = 3;

    self.fixedDisplayDungeonScoreLink = function(link)
        if ( not ItemRefTooltip:IsShown() ) then
            ItemRefTooltip:SetOwner(UIParent, 'ANCHOR_PRESERVE');
        end

        local splits  = StringSplitIntoTable(':', link);

        --Bad Link, Return.
        if(not splits) then
            return;
        end
        local dungeonScore = tonumber(splits[2]);
        local playerName = splits[4];
        local playerClass = splits[5];
        local playerItemLevel = tonumber(splits[6]);
        local playerLevel = tonumber(splits[7]);
        local className, classFileName = GetClassInfo(playerClass);
        local classColor = C_ClassColor.GetClassColor(classFileName);
        local runsThisSeason = tonumber(splits[8]);
        local bestSeasonScore = tonumber(splits[9]);
        local bestSeasonNumber = tonumber(splits[10]);

        --Bad Link..
        if(not playerName or not playerClass or not playerItemLevel or not playerLevel) then
            return;
        end

        --Bad Link..
        if(not className or not classFileName or not classColor) then
            return;
        end

        GameTooltip_SetTitle(ItemRefTooltip, classColor:WrapTextInColorCode(playerName));
        GameTooltip_AddColoredLine(ItemRefTooltip, DUNGEON_SCORE_LINK_LEVEL_CLASS_FORMAT_STRING:format(playerLevel, className), HIGHLIGHT_FONT_COLOR);
        GameTooltip_AddNormalLine(ItemRefTooltip, DUNGEON_SCORE_LINK_ITEM_LEVEL:format(playerItemLevel));

        local color = C_ChallengeMode.GetDungeonScoreRarityColor(dungeonScore) or HIGHLIGHT_FONT_COLOR;
        GameTooltip_AddNormalLine(ItemRefTooltip, DUNGEON_SCORE_LINK_RATING:format(color:WrapTextInColorCode(dungeonScore)));
        GameTooltip_AddNormalLine(ItemRefTooltip, DUNGEON_SCORE_LINK_RUNS_SEASON:format(runsThisSeason));

        if(bestSeasonScore ~= 0) then
            local bestSeasonColor = C_ChallengeMode.GetDungeonScoreRarityColor(bestSeasonScore) or HIGHLIGHT_FONT_COLOR;
            GameTooltip_AddNormalLine(ItemRefTooltip, DUNGEON_SCORE_LINK_PREVIOUS_HIGH:format(bestSeasonColor:WrapTextInColorCode(bestSeasonScore), bestSeasonNumber));
        end
        GameTooltip_AddBlankLineToTooltip(ItemRefTooltip);

        local sortTable = { };
        for i = DUNGEON_SCORE_LINK_INDEX_START, (#splits), DUNGEON_SCORE_LINK_ITERATE do
            local mapChallengeModeID = tonumber(splits[i]);
            local completedInTime = tonumber(splits[i + 1]) == 1; -- patched
            local level = tonumber(splits[i + 2]);

            local mapName = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID);

            --If any of the maps don't exist.. this is a bad link
            if(not mapName) then
                return;
            end

            table.insert(sortTable, { mapName = mapName, completedInTime = completedInTime, level = level });
        end

        -- Sort Alphabetically.
        table.sort(sortTable, function(a, b) strcmputf8i(a.mapName, b.mapName); end);

        for i = 1, #sortTable do
            local textColor = sortTable[i].completedInTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR;
            GameTooltip_AddColoredDoubleLine(ItemRefTooltip, DUNGEON_SCORE_LINK_TEXT1:format(sortTable[i].mapName), (sortTable[i].level > 0 and  DUNGEON_SCORE_LINK_TEXT2:format(sortTable[i].level) or DUNGEON_SCORE_LINK_NO_SCORE), NORMAL_FONT_COLOR, textColor);
        end
        ItemRefTooltip:SetPadding(0, 0);
        ShowUIPanel(ItemRefTooltip);
    end
    self.oldDisplayDungeonScoreLink = DisplayDungeonScoreLink;
end

function Module:OnEnable()
    DisplayDungeonScoreLink = self.fixedDisplayDungeonScoreLink;
end

function Module:OnDisable()
    DisplayDungeonScoreLink = self.oldDisplayDungeonScoreLink;
end

function Module:GetName()
    return 'DungeonScore Tooltip fix';
end

function Module:GetDescription()
    return 'Fixes the Mythic+ Tooltip, to show if a run was completed in time or not.';
end

function Module:GetOptions(defaultOptionsTable)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Show Example',
        desc = 'Show an example of how the tooltip looks.',
        func = function()
            DisplayDungeonScoreLink('dungeonScore:1337:Player-1234-012345AB:PlayerName:1:278:60:500:1337:3:381:1:15:382:0:16:392:1:17:391:0:18:380:1:19:375:0:20:376:1:21:377:0:22:378:1:23:379:0:24');
        end,
        order = 10,
    };
    return defaultOptionsTable;
end
