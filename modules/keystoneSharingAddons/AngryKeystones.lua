--- @class MPT_NS
local MPT = select(2, ...);

--- @type MPT_Main
local Main = MPT.Main;

--- @type MPT_KeystoneSharing
--- @diagnostic disable-next-line: assign-type-mismatch
local ParentModule = Main:GetModule('KeystoneSharing-core');

--- @class MPT_AngryKeystones: NumyConfig_Module
local Module = ParentModule:NewModule('KeystoneSharing-AngryKeystones');

--- @type KeystoneSharingUtil
local KSUtil = MPT.KeystoneSharingUtil;

--[[
Prefix: AngryKeystones
Messages:
  -
    Name: ScheduleRequest
    Channel: PARTY
    Format: "Schedule|request"
    Usage: Sent by Angry Keystones to request the player's current keystone, reply with ScheduleResponse
  -
    Name: ScheduleResponse
    Channel: PARTY
    Format: "Schedule|%d:%d" or "Schedule|0" # mapID, level; 0 if no keystone
    Usage: Sent as a response to ScheduleRequest, and also after the keystone changes
--]]

Module.prefix = 'AngryKeystones';
Module.emulatedAddonName = 'AngryKeystones';
local playerRealm = select(2, UnitFullName("player")) or "";

function Module:OnEnable()
    if C_AddOns.IsAddOnLoaded(self.emulatedAddonName) then
        self.officialAddonLoaded = true;
        KSUtil:RegisterLibKeystone(self, function(...) self:OnLibKeystoneUpdate(...); end);

        return;
    end
    KSUtil:RegisterKeystoneUpdateCallback(self, self.OnKeystoneUpdate);
    KSUtil:RegisterAddonMessagePrefix(self.prefix);
    KSUtil:RegisterAddonMessageReceivedCallback(self.prefix, self, self.OnAddonMessageReceived);
end

function Module:OnDisable()
    KSUtil:UnregisterKeystoneUpdateCallback(self);
    if self.officialAddonLoaded then
        KSUtil:UnregisterLibKeystone(self);
    end
end

function Module:GetName()
    return 'Angry Keystones';
end

function Module:GetDescription()
    return 'Shares your keystone with party members who have the Angry Keystones addon.';
end

function Module:OnAddonMessageReceived(prefix, message, channel, sender)
    if 'Schedule|request' == message then
        self:SendCurrentKey();
    end
end

function Module:OnKeystoneUpdate()
    self:SendCurrentKey();
end

function Module:SendCurrentKey()
    local keystoneMapID, keystoneLevel = KSUtil:GetOwnedKeystone();
    if keystoneMapID then
        KSUtil:SendMessage(self.prefix, ('Schedule|%d:%d'):format(keystoneMapID, keystoneLevel), 'PARTY');
    else
        KSUtil:SendMessage(self.prefix, 'Schedule|0', 'PARTY');
    end
end

function Module:OnLibKeystoneUpdate(keyLevel, mapID, _, playerName)
    --- @diagnostic disable-next-line: undefined-global
    local scheduleModule = AngryKeystones and AngryKeystones.Modules and AngryKeystones.Modules.Schedule;
    if not scheduleModule then return; end
    if not playerName:find("-", 1, true) then
        playerName = playerName .. "-" .. playerRealm;
    end
    local message = ('%d:%d'):format(mapID, keyLevel);
    scheduleModule:ReceiveAddOnComm(message, nil, playerName);
end
