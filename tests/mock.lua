-- a permissive stand-in for the game's API, to run the addon's code outside the game
local log = {}
local widgets = {}
local function Widget(kind, name, parent)
	local w = { _kind = kind, _shown = true, _scripts = {}, _w = 100, _h = 100, _parent = parent, _children = {} }
	widgets[#widgets + 1] = w
	return setmetatable(w, { __index = function(t, k)
		if type(k) ~= "string" then return nil end
		if not k:match("^%u") then return nil end   -- (only methods: a field never set is nil, as in the game)
		local f
		if k == "CreateFrame" then return nil
		elseif k:match("^Create") then f = function(self, ...) return Widget(k, nil, self) end
		elseif k == "SetSize" then f = function(self, a, b) self._w, self._h = a, b end
		elseif k == "SetWidth" then f = function(self, a) assert(type(a) == "number", "SetWidth number") self._w = a end
		elseif k == "SetHeight" then f = function(self, a) assert(type(a) == "number", "SetHeight number") self._h = a end
		elseif k == "GetWidth" then f = function(self) return self._w end
		elseif k == "GetHeight" then f = function(self) return self._h end
		elseif k == "GetEffectiveScale" or k == "GetScale" then f = function() return 1 end
		elseif k == "GetFrameLevel" then f = function() return 3 end
		elseif k == "Show" then f = function(self) local was = self._shown self._shown = true if not was and self._scripts.OnShow then self._scripts.OnShow(self) end end
		elseif k == "Hide" then f = function(self) self._shown = false end
		elseif k == "SetShown" then f = function(self, on) if on then self:Show() else self:Hide() end end
		elseif k == "IsShown" or k == "IsVisible" then f = function(self) return self._shown end
		elseif k == "SetScript" then f = function(self, ev, fn) self._scripts[ev] = fn end
		elseif k == "GetScript" then f = function(self, ev) return self._scripts[ev] end
		elseif k == "SetText" or k == "SetLabel" then f = function(self, t) assert(t == nil or type(t) == "string" or type(t) == "number", "SetText wants text, got " .. type(t)) self._text = t end
		elseif k == "GetText" then f = function(self) return self._text or "" end
		elseif k == "GetPoint" then f = function() return "CENTER", nil, "CENTER", 0, 0 end
		elseif k == "GetCenter" then f = function() return 50, 50 end
		elseif k == "IsOwned" or k == "IsPlaying" then f = function() return false end
		elseif k == "GetMapID" then f = function(self) return self._mapID end
		elseif k == "SetMapID" then f = function(self, id) self._mapID = id end
		elseif k == "GetCanvas" then f = function(self) self._canvas = self._canvas or Widget("Canvas") return self._canvas end
		elseif k == "SetPoint" then f = function(self, point, ...) assert(type(point) == "string", "SetPoint point") for i = 1, select("#", ...) do local v = select(i, ...) assert(v ~= nil and v == v, "SetPoint nil/NaN arg") end end
		elseif k == "SetVertexColor" or k == "SetTextColor" or k == "SetColorTexture" then f = function(self, r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number", k .. " wants numbers") end
		elseif k == "AddLine" then f = function(self, t) assert(type(t) == "string", "AddLine text") log[#log + 1] = "tip: " .. t end
		elseif k == "AddDoubleLine" then f = function(self, a, b) assert(type(a) == "string" and type(b) == "string") end
		elseif k == "AddMessage" then f = function(self, t) log[#log + 1] = "chat: " .. t end
		else f = function() end end
		rawset(t, k, f)
		return f
	end })
end
MOCK = { log = log, widgets = widgets, timers = {}, explored = {}, arts = {}, maps = {}, Widget = Widget }
function CreateFrame(kind, name, parent) local w = Widget(kind, name, parent) if name then _G[name] = w end return w end
UIParent, Minimap, WorldMapFrame, GameTooltip = Widget("UIParent"), Widget("Minimap"), Widget("WorldMap"), Widget("Tooltip")
WorldMapFrame._shown = false
DEFAULT_CHAT_FRAME = Widget("Chat")
UISpecialFrames, SlashCmdList = {}, {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
MOCK.locale = "enUS"
function GetLocale() return MOCK.locale end
MOCK.now = 100
function GetTime() return MOCK.now end
MOCK.level, MOCK.faction = 23, "Alliance"
function UnitLevel() return MOCK.level end
function UnitFactionGroup() return MOCK.faction, MOCK.faction end
function GetCursorPosition() return 10, 20 end
function geterrorhandler() return function(err) error("ERRORHANDLER: " .. tostring(err), 0) end end
function ToggleWorldMap() WorldMapFrame:Show() end
function strsplit(sep, s) local out = {} for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end return unpack(out) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strlower, tinsert, tremove = string.lower, table.insert, table.remove
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
Enum = { UIMapType = { Continent = 2, Zone = 3 } }
C_Timer = { After = function(d, fn) MOCK.timers[#MOCK.timers + 1] = fn end }
C_Texture = { GetAtlasInfo = function(a) return MOCK.atlas and {} or nil end }
C_Map = {
	GetMapInfo = function(id) return MOCK.maps[id] end,
	GetMapArtID = function(id) return MOCK.arts[id] end,
	GetMapArtLayers = function(id) return { { layerWidth = 1002, layerHeight = 668 } } end,
	GetBestMapForUnit = function() return 1413 end,
	GetMapRectOnMap = function(a, b) return 0.2, 0.4, 0.3, 0.5 end,
}
function CreateVector2D(x, y) return { x = x, y = y } end
C_Map.GetWorldPosFromMapPos = function(id, v) return 1, { GetXY = function() return v.y * -3000, v.x * -5000 end } end
C_MapExplorationInfo = { GetExploredMapTextures = function(id) return MOCK.explored[id] end }
function MOCK.RunTimers() local t = MOCK.timers MOCK.timers = {} for _, fn in ipairs(t) do fn() end end
-- any other global the addon reads must be one it checks for: these are absent on purpose
local absent = { OpenMapAPI = true, ExplorersMapDB = true, ExplorersMap = true, issecretvalue = true }
setmetatable(_G, { __index = function(_, k) if absent[k] or k:match("^SLASH_") or k == "ExplorersMapFrame" or k == "ExplorersMapMinimapButton" then return nil end error("undefined global: " .. tostring(k), 2) end })
