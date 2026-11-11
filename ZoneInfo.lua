-- ExplorersMap: what the Guide knows of each zone: [uiMapID] = { min level, max level, owner, elites }.
-- owner: "A" Alliance, "H" Horde, "C" contested, "S" sanctuary. elites: 1 where elites or tightly
-- packed enemies stand near some areas. Levels and owners as the addon Zone Info: Forever lists them.

local _, ns = ...

ns.ZoneInfo = {
	-- Eastern Kingdoms
	[1416] = { 30, 40, "C", 1 },   -- Alterac Mountains
	[1417] = { 30, 40, "C" },      -- Arathi Highlands
	[1418] = { 35, 45, "C", 1 },   -- Badlands
	[1419] = { 45, 55, "C", 1 },   -- Blasted Lands
	[1428] = { 50, 58, "C", 1 },   -- Burning Steppes
	[1430] = { 55, 60, "C", 1 },   -- Deadwind Pass
	[1426] = { 1, 10, "A" },       -- Dun Morogh
	[1431] = { 18, 30, "C" },      -- Duskwood
	[1423] = { 53, 60, "C", 1 },   -- Eastern Plaguelands
	[1429] = { 1, 10, "A" },       -- Elwynn Forest
	[1424] = { 20, 30, "C" },      -- Hillsbrad Foothills
	[1432] = { 10, 20, "A" },      -- Loch Modan
	[1433] = { 15, 25, "C" },      -- Redridge Mountains
	[1427] = { 43, 50, "C", 1 },   -- Searing Gorge
	[1421] = { 10, 20, "H" },      -- Silverpine Forest
	[1434] = { 30, 45, "C", 1 },   -- Stranglethorn Vale
	[1435] = { 35, 45, "C" },      -- Swamp of Sorrows
	[1425] = { 40, 50, "C", 1 },   -- The Hinterlands
	[1420] = { 1, 10, "H" },       -- Tirisfal Glades
	[1436] = { 10, 20, "A" },      -- Westfall
	[1422] = { 51, 58, "C", 1 },   -- Western Plaguelands
	[1437] = { 20, 30, "C" },      -- Wetlands
	[2548] = { 35, 45, "C" },      -- Riverglades
	-- Kalimdor
	[1440] = { 18, 30, "C" },      -- Ashenvale
	[1447] = { 45, 55, "C", 1 },   -- Azshara
	[1439] = { 10, 20, "A" },      -- Darkshore
	[1443] = { 30, 40, "C" },      -- Desolace
	[1411] = { 1, 10, "H" },       -- Durotar
	[1445] = { 35, 45, "C", 1 },   -- Dustwallow Marsh
	[1448] = { 48, 55, "C", 1 },   -- Felwood
	[1444] = { 40, 50, "C", 1 },   -- Feralas
	[1450] = { nil, nil, "S" },    -- Moonglade
	[1412] = { 1, 10, "H" },       -- Mulgore
	[1451] = { 55, 60, "C", 1 },   -- Silithus
	[1442] = { 15, 27, "C" },      -- Stonetalon Mountains
	[1446] = { 40, 50, "C" },      -- Tanaris
	[1438] = { 1, 10, "A" },       -- Teldrassil
	[1413] = { 10, 25, "H" },      -- The Barrens
	[1441] = { 25, 35, "C" },      -- Thousand Needles
	[1449] = { 48, 55, "C", 1 },   -- Un'Goro Crater
	[1452] = { 55, 60, "C", 1 },   -- Winterspring
	[2482] = { 60, 60, "C", 1 },   -- Mount Hyjal
	[2652] = { 35, 45, "C" },      -- Shen'dralas
	-- islands
	[2521] = { 1, 12, "C" },       -- Zephras Isle
	[2665] = { 1, 12, "C" },       -- Zephras Isle
}
