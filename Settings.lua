-- ExplorersMap: the window's Settings page. Language (every language the Languages folder
-- adds), the map pins (shown or not, only the zone or the continent the character is in, the
-- discovered ones too, hidden in dungeons, the minimap button, the announcements),
-- their size, and their colours: one colour, by region, or by the zone's risk at your level,
-- each of them (and the discovered areas') any colour of a palette.

local _, ns = ...
local T = ns.T
local UI = ns.UI

local MODES = { { "single", "COLOR_SINGLE" }, { "region", "COLOR_REGION" }, { "level", "COLOR_LEVEL" } }
-- the colours each mode has to choose ({ its key, its text }), the discovered areas' always last
local KEYS = {
	single = { { "single", "COLOR_PINS" } },
	region = { { "region1", "KALIMDOR" }, { "region2", "EK" }, { "region3", "ISLANDS" } },
	level = { { "risk1", "LV_SAFE" }, { "risk2", "LV_OK" }, { "risk3", "LV_RISKY" }, { "risk4", "LV_DEADLY" } },
}
local FOUND = { "found", "COLOR_FOUND" }
local CHIPS = 5
local COLORS = {
	{ 0.45, 0.72, 1 }, { 0.25, 0.5, 1 }, { 0.3, 0.9, 0.9 }, { 0.4, 0.9, 0.45 }, { 0.7, 1, 0.3 }, { 1, 0.95, 0.4 },
	{ 1, 0.82, 0.2 }, { 1, 0.6, 0.2 }, { 1, 0.3, 0.3 }, { 1, 0.5, 0.75 }, { 0.82, 0.55, 1 }, { 0.6, 0.4, 0.25 },
	{ 1, 1, 1 }, { 0.62, 0.62, 0.62 }, { 0.35, 0.35, 0.35 },
}

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
	Box("OPT_CONTINENT", 20, -180, 450, function() return ExplorersMapDB.continentOnly end,
		function(on) ExplorersMapDB.continentOnly = on end)
	Box("OPT_FOUND", 20, -204, 450, function() return ExplorersMapDB.showFound end,
		function(on) ExplorersMapDB.showFound = on end)
	Box("OPT_DUNGEONS", 490, -180, 268, function() return ExplorersMapDB.hideDungeons end,
		function(on) ExplorersMapDB.hideDungeons = on end)
	Box("OPT_MINIMAP", 490, -132, 268, function() return ExplorersMapDB.minimap ~= false end, function(on)
		ExplorersMapDB.minimap = on
		if ns.RefreshMinimapButton then ns.RefreshMinimapButton() end
	end)
	Box("OPT_ANNOUNCE", 490, -156, 268, function() return ExplorersMapDB.announce end,
		function(on) ExplorersMapDB.announce = on end)

	-- their size
	page.sizeHead = Heading(page, -242)
	page.sizes = {}
	for i = 1, 3 do
		local b = Choice(page, 118, function(self)
			ExplorersMapDB.size = self.size
			Changed()
		end)
		b.size = i
		b:SetPoint("TOPLEFT", 20 + (i - 1) * 124, -270)
		page.sizes[i] = b
	end

	-- their colours
	page.colorHead = Heading(page, -312)
	page.modes = {}
	for i, mode in ipairs(MODES) do
		local b = Choice(page, 118, function(self)
			ExplorersMapDB.colorMode = self.mode
			Changed()
		end)
		b.mode, b.label = mode[1], mode[2]
		b:SetPoint("TOPLEFT", 20 + (i - 1) * 124, -340)
		page.modes[i] = b
	end
	-- each colour of the mode chosen, and the discovered areas': click one, then a colour for it
	page.chips = {}
	for i = 1, CHIPS do
		local b = Choice(page, 140, function(self)
			page.editing = self.key
			Changed()
		end)
		b:SetPoint("TOPLEFT", 20 + (i - 1) * 146, -372)
		b.text:SetPoint("LEFT", 26, 0)
		b.swatch = UI.Solid(b, "ARTWORK", 1, 1, 1, 1)
		b.swatch:SetSize(12, 12)
		b.swatch:SetPoint("LEFT", 8, 0)
		page.chips[i] = b
	end
	page.colors = {}
	for i, c in ipairs(COLORS) do
		local b = CreateFrame("Button", nil, page)
		b:SetSize(22, 22)
		b:SetPoint("TOPLEFT", 20 + (i - 1) * 27, -404)
		b.ring = UI.Solid(b, "BACKGROUND", 1, 1, 1, 1)
		b.ring:SetAllPoints()
		local fill = UI.Solid(b, "ARTWORK", c[1], c[2], c[3], 1)
		fill:SetPoint("TOPLEFT", 2, -2)
		fill:SetPoint("BOTTOMRIGHT", -2, 2)
		local hover = UI.Solid(b, "HIGHLIGHT", 1, 1, 1, 0.25)
		hover:SetAllPoints()
		b.color = c
		b:SetScript("OnClick", function(self)
			if not page.editing then return end
			ExplorersMapDB.custom[page.editing] = { self.color[1], self.color[2], self.color[3] }
			Changed()
		end)
		page.colors[i] = b
	end
	page.reset = UI.TextButton(page, 110, 22, 11.5)
	page.reset:SetPoint("TOPLEFT", 20 + #COLORS * 27 + 8, -404)
	page.reset:SetScript("OnClick", function()
		if not page.editing then return end
		ExplorersMapDB.custom[page.editing] = nil
		Changed()
	end)
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
	local keys, n = KEYS[mode] or KEYS.single, 0
	local editing
	for i, b in ipairs(page.chips) do
		local entry = keys[i] or (i == #keys + 1 and FOUND) or nil
		b:SetShown(entry ~= nil)
		if entry then
			n = i
			b.key = entry[1]
			b:SetLabel(T(entry[2]))
			local c = ns.ColorOf(b.key)
			b.swatch:SetColorTexture(c[1], c[2], c[3], 1)
			if b.key == page.editing then editing = b end
		end
	end
	-- (the one being changed: the one clicked, or the mode's first)
	editing = editing or page.chips[1]
	page.editing = editing.key
	for i = 1, n do page.chips[i]:SetChosen(page.chips[i] == editing) end
	local now = ns.ColorOf(page.editing)
	for _, b in ipairs(page.colors) do
		local same = math.abs(b.color[1] - now[1]) + math.abs(b.color[2] - now[2]) + math.abs(b.color[3] - now[3]) < 0.02
		b.ring:SetColorTexture(1, same and 0.82 or 1, same and 0.25 or 1, same and 1 or 0.12)
	end
	page.reset:SetLabel(T("COLOR_RESET"))
end

UI.AddPage({ key = "settings", label = "NAV_SETTINGS", build = Build, refresh = Refresh })
