local _, MPT = ...
--- @class KeystoneSharingUtil
local Util = {};
MPT.KeystoneSharingUtil = Util;
KSUtil = Util;

local BNSendGameData = C_BattleNet and C_BattleNet.SendGameData or BNSendGameData

local IS_LEMIX = PlayerGetTimerunningSeasonID() == 2;

local CTL = ChatThrottleLib;

Util.BNET_WHISPER_CHANNEL = 'BNET_WHISPER';
Util.CHARACTER_LIMIT = 255;
Util.CHARACTER_LIMIT_BNET = 4000; -- the real limit is documented to be 4078, but we'll just round it down a little

Util.lockedAt = nil;
Util.lockedKeystoneMapID = nil;
Util.lockedKeystoneLevel = nil;
--- @type table<number, table<number, string>> [mapID] = { [keystoneLevel] = keystoneLink }
Util.keystoneLinkCache = {};

--- @return number? keystoneChallengeMapID
--- @return number? keystoneLevel
function Util:GetOwnedKeystone()
    if self.lockedAt then
        local timeSinceLocked = GetTime() - self.lockedAt;
        if timeSinceLocked < 3 then -- it can take a few seconds for the C_MythicPlus API to update after a keystone is changed
            return self.lockedKeystoneMapID, self.lockedKeystoneLevel;
        else
            self.lockedAt = nil;
            self.lockedKeystoneMapID = nil;
            self.lockedKeystoneLevel = nil;
        end
    end
    local keystoneMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID();
    local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel();

    if keystoneMapID and keystoneLevel then
        return keystoneMapID, keystoneLevel;
    end
end

function Util:GetKeystoneLink()
    if not IS_LEMIX then
        local mapID, level = self:GetOwnedKeystone();
        if not mapID or not level then
            return nil;
        end
        if self.keystoneLinkCache[mapID] and self.keystoneLinkCache[mapID][level] then
            return self.keystoneLinkCache[mapID][level];
        end
    end

    local keyLink;

    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot);
            local itemID = info and info.itemID;
            local hyperlink = info and info.hyperlink;
            if itemID and hyperlink and C_Item.IsItemKeystoneByID(itemID) then
                keyLink = hyperlink;
                local keyMapID, keyLevel = self:GetMapIDAndLevelFromKeystoneLink(hyperlink);
                if keyMapID and keyLevel then
                    self.keystoneLinkCache[keyMapID] = self.keystoneLinkCache[keyMapID] or {};
                    self.keystoneLinkCache[keyMapID][keyLevel] = hyperlink;
                end
                break;
            end
        end
    end

    return keyLink;
end

---@param link string either an item link or a keystone link
---@return number|nil mapID
---@return number|nil level
function Util:GetMapIDAndLevelFromKeystoneLink(link)
    local linkType, data = LinkUtil.ExtractLink(link);
    local mapID, level;
    local parts = strsplittable(':', data);
    if linkType == 'item' then
        local numBonusIDs = tonumber(parts[13]) or 0;
        local offset = 14 + numBonusIDs;
        local numModifiers = tonumber(parts[offset]) or 0;
        for i = (offset + 1), (offset + numModifiers * 2), 2 do
            local modifierID = tonumber(parts[i]) or 0;
            local modifierValue = tonumber(parts[i + 1]) or 0;
            if modifierID == Enum.ItemModification.KeystonePowerLevel then
                level = modifierValue;
            elseif modifierID == Enum.ItemModification.KeystoneMapChallengeModeID then
                mapID = modifierValue;
            end
        end
    elseif linkType == 'keystone' then
        mapID = tonumber(parts[2]) or 0;
        level = tonumber(parts[3]) or 0;
    end

    return mapID, level;
end

-- mapID, level, affix1, affix2, affix3, affix4
local KEYSTONE_LINK_FORMAT = '|cnIQ4:|Hkeystone:180653:%d:%d:%d:%d:%d:%d:0|h[' .. CHALLENGE_MODE_KEYSTONE_HYPERLINK .. ']|h|r';
--- @param itemLink string keystone item link
--- @return string|nil keystoneLink
function Util:ConvertKeystoneItemLinkToKeystoneLink(itemLink)
    local _, data = LinkUtil.ExtractLink(itemLink);
    local parts = strsplittable(':', data);
    local numBonusIDs = tonumber(parts[13]) or 0;
    local offset = 14 + numBonusIDs;
    local numModifiers = tonumber(parts[offset]) or 0;
    local mapID, level;
    local affix1, affix2, affix3, affix4 = 0, 0, 0, 0;
    for i = (offset + 1), (offset + numModifiers * 2), 2 do
        local modifierID = tonumber(parts[i]) or 0;
        local modifierValue = tonumber(parts[i + 1]) or 0;
        if modifierID == Enum.ItemModification.KeystonePowerLevel then
            level = modifierValue;
        elseif modifierID == Enum.ItemModification.KeystoneMapChallengeModeID then
            mapID = modifierValue;
        elseif modifierID == Enum.ItemModification.KeystoneAffix0 then
            affix1 = modifierValue;
        elseif modifierID == Enum.ItemModification.KeystoneAffix01 then
            affix2 = modifierValue;
        elseif modifierID == Enum.ItemModification.KeystoneAffix02 then
            affix3 = modifierValue;
        elseif modifierID == Enum.ItemModification.KeystoneAffix03 then
            affix4 = modifierValue;
        end
    end

    if level and mapID then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID);
        return KEYSTONE_LINK_FORMAT:format(mapID, level, affix1, affix2, affix3, affix4, mapName, level)
    end
end

function Util:GetWeeklyBest()
    local weeklyBest = 0;
    local runHistory = C_MythicPlus.GetRunHistory(false, true);

    for _, entry in ipairs(runHistory) do
        if entry.thisWeek and entry.level > weeklyBest then
            weeklyBest = entry.level;
        end
    end

    return weeklyBest;
end

--- @return FriendInfo[]
function Util:GetFriendList()
    local friendList = {};
    local numFriends = C_FriendList.GetNumFriends();

    for i = 1, numFriends do
        local friendInfo = C_FriendList.GetFriendInfoByIndex(i);
        if friendInfo.connected then
            tinsert(friendList, friendInfo);
        end
    end

    return friendList;
end

function Util:GetBNetFriendList()
    local friendList = {};
    local numFriends = BNGetNumFriends();

    for i = 1, numFriends do
        for gameIndex = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
            local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, gameIndex);
            if gameAccountInfo and gameAccountInfo.clientProgram == BNET_CLIENT_WOW and gameAccountInfo.wowProjectID == WOW_PROJECT_MAINLINE then
                tinsert(friendList, {
                    gameAccountID = gameAccountInfo.gameAccountID,
                });
            end
        end
    end

    return friendList
end

 local bnetMessageQueue = {};
--- @param prefix string
--- @param message string
--- @param channel string
--- @param target nil|string|number
function Util:SendMessage(prefix, message, channel, target)
    if
        (channel == "PARTY" and not IsInGroup(LE_PARTY_CATEGORY_HOME))
        or (channel == "RAID" and not IsInRaid(LE_PARTY_CATEGORY_HOME))
        or (channel == "INSTANCE" and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInRaid(LE_PARTY_CATEGORY_INSTANCE))
        or (channel == "GUILD" and not IsInGuild())
    then
        return;
    end
    if channel == self.BNET_WHISPER_CHANNEL then
        tinsert(bnetMessageQueue, {
            prefix = prefix,
            message = message,
            target = target,
        });

        return;
    end
    CTL:SendAddonMessage('NORMAL', prefix, message, channel, target);
end
do
    local messageFrame = CreateFrame('Frame');
    messageFrame:SetScript('OnUpdate', function(self, elapsed)
        if #bnetMessageQueue == 0 then return; end
        local throttle = 1; -- 1 message per second
        self.throttle = (self.throttle or 0) + elapsed;
        if self.throttle > throttle then
            self.throttle = 0;
            local message = tremove(bnetMessageQueue, 1);
            if message then
                BNSendGameData(message.target, message.prefix, message.message);
            end
        end
    end);
end

local addonMessageReceivedRegistry = {};
function Util:RegisterAddonMessageReceivedCallback(prefix, owner, callback)
    addonMessageReceivedRegistry[prefix] = addonMessageReceivedRegistry[prefix] or {};
    addonMessageReceivedRegistry[prefix][owner] = callback;
end

function Util:UnregisterAddonMessageReceivedCallback(prefix, owner)
    if addonMessageReceivedRegistry[prefix] then
        addonMessageReceivedRegistry[prefix][owner] = nil;
    end
end

--- @param prefix string
function Util:RegisterAddonMessagePrefix(prefix)
    C_ChatInfo.RegisterAddonMessagePrefix(prefix);
end

local keystoneUpdate = {registry = {}, registrarCount = 0};
local startListeningForKeystoneUpdates, stopListeningForKeystoneUpdates;
function Util:RegisterKeystoneUpdateCallback(owner, callback)
    if 0 == keystoneUpdate.registrarCount then
        startListeningForKeystoneUpdates();
    end
    if not keystoneUpdate.registry[owner] then
        keystoneUpdate.registrarCount = keystoneUpdate.registrarCount + 1;
    end
    keystoneUpdate.registry[owner] = callback;
end

function Util:UnregisterKeystoneUpdateCallback(owner)
    if keystoneUpdate.registry[owner] then
        keystoneUpdate.registry[owner] = nil;
        keystoneUpdate.registrarCount = keystoneUpdate.registrarCount - 1;
    end
    if 0 == keystoneUpdate.registrarCount then
        stopListeningForKeystoneUpdates();
    end
end

local initializeTime = {}
initializeTime[GetCurrentRegion()] = 1500390000 -- US Tuesday at reset (default)
initializeTime[3] = 1500447600 -- EU Wednesday at reset
initializeTime[4] = 1500505200 -- TW Thursday at reset
function Util:GetWeek()
    return math.floor((GetServerTime() - initializeTime[GetCurrentRegion()]) / 604800);
end

function Util:GetWeekTimestamp()
    return GetServerTime() - initializeTime[GetCurrentRegion()] - (604800 * Util:GetWeek());
end

do
    --- @class KeystoneSharingUtilEventFrame: Frame
    local frame = CreateFrame('Frame');
    frame.lastUpdate = 0;
    frame.lastKnownKeystoneMapID = 0;
    frame.lastKnownKeystoneLevel = 0;

    frame:SetScript('OnEvent', function(self, event, ...) self[event](self, ...); end);
    frame:RegisterEvent('CHAT_MSG_ADDON');
    frame:RegisterEvent('BN_CHAT_MSG_ADDON');
    function frame:CHAT_MSG_ADDON(prefix, message, channel, sender)
        if addonMessageReceivedRegistry[prefix] then
            for owner, callback in pairs(addonMessageReceivedRegistry[prefix]) do
                securecallfunction(callback, owner, prefix, message, channel, sender);
            end
        end
    end

    function frame:BN_CHAT_MSG_ADDON(prefix, message, _, sender)
        if addonMessageReceivedRegistry[prefix] then
            for owner, callback in pairs(addonMessageReceivedRegistry[prefix]) do
                securecallfunction(callback, owner, prefix, message, Util.BNET_WHISPER_CHANNEL, sender);
            end
        end
    end

    function frame:BAG_UPDATE_DELAYED()
        self:Show();
    end

    function frame:ITEM_CHANGED(fromItem, toItem)
        local itemID = C_Item.GetItemIDForItemInfo(toItem);
        if C_Item.IsItemKeystoneByID(itemID) then
            local mapID, level = Util:GetMapIDAndLevelFromKeystoneLink(toItem);

            if mapID and level and (mapID ~= self.lastKnownKeystoneMapID or level ~= self.lastKnownKeystoneLevel) then
                self:Hide()
                self.lastUpdate = GetTime();
                self.lastKnownKeystoneMapID = mapID;
                self.lastKnownKeystoneLevel = level;
                Util.lockedKeystoneMapID = mapID;
                Util.lockedKeystoneLevel = level;
                Util.lockedAt = GetTime();
                Util.keystoneLinkCache[mapID] = Util.keystoneLinkCache[mapID] or {};
                Util.keystoneLinkCache[mapID][level] = Util.keystoneLinkCache[mapID][level] or Util:ConvertKeystoneItemLinkToKeystoneLink(toItem);
                RunNextFrame(function()
                    for owner, callback in pairs(keystoneUpdate.registry) do
                        securecallfunction(callback, owner, mapID, level);
                    end
                end);
            end
        end
    end

    function frame:OnUpdate()
        if (GetTime() - self.lastUpdate) < 2 then return; end

        self:CheckKeystones();
    end

    function frame:CheckKeystones()
        self:Hide();
        self.lastUpdate = GetTime();

        local keystoneMapID, keystoneLevel = Util:GetOwnedKeystone();
        if keystoneMapID ~= self.lastKnownKeystoneMapID or keystoneLevel ~= self.lastKnownKeystoneLevel then
            self.lastKnownKeystoneMapID = keystoneMapID;
            self.lastKnownKeystoneLevel = keystoneLevel;
            RunNextFrame(function()
                for owner, callback in pairs(keystoneUpdate.registry) do
                    securecallfunction(callback, owner, keystoneMapID, keystoneLevel);
                end
            end);
        end
    end

    function startListeningForKeystoneUpdates()
        frame:RegisterEvent('BAG_UPDATE_DELAYED');
        frame:RegisterEvent('ITEM_CHANGED');
        frame:SetScript('OnUpdate', frame.OnUpdate);
    end

    function stopListeningForKeystoneUpdates()
        frame:UnregisterEvent('BAG_UPDATE_DELAYED');
        frame:UnregisterEvent('ITEM_CHANGED');
        frame:SetScript('OnUpdate', nil);
    end
end
