-- ExplorersMap: its languages. Each file in the Languages folder adds one by calling
-- ExplorersMap_Language({ code, name, texts = { KEY = "text", ... } [, areaNames = "es"] [, areas = { ... }] }).
-- English ("eng") is the default; the Settings page picks another (ExplorersMapDB.lang).
-- A text a language leaves out shows in English.

local _, ns = ...

ns.languages, ns.languageOrder = {}, {}

function ExplorersMap_Language(def)
	if type(def) ~= "table" or type(def.code) ~= "string" or type(def.texts) ~= "table" then return end
	if not ns.languages[def.code] then ns.languageOrder[#ns.languageOrder + 1] = def.code end
	def.name = type(def.name) == "string" and def.name or def.code
	ns.languages[def.code] = def
end

-- the code of the language in use
function ns.Lang()
	local code = ExplorersMapDB and ExplorersMapDB.lang
	return ns.languages[code] and code or "eng"
end

function ns.T(key)
	local lang = ns.languages[ns.Lang()]
	local text = lang and lang.texts[key]
	if type(text) ~= "string" then
		local english = ns.languages.eng
		text = english and english.texts[key]
	end
	return type(text) == "string" and text or key
end

-- a zone's or an area's name (ns.Data.names[i]) in the language in use: the language's own
-- (areas = { ["English name"] = "its name" }), the built-in Spanish (areaNames = "es"), or English
function ns.Name(i)
	local raw = ns.Data and ns.Data.names[i]
	if not raw then return "?" end
	local en, es, mx = strsplit("|", raw)
	local lang = ns.languages[ns.Lang()]
	if lang then
		local own = type(lang.areas) == "table" and lang.areas[en]
		if type(own) == "string" then return own end
		if lang.areaNames == "es" then
			if mx and GetLocale and GetLocale() == "esMX" then return mx end
			return es or en
		end
	end
	return en
end
