local _, MPT = ...;
--- @type MPT_Main
local Main = MPT.Main;
--- @type MPT_Util
local Util = MPT.Util;

--- @class MPT_DungeonIconText: AceModule, AceHook-3.0, AceEvent-3.0
local Module = Main:NewModule('DungeonIconText', 'AceHook-3.0', 'AceEvent-3.0');

local OPTION_FULL_NAME = 'full';
local OPTION_MIDDLE_NAME = 'middle';
local OPTION_SHORT_NAME = 'short';
local OPTION_NO_NAME = 'none';

-- [mapID] = {shortName, middleName}
Module.shortNames = {
    [2] = {"TotJS", "Temple ot JS"}, -- Temple of the Jade Serpent
    [56] = {"SB", "Storm Brew"}, -- Stormstout Brewery
    [57] = {"GotSS", "Gate ot SS"}, -- Gate of the Setting Sun
    [58] = {"SPM", "Shado-Pan Mon"}, -- Shado-Pan Monastery
    [59] = {"SoNT", "Siege o NiuzaoT"}, -- Siege of Niuzao Temple
    [60] = {"MP", "Mogu Palace"}, -- Mogu'shan Palace
    [76] = {"SchM", "Scholomance"}, -- Scholomance
    [77] = {"SH", "Scar Halls"}, -- Scarlet Halls
    [78] = {"SM", "Scar Mona"}, -- Scarlet Monastery
    [161] = {"SR", "Skyreach"}, -- Skyreach
    [163] = {"BSM", "Blood Slag Mines"}, -- Bloodmaul Slag Mines
    [164] = {"AD", "Auchindoun"}, -- Auchindoun
    [165] = {"SBG", "Shadowmoon BG"}, -- Shadowmoon Burial Grounds
    [166] = {"GD", "Grimrail D"}, -- Grimrail Depot
    [167] = {"UBS", "Upper B-Spire"}, -- Upper Blackrock Spire
    [168] = {"EB", "Everbloom"}, -- The Everbloom
    [169] = {"ID", "Iron Docks"}, -- Iron Docks
    [197] = {"EoA", "Eye of Azshara"}, -- Eye of Azshara
    [198] = {"DhT", "Dark-Thicket"}, -- Darkheart Thicket
    [199] = {"BRH", "Black Rook Hold"}, -- Black Rook Hold
    [200] = {"HoV", "Halls of Valor"}, -- Halls of Valor
    [206] = {"NL", "Nelth Lair"}, -- Neltharion's Lair
    [207] = {"VotW", "Vault otW"}, -- Vault of the Wardens
    [208] = {"MoS", "Maw of Souls"}, -- Maw of Souls
    [209] = {"AW", "Arcway"}, -- The Arcway
    [210] = {"CoS", "Court of Stars"}, -- Court of Stars
    [227] = {"RtK1:Low", "Lower Karazhan"}, -- Return to Karazhan: Lower
    [234] = {"RtK2:Up", "Upper Karazhan"}, -- Return to Karazhan: Upper
    [233] = {"CoEN", "Cath of Et Ni"}, -- Cathedral of Eternal Night
    [239] = {"SotT", "Seat ot Trium"}, -- Seat of the Triumvirate
    [244] = {"AD", "Atal'Dazar"}, -- Atal'Dazar
    [245] = {"FH", "Freehold"}, -- Freehold
    [246] = {"TD", "Tol Dagor"}, -- Tol Dagor
    [247] = {"ML", "Motherlode"}, -- The MOTHERLODE!!
    [248] = {"WM", "Waycrest Manor"}, -- Waycrest Manor
    [249] = {"KR", "Kings' Rest"}, -- Kings' Rest
    [250] = {"ToS", "Temple of Seth"}, -- Temple of Sethraliss
    [251] = {"UR", "Underrot"}, -- The Underrot
    [252] = {"SotS", "Shrine ot Storm"}, -- Shrine of the Storm
    [353] = {"SoB", "S. of Boralus"}, -- Siege of Boralus
    [369] = {"OM1-JY", "Mecha1-Junk"}, -- Operation: Mechagon - Junkyard
    [370] = {"OM2-WS", "Mecha2-Workshop"}, -- Operation: Mechagon - Workshop
    [375] = {"MoTS", "Mists of TS"}, -- Mists of Tirna Scithe
    [376] = {"NW", "Necrotic Wake"}, -- The Necrotic Wake
    [377] = {"DOS", "Other Side"}, -- De Other Side
    [378] = {"HoA", "Halls of Aton"}, -- Halls of Atonement
    [379] = {"PF", "Plaguefall"}, -- Plaguefall
    [380] = {"SD", "Sang Depths"}, -- Sanguine Depths
    [381] = {"SoA", "Spires of Asc"}, -- Spires of Ascension
    [382] = {"ToP", "Theater of Pain"}, -- Theater of Pain
    [391] = {"T1:SoW", "Taza1 Streets"}, -- Tazavesh: Streets of Wonder
    [392] = {"T2:SG", "Taza2 Gambit"}, -- Tazavesh: So'leah's Gambit
    [399] = {"RLP", "Ruby Life"}, -- Ruby Life Pools
    [400] = {"NO", "Nokhud Off"}, -- The Nokhud Offensive
    [401] = {"AV", "Azure Vault"}, -- The Azure Vault
    [402] = {"AA", "Alg Academy"}, -- Algeth'ar Academy
    [403] = {"ULoT", "Uldaman"}, -- Uldaman: Legacy of Tyr
    [404] = {"Nelth", "Neltharus"}, -- Neltharus
    [405] = {"BH", "Brackenhide"}, -- Brackenhide Hollow
    [406] = {"HoI", "Halls of Infusion"}, -- Halls of Infusion
    [438] = {"VP", "Vortex Pinnacle"}, -- The Vortex Pinnacle
    [456] = {"TotT", "Throne ot Tides"}, -- Throne of the Tides
    [463] = {"DotI1:GF", "DawnOTI1:GalakrondF"}, -- Dawn of the Infinite: Galakrond's Fall
    [464] = {"DotI2:MR", "DawnOTI2:MurozondR"}, -- Dawn of the Infinite: Murozond's Rise
    [499] = {"PSF", "Priory ot SF"}, -- Priory of the Sacred Flame
    [500] = {"Rook", "Rookery"}, -- The Rookery
    [501] = {"SV", "Stonevault"}, -- The Stonevault
    [502] = {"CoT", "City of Threads"}, -- City of Threads
    [503] = {"A CoE", "Ara-Kara"}, -- Ara-Kara, City of Echoes - will it be called AK, ACoE, CoE / Ara-Kara, or City of Echoes?
    [504] = {"DC", "DarkflameC"}, -- Darkflame Cleft
    [505] = {"DB", "Dawnbreaker"}, -- The Dawnbreaker
    [506] = {"CM", "Cinderbrew"}, -- Cinderbrew Meadery
    [507] = {"GB", "Grim Batol"}, -- Grim Batol
};

function Module:OnInitialize()
    self.font = CreateFont('MythicPlusTweaks_DungeonIconText_Font');
    self.font:CopyFontObject(SystemFont_Huge1_Outline);
    self.minFontSize = 10;
    self.db = self.db or {};
end

function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ChallengesUI', function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if C_AddOns.IsAddOnLoaded('Blizzard_ChallengesUI') then
        ChallengesFrame:Update();
        self:RepositionFrameElements(ChallengesFrame, true);
        for i = 1, #ChallengesFrame.DungeonIcons do
            if ChallengesFrame.DungeonIcons[i].CurrentLevel then
                ChallengesFrame.DungeonIcons[i].CurrentLevel:Hide();
            end
            if ChallengesFrame.DungeonIcons[i].DungeonName then
                ChallengesFrame.DungeonIcons[i].DungeonName:Hide();
            end
            ChallengesFrame.DungeonIcons[i].HighestLevel:SetFontObject(SystemFont_Huge1_Outline);
        end
        self.font:CopyFontObject(SystemFont_Huge1_Outline);
    end
end

function Module:GetName()
    return 'Dungeon Icon Text';
end

function Module:GetDescription()
    return Util.AFFIX_SPECIFIC_SCORES
        and 'Changes the text on the dungeon icons, to show "{level} - {score}" on top (level is grey if out of time). And {affix level} - {affix score} on bottom for the current week\'s affix.'
        or 'Changes the text on the dungeon icons, to show "{level} - {score}" on the icon (level is grey if out of time). Affix-specific scores are not relevant this season.';
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        dash = false,
        name = OPTION_MIDDLE_NAME,
    }
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end
    local function get(info)
        return db[info[#info]];
    end
    local function set(info, value)
        db[info[#info]] = value;
        if ChallengesFrame and ChallengesFrame.IsShown and ChallengesFrame:IsShown() then
            ChallengesFrame:Update();
        end
    end
    local order = 10;
    local function increment() order = order + 1; return order; end
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Open Mythic+ UI',
        desc = 'Open the Mythic+ UI and the icons are on the bottom of the UI.',
        func = function()
            PVEFrame_ToggleFrame('ChallengesFrame');
        end,
        order = increment(),
    };
    defaultOptionsTable.args.dash = {
        type = 'toggle',
        name = 'Show separator',
        desc = 'Separate Level and Score with a dash (-). Disabling this might result in a larger font size.',
        get = get,
        set = function(info, value)
            self.font:CopyFontObject(SystemFont_Huge1_Outline);
            set(info, value);
        end,
        order = increment(),
    };
    defaultOptionsTable.args.name = {
        type = 'select',
        name = 'Show dungeon name above the icon.',
        desc = 'Full name is in your game\'s language, the others are English only.',
        values = {
            [OPTION_FULL_NAME] = 'Long name (e.g. "Brackenhide Hollow")',
            [OPTION_MIDDLE_NAME] = 'Shortened name (e.g. "Brackenhide")',
            [OPTION_SHORT_NAME] = 'Abbreviated (e.g. "BH")',
            [OPTION_NO_NAME] = 'No name',
        },
        sorting = {
            OPTION_FULL_NAME,
            OPTION_MIDDLE_NAME,
            OPTION_SHORT_NAME,
            OPTION_NO_NAME,
        },
        get = get,
        set = set,
        order = increment(),
        width = 'double',
        style = 'radio'
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    self:SecureHook(ChallengesFrame, 'Update', function(frame)
        self:AddScoresToAllIcons(frame);
        self:RepositionFrameElements(frame);
        self:AddNamesAboveIcons(frame);
        RunNextFrame(function()
            self:RepositionFrameElements(frame);
        end);
    end);
    if ChallengesFrame:IsShown() then
        ChallengesFrame:Update();
    end
end

--- @param frame ChallengesFrame
function Module:RepositionFrameElements(frame, forceReset)
    local seasonBestOffsetY = 35;
    local weeklyChestOffsetY = 20;
    if self.db.name == OPTION_NO_NAME or forceReset then
        seasonBestOffsetY = 15;
        weeklyChestOffsetY = 0;
    end
    if C_AddOns.IsAddOnLoaded('AngryKeystones') then
        -- AngryKeystones shifts the weekly chest to the left and adds a text underneath it, which would badly overlap with the SeasonBest text.
        GetFrameMetatable().__index.ClearAllPoints(frame.WeeklyInfo.Child.WeeklyChest);
        GetFrameMetatable().__index.SetPoint(frame.WeeklyInfo.Child.WeeklyChest, 'LEFT', 100, weeklyChestOffsetY);

        frame.WeeklyInfo.Child.WeeklyChest.ClearAllPoints = nop;
        frame.WeeklyInfo.Child.WeeklyChest.SetPoint = nop;
    end
    frame.WeeklyInfo.Child.SeasonBest:ClearAllPoints();
    frame.WeeklyInfo.Child.SeasonBest:SetPoint('TOPLEFT', frame.DungeonIcons[1], 'TOPLEFT', 5, seasonBestOffsetY);
end

function Module:AddNamesAboveIcons(frame)
    if self.db.name == OPTION_NO_NAME then
        for i = 1, #frame.DungeonIcons do
            local icon = frame.DungeonIcons[i];
            if icon.DungeonName then
                icon.DungeonName:Hide();
            end
        end

        return;
    end
    for i = 1, #frame.DungeonIcons do
        local icon = frame.DungeonIcons[i];
        if not icon.DungeonName then
            icon.DungeonName = icon:CreateFontString(nil, 'BORDER', 'GameFontNormalMed2');
            icon.DungeonName:SetPoint('BOTTOM', icon, 'TOP', 0, 4);
            icon.DungeonName:SetTextColor(1, 1, 1);
            local fontFile, fontHeight, flags = icon.DungeonName:GetFont()
            icon.DungeonName:SetFont(fontFile, fontHeight - 4, flags);
        end
        local name = C_ChallengeMode.GetMapUIInfo(icon.mapID);
        if name:sub(0, 4) == 'The ' then
            name = name:sub(4); -- strip leading "The "
        end
        if self.db.name == OPTION_SHORT_NAME or self.db.name == OPTION_MIDDLE_NAME then
            name = self:GetShortName(name, icon.mapID);
        end
        icon.DungeonName:SetText(name);
        icon.DungeonName:Show();
        icon.DungeonName:SetWidth(icon:GetWidth() - 1);
        icon.DungeonName:SetMaxLines(1);
    end
end

function Module:GetShortName(name, mapID)
    if self.shortNames[mapID] then
        return self.shortNames[mapID][self.db.name == OPTION_MIDDLE_NAME and 2 or 1];
    end

    if self.db.name == OPTION_MIDDLE_NAME then
        return name;
    end

    local shortName = '';
    for word in name:gmatch('%S+') do
        shortName = shortName .. word:sub(1, 1);
    end
    return shortName;
end

--- @param challengesFrame ChallengesFrame
function Module:AddScoresToAllIcons(challengesFrame)
    for i = 1, #challengesFrame.DungeonIcons do
        Module:AddScoresToIcon(challengesFrame.DungeonIcons[i]);
    end
end

--- @param icon ChallengesDungeonIconFrameTemplate
function Module:AddScoresToIcon(icon)
    if icon.CurrentLevel then icon.CurrentLevel:Hide(); end
    local mapId = icon.mapID;

    local overallInfo = Util:GetOverallInfoByMapId(mapId);

    local separator = self.db.dash and ' - ' or ' ';
    if overallInfo and overallInfo.score > 0 then
        icon.HighestLevel:SetText(overallInfo.levelColor:WrapTextInColorCode(overallInfo.level) .. separator .. overallInfo.scoreColor:WrapTextInColorCode(overallInfo.score));
        icon.HighestLevel:SetTextColor(1, 1, 1);
        icon.HighestLevel:Show();
        icon.HighestLevel:SetWidth(icon:GetWidth() - 1);
        self:AutoFitText(icon.HighestLevel);
    end

    if not Util.AFFIX_SPECIFIC_SCORES then return; end

    local affixInfo = Util:GetAffixInfoByMapId(mapId);
    if (not affixInfo or affixInfo.score == 0) then return; end

    if (not icon.CurrentLevel) then
        self:InitCurrentLevelText(icon);
    end
    icon.CurrentLevel:SetText(affixInfo.levelColor:WrapTextInColorCode(affixInfo.level) .. separator .. affixInfo.scoreColor:WrapTextInColorCode(affixInfo.score));
    icon.CurrentLevel:Show();
    icon.CurrentLevel:SetWidth(icon:GetWidth() - 1);
    self:AutoFitText(icon.CurrentLevel);
end

--- @param icon ChallengesDungeonIconFrameTemplate
function Module:InitCurrentLevelText(icon)
    icon.CurrentLevel = icon:CreateFontString(nil, 'BORDER', 'SystemFont_Huge1_Outline');
    icon.CurrentLevel:SetPoint('BOTTOM', 0, 4);
    icon.CurrentLevel:SetTextColor(1, 1, 1);
    icon.CurrentLevel:SetShadowOffset(1, -1);
    icon.CurrentLevel:SetShadowColor(0, 0, 0);
end

--- @param text FontString
function Module:AutoFitText(text)
    text:SetFontObject(self.font);

    while (true) do
        local difference = text:GetUnboundedStringWidth() - text:GetWidth();

        local fontFile, fontSize, fontFlags = self.font:GetFont();
        if (difference < 0 or fontSize <= self.minFontSize) then break; end

        if (difference > 0) then
            self.font:SetFont(fontFile, fontSize - 1, fontFlags);
        end
    end
end
