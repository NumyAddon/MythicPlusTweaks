local name = ...;
--- @class MPT_NS
local ns = select(2, ...);

--@debug@
_G.MythicPlusTweaks = ns;
if not _G.MPT then _G.MPT = ns; end
--@end-debug@

--- @class MPT_Main: AceAddon,AceHook-3.0,AceEvent-3.0,AceConsole-3.0
local Main = LibStub('AceAddon-3.0'):NewAddon('Mythic Plus Tweaks', 'AceConsole-3.0', 'AceHook-3.0', 'AceEvent-3.0');
if not Main then return; end
ns.Main = Main;

function Main:OnInitialize()
    if NumyProfiler then
        --- @type NumyProfiler
        local NumyProfiler = NumyProfiler;
        NumyProfiler:WrapModules(name, 'Main', self);
        NumyProfiler:WrapModules(name, 'Util', ns.Util);
        for moduleName, module in self:IterateModules() do
            NumyProfiler:WrapModules(name, moduleName, module);
        end
    end
    MythicPlusTweaksDB = MythicPlusTweaksDB or {};
    self.db = MythicPlusTweaksDB;
    self.version = C_AddOns.GetAddOnMetadata(name, 'Version') or '';
    self:InitDefaults();
    for moduleName, module in self:IterateModules() do
        --- @type NumyConfig_Module
        local module = module;
        if self.db.modules[moduleName] == false then
            module:Disable();
        end
    end

    ns.Util:Init();
    ns.Config:Init("Mythic Plus Tweaks", self.db, nil, nil, self, {
        'ShowOwnRatingOnLFGTooltip',
        'ImproveKeystoneLink',
        'AlwaysShowAffixes',

        'miscQoL',
        'PartyRating',
        'DungeonTeleports',
        'DungeonIconTooltip',
        'DungeonIconText',
        'KeystoneSharing-core',
        'ShowScoreOnKeystoneTooltip',
        'SortDungeonIcons',
        'MistHelperSync',
    }, function(configBuilder)
        configBuilder:MakeButton(
            "Open the Mythic+ UI",
            function() ns.Util:ToggleMythicPlusFrame(); end
        )
    end);

    SLASH_MYTHIC_PLUS_TWEAKS1 = '/mpt';
    SLASH_MYTHIC_PLUS_TWEAKS2 = '/mythicplustweaks';
    SlashCmdList['MYTHIC_PLUS_TWEAKS'] = function() ns.Config:OpenSettings(); end
end

function Main:InitDefaults()
    local defaults = {
        modules = {},
        moduleDb = {},
        inlineConfig = true,
    };

    for key, value in pairs(defaults) do
        if self.db[key] == nil then
            self.db[key] = value;
        end
    end
end

function Main:SetModuleState(moduleName, enabled)
    if enabled then
        self:EnableModule(moduleName);
    else
        self:DisableModule(moduleName);
    end
    self.db.modules[moduleName] = enabled;
end

function Main:IsModuleEnabled(moduleName)
    local module = self:GetModule(moduleName);

    return module and module:IsEnabled() or false;
end
