--- @class MPT_NS
local MPT = select(2, ...);
local Main = MPT.Main;
local Util = MPT.Util;
local Data = MPT.Data;

local OPTION_ALWAYS = 'always';
local OPTION_MAIN_ON_COOLDOWN = 'main_on_cooldown';
local OPTION_MAIN_UNKNOWN = 'main_unknown';
local OPTION_NEVER = 'never';

local TYPE_DUNGEON_PORTAL = Data.Portals.TYPE_DUNGEON_PORTAL;
local TYPE_TOY = Data.Portals.TYPE_TOY;
local TYPE_CLASS_TELEPORT = Data.Portals.TYPE_CLASS_TELEPORT;
local TYPE_HEARTHSTONE = Data.Portals.TYPE_HEARTHSTONE;
local TYPE_ITEM = Data.Portals.TYPE_ITEM;

--- @class MPT_DTP_Module : AceModule,AceHook-3.0,AceEvent-3.0
local Module = Main:NewModule('DungeonTeleports', 'AceHook-3.0', 'AceEvent-3.0');

local frameSetAttribute = GetFrameMetatable().__index.SetAttribute;

--- returns the remaining cooldown of a spell
--- @param spellID number
--- @return number
local function GetSpellCooldown(spellID)
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID);
    if not cooldownInfo then return 0; end
    local start, duration = cooldownInfo.startTime, cooldownInfo.duration;

    return start + duration - GetTime();
end

function Module:OnInitialize()
    self:InitializeButtonPools();
end

--- @type table<Frame, MPT_DTP_Button>
Module.buttons = {};
function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ChallengesUI', function()
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
    self:UnhookAll();
    self:UnregisterEvent('ACHIEVEMENT_EARNED');
    for _, button in pairs(self.buttons) do
        button:Hide();
    end
end

function Module:GetName()
    return 'Dungeon Teleports';
end

function Module:GetDescription()
    return 'Turns the dungeon icons in the Mythic+ UI into clickable buttons to teleport to the dungeon entrance.';
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        showAlternates = true,
        shuffleSharedCooldown = true,
        [TYPE_DUNGEON_PORTAL] = OPTION_MAIN_UNKNOWN,
        [TYPE_TOY] = OPTION_MAIN_ON_COOLDOWN,
        [TYPE_HEARTHSTONE] = OPTION_MAIN_ON_COOLDOWN,
        [TYPE_CLASS_TELEPORT] = OPTION_MAIN_ON_COOLDOWN,
    }
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end
    local function get(info) return db[info[#info]]; end
    local function set(info, value) db[info[#info]] = value; end
    local order = 10;
    local function increment() order = order + 1; return order; end
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        order = increment(),
        name = 'Open Mythic+ UI',
        desc = 'Open the Mythic+ UI and you\'ll be able to click any of the icons to teleport to the dungeons, if you have earned the Hero achievement.',
        func = function() PVEFrame_ToggleFrame('ChallengesFrame'); end,
    };

    defaultOptionsTable.args.showAlternates = {
        type = 'toggle',
        order = increment(),
        name = 'Show alternative teleports',
        desc = 'Show alternative teleports, such as mage portals, nearby dungeons, engineering toys, etc.',
        get = get,
        set = set,
        width = 'double',
    };

    local function addAlternateOption(type, name, desc)
        defaultOptionsTable.args[type] = {
            type = 'select',
            order = increment(),
            name = name,
            desc = desc,
            get = get,
            set = set,
            values = {
                [OPTION_ALWAYS] = 'Always',
                [OPTION_MAIN_ON_COOLDOWN] = 'When main teleport is on cooldown or unknown',
                [OPTION_MAIN_UNKNOWN] = 'Only when main teleport is unknown',
                [OPTION_NEVER] = 'Never',
            },
            sorting = {
                OPTION_ALWAYS,
                OPTION_MAIN_ON_COOLDOWN,
                OPTION_MAIN_UNKNOWN,
                OPTION_NEVER,
            },
            width = 'double',
            disabled = function() return not db.showAlternates; end,
        };
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
    addAlternateOption(
        TYPE_HEARTHSTONE,
        'Hearthstone',
        'Show hearthstone as an alternative teleport. Only some specific locations are supported. Includes Shaman Astral Recall.'
    );

    defaultOptionsTable.args.shuffleSharedCooldown = {
        type = 'toggle',
        order = increment(),
        name = 'Show a random hearthstone',
        desc = 'Shows a random hearthstone, if a hearthstone would show up, and you have multiple toys',
        get = get,
        set = set,
        width = 'double',
    };

    return defaultOptionsTable;
end

function Module:InitializeButtonPools()
    --- @class MPT_DTP_AlternatesContainer : Frame
    container = CreateFrame('Frame');
    self.alternatesContainer = container;
    container:SetFrameLevel(10);

    local function alternateInitFunc(alternateButton)
        --- @class MPT_DTP_AlternatesContainer_button : Button, InsecureActionButtonTemplate
        local alternateButton = alternateButton;
        alternateButton:RegisterForClicks('AnyUp', 'AnyDown');

        local cooldownFrame = CreateFrame('Cooldown', nil, alternateButton, 'CooldownFrameTemplate');
        cooldownFrame:SetAllPoints();
        cooldownFrame:SetDrawEdge(false);
        cooldownFrame:Show();
        alternateButton.cooldownFrame = cooldownFrame;

        alternateButton:SetHighlightTexture("Interface\\Buttons\\CheckButtonHighlight", "ADD");

        function alternateButton:SetData(data)
            self.data = data;
        end
        alternateButton:SetScript('OnEnter', function()
            GameTooltip:SetOwner(alternateButton, 'ANCHOR_TOPRIGHT');
            if alternateButton.data.type == TYPE_TOY then
                GameTooltip:SetToyByItemID(alternateButton.data.itemID);
            elseif alternateButton.data.type == TYPE_ITEM then
                GameTooltip:SetItemByID(alternateButton.data.itemID);
            else
                GameTooltip:SetSpellByID(alternateButton.data.spellID());
            end
            GameTooltip:Show();
        end);
        alternateButton:SetScript('OnLeave', function()
            GameTooltip:Hide();
            if not container:IsMouseOver() and not container:GetParent():IsMouseOver() then
                container:Hide();
            end
        end);
        alternateButton:SetScript('OnHide', function()
            container:Hide();
        end);
        function alternateButton:SetScript(script, func)
            error('unexpected SetScript call on alternateButton');
        end
        function alternateButton:SetAttribute(attribute, value)
            error('unexpected SetAttribute call on alternateButton');
        end
    end
    --- @type FramePool<MPT_DTP_AlternatesContainer_button>
    container.buttonPool = CreateFramePool('Button', container, 'InsecureActionButtonTemplate', nil, nil, alternateInitFunc);

    --- @type FramePool<MPT_DTP_Button>
    self.buttonPool = CreateFramePool('Button', UIParent, 'InsecureActionButtonTemplate', nil, nil, function(button)
        self:InitButton(button);
    end);

    for _ = 1, 20 do -- prepare a few buttons, to avoid issues if they're created while in combat
        container.buttonPool:Acquire();
        self.buttonPool:Acquire();
    end
    container.buttonPool:ReleaseAll();
    self.buttonPool:ReleaseAll();
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
    local duration = GetSpellCooldown(spellID);
    if duration > 3 then -- global cooldown is counted here as well, so lets just ignore anything below 3 seconds
        local minutes = math.floor(duration / 60);
        tooltip:AddLine(string.format('%sDungeon teleport is on cooldown.|r (%02d:%02d)', ERROR_COLOR_CODE, math.floor(minutes / 60), minutes % 60));
    elseif InCombatLockdown() then
        tooltip:AddLine(ERROR_COLOR:WrapTextInColorCode('Cannot be done in combat.'), 1, 1, 1, true);
    end
    tooltip:Show();
end

function Module:ProcessIcon(icon, index)
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
    button:SetAllPoints();
    button:Show();

    return button;
end

--- @param button MPT_DTP_Button
function Module:InitButton(button)
    --- @class MPT_DTP_Button : Button, InsecureActionButtonTemplate
    local button = button;
    button:Hide();
    frameSetAttribute(button, 'type', 'spell');
    button:SetFrameLevel(999);
    button:RegisterForClicks('AnyUp', 'AnyDown');

    local highlight = button:CreateTexture(nil, 'OVERLAY');
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
        local duration = GetSpellCooldown(spellID);
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
    button.highlight = highlight;

    button:SetScript('OnUpdate', function(_, elapsed)
        highlight:OnUpdate(elapsed);
    end);

    function button:RegisterSpell(spellID)
        self.spellID = spellID;
        frameSetAttribute(self, 'spell', spellID);
        self.highlight:SetShown(spellID and C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false));
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
    end)

    button:SetScript("OnLeave", function(button, ...)
        local parent = button:GetParent();
        parent:GetScript("OnLeave")(parent, ...);
        if not self.alternatesContainer:IsMouseOver() then
            self.alternatesContainer:Hide();
        end
    end)

    function button:SetScript(script, func)
        error('unexpected SetScript call on button');
    end
    function button:SetAttribute(attribute, value)
        error('unexpected SetAttribute call on button');
    end
end

local function getShuffledList(tbl)
    local shuffled = {}
    for i = 1, #tbl do shuffled[i] = tbl[i] end
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    return shuffled
end

function Module:AttachAlternates(button, mapID, mainKnown, mainSpellID)
    local mapName = Data.Portals.maps[mapID];
    local alternates = Data.Portals.alternates[mapName];
    if not alternates or next(alternates) == nil then return; end

    local onCooldown = false;
    if mainKnown then
        local duration = GetSpellCooldown(mainSpellID);
        if duration > 3 then -- global cooldown is counted here as well, so lets just ignore anything below 3 seconds
            onCooldown = true;
        end
    end

    local alternatatesToShow = {};
    for _, alternate in ipairs(alternates) do
        local option = self.db[alternate.type] or OPTION_MAIN_UNKNOWN;
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
                            table.insert(alternatatesToShow, implementation);
                            break;
                        end
                    end
                end
            else
                table.insert(alternatatesToShow, alternate);
            end
        end
    end

    if #alternatatesToShow == 0 then return; end

    local container = self:GetAlternatesContainer(button, #alternatatesToShow);
    local buttonPool = container.buttonPool;
    local alternateButtonSize = button:GetWidth() / 2;
    for i, alternate in ipairs(alternatatesToShow) do
        local alternateButton = buttonPool:Acquire();
        alternateButton:SetSize(alternateButtonSize, alternateButtonSize);
        alternateButton:SetData(alternate);
        if alternate.type == TYPE_TOY then
            frameSetAttribute(alternateButton, 'type', 'toy');
            frameSetAttribute(alternateButton, 'toy', alternate.itemID);
        elseif alternate.type == TYPE_ITEM then
            frameSetAttribute(alternateButton, 'type', 'item');
            frameSetAttribute(alternateButton, 'item', alternate.itemID);
        else
            frameSetAttribute(alternateButton, 'type', 'spell');
            frameSetAttribute(alternateButton, 'spell', alternate.spellID());
        end

        alternateButton:SetNormalTexture(alternate.icon);
        alternateButton:Show();
        alternateButton:SetPoint('BOTTOMLEFT', container, 'BOTTOMLEFT', ((i - 1) % 3) * alternateButton:GetWidth(), math.floor((i - 1) / 3) * alternateButton:GetHeight());
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
    container.buttonPool:ReleaseAll();
    container:Show();

    return container;
end
