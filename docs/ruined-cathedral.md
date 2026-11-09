# The ruined cathedral

Checked by reading the code of both executables (Stronghold Crusader.exe and
Stronghold_Crusader_Extreme.exe, same code in both; addresses below are the vanilla ones). Not
tried in game.

## What switches a cathedral to its ruined picture

`UpdateCathedral` (VAN `0x4177E0`) runs for every cathedral on every tick. After the usual work
(targetable buildings, building registry, its flag) it does this:

```
if GameMode2 == 0                        ; a game, not the map editor
   and [0x1FE7D50] == 7                  ; the historical mission being played
   and health <= maxHealth * 3 / 10      ; at or below 30 % (the code: maxHealth * 3 * 0x66666667 >> 34)
then
   if building.flag_0x2DA == 0 or building.picture != 0x11F:
       building.flag_0x2DA = 1
       building.picture    = 0x11F        ; building +0x00, the first picture of its sprite
       updateBuildingGraphicsLayer(building)
else
   building.flag_0x2DA = 0                ; the picture is not changed back
```

`[0x1FE7D50]` is the historical mission number: the campaign and mission select menus set it,
and it is a map section of its own (section 1047), so a mission's map file carries it. Mission
7 is Saladin's campaign, mission 2 ("Kerak", `crusaders_mission2b.map`). Picture `0x11F` is the
last picture of `tile_churches.gm1`, the ruined cathedral.

So the switch itself is **hardcoded to that one mission**: any other map (number 0 or another
mission) never ruins its cathedral, however badly damaged.

## Can a ruined cathedral be placed in the map editor?

Yes, without changing anything the game does in a match. The ruined look is only the building's
picture field (`+0x00`) and the flag at `+0x2DA`, both part of the building record, which the
map file saves with the other buildings. A map editor feature could place a normal cathedral
and then set:

- picture `+0x00` = `0x11F`,
- flag `+0x2DA` = 1,
- and call `updateBuildingGraphicsLayer` (VAN `0x506370`, on the tile map) to redraw its tiles.

In a match on such a map, `UpdateCathedral` leaves the picture alone (the map is not mission
7, or, on mission 7, it only ever sets the ruined picture and never back). It stays a working
cathedral with full health that just looks ruined. Not yet checked: whether any other code
(capture, repair, fire, the building's damage pictures) rewrites the picture field of a
cathedral.

## What the module does

Since 1.0.41: while the cathedral is chosen, a "Ruined" choice above the town menu. A cathedral
placed with it gets picture `0x11F` and the flag, then `updateBuildingGraphicsLayer`. The new
building is found through `TileMapState + 0x554888` (the last placed building), checked every
frame; ClickPlaceBuilding's call to `placeBuilding` is not hooked, because the
interface-visual-fixes module checks that call and its return address.
