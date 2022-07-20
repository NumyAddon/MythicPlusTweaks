
local name, M = ...

local frame = CreateFrame('Frame')
frame:HookScript('OnEvent', function(self, event, ...) M[event](M, ...); end);
frame:RegisterEvent('ADDON_LOADED')

function M:FixDungeonScoreTooltip()
    local DUNGEON_SCORE_LINK_INDEX_START = 11;
    local DUNGEON_SCORE_LINK_ITERATE = 3;

    -- copy/pasted from Blizzard's source https://github.com/Gethe/wow-ui-source/blob/978a1677c7825f6ddbf6a3f276ed61e61c6c970a/Interface/FrameXML/ItemRef.lua#L593-L664
    -- patched with the suggestion from https://github.com/Stanzilla/WoWUIBugs/issues/242

    function DisplayDungeonScoreLink(link)

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

end

function M:ExtendDungeonRatingTooltips()
    hooksecurefunc(GameTooltip, 'Show', function(tooltip) M:OnTooltipShow(tooltip) end)
end

function M:OnTooltipShow(tooltip)
    if self.skipOnTooltipShow or self.disable then return end
    local owner = tooltip.GetOwner and tooltip:GetOwner() or nil
    if not owner then return end

    local parent = owner.GetParent and owner:GetParent() or nil
    if parent ~= ChallengesFrame or not owner.mapID then return end

    local mapId = owner.mapID
    local affixScores, _ = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapId);

    if(not affixScores or #affixScores == 0) then return end
    local linesLeft, linesRight = self:ExtractTooltipLines(tooltip)
    local higherScore, higherAffix = 0, nil
    for _, affixInfo in ipairs(affixScores) do
        if affixInfo.score > higherScore then
            higherScore = affixInfo.score
            higherAffix = affixInfo.name
        end
    end
    for _, affixInfo in ipairs(affixScores) do
        local affixName, score = affixInfo.name, affixInfo.score
        local color = C_ChallengeMode.GetSpecificDungeonScoreRarityColor(score)
        local multiplier = affixName == higherAffix and '|cFFFFFFFF (x1.5)|r' or '|cFFFFFFFF (x0.5)|r'
        for i, line in ipairs(linesLeft) do
            if string.find(line.text, affixName) then
                table.insert(linesLeft, i+3, {text='Affix rating: ' .. color:WrapTextInColorCode(score) .. multiplier})
                table.insert(linesRight, i+3, {text=''})
                break
            end
        end
    end
    if(#linesLeft > 2) then
        table.insert(linesLeft, {text='|cFFEE6161ID|r ' .. mapId})
        table.insert(linesRight, {text=''})
    end

    tooltip:ClearLines()
    for i = 1, max(#linesLeft, #linesRight) do
        local left = linesLeft[i] or ''
        local right = linesRight[i] or ''

        tooltip:AddDoubleLine(left.text, right.text, left.r, left.g, left.b, right.r, right.g, right.b)
    end

    self.skipOnTooltipShow = true
    tooltip:Show()
    self.skipOnTooltipShow = nil
end

function M:ExtractTooltipLines(tooltip)
    local linesLeft, linesRight = {}, {}
    for i = 1, 15 do
        local lineLeft = _G[tooltip:GetName() .. 'TextLeft' .. i]
        local lineRight = _G[tooltip:GetName() .. 'TextRight' .. i]

        local left, right
        if lineLeft then left = lineLeft:GetText() end
        if lineRight then right = lineRight:GetText() end

        if not left and not right then break end
        local leftR, leftG, leftB, _ = lineLeft:GetTextColor()
        local rightR, rightG, rightB, _ = lineRight:GetTextColor()
        table.insert(linesLeft, {text=left, r=leftR, g=leftG, b=leftB})
        table.insert(linesRight, {text=right, r=rightR, g=rightG, b=rightB})
    end
    return linesLeft, linesRight
end

function M:ADDON_LOADED(addonName)
    if addonName == name then
        self:Init()
    end
end

function M:Init()
    self:FixDungeonScoreTooltip()
    self:ExtendDungeonRatingTooltips()
end
