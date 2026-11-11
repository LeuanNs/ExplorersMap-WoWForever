import os, sys
# Run from anywhere: the inputs live in a work folder (EMAP_WORK, default "work" next to tools/),
# and Data.lua is written into the addon (the repository's root). See tools/README.md.
TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
os.chdir(os.environ.get("EMAP_WORK", os.path.join(ROOT, "work")))
import re,json,collections
lf={}
for l in open('dl/worldmap-listfile.csv',encoding='utf-8',errors='replace'):
    i,_,p=l.strip().partition(';')
    if p.endswith('.blp'): lf[i]=p
src=open('dl/openmap/OpenMap/Data/Forever/Reveal.lua',encoding='utf-8').read()
arts={}
for m in re.finditer(r'\[(\d+)\] = \{(.*?)\},\n',src):
    art=int(m.group(1)); ps=[]
    for k,v in re.findall(r'\["([\d:]+)"\] = "([^"]*)"',m.group(2)):
        w,h,x,y=map(int,k.split(':')); ids=[s.strip() for s in v.split(',')]
        names=[lf.get(i) for i in ids]
        ps.append(dict(key=k,w=w,h=h,x=x,y=y,ids=ids,tex=names))
    arts[art]=ps
json.dump(arts,open('reveal.json','w'))
tot=sum(len(p) for p in arts.values()); unk=0
for art,ps in sorted(arts.items()):
    dirs=collections.Counter((t.split('/')[2] if t else '?') for p in ps for t in p['tex'][:1])
    u=sum(1 for p in ps if not p['tex'][0]); unk+=u
    print(art,len(ps),dict(dirs),'UNK' if u else '')
print('arts',len(arts),'pieces',tot,'unknown',unk)
