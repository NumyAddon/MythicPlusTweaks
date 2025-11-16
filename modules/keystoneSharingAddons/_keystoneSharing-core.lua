--- @class MPT_NS
local MPT = select(2, ...);
local Main = MPT.Main;
local KSUtil = MPT.KeystoneSharingUtil;

--- @class MPT_KeystoneSharing: MPT_Module, AceEvent-3.0
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

--- @param configBuilder MPT_ConfigBuilder
--- @param db MPT_KeystoneSharingDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class MPT_KeystoneSharingDB
    local defaults = {
        modules = {},
        moduleDB = {},
        shareAlts = true,
        altStore = {},
    };
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeText(
        DULL_RED_FONT_COLOR:WrapTextInColorCode('This module is disabled. All submodules are also disabled.')
    ):AddShownPredicate(function() return not self:IsEnabled(); end);
    configBuilder:MakeText(WHITE_FONT_COLOR:WrapTextInColorCode(
        'LibOpenRaid has been embedded into this addon, which allows various addons to use the same data sharing that Details! includes by default. This makes it a popular choice for fetching keystone information from your party/raid and guild members. Addons making use of this, include REKeys, PortaParty, and others.'
    ), 1);
    configBuilder:MakeCheckbox(
        'Share alt keystones',
        'shareAlts',
        'Allow submodules to share keystone information from your alts with others. Keystones are automatically forgotten each weekly reset.'
    );
    local subModules = configBuilder:MakeText('Submodules - Each submodule emulates a different addon.', 1);
    for subModuleName, subModule in self:IterateModules() do
        --- @type MPT_KeystoneSharingModule
        local subModule = subModule;
        configBuilder:MakeCheckbox(
            subModule:GetName(),
            subModuleName,
            subModule:GetDescription(),
            function(_, value) self:SetSubModuleState(subModuleName, value); end,
            true,
            self.db.modules
        ):AddModifyPredicate(function() return not C_AddOns.IsAddOnLoaded(subModule.emulatedAddonName); end);
        configBuilder:MakeText(WHITE_FONT_COLOR:WrapTextInColorCode(
            string.format('This module is disabled because %s is loaded.', subModule.emulatedAddonName)
        ), 3):AddShownPredicate(function() return C_AddOns.IsAddOnLoaded(subModule.emulatedAddonName); end);
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
