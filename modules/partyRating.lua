--- @class MPT_NS
local MPT = select(2, ...);

local Main = MPT.Main;
local Util = MPT.Util;

--- @class MPT_PartyRating: MPT_Module,AceHook-3.0,AceEvent-3.0
local Module = Main:NewModule('PartyRating', 'AceHook-3.0', 'AceEvent-3.0');
local updateFrame = CreateFrame('Frame');

function Module:OnEnable()
    Util:OnChallengesUILoad(function() RunNextFrame(function() self:SetupUI(); end); end);

    self:RegisterEvent('GROUP_ROSTER_UPDATE');
    updateFrame:SetScript('OnUpdate', function(_, elapsed) self:OnUpdate(elapsed); end);
end

function Module:OnDisable()
    self:UnhookAll();
    self:UnregisterAllEvents();
    updateFrame:SetScript('OnUpdate', nil);
end

function Module:GetName()
    return 'Party Rating';
end

function Module:GetDescription()
    return 'Adds a list of party members to the Mythic+ UI, which show their mythic+ scores in a tooltip.';
end

local SORT_MODE_MAP_ID = 'mapID';
local SORT_MODE_SCORE = 'score';
local SORT_MODE_NAME = 'name';

--- @param configBuilder MPT_ConfigBuilder
--- @param db MPT_PartyRatingDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class MPT_PartyRatingDB
    local defaults = {
        sortMode = SORT_MODE_SCORE,
        showZeroScoreDungeons = true,
    };
    configBuilder:SetDefaults(defaults, true);
    configBuilder:MakeDropdown(
        'Sort mode',
        'sortMode',
        'Select how dungeon scores should be sorted',
        {
            { text = 'By Dungeon ID', value = SORT_MODE_MAP_ID },
            { text = 'By Score', value = SORT_MODE_SCORE },
            { text = 'By Dungeon name', value = SORT_MODE_NAME },
        }
    );
    configBuilder:MakeCheckbox(
        'Show dungeons without any rating',
        'showZeroScoreDungeons',
        'Always show all dungeons in the tooltip, even if no rating has been earned.'
    );
    configBuilder:MakeButton(
        'Open Mythic+ UI',
        function() Util:ToggleMythicPlusFrame(); end,
        'Open the Mythic+ UI and hover over a dungeon icon to see an example.'
    );
end

function Module:SetupUI()
    Util:RepositionWeeklyChestFrame();

    self:CreatePartyFrame();
end

function Module:CreatePartyFrame()
    if self.PartyFrame then return; end

    local textWidth = 110;
    local containerFrame = CreateFrame('Frame', nil, ChallengesFrame.WeeklyInfo.Child);
    containerFrame:Hide();
    containerFrame:SetSize(textWidth + 24, 110);
    if C_AddOns.IsAddOnLoaded('AngryKeystones') then
        containerFrame:SetPoint('LEFT', ChallengesFrame.WeeklyInfo.Child.WeeklyChest, 'RIGHT', 40, -50);
    else
        containerFrame:SetPoint('RIGHT', ChallengesFrame.WeeklyInfo.Child, 'RIGHT', -10, 10);
    end
    self.PartyFrame = containerFrame;

    local bg = containerFrame:CreateTexture(nil, 'BACKGROUND');
    bg:SetAllPoints();
    bg:SetAtlas('ChallengeMode-guild-background');
    bg:SetAlpha(0.4);

    local title = containerFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalMed2');
    title:SetText('Party Rating');
    title:SetPoint('TOP', 0, -7);

    local line = containerFrame:CreateTexture(nil, 'ARTWORK');
    line:SetSize(textWidth + 10, 9);
    line:SetAtlas('ChallengeMode-RankLineDivider', false);
    line:SetPoint('TOP', 0, -20);

    local entries = {}
    local anchor = line;
    for i = 1, 4 do
        --- @class MPT_PartyRatingEntry: Frame
        local entry = CreateFrame('Frame', nil, containerFrame);
        entry:SetSize(textWidth, 18);
        entry:SetScript('OnEnter', function() self:OnEnter(entry, 'party' .. i); end);
        entry:SetScript('OnLeave', function() self:OnLeave(); end);
        entry.Update = function() self:UpdateEntry(entry, 'party' .. i); end;
        local timeElapsed = 0;
        entry:SetScript('OnUpdate', function(_, elapsed)
            timeElapsed = timeElapsed + elapsed;
            if timeElapsed < 1 then return; end
            timeElapsed = 0;
            entry:Update();
        end);

        local score = entry:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
        score:SetHeight(18);
        score:SetJustifyH('RIGHT');
        score:SetWordWrap(false);
        score:SetTextToFit('');
        score:SetPoint('RIGHT');
        entry.Score = score;

        local name = entry:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
        name:SetHeight(18);
        name:SetJustifyH('LEFT');
        name:SetWordWrap(false);
        name:SetText();
        name:SetPoint('LEFT');
        name:SetPoint('RIGHT', score, 'LEFT', -1, 0);
        entry.Name = name;

        entry:SetPoint('TOP', anchor, 'BOTTOM');
        anchor = entry;
        entries[i] = entry;
    end
    containerFrame:SetScript('OnShow', function()
        for _, entry in pairs(entries) do
            entry:Update();
            RunNextFrame(function() entry:Update(); end);
            C_Timer.After(0.1, function() entry:Update(); end);
        end
    end);

    containerFrame.Entries = entries;

    self:GROUP_ROSTER_UPDATE();
end

function Module:OnUpdate(elapsed)
    if not IsInGroup() then return; end

    self.elapsed = (self.elapsed or 0) + elapsed;
    if self.elapsed < 1 then return; end
    self.elapsed = 0;

    for i = 1, 4 do
        local unit = 'party' .. i;
        Util:GetUnitScores(unit); -- trigger a cache update
        RunNextFrame(function() Util:GetUnitScores(unit); end);
        C_Timer.After(0.1, function() Util:GetUnitScores(unit); end);
    end
end

function Module:GROUP_ROSTER_UPDATE()
    if not self.PartyFrame then return; end

    self.PartyFrame:SetShown(IsInGroup() and GetNumGroupMembers() > 1);

    local entries = self.PartyFrame.Entries;
    for _, entry in pairs(entries) do
        entry:Update();
        RunNextFrame(function() entry:Update(); end);
        C_Timer.After(0.1, function() entry:Update(); end);
    end
end

--- @param entry MPT_PartyRatingEntry
--- @param unit UnitToken.group
function Module:UpdateEntry(entry, unit)
    local unitName = UnitNameUnmodified(unit);
    local class = unitName and select(2, UnitClass(unit));
    if unitName and class then
        local classColor = C_ClassColor.GetClassColor(class);
        local scoreInfo = Util:GetUnitScores(unit);
        local score = scoreInfo and scoreInfo.overall or 0;
        local color = Util:GetRarityColorOverallScore(score);
        entry.Name:SetText(classColor:WrapTextInColorCode(unitName));
        entry.Score:SetTextToFit(color:WrapTextInColorCode(scoreInfo and score or '?'));
        entry:Show();
    else
        entry:Hide();
    end
end

function Module:OnLeave()
    GameTooltip:Hide();
end

--- @param frame Frame
--- @param unit UnitToken.group
function Module:OnEnter(frame, unit)
    local unitName = UnitNameUnmodified(unit);
    local classColor = C_ClassColor.GetClassColor(select(2, UnitClass(unit)));

    local tooltip = GameTooltip;
    tooltip:SetOwner(frame, 'ANCHOR_RIGHT');
    tooltip:SetText(classColor:WrapTextInColorCode(unitName));

    local scoreInfo = Util:GetUnitScores(unit);
    if not scoreInfo then
        tooltip:AddLine('No data available.', 1, 0, 0);
        tooltip:AddLine('The player is too far away, has not completed any m+ dungeon, or no m+ season is currently active.', 1, 1, 1, true);
        tooltip:Show();

        return;
    end

    local overallScore = scoreInfo.overall;
    local overallColor = Util:GetRarityColorOverallScore(overallScore);

    tooltip:AddDoubleLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(DUNGEON_SCORE), overallColor:WrapTextInColorCode(overallScore));

    if 0 == overallScore then
        tooltip:Show();

        return;
    end

    tooltip:AddLine(' ');
    tooltip:AddLine(DUNGEONS);

    local mapIDs = C_ChallengeMode.GetMapTable();
    if not mapIDs or 0 == #mapIDs then
        tooltip:AddLine('No dungeons found. There might not be any active season.');
        tooltip:Show();

        return;
    end

    local unsorted = {};
    for _, mapID in ipairs(mapIDs) do
        local info = scoreInfo.runs[mapID];
        local dungeonScore = info and info.score or 0;
        if self.db.showZeroScoreDungeons or dungeonScore > 0 then
            local level = info and info.level or 0;
            local inTime = info and info.inTime or false;
            local color = Util:GetRarityColorDungeonOverallScore(dungeonScore);
            local timeColor = inTime and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR;

            local name = C_ChallengeMode.GetMapUIInfo(mapID);

            table.insert(
                unsorted,
                {
                    left = HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(name),
                    right = color:WrapTextInColorCode(dungeonScore) .. ' ' .. timeColor:WrapTextInColorCode('+' .. level),
                    score = dungeonScore,
                    name = name,
                    mapID = mapID,
                }
            );
        end
    end

    local sortMode = self.db.sortMode;
    table.sort(
        unsorted,
        function(a, b)
            if
                (sortMode == SORT_MODE_SCORE and a.score == b.score)
                or (sortMode == SORT_MODE_NAME and a.name == b.name)
                or sortMode == SORT_MODE_MAP_ID
            then
                return a.mapID < b.mapID;
            end

            return
                (sortMode == SORT_MODE_MAP_ID and a.mapID < b.mapID)
                or (sortMode == SORT_MODE_SCORE and a.score > b.score)
                or (sortMode == SORT_MODE_NAME and a.name < b.name);
        end
    );
    for _, line in ipairs(unsorted) do
        tooltip:AddDoubleLine(line.left, line.right);
    end

    tooltip:Show();
end
