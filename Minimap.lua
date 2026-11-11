-- ExplorersMap: its button on the minimap. Left-click opens the window, right-click shows or
-- hides the map pins, dragging moves it round the minimap (ExplorersMapDB.angle).

local _, ns = ...
local T = ns.T

local button

local function Place()
	local angle = math.rad(ExplorersMapDB.angle or 215)
	local radius = Minimap:GetWidth() / 2 + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Tooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("|cff5cc8ffExplorers|rMap", 1, 1, 1)
	local r, g, b = ns.Color(ns.Percent())
	GameTooltip:AddDoubleLine(T("OVERALL"), ("%.1f%%"):format(ns.Percent() * 100), 1, 0.82, 0, r, g, b)
	GameTooltip:AddLine(T("AREAS_FMT"):format(ns.done, ns.total), 0.85, 0.85, 0.85)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(T("MM_LEFT"), 0.6, 0.6, 0.6)
	GameTooltip:AddLine(T("MM_RIGHT"), 0.6, 0.6, 0.6)
	GameTooltip:AddLine(T("MM_DRAG"), 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function Drag(self)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	if not (mx and my and px and py and scale and scale > 0) then return end
	ExplorersMapDB.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
	Place()
end

local function Build()
	button = CreateFrame("Button", "ExplorersMapMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetSize(20, 20)
	back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	back:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetPoint("TOPLEFT", 7, -6)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")
	button:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" then
			ns.SetPins(not ExplorersMapDB.pins)
			ns.Print(T(ExplorersMapDB.pins and "PINS_ON" or "PINS_OFF"))
		elseif ns.ToggleWindow then
			ns.ToggleWindow()
		end
		if GameTooltip:IsOwned(self) then Tooltip(self) end
	end)
	button:SetScript("OnEnter", Tooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", Drag) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	Place()
end

function ns.RefreshMinimapButton()
	if not button then
		if not Minimap then return end
		Build()
	end
	button:SetShown(ExplorersMapDB.minimap ~= false)
end

ns.Listen(function(what)
	if what == "login" then ns.RefreshMinimapButton() end
end)
