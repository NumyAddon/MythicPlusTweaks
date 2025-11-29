--- @type MPT_NS
local MPT = select(2, ...);
local Main = MPT.Main;
local Util = MPT.Util;

MPT.MistHelperSyncImplementations = MPT.MistHelperSyncImplementations or {};
--- @type MPT_MistHelperSyncImplementation[]
local implementations = MPT.MistHelperSyncImplementations;

--- @class MPT_MistHelperSync: NumyConfig_Module
local Module = Main:NewModule('MistHelperSync');

Module.initializedImplementations = {};

function Module:OnEnable()
    for _, implementation in ipairs(implementations) do
        if not self.initializedImplementations[implementation] then
            self:InitializeImplementation(implementation);
        else
            implementation:Enable();
        end
    end
end

function Module:OnDisable()
    for _, implementation in ipairs(implementations) do
        implementation:Disable();
    end
end

function Module:GetDescription()
    return 'Synchronizes various Mists of Tirna Scithe maze helper addons / weakauras.';
end

function Module:GetName()
    return 'Mist Maze Helper Sync';
end

--- @param configBuilder NumyConfigBuilder
function Module:BuildConfig(configBuilder)
    for _, implementation in ipairs(implementations) do
        configBuilder:MakeButton(
            'Copy ' .. implementation.type .. ' Link',
            function() Util:CopyText(implementation.url); end,
            'Copy the link for ' .. implementation.name
        );
    end
end

--- @param implementation MPT_MistHelperSyncImplementation
function Module:InitializeImplementation(implementation)
    implementation:Init(
        function(buttonID, active, sender, senderIsMe)
            self:OnButtonComms(implementation, buttonID, active, sender, senderIsMe);
        end,
        function(sender, senderIsMe)
            self:OnResetComms(implementation, sender, senderIsMe);
        end
    );
    self.initializedImplementations[implementation] = true;
end

local isSending = false;

--- @param implementation MPT_MistHelperSyncImplementation
--- @param buttonID number
--- @param active boolean
--- @param sender string
function Module:OnButtonComms(implementation, buttonID, active, sender, senderIsMe)
    local wasSending = isSending;
    isSending = true;
    for _, otherImplementation in ipairs(implementations) do
        if otherImplementation ~= implementation then
            if not wasSending then
                otherImplementation:SendButtonComms(buttonID, active);
                otherImplementation:OnButtonComms(buttonID, active, sender);
            end
        end
    end
    isSending = false;
end

--- @param implementation MPT_MistHelperSyncImplementation
--- @param sender string
function Module:OnResetComms(implementation, sender, senderIsMe)
    local wasSending = isSending;
    isSending = true;
    for _, otherImplementation in ipairs(implementations) do
        if otherImplementation ~= implementation then
            if not wasSending then
                otherImplementation:SendResetComms();
                otherImplementation:OnResetComms(sender);
            end
        end
    end
    isSending = false;
end
