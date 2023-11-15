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
    local spellID = self.spellMap[mapId];
    self.buttons[icon]:RegisterSpell(spellID); -- nil will unregister the spell

    if not spellID then return; end
    self.buttons[icon]:Show();

    return;
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
        self.highlight:SetAlpha(spellID and IsSpellKnown(spellID) and 1 or 0);
    end

    function button:GetRegisteredSpell()
        return self.spellID;
    end

    button:SetScript("OnEnter", function(button, ...)
        button:GetParent():GetScript("OnEnter")(button:GetParent(), ...);
        local spell = button:GetRegisteredSpell();
        if spell and GameTooltip:IsShown() and IsSpellKnown(spell) then
            self:AddInfoToTooltip(GameTooltip, spell);
        end
    end)

    button:SetScript("OnLeave", function(button, ...)
        button:GetParent():GetScript("OnLeave")(button:GetParent(), ...);
    end)

    return button;
end

Module.spellMap = {
    [2] = 131204, -- Temple of the Jade Serpent
    [165] = 159899, -- Shadowmoon Burial Grounds
    [166] = 159900, -- Grimrail Depot
    [168] = 159901, -- The Everbloom
    [169] = 159896, -- Iron Docks
    [198] = 424163, -- Darkheart Thicket
    [199] = 424153, -- Black Rook Hold
    [200] = 393764, -- Halls of Valor
    [206] = 410078, -- Neltharion's Lair
    [210] = 393766, -- Court of Stars
    [227] = 373262, -- Return to Karazhan: Lower
    [234] = 373262, -- Return to Karazhan: Upper
    [244] = 424187, -- Atal'Dazar
    [245] = 410071, -- Freehold
    [248] = 424167, -- Waycrest Manor
    [251] = 410074, -- The Underrot
    [369] = 373274, -- Operation: Mechagon - Junkyard
    [370] = 373274, -- Operation: Mechagon - Workshop
    [375] = 354464, -- Mists of Tirna Scithe
    [376] = 354462, -- The Necrotic Wake
    [377] = 354468, -- De Other Side
    [378] = 354465, -- Halls of Atonement
    [379] = 354463, -- Plaguefall
    [380] = 354469, -- Sanguine Depths
    [381] = 354466, -- Spires of Ascension
    [382] = 354467, -- Theater of Pain
    [391] = 367416, -- Tazavesh: Streets of Wonder
    [392] = 367416, -- Tazavesh: So'leah's Gambit
    [399] = 393256, -- Ruby Life Pools
    [400] = 393262, -- The Nokhud Offensive
    [401] = 393279, -- The Azure Vault
    [402] = 393273, -- Algeth'ar Academy
    [403] = 393222, -- Uldaman: Legacy of Tyr
    [404] = 393276, -- Neltharus
    [405] = 393267, -- Brackenhide Hollow
    [406] = 393283, -- Halls of Infusion
    [438] = 410080, -- The Vortex Pinnacle
    [456] = 424142, -- Throne of the Tides
    [463] = 424197, -- Dawn of the Infinite: Galakrond's Fall
    [464] = 424197, -- Dawn of the Infinite: Murozond's Rise
}
