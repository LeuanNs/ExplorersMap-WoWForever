-- ExplorersMap: the window's Guide page. The zones that still have areas to find, sorted by
-- how they suit the character's level (ZoneInfo.lua): the ones to explore now, the ones that take
-- care, the ones to leave for later; then the hardest and slowest of all, with the reasons
-- (enemies above your level, the other faction's land, elites, many areas left).

local _, ns = ...
local T = ns.T
local UI = ns.UI

local ROWS, ROW_H = 17, 22
local TAGS = { "TAG_SAFE", "TAG_CARE" }

local function Enemy(info)
	local faction = ns.PlayerFaction()
	return info and faction and ((info[3] == "A" and faction == "Horde") or (info[3] == "H" and faction == "Alliance")) or false
end

-- how a zone suits the character: 1 explore it now, 2 with care (your level, or the other
-- faction's land), 3 leave it for later
local function Suits(zone)
	local risk = math.min(3, ns.Risk(zone))
	if risk == 1 and Enemy(ns.Info(zone)) then risk = 2 end
	return risk
end

-- why a zone is hard: lines for its tooltip
local function Reasons(zone)
	local info, level, out = ns.Info(zone), ns.PlayerLevel(), {}
	if info and info[3] == "S" then out[#out + 1] = T("WHY_SANCT") end
	if info and info[2] and info[2] > level then out[#out + 1] = T("WHY_MOBS"):format(info[2], level) end
	if Enemy(info) then out[#out + 1] = T("WHY_ENEMY") end
	if info and info[4] then out[#out + 1] = T("WHY_ELITE") end
	out[#out + 1] = T("WHY_MANY"):format(zone.total - zone.done)
	return out
end

-- how hard and slow a zone is to finish, for the last list
local function Score(zone)
	local info, level = ns.Info(zone), ns.PlayerLevel()
	local score = zone.total - zone.done
	if info then
		if info[2] then score = score + math.max(0, info[2] - level) * 1.5 end
		if info[2] and info[2] >= 55 then score = score + 4 end
		if info[4] then score = score + 6 end
		if Enemy(info) then score = score + 8 end
	end
	return score
end

local function Levels(zone)
	local info = ns.Info(zone)
	if info and info[1] then
		return info[1] == info[2] and tostring(info[1]) or ("%d-%d"):format(info[1], info[2])
	end
	return T("GUIDE_ANYLEVEL")
end

local function MakeRow(list)
	local row = CreateFrame("Button", nil, list)
	local hover = UI.Solid(row, "HIGHLIGHT", 1, 1, 1, 0.06)
	hover:SetAllPoints()
	row.rule = UI.Solid(row, "ARTWORK", 1, 1, 1, 0.1)
	row.rule:SetPoint("BOTTOMLEFT", 8, 2)
	row.rule:SetPoint("BOTTOMRIGHT", -8, 2)
	row.rule:SetHeight(1)
	row.dot = UI.Solid(row, "ARTWORK", 1, 1, 1, 1)
	row.dot:SetSize(8, 8)
	row.dot:SetPoint("LEFT", 12, 0)
	row.name = UI.Label(row, 12, 1, 1, 1)
	row.name:SetPoint("LEFT", 30, 0)
	row.name:SetWidth(300)
	row.levels = UI.Label(row, 11.5, 0.8, 0.8, 0.8)
	row.levels:SetPoint("LEFT", 340, 0)
	row.left = UI.Label(row, 11.5, 0.8, 0.8, 0.8)
	row.left:SetPoint("LEFT", 450, 0)
	row.tag = UI.Label(row, 11.5, 1, 1, 1)
	row.tag:SetPoint("RIGHT", -10, 0)
	row.tag:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self) if self.zone then ns.ShowOnMap(self.zone) end end)
	row:SetScript("OnEnter", function(self)
		local zone = self.zone
		if not zone then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(ns.Name(zone.n), 1, 0.82, 0)
		for _, line in ipairs(Reasons(zone)) do GameTooltip:AddLine(line, 1, 1, 1, true) end
		GameTooltip:AddLine(T("GUIDE_CLICK"), 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return row
end

local function PaintRow(row, item)
	local zone = item.zone
	row.zone = zone
	row.rule:SetShown(zone == nil)
	row.dot:SetShown(zone ~= nil)
	row.levels:SetShown(zone ~= nil)
	row.left:SetShown(zone ~= nil and not item.hard)
	row.tag:SetShown(zone ~= nil)
	row:EnableMouse(zone ~= nil)
	if not zone then
		row.name:SetPoint("LEFT", 8, 0)
		row.name:SetText(item.header)
		row.name:SetTextColor(1, 0.82, 0.25)
		return
	end
	local suits = Suits(zone)
	local c = ns.RISK_COLORS[math.max(suits, ns.Risk(zone))]
	local info = ns.Info(zone)
	row.name:SetPoint("LEFT", 30, 0)
	row.name:SetText(ns.Name(zone.n))
	row.name:SetTextColor(1, 1, 1)
	row.dot:SetVertexColor(c[1], c[2], c[3])
	row.levels:SetText(Levels(zone))
	row.left:SetText(T("GUIDE_LEFT"):format(zone.total - zone.done))
	local tag = TAGS[suits] and T(TAGS[suits])
		or T("TAG_DANGER"):format(math.max(1, (info and info[1] or 0) - ns.PlayerLevel()))
	if item.hard then tag = Reasons(zone)[1] end
	row.tag:SetText(tag)
	row.tag:SetTextColor(c[1], c[2], c[3])
end

local function Build(page)
	page.you = UI.Label(page, 13, 1, 1, 1)
	page.you:SetPoint("TOPLEFT", 20, -12)
	page.tip = UI.Label(page, 11, 0.55, 0.6, 0.66)
	page.tip:SetPoint("TOPRIGHT", -20, -14)
	page.tip:SetJustifyH("RIGHT")
	local panel = UI.Panel(page, 750, ROWS * ROW_H + 8)
	panel:SetPoint("TOPLEFT", 14, -38)
	page.list = UI.List(panel, 746, ROW_H, ROWS, MakeRow, PaintRow)
	page.list:SetPoint("TOPLEFT", 2, -4)
end

local function Refresh(page)
	local level = ns.PlayerLevel()
	local _, faction = ns.PlayerFaction()
	page.you:SetText(T("GUIDE_YOU"):format(level, faction or ""))
	page.tip:SetText(T("GUIDE_TIP"))
	local groups, all = { {}, {}, {} }, {}
	for _, zone in ipairs(ns.zones) do
		if zone.done < zone.total then
			local to = groups[Suits(zone)]
			to[#to + 1] = zone
			all[#all + 1] = zone
		end
	end
	local function Top(zone) local info = ns.Info(zone) return info and info[2] or 0 end
	local function Low(zone) local info = ns.Info(zone) return info and info[1] or 0 end
	-- the nearest your level first; the ones for later, the lowest first
	table.sort(groups[1], function(a, b) if Top(a) ~= Top(b) then return Top(a) > Top(b) end return ns.Name(a.n) < ns.Name(b.n) end)
	table.sort(groups[2], function(a, b) if Top(a) ~= Top(b) then return Top(a) < Top(b) end return ns.Name(a.n) < ns.Name(b.n) end)
	table.sort(groups[3], function(a, b) if Low(a) ~= Low(b) then return Low(a) < Low(b) end return ns.Name(a.n) < ns.Name(b.n) end)
	local items = {}
	for i, key in ipairs({ "GUIDE_BEST", "GUIDE_CARE", "GUIDE_LATER" }) do
		if #groups[i] > 0 then
			items[#items + 1] = { header = T(key):format(#groups[i]) }
			for _, zone in ipairs(groups[i]) do items[#items + 1] = { zone = zone } end
		end
	end
	if #all > 0 then
		local scores = {}
		for _, zone in ipairs(all) do scores[zone] = Score(zone) end
		table.sort(all, function(a, b)
			if scores[a] ~= scores[b] then return scores[a] > scores[b] end
			return ns.Name(a.n) < ns.Name(b.n)
		end)
		items[#items + 1] = { header = T("GUIDE_HARD") }
		for i = 1, math.min(8, #all) do items[#items + 1] = { zone = all[i], hard = true } end
	else
		items[#items + 1] = { header = T("GUIDE_ALLDONE") }
	end
	page.list:SetItems(items, true)
end

UI.AddPage({ key = "guide", label = "NAV_GUIDE", build = Build, refresh = Refresh })
