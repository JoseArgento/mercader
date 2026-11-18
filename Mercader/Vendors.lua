local _, ns = ...

-- What Mercader knows, as one list: the vendors the player visited (MercaderDB.vendors) and the rumours of
-- the addon's own list (Seed.lua) that no visited vendor has replaced yet.

local V = {}
ns.Vendors = V

-- Item classes of the client (Enum.ItemClass); the numbers are the same in every flavour of the game.
local CLASS_CONSUMABLE, CLASS_CONTAINER, CLASS_WEAPON, CLASS_ARMOR, CLASS_RECIPE, CLASS_QUIVER = 0, 1, 2, 4, 9, 11
-- consumable subclasses that are a potion, an elixir or a flask
local POTION_SUB = { [1] = true, [2] = true, [3] = true }

-- Which kind of goods an item is for Mercader, or nil when it is not worth writing down.
--   gear    weapons and armour, only in limited stock (the greens a vendor has two of)
--   potion  potions, elixirs and flasks, whatever the stock
--   recipe  recipes in limited stock
--   bag     bags and quivers, whatever the stock
--   other   anything else in limited stock
function V.Classify(id, limited)
	local classID, subClassID
	if C_Item and C_Item.GetItemInfoInstant then
		local _
		_, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
	end
	if classID == CLASS_WEAPON or classID == CLASS_ARMOR then
		return limited and "gear" or nil
	elseif classID == CLASS_CONSUMABLE and POTION_SUB[subClassID] then
		return "potion"
	elseif classID == CLASS_RECIPE then
		return limited and "recipe" or nil
	elseif classID == CLASS_CONTAINER or classID == CLASS_QUIVER then
		return "bag"
	end
	return limited and "other" or nil
end

local seedByKey, seedByName
local function indexSeed()
	if seedByKey then
		return
	end
	seedByKey, seedByName = {}, {}
	for _, s in ipairs(ns.Seed) do
		seedByKey[s.key] = s
		seedByName[s.name:lower()] = s
	end
end

function V.SeedByKey(key)
	indexSeed()
	return seedByKey[key]
end

-- The rumour a vendor the player is talking to answers to: the one with the same name, or, when the client
-- writes names in another language, the only rumour of the zone that shares goods with what the vendor sells.
function V.MatchSeed(name, map, itemIDs)
	indexSeed()
	local byName = name and seedByName[name:lower()]
	if byName then
		return byName
	end
	local selling = {}
	for _, id in ipairs(itemIDs or {}) do
		selling[id] = true
	end
	local taken = {}
	for _, rec in pairs(ns.db.vendors) do
		if rec.seed then
			taken[rec.seed] = true
		end
	end
	local best, bestScore, tie = nil, 0, false
	for _, s in ipairs(ns.Seed) do
		if s.map == map and not taken[s.key] then
			local score = 0
			for _, id in ipairs(s.items) do
				if selling[id] then
					score = score + 1
				end
			end
			if score > bestScore then
				best, bestScore, tie = s, score, false
			elseif score == bestScore and score > 0 then
				tie = true
			end
		end
	end
	if best and not tie then
		return best
	end
	return nil
end

local function sideOk(entry, settings)
	if settings.otherSide then
		return true
	end
	local mine = ns.PlayerSide()
	if not mine then
		return true
	end
	if entry.seed and not entry.learned then
		return entry.side == nil or entry.side == mine:sub(1, 1)
	end
	-- a visited vendor: one of the player's characters of this faction talked to it, or nobody noted a side
	return entry.sides == nil or next(entry.sides) == nil or entry.sides[mine] == true
end

local function sortItems(items)
	local order = {}
	for i, cat in ipairs(ns.CATS) do
		order[cat] = i
	end
	table.sort(items, function(a, b)
		-- what the player saw first, what is only a rumour after it
		if (a.rumour or false) ~= (b.rumour or false) then
			return not a.rumour
		end
		if a.cat ~= b.cat then
			return (order[a.cat] or 9) < (order[b.cat] or 9)
		end
		return a.id < b.id
	end)
	return items
end

local function seedItems(s, skip)
	local out = {}
	for _, id in ipairs(s.items) do
		if not (skip and skip[id]) then
			out[#out + 1] = { id = id, cat = V.Classify(id, true) or "other", rumour = true }
		end
	end
	return out
end

-- Every vendor Mercader knows, visited ones and rumours, before any filter. Each entry:
--   { key, name, map, x, y, approx, place, road, learned, seed, classic, side, sides, t, items = { ... } }
-- An item is { id, cat, stock, limited, price, t } as the player saw it, or { id, cat, rumour = true }.
function V.All()
	indexSeed()
	local out, replaced = {}, {}
	for key, rec in pairs(ns.db.vendors) do
		local s = rec.seed and seedByKey[rec.seed] or nil
		if s then
			replaced[s.key] = true
		end
		local items, seen = {}, {}
		for id, it in pairs(rec.items or {}) do
			seen[id] = true
			items[#items + 1] = { id = id, cat = it.cat, stock = it.stock, limited = it.limited, price = it.price, t = it.t }
		end
		-- what the rumour said and the player has not seen in stock yet stays, as a rumour
		if s then
			for _, it in ipairs(seedItems(s, seen)) do
				items[#items + 1] = it
			end
		end
		out[#out + 1] = {
			key = key,
			name = rec.name,
			map = rec.map,
			x = rec.x,
			y = rec.y,
			learned = true,
			seed = s and s.key or nil,
			classic = s and s.classic or false,
			sides = rec.sides,
			t = rec.t,
			items = sortItems(items),
		}
	end
	for _, s in ipairs(ns.Seed) do
		if not replaced[s.key] and not ns.db.hidden[s.key] then
			out[#out + 1] = {
				key = s.key,
				name = s.name,
				map = s.map,
				x = s.x,
				y = s.y,
				approx = s.x ~= nil,
				place = s.place,
				road = s.road,
				seed = s.key,
				classic = s.classic,
				side = s.side,
				items = sortItems(seedItems(s)),
			}
		end
	end
	return out
end

-- The items of an entry that the chosen kinds let through.
function V.ShownItems(entry, cats)
	local out = {}
	for _, it in ipairs(entry.items) do
		if cats[it.cat] then
			out[#out + 1] = it
		end
	end
	return out
end

local function matches(entry, text)
	if entry.name:lower():find(text, 1, true) then
		return true
	end
	for _, it in ipairs(entry.items) do
		local name = ns.ItemName(it.id)
		if name and name:lower():find(text, 1, true) then
			return true
		end
	end
	return false
end

-- The list the book and the map draw. opts: { map = only this zone, text = search, cats = kinds (default: the
-- settings'), rumours = false to leave rumours out }. Sorted: the player's zone first, then by zone and name.
function V.List(opts)
	opts = opts or {}
	local s = ns.db.settings
	local cats = opts.cats or s.cats
	local rumours = opts.rumours
	if rumours == nil then
		rumours = s.rumours
	end
	local text = opts.text and strtrim(opts.text):lower() or ""
	local out = {}
	for _, entry in ipairs(V.All()) do
		local ok = (not opts.map or entry.map == opts.map)
			and (rumours or entry.learned)
			and sideOk(entry, s)
			and #V.ShownItems(entry, cats) > 0
			and (text == "" or matches(entry, text))
		if ok then
			out[#out + 1] = entry
		end
	end
	local here = ns.PlayerMap()
	local names = {}
	local function zone(map)
		names[map] = names[map] or ns.ZoneName(map)
		return names[map]
	end
	table.sort(out, function(a, b)
		if a.map ~= b.map then
			if a.map == here or b.map == here then
				return a.map == here
			end
			return zone(a.map) < zone(b.map)
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.key < b.key
	end)
	return out
end

function V.Find(key)
	for _, entry in ipairs(V.All()) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

-- Take a vendor off the list: a visited one is forgotten (its rumour, if it had one, comes back); a rumour is
-- hidden until /mercader rumores.
function V.Forget(key)
	if ns.db.vendors[key] then
		ns.db.vendors[key] = nil
		ns.Fire("vendors")
		return "forgotten"
	end
	if V.SeedByKey(key) then
		ns.db.hidden[key] = true
		ns.Fire("vendors")
		return "hidden"
	end
	return nil
end

function V.UnhideAll()
	local n = 0
	for key in pairs(ns.db.hidden) do
		n = n + 1
		ns.db.hidden[key] = nil
	end
	if n > 0 then
		ns.Fire("vendors")
	end
	return n
end

-- Where an entry is, in words: the coordinates the player saw, or the town of the rumour, or the road.
function V.Where(entry)
	local L = ns.L
	if entry.learned and entry.x then
		return L.COORDS:format(entry.x * 100, entry.y * 100)
	elseif entry.road then
		return L.WANDERS_AT:format(entry.road)
	elseif entry.approx then
		return entry.place and L.APPROX_AT:format(entry.place) or L.APPROX
	elseif entry.place then
		return L.NEAR:format(entry.place)
	end
	return L.NO_POSITION
end

-- One item's stock, in words.
function V.StockText(it)
	local L = ns.L
	if it.rumour then
		return L.STOCK_RUMOUR
	elseif it.stock == 0 then
		return L.STOCK_OUT
	elseif it.stock and it.stock > 0 then
		return L.STOCK_LEFT:format(it.stock)
	end
	return L.STOCK_ANY
end
