-- What Mercader needs on top of wow_mock.lua: items with their class, a vendor window a test fills, the
-- player's faction, maps with their kind and parent, the user waypoint and a world map with a canvas.

-- items: id -> { name, quality, class, sub } (classes as Enum.ItemClass: 0 consumable, 1 container, 2 weapon,
-- 4 armour, 7 trade goods, 9 recipe). `cached = false` hides the name until MOCK.cacheItem(id).
MOCK.itemData = {
	[4817] = { name = "Blessed Claymore", quality = 2, class = 2, sub = 8 },
	[4818] = { name = "Executioner's Sword", quality = 2, class = 2, sub = 8 },
	[4778] = { name = "Heavy Spiked Mace", quality = 2, class = 2, sub = 5 },
	[4777] = { name = "Ironwood Maul", quality = 2, class = 2, sub = 5 },
	[4765] = { name = "Enamelled Broadsword", quality = 2, class = 2, sub = 7 },
	[4766] = { name = "Feral Blade", quality = 2, class = 2, sub = 7 },
	[4788] = { name = "Agile Boots", quality = 2, class = 4, sub = 2 },
	[4789] = { name = "Stable Boots", quality = 2, class = 4, sub = 2 },
	[858] = { name = "Lesser Healing Potion", quality = 1, class = 0, sub = 1 },
	[2455] = { name = "Minor Mana Potion", quality = 1, class = 0, sub = 1 },
	[5640] = { name = "Recipe: Rage Potion", quality = 1, class = 9, sub = 6 },
	[4496] = { name = "Small Brown Pouch", quality = 1, class = 1, sub = 0 },
	[2512] = { name = "Rough Arrow", quality = 1, class = 6, sub = 2 },
	[4540] = { name = "Tough Hunk of Bread", quality = 1, class = 0, sub = 5 },
	[2488] = { name = "Gladius", quality = 1, class = 2, sub = 7 },
	[2320] = { name = "Coarse Thread", quality = 1, class = 7, sub = 0 },
	[4340] = { name = "Gray Dye", quality = 1, class = 7, sub = 0 },
}
function MOCK.cacheItem(id)
	MOCK.itemData[id].cached = nil
end

local function idOf(v)
	return tonumber(v) or tonumber(tostring(v):match("item:(%d+)"))
end
C_Item = {
	GetItemInfoInstant = function(v)
		local id = idOf(v)
		local it = MOCK.itemData[id]
		if not it then
			return nil
		end
		return id, "", "", "", 134400, it.class, it.sub
	end,
	GetItemNameByID = function(v)
		local it = MOCK.itemData[idOf(v)]
		return it and it.cached ~= false and it.name or nil
	end,
	GetItemQualityByID = function(v)
		local it = MOCK.itemData[idOf(v)]
		return it and it.cached ~= false and it.quality or nil
	end,
	GetItemInfo = function(v)
		local id = idOf(v)
		local it = MOCK.itemData[id]
		if not it or it.cached == false then
			return nil
		end
		return it.name, "|cnIQ" .. it.quality .. ":|Hitem:" .. id .. "::::::::|h[" .. it.name .. "]|h|r"
	end,
	RequestLoadItemDataByID = function(id)
		MOCK.requested = MOCK.requested or {}
		table.insert(MOCK.requested, id)
	end,
}

-- the vendor window: MOCK.merchant = { name, npc = id, items = { { id, stock, price } } } (stock -1 = no limit)
MOCK.merchant = nil
MerchantFrame = CreateFrame("Frame", "MerchantFrame")
MerchantFrame:Hide()
function GetMerchantNumItems()
	return MOCK.merchant and #MOCK.merchant.items or 0
end
function GetMerchantItemID(i)
	local line = MOCK.merchant and MOCK.merchant.items[i]
	return line and line[1]
end
function GetMerchantItemLink(i)
	local line = MOCK.merchant and MOCK.merchant.items[i]
	if not line then
		return nil
	end
	local _, link = C_Item.GetItemInfo(line[1])
	return link
end
C_MerchantFrame = {
	GetItemInfo = function(i)
		local line = MOCK.merchant and MOCK.merchant.items[i]
		if not line then
			return nil
		end
		-- the window names the item even when the client has not loaded it (MOCK.merchant.nameless = it does not)
		local it = MOCK.itemData[line[1]]
		local name = it and not MOCK.merchant.nameless and it.name or nil
		return { name = name, texture = 1, price = line[3] or 0, stackCount = 1, numAvailable = line[2] or -1, isPurchasable = true }
	end,
}
function MOCK.openMerchant(merchant)
	MOCK.merchant = merchant
	MerchantFrame:Show()
	MOCK.fire("MERCHANT_SHOW")
end

local unitName, unitGUID = UnitName, UnitGUID
function UnitName(unit)
	if unit == "npc" then
		return MOCK.merchant and MOCK.merchant.name
	end
	return unitName(unit)
end
function UnitGUID(unit)
	if unit == "npc" then
		local m = MOCK.merchant
		if not m or m.npc == nil then
			return nil
		end
		return (m.kind or "Creature") .. "-0-4400-1-22-" .. m.npc .. "-00001A2B3C"
	end
	return unitGUID(unit)
end
function UnitFactionGroup()
	return MOCK.player.side or "Alliance"
end

-- maps: id -> { name, mapType (2 continent, 3 zone), parentMapID }; rects: child zone on its continent
MOCK.mapInfo = {
	[1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 },
	[1415] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
	[1413] = { name = "The Barrens", mapType = 3, parentMapID = 1414 },
	[1442] = { name = "Stonetalon Mountains", mapType = 3, parentMapID = 1414 },
	[1429] = { name = "Elwynn Forest", mapType = 3, parentMapID = 1415 },
	[1436] = { name = "Westfall", mapType = 3, parentMapID = 1415 },
	[1424] = { name = "Hillsbrad Foothills", mapType = 3, parentMapID = 1415 },
	[1453] = { name = "Stormwind City", mapType = 3, parentMapID = 1415 },
}
MOCK.rects = { [1413] = { 0.4, 0.6, 0.3, 0.6 } } -- minX, maxX, minY, maxY on the parent
C_Map.GetMapInfo = function(id)
	local info = MOCK.mapInfo[id]
	if not info then
		return nil
	end
	return { mapID = id, name = info.name, mapType = info.mapType, parentMapID = info.parentMapID }
end
C_Map.GetMapRectOnMap = function(child)
	local r = MOCK.rects[child]
	if not r then
		return 0, 0, 0, 0
	end
	return r[1], r[2], r[3], r[4]
end
MOCK.waypoints = {}
MOCK.canWaypoint = true
C_Map.CanSetUserWaypointOnMap = function()
	return MOCK.canWaypoint
end
C_Map.SetUserWaypoint = function(point)
	table.insert(MOCK.waypoints, { map = point.uiMapID, x = point.position.x, y = point.position.y })
end
C_SuperTrack = {
	SetSuperTrackedUserWaypoint = function(on)
		MOCK.superTracked = on
	end,
}
function CreateVector2D(x, y)
	return { x = x, y = y }
end
Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3 }

-- the world map: a frame with a canvas of 1000 x 600, the zone it shows and its zoom
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
WorldMapFrame:Hide()
MOCK.canvas = CreateFrame("Frame", nil, WorldMapFrame)
MOCK.canvas:SetSize(1000, 600)
MOCK.shownMap = 1413
MOCK.canvasScale = 0.5
function WorldMapFrame:GetCanvas()
	return MOCK.canvas
end
function WorldMapFrame:GetCanvasContainer()
	return self
end
function WorldMapFrame:GetMapID()
	return MOCK.shownMap
end
function WorldMapFrame:GetCanvasScale()
	return MOCK.canvasScale
end
-- the game's own marks have absolute frame levels from 2000 up; the points of interest sit at 2023 here
function WorldMapFrame:GetPinFrameLevelsManager()
	return {
		GetValidFrameLevel = function(_, kind)
			MOCK.levelAsked = kind
			return MOCK.poiLevel
		end,
	}
end
MOCK.poiLevel = 2023
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:OnCanvasScaleChanged() end
MOCK.openedMaps = {}
function OpenWorldMap(map)
	table.insert(MOCK.openedMaps, map)
	MOCK.shownMap = map
	WorldMapFrame:Show()
end
function IsShiftKeyDown()
	return MOCK.shift or false
end

-- the minimap: 140 px across, its zoom, whether it turns with the player; zones' sizes in yards
Minimap:SetSize(140, 140)
MOCK.zoom, MOCK.indoors, MOCK.facing, MOCK.cvars = 0, false, 0, { rotateMinimap = "0" }
function Minimap:GetZoom()
	return MOCK.zoom
end
function IsIndoors()
	return MOCK.indoors
end
function GetPlayerFacing()
	return MOCK.facing
end
function GetCVar(name)
	return MOCK.cvars[name]
end
MOCK.zoneYards = { [1413] = { 10000, 6000 } } -- width, height
C_Map.GetWorldPosFromMapPos = function(map, at)
	local size = MOCK.zoneYards[map]
	if not size then
		return nil, nil
	end
	-- (north-south, west-east), both growing towards the north and the west, as the game answers
	local ns_, we = 5000 - at.y * size[2], 3000 - at.x * size[1]
	return 1, {
		GetXY = function()
			return ns_, we
		end,
	}
end

C_Minimap = {
	GetViewRadius = function()
		return MOCK.viewRadius
	end,
}
