local ADDON, ns = ...
local L = ns.L
local V = ns.Vendors

-- The marks on the minimap: the vendors of the zone the player is in that are close enough to fall inside it.
-- Like the world map's, they are plain frames of ours placed by hand, a few times a second.
--
-- Where a vendor falls: its distance from the player in yards (the zone's size in yards comes from the game,
-- C_Map.GetWorldPosFromMapPos at two corners of its map), against how many yards the minimap shows at its
-- zoom. Those sizes are the game's own and do not change: they are the ones every map addon uses.

local Mini = {}
ns.Mini = Mini

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
-- yards across the minimap at each zoom level, outdoors and inside a building or cave
local YARDS = {
	outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
	indoor = { [0] = 300, 240, 180, 120, 80, 50 },
}
local EDGE = 0.9 -- a mark this close to the rim is left out (the minimap is round; its corners are not there)
local TICK = 0.25 -- seconds between two looks
local PIN_SIZE, TOGETHER = 13, 7 -- marks closer than TOGETHER pixels are one mark

Mini.pins = {}
local sizes = {} -- map -> { width, height } in yards, or false when the game does not say

-- A zone's size in yards: width (west to east) and height (north to south). nil when the game does not say.
function Mini.ZoneSize(map)
	if sizes[map] == nil then
		sizes[map] = false
		if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
			-- the game answers with (north-south, west-east); the map's middle is asked for, not its far
			-- corner, which some maps do not answer for
			local _, corner = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0, 0))
			local _, middle = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0.5, 0.5))
			if corner and middle then
				local top, left = corner:GetXY()
				local midY, midX = middle:GetXY()
				if top and left and midY and midX then
					local w, h = math.abs(midX - left) * 2, math.abs(midY - top) * 2
					if w > 0 and h > 0 then
						sizes[map] = { w, h }
					end
				end
			end
		end
	end
	local size = sizes[map]
	if size then
		return size[1], size[2]
	end
	return nil
end

-- How many yards from the minimap's centre to its rim, at its zoom.
function Mini.Radius()
	local zoom = Minimap and Minimap.GetZoom and Minimap:GetZoom() or 0
	local indoors = IsIndoors and IsIndoors()
	local across = YARDS[indoors and "indoor" or "outdoor"]
	return (across[zoom] or across[0]) / 2
end

-- Plain maths (the tests check it): the player at px, py and a vendor at vx, vy of a zone of w by h yards; a
-- minimap that shows `radius` yards and is `half` pixels from centre to rim; facing = the player's, in
-- radians, when the minimap turns with the player (nil when north is up). Returns the offset from the
-- minimap's centre in pixels (right, up) and the distance in yards; no offset when it falls outside.
function Mini.Offset(px, py, vx, vy, w, h, radius, half, facing)
	local east, south = (vx - px) * w, (vy - py) * h
	local dist = math.sqrt(east * east + south * south)
	if dist > radius * EDGE then
		return nil, nil, dist
	end
	if facing then
		local sin, cos = math.sin(facing), math.cos(facing)
		east, south = east * cos - south * sin, east * sin + south * cos
	end
	return east / radius * half, -south / radius * half, dist
end

local zoneEntries, zoneMap
local function entries(map)
	if zoneMap ~= map or not zoneEntries then
		zoneMap, zoneEntries = map, {}
		for _, entry in ipairs(V.List({ map = map })) do
			if entry.x then
				zoneEntries[#zoneEntries + 1] = entry
			end
		end
	end
	return zoneEntries
end

-- What goes on the minimap right now, as plain data: { { x, y, dist, entries = {...}, rumour } } in pixels
-- from the minimap's centre. Empty when the marks are off, in a dungeon, or the zone's size is not known.
function Mini.Layout()
	local marks = {}
	if not (ns.db and ns.db.settings.minimapPins and Minimap) then
		return marks
	end
	local map = ns.PlayerMap()
	local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	if not pos then
		return marks
	end
	local px, py = pos:GetXY()
	if not px or (issecretvalue and (issecretvalue(px) or issecretvalue(py))) or (px == 0 and py == 0) then
		return marks
	end
	local w, h = Mini.ZoneSize(map)
	if not w then
		return marks
	end
	local facing
	if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
		facing = GetPlayerFacing()
		if not facing or (issecretvalue and issecretvalue(facing)) then
			return marks -- the minimap turns and the game does not say how much: better nothing than wrong
		end
	end
	local radius, half = Mini.Radius(), (Minimap:GetWidth() or 140) / 2
	for _, entry in ipairs(entries(map)) do
		local x, y, dist = Mini.Offset(px, py, entry.x, entry.y, w, h, radius, half, facing)
		if x then
			local home
			for _, mark in ipairs(marks) do
				if math.abs(mark.x - x) <= TOGETHER and math.abs(mark.y - y) <= TOGETHER then
					home = mark
					break
				end
			end
			if not home then
				home = { x = x, y = y, dist = dist, entries = {}, rumour = true }
				marks[#marks + 1] = home
			end
			home.entries[#home.entries + 1] = entry
			if entry.learned then
				home.rumour = false
			end
		end
	end
	return marks
end

local function guarded(fn, where)
	if ns.guard then
		return ns.guard.Wrap(fn, where)
	end
	return fn
end

local function makePin()
	local pin = CreateFrame("Button", nil, Minimap)
	pin:SetSize(PIN_SIZE, PIN_SIZE)
	pin:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 6)
	pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	pin.art = pin:CreateTexture(nil, "OVERLAY")
	pin.art:SetAllPoints()
	pin:SetScript(
		"OnEnter",
		guarded(function(self)
			ns.Map.ShowTip(self, L.MINI_DISTANCE:format(math.floor(self.mark.dist + 0.5)), self.mark.entries, L.PIN_CLICK)
		end, "minimap enter")
	)
	pin:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	pin:SetScript(
		"OnClick",
		guarded(function(self, button)
			local entry = self.mark.entries[1]
			if button == "RightButton" then
				ns.UI.Waypoint(entry)
			else
				ns.UI.Open(entry.key)
			end
		end, "minimap click")
	)
	return pin
end

-- Draw the marks as they are now.
function Mini.Update()
	local marks = Mini.Layout()
	for i, mark in ipairs(marks) do
		local pin = Mini.pins[i]
		if not pin then
			pin = makePin()
			Mini.pins[i] = pin
		end
		pin.mark = mark
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", Minimap, "CENTER", mark.x, mark.y)
		pin.art:SetTexture(MEDIA .. (mark.rumour and "pin_rumour" or "pin"))
		pin:Show()
	end
	for i = #marks + 1, #Mini.pins do
		Mini.pins[i]:Hide()
	end
	return #marks
end

-- Start looking, a few times a second. If a look ever fails (a value the game hides, say), the marks stop for
-- the session: the error is kept once (/mercader errores) instead of four times a second.
function Mini.Init()
	if Mini.frame or not Minimap then
		return
	end
	local done = true
	local look = guarded(function()
		Mini.Update()
		done = true
	end, "minimap")
	local wait = 0
	Mini.frame = CreateFrame("Frame")
	Mini.frame:SetScript("OnUpdate", function(self, elapsed)
		wait = wait + (elapsed or 0)
		if wait < TICK then
			return
		end
		wait = 0
		done = false
		look()
		if not done then
			self:SetScript("OnUpdate", nil)
			for _, pin in ipairs(Mini.pins) do
				pin:Hide()
			end
		end
	end)
end

local function again()
	zoneEntries = nil
end
ns.On("vendors", again)
ns.On("settings", again)
