local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('DungeonTeleports', 'AceHook-3.0', 'AceEvent-3.0');

local hooked = {};
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

function Module:GetOptions(defaultOptionsTable)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Open Mythic+ UI',
        desc = 'Open the Mythic+ UI and you\'ll be able to click any of the icons to teleport to the dungeons, if you have earned the Hero achievement.',
        func = function()
            PVEFrame_ToggleFrame('ChallengesFrame');
        end,
    };

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
        if not hooked[icon] then
            hooked[icon] = self:ProcessIcon(icon);
        end
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
    local spellID = self.spellMap[mapId];
    if not spellID then return false; end

    self.buttons[icon]:RegisterSpell(spellID);
    self.buttons[icon]:Show();

    return true;
end

function Module:MakeButton(parent)
    local button = CreateFrame('Button', nil, parent, 'InsecureActionButtonTemplate');
    button:Show()
    button:SetAllPoints();
    button:SetAttribute('type', 'spell');
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
        self:SetAttribute('spell', spellID);
        self.highlight:SetAlpha(IsSpellKnown(spellID) and 1 or 0);
    end

    function button:GetRegisteredSpell()
        return self.spellID;
    end

    button:SetScript("OnEnter", function(button, ...)
        button:GetParent():GetScript("OnEnter")(button:GetParent(), ...);
        if GameTooltip:IsShown() and IsSpellKnown(button:GetRegisteredSpell()) then
            self:AddInfoToTooltip(GameTooltip, button:GetRegisteredSpell());
        end
    end)

    button:SetScript("OnLeave", function(button, ...)
        button:GetParent():GetScript("OnLeave")(button:GetParent(), ...);
    end)

    return button;
end

Module.spellMap = {
    [2] = 131204, -- the Temple of the Jade Serpent
    [56] = 131205, -- Stormstout Brewery
    [58] = 131206, -- Shado-Pan Monastery
    [60] = 131222, -- Mogu'shan Palace
    [57] = 131225, -- Gate of the Setting Sun
    [59] = 131228, -- Siege of Niuzao
    [78] = 131229, -- Scarlet Monastery
    [77] = 131231, -- Scarlet Halls
    [76] = 131232, -- Scholomance
    [163] = 159895, -- Bloodmaul Slag Mines
    [169] = 159896, -- Iron Docks
    [164] = 159897, -- Auchindoun
    [161] = 159898, -- Skyreach
    [165] = 159899, -- Shadowmoon Burial Grounds
    [166] = 159900, -- Grimrail Depot
    [168] = 159901, -- The Everbloom
    [167] = 159902, -- Upper Blackrock Spire
    [376] = 354462, -- The Necrotic Wake
    [379] = 354463, -- Plaguefall
    [375] = 354464, -- Mists of Tirna Scithe
    [378] = 354465, -- Halls of Atonement
    [381] = 354466, -- Spires of Ascension
    [382] = 354467, -- Theater of Pain
    [377] = 354468, -- De Other Side
    [380] = 354469, -- Sanguine Depths
    [392] = 367416, -- Tazavesh: So'leah's Gambit
    [391] = 367416, -- Tazavesh: Streets of Wonder
    [370] = 373274, -- Operation: Mechagon - Workshop
    [369] = 373274, -- Operation: Mechagon - Junkyard
    [403] = 393222, -- Uldaman: Legacy of Tyr
    [399] = 393256, -- Ruby Life Pools
    [400] = 393262, -- The Nokhud Offensive
    [405] = 393267, -- Brackenhide Hollow
    [402] = 393273, -- Algeth'ar Academy
    [404] = 393276, -- Neltharus
    [401] = 393279, -- The Azure Vault
    [406] = 393283, -- Halls of Infusion
    [200] = 393764, -- Halls of Valor
    [210] = 393766, -- Court of Stars
    [245] = 410071, -- Freehold
    [251] = 410074, -- The Underrot
    [206] = 410078, -- Neltharion's Lair
    [438] = 410080, -- The Vortex Pinnacle
}
