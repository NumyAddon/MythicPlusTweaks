--- @class MPT_NS
local MPT = select(2, ...);
--- @class MPT_Data
local Data = {}
MPT.Data = Data

local isMidnight = select(4, GetBuildInfo()) >= 120001

--- @type table<number, number> # [activityID] = challengeModeMapID - there is currently no in-game way to get the ChallengeModeMapId from the ActivityID, so we have to resort to a hardcoded map
Data.ActivityIdToChallengeMapIdMap = {
    [1192] = 2, -- Temple of the Jade Serpent
    [182] = 161, -- Skyreach
    [1695] = 163, -- Bloodmaul Slag Mines
    [1193] = 165, -- Shadowmoon Burial Grounds
    [183] = 166, -- Grimrail Depot
    [184] = 168, -- The Everbloom
    [180] = 169, -- Iron Docks
    [459] = 197, -- Eye of Azshara
    [1782] = 197, -- Eye of Azshara
    [460] = 198, -- Darkheart Thicket
    [1788] = 198, -- Darkheart Thicket
    [463] = 199, -- Black Rook Hold
    [1790] = 199, -- Black Rook Hold
    [461] = 200, -- Halls of Valor
    [1783] = 200, -- Halls of Valor
    [462] = 206, -- Neltharion's Lair
    [1785] = 206, -- Neltharion's Lair
    [464] = 207, -- Vault of the Wardens
    [1795] = 207, -- Vault of the Wardens
    [465] = 208, -- Maw of Souls
    [1787] = 208, -- Maw of Souls
    [467] = 209, -- The Arcway
    [1791] = 209, -- The Arcway
    [466] = 210, -- Court of Stars
    [1789] = 210, -- Court of Stars
    [476] = 233, -- Cathedral of Eternal Night
    [471] = 227, -- Return to Karazhan: Lower
    [473] = 234, -- Return to Karazhan: Upper
    [1793] = 234, -- Return to Karazhan: Upper
    [1794] = 234, -- Return to Karazhan: Upper
    [486] = 239, -- Seat of the Triumvirate
    [1786] = 239, -- Seat of the Triumvirate
    [502] = 244, -- Atal'Dazar
    [518] = 245, -- Freehold
    [526] = 246, -- Tol Dagor
    [510] = 247, -- The MOTHERLODE!!
    [530] = 248, -- Waycrest Manor
    [514] = 249, -- Kings' Rest
    [661] = 249, -- Kings' Rest
    [504] = 250, -- Temple of Sethraliss
    [507] = 251, -- The Underrot
    [522] = 252, -- Shrine of the Storm
    [534] = 353, -- Siege of Boralus
    [659] = 353, -- Siege of Boralus
    [679] = 369, -- Operation: Mechagon - Junkyard
    [683] = 370, -- Operation: Mechagon - Workshop
    [703] = 375, -- Mists of Tirna Scithe
    [713] = 376, -- The Necrotic Wake
    [695] = 377, -- De Other Side
    [699] = 378, -- Halls of Atonement
    [691] = 379, -- Plaguefall
    [705] = 380, -- Sanguine Depths
    [709] = 381, -- Spires of Ascension
    [717] = 382, -- Theater of Pain
    [1016] = 391, -- Tazavesh: Streets of Wonder
    [1017] = 392, -- Tazavesh: So'leah's Gambit
    [1176] = 399, -- Ruby Life Pools
    [1184] = 400, -- The Nokhud Offensive
    [1180] = 401, -- The Azure Vault
    [1160] = 402, -- Algeth'ar Academy
    [1188] = 403, -- Uldaman: Legacy of Tyr
    [1172] = 404, -- Neltharus
    [1164] = 405, -- Brackenhide Hollow
    [1168] = 406, -- Halls of Infusion
    [1195] = 438, -- The Vortex Pinnacle
    [1274] = 456, -- Throne of the Tides
    [1247] = 463, -- Dawn of the Infinite: Galakrond's Fall
    [1248] = 464, -- Dawn of the Infinite: Murozond's Rise
    [1281] = 499, -- Priory of the Sacred Flame
    [1283] = 500, -- The Rookery
    [1287] = 501, -- The Stonevault
    [1288] = 502, -- City of Threads
    [1284] = 503, -- Ara-Kara, City of Echoes
    [1282] = 504, -- Darkflame Cleft
    [1285] = 505, -- The Dawnbreaker
    [1286] = 506, -- Cinderbrew Meadery
    [1290] = 507, -- Grim Batol
    [1550] = 525, -- Operation: Floodgate
    [1702] = 541, -- The Stonecore
    [1694] = 542, -- Eco-Dome Al'dani
    [1770] = 556, -- Pit of Saron
    [1542] = 557, -- Windrunner Spire
    [1760] = 558, -- Magisters' Terrace
    [1768] = 559, -- Nexus-Point Xenas
    [1764] = 560, -- Maisara Caverns

};

Data.Portals = {};
do
    Data.Portals.TYPE_DUNGEON_PORTAL = 'dungeon_portal';
    Data.Portals.TYPE_TOY = 'toy';
    Data.Portals.TYPE_CLASS_TELEPORT = 'mage_teleport';
    Data.Portals.TYPE_HEARTHSTONE = 'hearthstone';
    -- not used directly, but as a subtype for TYPE_HEARTHSTONE
    Data.Portals.TYPE_ITEM = 'item';

    local function toy(itemID)
        return {
            icon = select(5, C_Item.GetItemInfoInstant(itemID)),
            itemID = itemID,
            available = function()
                return PlayerHasToy(itemID) and C_ToyBox.IsToyUsable(itemID);
            end,
            cooldown = function() return C_Item.GetItemCooldown(itemID); end,
            type = Data.Portals.TYPE_TOY,
        };
    end
    local function spell(spellIDs, type)
        local function getSpellID()
            for _, spellID in ipairs(spellIDs) do
                if C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false) then
                    return spellID;
                end
            end

            return nil;
        end

        return {
            icon = C_Spell.GetSpellTexture(getSpellID() or spellIDs[1]),
            spellID = function() return getSpellID() or spellIDs[1] end,
            available = function()
                return nil ~= getSpellID();
            end,
            cooldown = function()
                local spellCooldownInfo = C_Spell.GetSpellCooldown(getSpellID() or spellIDs[1]);
                if spellCooldownInfo then
                    return spellCooldownInfo.startTime, spellCooldownInfo.duration, spellCooldownInfo.isEnabled;
                end
            end,
            type = type,
        };
    end
    local function dungeonPortal(spellID, ...)
        return spell({ spellID, ... }, Data.Portals.TYPE_DUNGEON_PORTAL);
    end
    local function classTeleport(spellID)
        return spell({ spellID }, Data.Portals.TYPE_CLASS_TELEPORT);
    end
    local hearthstoneImplementations = { -- implementations that share a cooldown, go into the same subtable
        {
            classTeleport(556), -- Astral Recall
        },
        {
            { -- Hearthstone
                icon = select(5, C_Item.GetItemInfoInstant(6948)),
                itemID = 6948,
                available = function()
                    return C_Item.GetItemCount(6948) > 0;
                end,
                cooldown = function()
                    return C_Item.GetItemCooldown(6948);
                end,
                type = Data.Portals.TYPE_ITEM,
            },
            toy(166747), -- Brewfest Reveler's Hearthstone
            toy(190237), -- Broker Translocation Matrix
            toy(246565), -- Cosmic Hearthstone
            toy(93672), -- Dark Portal
            toy(208704), -- Deepdweller's Earthen Hearthstone
            toy(188952), -- Dominated Hearthstone
            toy(210455), -- Draenic Hologem
            toy(190196), -- Enlightened Hearthstone
            toy(172179), -- Eternal Traveler's Hearthstone
            toy(54452), -- Ethereal Portal
            toy(236687), -- Explosive Hearthstone
            toy(166746), -- Fire Eater's Hearthstone
            toy(162973), -- Greatfather Winter's Hearthstone
            toy(163045), -- Headless Horseman's Hearthstone
            toy(209035), -- Hearthstone of the Flame
            toy(168907), -- Holographic Digitalization Hearthstone
            toy(184353), -- Kyrian Hearthstone
            toy(165669), -- Lunar Elder's Hearthstone
            toy(182773), -- Necrolord Hearthstone
            toy(180290), -- Night Fae Hearthstone
            toy(165802), -- Noble Gardener's Hearthstone
            toy(228940), -- Notorious Thread's Hearthstone
            toy(200630), -- Ohn'ir Windsage's Hearthstone
            toy(245970), -- P.O.S.T. Master's Express Hearthstone
            toy(206195), -- Path of the Naaru
            toy(165670), -- Peddlefeet's Lovely Hearthstone
            toy(235016), -- Redeployment Module
            toy(212337), -- Stone of the Hearth
            toy(64488), -- The Innkeeper's Daughter
            toy(193588), -- Timewalker's Hearthstone
            toy(142542), -- Tome of Town Portal
            toy(183716), -- Venthyr Sinstone
        }
    };
    local function hearthstone(areaID)
        local areaName = C_Map.GetAreaInfo(areaID);

        return {
            available = function()
                return GetBindLocation() == areaName;
            end,
            type = Data.Portals.TYPE_HEARTHSTONE,
            implementations = hearthstoneImplementations,
        };
    end

    local hearthstones = {
        CurrentHub = hearthstone(isMidnight and 16645 or 14771), -- the current hub generally has a portal to seasonal dungeons from older expansions
        SilvermoonMidnight = hearthstone(16645),
        Tazavesh = hearthstone(15781),
        Dornogal = hearthstone(14771),
        Valdrakken = hearthstone(13862),
    };

    local toys = {
        GarrisonHearthstone = toy(110560),
        DalaranHearthstone = toy(140192),
        EngiWormholeDraenor = toy(112059), -- Engineering, can select which zone to go to
        EngiWormholeNorthrend = toy(48933), -- Engineering, can't select zone
        EngiWormholePandaria = toy(87215), -- Engineering, can't select zone
        EngiWormholeArgus = toy(151652), -- Engineering, can't select zone
        EngiWormholeZandalar = toy(168808), -- Engineering, can't select zone
        EngiWormholeKulTiras = toy(168807), -- Engineering, can't select zone
        EngiWormholeShadowlands = toy(172924), -- Engineering, can select which zone to go to
        EngiWormholeDragonIsles = toy(198156), -- Engineering, can select which zone to go to
        EngiWormholeKhazAlgar = toy(221966), -- Engineering, can select which zone to go to
        EngiWormholeQuelThalas = toy(248485), -- Engineering, can't select zone (todo: verify)
        EngiToshelysStation = toy(30544), -- Gnomish Engineering, Blade's Edge Mountains, northern Outland
        EngiGadgetzan = toy(18986), -- Gnomish Engineering, Tanaris, north-east of Uldum
        EngiArea52 = toy(30542), -- Goblin Engineering, Netherstorm, northern Outland
        EngiEverlook = toy(18984), -- Goblin Engineering, Winterspring, north of Mount Hyjal, probably kinda useless for this ;)
    };
    local mage = {
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
        SilvermoonTbc = classTeleport(32272),
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
        Dornogal = classTeleport(446540),
        -- @todo: are they adding a new silvermoon teleport spell? the old one brings you to Silvermoon TBC
        CurrentHub = classTeleport(isMidnight and 0 or 446540), -- the current hub generally has a portal to seasonal dungeons from older expansions
    };
    local others = {
        DruidDreamwalk = classTeleport(193753),
        CastleNathria = dungeonPortal(373190), -- requires clearing on mythic in SL S4
    };

    Data.Portals.dungeonPortals = {
        TempleoftheJadeSerpent = dungeonPortal(131204),
        StormstoutBrewery = dungeonPortal(131205),
        GateoftheSettingSun = dungeonPortal(131225),
        ShadoPanMonastery = dungeonPortal(131206),
        SiegeofNiuzaoTemple = dungeonPortal(131228),
        MogushanPalace = dungeonPortal(131222),
        Scholomance = dungeonPortal(131232),
        ScarletHalls = dungeonPortal(131231),
        ScarletMonastery = dungeonPortal(131229),
        Skyreach = dungeonPortal(159898, 1254557),
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
        SeatoftheTriumvirate = dungeonPortal(1254551),
        AtalDazar = dungeonPortal(424187),
        Freehold = dungeonPortal(410071),
        TheMOTHERLODE = dungeonPortal(467553, 467555),
        WaycrestManor = dungeonPortal(424167),
        TheUnderrot = dungeonPortal(410074),
        SiegeofBoralus = dungeonPortal(445418, 464256),
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
        PrioryoftheSacredFlame = dungeonPortal(445444),
        TheRookery = dungeonPortal(445443),
        TheStonevault = dungeonPortal(445269),
        CityofThreads = dungeonPortal(445416),
        AraKaraCityofEchoes = dungeonPortal(445417),
        DarkflameCleft = dungeonPortal(445441),
        TheDawnbreaker = dungeonPortal(445414),
        CinderbrewMeadery = dungeonPortal(445440, 467546),
        GrimBatol = dungeonPortal(445424),
        OperationFloodgate = dungeonPortal(1216786),
        --TheStonecore = dungeonPortal(2), -- not implemented yet
        EcoDomeAldani = dungeonPortal(1237215),
        PitofSaron = dungeonPortal(1254555),
        WindrunnerSpire = dungeonPortal(1254400),
        MagistersTerrace = dungeonPortal(1254572),
        NexusPointXenas = dungeonPortal(1254563),
        MaisaraCaverns = dungeonPortal(1254559),
    };

    Data.Portals.maps = {
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
        [197] = 'EyeofAzshara',
        [198] = 'DarkheartThicket',
        [199] = 'BlackRookHold',
        [200] = 'HallsofValor',
        [206] = 'NeltharionsLair',
        [207] = 'VaultoftheWardens',
        [208] = 'MawofSouls',
        [209] = 'TheArcway',
        [210] = 'CourtofStars',
        [227] = 'ReturntoKarazhan',
        [233] = 'CathedralofEternalNight',
        [234] = 'ReturntoKarazhan',
        [239] = 'SeatoftheTriumvirate',
        [244] = 'AtalDazar',
        [245] = 'Freehold',
        [246] = 'TolDagor',
        [247] = 'TheMOTHERLODE',
        [248] = 'WaycrestManor',
        [249] = 'KingsRest',
        [250] = 'TempleofSethraliss',
        [251] = 'TheUnderrot',
        [252] = 'ShrineoftheStorm',
        [353] = 'SiegeofBoralus',
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
        [499] = 'PrioryoftheSacredFlame',
        [500] = 'TheRookery',
        [501] = 'TheStonevault',
        [502] = 'CityofThreads',
        [503] = 'AraKaraCityofEchoes',
        [504] = 'DarkflameCleft',
        [505] = 'TheDawnbreaker',
        [506] = 'CinderbrewMeadery',
        [507] = 'GrimBatol',
        [525] = 'OperationFloodgate',
        [541] = 'TheStonecore',
        [542] = 'EcoDomeAldani',
        [556] = 'PitofSaron',
        [557] = 'WindrunnerSpire',
        [558] = 'MagistersTerrace',
        [559] = 'NexusPointXenas',
        [560] = 'MaisaraCaverns',
    };

    local dungeon = Data.Portals.dungeonPortals;
    Data.Portals.alternates = {
        TempleoftheJadeSerpent = {},
        StormstoutBrewery = {},
        GateoftheSettingSun = {},
        ShadoPanMonastery = {},
        SiegeofNiuzaoTemple = {},
        MogushanPalace = {},
        Scholomance = {},
        ScarletHalls = {},
        ScarletMonastery = {},
        Skyreach = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
            dungeon.Auchindoun,
            dungeon.ShadowmoonBurialGrounds,
        },
        BloodmaulSlagMines = {},
        Auchindoun = {},
        ShadowmoonBurialGrounds = {},
        GrimrailDepot = {},
        UpperBlackrockSpire = {},
        TheEverbloom = {
            dungeon.GrimrailDepot,
            dungeon.IronDocks,
            toys.EngiWormholeDraenor,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        IronDocks = {},
        EyeofAzshara = {},
        DarkheartThicket = {
            dungeon.BlackRookHold,
            others.DruidDreamwalk,
            dungeon.NeltharionsLair,
            dungeon.CourtofStars,
            toys.DalaranHearthstone,
            mage.LegionOrderHall,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        BlackRookHold = {
            dungeon.DarkheartThicket,
            others.DruidDreamwalk,
            dungeon.NeltharionsLair,
            dungeon.CourtofStars,
            mage.LegionOrderHall,
            toys.DalaranHearthstone,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        HallsofValor = {},
        NeltharionsLair = {},
        VaultoftheWardens = {},
        MawofSouls = {},
        TheArcway = {},
        CourtofStars = {},
        ReturntoKarazhan = {},
        CathedralofEternalNight = {},
        SeatoftheTriumvirate = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
            toys.EngiWormholeArgus,
            toys.DalaranHearthstone,
        },
        AtalDazar = {
            mage.Dazaralor,
            dungeon.TheMOTHERLODE,
            toys.EngiWormholeZandalar,
            dungeon.TheUnderrot,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        Freehold = {},
        TolDagor = {},
        TheMOTHERLODE = {
            mage.Dazaralor,
            dungeon.AtalDazar,
            toys.EngiWormholeZandalar,
            dungeon.TheUnderrot,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        WaycrestManor = {
            dungeon.OperationMechagon,
            dungeon.Freehold,
            toys.EngiWormholeKulTiras,
            mage.Boralus,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        KingsRest = {},
        TempleofSethraliss = {},
        TheUnderrot = {},
        ShrineoftheStorm = {},
        SiegeofBoralus = {
            dungeon.Freehold,
            toys.EngiWormholeKulTiras,
            mage.Boralus,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        OperationMechagon = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        MistsofTirnaScithe = {
            dungeon.DeOtherSide,
            mage.Oribos,
            toys.EngiWormholeShadowlands,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        TheNecroticWake = {
            dungeon.SpiresofAscension,
            mage.Oribos,
            toys.EngiWormholeShadowlands,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        DeOtherSide = {
            dungeon.MistsofTirnaScithe,
            mage.Oribos,
            toys.EngiWormholeShadowlands,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        HallsofAtonement = {
            dungeon.SanguineDepths,
            others.CastleNathria,
            mage.CurrentHub,
            hearthstones.CurrentHub,
            toys.EngiWormholeShadowlands,
        },
        Plaguefall = {},
        SanguineDepths = {
            others.CastleNathria,
            dungeon.HallsofAtonement,
            mage.CurrentHub,
            hearthstones.CurrentHub,
            toys.EngiWormholeShadowlands,
        },
        SpiresofAscension = {
            dungeon.TheNecroticWake,
            mage.Oribos,
            toys.EngiWormholeShadowlands,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        TheaterofPain = {
            dungeon.Plaguefall,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        Tazavesh = {
            dungeon.EcoDomeAldani,
            hearthstones.Tazavesh,
            mage.CurrentHub,
            hearthstones.CurrentHub,
            mage.Oribos,
            toys.EngiWormholeShadowlands,
        },
        RubyLifePools = {
            mage.Valdrakken,
            hearthstones.Valdrakken,
            toys.EngiWormholeDragonIsles,
            dungeon.Neltharus, -- not so great options frankly
            dungeon.AlgetharAcademy,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        TheNokhudOffensive = {
            toys.EngiWormholeDragonIsles,
            mage.Valdrakken,
            hearthstones.Valdrakken,
            dungeon.RubyLifePools, -- not great
            dungeon.Neltharus,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        TheAzureVault = {
            dungeon.BrackenhideHollow,
            toys.EngiWormholeDragonIsles,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        AlgetharAcademy = {
            dungeon.HallsofInfusion,
            dungeon.DawnoftheInfinite,
            mage.Valdrakken,
            hearthstones.Valdrakken,
            dungeon.RubyLifePools,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        UldamanLegacyofTyr = {
            mage.Valdrakken, -- tbh, there isn't really any 'good' alternative for this one
            hearthstones.Valdrakken,
            dungeon.GrimBatol,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        Neltharus = {
            dungeon.RubyLifePools,
            dungeon.TheNokhudOffensive,
            toys.EngiWormholeDragonIsles,
            mage.Valdrakken,
            hearthstones.Valdrakken,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        BrackenhideHollow = {
            dungeon.TheAzureVault,
            toys.EngiWormholeDragonIsles,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        HallsofInfusion = {
            dungeon.DawnoftheInfinite,
            dungeon.AlgetharAcademy,
            toys.EngiWormholeDragonIsles,
            mage.Valdrakken,
            hearthstones.Valdrakken,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        TheVortexPinnacle = {},
        ThroneoftheTides = {
            mage.CurrentHub, -- tbh, there isn't really any 'good' alternative for this one
            hearthstones.CurrentHub,
        },
        DawnoftheInfinite = {
            dungeon.HallsofInfusion,
            dungeon.AlgetharAcademy,
            toys.EngiWormholeDragonIsles,
            mage.Valdrakken,
            hearthstones.Valdrakken,
            dungeon.RubyLifePools,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        PrioryoftheSacredFlame = {
            dungeon.TheDawnbreaker,
            toys.EngiWormholeKhazAlgar,
            mage.Dornogal,
            hearthstones.Dornogal,
        },
        TheRookery = {
            mage.Dornogal,
            hearthstones.Dornogal,
            dungeon.CinderbrewMeadery,
            toys.EngiWormholeKhazAlgar,
        },
        TheStonevault = {
            dungeon.DarkflameCleft,
            dungeon.OperationFloodgate,
            mage.Dornogal,
            hearthstones.Dornogal,
            toys.EngiWormholeKhazAlgar,
        },
        CityofThreads = {
            dungeon.AraKaraCityofEchoes,
            mage.Dornogal,
            hearthstones.Dornogal,
            toys.EngiWormholeKhazAlgar,
        },
        AraKaraCityofEchoes = {
            dungeon.CityofThreads,
            mage.Dornogal,
            hearthstones.Dornogal,
            toys.EngiWormholeKhazAlgar,
        },
        DarkflameCleft = {
            dungeon.TheStonevault,
            dungeon.OperationFloodgate,
            mage.Dornogal,
            hearthstones.Dornogal,
            toys.EngiWormholeKhazAlgar,
        },
        TheDawnbreaker = {
            dungeon.PrioryoftheSacredFlame,
            toys.EngiWormholeKhazAlgar,
            mage.Dornogal,
            hearthstones.Dornogal,
        },
        CinderbrewMeadery = {
            mage.Dornogal,
            hearthstones.Dornogal,
            dungeon.TheRookery,
            toys.EngiWormholeKhazAlgar,
        },
        GrimBatol = {
            dungeon.UldamanLegacyofTyr, -- not great still :/
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        OperationFloodgate = {
            dungeon.TheStonevault,
            dungeon.DarkflameCleft,
            mage.Dornogal,
            hearthstones.Dornogal,
            toys.EngiWormholeKhazAlgar,
        },
        TheStonecore = {},
        EcoDomeAldani = {
            dungeon.Tazavesh,
            hearthstones.Tazavesh,
            mage.CurrentHub,
            hearthstones.CurrentHub,
        },
        PitofSaron = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
            mage.DalaranNorthrend,
            toys.EngiWormholeNorthrend,
        },
        WindrunnerSpire = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
            hearthstones.SilvermoonMidnight,
            dungeon.MaisaraCaverns,
        },
        MagistersTerrace = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
            hearthstones.SilvermoonMidnight,
        },
        NexusPointXenas = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
            hearthstones.SilvermoonMidnight,
        },
        MaisaraCaverns = {
            mage.CurrentHub,
            hearthstones.CurrentHub,
            hearthstones.SilvermoonMidnight,
            dungeon.WindrunnerSpire,
        },
    };

end
