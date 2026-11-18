local _, ns = ...

-- Mercader's own list of rumours: vendors known for limited-stock goods, so the map is not empty on day one.
--
-- Where it comes from (put together by hand, vendor by vendor, on 18 Nov 2026):
--   * Who sells what, and whether somebody already saw it in Forever: the public item pages of foreverdb.net
--     (one look-up per item below). `classic = true` marks a vendor that site still lists with Classic data
--     only, that is, nobody confirmed it in Forever yet.
--   * Where: the town or spot each vendor's page on warcraft.wiki.gg names (one look-up per vendor). x and y
--     are that TOWN's or spot's position, to the nearest point of the map. For a town they are the town's
--     centre; for a lone spot they are the page's own coordinates when it gives them and they are of the old
--     world (the wiki also describes the world after Cataclysm, whose maps of cities and of some zones do not
--     match: those were placed by the district or landmark the page names). They say "around here", not
--     "exactly here", and the game shows them as approximate. A vendor without x and y is listed for its
--     zone and has no mark on the map.
--   * `road` is for a vendor that walks a road instead of standing still: its mark is somewhere along it.
--
-- Nothing here is treated as true by the addon: the first time the player opens the vendor's window, what the
-- player saw replaces the rumour (real position, real stock). The map ids are the client's uiMapIDs.
--
-- side: "A" Alliance, "H" Horde, nil = both can buy.

local BARRENS, STONETALON, DUSTWALLOW, DESOLACE, FERALAS, MOONGLADE = 1413, 1442, 1445, 1443, 1444, 1450
local ELWYNN, WETLANDS, HILLSBRAD, SILVERPINE, DUSKWOOD, WESTFALL = 1429, 1437, 1424, 1421, 1431, 1436
local LOCH_MODAN, REDRIDGE, STRANGLETHORN, SWAMP, ALTERAC = 1432, 1433, 1434, 1435, 1416
local STORMWIND, ORGRIMMAR, IRONFORGE, THUNDER_BLUFF, DARNASSUS, UNDERCITY = 1453, 1454, 1455, 1456, 1457, 1458

-- A town or spot: its position in points of the zone's map (0-100) and its name.
local function at(x, y, place)
	return { x = x / 100, y = y / 100, place = place }
end
-- A vendor that walks a road: a point along it and the road's ends.
local function road(x, y, route)
	return { x = x / 100, y = y / 100, road = route }
end

local CROSSROADS, RATCHET = at(52, 30, "The Crossroads"), at(62, 37, "Ratchet")
local LUSHWATER = at(42, 38, "Lushwater Oasis")
local THERAMORE, BRACKENWALL = at(66, 48, "Theramore Isle"), at(36, 31, "Brackenwall Village")
local MOJACHE, NIGHTHAVEN = at(75, 44, "Camp Mojache"), at(53, 42, "Nighthaven")
local TRADESMEN = at(58, 57, "Tradesmen's Terrace")
local MENETHIL = at(10, 58, "Menethil Harbor")
local TARREN_MILL, SOUTHSHORE = at(62, 20, "Tarren Mill"), at(50, 58, "Southshore")
local SEPULCHER, DARKSHIRE = at(43, 41, "The Sepulcher"), at(74, 46, "Darkshire")
local THELSAMAR, FARSTRIDER = at(35, 47, "Thelsamar"), at(82, 63, "Farstrider Lodge")
local LAKESHIRE, BOOTY_BAY = at(27, 45, "Lakeshire"), at(27, 77, "Booty Bay")

local seed = {
	-- Kalimdor
	{ "Lizzarik", BARRENS, nil, road(57, 34, "The Crossroads - Ratchet"), { 4778, 4777, 4765, 4766, 858, 2455 } },
	{
		"Vrang Wildgore",
		BARRENS,
		"H",
		at(44, 12, "Dreadmist Peak"),
		{ 4778, 4777, 4765, 4766, 4797, 4798, 4799, 4800, 4816 },
	},
	{ "Nargal Deatheye", BARRENS, "H", CROSSROADS, { 4765, 4766 } },
	{ "Halija Whitestrider", BARRENS, "H", CROSSROADS, { 4790, 4792, 4793, 4781, 4782, 4786 } },
	{ "Grazlix", BARRENS, nil, RATCHET, { 4797, 4798, 4799, 4800, 4816, 4820, 4821, 4822 } },
	{ "Vexspindle", BARRENS, nil, RATCHET, { 4794, 4796 } },
	{ "Kiknikle", BARRENS, nil, LUSHWATER, { 4781, 4782, 4786, 5772 } },
	{ "Pizznukle", BARRENS, nil, LUSHWATER, { 4788, 4789 } },
	{ "Veenix", STONETALON, nil, at(58, 51, "Windshear Crag"), { 4817, 4818, 4836, 4838, 4837, 7561 } },
	{ "Nizzik", STONETALON, nil, at(62, 40, "Cragpool Lake"), { 4827, 4828, 4829, 4830, 4831, 4832, 4833, 4835 } },
	{ "Piter Verance", DUSTWALLOW, "A", THERAMORE, { 4817, 4818, 4824, 4825, 4826, 4830, 4831, 4832, 4833, 4835 } },
	{ "Marie Holdston", DUSTWALLOW, "A", THERAMORE, { 12248, 12250 } },
	{ "Zulrg", DUSTWALLOW, "H", BRACKENWALL, { 12250, 12251 } },
	{ "Hae'Wilani", DESOLACE, "H", at(26, 71, "Shadowprey Village"), { 12249, 12250 } },
	{ "Worb Strongstitch", FERALAS, "H", MOJACHE, { 12253, 12254 }, true },
	{ "Cawind Trueaim", FERALAS, "H", MOJACHE, { 11308 }, true },
	{ "Kharedon", MOONGLADE, nil, NIGHTHAVEN, { 12254 } },
	{ "Narianna", MOONGLADE, nil, NIGHTHAVEN, { 11308 }, true },
	{ "Tor'phan", ORGRIMMAR, "H", at(63, 50, "The Drag"), { 12255 } },
	{ "Handor", ORGRIMMAR, "H", at(63, 45, "The Drag"), { 12256 } },
	{ "Delgo Ragetotem", THUNDER_BLUFF, "H", at(45, 55, "High Rise"), { 12249 } },
	{ "Kuna Thunderhorn", THUNDER_BLUFF, "H", at(45, 55, "Middle Rise"), { 11307 } },
	{ "Landria", DARNASSUS, "A", TRADESMEN, { 11308 } },
	{ "Vinasia", DARNASSUS, "A", TRADESMEN, { 12256 } },
	{ "Turian", DARNASSUS, "A", TRADESMEN, { 12247 }, true },
	{ "Glorandiir", DARNASSUS, "A", TRADESMEN, { 12249 }, true },
	-- Eastern Kingdoms
	{
		"Antonio Perelli",
		ELWYNN,
		"A",
		road(42, 65, "Lakeshire - Goldshire - Sentinel Hill - Darkshire"),
		{ 4817, 4818, 4778, 4777, 4794, 4795, 4796, 858 },
		true,
	},
	{ "Frederick Stover", STORMWIND, "A", at(51, 58, "Trade District"), { 11307 } },
	{ "Charys Yserian", STORMWIND, "A", at(39, 79, "Mage Quarter"), { 4824, 4825, 4826, 4827, 4828, 4829 }, true },
	{ "Skolmin Goldfury", IRONFORGE, "A", at(70, 72, "Military Ward"), { 11307 } }, -- seen there in Forever, 18 Nov
	{ "Abigail Sawyer", UNDERCITY, "H", { place = "War Quarter" }, { 11307 } },
	{ "Brak Durnad", WETLANDS, "A", MENETHIL, { 4817, 4818 } },
	{ "Jennabink Powerseam", WETLANDS, "A", MENETHIL, { 4790, 4792, 4793, 4827, 4828, 4829, 5772 } },
	{
		"Dark Iron Entrepreneur",
		WETLANDS,
		nil,
		{ place = "Thandol Span" },
		{ 4824, 4825, 4826, 4830, 4831, 4832, 4833, 4835 },
	},
	{
		"Wenna Silkbeard",
		WETLANDS,
		"A",
		at(26, 26, "Sundown Marsh"),
		{ 4827, 4828, 4829, 4830, 4831, 4832, 4833, 4835 },
		true,
	},
	{ "Kixxle", WETLANDS, nil, at(50, 38), { 929 } },
	{ "Ott", HILLSBRAD, "H", TARREN_MILL, { 4817, 4818, 4824, 4825, 4826, 12247, 12249 } },
	{ "Robert Aebischer", HILLSBRAD, "A", SOUTHSHORE, { 4797, 4798, 4799, 4800, 4816, 4833, 4835 } },
	{
		"Zixil",
		HILLSBRAD,
		nil,
		road(56, 38, "Tarren Mill - Southshore"),
		{ 4836, 4838, 4837, 4827, 4828, 4829, 7561, 5772 },
	},
	{ "Kris Legace", HILLSBRAD, nil, at(79, 40, "Durnholde Keep"), { 4794, 4795, 4796, 4830, 4831, 4832 } },
	-- seen at 43.9, 84.5 in Forever on 18 Nov (the wiki's North Tide's Run is where he stands after Cataclysm)
	{ "Wallace the Blind", SILVERPINE, nil, at(44, 85), { 4817, 4818, 4777, 4778, 929 } },
	{ "Alexandre Lefevre", SILVERPINE, "H", SEPULCHER, { 4788, 4789 } },
	{ "Andrea Boynton", SILVERPINE, "H", SEPULCHER, { 4781, 4782, 4786 } },
	{
		"Kzixx",
		DUSKWOOD,
		nil,
		at(82, 20, "Darkened Bank"),
		{ 4836, 4838, 4837, 4827, 4828, 4829, 7561, 6053, 929 },
	},
	{ "Gavin Gnarltree", DUSKWOOD, "A", DARKSHIRE, { 12247, 12249 } },
	{ "Morg Gnarltree", DUSKWOOD, "A", DARKSHIRE, { 4797, 4798, 4799, 4800, 4816 } },
	{ "Defias Profiteer", WESTFALL, nil, at(43, 66, "Moonbrook"), { 4788, 4789, 5640 } },
	{ "Kat Sampson", LOCH_MODAN, "A", FARSTRIDER, { 4788, 4789 } },
	{ "Xandar Goodbeard", LOCH_MODAN, "A", FARSTRIDER, { 5640, 6053 } },
	{ "Aldren Cordon", LOCH_MODAN, "A", at(65, 66, "Ironband's Excavation Site"), { 4781, 4782, 4786 } },
	{ "Morhan Coppertongue", LOCH_MODAN, "A", THELSAMAR, { 4765, 4766 } },
	{ "Nillen Andemar", LOCH_MODAN, "A", at(42, 10, "Stonewrought Dam"), { 4778, 4777 } },
	{ "Bernard Brubaker", REDRIDGE, "A", { place = "Stonewatch Falls" }, { 4794, 4795, 4796 } },
	{ "Franklin Hamar", REDRIDGE, "A", LAKESHIRE, { 4781, 4782, 4786 } },
	{ "Kara Adams", REDRIDGE, "A", LAKESHIRE, { 4820, 4821, 4822 } },
	{ "Captured Servant of Azora", REDRIDGE, nil, at(74, 79, "Render's Valley"), { 4790, 4792, 4793 } },
	{ "Kizz Bluntstrike", STRANGLETHORN, nil, BOOTY_BAY, { 4777, 4778 } },
	{ "Jutak", STRANGLETHORN, nil, BOOTY_BAY, { 12248 } },
	{ "Zarena Cromwind", STRANGLETHORN, nil, BOOTY_BAY, { 12251, 12252 } },
	{ "Jaquilina Dramet", STRANGLETHORN, nil, at(36, 11, "Nesingwary's Expedition"), { 12250 } },
	{ "Vharr", STRANGLETHORN, "H", at(32, 28, "Grom'gol Base Camp"), { 12248, 12250 } },
	{ "Masat T'andr", SWAMP, nil, at(26, 31), { 12253, 12254 } },
	{ "Thralosh", SWAMP, "H", at(45, 54, "Stonard"), { 12255, 12256 }, true },
	{ "Bro'kin", ALTERAC, nil, at(44, 21, "Ruins of Alterac"), { 14634, 858 }, true },
}

-- The list in the shape the rest of the addon reads: one table per rumour, with a key that never changes
-- between versions (name and zone), so a hidden or a confirmed rumour stays so after an update.
ns.Seed = {}
for _, row in ipairs(seed) do
	local name, map, side, where, items, classic = row[1], row[2], row[3], row[4], row[5], row[6]
	ns.Seed[#ns.Seed + 1] = {
		key = name .. "@" .. map,
		name = name,
		map = map,
		side = side,
		x = where.x,
		y = where.y,
		place = where.place,
		road = where.road,
		items = items,
		classic = classic and true or false,
	}
end
