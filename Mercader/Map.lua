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
-- A mark's size on screen: on a zone's map, and smaller on a continent's, where a whole zone is a thumb wide.
-- Both shrink a little more when the map is the small windowed one (see Map.PinSize).
local PIN_SIZE, PIN_SIZE_CONTINENT, NOTE_SIZE, DOT_RATIO = 16, 12, 20, 0.62
local SMALL_MAP, FULL_MAP, SMALLEST = 700, 1300, 0.85 -- the map's width on screen, and how far a mark shrinks
-- vendors closer than this (in map units, 0..1) share one mark: a town's shops are a few steps apart
local CLUSTER = 0.02
local TIP_VENDORS, TIP_ITEMS = 4, 6
-- The game gives its own marks absolute frame levels from 2000 up (MapCanvas_PinFrameLevelsManager), and the
-- lowest of them, the explored-areas overlay, is as big as the whole map: a mark of ours below 2000 is drawn
-- under it and is not seen. Ours go where the game puts its points of interest (and other addons theirs).
local PIN_LEVEL_TYPE, PIN_LEVEL_FALLBACK = "PIN_FRAME_LEVEL_AREA_POI", 2100
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
	-- a continent's map shows every zone's marks at once: only when the player asks for it (Options)
	if Map.IsContinent(shown) and not ns.db.settings.continentPins then
		return { marks = marks, notes = notes, off = true }
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

function Map.ShowTip(owner, heading, entries, foot)
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

-- The frame level for our marks on this map (see PIN_LEVEL_TYPE).
function Map.PinLevel(map)
	local manager = map and map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
	if manager and manager.GetValidFrameLevel then
		local ok, level = pcall(manager.GetValidFrameLevel, manager, PIN_LEVEL_TYPE)
		if ok and type(level) == "number" and level > 0 then
			return level
		end
	end
	return PIN_LEVEL_FALLBACK
end

-- How big a mark is drawn: `continent` for a continent's map, `width` = how wide the map is on screen.
function Map.PinSize(continent, width)
	local base = continent and PIN_SIZE_CONTINENT or PIN_SIZE
	local t = ((width or FULL_MAP) - SMALL_MAP) / (FULL_MAP - SMALL_MAP)
	t = math.max(0, math.min(1, t))
	return math.floor(base * (SMALLEST + (1 - SMALLEST) * t) + 0.5)
end

function Map.IsContinent(shown)
	local info = shown and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(shown)
	local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent or CONTINENT
	return info ~= nil and info.mapType == continent
end

-- The number of vendors a mark stands for, on a small ink disc at its corner.
local function addCount(frame)
	frame.dot = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	frame.dot:SetPoint("CENTER", frame, "BOTTOMRIGHT", -3, 3)
	frame.dot:SetTexture(MEDIA .. "dot")
	frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.count:SetPoint("CENTER", frame.dot, "CENTER", 0, 0)
	frame.count:SetTextColor(1, 0.93, 0.67)
	-- size = the mark's. On a continent's map the marks are too small for a number: plain = true leaves it out
	-- (the tooltip still names every vendor of the mark).
	function frame:SetCount(n, always, size, plain)
		local dot = math.max(10, math.floor((size or PIN_SIZE) * DOT_RATIO + 0.5))
		local shown = (always or n > 1) and not plain
		self.dot:SetSize(dot, dot)
		self.dot:SetShown(shown)
		self.count:SetText(shown and tostring(n) or "")
	end
end

local function makePin(canvas)
	local pin = CreateFrame("Button", nil, canvas)
	pin:SetSize(PIN_SIZE, PIN_SIZE)
	pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	pin.art = pin:CreateTexture(nil, "ARTWORK")
	pin.art:SetAllPoints()
	addCount(pin)
	pin:SetScript(
		"OnEnter",
		guarded(function(self)
			Map.ShowTip(self, nil, self.mark.entries, L.PIN_CLICK)
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
	note:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 12, 12)
	note.art = note:CreateTexture(nil, "ARTWORK")
	note.art:SetAllPoints()
	note.art:SetTexture(MEDIA .. "pin_rumour")
	addCount(note)
	note:SetScript(
		"OnEnter",
		guarded(function(self)
			Map.ShowTip(self, L.NOTE_TITLE, self.entries, L.NOTE_CLICK)
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

-- A gold ring that pulses around one mark for a few seconds: "Open map" in the book points at the vendor with
-- it. One ring for the whole map, moved to whichever mark (or the corner note) holds the vendor.
local GLOW_RATIO, GLOW_SECONDS = 2.4, 8
local function glowOn(frame)
	local g = Map.glow
	if not g then
		g = CreateFrame("Frame", nil, frame)
		g.art = g:CreateTexture(nil, "OVERLAY")
		g.art:SetAllPoints()
		g.art:SetTexture(MEDIA .. "glow")
		g.pulse = g:CreateAnimationGroup()
		local fade = g.pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.25)
		fade:SetDuration(0.55)
		g.pulse:SetLooping("BOUNCE")
		Map.glow = g
	end
	g:SetParent(frame) -- so it takes the mark's own scale and goes away with it
	g:ClearAllPoints()
	g:SetPoint("CENTER", frame, "CENTER", 0, 0)
	local size = (frame:GetWidth() or PIN_SIZE) * GLOW_RATIO
	g:SetSize(size, size)
	g.on = frame
	g:Show()
	g.pulse:Play()
end
local function glowOff()
	local g = Map.glow
	if g and g.on then
		g.on = nil
		g.pulse:Stop()
		g:Hide()
	end
end

-- Point at a vendor on the map for a few seconds (nil stops it).
function Map.Highlight(key)
	Map.highlight = key
	Map.highlightTurn = (Map.highlightTurn or 0) + 1
	local turn = Map.highlightTurn
	if key then
		C_Timer.After(GLOW_SECONDS, function()
			if Map.highlightTurn == turn then
				Map.highlight = nil
				Map.Draw()
			end
		end)
	end
	Map.Draw()
end

local function holds(entries, key)
	for _, entry in ipairs(entries) do
		if entry.key == key then
			return true
		end
	end
	return false
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
	local level = Map.PinLevel(map)
	Map.level = level
	local continent = Map.IsContinent(map:GetMapID())
	-- how wide the map's window is on screen (not the canvas, which grows when the player zooms in)
	local view = map.GetCanvasContainer and map:GetCanvasContainer()
	local width = view and view:GetWidth() or 0
	if not width or width <= 0 then
		width = w * canvasScale
	end
	local size = Map.PinSize(continent, width)
	Map.size = size
	local lit
	for i, mark in ipairs(layout.marks) do
		local pin = Map.pins[i]
		if not pin then
			pin = makePin(canvas)
			Map.pins[i] = pin
		end
		pin.mark = mark
		pin:SetFrameLevel(level)
		pin:SetSize(size, size)
		pin:SetScale(scale)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", canvas, "TOPLEFT", mark.x * w / scale, -mark.y * h / scale)
		pin.art:SetTexture(MEDIA .. (mark.rumour and "pin_rumour" or "pin"))
		pin:SetCount(#mark.entries, false, size, continent)
		pin:Show()
		if Map.highlight and holds(mark.entries, Map.highlight) then
			lit = pin
		end
	end
	for i = #layout.marks + 1, #Map.pins do
		Map.pins[i]:Hide()
	end
	if #layout.notes > 0 then
		if not Map.note then
			Map.note = makeNote(map.GetCanvasContainer and map:GetCanvasContainer() or map)
		end
		Map.note.entries = layout.notes
		Map.note:SetFrameLevel(level + 5)
		Map.note:SetCount(#layout.notes, true, NOTE_SIZE)
		Map.note:Show()
		if Map.highlight and holds(layout.notes, Map.highlight) then
			lit = Map.note
		end
	elseif Map.note then
		Map.note:Hide()
	end
	if lit then
		glowOn(lit)
	else
		glowOff()
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
	if layout.off then
		lines[#lines + 1] = L.MARKS_CONTINENT:format(ns.ZoneName(shown), shown)
		return lines
	end
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
			map.GetCanvasScale and map:GetCanvasScale() or 0,
			Map.level or 0
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
