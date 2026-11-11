import os, sys
# Run from anywhere: the inputs live in a work folder (EMAP_WORK, default "work" next to tools/),
# and Data.lua is written into the addon (the repository's root). See tools/README.md.
TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
os.chdir(os.environ.get("EMAP_WORK", os.path.join(ROOT, "work")))
import json,re,collections
d=json.load(open('matched.json')); a={int(k):v for k,v in d['a'].items()}; fn=d['fnames']; uimap=d['uimap']
def loc(path):
    s=open(path,encoding='utf-8').read(); out={}
    for m in re.finditer(r'^\t\["((?:[^"\\]|\\.)*)"\] = "((?:[^"\\]|\\.)*)",',s,re.M):
        out[m.group(1).replace('\\"','"')]=m.group(2).replace('\\"','"')
    return out
ES=loc('dl/lbsz/Locale/esES.lua'); MX=loc('dl/lbsz/Locale/esMX.lua')
FIX={('Elwynn Forest','stormwind'):'Stormwind City',('Tirisfal Glades','monastary'):'Scarlet Monastery',
     ('Stranglethorn Vale','thearena'):'Gurubashi Arena',("Shen'dralas",'buildings'):"Shen'dralas",
     ('Dustwallow Marsh','backbaywetlands'):'The Quagmire'}
KAL={'Durotar','Mulgore','The Barrens','Teldrassil','Darkshore','Ashenvale','Thousand Needles','Stonetalon Mountains','Desolace','Feralas','Dustwallow Marsh','Tanaris','Azshara','Felwood',"Un'Goro Crater",'Moonglade','Silithus','Winterspring','Mount Hyjal',"Shen'dralas"}
fam=collections.defaultdict(list)
for art,ps in a.items():
    for p in ps:
        if (p['zone'],p['base']) in FIX: p['name']=FIX[(p['zone'],p['base'])]
        assert p['name'],p
    fam[ps[0]['zone']].append(art)
print('Dustwallow',[(p['base'],p['key'],p['name']) for p in a[1253]])
names={}
def idx(n):
    if n not in names: names[n]=len(names)+1
    return names[n]
zones=[];tot=0
order=sorted(fam,key=lambda z:(0 if z in KAL else (2 if z=='Zephras Isle' else 1),z.replace('The ','')))
for z in order:
    if z=='Alterac Valley': continue
    arts=sorted(fam[z]); ent=[]
    if len(arts)==2:
        o,n=arts; used=set()
        for p in a[o]:
            m=[q for q in a[n] if q['name']==p['name'] and abs(q['x']-p['x'])<=3 and abs(q['y']-p['y'])<=3 and id(q) not in used]
            if m: used.add(id(m[0])); ent.append((p,''))
            else: ent.append((p,'o'))
        for q in a[n]:
            if id(q) not in used: ent.append((q,'n'))
    else:
        ent=[(p,'') for p in a[arts[0]]]
    # sanity: distinct offsets within each variant
    for var in ('o','n'):
        l=[p for p,f in ent if f in('',var)]
        for i in range(len(l)):
            for j in range(i+1,len(l)):
                if abs(l[i]['x']-l[j]['x'])<=7 and abs(l[i]['y']-l[j]['y'])<=7: print('CLOSE',z,var,l[i]['key'],l[i]['base'],l[j]['key'],l[j]['base'])
    ent.sort(key=lambda e:(e[0]['y']+e[0]['h']/2,e[0]['x']))
    s=';'.join('%d,%d,%d,%d,%d%s'%(p['x'],p['y'],p['w'],p['h'],idx(p['name']),(','+f) if f else '') for p,f in ent)
    maps=uimap[z]; c=1 if z in KAL else (3 if z=='Zephras Isle' else 2)
    zones.append((z,maps,c,arts,s,len([1 for _,f in ent if f in('','n')]),len([1 for _,f in ent if f in('','o')])))
    for _,f in ent: pass
zn={z:idx(z) for z,*_ in zones}
def q(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
miss=[n for n in names if n not in ES]
print('names',len(names),'missing ES',miss)
diffmx=[n for n in names if MX.get(n,ES.get(n))!=ES.get(n)]
print('MX differs',len(diffmx),[(n,ES.get(n),MX.get(n)) for n in diffmx][:12])
L=['-- ExplorersMap data: the pieces of map that exploring reveals, per zone. Generated; do not edit by hand.',
   '-- names[i] = "English|Español (esES)|Español (esMX)": later ones left out when they repeat the one before.',
   '-- zones[i] = { m = uiMapIDs, c = continent (1 Kalimdor, 2 Eastern Kingdoms, 3 islands), n = name index,',
   '--   a = uiMapArtIDs (classic art, WoW Forever art), p = "x,y,w,h,name[,o|n];..." on the 1002 x 668 map art',
   '--   (o: only on the first art, n: only on the second) }','','local _, ns = ...','','ns.Data = {','\tnames = {']
for n,i in sorted(names.items(),key=lambda kv:kv[1]):
    es=ES.get(n,n); mx=MX.get(n,es)
    L.append('\t\t'+q(n if (es==n and mx==n) else (n+'|'+es if mx==es else n+'|'+es+'|'+mx))+',')
L.append('\t},');L.append('\tzones = {')
for z,maps,c,arts,s,nn,no in zones:
    L.append('\t\t{ m = {%s}, c = %d, n = %d, a = {%s},\n\t\t\tp = %s },'%(', '.join(map(str,maps)),c,zn[z],', '.join(map(str,arts)),q(s)))
L.append('\t},');L.append('}');L.append('')
open(os.path.join(ROOT,'Data.lua'),'w',encoding='utf-8',newline='\n').write('\n'.join(L))
import os
print('zones',len(zones),'bytes',os.path.getsize(os.path.join(ROOT,'Data.lua')),'pieces new-art',sum(z[5] for z in zones),'old-art',sum(z[6] for z in zones))
for z in zones[:3]: print(z[0],z[1],z[3],z[5],z[6])
