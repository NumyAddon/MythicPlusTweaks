---@meta _

--- @class MPT_Config_ColorSwatchButton: Button, ColorSwatchTemplate

--- @class MPT_Config_ColorControlMixin : SettingsListElementTemplate, SettingsControlMixin
--- @field ColorSwatch MPT_Config_ColorSwatchButton
--- @field data MPT_Config_SettingData

--- @class MPT_Config_ButtonControlMixin : SettingsListElementTemplate
--- @field Button UIPanelButtonTemplate
--- @field data MPT_Config_ButtonSettingData

--- @class MPT_Config_ButtonSettingData
--- @field name string
--- @field tooltip string
--- @field buttonText string
--- @field OnButtonClick fun(button: Button)

--- @class MPT_Config_MultiButtonControlMixin : SettingsListElementTemplate
--- @field ButtonContainer MPT_Config_MultiButton_ButtonContainer
--- @field data MPT_Config_MultiButtonSettingData

--- @class MPT_Config_MultiButton_ButtonContainer
--- @field buttonPool FramePool<UIPanelButtonTemplate>

--- @class MPT_Config_MultiButtonSettingData
--- @field name string
--- @field tooltip string
--- @field buttonTexts string[]
--- @field OnButtonClick fun(button: Button, buttonIndex: number)

--- @class MPT_Config_TextMixin: Frame, DefaultTooltipMixin
--- @field Text FontString

--- @class MPT_Config_HeaderMixin: Frame, DefaultTooltipMixin
--- @field Title FontString

--- @class MPT_Config_SettingData
--- @field setting AddOnSettingMixin
--- @field name string
--- @field options table
--- @field tooltip string

--- @class MPT_Config_SliderOptions: SettingsSliderOptionsMixin
--- @field minValue number
--- @field maxValue number
--- @field steps number

--- @param minValue number? # Minimum value (default: 0)
--- @param maxValue number? # Maximum value (default: 1)
--- @param rate number? # Size between steps; Defaults to 100 steps
--- @return MPT_Config_SliderOptions
function Settings.CreateSliderOptions(minValue, maxValue, rate) end

--- @alias MPT_Config_DropDownOptions { text: string, label: string?, tooltip: string?, value: any }[] # label is shown in the dropdown, text when selected

--- @class MPT_Module: AceAddon
local Module = {};

--- @return string # The description of the module. Will be displayed in the options
function Module:GetDescription() end

--- @return string # The short name of the module. Will be used as option header
function Module:GetName() end

--- @param configBuilder MPT_ConfigBuilder
--- @param db table # The module's private database
function Module:BuildConfig(configBuilder, db) end

--- @class MPT_KeystoneSharingModule: MPT_Module
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
