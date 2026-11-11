# Building Data.lua

`Data.lua` lists every area that exploring reveals: where it sits on its zone's map art and its
name in English and Spanish. These scripts build it from public sources. You only need them to
regenerate the data (after a game patch, say); the addon itself doesn't use them.

## Inputs

Make a work folder (`work/` next to `tools/`, or any folder named by `EMAP_WORK`) holding, under `dl/`:

| Path in `work/dl/` | Source |
|---|---|
| `openmap/` | `git clone https://github.com/openmap-world/openmap` (its `OpenMap/Data/Forever/Reveal.lua`: the map pieces) |
| `lbsz/` | `git clone https://github.com/arithmandar/LibBabble-SubZone-3.0 lbsz` (area names, area IDs, Spanish) |
| `worldmap-listfile.csv` | the lines of [wowdev/wow-listfile](https://github.com/wowdev/wow-listfile)'s `community-listfile.csv` containing `;interface/worldmap/` |
| `vdb_x/world_full_14_june_2021.sql` | the vanilla world database dump from `brotalnia/database` (`world_full_14_june_2021.7z`, extracted): which zone each area belongs to |

## Steps

```
python tools/parse.py     # map pieces + their texture names       -> work/reveal.json
python tools/areas.py     # area IDs and the zone each one is in   -> work/areas.json
python tools/match.py     # texture names matched to area names    -> work/matched.json
python tools/gen.py       # the addon's data                       -> Data.lua
```

`match.py` prints the pieces it matched only approximately or not at all; `gen.py` holds a short
list of hand fixes (`FIX`) for those. Check its output before committing a new `Data.lua`.
