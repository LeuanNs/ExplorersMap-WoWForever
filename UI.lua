-- ExplorersMap: its window. The world's progress on top, the zones on the left (by continent,
-- searched and sorted), the chosen zone's areas on the right: the ones still to discover first
-- (click one to see it on the map, circled), then the ones found. Built on first use.

local _, ns = ...
local T = ns.T

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local W, H = 780, 548
local LEFT_W, RIGHT_W = 322, 414
local ZONE_ROWS, ZONE_H = 10, 30
local AREA_ROWS, AREA_H = 13, 22
local TABS = { { 0, "ALL" }, { 1, "KALIMDOR" }, { 2, "EK" }, { 3, "ISLANDS" } }
local SORTS = { "SORT_NAME", "SORT_LEAST", "SORT_MOST" }
local LANGS = { auto = "LANG_AUTO", en = "LANG_EN", es = "LANG_ES" }
local NEXT_LANG = { auto = "en", en = "es", es = "auto" }

local ui
local moving = {}               -- bars gliding to their value

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

local function Outline(frame, r, g, b, a)
	local top = Solid(frame, "BORDER", r, g, b, a)
	top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(1)
	local bottom = Solid(frame, "BORDER", r, g, b, a)
	bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(1)
	local left = Solid(frame, "BORDER", r, g, b, a)
	left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(1)
	local right = Solid(frame, "BORDER", r, g, b, a)
	right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(1)
end

local function Label(parent, size, r, g, b, flags)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, size, flags or "")
	fs:SetTextColor(r or 1, g or 1, b or 1)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function Panel(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	Solid(f, "BACKGROUND", 1, 1, 1, 0.035):SetAllPoints()
	Outline(f, 1, 1, 1, 0.08)
	return f
end

-- a progress bar `width` wide: bar:Set(share [, at once]) glides to it, coloured by how far it is
local function Bar(parent, width, height)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	Solid(f, "BACKGROUND", 1, 1, 1, 0.08):SetAllPoints()
	f.fill = Solid(f, "ARTWORK", 1, 1, 1, 1)
	f.fill:SetPoint("TOPLEFT")
	f.fill:SetPoint("BOTTOMLEFT")
	f.shine = Solid(f, "OVERLAY", 1, 1, 1, 0.14)
	f.shine:SetPoint("TOPLEFT", f.fill, "TOPLEFT")
	f.shine:SetPoint("TOPRIGHT", f.fill, "TOPRIGHT")
	f.shine:SetHeight(math.max(1, height / 2))
	f.width, f.now, f.goal = width, 0, 0
	function f:Paint()
		local v = math.max(0, math.min(1, self.now))
		self.fill:SetWidth(math.max(0.5, self.width * v))
		self.fill:SetShown(v > 0.002)
		self.shine:SetShown(v > 0.002)
		self.fill:SetVertexColor(ns.Color(self.goal))
	end
	function f:Set(v, atOnce)
		self.goal = v
		if atOnce then
			self.now = v
			moving[self] = nil
		elseif self.now ~= v then
			moving[self] = true
		end
		self:Paint()
	end
	f:Paint()
	return f
end

local function Glide(_, elapsed)
	for bar in pairs(moving) do
		local gap = bar.goal - bar.now
		if math.abs(gap) < 0.002 then
			bar.now = bar.goal
			moving[bar] = nil
		else
			bar.now = bar.now + gap * math.min(1, elapsed * 7)
		end
		bar:Paint()
	end
end

-- a flat button with a text; button:SetLabel(text)
local function TextButton(parent, w, h, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.back = Solid(b, "BACKGROUND", 1, 1, 1, 0.06)
	b.back:SetAllPoints()
	Outline(b, 1, 1, 1, 0.1)
	local hover = Solid(b, "HIGHLIGHT", 1, 1, 1, 0.08)
	hover:SetAllPoints()
	b.text = Label(b, size or 12, 0.9, 0.9, 0.9)
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -8, 0)
	b.text:SetJustifyH("CENTER")
	function b:SetLabel(text) self.text:SetText(text) end
	return b
end

-- a tick box with a text; box:SetOn(bool), box.onToggle(bool)
local function Check(parent, w)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, 20)
	local box = CreateFrame("Frame", nil, b)
	box:SetSize(14, 14)
	box:SetPoint("LEFT", 0, 0)
	Solid(box, "BACKGROUND", 1, 1, 1, 0.07):SetAllPoints()
	Outline(box, 1, 0.82, 0.25, 0.7)
	b.mark = box:CreateTexture(nil, "ARTWORK")
	b.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	b.mark:SetPoint("CENTER")
	b.mark:SetSize(20, 20)
	b.text = Label(b, 12, 0.85, 0.85, 0.85)
	b.text:SetPoint("LEFT", box, "RIGHT", 7, 0)
	b.text:SetPoint("RIGHT", 0, 0)
	function b:SetOn(on) self.on = on and true or false self.mark:SetShown(self.on) end
	b:SetScript("OnClick", function(self)
		self:SetOn(not self.on)
		if self.onToggle then self.onToggle(self.on) end
	end)
	b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function(self) self.text:SetTextColor(0.85, 0.85, 0.85) end)
	return b
end

-- a list of `count` rows that the wheel scrolls: list:SetItems(items [, keep its place])
local function List(parent, width, rowH, count, make, paint)
	local l = CreateFrame("Frame", nil, parent)
	l:SetSize(width, rowH * count)
	l.rows, l.items, l.offset = {}, {}, 0
	for i = 1, count do
		local row = make(l)
		row:SetSize(width - 8, rowH)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
		l.rows[i] = row
	end
	l.track = Solid(l, "BACKGROUND", 1, 1, 1, 0.05)
	l.track:SetPoint("TOPRIGHT", -1, 0)
	l.track:SetPoint("BOTTOMRIGHT", -1, 0)
	l.track:SetWidth(3)
	l.thumb = Solid(l, "ARTWORK", 1, 0.82, 0.25, 0.7)
	l.thumb:SetWidth(3)
	function l:Paint()
		for i, row in ipairs(self.rows) do
			local item = self.items[i + self.offset]
			if item then
				paint(row, item)
				row:Show()
			else
				row:Hide()
			end
		end
		local n, height = #self.items, rowH * count
		if n > count then
			local size = math.max(16, height * count / n)
			self.thumb:ClearAllPoints()
			self.thumb:SetPoint("TOPRIGHT", -1, -(height - size) * self.offset / (n - count))
			self.thumb:SetHeight(size)
			self.thumb:Show()
			self.track:Show()
		else
			self.thumb:Hide()
			self.track:Hide()
		end
	end
	function l:Scroll(offset)
		self.offset = math.max(0, math.min(math.max(0, #self.items - count), offset))
		self:Paint()
	end
	function l:SetItems(items, keep)
		self.items = items
		self:Scroll(keep and self.offset or 0)
	end
	l:EnableMouseWheel(true)
	l:SetScript("OnMouseWheel", function(self, delta) self:Scroll(self.offset - delta * 2) end)
	return l
end

-- for the other pages (Settings.lua, Guide.lua): the pieces above, and a way to add a page over
-- the progress: ns.UI.AddPage({ key, label (a text's key), build = fn(frame), refresh = fn(frame) })
ns.UI = { Solid = Solid, Outline = Outline, Label = Label, Panel = Panel, Bar = Bar, TextButton = TextButton,
	Check = Check, List = List, pages = {} }
function ns.UI.AddPage(page) ns.UI.pages[#ns.UI.pages + 1] = page end

--------------------------------------------------------------------------------
-- The rows
--------------------------------------------------------------------------------

local function Share(zone) return zone.total > 0 and zone.done / zone.total or 0 end

local function MakeZoneRow(list)
	local row = CreateFrame("Button", nil, list)
	row.chosen = Solid(row, "BACKGROUND", 1, 0.82, 0.25, 0.13)
	row.chosen:SetAllPoints()
	row.edge = Solid(row, "ARTWORK", 1, 0.82, 0.25, 1)
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetWidth(2)
	local hover = Solid(row, "HIGHLIGHT", 1, 1, 1, 0.06)
	hover:SetAllPoints()
	row.name = Label(row, 12.5, 1, 1, 1)
	row.name:SetPoint("TOPLEFT", 10, -5)
	row.name:SetWidth(LEFT_W - 110)
	row.count = Label(row, 11, 0.8, 0.8, 0.8)
	row.count:SetPoint("TOPRIGHT", -6, -6)
	row.count:SetJustifyH("RIGHT")
	row.bar = Bar(row, LEFT_W - 24, 4)
	row.bar:SetPoint("BOTTOMLEFT", 10, 4)
	row:SetScript("OnClick", function(self)
		if not self.zone then return end
		ui.zone = self.zone
		ui.picked = true
		ui:RefreshZones(true)
		ui:RefreshAreas()
	end)
	return row
end

local function PaintZoneRow(row, zone)
	row.zone = zone
	local share = Share(zone)
	local on = ui.zone == zone
	row.chosen:SetShown(on)
	row.edge:SetShown(on)
	row.name:SetText(ns.Name(zone.n))
	local r, g, b = ns.Color(share)
	row.count:SetText(("%d/%d  |cffffffff%d%%|r"):format(zone.done, zone.total, math.floor(share * 100 + 0.5)))
	row.count:SetTextColor(r, g, b)
	row.bar:Set(share, true)
end

local function MakeAreaRow(list)
	local row = CreateFrame("Button", nil, list)
	row.chosen = Solid(row, "BACKGROUND", 0.45, 0.72, 1, 0.16)
	row.chosen:SetAllPoints()
	local hover = Solid(row, "HIGHLIGHT", 1, 1, 1, 0.06)
	hover:SetAllPoints()
	row.rule = Solid(row, "ARTWORK", 1, 1, 1, 0.1)
	row.rule:SetPoint("BOTTOMLEFT", 8, 2)
	row.rule:SetPoint("BOTTOMRIGHT", -8, 2)
	row.rule:SetHeight(1)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", 8, 0)
	row.name = Label(row, 12, 1, 1, 1)
	row.name:SetPoint("LEFT", 30, 0)
	row.name:SetWidth(RIGHT_W - 190)
	row.info = Label(row, 11, 0.8, 0.8, 0.8)
	row.info:SetPoint("RIGHT", -8, 0)
	row.info:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self)
		local p = self.piece
		if not p then return end
		if ns.selected == p then ns.Select(nil) else ns.ShowOnMap(p.zone, p) end
	end)
	row:SetScript("OnEnter", function(self)
		local p = self.piece
		if not p then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(ns.Name(p.n), 1, 0.82, 0)
		if p.explored then
			GameTooltip:AddLine(T("ROW_FOUND"), 0.4, 0.9, 0.5)
			GameTooltip:AddLine(T("ROW_CLICK"), 0.6, 0.6, 0.6)
		else
			GameTooltip:AddLine(("%.1f, %.1f  (%s)"):format(p.x * 100, p.y * 100, T("MARGIN_SHORT")), 1, 1, 1)
			GameTooltip:AddLine(T("MARGIN"), 0.45, 0.72, 1, true)
			GameTooltip:AddLine(T("ROW_CLICK"), 0.6, 0.6, 0.6)
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return row
end

local function PaintAreaRow(row, item)
	local p = item.piece
	row.piece = p
	row.rule:SetShown(item.header ~= nil)
	row.icon:SetShown(p ~= nil)
	row.info:SetShown(p ~= nil)
	row.chosen:SetShown(p ~= nil and ns.selected == p)
	row:EnableMouse(p ~= nil)
	if not p then
		row.name:SetPoint("LEFT", 8, 0)
		row.name:SetText(item.header)
		row.name:SetTextColor(1, 0.82, 0.25)
		return
	end
	row.name:SetPoint("LEFT", 30, 0)
	row.name:SetText(ns.Name(p.n))
	row.icon:SetTexCoord(0, 1, 0, 1)
	if p.explored then
		row.icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		row.icon:SetVertexColor(0.4, 0.95, 0.5)
		row.name:SetTextColor(0.55, 0.62, 0.55)
		row.info:SetText("")
	else
		ns.PinLook(row.icon)
		row.name:SetTextColor(1, 1, 1)
		row.info:SetText(("|cffffd040%.1f, %.1f|r  |cff73b8ff%s|r"):format(p.x * 100, p.y * 100, T("MARGIN_SHORT")))
	end
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function ByName(a, b) return ns.Name(a.n) < ns.Name(b.n) end

local function Build()
	ui = CreateFrame("Frame", "ExplorersMapFrame", UIParent)
	ui:SetSize(W, H)
	ui:SetFrameStrata("HIGH")
	ui:SetToplevel(true)
	ui:SetClampedToScreen(true)
	ui:EnableMouse(true)
	ui:SetMovable(true)
	ui:RegisterForDrag("LeftButton")
	ui:SetScript("OnDragStart", ui.StartMoving)
	ui:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, rel, x, y = self:GetPoint(1)
		ExplorersMapDB.window = { point, rel, x, y }
	end)
	local at = ExplorersMapDB.window
	if type(at) == "table" and at[1] then
		ui:SetPoint(at[1], UIParent, at[2] or at[1], at[3] or 0, at[4] or 0)
	else
		ui:SetPoint("CENTER")
	end
	tinsert(UISpecialFrames, "ExplorersMapFrame")
	ui.tab, ui.search = 0, ""

	Solid(ui, "BACKGROUND", 0.045, 0.055, 0.075, 0.97):SetAllPoints()
	Outline(ui, 1, 0.82, 0.25, 0.55)
	local head = Solid(ui, "BORDER", 0.1, 0.16, 0.24, 0.9)
	head:SetPoint("TOPLEFT", 1, -1)
	head:SetPoint("TOPRIGHT", -1, -1)
	head:SetHeight(56)
	local headRule = Solid(ui, "ARTWORK", 1, 0.82, 0.25, 0.45)
	headRule:SetPoint("TOPLEFT", 1, -57)
	headRule:SetPoint("TOPRIGHT", -1, -57)
	headRule:SetHeight(1)

	local icon = ui:CreateTexture(nil, "ARTWORK")
	icon:SetSize(36, 36)
	icon:SetPoint("TOPLEFT", 14, -10)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local title = Label(ui, 20, 1, 1, 1)
	title:SetPoint("TOPLEFT", 60, -10)
	title:SetText("|cff5cc8ffExplorers|rMap")
	ui.subtitle = Label(ui, 11.5, 0.7, 0.76, 0.84)
	ui.subtitle:SetPoint("TOPLEFT", 61, -35)

	local close = CreateFrame("Button", nil, ui)
	close:SetSize(26, 26)
	close:SetPoint("TOPRIGHT", -12, -15)
	local closeHover = Solid(close, "HIGHLIGHT", 1, 0.3, 0.3, 0.35)
	closeHover:SetAllPoints()
	local x = Label(close, 16, 0.9, 0.9, 0.9)
	x:SetPoint("CENTER", 0, 0)
	x:SetText("X")
	close:SetScript("OnClick", function() ui:Hide() end)

	-- the whole world's progress
	ui.percent = Label(ui, 34, 1, 1, 1)
	ui.percent:SetPoint("TOPLEFT", 16, -68)
	ui.overall = Label(ui, 12, 1, 0.82, 0.25)
	ui.overall:SetPoint("TOPLEFT", 150, -70)
	ui.counts = Label(ui, 11.5, 0.8, 0.8, 0.8)
	ui.counts:SetPoint("TOPRIGHT", -16, -70)
	ui.counts:SetJustifyH("RIGHT")
	ui.bar = Bar(ui, W - 166, 14)
	ui.bar:SetPoint("TOPLEFT", 150, -88)

	-- the continents
	ui.tabs = {}
	local tabW = (W - 28 - 3 * 6) / 4
	for i, def in ipairs(TABS) do
		local tab = TextButton(ui, tabW, 26, 12)
		tab:SetPoint("TOPLEFT", 14 + (i - 1) * (tabW + 6), -118)
		tab.key, tab.label = def[1], def[2]
		tab.line = Solid(tab, "OVERLAY", 1, 0.82, 0.25, 1)
		tab.line:SetPoint("BOTTOMLEFT")
		tab.line:SetPoint("BOTTOMRIGHT")
		tab.line:SetHeight(2)
		tab:SetScript("OnClick", function(self)
			ui.tab = self.key
			ui:RefreshZones()
		end)
		ui.tabs[i] = tab
	end

	-- the zones
	local left = Panel(ui, LEFT_W, H - 152 - 44)
	left:SetPoint("TOPLEFT", 14, -152)
	local search = CreateFrame("EditBox", nil, left)
	search:SetSize(LEFT_W - 16 - 150, 22)
	search:SetPoint("TOPLEFT", 8, -8)
	search:SetAutoFocus(false)
	search:SetFont(FONT, 12, "")
	search:SetTextColor(1, 1, 1)
	search:SetTextInsets(7, 7, 0, 0)
	search:SetMaxLetters(30)
	Solid(search, "BACKGROUND", 0, 0, 0, 0.35):SetAllPoints()
	Outline(search, 1, 1, 1, 0.12)
	ui.hint = Label(search, 11.5, 0.5, 0.5, 0.5)
	ui.hint:SetPoint("LEFT", 8, 0)
	search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	search:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		ui.hint:SetShown(text == "")
		ui.search = strlower(strtrim(text))
		ui:RefreshZones()
	end)
	ui.sort = TextButton(left, 144, 22, 11)
	ui.sort:SetPoint("TOPRIGHT", -8, -8)
	ui.sort:SetScript("OnClick", function()
		ExplorersMapDB.sort = (ExplorersMapDB.sort or 1) % #SORTS + 1
		ui:ApplyTexts()
		ui:RefreshZones()
	end)
	ui.zoneList = List(left, LEFT_W - 4, ZONE_H, ZONE_ROWS, MakeZoneRow, PaintZoneRow)
	ui.zoneList:SetPoint("TOPLEFT", 2, -38)
	ui.none = Label(left, 12, 0.6, 0.6, 0.6)
	ui.none:SetPoint("TOP", 0, -70)

	-- the chosen zone's areas
	local right = Panel(ui, RIGHT_W, H - 152 - 44)
	right:SetPoint("TOPLEFT", 14 + LEFT_W + 16, -152)
	ui.zoneName = Label(right, 16, 1, 1, 1)
	ui.zoneName:SetPoint("TOPLEFT", 10, -9)
	ui.zoneName:SetWidth(RIGHT_W - 170)
	ui.zoneCount = Label(right, 12, 0.85, 0.85, 0.85)
	ui.zoneCount:SetPoint("TOPLEFT", 10, -32)
	ui.zoneBar = Bar(right, RIGHT_W - 20, 6)
	ui.zoneBar:SetPoint("TOPLEFT", 10, -52)
	ui.open = TextButton(right, 148, 22, 11)
	ui.open:SetPoint("TOPRIGHT", -8, -8)
	ui.open:SetScript("OnClick", function()
		if ui.zone then ns.ShowOnMap(ui.zone) end
	end)
	ui.areaList = List(right, RIGHT_W - 4, AREA_H, AREA_ROWS, MakeAreaRow, PaintAreaRow)
	ui.areaList:SetPoint("TOPLEFT", 2, -64)

	-- the pages: this one (the progress) and the ones other files add over it (ns.UI.AddPage)
	ui.navs, ui.page = {}, "progress"
	local function Nav(key, label, index)
		local b = TextButton(ui, 100, 24, 11.5)
		b:SetPoint("TOPRIGHT", -50 - (index - 1) * 106, -16)
		b.key, b.label = key, label
		b.line = Solid(b, "OVERLAY", 1, 0.82, 0.25, 1)
		b.line:SetPoint("BOTTOMLEFT")
		b.line:SetPoint("BOTTOMRIGHT")
		b.line:SetHeight(2)
		b:SetScript("OnClick", function(self) ui:ShowPage(self.key) end)
		ui.navs[#ui.navs + 1] = b
	end
	local count = #ns.UI.pages
	Nav("progress", "NAV_PROGRESS", count + 1)
	for i, page in ipairs(ns.UI.pages) do Nav(page.key, page.label, count + 1 - i) end

	function ui:ShowPage(key)
		self.page = key
		for _, page in ipairs(ns.UI.pages) do
			if page.key == key and not page.frame then
				local f = CreateFrame("Frame", nil, self)
				f:SetPoint("TOPLEFT", 1, -112)
				f:SetPoint("BOTTOMRIGHT", -1, 1)
				f:SetFrameLevel(self:GetFrameLevel() + 30)
				f:EnableMouse(true)
				f:EnableMouseWheel(true)
				f:SetScript("OnMouseWheel", function() end)
				Solid(f, "BACKGROUND", 0.045, 0.055, 0.075, 1):SetAllPoints()
				page.frame = f
				local ok, err = pcall(page.build, f)
				if not ok and geterrorhandler then geterrorhandler()(err) end
			end
			if page.frame then page.frame:SetShown(page.key == key) end
		end
		self:Refresh(true)
	end

	function ui:ApplyTexts()
		self.subtitle:SetText(T("SUBTITLE"))
		self.overall:SetText(T("OVERALL"))
		self.hint:SetText(T("SEARCH"))
		self.sort:SetLabel(T(SORTS[ExplorersMapDB.sort or 1] or SORTS[1]))
		self.open:SetLabel(T("SHOW_ZONE"))
		for _, b in ipairs(self.navs) do
			local on = self.page == b.key
			b:SetLabel(T(b.label))
			b.line:SetShown(on)
			b.text:SetTextColor(on and 1 or 0.75, on and 1 or 0.75, on and 1 or 0.75)
		end
	end

	function ui:RefreshTop()
		local share = ns.Percent()
		self.percent:SetText(("%.1f%%"):format(share * 100))
		self.percent:SetTextColor(ns.Color(share))
		self.counts:SetText(("%s  ·  %s"):format(T("AREAS_FMT"):format(ns.done, ns.total), T("LEFT_FMT"):format(ns.total - ns.done)))
		self.bar:Set(share)
		for _, tab in ipairs(self.tabs) do
			local done, total = 0, 0
			for _, zone in ipairs(ns.zones) do
				if tab.key == 0 or zone.c == tab.key then done, total = done + zone.done, total + zone.total end
			end
			local on = self.tab == tab.key
			tab:SetLabel(("%s  |cff%s%d%%|r"):format(T(tab.label), on and "ffd040" or "9aa4b0",
				total > 0 and math.floor(done / total * 100 + 0.5) or 0))
			tab.line:SetShown(on)
			tab.text:SetTextColor(on and 1 or 0.75, on and 1 or 0.75, on and 1 or 0.75)
			tab.back:SetColorTexture(1, 1, 1, on and 0.12 or 0.05)
		end
	end

	function ui:RefreshZones(keep)
		self:RefreshTop()
		local items = {}
		for _, zone in ipairs(ns.zones) do
			if (self.tab == 0 or zone.c == self.tab)
				and (self.search == "" or strlower(ns.Name(zone.n)):find(self.search, 1, true)) then
				items[#items + 1] = zone
			end
		end
		local sort = ExplorersMapDB.sort or 1
		table.sort(items, function(a, b)
			local sa, sb = Share(a), Share(b)
			if sort == 2 and sa ~= sb then return sa < sb end
			if sort == 3 and sa ~= sb then return sa > sb end
			return ByName(a, b)
		end)
		self.none:SetText(#items == 0 and T("NO_RESULTS") or "")
		self.zoneList:SetItems(items, keep)
	end

	function ui:RefreshAreas(keep)
		local zone = self.zone
		self.open:SetShown(zone ~= nil)
		self.zoneBar:SetShown(zone ~= nil)
		if not zone then
			self.zoneName:SetText(T("NO_ZONE"))
			self.zoneCount:SetText("")
			self.areaList:SetItems({})
			return
		end
		local share = Share(zone)
		self.zoneName:SetText(ns.Name(zone.n))
		local r, g, b = ns.Color(share)
		self.zoneCount:SetText(share >= 1 and T("ZONE_DONE")
			or ("%d/%d  ·  %d%%"):format(zone.done, zone.total, math.floor(share * 100 + 0.5)))
		self.zoneCount:SetTextColor(r, g, b)
		self.zoneBar:Set(share)
		local missing, found = {}, {}
		for _, p in ipairs(zone.pieces) do
			local to = p.explored and found or missing
			to[#to + 1] = p
		end
		table.sort(missing, ByName)
		table.sort(found, ByName)
		local items = {}
		if #missing > 0 then
			items[#items + 1] = { header = T("MISSING_FMT"):format(#missing) }
			for _, p in ipairs(missing) do items[#items + 1] = { piece = p } end
		end
		if #found > 0 then
			items[#items + 1] = { header = T("FOUND_FMT"):format(#found) }
			for _, p in ipairs(found) do items[#items + 1] = { piece = p } end
		end
		self.areaList:SetItems(items, keep)
	end

	function ui:Refresh(keep)
		self:ApplyTexts()
		self:RefreshZones(keep)
		self:RefreshAreas(keep)
		for _, page in ipairs(ns.UI.pages) do
			if page.frame and page.frame:IsShown() and page.refresh then
				local ok, err = pcall(page.refresh, page.frame)
				if not ok and geterrorhandler then geterrorhandler()(err) end
			end
		end
	end

	ui:SetScript("OnUpdate", Glide)
	ui:SetScript("OnShow", function(self)
		-- it opens on the zone you're in, on the progress page
		local here = ns.CurrentZone()
		if here then
			self.zone = here
			if self.tab ~= 0 and self.tab ~= here.c then self.tab = 0 end
		end
		self.zone = self.zone or ns.zones[1]
		self.page = "progress"
		for _, page in ipairs(ns.UI.pages) do
			if page.frame then page.frame:Hide() end
		end
		self.bar:Set(0, true)
		self.zoneBar:Set(0, true)
		self:Refresh()
		for i, zone in ipairs(self.zoneList.items) do
			if zone == here then self.zoneList:Scroll(i - 4) break end
		end
		if self.fade then self.fade:Play() end
	end)
	if ui.CreateAnimationGroup then
		local group = ui:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		if fade.SetFromAlpha then
			fade:SetFromAlpha(0)
			fade:SetToAlpha(1)
			fade:SetDuration(0.18)
			ui.fade = group
		end
	end
	ui:Hide()
end

function ns.ToggleWindow()
	if not ui then
		local ok, err = pcall(Build)
		if not ok then
			if ui then ui:Hide() end
			ui = nil
			if geterrorhandler then geterrorhandler()(err) end
			return
		end
	end
	if ui:IsShown() then ui:Hide() else ui:Show() end
end

ns.Listen(function(what)
	if ui and ui:IsShown() then ui:Refresh(what ~= "lang") end
end)
