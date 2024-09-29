--- @meta _

--- @class MPT_MistHelperSyncImplementation
--- @field name string
--- @field type string # 'Addon' or 'WeakAura'
--- @field url string

--- @class MPT_MistHelperSyncImplementation
local MPT_MistHelperSyncImplementation = {}

--- @param buttonID number
--- @param active boolean
--- @return nil
function MPT_MistHelperSyncImplementation:SendButtonComms(buttonID, active) end

--- @param buttonID number
--- @param active boolean
--- @param sender string
--- @return nil
function MPT_MistHelperSyncImplementation:OnButtonComms(buttonID, active, sender) end

--- @return nil
function MPT_MistHelperSyncImplementation:SendResetComms() end

--- @param sender string
--- @return nil
function MPT_MistHelperSyncImplementation:OnResetComms(sender) end

--- @param buttonCallback fun(buttonID: number, active: boolean, sender: string, senderIsMe: boolean): nil
--- @param resetCallback fun(sender: string, senderIsMe: boolean): nil
--- @return nil
function MPT_MistHelperSyncImplementation:Init(buttonCallback, resetCallback) end

--- has no effect unless ListenToComms is called first
--- @return nil
function MPT_MistHelperSyncImplementation:Enable() end

--- @return nil
function MPT_MistHelperSyncImplementation:Disable() end
