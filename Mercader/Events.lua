local ADDON, ns = ...
local L = ns.L

local Learn, Map, V = ns.Learn, ns.Map, ns.Vendors

-- A purchase changes the stock: the window is read again a moment later (several updates come together).
local RESCAN_DELAY, ITEMS_DELAY = 0.3, 0.5
local rescan, itemsSoon = false, false

local handlers = {
	MERCHANT_SHOW = function()
		Learn.Scan(true)
	end,
	MERCHANT_UPDATE = function()
		if rescan then
			return
		end
		rescan = true
		C_Timer.After(RESCAN_DELAY, function()
			rescan = false
			if MerchantFrame and MerchantFrame:IsShown() then
				Learn.Scan(false)
			end
		end)
	end,
	-- an item's name arrived: the pages that wrote "Item 4817" are drawn again, once for the whole batch
	GET_ITEM_INFO_RECEIVED = function()
		if itemsSoon then
			return
		end
		itemsSoon = true
		C_Timer.After(ITEMS_DELAY, function()
			itemsSoon = false
			ns.Fire("items")
		end)
	end,
	-- the list follows the player's zone; read a moment later, when the client already knows where it is
	ZONE_CHANGED_NEW_AREA = function()
		C_Timer.After(1, function()
			ns.UI.Refresh()
		end)
	end,
}

local onSlash -- the /mercader handler, defined below; guarded once the saved variables are in
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... == ADDON then
			ns.InitDB()
			frame:UnregisterEvent("ADDON_LOADED")
			-- from here on a Lua error in a handler is kept, not thrown (see /mercader errores)
			SlashCmdList.MERCADER = ns.guard.Install(frame, onSlash)
		end
	elseif event == "PLAYER_LOGIN" then
		ns.UI.Minimap()
		Map.Init()
		for e in pairs(handlers) do
			frame:RegisterEvent(e)
		end
	elseif handlers[event] then
		handlers[event](...)
	end
end)

local function onOff(word, current)
	if word == "on" or word == "si" or word == "sí" then
		return true
	elseif word == "off" or word == "no" then
		return false
	end
	return not current
end

-- /mercader zonas: the zones of the addon's own list, as this client names them (a wrong id shows at once).
local function zones()
	local seen, ids = {}, {}
	for _, s in ipairs(ns.Seed) do
		if not seen[s.map] then
			seen[s.map] = true
			ids[#ids + 1] = s.map
		end
	end
	table.sort(ids)
	ns.Print(L.ZONES_HEAD)
	local missing = 0
	for _, id in ipairs(ids) do
		local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
		if info and info.name then
			ns.Print(id .. ": " .. info.name)
		else
			missing = missing + 1
			ns.Print(L.ZONES_MISSING:format(id))
		end
	end
	return #ids, missing
end
ns.Zones = zones

SLASH_MERCADER1 = "/mercader"
onSlash = function(msg)
	local raw = strtrim(msg or "")
	msg = raw:lower()
	local s = ns.db.settings
	if msg:match("^buscar%s") or msg:match("^search%s") or msg:match("^find%s") then
		ns.UI.Open(nil, strtrim(raw:match("^%S+%s+(.*)$") or ""))
	elseif msg:match("^mapa") or msg:match("^map%f[%A]") then
		s.pins = onOff(msg:match("%s+(%S+)$"), s.pins)
		ns.Fire("settings", "pins")
		ns.Print(s.pins and L.PINS_ON or L.PINS_OFF)
	elseif msg == "rumores" or msg == "rumours" or msg == "rumors" then
		ns.Print(L.RUMOURS_BACK:format(V.UnhideAll()))
	elseif msg == "zonas" or msg == "zones" then
		zones()
	elseif msg:match("^minimapa%s+juntar") or msg:match("^minimap%s+merge") then
		local word = msg:match("%s+(%a+)$")
		if word == "on" or word == "off" then
			ns.UI.SetMinimapMerged(word == "on")
		else
			ns.UI.SetMinimapMerged(not s.minimapMerged)
		end
	elseif msg:match("^minimapa") or msg:match("^minimap") then
		s.minimap = onOff(msg:match("%s+(%S+)$"), s.minimap)
		ns.UI.Minimap()
		ns.UI.Refresh()
	elseif msg:match("^idioma") or msg:match("^language") or msg:match("^lang") then
		local code = msg:match("%s+(%a+)$")
		if code == "es" or code == "en" or code == "auto" then
			ns.UI.SetLanguage(code)
		else
			ns.Print(L.LANG_USAGE)
		end
	elseif msg == "errores" or msg == "errors" then
		ns.UI.Errors()
	elseif msg == "help" or msg == "ayuda" then
		ns.Print(L.HELP)
	else
		ns.UI.Toggle()
	end
end
SlashCmdList.MERCADER = onSlash

-- the addon compartment is not a frame, so its click is wrapped by hand (an error is kept, not thrown)
function Mercader_OnAddonCompartmentClick()
	if ns.guard then
		ns.guard.Wrap(ns.UI.Toggle, "compartment")()
	else
		ns.UI.Toggle()
	end
end
function Mercader_OnAddonCompartmentEnter(_, button)
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText(L.TITLE)
	GameTooltip:AddLine(L.COMPARTMENT, 1, 1, 1)
	GameTooltip:Show()
end
function Mercader_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end

-- Key binding (Bindings.xml, loaded by the game on its own: it is not listed in the TOC) and its names.
_G["Mercader_Toggle"] = function()
	ns.UI.Toggle()
end
_G["BINDING_HEADER_MERCADER"] = "Mercader"
_G["BINDING_NAME_MERCADER_TOGGLE"] = L.BINDING_TOGGLE
