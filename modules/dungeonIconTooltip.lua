local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('DungeonIconTooltip', 'AceHook-3.0');

function Module:OnEnable()
    self:SecureHook(GameTooltip, 'Show', function(tooltip) Module:OnTooltipShow(tooltip); end);
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

function Module:OnTooltipShow(tooltip)
    if self.skipOnTooltipShow then return end
    local owner = tooltip.GetOwner and tooltip:GetOwner() or nil
    if not owner then return end

    local parent = owner.GetParent and owner:GetParent() or nil
    if parent ~= ChallengesFrame or not owner.mapID then return end

    local mapId = owner.mapID
    local affixScores, _ = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapId);

    local linesLeft, linesRight = self:ExtractTooltipLines(tooltip)
    if(affixScores and #affixScores > 0) then
        self:ProcessAffixScores(linesLeft, linesRight, affixScores)
    end

    if(not self:MapIdIsAddedToTooltip(linesLeft, mapId)) then
        table.insert(linesLeft, {text='|cFFEE6161ID|r ' .. mapId})
        table.insert(linesRight, {text=''})
    end

    tooltip:ClearLines()
    for i = 1, max(#linesLeft, #linesRight) do
        local left = linesLeft[i] or ''
        local right = linesRight[i] or ''

        tooltip:AddDoubleLine(left.text, right.text, left.r, left.g, left.b, right.r, right.g, right.b)
    end

    self.skipOnTooltipShow = true
    tooltip:Show()
    self.skipOnTooltipShow = nil
end

function Module:ProcessAffixScores(linesLeft, linesRight, affixScores)
    local higherScore, higherAffix = 0, nil
    for _, affixInfo in ipairs(affixScores) do
        if affixInfo.score > higherScore then
            higherScore = affixInfo.score
            higherAffix = affixInfo.name
        end
    end
    for _, affixInfo in ipairs(affixScores) do
        local affixName, score = affixInfo.name, affixInfo.score
        local color = C_ChallengeMode.GetSpecificDungeonScoreRarityColor(score)
        local multiplier = affixName == higherAffix and '|cFFFFFFFF (x1.5)|r' or '|cFFFFFFFF (x0.5)|r'
        for i, line in ipairs(linesLeft) do
            if string.find(line.text, affixName) then
                table.insert(linesLeft, i+3, {text='Affix rating: ' .. color:WrapTextInColorCode(score) .. multiplier})
                table.insert(linesRight, i+3, {text=''})
                break
            end
        end
    end
end

function Module:MapIdIsAddedToTooltip(linesLeft, mapId)
    for _, line in ipairs(linesLeft) do
        if string.find(line.text, mapId) then
            return true
        end
    end
    return false
end

function Module:ExtractTooltipLines(tooltip)
    local linesLeft, linesRight = {}, {}
    for i = 1, 15 do
        local lineLeft = _G[tooltip:GetName() .. 'TextLeft' .. i]
        local lineRight = _G[tooltip:GetName() .. 'TextRight' .. i]

        local left, right
        if lineLeft then left = lineLeft:GetText() end
        if lineRight then right = lineRight:GetText() end

        if not left and not right then break end
        local leftR, leftG, leftB, _ = lineLeft:GetTextColor()
        local rightR, rightG, rightB, _ = lineRight:GetTextColor()
        table.insert(linesLeft, {text=left, r=leftR, g=leftG, b=leftB})
        table.insert(linesRight, {text=right, r=rightR, g=rightG, b=rightB})
    end
    return linesLeft, linesRight
end