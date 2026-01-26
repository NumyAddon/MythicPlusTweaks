--- @class MPT_NS
local MPT = select(2, ...);

local issecretvalue = issecretvalue or function(val) return false; end;

--- @type MPT_Main
local Main = MPT.Main;
--- @type MPT_Util
local Util = MPT.Util;

--- @class MPT_ShowScoreOnKeystoneTooltip: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('ShowScoreOnKeystoneTooltip', 'AceHook-3.0');

function Module:OnEnable()
    self.enabled = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) Module:TooltipPostCall(tooltip) end);
end

function Module:OnDisable()
    self.enabled = false;
    self:UnhookAll();
end

function Module:GetDescription()
    return 'Adds your mythic+ score to the keystone tooltip.';
end

function Module:GetName()
    return 'Show Score On Keystone Tooltip';
end

--- @param configBuilder NumyConfigBuilder
function Module:BuildConfig(configBuilder)
    configBuilder:MakeButton(
        'Show Example Tooltip',
        function()
            local link = string.format(
                '|cffa335ee|Hkeystone:180653:%d:16:10:1:2:3|h[Keystone]|h|r',
                C_ChallengeMode.GetMapTable()[1]
            );
            --local link = string.format('|cFFA335EE|Hitem:180653::::::::60:252::::6:17:%d:18:16:19:10:20:1:21:2:22:3:::::|h[Mythic Keystone]|h|r', C_ChallengeMode.GetMapTable()[1]);
            SetItemRef(link, link, 'LeftButton');
        end,
        'Open an example keystone tooltip.'
    );
end

function Module:TooltipLinePostCall(tooltip, lineData)
    return
end

function Module:TooltipPostCall(tooltip)
    if not self.enabled then return end
    if InCombatLockdown() then return end
    if not tooltip or not tooltip.GetItem or not tooltip:IsShown() then return end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    self:HandleHyperlink(tooltip, itemLink)
end

function Module:HandleHyperlink(tooltip, itemLink)
    if InCombatLockdown() then return end
    if not tooltip or not tooltip:IsShown() then return end

    local mapId = itemLink:match('keystone:%d+:(%d+)');
    if not mapId then
        local itemId = itemLink:match('item:(%d+)');
        if not itemId or not C_Item.IsItemKeystoneByID(itemId) then return end
        mapId = itemLink:match(string.format(':%s:(%%d+):', Enum.ItemModification.KeystoneMapChallengeModeID));
    end
    if not mapId then return end

    local overallInfo = Util:GetOverallInfoByMapId(mapId);
    local affixInfo = Util.AFFIX_SPECIFIC_SCORES and Util:GetAffixInfoByMapId(mapId) or nil;

    if (overallInfo and overallInfo.score > 0) then
        tooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(
            'Your Overall: '
            .. overallInfo.scoreColor:WrapTextInColorCode(overallInfo.score)
            .. ' (' .. overallInfo.levelColor:WrapTextInColorCode(overallInfo.level) .. ')'
        ));
        if (affixInfo and affixInfo.score > 0) then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(
                'Your Affix score: '
                .. affixInfo.scoreColor:WrapTextInColorCode(affixInfo.score)
                .. ' (' .. affixInfo.levelColor:WrapTextInColorCode(affixInfo.level) .. ')'
            ));
        elseif Util.AFFIX_SPECIFIC_SCORES then
            tooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(
                'Your Affix score: ' .. GRAY_FONT_COLOR:WrapTextInColorCode('-never completed-')
            ));
        end
    else
        tooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(
            'Your Overall: ' .. GRAY_FONT_COLOR:WrapTextInColorCode('-never completed-')
        ));
    end
end
