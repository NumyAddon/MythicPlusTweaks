--- @class MPT_NS
local MPT = select(2, ...);
local Main = MPT.Main;
local Util = MPT.Util;
local KSUtil = MPT.KeystoneSharingUtil;

local SendChatMessage = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage

--- @class MPT_MiscQoL: NumyConfig_Module,NumyAceEvent-3.0,AceHook-3.0
local Module = Main:NewModule('miscQoL', 'NumyAceEvent-3.0', 'AceHook-3.0');

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

    Util:OnChallengesUILoad(function()
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

--- @param configBuilder NumyConfigBuilder
--- @param db MPT_MiscQoL_Settings
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class MPT_MiscQoL_Settings
    local defaults = {
        respondToParty = true,
        respondToRaid = true,
        respondToGuild = true,
        autoSlotKeystone = true,
        [HOVER_BLOCK_SETTING] = true,
    };
    configBuilder:SetDefaults(defaults, true);
    --- @param setting AddOnSettingMixin
    local function callback(setting, value)
        self:OnSettingChange(setting.variableKey, value);
    end
    -- key responder
    do
        local text = configBuilder:MakeText('Respond to "!keys" in chat with your current keystone.', 2);
        configBuilder:MakeCheckbox(
            'Respond to party',
            'respondToParty',
            'Respond to "!keys" in party chat.',
            callback
        ):SetParentInitializer(text);
        configBuilder:MakeCheckbox(
            'Respond to raid',
            'respondToRaid',
            'Respond to "!keys" in raid chat.',
            callback
        ):SetParentInitializer(text);
        configBuilder:MakeCheckbox(
            'Respond to guild',
            'respondToGuild',
            'Respond to "!keys" in guild chat.',
            callback
        ):SetParentInitializer(text);
    end
    configBuilder:MakeCheckbox(
        'Auto slot keystone',
        'autoSlotKeystone',
        'Automatically slot the keystone when clicking the Font of Power.',
        callback
    );
    configBuilder:MakeCheckbox(
        'View LFG Applicant info as non-leader',
        HOVER_BLOCK_SETTING,
        'Lets you see LFG Applicant info that is normally only visible to the group leader, by stopping blizzard from blocking the tooltip.',
        callback
    );
end

--- @param setting string
--- @param value any
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
    if issecretvalue(msg) then return; end
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
