local _, ns = ...

-- Mercader's own list of rumours: vendors known for limited-stock goods, so the map is not empty on day one.
--
-- Where it comes from (put together by hand, item by item, on 18 Nov 2026):
--   * Who sells what, and whether somebody already saw it in Forever: the public item pages of foreverdb.net
--     (one look-up per item below). `classic = true` marks a vendor that site still lists with Classic data
--     only, that is, nobody confirmed it in Forever yet.
--   * `place` is the town or spot the vendor is known to stand in, from Classic. x and y are that TOWN's
--     position, to the nearest point of the map: they say "around here", not "exactly here", and the game
--     shows them as approximate. A vendor without x and y is listed for its zone and has no mark on the map.
--   * `road` is for a vendor that walks a road instead of standing still.
--
-- Nothing here is treated as true by the addon: the first time the player opens the vendor's window, what the
-- player saw replaces the rumour (real position, real stock). The map ids are the client's uiMapIDs.
--
-- side: "A" Alliance, "H" Horde, nil = both can buy.

local BARRENS, STONETALON, DUSTWALLOW, DESOLACE, FERALAS, MOONGLADE = 1413, 1442, 1445, 1443, 1444, 1450
local ELWYNN, WETLANDS, HILLSBRAD, SILVERPINE, DUSKWOOD, WESTFALL = 1429, 1437, 1424, 1421, 1431, 1436
local LOCH_MODAN, REDRIDGE, STRANGLETHORN, SWAMP, ALTERAC = 1432, 1433, 1434, 1435, 1416
local STORMWIND, ORGRIMMAR, IRONFORGE, THUNDER_BLUFF, DARNASSUS, UNDERCITY = 1453, 1454, 1455, 1456, 1457, 1458

-- towns: { x, y } in points of the zone's map (0-100)
local CROSSROADS, RATCHET = { 52, 30 }, { 62, 37 }
local THERAMORE, BRACKENWALL = { 66, 48 }, { 36, 31 }
local MENETHIL, TARREN_MILL, SOUTHSHORE = { 10, 58 }, { 62, 20 }, { 50, 58 }
local SEPULCHER, DARKSHIRE, THELSAMAR, LAKESHIRE = { 43, 41 }, { 74, 46 }, { 35, 47 }, { 27, 45 }
local BOOTY_BAY, GROMGOL, STONARD = { 27, 77 }, { 32, 28 }, { 45, 54 }
local SHADOWPREY, MOJACHE = { 24, 71 }, { 75, 44 }

local function at(town, place)
	return { x = town[1] / 100, y = town[2] / 100, place = place }
end

local seed = {
	-- Kalimdor
	{ "Lizzarik", BARRENS, nil, { road = "The Crossroads - Ratchet" }, { 4778, 4777, 4765, 4766, 858, 2455 } },
	{ "Vrang Wildgore", BARRENS, "H", {}, { 4778, 4777, 4765, 4766, 4797, 4798, 4799, 4800, 4816 } },
	{ "Nargal Deatheye", BARRENS, "H", at(CROSSROADS, "The Crossroads"), { 4765, 4766 } },
	{ "Halija Whitestrider", BARRENS, "H", at(CROSSROADS, "The Crossroads"), { 4790, 4792, 4793, 4781, 4782, 4786 } },
	{ "Grazlix", BARRENS, nil, at(RATCHET, "Ratchet"), { 4797, 4798, 4799, 4800, 4816, 4820, 4821, 4822 } },
	{ "Vexspindle", BARRENS, nil, at(RATCHET, "Ratchet"), { 4794, 4796 } },
	{ "Kiknikle", BARRENS, nil, {}, { 4781, 4782, 4786, 5772 } },
	{ "Pizznukle", BARRENS, nil, {}, { 4788, 4789 } },
	{ "Veenix", STONETALON, nil, { x = 0.58, y = 0.51, place = "Windshear Crag" }, { 4817, 4818, 4836, 4838, 4837, 7561 } },
	{ "Nizzik", STONETALON, nil, {}, { 4827, 4828, 4829, 4830, 4831, 4832, 4833, 4835 } },
	{
		"Piter Verance",
		DUSTWALLOW,
		"A",
		at(THERAMORE, "Theramore Isle"),
		{ 4817, 4818, 4824, 4825, 4826, 4830, 4831, 4832, 4833, 4835 },
	},
	{ "Marie Holdston", DUSTWALLOW, "A", at(THERAMORE, "Theramore Isle"), { 12248, 12250 } },
	{ "Zulrg", DUSTWALLOW, "H", at(BRACKENWALL, "Brackenwall Village"), { 12250, 12251 } },
	{ "Hae'Wilani", DESOLACE, "H", at(SHADOWPREY, "Shadowprey Village"), { 12249, 12250 } },
	{ "Worb Strongstitch", FERALAS, "H", at(MOJACHE, "Camp Mojache"), { 12253, 12254 }, true },
	{ "Cawind Trueaim", FERALAS, "H", at(MOJACHE, "Camp Mojache"), { 11308 }, true },
	{ "Kharedon", MOONGLADE, nil, { place = "Nighthaven" }, { 12254 } },
	{ "Narianna", MOONGLADE, nil, { place = "Nighthaven" }, { 11308 }, true },
	{ "Tor'phan", ORGRIMMAR, "H", {}, { 12255 } },
	{ "Handor", ORGRIMMAR, "H", {}, { 12256 } },
	{ "Delgo Ragetotem", THUNDER_BLUFF, "H", {}, { 12249 } },
	{ "Kuna Thunderhorn", THUNDER_BLUFF, "H", {}, { 11307 } },
	{ "Landria", DARNASSUS, "A", {}, { 11308 } },
	{ "Vinasia", DARNASSUS, "A", {}, { 12256 } },
	{ "Turian", DARNASSUS, "A", {}, { 12247 }, true },
	{ "Glorandiir", DARNASSUS, "A", {}, { 12249 }, true },
	-- Eastern Kingdoms
	{ "Antonio Perelli", ELWYNN, "A", {}, { 4817, 4818, 4778, 4777, 4794, 4795, 4796, 858 }, true },
	{ "Frederick Stover", STORMWIND, "A", {}, { 11307 } },
	{ "Charys Yserian", STORMWIND, "A", {}, { 4824, 4825, 4826, 4827, 4828, 4829 }, true },
	{ "Skolmin Goldfury", IRONFORGE, "A", {}, { 11307 } },
	{ "Abigail Sawyer", UNDERCITY, "H", {}, { 11307 } },
	{ "Brak Durnad", WETLANDS, "A", at(MENETHIL, "Menethil Harbor"), { 4817, 4818 } },
	{
		"Jennabink Powerseam",
		WETLANDS,
		"A",
		at(MENETHIL, "Menethil Harbor"),
		{ 4790, 4792, 4793, 4827, 4828, 4829, 5772 },
	},
	{ "Dark Iron Entrepreneur", WETLANDS, nil, {}, { 4824, 4825, 4826, 4830, 4831, 4832, 4833, 4835 } },
	{ "Wenna Silkbeard", WETLANDS, "A", {}, { 4827, 4828, 4829, 4830, 4831, 4832, 4833, 4835 }, true },
	{ "Kixxle", WETLANDS, nil, {}, { 929 } },
	{ "Ott", HILLSBRAD, "H", at(TARREN_MILL, "Tarren Mill"), { 4817, 4818, 4824, 4825, 4826, 12247, 12249 } },
	{
		"Robert Aebischer",
		HILLSBRAD,
		"A",
		at(SOUTHSHORE, "Southshore"),
		{ 4797, 4798, 4799, 4800, 4816, 4833, 4835 },
	},
	{
		"Zixil",
		HILLSBRAD,
		nil,
		{ road = "Tarren Mill - Southshore" },
		{ 4836, 4838, 4837, 4827, 4828, 4829, 7561, 5772 },
	},
	{ "Kris Legace", HILLSBRAD, nil, {}, { 4794, 4795, 4796, 4830, 4831, 4832 } },
	{ "Wallace the Blind", SILVERPINE, nil, {}, { 4817, 4818, 4777, 4778, 929 } },
	{ "Alexandre Lefevre", SILVERPINE, "H", at(SEPULCHER, "The Sepulcher"), { 4788, 4789 } },
	{ "Andrea Boynton", SILVERPINE, "H", at(SEPULCHER, "The Sepulcher"), { 4781, 4782, 4786 } },
	{ "Kzixx", DUSKWOOD, nil, {}, { 4836, 4838, 4837, 4827, 4828, 4829, 7561, 6053, 929 } },
	{ "Gavin Gnarltree", DUSKWOOD, "A", at(DARKSHIRE, "Darkshire"), { 12247, 12249 } },
	{ "Morg Gnarltree", DUSKWOOD, "A", at(DARKSHIRE, "Darkshire"), { 4797, 4798, 4799, 4800, 4816 } },
	{ "Defias Profiteer", WESTFALL, nil, {}, { 4788, 4789, 5640 } },
	{ "Kat Sampson", LOCH_MODAN, "A", at(THELSAMAR, "Thelsamar"), { 4788, 4789 } },
	{ "Aldren Cordon", LOCH_MODAN, "A", at(THELSAMAR, "Thelsamar"), { 4781, 4782, 4786 } },
	{ "Morhan Coppertongue", LOCH_MODAN, "A", at(THELSAMAR, "Thelsamar"), { 4765, 4766 } },
	{ "Nillen Andemar", LOCH_MODAN, "A", {}, { 4778, 4777 } },
	{ "Xandar Goodbeard", LOCH_MODAN, "A", {}, { 5640, 6053 } },
	{ "Bernard Brubaker", REDRIDGE, "A", at(LAKESHIRE, "Lakeshire"), { 4794, 4795, 4796 } },
	{ "Franklin Hamar", REDRIDGE, "A", at(LAKESHIRE, "Lakeshire"), { 4781, 4782, 4786 } },
	{ "Kara Adams", REDRIDGE, "A", at(LAKESHIRE, "Lakeshire"), { 4820, 4821, 4822 } },
	{ "Captured Servant of Azora", REDRIDGE, nil, {}, { 4790, 4792, 4793 } },
	{ "Kizz Bluntstrike", STRANGLETHORN, nil, at(BOOTY_BAY, "Booty Bay"), { 4777, 4778 } },
	{ "Jutak", STRANGLETHORN, nil, at(BOOTY_BAY, "Booty Bay"), { 12248 } },
	{ "Zarena Cromwind", STRANGLETHORN, nil, at(BOOTY_BAY, "Booty Bay"), { 12251, 12252 } },
	{ "Jaquilina Dramet", STRANGLETHORN, nil, at(BOOTY_BAY, "Booty Bay"), { 12250 } },
	{ "Vharr", STRANGLETHORN, "H", at(GROMGOL, "Grom'gol Base Camp"), { 12248, 12250 } },
	{ "Masat T'andr", SWAMP, nil, {}, { 12253, 12254 } },
	{ "Thralosh", SWAMP, "H", at(STONARD, "Stonard"), { 12255, 12256 }, true },
	{ "Bro'kin", ALTERAC, nil, {}, { 14634, 858 }, true },
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
