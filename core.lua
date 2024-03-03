local name, MPT = ...;

--@debug@
_G.MythicPlusTweaks = MPT;
if not _G.MPT then _G.MPT = MPT; end
--@end-debug@

--- @class Main: AceAddon,AceHook-3.0,AceEvent-3.0,AceConsole-3.0
local Main = LibStub('AceAddon-3.0'):NewAddon(name, 'AceConsole-3.0', 'AceHook-3.0', 'AceEvent-3.0');
if not Main then return; end
MPT.Main = Main;

function Main:OnInitialize()
    if NumyProfiler then
        --- @type NumyProfiler
        local NumyProfiler = NumyProfiler;
        NumyProfiler:WrapModules(name, 'Main', self);
        NumyProfiler:WrapModules(name, 'Util', MPT.Util);
        for moduleName, module in self:IterateModules() do
            NumyProfiler:WrapModules(name, moduleName, module);
        end
    end
    MythicPlusTweaksDB = MythicPlusTweaksDB or {};
    self.db = MythicPlusTweaksDB;
    self.version = C_AddOns.GetAddOnMetadata(name, "Version") or "";
    self:InitDefaults();
    for moduleName, module in self:IterateModules() do
        if self.db.modules[moduleName] == false then
            module:Disable();
        end
    end

    self:InitConfig();

    self:RegisterChatCommand('mpt', function() self:OpenConfig(); end);
end

function Main:InitDefaults()
    local defaults = {
        modules = {},
        moduleDb = {},
    };

    for key, value in pairs(defaults) do
        if self.db[key] == nil then
            self.db[key] = value;
        end
    end
end

function Main:InitConfig()
    local count = 1;
    local function increment() count = count + 1; return count end;
    self.options = {
        type = 'group',
        name = 'Mythic+ Tweaks',
        desc = 'Various tweaks related to mythic+',
        childGroups = 'tab',
        args = {
            version = {
                order = increment(),
                type = 'description',
                name = 'Version: ' .. self.version,
            },
            modules = {
                order = increment(),
                type = 'group',
                name = 'Modules',
                childGroups = 'tree',
                args = {
                    desc = {
                        order = increment(),
                        type = 'description',
                        name = 'This addon consists of a number of modules, each of which can be enabled or disabled, to fine-tune your experience.',
                    },
                },
            }
        }
    };
    local defaultModuleOptions = {
        type = 'group',
        name = function(info)
            return info[#info - 1];
        end,
        args = {
            name = {
                order = 1,
                type = 'header',
                name = function(info)
                    return info.options.args.modules.args[info[#info - 1]].name;
                end,
            },
            description = {
                order = 2,
                type = 'description',
                name = function(info)
                    local module = Main:GetModule(info[#info - 1]);
                    return module.GetDescription and module:GetDescription() or '';
                end,
                hidden = function(info)
                    return '' == info.option.name(info)
                end,
            },
            enable = {
                order = 3,
                name = 'Enable',
                desc = 'Enable this module',
                type = 'toggle',
                get = function(info) return Main:IsModuleEnabled(info[#info - 1]); end,
                set = function(info, enabled) Main:SetModuleState(info[#info - 1], enabled); end,
            },
        },
    };
    for moduleName, module in self:IterateModules() do
        local copy = CopyTable(defaultModuleOptions);
        self.db.moduleDb[moduleName] = self.db.moduleDb[moduleName] or {};
        local moduleOptions = module.GetOptions and module:GetOptions(copy, self.db.moduleDb[moduleName]) or copy;
        moduleOptions.name = module.GetName and module:GetName() or moduleName;
        moduleOptions.order = increment();
        self.options.args.modules.args[moduleName] = moduleOptions;
    end

    self.configCategory = 'Mythic+ Tweaks';
    LibStub('AceConfig-3.0'):RegisterOptionsTable(self.configCategory, self.options);
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.configCategory);
end

function Main:OpenConfig()
    Settings.OpenToCategory(self.configCategory);
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
