-- ExplorersMap: the guide arrow. An arrow on the screen (top centre; drag it anywhere) that turns
-- towards the nearest area still to discover in the zone the character is in (or the area chosen
-- on the map, when it's in this zone), with its name and how far it is. Only once that zone is all
-- explored does it point out of it: to the nearest area of another zone of the continent. Green
-- when near, yellow when far, red when very far. It hides where there's nothing to point at (a
-- dungeon, a continent all explored). Settings: "Guide arrow"; /emap arrow.

local _, ns = ...
local T = ns.T

local SIZE = 56                 -- px: the arrow's box
local NEAR, FAR = 150, 500      -- metres: green up to NEAR, yellow up to FAR, red past it
local COLORS = { { 0.35, 0.95, 0.45 }, { 1, 0.85, 0.25 }, { 1, 0.3, 0.3 } }
local METRES = 0.9144           -- a yard
-- the arrow's strokes, pointing up, in shares of half its box: x1, y1, x2, y2
local STROKES = { { 0, -0.9, 0, 0.9 }, { -0.55, 0.3, 0, 0.95 }, { 0.55, 0.3, 0, 0.95 } }

local arrow, driver, target, home
local sinceTarget, sinceDraw = 1, 1

-- where the character is on a zone's map (0..1); nil when the game doesn't say (a dungeon)
local function PlayerOn(zone)
	if not (C_Map and C_Map.GetPlayerMapPosition) then return end
	local ok, x, y = pcall(function()
		local pos = C_Map.GetPlayerMapPosition(zone.mapID, "player")
		if not pos then return end
		if pos.GetXY then return pos:GetXY() end
		return pos.x, pos.y
	end)
	if ok and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then return x, y end
end

-- the continent's map a zone's map is on
local function Continent(mapID)
	local id = mapID
	for _ = 1, 6 do
		local ok, info = pcall(C_Map.GetMapInfo, id)
		if not ok or not info then return end
		if info.mapType == 2 then return id end
		id = info.parentMapID
		if type(id) ~= "number" or id == 0 then return end
	end
end

-- how a zone's map lies on its continent, to measure from one zone to another: { cont, e0, e1,
-- n0, n1 } (a point of the map is e0 + x * e1 yards east, n0 + y * n1 north); false when the game
-- doesn't say. From the world's own coordinates, or else from the zone's place on the continent's map
local scales = {}
local function Lie(zone)
	if zone.lie ~= nil then return zone.lie end
	local lie = false
	local ok, cont, x0, y0, x1, y1 = pcall(function()
		local c, a = C_Map.GetWorldPosFromMapPos(zone.mapID, CreateVector2D(0, 0))
		local _, b = C_Map.GetWorldPosFromMapPos(zone.mapID, CreateVector2D(1, 1))
		local ax, ay = a:GetXY()
		local bx, by = b:GetXY()
		return c, ax, ay, bx, by
	end)
	-- (the world's x runs north, its y west)
	if ok and cont and type(x0) == "number" and type(y1) == "number" and math.abs(y1 - y0) > 200 and math.abs(x1 - x0) > 200 then
		lie = { cont = "w" .. tostring(cont), e0 = -y0, e1 = y0 - y1, n0 = x0, n1 = x1 - x0 }
	else
		local c = Continent(zone.mapID)
		if c and C_Map.GetMapRectOnMap then
			local ok2, l, r, t, b = pcall(C_Map.GetMapRectOnMap, zone.mapID, c)
			if ok2 and l and r and t and b and r > l and b > t then
				local s = scales[c] or { zone.width / (r - l), zone.height / (b - t) }
				scales[c] = s
				lie = { cont = "m" .. tostring(c), e0 = l * s[1], e1 = (r - l) * s[1], n0 = -t * s[2], n1 = (t - b) * s[2] }
			end
		end
	end
	zone.lie = lie
	return lie
end

-- the area to point at, and the zone the character is in: the area chosen, when it's in this zone
-- and still to discover; or this zone's nearest; or, this zone all explored, the nearest of another
local function Nearest()
	local zone = ns.CurrentZone()
	if not zone then return end
	local px, py = PlayerOn(zone)
	if not px then return end
	local chosen = ns.selected
	if chosen and not chosen.explored and chosen.zone == zone then return chosen, zone end
	local best, bestD
	for _, p in ipairs(zone.pieces) do
		if not p.explored then
			local dx, dy = (p.x - px) * zone.width, (p.y - py) * zone.height
			local d = dx * dx + dy * dy
			if not bestD or d < bestD then best, bestD = p, d end
		end
	end
	if best then return best, zone end
	local here = Lie(zone)
	if not here then return end
	local pe, pn = here.e0 + px * here.e1, here.n0 + py * here.n1
	for _, other in ipairs(ns.zones) do
		local lie = other ~= zone and other.done < other.total and Lie(other)
		if lie and lie.cont == here.cont then
			for _, p in ipairs(other.pieces) do
				if not p.explored then
					local de, dn = lie.e0 + p.x * lie.e1 - pe, lie.n0 + p.y * lie.n1 - pn
					local d = de * de + dn * dn
					if not bestD or d < bestD then best, bestD = p, d end
				end
			end
		end
	end
	return best, zone
end

local function OnEnter(self)
	local p = target
	if not p then return end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(ns.Name(p.n), 1, 0.82, 0)
	GameTooltip:AddLine(("%s  %.1f, %.1f"):format(ns.Name(p.zone.n), p.x * 100, p.y * 100), 1, 1, 1)
	GameTooltip:AddLine(T("ARROW_TIP"), 0.6, 0.6, 0.6, true)
	GameTooltip:Show()
end

local function Build()
	arrow = CreateFrame("Frame", "ExplorersMapArrow", UIParent)
	arrow:SetSize(SIZE, SIZE)
	arrow:SetFrameStrata("MEDIUM")
	arrow:SetClampedToScreen(true)
	arrow:EnableMouse(true)
	arrow:SetMovable(true)
	arrow:RegisterForDrag("LeftButton")
	arrow:SetScript("OnDragStart", arrow.StartMoving)
	arrow:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, rel, x, y = self:GetPoint(1)
		ExplorersMapDB.arrowPos = { point, rel, x, y }
	end)
	arrow:SetScript("OnEnter", OnEnter)
	arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local at = ExplorersMapDB.arrowPos
	if type(at) == "table" and at[1] and at[2] and tonumber(at[3]) and tonumber(at[4]) then
		arrow:SetPoint(at[1], UIParent, at[2], at[3], at[4])
	else
		arrow:SetPoint("TOP", UIParent, "TOP", 0, -46)
	end
	-- (each stroke twice: a dark edge under the colour)
	arrow.edges, arrow.lines = {}, {}
	if arrow.CreateLine then
		for i = 1, #STROKES do
			arrow.edges[i] = arrow:CreateLine(nil, "BORDER")
			arrow.edges[i]:SetColorTexture(0, 0, 0, 0.85)
			arrow.edges[i]:SetThickness(10)
			arrow.lines[i] = arrow:CreateLine(nil, "ARTWORK")
			arrow.lines[i]:SetThickness(5.5)
		end
	end
	arrow.text = arrow:CreateFontString(nil, "OVERLAY")
	arrow.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
	arrow.text:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
	arrow:Hide()
end

-- the arrow turned `angle` (radians, anticlockwise from straight up), in a colour
local function Paint(angle, c)
	local cos, sin, half = math.cos(angle), math.sin(angle), SIZE / 2
	for i, s in ipairs(STROKES) do
		local x1, y1 = (s[1] * cos - s[2] * sin) * half, (s[1] * sin + s[2] * cos) * half
		local x2, y2 = (s[3] * cos - s[4] * sin) * half, (s[3] * sin + s[4] * cos) * half
		local edge, line = arrow.edges[i], arrow.lines[i]
		if line then
			edge:SetStartPoint("CENTER", arrow, x1, y1)
			edge:SetEndPoint("CENTER", arrow, x2, y2)
			line:SetStartPoint("CENTER", arrow, x1, y1)
			line:SetEndPoint("CENTER", arrow, x2, y2)
			line:SetColorTexture(c[1], c[2], c[3], 1)
		end
	end
	arrow.text:SetTextColor(c[1], c[2], c[3])
end

local function Draw()
	local p = target
	local px, py
	if p and home and not p.explored then px, py = PlayerOn(home) end
	if not px then
		arrow:Hide()
		return
	end
	local zone = p.zone
	-- (on a map, east is +x and north is -y; the game's facing turns anticlockwise from north)
	local east, north
	if zone == home then
		east, north = (p.x - px) * zone.width, (py - p.y) * zone.height
	else
		local here, there = Lie(home), Lie(zone)
		if not (here and there) then
			arrow:Hide()
			return
		end
		east = there.e0 + p.x * there.e1 - (here.e0 + px * here.e1)
		north = there.n0 + p.y * there.n1 - (here.n0 + py * here.n1)
	end
	local metres = math.sqrt(east * east + north * north) * METRES
	local facing = 0
	if type(GetPlayerFacing) == "function" then
		local ok, f = pcall(GetPlayerFacing)
		if ok and type(f) == "number" then facing = f end
	end
	Paint(math.atan2(-east, north) - facing, COLORS[(metres <= NEAR and 1) or (metres <= FAR and 2) or 3])
	if zone == home then
		arrow.text:SetText(T("ARROW_FMT"):format(ns.Name(p.n), metres))
	else
		arrow.text:SetText(T("ARROW_FMT_ZONE"):format(ns.Name(p.n), ns.Name(zone.n), metres))
	end
	arrow:Show()
end

local function Tick(_, elapsed)
	sinceTarget, sinceDraw = sinceTarget + elapsed, sinceDraw + elapsed
	if sinceTarget >= 0.5 then
		sinceTarget = 0
		local ok, p, zone = pcall(Nearest)
		target, home = ok and p or nil, ok and zone or nil
	end
	if sinceDraw >= 0.03 then
		sinceDraw = 0
		local ok, err = pcall(Draw)
		if not ok then
			arrow:Hide()
			if geterrorhandler then geterrorhandler()(err) end
		end
	end
end

-- shows the arrow, or not, as the settings say
function ns.RefreshArrow()
	local on = ExplorersMapDB.guideArrow and ns.ready and true or false
	if on and not arrow then Build() end
	if not driver then
		if not on then return end
		driver = CreateFrame("Frame")
		driver:SetScript("OnUpdate", Tick)
	end
	driver:SetShown(on)
	if not on and arrow then arrow:Hide() end
	sinceTarget, sinceDraw = 1, 1
end

function ns.SetArrow(on)
	ExplorersMapDB.guideArrow = on and true or false
	ns.Notify("settings")
end

ns.Listen(function(what)
	if what == "lang" or what == "level" then return end
	ns.RefreshArrow()
end)
