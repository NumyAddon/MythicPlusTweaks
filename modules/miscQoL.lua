local _, MPT = ...;
--- @type MPT_Main
local Main = MPT.Main;
--- @type MPT_Util
local Util = MPT.Util;
--- @type KeystoneSharingUtil
local KSUtil = MPT.KeystoneSharingUtil;

--- @class MPT_MiscQoL: AceModule,AceEvent-3.0,AceHook-3.0
local Module = Main:NewModule('miscQoL', 'AceEvent-3.0', 'AceHook-3.0');

local PREFIX = '<M+ Tweaks> ';
local QUERY = '!keys';
local HOVER_BLOCK_SETTING = 'removeHoverBlockFromLFGApplicationViewer';

function Module:OnEnable()
    self.keysCooldown = {};
    self:RegisterEvent('CHAT_MSG_GUILD', 'OnGuildMessage');
    self:RegisterEvent('CHAT_MSG_PARTY', 'OnPartyMessage');
    self:RegisterEvent('CHAT_MSG_PARTY_LEADER', 'OnPartyMessage');
    self:RegisterEvent('CHAT_MSG_RAID', 'OnRaidMessage');
    self:RegisterEvent('CHAT_MSG_RAID_LEADER', 'OnRaidMessage');
    self:RegisterEvent('CHAT_MSG_INSTANCE_CHAT', 'OnRaidMessage');
    self:RegisterEvent('CHAT_MSG_INSTANCE_CHAT_LEADER', 'OnRaidMessage');

    EventUtil.ContinueOnAddOnLoaded('Blizzard_ChallengesUI', function()
        self:SecureHookScript(ChallengesKeystoneFrame, 'OnShow', 'OnShowKeystoneFrame');
    end);
    RunNextFrame(function()
        self:OnSettingChange(HOVER_BLOCK_SETTING, self.db[HOVER_BLOCK_SETTING]);
    end);
end

function Module:OnDisable()
    self:UnregisterAllEvents();
    self:UnhookAll();
    self:OnSettingChange(HOVER_BLOCK_SETTING, false);
end

function Module:GetName()
    return 'Miscellaneous';
end

function Module:GetDescription()
    return 'Miscellaneous QoL Tweaks.';
end

function Module:GetOptions(defaultOptionsTable, db, increment)
    self.db = db;
    local defaults = {
        respondToParty = true,
        respondToRaid = true,
        respondToGuild = true,
        autoSlotKeystone = true,
        [HOVER_BLOCK_SETTING] = true,
    };
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local function get(info) return db[info[#info]]; end
    local function set(info, value)
        db[info[#info]] = value;
        self:OnSettingChange(info[#info], value);
    end

    defaultOptionsTable.args.keyResponder = {
        type = 'description',
        name = 'Respond to "!keys" in chat with your current keystone.',
        order = increment(),
    };
    defaultOptionsTable.args.respondToParty = {
        type = 'toggle',
        name = 'Respond to party',
        desc = 'Respond to "!keys" in party chat.',
        get = get,
        set = set,
        order = increment(),
    };
    defaultOptionsTable.args.respondToRaid = {
        type = 'toggle',
        name = 'Respond to raid',
        desc = 'Respond to "!keys" in raid chat.',
        get = get,
        set = set,
        order = increment(),
    };
    defaultOptionsTable.args.respondToGuild = {
        type = 'toggle',
        name = 'Respond to guild',
        desc = 'Respond to "!keys" in guild chat.',
        get = get,
        set = set,
        order = increment(),
    };
    defaultOptionsTable.args.spacer = {
        type = 'description',
        name = '',
        order = increment(),
    };
    defaultOptionsTable.args.autoSlotKeystone = {
        type = 'toggle',
        name = 'Auto slot keystone',
        desc = 'Automatically slot the keystone when clicking the Font of Power.',
        get = get,
        set = set,
        order = increment(),
    };
    defaultOptionsTable.args[HOVER_BLOCK_SETTING] = {
        type = 'toggle',
        name = 'View LFG Applicant info as non-leader',
        desc = 'Lets you see LFG Applicant info that is normally only visible to the group leader, by stopping blizzard from blocking the tooltip.',
        get = get,
        set = set,
        width = 'double',
        order = increment(),
    };

    return defaultOptionsTable;
end

--- @param setting string
---@param value any
function Module:OnSettingChange(setting, value)
    if setting == HOVER_BLOCK_SETTING then
        LFGListFrame.ApplicationViewer.UnempoweredCover:EnableMouse(not value)
        LFGListFrame.ApplicationViewer.UnempoweredCover:SetAlpha(value and 0.4 or 1)
    end
end

function Module:OnPartyMessage(_, msg)
    if not self.db.respondToParty then return; end
    self:ParseChat(msg, 'PARTY');
end

function Module:OnRaidMessage(event, msg)
    if not self.db.respondToRaid then return; end
    local channel = 'RAID';
    if event == 'CHAT_MSG_INSTANCE_CHAT' or event == 'CHAT_MSG_INSTANCE_CHAT_LEADER' then
        channel = 'INSTANCE_CHAT';
    end
    self:ParseChat(msg, channel);
end

function Module:OnGuildMessage(event, msg)
    if not self.db.respondToGuild then return; end
    self:ParseChat(msg, 'GUILD');
end

function Module:ParseChat(msg, channel)
    if not self.keysCooldown[channel] and strlower(msg) == QUERY then
        local link = KSUtil:GetKeystoneLink();
        if not link then return; end
        self.keysCooldown[channel] = true
        C_Timer.After(10, function() self.keysCooldown[channel] = false end);

        SendChatMessage(PREFIX .. link, channel);
    end
end

function Module:OnShowKeystoneFrame()
    if not self.db.autoSlotKeystone or C_ChallengeMode.HasSlottedKeystone() then return; end

    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemLink = C_Container.GetContainerItemLink(bag, slot);
            if itemLink and itemLink:match('|Hkeystone:') then
                local location = ItemLocation:CreateFromBagAndSlot(bag, slot);
                if C_ChallengeMode.CanUseKeystoneInCurrentMap(location) then
                    C_Container.PickupContainerItem(bag, slot);
                    if (CursorHasItem()) then
                        C_ChallengeMode.SlotKeystone();
                    end

                    return;
                end
            end
        end
    end
end
