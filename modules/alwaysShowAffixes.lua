local _, MPT = ...;
local Main = MPT.Main;

local Module = Main:NewModule('AlwaysShowAffixes', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnEnable()
    if C_AddOns.IsAddOnLoaded('Blizzard_ChallengesUI') then
        self:SetupHook();
    else
        self:RegisterEvent('ADDON_LOADED');
    end
end

function Module:OnDisable()
    self:UnhookAll();
    if C_AddOns.IsAddOnLoaded('Blizzard_ChallengesUI') then
        self.updateFunc(ChallengesFrame);
    end
end

function Module:GetDescription()
    return 'By default, affix information is hidden if you don\'t have any score, and no keystone. This module makes it always show.';
end

function Module:GetOptions(defaultOptionsTable)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Open Mythic+ UI',
        desc = 'Open the Mythic+ UI and the affixes are on the top of the UI.',
        func = function()
            PVEFrame_ToggleFrame('ChallengesFrame');
        end,
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
    self:SecureHook(ChallengesFrame, 'Update', function(frame)
        frame.WeeklyInfo:SetUp();
    end);
    self.updateFunc = ChallengesFrame.Update;
    if ChallengesFrame:IsShown() then
        self.updateFunc(ChallengesFrame);
    end
end
