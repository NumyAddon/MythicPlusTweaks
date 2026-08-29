--- @meta _

--- @class MPT_KeystoneSharingModule: NumyConfig_Module
--- @field emulatedAddonName string

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

--- @class MPT_UnitScores
--- @field overall number
--- @field runs table<number, MPT_UnitScore> # [challengeModeID] = MPT_UnitScore

--- @class MPT_UnitScore
--- @field score number
--- @field level number
--- @field inTime boolean

--- @class MPT_TeleportImpl
--- @field icon number
--- @field type MPT_TeleportImplType
--- @field optionType MPT_TeleportImplType?
--- @field available fun(): boolean
--- @field cooldown fun(): (number, number, boolean)
--- @field spellID nil|fun(): number
--- @field itemID number?

--- @class MPT_SpellTeleportImpl: MPT_TeleportImpl
--- @field spellID fun(): number

--- @class MPT_ItemTeleportImpl: MPT_TeleportImpl
--- @field itemID number
--- @field type "item"

--- @class MPT_HearthstoneTeleportImpl
--- @field available fun(): boolean
--- @field type "hearthstone"
--- @field implementations MPT_TeleportImpl[][] # shared cooldowns go into the same lists
