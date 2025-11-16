--- @class MPT_NS
local MPT = select(2, ...);

local Main = MPT.Main;
local Util = MPT.Util;

local SORT_OPTION_BEST_RUN_SCORE = 'best_run_score'; -- default UI uses this style
local SORT_OPTION_OVERALL_SCORE = 'overall_score';
local SORT_OPTION_BEST_RUN_LEVEL = 'best_run_level';
local SORT_OPTION_OVERALL_LEVEL_TIMED = 'overall_level_timed';
local SORT_CURRENT_AFFIX_SCORE = 'current_affix_score';
local SORT_CURRENT_AFFIX_LEVEL = 'current_affix_level';
local SORT_OPTION_NAME = 'name';
local SORT_OPTION_ID = 'id';

local SORT_DIRECTION_DESC = 'desc'; -- default UI does this
local SORT_DIRECTION_ASC = 'asc';

--- @class MPT_SortDungeonIcons: MPT_Module, AceHook-3.0, AceEvent-3.0
local Module = Main:NewModule('SortDungeonIcons', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnEnable()
    Util:OnChallengesUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    self.allowIconSetUp = true;
    if C_AddOns.IsAddOnLoaded('Blizzard_ChallengesUI') then
        ChallengesFrame:Update();
    end
end

function Module:GetName()
    return 'Sort Dungeon Icons';
end

function Module:GetDescription()
    return 'Allows you to sort the dungeon icons in various different ways.';
end

--- @param configBuilder MPT_ConfigBuilder
--- @param db MPT_SortDungeonIconsDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class MPT_SortDungeonIconsDB
    local defaults = {
        sortStyle = SORT_OPTION_OVERALL_SCORE,
        sortDirection = SORT_DIRECTION_DESC,
    };
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeButton(
        'Open Mythic+ UI',
        function() Util:ToggleMythicPlusFrame(); end,
        'Open the Mythic+ UI and the icons are on the bottom of the UI.'
    );
    local function updateUI()
        if ChallengesFrame and ChallengesFrame.IsShown and ChallengesFrame:IsShown() then
            ChallengesFrame:Update();
        end
    end
    configBuilder:MakeDropdown(
        'Sort Style',
        'sortStyle',
        'How to sort the icons.',
        {
            { text = 'Score from your best run', label = 'Score from your best run (default UI style)', value = SORT_OPTION_BEST_RUN_SCORE },
            { text = 'Overall Dungeon Score', label = 'Overall Dungeon Score', value = SORT_OPTION_OVERALL_SCORE },
            { text = 'Level from your best run', label = 'Level from your best run', value = SORT_OPTION_BEST_RUN_LEVEL },
            { text = 'Highest Level (Timed)', label = 'Highest Level (Timed)', value = SORT_OPTION_OVERALL_LEVEL_TIMED },
            { text = 'Current Affix Score', label = 'Current Affix Score' .. (Util.AFFIX_SPECIFIC_SCORES and '' or ' (this season will use Overall Score instead)'), value = SORT_CURRENT_AFFIX_SCORE },
            { text = 'Current Affix Level', label = 'Current Affix Level' .. (Util.AFFIX_SPECIFIC_SCORES and '' or ' (this season will use Level from your best run instead)'), value = SORT_CURRENT_AFFIX_LEVEL },
            { text = 'Name', label = 'Sorted by Name', value = SORT_OPTION_NAME },
            { text = 'M+ MapID', label = 'Sorted by M+ MapID', value = SORT_OPTION_ID },
        },
        updateUI
    );
    configBuilder:MakeDropdown(
        'Sort Direction',
        'sortDirection',
        'Which direction to sort the icons.',
        {
            { text = 'Descending', label = 'Highest left -> lowest right (default UI style)', value = SORT_DIRECTION_DESC },
            { text = 'Ascending', label = 'Lowest left -> highest right', value = SORT_DIRECTION_ASC },
        },
        updateUI
    );
end

Module.allowIconSetUp = false;
function Module:SetupHook()
    self:RawHook(ChallengesFrame, 'Update', function(frame)
        if not self.oneTimeSetupCompleted then
            self.oneTimeSetupCompleted = true;

            self:PreventIconSetUpFromOthers(frame);
            self.allowIconSetUp = true;
            self.hooks[frame].Update(frame);
            self.allowIconSetUp = false;

            frame:Update();
            return;
        end

        self:SortIcons(frame);
        self.hooks[frame].Update(frame);
        self:SetBackground(frame);
    end, true);
    if ChallengesFrame:IsShown() then
        ChallengesFrame:Update();
    end
end

--- @param frame ChallengesFrame
function Module:PreventIconSetUpFromOthers(frame)
    for i = 1, #frame.DungeonIcons do
        local icon = frame.DungeonIcons[i];
        local originalSetUp = icon.SetUp;
        icon.SetUp = function(...)
            if self.allowIconSetUp then
                originalSetUp(...);
            end
        end
    end
    local originalSetUp = ChallengesDungeonIconMixin.SetUp;
    ChallengesDungeonIconMixin.SetUp = function(...)
        if self.allowIconSetUp then
            originalSetUp(...);
        end
    end
end

local CreateFrames, LineUpFrames;
do
    function CreateFrames(self, array, num, template)
        while (#self[array] < num) do
            CreateFrame("Frame", nil, self, template);
        end

        for i = num + 1, #self[array] do
            self[array][i]:Hide();
        end
    end

    --- @param frames ChallengesDungeonIconFrameTemplate[]
    function LineUpFrames(frames, anchorPoint, anchor, relativePoint, width)
        local num = #frames;

        local distanceBetween = 2;
        local spacingWidth = distanceBetween * num;
        local widthRemaining = width - spacingWidth;

        local halfWidth = width / 2;

        local calculateWidth = widthRemaining / num;

        -- First frame
        frames[1]:ClearAllPoints();
        if (frames[1].Icon) then
            frames[1].Icon:SetSize(calculateWidth, calculateWidth);
        end
        frames[1]:SetSize(calculateWidth, calculateWidth);
        frames[1]:SetPoint(anchorPoint, anchor, relativePoint, -halfWidth, 5);

        for i = 2, #frames do
            if (frames[i].Icon) then
                frames[i].Icon:SetSize(calculateWidth, calculateWidth);
            end
            frames[i].Icon:SetSize(calculateWidth, calculateWidth);
            frames[i]:SetSize(calculateWidth, calculateWidth);
            frames[i]:SetPoint("LEFT", frames[i - 1], "RIGHT", distanceBetween, 0);
        end
    end
end

local sortFunctions = {
    [SORT_OPTION_BEST_RUN_SCORE] = function(a, b)
        if (b.dungeonScore ~= a.dungeonScore) then
            return a.dungeonScore > b.dungeonScore;
        else
            return strcmputf8i(a.name, b.name) > 0;
        end
    end,
    [SORT_OPTION_OVERALL_SCORE] = function(a, b)
        if (b.extraDetails.score ~= a.extraDetails.score) then
            return a.extraDetails.score > b.extraDetails.score;
        else
            return strcmputf8i(a.name, b.name) > 0;
        end
    end,
    [SORT_OPTION_BEST_RUN_LEVEL] = function(a, b)
        if (b.level ~= a.level) then
            return a.level > b.level;
        else
            return strcmputf8i(a.name, b.name) > 0;
        end
    end,
    [SORT_OPTION_OVERALL_LEVEL_TIMED] = function(a, b)
        if (b.extraDetails.inTimeLevel ~= a.extraDetails.inTimeLevel) then
            return a.extraDetails.inTimeLevel > b.extraDetails.inTimeLevel;
        else
            return strcmputf8i(a.name, b.name) > 0;
        end
    end,
    [SORT_CURRENT_AFFIX_SCORE] = function(a, b)
        if (b.extraDetails.currentAffixInfo.score ~= a.extraDetails.currentAffixInfo.score) then
            return a.extraDetails.currentAffixInfo.score > b.extraDetails.currentAffixInfo.score;
        else
            return strcmputf8i(a.name, b.name) > 0;
        end
    end,
    [SORT_CURRENT_AFFIX_LEVEL] = function(a, b)
        if (b.extraDetails.currentAffixInfo.level ~= a.extraDetails.currentAffixInfo.level) then
            return a.extraDetails.currentAffixInfo.level > b.extraDetails.currentAffixInfo.level;
        else
            return strcmputf8i(a.name, b.name) > 0;
        end
    end,
    [SORT_OPTION_NAME] = function(a, b)
        return strcmputf8i(a.name, b.name) > 0;
    end,
    [SORT_OPTION_ID] = function(a, b)
        return a.id > b.id;
    end,
};
if not Util.AFFIX_SPECIFIC_SCORES then
    sortFunctions[SORT_CURRENT_AFFIX_SCORE] = sortFunctions[SORT_OPTION_OVERALL_SCORE];
    sortFunctions[SORT_CURRENT_AFFIX_LEVEL] = sortFunctions[SORT_OPTION_BEST_RUN_LEVEL];
end

function Module:GetSortFunction()
    local sortFunction = sortFunctions[self.db.sortStyle] or sortFunctions[SORT_OPTION_OVERALL_SCORE];
    if self.db.sortDirection == SORT_DIRECTION_ASC then
        return function(a, b)
            return not sortFunction(a, b);
        end
    end

    return sortFunction;
end

--- @param frame ChallengesFrame
function Module:SortIcons(frame)
    local sortedMaps = {};

    for i = 1, #frame.maps do
        local inTimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(frame.maps[i]);
        local level = 0;
        local dungeonScore = 0;
        if (inTimeInfo and overtimeInfo) then
            local inTimeScoreIsBetter = inTimeInfo.dungeonScore > overtimeInfo.dungeonScore;
            level = inTimeScoreIsBetter and inTimeInfo.level or overtimeInfo.level;
            dungeonScore = inTimeScoreIsBetter and inTimeInfo.dungeonScore or overtimeInfo.dungeonScore;
        elseif (inTimeInfo or overtimeInfo) then
            level = inTimeInfo and inTimeInfo.level or overtimeInfo.level;
            dungeonScore = inTimeInfo and inTimeInfo.dungeonScore or overtimeInfo.dungeonScore;
        end
        local name = C_ChallengeMode.GetMapUIInfo(frame.maps[i]);
        tinsert(sortedMaps, {
            id = frame.maps[i],
            level = level,
            dungeonScore = dungeonScore,
            name = name,
            extraDetails = Util:GetOverallInfoByMapId(frame.maps[i], true),
        });
    end
    table.sort(sortedMaps, self:GetSortFunction());

    local frameWidth = frame.WeeklyInfo:GetWidth();
    local num = #sortedMaps;
    CreateFrames(frame, "DungeonIcons", num, "ChallengesDungeonIconFrameTemplate");
    LineUpFrames(frame.DungeonIcons, "BOTTOMLEFT", frame, "BOTTOM", frameWidth);

    for i = 1, #sortedMaps do
        local icon = frame.DungeonIcons[i];
        self.allowIconSetUp = true;
        icon:SetUp(sortedMaps[i], i == 1);
        self.allowIconSetUp = false;
        icon:Show();
    end
end

function Module:SetBackground(frame)
    local backgroundTexture = select(5, C_ChallengeMode.GetMapUIInfo(frame.DungeonIcons[1].mapID));
    if (backgroundTexture ~= 0) then
        frame.Background:SetTexture(backgroundTexture);
    end
end
