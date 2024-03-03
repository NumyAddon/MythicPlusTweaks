local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local OPTION_ALWAYS = 'always';
local OPTION_MAIN_ON_COOLDOWN = 'main_on_cooldown';
local OPTION_MAIN_UNKNOWN = 'main_unknown';
local OPTION_NEVER = 'never';

local TYPE_DUNGEON_PORTAL = 'dungeon_portal';
local TYPE_TOY = 'toy';
local TYPE_CLASS_TELEPORT = 'mage_teleport';

--- @class MPT_DTP_Module : AceModule,AceHook-3.0,AceEvent-3.0
local Module = Main:NewModule('DungeonTeleports', 'AceHook-3.0', 'AceEvent-3.0');

local frameSetAttribute = GetFrameMetatable().__index.SetAttribute;

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
        ['showAlternates'] = true,
        [TYPE_DUNGEON_PORTAL] = OPTION_MAIN_UNKNOWN,
        [TYPE_TOY] = OPTION_MAIN_ON_COOLDOWN,
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

    return defaultOptionsTable;
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

function Module:AddInfoToTooltip(tooltip, spellID)
    tooltip:AddLine(GREEN_FONT_COLOR:WrapTextInColorCode('Click to teleport to the dungeon entrance.'));
    local _, duration = GetSpellCooldown(spellID);
    if(duration and duration > 3) then -- global cooldown is counted here as well, so lets just ignore anything below 3 seconds
        local minutes = math.floor(duration / 60);
        tooltip:AddLine(string.format('%sDungeon teleport is on cooldown.|r (%02d:%02d)', ERROR_COLOR_CODE, math.floor(minutes / 60), minutes % 60));
    elseif InCombatLockdown() then
        tooltip:AddLine(ERROR_COLOR:WrapTextInColorCode('Cannot be done in combat.'));
    end
    tooltip:Show();
end

function Module:ProcessIcon(icon)
    self.buttons[icon] = self.buttons[icon] or self:MakeButton(icon);

    local mapId = icon.mapID;
    local mapName = self.maps[mapId];
    local spellID = self.portals[mapName] and self.portals[mapName].spellID or nil;
    self.buttons[icon]:RegisterSpell(spellID); -- nil will unregister the spell

    if not spellID then return; end
    self.buttons[icon]:Show();
end

--- @return MPT_DTP_Button
function Module:MakeButton(parent)
    --- @class MPT_DTP_Button : Button|InsecureActionButtonTemplate
    local button = CreateFrame('Button', nil, parent, 'InsecureActionButtonTemplate');
    button:Show()
    button:SetAllPoints();
    frameSetAttribute(button, 'type', 'spell');
    button:SetFrameLevel(999);
    button:RegisterForClicks('AnyUp', 'AnyDown');

    local highlight = button:CreateTexture(nil, 'OVERLAY');
    highlight:SetTexture('Interface\\EncounterJournal\\UI-EncounterJournalTextures');
    highlight:SetTexCoord(0.34570313, 0.68554688, 0.33300781, 0.42675781);
    highlight:SetAllPoints();
    highlight:SetAlpha(0);
    button.highlight = highlight;

    function button:RegisterSpell(spellID)
        self.spellID = spellID;
        frameSetAttribute(self, 'spell', spellID);
        self.highlight:SetAlpha(spellID and IsSpellKnown(spellID) and 1 or 0);
    end

    function button:GetRegisteredSpell()
        return self.spellID;
    end

    button:SetScript("OnEnter", function(button, ...)
        parent:GetScript("OnEnter")(parent, ...);
        local spellID = button:GetRegisteredSpell();
        local spellKnown = IsSpellKnown(spellID);
        if spellID and GameTooltip:IsShown() and spellKnown then
            self:AddInfoToTooltip(GameTooltip, spellID);
        end
        if self.db.showAlternates then
            self:AttachAlternates(button, parent.mapID, spellKnown, spellID);
            C_Timer.NewTicker(0.2, function(ticker) -- refresh a few times, cause I'm too lazy to properly wait for toy info to be loaded :P
                if
                    button:IsMouseOver()
                    or (self.alternatesContainer and self.alternatesContainer:IsMouseOver() and self.alternatesContainer:GetParent() == button)
                then
                    self:AttachAlternates(button, parent.mapID, spellKnown, spellID);
                else
                    ticker:Cancel();
                end
            end, 10); -- 2 seconds
        end
    end)

    button:SetScript("OnLeave", function(button, ...)
        button:GetParent():GetScript("OnLeave")(button:GetParent(), ...);
        if self.alternatesContainer and not self.alternatesContainer:IsMouseOver() then
            self.alternatesContainer:Hide();
        end
    end)

    function button:SetScript(script, func)
        error('unexpected SetScript call on button');
    end
    function button:SetAttribute(attribute, value)
        error('unexpected SetAttribute call on button');
    end

    return button;
end

function Module:AttachAlternates(button, mapID, mainKnown, mainSpellID)
    local mapName = self.maps[mapID];
    local alternates = self.alternates[mapName];
    if not alternates or next(alternates) == nil then return; end

    local onCooldown = false;
    if mainKnown then
        local _, duration = GetSpellCooldown(mainSpellID);
        if (duration and duration > 3) then -- global cooldown is counted here as well, so lets just ignore anything below 3 seconds
            onCooldown = true;
        end
    end

    local alternatatesToShow = {};
    for _, alternate in ipairs(alternates) do
        local option = self.db[alternate.type] or OPTION_MAIN_UNKNOWN;
        if option == OPTION_ALWAYS and alternate.available() then
            table.insert(alternatatesToShow, alternate);
        elseif option == OPTION_MAIN_ON_COOLDOWN and (onCooldown or not mainKnown) and alternate.available() then
            table.insert(alternatatesToShow, alternate);
        elseif option == OPTION_MAIN_UNKNOWN and not mainKnown and alternate.available() then
            table.insert(alternatatesToShow, alternate);
        end
    end

    if #alternatatesToShow == 0 then return; end

    local container = self:GetAlternatesContainer(button, #alternatatesToShow);
    local buttonPool = container.buttonPool;
    for i, alternate in ipairs(alternatatesToShow) do
        local alternateButton = buttonPool:Acquire();
        alternateButton.data = alternate;
        if alternate.type == TYPE_TOY then
            frameSetAttribute(alternateButton, 'type', 'toy');
            frameSetAttribute(alternateButton, 'toy', alternate.itemID);
        else
            frameSetAttribute(alternateButton, 'type', 'spell');
            frameSetAttribute(alternateButton, 'spell', alternate.spellID);
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

    --- @class MPT_DTP_AlternatesContainer : Frame
    local container = self.alternatesContainer;
    if not container then
        --- @class MPT_DTP_AlternatesContainer : Frame
        container = CreateFrame('Frame', nil, button);
        self.alternatesContainer = container;
        container:SetFrameLevel(10);

        local function initFunc(alternateButton)
            alternateButton:SetSize(alternateButtonSize, alternateButtonSize);
            alternateButton:RegisterForClicks('AnyUp', 'AnyDown');

            local cooldownFrame = CreateFrame('Cooldown', nil, alternateButton, 'CooldownFrameTemplate');
            cooldownFrame:SetAllPoints();
            cooldownFrame:SetDrawEdge(false);
            cooldownFrame:Show();
            alternateButton.cooldownFrame = cooldownFrame;

            alternateButton:SetHighlightTexture("Interface\\Buttons\\CheckButtonHighlight", "ADD")
            alternateButton:SetScript('OnEnter', function()
                GameTooltip:SetOwner(alternateButton, 'ANCHOR_TOPRIGHT');
                if alternateButton.data.type == TYPE_TOY then
                    GameTooltip:SetToyByItemID(alternateButton.data.itemID);
                else
                    GameTooltip:SetSpellByID(alternateButton.data.spellID);
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
        container.buttonPool = CreateFramePool('Button', container, 'InsecureActionButtonTemplate', nil, nil, initFunc);
    end
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

local function toy(itemID, spellID)
    return {
        icon = select(5, GetItemInfoInstant(itemID)),
        itemID = itemID,
        spellID = spellID,
        available = function()
            return PlayerHasToy(itemID) and C_ToyBox.IsToyUsable(itemID);
        end,
        cooldown = function() return GetItemCooldown(itemID); end,
        type = TYPE_TOY,
    };
end
local function spell(spellID, type)
    return {
        icon = select(3, GetSpellInfo(spellID)),
        spellID = spellID,
        available = function()
            return IsSpellKnown(spellID);
        end,
        cooldown = function() return GetSpellCooldown(spellID); end,
        type = type,
    };
end
local function dungeonPortal(spellID)
    return spell(spellID, TYPE_DUNGEON_PORTAL);
end
local function classTeleport(spellID)
    return spell(spellID, TYPE_CLASS_TELEPORT);
end

Module.portals = {
    TempleoftheJadeSerpent = dungeonPortal(131204),
    StormstoutBrewery = dungeonPortal(131205),
    GateoftheSettingSun = dungeonPortal(131225),
    ShadoPanMonastery = dungeonPortal(131206),
    SiegeofNiuzaoTemple = dungeonPortal(131228),
    MogushanPalace = dungeonPortal(131222),
    Scholomance = dungeonPortal(131232),
    ScarletHalls = dungeonPortal(131231),
    ScarletMonastery = dungeonPortal(131229),
    Skyreach = dungeonPortal(159898),
    BloodmaulSlagMines = dungeonPortal(159895),
    Auchindoun = dungeonPortal(159897),
    ShadowmoonBurialGrounds = dungeonPortal(159899),
    GrimrailDepot = dungeonPortal(159900),
    UpperBlackrockSpire = dungeonPortal(159902),
    TheEverbloom = dungeonPortal(159901),
    IronDocks = dungeonPortal(159896),
    DarkheartThicket = dungeonPortal(424163),
    BlackRookHold = dungeonPortal(424153),
    HallsofValor = dungeonPortal(393764),
    NeltharionsLair = dungeonPortal(410078),
    CourtofStars = dungeonPortal(393766),
    ReturntoKarazhan = dungeonPortal(373262),
    AtalDazar = dungeonPortal(424187),
    Freehold = dungeonPortal(410071),
    WaycrestManor = dungeonPortal(424167),
    TheUnderrot = dungeonPortal(410074),
    OperationMechagon = dungeonPortal(373274),
    MistsofTirnaScithe = dungeonPortal(354464),
    TheNecroticWake = dungeonPortal(354462),
    DeOtherSide = dungeonPortal(354468),
    HallsofAtonement = dungeonPortal(354465),
    Plaguefall = dungeonPortal(354463),
    SanguineDepths = dungeonPortal(354469),
    SpiresofAscension = dungeonPortal(354466),
    TheaterofPain = dungeonPortal(354467),
    Tazavesh = dungeonPortal(367416),
    RubyLifePools = dungeonPortal(393256),
    TheNokhudOffensive = dungeonPortal(393262),
    TheAzureVault = dungeonPortal(393279),
    AlgetharAcademy = dungeonPortal(393273),
    UldamanLegacyofTyr = dungeonPortal(393222),
    Neltharus = dungeonPortal(393276),
    BrackenhideHollow = dungeonPortal(393267),
    HallsofInfusion = dungeonPortal(393283),
    TheVortexPinnacle = dungeonPortal(410080),
    ThroneoftheTides = dungeonPortal(424142),
    DawnoftheInfinite = dungeonPortal(424197),
}
Module.toys = {
    GarrisonHearthstone = toy(110560, 171253),
    DalaranHearthstone = toy(140192, 222695),
    EngiWormholeDraenor = toy(112059, 163830), -- Engineering, can select which zone to go to
    EngiWormholeNorthrend = toy(48933, 67833), -- Engineering, can't select zone
    EngiWormholePandaria = toy(87215, 126755), -- Engineering, can't select zone
    EngiWormholeArgus = toy(151652, 250796), -- Engineering, can't select zone
    EngiWormholeZandalar = toy(168808, 299084), -- Engineering, can't select zone
    EngiWormholeKulTiras = toy(168807, 299083), -- Engineering, can't select zone
    EngiWormholeShadowlands = toy(172924, 324031), -- Engineering, can select which zone to go to
    EngiWormholeDragonIsles = toy(198156, 386379), -- Engineering, can select which zone to go to
    EngiToshelysStation = toy(30544, 36941), -- Gnomish Engineering, Blade's Edge Mountains, northern Outland
    EngiGadgetzan = toy(18986, 23453), -- Gnomish Engineering, Tanaris, north-east of Uldum
    EngiArea52 = toy(30542, 36890), -- Goblin Engineering, Netherstorm, northern Outland
    EngiEverlook = toy(18984, 23442), -- Goblin Engineering, Winterspring, north of Mount Hyjal, probably kinda useless for this ;)
}
Module.mage = {
   Dazaralor = classTeleport(281404),
   Stormshield = classTeleport(176248),
   ValeofEternalBlossoms1 = classTeleport(132621),
   ValeofEternalBlossoms2 = classTeleport(132627),
   Warspear = classTeleport(176242),
   LegionOrderHall = classTeleport(193759), -- Hall of the Guardian, useful for all legion locations
   Boralus = classTeleport(281403),
   DalaranBrokenIsles = classTeleport(224869),
   DalaranNorthrend = classTeleport(53140),
   Darnassus = classTeleport(3565),
   Exodar = classTeleport(32271),
   Ironforge = classTeleport(3562),
   Orgrimmar = classTeleport(3567),
   Shattrath1 = classTeleport(33690),
   Shattrath2 = classTeleport(35715),
   Silvermoon = classTeleport(32272),
   Stonard = classTeleport(49358),
   Stormwind = classTeleport(3561),
   Theramore = classTeleport(49359),
   ThunderBluff = classTeleport(3566),
   TolBarad1 = classTeleport(88342),
   TolBarad2 = classTeleport(88344),
   Undercity = classTeleport(3563),
   DalaranCrater = classTeleport(120145),
   Oribos = classTeleport(344587),
   Valdrakken = classTeleport(395277),
}
Module.others = {
    DruidDreamwalk = classTeleport(193753),
}

local portals, toys, mage, others = Module.portals, Module.toys, Module.mage, Module.others;

Module.maps = {
    [2] = 'TempleoftheJadeSerpent',
    [56] = 'StormstoutBrewery',
    [57] = 'GateoftheSettingSun',
    [58] = 'ShadoPanMonastery',
    [59] = 'SiegeofNiuzaoTemple',
    [60] = 'MogushanPalace',
    [76] = 'Scholomance',
    [77] = 'ScarletHalls',
    [78] = 'ScarletMonastery',
    [161] = 'Skyreach',
    [163] = 'BloodmaulSlagMines',
    [164] = 'Auchindoun',
    [165] = 'ShadowmoonBurialGrounds',
    [166] = 'GrimrailDepot',
    [167] = 'UpperBlackrockSpire',
    [168] = 'TheEverbloom',
    [169] = 'IronDocks',
    [198] = 'DarkheartThicket',
    [199] = 'BlackRookHold',
    [200] = 'HallsofValor',
    [206] = 'NeltharionsLair',
    [210] = 'CourtofStars',
    [227] = 'ReturntoKarazhan',
    [234] = 'ReturntoKarazhan',
    [244] = 'AtalDazar',
    [245] = 'Freehold',
    [248] = 'WaycrestManor',
    [251] = 'TheUnderrot',
    [369] = 'OperationMechagon',
    [370] = 'OperationMechagon',
    [375] = 'MistsofTirnaScithe',
    [376] = 'TheNecroticWake',
    [377] = 'DeOtherSide',
    [378] = 'HallsofAtonement',
    [379] = 'Plaguefall',
    [380] = 'SanguineDepths',
    [381] = 'SpiresofAscension',
    [382] = 'TheaterofPain',
    [391] = 'Tazavesh',
    [392] = 'Tazavesh',
    [399] = 'RubyLifePools',
    [400] = 'TheNokhudOffensive',
    [401] = 'TheAzureVault',
    [402] = 'AlgetharAcademy',
    [403] = 'UldamanLegacyofTyr',
    [404] = 'Neltharus',
    [405] = 'BrackenhideHollow',
    [406] = 'HallsofInfusion',
    [438] = 'TheVortexPinnacle',
    [456] = 'ThroneoftheTides',
    [463] = 'DawnoftheInfinite',
    [464] = 'DawnoftheInfinite',
};

Module.alternates = {
    TempleoftheJadeSerpent = {},
    StormstoutBrewery = {},
    GateoftheSettingSun = {},
    ShadoPanMonastery = {},
    SiegeofNiuzaoTemple = {},
    MogushanPalace = {},
    Scholomance = {},
    ScarletHalls = {},
    ScarletMonastery = {},
    Skyreach = {},
    BloodmaulSlagMines = {},
    Auchindoun = {},
    ShadowmoonBurialGrounds = {},
    GrimrailDepot = {},
    UpperBlackrockSpire = {},
    TheEverbloom = {
        portals.GrimrailDepot,
        portals.IronDocks,
        toys.EngiWormholeDraenor,
    },
    IronDocks = {},
    DarkheartThicket = {
        portals.BlackRookHold,
        others.DruidDreamwalk,
        portals.NeltharionsLair,
        portals.CourtofStars,
        toys.DalaranHearthstone,
        mage.LegionOrderHall,
    },
    BlackRookHold = {
        portals.DarkheartThicket,
        others.DruidDreamwalk,
        portals.NeltharionsLair,
        portals.CourtofStars,
        mage.LegionOrderHall,
        toys.DalaranHearthstone,
    },
    HallsofValor = {},
    NeltharionsLair = {},
    CourtofStars = {},
    ReturntoKarazhan = {},
    AtalDazar = {
        mage.Dazaralor,
        toys.EngiWormholeZandalar,
        portals.TheUnderrot,
    },
    Freehold = {},
    WaycrestManor = {
        portals.OperationMechagon,
        portals.Freehold,
        toys.EngiWormholeKulTiras,
        mage.Boralus,
    },
    TheUnderrot = {},
    OperationMechagon = {},
    MistsofTirnaScithe = {},
    TheNecroticWake = {},
    DeOtherSide = {},
    HallsofAtonement = {},
    Plaguefall = {},
    SanguineDepths = {},
    SpiresofAscension = {},
    TheaterofPain = {},
    Tazavesh = {},
    RubyLifePools = {},
    TheNokhudOffensive = {},
    TheAzureVault = {},
    AlgetharAcademy = {},
    UldamanLegacyofTyr = {},
    Neltharus = {},
    BrackenhideHollow = {},
    HallsofInfusion = {},
    TheVortexPinnacle = {},
    ThroneoftheTides = {
        mage.Valdrakken, -- tbh, there isn't really any 'good' alternative for this one
    },
    DawnoftheInfinite = {
        portals.HallsofInfusion,
        portals.AlgetharAcademy,
        toys.EngiWormholeDragonIsles,
        portals.RubyLifePools,
        mage.Valdrakken,
    },
};
