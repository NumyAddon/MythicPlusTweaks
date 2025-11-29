--- @class MPT_NS
local MPT = select(2, ...);
local Main = MPT.Main;
local Data = MPT.Data;
local Util = MPT.Util;
local KSUtil = MPT.KeystoneSharingUtil;

local SendChatMessage = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage

--- @class MPT_MiscQoL: NumyConfig_Module,AceEvent-3.0,AceHook-3.0
local Module = Main:NewModule('miscQoL', 'AceEvent-3.0', 'AceHook-3.0');

local PREFIX = '<M+ Tweaks> ';
local QUERY = '!keys';
local HOVER_BLOCK_SETTING = 'removeHoverBlockFromLFGApplicationViewer';

--- returns the remaining cooldown of a spell
--- @param spellID number
--- @return number
local function GetRemainingSpellCooldown(spellID)
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID);
    if not cooldownInfo then return 0; end
    local start, duration = cooldownInfo.startTime, cooldownInfo.duration;

    return start + duration - GetTime();
end

function Module:OnInitialize()
    self:InitTeleportOverlayButton();
    self.activeActivityID = nil;
    self:RegisterEvent('LFG_LIST_ACTIVE_ENTRY_UPDATE');
end

function Module:OnEnable()
    self.lfgMessageCooldown = false;
    self:RegisterEvent('LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS');
    self:RegisterEvent('LFG_LIST_JOINED_GROUP');
    for _, frameName in pairs(CHAT_FRAMES) do
        local frame = _G[frameName];
        self:SecureHookScript(frame, 'OnHyperlinkEnter');
        self:SecureHookScript(frame, 'OnHyperlinkLeave');
    end
    self:SecureHook('FloatingChatFrame_SetupScrolling', function(frame)
        self:SecureHookScript(frame, 'OnHyperlinkEnter');
        self:SecureHookScript(frame, 'OnHyperlinkLeave');
    end);
    if Chattynator and Chattynator.API and Chattynator.API.GetHyperlinkHandler and Chattynator.API.GetHyperlinkHandler() then
        self:SecureHookScript(Chattynator.API.GetHyperlinkHandler(), 'OnHyperlinkEnter');
        self:SecureHookScript(Chattynator.API.GetHyperlinkHandler(), 'OnHyperlinkLeave');
    end

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
    self:RegisterEvent('LFG_LIST_ACTIVE_ENTRY_UPDATE');
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
        groupFormedMessage = true,
        groupFormedMessageKeystoneOnly = true,
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
    local groupFormed = configBuilder:MakeCheckbox(
        'LFG group formed/joined message',
        'groupFormedMessage',
        'Show a reminder message in chat when you join a group or when the group is full, showing the activity you joined, with a clickable teleport link if available.',
        callback
    );
    configBuilder:MakeCheckbox(
        'Only for Mythic+',
        'groupFormedMessageKeystoneOnly',
        'Only show the reminder for m+ groups.',
        callback
    ):SetParentInitializer(groupFormed, function() return db.groupFormedMessage; end);
end

function Module:InitTeleportOverlayButton()
    self.teleportOverlayButton = CreateFrame('Button', nil, UIParent, 'InsecureActionButtonTemplate');
    local button = self.teleportOverlayButton;
    button:Hide();
    button:SetAttribute('type', 'spell');
    button:SetFrameStrata('TOOLTIP');
    button:SetAllPoints(nil);
    button:RegisterForClicks('AnyUp', 'AnyDown');
    button:SetPropagateMouseMotion(true);
end

function Module:SetShownTeleportOverlayButton(shown, spellID)
    local button = self.teleportOverlayButton;
    button:SetAttribute('spell', spellID);
    button:SetShown(shown);
end

--- @param setting string
--- @param value any
function Module:OnSettingChange(setting, value)
    if setting == HOVER_BLOCK_SETTING then
        LFGListFrame.ApplicationViewer.UnempoweredCover:EnableMouse(not value)
        LFGListFrame.ApplicationViewer.UnempoweredCover:SetAlpha(value and 0.4 or 1)
    end
end

function Module:LFG_LIST_ACTIVE_ENTRY_UPDATE()
    local activeEntryInfo = C_LFGList.GetActiveEntryInfo();
    if activeEntryInfo then
        self.activeActivityID = activeEntryInfo.activityIDs[1];
    end
end

local joinedMessage = 'You have joined a group for %s |cnNORMAL_FONT_COLOR:%s|r.';
local formedMessage = 'Your group for %s has been formed.';
local teleportMessage = '|cff71d5ff|Haddon:MythicPlusTweaks:teleport-spell:%d|h[Click here to teleport to the instance.]|h|r';
function Module:LFG_LIST_JOINED_GROUP(_, searchResultID, groupName)
    if not self.db.groupFormedMessage then return; end
    local searchResultInfo = C_LFGList.GetSearchResultInfo(searchResultID);
    local activityID = searchResultInfo.activityIDs[1];
    local mapID, fullName, isMythicPlusActivity = Util:GetMapInfoByLfgActivityID(activityID);
    if self.db.groupFormedMessageKeystoneOnly and not isMythicPlusActivity then return; end

    local spellID = mapID and self:GetSpellIDForMapID(mapID);

    Main:Print(joinedMessage:format(fullName, groupName), spellID and teleportMessage:format(spellID) or '');

    self.lfgMessageCooldown = true;
    C_Timer.After(10, function() self.lfgMessageCooldown = false; end);
end

function Module:LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS()
    if not self.db.groupFormedMessage or not self.activeActivityID or self.lfgMessageCooldown then return; end
    local mapID, fullName, isMythicPlusActivity = Util:GetMapInfoByLfgActivityID(self.activeActivityID);
    if self.db.groupFormedMessageKeystoneOnly and not isMythicPlusActivity then return; end

    local spellID = mapID and self:GetSpellIDForMapID(mapID);

    Main:Print(formedMessage:format(fullName), spellID and teleportMessage:format(spellID) or '');
end

--- @param mapID number
--- @return number|nil spellID # nil if unknown or on cooldown
function Module:GetSpellIDForMapID(mapID)
    local mapKey = Data.Portals.maps[mapID];
    if not mapKey then return nil; end

    local spell = Data.Portals.dungeonPortals[mapKey];
    local spellID = spell and spell:spellID();
    if not spell or not spell:available() or GetRemainingSpellCooldown(spellID) > 3 then return nil; end

    return spellID;
end

function Module:OnHyperlinkEnter(frame, link)
    local linkType, part1, part2, part3 = string.split(":", link);
    if linkType == 'addon' and part1 == 'MythicPlusTweaks' and part2 == 'teleport-spell' then
        local spellID = tonumber(part3);
        GameTooltip:SetOwner(frame, 'ANCHOR_CURSOR');
        GameTooltip:SetSpellByID(spellID);
        GameTooltip_AddInstructionLine(GameTooltip, 'Click to teleport to the instance.');
        GameTooltip:Show();
        self:SetShownTeleportOverlayButton(true, spellID);
        self.tooltipShown = true;
    end
end

function Module:OnHyperlinkLeave()
    if self.tooltipShown then
        GameTooltip:Hide();
        self:SetShownTeleportOverlayButton(false);
    end
    self.tooltipShown = false;
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
