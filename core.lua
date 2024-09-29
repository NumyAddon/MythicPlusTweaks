local name = ...;
--- @class MPT_NS
local MPT = select(2, ...);

--@debug@
_G.MythicPlusTweaks = MPT;
if not _G.MPT then _G.MPT = MPT; end
--@end-debug@

--- @class MPT_Main: AceAddon,AceHook-3.0,AceEvent-3.0,AceConsole-3.0
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
    self.version = C_AddOns.GetAddOnMetadata(name, 'Version') or '';
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
        inlineConfig = true,
    };

    for key, value in pairs(defaults) do
        if self.db[key] == nil then
            self.db[key] = value;
        end
    end
end

function Main:InitConfig()
    local search = '';
    local increment = CreateCounter();
    local inline = self.db.inlineConfig;

    local function registerOptions()
        LibStub('AceConfig-3.0'):RegisterOptionsTable(self.configCategory, self.options);
    end

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
                inline = inline,
                args = {
                    desc = {
                        order = increment(),
                        width = 'full',
                        type = 'description',
                        name = 'This addon consists of a number of modules, each of which can be enabled or disabled, to fine-tune your experience.',
                    },
                    inlineConfig = {
                        name = 'Show options as a list',
                        type = 'toggle',
                        desc = 'Show the module options in one long list, instead of a tree.',
                        order = increment(),
                        get = function() return inline; end,
                        set = function(_, value)
                            inline = value;
                            self.db.inlineConfig = value;
                            self.options.args.modules.inline = value;
                            registerOptions();
                        end,
                    },
                    filter = {
                        name = 'Filter',
                        type = 'input',
                        desc = 'Search by module name or description, or \'-\' for disabled modules, or \'+\' for enabled modules.',
                        order = increment(),
                        hidden = function() return not inline end,
                        get = function() return search; end,
                        set = function(_, value) search = value; end
                    },
                    clear = {
                        name = 'Clear',
                        type = 'execute',
                        desc = 'Clear the search filter.',
                        order = increment(),
                        hidden = function() return not inline end,
                        func = function() search = ''; end,
                        width = 0.5,
                    },
                },
            },
        },
    };

    local function hiddenFunc(info)
        if not inline then return false; end
        if 2 ~= #info then return false; end -- prevents the function from running when it's inherited down the option chain
        local moduleName = info[#info];
        local module = Main:GetModule(moduleName, true);
        if not module then return false; end

        if '' == search then return false; end
        if '+' == search or "'+'" == search then return not Main:IsModuleEnabled(moduleName); end
        if '-' == search or "'-'" == search then return Main:IsModuleEnabled(moduleName); end

        local displayName = module.GetName and module:GetName() or moduleName;
        local desc = module.GetDescription and module:GetDescription() or '';
        return not (displayName:lower():find(search:lower()) or desc:lower():find(search:lower()));
    end

    local subIncrement = CreateCounter();
    local defaultModuleOptions = {
        type = 'group',
        name = function(info)
            return info[#info - 1];
        end,
        hidden = hiddenFunc,
        args = {
            name = {
                order = subIncrement(),
                type = 'header',
                hidden = function() return inline end,
                name = function(info)
                    return info.options.args.modules.args[info[#info - 1]].name;
                end,
            },
            description = {
                order = subIncrement(),
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
                order = subIncrement(),
                name = 'Enable',
                desc = 'Enable this module',
                type = 'toggle',
                get = function(info) return Main:IsModuleEnabled(info[#info - 1]); end,
                set = function(info, enabled) Main:SetModuleState(info[#info - 1], enabled); end,
            },
        },
    };
    local subIncrementCount = subIncrement();
    for moduleName, module in self:IterateModules() do
        local copy = CopyTable(defaultModuleOptions);
        self.db.moduleDb[moduleName] = self.db.moduleDb[moduleName] or {};
        local moduleIncrement = CreateCounter(subIncrementCount);
        local moduleOptions = module.GetOptions and module:GetOptions(copy, self.db.moduleDb[moduleName], moduleIncrement) or copy;
        moduleOptions.name = module.GetName and module:GetName() or moduleName;
        moduleOptions.order = increment();
        self.options.args.modules.args[moduleName] = moduleOptions;
    end

    self.configCategory = 'Mythic+ Tweaks';
    registerOptions();
    LibStub('AceConfigDialog-3.0'):AddToBlizOptions(self.configCategory);
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
