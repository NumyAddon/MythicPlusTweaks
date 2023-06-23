local _, MPT = ...;
--- @type Main
local Main = MPT.Main;

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
};

local function Filter(...) return Module:Filter(...) end


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
-- mapID, level, affix1, affix2, affix3, affix4
local KEYSTONE_LINK_FORMAT = '|Hkeystone:180653:%d:%d:%d:%d:%d:%d|h['.. CHALLENGE_MODE_KEYSTONE_HYPERLINK ..']|h';
function Module:Filter(_, _, message, ...)
    local original = message;
    for link in original:gmatch(KEYSTONE_ITEM_LINK_PATTERN) do
        local parts = strsplittable(':', (link:gsub('|Hitem:', '')));
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
            message = string_replace(
                message,
                link,
                KEYSTONE_LINK_FORMAT:format(mapID, level, affix1, affix2, affix3, affix4, mapName, level)
            );
        end
    end

    return false, message, ...
end
