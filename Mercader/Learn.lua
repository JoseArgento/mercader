local _, ns = ...
local L = ns.L
local V = ns.Vendors

-- Learning: when the player opens a vendor's window, what is worth it of what the vendor sells is written
-- down with where the player is standing. Limited stock is what the game itself reports for each line
-- (numAvailable: -1 when there is no limit).

local Learn = {}
ns.Learn = Learn

-- The npc's id out of its GUID ("Creature-0-1-2-3-3658-0000"), or nil when the client hides it.
local function npcId()
	local guid = UnitGUID and UnitGUID("npc")
	if not guid or (issecretvalue and issecretvalue(guid)) or type(guid) ~= "string" then
		return nil
	end
	local kind, _, _, _, _, id = strsplit("-", guid)
	if kind ~= "Creature" and kind ~= "Vehicle" then
		return nil
	end
	return tonumber(id)
end

local function position()
	local map = ns.PlayerMap()
	if not map then
		return nil
	end
	local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	if not pos then
		return map
	end
	local x, y = pos:GetXY()
	if not x or (x == 0 and y == 0) then
		return map
	end
	return map, x, y
end

-- What the open vendor window lists: { { id, link, stock, price, limited } }, in the window's order.
function Learn.Read()
	local out = {}
	local n = GetMerchantNumItems and GetMerchantNumItems() or 0
	for i = 1, n do
		local id = GetMerchantItemID and GetMerchantItemID(i)
		local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(i)
		if id and info then
			local stock = tonumber(info.numAvailable) or -1
			-- the window knows the item's name even when the client has not loaded the item yet
			if type(info.name) == "string" and info.name ~= "" and not (issecretvalue and issecretvalue(info.name)) then
				ns.db.names[id] = info.name
			end
			out[#out + 1] = {
				id = id,
				link = GetMerchantItemLink and GetMerchantItemLink(i) or nil,
				stock = stock,
				price = tonumber(info.price) or 0,
				limited = stock >= 0,
			}
		end
	end
	return out
end

-- Write the open vendor down. announce = true on MERCHANT_SHOW (the chat line is said once per visit, not on
-- every purchase). Returns the saved record, or nil when there was nothing worth it and no rumour about it.
function Learn.Scan(announce)
	local name = UnitName and UnitName("npc")
	if type(name) ~= "string" or name == "" or (issecretvalue and issecretvalue(name)) then
		return nil
	end
	local lines = Learn.Read()
	local map, x, y = position()
	if not map then
		return nil
	end
	local npc = npcId()
	local key = npc and ("n" .. npc) or (name .. "@" .. map)
	local rec = ns.db.vendors[key]

	local kept, ids = {}, {}
	for _, line in ipairs(lines) do
		ids[#ids + 1] = line.id
		local before = rec and rec.items and rec.items[line.id]
		local limited = line.limited or (before and before.limited) or false
		local cat = V.Classify(line.id, limited)
		if cat then
			kept[line.id] = { cat = cat, stock = line.stock, limited = limited, price = line.price, t = time(), link = line.link }
		end
	end

	local seed = rec and rec.seed and V.SeedByKey(rec.seed) or V.MatchSeed(name, map, ids)
	if not next(kept) and not seed and not rec then
		return nil -- a vendor of bread and water: nothing to write down
	end

	local isNew = rec == nil
	rec = rec or { items = {}, sides = {} }
	rec.name, rec.npc, rec.map, rec.t = name, npc, map, time()
	if x then
		rec.x, rec.y = x, y
	end
	rec.seed = seed and seed.key or rec.seed
	local side = ns.PlayerSide()
	if side then
		rec.sides = rec.sides or {}
		rec.sides[side] = true
	end
	-- what was written down before and is not in the window now: a limited one sold out, any other is gone
	for id, it in pairs(rec.items) do
		if not kept[id] then
			if it.limited then
				it.stock, it.t = 0, time()
			else
				rec.items[id] = nil
			end
		end
	end
	local inStock = {}
	for _, line in ipairs(lines) do
		local it = kept[line.id]
		if it then
			if it.limited and it.stock > 0 and ns.db.settings.cats[it.cat] then
				inStock[#inStock + 1] = (it.link or ns.GameLink(line.id)) .. (it.stock > 1 and (" x" .. it.stock) or "")
			end
			it.link = nil
			rec.items[line.id] = it
			kept[line.id] = nil -- a vendor can list the same item twice: once is enough
		end
	end
	ns.db.vendors[key] = rec

	if announce then
		if #inStock > 0 and ns.db.settings.announce then
			ns.Print(L.ANNOUNCE:format(name, table.concat(inStock, ", ")))
		elseif isNew then
			ns.Print(L.LEARNED_NEW:format(name, ns.ZoneName(map)))
		end
	end
	ns.Fire("vendors")
	return rec
end
