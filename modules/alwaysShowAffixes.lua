--- @class MPT_NS
local MPT = select(2, ...);

local Main = MPT.Main;
local Util = MPT.Util;

--- @class MPT_AlwaysShowAffixes: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('AlwaysShowAffixes', 'AceHook-3.0');

function Module:OnEnable()
    Util:OnChallengesUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if ChallengesFrame then
        self.updateFunc(ChallengesFrame);
    end
end

function Module:GetDescription()
    return 'By default, affix information is hidden if you don\'t have any score, and no keystone. This module makes it always show.';
end

function Module:GetName() return 'Always Show Affixes'; end

function Module:SetupHook()
    self:SecureHook(ChallengesFrame, 'Update', function(frame)
        frame.WeeklyInfo:SetUp();
    end);
    self.updateFunc = ChallengesFrame.Update;
    if ChallengesFrame:IsShown() then
        self.updateFunc(ChallengesFrame);
    end
end
