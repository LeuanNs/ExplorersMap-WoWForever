import os, sys
# Run from anywhere: the inputs live in a work folder (EMAP_WORK, default "work" next to tools/),
# and Data.lua is written into the addon (the repository's root). See tools/README.md.
TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
os.chdir(os.environ.get("EMAP_WORK", os.path.join(ROOT, "work")))
import json,re,difflib,collections
a={int(k):v for k,v in json.load(open('reveal.json')).items()}
areas={int(k):v for k,v in json.load(open('areas.json')).items()}
# forever names -> ids
src=open('dl/lbsz/Data/LocalizedNameIndexes_ClassicForever.lua',encoding='utf-8').read()
blk=src[src.index('MapData.AreaNameToIDs'):src.index('MapData.UiMapNameToIDs')]
fnames={}
for m in re.finditer(r'\["((?:[^"\\]|\\.)*)"\] = \{([^}]*)\}',blk):
    fnames[m.group(1).replace('\\"','"')]=[int(x) for x in m.group(2).split(',') if x.strip()]
ub=src[src.index('MapData.UiMapNameToIDs'):]
uimap={m.group(1):[int(x) for x in m.group(2).split(',')] for m in re.finditer(r'\["([^"]*)"\] = \{([^}]*)\}',ub)}
ZONE={'durotar':'Durotar','mulgore':'Mulgore','barrens':'The Barrens','alterac':'Alterac Mountains','arathi':'Arathi Highlands','badlands':'Badlands','blastedlands':'Blasted Lands','tirisfal':'Tirisfal Glades','silverpine':'Silverpine Forest','westernplaguelands':'Western Plaguelands','easternplaguelands':'Eastern Plaguelands','hilsbrad':'Hillsbrad Foothills','hillsbrad':'Hillsbrad Foothills','hinterlands':'The Hinterlands','dunmorogh':'Dun Morogh','searinggorge':'Searing Gorge','burningsteppes':'Burning Steppes','elwynn':'Elwynn Forest','deadwindpass':'Deadwind Pass','duskwood':'Duskwood','lochmodan':'Loch Modan','stranglethorn':'Stranglethorn Vale','swampofsorrows':'Swamp of Sorrows','westfall':'Westfall','wetlands':'Wetlands','teldrassil':'Teldrassil','darkshore':'Darkshore','ashenvale':'Ashenvale','thousandneedles':'Thousand Needles','stonetalonmountains':'Stonetalon Mountains','stonetalonmountain':'Stonetalon Mountains','desolace':'Desolace','feralas':'Feralas','dustwallow':'Dustwallow Marsh','dustwallowmarsh':'Dustwallow Marsh','tanaris':'Tanaris','aszhara':'Azshara','azshara':'Azshara','felwood':'Felwood','ungorocrater':"Un'Goro Crater",'moonglade':'Moonglade','silithus':'Silithus','winterspring':'Winterspring','alteracvalley':'Alterac Valley','hyjal':'Mount Hyjal','zephrasisle':'Zephras Isle','riverlands':'Riverglades','redridge':'Redridge Mountains','shendralas':"Shen'dralas"}
norm=lambda s: re.sub(r'[^a-z0-9]','',s.lower())
zid={v['name']:k for k,v in areas.items() if v['zone']==0}
def cands(zone):
    z=zid.get(zone)
    inz={v['name'] for v in areas.values() if z and (v['zone']==z or v['id']==z)}
    return inz
allf={n for n in fnames if 'UNUSED' not in n and not n.startswith('*')}
newf={n for n,ids in fnames.items() if min(ids)>15000}
res={};unm=[]
for art,ps in sorted(a.items()):
    d=ps[0]['tex'][0].split('/')[2]; zone=ZONE[d.replace('_c60','')]
    inz=cands(zone)
    for p in ps:
        base=re.sub(r'\d+\.blp$','',p['tex'][0].split('/')[-1])
        p['base']=base;p['zone']=zone
        pools=[('zone',inz&allf|inz),('new',newf),('all',allf)]
        hit=None
        for tag,pool in pools:
            nm={norm(n):n for n in pool}
            for k in (base,'the'+base,re.sub('^the','',base)):
                if k in nm: hit=(nm[k],tag,'exact'); break
            if hit: break
        if not hit:
            nm={norm(n):n for n in (inz|newf)}
            c=difflib.get_close_matches(base,list(nm),1,0.72)
            if c: hit=(nm[c[0]],'fuzzy','%.2f'%difflib.SequenceMatcher(None,base,c[0]).ratio())
        p['name']=hit[0] if hit else None; p['how']=hit[1:] if hit else None
        if not hit: unm.append((art,zone,base,p['key']))
json.dump(dict(a=a,fnames=fnames,uimap=uimap),open('matched.json','w'))
tot=sum(len(v) for v in a.values())
print('total',tot,'unmatched',len(unm))
fz=[(art,p['zone'],p['base'],p['name'],p['how'][1]) for art,ps in a.items() for p in ps if p['how'] and p['how'][0]=='fuzzy']
print('fuzzy',len(fz))
seen=set()
for x in fz:
    k=(x[1],x[2])
    if k not in seen: seen.add(k); print('FZ',x[1],'|',x[2],'->',x[3],x[4])
seen=set()
for x in unm:
    k=(x[1],x[2])
    if k not in seen: seen.add(k); print('UN',x[0],x[1],'|',x[2],x[3])
gl=[(p['zone'],p['base'],p['name']) for ps in a.values() for p in ps if p['how'] and p['how'][0] in('all',) ]
for x in sorted(set(gl)): print('GLOBAL',x)
