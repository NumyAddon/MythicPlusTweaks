local _, MPT = ...;
--- @type MPT_Main
local Main = MPT.Main;

--- @type KeystoneSharingUtil
local KSUtil = MPT.KeystoneSharingUtil;

--- @class MPT_KeystoneSharing: AceModule, AceEvent-3.0
local Module = Main:NewModule('KeystoneSharing-core', 'AceEvent-3.0');

function Module:OnEnable()
    self.playerName = UnitName('player');
    self.playerRealm = GetRealmName();
    self.playerFaction = UnitFactionGroup('player');
    self.playerClass = select(2, UnitClass('player'));
    self.playerGuild = GetGuildInfo('player');
    self:RegisterEvent('PLAYER_GUILD_UPDATE');
    self:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE', 'UpdateKeystoneInfo');
    self:UpdateKeystoneInfo();

    KSUtil:RegisterKeystoneUpdateCallback(self, self.UpdateKeystoneInfo);
    for subModuleName, subModule in pairs(self.modules) do
        if false == self.db.modules[subModuleName] then -- nil implies enabled, so check explicitly for false
            subModule:Disable();
        else
            subModule:Enable();
        end
    end
end

function Module:OnDisable()
    KSUtil:UnregisterKeystoneUpdateCallback(self);
    self:UnregisterEvent('PLAYER_GUILD_UPDATE');
    self:UnregisterEvent('CHALLENGE_MODE_MAPS_UPDATE');
    for _, subModule in pairs(self.modules) do
        subModule:Disable();
    end
end

function Module:GetName()
    return 'Share your keystone to addons used by others';
end

function Module:GetDescription()
    return 'This module emulates the behavior of other addons that share keystone data. Allowing your party/guild/friends to see your keystone without you needing to install the addon they\'re using.';
end

function Module:GetOptions(defaultOptionsTable, db, increment)
    --- @class MPT_KeystoneSharingDB: MPT_KeystoneSharingDB_Defaults
    self.db = db;
    --- @class MPT_KeystoneSharingDB_Defaults
    local defaults = {
        modules = {},
        moduleDB = {},
        shareAlts = true,
        altStore = {},
    };
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end
    defaultOptionsTable.args.disabledWarning = {
        order = increment(),
        type = 'description',
        hidden = function() return self:IsEnabled(); end,
        name = DULL_RED_FONT_COLOR:WrapTextInColorCode('This module is disabled. All submodules are also disabled.'),
    };
    defaultOptionsTable.args.LibOpenRaid = {
        order = increment(),
        type = 'description',
        name = 'LibOpenRaid has been embedded into this addon, which allows various addons to use the same data sharing that Details! includes by default. This makes it a popular choice for fetching keystone information from your party/raid and guild members. Addons making use of this, include REKeys, PortaParty, and others.',
    };
    defaultOptionsTable.args.shareAlts = {
        order = increment(),
        type = 'toggle',
        name = 'Share alt keystones',
        desc = 'Allow submodules to share keystone information from your alts with others. Keystones are automatically forgotten each weekly reset.',
        get = function() return self.db.shareAlts; end,
        set = function(_, value) self.db.shareAlts = value; end,
    };
    defaultOptionsTable.args.modules = {
        order = increment(),
        type = 'group',
        name = 'Submodules - Each submodule emulates a different addon.',
        inline = true,
        args = {},
    };

    local defaultSubModuleOptions = {
        type = 'group',
        name = function(info)
            return info[#info - 1];
        end,
        args = {
            description = {
                order = 1,
                type = 'description',
                name = function(info)
                    local subModule = self:GetModule(info[#info - 1]);
                    return subModule.GetDescription and subModule:GetDescription() or '';
                end,
                hidden = function(info)
                    return '' == info.option.name(info)
                end,
            },
            disabledDueToAddon = {
                order = 2,
                type = 'description',
                name = function(info)
                    local subModule = self:GetModule(info[#info - 1]);
                    return string.format('This module is disabled because %s is loaded.', subModule.emulatedAddonName or '');
                end,
                hidden = function(info)
                    local subModule = self:GetModule(info[#info - 1]);
                    return not (subModule.emulatedAddonName and C_AddOns.IsAddOnLoaded(subModule.emulatedAddonName))
                end,
            },
            enable = {
                order = 2,
                name = 'Enable',
                desc = 'Enable this module',
                type = 'toggle',
                disabled = function(info)
                    local subModule = self:GetModule(info[#info - 1]);
                    return subModule.emulatedAddonName and C_AddOns.IsAddOnLoaded(subModule.emulatedAddonName);
                end,
                get = function(info) return self:IsSubModuleEnabled(info[#info - 1]); end,
                set = function(info, enabled) self:SetSubModuleState(info[#info - 1], enabled); end,
            },
        },
    };
    for subModuleName, subModule in pairs(self.modules) do
        local copy = CopyTable(defaultSubModuleOptions);
        self.db.moduleDB[subModuleName] = self.db.moduleDB[subModuleName] or {};
        local subIncrement = CreateCounter(3);
        local moduleOptions = subModule.GetOptions and subModule:GetOptions(copy, self.db.moduleDB[subModuleName], subIncrement) or copy;
        moduleOptions.name = subModule.GetName and subModule:GetName() or subModuleName;
        moduleOptions.order = increment();
        defaultOptionsTable.args.modules.args[subModuleName] = moduleOptions;
    end
end

function Module:SetSubModuleState(subModuleName, enabled)
    if enabled then
        self:EnableModule(subModuleName);
    else
        self:DisableModule(subModuleName);
    end
    self.db.modules[subModuleName] = enabled;
end

function Module:IsSubModuleEnabled(subModuleName)
    return self.db.modules[subModuleName] ~= false;
end

function Module:PLAYER_GUILD_UPDATE(unit)
    if unit ~= 'player' then return; end

    self.playerGuild = GetGuildInfo('player');
    self:UpdateKeystoneInfo();
end

function Module:UpdateKeystoneInfo()
    local keystoneMapID, keystoneLevel = KSUtil:GetOwnedKeystone();
    self.db.altStore[self.playerRealm] = self.db.altStore[self.playerRealm] or {};
    local realmDb = self.db.altStore[self.playerRealm];
    realmDb[self.playerName] = {
        name = self.playerName,
        mapID = keystoneMapID or 0,
        level = keystoneLevel or 0,
        class = self.playerClass,
        faction = self.playerFaction,
        guild = self.playerGuild,
        week = KSUtil:GetWeek(),
        timestamp = KSUtil:GetWeekTimestamp(),
        weeklyBest = KSUtil:GetWeeklyBest(),
    };
end

--- @class MPT_KeystoneSharingAltData
--- @field name string character name
--- @field mapID number 0 if no keystone
--- @field level number 0 if no keystone
--- @field class string Class file name
--- @field faction string English faction name: 'Alliance', 'Horde', or 'Neutral'
--- @field guild string guild name
--- @field week number
--- @field timestamp number
--- @field weeklyBest number 0 if none completed

--- @param sameGuildOnly boolean # if true, only characters in the same guild as the player are returned, and no guildless characters are returned
--- @return table<string, MPT_KeystoneSharingAltData> characterName -> data; only current realm & current week is returned, current character is also added
function Module:GetAltKeystones(sameGuildOnly)
    local realmDb = self.db.altStore[self.playerRealm];
    if not realmDb then return {}; end
    local alts = {};
    local currentWeek = KSUtil:GetWeek();
    for altName, altData in pairs(realmDb) do
        if
            altData.week == currentWeek
            and (self.db.shareAlts or altName == self.playerName)
            and (not sameGuildOnly or (altData.guild and altData.guild == self.playerGuild))
        then
            alts[altName] = CopyTable(altData);
        end
    end

    return alts;
end
