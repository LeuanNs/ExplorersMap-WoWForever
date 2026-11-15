import os
HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
import sys,re,json
from lupa import lua51
L=lua51.LuaRuntime(unpack_returned_tuples=True)
L.execute(open(os.path.join(HERE,'mock.lua'),encoding='utf-8').read())
G=L.globals()
toc=[l.strip().replace('\\','/') for l in open(os.path.join(ADDON,'ExplorersMap.toc'),encoding='utf-8') if l.strip() and not l.startswith('#')]
load=L.eval('''function(src,name,ns) local f,err=loadstring(src,name) if not f then error(err,0) end return f("ExplorersMap",ns) end''')
ns=L.eval('{}')
# the maps this pretend client has: every zone's first map, with its WoW Forever art (the second)
def setup(variant):
    data=open(os.path.join(ADDON,'Data.lua'),encoding='utf-8').read()
    L.execute('MOCK.maps={} MOCK.arts={} MOCK.explored={}')
    for m in re.finditer(r'm = \{([^}]*)\}, c = (\d), n = (\d+), a = \{([^}]*)\}',data):
        maps=[int(x) for x in m.group(1).split(',')]; arts=[int(x) for x in m.group(4).split(',')]
        L.execute('MOCK.maps[%d]={mapType=3,name="z"} MOCK.arts[%d]=%d'%(maps[0],maps[0],arts[variant if len(arts)>1 else 0]))
    L.execute('MOCK.maps[1414]={mapType=2,name="Kalimdor"}')
setup(int(sys.argv[1]) if len(sys.argv)>1 else 1)
for f in toc:
    load(open(os.path.join(ADDON,f),encoding='utf-8').read(),'@'+f,ns)
print('loaded',toc)
fire=L.eval('''function(ns,ev,arg) for _,w in ipairs(MOCK.widgets) do local s=w._scripts.OnEvent if s and w._kind=="Frame" and not w._parent then s(w,ev,arg) end end end''')
fire(ns,'ADDON_LOADED','ExplorersMap'); fire(ns,'PLAYER_LOGIN'); fire(ns,'PLAYER_ENTERING_WORLD')
L.execute('MOCK.RunTimers()')
print('zones',len(ns.zones),'total',ns.total,'done',ns.done)
# Barrens on the Forever art: explore three pieces (one a pixel off, as the other art has it)
L.execute('MOCK.explored[1440]={ {offsetX=19,offsetY=28} }'); fire(ns,'MAP_EXPLORATION_UPDATED'); L.execute('MOCK.RunTimers()'); print('quiet at login:',len([1 for x in L.eval('MOCK.log').values() if str(x).startswith('chat')])); L.execute('MOCK.now=200 MOCK.explored[1413]={ {offsetX=340,offsetY=234,textureWidth=256,textureHeight=256}, {offsetX=431,offsetY=479}, {offsetX=556,offsetY=190} }'); fire(ns,'MAP_EXPLORATION_UPDATED'); L.execute('MOCK.RunTimers()')
print('after exploring: done',ns.done, [str(x) for x in L.eval('MOCK.log').values()][-3:])
toast=L.eval('''function() local out={} for _,w in ipairs(MOCK.widgets) do if w.title and w.sub and w.age then
  out[#out+1]=tostring(w.title._text).." / "..tostring(w.sub._text).." shown="..tostring(w._shown)
  for i=1,3 do w._scripts.OnUpdate(w,1.6) end out[#out+1]=tostring(w.title._text).." shown="..tostring(w._shown)
  for i=1,9 do if w._shown then w._scripts.OnUpdate(w,1.6) end end out[#out+1]="end shown="..tostring(w._shown) end end return table.concat(out," || ") end''')
print('toast',toast())
z=L.eval('function(ns) local z=ns.byMap[1413] return ns.Name(z.n), z.done, z.total end')(ns); print('barrens',z)
# window
L.execute('MOCK.maps[1454]={mapType=3,name="Orgrimmar",parentMapID=1411} C_Map.GetBestMapForUnit=function() return 1454 end'); ns.ToggleWindow(); ui=G.ExplorersMapFrame; print('opens on',L.eval('function(ns) local ui=ExplorersMapFrame local n=ns.Name(ui.zone.n) ui:ShowPage("guide") ui.tab=2 ui:Hide() C_Map.GetBestMapForUnit=function() return 1413 end ui:Show() return n, ns.Name(ui.zone.n), ui.page, ui.tab, ui.zoneList.offset end')(ns))
assert ui and ui.IsShown(ui), 'window not shown'
step=L.eval('''function(ns)
  local ui=ExplorersMapFrame
  ui._scripts.OnUpdate(ui,0.1) ui._scripts.OnUpdate(ui,5)
  for _,tab in ipairs(ui.tabs) do tab._scripts.OnClick(tab) end
  ui.tabs[1]._scripts.OnClick(ui.tabs[1])
  ui.sort._scripts.OnClick(ui.sort) ui.sort._scripts.OnClick(ui.sort) ui.sort._scripts.OnClick(ui.sort)
  local n=#ui.zoneList.items
  ui.zoneList._scripts.OnMouseWheel(ui.zoneList,-1) ui.zoneList._scripts.OnMouseWheel(ui.zoneList,1)
  local row=ui.zoneList.rows[2] row._scripts.OnClick(row)
  ui.zone=ns.byMap[1413] ui:RefreshAreas()
  local hdr, miss, found = ui.areaList.items[1].header, nil, nil
  ui.areaList:Scroll(99)
  for _,r in ipairs(ui.areaList.rows) do if r.piece and r.piece.explored then found=r end end
  found._scripts.OnEnter(found) found._scripts.OnClick(found)
  local selFound=ns.selected and ns.selected.explored and ns.Name(ns.selected.n)
  ui.areaList:Scroll(0)
  for _,r in ipairs(ui.areaList.rows) do if r.piece and not r.piece.explored then miss=r break end end
  miss._scripts.OnEnter(miss) miss._scripts.OnClick(miss)
  local sel=ns.selected and ns.Name(ns.selected.n)
  ui.open._scripts.OnClick(ui.open)
  -- the pages
  local navs={} for _,b in ipairs(ui.navs) do navs[#navs+1]=b.key b._scripts.OnClick(b) end
  local pages={} for _,p in ipairs(ns.UI.pages) do pages[p.key]=p.frame end
  local g=pages.guide ui:ShowPage("guide")
  local guide={} for i,it in ipairs(g.list.items) do guide[#guide+1]= it.header or (ns.Name(it.zone.n)..(it.hard and "!" or "")) end
  for _,r in ipairs(g.list.rows) do if r.zone then r._scripts.OnEnter(r) r._scripts.OnClick(r) break end end
  g.list:Scroll(99) for _,r in ipairs(g.list.rows) do if r.zone then r._scripts.OnEnter(r) end end
  local you, lasttag = g.you._text, g.list.rows[#g.list.rows].tag._text
  MOCK.level=60 ui:Refresh(true) local at60=g.list.items[1].header MOCK.level=23
  local s=pages.settings ui:ShowPage("settings")
  for _,c in ipairs(s.checks) do c._scripts.OnClick(c) c._scripts.OnClick(c) end
  for _,b in ipairs(s.sizes) do b._scripts.OnClick(b) end
  for _,b in ipairs(s.modes) do b._scripts.OnClick(b) end
  local legend={}
  for _,m in ipairs(s.modes) do m._scripts.OnClick(m) local n=0
    for _,chip in ipairs(s.chips) do if chip._shown then n=n+1 chip._scripts.OnClick(chip) for _,b in ipairs(s.colors) do b._scripts.OnClick(b) end end end
    legend[#legend+1]=ExplorersMapDB.colorMode..":"..n.." editing "..tostring(s.editing) end
  local r,g,b=ns.PinColor({explored=true}) legend[#legend+1]=("found custom %.2f"):format(r)
  for _,chip in ipairs(s.chips) do if chip._shown then chip._scripts.OnClick(chip) s.reset._scripts.OnClick(s.reset) end end
  for _,m in ipairs({s.modes[2],s.modes[3]}) do m._scripts.OnClick(m) for _,chip in ipairs(s.chips) do if chip._shown then chip._scripts.OnClick(chip) s.reset._scripts.OnClick(s.reset) end end end
  r,g,b=ns.PinColor({explored=true}) legend[#legend+1]=("found default %.2f"):format(r) legend[#legend+1]="custom left:"..(next(ExplorersMapDB.custom) and "some" or "none")
  legend=table.concat(legend," | ")
  s.modes[1]._scripts.OnClick(s.modes[1])
  local langs={} for _,b in ipairs(s.langs) do langs[#langs+1]=b._text b._scripts.OnClick(b) end
  local es=ns.Name(ns.byMap[1413].n) .. " / " .. ns.T("OVERALL") .. " / " .. ui.navs[1].text._text
  ui:ShowPage("progress")
  return n, hdr, selFound, sel, table.concat(navs,","), table.concat(guide," | "), you, lasttag, at60, legend, table.concat(langs,","), es, ExplorersMapDB.lang, ui.percent._text
end''')
for x in step(ns): print('  ui:',x)
# pins: zone map, continent map, then with a pretend OpenMap
pins=L.eval('''function(ns, stitched)
  if stitched then
    OpenMapAPI={ IsStitched=function() return true end, GetView=function() return 0.5,0.5,6 end,
      WorldFromMap=function(id,x,y) return 0.3+x*0.1,0.4+y*0.1 end, MapAt=function(u,v) return 1413 end, MapFromWorld=function(id,u,v) return u*2-0.3,v*2-0.5 end,
      ArtTopLevel=function() return 2400 end, ShowWorld=function() return true end }
  end
  local driver for _,w in ipairs(MOCK.widgets) do if w._parent==WorldMapFrame and w._scripts.OnUpdate then driver=w end end
  local count=function() local n=0 for _,w in ipairs(MOCK.widgets) do if w._kind=="Button" and w.piece and w._shown and w._parent and w._parent._parent==WorldMapFrame._canvas then n=n+1 end end return n end
  local out={}
  for _,id in ipairs({1413,1414,947}) do
    WorldMapFrame._mapID=id driver._scripts.OnShow(driver) driver._scripts.OnUpdate(driver,0.2)
    out[#out+1]=id..":"..count()
  end
  -- hover and click a pin
  WorldMapFrame._mapID=1413 driver._scripts.OnShow(driver) driver._scripts.OnUpdate(driver,0.2)
  for _,w in ipairs(MOCK.widgets) do if w._kind=="Button" and w.piece and w._shown and w._scripts.OnEnter and w._parent._parent==WorldMapFrame._canvas then
    w._scripts.OnEnter(w) w._scripts.OnClick(w) driver._scripts.OnUpdate(driver,0.2) w._scripts.OnClick(w) break end end
  ns.SetPins(false) driver._scripts.OnUpdate(driver,0.2) out[#out+1]="off:"..count()
  local found for _,p in ipairs(ns.byMap[1413].pieces) do if p.explored then found=p end end
  ns.Select(found) driver._scripts.OnUpdate(driver,0.2) out[#out+1]="off+found:"..count() ns.Select(nil) ns.SetPins(true)
  local db=ExplorersMapDB
  local show=function(label,ids) for _,id in ipairs(ids) do WorldMapFrame._mapID=id driver._scripts.OnShow(driver) driver._scripts.OnUpdate(driver,0.2) out[#out+1]=label.." "..id..":"..count() end end
  -- the character is in the Barrens (1413, Kalimdor); 1429 is Elwynn (Eastern Kingdoms)
  db.zoneOnly=true show("zoneOnly",{1413,1414,1429})
  C_Map.GetBestMapForUnit=function() return 1429 end ns.Notify("zone") driver._scripts.OnUpdate(driver,0.2) out[#out+1]="moved to elwynn:"..count()
  C_Map.GetBestMapForUnit=function() return 1413 end
  db.zoneOnly=false db.continentOnly=true show("continentOnly",{1413,1414,1429})
  db.continentOnly=false db.showFound=true show("showFound",{1413})
  local green=0 for _,w in ipairs(MOCK.widgets) do if w._kind=="Button" and w.piece and w._shown and w.piece.explored then green=green+1 end end out[#out+1]="found pins:"..green
  db.showFound=false db.hideDungeons=true
  IsInInstance=function() return 1,"party" end show("in dungeon",{1413})
  IsInInstance=function() return nil,"none" end show("outside",{1413})
  db.hideDungeons=false
  for _,mode in ipairs({"region","level","single"}) do ExplorersMapDB.colorMode=mode ns.Notify("settings") driver._scripts.OnUpdate(driver,0.2) end
  return table.concat(out," ")
end''')
print('pins blizzard',pins(ns,False)); print('pins openmap',pins(ns,True))
mm=L.eval('''function(ns) local b=ExplorersMapMinimapButton b._scripts.OnEnter(b) b._scripts.OnClick(b,"RightButton") b._scripts.OnClick(b,"LeftButton") b._scripts.OnDragStart(b) b._scripts.OnUpdate(b) b._scripts.OnDragStop(b)
  SlashCmdList.EXPLORERSMAP("pins") SlashCmdList.EXPLORERSMAP("help") SlashCmdList.EXPLORERSMAP("") SlashCmdList.EXPLORERSMAP("")
  return ExplorersMapDB.angle, ExplorersMapDB.lang, ns.T('MARGIN_SHORT') end''')
print('minimap',mm(ns))
print('tips',[str(x) for x in L.eval('MOCK.log').values() if str(x).startswith('tip')][:14])

# the guide arrow: the character at the middle of the Barrens, facing north
arrow=L.eval('''function(ns)
  C_Map.GetPlayerMapPosition=function(id,unit) return { GetXY=function() return 0.5,0.5 end } end
  GetPlayerFacing=function() return 0 end
  local out={}
  SlashCmdList.EXPLORERSMAP("arrow")
  local drv for _,w in ipairs(MOCK.widgets) do if w._kind=="Frame" and not w._parent and w._scripts.OnUpdate and not w._scripts.OnEvent and w~=ExplorersMapFrame then drv=w end end
  local a=ExplorersMapArrow
  drv._scripts.OnUpdate(drv,0.6)
  out[#out+1]="on="..tostring(ExplorersMapDB.guideArrow).." shown="..tostring(a._shown).." text="..tostring(a.text._text)
  a._scripts.OnEnter(a) a._scripts.OnDragStart(a) a._scripts.OnDragStop(a)
  -- a chosen area of this zone wins
  local far for _,p in ipairs(ns.byMap[1413].pieces) do if not p.explored and p.y>0.9 then far=p end end
  ns.Select(far) drv._scripts.OnUpdate(drv,0.6) out[#out+1]="chosen: "..tostring(a.text._text) ns.Select(nil)
  -- the zone all explored: on to another zone of the continent (here, by the zones' places on its map)
  local left={} for _,p in ipairs(ns.byMap[1413].pieces) do if not p.explored then left[#left+1]=p p.explored=true end end
  MOCK.maps[1413].parentMapID=1414 MOCK.maps[1440].parentMapID=1414 MOCK.maps[1429].parentMapID=1415 MOCK.maps[1415]={mapType=2,name="EK"}
  C_Map.GetMapRectOnMap=function(a,b) if a==1440 then return 0.5,0.7,0.1,0.3 end return 0.2,0.4,0.3,0.5 end
  for _,z in ipairs(ns.zones) do z.lie=nil end
  drv._scripts.OnUpdate(drv,0.6) out[#out+1]="zone done: "..tostring(a.text._text).." shown="..tostring(a._shown)
  local world=C_Map.GetWorldPosFromMapPos C_Map.GetWorldPosFromMapPos=function() return nil end
  for _,z in ipairs(ns.zones) do z.lie=nil end
  drv._scripts.OnUpdate(drv,0.6) out[#out+1]="by continent map: "..tostring(a.text._text).." shown="..tostring(a._shown)
  C_Map.GetWorldPosFromMapPos=world for _,z in ipairs(ns.zones) do z.lie=nil end
  for _,p in ipairs(left) do p.explored=false end
  -- nowhere known: hidden
  C_Map.GetPlayerMapPosition=function() return nil end drv._scripts.OnUpdate(drv,0.6) out[#out+1]="no position shown="..tostring(a._shown)
  SlashCmdList.EXPLORERSMAP("arrow") out[#out+1]="off shown="..tostring(a._shown).." driver="..tostring(drv._shown)
  return table.concat(out," | ")
end''')
print('arrow',arrow(ns))
