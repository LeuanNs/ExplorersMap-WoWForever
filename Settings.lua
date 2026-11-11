-- ExplorersMap: the window's Settings page. Language (every language the Languages folder
-- adds), the map pins (shown or not, only on zone maps, the minimap button, the chat lines),
-- their size, and their colours: one colour, by region, or by the zone's risk at your level.

local _, ns = ...
local T = ns.T
local UI = ns.UI

local MODES = { { "single", "COLOR_SINGLE" }, { "region", "COLOR_REGION" }, { "level", "COLOR_LEVEL" } }
local RISKS = { "LV_SAFE", "LV_OK", "LV_RISKY", "LV_DEADLY" }
local REGIONS = { "KALIMDOR", "EK", "ISLANDS" }

local function Hex(c)
	return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function Changed() ns.Notify("settings") end

-- a button of a group, one of them chosen (a gold line under it)
local function Choice(parent, width, onClick)
	local b = UI.TextButton(parent, width, 24, 11.5)
	b.line = UI.Solid(b, "OVERLAY", 1, 0.82, 0.25, 1)
	b.line:SetPoint("BOTTOMLEFT")
	b.line:SetPoint("BOTTOMRIGHT")
	b.line:SetHeight(2)
	function b:SetChosen(on)
		self.line:SetShown(on)
		self.text:SetTextColor(on and 1 or 0.75, on and 1 or 0.75, on and 1 or 0.75)
		self.back:SetColorTexture(1, 1, 1, on and 0.13 or 0.05)
	end
	b:SetScript("OnClick", onClick)
	return b
end

local function Heading(page, y)
	local fs = UI.Label(page, 13, 1, 0.82, 0.25)
	fs:SetPoint("TOPLEFT", 20, y)
	local rule = UI.Solid(page, "ARTWORK", 1, 1, 1, 0.08)
	rule:SetPoint("TOPLEFT", 20, y - 18)
	rule:SetPoint("TOPRIGHT", -20, y - 18)
	rule:SetHeight(1)
	return fs
end

local function Build(page)
	-- the language
	page.langHead = Heading(page, -14)
	page.langs = {}
	for i, code in ipairs(ns.languageOrder) do
		local b = Choice(page, 118, function(self)
			ExplorersMapDB.lang = self.code
			ns.Notify("lang")
		end)
		b.code = code
		b:SetPoint("TOPLEFT", 20 + ((i - 1) % 6) * 124, -42 - math.floor((i - 1) / 6) * 28)
		page.langs[i] = b
	end
	page.langHint = UI.Label(page, 11, 0.55, 0.6, 0.66)
	page.langHint:SetPoint("TOPLEFT", 20, -74 - math.floor((#ns.languageOrder - 1) / 6) * 28)

	-- the pins
	page.pinHead = Heading(page, -104)
	page.checks = {}
	local function Box(label, x, y, width, get, set)
		local c = UI.Check(page, width)
		c:SetPoint("TOPLEFT", x, y)
		c.label, c.get = label, get
		c.onToggle = function(on) set(on) Changed() end
		page.checks[#page.checks + 1] = c
	end
	Box("OPT_PINS", 20, -132, 450, function() return ExplorersMapDB.pins end, function(on) ns.SetPins(on) end)
	Box("OPT_ZONEONLY", 20, -156, 450, function() return ExplorersMapDB.zoneOnly end,
		function(on) ExplorersMapDB.zoneOnly = on end)
	Box("OPT_MINIMAP", 490, -132, 268, function() return ExplorersMapDB.minimap ~= false end, function(on)
		ExplorersMapDB.minimap = on
		if ns.RefreshMinimapButton then ns.RefreshMinimapButton() end
	end)
	Box("OPT_ANNOUNCE", 490, -156, 268, function() return ExplorersMapDB.announce end,
		function(on) ExplorersMapDB.announce = on end)

	-- their size
	page.sizeHead = Heading(page, -194)
	page.sizes = {}
	for i = 1, 3 do
		local b = Choice(page, 118, function(self)
			ExplorersMapDB.size = self.size
			Changed()
		end)
		b.size = i
		b:SetPoint("TOPLEFT", 20 + (i - 1) * 124, -222)
		page.sizes[i] = b
	end

	-- their colours
	page.colorHead = Heading(page, -264)
	page.modes = {}
	for i, mode in ipairs(MODES) do
		local b = Choice(page, 118, function(self)
			ExplorersMapDB.colorMode = self.mode
			Changed()
		end)
		b.mode, b.label = mode[1], mode[2]
		b:SetPoint("TOPLEFT", 20 + (i - 1) * 124, -292)
		page.modes[i] = b
	end
	page.swatches = {}
	for i, c in ipairs(ns.PALETTE) do
		local b = CreateFrame("Button", nil, page)
		b:SetSize(34, 34)
		b:SetPoint("TOPLEFT", 20 + (i - 1) * 42, -330)
		b.ring = UI.Solid(b, "BACKGROUND", 1, 0.82, 0.25, 1)
		b.ring:SetAllPoints()
		local back = UI.Solid(b, "BORDER", 0.045, 0.055, 0.075, 1)
		back:SetPoint("TOPLEFT", 2, -2)
		back:SetPoint("BOTTOMRIGHT", -2, 2)
		b.pin = b:CreateTexture(nil, "ARTWORK")
		b.pin:SetSize(26, 26)
		b.pin:SetPoint("CENTER")
		ns.PinLook(b.pin, c[1], c[2], c[3])
		local hover = UI.Solid(b, "HIGHLIGHT", 1, 1, 1, 0.12)
		hover:SetAllPoints()
		b.color = i
		b:SetScript("OnClick", function(self)
			ExplorersMapDB.color = self.color
			Changed()
		end)
		page.swatches[i] = b
	end
	page.legend = UI.Label(page, 12.5, 1, 1, 1)
	page.legend:SetPoint("TOPLEFT", 20, -340)
end

local function Refresh(page)
	local db = ExplorersMapDB
	page.langHead:SetText(T("SET_LANGUAGE"))
	page.langHint:SetText(T("SET_LANGUAGE_HINT"))
	for _, b in ipairs(page.langs) do
		b:SetLabel(ns.languages[b.code].name)
		b:SetChosen(ns.Lang() == b.code)
	end
	page.pinHead:SetText(T("SET_PINS"))
	for _, c in ipairs(page.checks) do
		c.text:SetText(T(c.label))
		c:SetOn(c.get())
	end
	page.sizeHead:SetText(T("SET_SIZE"))
	for i, b in ipairs(page.sizes) do
		b:SetLabel(T("SIZE_" .. i))
		b:SetChosen((db.size or 2) == i)
	end
	page.colorHead:SetText(T("SET_COLOR"))
	local mode = db.colorMode or "single"
	for _, b in ipairs(page.modes) do
		b:SetLabel(T(b.label))
		b:SetChosen(mode == b.mode)
	end
	for i, b in ipairs(page.swatches) do
		b:SetShown(mode == "single")
		b.ring:SetShown((db.color or 1) == i)
	end
	local parts = {}
	if mode == "region" then
		for i, key in ipairs(REGIONS) do parts[i] = ("|cff%s%s|r"):format(Hex(ns.REGION_COLORS[i]), T(key)) end
	elseif mode == "level" then
		for i, key in ipairs(RISKS) do parts[i] = ("|cff%s%s|r"):format(Hex(ns.RISK_COLORS[i]), T(key)) end
	end
	page.legend:SetText(table.concat(parts, "   ·   "))
end

UI.AddPage({ key = "settings", label = "NAV_SETTINGS", build = Build, refresh = Refresh })
