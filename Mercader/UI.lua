local ADDON, ns = ...
local L = ns.L
local V = ns.Vendors

-- The book (Pergamino.Book, two pages). "Vendors": on the left the search, the kinds of goods, "this zone /
-- everywhere" and the list; on the right the chosen vendor: where it is, what it sells and how much was left,
-- and the buttons (mark on the map, open the map, forget). "Options": what is shown and the language.

local UI = {}
ns.UI = UI
local P = Pergamino
local ROW_H, ITEM_H = 26, 24
local MUTED = "|cff6b5a45"

UI.scope = "zone" -- "zone" = the zone the player is in, "all" = everywhere
UI.text = ""
UI.selected = nil -- key of the vendor on the right page

-- The left page's rows, as plain data (the tests read them; the list draws them).
function UI.Rows()
	local rows = {}
	local opts = { text = UI.text }
	if UI.scope == "zone" and UI.text == "" then
		opts.map = ns.PlayerMap()
	end
	for _, entry in ipairs(V.List(opts)) do
		local n = #V.ShownItems(entry, ns.db.settings.cats)
		rows[#rows + 1] = {
			key = entry.key,
			name = entry.name,
			zone = ns.ZoneName(entry.map),
			count = n == 1 and L.COUNT_ITEM or L.COUNT_ITEMS:format(n),
			rumour = not entry.learned,
		}
	end
	return rows
end

-- The right page, as plain data: nil when no vendor is chosen (or the chosen one is gone).
function UI.Detail()
	local entry = UI.selected and V.Find(UI.selected)
	if not entry then
		return nil
	end
	local status
	if entry.learned then
		local seen = false
		for _, it in ipairs(entry.items) do
			if not it.rumour then
				seen = true
				break
			end
		end
		status = seen and L.SEEN_AGO:format(ns.Ago(entry.t)) or L.LOCATED_ONLY
	else
		status = entry.classic and L.RUMOUR_CLASSIC or L.RUMOUR_FOREVER
	end
	local items = {}
	for _, it in ipairs(V.ShownItems(entry, ns.db.settings.cats)) do
		local stock = V.StockText(it)
		if it.price and it.price > 0 then
			stock = stock .. " · " .. ns.Money(it.price)
		end
		items[#items + 1] = { id = it.id, link = ns.InkLink(it.id), stock = stock, rumour = it.rumour or false }
	end
	return {
		entry = entry,
		title = entry.name,
		where = ns.ZoneName(entry.map) .. " · " .. V.Where(entry),
		status = status,
		items = items,
		canMark = entry.x ~= nil,
		forget = entry.learned and L.FORGET or L.HIDE_RUMOUR,
	}
end

local function initRow(row, item)
	if not row.name then
		row.name = P.Label(row, "", "strong")
		row.name:SetPoint("LEFT", 6, 0)
		row.name:SetWidth(150)
		row.name:SetWordWrap(false)
		row.count = P.Label(row, "", "small", "RIGHT")
		row.count:SetPoint("RIGHT", -6, 0)
		row.count:SetWidth(84)
		row.count:SetWordWrap(false)
		row.zone = P.Label(row, "", "muted")
		row.zone:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
		row.zone:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
		row.zone:SetWordWrap(false)
	end
	row.name:SetText(item.name)
	row.zone:SetText(item.zone)
	row.count:SetText(item.rumour and (MUTED .. L.TAG_RUMOUR .. "|r") or item.count)
	if row.selected then
		row.selected:SetShown(item.key == UI.selected)
	end
end
UI.InitRow = initRow -- for the tests

local function initItem(row, item)
	if not row.link then
		row.link = P.Label(row, "", "body")
		row.link:SetPoint("LEFT", 6, 0)
		row.link:SetWordWrap(false)
		row.stock = P.Label(row, "", "small", "RIGHT")
		row.stock:SetPoint("RIGHT", -6, 0)
		row.stock:SetWidth(150)
		row.stock:SetWordWrap(false)
		row.link:SetPoint("RIGHT", row.stock, "LEFT", -6, 0)
		-- the game's own tooltip of the item while the mouse is on its line
		row:SetScript("OnEnter", function(self)
			if self.item then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.item.id) then
					GameTooltip:Show()
				end
			end
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
	row.link:SetText(item.link)
	row.stock:SetText(item.rumour and (MUTED .. item.stock .. "|r") or item.stock)
end
UI.InitItem = initItem

-- Shift-click on an item's line puts its link in the chat box, as anywhere else in the game.
local function clickItem(item)
	if IsShiftKeyDown and IsShiftKeyDown() and ChatFrameUtil and ChatFrameUtil.InsertLink then
		ChatFrameUtil.InsertLink(ns.GameLink(item.id))
	end
end

function UI.Waypoint(entry)
	if entry and ns.Waypoint(entry.map, entry.x, entry.y) then
		ns.Print(L.WAYPOINT_SET:format(entry.name))
		return true
	end
	ns.Print(L.WAYPOINT_NO)
	return false
end

-- The game's map, turned to the vendor's zone. The book steps aside so the map is seen.
function UI.ShowOnMap(entry)
	if not entry then
		return
	end
	if UI.frame then
		UI.frame:Hide()
	end
	if OpenWorldMap then
		OpenWorldMap(entry.map)
	elseif WorldMapFrame then
		if not WorldMapFrame:IsShown() and ToggleWorldMap then
			ToggleWorldMap()
		end
		if WorldMapFrame.SetMapID then
			WorldMapFrame:SetMapID(entry.map)
		end
	end
end

function UI.Forget()
	local entry = UI.selected and V.Find(UI.selected)
	if not entry then
		return
	end
	local what = V.Forget(entry.key)
	if what == "forgotten" then
		ns.Print(L.FORGOTTEN:format(entry.name))
	elseif what == "hidden" then
		ns.Print(L.RUMOUR_HIDDEN)
	end
	UI.selected = nil
	UI.Refresh()
end

local function setting(key, value)
	ns.db.settings[key] = value
	ns.Fire("settings", key)
end

-- The kinds' chips, in as many rows as their texts need (they are wider in some languages), and the list
-- right under them. Called again when the language changes.
local KINDS_TOP, KIND_ROW, KIND_GAP = 34, 26, 5
function UI.FlowKinds()
	local f = UI.frame
	local left = f.pages.vendors.left
	local room = left:GetWidth() or 0
	if room <= 0 then
		room = 360
	end
	local x, row = 0, 0
	for _, cat in ipairs(ns.CATS) do
		local chip = f.cats[cat]
		local w = chip:GetWidth() or 60
		if x > 0 and x + w > room then
			x, row = 0, row + 1
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", left, "TOPLEFT", x, -(KINDS_TOP + row * KIND_ROW))
		x = x + w + KIND_GAP
	end
	f.kindRows = row + 1
	f.listHolder:ClearAllPoints()
	f.listHolder:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -(KINDS_TOP + (row + 1) * KIND_ROW + 4))
	f.listHolder:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -14, 0)
end

local function buildVendors(f, page)
	local left, right = page.left, page.right

	f.search = P.Edit(left, 150, {
		placeholder = L.SEARCH,
		onChange = function(_, text)
			UI.text = text or ""
			UI.Refresh()
		end,
	})
	f.search:SetPoint("TOPLEFT", 0, 0)
	f.scopeAll = P.Chip(left, L.SCOPE_ALL, function()
		UI.scope = "all"
		UI.Refresh()
	end)
	f.scopeAll:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, -2)
	f.scopeZone = P.Chip(left, L.SCOPE_ZONE, function()
		UI.scope = "zone"
		UI.Refresh()
	end)
	f.scopeZone:SetPoint("RIGHT", f.scopeAll, "LEFT", -6, 0)

	f.cats = {}
	for _, cat in ipairs(ns.CATS) do
		f.cats[cat] = P.Chip(left, L[ns.CAT_LABEL[cat]], function()
			ns.db.settings.cats[cat] = not ns.db.settings.cats[cat]
			ns.Fire("settings", "cats")
		end)
	end

	local holder = P.Panel(left)
	f.listHolder = holder
	UI.FlowKinds()
	f.list = P.List(holder, ROW_H, initRow, function(item)
		UI.selected = item.key
		UI.Refresh()
	end)
	f.list.box:SetPoint("TOPLEFT", 2, -2)
	f.list.box:SetPoint("BOTTOMRIGHT", -2, 2)
	f.empty = P.Label(holder, "", "muted", "CENTER")
	f.empty:SetPoint("TOPLEFT", 16, -24)
	f.empty:SetPoint("TOPRIGHT", -16, -24)
	f.empty:SetWordWrap(true)

	f.name = P.Label(right, "", "big")
	f.name:SetPoint("TOPLEFT")
	f.name:SetPoint("TOPRIGHT")
	f.name:SetWordWrap(false)
	f.where = P.Label(right, "", "body")
	f.where:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
	f.where:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	f.where:SetWordWrap(true)
	f.status = P.Label(right, "", "muted")
	f.status:SetPoint("TOPLEFT", f.where, "BOTTOMLEFT", 0, -6)
	f.status:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	f.status:SetWordWrap(true)

	f.mark = P.Button(right, L.WAYPOINT, 136, function()
		UI.Waypoint(UI.selected and V.Find(UI.selected))
	end)
	f.mark:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
	f.showMap = P.Button(right, L.SHOW_MAP, 104, function()
		UI.ShowOnMap(UI.selected and V.Find(UI.selected))
	end)
	f.showMap:SetPoint("LEFT", f.mark, "RIGHT", 8, 0)
	f.forget = P.Button(right, L.FORGET, 100, function()
		UI.Forget()
	end)
	f.forget:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)

	local itemsHolder = P.Panel(right)
	itemsHolder:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", 0, -10)
	itemsHolder:SetPoint("RIGHT", right, "RIGHT", -14, 0)
	itemsHolder:SetPoint("BOTTOM", f.mark, "TOP", 0, 10)
	f.itemsHolder = itemsHolder
	f.items = P.List(itemsHolder, ITEM_H, initItem, clickItem)
	f.items.box:SetPoint("TOPLEFT", 2, -2)
	f.items.box:SetPoint("BOTTOMRIGHT", -2, 2)
end

local OPTION_CHECKS = {
	{ "pins", "OPT_PINS" },
	{ "rumours", "OPT_RUMOURS" },
	{ "announce", "OPT_ANNOUNCE" },
	{ "otherSide", "OPT_OTHER_SIDE" },
	{ "minimap", "OPT_MINIMAP" },
	{ "minimapMerged", "OPT_MINIMAP_MERGED" },
}
local LANGS = { "auto", "es", "en" }

local function buildOptions(f, page)
	local left, right = page.left, page.right
	f.checks = {}
	local y = 0
	for _, pair in ipairs(OPTION_CHECKS) do
		local key = pair[1]
		local c = P.Check(left, L[pair[2]], function(self)
			local on = self:GetChecked() and true or false
			if key == "minimapMerged" then
				UI.SetMinimapMerged(on)
			else
				setting(key, on)
				if key == "minimap" then
					UI.Minimap()
				end
			end
		end)
		c:SetPoint("TOPLEFT", 0, y)
		c.label:SetWidth(330)
		c.label:SetWordWrap(true)
		c.textKey = pair[2]
		f.checks[key] = c
		y = y - 40
	end
	f.langLabel = P.Label(left, L.OPT_LANG, "strong")
	f.langLabel:SetPoint("TOPLEFT", 0, y - 6)
	f.langs = {}
	local prev
	for _, code in ipairs(LANGS) do
		local chip = P.Chip(left, L.LANG_NAMES[code], function()
			UI.SetLanguage(code)
		end)
		if prev then
			chip:SetPoint("LEFT", prev, "RIGHT", 6, 0)
		else
			chip:SetPoint("TOPLEFT", f.langLabel, "BOTTOMLEFT", 0, -8)
		end
		f.langs[code] = chip
		prev = chip
	end
	f.about = P.Label(right, L.OPT_ABOUT, "body")
	f.about:SetPoint("TOPLEFT")
	f.about:SetPoint("TOPRIGHT")
	f.about:SetWordWrap(true)
end

local function build()
	local f = P.Book(ADDON .. "Frame", {
		title = L.TITLE,
		width = 860,
		height = 540,
		tabs = { { "vendors", L.TAB_VENDORS }, { "options", L.TAB_OPTIONS } },
	})
	UI.frame = f
	local s = ns.db.settings
	if s.point then
		f:ClearAllPoints()
		f:SetPoint(unpack(s.point))
	end
	f.OnMoved = function(...)
		s.point = { ... }
	end
	f.OnTab = function()
		UI.Refresh()
	end
	buildVendors(f, f:AddPage("vendors"))
	buildOptions(f, f:AddPage("options"))
	f:SelectTab("vendors")
	f:HookScript("OnShow", function()
		UI.Refresh()
	end)
	return f
end

function UI.SetLanguage(code)
	ns.db.settings.lang = code
	ns.ApplyLanguage(code)
	ns.Print(L.LANG_SET:format(L.LANG_NAMES[code]))
end

-- The static texts, again: the language can change after the book was built.
function UI.ApplyTexts()
	local f = UI.frame
	if not f then
		return
	end
	f:SetTitle(L.TITLE)
	f.tabs.vendors:SetText(L.TAB_VENDORS)
	f.tabs.options:SetText(L.TAB_OPTIONS)
	f.search:SetPlaceholder(L.SEARCH)
	local function chip(c, text)
		c:SetText(text)
		c:Fit()
	end
	chip(f.scopeZone, L.SCOPE_ZONE)
	chip(f.scopeAll, L.SCOPE_ALL)
	for _, cat in ipairs(ns.CATS) do
		chip(f.cats[cat], L[ns.CAT_LABEL[cat]])
	end
	UI.FlowKinds()
	f.mark:SetText(L.WAYPOINT)
	f.showMap:SetText(L.SHOW_MAP)
	for _, c in pairs(f.checks) do
		c.label:SetText(L[c.textKey])
	end
	f.langLabel:SetText(L.OPT_LANG)
	for _, code in ipairs(LANGS) do
		chip(f.langs[code], L.LANG_NAMES[code])
	end
	f.about:SetText(L.OPT_ABOUT)
	UI.Refresh()
end

function UI.Refresh()
	local f = UI.frame
	if not f or not f:IsShown() then
		return
	end
	local s = ns.db.settings
	-- the list
	local rows = UI.Rows()
	local searching = UI.text ~= ""
	f.scopeZone:SetPressed(UI.scope == "zone" and not searching)
	f.scopeAll:SetPressed(UI.scope == "all" or searching)
	for _, cat in ipairs(ns.CATS) do
		f.cats[cat]:SetPressed(s.cats[cat])
	end
	f.list:SetData(rows, true)
	f.empty:SetText(#rows == 0 and ((UI.scope == "zone" and not searching) and L.EMPTY_ZONE or L.EMPTY_ALL) or "")
	-- the chosen vendor
	local detail = UI.Detail()
	local shown = detail ~= nil
	f.name:SetText(shown and detail.title or L.PICK_ONE)
	f.where:SetText(shown and detail.where or "")
	f.status:SetText(shown and detail.status or "")
	f.itemsHolder:SetShown(shown)
	f.mark:SetShown(shown)
	f.showMap:SetShown(shown)
	f.forget:SetShown(shown)
	if shown then
		f.items:SetData(detail.items, true)
		f.mark:SetEnabled(detail.canMark)
		f.mark:SetAlpha(detail.canMark and 1 or 0.45)
		f.forget:SetText(detail.forget)
	end
	-- the options
	for key, c in pairs(f.checks) do
		c:SetChecked(s[key] and true or false)
	end
	for _, code in ipairs(LANGS) do
		f.langs[code]:SetPressed(s.lang == code)
	end
end

function UI.Toggle()
	local f = UI.frame or build()
	if not f:IsShown() then
		-- open on this zone when there is something to show of it, on everything when there is not
		UI.scope = #V.List({ map = ns.PlayerMap() }) > 0 and "zone" or "all"
	end
	f:SetShown(not f:IsShown())
end

-- Open the book on a vendor (from a mark of the map, or after a search in chat).
function UI.Open(key, text)
	local f = UI.frame or build()
	local entry = key and V.Find(key)
	UI.text = text or ""
	f.search:SetValue(UI.text)
	if entry then
		UI.selected = key
		UI.scope = entry.map == ns.PlayerMap() and "zone" or "all"
	elseif text then
		UI.scope = "all"
	end
	f:SelectTab("vendors")
	f:Show()
	UI.Refresh()
end

-- This zone's vendors, one chat line each (the minimap button's right click).
function UI.ZoneToChat()
	local list = V.List({ map = ns.PlayerMap() })
	if #list == 0 then
		ns.Print(L.ZONE_NONE)
		return 0
	end
	for _, entry in ipairs(list) do
		local parts = {}
		for i, it in ipairs(V.ShownItems(entry, ns.db.settings.cats)) do
			if i > 4 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = ns.GameLink(it.id)
		end
		local name = entry.learned and entry.name or (entry.name .. " (" .. L.TAG_RUMOUR .. ")")
		ns.Print(L.ZONE_LINE:format(name .. ", " .. V.Where(entry), table.concat(parts, " ")))
	end
	return #list
end

-- The addon's own errors (Pergamino.Guard), on a card to copy them into an issue.
function UI.Errors()
	if not UI.errorsCard then
		local card = P.Card(ADDON .. "ErrorsCard", 460, 360, L.ERR_TITLE)
		card.page = ns.guard.Page(card.body)
		UI.errorsCard = card
	end
	UI.errorsCard.page.Refresh()
	UI.errorsCard:Show()
	return UI.errorsCard
end

-- The minimap button (Pergamino's), kept in the settings: shown or not, and where around the minimap. It is
-- registered in the family's hub (settings.minimapMerged = one button for every addon that shares the lib),
-- and its clicks go through the guard: an error is kept, not thrown.
function UI.Minimap()
	local s = ns.db.settings
	if not UI.minimap then
		UI.minimap = P.MinimapButton(ADDON .. "MinimapButton", {
			icon = "Interface\\AddOns\\" .. ADDON .. "\\Media\\icon",
			angle = s.minimapAngle,
			shown = s.minimap,
			onClick = function()
				UI.Toggle()
			end,
			onRightClick = function()
				UI.ZoneToChat()
			end,
			onMove = function(angle)
				s.minimapAngle = angle
			end,
			tooltip = function(tip)
				tip:SetText(L.TITLE)
				tip:AddLine(L.MINIMAP_TIP, 1, 1, 1)
			end,
			guard = ns.guard,
			hub = { addon = L.TITLE, label = L.TITLE, order = 8 },
		})
		-- the family's choice (one button for all) lives in every addon's settings: the hub reads and keeps it
		P.MinimapHub.Bind(s)
	end
	UI.minimap:SetShown(s.minimap)
	return UI.minimap
end

-- One button for the whole family (the lib keeps the choice for every addon).
function UI.SetMinimapMerged(merged)
	P.MinimapHub.Choose(merged)
	ns.Print(merged and L.MINIMAP_MERGED_ON or L.MINIMAP_MERGED_OFF)
end

ns.On("vendors", UI.Refresh)
ns.On("settings", UI.Refresh)
ns.On("items", UI.Refresh)
ns.On("language", UI.ApplyTexts)
