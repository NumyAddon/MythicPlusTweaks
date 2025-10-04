local _, MPT = ...;
--- @type MPT_Main
local Main = MPT.Main;
--- @type KeystoneSharingUtil
local KSUtil = MPT.KeystoneSharingUtil;

local ChatFrame_AddMessageEventFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter or ChatFrame_RemoveMessageEventFilter

--- @class MPT_ImproveKeystoneLink: AceModule
local Module = Main:NewModule('ImproveKeystoneLink');

local events = {
    CHAT_MSG_BATTLEGROUND = true,
    CHAT_MSG_BATTLEGROUND_LEADER = true,
    CHAT_MSG_BN_WHISPER = true,
    CHAT_MSG_BN_WHISPER_INFORM = true,
    CHAT_MSG_CHANNEL = true,
    CHAT_MSG_EMOTE = true,
    CHAT_MSG_GUILD = true,
    CHAT_MSG_INSTANCE_CHAT = true,
    CHAT_MSG_INSTANCE_CHAT_LEADER = true,
    CHAT_MSG_OFFICER = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true,
    CHAT_MSG_SAY = true,
    CHAT_MSG_WHISPER = true,
    CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_YELL = true,
    CHAT_MSG_LOOT = true,
};

local function Filter(_, _, message, ...) return false, Module:ReplaceChatMessage(message), ... end


function Module:OnEnable()
    for event in pairs(events) do
        ChatFrame_AddMessageEventFilter(event, Filter)
    end
end

function Module:OnDisable()
    for event in pairs(events) do
        ChatFrame_RemoveMessageEventFilter(event, Filter);
    end
end

function Module:GetDescription()
    return 'Replace keystone links without the dungeon name and level, with proper links. E.g. the link shown when downgrading or changing your keystone.';
end

function Module:GetName()
    return 'Improve Keystone Link';
end

--- plain text replacement
local function string_replace(text, search, replace)
    local start, finish = text:find(search, 1, true);
    if start then
        return string_replace(text:sub(1, start - 1) .. replace .. text:sub(finish + 1), search, replace);
    end

    return text;
end

local KEYSTONE_ITEM_LINK_PATTERN = '|Hitem:180653:.-|h%[.-%]|h';
function Module:ReplaceChatMessage(message)
    local original = message;
    for link in original:gmatch(KEYSTONE_ITEM_LINK_PATTERN) do
        local keystoneLink = KSUtil:ConvertKeystoneItemLinkToKeystoneLink(link);

        if keystoneLink then
            message = string_replace(message, link, keystoneLink);
        end
    end

    return message
end
