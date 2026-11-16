# AI players with several keeps: no rotation, no AIV

Request 34.4: on a skirmish map where an AI player has more than one keep, the AI's keep is not
turned towards the map centre at the start of a match and no AIV is used. This note says why.
Addresses are for the vanilla 1.41 exe (`Stronghold Crusader.exe`); Extreme has the same code.

## Short answer

Nothing is wrong in the map data. The problem is in the match-start code, which assumes one
keep per player:

1. It reads only the player's **active keep**, records where that keep stood, and removes it
   together with its own parts.
2. The player's **other keeps stay on the map**, with their doors, campfires and stockpiles.
3. The AI's castle plan (AIV) is then test-fitted around the recorded spot, and it has to find
   its tiles free. The leftover keeps occupy them, so **no AIV fits**.
4. Without a fitting AIV the game falls back to placing a **plain keep at the recorded spot with
   a fixed orientation**, which means no rotation and no castle plan for the rest of the match.

So both symptoms have one cause: the AI's extra keeps block the AIV fit.

## The match start in detail (`LaunchSkirmishGame`, VAN `0x441270`)

**Recording and removing the active keep** (`0x441B0D` .. `0x441B76`), for each player 1..8:

- `keep = playerData[p].keep.id` (PlayerData `+0x94`, the active keep the map editor's crests
  now show).
- If set, its corner `x`/`y` go into a local start-position table, and then
  `destroyBuildingAndLinkedDuplicates(keep)` and the same call for the next entry
  (PlayerData `+0xBC`, category 1) remove it and its parts.
- **Only this one keep is touched.** Keeps that are not the active one are not looked at at all.

**Placing an AI's castle** (`0x441DE0` .. `0x441F49`), for each AI player:

- `GetPlayerPosition(p)` picks the start-position slot and `setupAIVMetadata(p)` prepares the plan.
- `setKeepOffsetAndOrientation(aiv, x, y)` (`0x4ECF70`) anchors the plan at the recorded spot and
  works out the keep's orientation relative to the map centre (`calculatePreferredRelativeOrientation`
  against (200, 200), 2 and 6 swapped). **This is the "rotation".**
- `selectBestAIVwithRandomStart` (`0x4F13F0`), or `tryPlaceAIVAndReturnFitPercentage` (`0x4F14F0`)
  when the AIV is fixed: unpacks each of the AI's AIVs, rotates it with `rotateAIV`, and asks
  `computeAIVPlacementFit` (`0x4EF8C0`). That walks the plan's buildings and checks their tiles
  on the map. The best fit is stored in the AIV state (`+0x10`, sub type `+0x14`).
- If an AIV fitted (sub type ≠ 0): `applyAIV`, then
  `placeBuilding(p, keepX, keepY, 0x3D, 7, orientation)`, so the keep gets the AIV's orientation.
- **If none fitted (`0x441F2E`): `placeBuilding(p, x, y, 0x3D, 7, 0xF)`**. This is a plain keep at
  the recorded corner with the default orientation, and the AI has no AIV for the whole match.

With one keep per player the spot is empty once the active keep is gone, and the AIV fits. With
several keeps, the others (doors, campfire, stockpile included) stand within the plan's area, the
fit comes back 0 or negative, and the fallback runs.

## Side effects worth knowing

- A player whose active keep is **cleared** (no crest selected) has no start position recorded.
  The match then has no place to put that player.
- The other keeps survive the match start and belong to the AI. They are ordinary buildings to
  it: the AI does not build around them or treat them as its castle.

## Ways to fix it (not done yet)

1. **Clear the AI's extra keeps before the fit**: hook `LaunchSkirmishGame` after the active keep
   is removed (`0x441B7B`) and, for AI players only, also remove every other keep of theirs with
   its parts (`destroyBuildingAndLinkedDuplicates`). The AIV then fits as on a one-keep map. The
   map maker's extra keeps for AI players are lost in the match, while human players keep theirs.
2. **Let the fit ignore the player's own extra keeps**: patch `computeAIVPlacementFit`'s tile
   test so tiles of the same player's keeps count as free. The keeps then stay, but the AIV builds
   over them, which overlaps the old keep with the new castle. That needs more care.
3. **Fall back with rotation at least**: in the no-AIV branch (`0x441F2E`), pass the orientation
   `setKeepOffsetAndOrientation` worked out instead of `0xF`. The keep then faces the centre, but
   the AI still has no AIV. This only fixes half of the problem.

Option 1 is the simplest and gives AI players their normal castle. It can be a map editor
setting that only acts on AI players with several keeps.
