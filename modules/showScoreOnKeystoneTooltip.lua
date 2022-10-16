local _, MPT = ...;
--- @type Main
local Main = MPT.Main;
--- @type Util
local Util = MPT.Util;

local Module = Main:NewModule('ShowScoreOnKeystoneTooltip', 'AceHook-3.0');

function Module:OnInitialize()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        hooksecurefunc(GameTooltip, 'SetHyperlink', function(tooltip, hyperlink) Module:OnSetHyperlink(tooltip, hyperlink) end)
        hooksecurefunc(ItemRefTooltip, 'SetHyperlink', function(tooltip, hyperlink) Module:OnSetHyperlink(tooltip, hyperlink) end)
    end
end

function Module:OnEnable()
    self.enabled = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        -- uncomment if they fix the issue that data.hyperlink is a generic keystone item link instead of the specific keystone link
        --TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip, data) Module:TooltipPostCall(tooltip, data) end)
    else
        self:SecureHookScript(GameTooltip, 'OnTooltipSetItem', function(tooltip) Module:OnTooltipShow(tooltip); end);
        self:SecureHookScript(ItemRefTooltip, 'OnTooltipSetItem', function(tooltip) Module:OnTooltipShow(tooltip); end);
    end
end

function Module:OnDisable()
    self.enabled = false
    self:UnhookAll();
end

function Module:GetDescription()
    return 'Adds your mythic+ score to the keystone tooltip.';
end

function Module:GetName()
    return 'Show Score On Keystone Tooltip';
end

function Module:GetOptions(defaultOptionsTable)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Show Example Tooltip',
        desc = 'Open an example keystone tooltip.',
        func = function()
            local link = string.format('|cffa335ee|Hkeystone:180653:%d:16:10:1:2:3|h[Keystone]|h|r', C_ChallengeMode.GetMapTable()[1]);
            --local link = string.format('|cFFA335EE|Hitem:180653::::::::60:252::::6:17:%d:18:16:19:10:20:1:21:2:22:3:::::|h[Mythic Keystone]|h|r', C_ChallengeMode.GetMapTable()[1]);
            SetItemRef(link, link, 'LeftButton');
        end,
    };

    return defaultOptionsTable;
end

function Module:OnSetHyperlink(tooltip, hyperlink)
    if not self.enabled then return; end
    self:HandleHyperlink(tooltip, hyperlink);
end

function Module:TooltipPostCall(tooltip, data)
    local itemLink = data.hyperlink;
    if not itemLink then return; end

    self:HandleHyperlink(tooltip, itemLink);
end

function Module:OnTooltipShow(tooltip)
    local _, itemLink = tooltip:GetItem();
    if not itemLink then return end

    self:HandleHyperlink(tooltip, itemLink);
end

function Module:HandleHyperlink(tooltip, itemLink)
    local mapId = itemLink:match('keystone:%d+:(%d+)');
    if not mapId then
        local itemId = itemLink:match('item:(%d+)');
        if not itemId or not C_Item.IsItemKeystoneByID(itemId) then return end
        mapId = itemLink:match(string.format(':%s:(%%d+):', Enum.ItemModification.KeystoneMapChallengeModeID));
    end
    if not mapId then return end

    local overallInfo = Util:GetOverallInfoByMapId(mapId);
    local affixInfo = Util:GetAffixInfoByMapId(mapId);

    local linesLeft, linesRight = Util:ExtractTooltipLines(tooltip);

    for i, line in ipairs(linesLeft) do
        if string.find(line.text, CHALLENGE_MODE_ITEM_POWER_LEVEL) then
            if (overallInfo and overallInfo.score > 0) then
                table.insert(linesLeft, i + 1, {
                    text = HIGHLIGHT_FONT_COLOR:WrapTextInColorCode('Your Overall: '
                            .. overallInfo.scoreColor:WrapTextInColorCode(overallInfo.score)
                            .. ' (' .. overallInfo.levelColor:WrapTextInColorCode(overallInfo.level) .. ')'),
                });
                table.insert(linesRight, i + 1, { text = '' });
                if (affixInfo and affixInfo.score > 0) then
                    table.insert(linesLeft, i + 2, {
                        text = HIGHLIGHT_FONT_COLOR:WrapTextInColorCode('Your Affix score: '
                                .. affixInfo.scoreColor:WrapTextInColorCode(affixInfo.score)
                                .. ' (' .. affixInfo.levelColor:WrapTextInColorCode(affixInfo.level) .. ')'),
                    });
                    table.insert(linesRight, i + 2, { text = '' });
                else
                    table.insert(linesLeft, i + 2, {
                        text = HIGHLIGHT_FONT_COLOR:WrapTextInColorCode('Your Affix score: '
                                .. GRAY_FONT_COLOR:WrapTextInColorCode('-never completed-')),
                    });
                    table.insert(linesRight, i + 2, { text = '' });
                end
            else
                table.insert(linesLeft, i + 1, {
                    text = HIGHLIGHT_FONT_COLOR:WrapTextInColorCode('Your Overall: ' .. GRAY_FONT_COLOR:WrapTextInColorCode('-never completed-')),
                });
                table.insert(linesRight, i + 1, { text = '' });
            end
            break;
        end
    end

    Util:ReplaceTooltipLines(tooltip, linesLeft, linesRight);
end
