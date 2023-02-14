local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('DungeonIconTooltip', 'AceHook-3.0');

function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ChallengesUI', function()
        self:SecureHook(ChallengesFrame, 'Update', function()
            for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
                if not self:IsHooked(icon, 'OnEnter') then
                    self:SecureHookScript(icon, 'OnEnter', function()
                        Module:OnTooltipShow(GameTooltip, icon);
                    end);
                end
            end
        end);
    end);
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetName()
    return 'Dungeon Icon Tooltip';
end

function Module:GetDescription()
    return 'Adds individual affix rating information to the dungeon icon tooltip in the LFG frame.';
end

function Module:GetOptions(defaultOptionsTable)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Open Mythic+ UI',
        desc = 'Open the Mythic+ UI and hover over a dungeon icon to see an example.',
        func = function()
            PVEFrame_ToggleFrame('ChallengesFrame');
        end,
    };

    return defaultOptionsTable;
end

function Module:OnTooltipShow(tooltip, icon)
    if not icon.mapID then return; end

    local mapId = icon.mapID;
    local affixScores, _ = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapId);

    local linesLeft, linesRight = Util:ExtractTooltipLines(tooltip);
    if(affixScores and #affixScores > 0) then
        self:ProcessAffixScores(linesLeft, linesRight, affixScores);
    end

    if(not self:MapIdIsAddedToTooltip(linesLeft, mapId)) then
        table.insert(linesLeft, {text='|cFFEE6161ID|r ' .. mapId});
        table.insert(linesRight, {text=''});
    end

    Util:ReplaceTooltipLines(tooltip, linesLeft, linesRight);
end

function Module:ProcessAffixScores(linesLeft, linesRight, affixScores)
    local higherScore, higherAffix = 0, nil;
    for _, affixInfo in ipairs(affixScores) do
        if affixInfo.score > higherScore then
            higherScore = affixInfo.score;
            higherAffix = affixInfo.name;
        end
    end
    for _, affixInfo in ipairs(affixScores) do
        local affixName, score = affixInfo.name, affixInfo.score;
        local color = C_ChallengeMode.GetSpecificDungeonScoreRarityColor(score);
        local multiplier = affixName == higherAffix and '|cFFFFFFFF (x1.5)|r' or '|cFFFFFFFF (x0.5)|r';
        for i, line in ipairs(linesLeft) do
            if string.find(line.text, affixName) then
                table.insert(linesLeft, i+3, {text='Affix rating: ' .. color:WrapTextInColorCode(score) .. multiplier});
                table.insert(linesRight, i+3, {text=''});
                break
            end
        end
    end
end

function Module:MapIdIsAddedToTooltip(linesLeft, mapId)
    for _, line in ipairs(linesLeft) do
        if string.find(line.text, mapId) and string.find(line.text:lower(), 'id') then
            return true;
        end
    end
    return false;
end
