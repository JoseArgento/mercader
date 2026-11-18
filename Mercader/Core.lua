local ADDON, ns = ...
local L = ns.L

ns.ADDON = ADDON

-- Saved data (MercaderDB), the same for every character of the account:
--   settings = { lang, minimap, minimapAngle, point, pins, rumours, announce, otherSide,
--                cats = { gear, potion, recipe, bag, other } }
--   vendors  = { [key] = { name, npc, map, x, y, t, sides = { Alliance = true }, seed = seed key or nil,
--                          items = { [itemID] = { cat, stock, limited, price, t } } } }
--              key is "n<npc id>" (or the name and the map when the client hides the id). x and y are 0..1.
--              stock: how many were left the last time (-1 = always in stock, 0 = sold out).
--   hidden   = { [seed key] = true }   rumours the player took off the list

local listeners = {}
function ns.On(topic, fn)
	listeners[topic] = listeners[topic] or {}
	table.insert(listeners[topic], fn)
end
function ns.Fire(topic, ...)
	for _, fn in ipairs(listeners[topic] or {}) do
		fn(...)
	end
end

-- The kinds of goods Mercader writes down, in the order the chips show them.
ns.CATS = { "gear", "potion", "recipe", "bag", "other" }
ns.CAT_LABEL = { gear = "CAT_GEAR", potion = "CAT_POTION", recipe = "CAT_RECIPE", bag = "CAT_BAG", other = "CAT_OTHER" }

function ns.InitDB()
	if type(MercaderDB) ~= "table" then
		MercaderDB = {}
	end
	local db = MercaderDB
	db.version = 1
	db.settings = type(db.settings) == "table" and db.settings or {}
	local s = db.settings
	if s.lang ~= "es" and s.lang ~= "en" then
		s.lang = "auto"
	end
	for key, default in pairs({ minimap = true, pins = true, rumours = true, announce = true, otherSide = false }) do
		if type(s[key]) ~= "boolean" then
			s[key] = default
		end
	end
	if type(s.minimapAngle) ~= "number" then
		s.minimapAngle = 150
	end
	s.cats = type(s.cats) == "table" and s.cats or {}
	for _, cat in ipairs(ns.CATS) do
		if type(s.cats[cat]) ~= "boolean" then
			s.cats[cat] = true
		end
	end
	db.vendors = type(db.vendors) == "table" and db.vendors or {}
	db.hidden = type(db.hidden) == "table" and db.hidden or {}
	ns.db = db
	ns.ApplyLanguage(s.lang)
	-- the addon's own errors, kept here and shown with /mercader errores (Pergamino.Guard)
	db.errors = type(db.errors) == "table" and db.errors or {}
	ns.guard = Pergamino.Guard(ADDON, db, {
		slash = "/mercader",
		chat = function()
			ns.Print(L.ERR_NOTICE)
		end,
		L = { title = L.ERR_TITLE, empty = L.ERR_EMPTY, clear = L.ERR_CLEAR, copy = L.ERR_COPY },
	})
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L.TITLE .. ":|r " .. msg)
end

-- Copper as the game writes it ("12g 30s").
function ns.Money(copper)
	if GetMoneyString then
		return GetMoneyString(copper)
	end
	return math.floor(copper / 10000) .. "g"
end

-- "3 h", "2 d": how long ago t was.
function ns.Ago(t)
	local s = math.max(0, time() - (t or 0))
	if s < 90 then
		return L.AGO_NOW
	elseif s < 3600 then
		return L.AGO_MIN:format(math.floor(s / 60))
	elseif s < 86400 then
		return L.AGO_HOUR:format(math.floor(s / 3600))
	end
	return L.AGO_DAY:format(math.floor(s / 86400))
end

-- A zone's name as this client writes it (so it is in the client's language and never ours).
function ns.ZoneName(map)
	local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return info and info.name or L.UNKNOWN_ZONE:format(map or 0)
end

function ns.PlayerMap()
	return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
end

function ns.PlayerSide()
	local side = UnitFactionGroup and UnitFactionGroup("player")
	if side == "Alliance" or side == "Horde" then
		return side
	end
	return nil
end

-- An item's name, or nil while the client has not loaded it (it is asked for, and "items" fires when it comes).
function ns.ItemName(id)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not name and C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(id)
	end
	return name
end

function ns.ItemQuality(id)
	return C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id) or nil
end

-- The item as a link in ink, for a parchment page.
function ns.InkLink(id)
	return Pergamino.RefLink("item:" .. id, ns.ItemName(id) or L.ITEM_UNKNOWN:format(id), ns.ItemQuality(id) or 1)
end

-- The item as the game links it, for chat and dark tooltips.
function ns.GameLink(id)
	local _, link = nil, nil
	if C_Item and C_Item.GetItemInfo then
		_, link = C_Item.GetItemInfo(id)
	end
	return link or ("[" .. (ns.ItemName(id) or L.ITEM_UNKNOWN:format(id)) .. "]")
end

-- A mark on the game's own map, followed by the arrow. False when this client cannot.
function ns.Waypoint(map, x, y)
	if not (map and x and y and C_Map and C_Map.SetUserWaypoint and CreateVector2D) then
		return false
	end
	if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map) then
		return false
	end
	-- the point is the plain table UiMapPoint.CreateFromCoordinates builds (that helper is not in Forever)
	if not pcall(C_Map.SetUserWaypoint, { uiMapID = map, position = CreateVector2D(x, y) }) then
		return false
	end
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	end
	return true
end
