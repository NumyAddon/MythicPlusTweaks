local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('DungeonIconText', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnInitialize()
    self.font = CreateFont('MythicPlusTweaks_DungeonIconText_Font');
    self.font:CopyFontObject(SystemFont_Huge1_Outline);
    self.minFontSize = 10;
    self.db = self.db or {};
end

function Module:OnEnable()
    if IsAddOnLoaded('Blizzard_ChallengesUI') then
        self:SetupHook();
    else
        self:RegisterEvent('ADDON_LOADED');
    end
end

function Module:OnDisable()
    self:UnhookAll();
    if IsAddOnLoaded('Blizzard_ChallengesUI') then
        self.updateFunc(ChallengesFrame);
        for i = 1, #ChallengesFrame.DungeonIcons do
            if ChallengesFrame.DungeonIcons[i].CurrentLevel then
                ChallengesFrame.DungeonIcons[i].CurrentLevel:Hide();
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
    return 'Changes the text on the dungeon icons, to show "{level} - {score}" on top (level is grey if out of time). And {affix level} - {affix score} on bottom for the current week\'s affix.';
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    if db.dash == nil then
        db.dash = true;
    end
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Open Mythic+ UI',
        desc = 'Open the Mythic+ UI and the icons are on the bottom of the UI.',
        func = function()
            PVEFrame_ToggleFrame('ChallengesFrame');
        end,
        order = 10,
    };
    defaultOptionsTable.args.toggleDash = {
        type = 'toggle',
        name = 'Show separator',
        desc = 'Separate Level and Score with a dash (-). Disabling this might result in a larger font size.',
        get = function()
            return db.dash;
        end,
        set = function(info, value)
            db.dash = value;
            self.font:CopyFontObject(SystemFont_Huge1_Outline);
            if ChallengesFrame and ChallengesFrame.IsShown and ChallengesFrame:IsShown() then
                self.updateFunc(ChallengesFrame);
            end
        end,
        order = 11,
    };

    return defaultOptionsTable;
end

function Module:ADDON_LOADED(event, addon)
    if addon == 'Blizzard_ChallengesUI' then
        self:SetupHook();
        self:UnregisterEvent('ADDON_LOADED');
    end
end

function Module:SetupHook()
    self.updateFunc = ChallengesFrame_Update or ChallengesFrame.Update;
    if ChallengesFrame_Update then
        self:SecureHook('ChallengesFrame_Update', function(frame)
            Module:AddScoresToAllIcons(frame);
        end);
    else
        self:SecureHook(ChallengesFrame, 'Update', function(frame)
            Module:AddScoresToAllIcons(frame);
        end);
    end
    if ChallengesFrame:IsShown() then
        self.updateFunc(ChallengesFrame);
    end
end

function Module:AddScoresToAllIcons(challengesFrame)
    for i = 1, #challengesFrame.DungeonIcons do
        Module:AddScoresToIcon(challengesFrame.DungeonIcons[i]);
    end
end

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

function Module:InitCurrentLevelText(icon)
    icon.CurrentLevel = icon:CreateFontString(nil, 'BORDER', 'SystemFont_Huge1_Outline');
    icon.CurrentLevel:SetPoint('BOTTOM', 0, 4);
    icon.CurrentLevel:SetTextColor(1, 1, 1);
    icon.CurrentLevel:SetShadowOffset(1, -1);
    icon.CurrentLevel:SetShadowColor(0, 0, 0);
end

function Module:AutoFitText(text)
    text:SetFontObject(self.font);

    while (true) do
        local difference = text:GetUnboundedStringWidth() - text:GetWidth();

        local fontFile, fontSize, fontFlags = self.font:GetFont();
        if (difference < 0 or fontSize == self.minFontSize) then break; end

        if (difference > 0) then
            self.font:SetFont(fontFile, fontSize - 1, fontFlags);
        end
    end
end
