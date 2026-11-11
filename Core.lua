-- ExplorersMap: which pieces of each zone's map the character has discovered.
-- The game tells which map pieces are explored (C_MapExplorationInfo.GetExploredMapTextures);
-- Data.lua lists every piece there is, so the rest are the ones still to find.
--   ns.zones[i] = { mapID, maps, c (continent), n (name index), pieces, total, done }
--   piece = { zone, n (name index), x, y (on the zone's map, 0..1), r (radius, share of the map's width),
--             ox, oy (the piece's corner on the map art), explored }

local ADDON, ns = ...
ExplorersMap = ns

ns.zones, ns.byMap, ns.listeners = {}, {}, {}
ns.total, ns.done = 0, 0
local T = ns.T

local DEFAULTS = { lang = "eng", pins = true, zoneOnly = false, minimap = true, angle = 215, sort = 1, announce = true,
	colorMode = "single", color = 1, size = 2 }
ns.PALETTE = { { 0.45, 0.72, 1 }, { 1, 0.82, 0.2 }, { 0.5, 0.95, 0.4 }, { 1, 0.38, 0.32 }, { 0.82, 0.55, 1 }, { 1, 0.6, 0.2 }, { 1, 1, 1 } }
ns.REGION_COLORS = { { 1, 0.6, 0.2 }, { 0.45, 0.72, 1 }, { 0.82, 0.55, 1 } }                 -- Kalimdor, Eastern Kingdoms, islands
ns.RISK_COLORS = { { 0.4, 0.9, 0.45 }, { 1, 0.85, 0.25 }, { 1, 0.55, 0.2 }, { 1, 0.3, 0.3 } }  -- safe, your level, risky, deadly
local TOLERANCE = 3             -- px: the two arts of a zone place the same piece a pixel or two apart
local RADIUS_YARDS = 10.94      -- the circle round a chosen area: 10 m

function ns.Listen(fn) ns.listeners[#ns.listeners + 1] = fn end

-- tells the map pins, the minimap button and the window that something changed
function ns.Notify(what, arg)
	for _, fn in ipairs(ns.listeners) do
		local ok, err = pcall(fn, what, arg)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end

function ns.Print(msg)
	local chat = DEFAULT_CHAT_FRAME
	if chat then chat:AddMessage("|cff5cc8ffExplorersMap|r: " .. tostring(msg)) end
end

-- a colour for a share explored (0..1): red, amber, green
function ns.Color(p)
	if p >= 1 then return 0.3, 0.95, 0.5 end
	if p >= 0.67 then return 0.55, 0.85, 0.4 end
	if p >= 0.34 then return 1, 0.8, 0.25 end
	return 0.95, 0.45, 0.3
end

function ns.Percent() return ns.total > 0 and ns.done / ns.total or 0 end

function ns.PlayerLevel()
	local ok, level = pcall(function() return tonumber(UnitLevel("player")) end)
	return math.max(ok and level or 0, ns.level or 0, 1)
end

-- "Alliance" or "Horde" (nil when the game doesn't say), and its name in the game's language
function ns.PlayerFaction()
	local ok, faction, name = pcall(UnitFactionGroup, "player")
	if ok and (faction == "Alliance" or faction == "Horde") then return faction, name or faction end
	return nil, ""
end

-- a zone's levels and owner (ZoneInfo.lua): { min, max, "A" | "H" | "C" | "S", elites }
function ns.Info(zone)
	for _, id in ipairs(zone.maps) do
		local info = ns.ZoneInfo and ns.ZoneInfo[id]
		if info then return info end
	end
end

-- how risky a zone is at the player's level: 1 safe, 2 your level, 3 risky, 4 deadly
function ns.Risk(zone)
	local info = ns.Info(zone)
	if not info or not info[1] then return 1 end
	local level = ns.PlayerLevel()
	if info[2] <= level then return 1 end
	if info[1] <= level then return 2 end
	if info[1] <= level + 4 then return 3 end
	return 4
end

-- a pin's colour, as the settings say: one colour, by region, or by the zone's risk at your level
function ns.PinColor(piece)
	local db, c = ExplorersMapDB, nil
	if db.colorMode == "region" then
		c = ns.REGION_COLORS[piece.zone.c]
	elseif db.colorMode == "level" then
		c = ns.RISK_COLORS[ns.Risk(piece.zone)]
	end
	c = c or ns.PALETTE[db.color] or ns.PALETTE[1]
	return c[1], c[2], c[3]
end

local function ArtSize(mapID)
	local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
	local layer = ok and type(layers) == "table" and layers[1]
	if layer and (tonumber(layer.layerWidth) or 0) > 0 and (tonumber(layer.layerHeight) or 0) > 0 then
		return layer.layerWidth, layer.layerHeight
	end
	return 1002, 668
end

-- a map's width in yards (nil when the game doesn't say)
local function WidthYards(mapID)
	local ok, width = pcall(function()
		local _, a = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
		local _, b = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
		local _, ay = a:GetXY()
		local _, by = b:GetXY()
		return math.abs(ay - by)
	end)
	if ok and type(width) == "number" and width > 200 then return width end
end

-- the zones this client has, each with the pieces of the map art it uses
local function Build()
	wipe(ns.zones)
	wipe(ns.byMap)
	for _, z in ipairs(ns.Data.zones) do
		local maps, primary, variant = {}, nil, nil
		for _, id in ipairs(z.m) do
			local ok, info = pcall(C_Map.GetMapInfo, id)
			if ok and info then
				maps[#maps + 1] = id
				local okArt, art = pcall(C_Map.GetMapArtID, id)
				art = okArt and art or nil
				for i, a in ipairs(z.a) do
					if a == art and not variant then primary, variant = id, (i == 1 and "o" or "n") end
				end
			end
		end
		if #maps > 0 then
			primary = primary or maps[1]
			if #z.a < 2 then variant = nil else variant = variant or "n" end
			local W, H = ArtSize(primary)
			local radius = RADIUS_YARDS / (WidthYards(primary) or 4500)
			local zone = { mapID = primary, maps = maps, c = z.c, n = z.n, pieces = {}, total = 0, done = 0 }
			for entry in z.p:gmatch("[^;]+") do
				local x, y, w, h, n, flag = strsplit(",", entry)
				if not flag or not variant or flag == variant then
					x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
					zone.pieces[#zone.pieces + 1] = { zone = zone, n = tonumber(n), ox = x, oy = y,
						x = (x + w / 2) / W, y = (y + h / 2) / H, r = radius, explored = false }
				end
			end
			zone.total = #zone.pieces
			ns.zones[#ns.zones + 1] = zone
			for _, id in ipairs(maps) do ns.byMap[id] = zone end
		end
	end
end

local function ScanZone(zone)
	local seen = {}
	for _, id in ipairs(zone.maps) do
		local list = C_MapExplorationInfo.GetExploredMapTextures(id)
		if type(list) == "table" then
			for _, info in ipairs(list) do
				if type(info.offsetX) == "number" and type(info.offsetY) == "number" then seen[#seen + 1] = info end
			end
		end
	end
	local found
	for _, p in ipairs(zone.pieces) do
		if not p.explored then
			for _, info in ipairs(seen) do
				if math.abs(info.offsetX - p.ox) <= TOLERANCE and math.abs(info.offsetY - p.oy) <= TOLERANCE then
					p.explored = true
					found = found or {}
					found[#found + 1] = p
					break
				end
			end
		end
	end
	return found
end

-- reads what's explored now; a piece once seen explored stays so (the game never takes it back)
function ns.Scan()
	local news = {}
	for _, zone in ipairs(ns.zones) do
		local ok, found = pcall(ScanZone, zone)
		if ok and found then for _, p in ipairs(found) do news[#news + 1] = p end end
	end
	local total, done = 0, 0
	for _, zone in ipairs(ns.zones) do
		local d = 0
		for _, p in ipairs(zone.pieces) do if p.explored then d = d + 1 end end
		zone.done = d
		total, done = total + zone.total, done + d
	end
	ns.total, ns.done = total, done
	-- (not at login, when everything already explored arrives at once)
	if ns.ready and ExplorersMapDB.announce and #news <= 3 and GetTime() > (ns.quietUntil or 0) then
		for i = 1, #news do
			local p = news[i]
			ns.Print(T("DISCOVERED_MSG"):format(ns.Name(p.n), ns.Name(p.zone.n), p.zone.done, p.zone.total, ns.Percent() * 100))
			ns.Toast(p)
		end
	end
	for _, p in ipairs(news) do if ns.selected == p then ns.selected = nil end end
	local first = not ns.ready
	ns.ready = true
	if first or #news > 0 then ns.Notify("scan") end
end

local scanQueued = false
function ns.QueueScan(delay)
	if scanQueued then return end
	scanQueued = true
	C_Timer.After(delay or 0.4, function() scanQueued = false ns.Scan() end)
end

-- the piece whose area the map shows with a circle (nil: none)
function ns.Select(piece)
	ns.selected = piece
	ns.Notify("select")
end

function ns.SetPins(on)
	ExplorersMapDB.pins = on and true or false
	ns.Notify("pins")
end

-- opens the world map on a zone, or on one of its pieces (circled)
function ns.ShowOnMap(zone, piece)
	if piece then ns.selected = piece end
	local map = WorldMapFrame
	if not map then return end
	if not map:IsShown() then
		if ToggleWorldMap then pcall(ToggleWorldMap) else pcall(map.Show, map) end
	end
	if map.SetMapID then pcall(map.SetMapID, map, zone.mapID) end
	local OM = OpenMapAPI
	if OM and OM.IsStitched and OM.WorldFromMap and OM.ShowWorld then
		pcall(function()
			if not OM.IsStitched() then return end
			local u, v = OM.WorldFromMap(zone.mapID, piece and piece.x or 0.5, piece and piece.y or 0.5)
			if not u then return end
			local _, _, zoom = OM.GetView()
			OM.ShowWorld(u, v, math.max(tonumber(zoom) or 1, piece and 7 or 5))
		end)
	end
	ns.Notify("select")
end

-- the zone the character is in (in a city or a cave: the zone round it)
function ns.CurrentZone()
	local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
	id = ok and id or nil
	for _ = 1, 5 do
		if type(id) ~= "number" then return end
		if ns.byMap[id] then return ns.byMap[id] end
		local okInfo, info = pcall(C_Map.GetMapInfo, id)
		id = okInfo and info and info.parentMapID or nil
	end
end

-- a discovery on the screen: the area's name, then its zone's count, fading in and out
-- (several queue up, one after the other)
local toast, waiting = nil, {}
local function NextToast()
	local p = tremove(waiting, 1)
	if not p then toast:Hide() return end
	toast.title:SetText(T("TOAST_TITLE"):format(ns.Name(p.n)))
	toast.sub:SetText(T("TOAST_SUB"):format(ns.Name(p.zone.n), p.zone.done, p.zone.total, ns.Percent() * 100))
	toast.age = 0
	toast:SetAlpha(0)
	toast:Show()
end

function ns.Toast(piece)
	if not toast then
		local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		toast = CreateFrame("Frame", nil, UIParent)
		toast:SetSize(700, 60)
		toast:SetPoint("TOP", 0, -150)
		toast:SetFrameStrata("HIGH")
		toast.title = toast:CreateFontString(nil, "OVERLAY")
		toast.title:SetFont(font, 26, "OUTLINE")
		toast.title:SetPoint("TOP", 0, 0)
		toast.title:SetTextColor(1, 0.82, 0.2)
		toast.sub = toast:CreateFontString(nil, "OVERLAY")
		toast.sub:SetFont(font, 15, "OUTLINE")
		toast.sub:SetPoint("TOP", toast.title, "BOTTOM", 0, -6)
		toast.sub:SetTextColor(1, 1, 1)
		toast:SetScript("OnUpdate", function(self, elapsed)
			local age = (self.age or 0) + elapsed
			self.age = age
			if age >= 4.5 then NextToast() return end
			self:SetAlpha(age < 0.4 and age / 0.4 or (age > 3.7 and (4.5 - age) / 0.8 or 1))
		end)
		toast:Hide()
	end
	waiting[#waiting + 1] = piece
	if not toast:IsShown() then NextToast() end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" then
		if arg ~= ADDON then return end
		ExplorersMapDB = type(ExplorersMapDB) == "table" and ExplorersMapDB or {}
		for k, v in pairs(DEFAULTS) do if ExplorersMapDB[k] == nil then ExplorersMapDB[k] = v end end
		if not ns.languages[ExplorersMapDB.lang] then ExplorersMapDB.lang = "eng" end
	elseif event == "PLAYER_LOGIN" then
		local ok, err = pcall(Build)
		if not ok and geterrorhandler then geterrorhandler()(err) end
		ns.Notify("login")
		ns.QueueScan(1)
	elseif event == "PLAYER_LEVEL_UP" then
		ns.level = tonumber(arg)
		ns.Notify("level")
	else
		if event == "PLAYER_ENTERING_WORLD" then ns.quietUntil = GetTime() + 8 end
		ns.QueueScan(event == "PLAYER_ENTERING_WORLD" and 1.5 or 0.4)
	end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "MAP_EXPLORATION_UPDATED",
	"ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_LEVEL_UP" }) do
	pcall(events.RegisterEvent, events, event)
end

SLASH_EXPLORERSMAP1, SLASH_EXPLORERSMAP2 = "/emap", "/explorersmap"
SlashCmdList["EXPLORERSMAP"] = function(msg)
	msg = strlower(strtrim(msg or ""))
	if msg == "pins" or msg == "pines" then
		ns.SetPins(not ExplorersMapDB.pins)
		ns.Print(T(ExplorersMapDB.pins and "PINS_ON" or "PINS_OFF"))
	elseif msg == "help" or msg == "ayuda" or msg == "?" then
		ns.Print(T("HELP"))
	elseif ns.ToggleWindow then
		ns.ToggleWindow()
	end
end
