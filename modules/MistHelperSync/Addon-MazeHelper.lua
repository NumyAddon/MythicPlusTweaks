--- @class MPT_NS
local ns = select(2, ...);

--[[
MAZEHELPER
    SendButtonID:
        syntax: `SendButtonID|${buttonID}|${state}|P${predictionState}`
        ${buttonID}: 1 -> 8
        ${state}: `ACTIVE` or `UNACTIVE` (not a typo)
        ${predictionState}: `ON` or `OFF`
    SendReset:
        syntax: `SendReset`
        sets all symbols to inactive
--]]

--- @class MPT_MistHelperSync_MazeHelper: MPT_MistHelperSyncImplementation
local MH = {
    name = 'MazeHelper',
    type = 'Addon',
    url = 'https://www.curseforge.com/wow/addons/maze-helper-mists-of-tirna-scithe',
};
local playerName, playerShortenedRealm = UnitFullName('player');
local playerNameWithRealm = playerName .. '-' .. playerShortenedRealm;

--- @type MPT_MistHelperSyncImplementation[]
ns.MistHelperSyncImplementations = ns.MistHelperSyncImplementations or {};
tinsert(ns.MistHelperSyncImplementations, MH);

local prefix = 'MAZEHELPER';
C_ChatInfo.RegisterAddonMessagePrefix(prefix);
local function GetPartyChatType()
    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and 'INSTANCE_CHAT' or 'PARTY';
end

function MH:SendButtonComms(buttonID, active)
    C_ChatInfo.SendAddonMessage(prefix, format('SendButtonID|%d|%s|POFF', buttonID, active and 'ACTIVE' or 'UNACTIVE'), GetPartyChatType());
end

function MH:OnButtonComms(buttonID, active, sender)
    if not ST_Maze_Helper or not ST_Maze_Helper.CHAT_MSG_ADDON then return; end

    if sender == playerNameWithRealm then
        sender = 'MythicPlusTweaks';
    end
    local message = format('SendButtonID|%d|%s|PON', buttonID, active and 'ACTIVE' or 'UNACTIVE');

    ST_Maze_Helper:CHAT_MSG_ADDON(prefix, message, nil, sender)
end

function MH:SendResetComms()
    C_ChatInfo.SendAddonMessage(prefix, 'SendReset', GetPartyChatType());
end

function MH:OnResetComms(sender)
    if not ST_Maze_Helper or not ST_Maze_Helper.CHAT_MSG_ADDON then return; end

    if sender == playerNameWithRealm then
        sender = 'MythicPlusTweaks';
    end

    ST_Maze_Helper:CHAT_MSG_ADDON(prefix, 'SendReset', nil, sender);
end

function MH:ListenToComms(buttonCallback, resetCallback)
    self.enabled = true;
    hooksecurefunc(C_ChatInfo, 'SendAddonMessage', function(...)
        if not self.enabled then return; end
        local msgPrefix, message = ...;
        if msgPrefix ~= prefix then return; end

        if message == 'SendReset' then
            resetCallback(playerNameWithRealm, true);
        elseif strfind(message, 'SendPassed') then
            -- ignore passed, let addons/WAs handle it themselves
        elseif strfind(message, 'SendButtonID') then
            local _, buttonID, state, _ = strsplit('|', message);
            buttonCallback(tonumber(buttonID), state == 'ACTIVE', playerNameWithRealm, true);
        end
    end);
    local f = CreateFrame('Frame');
    self.listenerFrame = f;
    f:RegisterEvent('CHAT_MSG_ADDON');
    f:SetScript('OnEvent', function(_, _, msgPrefix, message, _, sender)
        if msgPrefix ~= prefix or sender == playerName or sender == playerNameWithRealm then return; end

        if message == 'SendReset' then
            resetCallback(sender);
        elseif strfind(message, 'SendPassed') then
            -- ignore passed, let addons/WAs handle it themselves
        elseif strfind(message, 'SendButtonID') then
            local _, buttonID, state, _ = strsplit('|', message);
            buttonCallback(tonumber(buttonID), state == 'ACTIVE', sender);
        end
    end);
end

function MH:Enable()
    if not self.listenerFrame then return; end
    self.listenerFrame:RegisterEvent('CHAT_MSG_ADDON');
    self.enabled = true;
end

function MH:Disable()
    if not self.listenerFrame then return; end
    self.listenerFrame:UnregisterEvent('CHAT_MSG_ADDON');
    self.enabled = false;
end
