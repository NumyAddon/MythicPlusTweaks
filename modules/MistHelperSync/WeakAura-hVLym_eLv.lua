--- @class MPT_NS
local ns = select(2, ...);

--[[
Tirna Ver2
    `0 1 0 0 ${button}` - `0 1 1 1 ${button}` - `0 0 0 2 ${button}` - `0 0 1 3 ${button}`
    `1 1 0 4 ${button}` - `1 1 1 5 ${button}` - `1 0 0 6 ${button}` - `1 0 1 7 ${button}`
    ${button}: `LeftButton` = activate; `RightButton` = deactivate
    reset: `9 9 9 9` - version check is almost the same: `9 9 9 9v${versionNr}`
--]]

--- @class MPT_MistHelperSync_WeakAuraHelperV2: MPT_MistHelperSyncImplementation
local MH = {
    name = 'Mists of Tirna Scithe maze guessing game V2',
    type = 'WeakAura',
    url = 'https://wago.io/hVLym_eLv',
};
local playerName, playerShortenedRealm = UnitFullName('player');
local playerNameWithRealm = playerName .. '-' .. playerShortenedRealm;

--- @type MPT_MistHelperSyncImplementation[]
ns.MistHelperSyncImplementations = ns.MistHelperSyncImplementations or {};
tinsert(ns.MistHelperSyncImplementations, MH);

local prefix = 'Tirna Ver2';
C_ChatInfo.RegisterAddonMessagePrefix(prefix);
local function GetPartyChatType()
    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and 'INSTANCE_CHAT' or 'PARTY';
end

MH.buttonMapping = {
    '0 1 0 0',
    '0 1 1 1',
    '0 0 0 2',
    '0 0 1 3',
    '1 1 0 4',
    '1 1 1 5',
    '1 0 0 6',
    '1 0 1 7',
};
MH.reverseButtonMapping = tInvert(MH.buttonMapping);

function MH:SendButtonComms(buttonID, active)
    C_ChatInfo.SendAddonMessageLogged(prefix, format('%s %s', self.buttonMapping[buttonID], active and 'LeftButton' or 'RightButton'), GetPartyChatType());
end

function MH:OnButtonComms(buttonID, active, sender)
    -- do nohting, the WA reacts to messages sent by yourself anyway
end

function MH:SendResetComms()
    C_ChatInfo.SendAddonMessageLogged(prefix, '9 9 9 9', GetPartyChatType());
end

function MH:OnResetComms(sender)
    -- do nohting, the WA reacts to messages sent by yourself anyway
end

function MH:ListenToComms(buttonCallback, resetCallback)
    self.enabled = true;
    local pattern = '(%d %d %d %d) (.*)';
    hooksecurefunc(C_ChatInfo, 'SendAddonMessageLogged', function(...)
        if not self.enabled then return; end
        local msgPrefix, message = ...;
        if msgPrefix ~= prefix then return; end

        local buttonCombo, button = message:match(pattern);
        if message == '9 9 9 9' then
            resetCallback(playerNameWithRealm, true);
            return;
        elseif self.reverseButtonMapping[buttonCombo] then
            buttonCallback(self.reverseButtonMapping[buttonCombo], button == 'LeftButton', playerNameWithRealm, true);
        end
    end);
    local f = CreateFrame('Frame');
    self.listenerFrame = f;
    f:RegisterEvent('CHAT_MSG_ADDON_LOGGED');
    f:SetScript('OnEvent', function(_, _, msgPrefix, message, _, sender)
        if msgPrefix ~= prefix or sender == playerName or sender == playerNameWithRealm then return; end

        local buttonCombo, button = message:match(pattern);
        if message == '9 9 9 9' then
            resetCallback(sender);
            return;
        elseif self.reverseButtonMapping[buttonCombo] then
            buttonCallback(self.reverseButtonMapping[buttonCombo], button == 'LeftButton', sender);
        end
    end);
end

function MH:Enable()
    if not self.listenerFrame then return; end
    self.listenerFrame:RegisterEvent('CHAT_MSG_ADDON_LOGGED');
    self.enabled = true;
end

function MH:Disable()
    if not self.listenerFrame then return; end
    self.listenerFrame:UnregisterEvent('CHAT_MSG_ADDON_LOGGED');
    self.enabled = false;
end
