# River decorations: foam and small waves

Checked by reading the code of both executables (Stronghold Crusader.exe and
Stronghold_Crusader_Extreme.exe, same code in both; addresses below are the vanilla ones). Not yet
confirmed in game.

## In short

Both Stronghold decorations are still in Crusader; their menu buttons are gone, and one editor step
added for Crusader's land types gets in their way (see below):

| Decoration | Placement id | Decoration value | What setTerrain does |
|---|---|---|---|
| Foam | 150 (`M_MAPPER_FOAM`) | 0x10 (16) | river terrain, decoration byte 0x10, on every river tile under the brush |
| Small waves | 151 (`M_MAPPER_RIPPLE`) | 0x20 (32) | river terrain, decoration byte 0x20, brush forced to 1 tile, animation word set |

The values are the ones from Stronghold 1 (16 and 32).

## How they are placed

The landscape editor's click handler (`MenuItemActionHandler_MapEditorLandscaping_QueueCommandCallback`)
sends river (14), foam (150) and small waves (151) through the same branch (VAN `0x443F39`): command
0x15 (`ClickSetTerrain`) with terrain flag `0x100000` (river) and a fifth parameter that is 0 for
river, 0x10 for foam and 0x20 for small waves; small waves also get brush size 1.

`TileMapState::setTerrain(player, tile, y, brush, terrain, decoration)` (VAN `0x512940`) then, for
river terrain:

- writes the decoration value into the tile's byte in the **Logic2 layer** (`TileMapState + 0x1B3FE0`,
  VAN `0x1C471E8`, one byte per tile);
- for small waves (0x20) also writes the tile's animation word (`TileMapState + 0xEF500`, VAN
  `0x1B82708`, two bytes per tile): `(match time & 8) + (old word << 5) + ((direction & 7) << 10)`,
  where the direction is the tile's word in `TileMapState + 0x13DD40` (VAN `0x1BD0F48`). For the other
  values it copies that direction into the animation word.

So the waves' direction comes from the direction the game already stores for the tile, not from
the direction the mouse is dragged in as in Stronghold 1.

Only river tiles take a decoration: for a decoration other than 0, a tile that is not already river
(`0x100000`) is skipped (VAN `0x512CF1`).

**The catch in Crusader**: in the map editor, before its tile loop, setTerrain first lays the whole
brush area as land when the decoration is one of Crusader's land types - 2, 0x10, 0x20, 0x40, 1,
0x80 (VAN `0x512995`, a call to `setLand`). 0x10 and 0x20 are on that list, so foam and small waves
first turn the river into plain ground, and then find no river tile to decorate. In game, foam left
plain ground and small waves gave a pond. The module skips that step for river terrain.

## How they are stored in the map

The map file's sections are listed in the game's section table (VAN `0xB92A94`, entries of 16 bytes:
section number << 16 | flag, address, 0, size):

| Layer | Section | Flag | Size | Contents |
|---|---|---|---|---|
| Logic2 layer (`0x1C471E8`) | 1003 | 1 | 80,400 bytes (one per tile) | the **decoration byte** |
| direction words (`0x1BD0F48`) | 1007 | 1 | 160,800 bytes (two per tile) | the tile's direction (`& 7`) |
| animation words (`0x1B82708`) | 1008 | 0 | 160,800 bytes | the waves' current picture |

Section 1003 is saved like the other map layers, so the decoration byte of every tile is in the map
file: 0x10 for foam, 0x20 for small waves on river tiles (flag `0x100000` in the tile flags). The
same byte holds other things on other ground: 0x01 thin scrub, 0x10 oasis grass, 0x80 thick scrub;
on a river tile 0x10 means foam. Section 1008 has flag 0 where the others have 1; whether that keeps
it out of map files was not checked - the animation word is worked out again from the direction and
the time anyway.

## What reads them

- `collectCliffEdgeTilesForClimbData` (VAN `0x4FC340`, misnamed) collects river tiles with 0x10 into
  the list of up to 1000 tiles that the waterfall foam and spray come from (`TileMapState + 0x55292C`,
  count `+0x55291C`). Foam placed by hand is the same thing the game puts below waterfalls.
- `computeTileCliffEdgeFlags` (VAN `0x4FC0B0`) works the byte out again for cliff edges with
  `and byte [...], 0x38`, which keeps 0x10 and 0x20.
- `updateLogicalTileMapRelatedSections` (VAN `0x4F70F0`) tests 0x20 on river tiles.
- `UpgradeMapLogicToVersion_145` (VAN `0x5016D0`) tests 0x20 when upgrading old maps.

## What the module does

It adds two buttons to the water menu - copies of the river button with placement ids 150 and 151
and the menu pictures that are still in the image table (entries 286 and 287, `mapedit_buttons.gm1`
pictures 154 and 145) - and skips the land step above for river terrain. Placing and drawing are
otherwise the game's own.
