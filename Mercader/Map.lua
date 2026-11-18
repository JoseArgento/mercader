local ADDON, ns = ...
local L = ns.L
local V = ns.Vendors

-- The marks on the game's world map. They are plain frames of ours, children of the map's canvas and placed
-- by hand (no data provider and no pin template of the game: nothing of the map's own code runs through us).
-- A solid gold mark is a vendor the player visited; a pale ring is a rumour, at its town's approximate spot.
-- Vendors that stand together share one mark with a number. Rumours without a known position are gathered
-- in a small note at the map's corner.

local Map = {}
ns.Map = Map

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local PIN_SIZE, NOTE_SIZE = 18, 22
-- vendors closer than this (in map units, 0..1) share one mark: a town's shops are a few steps apart
local CLUSTER = 0.02
local TIP_VENDORS, TIP_ITEMS = 4, 6
-- above the map's own art and labels (the game's marks sit a few hundred levels over the canvas)
local PIN_LEVEL = 500
local CONTINENT = 2 -- Enum.UIMapType.Continent

-- Where an entry falls on the map being shown: its own zone, or its zone drawn on the continent.
function Map.Project(entry, shown)
	if not entry.x then
		return nil
	end
	if entry.map == shown then
		return entry.x, entry.y
	end
	if not (C_Map and C_Map.GetMapRectOnMap and C_Map.GetMapInfo) then
		return nil
	end
	local top = C_Map.GetMapInfo(shown)
	local own = C_Map.GetMapInfo(entry.map)
	local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent or CONTINENT
	if not (top and own and top.mapType == continent and own.parentMapID == shown) then
		return nil
	end
	local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(entry.map, shown)
	if not (minX and maxX and maxX > minX and maxY > minY) then
		return nil
	end
	return minX + entry.x * (maxX - minX), minY + entry.y * (maxY - minY)
end

-- What goes on the map `shown`, as plain data: marks = { { x, y, entries = {...}, rumour = all are rumours } }
-- and notes = the rumours of this very zone that have no position.
function Map.Layout(shown)
	local marks, notes = {}, {}
	if not (ns.db and ns.db.settings.pins and shown) then
		return { marks = marks, notes = notes }
	end
	for _, entry in ipairs(V.List()) do
		local x, y = Map.Project(entry, shown)
		if x then
			local home
			for _, mark in ipairs(marks) do
				if math.abs(mark.x - x) <= CLUSTER and math.abs(mark.y - y) <= CLUSTER then
					home = mark
					break
				end
			end
			if not home then
				home = { x = x, y = y, entries = {}, rumour = true }
				marks[#marks + 1] = home
			end
			home.entries[#home.entries + 1] = entry
			if entry.learned then
				home.rumour = false
			end
		elseif entry.map == shown and not entry.learned then
			notes[#notes + 1] = entry
		end
	end
	return { marks = marks, notes = notes }
end

-- The tooltip's lines for some entries, as { left, r, g, b } (the tests read them; the tooltip draws them).
function Map.TipLines(entries)
	local lines = {}
	for i, entry in ipairs(entries) do
		if i > TIP_VENDORS then
			lines[#lines + 1] = { L.PIN_MORE:format(#entries - TIP_VENDORS), 0.7, 0.7, 0.7 }
			break
		end
		local title = entry.name
		if not entry.learned then
			title = title .. " (" .. L.TAG_RUMOUR .. ")"
		end
		lines[#lines + 1] = { title, 1, 0.82, 0 }
		lines[#lines + 1] = { V.Where(entry), 0.8, 0.8, 0.8 }
		local items = V.ShownItems(entry, ns.db.settings.cats)
		for j, it in ipairs(items) do
			if j > TIP_ITEMS then
				lines[#lines + 1] = { "  " .. L.PIN_MORE:format(#items - TIP_ITEMS), 0.7, 0.7, 0.7 }
				break
			end
			lines[#lines + 1] = { "  " .. ns.GameLink(it.id) .. "  " .. V.StockText(it), 1, 1, 1 }
		end
	end
	return lines
end

local function showTip(owner, heading, entries, foot)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local first = true
	local function add(text, r, g, b)
		if first then
			GameTooltip:SetText(text, r, g, b)
			first = false
		else
			GameTooltip:AddLine(text, r, g, b)
		end
	end
	if heading then
		add(heading, 1, 1, 1)
	end
	for _, line in ipairs(Map.TipLines(entries)) do
		add(line[1], line[2], line[3], line[4])
	end
	add(foot, 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function guarded(fn, where)
	if ns.guard then
		return ns.guard.Wrap(fn, where)
	end
	return fn
end

Map.pins = {}

local function makePin(canvas)
	local pin = CreateFrame("Button", nil, canvas)
	pin:SetSize(PIN_SIZE, PIN_SIZE)
	pin:SetFrameLevel((canvas:GetFrameLevel() or 0) + PIN_LEVEL)
	pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	pin.art = pin:CreateTexture(nil, "ARTWORK")
	pin.art:SetAllPoints()
	pin.count = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pin.count:SetPoint("CENTER", 0, 0)
	pin.count:SetTextColor(0.16, 0.09, 0.04) -- ink: it is read on gold or on parchment
	pin:SetScript(
		"OnEnter",
		guarded(function(self)
			showTip(self, nil, self.mark.entries, L.PIN_CLICK)
		end, "pin enter")
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
		end, "pin click")
	)
	return pin
end

local function makeNote(holder)
	local note = CreateFrame("Button", nil, holder)
	note:SetSize(NOTE_SIZE, NOTE_SIZE)
	note:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 10, 10)
	note:SetFrameLevel((holder:GetFrameLevel() or 0) + 80)
	note.art = note:CreateTexture(nil, "ARTWORK")
	note.art:SetAllPoints()
	note.art:SetTexture(MEDIA .. "pin_rumour")
	note.count = note:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	note.count:SetPoint("CENTER", 0, 0)
	note.count:SetTextColor(0.16, 0.09, 0.04)
	note:SetScript(
		"OnEnter",
		guarded(function(self)
			showTip(self, L.NOTE_TITLE, self.entries, L.NOTE_CLICK)
		end, "note enter")
	)
	note:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	note:SetScript(
		"OnClick",
		guarded(function(self)
			ns.UI.Open(self.entries[1] and self.entries[1].key)
		end, "note click")
	)
	return note
end

-- Put the marks on the world map as it is now. Does nothing while the map is closed.
function Map.Draw()
	local map = WorldMapFrame
	if not (map and map.GetCanvas and map:IsShown()) then
		return
	end
	local canvas = map:GetCanvas()
	local layout = Map.Layout(map:GetMapID())
	local canvasScale = map.GetCanvasScale and map:GetCanvasScale() or 1
	if not canvasScale or canvasScale <= 0 then
		canvasScale = 1
	end
	-- the canvas is zoomed; the marks are not: each one undoes the zoom, and its offset is in its own scale
	local scale = 1 / canvasScale
	local w, h = canvas:GetWidth() or 0, canvas:GetHeight() or 0
	for i, mark in ipairs(layout.marks) do
		local pin = Map.pins[i]
		if not pin then
			pin = makePin(canvas)
			Map.pins[i] = pin
		end
		pin.mark = mark
		pin:SetScale(scale)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", canvas, "TOPLEFT", mark.x * w / scale, -mark.y * h / scale)
		pin.art:SetTexture(MEDIA .. (mark.rumour and "pin_rumour" or "pin"))
		pin.count:SetText(#mark.entries > 1 and tostring(#mark.entries) or "")
		pin:Show()
	end
	for i = #layout.marks + 1, #Map.pins do
		Map.pins[i]:Hide()
	end
	if #layout.notes > 0 then
		if not Map.note then
			Map.note = makeNote(map.GetCanvasContainer and map:GetCanvasContainer() or map)
		end
		Map.note.entries = layout.notes
		Map.note.count:SetText(tostring(#layout.notes))
		Map.note:Show()
	elseif Map.note then
		Map.note:Hide()
	end
end

-- Hook the map once: when it opens, when it turns to another zone and when its zoom changes. Returns whether
-- the map is hooked; when the game has not made its map yet, it is tried again a few times.
local RETRY_EVERY, RETRIES = 3, 10
function Map.Init()
	local map = WorldMapFrame
	if Map.hooked then
		return true
	end
	if not (map and map.GetCanvas) then
		Map.tries = (Map.tries or 0) + 1
		if Map.tries <= RETRIES then
			C_Timer.After(RETRY_EVERY, Map.Init)
		end
		return false
	end
	Map.hooked = true
	local draw = guarded(Map.Draw, "map")
	map:HookScript("OnShow", function()
		draw()
	end)
	for _, method in ipairs({ "OnMapChanged", "OnCanvasScaleChanged" }) do
		if map[method] then
			hooksecurefunc(map, method, function()
				draw()
			end)
		end
	end
	if map:IsShown() then
		draw()
	end
	return true
end

-- What the map is doing with the marks, in lines for the chat (/mercader marcas): when a player says "I see
-- nothing on the map", this tells whether there was nothing to draw or something did not get drawn.
function Map.Report()
	local map = WorldMapFrame
	local lines = {}
	lines[#lines + 1] = L.MARKS_HOOK:format(Map.hooked and L.YES or L.NO, ns.db.settings.pins and L.YES or L.NO)
	local shown = map and map.GetMapID and map:GetMapID() or nil
	local open = map and map:IsShown() or false
	if not open then
		-- with the map closed, tell about the zone the player is in
		shown = ns.PlayerMap()
	end
	if not shown then
		lines[#lines + 1] = L.MARKS_NO_MAP
		return lines
	end
	local layout = Map.Layout(shown)
	local vendors = 0
	for _, mark in ipairs(layout.marks) do
		vendors = vendors + #mark.entries
	end
	lines[#lines + 1] = L.MARKS_ZONE:format(ns.ZoneName(shown), shown, #layout.marks, vendors, #layout.notes)
	if open then
		local canvas = map:GetCanvas()
		local drawn = 0
		for _, pin in ipairs(Map.pins) do
			if pin:IsShown() then
				drawn = drawn + 1
			end
		end
		lines[#lines + 1] = L.MARKS_CANVAS:format(
			drawn,
			canvas:GetWidth() or 0,
			canvas:GetHeight() or 0,
			map.GetCanvasScale and map:GetCanvasScale() or 0
		)
	else
		lines[#lines + 1] = L.MARKS_CLOSED
	end
	return lines
end

ns.On("vendors", function()
	Map.Draw()
end)
ns.On("settings", function()
	Map.Draw()
end)
