--- @class MPT_NS
local MPT = select(2, ...);

--- @type MPT_Main
local Main = MPT.Main;

--- @type MPT_KeystoneSharing
--- @diagnostic disable-next-line: assign-type-mismatch
local ParentModule = Main:GetModule('KeystoneSharing-core');

--- @class MPT_AstralKeys: NumyConfig_Module, AceEvent-3.0
local Module = ParentModule:NewModule('KeystoneSharing-AstralKeys', 'AceEvent-3.0');

--- @type KeystoneSharingUtil
local KSUtil = MPT.KeystoneSharingUtil;

--[[
Prefix: AstralKeys
Messages:
  -
    Name: Request
    Channel: GUILD
    Format: "request"
    Usage: Sent to request the player's current keystone, reply with Sync5

  -
    Name: UpdateWeekly
    Channel: GUILD
    Format: "updateWeekly %d" # weeklyBest
    Usage: Triggered by CHALLENGE_MODE_MAPS_UPDATE

  -
    Name: Update4
    Channel: BNetWhisper|WHISPER
    Format: "update4 %s:%s:%d:%d:%d:%d:%d" # Playername-Realm, PLAYERCLASS, mapID, level, weeklyBest, weekNr, factionID
    Notes: |
        format data is identical to Update8
        weekNr: Util:GetWeek()
        factionID: 0 = Alliance, 1 = Horde/Neutral
    Usage: Sent as a response to Request, and also to all friends after keystone changes

  -
    Name: Update8
    Channel: GUILD
    Format: "updateV8 %s:%s:%d:%d:%d:%d:%d" # Playername-Realm, PLAYERCLASS, mapID, level, weeklyBest, weekNr, factionID
    Notes: |
        format data is identical to Update4
        weekNr: Util:GetWeek()
        factionID: 0 = Alliance, 1 = Horde/Neutral
    Usage: Sent as a response to Request, and also after keystone changes

  -
    Name: Sync4
    Channel: BNetWhisper|WHISPER
    Format: "sync4 %s:%s:%d:%d:%d:%d:%d:%d_" # Playername-Realm, PLAYERCLASS, mapID, level, weekNr, timestamp, factionID, weeklyBest
    Notes: |
        the data segement is repeated for each alt character, trying to fit as many into a single message as is allowed
        timestamp: Util:GetWeekTimestamp()
    Usage: Sent as a response to BNetPing

  -
    Name: Sync5
    Channel: GUILD
    Format: "sync5 %s:%s:%d:%d:%d:%d:%d_" # Playername-Realm, PLAYERCLASS, mapID, level, weeklyBest, weekNr, timestamp
    Notes: |
        the data segement is repeated for each alt character, trying to fit as many into a single message as is allowed
        timestamp: Util:GetWeekTimestamp()
    Usage: Sent as a response to Request

  -
    Name: BNetPing
    Channel: BNetWhisper|WHISPER
    Format: "BNET_query ping"
    Usage: Sent to all friends, to check if the addon is installed, reply with BNetPingResponse and a Sync4

  -
    Name: BNetPingResponse
    Channel: BNetWhisper|WHISPER
    Format: "BNET_query response"
    Usage: Sent as a response to BNetPing

  -
    Name: VersionRequest
    Channel: GUILD
    Format: "versionRequest"
    Usage: Requests the addon version, reply with VersionResponse

  -
    Name: VersionResponse
    Channel: GUILD
    Format: "versionResponse %d.%d:%s" # mayor, minor, PLAYERCLASS
    Usage: Sent as a response to VersionRequest, we'll just send 0.0
--]]

Module.prefix = 'AstralKeys';
Module.emulatedAddonName = 'AstralKeys';

function Module:OnEnable()
    self.playerName = UnitName('player');
    self.playerRealm = GetRealmName():gsub("%s+", "");
    self.playerFullName = self.playerName .. '-' .. self.playerRealm;
    self.playerClass = select(2, UnitClass('player'));
    self.playerFaction = UnitFactionGroup('player') == 'Alliance' and 0 or 1; -- 0 = Alliance, 1 = Horde/Neutral

    if C_AddOns.IsAddOnLoaded(self.emulatedAddonName) then
        self.officialAddonLoaded = true;

        return;
    end
    KSUtil:RegisterAddonMessagePrefix(self.prefix);
    KSUtil:RegisterAddonMessageReceivedCallback(self.prefix, self, self.OnAddonMessageReceived);
    KSUtil:RegisterKeystoneUpdateCallback(self, self.OnKeystoneUpdate);
    self:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE');
end

function Module:OnDisable()
    KSUtil:UnregisterKeystoneUpdateCallback(self);
    KSUtil:UnregisterAddonMessageReceivedCallback(self.prefix, self);
    self:UnregisterEvent('CHALLENGE_MODE_MAPS_UPDATE');
end

function Module:GetName()
    return 'Astral Keys';
end

function Module:GetDescription()
    return 'Exposes your keystone to players who have the Astral Keys addon.';
end

local function startsWith(str, start)
    return str:sub(1, #start) == start;
end
function Module:OnAddonMessageReceived(prefix, message, channel, sender)
    if 'request' == message and 'GUILD' == channel then
        self:SendFullSyncToGuild();
    elseif 'versionRequest' == message and 'GUILD' == channel then
        KSUtil:SendMessage(self.prefix, ('versionResponse %d.%d:%s'):format(0, 0, self.playerClass), 'GUILD');
    elseif startsWith(message, 'BNET_query ') then
        if message:find('ping') then
            KSUtil:SendMessage(self.prefix, 'BNET_query response', channel, sender);
        end
        self:SendFullSyncToPlayer(channel, sender);
    end
end

function Module:CHALLENGE_MODE_MAPS_UPDATE()
    local weeklyBest = KSUtil:GetWeeklyBest();
    KSUtil:SendMessage(self.prefix, ('updateWeekly %d'):format(weeklyBest), 'GUILD');
end

function Module:OnKeystoneUpdate()
    self:SendCurrentKeyToGuild();
    self:SendCurrentKeyToFriends();
end

function Module:SendCurrentKeyToGuild()
    if not IsInGuild() then return; end

    local message = self:MakeUpdate8Message();
    KSUtil:SendMessage(self.prefix, message, 'GUILD');
end

function Module:SendCurrentKeyToFriends()
    local message = self:MakeUpdate4Message();
    for _, friend in ipairs(KSUtil:GetBNetFriendList()) do
        KSUtil:SendMessage(self.prefix, message, KSUtil.BNET_WHISPER_CHANNEL, friend.gameAccountID);
    end
    for _, friend in ipairs(KSUtil:GetFriendList()) do
        KSUtil:SendMessage(self.prefix, message, 'WHISPER', friend.name);
    end
end

function Module:SendFullSyncToGuild()
    if not IsInGuild() then return; end

    local messages = self:MakeSync5Messages(KSUtil.CHARACTER_LIMIT, true);
    for _, message in ipairs(messages) do
        KSUtil:SendMessage(self.prefix, message, 'GUILD');
    end
end

function Module:SendFullSyncToPlayer(channel, target)
    local messages = self:MakeSync4Messages(channel == KSUtil.BNET_WHISPER_CHANNEL and KSUtil.CHARACTER_LIMIT_BNET or KSUtil.CHARACTER_LIMIT);
    for _, message in ipairs(messages) do
        KSUtil:SendMessage(self.prefix, message, channel, target);
    end
end

function Module:MakeUpdate4Message()
    -- the messages are identical, besides the prefix
    return 'update4' .. self:MakeUpdate8Message():sub(#'updateV8' + 1);
end

function Module:MakeUpdate8Message()
    local keystoneMapID, keystoneLevel = KSUtil:GetOwnedKeystone();
    local weeklyBest = KSUtil:GetWeeklyBest();
    local weekNr = KSUtil:GetWeek();

    return ('updateV8 %s:%s:%d:%d:%d:%d:%d'):format(
        self.playerName .. '-' .. self.playerRealm,
        self.playerClass,
        keystoneMapID or 0,
        keystoneLevel or 0,
        weeklyBest,
        weekNr,
        self.playerFaction
    );
end

function Module:MakeSync4Messages(charLimit, sameGuildOnly)
    local altDataList = ParentModule:GetAltKeystones(sameGuildOnly);

    local messages = {};
    for altName, altData in pairs(altDataList) do
        --Format: "sync4 %s:%s:%d:%d:%d:%d:%d:%d_" # Playername-Realm, PLAYERCLASS, mapID, level, weekNr, timestamp, factionID, weeklyBest
        tinsert(messages, ('%s:%s:%d:%d:%d:%d:%d:%d_'):format(
            altName .. '-' .. self.playerRealm,
            altData.class,
            altData.mapID,
            altData.level,
            altData.week,
            altData.timestamp,
            altData.faction == 'Alliance' and 0 or 1,
            altData.weeklyBest
        ));
    end
    local messagePrefix = 'sync4 ';

    return self:ConcatMessages(messagePrefix, messages, charLimit);
end

function Module:MakeSync5Messages(charLimit, sameGuildOnly)
    local altDataList = ParentModule:GetAltKeystones(sameGuildOnly);

    local messages = {};
    for altName, altData in pairs(altDataList) do
        --Format: "sync5 %s:%s:%d:%d:%d:%d:%d_" # Playername-Realm, PLAYERCLASS, mapID, level, weeklyBest, weekNr, timestamp
        tinsert(messages, ('%s:%s:%d:%d:%d:%d:%d_'):format(
            altName .. '-' .. self.playerRealm,
            altData.class,
            altData.mapID,
            altData.level,
            altData.weeklyBest,
            altData.week,
            altData.timestamp
        ));
    end
    local messagePrefix = 'sync5 ';

    return self:ConcatMessages(messagePrefix, messages, charLimit);
end

function Module:ConcatMessages(messagePrefix, messages, charLimit)
    if #messages == 0 then return {}; end

    local effectiveCharLimit = charLimit - #messagePrefix;
    local result = {};
    local currentMessage = messagePrefix;
    for _, message in ipairs(messages) do
        if #message > effectiveCharLimit then
            error('Message too long: ' .. message);
        end
        if #currentMessage + #message > charLimit then
            tinsert(result, currentMessage);
            currentMessage = messagePrefix;
        end
        currentMessage = currentMessage .. message;
    end
    tinsert(result, currentMessage);

    return result;
end
