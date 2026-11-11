-- ExplorersMap: a pin on the world map for every area still to discover, and a circle round the
-- one chosen (the area that may unlock it; a discovered area chosen in the window shows too, in
-- green). The pins are frames on the map's canvas, kept the same size on screen at any zoom. On
-- OpenMap's stitched map they go through OpenMapAPI, so every zone's pins show; on Blizzard's own
-- map, the zone's (or, on a continent, its zones'). Settings: which maps, the size, the colours.

local _, ns = ...
local T = ns.T

local SIZES = { 18, 24, 30 }    -- px on screen: small, medium, large
local ATLAS, FALLBACK = "Waypoint-MapPin-Untracked", "Interface\\Minimap\\Ping\\ping5"
local GOLD, GREEN = { 1, 0.82, 0.2 }, { 0.4, 0.95, 0.5 }
local SEGMENTS = 48             -- the circle's
local MIN_RING = 18             -- px on screen: the circle's radius at least (10 m is a pixel or two on a zone's map)
local ZONE_ZOOM = 3             -- OpenMap's zoom from which a zone counts as "its own map"

local canvas, host, ring, driver
local pool, active = {}, {}
local dirty, lastSig = true, nil

-- the look of a map pin (OpenMap's own), in a colour
function ns.PinLook(tex, r, g, b)
	local known = C_Texture and C_Texture.GetAtlasInfo
	if tex.SetAtlas and (not known or C_Texture.GetAtlasInfo(ATLAS)) then
		tex:SetAtlas(ATLAS)
	else
		tex:SetTexture(FALLBACK)
	end
	tex:SetVertexColor(r or 0.45, g or 0.72, b or 1)
end

local function Stitched()
	local OM = OpenMapAPI
	if not (OM and OM.IsStitched and OM.WorldFromMap and OM.MapFromWorld) then return false end
	local ok, on = pcall(OM.IsStitched)
	return ok and on and true or false
end

-- a function that places a point of a zone's map (0..1) on the canvas (0..1 of the map showing,
-- and past it); how big the pins are at this view (0..1); and, with "only on zone maps", the one
-- zone whose pins show (false: none). nil when this map takes no pins
local function Mapper()
	local mapID = WorldMapFrame:GetMapID()
	if not mapID then return end
	local zoneOnly = ExplorersMapDB.zoneOnly
	if Stitched() then
		local OM = OpenMapAPI
		local u, v, zoom = OM.GetView()
		zoom = tonumber(zoom) or 4
		local only
		if zoneOnly then
			local here = zoom >= ZONE_ZOOM and OM.MapAt and u and v and OM.MapAt(u, v)
			only = here and ns.byMap[here] or false
		end
		return function(zone, x, y)
			local wu, wv = OM.WorldFromMap(zone.mapID, x, y)
			if not wu then return end
			return OM.MapFromWorld(mapID, wu, wv)
		end, math.max(0.4, math.min(1, zoom / 5)), only
	end
	local shown = ns.byMap[mapID]
	if shown then
		return function(zone, x, y) if zone == shown then return x, y end end, 1, nil
	end
	local info = C_Map.GetMapInfo(mapID)
	local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
	if not info or info.mapType ~= continent or not C_Map.GetMapRectOnMap then return end
	local rects = {}
	return function(zone, x, y)
		local r = rects[zone]
		if r == nil then
			r = false
			local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, zone.mapID, mapID)
			if ok and left and right and top and bottom and right > left and bottom > top then r = { left, right, top, bottom } end
			rects[zone] = r
		end
		if r then return r[1] + x * (r[2] - r[1]), r[3] + y * (r[4] - r[3]) end
	end, 0.6, zoneOnly and false or nil
end

local function OnEnter(self)
	local p = self.piece
	if not p then return end
	local zone = p.zone
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(("%s  |cff73b8ff(%s)|r"):format(ns.Name(p.n), T("MARGIN_SHORT")), 1, 0.82, 0, true)
	GameTooltip:AddLine(("%s  %.1f, %.1f"):format(ns.Name(zone.n), p.x * 100, p.y * 100), 1, 1, 1)
	if p.explored then
		GameTooltip:AddLine(T("PIN_FOUND"), 0.4, 0.9, 0.5)
	else
		GameTooltip:AddLine(T("MARGIN"), 0.45, 0.72, 1, true)
	end
	GameTooltip:AddLine(T("ZONE_FMT"):format(ns.Name(zone.n), zone.done, zone.total,
		zone.total > 0 and math.floor(zone.done / zone.total * 100 + 0.5) or 0), 0.8, 0.8, 0.8)
	GameTooltip:AddLine(T(ns.selected == p and "PIN_CLICK_OFF" or "PIN_CLICK"), 0.6, 0.6, 0.6, true)
	GameTooltip:Show()
end

local function OnClick(self)
	local p = self.piece
	if not p then return end
	ns.Select(ns.selected ~= p and p or nil)
	if GameTooltip:IsOwned(self) then OnEnter(self) end
end

local function NewPin()
	local b = CreateFrame("Button", nil, host)
	b:SetSize(24, 24)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	ns.PinLook(b.icon)
	b.glow = b:CreateTexture(nil, "HIGHLIGHT")
	b.glow:SetAllPoints()
	ns.PinLook(b.glow, 1, 1, 1)
	b.glow:SetBlendMode("ADD")
	b.glow:SetAlpha(0.45)
	b:SetScript("OnEnter", OnEnter)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", OnClick)
	return b
end

local function BuildRing()
	ring = CreateFrame("Frame", nil, host)
	ring:SetSize(10, 10)
	ring.disc = ring:CreateTexture(nil, "BACKGROUND")
	ring.disc:SetAllPoints()
	ring.disc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	ring.lines = {}
	if ring.CreateLine then
		for i = 1, SEGMENTS do ring.lines[i] = ring:CreateLine(nil, "ARTWORK") end
	end
	if ring.CreateAnimationGroup then
		local pulse = ring:CreateAnimationGroup()
		local fade = pulse:CreateAnimation("Alpha")
		if fade.SetFromAlpha then
			fade:SetFromAlpha(1)
			fade:SetToAlpha(0.55)
			fade:SetDuration(0.9)
			pulse:SetLooping("BOUNCE")
			ring.pulse = pulse
		end
	end
	ring:Hide()
end

-- the circle: `radius` in the canvas's own units, its line `thick`, in a colour
local function PlaceRing(cx, cy, radius, thick, c)
	ring:ClearAllPoints()
	ring:SetSize(radius * 2, radius * 2)
	ring:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * cx, -canvas:GetHeight() * cy)
	ring.disc:SetVertexColor(c[1], c[2], c[3], 0.22)
	local step = 2 * math.pi / SEGMENTS
	for i, line in ipairs(ring.lines) do
		local a, b = (i - 1) * step, i * step
		line:SetColorTexture(c[1], c[2], c[3], 0.95)
		line:SetThickness(thick)
		line:SetStartPoint("CENTER", ring, math.cos(a) * radius, math.sin(a) * radius)
		line:SetEndPoint("CENTER", ring, math.cos(b) * radius, math.sin(b) * radius)
	end
	ring:Show()
	if ring.pulse and not ring.pulse:IsPlaying() then ring.pulse:Play() end
end

local function Level()
	local level = canvas:GetFrameLevel() + 2030
	local OM = OpenMapAPI
	if OM and OM.ArtTopLevel then
		local ok, top = pcall(OM.ArtTopLevel)
		if ok and type(top) == "number" then level = math.max(level, top + 5) end
	end
	return math.min(level, 9000)
end

local function Layout()
	for i = #active, 1, -1 do
		active[i]:Hide()
		pool[#pool + 1] = active[i]
		active[i] = nil
	end
	ring:Hide()
	local showAll = ExplorersMapDB.pins
	local selected = ns.selected
	if not showAll and not selected then return end
	local place, size, only = Mapper()
	if not place then return end
	local width, height = canvas:GetWidth(), canvas:GetHeight()
	local onScreen = canvas:GetEffectiveScale() / UIParent:GetEffectiveScale()   -- canvas units -> px
	if not (width > 0 and height > 0 and onScreen > 0) then return end
	size = size * (SIZES[ExplorersMapDB.size] or 24) / 24
	local level = Level()
	host:SetFrameLevel(level)
	ring:SetFrameLevel(level + 1)
	for _, zone in ipairs(ns.zones) do
		local all = showAll and (only == nil or only == zone) and zone.done < zone.total
		if all or (selected and selected.zone == zone) then
			for _, p in ipairs(zone.pieces) do
				local chosen = p == selected
				if chosen or (all and not p.explored) then
					local ok, cx, cy = pcall(place, zone, p.x, p.y)
					if ok and cx and cy and cx > -1 and cx < 2 and cy > -1 and cy < 2 then
						local b = tremove(pool) or NewPin()
						local scale = size * (chosen and 1.3 or 1) / onScreen
						b.piece = p
						if chosen then
							local c = p.explored and GREEN or GOLD
							b.icon:SetVertexColor(c[1], c[2], c[3])
							local ok2, ex = pcall(place, zone, p.x + p.r, p.y)
							local radius = ok2 and ex and math.abs(ex - cx) * width or 0
							PlaceRing(cx, cy, math.max(radius, MIN_RING / onScreen), 2 / onScreen, c)
						else
							b.icon:SetVertexColor(ns.PinColor(p))
						end
						b:SetScale(scale)
						b:ClearAllPoints()
						b:SetPoint("CENTER", canvas, "TOPLEFT", width * cx / scale, -height * cy / scale)
						b:SetFrameLevel(level + (chosen and 3 or 2))
						b:Show()
						active[#active + 1] = b
					end
				end
			end
		end
	end
end

local function Signature()
	local sig = ("%s:%.4f:%.1f"):format(tostring(WorldMapFrame:GetMapID()), canvas:GetEffectiveScale(), canvas:GetWidth())
	if Stitched() then
		local u, v, zoom = OpenMapAPI.GetView()
		sig = ("%s:%.5f:%.5f:%.3f"):format(sig, tonumber(u) or 0, tonumber(v) or 0, tonumber(zoom) or 0)
	end
	return sig
end

local wait = 0
local function Tick(_, elapsed)
	wait = wait + elapsed
	if wait < 0.05 and not dirty then return end
	wait = 0
	local ok, sig = pcall(Signature)
	if not ok then return end
	if dirty or sig ~= lastSig then
		dirty, lastSig = false, sig
		local okLayout, err = pcall(Layout)
		if not okLayout and geterrorhandler then geterrorhandler()(err) end
	end
end

local function Setup()
	if host then return true end
	local map = WorldMapFrame
	if not map then return false end
	canvas = (map.GetCanvas and map:GetCanvas()) or (map.ScrollContainer and map.ScrollContainer.Child)
	if not canvas then return false end
	host = CreateFrame("Frame", nil, canvas)
	host:SetAllPoints(canvas)
	BuildRing()
	driver = CreateFrame("Frame", nil, map)
	driver:SetScript("OnShow", function() dirty = true end)
	driver:SetScript("OnUpdate", Tick)
	-- a switch in OpenMap's own menu, when it's there
	local OM = OpenMapAPI
	if OM and OM.RegisterMenuToggle then
		pcall(OM.RegisterMenuToggle, "ExplorersMap", { id = "pins", label = T("OM_TOGGLE"), section = T("OM_SECTION"),
			icon = "Interface\\Icons\\INV_Misc_Map_01",
			get = function() return ExplorersMapDB.pins end, set = function(on) ns.SetPins(on) end })
	end
	return true
end

ns.Listen(function(what)
	if what == "login" then
		if not Setup() then
			-- (the world map comes with an addon of Blizzard's on some clients: wait for it)
			local waiter = CreateFrame("Frame")
			waiter:RegisterEvent("ADDON_LOADED")
			waiter:SetScript("OnEvent", function(self) if Setup() then self:UnregisterAllEvents() end end)
		end
	end
	dirty = true
end)
