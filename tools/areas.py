import os, sys
# Run from anywhere: the inputs live in a work folder (EMAP_WORK, default "work" next to tools/),
# and Data.lua is written into the addon (the repository's root). See tools/README.md.
TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
os.chdir(os.environ.get("EMAP_WORK", os.path.join(ROOT, "work")))
import re,json
F='dl/vdb_x/world_full_14_june_2021.sql'
def rows(table):
    out=[];on=False
    for l in open(F,encoding='utf-8',errors='replace'):
        if l.startswith('INSERT INTO `%s`'%table): on=True; continue
        if on:
            s=l.strip()
            if not s.startswith('('): on=False; continue
            out.append(s.rstrip(',;'))
    return out
def parse(row):
    vals=[];cur='';q=False;i=1
    s=row[1:-1]; i=0
    while i<len(s):
        c=s[i]
        if q:
            if c=='\\': cur+=s[i+1]; i+=2; continue
            if c=="'":
                if i+1<len(s) and s[i+1]=="'": cur+="'"; i+=2; continue
                q=False
            else: cur+=c
        else:
            if c=="'": q=True
            elif c==',': vals.append(cur.strip()); cur=''
            else: cur+=c
        i+=1
    vals.append(cur.strip()); return vals
areas={}
for r in rows('area_template'):
    v=parse(r); areas[int(v[0])]=dict(id=int(v[0]),map=int(v[1]),zone=int(v[2]),name=v[6])
loc={}
for r in rows('locales_area'):
    v=parse(r); loc[int(v[0])]=v[1:]
for i,a in areas.items():
    l=loc.get(i); a['es']=(l[5] if l and l[5] not in('','NULL') else None); a['mx']=(l[6] if l and l[6] not in('','NULL') else None)
json.dump(areas,open('areas.json','w'))
print(len(areas),len(loc)); print(areas[17],areas[392],areas.get(380)); print(loc.get(17))
print(sum(1 for a in areas.values() if a['es']))
