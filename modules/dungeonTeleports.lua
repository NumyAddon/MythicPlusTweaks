local addonName = ...;
--- @class MPT_NS
local MPT = select(2, ...);
local Main = MPT.Main;
local Util = MPT.Util;
local Data = MPT.Data;

local OPTION_ALWAYS = 'always';
local OPTION_MAIN_ON_COOLDOWN = 'main_on_cooldown';
local OPTION_MAIN_UNKNOWN = 'main_unknown';
local OPTION_NEVER = 'never';

local TYPE_DUNGEON_PORTAL = Data.Portals.Types.DUNGEON_PORTAL;
local TYPE_TOY = Data.Portals.Types.TOY;
local TYPE_CLASS_TELEPORT = Data.Portals.Types.CLASS_TELEPORT;
local TYPE_HEARTHSTONE = Data.Portals.Types.HEARTHSTONE;
local TYPE_ITEM = Data.Portals.Types.ITEM;

local POPUP_SETTING = 'groupFormedPopup';
local POPUP_TITLE_BAR_HEIGHT = 20;
local POPUP_ICON_SIZE = 50;
local POPUP_ALTERNATE_SIZE = 24;
local POPUP_ALTERNATE_COLUMNS = 8;
local POPUP_HEADER_HEIGHT = POPUP_TITLE_BAR_HEIGHT + POPUP_ICON_SIZE + 6;

local KINGS_REST_MAP_ID = 249;

--- @class MPT_DungeonTeleports : NumyConfig_Module,AceHook-3.0,NumyAceEvent-3.0
local Module = Main:NewModule('DungeonTeleports', 'AceHook-3.0', 'NumyAceEvent-3.0');

local frameSetAttribute = GetFrameMetatable().__index.SetAttribute;

--- returns the remaining cooldown of a spell
--- @param spellID number
--- @return number
local function GetRemainingSpellCooldown(spellID)
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID);
    if not cooldownInfo or issecretvalue(cooldownInfo) or issecretvalue(cooldownInfo.startTime) then return 0; end
    local start, duration = cooldownInfo.startTime, cooldownInfo.duration;

    return start + duration - GetTime();
end

function Module:OnInitialize()
    self:InitializeButtonPools();
    self:InitTeleportOverlayButton();
    self:InitJoinPopup();
end

--- @type table<Frame, MPT_DTP_Button>
Module.buttons = {};
function Module:OnEnable()
    self.enabled = true;
    self.hookedTooltips = {};
    self.lfgMessageCooldown = false;
    self:RegisterEvent('LFG_LIST_ACTIVE_ENTRY_UPDATE');
    self:RegisterEvent('LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS');
    self:RegisterEvent('LFG_LIST_JOINED_GROUP');
    if not self.registeredTooltipHandler then
        self.registeredTooltipHandler = true;
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) Module:ItemTooltipPostCall(tooltip); end);
    end
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
    Util:OnChallengesUILoad(function()
        for _, button in pairs(self.buttons) do
            button:Show();
        end
        self:RegisterEvent('ACHIEVEMENT_EARNED');
        self:SecureHook(ChallengesFrame, 'Update', function()
            self:OnChallengesFrameUpdate();
        end);
        self:OnChallengesFrameUpdate();
    end);
end

function Module:OnDisable()
    self.enabled = false;
    self.hookedTooltips = {};
    self:UnhookAll();
    self:UnregisterAllEvents();
    for _, button in pairs(self.buttons) do
        button:Hide();
    end
    self.joinPopup:Hide();
end

function Module:GetName() return 'Dungeon Teleports'; end

function Module:GetDescription()
    return 'Turns the dungeon icons in the Mythic+ UI into clickable buttons to teleport to the dungeon entrance.';
end

--- @param configBuilder NumyConfigBuilder
--- @param db MPT_DungeonTeleportsDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    self.configBuilder = configBuilder;
    --- @class MPT_DungeonTeleportsDB
    --- @field popupPosition {point: string, relativePoint: string, x: number, y: number}?
    local defaults = {
        showAlternates = true,
        shuffleSharedCooldown = true,
        teleportOnKeystoneCtrlClick = true,
        groupFormedMessage = true,
        groupFormedMessageKeystoneOnly = true,
        [POPUP_SETTING] = true,
        [TYPE_DUNGEON_PORTAL] = OPTION_MAIN_UNKNOWN,
        [TYPE_TOY] = OPTION_MAIN_ON_COOLDOWN,
        [TYPE_HEARTHSTONE] = OPTION_MAIN_ON_COOLDOWN,
        [TYPE_CLASS_TELEPORT] = OPTION_MAIN_ON_COOLDOWN,
    };
    -- Preserve settings from builds where this feature lived in the Miscellaneous module.
    local oldDb = Main.db.moduleDb.miscQoL;
    if oldDb then
        for _, key in ipairs({ 'groupFormedMessage', 'groupFormedMessageKeystoneOnly' }) do
            if db[key] == nil and oldDb[key] ~= nil then
                db[key] = oldDb[key];
            end
        end
    end
    configBuilder:SetDefaults(defaults, true);
    configBuilder:MakeButton(
        'Open Mythic+ UI',
        function() Util:ToggleMythicPlusFrame(); end,
        'Open the Mythic+ UI and you\'ll be able to click any of the icons to teleport to the dungeons, if you have earned the Hero achievement.'
    );
    configBuilder:MakeCheckbox(
        'Teleport on Keystone CTRL+Click',
        'teleportOnKeystoneCtrlClick',
        'Allows you to teleport to the dungeon entrance by CTRL+Clicking a keystone chat link or in your bags.'
    );
    local groupFormed = configBuilder:MakeCheckbox(
        'LFG group formed/joined message',
        'groupFormedMessage',
        'Show a reminder message in chat when you join a group or when the group is full, showing the activity you joined, with a clickable teleport link if available.'
    );
    configBuilder:MakeCheckbox(
        'Only for Mythic+',
        'groupFormedMessageKeystoneOnly',
        'Only show the reminder for m+ groups.'
    ):SetParentInitializer(groupFormed, function() return db.groupFormedMessage; end);
    local popup = configBuilder:MakeCheckbox(
        'LFG teleport popup',
        POPUP_SETTING,
        'Show the dungeon teleport and configured alternatives on screen. Drag the bar at the top of the popup to move it.',
        function(_, value)
            if not value then self.joinPopup:Hide(); end
        end
    );
    configBuilder:MakeButton(
        'Open Example',
        function() self:ShowJoinPopup(KINGS_REST_MAP_ID, "King's Rest (Mythic Keystone)", '+10'); end,
        'Open example popup'
    ):SetParentInitializer(popup, function() return self.db[POPUP_SETTING] end);
    local alternate = configBuilder:MakeCheckbox(
        'Show alternative teleports',
        'showAlternates',
        'Show alternative teleports, such as mage portals, nearby dungeons, engineering toys, etc.'
    );
    local function addAlternateOption(type, name, desc)
        local initializer = configBuilder:MakeDropdown(
            name,
            type,
            desc,
            {
                { text = 'Always', value = OPTION_ALWAYS, },
                { text = 'When Main is on cooldown', label = 'When main teleport is on cooldown or unknown', value = OPTION_MAIN_ON_COOLDOWN, },
                { text = 'When Main is unknown', label = 'Only when main teleport is unknown', value = OPTION_MAIN_UNKNOWN, },
                { text = 'Never', value = OPTION_NEVER, },
            }
        );
        initializer:SetParentInitializer(alternate, function() return self.db.showAlternates; end);

        return initializer;
    end
    addAlternateOption(
        TYPE_DUNGEON_PORTAL,
        'Dungeon portals',
        'Show dungeon portals as an alternative teleport.'
    );
    addAlternateOption(
        TYPE_TOY,
        'Toys (engineering and Dalaran/Garrison hearthstones)',
        'Show toys as an alternative teleport.'
    );
    addAlternateOption(
        TYPE_CLASS_TELEPORT,
        'Class teleports',
        'Show class teleports as an alternative teleport. (Mage portals, Druid Dreamwalk, etc.)'
    );
    local hearthstone = addAlternateOption(
        TYPE_HEARTHSTONE,
        'Hearthstone',
        'Show hearthstone as an alternative teleport. Only some specific locations are supported. Includes Shaman Astral Recall.'
    );
    configBuilder:MakeCheckbox(
        'Show a random hearthstone',
        'shuffleSharedCooldown',
        'Shows a random hearthstone, if a hearthstone would show up, and you have multiple toys'
    ):SetParentInitializer(hearthstone);
end

function Module:InitializeButtonPools()
    self.alternatesContainer = self:CreateAlternatesContainer();
    self.alternatesContainer.autoHide = true;

    local capacity = 20; -- prepare a few buttons, to avoid issues if they're created while in combat

    --- @type FramePool<MPT_DTP_Button>
    self.buttonPool = CreateFramePool('Button', UIParent, 'InsecureActionButtonTemplate', nil, nil, function(button)
        self:InitButton(button);
    end, capacity);
end

--- @param parent Frame? # defaults to no parent, the container is expected to be re-parented on use
--- @return MPT_DTP_AlternatesContainer
function Module:CreateAlternatesContainer(parent)
    --- @class MPT_DTP_AlternatesContainer : Frame
    --- @field autoHide boolean? # if set, the container hides itself when the mouse leaves it and its parent
    local container = CreateFrame('Frame', nil, parent);
    container:SetFrameLevel(10);

    local capacity = 20; -- prepare a few buttons, to avoid issues if they're created while in combat

    --- @type FramePool<MPT_DTP_AlternatesContainer_button>
    container.buttonPool = CreateFramePool('Button', container, 'InsecureActionButtonTemplate', nil, nil, function(button)
        self:InitAlternateButton(button);
    end, capacity);

    return container;
end

function Module:InitTeleportOverlayButton()
    self.overlayTrackerFrame = CreateFrame('Frame');
    self.overlayTrackerFrame:SetAllPoints(UIParent);
    self.overlayTrackerFrame:Hide();
    self.overlayTrackerFrame:SetScript('OnUpdate', function()
        local spellID = self.overlayTrackerFrame.spellID;
        if not spellID then
            self.overlayTrackerFrame:Hide();
            return;
        end

        self:SetShownTeleportOverlayButton(self.overlayTrackerFrame.alwaysShown or IsControlKeyDown(), spellID);
    end);

    self.teleportOverlayButton = CreateFrame('Button', nil, self.overlayTrackerFrame, 'InsecureActionButtonTemplate');
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

function Module:InitJoinPopup()
    --- @class MPT_DTP_JoinPopup : Frame
    local frame = CreateFrame('Frame', nil, UIParent);
    self.joinPopup = frame;
    do
        frame:Hide();
        frame:SetSize(280, POPUP_HEADER_HEIGHT);
        frame:SetFrameStrata('HIGH');
        frame:EnableMouse(true);
        frame:SetMovable(true);
        frame:SetClampedToScreen(true);
        frame:SetScript('OnHide', function() self:SaveJoinPopupPosition(); end);
        self:RestoreJoinPopupPosition();
    end

    local background = frame:CreateTexture(nil, 'BACKGROUND');
    frame.Background = background;
    do
        background:SetAllPoints();
        background:SetTexCoord(0.014, 2/3, 0.027, 0.72); -- just.. don't ask -.-

        local backgroundTint = frame:CreateTexture(nil, 'BACKGROUND', nil, 1);
        background.Tint = backgroundTint;
        backgroundTint:SetAllPoints();
        backgroundTint:SetColorTexture(0, 0, 0, 0.7);
    end

    local header = CreateFrame('Frame', nil, frame, 'PanelDragBarTemplate');
    frame.Header = header;
    do
        header:SetPoint('TOPLEFT');
        header:SetPoint('TOPRIGHT');
        header:SetHeight(POPUP_TITLE_BAR_HEIGHT);
        header:SetFrameLevel(frame:GetFrameLevel());
        header:HookScript('OnDragStop', function() self:SaveJoinPopupPosition(); end);

        local headerText = header:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
        header.Text = headerText;
        headerText:SetPoint('LEFT', 5, 0);
        headerText:SetText('Mythic+ Tweaks - Group Joined');

        local headerBackground = frame:CreateTexture(nil, 'BACKGROUND', nil, 2);
        header.BG = headerBackground;
        headerBackground:SetPoint('TOPLEFT', header);
        headerBackground:SetPoint('BOTTOMRIGHT', header);
        headerBackground:SetColorTexture(1, 1, 1, 0.06);
    end

    --- @class MPT_DTP_JoinPopup_Icon : Button, InsecureActionButtonTemplate
    --- @field mapID number?
    --- @field spellID number?
    --- @field spellKnown boolean?
    local icon = CreateFrame('Button', nil, frame, 'InsecureActionButtonTemplate');
    frame.Icon = icon;
    do
        icon:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 5, 0);
        icon:SetSize(POPUP_ICON_SIZE, POPUP_ICON_SIZE);
        icon:SetAttribute('type', 'spell');
        icon:RegisterForClicks('AnyUp', 'AnyDown');
        icon:SetHighlightTexture('Interface\\Buttons\\CheckButtonHighlight', 'ADD');
        icon:SetScript('OnEnter', function()
            if not icon.spellID then return; end

            GameTooltip:SetOwner(icon, 'ANCHOR_RIGHT');
            if icon.spellKnown then
                GameTooltip:SetSpellByID(icon.spellID);
            else
                GameTooltip:SetText('Teleport not yet earned.');
            end
            GameTooltip:Show();
        end);
        icon:SetScript('OnLeave', function() GameTooltip:Hide(); end);

        local cooldown = CreateFrame('Cooldown', nil, icon, 'CooldownFrameTemplate');
        icon.Cooldown = cooldown;
        cooldown:SetAllPoints();
        cooldown:SetDrawEdge(false);
    end

    local title = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
    frame.Title = title;
    do
        title:SetPoint('TOPLEFT', icon, 'TOPRIGHT', 8, -2);
        title:SetPoint('RIGHT', frame, 'RIGHT', -6, 0);
        title:SetJustifyH('LEFT');
        title:SetWordWrap(false);
        title:SetScript('OnEnter', function()
            GameTooltip:SetOwner(title, 'ANCHOR_TOPLEFT');
            GameTooltip:SetText(title:GetText());
            GameTooltip:AddLine(frame.Subtitle:GetText(), 1, 1, 1, true);
            GameTooltip:Show();
        end);
        title:SetScript('OnLeave', function() GameTooltip:Hide(); end);

        local subtitle = frame:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall');
        frame.Subtitle = subtitle;
        subtitle:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4);
        subtitle:SetPoint('RIGHT', title, 'RIGHT');
        subtitle:SetJustifyH('LEFT');
        subtitle:SetWordWrap(false);
        subtitle:SetScript('OnEnter', function() title:GetScript('OnEnter')(title); end);
        subtitle:SetScript('OnLeave', function() GameTooltip:Hide(); end);
    end

    local close = CreateFrame('Button', nil, frame, 'UIPanelCloseButton');
    frame.CloseButton = close;
    close:SetPoint('TOPRIGHT', 0, 0);
    close:SetScale(0.7);

    local settingsButton = CreateFrame('Button', nil, frame);
    frame.SettingsButton = settingsButton;
    do
        settingsButton:SetPoint('RIGHT', close, 'LEFT', 0, 0);
        settingsButton:SetSize(16, 16);
        settingsButton:SetNormalAtlas('GM-icon-settings');
        settingsButton:GetNormalTexture():SetPoint('TOPLEFT', -3, 3);
        settingsButton:GetNormalTexture():SetPoint('BOTTOMRIGHT', 3, -3);
        local leftClick = CreateAtlasMarkup('NPE_LeftClick', 18, 18);
        settingsButton:SetScript('OnEnter', function()
            settingsButton:SetNormalAtlas('GM-icon-settings-hover');
            GameTooltip:SetOwner(settingsButton, 'ANCHOR_TOPRIGHT');
            GameTooltip:SetText('Mythic+ Tweaks');
            GameTooltip_AddInstructionLine(GameTooltip, leftClick .. ' to open the settings, where you can permanently disable this popup.');
            GameTooltip:Show();
        end);
        settingsButton:SetScript('OnLeave', function()
            settingsButton:SetNormalAtlas('GM-icon-settings');
            GameTooltip:Hide();
        end);
        settingsButton:SetScript('OnClick', function()
            MPT.Config:OpenSettings(self.configBuilder);
        end);
    end

    local container = self:CreateAlternatesContainer(frame);
    frame.Alternates = container;
    do
        container:SetPoint('TOPLEFT', icon, 'BOTTOMLEFT', 0, -4);
    end

    self:RegisterJoinPopupWithBlizzMove();
end

function Module:RestoreJoinPopupPosition()
    local position = self.db and self.db.popupPosition;
    local frame = self.joinPopup;
    frame:ClearAllPoints();
    if position then
        frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y);
    else
        frame:SetPoint('TOP', UIParent, 'TOP', 0, -230);
    end
end

function Module:SaveJoinPopupPosition()
    local point, relativeTo, relativePoint, x, y = self.joinPopup:GetPoint(1);
    if not point or (relativeTo and relativeTo ~= UIParent) then return; end
    self.db.popupPosition = { point = point, relativePoint = relativePoint, x = x, y = y };
end

function Module:RegisterJoinPopupWithBlizzMove()
    Util:ContinueOnAddonLoaded('BlizzMove', function()
        --- @type BlizzMoveAPI?
        local BlizzMoveAPI = _G.BlizzMoveAPI;
        if not BlizzMoveAPI then return; end
        BlizzMoveAPI:RegisterAddOnFrames({
            [addonName] = {
                ['LFG_Popup'] = {
                    FrameReference = self.joinPopup,
                    SubFrames = {
                        ['header'] = {
                            FrameReference = self.joinPopup.Header,
                        },
                    },
                },
            },
        });
    end);
end

--- @param mapID number?
--- @param title string
--- @param subtitle string
function Module:ShowJoinPopup(mapID, title, subtitle)
    if not self.db[POPUP_SETTING] or not mapID then return; end

    local frame = self.joinPopup;
    local icon = frame.Icon;
    local mapKey = Data.Portals.maps[mapID];
    local spell = mapKey and Data.Portals.dungeonPortals[mapKey];
    icon.mapID = mapID;
    icon.spellID = spell and spell:spellID() or nil;
    icon.spellKnown = spell and spell:available() or false;
    icon:SetAttribute('spell', icon.spellKnown and icon.spellID or nil);
    icon:SetNormalTexture(icon.spellID and C_Spell.GetSpellTexture(icon.spellID));
    icon:DesaturateHierarchy(icon.spellKnown and 0 or 1);
    if icon.spellKnown then
        local startTime, duration = spell:cooldown();
        icon.Cooldown:SetCooldown(startTime or 0, duration or 0);
    else
        icon.Cooldown:Clear();
    end

    local dungeonTexture = Data.IconMap[mapID];
    frame.Background:SetShown(not not dungeonTexture);
    if dungeonTexture then
        frame.Background:SetTexture(dungeonTexture);
    end

    frame.Title:SetText(title);
    frame.Subtitle:SetText(subtitle);
    self:UpdateJoinPopupAlternates(icon);
    frame:Show();

    if self.alternatesTicker then self.alternatesTicker:Cancel(); end
    self.alternatesTicker = C_Timer.NewTicker(0.2, function(ticker)
        if not frame:IsShown() then
            ticker:Cancel();

            return;
        end
        self:UpdateJoinPopupAlternates(icon);
    end, 10);
end

--- @param icon MPT_DTP_JoinPopup_Icon
function Module:UpdateJoinPopupAlternates(icon)
    --- @type MPT_TeleportImpl[]
    local alternates = {};
    if self.db.showAlternates then
        alternates = self:GetAlternatesToShow(icon.mapID, icon.spellKnown, icon.spellID);
    end
    local rows = math.ceil(#alternates / POPUP_ALTERNATE_COLUMNS);

    local container = self.joinPopup.Alternates;
    if container then
        container:SetShown(rows > 0);
    end
    if container and rows > 0 then
        container:SetSize(
            POPUP_ALTERNATE_SIZE * math.min(#alternates, POPUP_ALTERNATE_COLUMNS),
            POPUP_ALTERNATE_SIZE * rows
        );
        self:FillAlternatesContainer(container, alternates, POPUP_ALTERNATE_SIZE, POPUP_ALTERNATE_COLUMNS);
    end

    self.joinPopup:SetHeight(POPUP_HEADER_HEIGHT + (rows > 0 and (4 + (rows * POPUP_ALTERNATE_SIZE)) or 0));
end

local joinedMessage = 'You have joined a group for %s |cnNORMAL_FONT_COLOR:%s|r.';
local formedMessage = 'Your group for %s has been formed.';
local teleportMessage = '|cff71d5ff|Haddon:MythicPlusTweaks:teleport-spell:%d|h[Click here to teleport to the instance.]|h|r';

function Module:LFG_LIST_ACTIVE_ENTRY_UPDATE()
    local activeEntryInfo = C_LFGList.GetActiveEntryInfo();
    if activeEntryInfo then
        self.activeActivityID = activeEntryInfo.activityIDs[1];
    end
end

function Module:LFG_LIST_JOINED_GROUP(_, searchResultID, groupName)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(searchResultID);
    if not searchResultInfo then return; end
    local activityID = searchResultInfo.activityIDs[1];
    local mapID, fullName, isMythicPlusActivity = Util:GetMapInfoByLfgActivityID(activityID);

    local spellID = mapID and self:GetSpellIDForMapID(mapID);
    self:ShowJoinPopup(mapID, fullName, groupName);

    if not self.db.groupFormedMessage then return; end
    if self.db.groupFormedMessageKeystoneOnly and not isMythicPlusActivity then return; end
    Main:Print(joinedMessage:format(fullName, groupName), spellID and teleportMessage:format(spellID) or '');

    self.lfgMessageCooldown = true;
    C_Timer.After(10, function() self.lfgMessageCooldown = false; end);
end

function Module:LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS()
    if not self.activeActivityID then return; end
    local mapID, fullName, isMythicPlusActivity = Util:GetMapInfoByLfgActivityID(self.activeActivityID);
    self:ShowJoinPopup(mapID, fullName, 'Your group has been formed.');

    if not self.db.groupFormedMessage or self.lfgMessageCooldown or (self.db.groupFormedMessageKeystoneOnly and not isMythicPlusActivity) then return; end
    local spellID = mapID and self:GetSpellIDForMapID(mapID);
    Main:Print(formedMessage:format(fullName), spellID and teleportMessage:format(spellID) or '');
end

function Module:PLAYER_LEAVING_WORLD()
    self:UnregisterEvent('PLAYER_LEAVING_WORLD');
    self:UnregisterEvent('UNIT_SPELLCAST_INTERRUPTED');
    if
        not self.joinPopup:IsShown() or not self.buttonClickedAt
        or (GetTime() - self.buttonClickedAt) > 30
    then
        return;
    end

    self.joinPopup:Hide();
end
function Module:UNIT_SPELLCAST_INTERRUPTED(_, unit)
    if unit ~= 'player' then return; end
    if
        not self.joinPopup:IsShown() or not self.buttonClickedAt
        or (GetTime() - self.buttonClickedAt) > 30
    then
        return;
    end

    self:UnregisterEvent('PLAYER_LEAVING_WORLD');
    self:UnregisterEvent('UNIT_SPELLCAST_INTERRUPTED');
    self.buttonClickedAt = nil;
end

function Module:OnHyperlinkEnter(frame, link)
    local linkType, part1, part2, part3 = string.split(':', link);
    if linkType == 'addon' and part1 == 'MythicPlusTweaks' and part2 == 'teleport-spell' then
        local spellID = tonumber(part3);
        GameTooltip:SetOwner(frame, 'ANCHOR_CURSOR');
        GameTooltip:SetSpellByID(spellID);
        GameTooltip_AddInstructionLine(GameTooltip, 'Click to teleport to the instance.');
        GameTooltip:Show();
        self.overlayTrackerFrame.spellID = spellID;
        self.overlayTrackerFrame.alwaysShown = true;
        self.overlayTrackerFrame:Show();
        self.addonLinkTooltipShown = true;
        self.tooltipShown = true;

        return;
    end

    if not self.db.teleportOnKeystoneCtrlClick then return; end
    local mapID = link:match('keystone:%d+:(%d+)');
    if not mapID then
        local itemId = link:match('item:(%d+)');
        if not itemId or not C_Item.IsItemKeystoneByID(itemId) then return end
        mapID = link:match(string.format(':%s:(%%d+):', Enum.ItemModification.KeystoneMapChallengeModeID));
    end
    if not mapID then return end
    GameTooltip:SetOwner(frame, 'ANCHOR_CURSOR');
    GameTooltip:SetHyperlink(link);
    GameTooltip:Show();
    self.tooltipShown = true;
end

function Module:OnHyperlinkLeave()
    if self.tooltipShown then
        GameTooltip:Hide();
        self:SetShownTeleportOverlayButton(false);
    end
    if self.addonLinkTooltipShown then
        self.overlayTrackerFrame.spellID = nil;
        self.overlayTrackerFrame:Hide();
    end
    self.overlayTrackerFrame.alwaysShown = nil;
    self.addonLinkTooltipShown = nil;
    self.tooltipShown = false;
end

--- @param tooltip GameTooltip
function Module:ItemTooltipPostCall(tooltip)
    if tooltip ~= GameTooltip then return; end

    self.overlayTrackerFrame:Hide();
    if not self.enabled or not self.db.teleportOnKeystoneCtrlClick then return; end
    if not tooltip or not tooltip.GetItem then return end

    local _, itemLink = tooltip:GetItem();
    if not itemLink then return; end
    local mapID = itemLink:match('keystone:%d+:(%d+)');
    if not mapID then
        local itemId = itemLink:match('item:(%d+)');
        if not itemId or not C_Item.IsItemKeystoneByID(itemId) then return end
        mapID = itemLink:match(string.format(':%s:(%%d+):', Enum.ItemModification.KeystoneMapChallengeModeID));
    end
    if not mapID then return end

    self:OnKeystoneTooltip(tooltip, tonumber(mapID));
end

--- @param tooltip GameTooltip
--- @param mapID number
function Module:OnKeystoneTooltip(tooltip, mapID)
    local spellID = self:GetSpellIDForMapID(mapID);
    if not spellID then return; end

    self.overlayTrackerFrame.spellID = spellID;
    self.overlayTrackerFrame:Show();
    GameTooltip_AddInstructionLine(GameTooltip, 'CTRL+Click to teleport to the instance.');
    GameTooltip:Show();

    if self.hookedTooltips[tooltip] then return; end
    self.hookedTooltips[tooltip] = true;
    self:SecureHookScript(tooltip, 'OnHide', function()
        self.overlayTrackerFrame:Hide();
    end);
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

function Module:ACHIEVEMENT_EARNED()
    for _, button in pairs(self.buttons) do
        local spellID = button:GetRegisteredSpell();
        if spellID then
            button:RegisterSpell(spellID);
        end
    end
end

function Module:OnChallengesFrameUpdate()
    for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
        self:ProcessIcon(icon);
    end
end

--- @param tooltip GameTooltip
function Module:AddInfoToTooltip(tooltip, spellID)
    GameTooltip_AddInstructionLine(tooltip, 'Click to teleport to the dungeon entrance.', true);
    local duration = GetRemainingSpellCooldown(spellID);
    if duration > 3 then -- global cooldown is counted here as well, so lets just ignore anything below 3 seconds
        local minutes = math.floor(duration / 60);
        tooltip:AddLine(string.format('%sDungeon teleport is on cooldown.|r (%02d:%02d)', ERROR_COLOR_CODE, math.floor(minutes / 60), minutes % 60));
    elseif InCombatLockdown() then
        tooltip:AddLine(ERROR_COLOR:WrapTextInColorCode('Cannot be done in combat.'), 1, 1, 1, true);
    end
    tooltip:Show();
end

--- @param icon ChallengesDungeonIconFrameTemplate
function Module:ProcessIcon(icon)
    self.buttons[icon] = self.buttons[icon] or self:GetButton(icon);

    local mapId = icon.mapID;
    local mapName = Data.Portals.maps[mapId];
    local spellID = Data.Portals.dungeonPortals[mapName] and Data.Portals.dungeonPortals[mapName].spellID() or nil;
    self.buttons[icon]:RegisterSpell(spellID); -- nil will unregister the spell

    if not spellID then return; end
    self.buttons[icon]:Show();
end

--- @return MPT_DTP_Button
function Module:GetButton(parent)
    local button = self.buttonPool:Acquire();
    button:SetParent(parent);
    parent.MPT_DTP_Button = button;
    button:SetFrameLevel(999); -- ensure the button is above anyone else's
    button:SetAllPoints();
    button:Show();

    return button;
end

function Module:InitAlternateButton(alternateButton)
    local container = alternateButton:GetParent();

    --- @class MPT_DTP_AlternatesContainer_button : Button, InsecureActionButtonTemplate
    --- @field data MPT_TeleportImpl?
    local alternateButton = alternateButton;
    alternateButton:RegisterForClicks('AnyUp', 'AnyDown');

    local cooldownFrame = CreateFrame('Cooldown', nil, alternateButton, 'CooldownFrameTemplate');
    cooldownFrame:SetAllPoints();
    cooldownFrame:SetDrawEdge(false);
    cooldownFrame:Show();
    alternateButton.cooldownFrame = cooldownFrame;

    alternateButton:SetHighlightTexture("Interface\\Buttons\\CheckButtonHighlight", "ADD");

    --- @param data MPT_TeleportImpl
    function alternateButton:SetData(data)
        self.data = data;
    end
    function alternateButton:OnEnter()
        GameTooltip:SetOwner(self, 'ANCHOR_TOPRIGHT');
        if self.data.type == TYPE_TOY then
            GameTooltip:SetToyByItemID(self.data.itemID);
        elseif self.data.type == TYPE_ITEM then
            GameTooltip:SetItemByID(self.data.itemID);
        else
            GameTooltip:SetSpellByID(self.data.spellID());
        end
        GameTooltip:Show();
    end
    alternateButton:SetScript('OnEnter', alternateButton.OnEnter);
    alternateButton:SetScript('OnLeave', function()
        GameTooltip:Hide();
        if container.autoHide and not container:IsMouseOver() and not container:GetParent():IsMouseOver() then
            container:Hide();
        end
    end);
    alternateButton:SetScript('OnHide', function()
        if container.autoHide then
            container:Hide();
        end
    end);
    alternateButton:HookScript('OnClick', function()
        if not self.joinPopup:IsShown() then return; end
        self.buttonClickedAt = GetTime();
        self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED');
        self:RegisterEvent('PLAYER_LEAVING_WORLD');
    end);
    function alternateButton:SetScript(script, func)
        error('unexpected SetScript call on alternateButton');
    end
    function alternateButton:SetAttribute(attribute, value)
        error('unexpected SetAttribute call on alternateButton');
    end
end

--- @param button MPT_DTP_Button
function Module:InitButton(button)
    --- @class MPT_DTP_Button : Button, InsecureActionButtonTemplate
    local button = button;
    button:Hide();
    frameSetAttribute(button, 'type', 'spell');
    button:RegisterForClicks('AnyUp', 'AnyDown');

    local highlight = button:CreateTexture(nil, 'OVERLAY');
    button.Highlight = highlight;
    do
        highlight:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures');
        highlight:SetTexCoord(0.34570313, 0.68554688, 0.33300781, 0.42675781);
        highlight:SetAllPoints();
        highlight:Hide();
        highlight.elapsed = 0;
        highlight.OnUpdate = nop;
        local function OnUpdate(_, elapsed)
            highlight.elapsed = highlight.elapsed + elapsed;
            if highlight.elapsed < 1 then return; end
            highlight.elapsed = 0;

            local spellID = button:GetRegisteredSpell();
            if not spellID then return; end
            local duration = GetRemainingSpellCooldown(spellID);
            if duration > 3 then -- global cooldown is counted here as well, so lets just ignore anything below 3 seconds
                highlight:SetVertexColor(1, 0, 0);
            else
                highlight:SetVertexColor(1, 1, 1);
            end
        end
        highlight:SetScript('OnShow', function()
            highlight.elapsed = 10;
            highlight.OnUpdate = OnUpdate;
        end);
        highlight:SetScript('OnHide', function()
            highlight.OnUpdate = nop;
        end);

        button:SetScript('OnUpdate', function(_, elapsed)
            highlight:OnUpdate(elapsed);
        end);
    end

    --- @param spellID number?
    function button:RegisterSpell(spellID)
        self.spellID = spellID;
        frameSetAttribute(self, 'spell', spellID);
        self.Highlight:SetShown(spellID and C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false));
    end

    function button:GetRegisteredSpell()
        return self.spellID;
    end

    button:SetScript("OnEnter", function(button, ...)
        local parent = button:GetParent();
        parent:GetScript("OnEnter")(parent, ...);
        local spellID = button:GetRegisteredSpell();
        local spellKnown = spellID and C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false);
        if spellID and GameTooltip:IsShown() and spellKnown then
            self:AddInfoToTooltip(GameTooltip, spellID);
        end
        local containerShown = self.alternatesContainer:IsShown();
        if self.db.showAlternates and not containerShown then
            self:AttachAlternates(button, parent.mapID, spellKnown, spellID);
            C_Timer.NewTicker(0.2, function(ticker) -- refresh a few times, cause I'm too lazy to properly wait for toy info to be loaded :P
                if
                    button:IsMouseOver()
                    or (self.alternatesContainer:IsMouseOver() and self.alternatesContainer:GetParent() == button)
                then
                    self:AttachAlternates(button, parent.mapID, spellKnown, spellID);
                else
                    ticker:Cancel();
                end
            end, 10); -- 2 seconds
        end
    end);

    button:SetScript("OnLeave", function(button, ...)
        local parent = button:GetParent();
        parent:GetScript("OnLeave")(parent, ...);
        if not self.alternatesContainer:IsMouseOver() then
            self.alternatesContainer:Hide();
        end
    end);

    button:HookScript('OnClick', function()
        if not self.joinPopup:IsShown() then return; end
        self.buttonClickedAt = GetTime();
        self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED');
        self:RegisterEvent('PLAYER_LEAVING_WORLD');
    end);

    function button:SetScript(script, func)
        error('unexpected SetScript call on button');
    end
    function button:SetAttribute(attribute, value)
        error('unexpected SetAttribute call on button');
    end
end

--- @generic T
--- @param tbl table<number, T>
--- @return table<number, T>
local function getShuffledList(tbl)
    local shuffled = {}
    for i = 1, #tbl do shuffled[i] = tbl[i] end
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    return shuffled
end

--- @param mapID number
--- @param mainKnown boolean?
--- @param mainSpellID number?
--- @return MPT_TeleportImpl[] # empty if there's nothing to show
function Module:GetAlternatesToShow(mapID, mainKnown, mainSpellID)
    local mapName = Data.Portals.maps[mapID];
    --- @type table<MPT_TeleportImpl|MPT_HearthstoneTeleportImpl>
    local alternates = Data.Portals.alternates[mapName];
    if not alternates or next(alternates) == nil then return {}; end

    local onCooldown = false;
    if mainKnown then
        local duration = GetRemainingSpellCooldown(mainSpellID);
        if duration > 3 then -- global cooldown is counted here as well, so lets just ignore anything below 3 seconds
            onCooldown = true;
        end
    end

    --- @type MPT_TeleportImpl[]
    local alternatesToShow = {};
    for _, alternate in ipairs(alternates) do
        --- @cast alternate MPT_TeleportImpl|MPT_HearthstoneTeleportImpl
        local option = self.db[alternate.optionType] or self.db[alternate.type] or OPTION_MAIN_UNKNOWN;
        local showAlternative = false;
        if option == OPTION_ALWAYS and alternate.available() then
            showAlternative = true;
        elseif option == OPTION_MAIN_ON_COOLDOWN and (onCooldown or not mainKnown) and alternate.available() then
            showAlternative = true;
        elseif option == OPTION_MAIN_UNKNOWN and not mainKnown and alternate.available() then
            showAlternative = true;
        end
        if showAlternative then
            if alternate.implementations then
                for _, implementationList in ipairs(alternate.implementations) do
                    if self.db.shuffleSharedCooldown then
                        implementationList = getShuffledList(implementationList);
                    end
                    for _, implementation in ipairs(implementationList) do
                        if implementation.available() then
                            table.insert(alternatesToShow, implementation);
                            break;
                        end
                    end
                end
            else
                --- @cast alternate MPT_TeleportImpl
                table.insert(alternatesToShow, alternate);
            end
        end
    end

    return alternatesToShow;
end

function Module:AttachAlternates(button, mapID, mainKnown, mainSpellID)
    local alternatesToShow = self:GetAlternatesToShow(mapID, mainKnown, mainSpellID);
    if #alternatesToShow == 0 then return; end

    local container = self:GetAlternatesContainer(button, #alternatesToShow);
    self:FillAlternatesContainer(container, alternatesToShow, button:GetWidth() / 2);
end

--- @param container MPT_DTP_AlternatesContainer
--- @param alternatesToShow MPT_TeleportImpl[]
--- @param alternateButtonSize number
--- @param columns number? # default 3
function Module:FillAlternatesContainer(container, alternatesToShow, alternateButtonSize, columns)
    columns = columns or 3;
    local buttonPool = container.buttonPool;
    local autoHide = container.autoHide;
    container.autoHide = nil;
    buttonPool:ReleaseAll();
    container.autoHide = autoHide;
    for i, alternate in ipairs(alternatesToShow) do
        local alternateButton = buttonPool:Acquire();
        alternateButton:SetSize(alternateButtonSize, alternateButtonSize);
        alternateButton:SetData(alternate);
        if alternate.type == TYPE_TOY then
            frameSetAttribute(alternateButton, 'type', 'toy');
            frameSetAttribute(alternateButton, 'toy', alternate.itemID);
        elseif alternate.type == TYPE_ITEM then
            frameSetAttribute(alternateButton, 'type', 'macro');
            frameSetAttribute(alternateButton, 'macrotext', '/use item:' .. alternate.itemID);
        else
            frameSetAttribute(alternateButton, 'type', 'spell');
            frameSetAttribute(alternateButton, 'spell', alternate.spellID());
        end

        alternateButton:SetNormalTexture(alternate.icon);
        alternateButton:Show();
        alternateButton:SetPoint('BOTTOMLEFT', container, 'BOTTOMLEFT', ((i - 1) % columns) * alternateButton:GetWidth(), math.floor((i - 1) / columns) * alternateButton:GetHeight());
        local startTime, duration, _ = alternate.cooldown();
        alternateButton.cooldownFrame:SetCooldown(startTime, duration);
    end
end

function Module:GetAlternatesContainer(button, numberOfAlternates)
    local alternateButtonSize = button:GetWidth() / 2;

    local container = self.alternatesContainer;
    container:SetParent(button);
    container:ClearAllPoints();
    container:SetPoint('BOTTOM', button, 'TOP');

    container:SetWidth(alternateButtonSize * 3);
    if numberOfAlternates < 3 then
        container:SetWidth(alternateButtonSize * numberOfAlternates);
    end
    container:SetHeight(alternateButtonSize * (math.ceil(numberOfAlternates / 3)));
    container:Show();

    return container;
end
