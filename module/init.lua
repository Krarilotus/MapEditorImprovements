--[[
  Map Editor Improvements

  Changes to the map editor, each a setting of its own:

  1. Map counts. In the landscape editor:
     - Pointing at the Animals, Vegetation or Rocks category button shows a tooltip with how
       many the map has against the game's limit: units and animals (UnitsState's unit count
       against the limit the editor tests before placing more), herds and troops (used group
       slots), trees and shrubs (used tree slots) and rocks (used rock slots).
     - The deer, lion, rabbit and camel buttons of the Animals menu show the counters their
       update functions add to every tick; the plant buttons of the Vegetation menu show how
       many trees or shrubs of their type stand on the map.
     A red "i" button above the key button switches all of it on and off.
  2. Always keep the menu up to date. The main loop redraws the menu only while
     GameCore.countdown (kept at 1 while the mouse is over the menu, counted down otherwise)
     is set; otherwise, in the landscape editor, it only redraws the minimap. The branch that
     makes that choice is pointed at a stub that also takes the full redraw in the map
     editor (GameMode2 == 1). The countdown itself is left alone, so nothing else that reads
     it changes.
  3. Trees:
     - Growth stage from the brush size. placeTree hands createTree a fixed stage, 3; it gets
       brush size - 1 (0 .. 6) instead. createTree still decides for shrubs (always 4).
     - An apple tree button. No tool command makes an apple tree (type 15), so the module
       takes command 136, which the click handler already sends through placeTree like the
       shrubs (it would make type 11, an invisible shrub no button uses), and has the
       command-to-type function answer 15 for it.
     - A shrub panel above the Vegetation menu while one of shrub types 5 .. 9 is chosen:
       commands 130 .. 134, which the game already understands (only 130 has a button).
       Those five shrubs are one picture (tree_shrub1) in the colours createTree gives them.
     - A felled tree panel above the Vegetation menu while a tree (types 1 .. 4) is chosen:
       one button per number of logs a felled tree of that type and growth stage can have
       (TreeRelated1[type][stage]: 1, 2, 4, 9, 9 for stages 0 .. 4). A tree placed with one
       of them chosen is laid down the way the woodcutter's log taking leaves a tree
       (advanceTreeDecayState: lying = 2, that many logs, no chops left). Its picture is the
       game's own choice (UpdateTree1: stage base - logs).
  4. Ground textures: the Textures menu's two rows get a fifth button each, Gravel (command
     13, which the click handler already understands; pictures from images/) and Iron (a copy
     of the Heights menu's iron button), and the rows are spread evenly over the panel.
  5. Rocks: skirmish maps open the scenario Rocks menu (tab 237, with the signpost) instead of
     tab 239: the category button's `jl` past `mov eax, 239` becomes a `jmp`.
  6. Random rock rotation: the random button sets rotation mode 0 instead of 5. Mode 5 turns
     the rotation every frame and the preview ignores it; mode 0 turns it once a second and
     the preview follows.
  7. Rock variants: a row above the Rocks menu shows the four variants of the chosen rock size
     and rotation (drawn from the game's own tile pictures through its own tile layout,
     getBuildingSizeIndexMappingData, and the map's turn). Choosing one fixes the variant the
     editor places and previews instead of cycling; the Rocks menu's own buttons go back to
     cycling.
  8. The extra rock: rock number 16 and up makes a 1x1 rock of type 0 (see docs/size-4-rocks.md);
     the variant row offers it at size 1x1.
  9. Herds: a panel above the Animals menu shows the chosen animal's herd size (base + random
     mask) and troop type, read from the herd code, with a check box that makes herds
     2 x brush - 1 animals.
  10. Trees next to obstacles: a check box in the Vegetation menu skips placeTree's check of
     the tiles around a new tree. The Vegetation menu's rows are tidied: the top row's shrub
     moves to the bottom row, which is sorted by command.
  11. Random mixes: the felled tree row gets a random standing tree (placeTree's stage, 0 up to
     the brush's) and a random felled tree (logs 1 up to the most), the shrub row a random
     shrub (the command-to-type function picks one of the five shrub commands).

  None of the menu changes patch code. The landscape editor's menu items are a static table
  handed to the Menu constructor by a CRT initializer (push table / mov ecx, menu / call
  Menu::Menu). A copy of that table is built with the module's items added and the push
  pointed at the copy; if the menu has been built already, it is built again.

  Buttons above the panel (the "i", the shrub and felled tree panels) lie over the map. The
  game draws there on the map surface, at the item position plus the camera offset (see its
  description line renderer), and so does the module. Clicks there would also reach the
  map: an item put in front of the game's map click handler tells it the mouse is not on the
  map while it is on one of these buttons.

  Every address is found by pattern scan or read out of the instruction that uses it, so the
  module runs on Stronghold Crusader.exe and Stronghold_Crusader_Extreme.exe alike.
]]

local templates = require("templates")
local png = require("png")

local MODULE_NAME = "map-editor-improvements"
local MODULE_FOLDERS = { "ucp/modules/map-editor-improvements/" }   -- UCP maps this to the active version

local DEFAULTS = {
  counts = { enabled = true, shown = true },
  menu = { always_update = true, dust_clouds = true, compass = true, compass_turn = true },
  trees = { growth_from_brush = true, apple = true, shrubs = true, felled = true, random_mix = true, preview = true,
    obstacles = true, sorted_rows = true, no_shrub_stacking = true, spread_order = true, spread_outlines = true,
    rocks_and_water = true },
  textures = { gravel_and_iron = true, no_heights_iron = true, mask = true, mask_by_type = true },
  water = { decorations = true, foam_on_sea = true },
  brushes = { full_shape = true },
  undo = { enabled = true },
  pipette = { enabled = true, select_key_on = true, select_key = "letter_p", read_key_on = true, read_key = "ctrl",
    any_tile_key_on = true, any_tile_key = "alt" },
  rocks = { signpost = true, random_preview = true, variants = true, extra_rock = true, invisible = true,
    erase_invisible = true, remove_lost = true },
  castle = { building_counts = true, tower_ruins = true, tunnel_and_tents = true, statues_and_shrines = true,
    barrier = true, several_keeps = true, several_storage_and_recruitment = true, tower_engines_anywhere = true,
    keep_parts = true, damaged_walls = true, hover_text_left = true, moat_kinds = true, moat_on_marsh = true,
    moat_removal_keeps_ground = true, variant_panels = true, ruined_cathedral = true, all_players = true,
    all_keeps = true, player_zero = true, keep_crests = true, keep_crest_tooltip = true, keep_ground = true, rotation = true, unit_colour = true,
    wall_tools = true },
  herds = { panel = true, bird_bins = true, animal_bin = true, group_warning = true },
  eraser = { choice = true, seagulls = true },
  map_settings = { show_locked = true, button = true, menu = true, size_refresh = true, camera_edge = true },
  heights = { max_height = true, tool_options = true, invert_key_on = true, invert_key = "ctrl" },
}

---------------------------------------------------------------------------------------
-- What the game's code and data look like where this module touches them
---------------------------------------------------------------------------------------

-- The landscape editor's item table, found by its key button (item 11: a group member placed
-- by user control 146, command 152). The bytes in between are its action, 0 until the Menu
-- constructor has copied the group's action in.
local AOB_ITEM_TABLE = "03 00 00 02 00 00 00 80 92 00 00 00 00 00 00 00 00 00 00 00 ? ? ? ? 98 00 00 00"
local KEY_BUTTON_ITEM = 11
local ITEM_COUNT = 99                    -- items before the end marker
local MAP_CLICK_ITEM = 1                 -- every frame: the game's map click handler

-- MenuItem (0x50 bytes)
local MENU_ITEM_SIZE = 0x50
local ITEM_TYPE, ITEM_X, ITEM_Y, ITEM_WIDTH, ITEM_HEIGHT = 0x00, 0x04, 0x08, 0x0C, 0x10
local ITEM_ACTION, ITEM_PARAM, ITEM_RENDER = 0x14, 0x18, 0x1C
local ITEM_IMAGE, ITEM_RENDER_TYPE, ITEM_TEXT = 0x20, 0x24, 0x2C
local ITEM_CONTROL = 0x30                -- word: user control placing the item, -1 none
local ITEM_HOVERED, ITEM_HIDDEN, ITEM_MENU = 0x32, 0x36, 0x4C
local TYPE_EVERY_FRAME, TYPE_CLICKABLE = 0, 3
local TYPE_GROUP_START, TYPE_BLOCK, TYPE_END = 0x01000000, 0x64, 0x66
local TYPE_GROUP_MEMBER_MASK, TYPE_GROUP_MEMBER = 0xFF000000, 0x02000000
local RENDER_NONE, RENDER_SIMPLE, RENDER_IMAGE = 0, 1, 3
local PLACED_BY_CONTROL = 0x80000000     -- x of an item the user control table places
local IMAGE_INDEX_MASK = 0x7FFFFF
local MENU_X, MENU_Y = 0x04, 0x08        -- the menu's position on screen
local MENU_SCROLL = 0x14                 -- subtracted from x when drawing

-- Item 9 is the line that shows the description of the button under the mouse.
local HOVER_TEXT_ITEM = 9
local HOVER_TEXT_POSITION = { 20, 422 }

-- The "i" button: interface_buttons.gm1 picture 28 (image table index 197), the game's own
-- red "i"; the renderer shows picture 29 while the mouse is on it. It goes in front of the
-- general buttons group, above the key button, and the description line moves right.
local INFO_IMAGE = 197
local INFO_BUTTON = { 22, 424 }
local INFO_BEFORE_ITEM = 10
local HOVER_TEXT_MOVED_X = 56

-- Button commands (item param). A category button's command is its tab's id.
local DEER, LION, RABBIT, CAMEL = 220, 221, 222, 223
local TEXTURES, VEGETATION, ANIMALS, ROCKS = 232, 234, 235, 237
local FIRST_TREE_COMMAND, LAST_TREE_COMMAND = 40, 43        -- tree types 1 .. 4
local SHRUB_COMMANDS = { 130, 131, 132, 133, 134 }          -- shrub types 5 .. 9
local APPLE_COMMAND, APPLE_TYPE = 136, 15
local GRAVEL_COMMAND, IRON_COMMAND = 13, 16

-- The rows the module spreads out, by command, left to right (the order of the buttons'
-- user control positions), and the span of the panel they are spread over.
local TEXTURE_ROWS = { { 18, 340, 10, 12, GRAVEL_COMMAND }, { 5, 7, 19, 341, IRON_COMMAND } }
local VEGETATION_TREES = { 41, 42, 40, 43 }            -- the top row's trees
local TOP_ROW_SHRUB = 135
local SORTED_SHRUBS = { 130, 135, 153, 154, 155, 156 }  -- the bottom row, sorted by command
local ROW_LEFT, ROW_RIGHT = 250, 636
local OBSTACLES_BUTTON = "obstacles"                   -- the check box's key in a row

-- Constants of the later features, in a table: a Lua chunk may have at most 200 locals.
local K = {}
-- Functions of the later features, in a table for the same reason.
local C = {}

-- Rocks: the tabs (scenario with signpost, skirmish without) and the tools.
K.ROCKS_SKIRMISH = 239
K.SIGNPOST = 59
K.FIRST_ROCK_COMMAND = 205
K.LAST_ROCK_COMMAND = 209
-- The category button's action: `cmp eax, 237 / jne / cmp [map type], 1 / jl +5 / mov eax, 239`.
K.AOB_SIGNPOST = "3D ED 00 00 00 75 0E 83 3D ? ? ? ? 01 7C 05 B8 EF 00 00 00"
K.SIGNPOST_JUMP = 0x0E
K.JL_SHORT = 0x7C
K.JMP_SHORT = 0xEB
-- The random rock button: `... / mov ecx, 5 / mov [rotation mode], ecx / mov [rotation], 0`.
K.AOB_RANDOM_ROCK = "A3 ? ? ? ? A1 ? ? ? ? 83 F8 02 B9 05 00 00 00 89 0D ? ? ? ? C7 05"
K.RANDOM_ROCK_MODE = 0x12
K.RANDOM_ROCK_MODE_SIZE = 6
K.ROCK_TURN_MODE = 6                     -- the module's own rock rotation mode (the game's: 0-5)
-- placeRock: `mov eax,[esi+rotation] / push eax / push ebp / push edi / push ecx / sar ebx,1 / ...`
K.AOB_ROCK_TURN = "8B 86 ? ? ? ? 50 55 57 51 D1 FB 03 5C 24 30 52 B9"
K.ROCK_TURN = { size = 6, rotation = 2 }
-- The click handler's rock placement: `lea ecx,[variant + size*4] / mov [command param 3],ecx /
-- push 0x1A / ... / call queueCommand / mov eax,[variant]` (the variant cycling).
K.AOB_ROCK_PLACE = "8D 0C ? 89 0D ? ? ? ? 6A 1A B9 ? ? ? ? C7 05 ? ? ? ? 14 00 00 00 E8 ? ? ? ? A1"
K.ROCK_PLACE = { size = 9, param = 5, variant = 0x20 }
-- ... and its preview: `mov reg,[a] / mov reg,[b]` (variant and size, either order),
-- `lea ecx,[...] / mov edx,[mouse tile y] / ... / mov ecx, TileMapState / call preview`.
K.AOB_ROCK_PREVIEW = "8D 0C ? 8B 15 ? ? ? ? A1 ? ? ? ? 51 52 50 B9 ? ? ? ? E8"
K.ROCK_PREVIEW = { size = 9, mouseY = 5, tileMap = 0x12, first = { -0x0B, { 0x8B, 0x15 } },
  second = { -0x05, { 0xA1 } } }
-- TileMapState fields: the rock tool's rotation and rotation mode, the map's turn (0, 6, 4,
-- 2), and what getBuildingSizeIndexMappingData(tile, size) leaves for a footprint tile.
K.TILE_MAP = { rotation = 0x554890, mode = 0x554894, orientation = 0x55489C,
  tileX = 0x55498C, tileY = 0x554990, tilePicture = 0x554994 }
-- The rock stamping in the map renderer: `mov eax,[esi+tileY] / add eax,[esp+10]` right after
-- the footprint call, and getRandomRockImageOffset (mov eax,[esp+4] / mov eax,[eax*4+table]).
K.AOB_ROCK_STAMP = "8B 86 90 49 55 00 03 44 24 10"
K.ROCK_STAMP = { mapping = -0x05, randomOffset = 0xAA }
K.ROCK_PICTURES = { 0x04, { 0x8B, 0x04, 0x85 } }   -- in getRandomRockImageOffset
K.ROCK_GM = { 0xA5, { 0x66, 0x8B, 0x14, 0x95 } }    -- in createRock: the gm per rock type
K.ROCK_VARIANTS = 4
K.EXTRA_VARIANT = 4
K.EXTRA_ID = 16
K.TILE_DIAMOND = { 2, 6, 10, 14, 18, 22, 26, 30, 30, 26, 22, 18, 14, 10, 6, 2 }
K.TILE_DIAMOND_BYTES = 512
-- The screen offset of a footprint tile (dx, dy) for each map turn: d = dx - dy, s = dx + dy;
-- x = xd*d + xs*s, y = yd*d + ys*s (renderMap's transform without its constants).
K.TURN = {
  [0] = { xd = 16, xs = 0, yd = 0, ys = 8 }, [6] = { xd = 0, xs = -16, yd = 8, ys = 0 },
  [4] = { xd = -16, xs = 0, yd = 0, ys = -8 }, [2] = { xd = 0, xs = 16, yd = -8, ys = 0 },
}

-- Herds: `movzx eax, byte [random] / and eax, MASK / mov edi, UNIT / add eax, BASE`, after
-- `mov word [herd + 0x42], TROOP TYPE`; deer, lions, rabbits, camels in that order.
K.AOB_HERD = "0F B6 05 ? ? ? ? 83 E0 ? BF ? 00 00 00 83 C0 ?"
K.HERD = { site = 7, size = 11, mask = 9, unit = 11, base = 17, group = { -7, { 0x66, 0xC7, 0x44, 0x28, 0x42 } } }
K.HERD_ANIMALS = { { DEER, "Deer" }, { LION, "Lion" }, { RABBIT, "Rabbit" }, { CAMEL, "Camel" } }
K.HERD_SEARCH_END = 0x01000000       -- the end of the game's code for searches with several hits

-- placeTree: `xor ebx,ebx / test eax,eax / mov [esp+0x10],esi / jle <past the check>`.
K.AOB_OBSTACLES = "33 DB 85 C0 89 74 24 10 7E 50 56 55 8D 44 24 18"
K.OBSTACLES_SIZE = 10
K.OBSTACLES_JUMP = 0x09
K.OBSTACLES_NEAR = 0x400               -- how far from placeTree's start the check lies at most
K.OBSTACLES_NUDGE = { -10, -20 }        -- the obstacles box, from its place at the end of the top row
K.ROCKS_AND_WATER_GAP = 4
-- placeTree's tile test `test dword [edi+ebp*4+LogicLayer], 0x703E25B5`; with Vegetation on rocks
-- and water these bits stay out of it: rocky, boulders, pebbles, river, ford, marsh.
K.AOB_TREE_GROUND = "F7 84 AF ? ? ? ? B5 25 3E 70"
K.TREE_GROUND = { size = 11, logic = 3, mask = 7, loose = 0x80 | 0x20000 | 0x40000 | 0x100000 | 0x200000 | 0x20000000 }

-- The game's check boxes (interface_icons3 pictures 206 tick / 208 cross, + 1 under the
-- mouse), by image table index.
K.CHECKED_IMAGE = 569
K.UNCHECKED_IMAGE = 570
K.CHECK_BOX_SIZE = 29

-- Random mixes in the tree panels: the felled tree buttons' choices for a random standing
-- tree (growth stage 0 up to the brush's, offered for stages 1 .. 4) and a random number of
-- logs, and the random numbers (a linear congruential generator, high 16 bits used).
K.RANDOM_STANDING = 0x40
K.RANDOM_FELLED = 0x41
K.MOST_RANDOM_STAGE = 4
K.RANDOM_MULTIPLIER = 1103515245
K.RANDOM_INCREMENT = 12345
K.RANDOM_LABEL = "?"

-- Invisible rocks: placeRock's `push edx / mov ecx, LandscapeState / call createRock / xor
-- edi,edi / add eax, 2000 / mov [esp+0x20],eax` (the rock number the tiles get: 2000 + slot,
-- 2000 when the list is full). createRock takes 5 arguments.
K.AOB_CREATE_ROCK_CALL = "52 B9 ? ? ? ? E8 ? ? ? ? 33 FF 05 D0 07 00 00 89 44 24 20"
K.CREATE_ROCK_CALL = 6
K.CREATE_ROCK_ARGUMENTS = 0x14
K.CHECK_BOX_GAP = 8
-- Tooltips of the check boxes sit higher than the category tooltips (clear of the menu's top).
K.CHECK_BOX_TOOLTIP_RAISE = 20
-- Names the game has no text for, shown on the description line in the game's language
-- (German when the game's text for iron, cr.tex group 8 text 337, is "Eisen").
K.NAMES = { apple = { en = "Apple tree", de = "Apfelbaum" }, gravel = { en = "Gravel", de = "Kies" } }
K.TEXT_FILE, K.TEXT_GROUP, K.TEXT_INDEX, K.GERMAN_TEXT = "cr.tex", 8, 337, "Eisen"
K.TEXT_GROUPS, K.TEXT_START = 250, 1000
-- A felled tree placed at the smallest growth stage is placed at the next one, with 1 log (the
-- smallest stage has no felled picture).
K.SMALLEST_FELLED_STAGE, K.SMALLEST_FELLED_LOGS = 1, 1
-- Erasing invisible rocks: the eraser brush (and the brush the other tools erase with) takes a
-- tile's rock off by its number: `cmp eax, 2000 / mov ecx, LandscapeState / jl <tree> / add
-- eax, -2000 / push eax / call removeRock`. An invisible rock's tiles have number 2000, an
-- empty slot. The tile is in [esp+0x20], the map tables are named a little before.
K.AOB_ERASE_ROCK = "3D D0 07 00 00 B9 ? ? ? ? 7C 15 05 30 F8 FF FF 50 E8"
K.ERASE_ROCK = { base = 1, site = 12, size = 11, call = 6 }
K.AOB_ERASE_TABLES = "F6 84 86 ? ? ? ? 30 75 ? 0F BF 84 46 ? ? ? ? 85 C0 74"
K.ERASE_TABLES = { flags = 3, numbers = 14 }
K.ROCK_TILE_FLAG = 0x80
K.ERASE_SITES = 2
-- ... and its tree branch, `push eax / call removeTree` (the tile's tree; shrubs stacked on the
-- tile stay in the tree list). A tree's tile is 0x24 after its "in use" word.
K.ERASE_TREE = { site = 0x21, size = 6, call = 1, bytes = { 0x50, 0xE8 } }
K.TREE_TILE_FROM_IN_USE = 0x24
-- Shrub stacking: placeTree's obstacle check site follows `jne <refuse>` (a blocked tile).
K.OBSTACLES_REFUSE = { -6, { 0x0F, 0x85 } }
-- The water menu's two decorations (Stronghold's foam and small waves): commands the click
-- handler still sends to setTerrain as river with decoration 0x10 / 0x20, and the menu
-- pictures that are still in the image table (mapedit_buttons.gm1).
K.WATER = 236
K.RIVER = 14
K.WATER_DECORATIONS = { { command = 150, image = 286, name = "foam" }, { command = 151, image = 287, name = "waves" } }
K.NAMES.foam = { en = "Foam", de = "Gischt" }
K.NAMES.waves = { en = "Small waves", de = "Kleine Wellen" }
K.ROW_TOLERANCE = 20                     -- buttons whose middles are this close are one row
-- setTerrain in the map editor first turns the brush area to land for the land types (`cmp
-- [ebp+0x18], 0x40000000 / je <skip> / cmp [ebp+0x1C], 2 ...`), and 0x10 / 0x20 are among them:
-- river terrain (0x100000) with a decoration skips that, or the decoration finds no river.
K.AOB_TERRAIN_LAND = "83 3D ? ? ? ? 01 75 ? 81 7D 18 00 00 00 40 74 ? 83 7D 1C 02 74"
K.TERRAIN_LAND = { site = 9, size = 9 }
K.RIVER_TERRAIN = 0x100000
-- ... and in its tile loop, a decoration only goes on a river tile: `cmp [ebp+0x1C],0 / je /
-- mov edx,[ebp+0xC] / mov eax,[ebp-0x20] / mov ecx,[eax+edx*4+flags] / and ecx,0x100000 / jne
-- <river> / jmp <skip>`. Foam may also take an ocean tile (flag 1, the sea terrain's own flag,
-- which the river path clears).
K.AOB_DECORATION_TILE = "83 7D 1C 00 74 1A 8B 55 0C 8B 45 E0 8B 8C 90 ? ? ? ? 81 E1 00 00 10 00 75 05 E9"
K.DECORATION_TILE = { site = 0x0C, size = 15, flags = 3 }
K.FOAM, K.SEA_TILE = 0x10, 0x1
-- The brushes: getTileInSquareBrush(index, x, y) walks outwards from the cursor tile (four
-- directions, a visited mark per tile) and answers the index-th tile it reaches. It never marks
-- the cursor tile, so it comes back to it from the first ring and counts it twice: the last
-- tile of every brush (its top left corner on screen) is left out. At its start, `cmp [esp+
-- 0x1F60], ebp (index) / mov [esp+0x1C], eax / mov [esp+0xFBC], ecx (the tile) / jg <walk>`;
-- the visited marks: `movsx ebp, word [eax*2 + marks] / cmp ebp, [edi+4] (this walk's mark)`.
K.AOB_BRUSH_START = "39 AC 24 60 1F 00 00 89 44 24 1C 89 8C 24 BC 0F 00 00 7F"
K.BRUSH_START_SIZE = 18
K.AOB_BRUSH_MARKS = "0F BF 2C 45 ? ? ? ? 3B 6F 04 74"
K.BRUSH_MARKS = 4

-- Undo and redo. The map sections: `push SECTION TABLE / mov ecx, ... / mov [esp+0x50],edx /
-- mov [esp+0xBC],eax / call` (the map file's writer); entries { address, 0, size, number << 16 |
-- flag }, ending at address 0.
K.AOB_SECTION_TABLE = "68 ? ? ? ? B9 ? ? ? ? 89 54 24 50 89 84 24 BC 00 00 00 E8"
K.SECTION_TABLE = 1
K.SECTION = { address = 0, size = 8, stride = 16 }
K.MOST_SECTIONS = 1000
-- queueCommand, which every command of the player goes through before it is carried out:
-- `mov eax, [esi+0x6A4] / imul edx, edx, 0x4F8 / mov ebx, [esp+0x10] / mov [edx+esi+...], eax`
-- (+0x4B). The protocol module finds queueCommand by its first 0x45 bytes and hooks the six
-- calls through the command table, so neither is touched here.
K.AOB_QUEUE_COMMAND = "8B 86 ? ? ? ? 69 D2 F8 04 00 00 8B 5C 24 10 89 84 32"
K.QUEUE_COMMAND_SIZE = 6
-- The two buttons in the screen's top left corner (screen pixels; their items are moved there
-- every frame, whatever the menu's position), and a hidden item's place.
K.UNDO_BUTTONS = { left = 10, top = 10, gap = 8, padding = 4 }
K.FAR_AWAY = -100000
-- `push VK_DOWN / call [GetAsyncKeyState] / test ax,ax`: the mouse buttons' state.
K.AOB_ASYNC_KEY = "6A 28 FF 15 ? ? ? ? 66 85 C0"
K.ASYNC_KEY_IMPORT = 4
K.VK_LBUTTON, K.VK_RBUTTON = 0x01, 0x02
-- The commands that change the map (the command table's ids): erase, set land, raise land,
-- set terrain, equalize heights, height min/max, plateau, walls, rocks and trees, raise land 2,
-- buildings, destroy building, destroy, siege tents, animals, gates, repair tower, spawn
-- entity, remove tower engine, destroy wall or pitch. Others, like a click that only selects
-- (0x10), make no step.
K.MAP_EDITS = { 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x29, 0x2A, 0x2C,
  0x2D, 0x44, 0x45, 0x4B, 0x4C }
-- prepareMap's calls after loading a map, from `call / mov ecx, PATHFINDING / call linkTiles /
-- push edi / ...`; its `mov ecx, PATHFINDING` (forget) is where a new map clears the history.
-- (interface-visual-fixes patches prepareMap's first bytes.)
K.AOB_PREPARE_BLOCK = "E8 ? ? ? ? B9 ? ? ? ? E8 ? ? ? ? 57 B9 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? E8"
K.PREPARE = { forget = 0x05, forgetSize = 5, pathFinding = 0x06, linkTiles = 0x0A, areas = 0x15, buildings = 0x1B, linkBuildings = 0x1F,
  climb = 0x29, cliffs = 0x4E, hovered = 0xD3, unhover = 0xDD, changedAll = -0xFB }
-- `push edi / mov ecx, MINIMAP / call triggerMinimapRedraw / mov eax, 2000 / mov ecx`.
K.AOB_MINIMAP_REDRAW = "57 B9 ? ? ? ? E8 ? ? ? ? B8 D0 07 00 00 B9"
K.MINIMAP_REDRAW = { object = 2, call = 6 }
K.UNDO_STEPS = 20
K.UNDO_GAP_BYTES = 16                     -- unchanged bytes that end a changed run
K.UNDO_SCRATCH = 16 * 1024 * 1024         -- the largest single step
K.UNDO_MOST_BYTES = 64 * 1024 * 1024      -- all steps together
-- Castle mode's building hover text ("Player 1's Keep"): RenderPlayerInfoOnHoverDisplayElement's
-- map editor branch, `mov eax,[esp+0x10] (x) / mov ecx,[hovered player]` before renderText.
K.AOB_HOVER_TEXT = "8B 44 24 10 8B 0D ? ? ? ? 53 6A 10 53 68 ? ? ? ? 6A 01 83 C5 EC 55 50"
K.HOVER_TEXT_SIZE, K.HOVER_TEXT_PLAYER, K.HOVER_TEXT_SHIFT = 10, 6, 100

-- Castle mode: the build menu (found by its minimap item, item 17), its tabs (the menu
-- category values) and the commands (placement ids) the module adds.
K.AOB_BUILD_MINIMAP = "02 00 80 00 3B 02 00 00 D1 01 00 00 7E 00 00 00 7E 00 00 00 ? ? ? ? 39 30 00 00"
K.BUILD_MINIMAP_ITEM = 17
K.BUILD_MOST_ITEMS = 1000
K.MAP_EDITOR = 1                         -- GameMode2
K.TAB_TOWERS, K.TAB_KEEPS, K.TAB_ARMY, K.TAB_GOOD, K.TAB_RUINS = 11, 13, 14, 15, 27
K.TAB_UNIT_COMMANDS = 61                 -- the engineer's siege tent buttons are here
K.FIRST_TOWER = 110                      -- towers 110 .. 114, their ruins 115 .. 119
K.TOWER_RUINS = { 115, 116, 117, 118, 119 }
K.RUIN_LABEL = "Ruin"
K.ENGINEERS_GUILD, K.TUNNELERS_GUILD = 88, 89
K.TUNNEL_COMMAND, K.TUNNEL_LABEL = 57, "Tunnel"
K.TUNNEL_WHEN = { [89] = true, [57] = true }
K.TENTS = { 190, 191, 192, 193, 194, 358 }
K.TENTS_WHEN = { [88] = true, [190] = true, [191] = true, [192] = true, [193] = true, [194] = true, [358] = true }
K.STATUES = { { 320, 313, "2x2" }, { 321, 318, "2x2" }, { 322, 318, "1x1" } }   -- command, picture of, label
K.FIRST_RUIN = 248
K.BARRIER_COMMAND, K.BARRIER_LABEL = 58, "Barrier"
-- The barrier's picture: the "no workers" sign the game floats over buildings, face on (gm
-- floats_new, picture 80; pictures 65 .. 80 turn it round). The gm number is checked against
-- the gm list (records of 1000 bytes, by name) and the check boxes' gm, interface_icons3.
K.NO_WORKERS_GM, K.NO_WORKERS_PICTURE = 172, 80
K.AOB_GM_NO_WORKERS = "66 6C 6F 61 74 73 5F 6E 65 77 00"           -- "floats_new"
K.AOB_GM_CHECK_BOXES = "69 6E 74 65 72 66 61 63 65 5F 69 63 6F 6E 73 33 00"   -- "interface_icons3"
K.GM_RECORD_SIZE = 1000
K.SCREEN_LAYER = 0
K.BUILD_NEEDED = {
  { 11, 110 }, { 11, 111 }, { 11, 112 }, { 11, 113 }, { 11, 114 }, { 14, 88 }, { 14, 89 }, { 15, 313 }, { 15, 318 },
  { 27, 248 }, { 61, 190 }, { 61, 191 }, { 61, 192 }, { 61, 193 }, { 61, 194 }, { 61, 358 },
  { 13, 60 }, { 13, 61 }, { 13, 62 }, { 10, 25 }, { 10, 26 }, { 10, 27 }, { 10, 46 },
}
-- The building list: placeBuilding's `push ebx / mov ecx, BuildingsState / mov [esi+..],edx /
-- call convertCommandBuildingTypeToBuildingType`; BuildingsState + 8 is the list's size.
K.AOB_BUILDINGS_STATE = "53 B9 ? ? ? ? 89 96 ? ? ? ? E8 ? ? ? ? 83 3D ? ? ? ? 04"
K.MAX_BUILDINGS = 8
-- The list's capacity: a walk over every slot, `mov esi, <first state> / ... / add esi,
-- <building size> / inc edi / cmp esi, <past the last>`.
K.AOB_BUILDING_SLOTS = "BE ? ? ? ? 8D 64 24 00 66 83 3E 00 74 0B 57 B9 ? ? ? ? E8 ? ? ? ? 81 C6 2C 03 00 00 83 C7 01 81 FE"
K.BUILDING_SLOTS = { first = 1, past = 0x25 }
K.BUILDING_REMOVED = 3                   -- logical state; 0 is a free slot
-- The toolbar action's `mov eax, [current player] / mov ecx,eax / imul ecx,ecx,<player size>`.
K.AOB_CURRENT_PLAYER = "A1 ? ? ? ? 8B C8 69 C9 ? ? 00 00 39 99 ? ? ? ? 74 18"
-- A walk over the building list: `lea edx,[ecx + first state] / push ebx / movzx eax, word
-- [edx] / test ax,ax / je / movsx ebx, word [edx + owner]`, ... `add edx, <building size>`.
K.AOB_PLAYER_LOOP = "8D 91 ? ? ? ? 53 0F B7 02 66 85 C0 74 ? 0F BF 5A ?"
K.PLAYER_LOOP_OWNER = 18
K.PLAYER_LOOP_STRIDE = { 0x79, { 0x81, 0xC2 } }
-- ... and in it the building types it counts: `movsx eax, word [edx + type] / add eax,-first /
-- cmp eax, last - first / ja <counted> / movzx eax, byte [eax + table] / jmp [eax*4 + jumps]`.
K.AOB_PLAYER_BUILDINGS = "0F BF 42 02 83 C0 F6 83 F8 5E 77 0E 0F B6 80 ? ? ? ? FF 24 85 ? ? ? ?"
-- getBuildingSizeForCommandBuildingType: `mov eax,[esp+4] / add eax,-0x2C / cmp eax,0x146 / ja`.
K.AOB_BUILDING_SIZE = "8B 44 24 04 83 C0 D4 3D 46 01 00 00 77 75"
K.BUILDING_SIZE_START = 7
-- The preview's building pictures: `call convertCommandBuildingTypeToBuildingType / mov eax,
-- [eax*4 + gm per building type] / mov [esi+..],eax / movsx eax,bx / push eax / mov ecx,
-- BuildingsState / call getSpriteID` (the building's first picture).
K.AOB_BUILDING_SPRITES = "E8 ? ? ? ? 8B 04 85 ? ? ? ? 89 86 ? ? ? ? 0F BF C3 50 B9 ? ? ? ? E8"
K.BUILDING_SPRITES = { gms = 8, sprite = 0x1B }
K.TUNNEL_SIZE = 3
-- Panels moved left of the screen's middle.
K.PANEL_SHIFT = { [11] = -150, [12] = -100, [13] = -50, [15] = -100, [30] = -100, [33] = -100 }
-- Buildings with variants. Placement gives setupBuildingData the variant (placement id - the
-- group's first), which keeps a value from its group's table at building +0x29C (BuildingsState
-- + id * stride + 0x2B0): `mov ecx,[esp+0x30] / mov edx,[ecx*4+GARDENS] / mov [edi+esi+0x2B0],
-- edx / ...`, then the same for ruins, cesspits, statues, shrines and ponds (by building type).
K.TAB_BAD, K.TAB_TOWN = 33, 30
K.VARIANT_GROUPS = {
  [0x42] = { first = 160, count = 12, table = 1, name = "garden" },
  [0x27] = { first = 248, count = 13, table = 2, name = "ruin" },
  [0x5B] = { first = 301, count = 4, table = 3, name = "cesspit" },
  [0x64] = { first = 313, count = 5, table = 4, name = "statue" },
  [0x65] = { first = 318, count = 5, table = 5, name = "shrine" },
  [0x68] = { first = 325, count = 4, table = 6, name = "pond" },
}
K.AOB_VARIATIONS = "8B 4C 24 30 8B 14 8D ? ? ? ? 89 94 37 ? ? ? ? 8D 45 CD E9 ? ? ? ? 5B 33 C0 5E C2 20 00 "
  .. "83 FD 27 75 17 8B 44 24 30 8B 0C 85"
K.VARIATIONS = { field = 14, tables = { 7, 0x2D, 0x49, 0x65, 0x81, 0x9D } }
-- The variant panels above the menu: one row per building with variants (its menu button's
-- first id and how many), the module's extra statues and shrines at the end of theirs.
K.VARIANT_ROWS = {
  [K.TAB_GOOD] = { { 160, 6 }, { 166, 3 }, { 169, 3 }, { 313, 5, { 320 } }, { 318, 2, { 321, 322 } } },
  [K.TAB_BAD] = { { 301, 4 } },
}
K.CAMPFIRE_TYPE = 0x33                   -- the module's barrier is a campfire (placement 58)
-- rotateFearFactorBuildingVariations, every second: `mov eax,[chosen tool] / add eax,-0xA0 /
-- cmp eax,0xA8 / ja <end>` before the table that moves the tool to the next variant.
K.AOB_VARIANT_TURN = "A1 ? ? ? ? 05 60 FF FF FF 3D A8 00 00 00 77"
K.VARIANT_TURN = { size = 10, add = 6, endRel = 0x10 }
-- Hovels: placeWorkshopOrHovel gives a new hovel its player's next variant, `mov cx,[ebx+COUNTER]
-- / ... / mov [eax+HOVEL],cx / jne / mov eax,[ebx+COUNTER] / add eax,1 / cdq / mov ecx,7 / idiv
-- ecx / mov [ebx+COUNTER],edx` (ebx: player * the player data size).
K.HOVEL_TOOL, K.HOVEL_TYPE, K.HOVEL_VARIANTS = 54, 1, 7
K.AOB_HOVEL_VARIANT = "66 8B 8B ? ? ? ? 8B E8 69 C0 2C 03 00 00 66 83 7C 24 20 01 89 44 24 28 66 89 88 ? ? ? ? "
  .. "75 ? 8B 83 ? ? ? ? 83 C0 01 99 B9 07 00 00 00 F7 F9 89 93"
K.HOVEL_VARIANT = { size = 7, counter = 3, field = 0x1C, skipRel = 0x21, advance = 0x22, advanceSize = 6 }
-- ...and the placement preview's `imul ecx,ecx,player size / mov edx,[ecx+COUNTER] / mov eax,
-- [edx*4+HOVEL PICTURES] / mov [esp+0x2C],eax`.
K.AOB_HOVEL_PREVIEW = "69 C9 F4 39 00 00 8B 91 ? ? ? ? 8B 04 95 ? ? ? ? 89 44 24 2C"
K.HOVEL_PREVIEW = { site = 6, size = 6 }
K.HOVEL_PICTURES = 15                    -- in K.AOB_HOVEL_PREVIEW: the variants' first pictures
K.MOAT_ENTRY_WIDTH = 76                  -- room for "Permanent" under its picture
-- Panels the module draws mark where they are (menu coordinates) each frame they are drawn; the
-- guard keeps clicks there off the map. A rect: active, x, y, width, height; -1 ends the list.
K.GUARD_RECTS, K.RECT_SIZE = 64, 20
-- checkBuildingCanBePlacedHere's limits on empty storage buildings (stockpile 32, granary and
-- armoury 8): `push type / push ebx / mov ecx, BuildingsState / call getEmptyBuildingCount /
-- cmp eax, LIMIT / jge <refused> / mov reg,[esp+0x50] / push type`; three sites.
K.AOB_EMPTY_STORAGE = "53 B9 ? ? ? ? E8 ? ? ? ? 83 F8 ? 0F 8D ? ? ? ? 8B ? 24 50 6A"
K.EMPTY_STORAGE = { site = 11, size = 9, limit = 13, failRel = 16, sites = 3 }
K.TENTS_SHIFT = -200
-- Keep parts in the placement check (checkBuildingCanBePlacedHere: after the door tiles `mov
-- eax,[esp+0x48] / shl eax,5`, before the stockpile `mov eax,[esp+0x4C] / mov ebx,[eax+..]`)
-- and in the preview colours (setConstructionGFXLayerBasedOnPlacementChecks: after the doors
-- `shl edx,5 / add ebp,[edx+..]`, before the stockpile `mov eax,[esp+0x38] / mov ebp,[eax+..]`).
K.AOB_KEEP_CHECK = "8B 44 24 48 C1 E0 05 03 B8 ? ? ? ? 03 A8"
K.KEEP_CHECK = { size = 7, stockpile = 0xBF, stockpileSize = 10, table = 6, done = 0xB1,
  doneBytes = { 0x5F, 0x5E, 0x5D, 0x5B, 0x83, 0xC4, 0x2C, 0xC2, 0x14, 0x00 } }
K.AOB_KEEP_PREVIEW = "C1 E2 05 03 AA ? ? ? ? 03 BA ? ? ? ? 89 54 24 38"
K.AOB_KEEP_PREVIEW_STOCKPILE = "8B 44 24 38 8B A8 ? ? ? ? 8B 80 ? ? ? ? 03 44 24 18"
K.KEEP_PREVIEW = { size = 9, table = 5, stockpileSize = 10, stockpileTable = 6, done = 0x83,
  doneBytes = { 0x66, 0x8B, 0x44, 0x24, 0x34 } }
-- computeBuildingCategoryEntryPointAndDestroyEarlierBuilding(building, player, category): its
-- `push eax / mov ecx, BuildingsState / call destroyBuilding / mov edx,[esp+0x1C]`, three
-- times: the player's earlier keep (twice), then the earlier one of the unique buildings.
K.AOB_EARLIER_BUILDING = "8B 54 24 0C 53 55 56 57 33 FF 33 F6 85 D2 8B E9 C7 05"
K.EARLIER_DESTROY = "50 B9 ? ? ? ? E8 ? ? ? ? 8B 54 24 1C"
K.EARLIER_DESTROY_CALL, K.EARLIER_SEARCH = 6, 0x2D0
K.EARLIER_KEEP_CALLS = { 1, 2 }
K.EARLIER_UNIQUE_CALLS = { 3 }
K.DESTROY_ARGUMENTS = 4
-- checkBuildingCanBePlacedHere: a second stockpile, granary or armoury must touch the first
-- (`push type / ... / call hasBuildingAsNeighbour / test eax,eax / jne <allowed>`).
K.AOB_STORAGE_NEIGHBOURS = {
  "8B 44 24 50 6A 0A 50 55 57 53 B9 ? ? ? ? E8 ? ? ? ? 85 C0 0F 85",
  "8B 54 24 50 6A 13 52 55 57 53 B9 ? ? ? ? E8 ? ? ? ? 85 C0 0F 85",
  "8B 4C 24 50 6A 0B 51 55 57 53 B9 ? ? ? ? E8 ? ? ? ? 85 C0 0F 85",
}
K.STORAGE_NEIGHBOUR_CALL = 15
K.NEIGHBOUR_ARGUMENTS = 0x14
-- The place-building click for the tower mangonel and the tower ballista (in that order): with
-- the mouse button let go, `cmp esi, ebx / je <refuse>` (esi: the building on the tile), then
-- the tower tests and the spawn command (42: spawnUnit at a micro position and height).
K.AOB_TOWER_ENGINE_CLICK = "3B F3 0F 84 ? ? ? ? 8B 15 ? ? ? ? 69 F6 2C 03 00 00 0F BF 8E"
K.TOWER_ENGINE = {
  size = 8, refuse = { 0x02, { 0x3B, 0xF3, 0x0F, 0x84 } }, player = { 0x08, { 0x8B, 0x15 } },
  buildingSize = { 0x0E, { 0x69, 0xF6 } }, owners = { 0x14, { 0x0F, 0xBF, 0x8E } },
  types = { 0x23, { 0x0F, 0xB7, 0x8E } }, units = { 0x4B, { 0x66, 0x39, 0x1C, 0x45 } },
  param0 = { 0xC0, { 0x89, 0x15 } }, param1 = { 0xD5, { 0x89, 0x15 } },
  heights = { 0xE8, { 0x0F, 0xB6, 0x84, 0x0A } }, command = { 0xF0, { 0x6A } }, sync = { 0xF2, { 0xB9 } },
  param2 = { 0xF7, { 0xA3 } }, param3 = { 0xFC, { 0xC7, 0x05 } }, queue = 0x106, epilogue = 0x10B,
}
K.TOWER_4, K.TOWER_5 = 77, 78            -- the building types a tower engine can stand on
-- The preview of the same tools with the mouse button up: `cmp esi,ebx / je <see-through> /
-- imul esi,esi,0x32C`; the solid preview's `push 5` follows at +0x4B, the see-through one's
-- `push 0x100005` at +0x66.
K.AOB_TOWER_ENGINE_PREVIEW = "3B F3 74 62 69 F6 2C 03 00 00 0F BF"
K.TOWER_PREVIEW = { size = 10, solid = { 0x4B, { 0x6A, 0x05, 0x50, 0x53, 0x53 } },
  clear = { 0x66, { 0x68, 0x05, 0x00, 0x10, 0x00 } }, flags = { 0x3A, { 0xF7, 0x04, 0x85 } } }
-- The map editor's unit tool: `mov [esp+0x14], <tile flags that refuse a unit>` (sea, rocky,
-- building, tree, river, moat, ...); a tower engine goes only where a unit could.
K.AOB_UNIT_MASK = "89 54 24 18 89 7C 24 20 C7 44 24 14 ? ? ? ? 0F 87"
K.UNIT_MASK = 12
K.TOWER_ENGINE_UNITS = { [41] = true, [61] = true }   -- mangonel, ballista
-- ClickPlaceSiegeTent's building test: `movsx eax,word [edx*2+buildings on tiles] / test eax,eax /
-- pop ebp / je / imul eax,eax,0x32C / cmp byte [eax+has engine],0 / jne <refuse>`.
K.AOB_ENGINE_BUSY = "0F BF 04 55 ? ? ? ? 85 C0 5D 74 13 69 C0 2C 03 00 00 80 B8 ? ? ? ? 00 0F 85"
K.ENGINE_BUSY = { site = 0x13, size = 13, field = 2, jump = 9 }
-- The eraser's walk over a tile's units: `imul eax,eax,<unit size> / mov word [eax+state],3 /
-- movsx eax,word [eax+next on tile] / test eax,eax / jne`; the next unit lies 0x216 after the
-- state word (both exes).
K.AOB_UNIT_WALK = "69 C0 ? ? ? ? ? ? ? ? ? ? ? ? ? 0F BF 80 ? ? ? ? 85 C0 75 E6"
K.UNIT_WALK = { stride = 2, next = 18, nextAfterState = 0x216 }
-- How many tower engines a building takes (its own big towers go by the game's own rule, one):
-- the keeps 4 and the stronghold keeps 8, the large gatehouse 4, any other building one.
K.TOWER_ENGINE_MOST = { [40] = 4, [41] = 4, [42] = 4, [43] = 8, [44] = 8, [45] = 4 }
-- Keep parts: placeKeep places the keep and its doors, then (`mov eax,[esp+0x3C] / mov ecx,
-- [esp+0x48] / add ebx,[eax*8+..]`) the campfire area, then (`mov eax,[esp+0x3C] / mov edi,
-- [eax*8+..]`) the stockpile; both lead on to the same epilogue.
K.AOB_KEEP_CAMPFIRE = "8B 44 24 3C 8B 4C 24 48 03 1C C5 ? ? ? ? 03 3C C5"
K.AOB_KEEP_STOCKPILE = "8B 44 24 3C 8B 3C C5 ? ? ? ? 8B 1C C5 ? ? ? ? 03 7C 24 24"
K.KEEP_CAMPFIRE_SIZE, K.KEEP_STOCKPILE_SIZE = 8, 11
-- placeKeep's ground painter calls (keep tiles, campfire area): `push 2 / push 0 / push 6 / add
-- reg,ebx / push reg / push eax / push ebp / mov ecx,esi / call paint` (thiscall, 6 arguments).
-- Building rotation (44.2). The game's building orientation (TriggerPlaceBuilding: `cmp ecx,0x92 /
-- mov eax,0x51 / je / mov eax,[orientation]`), which the placement command, the placement
-- preview and the AI's AIV placement read; values 0, 2, 4, 6 (0xF: default). The keep's turn at
-- the start of a match (setKeepOffsetAndOrientation): the direction from the keep to (200, 200)
-- (`push 200 / ... / mov ecx,direction / ... / call / mov eax,[direction result] / and eax,0xFFFE`),
-- 2 and 6 swapped.
K.AOB_ORIENTATION = "81 F9 92 00 00 00 B8 51 00 00 00 74 05 A1 ? ? ? ?"
K.ORIENTATION = 14
K.AOB_KEEP_TURN = "68 C8 00 00 00 8D 50 D5 68 C8 00 00 00 51 89 56 28 8D 51 D5 89 4E 34 50 B9 ? ? ? ? 89 46 30 89 56 2C E8 ? ? ? ? A1 ? ? ? ? 25 FE FF 00 00"
K.KEEP_TURN = { this = 25, call = 35, result = 41 }
K.MAP_CENTRE = 200
-- placeBuilding: `cmp eax,0xF / jne / mov [esi+rotation],edx / jmp / cdq / sub eax,edx / sar eax,1 /
-- mov [esi+rotation],eax`: TileMapState's placement rotation (orientation / 2), which the placement
-- check - and so the cursor preview with the keep's parts - reads.
-- The keep layout tables (3 keep types x 4 orientations): doors etc. 24 bytes a row (the preview's
-- `movsx edx,ax / add edx,-0x3C / lea ecx,[edx+edx*2] / shl ecx,5 / add ecx,TABLE`), the campfire
-- area and the stockpile 8 bytes a row (placeKeep's `add ebx,[eax*8+..]` / `mov edi,[eax*8+..]`);
-- the preview's call `mov ecx,[..] / mov edx,[..] / push ecx / push esi / push eax / push edx /
-- mov ecx,TileMapState / call setConstructionGFXLayerBasedOnPlacementChecks`.
K.AOB_KEEP_TABLE_A = "0F BF D0 83 C2 C4 8D 0C 52 C1 E1 05 81 C1 ? ? ? ?"
K.AOB_PREVIEW_CALL = "8B 0D ? ? ? ? 8B 15 ? ? ? ? 51 56 50 52 B9 ? ? ? ? E8"
K.KEEP_TABLES = { a = 14, b = 18, c = 7, call = 21, rows = 3 }
-- Only buildings placed as several parts turn (placeBuilding's own placers, by building type):
-- barracks 8/9, engineers' guild 24, tunnellers' guild 25, oil smelter 28, keeps 40-44. The chosen
-- tool (TriggerPlaceBuilding `mov ecx,[tool] / cmp ecx,0x65 / mov edx,..`) and
-- convertCommandBuildingTypeToBuildingType (`push ebx / mov ecx,BuildingsState / mov [..],edx /
-- call`).
K.ROTATING_TYPES = { [8] = true, [9] = true, [24] = true, [25] = true, [28] = true, [40] = true, [41] = true,
  [42] = true, [43] = true, [44] = true }
K.AOB_CHOSEN_TOOL = "8B 0D ? ? ? ? 83 F9 65 8B 15"
K.AOB_TOOL_TYPE = "53 B9 ? ? ? ? 89 96 ? ? ? ? E8"
K.TOOL_TYPE = { this = 2, call = 12 }
K.AOB_PLACE_ROTATION = "83 F8 0F 75 08 89 96 ? ? ? ? EB 0B 99 2B C2 D1 F8 89 86 ? ? ? ?"
K.PLACE_ROTATION = 7
K.ROTATIONS = { { "Default" }, { "90\xB0", 2 }, { "180\xB0", 4 }, { "270\xB0", 6 }, { "Location based", "location" } }
K.ROTATION_BOX = { x = 12, y = 420, width = 150, height = 22, option = 20 }
-- The right-click ring's compass (45): `cmp eax,3 / jne / mov edx,[next] / push edx / mov ecx,
-- TileMapState / call setMapRotation` (in a match) and the same with eax (map editor); it draws
-- its picture with `add ecx,[..] / add edi,0x26 / push ecx / push edi / push 0x10 / mov ecx,
-- textures / call renderGM`, picture 0x26 + 0, 3, 2, 1 for the orientations 0, 2, 4, 6.
K.AOB_COMPASS_TURN = { { "83 F8 03 75 23 8B 15 ? ? ? ? 52 B9 ? ? ? ? E8", "compassTurnEdx", 6 },
  { "83 F8 03 75 12 A1 ? ? ? ? 50 B9 ? ? ? ? E8", "compassTurnEax", 5 } }
K.COMPASS_TURN_SITE = 5
K.AOB_COMPASS_DRAW = "03 0D ? ? ? ? 83 C7 26 51 57 6A 10 B9 ? ? ? ? E8"
K.COMPASS_DRAW = { first = 8, gm = 12 }
K.COMPASS_PICTURE = { [0] = 0, [2] = 3, [4] = 2, [6] = 1 }
-- Unit display player (46.1): PlaceUnit's single unit `push ecx / push eax / push eax / mov ecx,
-- UnitsState / call spawnUnit / pop edi ...`; the panel shows in the castle tabs 26 and 29.
K.AOB_UNIT_COLOUR = "51 50 50 B9 ? ? ? ? E8 ? ? ? ? 5F 5E 5D 5B 83 C4 1C C3"
K.UNIT_COLOUR = { site = 1, size = 7, units = 3 }
K.UNIT_TABS = { [26] = true, [29] = true }
K.UNIT_COLOUR_PANEL = { x = 330, gap = 4, label = "Unit display player:", selectedLabel = "Selected units:", above = 58 }
-- The group spawner (TribesState, VAN 0x523030) the castle's unit tools use: `push ebx / push ebp /
-- push edi / push edi / mov ecx,UnitsState / call spawnUnit / mov esi,eax / test esi,esi / je`.
K.AOB_GROUP_COLOUR = "53 55 57 57 B9 ? ? ? ? E8 ? ? ? ? 8B F0 85 F6 74 1E"
K.GROUP_COLOUR = { site = 2, size = 7, units = 3, sites = 2 }
-- Selected units (46.2): UnitsState + 0x24 + player * 4 counts each player's selection; a unit
-- (0x490 bytes, the walk's state word at +0x8C) is alive with state 2, selected by the player in
-- its word +0xB2 (0: by nobody, so player 0 cannot select), drawn in the colours of +0x80.
K.SELECTION = { counts = 0x24, state = 0x8C, alive = 2, selectedBy = 0xB2, colour = 0x80 }
-- Map size changes (47): the size action's tail `mov ecx,TileMapState / call / mov ecx,X /
-- mov [..],1 / call / push 1 / mov ecx,X / call`, patched at its second `mov ecx`; the map load's
-- viewport calls `mov ecx,viewport / mov [..],ebp / mov [..],edx / call bounds / mov ecx,viewport /
-- call build / mov ecx,viewport / call tweak`; the camera clamp in setViewportBasedOnMapSize.
K.AOB_SIZE_TAIL = "B9 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? C7 05 ? ? ? ? 01 00 00 00 E8 ? ? ? ? 6A 01 B9 ? ? ? ? E8"
K.SIZE_TAIL = { site = 10, size = 5 }
K.AOB_VIEWPORT_LOAD = "B9 ? ? ? ? 89 2D ? ? ? ? 89 15 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? E8"
K.VIEWPORT_LOAD = { viewport = 1, bounds = 17, build = 27, tweak = 37 }
K.AOB_CAMERA_CLAMP = "39 51 78 7D 03 89 51 78 39 79 78 7E 03 89 79 78 39 71 7C"
K.CAMERA_CLAMP = { size = 8 }
K.CAMERA_EDGE = { x = 32, y = 16 }
-- ... and the load's `push ebx / mov ecx,esi / call toggleFlatView / mov [..],ebx / mov [..],ebx /
-- call setChangedLayerToThreeAndMapping0x40x40` (every tile drawn afresh).
K.AOB_ALL_CHANGED = "53 8B CE E8 ? ? ? ? 89 1D ? ? ? ? 89 1D ? ? ? ? E8"
K.ALL_CHANGED = 20
-- ... and before those viewport calls the load clears the tiles' drawn pictures (`push pictures /
-- push ebx / push 0x27420 / mov ecx,memory / mov [..],edi / call fillMemory_ByteValue`, thiscall,
-- 3 arguments): tiles the new size leaves out keep none (black), the rest are drawn afresh.
-- The map size word: the size action's `push eax / mov ecx,TileMapState / mov [size],eax`.
K.AOB_SIZE_WORD = "50 B9 ? ? ? ? A3 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? E8 ? ? ? ? B9 ? ? ? ? C7 05"
K.SIZE_WORD = 7                          -- then `call resetHeightAndMapBorders` at +11       -- one tile, in the viewport's camera units
K.AOB_KEEP_GROUND = { "6A 02 6A 00 6A 06 03 D3 52 50 55 8B CE E8", "6A 02 6A 00 6A 06 03 CB 51 50 55 8B CE E8" }
K.KEEP_GROUND_CALL = 13
K.KEEP_EPILOGUE = { 0x78, { 0x5F, 0x5E, 0x5D, 0x5B, 0x83, 0xC4, 0x1C, 0xC2, 0x1C, 0x00 } }
K.KEEPS = { 60, 61, 62 }
K.KEEP_ONLY, K.KEEP_NO_STOCKPILE = 1, 3   -- the keep panel's choices
K.KEEP_LABELS = { [1] = "Keep only", [3] = "No stockpile" }
-- Damaged walls: placeWalls, after a tile is built or repaired (`mov ecx,[esp+0x44] / push esi /
-- push ecx / mov ecx, PathFindingState / call ...`; esi the tile, edi TileMapState), and its
-- repair test `cmp byte [esi+edi+damage], 0 / jne / test ebp,ebp / je`.
K.AOB_WALL_TILE_DONE = "56 8B CF E8 ? ? ? ? 8B 54 24 44 8B 44 24 20 52 50 6A 07"
K.WALL_TILE_DONE_SIZE, K.WALL_CLEAR_MOAT_CALL = 8, 3
-- ... and the damage byte the wall drawing reads (updateGfxLayer: `movsx edx, byte [ecx+eax+
-- damage] / test edx,edx / je`). The repair test inside placeWalls is patched by smarter-walls,
-- and so is the instruction before the site above, which it also checks.
K.AOB_WALL_DAMAGE = "0F BE 94 01 ? ? ? ? 85 D2 74"
K.WALL_DAMAGE_OPERAND = 4
K.WALLS = { 27, 46, 25, 26 }             -- stairs, low wall, high wall, crenellated wall
K.TAB_CASTLE = 10
K.DAMAGED_LABEL = "Damaged"

-- The ruined cathedral (see docs/ruined-cathedral.md): UpdateCathedral gives a cathedral its
-- ruined picture only in historical mission 7, by setting its picture field and a flag and
-- redrawing it - `cmp word [ecx+FLAG],bx / mov eax,RUINED / je / cmp [ecx+PICTURE],eax / je /
-- mov word [ecx+FLAG],1 / mov [ecx+PICTURE],eax / push esi / mov ecx, TileMapState / call
-- updateBuildingGraphicsLayer` (ecx: the building's id * its size). The module does the same to
-- a cathedral placed while "Ruined" is chosen (C.ruinWatch).
K.CATHEDRAL_TOOL, K.CATHEDRAL_TYPE, K.RUINED_LABEL = 97, 0x26, "Ruined"
K.AOB_RUINED_CATHEDRAL = "66 39 99 ? ? ? ? B8 ? ? ? ? 74 08 39 81 ? ? ? ? 74 ? 66 C7 81 ? ? ? ? 01 00 89 81 ? ? ? ? "
  .. "56 B9 ? ? ? ? E8"
K.RUINED_CATHEDRAL = { flag = 3, picture = 8, pictureField = 0x10, tileMap = 0x27, update = 0x2B }
K.LAST_PLACED = 0x554888
K.TYPE_AFTER_PICTURE = 0xD2              -- a building's type word, from its picture field
K.GM_AFTER_PICTURE = 0x04                -- and its gm (spriteSheetID)
K.RUIN_PARTS = 169                       -- the ruin's pictures, one per tile of the 13 x 13 cathedral

-- Moat. The gatehouses tab's moat buttons (106, 107) choose 0x2D (dig) and 0x2C (remove) in the
-- map editor; the click sends ClickSetTerrain with terrain 0x40000000 and a mode: 0 planned
-- moat, 1 plan removed (the game's), 2 dug moat, 3 moat removed (the editor's). The module adds
-- mode 4: dug moat without an entry in the moat list, which nothing can fill in or delete.
K.TAB_GATEHOUSES = 12
K.MOAT_BUTTON, K.MOAT_TOOL = 106, 0x2D
K.MOAT_DUG, K.MOAT_PLANNED, K.MOAT_PERMANENT = 0, 1, 2     -- the panel's choices
K.MOAT_LABELS = { [0] = "Dug", [1] = "Planned", [2] = "Permanent" }
K.MOAT_PERMANENT_MODE = 4
K.MOAT_FLAGS, K.MOAT_DUG_FLAG = 0x40004000, 0x40000000      -- planned or dug, dug
K.GROUND_HEIGHT = 8                                         -- what removeMoat gives a filled tile
K.PLAIN2_FLAG = 0x8                                         -- dug moat clears it too
-- TriggerPlaceBuildingCommand, the editor's moat click: `xor ecx,ecx / cmp eax,0x2D / setne cl /
-- push 0x15 / add ecx,2 / mov [command param 4],ecx` (2 dig, 3 remove).
K.AOB_MOAT_CLICK = "33 C9 83 F8 2D 0F 95 C1 6A 15 83 C1 02 89 0D"
K.MOAT_CLICK_SIZE = 8
-- setTerrain's moat branch, after its tests (`... movzx eax, byte [edx+HEIGHT] / cmp eax,12 / jle
-- / jmp <skip>`): `cmp dword [ebp+0x1C],0 / jne NEXT` picks the mode (ebp-0x20 TileMapState,
-- ebp+0xC the tile, ebp-0xC x, ebp+0x10 y). NEXT (mode 1) calls clearMoatDataAtTile at +0x46;
-- the mode 0 code ends with a jmp to the branch's end; the mode 2/3 code writes the decoration
-- byte at NEXT+0x80.
K.AOB_MOAT_MODE = "8B 55 E0 03 55 0C 0F B6 82 ? ? ? ? 83 F8 0C 7E 05 E9 ? ? ? ? 83 7D 1C 00 75 52"
K.MOAT_MODE = { site = 23, size = 6, height = 9, logic = 9, clear = 0x46, done = 0x4D, decoration = 0x80 }
-- The same branch's marsh test: `mov eax,[edx+ecx*4+LOGIC] / and eax,0x20000000 / je +5 / jmp <skip>`.
K.AOB_MOAT_MARSH = "8B 84 8A ? ? ? ? 25 00 00 00 20 74 05 E9"
K.MOAT_MARSH = { site = 7, size = 5 }

-- The pipette. Its tool id is above the landscape click handler's last case (0x155: anything
-- higher does nothing) and outside getBuildingSizeForCommandBuildingType's range (0x2C-0x172),
-- and no wall tool; renderPreviewMapperWithBrush shows it as the plain brush.
K.PIPETTE_TOOL = 0x1F4
K.NO_TOOL = 0xFFFFFFFF
K.PIPETTE_HEIGHTS, K.PIPETTE_TEXTURES, K.PIPETTE_OBJECTS, K.PIPETTE_ALL = 1, 2, 3, 4
K.PIPETTE_MODES = {
  { label = "Heights", what = "heights", image = 240 },        -- the Heights category's picture
  { label = "Textures", what = "textures", image = 241 },      -- the Textures category's picture
  { label = "Objects", what = "building, wall, tree or rock", image = 242 }, -- the Objects category's picture
  { label = "All", what = "textures, heights and 1x1 tree or rock" },          -- the pipette's own picture
}
-- The objects pipette takes a building or wall and then simply chooses that tool: the game's own
-- building and wall handlers (also in the landscape menu's item table) show and place it; the
-- landscape click handler only acts on its own tools (36-49, shrubs, foam, rocks, animals).
-- Buildings: building layer -> building (stride and type field from updateLogicalTileMapRelated-
-- Sections: `movsx eax, word [esi+edi*2+LAYER] / test eax,eax / je / imul eax,eax,STRIDE / cmp
-- word [eax+TYPE],0x31`) -> convertBuildingTypeToCommandBuildingType (`mov eax,[esp+4] / add
-- eax,-1 / cmp eax,0x6A / ja`, 0 for none).
K.AOB_BUILDING_TYPE = "0F BF 84 7E ? ? ? ? 85 C0 74 ? 69 C0 ? ? ? ? 66 83 B8 ? ? ? ? 31"
K.BUILDING_TYPE = { stride = 14, type = 21 }
K.AOB_COMMAND_OF_TYPE = "8B 44 24 04 83 C0 FF 83 F8 6A 0F 87"
K.BUILDINGS_STATE = 0x17                 -- in K.AOB_BUILDING_SPRITES: `mov ecx, BuildingsState`
-- Walls by their tile flags: stairs, crenellation, wall (high wall 90 above the ground, low 60).
K.STAIRS_FLAG, K.CRENEL_FLAG, K.WALL_FLAG, K.STOCKPILE_FLAG = 0x800, 0x200, 0x100, 0x2
K.STAIRS_TOOL, K.CRENEL_TOOL, K.HIGH_WALL_TOOL, K.LOW_WALL_TOOL = 27, 26, 25, 46
K.HIGH_WALL_ABOVE = 75
-- Whose a building or wall is: a building's owner word follows its type (+0xD2, +0xD6); a wall
-- tile's owner is the low 3 bits of the wall owner layer, player - 1. The editor places for the
-- player chosen with the shields beside the minimap (InGameMenu_MainButtons, map editor only):
-- `mov eax,-9 / sub eax,esi / pop edi / mov [eax*4+FLAGS],ebx / pop esi / mov [CURRENT],eax`,
-- after clearing all nine shield flags.
K.OWNER_AFTER_TYPE = 4
K.WALL_OWNER_BITS = 7
K.AOB_PLAYER_CHOICE = "B8 F7 FF FF FF 2B C6 5F 89 1C 85 ? ? ? ? 5E A3"
-- Player 0's shield (castle menu): between the 4 x 2 shields (menu x 719/757, y 462..561), its
-- clickable item before their group (the menu stops at the first item under the mouse) and its
-- picture drawn after it, on top. The first shield is the group member with parameter -10.
K.SHIELD_ZERO = { x = 738, y = 511, firstParam = -10, players = 9 }
-- The keep crests (castle mode): each keep shows its owner's shield above it, chosen look for the
-- player's active keep; a click makes it the active keep, or leaves the player without one.
-- A player's keep is GameState's BuildingEntryInfo {id, entry x, entry y, tile, area, ...} at
-- +0x30DD4 + player * player size (category 0; its campfire is category 8, 8 entries further),
-- set by computeBuildingCategoryEntryPointAndDestroyEarlierBuilding(building, player, category),
-- which placeKeep calls as `push eax / mov ecx, GameState / mov [esp+0x40],eax / call`.
K.AOB_KEEP_ENTRY_CALL = "50 B9 ? ? ? ? 89 44 24 40 E8"
K.KEEP_ENTRY = { state = 2, call = 10, first = 0x30DD4, entry = 0x28, dwords = 10, campfire = 8, stockpile = 1,
  strideAt = { 0x24, { 0x69, 0xC0 } } }
K.KEEP_TYPES = { [40] = true, [41] = true, [42] = true, [43] = true, [44] = true }
K.CAMPGROUND_TYPE = 55                   -- the keep's campfire area (not the barrier's campfire)
K.STOCKPILE_TYPE = 10
-- Building fields from the start of a building (BuildingsState + 0x14 is building 0).
K.BUILDING = { first = 0x14, type = 0xD2, owner = 0xD6, x = 0xEE, y = 0xF0, size = 0xF8, uid = 0x2A8 }
K.CREST = { lift = 120, rects = 40, selected = 8 }
-- The crest tooltip's lines ({player}: "player N"); gap: between crest and box.
K.CREST_TOOLTIP = {
  gap = 4,
  active = { "Active keep of {player}", "The lord, the starting units and new peasants appear here.",
    "Click: leave {player} without an active keep." },
  other = { "Keep of {player}", "Click: make this the active keep, where the lord,",
    "the starting units and new peasants appear." },
}
-- Wall tools (35): placeWalls' `cmp dx,0x19 / jne / add byte [esi+edi+LIVE],0x5A / jmp / cmp dx,0x2E /
-- jne / add byte [..],0x3C` (high and low wall heights); its high crenellation add followed by
-- the join point of every crenellation height, `mov eax,[esp+0x20] / and eax,1`; the stairs'
-- first step `mov eax,[esp+0x24] / sub eax,edx / sub eax,0x10`; the per-step drop `mov eax,0x10 /
-- cmp [esp+..],eax / jle / sub [esp+..],eax` in renderWallDragPreview, validateWallBuildPath and
-- placeWalls; validateWallBuildPath's two isTileEnclosedByWalls answers for crenellations
-- (`test eax,eax / mov edx,ecx / jne` and `call / test eax,eax / jne / pop ebx`, refusing with
-- reason 0x13 otherwise).
K.WALL_SITES = {
  heights = { aob = "66 83 FA 19 75 0D 80 84 3E ? ? ? ? 5A E9 ? ? ? ? 66 83 FA 2E 75 0D 80 84 3E ? ? ? ? 3C",
    high = 13, low = 32 },
  crenel = { aob = "80 84 3E ? ? ? ? 62 8B 44 24 20 83 E0 01", join = 8, live = 3 },
  first = { aob = "8B 44 24 24 2B C2 83 E8 10 85 C0 7E", at = 8 },
  steps = {
    { aob = "83 6C 24 18 01 B8 10 00 00 00 39 44 24 20 7E 0B", at = 6 },
    { aob = "83 6C 24 20 01 B8 10 00 00 00 39 44 24 24 7E 04 29 44 24 24", at = 6 },
    { aob = "29 44 24 28 B8 10 00 00 00 39 44 24 24 7C 04 29 44 24 24", at = 5 },
  },
  free1 = { aob = "85 C0 8B D1 75 B1 5B 5F 5E C7 82 ? ? ? ? 13 00 00 00" },
  free2 = { aob = "E8 ? ? ? ? 85 C0 75 3A 5B 5F 5E C7 81 ? ? ? ? 13 00 00 00", at = 5 },
}
K.HIGH_WALL, K.LOW_WALL, K.CRENEL_WALL, K.STAIRS = 25, 46, 26, 27
K.WALL_DEFAULT = { [25] = 0x5A, [46] = 0x3C, [27] = 16 }
K.STAIR_STEP = 16
K.CRENEL_LOW_HEIGHT, K.CRENEL_HIGH_HEIGHT = 0x44, 0x62
K.CRENEL_DAMAGED, K.CRENEL_LOW, K.CRENEL_HIGH, K.CRENEL_LOW_DAMAGED, K.CRENEL_HIGH_DAMAGED = 1, 2, 3, 4, 5
K.CRENEL_LABELS = { { 2, "Low" }, { 3, "High" }, { 4, "Low damaged" }, { 5, "High damaged" } }
K.WALL_SLIDER = { track = 150, height = 24, trackHeight = 10, panelRoom = 70, textRaise = 7, reset = "Reset" }
K.PLAYER_CHOICE = { flags = 11, current = 17 }
-- ...but in the landscape editor (screen 0xC) ClickPlaceBuilding places for its own player
-- variable instead (the castle screen for the command's sender): `cmp [screen],0xC / ... / mov
-- edx,[editor player] / ... / je / mov edx,[sender]`.
K.AOB_EDITOR_PLAYER = "83 3D ? ? ? ? 0C 8B 15 ? ? ? ? A1 ? ? ? ? 8B 0D ? ? ? ? 50 A1 ? ? ? ? 89 15 ? ? ? ? "
  .. "0F B7 15 ? ? ? ? 51 8B 0D ? ? ? ? 52 8B 15"
K.EDITOR_PLAYER = 53
K.PLAYERS = 8
-- Trees and rocks: the organism layer holds a tree's slot (tile flag 0x1000) or a rock's slot +
-- 2000. The pipette places one the way the landscape editor's command 0x1A ends: placeRock(x,
-- y, rock number) or placeTree(x, y, tree tool) on the tile map, called straight away (a queued
-- command runs later, after the stage, logs and turn set for it would be back): `movzx eax, word
-- [param 3] / mov ecx,[param 1] / mov edx,[param 0] / push eax / push ecx / push edx / mov ecx,
-- TileMapState / call placeRock / ret / ... / call placeTree`. placeRock makes rock number n into rock type n + 1
-- (sizes 1 to 4 for numbers 0-3, 4-7, 8-11, 12-15); a rock slot keeps its type at +0x10 and
-- its turn at +0x18, which placeRock takes from the tile map's rotation.
K.TREE_FLAG = 0x1000
-- Where renderMap draws a tile on the map surface (see the skill's notes on the screen transform):
-- per map turn the constants of drawX = cx + xd*(x-y) + xs*(x+y) - 32*C and drawY = bias + cy +
-- yd*(x-y) + ys*(x+y) - 16*R, C and R from the viewport position; the tile's height lifts it by
-- heightBasedScreenYOffset[height] (TileMapState + 0x3840). Viewport fields: x, y, zoomed out,
-- row bias.
K.SCREEN_TURN = {
  [0] = { cx = 3334, xd = 16, xs = 0, cy = 8 - 1592, yd = 0, ys = 8 },
  [6] = { cx = 9718, xd = 0, xs = -16, cy = 8 + 1600, yd = 8, ys = 0 },
  [4] = { cx = 3334, xd = -16, xs = 0, cy = 8 + 4792, yd = 0, ys = -8 },
  [2] = { cx = -3050, xd = 0, xs = 16, cy = 8 + 1600, yd = -8, ys = 0 },
}
K.VIEWPORT = { x = 0x78, y = 0x7C, zoomedOut = 0x90, bias = 0x94 }
K.HEIGHT_OFFSETS = 0x3840
K.FLAT_HEIGHT_OFFSET = 8                 -- renderMap's flattened view: every tile at this offset
K.TILE_WIDTH, K.TILE_HEIGHT = 32, 16
K.TREE_PICTURE = 0x00                    -- a tree slot's current picture (UpdateTree keeps it)
K.TREE_GM = 0x04                         -- and its gm
-- renderMap draws a tree at its tile + (14, 6) - its gm's origin; createTree reads the origin
-- from the gm's header: `movsx edx, word [ecx+0x20] / imul edx,edx,STRIDE / mov bx,[edx+X] / mov
-- [ecx+0x28],bx / movzx edx, word [edx+Y] / mov [ecx+0x2A],dx`.
K.AOB_TREE_ORIGIN = "0F BF 51 20 69 D2 ? ? ? ? 66 8B 9A ? ? ? ? 66 89 59 28 0F B7 92 ? ? ? ? 66 89 51 2A"
K.TREE_ORIGIN = { stride = 6, x = 0x0D, y = 0x18 }
K.TREE_DRAW_X, K.TREE_DRAW_Y = 14, 6
-- The rock tool's variant and size (0-3) in the tile map (rock number = size * 4 + variant), and
-- a rotation mode that leaves the rock rotation alone (5 turns it every frame, 0 every second).
K.ROCK_VARIANT_AT, K.ROCK_SIZE_AT, K.FIXED_TURN = 0x5548F4, 0x5548F8, 1
K.AOB_PLACE_PLANT = "0F B7 05 ? ? ? ? 8B 0D ? ? ? ? 8B 15 ? ? ? ? 50 51 52 B9 ? ? ? ? E8 ? ? ? ? C3 "
  .. "8B 0D ? ? ? ? 50 A1 ? ? ? ? 50 51 B9 ? ? ? ? E8"
K.PLACE_PLANT = { placeRock = 0x1B, placeTree = 0x34 }
K.ROCK_SLOT = { type = 0x10, turn = 0x18, inUse = 0x0C }
K.ROCK_TYPES = 16
K.PLANT_NAMES = { [40] = "chestnut", [41] = "oak", [42] = "pine", [43] = "birch" }
-- Names for the line above the pipette panel, by tool.
K.OBJECT_NAMES = {
  [25] = "high wall", [26] = "crenellated wall", [27] = "stairs", [46] = "low wall", [50] = "fletcher",
  [51] = "woodsman", [52] = "stockpile", [53] = "outpost bedouin", [54] = "hovel", [55] = "ox tether",
  [56] = "quarry", [57] = "tunnel", [58] = "campfire", [59] = "signpost", [60] = "keep", [61] = "keep",
  [62] = "keep", [63] = "keep", [64] = "keep", [65] = "stables", [66] = "tunnel construction",
  [70] = "wheatfarm", [71] = "hopsfarm", [72] = "applefarm", [73] = "cattlefarm", [74] = "mill",
  [75] = "baker", [76] = "brewer", [77] = "tradepost", [78] = "hunter", [79] = "bedouin stockade",
  [80] = "granary", [81] = "armoury", [82] = "poleturner", [83] = "blacksmith", [84] = "armourer",
  [85] = "tanner", [86] = "barracks", [87] = "mercenary post", [88] = "engineers guild",
  [89] = "tunnelers guild", [90] = "iron mine", [91] = "pitch rig", [92] = "inn", [93] = "healer",
  [94] = "siege tower base", [95] = "chapel", [96] = "church", [97] = "cathedral",
  [98] = "killing pit", [99] = "pitch ditch", [100] = "gatehouse", [101] = "large gatehouse",
  [102] = "small gatehouse", [103] = "wooden gatehouse", [104] = "postern gate", [105] = "drawbridge",
  [106] = "moat", [107] = "antimoat", [108] = "generic", [109] = "quarrypile", [110] = "lookout tower",
  [111] = "perimeter turret", [112] = "defence turret", [113] = "square tower", [114] = "round tower",
  [115] = "tower1 ruin", [116] = "tower2 ruin", [117] = "tower3 ruin", [118] = "tower4 ruin",
  [119] = "tower5 ruin", [120] = "flag type0", [121] = "flag type1", [122] = "flag type2",
  [123] = "flag type3", [124] = "flag type4", [125] = "flag type5", [126] = "flag type6",
  [127] = "flag type7", [128] = "flag type8", [129] = "heads", [190] = "catapult", [191] = "trebuchet",
  [192] = "siege tower", [193] = "battering ram", [194] = "portable shield"
}
-- The landscape menu's left column (UC_MAP_BRUSH 82,464 / UC_MAP_SNAP 82,507 / UC_MAP_DELETE
-- 82,552): the pipette on top, then brush size (and its second item, 331), ruler and eraser.
K.PIPETTE_COLUMN = { x = 82, tops = { 456, 490, 524, 562 }, moved = { { 1, 331 }, { 204 }, { 39 } } }
K.PIPETTE_TEXT_ABOVE = 22
K.PIPETTE_LABEL_ROOM = 15                -- a row above the panel's pictures for their labels
K.PIPETTE_ENTRY_WIDTH = 64               -- wide enough for "Textures" above its picture
K.MAP_SIZE, K.MAP_TILES = 400, 80400
-- TileMapState layers (the same offsets in both exes): decoration byte, building. The word layer
-- at +0x13DD40 (OpenSHC's RandomLayer, a saved map section) is each tile's own random number: the
-- renderers take its low bits (& 1, 3, 7, 15) to pick a picture, river foam and waves their
-- direction. Never copied: a tile whose ground changes gets a new random number.
K.TMS = { decoration = 0x1B3FE0, random = 0x13DD40, building = 0x2029B0, wallOwner = 0x2C6E50 }
K.RANDOM_LIMIT = 0x7FFF
K.MAP_BORDER = 0x30
-- The tile flags that are ground: sea, plain 1/2, earth, boulders, pebbles, iron, river, ford,
-- marsh, oil.
K.TEXTURE_FLAGS = 0xA03E800D
K.MASK_WATER = 0x00300001                -- sea, river, ford: their variants count as one
-- What the mask compares: the ground flags and the rocky flag (the Rocky texture is earth with
-- it). With water variants as one, a water tile's earth flag is dropped: a river running down a
-- slope (the waterfall edge) is river with earth.
K.MASK_FLAGS = 0xA03E808D
K.EARTH = 0x8000
-- Dust clouds (entity 0x15) step their x and y by `count % speed`; a cloud whose speeds are 0
-- divides by zero and takes the game down. In updateEntities, each step: `movsx ebp,dx / cdq /
-- jge GE` (x, after `cmp dx,bp`) and `movsx ebp,dx / test dx,dx / cdq / jge GE` (y), twice each.
K.AOB_DUST_X = "66 3B D5 0F BF EA 99 7D 0C F7 FD 85 D2 75 10 66 01 79 4C EB 0A F7 FD 85 D2 75 04 66 01 59 4C"
K.AOB_DUST_Y = "0F BF EA 66 85 D2 99 7D 0C F7 FD 85 D2 75 10 66 01 79 4E EB 0A F7 FD 85 D2 75 04 66 01 59 4E"
K.DUST_STEP = { x = 3, xSize = 6, ySize = 9, skip = 0x0A, sites = 2 }   -- skip: idiv, test, jne, add after GE
-- Heights stay off sea, walls, crenels, stairs, buildings, keeps, marsh and moat (and beach, a
-- decoration); textures off walls, crenels, stairs, buildings and keeps. Both stay off rocks,
-- but not off cliff rocks: in the map editor updateGfxLayer marks cliff edges rocky (0x80)
-- without a rock, and does so again wherever a cliff remains, so the pipette clears that flag.
K.HEIGHT_REFUSED = 0x70004F01
K.TEXTURE_REFUSED = 0x10000F00
K.ROCKY = 0x80
K.FIRST_ROCK_NUMBER = 2000               -- the organism layer: rock slot + 2000
-- useTerrainHeightBrush taking a rock off a tile it changes: `test byte [edi+ebp*4+LOGIC],0x80 /
-- je / movsx eax, word [edi+ebp*2+ORGANISM] / cmp eax,2000 / jl / add eax,-2000 / push eax /
-- mov ecx, LandscapeState / call removeRock`.
K.AOB_HEIGHT_ROCK = "F6 84 AF ? ? ? ? 80 74 1F 0F BF 84 6F ? ? ? ? 3D D0 07 00 00 7C 10 05 30 F8 FF FF 50 B9 ? ? ? ? E8"
K.HEIGHT_ROCK = { organism = 14, landscape = 32, remove = 36 }
K.BEACH_DECORATION = 0x20
K.RIVER_DEPTH = 8                        -- a river tile lies this far below its base height
K.WALK_RADIUS = 9                        -- what the height tools hand updateWalkAndPathLayer
K.TEXTURE_NAMES = { { 0x1, "sea" }, { 0x100000, "river" }, { 0x200000, "ford" }, { 0x20000000, "marsh" },
  { 0x20000, "boulders" }, { 0x40000, "pebbles" }, { 0x80000, "iron" }, { 0x80000000, "oil" },
  { 0x4, "plain 1" }, { 0x8, "plain 2" }, { 0x8000, "earth" } }
K.DECORATION_NAMES = { { 0x1, "scrub" }, { 0x2, "earth and stones" }, { 0x4, "plateau" }, { 0x8, "high plateau" },
  { 0x10, "oasis grass" }, { 0x20, "beach" }, { 0x40, "stones" }, { 0x80, "thick scrub" } }
K.RIVER_DECORATION_NAMES = { { 0x10, "foam" }, { 0x20, "small waves" } }
-- The landscape click handler: `cmp [click start],ebx / mov eax,[..] / jne / cmp [..],eax / je /
-- push ebp / mov ecx, viewport / mov [..],eax / call / cmp [click start],ebx / mov ebp,[..] /
-- mov ebx,[..] / mov esi,[mouse tile y] / mov edi,[mouse tile x]`; and its `cmp [click held],
-- ebx / jne` before the preview.
K.AOB_MOUSE_CLICK = "39 1D ? ? ? ? A1 ? ? ? ? 75 0C 39 05 ? ? ? ? 0F 84 ? ? ? ? 55 B9 ? ? ? ? A3 ? ? ? ? "
  .. "E8 ? ? ? ? 39 1D ? ? ? ? 8B 2D ? ? ? ? 8B 1D ? ? ? ? 8B 35 ? ? ? ? 8B 3D"
K.MOUSE_CLICK = { start = 2, y = 0x3D, x = 0x43 }
K.AOB_CLICK_HELD = "39 1D ? ? ? ? 0F 85 91 00 00 00 B9 ? ? ? ? E8 ? ? ? ? 8B 15"
K.CLICK_HELD = 2
-- The tile under the mouse, as the click handlers work it out before using it (from the tile
-- the renderer found under the cursor, so on raised ground too): `cmp [flat view],0 / mov ecx,
-- viewport / je / call setupMouseTileXY2 / jmp / call setupMouseTileXY`.
K.AOB_MOUSE_TILE = "83 3D ? ? ? ? 00 B9 ? ? ? ? 74 07 E8 ? ? ? ? EB 05 E8"
K.MOUSE_TILE = { flat = 2, viewport = 8, flatSetup = 14, setup = 21 }
-- renderPreviewMapperWithBrush: `mov edx,[esi+BRUSH] / mov eax,[edx*4+SIZES] / mov [esp+0x14],eax /
-- lea eax,[ebx+ebx*2] / mov eax,[eax*4+ROWS]`; its brush loop `push edx / push edi / push 1 /
-- mov ecx,esi / call getTileForBrush / ...`.
K.AOB_PIPETTE_PREVIEW = "8B 96 ? ? ? ? 8B 04 95 ? ? ? ? 89 44 24 14 8D 04 5B"
K.PIPETTE_PREVIEW = { size = 6, brush = 2, sizes = 9, rows = { 0x14, { 0x8B, 0x04, 0x85 } } }
K.AOB_BRUSH_TILE = "52 57 6A 01 8B CE E8 ? ? ? ? 8B 44 24 18 83 C7 01 3B 7C 24 1C 66 89 AC 46"
K.BRUSH_TILE_CALL = 6
-- useTerrainHeightBrush: per tile `push ebp / push ebx / mov ecx, PathFindingState / call
-- updatePathLinkagesInAllEightDirections`, after the loop `mov dword [edi+FLAG],1`; and its
-- height writes `mov al,[edi+ebp+HEIGHT] / mov [edi+ebp+DEFAULT],al / test [edi+ebp*4+LOGIC],river`.
K.AOB_HEIGHT_TAIL = "55 53 B9 ? ? ? ? E8 ? ? ? ? 8B 5C 24 1C 8B 74 24 2C 83 C6 01 3B 74 24 14 89 74 24 2C "
  .. "0F 8C ? ? ? ? C7 87 ? ? ? ? 01 00 00 00"
K.HEIGHT_TAIL = { pathFinding = 3, links = 7, flag = 0x27 }
K.AOB_HEIGHTS = "8A 84 2F ? ? ? ? 88 84 2F ? ? ? ? F7 84 AF ? ? ? ? 00 00 10 00"
K.HEIGHTS = { height = 3, default = 10, logic = 17 }
-- The height and terrain commands' end: `push 9 / mov ecx, PathFindingState / call
-- updateWalkAndPathLayer / push 2 / mov ecx, minimap / mov [macro layer flag],1 / call
-- triggerMinimapRedraw` (five commands share it).
K.AOB_HEIGHT_TOOL = "6A 09 B9 ? ? ? ? E8 ? ? ? ? 6A 02 B9 ? ? ? ? C7 05 ? ? ? ? 01 00 00 00 E8"
K.HEIGHT_TOOL = { walk = 7, minimap = 0x0F, macro = 0x15, redraw = 0x1D }
-- The tiles that are on the map, a byte per x, y (400 a row): the height commands' test `mov esi,
-- eax / imul esi,esi,400 / cmp byte [esi+ecx+VALID],0 / pop esi / je`.
K.AOB_TILE_VALID = "8B F0 69 F6 90 01 00 00 80 BC 0E ? ? ? ? 00 5E 74"
K.TILE_VALID = 11

-- The heights menu (features 28 and 29). Its tools: raise 2 and lower 3 (raiseLand, which hill
-- 37 and mountain 36 also call, with amount 1, once per tile of a spreading search), min 21 and
-- max 22 height (useTerrainHeightBrush: 8 or 156), equalize 23 (useLevelBrush), mid 47 and high
-- 48 plateau (createPlateau). The game still handles 22; only its button was taken out (the
-- iron button took its user control, 153, and its pictures follow min height's).
K.HEIGHTS_TAB = 231
K.RAISE_TOOL, K.LOWER_TOOL, K.EQUALIZE_TOOL = 2, 3, 23
K.MIN_HEIGHT_TOOL, K.MAX_HEIGHT_TOOL, K.MAX_HEIGHT_CONTROL = 21, 22, 153
K.HEIGHT_TOOLS = { 2, 3, 21, 22, 23, 36, 37, 47, 48 }
K.HEIGHTS_TOP_ROW = { 37, 36, 21 }       -- hill, mountain, min height (then max, then iron)
K.MAX_HEIGHT_NAME = "Max Height"
-- What a height tool does to a rock it touches: "Tile only" moves just the tiles under the brush,
-- "Whole rock" moves every tile of the rock by the same amount, "Erase rock" takes it away.
K.ROCK_TILE_ONLY, K.ROCK_WHOLE, K.ROCK_ERASE = 0, 1, 2
K.ROCK_MODES = { { K.ROCK_TILE_ONLY, "Tile only" }, { K.ROCK_WHOLE, "Whole rock" }, { K.ROCK_ERASE, "Erase rock" } }
K.ROCK_RECORDS = 1024                    -- rock tiles a whole-rock move remembers between frames
K.ROCK_REACH = 4                         -- a rock's tiles lie this far around its position at most
K.ROCK_POSITION = { x = 0x12, y = 0x14 } -- in a rock slot
-- Strength 1-16: raise and lower land by that much; equalize moves a tile by (difference to
-- the middle) / (17 - strength) + 1, so 7 is the game's own rate (/ 10).
K.STRENGTH_MOST, K.STRENGTH_SUM = 16, 17
K.STRENGTH_DEFAULTS = { [2] = 1, [3] = 1, [23] = 7 }
-- raiseLand, per tile: `and dword [esi+eax*4+LOGIC], ~0x80 / test [...],river / je / add [height],8`
-- (the rocky flag goes: a rock's tile turns invisible and walkable) and, further on, `mov bl,
-- [esp+0x24] / add [eax+esi+HEIGHT],bl / mov byte [eax+esi+DECORATION],0` (the amount, which wraps
-- below 0, and the ground's look going back to plain).
K.AOB_RAISE_AND = "81 A4 86 ? ? ? ? 7F FF FF FF F7 84 86 ? ? ? ? 00 00 10 00 74 08 80 84 30"
K.RAISE_AND = { size = 11, logic = 3 }
K.AOB_RAISE_ADD = "8A 5C 24 24 00 9C 30 ? ? ? ? C6 84 30 ? ? ? ? 00 0F B6 9C 30"
K.RAISE_ADD = { size = 19, height = 7, decoration = 14 }
-- useLevelBrush: the same `and`, and the step towards the middle height `mov ecx,esi / sub ecx,eax
-- / ... (/ 10) ... / add cl,bl / add cl,1 / jmp store` up and `movzx edx,cl / sub edx,esi / ...
-- / sub cl,al / sub cl,1` down, then `mov [height],cl / mov byte [DECORATION],0`.
K.AOB_LEVEL_AND = "81 A4 AF ? ? ? ? 7F FF FF FF 0F B6 84 2F ? ? ? ? 3B C6 7D 26"
K.LEVEL_AND = { size = 11, logic = 3 }
K.AOB_LEVEL_RISE = "8B CE 2B C8 B8 67 66 66 66 F7 E9 C1 FA 02 8B CA C1 E9 1F 03 CA 02 CB 80 C1 01 EB 24"
K.LEVEL_RISE = { size = 28, store = 0x40 }
K.AOB_LEVEL_FALL = "0F B6 D1 2B D6 B8 67 66 66 66 F7 EA C1 FA 02 8B C2 C1 E8 1F 03 C2 2A C8 80 E9 01 88 8C 2F"
K.LEVEL_FALL = { size = 27 }
K.AOB_LEVEL_DECORATION = "C6 84 2F ? ? ? ? 00 80 BC 2F ? ? ? ? 08 73 08 C6 84 2F ? ? ? ? 08 80 BC 2F ? ? ? ? 9C"
K.LEVEL_DECORATION = { size = 8, decoration = 3 }
-- createPlateau: the same `and` (`... / cmp eax,4 / jne`), and `mov [edi+ebp+DECORATION],al`
-- (the plateau look, 4 or 8).
K.AOB_PLATEAU_AND = "81 A4 AF ? ? ? ? 7F FF FF FF 83 F8 04 75 0A"
K.PLATEAU_AND = { size = 11, logic = 3 }
K.AOB_PLATEAU_DECORATION = "88 84 2F ? ? ? ? 89 AF ? ? ? ? 89 9F"
K.PLATEAU_DECORATION = { size = 7, decoration = 3 }
-- useTerrainHeightBrush (min and max height): `and byte [DECORATION],0xF3` (min only: the
-- plateau looks go), then for both `test byte [LOGIC],0x80 / je and` and the rock's removal
-- (K.AOB_HEIGHT_ROCK), the `and` at +0x29, the code after it at +0x34.
K.AOB_MIN_DECORATION = "80 A4 2F ? ? ? ? F3 F6 84 AF ? ? ? ? 80 74 1F"
K.MIN_DECORATION = { size = 8, decoration = 3 }
K.MIN_ROCK = { size = 10, logic = 3, andSite = 0x29, afterAnd = 0x34 }
-- The landscape editor's click: raise `mov dword [command param],1 / call queueCommand / ...`
-- and lower `mov dword [command param],-1 / push 0x14 / jmp`: the amounts the commands carry.
K.AOB_RAISE_AMOUNT = "C7 05 ? ? ? ? 01 00 00 00 E8 ? ? ? ? 5F 5E 5B C3 C7 05 ? ? ? ? 05 00 00 00 6A 1B"
K.AOB_LOWER_AMOUNT = "C7 05 ? ? ? ? FF FF FF FF 6A 14 E9"
K.AMOUNT_VALUE = 6
-- The heights panel above the menu, and the button that removes lost rocks.
-- The texture mask. setTerrain's tile loop starts `mov ecx,[ebp+0xC] / mov edx,[ebp-0x20] / mov
-- eax,[edx+ecx*4+LOGIC] / and eax,0x10 / je / jmp <next tile>` (the clicked tile is [ebp-0x1C]);
-- setLand's `mov esi,[esp+0x18] / mov eax,[edi+esi*4+LOGIC] / test al,0x30 / jne <next tile>`
-- (the clicked tile is ebx); setTerrain calls setLand first for the ground looks: `push edx /
-- mov eax,[ebp+0xC] / push eax / mov ecx,[ebp-0x20] / call setLand / cmp [ebp+0x18],0x40000000`.
K.AOB_MASK_TERRAIN = "8B 4D 0C 8B 55 E0 8B 84 8A ? ? ? ? 83 E0 10 74 02 EB 90"
K.MASK_TERRAIN = { size = 13, logic = 9, next = 0x13 }
K.AOB_MASK_LAND = "8B 74 24 18 8B 84 B7 ? ? ? ? A8 30 0F 85"
K.MASK_LAND = { size = 11, logic = 7, next = 0x0F }
K.AOB_MASK_CALL = "52 8B 45 0C 50 8B 4D E0 E8 ? ? ? ? 81 7D 18 00 00 00 40"
K.MASK_CALL = 8
-- ...and in the other nature tools, at the start of each tile: raiseLand (raise, lower, hill,
-- mountain) `mov eax,[esp+0x18] / mov ecx,[esi+eax*4+LOGIC] / test cl,0x30 / jne <next>`;
-- useLevelBrush, useTerrainHeightBrush and createPlateau `mov ebp,[esp+TILE] / mov eax,[edi+ebp*4+
-- LOGIC] / test al,0x30 / jne <next>` (told apart by what follows); placeTree `test [edi+ebp*4+
-- LOGIC],0x703E25B5 / mov / mov / mov / jne <leave>`; placeRock's start `push ecx / mov eax,[esp+8]`.
K.AOB_MASK_RAISE = "8B 44 24 18 8B 8C 86 ? ? ? ? F6 C1 30 0F 85"
K.MASK_RAISE = { size = 11, logic = 7, next = 0x10 }
K.AOB_MASK_LEVEL = "8B 6C 24 24 8B 84 AF ? ? ? ? A8 30 0F 85 ? ? ? ? 8B C8 81 E1 01 00 00 20"
K.AOB_MASK_MIN = "8B 6C 24 24 8B 84 AF ? ? ? ? A8 30 0F 85 ? ? ? ? A9 01 05 00 70"
K.AOB_MASK_PLATEAU = "8B 6C 24 20 8B 84 AF ? ? ? ? A8 30 0F 85 ? ? ? ? A9 01 04 00 70"
K.MASK_BRUSH = { size = 11, tile = 3, logic = 7, next = 0x0F }
K.MASK_LEVEL_CLICKED = 0x18                 -- useLevelBrush keeps the clicked tile there
K.AOB_MASK_TREE = "F7 84 AF ? ? ? ? B5 25 3E 70 89 44 24 18 8B 04 85 ? ? ? ? 89 44 24 14 89 6C 24 24 0F 85"
K.MASK_TREE = { size = 11, logic = 3, test = 7, leave = 0x20 }
K.AOB_MASK_ROCK = "51 8B 44 24 08 53 55 56 57 33 DB 33 FF 3D 8F 01 00 00"
K.MASK_ROCK = { size = 5 }
-- The mask button: at the top left of the menu's panel, right of the category buttons (menu
-- coordinates; the category buttons sit at user controls 137..182, 460).
K.MASK_BUTTON = { x = 240, y = 455 }
K.HEIGHT_PANEL = { gap = 14, slider = 112, rangeSlider = 256, sliderHeight = 10, dropdown = 6, optionHeight = 20,
  rowGap = 4 }
-- The height range of raise, lower and equalize (the game's: 8 .. 128 for raise and lower, 8 ..
-- 156 for equalize), Snap to range, Invert and the ignore boxes.
K.HEIGHT_RANGE_DEFAULT = { 8, 156 }
K.LEFT_BUTTON = 1                        -- VK_LBUTTON, for following a slider
K.WATER_FLAGS = 0x60304001               -- sea, river, ford, marsh, planned or dug moat
K.FARMLAND_LOOKS = 0x91                  -- scrub, oasis grass, thick scrub
-- raiseLand's limits for ordinary ground: `je / xor ecx,ecx / lea edx,[ecx+0x14] / jmp / mov ecx,8
-- / lea edx,[ecx+0x78]`.
K.AOB_RAISE_RANGE = "74 07 33 C9 8D 51 14 EB 08 B9 08 00 00 00 8D 51 78"
K.RAISE_RANGE = { site = 9, size = 8, lowest = 1, highestAdd = 7 }
-- useLevelBrush: its limits (8 and 0x9C), the first loop's height read (`mov eax,[esp+0x24] / test
-- [edi+eax*4+LOGIC],0x30 / jne next / movzx eax,byte [eax+edi+HEIGHT] / cmp eax,ebx`) and the
-- step's `jle <no step> / mov cl,[height]` for a tile at or above the middle.
K.AOB_LEVEL_RANGE = "C6 84 2F ? ? ? ? 00 80 BC 2F ? ? ? ? 08 73 08 C6 84 2F ? ? ? ? 08 80 BC 2F ? ? ? ? 9C 76 08 C6 84 2F ? ? ? ? 9C"
K.LEVEL_RANGE = { site = 8, size = 36, height = 3 }   -- after `mov byte [DECORATION],0`
K.AOB_LEVEL_AVERAGE = "8B 44 24 24 F6 84 87 ? ? ? ? 30 75 18 0F B6 84 38 ? ? ? ? 3B C3"
K.LEVEL_AVERAGE = { site = 0x0E, size = 8, height = 0x12, next = 0x26 }
K.AOB_LEVEL_EQUAL = "7E 31 8A 8C 2F ? ? ? ? 0F B6 D1 2B D6"
K.LEVEL_EQUAL = { size = 9, height = 5, noStep = 0x33 }
-- The one call of renderMap and the floater pass: `mov [..],ebp / call renderMap / call / mov eax,
-- [..] (resource-grid-overlay detours this one) / mov ecx,[OPERAND] / push eax / push ecx / mov
-- ecx, viewport`; the module detours the `mov ecx`.
K.AOB_FRAME = "89 2D ? ? ? ? E8 ? ? ? ? E8 ? ? ? ? ? ? ? ? ? 8B 0D ? ? ? ? 50 51 B9"
K.FRAME = { site = 21, size = 6, operand = 23 }
K.PLANT_TOOLS = 512                      -- the tree preview's table of tools, a byte each
-- placeTree turns a tile down with these flags (and with a plant on it).
K.TREE_REFUSED, K.TREE_FOOT_REFUSED = 0x703E25B5, 0x10100500
-- placeTree's room check (its tree-type argument `movsx eax,word [esp+0x24] / push ebp / push 3 /
-- push eax / mov ecx,organisms / call / push eax / mov ecx,organisms / call / lea ecx,[esi+esi*2] /
-- ... / mov eax,[eax*4+room]`): neighbours with these flags (border) end the look.
K.AOB_TREE_ROOM = "0F BF 44 24 24 55 6A 03 50 B9 ? ? ? ? E8 ? ? ? ? 50 B9 ? ? ? ? E8"
K.TREE_ROOM = { this = 10, first = 14, second = 25, room = { 0x3A, { 0x8B, 0x04, 0x85 } }, kinds = 64, most = 64 }
K.TREE_ROOM_EDGE = 0x10
-- The variant panels' pictures: the building composed from its tiles, made smaller to fit.
K.VARIANT_THUMB = { width = 72, height = 84 }
K.LOST_ROCKS_LABEL = "Remove lost rocks"
K.LOST_ROCKS_BUTTON = { padding = 5, height = 22, below = 6 }
-- The in-game key handlers' guard (five share it): `... cmp [menu guard],-1`, -1 while nothing
-- takes the keyboard (no text box).
K.AOB_KEY_GUARD = "F7 C1 00 00 00 40 0F 85 ? ? ? ? B9 ? ? ? ? E8 ? ? ? ? 85 C0 0F 84 ? ? ? ? 83 3D ? ? ? ? FF"
K.KEY_GUARD = 32

-- MenuItemRenderFunction_MapEditorLandscaping_GeneralButtons: the item position globals
-- (width follows the position), the hover flag, the open tab, the brush size, the chosen
-- tool, the image table, the texture renderer and the store that switches it to the screen
-- (0) before drawing; 1 draws on the map surface.
local BUTTON_RENDER = {
  hover = { 0x01, { 0x8B, 0x35 } },
  tab = { 0x21, { 0x39, 0x05 } },
  brush = { 0x4D, { 0xA1 } },
  subtype = { 0x91, { 0x39, 0x05 } },
  drawMode = { 0xC8, { 0xC7, 0x05 } },
  images = { 0xD2, { 0x8D, 0x88 } },
  y = { 0xEF, { 0x8B, 0x15 } },
  x = { 0xF8, { 0xA1 } },
  textures = { 0x101, { 0xB9 } },
}
local BUTTON_WIDTH = 0x08                -- from the x global
local IMAGE_SIZE = 0x1C                  -- image table entry: +0 gm, +4 picture

-- MenuItemActionHandler_MapEditorLandscaping_QueueCommandCallback: whether the mouse is on
-- the map (ViewportRenderState +0).
local MAP_CLICK = { onMap = { 0xF1, { 0x39, 0x1D } } }

-- The description line's renderer: mov eax,[esp+4] / push eax / mov ecx, state / call / ret,
-- and in the function it calls, the camera offset it adds for the map layer.
local HOVER_RENDER_BYTES = { 0x8B, 0x44, 0x24, 0x04, 0x50, 0xB9 }
local HOVER_RENDER_CALL = 0x0A
local CAMERA_X = { 0x5C, { 0x03, 0x0D } }   -- add ecx, [camera x]
local CAMERA_Y = { 0x62, { 0x03, 0x3D } }   -- add edi, [camera y]
local TEXT_LAYER = { 0x68, { 0xC7, 0x05 } }  -- mov dword [textManager.layer], 1

-- The siege engine button's ammunition count: renderNumber2(count, x, y, 1, white, 0, 0x11,
-- 0, 0) on the text manager. The number style the counts copy.
local AOB_AMMO_COUNT = "6A 00 6A 00 6A 11 6A 00 99 68 FF FF FF 00 2B C2 6A 01 D1 F8 83 C7 53 57 "
  .. "03 C3 50 8B 04 B5 ? ? ? ? 50 B9 ? ? ? ? E8"
local AMMO_WIDTH = { -0x05, { 0xA1 } }   -- mov eax, [item width]
local AMMO_TEXT_MANAGER = { 0x23, { 0xB9 } }
local AMMO_RENDER_NUMBER = 0x28
local NUMBER_FONT, NUMBER_COLOUR = 0x11, 0xFFFFFF
local NUMBER_FROM_BOTTOM = 11

-- The Save dialog's file name box renderer: the pencil and its translucent rounded box, the
-- text width, the shadowed text, and the colour box (whose code gives the pencil's surface
-- and clipping functions).
local AOB_NAME_BOX = "A1 ? ? ? ? 8B 0D ? ? ? ? 8B 15 ? ? ? ? 56 57 6A 05 03 C8 51 8B 0D ? ? ? ? 03 "
  .. "D1 52 50 51 B9 ? ? ? ?"
local NAME_BOX = {
  pencil = { 0x23, { 0xB9 } },
  roundedBox = 0x28,
  widthUntilCursor = 0x32,
  colourBox = 0x69,
  textManager = { 0x9C, { 0xB9 } },
  shadowedText = 0xA1,
}
local WIDTH_UNTIL_CURSOR_CALL = 0x22     -- inside it: the text width up to a length
local COLOUR_BOX_SURFACE, COLOUR_BOX_CLIP = 0x03, 0x23
local PENCIL_TARGET = 0x0C               -- 0 screen, 1 map surface
local BOX_BLEND = 5

-- The screen's pixel format (0x565 or 0x555).
local AOB_PIXEL_FORMAT = "81 3D ? ? ? 00 65 05 00 00 75 40"
local PIXEL_FORMAT_OPERAND = 2

-- handleMenuItems, where it asks whether the mouse is over an item: the mouse and its
-- "is the mouse in this box" test. (The ui module patches the function's start.)
local AOB_MENU_ITEM = "8B 56 10 8B 46 4C 8B 4E 0C 52 8B 50 08 03 56 08 8B 40 04 03 46 04 51 52 50 B9"
local MENU_ITEM_MOUSE = { 0x19, { 0xB9 } }
local MENU_ITEM_IS_INSIDE = 0x1E

-- The tooltip: above the panel, over the map, just above the description line and starting
-- at the button's left edge.
local TOOLTIP_FONT, TOOLTIP_COLOUR = 0x12, 0xB8EEFB  -- the description line's own style
local TOOLTIP_LINE, TOOLTIP_PADDING = 16, 6
local TOOLTIP_BOTTOM = HOVER_TEXT_POSITION[2] - 3
local ALIGN_LEFT = 0
local MAP_LAYER = 1                      -- text manager layer / pencil target: the map surface

-- renderGM(gm, picture, x, y) on the texture renderer: picture tables (first picture of a
-- gm, data offsets, sizes) and the animation sprite renderer it hands trees to, which reads
-- the sprite (for its palettes) and the palette to use from two globals.
local AOB_RENDER_GM = "8B 54 24 08 56 8B 74 24 08 8B 04 B5 ? ? ? ? 69 F6 58 14 00 00"
local RENDER_GM = {
  firstPictures = 0x0C,
  offsets = { 0x21, { 0x8B, 0x14, 0x85 } },
  dataBase = { 0x28, { 0x03, 0x51, 0x78 } },
  heights = { 0x39, { 0x0F, 0xBF, 0x90 } },   -- +2 of the picture sizes (+0 width)
  animation = 0x7F,
}
local ANIMATION = { palette = { 0x25, { 0x83, 0x3D } }, sprite = { 0x56, { 0x8B, 0x0D } } }
local PICTURE_SIZE = 16
local TEXTURES_MODE, TEXTURES_DIRECT_PALETTE, TEXTURES_DATA = 0x04, 0x10, 0x78

-- The free slot searches. Slots run from 1 to the last one they test.
-- LandscapeState::createTree: the first slot's "in use" word, the last slot, the slot size.
local AOB_NEW_TREE = "51 BA 01 00 00 00 55 89 4C 24 04 8B EA 8D 81 ? ? ? ? 66 83 38 00 74 17 81 FD ? ? ? ?"
local NEW_TREE = { first = 0x0F, last = 0x1B, size = { 0x23, { 0x05 } } }
local TREE_TYPE_FROM_IN_USE = 0x02       -- the tree type word follows the "in use" word
local TREE_TYPES = 32
-- LandscapeState::createRock
local AOB_NEW_ROCK = "BA 01 00 00 00 56 8B F2 8D 81 ? ? ? ? 8B FF 66 83 38 00 74 19 81 FE ? ? ? ?"
local NEW_ROCK = { first = 0x0A, last = 0x18, size = { 0x24, { 0x83, 0xC0 } } }
-- TribesState::findFreeTribe: the slot size, the "in use" word, the slot after the last one.
local AOB_NEW_GROUP = "53 55 56 B8 01 00 00 00 57 8B E9 A3 ? ? ? ? 33 DB 8B C8 69 C9 ? ? ? ? 66 39 5C 29 ? "
  .. "74 ? 83 C0 01 3D ? ? ? ?"
local NEW_GROUP = { size = 0x16, inUse = 0x1E, limit = 0x25 }
-- A caller of it, for the TribesState object.
local AOB_GROUPS = "69 FF ? ? 00 00 EB 04 8B 6C 24 10 6A 00 55 B9 ? ? ? ? E8"
local GROUPS_OBJECT, GROUPS_CALL = 0x10, 0x14
-- LandscapeState::mapUITreeTypeToLogicalTreeType(command): which tree type a tool places.
local AOB_TREE_TYPE = "8B 44 24 04 83 C0 D8 83 F8 74 0F 87"
local TREE_TYPE_START = { 0x8B, 0x44, 0x24, 0x04, 0x83, 0xC0, 0xD8 }

-- placeTree(x, y, command), at `push 3 / push 0 / movzx eax,ax / ...` (the growth stage and
-- other arguments of createTree), the createTree call, and right after it
-- `mov esi,eax / imul esi,esi,<tree size>`. The command is at [esp+0x28] there.
local AOB_PLACE_TREE = "6A 03 6A 00 0F B7 C0 6A 00 52 0F BF C0 50 56 51 B9 ? ? ? ? E8 ? ? ? ? 8B F0 69 F6 ? ? ? ?"
local PLACE_TREE = { stageSize = 7, landscape = 0x11, create = 0x15, created = 0x1A, createdSize = 8,
  command = 0x28 }
-- In createTree: the logs table (TreeRelated1, int [type][7]), the gm of each tree type and
-- the update function of each tree type.
local CREATE_TREE = {
  logs = { 0x10C, { 0x0F, 0xB7, 0x94, 0x00 } },
  gm = { 0xEE, { 0x0F, 0xB7, 0x14, 0xB5 } },
  update = { 0x2E4, { 0x8B, 0x14, 0x8D } },
}
local STAGES, MAX_STAGE, PLACED_STAGE = 7, 6, 3
-- Tree fields (from a slot's start; slot 0 starts at LandscapeState + 0x1C).
local TREES_IN_LANDSCAPE = 0x1C
local TREE = { TYPE = 0x46, CHOPS = 0x72, LYING = 0x76, LOGS = 0x78, STAGE = 0x80 }
local LYING_FELLED = 2
local LAST_TREE_TYPE = 4
-- UpdateTree1's pictures of a felled tree: stage base - logs; stage 0 has only the dead
-- tree picture.
local FELLED_PICTURE_BASE = { [1] = 0x8C, [2] = 0x82, [3] = 0x76, [4] = 0x76 }
local FELLED_STAGE_0_PICTURE = 0x92
-- createTree's colours (palettes) of shrub types 5 .. 9 (all tree_shrub1, picture 1 is the
-- first wind animation frame).
local SHRUB_PALETTES = { [5] = 0, [6] = 3, [7] = 4, [8] = 7, [9] = 8 }
local SHRUB_PICTURE = 1
local FELLED_PALETTE = 0

-- The panels above the Vegetation menu: centred on the screen, squeezed together when wider.
local PANEL_BOTTOM = 444
local PANEL_PADDING, PANEL_GAP, PANEL_MARGIN = 4, 2, 4
-- The present function, where it reads the screen size: mov edx,[width] / mov edi,[height].
local AOB_SCREEN_SIZE = "8B 15 ? ? ? ? 8B 3D ? ? ? ? 89 44 24 20 03 C2 89 44 24 28"
local SCREEN_WIDTH_OPERAND = 2
local MOST_LOGS = 9                      -- buttons in the felled tree panel

-- The unit count, and the limit the editor tests it against before placing more.
K.AOB_UNITS = "81 3D ? ? ? ? ? ? 00 00 7C 03 ? EB 01 ? 6A 1D E8"
K.UNITS_OPERAND = 2
K.UNITS_LIMIT = 6

-- The animal counters, from the animals' update functions.
K.AOB_DEER = "0F BF BE ? ? ? ? BA 01 00 00 00 01 15 ? ? ? ? 66 89 9E"
K.DEER_OPERAND = 0x0E
K.AOB_LIONS = "0F BF BE ? ? ? ? B9 01 00 00 00 01 0D ? ? ? ? 66 89 9E"
K.LIONS_OPERAND = 0x0E
K.AOB_RABBITS = "51 8B 15 ? ? ? ? 83 05 ? ? ? ? 01 53 56 8B F2"
K.RABBITS_OPERAND = 0x09
K.AOB_CAMELS = "83 05 ? ? ? ? 01 53 55 56 57 8B 3D"
K.CAMELS_OPERAND = 0x02

-- The main loop, where it picks between redrawing the menu and redrawing only the minimap:
-- cmp [GameCore.countdown], ebx / jne <full redraw> (ebx is 0 here).
local AOB_MENU_REDRAW = "83 3D ? ? ? ? 04 89 1D ? ? ? ? 0F 84 ? ? ? ? 39 1D ? ? ? ? 0F 85 ? ? ? ? 39 1D"
local MENU_REDRAW_SITE = 0x13
local MENU_REDRAW_SIZE = 12

-- GameMode2: 1 in the map editor.
local AOB_GAME_MODE = "83 3D ? ? ? ? 01 75 0D 6A 04 B9 ? ? ? ? E8 ? ? ? ? C3"
local GAME_MODE_OPERAND = 2

local AOB_IMAGE_BUTTON = "56 33 F6 39 ? ? ? ? ? 57 74 05"

---------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------

local rd32, rd16, rd8 = core.readInteger, core.readSmallInteger, core.readByte
local wr32, wr16 = core.writeInteger, core.writeSmallInteger

local function scan(pattern, purpose)
  local ok, address = pcall(core.AOBScan, pattern)
  if not ok or address == nil then
    error(MODULE_NAME .. ": could not find " .. purpose)
  end
  return address
end

local function expectBytes(address, bytes, purpose)
  for index, byte in ipairs(bytes) do
    if (rd8(address + index - 1) & 0xFF) ~= byte then
      error(string.format("%s: %s at 0x%X is not the code this module knows", MODULE_NAME, purpose,
        address))
    end
  end
end

local function readOperand(base, site, purpose)
  expectBytes(base + site[1], site[2], purpose)
  return rd32(base + site[1] + #site[2])
end

local function readCallTarget(base, offset, purpose)
  expectBytes(base + offset, { 0xE8 }, purpose)
  return base + offset + 5 + rd32(base + offset + 1)
end

local function setting(config, group, name)
  local section = config[group]
  if type(section) == "table" and section[name] ~= nil then
    return section[name]
  end
  return DEFAULTS[group][name]
end

local function bytesOf(value)
  local out = {}
  for index, byte in ipairs(core.itob(value)) do
    out[index] = string.format("%02X", byte & 0xFF)
  end
  return table.concat(out, " ")
end

local function item(itemTable, index, offset)
  return itemTable + index * MENU_ITEM_SIZE + (offset or 0)
end

local function writeCString(address, text)
  local bytes = { string.byte(text, 1, -1) }
  bytes[#bytes + 1] = 0
  core.writeBytes(address, bytes)
end

-- A zero-terminated list of dwords (pairs flattened) in allocated memory.
local function dwordList(values)
  local list = core.allocate((#values + 1) * 4, true)
  for i, value in ipairs(values) do wr32(list + (i - 1) * 4, value) end
  wr32(list + #values * 4, 0)
  return list
end

local function jumpTo(site, target, size)
  local bytes = { 0xE9, core.itob(core.getRelativeAddress(site, target, -5)) }
  for _ = 6, size do bytes[#bytes + 1] = 0x90 end
  return bytes
end

---------------------------------------------------------------------------------------
-- Pictures from images/
---------------------------------------------------------------------------------------

local function readFile(name)
  for _, folder in ipairs(MODULE_FOLDERS) do
    local file = io.open(folder .. name, "rb")
    if file ~= nil then
      local data = file:read("a")
      file:close()
      return data
    end
  end
  return nil
end

local function loadPicture(name)
  local data = readFile("images/" .. name .. ".png")
  if data == nil then
    error(string.format("%s: images/%s.png not found", MODULE_NAME, name))
  end
  local ok, width, height, pixels = pcall(png.decode, data)
  if not ok then
    error(string.format("%s: images/%s.png: %s", MODULE_NAME, name, (tostring(width):gsub("^.-:%d+: ", ""))))
  end
  return { width = width, height = height, pixels = pixels }
end

-- Writes a picture, centred on a width x height canvas, in the layout the blit routine
-- reads and returns its address.
local function storePicture(picture, width, height)
  local count = width * height
  local base = core.allocate(0x14 + count * 5, true)
  local rgb565, rgb555, mask = {}, {}, {}
  local left, top = (width - picture.width) // 2, (height - picture.height) // 2
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      local index = y * width + x + 1
      local sx, sy = x - left, y - top
      local p = { 0, 0, 0, 0 }
      if sx >= 0 and sy >= 0 and sx < picture.width and sy < picture.height then
        p = picture.pixels[sy * picture.width + sx + 1]
      end
      local r, g, b = p[1], p[2], p[3]
      local value565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
      local value555 = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)
      rgb565[index * 2 - 1], rgb565[index * 2] = value565 & 0xFF, value565 >> 8
      rgb555[index * 2 - 1], rgb555[index * 2] = value555 & 0xFF, value555 >> 8
      mask[index] = p[4]
    end
  end
  wr32(base, width)
  wr32(base + 4, height)
  wr32(base + 8, base + 0x14)
  wr32(base + 0xC, base + 0x14 + count * 2)
  wr32(base + 0x10, base + 0x14 + count * 4)
  core.writeBytes(base + 0x14, rgb565)
  core.writeBytes(base + 0x14 + count * 2, rgb555)
  core.writeBytes(base + 0x14 + count * 4, mask)
  return base
end

-- A button's three pictures: <name>.png, <name>_hover.png, <name>_selected.png, all on the
-- canvas of the largest.
local function buttonPictures(name)
  local normal, hover, chosen = loadPicture(name), loadPicture(name .. "_hover"), loadPicture(name .. "_selected")
  local width = math.max(normal.width, hover.width, chosen.width)
  local height = math.max(normal.height, hover.height, chosen.height)
  return {
    width = width, height = height,
    normal = storePicture(normal, width, height),
    hover = storePicture(hover, width, height),
    chosen = storePicture(chosen, width, height),
  }
end

---------------------------------------------------------------------------------------
-- Finding things
---------------------------------------------------------------------------------------

local function resolveMenu(G)
  G.table = scan(AOB_ITEM_TABLE, "the landscape editor's menu") - KEY_BUTTON_ITEM * MENU_ITEM_SIZE
  local index = 0
  while rd32(item(G.table, index, ITEM_TYPE)) ~= TYPE_END do
    index = index + 1
    if index > ITEM_COUNT then break end
  end
  if index ~= ITEM_COUNT then
    error(MODULE_NAME .. ": the landscape editor's menu is not the one this module knows")
  end
  if rd32(item(G.table, HOVER_TEXT_ITEM, ITEM_TYPE)) ~= TYPE_CLICKABLE
      or rd32(item(G.table, HOVER_TEXT_ITEM, ITEM_X)) ~= HOVER_TEXT_POSITION[1]
      or rd32(item(G.table, HOVER_TEXT_ITEM, ITEM_Y)) ~= HOVER_TEXT_POSITION[2]
      or rd32(item(G.table, MAP_CLICK_ITEM, ITEM_TYPE)) ~= TYPE_EVERY_FRAME then
    error(MODULE_NAME .. ": the landscape editor's menu is not laid out as the module expects")
  end

  G.site = scan("68 " .. bytesOf(G.table) .. " B9 ? ? ? ? E8", "the landscape editor menu's constructor")
  G.menu = rd32(G.site + 6)
  G.constructor = readCallTarget(G.site, 10, "the Menu constructor")

  -- The buttons by command, the render function their groups give them, the block each one
  -- is in (the tab id of the 0x64 marker before it, 0 for the part that is always shown), and
  -- where the always shown part and each tab end.
  -- Rock tool buttons are listed per tab too (they are in both Rocks tabs), with the action
  -- their group gives them.
  G.buttons, G.blockEnd, G.rockButtons = {}, {}, {}
  local groupRender, groupAction, groupIndex, block = nil, nil, nil, 0
  for i = 0, ITEM_COUNT - 1 do
    local itemType = rd32(item(G.table, i, ITEM_TYPE))
    if itemType == TYPE_BLOCK then
      if block == 0 then G.firstBlock = i else G.blockEnd[block] = G.blockEnd[block] or i end
      block = rd32(item(G.table, i, ITEM_PARAM))
    elseif itemType == TYPE_GROUP_START then
      groupRender = rd32(item(G.table, i, ITEM_RENDER))
      groupAction = rd32(item(G.table, i, ITEM_ACTION))
      groupIndex = i
    elseif (itemType & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_MEMBER then
      local param = rd32(item(G.table, i, ITEM_PARAM))
      if G.buttons[param] == nil then
        local render = rd32(item(G.table, i, ITEM_RENDER))
        if render == 0 then render = groupRender end
        local action = rd32(item(G.table, i, ITEM_ACTION))
        if action == 0 then action = groupAction end
        G.buttons[param] = { index = i, render = render, block = block, action = action }
      end
      if param >= K.FIRST_ROCK_COMMAND and param <= K.LAST_ROCK_COMMAND then
        local action = rd32(item(G.table, i, ITEM_ACTION))
        if action == 0 then action = groupAction end
        table.insert(G.rockButtons, { index = i, action = action, block = block, group = groupIndex })
      end
    end
  end
  if block ~= 0 then G.blockEnd[block] = G.blockEnd[block] or ITEM_COUNT end
  if G.firstBlock == nil or G.blockEnd[ANIMALS] == nil or G.blockEnd[VEGETATION] == nil
      or G.blockEnd[TEXTURES] == nil or G.blockEnd[ROCKS] == nil then
    error(MODULE_NAME .. ": the landscape editor's menu has not got the tabs this module knows")
  end
  local needed = { DEER, LION, RABBIT, CAMEL, VEGETATION, ANIMALS, ROCKS, IRON_COMMAND, TOP_ROW_SHRUB,
    table.unpack(SORTED_SHRUBS) }
  for _, row in ipairs(TEXTURE_ROWS) do
    for i = 1, 4 do needed[#needed + 1] = row[i] end
  end
  for _, param in ipairs(VEGETATION_TREES) do needed[#needed + 1] = param end
  for _, param in ipairs(needed) do
    if G.buttons[param] == nil then
      error(string.format("%s: button %d is missing from the landscape editor's menu", MODULE_NAME, param))
    end
  end
  G.plants = {}
  for param, button in pairs(G.buttons) do
    if button.block == VEGETATION then G.plants[#G.plants + 1] = param end
  end

  G.buttonRender = G.buttons[DEER].render
  for _, param in ipairs({ LION, RABBIT, CAMEL, table.unpack(G.plants) }) do
    if G.buttons[param].render ~= G.buttonRender then
      error(MODULE_NAME .. ": the landscape editor's buttons are drawn by an unknown function")
    end
  end
  local b = BUTTON_RENDER
  G.hover = readOperand(G.buttonRender, b.hover, "the editor button renderer")
  G.activeTab = readOperand(G.buttonRender, b.tab, "the editor button renderer")
  G.brush = readOperand(G.buttonRender, b.brush, "the editor button renderer")
  G.subtype = readOperand(G.buttonRender, b.subtype, "the editor button renderer")
  G.drawMode = readOperand(G.buttonRender, b.drawMode, "the editor button renderer")
  G.buttonImages = readOperand(G.buttonRender, b.images, "the editor button renderer")
  G.itemY = readOperand(G.buttonRender, b.y, "the editor button renderer")
  G.itemX = readOperand(G.buttonRender, b.x, "the editor button renderer")
  G.textures = readOperand(G.buttonRender, b.textures, "the editor button renderer")
  if G.drawMode ~= G.textures + TEXTURES_MODE then
    error(MODULE_NAME .. ": the texture renderer is not laid out as the module expects")
  end

  G.onMap = readOperand(rd32(item(G.table, MAP_CLICK_ITEM, ITEM_ACTION)), MAP_CLICK.onMap, "the map click handler")

  G.hoverRender = rd32(item(G.table, HOVER_TEXT_ITEM, ITEM_RENDER))
  expectBytes(G.hoverRender, HOVER_RENDER_BYTES, "the description line renderer")
  local describe = readCallTarget(G.hoverRender, HOVER_RENDER_CALL, "the description line renderer")
  G.cameraX = readOperand(describe, CAMERA_X, "the description line renderer")
  G.cameraY = readOperand(describe, CAMERA_Y, "the description line renderer")
  G.textLayer = readOperand(describe, TEXT_LAYER, "the description line renderer")
  G.imageButton = scan(AOB_IMAGE_BUTTON, "the image button renderer")
end

local function resolveDrawing(G)
  local ammo = scan(AOB_AMMO_COUNT, "the ammunition count")
  if readOperand(ammo, AMMO_WIDTH, "the ammunition count") ~= G.itemX + BUTTON_WIDTH then
    error(MODULE_NAME .. ": the item position globals are not laid out as the module expects")
  end
  G.textManager = readOperand(ammo, AMMO_TEXT_MANAGER, "the ammunition count")
  G.renderNumber = readCallTarget(ammo, AMMO_RENDER_NUMBER, "the number drawing")

  local nameBox = scan(AOB_NAME_BOX, "the Save dialog's name box")
  G.pencil = readOperand(nameBox, NAME_BOX.pencil, "the name box")
  G.roundedBox = readCallTarget(nameBox, NAME_BOX.roundedBox, "the name box background")
  local untilCursor = readCallTarget(nameBox, NAME_BOX.widthUntilCursor, "the name box cursor")
  G.textWidth = readCallTarget(untilCursor, WIDTH_UNTIL_CURSOR_CALL, "the text width")
  if readOperand(nameBox, NAME_BOX.textManager, "the name box") ~= G.textManager then
    error(MODULE_NAME .. ": the text manager is not the one this module knows")
  end
  G.shadowedText = readCallTarget(nameBox, NAME_BOX.shadowedText, "the text drawing")
  G.colourBox = readCallTarget(nameBox, NAME_BOX.colourBox, "the colour box")
  G.setupSurface = readCallTarget(G.colourBox, COLOUR_BOX_SURFACE, "the drawing surface")
  G.setupPencil = readCallTarget(G.colourBox, COLOUR_BOX_CLIP, "the drawing clip")
  G.pixelFormat = rd32(scan(AOB_PIXEL_FORMAT, "the pixel format") + PIXEL_FORMAT_OPERAND)
  G.screenWidth = rd32(scan(AOB_SCREEN_SIZE, "the screen size") + SCREEN_WIDTH_OPERAND)

  local menuItem = scan(AOB_MENU_ITEM, "the menu's mouse test")
  G.mouse = readOperand(menuItem, MENU_ITEM_MOUSE, "the menu's mouse test")
  G.isMouseInside = readCallTarget(menuItem, MENU_ITEM_IS_INSIDE, "the menu's mouse test")

  local renderGM = scan(AOB_RENDER_GM, "the picture renderer")
  G.renderGM = renderGM
  G.firstPictures = rd32(renderGM + RENDER_GM.firstPictures)
  G.pictureOffsets = readOperand(renderGM, RENDER_GM.offsets, "the picture renderer")
  expectBytes(renderGM + RENDER_GM.dataBase[1], RENDER_GM.dataBase[2], "the picture renderer")
  G.pictureHeights = readOperand(renderGM, RENDER_GM.heights, "the picture renderer")
  local animation = readCallTarget(renderGM, RENDER_GM.animation, "the sprite renderer")
  G.spritePalette = readOperand(animation, ANIMATION.palette, "the sprite renderer")
  G.sprite = readOperand(animation, ANIMATION.sprite, "the sprite renderer")
end

local function resolveCounters(G)
  local unitTest = scan(K.AOB_UNITS, "the unit count")
  G.units = rd32(unitTest + K.UNITS_OPERAND)
  G.unitLimit = rd32(unitTest + K.UNITS_LIMIT)
  local ok, found = pcall(scan, K.AOB_UNIT_MAX, "the unit limit")
  if ok then G.unitMax = rd32(found + K.UNIT_MAX) end
  G.animals = {
    [DEER] = rd32(scan(K.AOB_DEER, "the deer count") + K.DEER_OPERAND),
    [LION] = rd32(scan(K.AOB_LIONS, "the lion count") + K.LIONS_OPERAND),
    [RABBIT] = rd32(scan(K.AOB_RABBITS, "the rabbit count") + K.RABBITS_OPERAND),
    [CAMEL] = rd32(scan(K.AOB_CAMELS, "the camel count") + K.CAMELS_OPERAND),
  }

  local placeTree = scan(AOB_PLACE_TREE, "the tree placement")
  G.placeTree = placeTree
  G.landscape = rd32(placeTree + PLACE_TREE.landscape)
  G.createTree = readCallTarget(placeTree, PLACE_TREE.create, "createTree")
  G.treeSize = rd32(placeTree + PLACE_TREE.created + 4)
  G.logs = readOperand(G.createTree, CREATE_TREE.logs, "createTree")
  G.typeGm = readOperand(G.createTree, CREATE_TREE.gm, "createTree")
  G.updateTree = readOperand(G.createTree, CREATE_TREE.update, "createTree")

  local newTree = scan(AOB_NEW_TREE, "the tree slot search")
  if newTree ~= G.createTree then
    error(MODULE_NAME .. ": createTree is not where the module expects it")
  end
  G.firstTree = G.landscape + rd32(newTree + NEW_TREE.first)
  G.treeSlots = rd32(newTree + NEW_TREE.last)
  if readOperand(newTree, NEW_TREE.size, "the tree slot search") ~= G.treeSize then
    error(MODULE_NAME .. ": the tree size is not the one this module knows")
  end
  local newRock = scan(AOB_NEW_ROCK, "the rock slot search")
  G.firstRock = G.landscape + rd32(newRock + NEW_ROCK.first)
  G.rockSlots = rd32(newRock + NEW_ROCK.last)
  expectBytes(newRock + NEW_ROCK.size[1], NEW_ROCK.size[2], "the rock slot search")
  G.rockSize = rd8(newRock + NEW_ROCK.size[1] + 2) & 0xFF

  local newGroup = scan(AOB_NEW_GROUP, "the group slot search")
  local groupsCall = scan(AOB_GROUPS, "the group array")
  if readCallTarget(groupsCall, GROUPS_CALL, "the group array") ~= newGroup then
    error(MODULE_NAME .. ": the group array is not the one this module knows")
  end
  G.groupSize = rd32(newGroup + NEW_GROUP.size)
  G.firstGroup = rd32(groupsCall + GROUPS_OBJECT) + G.groupSize + (rd8(newGroup + NEW_GROUP.inUse) & 0xFF)
  G.groupSlots = rd32(newGroup + NEW_GROUP.limit) - 1

  -- Which tree type each tool places, asked of the game itself (before the apple tree hook).
  G.treeTypeOf = scan(AOB_TREE_TYPE, "the plant types")
  expectBytes(G.treeTypeOf, TREE_TYPE_START, "the plant types")
  local treeType = core.exposeCode(G.treeTypeOf, 2, 1)
  G.plantTypes = {}
  for _, param in ipairs(G.plants) do
    G.plantTypes[param] = treeType(G.landscape, param) & (TREE_TYPES - 1)
  end
  for _, param in ipairs(SHRUB_COMMANDS) do
    G.plantTypes[param] = treeType(G.landscape, param) & (TREE_TYPES - 1)
  end
  G.plantTypes[APPLE_COMMAND] = APPLE_TYPE
end

-- Rocks: the rock tool's state, the placement and preview sites, and what the module needs to
-- draw rocks the way the map renderer does.
local function resolveRocks(G)
  G.rockPlace = scan(K.AOB_ROCK_PLACE, "the rock placement")
  G.rockParam = rd32(G.rockPlace + K.ROCK_PLACE.param)
  G.rockVariant = rd32(G.rockPlace + K.ROCK_PLACE.variant)
  G.chosenRockSize = G.rockVariant + 4
  G.rockPreview = scan(K.AOB_ROCK_PREVIEW, "the rock preview")
  G.mouseTileY = rd32(G.rockPreview + K.ROCK_PREVIEW.mouseY)
  G.tileMap = rd32(G.rockPreview + K.ROCK_PREVIEW.tileMap)
  local a = readOperand(G.rockPreview, K.ROCK_PREVIEW.first, "the rock preview")
  local b = readOperand(G.rockPreview, K.ROCK_PREVIEW.second, "the rock preview")
  if not ((a == G.rockVariant and b == G.chosenRockSize) or (b == G.rockVariant and a == G.chosenRockSize)) then
    error(MODULE_NAME .. ": the rock variant and size are not where the module expects them")
  end
  if G.tileMap + 0x5548F4 ~= G.rockVariant then
    error(MODULE_NAME .. ": the map tile state is not laid out as the module expects")
  end
  local stamp = scan(K.AOB_ROCK_STAMP, "the rock drawing")
  G.footprint = readCallTarget(stamp, K.ROCK_STAMP.mapping, "the footprint layout")
  local randomOffset = readCallTarget(stamp, K.ROCK_STAMP.randomOffset, "the rock pictures")
  G.rockBases = readOperand(randomOffset, K.ROCK_PICTURES, "the rock pictures")
  local newRock = scan(AOB_NEW_ROCK, "the rock slot search")
  G.rockGm = rd16(readOperand(newRock, K.ROCK_GM, "createRock") + 4)
end

-- Herds: per animal the herd code site and what it does.
local function resolveHerds(G)
  local sites, start = {}, 0x400000
  while #sites < #K.HERD_ANIMALS + 1 do
    local ok, found = pcall(core.scanForAOB, K.AOB_HERD, start, K.HERD_SEARCH_END)
    if not ok or found == nil or found == 0 then break end
    sites[#sites + 1] = found
    start = found + 1
  end
  if #sites ~= #K.HERD_ANIMALS then
    error(MODULE_NAME .. ": the herd code is not the one this module knows")
  end
  G.herds = {}
  for i, site in ipairs(sites) do
    local herd = { command = K.HERD_ANIMALS[i][1], name = K.HERD_ANIMALS[i][2], site = site + K.HERD.site }
    herd.mask = rd8(site + K.HERD.mask) & 0xFF
    herd.unit = rd32(site + K.HERD.unit)
    herd.base = rd8(site + K.HERD.base) & 0xFF
    expectBytes(site + K.HERD.group[1], K.HERD.group[2], "the herd code")
    herd.group = rd16(site + K.HERD.group[1] + #K.HERD.group[2])
    G.herds[herd.command] = herd
  end
end

---------------------------------------------------------------------------------------
-- Sprites: where a picture's pixels lie within its frame
---------------------------------------------------------------------------------------

-- The bounding box of a picture's visible pixels, from the game's loaded picture data (TGX
-- with one byte per pixel for sprites: n literal bytes, a repeated byte, n transparent, new
-- line). nil while the gm is not loaded.
local function makeSpriteBoxes(G)
  local cache = {}
  return function(gm, picture)
    local first = rd32(G.firstPictures + gm * 4)
    if first <= 0 then return nil end
    local frame = first + picture - 1
    local key = frame
    if cache[key] ~= nil then return cache[key] end
    local width = rd16(G.pictureHeights - 2 + frame * PICTURE_SIZE)
    local height = rd16(G.pictureHeights + frame * PICTURE_SIZE)
    local data = rd32(G.pictureOffsets + frame * 4) + rd32(G.textures + TEXTURES_DATA)
    if width <= 0 or height <= 0 then return nil end
    local chunk, chunkStart = nil, 0
    local function byte(offset)
      if chunk == nil or offset >= chunkStart + #chunk then
        chunkStart = offset
        chunk = core.readBytes(data + offset, 4096)
      end
      return chunk[offset - chunkStart + 1] & 0xFF
    end
    local left, top, right, bottom = width, height, -1, -1
    local x, y, offset = 0, 0, 0
    local function mark(n)
      if x < left then left = x end
      if x + n - 1 > right then right = x + n - 1 end
      if y < top then top = y end
      if y > bottom then bottom = y end
    end
    while y < height and offset < width * height * 4 do
      local token = byte(offset)
      offset = offset + 1
      local n, flag = (token & 0x1F) + 1, token >> 5
      if flag == 0 then
        mark(n)
        offset, x = offset + n, x + n
      elseif flag == 4 then
        x, y = 0, y + 1
      elseif flag == 2 then
        mark(n)
        offset, x = offset + 1, x + n
      elseif flag == 1 then
        x = x + n
      else
        break
      end
    end
    local box = nil
    if right >= left then
      box = { x = left, y = top, width = right - left + 1, height = bottom - top + 1 }
    end
    cache[key] = box
    return box
  end
end

-- A picture for the blit routine from raw screen pixels (the game's own pixel values, the
-- same for both pixel formats): pixels[y * width + x + 1] or nil for see-through.
local function storeRawPicture(width, height, pixels)
  local count = width * height
  local base = core.allocate(0x14 + count * 3, true)
  local words, mask = {}, {}
  for index = 1, count do
    local value = pixels[index]
    words[index * 2 - 1], words[index * 2] = (value or 0) & 0xFF, ((value or 0) >> 8) & 0xFF
    mask[index] = value ~= nil and 255 or 0
  end
  wr32(base, width)
  wr32(base + 4, height)
  wr32(base + 8, base + 0x14)
  wr32(base + 0xC, base + 0x14)
  wr32(base + 0x10, base + 0x14 + count * 2)
  core.writeBytes(base + 0x14, words)
  core.writeBytes(base + 0x14 + count * 2, mask)
  return base
end

-- Rocks as the map renderer draws them: per footprint tile (getBuildingSizeIndexMappingData:
-- the tile's offset and picture number for the map's current turn) the picture
-- first + base + tile picture + rotation step * tiles - 1 of the rock gm, a 30 x 16 diamond
-- (512 bytes of pixels) and above it a TGX picture of the tall part. The tiles are laid out
-- with renderMap's transform for the turn and composed into one picture, cached.
local function makeRockPictures(G)
  local footprint = core.exposeCode(G.footprint, 3, 1)
  local cache, tiles = {}, {}

  local function tile(frame)
    if tiles[frame] ~= nil then return tiles[frame] end
    local header = G.pictureHeights - 2 + frame * PICTURE_SIZE
    local width, height = rd16(header), rd16(header + 2)
    local tileY, partX = rd16(header + 10), rd8(header + 13) & 0xFF
    if width <= 0 or height <= 0 then return nil end
    local data = rd32(G.pictureOffsets + frame * 4) + rd32(G.textures + TEXTURES_DATA)
    local canvas = math.max(32, partX + width)
    local pixels = {}
    local diamond = core.readBytes(data, K.TILE_DIAMOND_BYTES)
    local i = 1
    for row, n in ipairs(K.TILE_DIAMOND) do
      local left = 16 - n // 2
      for k = 0, n - 1 do
        pixels[(tileY + row - 1) * canvas + left + k + 1] = (diamond[i] & 0xFF) | ((diamond[i + 1] & 0xFF) << 8)
        i = i + 2
      end
    end
    -- The tall part: n literal pixels, a repeated pixel, n see-through, new line.
    local chunk, chunkStart = nil, 0
    local function byte(offset)
      if chunk == nil or offset >= chunkStart + #chunk then
        chunkStart = offset
        chunk = core.readBytes(data + K.TILE_DIAMOND_BYTES + offset, 4096)
      end
      return chunk[offset - chunkStart + 1] & 0xFF
    end
    local x, y, offset = 0, 0, 0
    while y < height and offset < width * height * 4 do
      local token = byte(offset)
      offset = offset + 1
      local n, flag = (token & 0x1F) + 1, token >> 5
      if flag == 0 then
        for _ = 1, n do
          pixels[y * canvas + partX + x + 1] = byte(offset) | (byte(offset + 1) << 8)
          offset, x = offset + 2, x + 1
        end
      elseif flag == 4 then
        x, y = 0, y + 1
      elseif flag == 2 then
        local value = byte(offset) | (byte(offset + 1) << 8)
        offset = offset + 2
        for _ = 1, n do
          pixels[y * canvas + partX + x + 1] = value
          x = x + 1
        end
      elseif flag == 1 then
        x = x + n
      else
        break
      end
    end
    local result = { width = canvas, height = math.max(height, tileY + 16), tileY = tileY, pixels = pixels }
    tiles[frame] = result
    return result
  end

  -- size: footprint tiles per side (1 .. 4); base: the rock's first picture. Other objects
  -- made of tiles the same way (buildings) give their gm, and `fixed`: no turned sets.
  return function(size, base, rotation, gm, fixed)
    gm = gm or G.rockGm
    local tileMap = G.tileMap
    local turn = rd32(tileMap + K.TILE_MAP.orientation)
    if rd32(tileMap + K.TILE_MAP.mode) ~= 5 then turn = turn + rotation end
    local step = fixed and 0 or (turn % 8) // 2
    local view = rd32(tileMap + K.TILE_MAP.orientation)
    local key = string.format("%d/%d/%d/%d/%d", size, base, step, view, gm)
    if cache[key] ~= nil then return cache[key] end
    local first = rd32(G.firstPictures + gm * 4)
    local t = K.TURN[view]
    if first <= 0 or t == nil then return nil end
    local parts, left, top, right, bottom = {}, math.huge, math.huge, -math.huge, -math.huge
    for k = 0, size * size - 1 do
      footprint(tileMap, k, size)
      local dx, dy = rd32(tileMap + K.TILE_MAP.tileX), rd32(tileMap + K.TILE_MAP.tileY)
      local picture = rd32(tileMap + K.TILE_MAP.tilePicture)
      local part = tile(first + base + picture + step * size * size - 1)
      if part == nil then return nil end
      local d, s = dx - dy, dx + dy
      local x = t.xd * d + t.xs * s
      local y = t.yd * d + t.ys * s - part.tileY
      parts[#parts + 1] = { part = part, x = x, y = y, order = y + part.tileY }
      left, top = math.min(left, x), math.min(top, y)
      right, bottom = math.max(right, x + part.width), math.max(bottom, y + part.height)
    end
    table.sort(parts, function(a, b) return a.order < b.order end)
    local width, height = right - left, bottom - top
    local pixels = {}
    for _, p in ipairs(parts) do
      local ox, oy = p.x - left, p.y - top
      for index, value in pairs(p.part.pixels) do
        local px, py = (index - 1) % p.part.width, (index - 1) // p.part.width
        pixels[(oy + py) * width + ox + px + 1] = value
      end
    end
    local picture = { address = storeRawPicture(width, height, pixels), width = width, height = height, pixels = pixels }
    cache[key] = picture
    return picture
  end
end

---------------------------------------------------------------------------------------
-- Map counts: the tooltip
---------------------------------------------------------------------------------------

-- candidates: { item = button, lines = function returning text lines or nil }.
local function makeTooltip(G, candidates)
  local isMouseInside = core.exposeCode(G.isMouseInside, 5, 1)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local lineBuffers = { core.allocate(96, true), core.allocate(96, true), core.allocate(96, true),
    core.allocate(96, true) }

  -- Like the description line, the tooltip is drawn on the map surface (at the screen
  -- position plus the camera offset), which is drawn afresh every frame: nothing of it stays
  -- behind once the mouse leaves the button. Lines are added upwards, away from the panel.
  return function()
    for _, candidate in ipairs(candidates) do
      local button = candidate.item
      local x = rd32(G.menu + MENU_X) + rd32(button + ITEM_X)
      local y = rd32(G.menu + MENU_Y) + rd32(button + ITEM_Y)
      local shown = rd16(button + ITEM_HOVERED) ~= 0
        and isMouseInside(G.mouse, x, y, rd32(button + ITEM_WIDTH), rd32(button + ITEM_HEIGHT)) ~= 0
        and (candidate.name or candidate.lines())
      if shown and candidate.name ~= nil then   -- a name on the description line, like the game's
        writeCString(lineBuffers[1], shown)
        local layer = rd32(G.textLayer)
        wr32(G.textLayer, MAP_LAYER)
        shadowedText(G.textManager, lineBuffers[1], rd32(G.menu + MENU_X) + G.describeAt[1] + rd32(G.cameraX),
          rd32(G.menu + MENU_Y) + G.describeAt[2] + rd32(G.cameraY), ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
        wr32(G.textLayer, layer)
        return
      end
      if shown then
        local widest = 0
        for i, text in ipairs(shown) do
          writeCString(lineBuffers[i], text)
          widest = math.max(widest, textWidth(G.textManager, lineBuffers[i], #text, TOOLTIP_FONT))
        end
        local left = x + rd32(G.cameraX)
        local right = left + widest + 2 * TOOLTIP_PADDING
        local bottom = rd32(G.menu + MENU_Y) + TOOLTIP_BOTTOM + rd32(G.cameraY) - (candidate.raise or 0)
        local top = bottom - #shown * TOOLTIP_LINE - TOOLTIP_PADDING
        local target = rd32(G.pencil + PENCIL_TARGET)
        wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
        roundedBox(G.pencil, left, top, right, bottom, BOX_BLEND)
        wr32(G.pencil + PENCIL_TARGET, target)
        local layer = rd32(G.textLayer)
        wr32(G.textLayer, MAP_LAYER)
        for i = 1, #shown do
          shadowedText(G.textManager, lineBuffers[i], left + TOOLTIP_PADDING,
            top + TOOLTIP_PADDING // 2 + (i - 1) * TOOLTIP_LINE, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT,
            0, 0)
        end
        wr32(G.textLayer, layer)
        return
      end
    end
  end
end

---------------------------------------------------------------------------------------
-- Rows of buttons above the panel: trees, shrubs, rocks
---------------------------------------------------------------------------------------

-- What the tree panel shows for the chosen tool: the felled trees of the chosen tree, or the
-- five shrubs, and with random mixes on a random standing tree (the tree's own button picture),
-- a random felled tree and a random shrub. Each entry: its item, a game sprite (gm, picture,
-- palette) or button image, the param its click gets, whether it is the chosen one, a label and
-- the counter to show on it.
local function makeTreeEntries(G, O, data, panel)
  local function stage()
    if not O.growth then return PLACED_STAGE end
    return math.max(0, math.min(MAX_STAGE, rd32(G.brush) - 1))
  end
  return function(command)
    local list = {}
    if O.felled and command >= FIRST_TREE_COMMAND and command <= LAST_TREE_COMMAND then
      local treeType, treeStage = G.plantTypes[command], stage()
      local most = math.min(rd32(G.logs + (treeType * STAGES + treeStage) * 4), MOST_LOGS)
      if treeStage == 0 then most = K.SMALLEST_FELLED_LOGS end
      local gm = rd16(G.typeGm + treeType * 4)
      local felledLogs, felledCommand = rd32(data.felledLogs), rd32(data.felledCommand)
      local function add(entry)
        entry.item = panel.felled[#list + 1]
        entry.chosen = felledLogs == entry.param and felledCommand == command
        list[#list + 1] = entry
      end
      local function felledPicture(logs)
        local shown = math.max(treeStage, K.SMALLEST_FELLED_STAGE)   -- see stageFromBrush
        return FELLED_PICTURE_BASE[math.min(shown, 4)] - logs
      end
      add({ image = panel.images[command], param = 0 })   -- the standing tree
      list[1].chosen = felledLogs == 0 or felledCommand ~= command
      if O.randomMix and treeStage >= 1 and treeStage <= K.MOST_RANDOM_STAGE then
        add({ image = panel.images[command], param = K.RANDOM_STANDING, label = K.RANDOM_LABEL })
      end
      for logs = most, 1, -1 do
        add({ gm = gm, picture = felledPicture(logs), palette = FELLED_PALETTE, param = logs })
      end
      if O.randomMix and most >= 2 then
        add({ gm = gm, picture = felledPicture(most), palette = FELLED_PALETTE, param = K.RANDOM_FELLED,
          label = K.RANDOM_LABEL })
      end
    elseif O.shrubs then
      local random = O.randomMix and rd8(data.randomShrub) ~= 0
      for i, shrub in ipairs(SHRUB_COMMANDS) do
        local shrubType = G.plantTypes[shrub]
        list[i] = { item = panel.shrubs[i], gm = rd16(G.typeGm + shrubType * 4), picture = SHRUB_PICTURE,
          palette = SHRUB_PALETTES[shrubType] or 0, chosen = command == shrub and not random,
          count = data.typeCounts and (data.typeCounts + shrubType * 4) }
      end
      if O.randomMix then
        local shrubType = G.plantTypes[SHRUB_COMMANDS[1]]
        list[#list + 1] = { item = panel.randomShrub, gm = rd16(G.typeGm + shrubType * 4), picture = SHRUB_PICTURE,
          palette = SHRUB_PALETTES[shrubType] or 0, chosen = random, label = K.RANDOM_LABEL }
      end
    end
    return list
  end
end

-- What the rock panel shows: the four variants of the chosen size, as the map would draw them
-- now (rotation and turn), and at size 1x1 the extra rock (number 16: type 0, base 0).
local function makeRockEntries(G, O, data, panel, rockPicture)
  return function(command)
    local size = rd32(G.chosenRockSize)
    if size < 0 or size > 3 then return {} end
    local lock = rd32(data.rockLock)
    if lock == K.EXTRA_VARIANT + 1 and size ~= 0 then
      wr32(data.rockLock, 0)                   -- the extra rock exists at 1x1 only
      lock = 0
    end
    local rotation = rd32(G.tileMap + K.TILE_MAP.rotation)
    local list = {}
    for v = 0, K.ROCK_VARIANTS - 1 do
      local base = rd32(G.rockBases + (size * K.ROCK_VARIANTS + v) * 4)
      local picture = rockPicture(size + 1, base, rotation)
      if picture == nil then return {} end
      list[#list + 1] = { item = panel.rocks[v + 1], picture = picture, param = v + 1, chosen = lock == v + 1 }
    end
    if O.extraRock and size == 0 then
      local picture = rockPicture(1, 0, rotation)
      if picture == nil then return {} end
      list[#list + 1] = { item = panel.rocks[K.EXTRA_VARIANT + 1], picture = picture,
        param = K.EXTRA_VARIANT + 1, chosen = lock == K.EXTRA_VARIANT + 1 }
    end
    return list
  end
end

-- The tooltip, drawn before the panels, again on top of them (see buildTable).
local function drawTooltipOnTop(data)
  if data.tooltip ~= nil then
    data.tooltipLate = true
    data.tooltip()
  end
end

-- Draws a row of buttons above the panel, centred on the screen (squeezed together when wider
-- than it), on the map surface like the description line, and lays out the row's items to
-- match. Every frame while the panel is shown; the panel item hides the items otherwise.
-- The variant locks, shared by the castle panels and the pipette: the building variant the
-- rotation leaves alone (its placement id), and the hovel variant + 1 (0: the game's own).
function C.locks()
  C.lockWords = C.lockWords or { variant = core.allocate(4, true), hovel = core.allocate(4, true),
    ruined = core.allocate(4, true) }               -- and the ruined cathedral choice (1)
  return C.lockWords
end

-- A chosen variant stays chosen, a chosen hovel variant is placed every time (map editor).
function C.patchVariantLocks(self, G)
  local locks = C.locks()
  local turn = scan(K.AOB_VARIANT_TURN, "the variant rotation")
  local T = K.VARIANT_TURN
  C.patchJump(self, turn, T.size, core.allocateAssembly(templates.variantLock, {
    SUBTYPE = G.subtype, VARIANT_LOCK = locks.variant, TURN_ADD = rd32(turn + T.add) & 0xFFFFFFFF,
    TURN_END = turn + T.endRel + 1 + (rd8(turn + T.endRel) & 0xFF), BACK = turn + T.size,
  }))
  local hovel = scan(K.AOB_HOVEL_VARIANT, "the hovel variants")
  local H = K.HOVEL_VARIANT
  local counter = rd32(hovel + H.counter)
  C.patchJump(self, hovel, H.size, core.allocateAssembly(templates.hovelVariant, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, HOVEL_LOCK = locks.hovel, COUNTER = counter,
    BACK = hovel + H.size,
  }))
  local preview = scan(K.AOB_HOVEL_PREVIEW, "the hovel preview") + K.HOVEL_PREVIEW.site
  C.patchJump(self, preview, K.HOVEL_PREVIEW.size, core.allocateAssembly(templates.hovelPreview, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, HOVEL_LOCK = locks.hovel, COUNTER = counter,
    BACK = preview + K.HOVEL_PREVIEW.size,
  }))
  local advance = hovel + H.advance
  C.patchJump(self, advance, H.advanceSize, core.allocateAssembly(templates.hovelAdvance, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, HOVEL_LOCK = locks.hovel, COUNTER = counter,
    SKIP = hovel + H.skipRel + 1 + (rd8(hovel + H.skipRel) & 0xFF), BACK = advance + H.advanceSize,
  }))
end

-- A cathedral placed in the map editor while "Ruined" is chosen gets the ruined picture. Placing
-- leaves the new building's id at TileMapState + 0x554888; a check every frame (castle menu,
-- pipette) sees a new one there. (ClickPlaceBuilding's call to placeBuilding is not hooked:
-- interface-visual-fixes checks that call and its return address.)
function C.ruinWatch(G)
  if C.watchRuins ~= nil then return C.watchRuins end
  local ruined = scan(K.AOB_RUINED_CATHEDRAL, "the ruined cathedral")
  local RC = K.RUINED_CATHEDRAL
  local flagField, pictureField = rd32(ruined + RC.flag), rd32(ruined + RC.pictureField)
  local picture, tileMap = rd32(ruined + RC.picture), rd32(ruined + RC.tileMap)
  local update = core.exposeCode(readCallTarget(ruined, RC.update, "updateBuildingGraphicsLayer"), 2, 1)
  local stride = rd32(scan(K.AOB_BUILDING_TYPE, "the building types") + K.BUILDING_TYPE.stride)
  local gameMode = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND)
  local choice = C.locks().ruined
  local warned = false
  -- The ruin is 169 pictures from RUINED on in tile_churches.gm1; older copies end before it.
  local function ruinThere(id)
    local gm = rd16(pictureField + K.GM_AFTER_PICTURE + id * stride)
    local first, after = rd32(G.firstPictures + gm * 4), rd32(G.firstPictures + (gm + 1) * 4)
    if after > first and picture + K.RUIN_PARTS - 1 <= after - first then return true end
    if not warned then
      warned = true
      log(WARNING, MODULE_NAME .. ": this game's tile_churches.gm1 has no ruined cathedral (it ends at picture "
        .. (after - first) .. "); cathedrals are placed whole")
    end
    return false
  end
  local seen = rd32(tileMap + K.LAST_PLACED)
  C.watchRuins = function()
    local id = rd32(tileMap + K.LAST_PLACED)
    if id == seen then return end
    seen = id
    if rd32(gameMode) ~= K.MAP_EDITOR or rd32(choice) ~= 1 or id <= 0 then return end
    if rd16(pictureField + K.TYPE_AFTER_PICTURE + id * stride) ~= K.CATHEDRAL_TYPE then return end
    if not ruinThere(id) then return end
    wr16(flagField + id * stride, 1)
    wr32(pictureField + id * stride, picture)
    update(tileMap, id)
  end
  return C.watchRuins
end

-- The rects a menu's guard keeps off the map (see K.GUARD_RECTS).
function C.guardRects(data)
  data.rects = core.allocate((K.GUARD_RECTS + 1) * K.RECT_SIZE, true)
  wr32(data.rects + K.GUARD_RECTS * K.RECT_SIZE, -1)
  data.nextRect = 0
end
function C.takeRect(data)
  if data == nil or data.rects == nil or data.nextRect >= K.GUARD_RECTS then return nil end
  local rect = data.rects + data.nextRect * K.RECT_SIZE
  data.nextRect = data.nextRect + 1
  return rect
end
function C.markRect(rect, x, y, width, height)
  if rect == nil then return end
  wr32(rect + 4, math.floor(x))
  wr32(rect + 8, math.floor(y))
  wr32(rect + 12, math.floor(width))
  wr32(rect + 16, math.floor(height))
  wr32(rect, 1)
end

local function makePanel(G, O, data, panel, entries)
  local rect = C.takeRect(data)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local colourBox = core.exposeCode(G.colourBox, 6, 1)
  local renderGM = core.exposeCode(G.renderGM, 5, 1)
  local renderNumber = core.exposeCode(G.renderNumber, 10, 1)
  local blit = core.exposeCode(G.blit, 3, 0)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local labelBuffer = core.allocate(16, true)
  local spriteBox = makeSpriteBoxes(G)

  -- A button image's gm, picture and size; nil while it is not loaded.
  local function image(index)
    local entry = G.buttonImages + index * IMAGE_SIZE
    local gm, picture = rd32(entry), rd32(entry + 4)
    local first = rd32(G.firstPictures + gm * 4)
    if first <= 0 then return nil end
    local header = G.pictureHeights - 2 + (first + picture - 1) * PICTURE_SIZE
    local width, height = rd16(header), rd16(header + 2)
    if width <= 0 or height <= 0 then return nil end
    return { gm = gm, picture = picture, width = width, height = height }
  end

  local function drawSprite(entry, x, y)
    local t = G.textures
    local mode, direct = rd32(t + TEXTURES_MODE), rd32(t + TEXTURES_DIRECT_PALETTE)
    local sprite, palette = rd32(G.sprite), rd32(G.spritePalette)
    wr32(t + TEXTURES_MODE, MAP_LAYER)
    wr32(t + TEXTURES_DIRECT_PALETTE, 1)
    wr32(G.sprite, entry.gm)
    wr32(G.spritePalette, entry.palette)
    renderGM(t, entry.gm, entry.picture, x, y)
    wr32(G.sprite, sprite)
    wr32(G.spritePalette, palette)
    wr32(t + TEXTURES_DIRECT_PALETTE, direct)
    wr32(t + TEXTURES_MODE, mode)
  end

  return function()
    local list = entries(rd32(G.subtype))
    for _, address in ipairs(panel.items) do wr16(address + ITEM_HIDDEN, 1) end
    if #list == 0 then return end
    local tallest = 0
    for _, entry in ipairs(list) do
      if entry.gm ~= nil then
        entry.box = spriteBox(entry.gm, entry.picture)
        if entry.box == nil then return end    -- the pictures are not loaded yet
      elseif entry.image ~= nil then
        entry.button = image(entry.image)
        if entry.button == nil then return end
        entry.box = { x = 0, y = 0, width = entry.button.width, height = entry.button.height }
        if entry.image2 ~= nil then              -- a second picture right of the first
          entry.button2 = image(entry.image2)
          if entry.button2 == nil then return end
          entry.box.width = entry.button.width + K.PANEL_PICTURE_GAP + entry.button2.width
          entry.box.height = math.max(entry.button.height, entry.button2.height)
        end
      else
        entry.box = { x = 0, y = 0, width = entry.picture.width, height = entry.picture.height }
      end
      tallest = math.max(tallest, entry.box.height)
    end

    local height = tallest + 2 * PANEL_PADDING + (list.labelRoom or 0)   -- labelRoom: labels above the pictures
    local sum = 0
    for _, entry in ipairs(list) do
      entry.width = entry.box.width + 2 * PANEL_PADDING
      entry.inset = PANEL_PADDING
      if entry.minWidth ~= nil and entry.width < entry.minWidth then   -- room for a long label
        entry.inset = PANEL_PADDING + (entry.minWidth - entry.width) // 2
        entry.width = entry.minWidth
      end
      sum = sum + entry.width
    end
    local screen = rd32(G.screenWidth)
    local gap = PANEL_GAP
    if #list > 1 and sum + gap * (#list - 1) > screen - 2 * PANEL_MARGIN then
      gap = (screen - 2 * PANEL_MARGIN - sum) / (#list - 1)
    end
    local total = sum + gap * (#list - 1)
    local menuX = rd32(G.menu + MENU_X)
    local top = PANEL_BOTTOM - height
    local x = (screen - total) / 2 - menuX + (list.shift or 0)
    local left = math.floor(x + 0.5)
    for _, entry in ipairs(list) do
      entry.x = math.floor(x + 0.5)
      wr32(entry.item + ITEM_X, entry.x)
      wr32(entry.item + ITEM_Y, top)
      wr32(entry.item + ITEM_WIDTH, entry.width)
      wr32(entry.item + ITEM_HEIGHT, height)
      if entry.param ~= nil then wr32(entry.item + ITEM_PARAM, entry.param) end
      wr16(entry.item + ITEM_HIDDEN, 0)
      x = x + entry.width + gap
    end
    local right = math.floor(x - gap + 0.5)
    local above = list.rectAbove or 0
    C.markRect(rect, left - PANEL_GAP, top - PANEL_GAP - above, right - left + 2 * PANEL_GAP,
      PANEL_BOTTOM - top + 2 * PANEL_GAP + above)

    local offsetX = menuX - rd32(G.menu + MENU_SCROLL) + rd32(G.cameraX)
    local offsetY = rd32(G.menu + MENU_Y) + rd32(G.cameraY)
    local white = rd32(G.pixelFormat) == 0x565 and 0xFFFF or 0x7FFF
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    roundedBox(G.pencil, offsetX + left - PANEL_GAP, offsetY + top - PANEL_GAP,
      offsetX + right + PANEL_GAP, offsetY + PANEL_BOTTOM + PANEL_GAP, BOX_BLEND)
    for _, entry in ipairs(list) do
      local l, r = offsetX + entry.x, offsetX + entry.x + entry.width - 1
      local upper, lower = offsetY + top, offsetY + PANEL_BOTTOM - 1
      if rd16(entry.item + ITEM_HOVERED) ~= 0 then
        roundedBox(G.pencil, l, upper, r, lower, BOX_BLEND)
      end
      if entry.chosen then
        colourBox(G.pencil, l, upper, r, upper + 1, white)
        colourBox(G.pencil, l, lower - 1, r, lower, white)
        colourBox(G.pencil, l, upper, l + 1, lower, white)
        colourBox(G.pencil, r - 1, upper, r, lower, white)
      end
    end
    for _, entry in ipairs(list) do
      local sx = offsetX + entry.x + entry.inset - entry.box.x
      local sy = offsetY + PANEL_BOTTOM - PANEL_PADDING - entry.box.height - entry.box.y
      if entry.gm == nil and entry.button == nil then blit(entry.picture.address, sx, sy) end
    end
    wr32(G.pencil + PENCIL_TARGET, target)
    for _, entry in ipairs(list) do
      local sx = offsetX + entry.x + entry.inset - entry.box.x
      local sy = offsetY + PANEL_BOTTOM - PANEL_PADDING - entry.box.height - entry.box.y
      if entry.gm ~= nil then
        drawSprite(entry, sx, sy)
      elseif entry.button ~= nil then
        local mode = rd32(G.textures + TEXTURES_MODE)
        wr32(G.textures + TEXTURES_MODE, MAP_LAYER)
        local first, second = entry.button, entry.button2
        renderGM(G.textures, first.gm, first.picture, sx, sy + entry.box.height - first.height)
        if second ~= nil then
          renderGM(G.textures, second.gm, second.picture, sx + first.width + K.PANEL_PICTURE_GAP,
            sy + entry.box.height - second.height)
        end
        wr32(G.textures + TEXTURES_MODE, mode)
      end
    end
    -- Labels (the random mixes' "?"), at the top of their button.
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    for _, entry in ipairs(list) do
      if entry.label ~= nil then
        writeCString(labelBuffer, entry.label)
        local width = textWidth(G.textManager, labelBuffer, #entry.label, TOOLTIP_FONT)
        shadowedText(G.textManager, labelBuffer, offsetX + entry.x + (entry.width - width) // 2,
          offsetY + top + PANEL_PADDING, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
      end
    end
    wr32(G.textLayer, layer)
    if O.counts and rd8(data.shown) ~= 0 then
      local layer = rd32(G.textLayer)
      wr32(G.textLayer, MAP_LAYER)
      for _, entry in ipairs(list) do
        if entry.count ~= nil then
          renderNumber(G.textManager, rd32(entry.count), offsetX + entry.x + entry.width // 2,
            offsetY + PANEL_BOTTOM - NUMBER_FROM_BOTTOM, 1, NUMBER_COLOUR, 0, NUMBER_FONT, 0, 0)
        end
      end
      wr32(G.textLayer, layer)
    end

    -- The "i" was drawn before the panel (it belongs to the part of the menu that is always
    -- shown); draw it again on top, the way its own renderer does (picture + 1 under the mouse).
    if panel.info ~= nil then
      local image = G.buttonImages + INFO_IMAGE * IMAGE_SIZE
      local picture = rd32(image + 4)
      if rd16(panel.info + ITEM_HOVERED) ~= 0 then picture = picture + 1 end
      local mode = rd32(G.textures + TEXTURES_MODE)
      wr32(G.textures + TEXTURES_MODE, MAP_LAYER)
      renderGM(G.textures, rd32(image), picture, offsetX + rd32(panel.info + ITEM_X),
        offsetY + rd32(panel.info + ITEM_Y))
      wr32(G.textures + TEXTURES_MODE, mode)
    end
    drawTooltipOnTop(data)
  end
end

---------------------------------------------------------------------------------------
-- The herd panel above the Animals menu
---------------------------------------------------------------------------------------

-- Two lines of text in a box centred on the screen: the chosen animal's herd (base + random
-- part, or 2 x brush - 1 with the check box on) and troop type, and the check box with its
-- label. The check box item is placed under its picture.
local function makeHerdPanel(G, O, data, herd)
  local rect = C.takeRect(data)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local renderGM = core.exposeCode(G.renderGM, 5, 1)
  local buffers = { core.allocate(128, true), core.allocate(128, true) }

  return function()
    wr16(herd.checkBox + ITEM_HIDDEN, 1)
    local animal = G.herds[rd32(G.subtype)]
    if animal == nil then return end
    local brush = rd32(G.brush)
    local size
    if rd8(data.herdSync) ~= 0 then
      size = string.format("2 x brush %d - 1 = %d animals", brush, 2 * brush - 1)
    else
      size = string.format("%d + 0 to %d animals", animal.base, animal.mask)
    end
    local texts = {
      string.format("%s herd: %s, group behaviour type %d", animal.name, size, animal.group),
      "Herd size from the brush size: 2 x brush - 1",
    }
    local widths = {}
    for i, text in ipairs(texts) do
      writeCString(buffers[i], text)
      widths[i] = textWidth(G.textManager, buffers[i], #text, TOOLTIP_FONT)
    end
    local line = math.max(TOOLTIP_LINE, K.CHECK_BOX_SIZE + 2)
    local width = math.max(widths[1], K.CHECK_BOX_SIZE + TOOLTIP_PADDING + widths[2]) + 2 * TOOLTIP_PADDING
    local height = TOOLTIP_LINE + line + 2 * TOOLTIP_PADDING
    local menuX = rd32(G.menu + MENU_X)
    local left = (rd32(G.screenWidth) - width) // 2 - menuX
    local top = PANEL_BOTTOM - height
    local boxX, boxY = left + TOOLTIP_PADDING, top + TOOLTIP_PADDING + TOOLTIP_LINE
    C.markRect(rect, left, top, width, PANEL_BOTTOM - top)
    wr32(herd.checkBox + ITEM_X, boxX)
    wr32(herd.checkBox + ITEM_Y, boxY)
    wr32(herd.checkBox + ITEM_WIDTH, K.CHECK_BOX_SIZE)
    wr32(herd.checkBox + ITEM_HEIGHT, K.CHECK_BOX_SIZE)
    wr16(herd.checkBox + ITEM_HIDDEN, 0)

    local offsetX = menuX - rd32(G.menu + MENU_SCROLL) + rd32(G.cameraX)
    local offsetY = rd32(G.menu + MENU_Y) + rd32(G.cameraY)
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    roundedBox(G.pencil, offsetX + left, offsetY + top, offsetX + left + width, offsetY + PANEL_BOTTOM, BOX_BLEND)
    wr32(G.pencil + PENCIL_TARGET, target)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    shadowedText(G.textManager, buffers[1], offsetX + left + TOOLTIP_PADDING, offsetY + top + TOOLTIP_PADDING // 2,
      ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    shadowedText(G.textManager, buffers[2], offsetX + boxX + K.CHECK_BOX_SIZE + TOOLTIP_PADDING,
      offsetY + boxY + (K.CHECK_BOX_SIZE - TOOLTIP_LINE) // 2 + 2, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    wr32(G.textLayer, layer)

    local image = G.buttonImages + (rd8(data.herdSync) ~= 0 and K.CHECKED_IMAGE or K.UNCHECKED_IMAGE) * IMAGE_SIZE
    local picture = rd32(image + 4)
    if rd16(herd.checkBox + ITEM_HOVERED) ~= 0 then picture = picture + 1 end
    local mode = rd32(G.textures + TEXTURES_MODE)
    wr32(G.textures + TEXTURES_MODE, MAP_LAYER)
    renderGM(G.textures, rd32(image), picture, offsetX + boxX, offsetY + boxY)
    wr32(G.textures + TEXTURES_MODE, mode)
    drawTooltipOnTop(data)
  end
end

---------------------------------------------------------------------------------------
-- Spreading rows of buttons over the panel
---------------------------------------------------------------------------------------

-- Once the buttons' pictures are loaded and the menu has placed them, spread rows of buttons
-- evenly between ROW_LEFT and ROW_RIGHT. Buttons keep their height; new ones (in `added`) are
-- centred on their left neighbour. A row with `bottom` set stands its buttons on a common
-- line instead (the lowest bottom edge among them). Buttons with their own pictures have their
-- size in `sizeOf`, the others are measured by their gm picture. Moved buttons are taken off
-- the user control table, which would put them back the next time the menu loads. Each of
-- `places` puts one more item somewhere once it can (it answers whether it has).
local function makeLayout(G, rows, added, sizeOf, places, finishes)
  local function measure(address)
    local size = sizeOf[address]
    if size ~= nil then return size[1], size[2] end
    local index = rd32(address + ITEM_IMAGE) & IMAGE_INDEX_MASK
    local gm = rd32(G.buttonImages + index * IMAGE_SIZE)
    local first = rd32(G.firstPictures + gm * 4)
    if first <= 0 then return nil end
    local header = G.pictureHeights - 2 + (first + rd32(G.buttonImages + index * IMAGE_SIZE + 4) - 1) * PICTURE_SIZE
    local width, height = rd16(header), rd16(header + 2)
    if width <= 0 then return nil end
    return width, height
  end

  return function()
    for _, place in ipairs(places or {}) do
      if not place(measure) then return false end
    end
    for _, row in ipairs(rows) do
      local widths, heights, sum = {}, {}, 0
      for i, address in ipairs(row) do
        local width, height = measure(address)
        if width == nil then return false end
        if not added[address] and (rd32(address + ITEM_X) & 0xFFFFFFFF) == PLACED_BY_CONTROL then
          return false                         -- the menu has not been loaded yet
        end
        widths[i], heights[i], sum = width, height, sum + width
      end
      row.widths, row.heights, row.sum = widths, heights, sum
    end
    for _, row in ipairs(rows) do
      local line = nil
      if row.bottom then
        for i, address in ipairs(row) do
          if not added[address] then line = math.max(line or 0, rd32(address + ITEM_Y) + row.heights[i]) end
        end
      end
      local gap = (ROW_RIGHT - ROW_LEFT - row.sum) / (#row - 1)
      local x, y, h = ROW_LEFT, nil, nil
      for i, address in ipairs(row) do
        if line ~= nil then
          wr32(address + ITEM_Y, line - row.heights[i])
        elseif added[address] then
          wr32(address + ITEM_Y, y + (h - row.heights[i]) // 2)
        else
          y, h = rd32(address + ITEM_Y), row.heights[i]
        end
        wr32(address + ITEM_X, math.floor(x + 0.5))
        wr16(address + ITEM_CONTROL, -1)
        wr16(address + ITEM_HIDDEN, 0)
        x = x + row.widths[i] + gap
      end
    end
    for _, finish in ipairs(finishes or {}) do finish() end
    return true
  end
end

---------------------------------------------------------------------------------------
-- The new item table
---------------------------------------------------------------------------------------

-- Copies the item table with the module's items inserted (in front of the original item
-- whose index they are listed under) and fills them in.
local function buildTable(G, O)
  local data = {}
  C.guardRects(data)
  local pictures = {}
  if O.apple then pictures.apple = buttonPictures("apple") end
  if O.textures then pictures.gravel = buttonPictures("gravel") end
  local rockTabs, boxTabs = {}, {}
  for _, tab in ipairs({ ROCKS, K.ROCKS_SKIRMISH }) do
    if G.blockEnd[tab] ~= nil then
      if O.variants then rockTabs[#rockTabs + 1] = tab end
      if O.invisibleRocks then boxTabs[#boxTabs + 1] = tab end
    end
  end

  local inserts = {}
  local function insert(before, kind)
    inserts[before] = inserts[before] or {}
    table.insert(inserts[before], kind)
  end
  insert(MAP_CLICK_ITEM, "guard")
  if O.undo then
    insert(MAP_CLICK_ITEM, "undo")
    insert(MAP_CLICK_ITEM, "redo")
  end
  if O.compass then insert(MAP_CLICK_ITEM, "compass") end
  if O.counts then insert(INFO_BEFORE_ITEM, "info") end
  if O.treePreview then insert(INFO_BEFORE_ITEM, "treePreview") end
  local pipetteItems = { "pipetteTick", "pipette", "pipettePanel" }
  if O.pipette then
    insert(MAP_CLICK_ITEM, "pipetteTick")
    insert(INFO_BEFORE_ITEM, "pipette")
    for i = 1, #K.PIPETTE_MODES do
      insert(INFO_BEFORE_ITEM, "pipetteMode" .. i)
      pipetteItems[#pipetteItems + 1] = "pipetteMode" .. i
    end
    insert(INFO_BEFORE_ITEM, "pipettePanel")
  end
  if O.eraserChoice then
    for i = 1, #K.ERASER_MODES do insert(INFO_BEFORE_ITEM, "eraserMode" .. i) end
    insert(INFO_BEFORE_ITEM, "eraserPanel")
  end
  if O.textureMask then insert(G.firstBlock, "maskButton") end
  if O.counts or O.obstacles or O.rocksAndWater or O.invisibleRocks or O.apple or O.textures or O.waterDecorations
      or O.maxHeight or O.lostRocks or O.textureMask or O.birdButtons or O.animalBin then
    insert(G.firstBlock, "tooltip")
  end
  if G.blockEnd[K.HEIGHTS_TAB] == nil or G.buttons[K.MIN_HEIGHT_TOOL] == nil then
    O.maxHeight, O.heightTools = false, false
  end
  for _, kind in ipairs(C.heightItems(O)) do insert(G.blockEnd[K.HEIGHTS_TAB], kind) end
  if O.heightTools then insert(MAP_CLICK_ITEM, "heightTick") end
  local animalsEnd = G.blockEnd[ANIMALS]
  if O.herds then
    insert(animalsEnd, "herdCheck")
    insert(animalsEnd, "herdPanel")
  end
  if O.counts then insert(animalsEnd, "numbers" .. ANIMALS) end
  if O.birdButtons then
    insert(animalsEnd, "crowBin")
    insert(animalsEnd, "gullBin")
  end
  if O.animalBin then insert(animalsEnd, "animalBin") end
  local vegetationEnd = G.blockEnd[VEGETATION]
  if O.apple then insert(vegetationEnd, "apple") end
  if O.shrubs then
    for i = 1, #SHRUB_COMMANDS do insert(vegetationEnd, "shrub" .. i) end
    if O.randomMix then insert(vegetationEnd, "randomShrub") end
  end
  local felledButtons = 1 + MOST_LOGS + (O.randomMix and 2 or 0)
  if O.obstacles then insert(vegetationEnd, OBSTACLES_BUTTON) end
  if O.rocksAndWater then insert(vegetationEnd, "rocksAndWater") end
  if O.felled then
    for i = 1, felledButtons do insert(vegetationEnd, "felled" .. i) end
  end
  if O.shrubs or O.felled then insert(vegetationEnd, "panel") end
  if O.counts then insert(vegetationEnd, "numbers" .. VEGETATION) end
  if O.spreadOutlines then insert(vegetationEnd, "spreadOutline") end
  if O.textures then
    insert(G.blockEnd[TEXTURES], "gravel")
    insert(G.blockEnd[TEXTURES], "iron")
  end
  -- New items that are not button copies go after the copies: the menu only gives a copy its
  -- group's renderer while the copies follow the group's buttons with nothing in between.
  if O.textureMask then insert(MAP_CLICK_ITEM, "maskTick") end
  if O.waterDecorations and G.blockEnd[K.WATER] ~= nil then
    for _, decoration in ipairs(K.WATER_DECORATIONS) do insert(G.blockEnd[K.WATER], "water" .. decoration.command) end
  end
  for _, tab in ipairs(rockTabs) do
    for v = 1, K.ROCK_VARIANTS + 1 do insert(G.blockEnd[tab], "rock" .. tab .. "/" .. v) end
    insert(G.blockEnd[tab], "rockPanel" .. tab)
  end
  for _, tab in ipairs(boxTabs) do insert(G.blockEnd[tab], "invisible" .. tab) end
  if O.lostRocks then
    for _, tab in ipairs({ ROCKS, K.ROCKS_SKIRMISH }) do
      if G.blockEnd[tab] ~= nil then insert(G.blockEnd[tab], "lostRocks" .. tab) end
    end
  end

  local count = ITEM_COUNT + 1
  for _, list in pairs(inserts) do count = count + #list end
  local newTable = core.allocate(count * MENU_ITEM_SIZE, true)
  local movedTo, added, slot = {}, {}, 0
  for i = 0, ITEM_COUNT do
    for _, kind in ipairs(inserts[i] or {}) do
      added[kind] = item(newTable, slot)
      slot = slot + 1
    end
    core.writeBytes(item(newTable, slot), core.readBytes(item(G.table, i), MENU_ITEM_SIZE))
    movedTo[i] = slot
    slot = slot + 1
  end
  local function moved(index) return movedTo[index] end
  local function button(param) return item(newTable, moved(G.buttons[param].index)) end
  local function copyOf(param, into)
    core.writeBytes(into, core.readBytes(item(G.table, G.buttons[param].index), MENU_ITEM_SIZE))
  end
  -- A lua function called from injected code: a pad that runs it, switched off after an error.
  local function luaPad(fn, what)
    local pad = core.allocateCode({ 0x90, 0x90, 0x90, 0x90, 0x90, 0xC3 })
    local broken = false
    core.detourCode(function(registers)
      if not broken then
        local ok, problem = pcall(fn)
        if not ok then
          broken = true
          log(WARNING, string.format("%s: %s stopped after an error: %s", MODULE_NAME, what, tostring(problem)))
        end
      end
      return registers
    end, pad, 5)
    return pad
  end
  -- A button with no picture of its own, never drawn by the menu.
  local function plainButton(into, action)
    wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(into + ITEM_ACTION, action)
    wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
    wr16(into + ITEM_HIDDEN, 1)
  end

  data.shown = core.allocate(4, true)
  wr32(data.shown, O.shown and 1 or 0)
  data.felledLogs = core.allocate(4, true)
  data.felledCommand = core.allocate(4, true)
  data.rockLock = core.allocate(4, true)
  data.herdSync = core.allocate(4, true)
  data.nearObstacles = core.allocate(4, true)
  data.rocksAndWater = core.allocate(4, true)
  data.randomShrub = core.allocate(4, true)
  data.invisibleRocks = core.allocate(4, true)
  data.seed = core.allocate(4, true)
  wr32(data.seed, os.time())
  local unused = core.allocate(8, true)        -- the panel template's felled tree state, for panels without it
  if next(pictures) ~= nil or #rockTabs > 0 then
    G.blit = core.allocateAssembly(templates.blit, {
      PENCIL = G.pencil, SETUP_SURFACE = G.setupSurface, SETUP_PENCIL = G.setupPencil,
      SCRATCH = core.allocate(32, true), PIXEL_FORMAT = G.pixelFormat,
    })
  end
  local guarded = {}
  local tooltips = {}

  -- Map counts.
  if O.counts then
    data.totals = core.allocate(12, true)
    data.typeCounts = core.allocate(TREE_TYPES * 4, true)
    local countSlots = core.allocateAssembly(templates.countSlots, {
      TYPE_COUNTS = data.typeCounts, TREE_TYPES = TREE_TYPES, TOTALS = data.totals,
      FIRST_TREE = G.firstTree, TREE_SLOTS = G.treeSlots, TREE_SIZE = G.treeSize,
      TREE_TYPE_FROM_IN_USE = TREE_TYPE_FROM_IN_USE,
      FIRST_ROCK = G.firstRock, ROCK_SLOTS = G.rockSlots, ROCK_SIZE = G.rockSize,
      FIRST_GROUP = G.firstGroup, GROUP_SLOTS = G.groupSlots, GROUP_SIZE = G.groupSize,
    })
    wr32(item(newTable, moved(HOVER_TEXT_ITEM), ITEM_RENDER), core.allocateAssembly(templates.descriptionLine, {
      SHOWN = data.shown, COUNT_SLOTS = countSlots, HOVER_RENDER = G.hoverRender,
    }))
    wr32(item(newTable, moved(HOVER_TEXT_ITEM), ITEM_X), HOVER_TEXT_MOVED_X)

    -- The numbers of the Animals and Vegetation tabs: per tab a list of (button, counter).
    local counted = { [ANIMALS] = {}, [VEGETATION] = {} }
    for param, address in pairs(G.animals) do
      table.insert(counted[ANIMALS], button(param))
      table.insert(counted[ANIMALS], address)
    end
    for _, param in ipairs(G.plants) do
      table.insert(counted[VEGETATION], button(param))
      table.insert(counted[VEGETATION], data.typeCounts + G.plantTypes[param] * 4)
    end
    if O.apple then
      table.insert(counted[VEGETATION], added.apple)
      table.insert(counted[VEGETATION], data.typeCounts + APPLE_TYPE * 4)
    end
    local tabNumbers = core.allocateAssembly(templates.tabNumbers, {
      SHOWN = data.shown, ITEM_MENU = ITEM_MENU, ITEM_HIDDEN = ITEM_HIDDEN, MENU_X = MENU_X, MENU_Y = MENU_Y,
      MENU_SCROLL = MENU_SCROLL, ITEM_X = ITEM_X, ITEM_Y = ITEM_Y, ITEM_WIDTH = ITEM_WIDTH,
      ITEM_HEIGHT = ITEM_HEIGHT, NUMBER_FROM_BOTTOM = NUMBER_FROM_BOTTOM, NUMBER_FONT = NUMBER_FONT,
      NUMBER_COLOUR = NUMBER_COLOUR, TEXT_MANAGER = G.textManager, RENDER_NUMBER = G.renderNumber,
    })
    for tab, list in pairs(counted) do
      local numbers = added["numbers" .. tab]
      wr32(numbers + ITEM_TYPE, TYPE_CLICKABLE)    -- no size, so never under the mouse
      wr32(numbers + ITEM_PARAM, dwordList(list))
      wr32(numbers + ITEM_RENDER, tabNumbers)
      wr32(numbers + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    end

    -- The "i" button.
    local info = added.info
    wr32(info + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(info + ITEM_X, INFO_BUTTON[1])
    wr32(info + ITEM_Y, INFO_BUTTON[2])
    wr32(info + ITEM_ACTION, core.allocateAssembly(templates.toggle, { SHOWN = data.shown }))
    wr32(info + ITEM_RENDER, core.allocateAssembly(templates.infoButton, {
      CAMERA_X = G.cameraX, CAMERA_Y = G.cameraY, ITEM_X = G.itemX, ITEM_Y = G.itemY,
      DRAW_MODE = G.drawMode, IMAGE_BUTTON = G.imageButton,
    }))
    wr32(info + ITEM_IMAGE, INFO_IMAGE)
    wr32(info + ITEM_RENDER_TYPE, RENDER_IMAGE)
    wr32(info + ITEM_TEXT, 0)              -- no description, the usual hover sound
    guarded[#guarded + 1] = info
    guarded[#guarded + 1] = 0

    -- The category tooltips.
    local function counts(...)
      local lines = { ... }
      return function()
        if rd8(data.shown) == 0 then return nil end
        local texts = {}
        for i, line in ipairs(lines) do
          texts[i] = line.text ~= nil and line.text() or string.format("%s: %d/%d", line[1], line[2](), line[3])
        end
        return texts
      end
    end
    local birds = { text = function()
      local ok, D = pcall(C.resolveBirds, G)
      if not ok then return "Birds: -" end
      local crows, gulls = C.birdCounts(G, D)
      return string.format("Birds: %d crows, %d/%d seagulls", crows, gulls, D.gullSlots - 1)
    end }
    tooltips[#tooltips + 1] = { item = button(ANIMALS), lines = counts(
      { "Animals and units", function() return rd32(G.units) end, G.unitMax or G.unitLimit },
      { "Herds and groups", function() return rd32(data.totals + 8) end, G.groupSlots }, birds) }
    tooltips[#tooltips + 1] = { item = button(VEGETATION), lines = counts(
      { "Trees and shrubs", function() return rd32(data.totals) end, G.treeSlots }) }
    tooltips[#tooltips + 1] = { item = button(ROCKS), lines = counts(
      { "Rocks", function() return rd32(data.totals + 4) end, G.rockSlots }) }
  end

  -- Buttons drawn from PNG pictures: a copy of a button of their tab, their own command and
  -- pictures, hidden until laid out.
  local function pictureButton(into, model, command, set)
    copyOf(model, into)
    wr32(into + ITEM_X, 0)
    wr32(into + ITEM_Y, 0)
    wr32(into + ITEM_WIDTH, set.width)
    wr32(into + ITEM_HEIGHT, set.height)
    wr32(into + ITEM_PARAM, command)
    wr32(into + ITEM_IMAGE, 0)
    wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(into + ITEM_TEXT, 0)
    wr16(into + ITEM_HIDDEN, 1)
    wr32(into + ITEM_RENDER, core.allocateAssembly(templates.pictureButton, {
      NORMAL = set.normal, HOVERED = set.hover, CHOSEN = set.chosen, COMMAND = command,
      SUBTYPE = G.subtype, HOVER = G.hover, PENCIL = G.pencil, PENCIL_TARGET = PENCIL_TARGET,
      ITEM_X = G.itemX, ITEM_Y = G.itemY, BLIT = G.blit,
    }))
  end

  local rows, newButtons, sizeOf = {}, {}, {}
  local language = C.language()
  local hoverText = item(newTable, moved(HOVER_TEXT_ITEM))
  G.describeAt = { rd32(hoverText + ITEM_X), rd32(hoverText + ITEM_Y) }
  if O.apple then
    tooltips[#tooltips + 1] = { item = added.apple, name = K.NAMES.apple[language] }
    pictureButton(added.apple, VEGETATION_TREES[1], APPLE_COMMAND, pictures.apple)
    sizeOf[added.apple] = { pictures.apple.width, pictures.apple.height }
    newButtons[added.apple] = true
  end

  -- The obstacles check box: in the Vegetation menu, drawn like the menu's buttons.
  if O.obstacles then
    local box = added[OBSTACLES_BUTTON]
    wr32(box + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(box + ITEM_WIDTH, K.CHECK_BOX_SIZE)
    wr32(box + ITEM_HEIGHT, K.CHECK_BOX_SIZE)
    wr32(box + ITEM_ACTION, core.allocateAssembly(templates.flip, { FLAG = data.nearObstacles }))
    wr32(box + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(box + ITEM_RENDER, core.allocateAssembly(templates.checkBox, {
      FLAG = data.nearObstacles, ON_IMAGE = G.buttonImages + K.CHECKED_IMAGE * IMAGE_SIZE,
      OFF_IMAGE = G.buttonImages + K.UNCHECKED_IMAGE * IMAGE_SIZE,
      HOVER = G.hover, DRAW_MODE = G.drawMode, ITEM_X = G.itemX, ITEM_Y = G.itemY,
      TEXTURES = G.textures, RENDER_GM = G.renderGM,
    }))
    wr16(box + ITEM_HIDDEN, 1)
    sizeOf[box] = { K.CHECK_BOX_SIZE, K.CHECK_BOX_SIZE }
    newButtons[box] = true
    tooltips[#tooltips + 1] = { item = box, lines = function()
      return { "Trees next to obstacles: " .. (rd8(data.nearObstacles) ~= 0 and "allowed" or "not allowed") }
    end, raise = K.CHECK_BOX_TOOLTIP_RAISE }
  end

  -- The Vegetation on rocks and water check box: right of the Vegetation menu, below the
  -- obstacles check box (which moves up and left to make room).
  local finishes = {}
  if O.obstacles then
    local box = added[OBSTACLES_BUTTON]
    finishes[#finishes + 1] = function()
      wr32(box + ITEM_X, rd32(box + ITEM_X) + K.OBSTACLES_NUDGE[1])
      wr32(box + ITEM_Y, rd32(box + ITEM_Y) + K.OBSTACLES_NUDGE[2])
    end
  end
  if O.rocksAndWater then
    local box = added.rocksAndWater
    wr32(box + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(box + ITEM_WIDTH, K.CHECK_BOX_SIZE)
    wr32(box + ITEM_HEIGHT, K.CHECK_BOX_SIZE)
    wr32(box + ITEM_ACTION, core.allocateAssembly(templates.flip, { FLAG = data.rocksAndWater }))
    wr32(box + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(box + ITEM_RENDER, core.allocateAssembly(templates.checkBox, {
      FLAG = data.rocksAndWater, ON_IMAGE = G.buttonImages + K.CHECKED_IMAGE * IMAGE_SIZE,
      OFF_IMAGE = G.buttonImages + K.UNCHECKED_IMAGE * IMAGE_SIZE,
      HOVER = G.hover, DRAW_MODE = G.drawMode, ITEM_X = G.itemX, ITEM_Y = G.itemY,
      TEXTURES = G.textures, RENDER_GM = G.renderGM,
    }))
    wr16(box + ITEM_HIDDEN, 1)
    tooltips[#tooltips + 1] = { item = box, lines = function()
      return { "Vegetation on rocks and water: " .. (rd8(data.rocksAndWater) ~= 0 and "allowed" or "not allowed") }
    end, raise = K.CHECK_BOX_TOOLTIP_RAISE }
    local above = O.obstacles and added[OBSTACLES_BUTTON] or nil
    local top = button(VEGETATION_TREES[1])
    finishes[#finishes + 1] = function()
      if above ~= nil then
        wr32(box + ITEM_X, rd32(above + ITEM_X))
        wr32(box + ITEM_Y, rd32(above + ITEM_Y) + K.CHECK_BOX_SIZE + K.ROCKS_AND_WATER_GAP)
      else
        wr32(box + ITEM_X, ROW_RIGHT + K.CHECK_BOX_GAP)
        wr32(box + ITEM_Y, rd32(top + ITEM_Y))
      end
      wr16(box + ITEM_HIDDEN, 0)
    end
  end

  -- The Vegetation menu's rows: the trees, the apple tree and the check box on top (the
  -- shrub moves down, unless the rows are left as they are), the shrubs sorted below.
  if O.apple or O.obstacles or O.sortedRows or O.spreadOrder then
    local top = {}
    for _, param in ipairs(O.spreadOrder and K.SPREAD_TREES or VEGETATION_TREES) do top[#top + 1] = button(param) end
    if O.apple then top[#top + 1] = added.apple end
    if not O.sortedRows then top[#top + 1] = button(TOP_ROW_SHRUB) end
    if O.obstacles then top[#top + 1] = added[OBSTACLES_BUTTON] end
    rows[#rows + 1] = top
  end
  if O.sortedRows then
    local bottom = { bottom = true }
    for _, param in ipairs(SORTED_SHRUBS) do bottom[#bottom + 1] = button(param) end
    rows[#rows + 1] = bottom
  end

  if O.textures then
    tooltips[#tooltips + 1] = { item = added.gravel, name = K.NAMES.gravel[language] }
    pictureButton(added.gravel, TEXTURE_ROWS[1][1], GRAVEL_COMMAND, pictures.gravel)
    sizeOf[added.gravel] = { pictures.gravel.width, pictures.gravel.height }
    newButtons[added.gravel] = true
    -- Iron: a copy of the Heights menu's iron button, picture and description included.
    copyOf(IRON_COMMAND, added.iron)
    wr32(added.iron + ITEM_X, 0)
    wr32(added.iron + ITEM_Y, 0)
    wr16(added.iron + ITEM_HIDDEN, 1)
    newButtons[added.iron] = true
    for _, rowCommands in ipairs(TEXTURE_ROWS) do
      local row = {}
      for _, param in ipairs(rowCommands) do
        if param == GRAVEL_COMMAND then
          row[#row + 1] = added.gravel
        elseif param == IRON_COMMAND then
          row[#row + 1] = added.iron
        else
          row[#row + 1] = button(param)
        end
      end
      rows[#rows + 1] = row
    end
  end
  -- The invisible rocks check box: right of the Rocks menu's last button.
  local places = {}
  for _, tab in ipairs(boxTabs) do
    local box = added["invisible" .. tab]
    wr32(box + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(box + ITEM_WIDTH, K.CHECK_BOX_SIZE)
    wr32(box + ITEM_HEIGHT, K.CHECK_BOX_SIZE)
    wr32(box + ITEM_ACTION, core.allocateAssembly(templates.flip, { FLAG = data.invisibleRocks }))
    wr32(box + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(box + ITEM_RENDER, core.allocateAssembly(templates.checkBox, {
      FLAG = data.invisibleRocks, ON_IMAGE = G.buttonImages + K.CHECKED_IMAGE * IMAGE_SIZE,
      OFF_IMAGE = G.buttonImages + K.UNCHECKED_IMAGE * IMAGE_SIZE,
      HOVER = G.hover, DRAW_MODE = G.drawMode, ITEM_X = G.itemX, ITEM_Y = G.itemY,
      TEXTURES = G.textures, RENDER_GM = G.renderGM,
    }))
    wr16(box + ITEM_HIDDEN, 1)
    tooltips[#tooltips + 1] = { item = box, lines = function()
      return { "Invisible rocks: " .. (rd8(data.invisibleRocks) ~= 0 and "on" or "off") }
    end, raise = K.CHECK_BOX_TOOLTIP_RAISE }
    local buttons = {}
    for _, rock in ipairs(G.rockButtons) do
      if rock.block == tab then buttons[#buttons + 1] = item(newTable, moved(rock.index)) end
    end
    if tab == ROCKS and G.buttons[K.SIGNPOST] ~= nil then buttons[#buttons + 1] = button(K.SIGNPOST) end
    places[#places + 1] = function(measure)
      local right, y, height = nil, 0, 0
      for _, address in ipairs(buttons) do
        local x = rd32(address + ITEM_X)
        if (x & 0xFFFFFFFF) == PLACED_BY_CONTROL then return false end
        local width, h = measure(address)
        if width == nil then return false end
        if right == nil or x + width > right then right, y, height = x + width, rd32(address + ITEM_Y), h end
      end
      wr32(box + ITEM_X, right + K.CHECK_BOX_GAP)
      wr32(box + ITEM_Y, y + (height - K.CHECK_BOX_SIZE) // 2)
      wr16(box + ITEM_HIDDEN, 0)
      return true
    end
  end
  -- Foam and small waves: copies of the river button with their own command and picture, put
  -- at the end of the water menu's shortest rows once the menu has placed its buttons.
  if O.waterDecorations and G.blockEnd[K.WATER] ~= nil then
    local waters, decorations = {}, {}
    for _, button in pairs(G.buttons) do
      if button.block == K.WATER then waters[#waters + 1] = item(newTable, moved(button.index)) end
    end
    for _, decoration in ipairs(K.WATER_DECORATIONS) do
      local into = added["water" .. decoration.command]
      copyOf(K.RIVER, into)
      wr32(into + ITEM_X, 0)
      wr32(into + ITEM_Y, 0)
      wr32(into + ITEM_PARAM, decoration.command)
      wr32(into + ITEM_IMAGE, decoration.image)
      wr32(into + ITEM_TEXT, 0)
      wr16(into + ITEM_CONTROL, -1)
      wr16(into + ITEM_HIDDEN, 1)
      decorations[#decorations + 1] = into
      tooltips[#tooltips + 1] = { item = into, name = K.NAMES[decoration.name][language] }
    end
    -- Once the menu has placed its buttons: the two join its shortest rows (a row: buttons whose
    -- middles are within K.ROW_TOLERANCE of each other). Every button keeps its height on the
    -- panel; a row keeps its left edge and only its gaps shrink, so that it ends no further
    -- right than ROW_RIGHT (or its own right edge, if that is further).
    places[#places + 1] = function(measure)
      local buttons = {}
      for _, address in ipairs(waters) do
        local x = rd32(address + ITEM_X)
        if (x & 0xFFFFFFFF) == PLACED_BY_CONTROL then return false end
        local width, height = measure(address)
        if width == nil then return false end
        local y = rd32(address + ITEM_Y)
        buttons[#buttons + 1] = { address = address, x = x, y = y, width = width, height = height,
          middle = y + height / 2 }
      end
      if #buttons == 0 then return false end
      table.sort(buttons, function(a, b) return a.middle < b.middle end)
      local list = {}
      for _, button in ipairs(buttons) do
        local row = list[#list]
        if row == nil or button.middle - row.middle > K.ROW_TOLERANCE then
          row = { middle = button.middle, items = {} }
          list[#list + 1] = row
        end
        table.insert(row.items, button)
      end
      for _, row in ipairs(list) do
        table.sort(row.items, function(a, b) return a.x < b.x end)
        row.left = row.items[1].x
        row.right = row.items[#row.items].x + row.items[#row.items].width
      end
      for _, into in ipairs(decorations) do
        local width, height = measure(into)
        if width == nil then return false end
        local shortest = list[1]
        for _, row in ipairs(list) do
          if #row.items < #shortest.items then shortest = row end
        end
        table.insert(shortest.items, { address = into, width = width, height = height,
          y = math.floor(shortest.middle - height / 2 + 0.5), added = true })
      end
      for _, row in ipairs(list) do
        local sum = 0
        for _, button in ipairs(row.items) do sum = sum + button.width end
        local right = math.max(row.right, ROW_RIGHT)
        local gap = #row.items > 1 and (right - row.left - sum) / (#row.items - 1) or 0
        if not row.items[#row.items].added then gap = nil end   -- no new button: left alone
        local x = row.left
        for _, button in ipairs(row.items) do
          if gap ~= nil then
            wr32(button.address + ITEM_X, math.floor(x + 0.5))
            wr32(button.address + ITEM_Y, button.y)
            wr16(button.address + ITEM_CONTROL, -1)
            x = x + button.width + gap
          end
          wr16(button.address + ITEM_HIDDEN, 0)
        end
      end
      return true
    end
  end
  -- The heights menu's iron goes; the Textures menu's copy of it stays.
  if O.noHeightsIron and O.textures then
    -- Hidden alone is not enough: the user control table places it (and shows it) again.
    local iron = button(IRON_COMMAND)
    wr32(iron + ITEM_X, 0)
    wr32(iron + ITEM_Y, 0)
    wr32(iron + ITEM_WIDTH, 0)
    wr32(iron + ITEM_HEIGHT, 0)
    wr32(iron + ITEM_IMAGE, 0)
    wr32(iron + ITEM_RENDER_TYPE, RENDER_NONE)
    wr16(iron + ITEM_CONTROL, -1)
    wr16(iron + ITEM_HIDDEN, 1)
  end
  if O.maxHeight or O.heightTools or O.lostRocks then
    local counts = { rows = #rows, places = #places, tooltips = #tooltips, guarded = #guarded }
    local ok, problem = pcall(C.heightsMenu, { G = G, O = O, data = data, added = added, copyOf = copyOf,
      button = button, moved = moved, newTable = newTable, rows = rows, newButtons = newButtons, places = places,
      tooltips = tooltips, guarded = guarded })
    if not ok then
      log(WARNING, tostring(problem) .. "; the heights menu and the lost rocks button are left out")
      for i = #rows, counts.rows + 1, -1 do rows[i] = nil end
      for i = #places, counts.places + 1, -1 do places[i] = nil end
      for i = #tooltips, counts.tooltips + 1, -1 do tooltips[i] = nil end
      for i = #guarded, counts.guarded + 1, -1 do guarded[i] = nil end
      data.heights = nil
      local kinds = C.heightItems(O)
      if O.heightTools then kinds[#kinds + 1] = "heightTick" end
      for _, tab in ipairs({ ROCKS, K.ROCKS_SKIRMISH }) do kinds[#kinds + 1] = "lostRocks" .. tab end
      for _, kind in ipairs(kinds) do              -- harmless: never hit, never drawn, no action
        local into = added[kind]
        if into ~= nil then
          wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
          wr32(into + ITEM_X, 0)
          wr32(into + ITEM_Y, 0)
          wr32(into + ITEM_WIDTH, 0)
          wr32(into + ITEM_HEIGHT, 0)
          wr32(into + ITEM_ACTION, 0)
          wr32(into + ITEM_RENDER, 0)
          wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
          wr16(into + ITEM_CONTROL, -1)
          wr16(into + ITEM_HIDDEN, 1)
        end
      end
    end
  end
  -- 36, 37, 39: the wastebins, the eraser panel, the tree outlines; each on its own, left out
  -- harmlessly if it fails.
  local function extra(wanted, fn, kinds, what)
    if not wanted then return end
    local counts = { places = #places, tooltips = #tooltips, guarded = #guarded }
    local ok, problem = pcall(fn, { G = G, O = O, data = data, added = added, button = button, places = places,
      tooltips = tooltips, guarded = guarded })
    if ok then return end
    log(WARNING, tostring(problem) .. "; " .. what .. " left out")
    for i = #places, counts.places + 1, -1 do places[i] = nil end
    for i = #tooltips, counts.tooltips + 1, -1 do tooltips[i] = nil end
    for i = #guarded, counts.guarded + 1, -1 do guarded[i] = nil end
    for _, kind in ipairs(kinds) do               -- harmless: never hit, never drawn, no action
      local into = added[kind]
      if into ~= nil then
        wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
        wr32(into + ITEM_WIDTH, 0)
        wr32(into + ITEM_HEIGHT, 0)
        wr32(into + ITEM_ACTION, 0)
        wr32(into + ITEM_RENDER, 0)
        wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
        wr16(into + ITEM_CONTROL, -1)
        wr16(into + ITEM_HIDDEN, 1)
      end
    end
  end
  extra(O.birdButtons or O.animalBin, C.animalsMenu, { "crowBin", "gullBin", "animalBin" }, "the wastebins")
  local eraserKinds = { "eraserPanel" }
  for i = 1, #K.ERASER_MODES do eraserKinds[#eraserKinds + 1] = "eraserMode" .. i end
  extra(O.eraserChoice, C.eraserMenu, eraserKinds, "the eraser panel")
  extra(O.spreadOutlines, C.spreadOutlines, { "spreadOutline" }, "the tree outlines")
  if O.groupWarning then
    local ok, problem = pcall(function() data.groupWarning = C.groupWarning(G, data) end)
    if not ok then log(WARNING, tostring(problem) .. "; no herds and groups line") end
  end
  if O.textureMask then
    local counts = { places = #places, tooltips = #tooltips }
    local ok, problem = pcall(C.textureMask, { G = G, O = O, data = data, added = added, moved = moved,
      newTable = newTable, places = places, tooltips = tooltips })
    if not ok then
      log(WARNING, tostring(problem) .. "; no texture mask")
      for i = #places, counts.places + 1, -1 do places[i] = nil end
      for i = #tooltips, counts.tooltips + 1, -1 do tooltips[i] = nil end
      data.mask = nil
      for _, kind in ipairs({ "maskButton", "maskTick" }) do   -- harmless: never hit, never drawn
        local into = added[kind]
        if into == nil then goto skip end
        wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
        wr32(into + ITEM_WIDTH, 0)
        wr32(into + ITEM_HEIGHT, 0)
        wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
        wr16(into + ITEM_HIDDEN, 1)
        ::skip::
      end
    end
  end
  local layout = makeLayout(G, rows, newButtons, sizeOf, places, finishes)

  -- A panel item at the end of a tab: shows its panel (lua) while one of its tools is chosen.
  local function panelItem(into, items, first, last, firstShrub, lastShrub, pad, felledLogs, felledCommand)
    wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(into + ITEM_RENDER, core.allocateAssembly(templates.panel, {
      SUBTYPE = G.subtype, FELLED_LOGS = felledLogs or unused, FELLED_COMMAND = felledCommand or unused + 4,
      FIRST_TREE = first, LAST_TREE = last, FIRST_SHRUB = firstShrub, LAST_SHRUB = lastShrub,
      PANEL_ITEMS = dwordList(items), ITEM_HIDDEN = ITEM_HIDDEN, PAD = pad,
    }))
  end

  -- The shrub and felled tree panels.
  if O.shrubs or O.felled then
    local panel = { items = {}, shrubs = {}, felled = {}, images = {}, info = added.info }
    if O.shrubs then
      -- With random mixes, choosing a shrub (here or in the menu) ends the random shrub.
      local shrubAction = nil
      if O.randomMix then
        shrubAction = core.allocateAssembly(templates.rockButton, {
          ROCK_LOCK = data.randomShrub, ACTION = G.buttons[SHRUB_COMMANDS[1]].action,
        })
        wr32(button(SHRUB_COMMANDS[1]) + ITEM_ACTION, shrubAction)
      end
      for i, command in ipairs(SHRUB_COMMANDS) do
        local into = added["shrub" .. i]
        copyOf(SHRUB_COMMANDS[1], into)        -- the shrub button: its group's action and description
        wr32(into + ITEM_X, 0)
        wr32(into + ITEM_Y, 0)
        wr32(into + ITEM_PARAM, command)
        wr32(into + ITEM_IMAGE, 0)
        wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
        wr16(into + ITEM_HIDDEN, 1)
        if shrubAction ~= nil then wr32(into + ITEM_ACTION, shrubAction) end
        panel.shrubs[i] = into
        panel.items[#panel.items + 1] = into
      end
      if O.randomMix then
        panel.randomShrub = added.randomShrub
        plainButton(panel.randomShrub, core.allocateAssembly(templates.flip, { FLAG = data.randomShrub }))
        panel.items[#panel.items + 1] = panel.randomShrub
      end
    end
    if O.felled then
      local click = core.allocateAssembly(templates.felledClick, {
        SUBTYPE = G.subtype, FELLED_LOGS = data.felledLogs, FELLED_COMMAND = data.felledCommand,
      })
      for command = FIRST_TREE_COMMAND, LAST_TREE_COMMAND do
        panel.images[command] = rd32(item(G.table, G.buttons[command].index, ITEM_IMAGE)) & IMAGE_INDEX_MASK
        -- The menu's tree buttons place standing trees again.
        wr32(button(command) + ITEM_ACTION, core.allocateAssembly(templates.rockButton, {
          ROCK_LOCK = data.felledLogs, ACTION = G.buttons[command].action,
        }))
      end
      for i = 1, felledButtons do
        plainButton(added["felled" .. i], click)
        panel.felled[i] = added["felled" .. i]
        panel.items[#panel.items + 1] = added["felled" .. i]
      end
    end
    for _, address in ipairs(panel.items) do
      guarded[#guarded + 1] = address
      guarded[#guarded + 1] = VEGETATION
    end
    local pad = luaPad(makePanel(G, O, data, panel, makeTreeEntries(G, O, data, panel)), "the tree panels")
    local first, last = 1, 0                   -- an empty range when the felled panel is off
    if O.felled then first, last = FIRST_TREE_COMMAND, LAST_TREE_COMMAND end
    local firstShrub, lastShrub = 1, 0
    if O.shrubs then firstShrub, lastShrub = SHRUB_COMMANDS[1], SHRUB_COMMANDS[#SHRUB_COMMANDS] end
    panelItem(added.panel, panel.items, first, last, firstShrub, lastShrub, pad, data.felledLogs, data.felledCommand)
  end

  -- The rock variant panels (one per Rocks tab), and the Rocks menu's own buttons going back
  -- to cycling variants.
  if #rockTabs > 0 then
    local click = core.allocateAssembly(templates.rockClick, { ROCK_LOCK = data.rockLock })
    local rockPicture = makeRockPictures(G)
    for _, tab in ipairs(rockTabs) do
      local panel = { items = {}, rocks = {}, info = added.info }
      for v = 1, K.ROCK_VARIANTS + 1 do
        local into = added["rock" .. tab .. "/" .. v]
        plainButton(into, click)
        panel.rocks[v] = into
        panel.items[#panel.items + 1] = into
        guarded[#guarded + 1] = into
        guarded[#guarded + 1] = tab
      end
      local pad = luaPad(makePanel(G, O, data, panel, makeRockEntries(G, O, data, panel, rockPicture)),
        "the rock panel")
      panelItem(added["rockPanel" .. tab], panel.items, K.FIRST_ROCK_COMMAND, K.LAST_ROCK_COMMAND, 1, 0, pad)
    end
    -- The buttons and their groups' headers, whose action the Menu constructor may copy into
    -- them.
    local wrapped = {}
    local function wrap(index, action)
      if wrapped[index] or action == 0 then return end
      wrapped[index] = true
      wr32(item(newTable, moved(index), ITEM_ACTION), core.allocateAssembly(templates.rockButton, {
        ROCK_LOCK = data.rockLock, ACTION = action,
      }))
    end
    for _, rock in ipairs(G.rockButtons) do
      wrap(rock.index, rock.action)
      if rock.group ~= nil then wrap(rock.group, rd32(item(G.table, rock.group, ITEM_ACTION))) end
    end
  end

  -- The herd panel.
  if O.herds then
    local herd = { checkBox = added.herdCheck }
    plainButton(herd.checkBox, core.allocateAssembly(templates.flip, { FLAG = data.herdSync }))
    guarded[#guarded + 1] = herd.checkBox
    guarded[#guarded + 1] = ANIMALS
    local pad = luaPad(makeHerdPanel(G, O, data, herd), "the herd panel")
    panelItem(added.herdPanel, { herd.checkBox }, K.HERD_ANIMALS[1][1], K.HERD_ANIMALS[#K.HERD_ANIMALS][1], 1, 0, pad)
  end

  -- The tooltip: drawn after everything else that is always shown, never hit by the mouse.
  if added.tooltip ~= nil then
    local hoverWords = {}
    for _, candidate in ipairs(tooltips) do hoverWords[#hoverWords + 1] = candidate.item + ITEM_HOVERED end
    -- A panel drawn later would cover it: the panels draw it again on top of themselves, and
    -- then it is left out here the next frame.
    data.tooltip = makeTooltip(G, tooltips)
    local function early()
      if data.tooltipLate then data.tooltipLate = false else data.tooltip() end
    end
    local tooltip = added.tooltip
    wr32(tooltip + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(tooltip + ITEM_RENDER, core.allocateAssembly(templates.tooltip, {
      HOVER_WORDS = dwordList(hoverWords), PAD = luaPad(early, "the tooltip"),
    }))
    wr32(tooltip + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  end

  if O.undo then C.undoButtons(G, added, guarded, O.undo) end
  if added.compass ~= nil then
    local ok, problem = pcall(C.compassItem, G, added.compass, O.undo)
    if not ok then log(WARNING, tostring(problem) .. "; no compass") end
  end
  if O.treePreview then
    local into = added.treePreview
    wr32(into + ITEM_TYPE, TYPE_CLICKABLE)    -- no size, so never under the mouse
    wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
    local ok, problem = pcall(function()
      data.treePreviewDraw = C.makeTreePreview(G, O, data)
      data.treePreviewItem = into
      wr32(into + ITEM_RENDER, C.luaPad(data.treePreviewDraw, "the tree preview"))
      wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    end)
    if not ok then log(WARNING, tostring(problem) .. "; no tree preview") end
  end
  if O.pipette then
    if G.blit == nil then
      G.blit = core.allocateAssembly(templates.blit, {
        PENCIL = G.pencil, SETUP_SURFACE = G.setupSurface, SETUP_PENCIL = G.setupPencil,
        SCRATCH = core.allocate(32, true), PIXEL_FORMAT = G.pixelFormat,
      })
    end
    local count = #guarded
    local ok, problem = pcall(C.pipette, G, O, data, added, guarded, places, button)
    if not ok then
      log(WARNING, tostring(problem) .. "; the pipette is left out")
      for i = #guarded, count + 1, -1 do guarded[i] = nil end
      for _, kind in ipairs(pipetteItems) do      -- harmless: never hit, never drawn, no action
        local into = added[kind]
        wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
        wr32(into + ITEM_WIDTH, 0)
        wr32(into + ITEM_HEIGHT, 0)
        wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
        wr16(into + ITEM_HIDDEN, 1)
      end
    end
  end

  -- The guard, in front of the game's map click handler; it also runs the layout until it
  -- has worked.
  data.laidOut = core.allocate(4, true)
  wr32(data.laidOut, (#rows == 0 and #places == 0) and 1 or 0)
  local layoutPad = core.allocateCode({ 0x90, 0x90, 0x90, 0x90, 0x90, 0xC3 })
  core.detourCode(function(registers)
    local ok, done = pcall(layout)
    if not ok then
      log(WARNING, MODULE_NAME .. ": the new buttons could not be laid out: " .. tostring(done))
      done = true
    end
    if done then wr32(data.laidOut, 1) end
    return registers
  end, layoutPad, 5)
  local guard = added.guard
  wr32(guard + ITEM_TYPE, TYPE_EVERY_FRAME)
  wr32(guard + ITEM_ACTION, core.allocateAssembly(templates.guard, {
    LAID_OUT = data.laidOut, LAYOUT = layoutPad, GUARDED = dwordList(guarded),
    ACTIVE_TAB = G.activeTab, ITEM_HIDDEN = ITEM_HIDDEN, ITEM_HEIGHT = ITEM_HEIGHT,
    ITEM_WIDTH = ITEM_WIDTH, ITEM_MENU = ITEM_MENU, MENU_X = MENU_X, MENU_Y = MENU_Y, ITEM_X = ITEM_X,
    ITEM_Y = ITEM_Y, MOUSE = G.mouse, IS_MOUSE_INSIDE = G.isMouseInside, ON_MAP = G.onMap,
    RECTS = data.rects, THE_MENU = G.menu,
  }))

  data.rockTabs = #rockTabs
  return newTable, data
end

-- Points the menu's constructor at the new table. Should the menu already have been built,
-- it is built again the same way.
local function installTable(G, newTable)
  core.writeCodeInteger(G.site + 1, newTable)
  local construct = core.exposeCode(G.constructor, 2, 1)
  local function ensure()
    if rd32(G.menu) == G.table then
      construct(G.menu, newTable)
    end
  end
  ensure()
  hooks.registerHookCallback("afterInit", ensure)
end

---------------------------------------------------------------------------------------
-- Code patches
---------------------------------------------------------------------------------------

-- Replaces size bytes at site with a jump to stub, remembering them for disable.
local function patchJump(self, site, size, stub)
  self.saved = self.saved or {}
  table.insert(self.saved, { address = site, bytes = core.readBytes(site, size) })
  core.writeCode(site, jumpTo(site, stub, size))
end
C.patchJump = patchJump                  -- for C functions written above this one

local function patchTrees(self, G, O, data)
  local randomShrubs = O.shrubs and O.randomMix
  local randomTrees = O.felled and O.randomMix
  if O.apple or randomShrubs then
    patchJump(self, G.treeTypeOf, #TREE_TYPE_START, core.allocateAssembly(templates.plantType, {
      APPLE_COMMAND = O.apple and APPLE_COMMAND or 0xFFFFFFFF, APPLE_TYPE = APPLE_TYPE,
      RANDOM_SHRUB = data.randomShrub, FIRST_SHRUB = SHRUB_COMMANDS[1],
      LAST_SHRUB = SHRUB_COMMANDS[#SHRUB_COMMANDS], SEED = data.seed, RANDOM_MULTIPLIER = K.RANDOM_MULTIPLIER,
      RANDOM_INCREMENT = K.RANDOM_INCREMENT, CONVERTER_BACK = G.treeTypeOf + #TREE_TYPE_START,
    }))
  end
  if O.growth or randomTrees then
    local brush = G.brush
    if not O.growth then                       -- the game's own stage, as a brush size
      brush = core.allocate(4, true)
      wr32(brush, PLACED_STAGE + 1)
    end
    patchJump(self, G.placeTree, PLACE_TREE.stageSize, core.allocateAssembly(templates.stageFromBrush, {
      BRUSH = brush, MAX_STAGE = MAX_STAGE, STAGE = core.allocate(4, true),
      FELLED_LOGS = data.felledLogs, FELLED_COMMAND = data.felledCommand, RANDOM_STANDING = K.RANDOM_STANDING,
      COMMAND_ON_STACK = PLACE_TREE.command, MOST_RANDOM_STAGE = K.MOST_RANDOM_STAGE, SEED = data.seed,
      SMALLEST_FELLED_STAGE = K.SMALLEST_FELLED_STAGE,
      RANDOM_MULTIPLIER = K.RANDOM_MULTIPLIER, RANDOM_INCREMENT = K.RANDOM_INCREMENT,
      BACK = G.placeTree + PLACE_TREE.stageSize,
    }))
  end
  if O.felled then
    local site = G.placeTree + PLACE_TREE.created
    patchJump(self, site, PLACE_TREE.createdSize, core.allocateAssembly(templates.felledTree, {
      FELLED_LOGS = data.felledLogs, FELLED_COMMAND = data.felledCommand,
      COMMAND_ON_STACK = PLACE_TREE.command, TREE_SIZE = G.treeSize,
      TREES = G.landscape + TREES_IN_LANDSCAPE, TREE_TYPE = TREE.TYPE, LAST_TREE_TYPE = LAST_TREE_TYPE,
      STAGES = STAGES, TREE_STAGE = TREE.STAGE, LOGS = G.logs, TREE_LYING = TREE.LYING,
      LYING_FELLED = LYING_FELLED, TREE_LOGS = TREE.LOGS, TREE_CHOPS = TREE.CHOPS,
      LANDSCAPE = G.landscape, UPDATE_TREE = G.updateTree, RANDOM_STANDING = K.RANDOM_STANDING,
      RANDOM_FELLED = K.RANDOM_FELLED, SEED = data.seed, RANDOM_MULTIPLIER = K.RANDOM_MULTIPLIER,
      RANDOM_INCREMENT = K.RANDOM_INCREMENT, BACK = site + PLACE_TREE.createdSize,
    }))
  end
  if O.obstacles or O.noStacking then
    local site = scan(K.AOB_OBSTACLES, "the tree placement's obstacle check")
    local tables = C.eraseTables()
    local stacking = core.allocate(4, true)
    wr32(stacking, O.noStacking and 1 or 0)
    expectBytes(site + K.OBSTACLES_REFUSE[1], K.OBSTACLES_REFUSE[2], "the tree placement's tile test")
    if site < G.placeTree - K.OBSTACLES_NEAR or site > G.placeTree + K.OBSTACLES_NEAR then
      error(MODULE_NAME .. ": the obstacle check is not in the tree placement")
    end
    local past = site + K.OBSTACLES_SIZE + (rd8(site + K.OBSTACLES_JUMP) & 0xFF)
    patchJump(self, site, K.OBSTACLES_SIZE, core.allocateAssembly(templates.nearObstacles, {
      FLAG = data.nearObstacles, CHECK = site + K.OBSTACLES_SIZE, PAST_CHECK = past, NO_STACKING = stacking,
      NUMBERS = tables.numbers, ROCK_BASE = rd32(C.eraseSites()[1] + K.ERASE_ROCK.base),
      REFUSE = (site + rd32(site - 4)) & 0xFFFFFFFF,
    }))
  end
  -- With the texture mask on, its own hook on the same tile test carries the check box too
  -- (two hooks on one instruction cannot both find it).
  if O.rocksAndWater and data.mask == nil then
    -- G.placeTree is a spot inside placeTree past this test, so the test lies within reach on
    -- either side. A problem here only leaves the check box without effect.
    local ok, problem = pcall(function()
      local site = scan(K.AOB_TREE_GROUND, "the tree placement's tile test")
      if site < G.placeTree - K.OBSTACLES_NEAR or site > G.placeTree + K.OBSTACLES_NEAR then
        error(MODULE_NAME .. ": the tile test is not in the tree placement")
      end
      local mask = rd32(site + K.TREE_GROUND.mask)
      patchJump(self, site, K.TREE_GROUND.size, core.allocateAssembly(templates.treeGround, {
        FLAG = data.rocksAndWater, GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR,
        LOGIC = rd32(site + K.TREE_GROUND.logic), MASK = mask, LOOSE_MASK = mask & ~K.TREE_GROUND.loose,
        BACK = site + K.TREE_GROUND.size,
      }))
    end)
    if not ok then log(WARNING, tostring(problem) .. "; vegetation stays off rocks and water") end
  end
  if O.noStacking then C.patchEraseStacks(self, G) end
  if O.waterDecorations then C.patchRiverDecorations(self) end
  if O.waterDecorations and O.foamOnSea then C.patchFoamOnSea(self) end
end

-- The rock number the editor places and previews follows the variant row.
local function patchRocks(self, G, data)
  local function rockId(site, size, tail)
    return core.allocateAssembly(templates.rockId .. tail .. "\njmp BACK\n", {
      ROCK_LOCK = data.rockLock, SIZE = G.chosenRockSize, VARIANT = G.rockVariant,
      EXTRA_VARIANT = K.EXTRA_VARIANT, EXTRA_ID = K.EXTRA_ID, PARAM3 = G.rockParam, MOUSE_Y = G.mouseTileY,
      BACK = site + size,
    })
  end
  patchJump(self, G.rockPlace, K.ROCK_PLACE.size, rockId(G.rockPlace, K.ROCK_PLACE.size, "mov [PARAM3],ecx"))
  patchJump(self, G.rockPreview, K.ROCK_PREVIEW.size, rockId(G.rockPreview, K.ROCK_PREVIEW.size, "mov edx,[MOUSE_Y]"))
end

-- With the invisible rocks check box on, placeRock gets rock 0 instead of a new rock.
function C.patchInvisibleRocks(self, data)
  local site = scan(K.AOB_CREATE_ROCK_CALL, "the rock placement's createRock call") + K.CREATE_ROCK_CALL
  local stub = core.allocateAssembly(templates.invisibleRocks, {
    FLAG = data.invisibleRocks, CREATE_ROCK = readCallTarget(site, 0, "createRock"),
    ROCK_ARGUMENTS = K.CREATE_ROCK_ARGUMENTS,
  })
  self.saved = self.saved or {}
  table.insert(self.saved, { address = site, bytes = core.readBytes(site, 5) })
  core.writeCode(site, { 0xE8, core.itob(core.getRelativeAddress(site, stub, -5)) })
end

-- The eraser frees an invisible rock's tile the way removing a rock frees the rock's tiles: the
-- rock flag and the tile's rock number go.
function C.eraseSites()
  if C.erasers ~= nil then return C.erasers end
  local sites, from = {}, 0x400000
  while #sites <= K.ERASE_SITES do
    local ok, found = pcall(core.scanForAOB, K.AOB_ERASE_ROCK, from, K.HERD_SEARCH_END)
    if not ok or found == nil or found == 0 then break end
    sites[#sites + 1] = found
    from = found + 1
  end
  if #sites ~= K.ERASE_SITES then error(MODULE_NAME .. ": the eraser is not the one this module knows") end
  C.erasers = sites
  return sites
end

-- The eraser's map tables (tile flags, organism numbers), read once: the eraser choice patches
-- the instruction this pattern ends in, the addresses themselves stay.
function C.eraseTables()
  if C.tables == nil then
    local found = scan(K.AOB_ERASE_TABLES, "the eraser's map tables")
    C.tables = { flags = rd32(found + K.ERASE_TABLES.flags), numbers = rd32(found + K.ERASE_TABLES.numbers) }
  end
  return C.tables
end

function C.patchEraser(self)
  local tables = C.eraseTables()
  for _, found in ipairs(C.eraseSites()) do
    local site = found + K.ERASE_ROCK.site
    patchJump(self, site, K.ERASE_ROCK.size, core.allocateAssembly(templates.eraseInvisible, {
      ROCK_BASE = rd32(found + K.ERASE_ROCK.base), FLAGS = tables.flags,
      NUMBERS = tables.numbers, KEEP_FLAGS = (~K.ROCK_TILE_FLAG) & 0xFFFFFFFF,
      REMOVE_ROCK = readCallTarget(site, K.ERASE_ROCK.call, "removeRock"), BACK = site + K.ERASE_ROCK.size,
    }))
  end
end

-- The eraser takes every tree and shrub off a tile, not only the one the tile names: shrubs
-- that were stacked there stay in the tree list otherwise, invisible and for good.
function C.patchEraseStacks(self, G)
  for _, found in ipairs(C.eraseSites()) do
    local site = found + K.ERASE_TREE.site
    expectBytes(site, K.ERASE_TREE.bytes, "the eraser's tree branch")
    patchJump(self, site, K.ERASE_TREE.size, core.allocateAssembly(templates.eraseStack, {
      REMOVE_TREE = readCallTarget(site, K.ERASE_TREE.call, "removeTree"), LANDSCAPE = G.landscape,
      FIRST_TREE = G.firstTree, TREE_SIZE = G.treeSize, TREE_SLOTS = G.treeSlots,
      TILE_FROM_IN_USE = K.TREE_TILE_FROM_IN_USE, BACK = site + K.ERASE_TREE.size,
    }))
  end
end

-- Foam and small waves: setTerrain leaves the brush area river for them (see K.TERRAIN_LAND).
function C.patchRiverDecorations(self)
  local site = scan(K.AOB_TERRAIN_LAND, "the terrain brush") + K.TERRAIN_LAND.site
  patchJump(self, site, K.TERRAIN_LAND.size, core.allocateAssembly(templates.riverDecorations, {
    RIVER = K.RIVER_TERRAIN, SKIP_LAND = site + K.TERRAIN_LAND.size + (rd8(site + K.TERRAIN_LAND.size - 1) & 0xFF),
    BACK = site + K.TERRAIN_LAND.size,
  }))
end

-- Foam goes on ocean tiles too (they become river with foam).
function C.patchFoamOnSea(self)
  local D = K.DECORATION_TILE
  local site = scan(K.AOB_DECORATION_TILE, "the decoration's tile test") + D.site
  patchJump(self, site, D.size, core.allocateAssembly(templates.foamOnSea, {
    FLAGS = rd32(site + D.flags), RIVER = K.RIVER_TERRAIN, FOAM = K.FOAM, SEA = K.SEA_TILE,
    TILE_OK = site + D.size + (rd8(site + D.size - 1) & 0xFF), BACK = site + D.size,
  }))
end

-- Every brush gets its full shape: the walk marks the cursor tile as visited before it starts.
-- In the map editor only: the walk also gives the area of collateral damage in the game.
function C.patchBrushShape(self)
  local site = scan(K.AOB_BRUSH_START, "the brush walk")
  patchJump(self, site, K.BRUSH_START_SIZE, core.allocateAssembly(templates.brushStart, {
    MARKS = rd32(scan(K.AOB_BRUSH_MARKS, "the brush walk's marks") + K.BRUSH_MARKS),
    GAME_MODE = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND), MAP_EDITOR = K.MAP_EDITOR,
    BACK = site + K.BRUSH_START_SIZE,
  }))
end

---------------------------------------------------------------------------------------
-- Undo and redo
---------------------------------------------------------------------------------------

-- What a map is: the sections the game saves a map with (its section table). Before the first
-- map edit of a click the module copies them (the snapshot); when the step ends - at the next
-- click's first edit, or at a click on undo or redo - it compares them and keeps only the bytes
-- that changed, old and new. A brush held down is one click. Undo writes the old bytes back, redo the new ones, and then the things
-- the game works out from the map are worked out again, as after loading a map.

-- The section list for the diff: { live address, snapshot address, size } per section, 0 at the end.
function C.undoSections()
  local sections, total = {}, 0
  local at = rd32(scan(K.AOB_SECTION_TABLE, "the map sections") + K.SECTION_TABLE)
  while rd32(at + K.SECTION.address) ~= 0 do
    local size = rd32(at + K.SECTION.size)
    sections[#sections + 1] = { address = rd32(at + K.SECTION.address), size = size }
    total = total + size
    at = at + K.SECTION.stride
    if #sections > K.MOST_SECTIONS then error(MODULE_NAME .. ": the map section table has no end") end
  end
  return sections, total
end

function C.enableUndo(self)
  local U = { open = false, last = 0, steps = {}, redo = {}, bytes = 0 }
  local sections, total = C.undoSections()
  U.shadow = core.allocate(total, true)
  U.list = core.allocate((#sections + 1) * 12, true)
  local offset = 0
  for i, section in ipairs(sections) do
    section.shadow = U.shadow + offset
    wr32(U.list + (i - 1) * 12, section.address)
    wr32(U.list + (i - 1) * 12 + 4, section.shadow)
    wr32(U.list + (i - 1) * 12 + 8, section.size)
    offset = offset + section.size
  end
  U.scratch = core.allocate(K.UNDO_SCRATCH, false)
  local state = core.allocate(16, true)
  local diff = core.exposeCode(core.allocateAssembly(templates.undoDiff, {
    SECTIONS = U.list, OUT_BEGIN = U.scratch, OUT_LIMIT = U.scratch + K.UNDO_SCRATCH, GAP = K.UNDO_GAP_BYTES,
    WRITE_AT = state, ENTRY_AT = state + 4, RUN_FROM = state + 8, RUN_LENGTH = state + 12,
  }), 0, 0)

  -- The mouse buttons, through a thunk to GetAsyncKeyState.
  local asyncKey = core.exposeCode(core.allocateAssembly(templates.undoKeyState, {
    IMPORT = rd32(scan(K.AOB_ASYNC_KEY, "the key state") + K.ASYNC_KEY_IMPORT),
  }), 1, 0)
  local function down(key) return (asyncKey(key) % 0x10000) >= 0x8000 end
  local edits = {}
  for _, command in ipairs(K.MAP_EDITS) do edits[command] = true end
  U.released = true      -- the mouse buttons were up since the last map edit

  -- What the game works out from the map after loading it (prepareMap's own calls).
  local block = scan(K.AOB_PREPARE_BLOCK, "the map preparation")
  local P = K.PREPARE
  local tileMap = rd32(scan(K.AOB_ROCK_PREVIEW, "the tile map") + K.ROCK_PREVIEW.tileMap)
  local pathFinding, buildingsState = rd32(block + P.pathFinding), rd32(block + P.buildings)
  local hovered = rd32(block + P.hovered)
  local function call(offset, args) return core.exposeCode(readCallTarget(block, offset, "the map preparation"), args, 1) end
  local changedAll = call(P.changedAll, 1)
  local linkTiles, areas, linkBuildings = call(P.linkTiles, 1), call(P.areas, 2), call(P.linkBuildings, 1)
  local climb, cliffs, unhover = call(P.climb, 1), call(P.cliffs, 1), call(P.unhover, 1)
  local minimapSite = scan(K.AOB_MINIMAP_REDRAW, "the minimap redraw")
  local minimap = rd32(minimapSite + K.MINIMAP_REDRAW.object)
  local redrawMinimap = core.exposeCode(readCallTarget(minimapSite, K.MINIMAP_REDRAW.call, "the minimap redraw"), 2, 1)
  local function refresh()
    changedAll(tileMap)
    linkTiles(pathFinding)
    areas(pathFinding, 1)
    linkBuildings(buildingsState)
    climb(pathFinding)
    cliffs(tileMap)
    unhover(hovered)
    redrawMinimap(minimap, 1)
  end

  local function forget(list)
    for i = #list, 1, -1 do
      U.bytes = U.bytes - list[i].size
      core.deallocate(list[i].address)
      list[i] = nil
    end
  end
  local function snapshot()
    for _, section in ipairs(sections) do core.copyMemory(section.shadow, section.address, section.size) end
  end
  local function closeStep()
    U.open = false
    local size = diff() & 0xFFFFFFFF
    if size == 0 then return end
    if size == 0xFFFFFFFF then
      log(WARNING, MODULE_NAME .. ": an editor change too big to undo; the undo history starts afresh")
      forget(U.steps)
      forget(U.redo)
      return
    end
    local record = { address = core.allocate(size, false), size = size }
    core.copyMemory(record.address, U.scratch, size)
    forget(U.redo)
    U.steps[#U.steps + 1] = record
    U.bytes = U.bytes + size
    while #U.steps > K.UNDO_STEPS or (U.bytes > K.UNDO_MOST_BYTES and #U.steps > 1) do
      local oldest = table.remove(U.steps, 1)
      U.bytes = U.bytes - oldest.size
      core.deallocate(oldest.address)
    end
  end
  -- Writes a step's old (undo) or new (redo) bytes back: records of address, length, old, new.
  local function apply(record, new)
    local at, finish = record.address, record.address + record.size
    while at < finish do
      local address, length = rd32(at), rd32(at + 4)
      core.copyMemory(address, at + 8 + (new and length or 0), length)
      at = at + 8 + 2 * length
    end
    refresh()
  end

  -- Every command the editor queues (before it is carried out): a map edit after the mouse
  -- buttons were let go starts a new step.
  local command = core.allocate(4, true)
  local function beginEdit()
    if U.open and U.released then closeStep() end
    if not U.open then
      snapshot()
      U.open = true
    end
    U.released = false
  end
  local function onCommand()
    if edits[rd32(command) & 0xFF] then beginEdit() end
  end
  local gameMode = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND)
  local queue = scan(K.AOB_QUEUE_COMMAND, "the command queue")
  local original = {}
  for i, byte in ipairs(core.readBytes(queue, K.QUEUE_COMMAND_SIZE)) do original[i] = string.format("0x%02X", byte & 0xFF) end
  patchJump(self, queue, K.QUEUE_COMMAND_SIZE, core.allocateAssembly(
    templates.undoCommand:gsub("ORIGINAL", "db " .. table.concat(original, ",")), {
      GAME_MODE = gameMode, MAP_EDITOR = K.MAP_EDITOR, PAD = C.luaPad(onCommand, "the undo history"),
      COMMAND = command, BACK = queue + K.QUEUE_COMMAND_SIZE,
    }))

  -- What the two buttons do (see C.undoButtons), in the map editor only.
  local function editor() return rd32(gameMode) == K.MAP_EDITOR end
  self.undo = {
    editor = editor,
    beginEdit = beginEdit,       -- for the module's own map edits (the pipette)
    undo = function()
      if not editor() then return end
      if U.open then closeStep() end
      local record = table.remove(U.steps)
      if record == nil then return end
      apply(record, false)
      U.redo[#U.redo + 1] = record
    end,
    redo = function()
      if not editor() then return end
      if U.open then closeStep() end   -- something new done since the undo: nothing to redo
      local record = table.remove(U.redo)
      if record == nil then return end
      apply(record, true)
      U.steps[#U.steps + 1] = record
    end,
    -- Every frame (from the buttons): notes the mouse buttons being let go.
    tick = function()
      if not (down(K.VK_LBUTTON) or down(K.VK_RBUTTON)) then U.released = true end
    end,
    available = {
      undo = function() return U.open or #U.steps > 0 end,
      redo = function() return not U.open and #U.redo > 0 end,
    },
  }

  -- Another map: the history is about the old one.
  expectBytes(block + P.forget, { 0xB9 }, "the map preparation")
  patchJump(self, block + P.forget, P.forgetSize, core.allocateAssembly(templates.undoForget, {
    PAD = C.luaPad(function()
      U.open = false
      forget(U.steps)
      forget(U.redo)
    end, "the undo history"),
    PATHFINDING = pathFinding, BACK = block + P.forget + P.forgetSize,
  }))
  log(INFO, string.format("%s: undo and redo ready (%d map sections, %.1f MB)", MODULE_NAME, #sections, total / 1e6))
end

-- The moat panel's choice decides the mode the editor's moat click sends.
function C.patchMoatClick(self, data)
  local site = scan(K.AOB_MOAT_CLICK, "the moat click")
  patchJump(self, site, K.MOAT_CLICK_SIZE, core.allocateAssembly(templates.moatClick, {
    MOAT_MODE = data.moatMode, PLANNED = K.MOAT_PLANNED, MOAT_TOOL = K.MOAT_TOOL, BACK = site + K.MOAT_CLICK_SIZE,
  }))
end

-- setTerrain's moat modes: permanent moat (mode 4), and a removal (mode 3) that only touches
-- moat tiles and leaves their ground as it is.
function C.patchMoatModes(self, permanent, keepGround)
  local base = scan(K.AOB_MOAT_MODE, "the moat modes")
  local D = K.MOAT_MODE
  local site = base + D.site
  local plan = site + D.size
  local nextMode = plan + (rd8(site + D.size - 1) & 0xFF)
  expectBytes(plan, { 0x8B, 0x4D, 0x0C, 0x8B, 0x55, 0xE0, 0x8B, 0x84, 0x8A }, "the planned moat")
  expectBytes(nextMode + D.decoration, { 0xC6, 0x81 }, "the moat decoration")
  expectBytes(plan + D.done, { 0xE9 }, "the moat branch's end")
  patchJump(self, site, D.size, core.allocateAssembly(templates.moatModes, {
    PERMANENT = permanent and K.MOAT_PERMANENT_MODE or 0xFFFFFFFF, KEEP_GROUND = keepGround and 1 or 0,
    LOGIC = rd32(plan + D.logic), HEIGHT = rd32(base + D.height), DECORATION = rd32(nextMode + D.decoration + 2),
    MOAT_FLAGS = K.MOAT_FLAGS, DUG = K.MOAT_DUG_FLAG, GROUND = K.GROUND_HEIGHT,
    UNMOAT = ~K.MOAT_FLAGS & 0xFFFFFFFF, UNMOAT_PLAIN = ~(K.MOAT_FLAGS | K.PLAIN2_FLAG) & 0xFFFFFFFF,
    CLEAR_DATA = readCallTarget(nextMode, D.clear, "clearMoatDataAtTile"),
    DONE = plan + D.done + 5 + rd32(plan + D.done + 1), PLAN = plan, NEXT = nextMode,
  }))
end

-- Moat on marsh in the map editor: the marsh stays under it.
function C.patchMoatMarsh(self)
  local site = scan(K.AOB_MOAT_MARSH, "the moat's marsh test") + K.MOAT_MARSH.site
  patchJump(self, site, K.MOAT_MARSH.size, core.allocateAssembly(templates.moatMarsh, {
    GAME_MODE = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND), MAP_EDITOR = K.MAP_EDITOR,
    BACK = site + K.MOAT_MARSH.size,
  }))
end

---------------------------------------------------------------------------------------
-- Pipette
---------------------------------------------------------------------------------------

-- The pipette is a tool of its own (K.PIPETTE_TOOL, an id the game's click handlers leave
-- alone; its preview is the plain brush). Every frame, before the map click handler, lua
-- looks at the mouse: in read mode a click on the map takes the tile's heights and/or
-- textures, in write mode clicking and dragging gives them to the tiles under the brush.
-- The writes are the ones the game's own height and terrain tools make, followed by the
-- same updates.

local function keyCode(name)
  if name == nil then return nil end
  local special = { ctrl = 0x11, shift = 0x10, alt = 0x12, space = 0x20, tab = 0x09 }
  if special[name] ~= nil then return special[name] end
  local letter = name:match("^letter_(%a)$")
  if letter ~= nil then return string.byte(letter:upper()) end
  local digit = name:match("^digit_(%d)$")
  if digit ~= nil then return 0x30 + tonumber(digit) end
  local f = name:match("^f(%d+)$")
  if f ~= nil and tonumber(f) >= 1 and tonumber(f) <= 12 then return 0x6F + tonumber(f) end
  return nil
end
C.keyCode = keyCode

-- What the game needs for the pipette, from the code that uses it.
function C.resolvePipette(G)
  if C.resolved ~= nil then return C.resolved end
  local R = {}
  R.validTiles = rd32(scan(K.AOB_TILE_VALID, "the map's tiles") + K.TILE_VALID)
  local mouse = scan(K.AOB_MOUSE_CLICK, "the map click")
  local M = K.MOUSE_CLICK
  R.clickStart, R.mouseX, R.mouseY = rd32(mouse + M.start), rd32(mouse + M.x), rd32(mouse + M.y)
  R.clickHeld = rd32(scan(K.AOB_CLICK_HELD, "the map click state") + K.CLICK_HELD)
  local mouseTile = scan(K.AOB_MOUSE_TILE, "the mouse tile")
  local MT = K.MOUSE_TILE
  R.flatView, R.viewport = rd32(mouseTile + MT.flat), rd32(mouseTile + MT.viewport)
  R.flatSetup = readCallTarget(mouseTile, MT.flatSetup, "setupMouseTileXY2")
  R.mouseSetup = readCallTarget(mouseTile, MT.setup, "setupMouseTileXY")
  local preview = scan(K.AOB_PIPETTE_PREVIEW, "the brush preview")
  local P = K.PIPETTE_PREVIEW
  R.previewSite, R.brushField, R.brushSizes = preview, rd32(preview + P.brush), rd32(preview + P.sizes)
  expectBytes(preview + P.rows[1], P.rows[2], "the brush preview's rows")
  R.rows = rd32(preview + P.rows[1] + #P.rows[2])
  local walk = scan(K.AOB_BRUSH_TILE, "the brush walk")
  R.tileForBrush = readCallTarget(walk, K.BRUSH_TILE_CALL, "getTileForBrush")
  local tail = scan(K.AOB_HEIGHT_TAIL, "the height brush")
  local H = K.HEIGHT_TAIL
  R.pathFinding, R.links, R.logicFlag = rd32(tail + H.pathFinding), readCallTarget(tail, H.links, "the path links"),
    rd32(tail + H.flag)
  local heights = scan(K.AOB_HEIGHTS, "the tile heights")
  R.height, R.defaultHeight, R.logic = rd32(heights + K.HEIGHTS.height), rd32(heights + K.HEIGHTS.default),
    rd32(heights + K.HEIGHTS.logic)
  local after = scan(K.AOB_HEIGHT_TOOL, "the height tool")
  local A = K.HEIGHT_TOOL
  R.walk, R.minimap = readCallTarget(after, A.walk, "the walk layer update"), rd32(after + A.minimap)
  R.macroFlag, R.redraw = rd32(after + A.macro), readCallTarget(after, A.redraw, "the minimap redraw")
  local rock = scan(K.AOB_HEIGHT_ROCK, "the height brush's rock removal")
  R.organism, R.landscape = rd32(rock + K.HEIGHT_ROCK.organism), rd32(rock + K.HEIGHT_ROCK.landscape)
  R.removeRock = readCallTarget(rock, K.HEIGHT_ROCK.remove, "removeRock")
  local building = scan(K.AOB_BUILDING_TYPE, "the building types")
  R.buildingStride, R.buildingType = rd32(building + K.BUILDING_TYPE.stride), rd32(building + K.BUILDING_TYPE.type)
  R.commandOfType = scan(K.AOB_COMMAND_OF_TYPE, "convertBuildingTypeToCommandBuildingType")
  local sprites = scan(K.AOB_BUILDING_SPRITES, "the building pictures")
  expectBytes(sprites + K.BUILDINGS_STATE - 1, { 0xB9 }, "the buildings")
  R.buildingsState = rd32(sprites + K.BUILDINGS_STATE)
  local variations = scan(K.AOB_VARIATIONS, "the building variations")
  R.variationField, R.variationTables = rd32(variations + K.VARIATIONS.field), {}
  for i, at in ipairs(K.VARIATIONS.tables) do R.variationTables[i] = rd32(variations + at) end
  R.hovelField = rd32(scan(K.AOB_HOVEL_VARIANT, "the hovel variants") + K.HOVEL_VARIANT.field)
  R.ruinedFlag = rd32(scan(K.AOB_RUINED_CATHEDRAL, "the ruined cathedral") + K.RUINED_CATHEDRAL.flag)
  local choice = scan(K.AOB_PLAYER_CHOICE, "the player shields")
  R.playerFlags, R.currentPlayer = rd32(choice + K.PLAYER_CHOICE.flags), rd32(choice + K.PLAYER_CHOICE.current)
  R.editorPlayer = rd32(scan(K.AOB_EDITOR_PLAYER, "the editor's building owner") + K.EDITOR_PLAYER)
  local place = scan(K.AOB_PLACE_PLANT, "the rock and tree placement")
  R.placeRock = readCallTarget(place, K.PLACE_PLANT.placeRock, "placeRock")
  R.placeTree = readCallTarget(place, K.PLACE_PLANT.placeTree, "placeTree")
  R.menuGuard = rd32(scan(K.AOB_KEY_GUARD, "the key guard") + K.KEY_GUARD)
  R.keyState = rd32(scan(K.AOB_ASYNC_KEY, "the key state") + K.ASYNC_KEY_IMPORT)
  R.gameMode = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND)
  R.tileMap = rd32(scan(K.AOB_ROCK_PREVIEW, "the tile map") + K.ROCK_PREVIEW.tileMap)
  C.resolved = R
  return R
end

-- Names of what the textures pipette took, for the line above its panel.
function C.textureNames(logic, decoration)
  local names = {}
  for _, flag in ipairs(K.TEXTURE_NAMES) do
    if logic & flag[1] ~= 0 then names[#names + 1] = flag[2] end
  end
  local river = logic & K.RIVER_TERRAIN ~= 0
  for _, flag in ipairs(river and K.RIVER_DECORATION_NAMES or K.DECORATION_NAMES) do
    if decoration & flag[1] ~= 0 then names[#names + 1] = flag[2] end
  end
  if #names == 0 then names[1] = "plain ground" end
  return table.concat(names, ", ")
end

-- The tree a tree or shrub tool would plant, drawn at the tile under the mouse the way renderMap
-- draws trees; a felled one from the felled tree pictures. data.treePreview, when the pipette
-- sets it, is the exact tree to show.
function C.makeTreePreview(G, O, data)
  local R = C.resolvePipette(G)
  local T = R.tileMap
  local renderGM = core.exposeCode(G.renderGM, 5, 1)
  local mouseSetup, flatSetup = core.exposeCode(R.mouseSetup, 1, 1), core.exposeCode(R.flatSetup, 1, 1)
  local origin = scan(K.AOB_TREE_ORIGIN, "the tree origins")
  local originStride = rd32(origin + K.TREE_ORIGIN.stride)
  local originX, originY = rd32(origin + K.TREE_ORIGIN.x), rd32(origin + K.TREE_ORIGIN.y)
  local inUse = G.firstTree - (G.landscape + TREES_IN_LANDSCAPE + G.treeSize)
  local blank = {}
  for i = 1, G.treeSize do blank[i] = 0 end
  local cache = {}
  -- placeTree's room check: how many brush tiles around a new tree of a type must be free
  -- (`push 3 / push type / call; push eax / call; ... mov eax,[eax*4+room]`).
  local roomSite = scan(K.AOB_TREE_ROOM, "the tree's room check")
  local RM = K.TREE_ROOM
  -- RM.first is mapUITreeTypeToLogicalTreeType(command) (one argument; G.plantTypes holds its
  -- answers), RM.second takes that type and the 3 pushed before it.
  local kindOf = core.exposeCode(readCallTarget(roomSite, RM.second, "the tree kind"), 3, 1)
  local organisms, roomTable = rd32(roomSite + RM.this), readOperand(roomSite, RM.room, "the tree's room check")
  local tileForBrush = core.exposeCode(R.tileForBrush, 7, 1)
  local out = core.allocate(8, true)
  local rooms = {}
  local function roomFree(treeType, tile, y)
    if rooms[treeType] == nil then
      local kind = kindOf(organisms, treeType, 3)
      rooms[treeType] = (kind >= 0 and kind < K.TREE_ROOM.kinds) and rd32(roomTable + kind * 4) or 0
    end
    for i = 0, math.min(rooms[treeType], K.TREE_ROOM.most) - 1 do
      tileForBrush(T, 1, i, out, out + 4, tile, y)
      local near = rd32(out)
      if near < 0 or near >= K.MAP_TILES then break end
      local logic = rd32(T + R.logic + near * 4) & 0xFFFFFFFF
      if logic & K.TREE_ROOM_EDGE ~= 0 then break end          -- placeTree stops looking here
      if logic & K.TREE_FOOT_REFUSED ~= 0 or logic & K.ROCKY ~= 0 or rd16(T + R.organism + near * 2) ~= 0 then
        return false
      end
    end
    return true
  end
  -- The value the next random choice gets (the seed is only read, the placing moves it on).
  local function nextRandom(range)
    if range <= 0 then return 0 end
    local n = (rd32(data.seed) * K.RANDOM_MULTIPLIER + K.RANDOM_INCREMENT) & 0xFFFFFFFF
    return (n >> 16) % range
  end

  -- The picture a new tree of this type and stage starts with, as createTree gets it: the type's
  -- own update function, run once on a free tree slot (put back as it was afterwards).
  local function picture(treeType, stage)
    local key = treeType * 16 + stage
    if cache[key] ~= nil then return cache[key] end
    cache[key] = false
    local update = rd32(G.updateTree + treeType * 4)
    if update == 0 or (rd8(update) & 0xFF) ~= 0xA1 then return false end   -- `mov eax,[current tree]`
    local current = rd32(update + 1)
    for slot = G.treeSlots, 1, -1 do
      local tree = G.landscape + TREES_IN_LANDSCAPE + slot * G.treeSize
      if rd16(tree + inUse) == 0 then
        local saved = core.readBytes(tree, G.treeSize)
        core.writeBytes(tree, blank)
        wr16(tree + TREE.TYPE, treeType)
        wr16(tree + K.TREE_GM, rd16(G.typeGm + treeType * 4))
        wr32(tree + TREE.STAGE, stage)
        local before = rd32(current)
        wr32(current, slot)
        local ok = pcall(core.exposeCode(update, 0, 0))
        wr32(current, before)
        local result = rd32(tree + K.TREE_PICTURE)
        core.writeBytes(tree, saved)
        if ok and result > 0 then cache[key] = result end
        return cache[key]
      end
    end
    return false
  end

  local function surface(x, y, tile)
    local vp = R.viewport
    local turn = K.SCREEN_TURN[rd32(T + K.TILE_MAP.orientation)]
    if turn == nil or rd32(vp + K.VIEWPORT.zoomedOut) ~= 0 then return nil end
    local bias = rd32(vp + K.VIEWPORT.bias) == 0 and 0 or 0x40
    local C2 = rd32(vp + K.VIEWPORT.x) // K.TILE_WIDTH
    local R2 = (rd32(vp + K.VIEWPORT.y) + bias) // K.TILE_HEIGHT
    local d, s = x - y, x + y
    local drawX = turn.cx + turn.xd * d + turn.xs * s - K.TILE_WIDTH * C2
    local drawY = bias + turn.cy + turn.yd * d + turn.ys * s - K.TILE_HEIGHT * R2
    local lift = K.FLAT_HEIGHT_OFFSET
    if rd32(R.flatView) == 0 then lift = rd32(T + K.HEIGHT_OFFSETS + (rd8(T + R.height + tile) & 0xFF) * 4) end
    return drawX, drawY - lift
  end

  local asyncKey = core.exposeCode(core.allocateAssembly(templates.undoKeyState, { IMPORT = R.keyState }), 1, 0)
  local wasDown, randomEntry = true, false
  -- Draws the preview; answers "refused" when the tile under the mouse would not take the tree.
  local function draw()
    randomEntry = false
    if rd32(R.gameMode) ~= K.MAP_EDITOR or rd32(G.onMap) == 0 then return end
    local command = rd32(G.subtype)
    local treeType = G.plantTypes[command]
    if treeType == nil then return end
    local exact = data.treePreview
    local randomShrub = data.randomShrub ~= nil and rd8(data.randomShrub) ~= 0
    if randomShrub and (exact == nil or exact.command ~= command)
        and command >= SHRUB_COMMANDS[1] and command <= SHRUB_COMMANDS[#SHRUB_COMMANDS] then
      -- the shrub the next random choice picks (as templates.plantType does)
      randomEntry = true
      local pick = SHRUB_COMMANDS[1] + nextRandom(SHRUB_COMMANDS[#SHRUB_COMMANDS] - SHRUB_COMMANDS[1] + 1)
      if G.plantTypes[pick] ~= nil then treeType = G.plantTypes[pick] end
    end
    local gm, shown, palette = rd16(G.typeGm + treeType * 4), nil, SHRUB_PALETTES[treeType] or 0
    if exact ~= nil and exact.command == command then
      shown = exact.picture
    else
      local stage = PLACED_STAGE
      if O.growth then stage = math.max(0, math.min(MAX_STAGE, rd32(G.brush) - 1)) end
      local logs = data.felledLogs ~= nil and rd32(data.felledLogs) or 0
      local ours = data.felledCommand ~= nil and rd32(data.felledCommand) == command
      if ours and (logs == K.RANDOM_FELLED or logs == K.RANDOM_STANDING) then randomEntry = true end
      if ours and logs == K.RANDOM_FELLED then
        -- the log count the next random choice gives (templates.felledTree)
        local felledStage = math.max(stage, K.SMALLEST_FELLED_STAGE)
        local most = rd32(G.logs + (treeType * STAGES + (stage == 0 and K.SMALLEST_FELLED_STAGE or stage)) * 4)
        if most <= 0 then return end
        shown, palette = FELLED_PICTURE_BASE[math.min(felledStage, 4)] - (nextRandom(most) + 1), FELLED_PALETTE
      elseif logs > 0 and logs < K.RANDOM_STANDING and ours then
        local felledStage = math.max(stage, K.SMALLEST_FELLED_STAGE)
        shown, palette = FELLED_PICTURE_BASE[math.min(felledStage, 4)] - logs, FELLED_PALETTE
      else
        if ours and logs == K.RANDOM_STANDING and stage <= K.MOST_RANDOM_STAGE then
          stage = nextRandom(stage + 1)               -- the stage the next random choice gives
        end
        shown = picture(treeType, stage)
      end
    end
    if not shown then return end
    -- The tile under the mouse, as the click handlers work it out.
    if rd32(R.flatView) ~= 0 then flatSetup(R.viewport) else mouseSetup(R.viewport) end
    local x, y = rd32(R.mouseX), rd32(R.mouseY)
    if x < 0 or y < 0 or x >= K.MAP_SIZE or y >= K.MAP_SIZE then return end
    -- Not where the tree cannot go: placeTree's tests on the tile, and the mask.
    if rd8(R.validTiles + y * K.MAP_SIZE + x) == 0 then return "refused" end
    local tile = rd32(R.rows + y * 12) + x
    local logic = rd32(T + R.logic + tile * 4) & 0xFFFFFFFF
    local refused = K.TREE_REFUSED
    if data.rocksAndWater ~= nil and rd8(data.rocksAndWater) ~= 0 then refused = refused & ~K.TREE_GROUND.loose end
    if logic & refused ~= 0 or rd16(T + R.organism + tile * 2) ~= 0 then return "refused" end
    -- the room around a new tree, unless Trees next to obstacles is ticked
    if not (data.nearObstacles ~= nil and rd8(data.nearObstacles) ~= 0) and not roomFree(treeType, tile, y) then return "refused" end
    if not C.maskPeek(T, R, tile) then return "refused" end
    local drawX, drawY = surface(x, y, tile)
    if drawX == nil then return end
    -- Where renderMap puts a tree: tile + (14, 6) - the origin of the tree's gm.
    local sx = drawX + K.TREE_DRAW_X - rd16(originX + gm * originStride)
    local sy = drawY + K.TREE_DRAW_Y - rd16(originY + gm * originStride)
    local t = G.textures
    local mode, direct = rd32(t + TEXTURES_MODE), rd32(t + TEXTURES_DIRECT_PALETTE)
    local sprite, spritePalette = rd32(G.sprite), rd32(G.spritePalette)
    wr32(t + TEXTURES_MODE, MAP_LAYER)
    wr32(t + TEXTURES_DIRECT_PALETTE, 1)
    wr32(G.sprite, gm)
    wr32(G.spritePalette, palette)
    renderGM(t, gm, shown, sx, sy)
    wr32(G.sprite, sprite)
    wr32(G.spritePalette, spritePalette)
    wr32(t + TEXTURES_DIRECT_PALETTE, direct)
    wr32(t + TEXTURES_MODE, mode)
  end
  -- A click where the tree cannot go moves a random entry on to its next variant (nothing is
  -- placed, the preview shows the new one).
  return function()
    local result = draw()
    local down = (asyncKey(K.LEFT_BUTTON) % 0x10000) >= 0x8000
    if down and not wasDown and result == "refused" and randomEntry then
      wr32(data.seed, (rd32(data.seed) * K.RANDOM_MULTIPLIER + K.RANDOM_INCREMENT) & 0xFFFFFFFF)
    end
    wasDown = down
  end
end

-- The tree or rock on a tile, for the pipette: what placing the same again takes. Rocks the
-- game has no slot for (the invisible ones, number 2000) are left out.
function C.readPlant(G, T, R, plantOf, tile, logic)
  local number = rd16(T + R.organism + tile * 2)
  if number >= K.FIRST_ROCK_NUMBER and logic & K.ROCKY ~= 0 then
    local slot = number - K.FIRST_ROCK_NUMBER
    if slot < 1 or slot > G.rockSlots then return nil end
    local rock = G.firstRock - K.ROCK_SLOT.inUse + (slot - 1) * G.rockSize
    local rockType = rd16(rock + K.ROCK_SLOT.type)
    if rockType < 1 or rockType > K.ROCK_TYPES then return nil end
    local id = rockType - 1
    local size = id // 4 + 1
    return { kind = "rock", number = id, size = size, turn = rd16(rock + K.ROCK_SLOT.turn) & 0xFFFF,
      name = string.format("rock (size %d)", size) }
  end
  if number > 0 and number <= G.treeSlots and logic & K.TREE_FLAG ~= 0 then
    local tree = G.landscape + TREES_IN_LANDSCAPE + number * G.treeSize
    local treeType = rd16(tree + TREE.TYPE)
    local command = plantOf[treeType]
    if command == nil then return nil end
    local stage = rd8(tree + TREE.STAGE) & 0xFF
    local plant = { kind = "tree", command = command, stage = math.min(stage, MAX_STAGE),
      picture = rd32(tree + K.TREE_PICTURE) }
    local name = treeType == APPLE_TYPE and "apple tree" or K.PLANT_NAMES[command] or "shrub"
    if rd8(tree + TREE.LYING) & 0xFF == LYING_FELLED then
      plant.logs = math.max(1, rd8(tree + TREE.LOGS) & 0xFF)
      plant.name = string.format("felled %s, %d logs", name, plant.logs)
    else
      plant.name = string.format("%s, stage %d", name, plant.stage + 1)
    end
    return plant
  end
  return nil
end

-- The pipette button, its panel and the per-frame work, in the landscape menu being built.
function C.pipette(G, O, data, added, guarded, places, button)
  local S = O.pipette
  local R = C.resolvePipette(G)
  local T = R.tileMap
  local blit = core.exposeCode(G.blit, 3, 0)
  local tileForBrush = core.exposeCode(R.tileForBrush, 7, 1)
  local links = core.exposeCode(R.links, 3, 1)
  local removeRock = core.exposeCode(R.removeRock, 2, 1)
  local walk = core.exposeCode(R.walk, 4, 1)
  local redraw = core.exposeCode(R.redraw, 2, 1)
  local mouseSetup, flatSetup = core.exposeCode(R.mouseSetup, 1, 1), core.exposeCode(R.flatSetup, 1, 1)
  local asyncKey = core.exposeCode(core.allocateAssembly(templates.undoKeyState, { IMPORT = R.keyState }), 1, 0)
  local function down(key) return key ~= nil and (asyncKey(key) % 0x10000) >= 0x8000 end
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local text = core.allocate(256, true)
  local out = core.allocate(8, true)
  local commandOfType = core.exposeCode(R.commandOfType, 2, 1)
  local placeRock, placeTree = core.exposeCode(R.placeRock, 4, 1), core.exposeCode(R.placeTree, 4, 1)
  -- Which tool plants each tree type (the game's own answer, read by resolveCounters).
  local plantOf = {}
  for command, treeType in pairs(G.plantTypes or {}) do
    if plantOf[treeType] == nil or command < plantOf[treeType] then plantOf[treeType] = command end
  end
  data.pipetteRead = core.allocate(4, true)
  local activeFlag = core.allocate(4, true)    -- the pipette (or the tool it chose) is in use
  local P = { mode = 1, stored = nil, held = false, waitRelease = false, last = nil, keys = {} }
  local selectKey, readKey, anyKey = keyCode(S.selectKey), keyCode(S.readKey), keyCode(S.anyKey)

  local function chosen() return rd32(G.subtype) == K.PIPETTE_TOOL end
  -- The objects pipette's tool, while it holds an object.
  -- The tool that places what the objects pipette holds: a building's own, the tree's, or the
  -- rock tool.
  local function objectTool()
    if P.mode ~= K.PIPETTE_OBJECTS or P.stored == nil then return nil end
    if P.stored.kind == "rock" then return K.FIRST_ROCK_COMMAND end   -- the size comes from the brush
    return P.stored.command
  end
  -- What that tool needs set while the pipette holds a tree or rock (the brush for the tree's
  -- stage, its felled logs; the rock's size, variant and turn), and the user's own settings
  -- back afterwards.
  local function hold(stored)
    if P.saved ~= nil or stored.kind == "building" then return end
    local S2 = { brush = rd32(G.brush), turn = rd32(T + K.TILE_MAP.rotation), mode = rd32(T + K.TILE_MAP.mode),
      variant = rd32(T + K.ROCK_VARIANT_AT), size = rd32(T + K.ROCK_SIZE_AT) }
    if data.felledLogs ~= nil then S2.logs, S2.felled = rd32(data.felledLogs), rd32(data.felledCommand) end
    if data.rockLock ~= nil then S2.lock = rd32(data.rockLock) end
    P.saved = S2
    if stored.kind == "tree" then
      data.treePreview = { command = stored.command, picture = stored.picture }
      wr32(G.brush, stored.stage + 1)          -- the module's growth stage follows the brush size
      if data.felledLogs ~= nil then
        wr32(data.felledLogs, stored.logs or 0)
        wr32(data.felledCommand, stored.logs ~= nil and stored.command or 0)
      end
    else
      wr32(G.brush, 2 * (stored.size - 1) + 1)  -- the rock tools' size is brush / 2 (brushes 1, 3, 5, 7)
      wr32(T + K.ROCK_SIZE_AT, stored.size - 1)
      wr32(T + K.ROCK_VARIANT_AT, stored.number % 4)
      if data.rockLock ~= nil then wr32(data.rockLock, stored.number % 4 + 1) end
      wr32(T + K.TILE_MAP.rotation, stored.turn)
      wr32(T + K.TILE_MAP.mode, K.FIXED_TURN)
    end
  end
  local function release()
    local S2 = P.saved
    if S2 == nil then return end
    P.saved = nil
    data.treePreview = nil
    wr32(G.brush, S2.brush)
    wr32(T + K.TILE_MAP.rotation, S2.turn)
    wr32(T + K.TILE_MAP.mode, S2.mode)
    wr32(T + K.ROCK_VARIANT_AT, S2.variant)
    wr32(T + K.ROCK_SIZE_AT, S2.size)
    if S2.logs ~= nil then
      wr32(data.felledLogs, S2.logs)
      wr32(data.felledCommand, S2.felled)
    end
    if S2.lock ~= nil then wr32(data.rockLock, S2.lock) end
  end
  local function active()
    local tool = objectTool()
    return chosen() or (tool ~= nil and rd32(G.subtype) == tool)
  end
  local function choose()
    release()
    wr32(G.subtype, K.PIPETTE_TOOL)
    P.stored, P.waitRelease, P.last = nil, true, nil
  end
  local function reading() return P.stored == nil or P.reading end

  -- The tile at map x, y and the tiles of the brush around it (write mode: the brush size).
  local function tileOf(x, y) return rd32(R.rows + y * 12) + x end
  local function brushTiles(x, y, size)
    local count = rd32(R.brushSizes + size * 4)
    local base, list = tileOf(x, y), {}
    for i = 0, count - 1 do
      tileForBrush(T, 1, i, out, out + 4, base, y)
      local tile, ty = rd32(out), rd32(out + 4)
      if tile >= 0 and tile < K.MAP_TILES and ty >= 0 and ty < K.MAP_SIZE then list[#list + 1] = { tile, ty } end
    end
    return list
  end

  local function logicAt(tile) return rd32(T + R.logic + tile * 4) & 0xFFFFFFFF end
  local function read(x, y)
    local tile = tileOf(x, y)
    local logic = logicAt(tile)
    P.stored = {
      -- The height that is shown (a river tile lies RIVER_DEPTH below its base height).
      mode = P.mode, live = rd8(T + R.height + tile) & 0xFF,
      texture = logic & K.TEXTURE_FLAGS, decoration = rd8(T + K.TMS.decoration + tile) & 0xFF,
      random = rd16(T + K.TMS.random + tile * 2),
    }
    P.stored.base = P.stored.live
    if logic & K.RIVER_TERRAIN ~= 0 then P.stored.base = math.min(0xFF, P.stored.live + K.RIVER_DEPTH) end
  end

  -- The building or wall on a tile, as the tool that places it.
  local function readObject(x, y)
    local tile = tileOf(x, y)
    local id = rd16(T + K.TMS.building + tile * 2)
    local command, owner = 0, nil
    local variant, hovel = nil, nil
    if id > 0 then
      local buildingType = rd16(R.buildingType + id * R.buildingStride)
      command = commandOfType(0, buildingType) & 0xFFFF
      owner = rd16(R.buildingType + K.OWNER_AFTER_TYPE + id * R.buildingStride)
      -- The exact variant: its value found in its group's table.
      local group = K.VARIANT_GROUPS[buildingType]
      if group ~= nil then
        local value = rd32(R.buildingsState + id * R.buildingStride + R.variationField)
        local list = R.variationTables[group.table]
        for i = 0, group.count - 1 do
          if rd32(list + i * 4) == value then
            command, variant = group.first + i, string.format("%s %d", group.name, i + 1)
            break
          end
        end
      elseif buildingType == K.HOVEL_TYPE then
        hovel = rd16(R.hovelField + id * R.buildingStride) % K.HOVEL_VARIANTS
      elseif buildingType == K.CAMPFIRE_TYPE then
        command = K.BARRIER_COMMAND
      elseif buildingType == K.CATHEDRAL_TYPE and rd16(R.ruinedFlag + id * R.buildingStride) == 1 then
        variant = "ruined cathedral"
      end
    else
      owner = (rd8(T + K.TMS.wallOwner + tile) & K.WALL_OWNER_BITS) + 1
      local logic = logicAt(tile)
      if logic & K.STOCKPILE_FLAG ~= 0 then
        command = 0
      elseif logic & K.STAIRS_FLAG ~= 0 then
        command = K.STAIRS_TOOL
      elseif logic & K.CRENEL_FLAG ~= 0 then
        command = K.CRENEL_TOOL
      elseif logic & K.WALL_FLAG ~= 0 then
        local above = (rd8(T + R.height + tile) & 0xFF) - (rd8(T + R.defaultHeight + tile) & 0xFF)
        command = above >= K.HIGH_WALL_ABOVE and K.HIGH_WALL_TOOL or K.LOW_WALL_TOOL
      end
    end
    if command ~= 0 then
      P.nothing = false
      P.stored = { kind = "building", command = command, name = variant or K.OBJECT_NAMES[command] or ("object " .. command),
        variant = variant ~= nil and command ~= K.CATHEDRAL_TOOL, hovel = hovel,
        ruined = command == K.CATHEDRAL_TOOL and variant ~= nil }
      if hovel ~= nil then P.stored.name = string.format("hovel %d", hovel + 1) end
      if command == K.BARRIER_COMMAND then P.stored.name = "barrier" end
      if owner ~= nil and owner >= 1 and owner <= K.PLAYERS then
        P.stored.owner = owner
        P.stored.name = string.format("%s of player %d", P.stored.name, owner)
      end
      return
    end
    local plant = C.readPlant(G, T, R, plantOf, tile, logicAt(tile))
    P.nothing = plant == nil
    if plant ~= nil then P.stored = plant end
  end

  -- One tree or rock (as read by C.readPlant) at x, y, placed the way the landscape editor
  -- places one; for a tree its stage and felled logs through the module's tree hooks.
  local function placePlant(plant, x, y)
    if plant.kind == "rock" then
      local turn = T + K.TILE_MAP.rotation
      local before = rd32(turn)
      wr32(turn, plant.turn)
      placeRock(T, x, y, plant.number)
      wr32(turn, before)
      return
    end
    local brush = rd32(G.brush)
    local logs, felledCommand
    if data.felledLogs ~= nil then
      logs, felledCommand = rd32(data.felledLogs), rd32(data.felledCommand)
      wr32(data.felledLogs, plant.logs or 0)
      wr32(data.felledCommand, plant.logs ~= nil and plant.command or 0)
    end
    wr32(G.brush, plant.stage + 1)             -- the module's growth stage follows the brush size
    placeTree(T, x, y, plant.command)
    wr32(G.brush, brush)
    if data.felledLogs ~= nil then
      wr32(data.felledLogs, logs)
      wr32(data.felledCommand, felledCommand)
    end
  end

  -- Gives one tile the stored heights or textures; answers whether it changed it.
  local function blocked(tile, logic, mask)
    return logic & mask ~= 0 or rd16(T + K.TMS.building + tile * 2) ~= 0
  end
  local function setLive(tile, logic)
    local base = rd8(T + R.defaultHeight + tile) & 0xFF
    local live = base
    if logic & K.RIVER_TERRAIN ~= 0 then live = math.max(0, base - K.RIVER_DEPTH) end
    core.writeByte(T + R.height + tile, live)
  end
  -- A rocky tile: a rock stays (only the any-tile key takes it away, as the game's height tools
  -- do), a cliff rock goes. Answers the tile word without the rocky flag, or nil.
  local function unrock(tile, logic, any)
    if logic & K.ROCKY == 0 then return logic end
    local number = rd16(T + R.organism + tile * 2)
    if number >= K.FIRST_ROCK_NUMBER then
      -- A rock stays; with the any-tile key its tile still gets the heights or textures, like
      -- the plateau tools give them.
      if not any then return nil end
      return logic
    end
    return logic & ~K.ROCKY & 0xFFFFFFFF
  end
  local function giveHeights(tile, logic, any)
    if not any and (blocked(tile, logic, K.HEIGHT_REFUSED)
        or (rd8(T + K.TMS.decoration + tile) & 0xFF) & K.BEACH_DECORATION ~= 0) then
      return false
    end
    logic = unrock(tile, logic, any)
    if logic == nil then return false end
    wr32(T + R.logic + tile * 4, logic)
    core.writeByte(T + R.defaultHeight + tile, P.stored.base)
    setLive(tile, logic)
    return true
  end
  local function giveTextures(tile, logic, any)
    if not any and blocked(tile, logic, K.TEXTURE_REFUSED) then return false end
    logic = unrock(tile, logic, any)
    if logic == nil then return false end
    local new = (logic & ~K.TEXTURE_FLAGS & 0xFFFFFFFF) | P.stored.texture
    local decoration = rd8(T + K.TMS.decoration + tile) & 0xFF
    wr32(T + R.logic + tile * 4, new)
    core.writeByte(T + K.TMS.decoration + tile, P.stored.decoration)
    -- A new random number for a tile whose ground changes, and for one that still has the
    -- source's (pipette versions before 1.0.31 copied it, which made the ground repeat).
    if new ~= logic or decoration ~= P.stored.decoration or rd16(T + K.TMS.random + tile * 2) == P.stored.random then
      wr16(T + K.TMS.random + tile * 2, math.random(0, K.RANDOM_LIMIT))
    end
    if (new ~ logic) & K.RIVER_TERRAIN ~= 0 then setLive(tile, new) end
    return true
  end

  local function apply(x, y)
    local any = S.anyKeyOn and down(anyKey)
    local changed = false
    local tiles = brushTiles(x, y, rd32(T + R.brushField))
    if O.undo ~= nil then O.undo.beginEdit() end
    -- The mask decides on every tile before anything changes (painting changes the texture).
    local clicked, allowed = tileOf(x, y), {}
    for _, at in ipairs(tiles) do allowed[at[1]] = C.maskAllows(T, R, at[1], clicked) end
    for _, at in ipairs(tiles) do
      local tile, ty = at[1], at[2]
      local logic = logicAt(tile)
      if logic & K.MAP_BORDER == 0 and allowed[tile] then
        local done = false
        if P.mode == K.PIPETTE_TEXTURES or P.mode == K.PIPETTE_ALL then
          done = giveTextures(tile, logic, any) or done
          logic = logicAt(tile)
        end
        if P.mode == K.PIPETTE_HEIGHTS or P.mode == K.PIPETTE_ALL then done = giveHeights(tile, logic, any) or done end
        if done then
          links(R.pathFinding, ty, tile)
          changed = true
        end
      end
    end
    if P.mode == K.PIPETTE_ALL and P.stored.plant ~= nil then
      -- The mask already chose the tiles; the tree and rock placement would test them again,
      -- after their texture changed.
      local mask = C.maskState
      local on = mask ~= nil and rd32(mask.on) or 0
      if mask ~= nil then wr32(mask.on, 0) end
      for _, at in ipairs(tiles) do
        local tile, ty = at[1], at[2]
        if allowed[tile] then placePlant(P.stored.plant, tile - rd32(R.rows + ty * 12), ty) end
      end
      if mask ~= nil then wr32(mask.on, on) end
    end
    if not changed then return end
    -- What the game's height and terrain tools do afterwards.
    wr32(T + R.logicFlag, 1)
    wr32(R.macroFlag, 1)
    walk(R.pathFinding, K.WALK_RADIUS, x, y)
    redraw(R.minimap, 2)
  end

  local function editor() return rd32(R.gameMode) == K.MAP_EDITOR end
  local function typing() return rd32(R.menuGuard) ~= -1 end
  local function pressed(key)
    local now = down(key)
    local was = P.keys[key]
    P.keys[key] = now
    return now and not was
  end

  -- Every frame, before the map click handler.
  local function tick()
    if not editor() then return end
    if C.watchRuins ~= nil then C.watchRuins() end   -- a ruined cathedral placed from here
    if S.selectKeyOn and selectKey ~= nil and pressed(selectKey) and not typing() then
      if active() then P.mode = P.mode % #K.PIPETTE_MODES + 1 end
      choose()
    end
    if not active() then
      P.held, P.waitRelease = false, false
      release()
      if P.mode == K.PIPETTE_OBJECTS then P.stored = nil end   -- another tool was chosen
      wr32(data.pipetteRead, K.NO_TOOL)
      wr32(activeFlag, 0)
      return
    end
    wr32(activeFlag, 1)
    P.reading = S.readKeyOn and down(readKey)
    -- One tile in the brush preview while taking a tile, and for objects (placed one at a time).
    -- (a tree's own tool too: placed one per tile like the game's tree tool, whatever the brush)
    local oneTile = K.NO_TOOL
    if reading() or P.mode == K.PIPETTE_OBJECTS then oneTile = K.PIPETTE_TOOL end
    if not chosen() and P.stored ~= nil and P.stored.kind == "tree" then oneTile = P.stored.command end
    wr32(data.pipetteRead, oneTile)
    local held = rd32(R.clickHeld) ~= 0
    if P.mode == K.PIPETTE_OBJECTS and not held then
      -- Between clicks: the object's own tool to place it, the pipette to take one.
      local tool = objectTool()
      if reading() and not chosen() then
        release()
        wr32(G.subtype, K.PIPETTE_TOOL)
      elseif not reading() and tool ~= nil and chosen() then
        hold(P.stored)
        wr32(G.subtype, tool)
        -- This very variant, not turning into the next one.
        local locks = C.locks()
        if P.stored.variant then wr32(locks.variant, tool) end
        if P.stored.hovel ~= nil then wr32(locks.hovel, P.stored.hovel + 1) end
        if tool == K.CATHEDRAL_TOOL then wr32(locks.ruined, P.stored.ruined and 1 or 0) end
        -- Placed for the same player: chosen as if by that player's shield.
        local owner = P.stored.owner
        if owner ~= nil then
          for i = 0, K.PLAYERS do wr32(R.playerFlags + i * 4, 0) end
          wr32(R.playerFlags + owner * 4, 1)
          wr32(R.currentPlayer, owner)
          wr32(R.editorPlayer, owner)
        end
      end
    end
    if not held then
      P.held, P.waitRelease, P.last = false, false, nil
      return
    end
    if not chosen() then return end            -- the game places the object
    if P.waitRelease or rd32(G.onMap) == 0 then return end
    if rd32(R.flatView) ~= 0 then flatSetup(R.viewport) else mouseSetup(R.viewport) end
    local x, y = rd32(R.mouseX), rd32(R.mouseY)
    if x < 0 or y < 0 or x >= K.MAP_SIZE or y >= K.MAP_SIZE then return end
    if reading() then
      if P.mode == K.PIPETTE_OBJECTS then
        readObject(x, y)
      else
        read(x, y)
        if P.mode == K.PIPETTE_ALL then
          local tile = tileOf(x, y)
          local plant = C.readPlant(G, T, R, plantOf, tile, logicAt(tile))
          if plant ~= nil and (plant.kind == "tree" or plant.size == 1) then P.stored.plant = plant end
        end
      end
      P.waitRelease = true       -- the next click writes
      return
    end
    if P.mode == K.PIPETTE_OBJECTS then return end   -- the object's own tool places it
    local tile = tileOf(x, y)
    if tile == P.last then return end
    P.last = tile
    apply(x, y)
  end

  -- The button, in the column of brush size, ruler and eraser (all moved down for it).
  local pictures = buttonPictures("pipette")
  local pipette = added.pipette
  wr32(pipette + ITEM_TYPE, TYPE_CLICKABLE)
  wr32(pipette + ITEM_X, K.PIPETTE_COLUMN.x)
  wr32(pipette + ITEM_Y, K.PIPETTE_COLUMN.tops[1])
  wr32(pipette + ITEM_WIDTH, pictures.width)
  wr32(pipette + ITEM_HEIGHT, pictures.height)
  wr32(pipette + ITEM_ACTION, C.luaPad(choose, "the pipette button"))
  wr32(pipette + ITEM_RENDER, core.allocateAssembly(templates.flagPictureButton, {
    NORMAL = pictures.normal, HOVERED = pictures.hover, CHOSEN = pictures.chosen, FLAG = activeFlag,
    HOVER = G.hover, PENCIL = G.pencil, PENCIL_TARGET = PENCIL_TARGET, ITEM_X = G.itemX, ITEM_Y = G.itemY,
    BLIT = G.blit,
  }))
  wr32(pipette + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  wr32(pipette + ITEM_TEXT, 0)
  guarded[#guarded + 1] = pipette
  guarded[#guarded + 1] = 0
  for i, param in ipairs(K.PIPETTE_COLUMN.moved) do
    local top = K.PIPETTE_COLUMN.tops[i + 1]
    for _, extra in ipairs(param) do
      if G.buttons[extra] ~= nil then
        local into = button(extra)
        wr32(into + ITEM_X, K.PIPETTE_COLUMN.x)
        wr32(into + ITEM_Y, top)
        wr16(into + ITEM_CONTROL, -1)
      end
    end
  end

  -- The panel: heights, textures, all; and above it what the pipette holds.
  local panel = { items = {}, info = added.info }
  local entries = {}
  for i, mode in ipairs(K.PIPETTE_MODES) do
    local into = added["pipetteMode" .. i]
    wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(into + ITEM_ACTION, C.luaPad(function()
      P.mode = i
      choose()
    end, "the pipette panel"))
    wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
    wr16(into + ITEM_HIDDEN, 1)
    panel.items[i] = into
    guarded[#guarded + 1] = into
    guarded[#guarded + 1] = 0
    entries[i] = { item = into, label = mode.label }
    if mode.image ~= nil then
      entries[i].image = mode.image
    else
      entries[i].picture = { address = pictures.normal, width = pictures.width, height = pictures.height }
    end
  end
  local paint = makePanel(G, { counts = false }, data, panel, function()
    local list = {}
    for i, entry in ipairs(entries) do
      list[i] = { item = entry.item, image = entry.image, picture = entry.picture, label = entry.label,
        chosen = P.mode == i, minWidth = K.PIPETTE_ENTRY_WIDTH }
    end
    list.labelRoom = K.PIPETTE_LABEL_ROOM
    list.rectAbove = K.PIPETTE_TEXT_ABOVE
    return list
  end)
  local function storedLine()
    local mode = K.PIPETTE_MODES[P.mode]
    if P.stored == nil then
      if P.mode == K.PIPETTE_OBJECTS and P.nothing then
        return "Pipette: nothing to take there - click a building, wall, tree or rock"
      end
      return "Pipette: click a tile to take its " .. mode.what
    end
    if P.mode == K.PIPETTE_OBJECTS then
      return (reading() and "Pipette (taking) holds: " or "Pipette places: ") .. P.stored.name
    end
    local parts = {}
    if P.mode ~= K.PIPETTE_HEIGHTS then
      parts[#parts + 1] = "textures: " .. C.textureNames(P.stored.texture, P.stored.decoration)
    end
    if P.mode == K.PIPETTE_ALL and P.stored.plant ~= nil then parts[#parts + 1] = P.stored.plant.name end
    if P.mode ~= K.PIPETTE_TEXTURES then
      local line = "height " .. P.stored.base
      if P.stored.live ~= P.stored.base then line = line .. " (water " .. P.stored.live .. ")" end
      parts[#parts + 1] = line
    end
    local prefix = reading() and "Pipette (taking): " or "Pipette holds "
    return prefix .. table.concat(parts, "; ")
  end
  local function painter()
    paint()
    local first = panel.items[1]
    if rd16(first + ITEM_HIDDEN) ~= 0 then return end
    local line = storedLine()
    writeCString(text, line:sub(1, 250))
    local width = textWidth(G.textManager, text, math.min(#line, 250), TOOLTIP_FONT)
    local x = (rd32(G.screenWidth) - width) // 2 + rd32(G.cameraX)
    local y = rd32(G.menu + MENU_Y) + rd32(first + ITEM_Y) - K.PIPETTE_TEXT_ABOVE + rd32(G.cameraY)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    shadowedText(G.textManager, text, x, y, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    wr32(G.textLayer, layer)
  end
  local painterItem = added.pipettePanel
  wr32(painterItem + ITEM_TYPE, TYPE_CLICKABLE)
  wr32(painterItem + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  wr32(painterItem + ITEM_RENDER, core.allocateAssembly(templates.flagPanel, {
    FLAG = activeFlag, PANEL_ITEMS = dwordList(panel.items), ITEM_HIDDEN = ITEM_HIDDEN,
    PAD = C.luaPad(painter, "the pipette panel"),
  }))

  local tickItem = added.pipetteTick
  wr32(tickItem + ITEM_TYPE, TYPE_EVERY_FRAME)
  wr32(tickItem + ITEM_ACTION, C.luaPad(tick, "the pipette"))
  data.pipette = R
end

-- The brush preview while the pipette takes a tile: one tile, whatever the brush size.
function C.patchPipettePreview(self, R, readFlag)
  wr32(readFlag, K.NO_TOOL)
  patchJump(self, R.previewSite, K.PIPETTE_PREVIEW.size, core.allocateAssembly(templates.pipettePreview, {
    ONE_TILE = readFlag, BRUSH = R.brushField, BACK = R.previewSite + K.PIPETTE_PREVIEW.size,
  }))
end

-- The undo and redo buttons (items added as "undo" and "redo") in the screen's top left
-- corner, drawn on the map surface like the tooltips. Shown in the map editor only.
function C.undoButtons(G, added, guarded, actions)
  if G.blit == nil then
    G.blit = core.allocateAssembly(templates.blit, {
      PENCIL = G.pencil, SETUP_SURFACE = G.setupSurface, SETUP_PENCIL = G.setupPencil,
      SCRATCH = core.allocate(32, true), PIXEL_FORMAT = G.pixelFormat,
    })
  end
  local blit = core.exposeCode(G.blit, 3, 0)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  if actions.pictures == nil then
    actions.pictures = {}
    for _, kind in ipairs({ "undo", "redo" }) do
      local normal, hover, off = loadPicture(kind), loadPicture(kind .. "_hover"), loadPicture(kind .. "_off")
      local width = math.max(normal.width, hover.width, off.width)
      local height = math.max(normal.height, hover.height, off.height)
      actions.pictures[kind] = { width = width, height = height, normal = storePicture(normal, width, height),
        hover = storePicture(hover, width, height), off = storePicture(off, width, height) }
    end
  end
  local B, left = K.UNDO_BUTTONS, K.UNDO_BUTTONS.left
  for _, kind in ipairs({ "undo", "redo" }) do
    local button, P, x = added[kind], actions.pictures[kind], left
    left = left + P.width + B.gap
    wr32(button + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(button + ITEM_Y, K.FAR_AWAY)
    wr32(button + ITEM_WIDTH, P.width)
    wr32(button + ITEM_HEIGHT, P.height)
    wr32(button + ITEM_ACTION, C.luaPad(actions[kind], "the " .. kind .. " button"))
    wr32(button + ITEM_RENDER, C.luaPad(function()
      if kind == "undo" then actions.tick() end
      local menu = rd32(button + ITEM_MENU)
      if menu == 0 or not actions.editor() then
        wr32(button + ITEM_Y, K.FAR_AWAY)
        return
      end
      wr32(button + ITEM_X, x - rd32(menu + MENU_X))
      wr32(button + ITEM_Y, B.top - rd32(menu + MENU_Y))
      local sx, sy = x + rd32(G.cameraX), B.top + rd32(G.cameraY)
      local picture = P.off
      if actions.available[kind]() then
        picture = rd16(button + ITEM_HOVERED) ~= 0 and P.hover or P.normal
      end
      local target = rd32(G.pencil + PENCIL_TARGET)
      wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
      roundedBox(G.pencil, sx - B.padding, sy - B.padding, sx + P.width - 1 + B.padding,
        sy + P.height - 1 + B.padding, BOX_BLEND)
      blit(picture, sx, sy)
      wr32(G.pencil + PENCIL_TARGET, target)
    end, "the " .. kind .. " button"))
    wr32(button + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(button + ITEM_TEXT, 0)
    guarded[#guarded + 1] = button
    guarded[#guarded + 1] = 0
  end
end

-- Herds of the brush size while the herd panel's check box is on.
local function patchHerds(self, G, data)
  for _, herd in pairs(G.herds) do
    patchJump(self, herd.site, K.HERD.size, core.allocateAssembly(templates.herdSize, {
      MASK = herd.mask, UNIT = herd.unit, BASE = herd.base, HERD_SYNC = data.herdSync, BRUSH = G.brush,
      BACK = herd.site + K.HERD.size,
    }))
  end
end

---------------------------------------------------------------------------------------
-- The heights menu: max height, the height tools' options, lost rocks (features 28, 29)
---------------------------------------------------------------------------------------

-- The words the height tool patches read (shared with the panel), the strength of raise, lower
-- and equalize, and where the raise and lower amounts are written (once patched). The height
-- range, snap, invert and the ignore boxes go back to their defaults outside the map editor
-- (templates.frameHook).
function C.heightWords()
  if C.heightState == nil then
    local function word(value)
      local address = core.allocate(4, true)
      wr32(address, value or 0)
      return address
    end
    local H = {
      reset = word(), breakRocks = word(), mode = word(K.ROCK_WHOLE), divisor = word(), count = word(),
      records = core.allocate(K.ROCK_RECORDS * 8, true), strength = {}, open = false,
      rangeMin = word(K.HEIGHT_RANGE_DEFAULT[1]), rangeMax = word(K.HEIGHT_RANGE_DEFAULT[2]), snap = word(1),
      invert = word(), ignoreWater = word(), ignoreFarmland = word(), seed = word(0x2F6B1D),
    }
    for tool, value in pairs(K.STRENGTH_DEFAULTS) do H.strength[tool] = value end
    wr32(H.divisor, K.STRENGTH_SUM - H.strength[K.EQUALIZE_TOOL])
    C.heightState = H
  end
  return C.heightState
end

-- The chosen strength into the game: the raise and lower commands' amounts (code immediates)
-- and equalize's divisor.
function C.applyStrength(H)
  if H.raiseAmount ~= nil then core.writeCodeInteger(H.raiseAmount, H.strength[K.RAISE_TOOL]) end
  if H.lowerAmount ~= nil then core.writeCodeInteger(H.lowerAmount, -H.strength[K.LOWER_TOOL]) end
  wr32(H.divisor, K.STRENGTH_SUM - H.strength[K.EQUALIZE_TOOL])
end

-- The items the heights menu gets, in the order they are inserted at the end of its tab.
K.HEIGHT_PANEL_ITEMS = { "heightReset", "heightBreak", "heightWater", "heightFarmland", "heightSnap", "heightInvert",
  "heightRange", "heightStrength", "heightMode", "heightRangeReset" }
function C.heightItems(O)
  local list = {}
  if O.maxHeight then list[#list + 1] = "maxHeight" end
  if O.heightTools then
    for _, kind in ipairs(K.HEIGHT_PANEL_ITEMS) do list[#list + 1] = kind end
    for i = 1, #K.ROCK_MODES do list[#list + 1] = "heightOption" .. i end
    list[#list + 1] = "heightPanel"
  end
  return list
end

-- Where the mouse is on the screen, in x: the largest x the menu's mouse test does not put the
-- mouse left of (the game keeps the position in its own form).
function C.mouseX(G)
  C.isMouseInside = C.isMouseInside or core.exposeCode(G.isMouseInside, 5, 1)
  local low, high = -1, 8192
  while high - low > 1 do
    local middle = (low + high) // 2
    if C.isMouseInside(G.mouse, -100000, -100000, 100000 + middle, 200000) ~= 0 then high = middle else low = middle end
  end
  return low
end

-- Moves the rest of each rock a height tool touched in Whole rock (the tiles rockCheck
-- remembered): every tile of the rock by the average change of its touched tiles, then what the
-- height tools do afterwards (path links per tile, walk layer, minimap).
function C.rockSettler(G, R, H)
  local T = R.tileMap
  local links = core.exposeCode(R.links, 3, 1)
  local walk = core.exposeCode(R.walk, 4, 1)
  local redraw = core.exposeCode(R.redraw, 2, 1)
  local function baseAt(tile) return rd8(T + R.defaultHeight + tile) & 0xFF end
  return function()
    local count = math.min(rd32(H.count), K.ROCK_RECORDS)
    wr32(H.count, 0)
    local rocks, order = {}, {}
    for i = 0, count - 1 do
      local at = H.records + i * 8
      local tile, id, old = rd32(at), rd16(at + 4) & 0xFFFF, rd8(at + 6) & 0xFF
      local rock = rocks[id]
      if rock == nil then
        rock = { old = {} }
        rocks[id] = rock
        order[#order + 1] = id
      end
      if rock.old[tile] == nil then rock.old[tile] = old end
    end
    local changed = false
    for _, id in ipairs(order) do
      local rock = rocks[id]
      local sum, n = 0, 0
      for tile, old in pairs(rock.old) do
        sum = sum + baseAt(tile) - old
        n = n + 1
      end
      local delta = sum >= 0 and math.floor(sum / n + 0.5) or -math.floor(-sum / n + 0.5)
      local slot = G.firstRock - K.ROCK_SLOT.inUse + (id - 1) * G.rockSize
      local rx, ry = rd16(slot + K.ROCK_POSITION.x) & 0xFFFF, rd16(slot + K.ROCK_POSITION.y) & 0xFFFF
      local number, moved = K.FIRST_ROCK_NUMBER + id, false
      for y = math.max(0, ry - K.ROCK_REACH), math.min(K.MAP_SIZE - 1, ry + K.ROCK_REACH) do
        local row = rd32(R.rows + y * 12)
        for x = math.max(0, rx - K.ROCK_REACH), math.min(K.MAP_SIZE - 1, rx + K.ROCK_REACH) do
          local tile = row + x
          if rd8(R.validTiles + y * K.MAP_SIZE + x) ~= 0 and tile >= 0 and tile < K.MAP_TILES
              and (rd16(T + R.organism + tile * 2) & 0xFFFF) == number then
            local height = math.max(0, math.min(0xFF, (rock.old[tile] or baseAt(tile)) + delta))
            if height ~= baseAt(tile) then
              core.writeByte(T + R.defaultHeight + tile, height)
              local live = height
              if rd32(T + R.logic + tile * 4) & K.RIVER_TERRAIN ~= 0 then live = math.max(0, height - K.RIVER_DEPTH) end
              core.writeByte(T + R.height + tile, live)
              links(R.pathFinding, y, tile)
              moved = true
            end
          end
        end
      end
      if moved then
        walk(R.pathFinding, K.WALK_RADIUS, rx, ry)
        changed = true
      end
    end
    if changed then
      wr32(T + R.logicFlag, 1)
      wr32(R.macroFlag, 1)
      redraw(R.minimap, 2)
    end
  end
end

-- Rock slots in use that no tile of the map names any more (all their tiles were taken over,
-- by shrubs placed on a rock the raise and lower tools broke): freed the way removeRock frees a
-- slot (zeroed), without touching any tile. Answers how many.
function C.removeLostRocks(G, R)
  local T = R.tileMap
  local named = {}
  for tile = 0, K.MAP_TILES - 1 do
    local number = rd16(T + R.organism + tile * 2) & 0xFFFF
    if number >= K.FIRST_ROCK_NUMBER then named[number - K.FIRST_ROCK_NUMBER] = true end
  end
  local zeros = {}
  for i = 1, G.rockSize do zeros[i] = 0 end
  local removed = 0
  for id = 1, G.rockSlots do
    local inUse = G.firstRock + (id - 1) * G.rockSize
    if rd16(inUse) ~= 0 and not named[id] then
      core.writeBytes(inUse - K.ROCK_SLOT.inUse, zeros)
      removed = removed + 1
    end
  end
  return removed
end

-- The heights panel, above the menu while a height tool is chosen, in rows from the bottom:
-- Reset ground textures, Break rock tiles, Ignore water, Ignore farmland; for raise, lower and
-- equalize Snap to range, Invert (equalize), the height range and the strength; on top the rock
-- height list (it opens upwards). The two sliders follow the mouse while its button is held.
function C.makeHeightPanel(G, data, H, items, leftHeld)
  local rect, listRect = C.takeRect(data), C.takeRect(data)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local colourBox = core.exposeCode(G.colourBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local renderGM = core.exposeCode(G.renderGM, 5, 1)
  local buffer = core.allocate(128, true)
  local P = K.HEIGHT_PANEL
  local function width(text)
    writeCString(buffer, text)
    return textWidth(G.textManager, buffer, #text, TOOLTIP_FONT)
  end
  local function write(text, x, y)
    writeCString(buffer, text)
    shadowedText(G.textManager, buffer, x, y, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
  end
  local function place(address, x, y, w, h)
    wr32(address + ITEM_X, x)
    wr32(address + ITEM_Y, y)
    wr32(address + ITEM_WIDTH, w)
    wr32(address + ITEM_HEIGHT, h)
    wr16(address + ITEM_HIDDEN, 0)
  end
  local function modeName(mode)
    for _, entry in ipairs(K.ROCK_MODES) do
      if entry[1] == mode then return entry[2] end
    end
    return "?"
  end
  local box = K.CHECK_BOX_SIZE
  local checks = {
    { item = items.reset, word = H.reset, label = "Reset ground textures" },
    { item = items.breakRocks, word = H.breakRocks, label = "Break rock tiles" },
    { item = items.water, word = H.ignoreWater, label = "Ignore water" },
    { item = items.farmland, word = H.ignoreFarmland, label = "Ignore farmland" },
    { item = items.snap, word = H.snap, label = "Snap to range" },
    { item = items.invert, word = H.invert, label = "Invert" },
  }
  local byItem = {}
  for _, check in ipairs(checks) do byItem[check.item] = check end

  -- A slider's value under the mouse: lo .. hi over the item's width.
  local function valueAt(address, lo, hi)
    local left = rd32(G.menu + MENU_X) + rd32(address + ITEM_X)
    local w = math.max(1, rd32(address + ITEM_WIDTH))
    local value = lo + ((C.mouseX(G) - left) * (hi - lo) + w // 2) // w
    return math.max(lo, math.min(hi, value))
  end
  local function follow()
    if H.drag == nil then return end
    if not leftHeld() then
      H.drag = nil
      return
    end
    local tool = rd32(G.subtype)
    if H.drag == "strength" then
      if H.strength[tool] == nil then return end
      local value = valueAt(items.strength, 1, K.STRENGTH_MOST)
      if value ~= H.strength[tool] then
        H.strength[tool] = value
        C.applyStrength(H)
      end
    else
      local value = valueAt(items.range, 0, 0xFF)
      if H.drag == "min" then
        wr32(H.rangeMin, math.min(value, rd32(H.rangeMax)))
      else
        wr32(H.rangeMax, math.max(value, rd32(H.rangeMin)))
      end
    end
  end
  C.heightPanelValueAt = valueAt

  return function()
    for _, address in ipairs(items.all) do wr16(address + ITEM_HIDDEN, 1) end
    follow()
    local tool = rd32(G.subtype)
    local strength = H.strength[tool]
    local ranged = strength ~= nil
    -- The rows: { kind, item } entries with their widths.
    local rows = { { checks[1], checks[2], checks[3], checks[4] } }
    if ranged then
      local row = { checks[5] }
      if tool == K.EQUALIZE_TOOL then row[#row + 1] = checks[6] end
      row[#row + 1] = { item = items.strength, slider = "strength" }
      rows[#rows + 1] = row
      -- the range slider (a pixel per height) and its Reset button on a row of their own
      rows[#rows + 1] = { { item = items.range, slider = "range" },
        { item = items.rangeReset, button = true, label = "Reset" } }
    end
    rows[#rows + 1] = { { item = items.mode, list = true } }
    local modeWidth = 0
    for _, entry in ipairs(K.ROCK_MODES) do modeWidth = math.max(modeWidth, width(entry[2])) end
    local listLabel = "Rock height changes:"
    local rangeLabel = string.format("Height range %d - %d", rd32(H.rangeMin), rd32(H.rangeMax))
    local panelWidth = 0
    for _, row in ipairs(rows) do
      row.width = 0
      for _, element in ipairs(row) do
        if element.list then
          element.width = width(listLabel) + TOOLTIP_PADDING + modeWidth + 3 * TOOLTIP_PADDING + width("v")
        elseif element.slider == "range" then
          element.label, element.track = rangeLabel, P.rangeSlider
          element.width = width("Height range 255 - 255") + TOOLTIP_PADDING + P.rangeSlider
        elseif element.button then
          element.width = width(element.label) + 2 * TOOLTIP_PADDING
        elseif element.slider == "strength" then
          element.label, element.track = string.format("Strength %d", strength), P.slider
          element.width = width("Strength 16") + TOOLTIP_PADDING + P.slider
        else
          element.width = box + TOOLTIP_PADDING + width(element.label)
        end
        row.width = row.width + element.width
      end
      row.width = row.width + P.gap * (#row - 1)
      panelWidth = math.max(panelWidth, row.width)
    end
    local total = panelWidth + 2 * TOOLTIP_PADDING
    local height = #rows * box + (#rows - 1) * P.rowGap + 2 * TOOLTIP_PADDING
    local menuX = rd32(G.menu + MENU_X)
    local left = (rd32(G.screenWidth) - total) // 2 - menuX
    local top = PANEL_BOTTOM - height
    C.markRect(rect, left, top, total, height)
    for r, row in ipairs(rows) do
      row.y = PANEL_BOTTOM - TOOLTIP_PADDING - r * box - (r - 1) * P.rowGap
      local x = left + TOOLTIP_PADDING + (panelWidth - row.width) // 2
      for _, element in ipairs(row) do
        element.x = x
        if element.track ~= nil then
          place(element.item, x + element.width - element.track, row.y, element.track, box)
        else
          place(element.item, x, row.y, element.width, box)
        end
        x = x + element.width + P.gap
      end
    end
    local list = rows[#rows][1]
    local options = #K.ROCK_MODES
    local listTop = top - P.dropdown - options * P.optionHeight
    if H.open then
      for i = 1, options do
        place(items.options[i], list.x, listTop + (i - 1) * P.optionHeight, list.width, P.optionHeight)
      end
      C.markRect(listRect, list.x, listTop, list.width, options * P.optionHeight)
    else
      C.markRect(listRect, 0, 0, 0, 0)
    end

    local offsetX = menuX - rd32(G.menu + MENU_SCROLL) + rd32(G.cameraX)
    local offsetY = rd32(G.menu + MENU_Y) + rd32(G.cameraY)
    local white = rd32(G.pixelFormat) == 0x565 and 0xFFFF or 0x7FFF
    local function frame(l, t, r, b)
      colourBox(G.pencil, l, t, r, t + 1, white)
      colourBox(G.pencil, l, b - 1, r, b, white)
      colourBox(G.pencil, l, t, l + 1, b, white)
      colourBox(G.pencil, r - 1, t, r, b, white)
    end
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    roundedBox(G.pencil, offsetX + left, offsetY + top, offsetX + left + total, offsetY + PANEL_BOTTOM, BOX_BLEND)
    for _, row in ipairs(rows) do
      for _, element in ipairs(row) do
        local address = element.item
        if element.track == nil and rd16(address + ITEM_HOVERED) ~= 0 then
          local l, t = offsetX + rd32(address + ITEM_X), offsetY + rd32(address + ITEM_Y)
          roundedBox(G.pencil, l, t, l + rd32(address + ITEM_WIDTH), t + rd32(address + ITEM_HEIGHT), BOX_BLEND)
        end
        if element.list then
          local headX = offsetX + element.x + width(listLabel) + TOOLTIP_PADDING
          element.headX = headX
          frame(headX, offsetY + row.y + 3, offsetX + element.x + element.width, offsetY + row.y + box - 3)
        elseif element.button then
          frame(offsetX + element.x, offsetY + row.y + 3, offsetX + element.x + element.width, offsetY + row.y + box - 3)
        elseif element.track ~= nil then
          local l = offsetX + rd32(address + ITEM_X)
          local middle = offsetY + row.y + box // 2
          local t, b = middle - P.sliderHeight // 2, middle + P.sliderHeight // 2
          roundedBox(G.pencil, l, t, l + element.track, b, BOX_BLEND)
          if element.slider == "strength" then
            local filled = l + (element.track * strength) // K.STRENGTH_MOST
            colourBox(G.pencil, l, middle - 1, filled, middle + 1, white)
            colourBox(G.pencil, filled - 2, t - 3, filled + 2, b + 3, white)
          else
            local low = l + (element.track * rd32(H.rangeMin)) // 0xFF
            local high = l + (element.track * rd32(H.rangeMax)) // 0xFF
            colourBox(G.pencil, low, middle - 2, math.max(low + 1, high), middle + 2, white)
            colourBox(G.pencil, low - 2, t - 3, low + 2, b + 3, white)
            colourBox(G.pencil, high - 2, t - 3, high + 2, b + 3, white)
          end
          frame(l, t, l + element.track, b)
        end
      end
    end
    if H.open then
      local l = offsetX + list.x
      roundedBox(G.pencil, l, offsetY + listTop, l + list.width, offsetY + top - P.dropdown, BOX_BLEND)
      for i = 1, options do
        local address = items.options[i]
        local ot = offsetY + rd32(address + ITEM_Y)
        if rd16(address + ITEM_HOVERED) ~= 0 then roundedBox(G.pencil, l, ot, l + list.width, ot + P.optionHeight, BOX_BLEND) end
        if K.ROCK_MODES[i][1] == rd32(H.mode) then frame(l, ot, l + list.width, ot + P.optionHeight) end
      end
    end
    wr32(G.pencil + PENCIL_TARGET, target)

    local mode = rd32(G.textures + TEXTURES_MODE)
    wr32(G.textures + TEXTURES_MODE, MAP_LAYER)
    for _, row in ipairs(rows) do
      for _, element in ipairs(row) do
        local check = byItem[element.item]
        if check ~= nil then
          local image = G.buttonImages + (rd32(check.word) ~= 0 and K.CHECKED_IMAGE or K.UNCHECKED_IMAGE) * IMAGE_SIZE
          local picture = rd32(image + 4)
          if rd16(element.item + ITEM_HOVERED) ~= 0 then picture = picture + 1 end
          renderGM(G.textures, rd32(image), picture, offsetX + element.x, offsetY + row.y)
        end
      end
    end
    wr32(G.textures + TEXTURES_MODE, mode)

    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    for _, row in ipairs(rows) do
      local textY = offsetY + row.y + (box - TOOLTIP_LINE) // 2 + 2
      for _, element in ipairs(row) do
        if byItem[element.item] ~= nil then
          write(element.label, offsetX + element.x + box + TOOLTIP_PADDING, textY)
        elseif element.list then
          write(listLabel, offsetX + element.x, textY)
          write(modeName(rd32(H.mode)), element.headX + TOOLTIP_PADDING, textY)
          write("v", offsetX + element.x + element.width - TOOLTIP_PADDING - width("v"), textY)
        elseif element.button then
          write(element.label, offsetX + element.x + TOOLTIP_PADDING, textY)
        else
          write(element.label, offsetX + element.x, textY)
        end
      end
    end
    if H.open then
      for i = 1, options do
        local ot = offsetY + rd32(items.options[i] + ITEM_Y)
        write(K.ROCK_MODES[i][2], offsetX + list.x + TOOLTIP_PADDING, ot + (P.optionHeight - TOOLTIP_LINE) // 2 + 2)
      end
    end
    wr32(G.textLayer, layer)
    drawTooltipOnTop(data)
  end
end

-- The heights menu's new items and the lost rocks button (called while the landscape menu's
-- new table is built; M holds what buildTable has at hand).
function C.heightsMenu(M)
  local G, O, data, added = M.G, M.O, M.data, M.added
  -- Max height: a copy of the min height button with command 22, the next picture and the user
  -- control the iron button took (the iron goes, or, kept, moves to the end of the row).
  if O.maxHeight then
    local into = added.maxHeight
    M.copyOf(K.MIN_HEIGHT_TOOL, into)
    local image = rd32(into + ITEM_IMAGE)
    wr32(into + ITEM_IMAGE, (image & ~IMAGE_INDEX_MASK & 0xFFFFFFFF) | ((image & IMAGE_INDEX_MASK) + 1))
    wr32(into + ITEM_PARAM, K.MAX_HEIGHT_TOOL)
    wr32(into + ITEM_Y, K.MAX_HEIGHT_CONTROL)
    wr32(into + ITEM_TEXT, 0)
    M.tooltips[#M.tooltips + 1] = { item = into, name = K.MAX_HEIGHT_NAME }
    if not (O.noHeightsIron and O.textures) and G.buttons[IRON_COMMAND] ~= nil then
      local row = {}
      for _, param in ipairs(K.HEIGHTS_TOP_ROW) do row[#row + 1] = M.button(param) end
      row[#row + 1] = into
      row[#row + 1] = M.button(IRON_COMMAND)
      M.rows[#M.rows + 1] = row
      M.newButtons[into] = true
    end
  end

  if O.heightTools then
    local H = C.heightWords()
    local items = {
      reset = added.heightReset, breakRocks = added.heightBreak, mode = added.heightMode,
      strength = added.heightStrength, water = added.heightWater, farmland = added.heightFarmland,
      rangeReset = added.heightRangeReset,
      snap = added.heightSnap, invert = added.heightInvert, range = added.heightRange, options = {},
    }
    for i = 1, #K.ROCK_MODES do items.options[i] = added["heightOption" .. i] end
    items.all = {}
    for _, kind in ipairs(K.HEIGHT_PANEL_ITEMS) do items.all[#items.all + 1] = added[kind] end
    for _, address in ipairs(items.options) do items.all[#items.all + 1] = address end
    local function button(address, fn, what)
      wr32(address + ITEM_TYPE, TYPE_CLICKABLE)
      wr32(address + ITEM_ACTION, C.luaPad(fn, what))
      wr32(address + ITEM_RENDER_TYPE, RENDER_NONE)
      wr32(address + ITEM_TEXT, 0)
      wr16(address + ITEM_CONTROL, -1)
      wr16(address + ITEM_HIDDEN, 1)
      M.guarded[#M.guarded + 1] = address
      M.guarded[#M.guarded + 1] = K.HEIGHTS_TAB
    end
    local function flip(word) wr32(word, rd32(word) ~= 0 and 0 or 1) end
    button(items.reset, function() flip(H.reset) end, "the Reset ground textures box")
    button(items.breakRocks, function() flip(H.breakRocks) end, "the Break rock tiles box")
    button(items.water, function() flip(H.ignoreWater) end, "the Ignore water box")
    button(items.farmland, function() flip(H.ignoreFarmland) end, "the Ignore farmland box")
    button(items.snap, function() flip(H.snap) end, "the Snap to range box")
    button(items.invert, function()
      flip(H.invert)
      H.keyInvert = false
    end, "the Invert box")
    button(items.mode, function() H.open = not H.open end, "the rock mode list")
    for i, entry in ipairs(K.ROCK_MODES) do
      button(items.options[i], function()
        wr32(H.mode, entry[1])
        H.open = false
      end, "the rock mode list")
    end
    -- The sliders: a click sets the value under the mouse and starts following the mouse; the
    -- height range moves the nearer handle (a click outside the range: the one on that side).
    button(items.strength, function()
      local tool = rd32(G.subtype)
      if H.strength[tool] == nil then return end
      H.strength[tool] = C.heightPanelValueAt(items.strength, 1, K.STRENGTH_MOST)
      C.applyStrength(H)
      H.drag = "strength"
    end, "the strength slider")
    button(items.rangeReset, function()
      wr32(H.rangeMin, K.HEIGHT_RANGE_DEFAULT[1])
      wr32(H.rangeMax, K.HEIGHT_RANGE_DEFAULT[2])
    end, "the height range Reset button")
    button(items.range, function()
      local value = C.heightPanelValueAt(items.range, 0, 0xFF)
      local low, high = rd32(H.rangeMin), rd32(H.rangeMax)
      if value < low or (value <= high and value - low <= high - value) then
        H.drag = "min"
        wr32(H.rangeMin, math.min(value, high))
      else
        H.drag = "max"
        wr32(H.rangeMax, math.max(value, low))
      end
    end, "the height range slider")
    local R = C.resolvePipette(G)
    local asyncKey = core.exposeCode(core.allocateAssembly(templates.undoKeyState, { IMPORT = R.keyState }), 1, 0)
    local function down(key) return key ~= nil and (asyncKey(key) % 0x10000) >= 0x8000 end
    local function leftHeld() return down(K.LEFT_BUTTON) end
    local panel = added.heightPanel
    local commands = {}
    for _, tool in ipairs(K.HEIGHT_TOOLS) do commands[#commands + 1] = tool end
    commands[#commands + 1] = -1
    wr32(panel + ITEM_TYPE, TYPE_CLICKABLE)    -- no size, so never under the mouse
    wr32(panel + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(panel + ITEM_RENDER, core.allocateAssembly(templates.toolPanel, {
      SUBTYPE = G.subtype, COMMANDS = dwordList(commands), PANEL_ITEMS = dwordList(items.all),
      ITEM_HIDDEN = ITEM_HIDDEN,
      PAD = C.luaPad(C.makeHeightPanel(G, data, H, items, leftHeld), "the heights panel"),
    }))
    -- Every frame something was remembered: the rest of a rock moved in Whole rock; while the
    -- equalize tool is chosen: its invert key (inverts while held, unless Invert is ticked).
    local settle = C.rockSettler(G, R, H)
    local key = O.invertKey ~= nil and keyCode(O.invertKey) or nil
    local tick = added.heightTick
    wr32(tick + ITEM_TYPE, TYPE_EVERY_FRAME)
    wr32(tick + ITEM_ACTION, C.assemble("heightTick", {
      COUNT = H.count, SUBTYPE = G.subtype, EQUALIZE_TOOL = K.EQUALIZE_TOOL,
      PAD = C.luaPad(function()
        if rd32(H.count) ~= 0 then settle() end
        local held = key ~= nil and rd32(G.subtype) == K.EQUALIZE_TOOL and rd32(R.menuGuard) == -1 and down(key)
        if held and not H.keyInvert and rd32(H.invert) == 0 then
          wr32(H.invert, 1)
          H.keyInvert = true
        elseif not held and H.keyInvert then
          wr32(H.invert, 0)
          H.keyInvert = false
        end
      end, "the heights tick"),
    }))
    data.heights = H
  end


  -- The lost rocks button, bottom right of the Rocks menu (both Rocks tabs).
  if O.lostRocks then
    local R = C.resolvePipette(G)
    local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
    local textWidth = core.exposeCode(G.textWidth, 4, 1)
    local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
    local buffer = core.allocate(64, true)
    local B = K.LOST_ROCKS_BUTTON
    local report = "Takes rocks off the map's list that no tile has any more"
    for _, tab in ipairs({ ROCKS, K.ROCKS_SKIRMISH }) do
      local into = added["lostRocks" .. tab]
      if into ~= nil then
        wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
        wr32(into + ITEM_ACTION, C.luaPad(function()
          if O.undo ~= nil then O.undo.beginEdit() end
          local removed = C.removeLostRocks(G, R)
          report = removed == 0 and "No lost rocks on this map"
            or string.format("Removed %d lost rock%s", removed, removed == 1 and "" or "s")
          log(INFO, MODULE_NAME .. ": " .. report)
        end, "the lost rocks button"))
        wr32(into + ITEM_TEXT, 0)
        wr16(into + ITEM_CONTROL, -1)
        wr16(into + ITEM_HIDDEN, 1)
        local buttons = {}
        for _, rock in ipairs(G.rockButtons) do
          if rock.block == tab then buttons[#buttons + 1] = item(M.newTable, M.moved(rock.index)) end
        end
        local box = added["invisible" .. tab]
        M.places[#M.places + 1] = function(measure)
          local right, bottom = nil, nil
          for _, address in ipairs(buttons) do
            local x = rd32(address + ITEM_X)
            if (x & 0xFFFFFFFF) == PLACED_BY_CONTROL then return false end
            local w, h = measure(address)
            if w == nil then return false end
            right = math.max(right or 0, x + w)
            bottom = math.max(bottom or 0, rd32(address + ITEM_Y) + h)
          end
          if right == nil then return true end
          writeCString(buffer, K.LOST_ROCKS_LABEL)
          local w = textWidth(G.textManager, buffer, #K.LOST_ROCKS_LABEL, TOOLTIP_FONT) + 2 * B.padding
          local y = bottom - B.height
          if box ~= nil and rd16(box + ITEM_HIDDEN) == 0 then
            y = math.max(y, rd32(box + ITEM_Y) + K.CHECK_BOX_SIZE + B.below)
          end
          wr32(into + ITEM_X, right + K.CHECK_BOX_GAP)
          wr32(into + ITEM_Y, y)
          wr32(into + ITEM_WIDTH, w)
          wr32(into + ITEM_HEIGHT, B.height)
          wr16(into + ITEM_HIDDEN, 0)
          return true
        end
        -- Drawn in the menu, like the tab numbers.
        wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
        wr32(into + ITEM_RENDER, C.luaPad(function()
          if rd16(into + ITEM_HIDDEN) ~= 0 then return end
          local l = rd32(G.menu + MENU_X) - rd32(G.menu + MENU_SCROLL) + rd32(into + ITEM_X)
          local t = rd32(G.menu + MENU_Y) + rd32(into + ITEM_Y)
          local w = rd32(into + ITEM_WIDTH)
          roundedBox(G.pencil, l, t, l + w, t + B.height, BOX_BLEND)
          if rd16(into + ITEM_HOVERED) ~= 0 then roundedBox(G.pencil, l, t, l + w, t + B.height, BOX_BLEND) end
          writeCString(buffer, K.LOST_ROCKS_LABEL)
          shadowedText(G.textManager, buffer, l + B.padding, t + (B.height - TOOLTIP_LINE) // 2 + 2, ALIGN_LEFT,
            TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
        end, "the lost rocks button"))
        M.tooltips[#M.tooltips + 1] = { item = into, lines = function() return { report } end,
          raise = K.CHECK_BOX_TOOLTIP_RAISE }
      end
    end
  end
end

-- The height tools' patches (with the options on): rocks kept whole or erased, the ground's look
-- only reset when asked, raise and lower without wrapping, the strength.
-- allocateAssembly with every value as an unsigned 32-bit number (core.assemble writes them with
-- %X, so a negative one would not assemble); a failure names the template and its values.
function C.assemble(name, values)
  local clean, listed = {}, {}
  for key, value in pairs(values) do
    clean[key] = value & 0xFFFFFFFF
    listed[#listed + 1] = string.format("%s=0x%X", key, clean[key])
  end
  local ok, result = pcall(core.allocateAssembly, templates[name], clean)
  if not ok then
    table.sort(listed)
    error(string.format("%s: %s (%s)", name, tostring(result), table.concat(listed, " ")))
  end
  return result
end

function C.patchHeightTools(self, G, data)
  local H = data.heights
  local R = C.resolvePipette(G)
  local T = R.tileMap
  local check = C.assemble("rockCheck", {
    ORGANISM = T + R.organism, FIRST_ROCK_NUMBER = K.FIRST_ROCK_NUMBER, ROCK_MODE = H.mode,
    MODE_ERASE = K.ROCK_ERASE, MODE_WHOLE = K.ROCK_WHOLE, RECORD_COUNT = H.count, RECORD_MOST = K.ROCK_RECORDS,
    RECORDS = H.records, BASE_HEIGHT = T + R.defaultHeight, BREAK_ROCKS = H.breakRocks,
    LANDSCAPE = R.landscape, REMOVE_ROCK = R.removeRock,
  })
  local raiseAnd = scan(K.AOB_RAISE_AND, "raiseLand's rock flag")
  local raiseAdd = scan(K.AOB_RAISE_ADD, "raiseLand's amount")
  local levelAnd = scan(K.AOB_LEVEL_AND, "the equalize tool's rock flag")
  local levelRise = scan(K.AOB_LEVEL_RISE, "the equalize tool's step up")
  local levelFall = scan(K.AOB_LEVEL_FALL, "the equalize tool's step down")
  local levelGround = scan(K.AOB_LEVEL_DECORATION, "the equalize tool's ground")
  local plateauAnd = scan(K.AOB_PLATEAU_AND, "the plateau tools' rock flag")
  local plateauGround = scan(K.AOB_PLATEAU_DECORATION, "the plateau tools' ground")
  local minGround = scan(K.AOB_MIN_DECORATION, "the min height tool's ground")
  local minRock = minGround + K.MIN_DECORATION.size
  expectBytes(minRock, { 0xF6, 0x84, 0xAF }, "the min and max height tools' rock")
  local raiseAmount = scan(K.AOB_RAISE_AMOUNT, "the raise land command") + K.AMOUNT_VALUE
  local lowerAmount = scan(K.AOB_LOWER_AMOUNT, "the lower land command") + K.AMOUNT_VALUE
  local raiseRange = scan(K.AOB_RAISE_RANGE, "raiseLand's limits") + K.RAISE_RANGE.site
  local levelRange = scan(K.AOB_LEVEL_RANGE, "the equalize tool's limits") + K.LEVEL_RANGE.site
  local levelAverage = scan(K.AOB_LEVEL_AVERAGE, "the equalize tool's middle height") + K.LEVEL_AVERAGE.site
  local levelEqual = scan(K.AOB_LEVEL_EQUAL, "the equalize tool's step")
  local filter = C.heightFilter(G, data)

  -- Every stub first, so that a failure leaves the game's code as it is.
  local stubs = {}
  stubs[#stubs + 1] = { raiseAnd, K.RAISE_AND.size, C.assemble("raiseRock", {
    ROCK_CHECK = check, LOGIC = rd32(raiseAnd + K.RAISE_AND.logic), BACK = raiseAnd + K.RAISE_AND.size,
  }) }
  stubs[#stubs + 1] = { raiseAdd, K.RAISE_ADD.size, C.assemble("raiseAmount", {
    HEIGHT = rd32(raiseAdd + K.RAISE_ADD.height), DECORATION = rd32(raiseAdd + K.RAISE_ADD.decoration),
    RESET = H.reset, BACK = raiseAdd + K.RAISE_ADD.size,
  }) }
  stubs[#stubs + 1] = { levelAnd, K.LEVEL_AND.size, C.assemble("brushRock", {
    ROCK_CHECK = check, MAY_BREAK = 1, LOGIC = rd32(levelAnd + K.LEVEL_AND.logic), BACK = levelAnd + K.LEVEL_AND.size,
  }) }
  stubs[#stubs + 1] = { levelRise, K.LEVEL_RISE.size, C.assemble("levelRise", {
    DIVISOR = H.divisor, INVERT = H.invert, HEIGHT_STORE = levelRise + K.LEVEL_RISE.store,
  }) }
  stubs[#stubs + 1] = { levelFall, K.LEVEL_FALL.size, C.assemble("levelFall", {
    DIVISOR = H.divisor, INVERT = H.invert, HEIGHT_STORE = levelFall + K.LEVEL_FALL.size,
  }) }
  local RR = K.RAISE_RANGE
  stubs[#stubs + 1] = { raiseRange, RR.size, C.assemble("raiseRange", {
    GAME_LOWEST = rd32(raiseRange + RR.lowest), GAME_HIGHEST = rd32(raiseRange + RR.lowest) + (rd8(raiseRange + RR.highestAdd) & 0xFF),
    SUBTYPE = G.subtype, RAISE_TOOL = K.RAISE_TOOL, LOWER_TOOL = K.LOWER_TOOL, RANGE_MIN = H.rangeMin,
    RANGE_MAX = H.rangeMax, BACK = raiseRange + RR.size,
  }) }
  stubs[#stubs + 1] = { levelRange, K.LEVEL_RANGE.size, C.assemble("levelRange", {
    HEIGHT = rd32(levelRange + K.LEVEL_RANGE.height), RANGE_MIN = H.rangeMin, RANGE_MAX = H.rangeMax,
    BACK = levelRange + K.LEVEL_RANGE.size,
  }) }
  local LA = K.LEVEL_AVERAGE
  stubs[#stubs + 1] = { levelAverage, LA.size, C.assemble("levelAverage", {
    HEIGHT_FILTER = filter, AVERAGE_NEXT = levelAverage - LA.site + LA.next,
    HEIGHT = rd32(levelAverage - LA.site + LA.height), BACK = levelAverage + LA.size,
  }) }
  local LE = K.LEVEL_EQUAL
  stubs[#stubs + 1] = { levelEqual, LE.size, C.assemble("levelEqual", {
    HEIGHT = rd32(levelEqual + LE.height), FALL = levelEqual + LE.size, INVERT = H.invert, NO_STEP = levelEqual + LE.noStep,
    SEED = H.seed, RANDOM_MULTIPLIER = K.RANDOM_MULTIPLIER, RANDOM_INCREMENT = K.RANDOM_INCREMENT,
    STRENGTH_SUM = K.STRENGTH_SUM, DIVISOR = H.divisor, HEIGHT_STORE = levelRise + K.LEVEL_RISE.store,
  }) }
  stubs[#stubs + 1] = { levelGround, K.LEVEL_DECORATION.size, C.assemble("levelGround", {
    RESET = H.reset, DECORATION = rd32(levelGround + K.LEVEL_DECORATION.decoration),
    BACK = levelGround + K.LEVEL_DECORATION.size,
  }) }
  stubs[#stubs + 1] = { plateauAnd, K.PLATEAU_AND.size, C.assemble("brushRock", {
    ROCK_CHECK = check, MAY_BREAK = 0, LOGIC = rd32(plateauAnd + K.PLATEAU_AND.logic),
    BACK = plateauAnd + K.PLATEAU_AND.size,
  }) }
  stubs[#stubs + 1] = { plateauGround, K.PLATEAU_DECORATION.size, C.assemble("plateauGround", {
    RESET = H.reset, DECORATION = rd32(plateauGround + K.PLATEAU_DECORATION.decoration),
    BACK = plateauGround + K.PLATEAU_DECORATION.size,
  }) }
  local minStub = C.assemble("minMaxRock", {
    RESET = H.reset, DECORATION = rd32(minGround + K.MIN_DECORATION.decoration), ROCK_CHECK = check,
    AFTER_AND = minRock + K.MIN_ROCK.afterAnd, AND_SITE = minRock + K.MIN_ROCK.andSite,
  })
  for _, stub in ipairs(stubs) do C.patchJump(self, stub[1], stub[2], stub[3]) end
  -- Min height's `and byte [DECORATION],0xF3` goes: the rock patch resets the look when asked.
  self.saved = self.saved or {}
  table.insert(self.saved, { address = minGround, bytes = core.readBytes(minGround, K.MIN_DECORATION.size) })
  local nops = {}
  for i = 1, K.MIN_DECORATION.size do nops[i] = 0x90 end
  core.writeCode(minGround, nops)
  C.patchJump(self, minRock, K.MIN_ROCK.size, minStub)
  for _, at in ipairs({ raiseAmount, lowerAmount }) do
    table.insert(self.saved, { address = at, bytes = core.readBytes(at, 4) })
  end
  H.raiseAmount, H.lowerAmount = raiseAmount, lowerAmount
  C.applyStrength(H)
end

---------------------------------------------------------------------------------------
-- The texture mask (Textures menu)
---------------------------------------------------------------------------------------

-- The mask's words: on (the check box), the stroke's reference texture (valid, ground flags,
-- look), setLand running inside setTerrain, a saved return address, and a byte per tile for
-- the tiles setLand let through.
function C.maskWords()
  if C.maskState == nil then
    C.maskState = {
      on = core.allocate(4, true), valid = core.allocate(4, true), flags = core.allocate(4, true),
      decoration = core.allocate(4, true), nested = core.allocate(4, true), ret = core.allocate(4, true),
      byType = core.allocate(4, true),
      stamps = core.allocate(K.MAP_TILES, true),
    }
  end
  return C.maskState
end

-- The Mask button, at the top left of the landscape menu's panel (in every one of its menus),
-- and the item that ends a stroke when the mouse button is let go (called while the landscape
-- menu's new table is built).
function C.textureMask(M)
  local G, O, data, added = M.G, M.O, M.data, M.added
  local W = C.maskWords()
  wr32(W.byType, O.maskByType and 1 or 0)
  local R = C.resolvePipette(G)
  local pictures = buttonPictures("mask")
  if G.blit == nil then
    G.blit = core.allocateAssembly(templates.blit, {
      PENCIL = G.pencil, SETUP_SURFACE = G.setupSurface, SETUP_PENCIL = G.setupPencil,
      SCRATCH = core.allocate(32, true), PIXEL_FORMAT = G.pixelFormat,
    })
  end
  for _, box in ipairs({ added.maskButton }) do
    wr32(box + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(box + ITEM_X, K.MASK_BUTTON.x)
    wr32(box + ITEM_Y, K.MASK_BUTTON.y)
    wr32(box + ITEM_WIDTH, pictures.width)
    wr32(box + ITEM_HEIGHT, pictures.height)
    wr32(box + ITEM_ACTION, core.allocateAssembly(templates.flip, { FLAG = W.on }))
    wr32(box + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(box + ITEM_RENDER, core.allocateAssembly(templates.flagPictureButton, {
      NORMAL = pictures.normal, HOVERED = pictures.hover, CHOSEN = pictures.chosen, FLAG = W.on,
      HOVER = G.hover, PENCIL = G.pencil, PENCIL_TARGET = PENCIL_TARGET, ITEM_X = G.itemX, ITEM_Y = G.itemY,
      BLIT = G.blit,
    }))
    wr32(box + ITEM_TEXT, 0)
    wr16(box + ITEM_CONTROL, -1)
    wr16(box + ITEM_HIDDEN, 0)
    M.tooltips[#M.tooltips + 1] = { item = box, lines = function()
      return { "Mask: " .. (rd8(W.on) ~= 0 and "on" or "off"),
        "Paints only tiles with the texture of the tile you start on" }
    end, raise = K.CHECK_BOX_TOOLTIP_RAISE }
  end

  -- The tools it works for, the nature tools: the Heights, Textures, Water, Vegetation and Rocks
  -- menus' (and the module's own: gravel, iron, max height, foam, small waves, the shrubs, the
  -- apple tree) and the pipette (its objects use the game's tools, already in the list).
  local tools = {}
  local blocks = { [K.HEIGHTS_TAB] = true, [TEXTURES] = true, [K.WATER] = true, [VEGETATION] = true,
    [ROCKS] = true, [K.ROCKS_SKIRMISH] = true }
  for param, entry in pairs(G.buttons) do
    if blocks[entry.block] then tools[#tools + 1] = param end
  end
  for _, rock in ipairs(G.rockButtons) do tools[#tools + 1] = rd32(item(G.table, rock.index, ITEM_PARAM)) end
  for _, decoration in ipairs(K.WATER_DECORATIONS) do tools[#tools + 1] = decoration.command end
  for _, command in ipairs(SHRUB_COMMANDS) do tools[#tools + 1] = command end
  for _, command in ipairs({ APPLE_COMMAND, K.MAX_HEIGHT_TOOL, K.PIPETTE_TOOL }) do tools[#tools + 1] = command end
  tools[#tools + 1] = GRAVEL_COMMAND
  tools[#tools + 1] = IRON_COMMAND
  tools[#tools + 1] = -1
  data.mask = { words = W, tools = dwordList(tools) }

  local tick = added.maskTick
  wr32(tick + ITEM_TYPE, TYPE_EVERY_FRAME)
  wr32(tick + ITEM_ACTION, core.allocateAssembly(templates.maskRelease, {
    CLICK_HELD = R.clickHeld, REF_VALID = W.valid,
  }))
end

-- The mask in the texture tools' tile loops (setTerrain and setLand) and around setTerrain's
-- call of setLand.
function C.patchTextureMask(self, G, data)
  local W = data.mask.words
  local R = C.resolvePipette(G)
  local T = R.tileMap
  local terrain = scan(K.AOB_MASK_TERRAIN, "setTerrain's tile loop")
  local land = scan(K.AOB_MASK_LAND, "setLand's tile loop")
  local call = scan(K.AOB_MASK_CALL, "setTerrain's call of setLand") + K.MASK_CALL
  local MT, ML = K.MASK_TERRAIN, K.MASK_LAND
  local check = C.assemble("maskCheck", {
    MASK_ON = W.on, SUBTYPE = G.subtype, TOOLS = data.mask.tools, REF_VALID = W.valid,
    LOGIC = T + rd32(terrain + MT.logic), TEXTURE_FLAGS = K.MASK_FLAGS, REF_FLAGS = W.flags,
    NOT_EARTH = (~K.EARTH) & 0xFFFFFFFF,
    DECORATION = T + K.TMS.decoration, REF_DECORATION = W.decoration, STAMPS = W.stamps, NESTED = W.nested,
    BY_TYPE = W.byType, WATER_FLAGS = K.MASK_WATER,
  })
  data.mask.check = check
  local skip = rd8(terrain + MT.next) & 0xFF
  if skip >= 0x80 then skip = skip - 0x100 end
  C.patchJump(self, terrain, MT.size, core.allocateAssembly(templates.maskTerrain, {
    MASK_CHECK = check, NEXT_TILE = terrain + MT.next + 1 + skip, LOGIC = rd32(terrain + MT.logic),
    BACK = terrain + MT.size,
  }))
  C.patchJump(self, land, ML.size, core.allocateAssembly(templates.maskLand, {
    MASK_CHECK = check, NEXT_TILE = land + ML.next + 4 + rd32(land + ML.next), LOGIC = rd32(land + ML.logic),
    BACK = land + ML.size,
  }))
  C.patchCall(self, call, core.allocateAssembly(templates.maskNested, {
    NESTED = W.nested, RETURN = W.ret, SET_LAND = readCallTarget(call, 0, "setLand"),
  }))

  -- The height tools, trees and rocks: every stub first, then the patches.
  local function nextOf(site, at) return site + at + 4 + rd32(site + at) end
  local stubs = {}
  local tree = scan(K.AOB_MASK_TREE, "placeTree's tile test")
  local TM = K.MASK_TREE
  local loose = data.rocksAndWater or core.allocate(4, true)   -- Vegetation on rocks and water
  stubs[#stubs + 1] = { tree, TM.size, C.assemble("treeMask", {
    MASK_CHECK = check, TREE_LEAVE = nextOf(tree, TM.leave), LOGIC = rd32(tree + TM.logic),
    TEST_MASK = rd32(tree + TM.test), BACK = tree + TM.size, FLAG = loose, GAME_MODE = G.gameMode,
    MAP_EDITOR = K.MAP_EDITOR, LOOSE_MASK = rd32(tree + TM.test) & ~K.TREE_GROUND.loose,
  }) }
  local rock = scan(K.AOB_MASK_ROCK, "placeRock")
  stubs[#stubs + 1] = { rock, K.MASK_ROCK.size, C.assemble("rockMask", {
    MASK_CHECK = check, MAP_SIZE = K.MAP_SIZE, VALID = R.validTiles, ROWS = R.rows, BACK = rock + K.MASK_ROCK.size,
  }) }
  for _, stub in ipairs(stubs) do C.patchJump(self, stub[1], stub[2], stub[3]) end
end

-- The height tools' filter routine (templates.heightFilter), made once: the ignore boxes, the
-- height range, then the mask (or nothing, without it).
function C.heightFilter(G, data)
  if data.heightFilter ~= nil then return data.heightFilter end
  local R = C.resolvePipette(G)
  local T = R.tileMap
  local H = C.heightWords()
  local mask = data.mask ~= nil and data.mask.check or C.assemble("alwaysYes", {})
  data.heightFilter = C.assemble("heightFilter", {
    LOGIC = T + R.logic, IGNORE_WATER = H.ignoreWater, WATER_FLAGS = K.WATER_FLAGS,
    IGNORE_FARMLAND = H.ignoreFarmland, RIVER = K.RIVER_TERRAIN, DECORATION = T + K.TMS.decoration,
    FARMLAND = K.FARMLAND_LOOKS, SUBTYPE = G.subtype, RAISE_TOOL = K.RAISE_TOOL, LOWER_TOOL = K.LOWER_TOOL,
    EQUALIZE_TOOL = K.EQUALIZE_TOOL, INVERT = H.invert, SNAP = H.snap, BASE_HEIGHT = T + R.defaultHeight,
    RANGE_MIN = H.rangeMin, RANGE_MAX = H.rangeMax, MASK_CHECK = mask,
  })
  return data.heightFilter
end

-- The start of each tile in the height tools (raiseLand, useLevelBrush, useTerrainHeightBrush,
-- createPlateau): the next tile when the height filter says no.
function C.patchHeightFilters(self, G, data)
  local filter = C.heightFilter(G, data)
  local function nextOf(site, at) return site + at + 4 + rd32(site + at) end
  local stubs = {}
  local raise = scan(K.AOB_MASK_RAISE, "raiseLand's tile loop")
  local RM = K.MASK_RAISE
  stubs[#stubs + 1] = { raise, RM.size, C.assemble("raiseMask", {
    MASK_CHECK = filter, NEXT_TILE = nextOf(raise, RM.next), LOGIC = rd32(raise + RM.logic), BACK = raise + RM.size,
  }) }
  local B = K.MASK_BRUSH
  local level = scan(K.AOB_MASK_LEVEL, "the equalize tool's tile loop")
  stubs[#stubs + 1] = { level, B.size, C.assemble("levelMask", {
    MASK_CHECK = filter, NEXT_TILE = nextOf(level, B.next), LOGIC = rd32(level + B.logic), BACK = level + B.size,
    TILE_AT = rd8(level + B.tile) & 0xFF, CLICKED_AT = K.MASK_LEVEL_CLICKED,
  }) }
  for _, entry in ipairs({ { K.AOB_MASK_MIN, "the min and max height tools' tile loop" },
      { K.AOB_MASK_PLATEAU, "the plateau tools' tile loop" } }) do
    local at = scan(entry[1], entry[2])
    stubs[#stubs + 1] = { at, B.size, C.assemble("brushMask", {
      MASK_CHECK = filter, NEXT_TILE = nextOf(at, B.next), LOGIC = rd32(at + B.logic), BACK = at + B.size,
      TILE_AT = rd8(at + B.tile) & 0xFF,
    }) }
  end
  for _, stub in ipairs(stubs) do C.patchJump(self, stub[1], stub[2], stub[3]) end
end

-- After the map is drawn, every frame: the tree preview (also while the menu is hidden), and
-- outside the map editor the height tool settings back to their defaults.
function C.patchFrame(self, G, data)
  local R = C.resolvePipette(G)
  local H = C.heightWords()
  local site = scan(K.AOB_FRAME, "the map drawing") + K.FRAME.site
  expectBytes(site, { 0x8B, 0x0D }, "the map drawing")
  local plants = core.allocate(K.PLANT_TOOLS, true)
  local pad = C.assemble("alwaysYes", {})
  -- the building rotation's words (spare ones if the game's orientation cannot be found)
  local okRotation, rotation = pcall(C.rotationState, G)
  if not okRotation then
    rotation = { on = core.allocate(4, true), default = core.allocate(4, true), address = core.allocate(4, true) }
  end
  data.groupOn = core.allocate(4, true)
  local groupPad = pad
  if data.groupWarning ~= nil then
    wr32(data.groupOn, 1)
    groupPad = C.luaPad(data.groupWarning, "the herds and groups line")
  end
  if data.treePreviewDraw ~= nil then
    for command in pairs(G.plantTypes or {}) do
      if command < K.PLANT_TOOLS then core.writeByte(plants + command, 1) end
    end
    pad = C.luaPad(data.treePreviewDraw, "the tree preview")
  end
  C.patchJump(self, site, K.FRAME.size, C.assemble("frameHook", {
    GAME_MODE = R.gameMode, MAP_EDITOR = K.MAP_EDITOR, RANGE_MIN = H.rangeMin, RANGE_MAX = H.rangeMax,
    DEFAULT_MIN = K.HEIGHT_RANGE_DEFAULT[1], DEFAULT_MAX = K.HEIGHT_RANGE_DEFAULT[2], SNAP = H.snap,
    INVERT = H.invert, IGNORE_WATER = H.ignoreWater, IGNORE_FARMLAND = H.ignoreFarmland, SUBTYPE = G.subtype,
    PLANT_TOOLS = K.PLANT_TOOLS, PLANTS = plants, PAD = pad, OPERAND = rd32(site + 2), BACK = site + K.FRAME.size,
    GROUP_ON = data.groupOn, FIRST_GROUP = G.firstGroup, GROUP_SLOTS = G.groupSlots, GROUP_SIZE = G.groupSize,
    GROUP_COUNT = data.groupCount or data.groupOn, GROUP_MARGIN = K.GROUP_MARGIN, GROUP_PAD = groupPad,
    ROTATION_ON = rotation.on, ROTATION_DEFAULT = rotation.default, ORIENTATION = rotation.address,
  }))
  C.frameHooked = true
  -- The menu's own drawing of the preview is no longer needed.
  if data.treePreviewItem ~= nil then wr32(data.treePreviewItem + ITEM_RENDER_TYPE, RENDER_NONE) end
end

-- Whether the mask would let a tile be changed, without starting a stroke (for previews).
-- What the mask compares for a tile's flags (maskCheck's mask_kind): its ground flags.
function C.maskKind(W, logic)
  local kind = logic & K.MASK_FLAGS & 0xFFFFFFFF
  if rd32(W.byType) ~= 0 and kind & K.MASK_WATER ~= 0 then kind = kind & ~K.EARTH & 0xFFFFFFFF end
  return kind
end

function C.maskPeek(T, R, tile)
  local W = C.maskState
  if W == nil or rd8(W.on) == 0 or rd32(W.valid) == 0 then return true end
  if C.maskKind(W, rd32(T + R.logic + tile * 4)) ~= (rd32(W.flags) & 0xFFFFFFFF) then return false end
  return C.waterAlike(W) or (rd8(T + K.TMS.decoration + tile) & 0xFF) == (rd32(W.decoration) & 0xFF)
end

-- The mask for lua that paints tiles (the pipette): answers whether tile may change, taking the
-- reference from clicked when a stroke starts, like maskCheck.
function C.maskAllows(T, R, tile, clicked)
  local W = C.maskState
  if W == nil or rd8(W.on) == 0 then return true end
  local function look(at)
    return C.maskKind(W, rd32(T + R.logic + at * 4)), rd8(T + K.TMS.decoration + at) & 0xFF
  end
  if rd32(W.valid) == 0 then
    local flags, decoration = look(clicked)
    wr32(W.flags, flags)
    wr32(W.decoration, decoration)
    wr32(W.valid, 1)
  end
  local flags, decoration = look(tile)
  return flags == (rd32(W.flags) & 0xFFFFFFFF)
    and (C.waterAlike(W) or decoration == (rd32(W.decoration) & 0xFF))
end

-- Water variants count as one: the setting is on and the stroke's reference is sea, river or ford.
function C.waterAlike(W)
  return rd32(W.byType) ~= 0 and (rd32(W.flags) & K.MASK_WATER) ~= 0
end

---------------------------------------------------------------------------------------
-- Constants of 36-39
---------------------------------------------------------------------------------------

-- The unit limit the editor really has (the "N more units" line computes 2499 / 9999 - count;
-- K.AOB_UNITS' test, 2300 / 9800, is only where that line starts).
K.AOB_UNIT_MAX = "8D 44 38 06 B9 ? ? ? ? 2B 0D"
K.UNIT_MAX = 5
K.GROUP_MARGIN = 200                     -- the herds and groups line from fewer than this left
K.GROUP_WARNING_Y, K.GROUP_WARNING_BELOW = 10, 30
-- Crows: markNearbyTreesAsCrowTargets (esi = a tree's stage word, its in-use word at -0x3C) sets
-- `mov word [esi+0x14], 1`: the crow word, 0x50 after the in-use word; the word after it says
-- the crows flew off.
K.AOB_CROW_MARK = "66 83 7E C4 02 75 ? 83 3E 04 7D"
K.CROW_MARK_IN_USE = 0x3C
K.TREE_CROW = 0x50
K.CROW_TOOL, K.GULL_TOOL = 224, 225
-- deleteAllSeagulls (VAN 0x404A70): `cmp word [eax + state], 2 / cmp word [eax + kind], 0x1D /
-- push ecx / mov ecx, entityState / call deleteEntity`, entity count at +0x42.
K.AOB_DELETE_GULLS = "B9 01 00 00 00 56 89 0D ? ? ? ? BE 02 00 00 00 8B C1 69 C0 E8 00 00 00 66 39 B0 ? ? ? ? "
  .. "75 1B 66 83 B8 ? ? ? ? 1D 75 11 51 B9 ? ? ? ? E8"
K.DELETE_GULLS = { state = 28, kind = 37, entities = 46, delete = 50, limit = 0x40 }
-- createSeagull: `mov ebx, 1 / lea esi, [edi + slot 1]`, `cmp ebx, 0x64` ends the slots.
K.AOB_NEW_GULL = "BB 01 00 00 00 8D B7 ? ? ? ? 66 83 7E 08 00 74"
K.NEW_GULL = { first = 7, limit = 0x42 }
K.ENTITY = { size = 0xE8, state = 0x28, kind = 0x2A, uid = 0x30, tile = 0x4C }
K.GULL = { size = 0x64, uid = 4, state = 8 }
K.ENTITY_ALIVE, K.CROW_ENTITY = 2, 0x1C
-- Alt + E in the map editor: `mov ecx, units / call deleteAllAnimals`.
K.AOB_DELETE_ANIMALS = "83 F8 11 74 1A 83 F8 0C 74 15 83 F8 0E 0F 85 ? ? ? ? 39 2D ? ? ? ? 0F 85 ? ? ? ? B9 ? ? ? ? E8"
K.DELETE_ANIMALS = { units = 0x20, call = 0x24 }
K.BIN_GAP = 4
K.ANIMAL_BIN_X = 612

-- The eraser (button and tool 39) and what it may take.
K.ERASER_TOOL = 39
K.ERASE_ALL, K.ERASE_ANIMALS, K.ERASE_UNITS, K.ERASE_BUILDINGS, K.ERASE_PLANTS, K.ERASE_ROCKS = 0, 1, 2, 3, 4, 5
K.ERASER_MODES = {                       -- in the order of the numbers above
  { label = "All" }, { label = "Animals", tab = 235 }, { label = "Units", build = 26 },
  { label = "Buildings", build = 30 }, { label = "Vegetation", tab = 234 }, { label = "Rocks", tab = 237 },
}
K.ERASER_ENTRY_WIDTH = 72
K.PANEL_PICTURE_GAP = 2
K.ROCK_ORGANISM_FIRST = 2000
K.ERASE_ORGANISM_BEFORE = 12             -- movsx eax, word [esi + reg*2 + organisms] / test / je
-- The second loop: `mov dword [esi + wall found], 0 / call findBuildingOrWallAt / cmp [blocked], 0
-- / jne / cmp [wall found], 0 / jne / mov eax, [building found] / cmp eax, -1`.
K.AOB_ERASE_BUILDING = "C7 86 ? ? ? ? 00 00 00 00 E8 ? ? ? ? 83 BE ? ? ? ? 00 0F 85 ? ? ? ? 83 BE ? ? ? ? 00 "
  .. "0F 85 ? ? ? ? 8B 86 ? ? ? ? 83 F8 FF"
K.ERASE_BUILDING = { call = 10, blocked = 17, wall = 30, building = 43 }
-- The third loop: `mov word [eax + state], 3 / movsx eax, word [eax + next on tile]`; the tile's
-- first unit is read 0x12 (brush) or 0x18 (area) bytes before.
K.AOB_ERASE_UNIT = "66 C7 80 ? ? ? ? 03 00 0F BF 80 ? ? ? ? 85 C0 75 E6"
K.ERASE_UNIT = { state = 3, size = 9, mapBack = { 0x12, 0x18 } }
K.UNIT_TYPE_AFTER_STATE = 2
K.ANIMAL_TYPES = 128
-- Deer, lion, rabbit, camel, crow, seagull, cow, chicken and the burning animals.
K.ANIMAL_UNIT_TYPES = { 44, 45, 46, 47, 48, 49, 51, 62, 68, 69 }

-- The Vegetation menu's trees by what they spread on: the first three on fertile ground, the
-- fourth on infertile ground (39).
K.SPREAD_TREES = { 41, 42, 43, 40 }
K.SPREAD_FERTILE = { [41] = true, [42] = true, [43] = true }
K.SPREAD_COLOURS = { fertile = { 72, 184, 56 }, infertile = { 226, 204, 152 } }

-- Map settings: the Alt + , menu (modal 0x1F, 400 x 300; group: Single 0xA, Multi 0xB, sizes
-- 0x14-0x17; its action also still knows the lock states 0-2 and the map types 3-6, its renderer
-- their labels and King of the Hill 0xC).
K.AOB_SETTINGS_MODAL = "68 ? ? ? ? 68 ? ? ? ? 50 68 00 02 00 00 68 ? ? ? ? 68 ? ? ? ? 6A FF 6A FF 6A 1F B9"
K.SETTINGS_MODAL = { menu = 1, height = 17, width = 22, record = 33 }
K.SETTINGS_MODAL_ID = 0x1F
K.MODAL_WIDTH, K.MODAL_HEIGHT = 0x0C, 0x10
K.AOB_SETTINGS_TABLE = "03 00 00 02 19 00 00 00 14 00 00 00 96 00 00 00 1B 00 00 00 00 00 00 00 0A 00 00 00"
K.SETTINGS_ITEMS = 7
K.SETTINGS_HOVER = { 1, { 0x8B, 0x1D } }   -- push ebx / mov ebx, [hover]
K.RECT_BEFORE_HOVER = 0x10
K.SETTINGS_RENDER_SIZE = 0x200
K.AOB_BUTTON_BACKGROUND = "6A FF 6A 00 B9 ? ? ? ? E8"
K.BUTTON_BACKGROUND = { this = 5, call = 9 }
K.AOB_BUTTON_TEXT = "B9 ? ? ? ? E8 ? ? ? ? 5F 5E 5B C3"
K.AOB_SETTINGS_LABELS = "B9 ? ? ? ? EB 2F B9 ? ? ? ? EB 28 B9 ? ? ? ? EB 21 B9"
K.SETTINGS_LABELS = { single = 8, multi = 15 }
K.AOB_SETTINGS_KOTH = "83 FE 0C 75 18 83 3D ? ? ? ? 00 0F 84 ? ? ? ? 83 3D ? ? ? ? 00 74"
K.SETTINGS_KOTH = { multi = 7, koth = 20 }
K.AOB_BALANCED = "39 0D ? ? ? ? 89 0D ? ? ? ? 75 05 83 FE FD"
K.BALANCED = 2
K.AOB_SETTINGS_ACTION = "83 FE 17 77 14 0F B6 86 ? ? ? ? FF 24 85 ? ? ? ? 89 35 ? ? ? ? 5E C3"
K.SETTINGS_LOCK = 21
K.MAP_LOCKED = 2                         -- "Mission": locked, still in the skirmish map list
K.AOB_SETTINGS_SIZE = "B8 90 01 00 00 74 04 8B 44 24 08 50 B9 ? ? ? ? A3 ? ? ? ?"
K.SETTINGS_SIZE_VAR = 18
K.AOB_SETTINGS_SIZE_ENTRY = "B9 ? ? ? ? E8 ? ? ? ? 83 FE 14 75 07 B8 A0 00 00 00"
K.AOB_ALT_COMMA = "83 3D ? ? ? ? 11 0F 85 ? ? ? ? A1 ? ? ? ? 83 F8 1F 75 13 6A 00 6A FF B9 ? ? ? ? E8"
K.ALT_COMMA = { screen = 2, modal = 14, manager = 28, open = 32 }
K.OPENER_STATE = 0x18                    -- the modal opener's `mov ecx, list state`
K.MAP_TYPE_PARAMS = { 3, 4, 5, 6 }       -- Siege, Invasion, Economic, Just Build
K.MAP_SIZE_PARAMS = { 0x14, 0x15, 0x16, 0x17 }
K.MAP_SIZES = { 160, 200, 300, 400 }
K.MAP_SIZE_RANGE = { 10, 400 }
K.SETTINGS_SIZE = { width = 560, height = 410 }
K.SETTINGS_LAYOUT = {
  title = { y = 12 },
  single = { x = 30, y = 44, width = 240 }, multi = { x = 290, y = 44, width = 240 },
  types = { { x = 50, y = 88, width = 200 }, { x = 50, y = 118, width = 200 }, { x = 50, y = 148, width = 200 },
    { x = 50, y = 178, width = 200 } },
  sizes = { { x = 310, y = 88, width = 200 }, { x = 310, y = 118, width = 200 }, { x = 310, y = 148, width = 200 },
    { x = 310, y = 178, width = 200 } },
  custom = { x = 310, y = 208, width = 200 },
  slider = { x = 310, y = 250, width = 200 },
  balanced = { x = 50, y = 222, width = 200 }, koth = { x = 50, y = 252, width = 200 },
  lock = { x = 180, y = 300, width = 200 },
  back = { x = 180, y = 362, width = 200 },
}
K.SLIDER_INSET = 6
K.TITLE_FONT, K.BUTTON_FONT = 0x13, 0x11
K.TEXT_NORMAL, K.TEXT_HOVERED = 0xC2F0EB, 0xCCFAFF
K.BUTTON_TEXT_DOWN = 4
K.CHECK_INSET, K.CHECK_SIZE = 7, 13
-- The map menu (MapEditorProperties) table, found by its Balanced button (item 10); the Map
-- Settings button goes right of Balanced / Unbalanced and Invasion / Economy.
K.AOB_PROPERTIES_TABLE = "03 00 00 02 F0 00 00 00 EA 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 FD FF FF FF "
  .. "00 00 00 00 06 02 00 40 03 00 00 00"
K.PROPERTIES_ITEM = 10
K.SETTINGS_BUTTON = { x = 390, y = 492, width = 160, height = 27 }
K.MOST_DIALOG_ITEMS = 200
-- Locked maps: mapNames_filterMapsIfMapLock's `cmp dword [lock], 0 / jne DROP`.
K.AOB_LOCK_FILTER = "83 3D ? ? ? ? 00 75 0E 53 56 8B CF E8"
K.LOCK_FILTER = { size = 9, jump = 7 }
K.AOB_LOAD_MODAL = "68 ? ? ? ? 68 ? ? ? ? 50 68 00 02 00 00 68 8D 01 00 00 68 BC 02 00 00 6A FF 6A FF 6A 09 B9"
K.AOB_MAP_OPENER = "55 56 57 8B F1 C7 05 ? ? ? ? 01 00 00 00 E8 ? ? ? ? 68 80 38 01 00 33 FF 57 68 ? ? ? ? E8 "
  .. "? ? ? ? 83 C4 0C 68"
K.MAP_LIST_KIND = 2
K.LOCKED_TOGGLE = { x = 55, y = 64, width = 200, height = 27 }

---------------------------------------------------------------------------------------
-- Birds, the animal buttons, the eraser's choice, the tree outlines (36, 37, 39)
---------------------------------------------------------------------------------------

-- Birds. Crows are no list of their own: the crow tool marks the grown trees near the click
-- (markNearbyTreesAsCrowTargets sets a word of the tree, K.TREE_CROW from its in-use word; the
-- word after it says the crows flew off). Seagulls are entities of type 0x1D with a slot each in
-- the entity state's seagull list (99 slots, 1..99; slot +0 entity, +4 its uid, +8 in use).
-- deleteAllSeagulls (the game's own, unused in the editor) deletes them all.
function C.resolveBirds(G)
  if C.birds ~= nil then return C.birds end
  local D = {}
  local mark = scan(K.AOB_CROW_MARK, "the crow tool")
  local found = false
  for at = mark, mark + 0x40 do
    if rd8(at) & 0xFF == 0x66 and rd8(at + 1) & 0xFF == 0xC7 and rd8(at + 2) & 0xFF == 0x46 then
      found = (rd8(at + 3) & 0xFF) + K.CROW_MARK_IN_USE == K.TREE_CROW
      break
    end
  end
  if not found then error(MODULE_NAME .. ": the crow tool is not the one this module knows") end
  local del = scan(K.AOB_DELETE_GULLS, "the seagull removal")
  local d = K.DELETE_GULLS
  D.deleteAllGulls = del
  D.entities = rd32(del + d.entities)
  D.entityZero = rd32(del + d.state) - K.ENTITY.state
  if rd32(del + d.kind) ~= D.entityZero + K.ENTITY.kind then
    error(MODULE_NAME .. ": the entity list is not laid out as the module expects")
  end
  D.deleteEntity = readCallTarget(del, d.delete, "deleteEntity")
  expectBytes(del + d.limit, { 0x81, 0xF9 }, "the seagull removal")
  D.entitySlots = rd32(del + d.limit + 2)
  local new = scan(K.AOB_NEW_GULL, "the seagull placement")
  D.firstGull = D.entities + rd32(new + K.NEW_GULL.first)
  expectBytes(new + K.NEW_GULL.limit, { 0x83, 0xFB }, "the seagull placement")
  D.gullSlots = rd8(new + K.NEW_GULL.limit + 2) & 0xFF        -- slots 1 .. gullSlots - 1
  local alt = scan(K.AOB_DELETE_ANIMALS, "Alt + E")
  D.units = rd32(alt + K.DELETE_ANIMALS.units)
  D.deleteAnimals = readCallTarget(alt, K.DELETE_ANIMALS.call, "the animal removal")
  C.birds = D
  return D
end

function C.birdCounts(G, D)
  local crows, gulls = 0, 0
  for i = 0, G.treeSlots - 1 do
    local tree = G.firstTree + i * G.treeSize
    if rd16(tree) ~= 0 and rd16(tree + K.TREE_CROW) ~= 0 then crows = crows + 1 end
  end
  for i = 1, D.gullSlots - 1 do
    if rd16(D.firstGull + (i - 1) * K.GULL.size + K.GULL.state) ~= 0 then gulls = gulls + 1 end
  end
  return crows, gulls
end

-- The Animals menu's wastebins: erase all crows and all seagulls (right of their buttons), and
-- all animals (the menu's right side; the game's own Alt + E).
function C.animalsMenu(M)
  local G, O, data, added = M.G, M.O, M.data, M.added
  local D = C.resolveBirds(G)
  local pictures = buttonPictures("bin")
  local never = core.allocate(4, true)
  if G.blit == nil then
    G.blit = core.allocateAssembly(templates.blit, {
      PENCIL = G.pencil, SETUP_SURFACE = G.setupSurface, SETUP_PENCIL = G.setupPencil,
      SCRATCH = core.allocate(32, true), PIXEL_FORMAT = G.pixelFormat,
    })
  end
  local render = core.allocateAssembly(templates.flagPictureButton, {
    NORMAL = pictures.normal, HOVERED = pictures.hover, CHOSEN = pictures.chosen, FLAG = never,
    HOVER = G.hover, PENCIL = G.pencil, PENCIL_TARGET = PENCIL_TARGET, ITEM_X = G.itemX, ITEM_Y = G.itemY,
    BLIT = G.blit,
  })
  local deleteEntity = core.exposeCode(D.deleteEntity, 2, 1)
  local deleteAllGulls = core.exposeCode(D.deleteAllGulls, 0, 0)
  local deleteAnimals = core.exposeCode(D.deleteAnimals, 1, 1)
  local function eraseCrows()
    for i = 0, G.treeSlots - 1 do
      local tree = G.firstTree + i * G.treeSize
      if rd16(tree) ~= 0 then
        wr16(tree + K.TREE_CROW, 0)
        wr16(tree + K.TREE_CROW + 2, 0)
      end
    end
    for id = 1, D.entitySlots - 1 do                 -- crows already in the air
      local entity = D.entityZero + id * K.ENTITY.size
      if rd16(entity + K.ENTITY.state) == K.ENTITY_ALIVE and rd16(entity + K.ENTITY.kind) == K.CROW_ENTITY then
        deleteEntity(D.entities, id)
      end
    end
  end
  local bins = {}
  if O.birdButtons then
    bins[#bins + 1] = { item = added.crowBin, beside = K.CROW_TOOL, fn = eraseCrows, text = "Erase all crows" }
    bins[#bins + 1] = { item = added.gullBin, beside = K.GULL_TOOL, fn = function() deleteAllGulls() end,
      text = "Erase all seagulls" }
  end
  if O.animalBin then
    bins[#bins + 1] = { item = added.animalBin, fn = function() deleteAnimals(D.units) end,
      text = "Erase all animals (Alt + E)" }
  end
  for _, bin in ipairs(bins) do
    local into = bin.item
    wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(into + ITEM_X, 0)
    wr32(into + ITEM_Y, 0)
    wr32(into + ITEM_WIDTH, pictures.width)
    wr32(into + ITEM_HEIGHT, pictures.height)
    wr32(into + ITEM_ACTION, C.luaPad(bin.fn, bin.text))
    wr32(into + ITEM_RENDER, render)
    wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(into + ITEM_TEXT, 0)
    wr16(into + ITEM_CONTROL, -1)
    wr16(into + ITEM_HIDDEN, 1)
    M.guarded[#M.guarded + 1] = into
    M.guarded[#M.guarded + 1] = ANIMALS
    M.tooltips[#M.tooltips + 1] = { item = into, lines = function() return { bin.text } end,
      raise = K.CHECK_BOX_TOOLTIP_RAISE }
  end
  -- Placed once the menu has placed the buttons: a bird's bin right of its button, the animals'
  -- bin at the menu's right, level with the deer.
  M.places[#M.places + 1] = function()
    local rightmost = 0
    for _, param in ipairs({ DEER, K.CROW_TOOL, K.GULL_TOOL }) do
      if (rd32(M.button(param) + ITEM_X) & 0xFFFFFFFF) == PLACED_BY_CONTROL then return false end
    end
    for _, bin in ipairs(bins) do
      local model = M.button(bin.beside or DEER)
      local x = K.ANIMAL_BIN_X
      if bin.beside ~= nil then
        x = rd32(model + ITEM_X) + rd32(model + ITEM_WIDTH) + K.BIN_GAP
        rightmost = math.max(rightmost, x + pictures.width)
      else
        x = math.max(x, rightmost + 3 * K.BIN_GAP)
      end
      wr32(bin.item + ITEM_X, x)
      wr32(bin.item + ITEM_Y, rd32(model + ITEM_Y) + (rd32(model + ITEM_HEIGHT) - pictures.height) // 2)
      wr16(bin.item + ITEM_HIDDEN, 0)
    end
    return true
  end
end

-- The eraser's choice (37.2): one word, K.ERASE_ALL .. K.ERASE_ROCKS.
function C.eraserWords()
  if C.eraser ~= nil then return C.eraser end
  C.eraser = { mode = core.allocate(4, true) }
  return C.eraser
end

-- The panel above the menu while the eraser is chosen: All, Animals, Units, Buildings,
-- Vegetation, Rocks, each the eraser's picture with the menu picture of what it takes.
function C.eraserMenu(M)
  local G, data, added = M.G, M.data, M.added
  local E = C.eraserWords()
  local eraser = G.buttons[K.ERASER_TOOL]
  if eraser == nil then error(MODULE_NAME .. ": the eraser button is missing") end
  local eraserImage = rd32(item(G.table, eraser.index, ITEM_IMAGE)) & IMAGE_INDEX_MASK
  local B = nil
  local ok = pcall(function() B = C.resolve(G) end)
  if not ok then B = nil end
  local function imageOf(mode)
    if mode.tab ~= nil and G.buttons[mode.tab] ~= nil then
      return rd32(item(G.table, G.buttons[mode.tab].index, ITEM_IMAGE)) & IMAGE_INDEX_MASK
    end
    if mode.build ~= nil and B ~= nil and B.buttons[0] ~= nil and B.buttons[0][mode.build] ~= nil then
      return B.buttons[0][mode.build].image
    end
    return nil
  end
  local panel = { items = {}, info = added.info }
  local entries = {}
  for i, mode in ipairs(K.ERASER_MODES) do
    local into = added["eraserMode" .. i]
    wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(into + ITEM_ACTION, C.luaPad(function() wr32(E.mode, i - 1) end, "the eraser panel"))
    wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
    wr16(into + ITEM_HIDDEN, 1)
    panel.items[i] = into
    M.guarded[#M.guarded + 1] = into
    M.guarded[#M.guarded + 1] = 0
    entries[i] = { item = into, label = mode.label, image = eraserImage, image2 = imageOf(mode) }
  end
  local paint = makePanel(G, { counts = false }, data, panel, function(subtype)
    if subtype ~= K.ERASER_TOOL then return {} end
    local list = {}
    for i, entry in ipairs(entries) do
      list[i] = { item = entry.item, image = entry.image, image2 = entry.image2, label = entry.label,
        chosen = rd32(E.mode) == i - 1, minWidth = K.ERASER_ENTRY_WIDTH }
    end
    list.labelRoom = K.PIPETTE_LABEL_ROOM
    return list
  end)
  local into = added.eraserPanel
  wr32(into + ITEM_TYPE, TYPE_CLICKABLE)       -- no size, so never under the mouse
  wr32(into + ITEM_RENDER, C.luaPad(paint, "the eraser panel"))
  wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
end

-- The eraser follows the choice: all three of its loops, in both of its functions (the brush
-- and the area version), and with All or Animals it takes seagulls too.
function C.patchEraserChoice(self, G, choice, gulls)
  pcall(C.eraseTables)                     -- before this patch hides them from the search
  local E = C.eraserWords()
  local D = C.resolveBirds(G)
  local sites = C.eraseSites()
  local buildings, units = {}, {}
  local from = 0x400000
  while #buildings <= K.ERASE_SITES do
    local ok, found = pcall(core.scanForAOB, K.AOB_ERASE_BUILDING, from, K.HERD_SEARCH_END)
    if not ok or found == nil or found == 0 then break end
    buildings[#buildings + 1] = found
    from = found + 1
  end
  from = 0x400000
  while #units <= K.ERASE_SITES do
    local ok, found = pcall(core.scanForAOB, K.AOB_ERASE_UNIT, from, K.HERD_SEARCH_END)
    if not ok or found == nil or found == 0 then break end
    units[#units + 1] = found
    from = found + 1
  end
  if #buildings ~= K.ERASE_SITES or #units ~= K.ERASE_SITES then
    error(MODULE_NAME .. ": the eraser is not the one this module knows")
  end
  local animals = {}
  for i = 1, K.ANIMAL_TYPES do animals[i] = 0 end
  for _, kind in ipairs(K.ANIMAL_UNIT_TYPES) do animals[kind + 1] = 1 end
  local animalTable = core.allocate(K.ANIMAL_TYPES, true)
  core.writeBytes(animalTable, animals)
  local modes = { MODE = E.mode, MODE_ALL = K.ERASE_ALL, MODE_ANIMALS = K.ERASE_ANIMALS, MODE_UNITS = K.ERASE_UNITS,
    MODE_BUILDINGS = K.ERASE_BUILDINGS, MODE_PLANTS = K.ERASE_PLANTS, MODE_ROCKS = K.ERASE_ROCKS }
  local function with(values)
    for k, v in pairs(modes) do values[k] = v end
    return values
  end
  -- Assembled first, patched after: all or nothing.
  local patches = {}
  for _, found in ipairs(sites) do
    local site = found - K.ERASE_ORGANISM_BEFORE
    expectBytes(site, { 0x0F, 0xBF, 0x84 }, "the eraser's first loop")
    if choice then
      patches[#patches + 1] = { site = site, size = 8, stub = C.assemble("eraseOrganism", with({
        ORIG_LO = rd32(site), ORIG_HI = rd32(site + 4), ROCK_FIRST = K.ROCK_ORGANISM_FIRST,
        TREE_SIZE = G.treeSize, CROW_BASE = G.firstTree - G.treeSize + K.TREE_CROW, BACK = site + 8,
      })) }
    end
  end
  for _, found in ipairs(buildings) do
    local b = K.ERASE_BUILDING
    local site = found + b.call
    if choice then
      patches[#patches + 1] = { call = true, site = site, stub = C.assemble("eraseBuilding", with({
        WALL_FOUND = rd32(found + b.wall), BLOCKED = rd32(found + b.blocked), BUILDING_FOUND = rd32(found + b.building),
        FIND = readCallTarget(site, 0, "the eraser's building search"),
      })) }
    end
  end
  for _, found in ipairs(units) do
    local u = K.ERASE_UNIT
    if choice then
      patches[#patches + 1] = { site = found, size = u.size, stub = C.assemble("eraseUnit", with({
        STATE = rd32(found + u.state), UNIT_TYPE = rd32(found + u.state) + K.UNIT_TYPE_AFTER_STATE,
        ANIMAL_TYPES = K.ANIMAL_TYPES, ANIMALS = animalTable, BACK = found + u.size,
      })) }
    end
    if gulls then
      local site = nil
      for _, back in ipairs(u.mapBack) do
        if rd8(found - back) & 0xFF == 0x0F and rd8(found - back + 1) & 0xFF == 0xBF
            and rd8(found - back + 2) & 0xFF == 0x04 then
          site = found - back
        end
      end
      if site == nil then error(MODULE_NAME .. ": the eraser's unit loop is not the one this module knows") end
      patches[#patches + 1] = { site = site, size = 8, stub = C.assemble("eraseGulls", with({
        ORIG_LO = rd32(site), ORIG_HI = rd32(site + 4), FIRST_GULL = D.firstGull, GULL_STATE = K.GULL.state,
        GULL_UID = K.GULL.uid, GULL_SIZE = K.GULL.size, GULL_SLOTS = D.gullSlots, ENTITY_SLOTS = D.entitySlots,
        ENTITY_SIZE = K.ENTITY.size, ENTITY_ZERO = D.entityZero, ENTITY_UID = K.ENTITY.uid,
        ENTITY_TILE = K.ENTITY.tile, ENTITY_STATE = D.entities, DELETE_ENTITY = D.deleteEntity, BACK = site + 8,
      })) }
    end
  end
  for _, patch in ipairs(patches) do
    if patch.call then C.patchCall(self, patch.site, patch.stub) else patchJump(self, patch.site, patch.size, patch.stub) end
  end
end

-- Thin outlines around the Vegetation menu's trees (39.2): green round the ones that spread on
-- fertile ground (grass, scrub), beige round the one that spreads on infertile ground.
function C.spreadOutlines(M)
  local G, added = M.G, M.added
  local colourBox = core.exposeCode(G.colourBox, 6, 1)
  local outlined = {}
  for _, param in ipairs(K.SPREAD_TREES) do
    outlined[#outlined + 1] = { item = M.button(param), fertile = K.SPREAD_FERTILE[param] == true }
  end
  local function pack(rgb)
    if rd32(G.pixelFormat) == 0x565 then
      return ((rgb[1] >> 3) << 11) | ((rgb[2] >> 2) << 5) | (rgb[3] >> 3)
    end
    return ((rgb[1] >> 3) << 10) | ((rgb[2] >> 3) << 5) | (rgb[3] >> 3)
  end
  local into = added.spreadOutline
  wr32(into + ITEM_TYPE, TYPE_CLICKABLE)       -- no size, so never under the mouse
  wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  wr32(into + ITEM_RENDER, C.luaPad(function()
    local menuX = rd32(G.menu + MENU_X) - rd32(G.menu + MENU_SCROLL)
    local menuY = rd32(G.menu + MENU_Y)
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, 0)
    for _, entry in ipairs(outlined) do
      local button = entry.item
      if rd16(button + ITEM_HIDDEN) == 0 and (rd32(button + ITEM_X) & 0xFFFFFFFF) ~= PLACED_BY_CONTROL then
        local colour = pack(entry.fertile and K.SPREAD_COLOURS.fertile or K.SPREAD_COLOURS.infertile)
        local l, t = menuX + rd32(button + ITEM_X) - 1, menuY + rd32(button + ITEM_Y) - 1
        local r, b = l + rd32(button + ITEM_WIDTH) + 2, t + rd32(button + ITEM_HEIGHT) + 2
        colourBox(G.pencil, l, t, r, t + 1, colour)
        colourBox(G.pencil, l, b - 1, r, b, colour)
        colourBox(G.pencil, l, t, l + 1, b, colour)
        colourBox(G.pencil, r - 1, t, r, b, colour)
      end
    end
    wr32(G.pencil + PENCIL_TARGET, target)
  end, "the tree outlines"))
end

-- The line at the top of the screen once fewer than K.GROUP_MARGIN herds and groups can still be
-- made (36.3), drawn from the frame hook (also with the menu hidden). It sits below the game's
-- own unit line when that one shows.
function C.groupWarning(G, data)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local buffer = core.allocate(96, true)
  data.groupCount = core.allocate(4, true)
  return function()
    local left = G.groupSlots - rd32(data.groupCount)
    local text = string.format("You can only make %d more herds and groups", math.max(left, 0))
    writeCString(buffer, text)
    local width = textWidth(G.textManager, buffer, #text, TOOLTIP_FONT)
    local x = (rd32(G.screenWidth) - width) // 2 + rd32(G.cameraX)
    local y = K.GROUP_WARNING_Y + (rd32(G.units) >= G.unitLimit and K.GROUP_WARNING_BELOW or 0) + rd32(G.cameraY)
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    roundedBox(G.pencil, x - TOOLTIP_PADDING, y, x + width + TOOLTIP_PADDING, y + TOOLTIP_LINE + TOOLTIP_PADDING,
      BOX_BLEND)
    wr32(G.pencil + PENCIL_TARGET, target)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    shadowedText(G.textManager, buffer, x, y + TOOLTIP_PADDING // 2, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    wr32(G.textLayer, layer)
  end
end

---------------------------------------------------------------------------------------
-- Map settings (38): locked maps in the Load dialog, the map menu's Map Settings button and the
-- Alt + , menu itself
---------------------------------------------------------------------------------------

-- A copy of a menu's item table with items of the module's own before its end marker; the
-- constructor's push is pointed at the copy and the menu built again if it was built already.
-- `site` is the `push table / mov ecx, menu / call Menu::Menu` in the constructor. Returns the new
-- items. Whatever the push names now is copied, so a module that extended the table first keeps
-- its items.
function C.appendItems(self, site, count, purpose)
  local old = rd32(site + 1)
  local menu = rd32(site + 6)
  local constructor = readCallTarget(site, 10, "the Menu constructor")
  local n = 0
  while rd32(old + n * MENU_ITEM_SIZE) ~= TYPE_END do
    n = n + 1
    if n > K.MOST_DIALOG_ITEMS then error(MODULE_NAME .. ": " .. purpose .. " is not the one this module knows") end
  end
  local new = core.allocate((n + count + 1) * MENU_ITEM_SIZE, true)
  core.writeBytes(new, core.readBytes(old, n * MENU_ITEM_SIZE))
  core.writeBytes(new + (n + count) * MENU_ITEM_SIZE, core.readBytes(old + n * MENU_ITEM_SIZE, MENU_ITEM_SIZE))
  local items = {}
  for i = 1, count do items[i] = new + (n + i - 1) * MENU_ITEM_SIZE end
  self.saved = self.saved or {}
  table.insert(self.saved, { address = site + 1, bytes = core.readBytes(site + 1, 4) })
  core.writeCodeInteger(site + 1, new)
  local construct = core.exposeCode(constructor, 2, 1)
  local function ensure()
    if rd32(menu) == old then construct(menu, new) end
  end
  return items, ensure, new, menu
end

-- An item that is clicked and drawn by lua functions.
function C.luaItem(into, x, y, width, height, action, render, what)
  wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
  wr32(into + ITEM_X, x)
  wr32(into + ITEM_Y, y)
  wr32(into + ITEM_WIDTH, width)
  wr32(into + ITEM_HEIGHT, height)
  wr32(into + ITEM_ACTION, action and C.luaPad(action, what) or C.assemble("alwaysYes", {}))
  wr32(into + ITEM_PARAM, 0)
  wr32(into + ITEM_RENDER, render and C.luaPad(render, what) or 0)
  wr32(into + ITEM_RENDER_TYPE, render and RENDER_SIMPLE or RENDER_NONE)
  wr32(into + ITEM_TEXT, 0)
  wr16(into + ITEM_CONTROL, 0)
end

-- What the menus here draw with: the Map settings menu's own button drawing (the button
-- background, then its text), the item rect it reads, the modal manager and its opener.
function C.resolveSettings(G)
  if C.settings ~= nil then return C.settings end
  local S = {}
  local modal = scan(K.AOB_SETTINGS_MODAL, "the Map settings menu")
  S.modalSite = modal
  S.menu = rd32(modal + K.SETTINGS_MODAL.menu)
  S.record = rd32(modal + K.SETTINGS_MODAL.record)
  S.table = scan(K.AOB_SETTINGS_TABLE, "the Map settings menu's items") - MENU_ITEM_SIZE
  if rd32(S.table + ITEM_TYPE) ~= TYPE_GROUP_START then
    error(MODULE_NAME .. ": the Map settings menu is not the one this module knows")
  end
  S.action = rd32(S.table + ITEM_ACTION)
  S.render = rd32(S.table + ITEM_RENDER)
  S.site = scan("68 " .. bytesOf(S.table) .. " B9 " .. bytesOf(S.menu) .. " E8", "the Map settings menu's constructor")
  -- The render: `mov ebx,[hover]` first; the item rect is the four words before the hover flag.
  expectBytes(S.render + K.SETTINGS_HOVER[1], K.SETTINGS_HOVER[2], "the Map settings buttons")
  S.hover = rd32(S.render + K.SETTINGS_HOVER[1] + #K.SETTINGS_HOVER[2])
  S.rect = S.hover - K.RECT_BEFORE_HOVER
  local okB, background = pcall(core.scanForAOB, K.AOB_BUTTON_BACKGROUND, S.render, S.render + K.SETTINGS_RENDER_SIZE)
  local okT, text = pcall(core.scanForAOB, K.AOB_BUTTON_TEXT, S.render, S.render + K.SETTINGS_RENDER_SIZE)
  if not okB or not okT or background == nil or text == nil or background == 0 or text == 0 then
    error(MODULE_NAME .. ": the Map settings buttons are not drawn as the module expects")
  end
  S.buttons = rd32(background + K.BUTTON_BACKGROUND.this)
  S.buttonBackground = readCallTarget(background, K.BUTTON_BACKGROUND.call, "the button background")
  S.textManager = rd32(text + 1)
  S.renderText = readCallTarget(text, 5, "the text drawing")
  local labels = scan(K.AOB_SETTINGS_LABELS, "the Map settings labels")
  S.singleLabel = labels + K.SETTINGS_LABELS.single
  S.multiLabel = labels + K.SETTINGS_LABELS.multi
  local koth = scan(K.AOB_SETTINGS_KOTH, "the King of the Hill flag")
  S.multi = rd32(koth + K.SETTINGS_KOTH.multi)
  S.koth = rd32(koth + K.SETTINGS_KOTH.koth)
  S.balanced = rd32(scan(K.AOB_BALANCED, "the balanced flag") + K.BALANCED)
  S.lock = rd32(scan(K.AOB_SETTINGS_ACTION, "the map lock") + K.SETTINGS_LOCK)
  S.size = rd32(scan(K.AOB_SETTINGS_SIZE, "the map size") + K.SETTINGS_SIZE_VAR)
  S.sizeEntry = scan(K.AOB_SETTINGS_SIZE_ENTRY, "the map size change")
  local alt = scan(K.AOB_ALT_COMMA, "Alt + ,")
  S.screen = rd32(alt + K.ALT_COMMA.screen)
  S.modal = rd32(alt + K.ALT_COMMA.modal)
  S.manager = rd32(alt + K.ALT_COMMA.manager)
  S.open = readCallTarget(alt, K.ALT_COMMA.open, "the modal opener")
  expectBytes(S.open + K.OPENER_STATE, { 0xB9 }, "the modal opener")
  S.listState = rd32(S.open + K.OPENER_STATE + 1)
  C.settings = S
  return S
end

-- Draws a button the way the Map settings menu draws its own: background (highlighted while
-- chosen or under the mouse), then the text centred in the game's button font.
function C.buttonDrawer(S, G)
  local background = core.exposeCode(S.buttonBackground, 3, 1)
  local renderText = core.exposeCode(S.renderText, 9, 1)
  local colourBox = core.exposeCode(G.colourBox, 6, 1)
  local buffers = {}
  local function buffer(text)
    if buffers[text] == nil then
      buffers[text] = core.allocate(#text + 1, true)
      writeCString(buffers[text], text)
    end
    return buffers[text]
  end
  local function rect()
    return rd32(S.rect), rd32(S.rect + 4), rd32(S.rect + 8), rd32(S.rect + 12)
  end
  local D = {}
  function D.button(text, chosen, box)
    local hovered = rd32(S.hover)
    wr32(S.hover, (chosen or hovered ~= 0) and 1 or 0)
    background(S.buttons, 0, -1)
    wr32(S.hover, hovered)
    local x, y, w = rect()
    local textX = x + w // 2
    if box ~= nil then                         -- a check box at the left, ticked while on
      local white = rd32(G.pixelFormat) == 0x565 and 0xFFFF or 0x7FFF
      local l, t = x + K.CHECK_INSET, y + K.CHECK_INSET
      local s = K.CHECK_SIZE
      colourBox(G.pencil, l, t, l + s, t + 1, white)
      colourBox(G.pencil, l, t + s - 1, l + s, t + s, white)
      colourBox(G.pencil, l, t, l + 1, t + s, white)
      colourBox(G.pencil, l + s - 1, t, l + s, t + s, white)
      if box then colourBox(G.pencil, l + 3, t + 3, l + s - 3, t + s - 3, white) end
      textX = textX + (K.CHECK_INSET + s) // 2
    end
    renderText(S.textManager, buffer(text), textX, y + K.BUTTON_TEXT_DOWN, 1,
      hovered ~= 0 and K.TEXT_HOVERED or K.TEXT_NORMAL, K.BUTTON_FONT, 0, 0)
  end
  function D.text(text, font, down)
    local x, y, w = rect()
    renderText(S.textManager, buffer(text), x + w // 2, y + (down or 0), 1, K.TEXT_NORMAL, font, 0, 0)
  end
  D.rect = rect
  return D
end

function C.enableMapSettings(self, O, G)
  local S = C.resolveSettings(G)
  local draw = C.buttonDrawer(S, G)
  local open = core.exposeCode(S.open, 3, 1)
  local function openSettings()
    if rd32(S.modal) == -1 then open(S.manager, K.SETTINGS_MODAL_ID, 0) end
  end
  local done = {}

  -- 38.1: Show locked maps, in the Load dialog while it lists maps.
  if O.lockedMaps then
    local ok, problem = pcall(function()
      local show = core.allocate(4, true)
      local site = scan(K.AOB_LOCK_FILTER, "the locked map filter")
      expectBytes(site + K.LOCK_FILTER.jump, { 0x75 }, "the locked map filter")
      local drop = site + K.LOCK_FILTER.size + (rd8(site + K.LOCK_FILTER.jump + 1) & 0xFF)
      local stub = C.assemble("lockedMaps", { SHOW = show, LOCK_STATE = rd32(site + 2), KEEP = site + K.LOCK_FILTER.size,
        DROP = drop })
      local menu = rd32(scan(K.AOB_LOAD_MODAL, "the Load dialog") + 1)
      local init = scan("68 ? ? ? ? B9 " .. bytesOf(menu) .. " E8", "the Load dialog's items")
      local opener = core.exposeCode(scan(K.AOB_MAP_OPENER, "the map list"), 2, 1)
      local items, ensure = C.appendItems(self, init, 1, "the Load dialog")
      local toggle = items[1]
      local function listingMaps() return rd32(S.listState) == K.MAP_LIST_KIND end
      C.luaItem(toggle, K.LOCKED_TOGGLE.x, K.LOCKED_TOGGLE.y, K.LOCKED_TOGGLE.width, K.LOCKED_TOGGLE.height,
        function()
          if not listingMaps() then return end
          wr32(show, rd32(show) ~= 0 and 0 or 1)
          opener(S.listState, rd32(S.modal))
        end,
        function()
          local on = listingMaps()
          wr32(toggle + ITEM_WIDTH, on and K.LOCKED_TOGGLE.width or 0)
          wr32(toggle + ITEM_HEIGHT, on and K.LOCKED_TOGGLE.height or 0)
          if on then draw.button("Show locked maps", false, rd32(show) ~= 0) end
        end, "the Show locked maps box")
      patchJump(self, site, K.LOCK_FILTER.size, stub)
      ensure()
      hooks.registerHookCallback("afterInit", ensure)
    end)
    if not ok then log(WARNING, tostring(problem) .. "; the Load dialog has no Show locked maps box") end
  end

  -- 38.2: the Map Settings button on the map's menu screen.
  if O.settingsButton then
    local ok, problem = pcall(function()
      local props = scan(K.AOB_PROPERTIES_TABLE, "the map menu's items") - K.PROPERTIES_ITEM * MENU_ITEM_SIZE
      local init = scan("68 " .. bytesOf(props) .. " B9 ? ? ? ? E8", "the map menu's constructor")
      local items, ensure = C.appendItems(self, init, 1, "the map menu")
      local b = K.SETTINGS_BUTTON
      C.luaItem(items[1], b.x, b.y, b.width, b.height, openSettings,
        function() draw.button("Map Settings", false) end, "the Map Settings button")
      ensure()
      hooks.registerHookCallback("afterInit", ensure)
    end)
    if not ok then log(WARNING, tostring(problem) .. "; the map menu has no Map Settings button") end
  end

  -- 38.3-38.9: the menu itself.
  if O.settingsMenu then
    local ok, problem = pcall(C.settingsMenu, self, G, S, draw, open)
    if not ok then log(WARNING, tostring(problem) .. "; the Map settings menu is left as it is") end
  end
end

function C.settingsMenu(self, G, S, draw, open)
  local L = K.SETTINGS_LAYOUT
  local keyState = C.resolved and C.resolved.keyState or rd32(scan(K.AOB_ASYNC_KEY, "the key state") + K.ASYNC_KEY_IMPORT)
  local asyncKey = core.exposeCode(core.allocateAssembly(templates.undoKeyState, { IMPORT = keyState }), 1, 0)
  local function leftHeld() return (asyncKey(K.LEFT_BUTTON) % 0x10000) >= 0x8000 end
  local mapSize = core.exposeCode(C.assemble("mapSize", { SIZE_CODE = S.sizeEntry }), 1, 0)

  -- The table: the group (Single, Multi, the four map types, the four sizes), then the module's
  -- own items, then the end marker.
  local group = { { L.single, 0xA }, { L.multi, 0xB } }
  for i, param in ipairs(K.MAP_TYPE_PARAMS) do group[#group + 1] = { L.types[i], param } end
  for i, param in ipairs(K.MAP_SIZE_PARAMS) do group[#group + 1] = { L.sizes[i], param } end
  local own = { "title", "custom", "slider", "sliderTick", "balanced", "koth", "lock", "back" }
  local count = 1 + #group + #own + 1
  local new = core.allocate(count * MENU_ITEM_SIZE, true)
  core.writeBytes(new, core.readBytes(S.table, MENU_ITEM_SIZE))
  local model = S.table + MENU_ITEM_SIZE                   -- the Single button
  for i, entry in ipairs(group) do
    local into = new + i * MENU_ITEM_SIZE
    core.writeBytes(into, core.readBytes(model, MENU_ITEM_SIZE))
    wr32(into + ITEM_X, entry[1].x)
    wr32(into + ITEM_Y, entry[1].y)
    wr32(into + ITEM_WIDTH, entry[1].width)
    wr32(into + ITEM_HEIGHT, K.SETTINGS_BUTTON.height)
    wr32(into + ITEM_PARAM, entry[2])
    wr32(into + ITEM_ACTION, S.action)
    wr32(into + ITEM_RENDER, S.render)
  end
  local at = {}
  for i, kind in ipairs(own) do at[kind] = new + (#group + i) * MENU_ITEM_SIZE end
  core.writeBytes(new + (count - 1) * MENU_ITEM_SIZE, core.readBytes(S.table + K.SETTINGS_ITEMS * MENU_ITEM_SIZE,
    MENU_ITEM_SIZE))
  if rd32(new + (count - 1) * MENU_ITEM_SIZE) ~= TYPE_END then
    error(MODULE_NAME .. ": the Map settings menu is not the one this module knows")
  end

  local h = K.SETTINGS_BUTTON.height
  local function flip(address) wr32(address, rd32(address) ~= 0 and 0 or 1) end
  C.luaItem(at.title, 0, L.title.y, K.SETTINGS_SIZE.width, 0, nil,
    function() draw.text("Map Settings", K.TITLE_FONT) end, "the Map settings title")
  local function standard()
    local size = rd32(S.size)
    for _, value in ipairs(K.MAP_SIZES) do if value == size then return true end end
    return false
  end
  C.luaItem(at.custom, L.custom.x, L.custom.y, L.custom.width, h, nil,
    function() draw.button("Custom", not standard()) end, "the Custom size")
  -- The slider: a click picks the size under the mouse and follows it while held; the map gets
  -- the size when the button is let go.
  local slider = { dragging = false, value = nil }
  local function valueAt()
    local x, _, w = draw.rect()
    local mouse = C.mouseX(G)
    if mouse == nil then return nil end
    local low, high = K.MAP_SIZE_RANGE[1], K.MAP_SIZE_RANGE[2]
    local t = math.min(math.max((mouse - x - K.SLIDER_INSET) / math.max(w - 2 * K.SLIDER_INSET, 1), 0), 1)
    return math.floor(low + t * (high - low) + 0.5)
  end
  local sliderRect = {}
  C.luaItem(at.slider, L.slider.x, L.slider.y, L.slider.width, h,
    function()
      slider.dragging = true
      slider.value = valueAt() or rd32(S.size)
    end,
    function()
      sliderRect.x, sliderRect.y, sliderRect.w = draw.rect()
      if slider.dragging then
        local value = valueAt()
        if value ~= nil then slider.value = value end
      end
      local value = slider.dragging and slider.value or rd32(S.size)
      draw.button(string.format("Map size: %d", value), false)
      local low, high = K.MAP_SIZE_RANGE[1], K.MAP_SIZE_RANGE[2]
      local t = (math.min(math.max(value, low), high) - low) / (high - low)
      local x = sliderRect.x + K.SLIDER_INSET + math.floor(t * (sliderRect.w - 2 * K.SLIDER_INSET) + 0.5)
      local white = rd32(G.pixelFormat) == 0x565 and 0xFFFF or 0x7FFF
      local colourBox = C.colourBoxFn or core.exposeCode(G.colourBox, 6, 1)
      C.colourBoxFn = colourBox
      colourBox(G.pencil, x - 2, sliderRect.y + 2, x + 2, sliderRect.y + h - 2, white)
    end, "the map size slider")
  wr32(at.sliderTick + ITEM_TYPE, TYPE_EVERY_FRAME)
  wr32(at.sliderTick + ITEM_ACTION, C.luaPad(function()
    if not slider.dragging or leftHeld() then return end
    slider.dragging = false
    local value = slider.value
    if value ~= nil and value ~= rd32(S.size) then mapSize(value) end
  end, "the map size slider"))
  wr32(at.sliderTick + ITEM_RENDER_TYPE, RENDER_NONE)
  C.luaItem(at.balanced, L.balanced.x, L.balanced.y, L.balanced.width, h, function() flip(S.balanced) end,
    function() draw.button("Balanced", false, rd32(S.balanced) == 0) end, "the Balanced box")   -- 0: balanced
  C.luaItem(at.koth, L.koth.x, L.koth.y, L.koth.width, h, function() flip(S.koth) end,
    function() draw.button("King of the Hill", false, rd32(S.koth) ~= 0) end, "the King of the Hill box")
  C.luaItem(at.lock, L.lock.x, L.lock.y, L.lock.width, h,
    function() wr32(S.lock, rd32(S.lock) ~= 0 and 0 or K.MAP_LOCKED) end,
    function() draw.button("Lock map", false, rd32(S.lock) ~= 0) end, "the Lock map box")
  C.luaItem(at.back, L.back.x, L.back.y, L.back.width, h,
    function() open(S.manager, -1, 0) end, function() draw.button("Back", false) end, "the Back button")

  -- Texts: Singleplayer and Multiplayer.
  self.saved = self.saved or {}
  for _, label in ipairs({ { S.singleLabel, "Singleplayer" }, { S.multiLabel, "Multiplayer" } }) do
    local text = core.allocate(#label[2] + 1, true)
    writeCString(text, label[2])
    table.insert(self.saved, { address = label[1], bytes = core.readBytes(label[1], 4) })
    core.writeCodeInteger(label[1], text)
  end
  -- Size: the constructor's pushes, and the record if it was built already.
  local m = K.SETTINGS_MODAL
  table.insert(self.saved, { address = S.modalSite + m.height, bytes = core.readBytes(S.modalSite + m.height, 4) })
  table.insert(self.saved, { address = S.modalSite + m.width, bytes = core.readBytes(S.modalSite + m.width, 4) })
  core.writeCodeInteger(S.modalSite + m.height, K.SETTINGS_SIZE.height)
  core.writeCodeInteger(S.modalSite + m.width, K.SETTINGS_SIZE.width)
  local function resize()
    if rd32(S.record) == K.SETTINGS_MODAL_ID then
      wr32(S.record + K.MODAL_WIDTH, K.SETTINGS_SIZE.width)
      wr32(S.record + K.MODAL_HEIGHT, K.SETTINGS_SIZE.height)
    end
  end
  resize()
  hooks.registerHookCallback("afterInit", resize)
  -- The table.
  table.insert(self.saved, { address = S.site + 1, bytes = core.readBytes(S.site + 1, 4) })
  core.writeCodeInteger(S.site + 1, new)
  local construct = core.exposeCode(readCallTarget(S.site, 10, "the Menu constructor"), 2, 1)
  local function ensure()
    if rd32(S.menu) == S.table then construct(S.menu, new) end
  end
  ensure()
  hooks.registerHookCallback("afterInit", ensure)
end

local function enableMenu(self, O)
  local G = {}
  resolveMenu(G)
  resolveDrawing(G)
  resolveCounters(G)
  C.gameModeOf(G)                          -- the landscape patches test it too
  if O.variants then
    local ok, problem = pcall(resolveRocks, G)
    if not ok then
      log(WARNING, tostring(problem) .. "; no rock variant row")
      O.variants = false
    end
  end
  if O.herds then
    local ok, problem = pcall(resolveHerds, G)
    if not ok then
      log(WARNING, tostring(problem) .. "; no herd panel")
      O.herds = false
    end
  end
  local newTable, data = buildTable(G, O)
  installTable(G, newTable)
  patchTrees(self, G, O, data)
  if data.rockTabs > 0 then patchRocks(self, G, data) end
  if O.herds then patchHerds(self, G, data) end
  if O.invisibleRocks then C.patchInvisibleRocks(self, data) end
  if data.mask ~= nil then
    local ok, problem = pcall(C.patchTextureMask, self, G, data)
    if not ok then log(WARNING, tostring(problem) .. "; the texture mask does nothing") end
  end
  if data.heights ~= nil then
    local ok, problem = pcall(C.patchHeightTools, self, G, data)
    if not ok then log(WARNING, tostring(problem) .. "; the height tools keep breaking rocks") end
  end
  if data.heights ~= nil or data.mask ~= nil then
    local ok, problem = pcall(C.patchHeightFilters, self, G, data)
    if not ok then log(WARNING, tostring(problem) .. "; the height tools change every tile under the brush") end
  end
  if data.heights ~= nil or data.treePreviewDraw ~= nil or data.groupWarning ~= nil then
    local ok, problem = pcall(C.patchFrame, self, G, data)
    if not ok then log(WARNING, tostring(problem) .. "; the tree preview only shows with the menu") end
  end
  if data.pipette ~= nil then
    local ok, problem = pcall(C.patchPipettePreview, self, data.pipette, data.pipetteRead)
    if not ok then log(WARNING, tostring(problem) .. "; the pipette shows the whole brush while taking a tile") end
  end
  if O.eraserChoice or O.eraseGulls then
    local ok, problem = pcall(C.patchEraserChoice, self, G, O.eraserChoice, O.eraseGulls)
    if not ok then log(WARNING, tostring(problem) .. "; the eraser takes everything as before") end
  end
  self.shownFlag = data.shown
  self.landscape = G
  log(INFO, string.format("%s: editor menu changed (menu 0x%X, items 0x%X -> 0x%X; %d tree, %d rock, "
    .. "%d group slots)", MODULE_NAME, G.menu, G.table, newTable, G.treeSlots, G.rockSlots, G.groupSlots))
end

-- Skirmish maps get the Rocks tab with the signpost: the jl past `mov eax, 239` always jumps.
local function enableSignpost(self)
  local site = scan(K.AOB_SIGNPOST, "the Rocks button") + K.SIGNPOST_JUMP
  expectBytes(site, { K.JL_SHORT }, "the Rocks button")
  self.saved = self.saved or {}
  table.insert(self.saved, { address = site, bytes = { K.JL_SHORT } })
  core.writeCode(site, { K.JMP_SHORT })
end

-- The random rotation button sets the module's own mode, which the preview follows and which
-- turns after every placed rock instead of on a timer.
local function enableRandomPreview(self)
  local site = scan(K.AOB_RANDOM_ROCK, "the random rock button") + K.RANDOM_ROCK_MODE
  expectBytes(site, { 0x89, 0x0D }, "the random rock button")
  local turn = scan(K.AOB_ROCK_TURN, "placeRock's rotation")
  local RT = K.ROCK_TURN
  local rotation = rd32(turn + RT.rotation)
  patchJump(self, turn, RT.size, core.allocateAssembly(templates.rockTurn, {
    ROTATION = rotation, TURN_MODE = K.ROCK_TURN_MODE, BACK = turn + RT.size,
  }))
  patchJump(self, site, K.RANDOM_ROCK_MODE_SIZE, core.allocateAssembly(templates.randomRockMode, {
    MODE = rd32(site + 2), TURN_MODE = K.ROCK_TURN_MODE, BACK = site + K.RANDOM_ROCK_MODE_SIZE,
  }))
end

---------------------------------------------------------------------------------------
-- Castle mode: the build menu
---------------------------------------------------------------------------------------

-- The build menu's item table (found by its minimap item), its constructor, its tabs and
-- buttons, and what the building counts need.
function C.resolve(G)
  local B = {}
  B.table = scan(K.AOB_BUILD_MINIMAP, "the build menu") - K.BUILD_MINIMAP_ITEM * MENU_ITEM_SIZE
  local count = 0
  while rd32(item(B.table, count, ITEM_TYPE)) ~= TYPE_END do
    count = count + 1
    if count > K.BUILD_MOST_ITEMS then error(MODULE_NAME .. ": the build menu is not the one this module knows") end
  end
  B.count = count
  B.site = scan("68 " .. bytesOf(B.table) .. " B9 ? ? ? ? E8", "the build menu's constructor")
  B.menu = rd32(B.site + 6)
  B.constructor = readCallTarget(B.site, 10, "the Menu constructor")
  local minimap = item(B.table, K.BUILD_MINIMAP_ITEM)
  B.minimapX, B.minimapWidth = rd32(minimap + ITEM_X), rd32(minimap + ITEM_WIDTH)

  -- Buttons by tab and command: item index, image table index, the action their group gives.
  B.buttons, B.blockEnd = {}, {}
  local block, groupAction = 0, nil
  for i = 0, count - 1 do
    local itemType = rd32(item(B.table, i, ITEM_TYPE))
    if itemType == TYPE_BLOCK then
      if block == 0 then B.firstBlock = i else B.blockEnd[block] = B.blockEnd[block] or i end
      block = rd32(item(B.table, i, ITEM_PARAM))
    elseif itemType == TYPE_GROUP_START then
      groupAction = rd32(item(B.table, i, ITEM_ACTION))
    elseif (itemType & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_MEMBER then
      local param = rd32(item(B.table, i, ITEM_PARAM))
      B.buttons[block] = B.buttons[block] or {}
      if B.buttons[block][param] == nil then
        local action = rd32(item(B.table, i, ITEM_ACTION))
        if action == 0 then action = groupAction end
        B.buttons[block][param] = { index = i, image = rd32(item(B.table, i, ITEM_IMAGE)) & IMAGE_INDEX_MASK,
          action = action }
      end
    end
  end
  if block ~= 0 then B.blockEnd[block] = B.blockEnd[block] or count end
  for _, need in ipairs(K.BUILD_NEEDED) do
    local tab = B.buttons[need[1]]
    if B.blockEnd[need[1]] == nil or tab == nil or tab[need[2]] == nil then
      error(string.format("%s: button %d of build menu tab %d is missing", MODULE_NAME, need[2], need[1]))
    end
  end
  -- Every building button's group hands its command to the same toolbar action.
  B.toolbar = B.buttons[K.TAB_TOWERS][K.FIRST_TOWER].action

  G.gameMode = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND)
  B.buildings = rd32(scan(K.AOB_BUILDINGS_STATE, "the building list") + 2)
  B.currentPlayer = rd32(scan(K.AOB_CURRENT_PLAYER, "the current player") + 1)
  local loop = scan(K.AOB_PLAYER_LOOP, "the building list walk")
  B.firstState = B.buildings + rd32(loop + 2)
  B.ownerFromState = rd8(loop + K.PLAYER_LOOP_OWNER) & 0xFF
  B.buildingSize = readOperand(loop, K.PLAYER_LOOP_STRIDE, "the building list walk")
  local slots = scan(K.AOB_BUILDING_SLOTS, "the building list's size")
  if rd32(slots + K.BUILDING_SLOTS.first) ~= B.firstState then
    error(MODULE_NAME .. ": the building list is not where the module expects it")
  end
  B.capacity = (rd32(slots + K.BUILDING_SLOTS.past) - B.firstState) // B.buildingSize
  -- Which building types are a player's buildings: the game's own list of buildings an enemy
  -- can be sent to destroy (`add eax, -first / cmp eax, last / ja <counted> / movzx eax, byte
  -- [eax + table] / jmp [eax*4 + jumps]`).
  local list = scan(K.AOB_PLAYER_BUILDINGS, "the player building types")
  B.typeFromState = rd8(list + 3) & 0xFF
  local first = -C.signedByte(list + 6)
  local last = first + (rd8(list + 9) & 0xFF)
  local counted = list + 12 + (rd8(list + 11) & 0xFF)
  local bytes, jumps = rd32(list + 15), rd32(list + 22)
  local types = {}
  for buildingType = 0, 255 do
    local yes = buildingType ~= 0
    if buildingType >= first and buildingType <= last then
      yes = rd32(jumps + (rd8(bytes + buildingType - first) & 0xFF) * 4) == counted
    end
    types[buildingType + 1] = yes and 1 or 0
  end
  B.playerTypes = core.allocate(256, true)
  core.writeBytes(B.playerTypes, types)
  return B
end

-- The building counts above the minimap: three lines in the tooltip style, drawn on the map
-- surface (the minimap's right edge, just above the panel).
function C.makeCounts(G, B, counts)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local buffers = { core.allocate(96, true), core.allocate(96, true), core.allocate(96, true) }
  return function()
    local player = rd32(B.currentPlayer)
    local texts = {
      string.format("Buildings: %d/%d", rd32(counts), B.capacity),
      string.format("Player buildings, all players: %d", rd32(counts + 4)),
      string.format("Player buildings, player %d: %d", player, rd32(counts + 8)),
    }
    local widest = 0
    for i, text in ipairs(texts) do
      writeCString(buffers[i], text)
      widest = math.max(widest, textWidth(G.textManager, buffers[i], #text, TOOLTIP_FONT))
    end
    local right = rd32(B.menu + MENU_X) + B.minimapX + B.minimapWidth + rd32(G.cameraX)
    local left = right - widest - 2 * TOOLTIP_PADDING
    local bottom = rd32(B.menu + MENU_Y) + PANEL_BOTTOM - PANEL_GAP + rd32(G.cameraY)
    local top = bottom - #texts * TOOLTIP_LINE - TOOLTIP_PADDING
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    roundedBox(G.pencil, left, top, right, bottom, BOX_BLEND)
    wr32(G.pencil + PENCIL_TARGET, target)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    for i = 1, #texts do
      shadowedText(G.textManager, buffers[i], left + TOOLTIP_PADDING,
        top + TOOLTIP_PADDING // 2 + (i - 1) * TOOLTIP_LINE, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    end
    wr32(G.textLayer, layer)
  end
end

-- The Barrier button in the Ruins tab: the game's "no workers" sign, on the screen like the
-- tab's other buttons, on a box while under the mouse; its name in a box if the sign cannot
-- be had.
function C.makeBarrier(G)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local blit = core.exposeCode(G.blit, 3, 0)
  local buffer = core.allocate(32, true)
  local gm = nil
  local ok, names = pcall(function()
    return { scan(K.AOB_GM_NO_WORKERS, "the gm list"), scan(K.AOB_GM_CHECK_BOXES, "the gm list") }
  end)
  local boxes = rd32(G.buttonImages + K.CHECKED_IMAGE * IMAGE_SIZE)
  if ok and (names[1] - names[2]) == (K.NO_WORKERS_GM - boxes) * K.GM_RECORD_SIZE then gm = K.NO_WORKERS_GM end
  local sign = nil                         -- the sign, cut out of its picture once it is loaded

  -- The picture's pixels (16-bit TGX: n literal pixels, a repeated pixel, n see-through, new
  -- line), cropped to the first run of rows with anything in them (the sign, not the mark
  -- under it).
  local function cut()
    local first = rd32(G.firstPictures + gm * 4)
    if first <= 0 then return nil end
    local frame = first + K.NO_WORKERS_PICTURE - 1
    local header = G.pictureHeights - 2 + frame * PICTURE_SIZE
    local width, height = rd16(header), rd16(header + 2)
    if width <= 0 or height <= 0 then return nil end
    local data = core.readBytes(rd32(G.pictureOffsets + frame * 4) + rd32(G.textures + TEXTURES_DATA), width * height * 3)
    local rows, x, y, i = {}, 0, 0, 1
    local function word(at) return (data[at] & 0xFF) | ((data[at + 1] & 0xFF) << 8) end
    while y < height and i <= #data do
      local token = data[i] & 0xFF
      i = i + 1
      local n, flag = (token & 0x1F) + 1, token >> 5
      if flag == 0 then
        for _ = 1, n do
          rows[y] = rows[y] or {}
          rows[y][x] = word(i)
          i, x = i + 2, x + 1
        end
      elseif flag == 2 then
        local value = word(i)
        i = i + 2
        rows[y] = rows[y] or {}
        for _ = 1, n do rows[y][x], x = value, x + 1 end
      elseif flag == 1 then
        x = x + n
      elseif flag == 4 then
        x, y = 0, y + 1
      else
        break
      end
    end
    local top = 0
    while top < height and rows[top] == nil do top = top + 1 end
    local bottom = top
    while bottom + 1 < height and rows[bottom + 1] ~= nil do bottom = bottom + 1 end
    local left, right = width, -1
    for row = top, bottom do
      for column in pairs(rows[row] or {}) do left, right = math.min(left, column), math.max(right, column) end
    end
    if right < left then return nil end
    local w, h, pixels = right - left + 1, bottom - top + 1, {}
    for row = top, bottom do
      for column, value in pairs(rows[row] or {}) do pixels[(row - top) * w + column - left + 1] = value end
    end
    return { address = storeRawPicture(w, h, pixels), width = w, height = h }
  end

  return function(barrier)
    local x, y = rd32(G.itemX), rd32(G.itemY)
    local width, height = rd32(barrier + ITEM_WIDTH), rd32(barrier + ITEM_HEIGHT)
    if gm ~= nil and sign == nil then sign = cut() end
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, K.SCREEN_LAYER)
    if sign == nil or rd32(G.hover) ~= 0 then roundedBox(G.pencil, x, y, x + width - 1, y + height - 1, BOX_BLEND) end
    if sign ~= nil then
      blit(sign.address, x + (width - sign.width) // 2, y + (height - sign.height) // 2)
      wr32(G.pencil + PENCIL_TARGET, target)
      return
    end
    wr32(G.pencil + PENCIL_TARGET, target)
    writeCString(buffer, K.BARRIER_LABEL)
    local textX = x + (width - textWidth(G.textManager, buffer, #K.BARRIER_LABEL, TOOLTIP_FONT)) // 2
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, K.SCREEN_LAYER)
    shadowedText(G.textManager, buffer, textX, y + (height - TOOLTIP_LINE) // 2, ALIGN_LEFT, TOOLTIP_COLOUR, 0,
      TOOLTIP_FONT, 0, 0)
    wr32(G.textLayer, layer)
  end
end

-- A picture made smaller (a whole number of times) to fit box, each pixel the average of its
-- block when at least half of the block is drawn.
function C.shrink(G, picture, box)
  local f = math.max(1, math.ceil(picture.width / box.width), math.ceil(picture.height / box.height))
  if f == 1 then return picture end
  local wide = rd32(G.pixelFormat) == 0x565
  local gShift, gMask, rShift = wide and 5 or 5, wide and 0x3F or 0x1F, wide and 11 or 10
  local w, h = picture.width // f, picture.height // f
  local pixels, source = {}, picture.pixels
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local n, r, g, b = 0, 0, 0, 0
      for dy = 0, f - 1 do
        local row = (y * f + dy) * picture.width + x * f + 1
        for dx = 0, f - 1 do
          local v = source[row + dx]
          if v ~= nil then
            n = n + 1
            r, g, b = r + ((v >> rShift) & 0x1F), g + ((v >> gShift) & gMask), b + (v & 0x1F)
          end
        end
      end
      if n * 2 >= f * f then
        pixels[y * w + x + 1] = ((r // n) << rShift) | ((g // n) << gShift) | (b // n)
      end
    end
  end
  return { address = storeRawPicture(w, h, pixels), width = w, height = h }
end

-- Pictures of buildings for the castle panels: composed from the building's tiles like the
-- tunnel entrance and made smaller; base: the first picture (nil: the building's own). Answers
-- nil while the pictures are not loaded, false when the gm has no such pictures.
function C.buildingPictures(G, B)
  local sprites = scan(K.AOB_BUILDING_SPRITES, "the building pictures")
  local convert = core.exposeCode(readCallTarget(sprites, 0, "the building types"), 2, 1)
  local firstPicture = core.exposeCode(readCallTarget(sprites, K.BUILDING_SPRITES.sprite, "the building pictures"), 2, 1)
  local gms = rd32(sprites + K.BUILDING_SPRITES.gms)
  -- getBuildingSizeForCommandBuildingType is stdcall: called as a thiscall with no `this`.
  local sizeOf = core.exposeCode(scan(K.AOB_BUILDING_SIZE, "the building sizes"), 2, 1)
  if G.footprint == nil then resolveRocks(G) end
  local tilePicture = makeRockPictures(G)
  local cache = {}
  return function(command, base)
    local key = command .. "/" .. tostring(base)
    if cache[key] ~= nil then return cache[key] end
    local gm = rd32(gms + (convert(B.buildings, command) & 0xFFFF) * 4)
    base = base or firstPicture(B.buildings, command)
    local size = sizeOf(0, command)
    local first = rd32(G.firstPictures + gm * 4)
    if first <= 0 then return nil end
    local after = rd32(G.firstPictures + (gm + 1) * 4)
    if size < 1 or size > 13 or (after > first and base + size * size - 1 > after - first) then
      cache[key] = false
      return false
    end
    local picture = tilePicture(size, base, 0, gm, true)
    if picture == nil then return nil end
    cache[key] = C.shrink(G, picture, K.VARIANT_THUMB)
    return cache[key]
  end
end

-- What a castle panel shows for the chosen tool: rows of commands with a game picture and a
-- label each; `when` says for which chosen tools (nil: whenever its tab is open). An entry
-- with `images` stands for the chosen tool itself (its picture by command); one with `flag`
-- is a way of placing it, chosen while the flag holds its `value`.
function C.makeEntries(G, panel, rows)
  return function(command)
    for _, row in ipairs(rows) do
      if row.when == nil or row.when[command] then
        local list = {}
        for i, entry in ipairs(row) do
          local param, image = entry.command, entry.image
          if entry.images ~= nil then param, image = command, entry.images[command] end
          local chosen = command == param
          if entry.tool ~= nil then param = entry.tool end   -- the button that chooses this tool
          if entry.flag ~= nil then chosen = chosen and rd32(entry.flag) == entry.value end
          if entry.lock ~= nil then chosen = chosen and rd32(entry.lock) == param end
          list[i] = { item = panel.items[i], image = image, label = entry.label, param = param, chosen = chosen,
            minWidth = entry.minWidth }
          if entry.compose ~= nil then
            local picture = entry.compose()
            if picture == nil then return {} end              -- its pictures are not loaded yet
            if picture then list[i].image, list[i].picture = nil, picture end   -- false: the menu's
          end
        end
        list.shift = row.shift or panel.shift
        return list
      end
    end
    return {}
  end
end

-- Player 0's shield: a click sets the current player to 0 the way the game's shields set theirs
-- (every player flag cleared, flag 0 set); drawn in its chosen look while player 0 is current.
function C.shieldZero(G, click, draw)
  local choice = scan(K.AOB_PLAYER_CHOICE, "the player shields")
  local flags, current = rd32(choice + K.PLAYER_CHOICE.flags), rd32(choice + K.PLAYER_CHOICE.current)
  local pictures = buttonPictures("shield0")
  local chosen = core.allocate(4, true)
  for _, at in ipairs({ click, draw }) do
    wr32(at + ITEM_X, K.SHIELD_ZERO.x)
    wr32(at + ITEM_Y, K.SHIELD_ZERO.y)
    wr32(at + ITEM_TEXT, 0)
    wr16(at + ITEM_CONTROL, -1)
  end
  wr32(click + ITEM_TYPE, TYPE_CLICKABLE)
  wr32(click + ITEM_WIDTH, pictures.width)
  wr32(click + ITEM_HEIGHT, pictures.height)
  wr32(click + ITEM_RENDER_TYPE, RENDER_NONE)
  wr32(click + ITEM_ACTION, C.luaPad(function()
    if rd32(G.gameMode) ~= K.MAP_EDITOR then return end
    for p = 0, K.SHIELD_ZERO.players - 1 do wr32(flags + p * 4, 0) end
    wr32(flags, 1)
    wr32(current, 0)
  end, "the player 0 shield"))
  wr16(click + ITEM_HIDDEN, 1)
  local button = core.allocateAssembly(templates.flagPictureButton, {
    NORMAL = pictures.normal, HOVERED = pictures.hover, CHOSEN = pictures.chosen, FLAG = chosen,
    HOVER = click + ITEM_HOVERED, PENCIL = G.pencil, PENCIL_TARGET = PENCIL_TARGET, ITEM_X = G.itemX,
    ITEM_Y = G.itemY, BLIT = G.blit,
  })
  wr32(draw + ITEM_TYPE, TYPE_CLICKABLE)     -- no size, so never under the mouse
  wr32(draw + ITEM_WIDTH, 0)
  wr32(draw + ITEM_HEIGHT, 0)
  wr32(draw + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  wr32(draw + ITEM_RENDER, core.allocateAssembly(templates.shieldZero, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, CLICK = click, ITEM_HIDDEN = ITEM_HIDDEN,
    CURRENT = current, CHOSEN = chosen, BUTTON = button,
  }))
  wr16(draw + ITEM_HIDDEN, 0)
end

-- The tooltip of the keep crest under the mouse: what the crest is and what a click does, in a
-- box above the crest (below it near the top of the screen), drawn on the map surface after the
-- crests. hovered: player, active, and the crest's place on the map surface (x, y, w, h).
function C.crestTooltip(G)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local buffers = {}
  for i = 1, math.max(#K.CREST_TOOLTIP.active, #K.CREST_TOOLTIP.other) do buffers[i] = core.allocate(96, true) end
  return function(hovered, camY)
    local who = "player " .. hovered.player
    local lines = {}
    for i, text in ipairs(hovered.active and K.CREST_TOOLTIP.active or K.CREST_TOOLTIP.other) do
      lines[i] = text:gsub("{player}", who)
    end
    local widest = 0
    for i, text in ipairs(lines) do
      writeCString(buffers[i], text)
      widest = math.max(widest, textWidth(G.textManager, buffers[i], #text, TOOLTIP_FONT))
    end
    local width = widest + 2 * TOOLTIP_PADDING
    local height = #lines * TOOLTIP_LINE + TOOLTIP_PADDING
    local left = hovered.x + hovered.w // 2 - width // 2
    local bottom = hovered.y - K.CREST_TOOLTIP.gap
    if bottom - height < camY then bottom = hovered.y + hovered.h + K.CREST_TOOLTIP.gap + height end
    local top = bottom - height
    roundedBox(G.pencil, left, top, left + width, bottom, BOX_BLEND)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    for i = 1, #lines do
      shadowedText(G.textManager, buffers[i], left + TOOLTIP_PADDING, top + TOOLTIP_PADDING // 2 + (i - 1) * TOOLTIP_LINE,
        ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    end
    wr32(G.textLayer, layer)
  end
end

-- The keep crests, drawn every frame in castle mode of the map editor; also keeps each player's
-- active keep where the map maker left it: a newly placed keep does not take it over (the game
-- makes every new keep the active one), and a removed active keep hands over to another keep of
-- the same player (the game leaves the player without one).
function C.keepCrests(G, B, data, at)
  local R = C.resolvePipette(G)
  local T = R.tileMap
  local site = scan(K.AOB_KEEP_ENTRY_CALL, "the keep's entry")
  local gameState = rd32(site + K.KEEP_ENTRY.state)
  local entryFn = readCallTarget(site, K.KEEP_ENTRY.call, "the keep's entry")
  if entryFn ~= scan(K.AOB_EARLIER_BUILDING, "the keep's entry") then
    error(MODULE_NAME .. ": placeKeep does not call the function this module knows")
  end
  local stride = readOperand(entryFn, K.KEEP_ENTRY.strideAt, "the keep's entry")
  local setEntry = core.exposeCode(entryFn, 4, 1)   -- this + keep, player, category (ret 0xC)
  local renderGM = core.exposeCode(G.renderGM, 5, 1)
  local blit = core.exposeCode(G.blit, 3, 0)
  local inside = core.exposeCode(G.isMouseInside, 5, 1)
  local asyncKey = core.exposeCode(core.allocateAssembly(templates.undoKeyState, { IMPORT = R.keyState }), 1, 0)
  local zero = buttonPictures("shield0")
  local first = B.buildings + K.BUILDING.first
  local size = B.buildingSize
  local stateOff = B.firstState - (first + size)
  local function building(id) return first + id * size end
  local function count() return rd32(B.buildings + K.MAX_BUILDINGS) end
  local function alive(id)
    local state = rd16(building(id) + stateOff) & 0xFFFF
    return state ~= 0 and state ~= K.BUILDING_REMOVED
  end
  local function entry(player, category)
    return gameState + K.KEEP_ENTRY.first + player * stride + category * K.KEEP_ENTRY.entry
  end
  -- Each player's shield: the gm picture its shield button shows (selected: picture + 8).
  local crest = {}
  for i = 0, B.count - 1 do
    local player = -9 - rd32(item(B.table, i, ITEM_PARAM))
    if player >= 1 and player <= K.PLAYERS and crest[player] == nil
        and (rd32(item(B.table, i, ITEM_TYPE)) & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_MEMBER
        and rd32(item(B.table, i, ITEM_RENDER_TYPE)) == RENDER_IMAGE then
      local image = G.buttonImages + (rd32(item(B.table, i, ITEM_IMAGE)) & IMAGE_INDEX_MASK) * IMAGE_SIZE
      crest[player] = { gm = rd32(image), picture = rd32(image + 4) }
    end
  end
  local rects = {}
  for i = 1, K.CREST.rects do rects[i] = C.takeRect(data) end
  local explain = data.crestTooltip and C.crestTooltip(G) or nil

  local function keepsNow()
    local list = {}
    for id = 1, count() - 1 do
      local b = building(id)
      if alive(id) and K.KEEP_TYPES[rd16(b + K.BUILDING.type) & 0xFFFF] then
        list[#list + 1] = { id = id, owner = rd16(b + K.BUILDING.owner), b = b }
      end
    end
    return list
  end
  local function isKeepOf(id, player)
    if id <= 0 or id >= count() or not alive(id) then return false end
    local b = building(id)
    return K.KEEP_TYPES[rd16(b + K.BUILDING.type) & 0xFFFF] ~= nil and rd16(b + K.BUILDING.owner) == player
  end
  -- A part placed together with a keep (placeKeep gives them one uidWhenPlaced): its campfire
  -- area or its stockpile.
  local function partOf(keep, kind)
    local uid, owner = rd32(building(keep) + K.BUILDING.uid), rd16(building(keep) + K.BUILDING.owner)
    for id = 1, count() - 1 do
      local b = building(id)
      if alive(id) and rd16(b + K.BUILDING.type) == kind and rd32(b + K.BUILDING.uid) == uid
          and rd16(b + K.BUILDING.owner) == owner then
        return id
      end
    end
    return nil
  end
  local function clear(player)
    for _, category in ipairs({ 0, K.KEEP_ENTRY.campfire }) do
      for d = 0, K.KEEP_ENTRY.dwords - 1 do wr32(entry(player, category) + d * 4, 0) end
    end
  end
  -- The player's stockpile entry follows the active keep. The game keeps the first stockpile
  -- ever placed there, and at the start of a match it removes the active keep together with the
  -- stockpile in that entry: with another keep's stockpile there, the active keep's own stockpile
  -- stayed and blocked the AI's castle plan, and the eraser took the active keep along with that
  -- other stockpile.
  -- A keep placed without its stockpile leaves the entry as it is.
  local function syncStockpile(keep, player)
    local stock = partOf(keep, K.STOCKPILE_TYPE)
    if stock == nil or rd32(entry(player, K.KEEP_ENTRY.stockpile)) == stock then return end
    for d = 0, K.KEEP_ENTRY.dwords - 1 do wr32(entry(player, K.KEEP_ENTRY.stockpile) + d * 4, 0) end
    setEntry(gameState, stock, player, K.KEEP_ENTRY.stockpile)
  end
  local function activate(keep, player)
    setEntry(gameState, keep, player, 0)
    local fire = partOf(keep, K.CAMPGROUND_TYPE)
    if fire ~= nil then setEntry(gameState, fire, player, K.KEEP_ENTRY.campfire) end
    syncStockpile(keep, player)
  end

  -- Where renderMap draws a tile on the map surface (as the tree preview works it out).
  local function surface(x, y, tile)
    local vp = R.viewport
    local turn = K.SCREEN_TURN[rd32(T + K.TILE_MAP.orientation)]
    if turn == nil or rd32(vp + K.VIEWPORT.zoomedOut) ~= 0 then return nil end
    local bias = rd32(vp + K.VIEWPORT.bias) == 0 and 0 or 0x40
    local column = rd32(vp + K.VIEWPORT.x) // K.TILE_WIDTH
    local row = (rd32(vp + K.VIEWPORT.y) + bias) // K.TILE_HEIGHT
    local d, sum = x - y, x + y
    local drawX = turn.cx + turn.xd * d + turn.xs * sum - K.TILE_WIDTH * column
    local drawY = bias + turn.cy + turn.yd * d + turn.ys * sum - K.TILE_HEIGHT * row
    local lift = K.FLAT_HEIGHT_OFFSET
    if rd32(R.flatView) == 0 then lift = rd32(T + K.HEIGHT_OFFSETS + (rd8(T + R.height + tile) & 0xFF) * 4) end
    return drawX, drawY - lift
  end

  local known, knownStock, wasEditor, wasDown = {}, {}, false, true
  local function tick()
    if rd32(R.gameMode) ~= K.MAP_EDITOR then
      wasEditor = false
      return
    end
    local keeps = keepsNow()
    -- The active keeps stay as the map maker left them.
    if not wasEditor then
      wasEditor = true
      for p = 0, K.PLAYERS do
        known[p] = rd32(entry(p, 0))
        if isKeepOf(known[p], p) then syncStockpile(known[p], p) end   -- maps made before this
        knownStock[p] = rd32(entry(p, K.KEEP_ENTRY.stockpile))
      end
    else
      for p = 0, K.PLAYERS do
        local now, before = rd32(entry(p, 0)), known[p]
        if before ~= nil and before > 0 then
          if not isKeepOf(before, p) then
            -- the active keep is gone: the player's next keep, else none
            local other = nil
            for _, keep in ipairs(keeps) do
              if other == nil and keep.owner == p then other = keep.id end
            end
            if other ~= nil then activate(other, p) else clear(p) end
          elseif now ~= before then
            activate(before, p)                     -- a new keep took over: give it back
          end
        end
        -- a first keep, or a stockpile entry changed under it (a separate stockpile placed first)
        local active, stock = rd32(entry(p, 0)), rd32(entry(p, K.KEEP_ENTRY.stockpile))
        if (active ~= known[p] or stock ~= knownStock[p]) and isKeepOf(active, p) then syncStockpile(active, p) end
        known[p], knownStock[p] = active, rd32(entry(p, K.KEEP_ENTRY.stockpile))
      end
    end

    local down = (asyncKey(K.LEFT_BUTTON) % 0x10000) >= 0x8000
    local pressed = down and not wasDown
    wasDown = down
    local menuX, menuY = rd32(B.menu + MENU_X), rd32(B.menu + MENU_Y)
    local camX, camY = rd32(G.cameraX), rd32(G.cameraY)
    local t = G.textures
    local mode, target = rd32(t + TEXTURES_MODE), rd32(G.pencil + PENCIL_TARGET)
    wr32(t + TEXTURES_MODE, MAP_LAYER)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    -- An error must not leave the menu drawing onto the map surface.
    local ok, problem = pcall(function()
    local used, hovered = 0, nil
    for _, keep in ipairs(keeps) do
      local p = keep.owner
      local half = (rd32(keep.b + K.BUILDING.size) & 0xFF) // 2
      local x, y = rd16(keep.b + K.BUILDING.x) + half, rd16(keep.b + K.BUILDING.y) + half
      if p >= 0 and p <= K.PLAYERS and (p == 0 or crest[p] ~= nil)
          and x >= 0 and y >= 0 and x < K.MAP_SIZE and y < K.MAP_SIZE then
        local drawX, drawY = surface(x, y, rd32(R.rows + y * 12) + x)
        if drawX ~= nil then
          local active = rd32(entry(p, 0)) == keep.id
          local w, h = zero.width, zero.height
          local sx, sy = drawX + K.TILE_WIDTH // 2 - w // 2, drawY - K.CREST.lift - h
          if p == 0 then
            blit(active and zero.chosen or zero.normal, sx, sy)
          else
            renderGM(t, crest[p].gm, crest[p].picture + (active and K.CREST.selected or 0), sx, sy)
          end
          local screenX, screenY = sx - camX, sy - camY
          used = used + 1
          if rects[used] ~= nil then C.markRect(rects[used], screenX - menuX, screenY - menuY, w, h) end
          local over = inside(G.mouse, screenX, screenY, w, h) ~= 0
          if over then hovered = { player = p, keep = keep.id, x = sx, y = sy, w = w, h = h } end
          if pressed and over then
            pressed = false
            if active then clear(p) else activate(keep.id, p) end
            known[p] = rd32(entry(p, 0))
          end
        end
      end
    end
    if hovered ~= nil and explain ~= nil then
      hovered.active = rd32(entry(hovered.player, 0)) == hovered.keep   -- after a click this frame
      explain(hovered, camY)
    end
    end)
    wr32(G.pencil + PENCIL_TARGET, target)
    wr32(t + TEXTURES_MODE, mode)
    if not ok then error(problem, 0) end
  end
  wr32(at + ITEM_TYPE, TYPE_CLICKABLE)       -- no size, so never under the mouse
  wr32(at + ITEM_WIDTH, 0)
  wr32(at + ITEM_HEIGHT, 0)
  wr32(at + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  wr32(at + ITEM_RENDER, C.luaPad(tick, "the keep crests"))
  wr32(at + ITEM_TEXT, 0)
  wr16(at + ITEM_CONTROL, -1)
  wr16(at + ITEM_HIDDEN, 0)
end

-- Wall tools (features 35): the words the crenellation hook reads, made once.
function C.wallWords()
  if C.wallState == nil then
    C.wallState = { height = core.allocate(4, true), low = core.allocate(4, true), mode = core.allocate(4, true) }
  end
  return C.wallState
end

-- The game code the wall tools change: placeWalls' wall heights (high, low), its crenellations'
-- join point, the stairs' first step and the per-step drop in the three functions that walk a
-- dragged wall, and the two tests in validateWallBuildPath that refuse a crenellation not
-- touching a wall.
function C.wallSites()
  if C.wallSiteCache ~= nil then return C.wallSiteCache end
  local W = K.WALL_SITES
  local heights = scan(W.heights.aob, "the wall heights")
  local crenel = scan(W.crenel.aob, "the crenellation heights")
  local sites = {
    high = heights + W.heights.high, low = heights + W.heights.low,
    join = crenel + W.crenel.join, live = rd32(crenel + W.crenel.live),
    first = scan(W.first.aob, "the first stair") + W.first.at,
    steps = {},
    free1 = scan(W.free1.aob, "the crenellation test"), free2 = scan(W.free2.aob, "the crenellation test") + W.free2.at,
  }
  for _, step in ipairs(W.steps) do
    sites.steps[#sites.steps + 1] = scan(step.aob, "the stairs' step") + step.at
  end
  if rd8(sites.high) & 0xFF ~= K.WALL_DEFAULT[K.HIGH_WALL] or rd8(sites.low) & 0xFF ~= K.WALL_DEFAULT[K.LOW_WALL]
      or rd8(sites.first) & 0xFF ~= K.STAIR_STEP then
    error(MODULE_NAME .. ": the wall heights are not the game's own")
  end
  for _, at in ipairs(sites.steps) do
    if rd32(at) ~= K.STAIR_STEP then error(MODULE_NAME .. ": the stairs' step is not the game's own") end
  end
  C.wallSiteCache = sites
  return sites
end

-- Crenellations may stand free in the map editor, and the crenellation choice / height slider
-- sets their height at the point all of placeWalls' crenellation heights meet (Smarter Walls'
-- own height jumps there too).
function C.patchWallTools(self, G, data)
  local S = C.wallSites()
  local W = C.wallWords()
  local R = C.resolvePipette(G)
  local yes1 = S.free1 + 6 + C.signedByte(S.free1 + 5)
  patchJump(self, S.free1, 6, core.allocateAssembly(templates.crenelFree1, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, YES = yes1, REFUSE = S.free1 + 6,
  }))
  local yes2 = S.free2 + 4 + C.signedByte(S.free2 + 3)
  patchJump(self, S.free2, 5, core.allocateAssembly(templates.crenelFree2, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, YES = yes2, REFUSE = S.free2 + 5,
  }))
  if S.live ~= R.height then error(MODULE_NAME .. ": placeWalls' height layer is not the tile map's") end
  patchJump(self, S.join, 7, C.assemble("crenelHeight", {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, HEIGHT = W.height, LOW = W.low,
    BASE = R.defaultHeight, LIVE = R.height, BACK = S.join + 7,
  }))
  -- The bytes the sliders rewrite go back to the game's own on disable.
  self.saved = self.saved or {}
  for _, at in ipairs({ S.high, S.low, S.first }) do
    table.insert(self.saved, { address = at, bytes = core.readBytes(at, 1) })
  end
  for _, at in ipairs(S.steps) do table.insert(self.saved, { address = at, bytes = core.readBytes(at, 4) }) end
end

-- The slider above the wall panel: Wall Height (0-255) for the high and low wall and the
-- crenellations, Steepness (0-16) for stairs. Values are kept per tool until the map editor is
-- left; a tool nobody moved the slider of builds the game's own way.
function C.wallControls(G, B, data, click, paint, reset)
  local S = C.wallSites()
  local W = C.wallWords()
  local R = C.resolvePipette(G)
  local asyncKey = core.exposeCode(core.allocateAssembly(templates.undoKeyState, { IMPORT = R.keyState }), 1, 0)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local colourBox = core.exposeCode(G.colourBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local buffer = core.allocate(64, true)
  local rect = C.takeRect(data)
  local P = K.WALL_SLIDER
  local values, drag, applied = {}, false, {}
  local function width(text)
    writeCString(buffer, text)
    return textWidth(G.textManager, buffer, #text, TOOLTIP_FONT)
  end
  local function crenelDefault()
    local mode = rd32(W.mode)
    return (mode == K.CRENEL_LOW or mode == K.CRENEL_LOW_DAMAGED) and K.CRENEL_LOW_HEIGHT or K.CRENEL_HIGH_HEIGHT
  end
  local function default(tool)
    if tool == K.CRENEL_WALL then return crenelDefault() end
    return K.WALL_DEFAULT[tool]
  end
  local function range(tool) return 0, tool == K.STAIRS and K.STAIR_STEP or 0xFF end
  local function write(at, value, size)
    if applied[at] == value then return end
    applied[at] = value
    if size == 4 then core.writeCodeInteger(at, value) else core.writeCodeByte(at, value) end
  end
  local function apply()
    write(S.high, values[K.HIGH_WALL] or K.WALL_DEFAULT[K.HIGH_WALL], 1)
    write(S.low, values[K.LOW_WALL] or K.WALL_DEFAULT[K.LOW_WALL], 1)
    local step = values[K.STAIRS] or K.STAIR_STEP
    write(S.first, step, 1)
    for _, at in ipairs(S.steps) do write(at, step, 4) end
    local mode = rd32(W.mode)
    local low = (mode == K.CRENEL_LOW or mode == K.CRENEL_LOW_DAMAGED) and 1 or 0
    local height = values[K.CRENEL_WALL]
    if height == nil and mode ~= 0 and mode ~= K.CRENEL_DAMAGED then height = crenelDefault() end
    wr32(W.height, height or 0)
    wr32(W.low, low)
    -- The crenellation choices that are damaged ones: the damaged look while they are chosen.
    if data.damagedWalls ~= nil and rd32(G.subtype) == K.CRENEL_WALL then
      local damaged = mode == K.CRENEL_LOW_DAMAGED or mode == K.CRENEL_HIGH_DAMAGED
      wr32(data.damagedWalls, damaged and 1 or 0)
    end
  end
  local function valueAt(tool)
    local lo, hi = range(tool)
    local left = rd32(B.menu + MENU_X) + rd32(click + ITEM_X)
    local w = math.max(1, rd32(click + ITEM_WIDTH))
    local value = lo + ((C.mouseX(G) - left) * (hi - lo) + w // 2) // w
    return math.max(lo, math.min(hi, value))
  end
  wr32(click + ITEM_TYPE, TYPE_CLICKABLE)
  wr32(click + ITEM_RENDER_TYPE, RENDER_NONE)
  wr32(click + ITEM_TEXT, 0)
  wr16(click + ITEM_CONTROL, -1)
  wr16(click + ITEM_HIDDEN, 1)
  wr32(click + ITEM_ACTION, C.luaPad(function()
    local tool = rd32(G.subtype)
    if K.WALL_DEFAULT[tool] == nil and tool ~= K.CRENEL_WALL then return end
    values[tool] = valueAt(tool)
    drag = true
  end, "the wall height slider"))
  -- Reset: the chosen tool builds the game's own height (or steepness) again.
  wr32(reset + ITEM_TYPE, TYPE_CLICKABLE)
  wr32(reset + ITEM_RENDER_TYPE, RENDER_NONE)
  wr32(reset + ITEM_TEXT, 0)
  wr16(reset + ITEM_CONTROL, -1)
  wr16(reset + ITEM_HIDDEN, 1)
  wr32(reset + ITEM_ACTION, C.luaPad(function()
    values[rd32(G.subtype)] = nil
    drag = false
  end, "the wall height reset"))

  local function frame()
    if rd32(G.gameMode) ~= K.MAP_EDITOR then
      values, drag = {}, false
      wr32(W.mode, 0)
      apply()
      wr16(click + ITEM_HIDDEN, 1)
      wr16(reset + ITEM_HIDDEN, 1)
      return
    end
    local tool = rd32(G.subtype)
    if drag then
      if (asyncKey(K.LEFT_BUTTON) % 0x10000) < 0x8000 then
        drag = false
      elseif K.WALL_DEFAULT[tool] ~= nil or tool == K.CRENEL_WALL then
        values[tool] = valueAt(tool)
      end
    end
    apply()
    wr16(click + ITEM_HIDDEN, 1)
    wr16(reset + ITEM_HIDDEN, 1)
    if rd32(G.activeTab) ~= K.TAB_CASTLE or (K.WALL_DEFAULT[tool] == nil and tool ~= K.CRENEL_WALL) then return end

    local value = values[tool] or default(tool)
    local label = string.format("%s %d", tool == K.STAIRS and "Steepness:" or "Wall Height:", value)
    local labelWidth = width(tool == K.STAIRS and "Steepness: 16" or "Wall Height: 255")
    local resetWidth = width(P.reset) + 2 * TOOLTIP_PADDING
    local total = TOOLTIP_PADDING + labelWidth + TOOLTIP_PADDING + P.track + TOOLTIP_PADDING + resetWidth
      + TOOLTIP_PADDING
    -- Above the wall panel when it is shown, else where it would be.
    local panel = tool == K.CRENEL_WALL and data.crenelPanel or data.wallPanel
    local panelTop = PANEL_BOTTOM - P.panelRoom
    if panel ~= nil and panel.items ~= nil and panel.items[1] ~= nil and rd16(panel.items[1] + ITEM_HIDDEN) == 0 then
      panelTop = rd32(panel.items[1] + ITEM_Y)
    end
    local bottom = panelTop - 3 * PANEL_GAP
    local top = bottom - P.height
    local menuX = rd32(B.menu + MENU_X)
    local left = math.floor((rd32(G.screenWidth) - total) / 2 - menuX + (K.PANEL_SHIFT[K.TAB_CASTLE] or 0))
    local trackX = left + TOOLTIP_PADDING + labelWidth + TOOLTIP_PADDING
    wr32(click + ITEM_X, trackX)
    wr32(click + ITEM_Y, top)
    wr32(click + ITEM_WIDTH, P.track)
    wr32(click + ITEM_HEIGHT, P.height)
    wr16(click + ITEM_HIDDEN, 0)
    local resetX = trackX + P.track + TOOLTIP_PADDING
    wr32(reset + ITEM_X, resetX)
    wr32(reset + ITEM_Y, top + 2)
    wr32(reset + ITEM_WIDTH, resetWidth)
    wr32(reset + ITEM_HEIGHT, P.height - 4)
    wr16(reset + ITEM_HIDDEN, 0)
    C.markRect(rect, left - PANEL_GAP, top - PANEL_GAP, total + 2 * PANEL_GAP, P.height + 2 * PANEL_GAP)

    local offsetX = menuX - rd32(B.menu + MENU_SCROLL) + rd32(G.cameraX)
    local offsetY = rd32(B.menu + MENU_Y) + rd32(G.cameraY)
    local white = rd32(G.pixelFormat) == 0x565 and 0xFFFF or 0x7FFF
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    roundedBox(G.pencil, offsetX + left, offsetY + top, offsetX + left + total, offsetY + bottom, BOX_BLEND)
    local middle = offsetY + top + P.height // 2
    local l = offsetX + trackX
    roundedBox(G.pencil, l, middle - P.trackHeight // 2, l + P.track, middle + P.trackHeight // 2, BOX_BLEND)
    local lo, hi = range(tool)
    local filled = l + ((value - lo) * P.track) // math.max(1, hi - lo)
    colourBox(G.pencil, l, middle - 1, filled, middle + 1, white)
    colourBox(G.pencil, filled - 2, middle - P.trackHeight // 2 - 3, filled + 2, middle + P.trackHeight // 2 + 3, white)
    local rl, rt = offsetX + resetX, offsetY + top + 2
    roundedBox(G.pencil, rl, rt, rl + resetWidth, rt + P.height - 4, BOX_BLEND)
    if rd16(reset + ITEM_HOVERED) ~= 0 then
      roundedBox(G.pencil, rl, rt, rl + resetWidth, rt + P.height - 4, BOX_BLEND)
    end
    wr32(G.pencil + PENCIL_TARGET, target)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    writeCString(buffer, label)
    shadowedText(G.textManager, buffer, offsetX + left + TOOLTIP_PADDING, middle - P.textRaise, ALIGN_LEFT,
      TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    writeCString(buffer, P.reset)
    shadowedText(G.textManager, buffer, offsetX + resetX + TOOLTIP_PADDING, middle - P.textRaise, ALIGN_LEFT,
      TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    wr32(G.textLayer, layer)
  end
  wr32(paint + ITEM_TYPE, TYPE_CLICKABLE)    -- no size, so never under the mouse
  wr32(paint + ITEM_WIDTH, 0)
  wr32(paint + ITEM_HEIGHT, 0)
  wr32(paint + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  wr32(paint + ITEM_RENDER, C.luaPad(frame, "the wall height slider"))
  wr32(paint + ITEM_TEXT, 0)
  wr16(paint + ITEM_CONTROL, -1)
  wr16(paint + ITEM_HIDDEN, 0)
end

-- Copies the build menu's item table with the module's items added, like buildTable.
function C.build(G, B, O)
  local data = { shown = core.allocate(4, true) }
  C.guardRects(data)
  local inserts = {}
  local function insert(before, kind)
    inserts[before] = inserts[before] or {}
    table.insert(inserts[before], kind)
  end
  insert(0, "guard")
  -- (switching the active keep calls the game's keep entry, which destroys the old keep unless
  -- several keeps are allowed)
  if O.keepCrests and O.severalKeeps then insert(0, "keepCrests") end
  if O.rotation then
    for i = 1, #K.ROTATIONS do insert(0, "rotation" .. i) end
    insert(0, "rotationHead")                -- after the options: drawn on top of them
  end
  if O.ruinedCathedral then insert(0, "ruinWatch") end
  if O.undo then
    insert(0, "undo")
    insert(0, "redo")
  end
  if O.compass then insert(0, "compass") end
  if O.unitColour then
    for p = 0, K.PLAYERS do insert(0, "unitColour" .. p) end
    insert(0, "unitColourPanel")
  end
  if O.buildingCounts then insert(B.firstBlock, "counts") end
  local shieldGroup, shieldEnd
  if O.playerZero then
    for i = 0, B.count - 1 do
      if shieldGroup == nil and rd32(item(B.table, i, ITEM_PARAM)) == K.SHIELD_ZERO.firstParam
          and (rd32(item(B.table, i, ITEM_TYPE)) & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_MEMBER then
        local start = i
        while start > 0 and (rd32(item(B.table, start, ITEM_TYPE)) & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_MEMBER do
          start = start - 1
        end
        local finish = i
        while finish < B.count and (rd32(item(B.table, finish, ITEM_TYPE)) & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_MEMBER do
          finish = finish + 1
        end
        if (rd32(item(B.table, start, ITEM_TYPE)) & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_START then
          shieldGroup, shieldEnd = start, finish
        end
      end
    end
    if shieldGroup == nil then
      log(WARNING, MODULE_NAME .. ": the player shields were not found; no player 0 shield")
    else
      insert(shieldGroup, "shieldZeroClick")
      insert(shieldEnd, "shieldZeroDraw")
    end
  end
  local panels = {}
  local function lookup(tab, command) return B.buttons[tab][command].image end
  if O.towerRuins then
    local row = {}
    -- Each ruin's own picture, made small like the variant panels' (the tower's button
    -- picture if that cannot be made).
    local okThumbs, thumb = pcall(C.buildingPictures, G, B)
    if not okThumbs then log(WARNING, tostring(thumb) .. "; the tower ruins show the towers' pictures") end
    for i, ruin in ipairs(K.TOWER_RUINS) do
      row[i] = { command = ruin, image = lookup(K.TAB_TOWERS, K.FIRST_TOWER + i - 1), label = K.RUIN_LABEL }
      if okThumbs then row[i].compose = function() return thumb(ruin) end end
    end
    panels[#panels + 1] = { tab = K.TAB_TOWERS, rows = { row }, shift = K.PANEL_SHIFT[K.TAB_TOWERS] }
  end
  if O.armyExtras then
    -- The tunnel entrance as the map shows it, composed from its tiles like a rock.
    local sprites = scan(K.AOB_BUILDING_SPRITES, "the building pictures")
    local convert = core.exposeCode(readCallTarget(sprites, 0, "the building types"), 2, 1)
    local firstPicture = core.exposeCode(readCallTarget(sprites, K.BUILDING_SPRITES.sprite, "the building pictures"), 2, 1)
    local tunnelGm = rd32(rd32(sprites + K.BUILDING_SPRITES.gms) + (convert(B.buildings, K.TUNNEL_COMMAND) & 0xFFFF) * 4)
    local tunnelBase = firstPicture(B.buildings, K.TUNNEL_COMMAND)
    if G.footprint == nil then resolveRocks(G) end
    local tilePicture = makeRockPictures(G)
    local tunnel = { when = K.TUNNEL_WHEN, { command = K.TUNNEL_COMMAND, label = K.TUNNEL_LABEL,
      compose = function() return tilePicture(K.TUNNEL_SIZE, tunnelBase, 0, tunnelGm, true) end } }
    local tents = { when = K.TENTS_WHEN, shift = K.TENTS_SHIFT }
    for i, tent in ipairs(K.TENTS) do
      tents[i] = { command = tent, image = lookup(K.TAB_UNIT_COMMANDS, tent) }
    end
    panels[#panels + 1] = { tab = K.TAB_ARMY, rows = { tunnel, tents } }
  end
  local resets = {}                        -- menu buttons that end a panel choice: { tab, command, flag }
  if O.variantPanels then
    -- One panel per tab, a row per building: its variants by placement id (chosen ones do not
    -- turn into the next), and on the statue and shrine rows the module's own.
    local lock = C.locks().variant
    local okThumbs, thumb = pcall(C.buildingPictures, G, B)
    if not okThumbs then
      log(WARNING, tostring(thumb) .. "; the variant panels show the menu's pictures")
      thumb = nil
    end
    local function thumbOf(command, base)
      if thumb == nil then return nil end
      return function() return thumb(command, base) end
    end
    local extraLabel = {}
    for _, statue in ipairs(K.STATUES) do extraLabel[statue[1]] = statue[3] end
    for tab, groups in pairs(K.VARIANT_ROWS) do
      local rows = {}
      for _, group in ipairs(groups) do
        local first, count = group[1], group[2]
        local row = { when = {} }
        local ids = {}
        for i = 0, count - 1 do ids[#ids + 1] = first + i end
        if O.statues then
          for _, extra in ipairs(group[3] or {}) do ids[#ids + 1] = extra end
        end
        for i, id in ipairs(ids) do
          row.when[id] = true
          row[i] = { command = id, image = lookup(tab, first), label = extraLabel[id] or tostring(i), lock = lock,
            compose = thumbOf(id) }
        end
        rows[#rows + 1] = row
        resets[#resets + 1] = { tab, first, lock }
      end
      panels[#panels + 1] = { tab = tab, rows = rows, shift = K.PANEL_SHIFT[tab], lock = lock }
    end
    -- The hovel: one of its seven variants every time, instead of the player's next one.
    local hovelLock = C.locks().hovel
    local hovelPictures = rd32(scan(K.AOB_HOVEL_PREVIEW, "the hovel pictures") + K.HOVEL_PICTURES)
    local row = {}
    for i = 1, K.HOVEL_VARIANTS do
      row[i] = { images = { [K.HOVEL_TOOL] = lookup(K.TAB_TOWN, K.HOVEL_TOOL) }, tool = K.HOVEL_TOOL,
        label = tostring(i), flag = hovelLock, value = i, compose = thumbOf(K.HOVEL_TOOL, rd32(hovelPictures + (i - 1) * 4)) }
    end
    row.when = { [K.HOVEL_TOOL] = true }
    resets[#resets + 1] = { K.TAB_TOWN, K.HOVEL_TOOL, hovelLock }
    panels[#panels + 1] = { tab = K.TAB_TOWN, rows = { row }, shift = K.PANEL_SHIFT[K.TAB_TOWN] }
  elseif O.statues then
    local row = {}
    for i, statue in ipairs(K.STATUES) do
      row[i] = { command = statue[1], image = lookup(K.TAB_GOOD, statue[2]), label = statue[3] }
    end
    panels[#panels + 1] = { tab = K.TAB_GOOD, rows = { row }, shift = K.PANEL_SHIFT[K.TAB_GOOD] }
  end
  data.keepMode = core.allocate(4, true)
  data.damagedWalls = core.allocate(4, true)
  local function choices(tab, commands, flag, labels)
    local images, when, row = {}, {}, {}
    for _, command in ipairs(commands) do
      images[command], when[command] = lookup(tab, command), true
      resets[#resets + 1] = { tab, command, flag }
    end
    row.when = when
    for _, choice in ipairs(labels) do
      row[#row + 1] = { images = images, label = choice[2], flag = flag, value = choice[1] }
    end
    panels[#panels + 1] = { tab = tab, rows = { row }, shift = K.PANEL_SHIFT[tab] }
  end
  if O.keepParts then
    choices(K.TAB_KEEPS, K.KEEPS, data.keepMode, { { K.KEEP_ONLY, K.KEEP_LABELS[K.KEEP_ONLY] },
      { K.KEEP_NO_STOCKPILE, K.KEEP_LABELS[K.KEEP_NO_STOCKPILE] } })
  end
  if O.wallTools then
    -- The crenellations get a panel of their own: low, high and both damaged.
    if O.damagedWalls then
      choices(K.TAB_CASTLE, { K.STAIRS, K.LOW_WALL, K.HIGH_WALL }, data.damagedWalls, { { 1, K.DAMAGED_LABEL } })
      data.wallPanel = panels[#panels]
    end
    local labels = {}
    for _, choice in ipairs(K.CRENEL_LABELS) do
      local damaged = choice[1] == K.CRENEL_DAMAGED or choice[1] >= K.CRENEL_LOW_DAMAGED
      if O.damagedWalls or not damaged then labels[#labels + 1] = choice end
    end
    choices(K.TAB_CASTLE, { K.CRENEL_WALL }, C.wallWords().mode, labels)
    data.crenelPanel = panels[#panels]
  elseif O.damagedWalls then
    choices(K.TAB_CASTLE, K.WALLS, data.damagedWalls, { { 1, K.DAMAGED_LABEL } })
  end
  data.ruinedCathedral = C.locks().ruined
  if O.ruinedCathedral then
    choices(K.TAB_TOWN, { K.CATHEDRAL_TOOL }, data.ruinedCathedral, { { 1, K.RUINED_LABEL } })
    -- The ruin's own picture (when tile_churches.gm1 has it).
    local okThumbs, thumb = pcall(C.buildingPictures, G, B)
    if okThumbs then
      local ruin = rd32(scan(K.AOB_RUINED_CATHEDRAL, "the ruined cathedral") + K.RUINED_CATHEDRAL.picture)
      local entry = panels[#panels].rows[1][1]
      entry.compose = function() return thumb(K.CATHEDRAL_TOOL, ruin) end
    end
    data.ruinWatch = C.ruinWatch(G)
  end
  data.moatMode = core.allocate(4, true)
  if O.moatKinds then
    -- The moat tool (chosen as 0x2D) placed dug, planned or permanent; the menu's moat button
    -- goes back to dug.
    local row = { when = { [K.MOAT_TOOL] = true } }
    local images = { [K.MOAT_TOOL] = lookup(K.TAB_GATEHOUSES, K.MOAT_BUTTON) }
    for _, kind in ipairs({ K.MOAT_DUG, K.MOAT_PLANNED, K.MOAT_PERMANENT }) do
      row[#row + 1] = { images = images, tool = K.MOAT_BUTTON, label = K.MOAT_LABELS[kind], flag = data.moatMode,
        value = kind, minWidth = K.MOAT_ENTRY_WIDTH }
    end
    resets[#resets + 1] = { K.TAB_GATEHOUSES, K.MOAT_BUTTON, data.moatMode }
    panels[#panels + 1] = { tab = K.TAB_GATEHOUSES, rows = { row }, shift = K.PANEL_SHIFT[K.TAB_GATEHOUSES] }
  end
  for p, panel in ipairs(panels) do
    local most = 0
    for _, row in ipairs(panel.rows) do most = math.max(most, #row) end
    panel.size = most
    for i = 1, most do insert(B.blockEnd[panel.tab], "panel" .. p .. "/" .. i) end
    insert(B.blockEnd[panel.tab], "painter" .. p)
  end
  if O.barrier then insert(B.blockEnd[K.TAB_RUINS], "barrier") end
  if O.wallTools then
    insert(B.blockEnd[K.TAB_CASTLE], "wallSlider")
    insert(B.blockEnd[K.TAB_CASTLE], "wallSliderReset")
    insert(B.blockEnd[K.TAB_CASTLE], "wallSliderPaint")
  end

  local total = B.count + 1
  for _, list in pairs(inserts) do total = total + #list end
  local newTable = core.allocate(total * MENU_ITEM_SIZE, true)
  local movedTo, added, slot = {}, {}, 0
  for i = 0, B.count do
    for _, kind in ipairs(inserts[i] or {}) do
      added[kind] = item(newTable, slot)
      slot = slot + 1
    end
    core.writeBytes(item(newTable, slot), core.readBytes(item(B.table, i), MENU_ITEM_SIZE))
    movedTo[i] = slot
    slot = slot + 1
  end

  local guarded, places = {}, {}
  if G.blit == nil then
    G.blit = core.allocateAssembly(templates.blit, {
      PENCIL = G.pencil, SETUP_SURFACE = G.setupSurface, SETUP_PENCIL = G.setupPencil,
      SCRATCH = core.allocate(32, true), PIXEL_FORMAT = G.pixelFormat,
    })
  end
  local GB = setmetatable({ menu = B.menu }, { __index = G })   -- G with the build menu
  -- The toolbar action takes the siege tents for an order to selected engineers: those are
  -- chosen straight away, like the game's hotkeys do.
  local direct = core.allocateAssembly(templates.directTool, {
    DIRECT = dwordList(K.TENTS), SUBTYPE = G.subtype, TOOLBAR = B.toolbar,
  })
  for p, panel in ipairs(panels) do
    panel.items = {}
    for i = 1, panel.size do
      local into = added["panel" .. p .. "/" .. i]
      local entry = panel.rows[1][i]
      local action = direct
      if panel.lock ~= nil then             -- a variant: locked, then chosen like its menu button
        action = core.allocateAssembly(templates.variantChoice, { VARIANT_LOCK = panel.lock, ACTION = B.toolbar })
      elseif #panel.rows == 1 and entry ~= nil and entry.flag ~= nil then
        action = core.allocateAssembly(templates.setChoice, { FLAG = entry.flag, VALUE = entry.value, ACTION = B.toolbar })
      end
      wr32(into + ITEM_TYPE, TYPE_CLICKABLE)
      wr32(into + ITEM_ACTION, action)
      wr32(into + ITEM_RENDER_TYPE, RENDER_NONE)
      wr16(into + ITEM_HIDDEN, 1)
      panel.items[i] = into
      guarded[#guarded + 1] = into
      guarded[#guarded + 1] = panel.tab
    end
    local paint = makePanel(GB, { counts = false }, data, panel, C.makeEntries(GB, panel, panel.rows))
    local painter = added["painter" .. p]
    wr32(painter + ITEM_TYPE, TYPE_CLICKABLE)
    wr32(painter + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(painter + ITEM_RENDER, core.allocateAssembly(templates.editorPanel, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, PANEL_ITEMS = dwordList(panel.items),
      ITEM_HIDDEN = ITEM_HIDDEN, PAD = C.luaPad(paint, "a castle panel"),
    }))
  end

  if O.buildingCounts then
    local counts = core.allocate(12, true)
    local count = core.allocateAssembly(templates.buildingCounts, {
      BUILDINGS = B.buildings, MAX_BUILDINGS = K.MAX_BUILDINGS, FIRST_STATE = B.firstState,
      BUILDING_SIZE = B.buildingSize, TYPE_FROM_STATE = B.typeFromState, OWNER_FROM_STATE = B.ownerFromState,
      REMOVED = K.BUILDING_REMOVED, PLAYER_TYPES = B.playerTypes, CURRENT_PLAYER = B.currentPlayer, COUNTS = counts,
    })
    local into = added.counts
    wr32(into + ITEM_TYPE, TYPE_CLICKABLE)    -- no size, so never under the mouse
    wr32(into + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr32(into + ITEM_RENDER, core.allocateAssembly(templates.editorOnly, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, FIRST = count,
      PAD = C.luaPad(C.makeCounts(G, B, counts), "the building counts"),
    }))
  end

  -- The barrier: a copy of the first ruin button with the barrier's command, placed in the
  -- free spot at the end of the ruins' grid once the menu has placed them.
  if O.barrier then
    local barrier = added.barrier
    local model = B.buttons[K.TAB_RUINS][K.FIRST_RUIN]
    core.writeBytes(barrier, core.readBytes(item(B.table, model.index), MENU_ITEM_SIZE))
    wr32(barrier + ITEM_X, 0)
    wr32(barrier + ITEM_Y, 0)
    wr32(barrier + ITEM_PARAM, K.BARRIER_COMMAND)
    wr32(barrier + ITEM_ACTION, B.toolbar)
    wr32(barrier + ITEM_RENDER_TYPE, RENDER_SIMPLE)
    wr16(barrier + ITEM_CONTROL, -1)
    wr16(barrier + ITEM_HIDDEN, 1)
    local draw = C.makeBarrier(G)
    wr32(barrier + ITEM_RENDER, C.luaPad(function() draw(barrier) end, "the barrier button"))
    local ruins = {}
    for _, button in pairs(B.buttons[K.TAB_RUINS]) do ruins[#ruins + 1] = item(newTable, movedTo[button.index]) end
    places[#places + 1] = function(measure)
      local width, height = measure(ruins[1])
      if width == nil then return false end
      local xs, ys, taken = {}, {}, {}
      for _, ruin in ipairs(ruins) do
        local x, y = rd32(ruin + ITEM_X), rd32(ruin + ITEM_Y)
        if (x & 0xFFFFFFFF) == PLACED_BY_CONTROL then return false end
        xs[x], ys[y], taken[x .. "/" .. y] = true, true, true
      end
      local columns, rows = {}, {}
      for x in pairs(xs) do columns[#columns + 1] = x end
      for y in pairs(ys) do rows[#rows + 1] = y end
      table.sort(columns)
      table.sort(rows)
      local y = rows[#rows]
      local x = nil
      for _, column in ipairs(columns) do
        if not taken[column .. "/" .. y] then x = column end
      end
      if x == nil then                         -- no free spot: one column further right
        x = columns[#columns] + (#columns > 1 and columns[#columns] - columns[#columns - 1] or width)
      end
      wr32(barrier + ITEM_X, x)
      wr32(barrier + ITEM_Y, y)
      wr32(barrier + ITEM_WIDTH, width)
      wr32(barrier + ITEM_HEIGHT, height)
      wr16(barrier + ITEM_HIDDEN, 0)
      return true
    end
  end

  for _, reset in ipairs(resets) do
    local button = B.buttons[reset[1]][reset[2]]
    wr32(item(newTable, movedTo[button.index], ITEM_ACTION), core.allocateAssembly(templates.rockButton, {
      ROCK_LOCK = reset[3], ACTION = button.action,
    }))
  end

  if O.undo then C.undoButtons(G, added, guarded, O.undo) end
  if added.shieldZeroClick ~= nil then C.shieldZero(G, added.shieldZeroClick, added.shieldZeroDraw) end
  if added.wallSlider ~= nil then
    local ok, problem = pcall(C.wallControls, G, B, data, added.wallSlider, added.wallSliderPaint,
      added.wallSliderReset)
    if not ok then log(WARNING, tostring(problem) .. "; no wall height slider") end
  end
  if added.compass ~= nil then
    local ok, problem = pcall(C.compassItem, G, added.compass, O.undo)
    if not ok then log(WARNING, tostring(problem) .. "; no compass") end
  end
  if added.unitColourPanel ~= nil then
    local crests = {}
    for p = 0, K.PLAYERS do crests[p] = added["unitColour" .. p] end
    local ok, problem = pcall(C.unitColours, C.owner, G, B, data, added.unitColourPanel, crests)
    if not ok then log(WARNING, tostring(problem) .. "; no unit display player") end
  end
  if added.rotationHead ~= nil then
    local options = {}
    for i = 1, #K.ROTATIONS do options[i] = added["rotation" .. i] end
    local ok, problem = pcall(C.buildingRotation, C.owner, G, B, data, added.rotationHead, options)
    if not ok then log(WARNING, tostring(problem) .. "; no building rotation") end
  end
  if added.keepCrests ~= nil then
    data.crestTooltip = O.crestTooltip
    local ok, problem = pcall(C.keepCrests, G, B, data, added.keepCrests)
    if not ok then log(WARNING, tostring(problem) .. "; no keep crests") end
  end
  if O.ruinedCathedral then
    local watch = added.ruinWatch
    wr32(watch + ITEM_TYPE, TYPE_EVERY_FRAME)
    wr32(watch + ITEM_ACTION, C.luaPad(data.ruinWatch, "the ruined cathedral"))
  end

  -- The guard in front of the click handlers, which also places the barrier.
  local laidOut = core.allocate(4, true)
  wr32(laidOut, #places == 0 and 1 or 0)
  local layout = makeLayout(G, {}, {}, {}, places)
  local layoutPad = C.luaPad(function()
    if layout() then wr32(laidOut, 1) end
  end, "the castle layout")
  local guard = added.guard
  wr32(guard + ITEM_TYPE, TYPE_EVERY_FRAME)
  wr32(guard + ITEM_ACTION, core.allocateAssembly(templates.guard, {
    LAID_OUT = laidOut, LAYOUT = layoutPad, GUARDED = dwordList(guarded),
    ACTIVE_TAB = G.activeTab, ITEM_HIDDEN = ITEM_HIDDEN, ITEM_HEIGHT = ITEM_HEIGHT,
    ITEM_WIDTH = ITEM_WIDTH, ITEM_MENU = ITEM_MENU, MENU_X = MENU_X, MENU_Y = MENU_Y, ITEM_X = ITEM_X,
    ITEM_Y = ITEM_Y, MOUSE = G.mouse, IS_MOUSE_INSIDE = G.isMouseInside, ON_MAP = G.onMap,
    RECTS = data.rects, THE_MENU = B.menu,
  }))
  return newTable, data
end

function C.signedByte(address)
  local value = rd8(address) & 0xFF
  if value >= 0x80 then value = value - 0x100 end
  return value
end

-- A lua function called from injected code: a pad that runs it, switched off after an error.
function C.luaPad(fn, what)
  local pad = core.allocateCode({ 0x90, 0x90, 0x90, 0x90, 0x90, 0xC3 })
  local broken = false
  core.detourCode(function(registers)
    if not broken then
      local ok, problem = pcall(fn)
      if not ok then
        broken = true
        log(WARNING, string.format("%s: %s stopped after an error: %s", MODULE_NAME, what, tostring(problem)))
      end
    end
    return registers
  end, pad, 5)
  return pad
end

-- Replaces the call at site with a call to stub, remembering it for disable.
function C.patchCall(self, site, stub)
  self.saved = self.saved or {}
  table.insert(self.saved, { address = site, bytes = core.readBytes(site, 5) })
  core.writeCode(site, { 0xE8, core.itob(core.getRelativeAddress(site, stub, -5)) })
end

-- In the map editor, any number of empty stockpiles, granaries and armouries.
function C.patchEmptyStorage(self, G)
  local E = K.EMPTY_STORAGE
  local sites, from = {}, 0x400000
  while #sites <= E.sites do
    local ok, found = pcall(core.scanForAOB, K.AOB_EMPTY_STORAGE, from, K.HERD_SEARCH_END)
    if not ok or found == nil or found == 0 then break end
    sites[#sites + 1] = found
    from = found + 1
  end
  if #sites ~= E.sites then error(MODULE_NAME .. ": the empty storage limits are not the ones this module knows") end
  for _, base in ipairs(sites) do
    local site = base + E.site
    patchJump(self, site, E.size, core.allocateAssembly(templates.storageLimit, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, LIMIT = rd8(base + E.limit) & 0xFF,
      FAIL = base + E.failRel + 4 + rd32(base + E.failRel), BACK = site + E.size,
    }))
  end
end

-- In the map editor, a player's new keep (and unique buildings: barracks, guilds, ...) no longer
-- destroys the earlier one, and further storage buildings need not touch the first.
function C.patchSeveralBuildings(self, G, O)
  local start = scan(K.AOB_EARLIER_BUILDING, "the earlier building removal")
  local calls, from = {}, start
  while #calls < 3 do
    local ok, found = pcall(core.scanForAOB, K.EARLIER_DESTROY, from, start + K.EARLIER_SEARCH)
    if not ok or found == nil or found == 0 then break end
    calls[#calls + 1] = found + K.EARLIER_DESTROY_CALL
    from = found + 1
  end
  if #calls ~= 3 then error(MODULE_NAME .. ": the earlier building removal is not the one this module knows") end
  local stub = core.allocateAssembly(templates.keepEarlier, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, DESTROY = readCallTarget(calls[1], 0, "destroyBuilding"),
    DESTROY_ARGUMENTS = K.DESTROY_ARGUMENTS,
  })
  local which = {}
  if O.severalKeeps then for _, i in ipairs(K.EARLIER_KEEP_CALLS) do which[#which + 1] = i end end
  if O.looseBuildings then for _, i in ipairs(K.EARLIER_UNIQUE_CALLS) do which[#which + 1] = i end end
  for _, i in ipairs(which) do C.patchCall(self, calls[i], stub) end
  if O.looseBuildings then
    local sites = {}
    for i, pattern in ipairs(K.AOB_STORAGE_NEIGHBOURS) do
      sites[i] = scan(pattern, "the storage placement test") + K.STORAGE_NEIGHBOUR_CALL
    end
    local neighbour = core.allocateAssembly(templates.anyNeighbour, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, HAS_NEIGHBOUR = readCallTarget(sites[1], 0, "the neighbour test"),
      NEIGHBOUR_ARGUMENTS = K.NEIGHBOUR_ARGUMENTS,
    })
    for _, site in ipairs(sites) do C.patchCall(self, site, neighbour) end
  end
end

-- In the map editor the tower mangonel and ballista can also be put on any tile without a unit
-- (ground, walls, gates, other towers, the keep): the click sends the game's own spawn command
-- for the clicked tile instead of refusing. The player's own big towers work as before.
-- Where a tower engine may go in the map editor, for the tile in rule.tile: 0 nowhere, 1 on
-- this very tile, 2 by the game's own tower rule (the current player's big towers).
function C.towerEngineRule(G, site)
  local T = K.TOWER_ENGINE
  local R = C.resolvePipette(G)
  local function operand(field) return readOperand(site, T[field], "the tower engine placement") end
  local types, owners, size = operand("types"), operand("owners"), operand("buildingSize")
  local base = types - K.BUILDING.type
  local player, units = operand("player"), operand("units")
  local onTile = readOperand(scan(K.AOB_TOWER_ENGINE_PREVIEW, "the tower engine preview"), { -0x0B, { 0x45 } },
    "the tower engine preview")
  expectBytes(site + K.TOWER_PREVIEW.flags[1], K.TOWER_PREVIEW.flags[2], "the tower engine placement")
  local flags = rd32(site + K.TOWER_PREVIEW.flags[1] + #K.TOWER_PREVIEW.flags[2])
  local mask = rd32(scan(K.AOB_UNIT_MASK, "the unit tool's tile test") + K.UNIT_MASK)
  local walk = scan(K.AOB_UNIT_WALK, "the units on a tile")   -- the eraser may have patched the middle
  local stride, nextOnTile = rd32(walk + K.UNIT_WALK.stride), rd32(walk + K.UNIT_WALK.next)
  local status = nextOnTile - K.UNIT_WALK.nextAfterState
  local rule = { tile = core.allocate(4, true), answer = core.allocate(4, true) }
  local function engines(tile)
    local count, id, guard = 0, rd16(units + tile * 2), 0
    while id > 0 and guard < 200 do
      if K.TOWER_ENGINE_UNITS[rd16(status + K.UNIT_TYPE_AFTER_STATE + id * stride) & 0xFFFF] then count = count + 1 end
      id, guard = rd16(nextOnTile + id * stride), guard + 1
    end
    return count
  end
  local function decide(tile)
    if tile < 0 or tile >= K.MAP_TILES or engines(tile) > 0 then return 0 end
    local b = rd16(onTile + tile * 2)
    if b > 0 then
      local at = base + b * size
      local kind = rd16(at + K.BUILDING.type) & 0xFFFF
      if (kind == K.TOWER_4 or kind == K.TOWER_5) and rd16(at + K.BUILDING.owner) == rd32(player) then return 2 end
    end
    if (rd32(flags + tile * 4) & mask) ~= 0 then return 0 end
    if b <= 0 then return 1 end
    local at = base + b * size
    local most = K.TOWER_ENGINE_MOST[rd16(at + K.BUILDING.type) & 0xFFFF] or 1
    local x0, y0, side = rd16(at + K.BUILDING.x), rd16(at + K.BUILDING.y), rd8(at + K.BUILDING.size) & 0xFF
    local count = 0
    for y = math.max(0, y0 - 1), math.min(K.MAP_SIZE - 1, y0 + side) do
      for x = math.max(0, x0 - 1), math.min(K.MAP_SIZE - 1, x0 + side) do
        local t = rd32(R.rows + y * 12) + x
        if rd16(onTile + t * 2) == b then count = count + engines(t) end
      end
    end
    return count < most and 1 or 0
  end
  rule.pad = C.luaPad(function() wr32(rule.answer, decide(rd32(rule.tile))) end, "the tower engine placement")
  return rule
end

-- Tower engines anywhere in the map editor where a unit could stand, one to a tile, on the
-- clicked tile, with up to K.TOWER_ENGINE_MOST on keeps and large gatehouses; the preview is
-- solid wherever a click would place one.
function C.patchTowerEngines(self, G)
  local T = K.TOWER_ENGINE
  local function all(pattern)
    local from, sites = 0x400000, {}
    while #sites < 3 do
      local ok, found = pcall(core.scanForAOB, pattern, from, K.HERD_SEARCH_END)
      if not ok or found == nil or found == 0 then break end
      sites[#sites + 1] = found
      from = found + 1
    end
    return sites
  end
  local sites, previews = all(K.AOB_TOWER_ENGINE_CLICK), all(K.AOB_TOWER_ENGINE_PREVIEW)
  if #sites ~= 2 or #previews ~= 2 then
    error(MODULE_NAME .. ": the tower engine placement is not the one this module knows")
  end
  local rule = C.towerEngineRule(G, sites[1])
  local busy = scan(K.AOB_ENGINE_BUSY, "the tower engine spawn command") + K.ENGINE_BUSY.site
  local EB = K.ENGINE_BUSY
  patchJump(self, busy, EB.size, core.allocateAssembly(templates.towerEngineBusy, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, HAS_ENGINE = rd32(busy + EB.field),
    BUSY = busy + EB.size + rd32(busy + EB.jump), BACK = busy + EB.size,
  }))
  for i, site in ipairs(sites) do
    local function operand(field) return readOperand(site, T[field], "the tower engine placement") end
    expectBytes(site + T.refuse[1] - 2, T.refuse[2], "the tower engine placement")
    expectBytes(site + T.command[1], T.command[2], "the tower engine placement")
    local stub = core.allocateAssembly(templates.towerEngineGround, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, TILE = rule.tile, ANSWER = rule.answer, RULE = rule.pad,
      HEIGHTS = operand("heights"),
      PARAM0 = operand("param0"), PARAM1 = operand("param1"), PARAM2 = operand("param2"),
      PARAM3 = operand("param3"), UNIT_TYPE = rd32(site + T.param3[1] + 6),
      COMMAND = rd8(site + T.command[1] + 1) & 0xFF, SYNC = operand("sync"),
      QUEUE = readCallTarget(site, T.queue, "the command queue"), EPILOGUE = site + T.epilogue,
      TOWER_PATH = site + T.size, REFUSE = site + T.size + rd32(site + 4),
    })
    patchJump(self, site, T.size, stub)
    local preview, P = previews[i], K.TOWER_PREVIEW
    expectBytes(preview + P.solid[1], P.solid[2], "the tower engine preview")
    expectBytes(preview + P.clear[1], P.clear[2], "the tower engine preview")
    patchJump(self, preview, P.size, core.allocateAssembly(templates.towerEnginePreview, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, TILE = rule.tile, ANSWER = rule.answer, RULE = rule.pad,
      BUILDING_SIZE = operand("buildingSize"), OPAQUE = preview + P.solid[1], TRANSPARENT = preview + P.clear[1],
      BACK = preview + P.size,
    }))
  end
end

-- The building orientation and the words the frame hook reads to put it back outside the editor.
function C.rotationState(G)
  if C.rotation ~= nil then return C.rotation end
  local address = rd32(scan(K.AOB_ORIENTATION, "the building orientation") + K.ORIENTATION)
  local Q = { address = address, on = core.allocate(4, true), default = core.allocate(4, true),
    choice = core.allocate(4, true), wanted = core.allocate(4, true),
    site = scan(K.AOB_ORIENTATION, "the building orientation") + K.ORIENTATION - 1 }
  wr32(Q.default, rd32(address))
  C.rotation = Q
  return Q
end

-- The rotation list in the castle menu (head: the box showing the choice, options: one item each)
-- and, every frame in the map editor while the castle menu is up, the building orientation it
-- asks for (Location based: as the keep would turn at the start of a match, from the tile under
-- the mouse). Outside the editor the frame hook puts the game's own back.
function C.buildingRotation(self, G, B, data, head, options)
  local Q = C.rotationState(G)
  local R = C.resolvePipette(G)
  local turn = scan(K.AOB_KEEP_TURN, "the keep's turn at the start of a match")
  local direction = rd32(turn + K.KEEP_TURN.this)
  local towards = core.exposeCode(readCallTarget(turn, K.KEEP_TURN.call, "the direction"), 5, 1)
  local result = rd32(turn + K.KEEP_TURN.result)
  local mouseSetup, flatSetup = core.exposeCode(R.mouseSetup, 1, 1), core.exposeCode(R.flatSetup, 1, 1)
  local placeRotation = R.tileMap + rd32(scan(K.AOB_PLACE_ROTATION, "the placement rotation") + K.PLACE_ROTATION)
  local chosenTool = rd32(scan(K.AOB_CHOSEN_TOOL, "the chosen building") + 2)
  local typeSite = scan(K.AOB_TOOL_TYPE, "the building types")
  local buildings = rd32(typeSite + K.TOOL_TYPE.this)
  local typeOf = core.exposeCode(readCallTarget(typeSite, K.TOOL_TYPE.call, "the building types"), 2, 1)
  local function turns()
    local tool = rd32(chosenTool)
    if tool <= 0 or tool > 0x200 then return false end
    return K.ROTATING_TYPES[typeOf(buildings, tool) & 0xFFFF] == true
  end
  -- the keep's preview: its parts where the chosen orientation puts them
  do
    local KT = K.KEEP_TABLES
    local previewSite = scan(K.AOB_PREVIEW_CALL, "the building preview") + KT.call
    local ok, problem = pcall(function()
      C.patchCall(self, previewSite, core.allocateAssembly(templates.keepPreviewTurn, {
        GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, ROTATION = placeRotation,
        PREVIEW = readCallTarget(previewSite, 0, "the building preview"),
        TABLE_A = rd32(scan(K.AOB_KEEP_TABLE_A, "the keep layout") + KT.a),
        TABLE_B = rd32(scan(K.AOB_KEEP_CAMPFIRE, "the keep's campfire area") + KT.b),
        TABLE_C = rd32(scan(K.AOB_KEEP_STOCKPILE, "the keep's stockpile") + KT.c),
        KEEP_ROWS = KT.rows,
      }))
    end)
    if not ok then log(WARNING, tostring(problem) .. "; the keep's preview keeps its first orientation") end
  end
  if not C.frameHooked then
    local site = scan(K.AOB_FRAME, "the map drawing") + K.FRAME.site
    expectBytes(site, { 0x8B, 0x0D }, "the map drawing")
    patchJump(self, site, K.FRAME.size, core.allocateAssembly(templates.rotationFrame, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, ROTATION_ON = Q.on, ROTATION_DEFAULT = Q.default,
      ORIENTATION = Q.address, OPERAND = rd32(site + 2), BACK = site + K.FRAME.size,
    }))
    C.frameHooked = true
  end
  wr32(Q.on, 1)
  -- the click itself takes the list's orientation (whatever else sets the game's word)
  expectBytes(Q.site, { 0xA1 }, "the building orientation")
  patchJump(self, Q.site, 5, core.allocateAssembly(templates.rotationRead, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, ROTATION_ON = Q.on, WANTED = Q.wanted,
    ORIENTATION = Q.address, BACK = Q.site + 5,
    PAD = C.luaPad(function()
      log(INFO, string.format("%s: placing a building with orientation %d", MODULE_NAME, rd32(Q.wanted)))
    end, "the rotation log"),
  }))
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local colourBox = core.exposeCode(G.colourBox, 6, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local text = core.allocate(64, true)
  local open = false
  local editorRotation = false
  local rect = C.takeRect(data)            -- clicks on the list do not reach the map
  local function location()
    if rd32(R.flatView) ~= 0 then flatSetup(R.viewport) else mouseSetup(R.viewport) end
    local x, y = rd32(R.mouseX), rd32(R.mouseY)
    if x < 0 or y < 0 or x >= K.MAP_SIZE or y >= K.MAP_SIZE then return nil end
    towards(direction, x, y, K.MAP_CENTRE, K.MAP_CENTRE)
    local o = rd32(result) & 0xFFFE
    if o == 6 then o = 2 elseif o == 2 then o = 6 end
    return o
  end
  local function orientation()
    local entry = K.ROTATIONS[rd32(Q.choice) + 1]
    if entry == nil or entry[2] == nil then return rd32(Q.default) end
    if entry[2] == "location" then return location() or rd32(Q.default) end
    return entry[2]
  end
  local box = K.ROTATION_BOX
  local function write(str, x, y)
    writeCString(text, str)
    shadowedText(G.textManager, text, x, y, ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
  end
  local function draw()
    if rd32(R.gameMode) ~= K.MAP_EDITOR then
      if editorRotation then                 -- the game's own preview again
        wr32(placeRotation, 0)
        editorRotation = false
      end
      wr32(head + ITEM_WIDTH, 0)             -- stays drawn (and so able to come back), never clicked
      for _, o in ipairs(options) do wr16(o + ITEM_HIDDEN, 1) end
      open = false
      C.markRect(rect, 0, 0, 0, 0)
      return
    end
    wr32(head + ITEM_WIDTH, box.width)
    local listHeight = open and #K.ROTATIONS * box.option or 0
    C.markRect(rect, box.x, box.y - listHeight, box.width, box.height + listHeight)
    for _, o in ipairs(options) do wr16(o + ITEM_HIDDEN, open and 0 or 1) end
    local o = turns() and orientation() or rd32(Q.default)   -- other buildings keep their look
    wr32(Q.address, o)
    wr32(Q.wanted, o)
    -- the cursor preview turns with it (placeBuilding sets the same from the orientation)
    wr32(placeRotation, (o == 0xF) and 0 or (o // 2))
    editorRotation = true
    local ox = rd32(B.menu + MENU_X) + rd32(G.cameraX)
    local oy = rd32(B.menu + MENU_Y) + rd32(G.cameraY)
    local white = rd32(G.pixelFormat) == 0x565 and 0xFFFF or 0x7FFF
    local function frame(l, t, r, b)
      colourBox(G.pencil, l, t, r, t + 1, white)
      colourBox(G.pencil, l, b - 1, r, b, white)
      colourBox(G.pencil, l, t, l + 1, b, white)
      colourBox(G.pencil, r - 1, t, r, b, white)
    end
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    local l, t = ox + box.x, oy + box.y
    roundedBox(G.pencil, l, t, l + box.width, t + box.height, BOX_BLEND)
    frame(l, t, l + box.width, t + box.height)
    local listTop = t - #K.ROTATIONS * box.option
    if open then
      roundedBox(G.pencil, l, listTop, l + box.width, t, BOX_BLEND)
      for i, o in ipairs(options) do
        local ot = listTop + (i - 1) * box.option
        if rd16(o + ITEM_HOVERED) ~= 0 then roundedBox(G.pencil, l, ot, l + box.width, ot + box.option, BOX_BLEND) end
        if i == rd32(Q.choice) + 1 then frame(l, ot, l + box.width, ot + box.option) end
      end
    end
    wr32(G.pencil + PENCIL_TARGET, target)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    local entry = K.ROTATIONS[rd32(Q.choice) + 1] or K.ROTATIONS[1]
    write("Rotation: " .. entry[1], l + TOOLTIP_PADDING, t + (box.height - TOOLTIP_LINE) // 2 + 2)
    write("v", l + box.width - TOOLTIP_PADDING - 6, t + (box.height - TOOLTIP_LINE) // 2 + 2)
    if open then
      for i, option in ipairs(K.ROTATIONS) do
        write(option[1], l + TOOLTIP_PADDING, listTop + (i - 1) * box.option + (box.option - TOOLTIP_LINE) // 2 + 2)
      end
    end
    wr32(G.textLayer, layer)
  end
  C.luaItem(head, box.x, box.y, box.width, box.height, function() open = not open end, draw, "the rotation list")
  wr16(head + ITEM_HIDDEN, 0)              -- a hidden item is not drawn, so it could never show itself
  for i, o in ipairs(options) do
    C.luaItem(o, box.x, box.y - (#K.ROTATIONS - i + 1) * box.option, box.width, box.option, function()
      wr32(Q.choice, i - 1)
      open = false
      log(INFO, string.format("%s: building rotation %s (orientation now %d)", MODULE_NAME,
        (K.ROTATIONS[i][1]:gsub("\xB0", " degrees")), orientation()))
    end, nil, "the rotation list")
    wr16(o + ITEM_HIDDEN, 1)
  end
end

-- Ctrl + the compass of the right-click ring turns the map counter-clockwise.
function C.patchCompassTurn(self, G)
  local R = C.resolvePipette(G)
  local current = R.tileMap + K.TILE_MAP.orientation
  local setRotation = nil
  for _, entry in ipairs(K.AOB_COMPASS_TURN) do
    local site = scan(entry[1], "the compass of the right-click ring") + K.COMPASS_TURN_SITE
    local target = readCallTarget(site, entry[3] + 6, "setMapRotation")
    if setRotation ~= nil and target ~= setRotation then
      error(MODULE_NAME .. ": the compass does not turn the map the way this module knows")
    end
    setRotation = target
    patchJump(self, site, entry[3], core.allocateAssembly(templates[entry[2]], {
      IMPORT = R.keyState, NEXT = rd32(site + entry[3] - 4), CURRENT = current, BACK = site + entry[3],
    }))
  end
end

-- The compass of the right-click ring, always shown in the map editor below the undo buttons
-- (at the undo buttons' place without them): an item drawn every frame, never under the mouse.
function C.compassItem(G, at, undo)
  local R = C.resolvePipette(G)
  local renderGM = core.exposeCode(G.renderGM, 5, 1)
  local site = scan(K.AOB_COMPASS_DRAW, "the compass picture")
  local first, gm = rd8(site + K.COMPASS_DRAW.first) & 0xFF, rd8(site + K.COMPASS_DRAW.gm) & 0xFF
  local orientation = R.tileMap + K.TILE_MAP.orientation
  wr32(at + ITEM_TYPE, TYPE_CLICKABLE)
  wr32(at + ITEM_WIDTH, 0)
  wr32(at + ITEM_HEIGHT, 0)
  wr32(at + ITEM_RENDER_TYPE, RENDER_SIMPLE)
  wr32(at + ITEM_TEXT, 0)
  wr16(at + ITEM_CONTROL, -1)
  wr16(at + ITEM_HIDDEN, 0)
  wr32(at + ITEM_RENDER, C.luaPad(function()
    if rd32(R.gameMode) ~= K.MAP_EDITOR then return end
    local index = K.COMPASS_PICTURE[rd32(orientation)]
    if index == nil then return end
    local top = K.UNDO_BUTTONS.top
    if undo ~= nil and undo.pictures ~= nil then
      top = top + math.max(undo.pictures.undo.height, undo.pictures.redo.height) + K.UNDO_BUTTONS.gap
    end
    local t = G.textures
    local mode = rd32(t + TEXTURES_MODE)
    wr32(t + TEXTURES_MODE, MAP_LAYER)
    renderGM(t, gm, first + index, K.UNDO_BUTTONS.left + rd32(G.cameraX), top + rd32(G.cameraY))
    wr32(t + TEXTURES_MODE, mode)
  end, "the compass"))
end

-- The unit display player (46.1): a panel above the castle menu's unit tabs with a crest per
-- player 0..8; new units placed in the map editor are drawn in the chosen player's colours. It
-- follows the current player whenever that changes.
function C.unitColours(self, G, B, data, panel, crests)
  local R = C.resolvePipette(G)
  local site = scan(K.AOB_UNIT_COLOUR, "the unit placement") + K.UNIT_COLOUR.site
  local click = scan(K.AOB_TOWER_ENGINE_CLICK, "the current player")
  local player = readOperand(click, K.TOWER_ENGINE.player, "the current player")
  local colour = core.allocate(4, true)
  wr32(colour, rd32(player))
  -- read before the patch below overwrites these bytes
  local units = rd32(site + K.UNIT_COLOUR.units)
  patchJump(self, site, K.UNIT_COLOUR.size, core.allocateAssembly(templates.unitColour, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, COLOUR = colour,
    UNITS = units, BACK = site + K.UNIT_COLOUR.size,
  }))
  data.unitColour = colour
  -- the castle's unit tools place their units as a group
  local from, groups = 0x400000, 0
  while groups < K.GROUP_COLOUR.sites do
    local ok, found = pcall(core.scanForAOB, K.AOB_GROUP_COLOUR, from, K.HERD_SEARCH_END)
    if not ok or found == nil or found == 0 then break end
    local at = found + K.GROUP_COLOUR.site
    patchJump(self, at, K.GROUP_COLOUR.size, core.allocateAssembly(templates.unitColourEdi, {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, COLOUR = colour,
      UNITS = rd32(at + K.GROUP_COLOUR.units), BACK = at + K.GROUP_COLOUR.size,
    }))
    groups, from = groups + 1, found + 1
  end
  if groups ~= K.GROUP_COLOUR.sites then log(WARNING, MODULE_NAME .. ": groups of units keep the player's colours") end
  -- The crest pictures, as the keep crests take them from the player shields.
  local crest = {}
  for i = 0, B.count - 1 do
    local p = -9 - rd32(item(B.table, i, ITEM_PARAM))
    if p >= 1 and p <= K.PLAYERS and crest[p] == nil
        and (rd32(item(B.table, i, ITEM_TYPE)) & TYPE_GROUP_MEMBER_MASK) == TYPE_GROUP_MEMBER
        and rd32(item(B.table, i, ITEM_RENDER_TYPE)) == RENDER_IMAGE then
      local image = G.buttonImages + (rd32(item(B.table, i, ITEM_IMAGE)) & IMAGE_INDEX_MASK) * IMAGE_SIZE
      crest[p] = { gm = rd32(image), picture = rd32(image + 4) }
    end
  end
  local zero = buttonPictures("shield0")
  local w, h = zero.width, zero.height
  local renderGM = core.exposeCode(G.renderGM, 5, 1)
  local blit = core.exposeCode(G.blit or core.allocateAssembly(templates.blit, {
    PENCIL = G.pencil, SETUP_SURFACE = G.setupSurface, SETUP_PENCIL = G.setupPencil,
    SCRATCH = core.allocate(32, true), PIXEL_FORMAT = G.pixelFormat,
  }), 3, 0)
  local roundedBox = core.exposeCode(G.roundedBox, 6, 1)
  local textWidth = core.exposeCode(G.textWidth, 4, 1)
  local shadowedText = core.exposeCode(G.shadowedText, 10, 1)
  local text = core.allocate(64, true)
  writeCString(text, K.UNIT_COLOUR_PANEL.label)
  local labelWidth = textWidth(G.textManager, text, #K.UNIT_COLOUR_PANEL.label, TOOLTIP_FONT)
  local P = K.UNIT_COLOUR_PANEL
  local width = 2 * TOOLTIP_PADDING + labelWidth + TOOLTIP_PADDING + (K.PLAYERS + 1) * (w + P.gap) - P.gap
  local height = h + 2 * TOOLTIP_PADDING
  local top = PANEL_BOTTOM - P.above - height       -- above the building counts
  local rect = C.takeRect(data)
  local lastPlayer = rd32(player)
  for p = 0, K.PLAYERS do
    local x = P.x + 2 * TOOLTIP_PADDING + labelWidth + p * (w + P.gap)
    C.luaItem(crests[p], x, top + TOOLTIP_PADDING, w, h, function() wr32(colour, p) end, nil, "the unit display player")
    wr16(crests[p] + ITEM_HIDDEN, 1)
  end
  -- Selected units: the current player's (1-8) selection takes the panel over; a crest then
  -- recolours them.
  local walk = scan(K.AOB_UNIT_WALK, "the units")
  local SEL = K.SELECTION
  local stride = rd32(walk + K.UNIT_WALK.stride)
  local first = rd32(walk + K.UNIT_WALK.next) - K.UNIT_WALK.nextAfterState - SEL.state   -- unit 0
  local selectedColour = nil
  -- In the unit tabs the crests always choose the colour of new units; elsewhere a selection of
  -- the current player's units (1-8) takes them over.
  local function selecting()
    if K.UNIT_TABS[rd32(G.activeTab)] then return false end
    local p = rd32(player)
    return p >= 1 and p <= K.PLAYERS and rd32(units + SEL.counts + p * 4) > 0
  end
  local function eachSelected(fn)
    local p = rd32(player)
    for id = 1, rd32(units) - 1 do
      local u = first + id * stride
      if rd16(u + SEL.state) == SEL.alive and rd16(u + SEL.selectedBy) == p then fn(u) end
    end
  end
  for p = 0, K.PLAYERS do
    wr32(crests[p] + ITEM_ACTION, C.luaPad(function()
      if selecting() then
        eachSelected(function(u) wr16(u + SEL.colour, p) end)
        selectedColour = p
      else
        wr32(colour, p)
      end
    end, "the unit display player"))
  end
  local lastCount = -1
  local function shown()
    if rd32(R.gameMode) ~= K.MAP_EDITOR then return false end
    if selecting() then
      local count = rd32(units + SEL.counts + rd32(player) * 4)
      if count ~= lastCount then          -- a new selection: show the colour its first unit has
        lastCount, selectedColour = count, nil
        eachSelected(function(u) if selectedColour == nil then selectedColour = rd16(u + SEL.colour) end end)
      end
      return true
    end
    lastCount = -1
    return K.UNIT_TABS[rd32(G.activeTab)] == true
  end
  C.luaItem(panel, 0, 0, 0, 0, nil, function()
    -- a new current player brings the choice along
    local now = rd32(player)
    if now ~= lastPlayer then
      lastPlayer = now
      wr32(colour, now)
    end
    if not shown() then
      C.markRect(rect, 0, 0, 0, 0)
      for p = 0, K.PLAYERS do wr16(crests[p] + ITEM_HIDDEN, 1) end
      return
    end
    for p = 0, K.PLAYERS do wr16(crests[p] + ITEM_HIDDEN, 0) end
    C.markRect(rect, P.x, top, width, height)
    local ox = rd32(B.menu + MENU_X) + rd32(G.cameraX)
    local oy = rd32(B.menu + MENU_Y) + rd32(G.cameraY)
    local target = rd32(G.pencil + PENCIL_TARGET)
    wr32(G.pencil + PENCIL_TARGET, MAP_LAYER)
    roundedBox(G.pencil, ox + P.x, oy + top, ox + P.x + width, oy + top + height, BOX_BLEND)
    local t = G.textures
    local mode = rd32(t + TEXTURES_MODE)
    wr32(t + TEXTURES_MODE, MAP_LAYER)
    local chosen = rd32(colour)
    if selecting() then chosen = selectedColour or -1 end
    for p = 0, K.PLAYERS do
      local sx, sy = ox + rd32(crests[p] + ITEM_X), oy + rd32(crests[p] + ITEM_Y)
      if p == 0 then
        blit(chosen == 0 and zero.chosen or zero.normal, sx, sy)
      elseif crest[p] ~= nil then
        renderGM(t, crest[p].gm, crest[p].picture + (chosen == p and K.CREST.selected or 0), sx, sy)
      end
    end
    wr32(t + TEXTURES_MODE, mode)
    wr32(G.pencil + PENCIL_TARGET, target)
    local layer = rd32(G.textLayer)
    wr32(G.textLayer, MAP_LAYER)
    writeCString(text, selecting() and P.selectedLabel or P.label)
    shadowedText(G.textManager, text, ox + P.x + TOOLTIP_PADDING, oy + top + (height - TOOLTIP_LINE) // 2 + 2,
      ALIGN_LEFT, TOOLTIP_COLOUR, 0, TOOLTIP_FONT, 0, 0)
    wr32(G.textLayer, layer)
  end, "the unit display player")
  wr16(panel + ITEM_HIDDEN, 0)
end

-- The game mode word, from G or found again (the landscape menu's G may not have it).
function C.gameModeOf(G)
  if G.gameMode == nil then G.gameMode = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND) end
  return G.gameMode
end

-- 47.1: a smaller map size takes the cut-off tiles away at once (no reload needed).
function C.patchSizeRefresh(self, G)
  local load = scan(K.AOB_VIEWPORT_LOAD, "the map load's viewport setup")
  local V = K.VIEWPORT_LOAD
  local site = scan(K.AOB_SIZE_TAIL, "the map size change") + K.SIZE_TAIL.site
  local sizeSite = scan(K.AOB_SIZE_WORD, "the map size")
  local sizeWord = rd32(sizeSite + K.SIZE_WORD)
  expectBytes(site, { 0xB9 }, "the map size change")
  patchJump(self, site, K.SIZE_TAIL.size, core.allocateAssembly(templates.sizeRefresh, {
    GAME_MODE = C.gameModeOf(G), MAP_EDITOR = K.MAP_EDITOR, VIEWPORT = rd32(load + V.viewport),
    BUILD = readCallTarget(load, V.build, "the viewport's tile map"),
    TWEAK = readCallTarget(load, V.tweak, "the viewport's border tiles"),
    BOUNDS = readCallTarget(load, V.bounds, "the camera bounds"),
    TILEMAP = rd32(site - K.SIZE_TAIL.site + 1), SIZE_WORD = sizeWord,
    -- resetHeightAndMapBorders: the size action calls it, then resetAreaBasedOnLogicalLayer
    -- empties every border tile and clears its flags as well; flagged again, the tiles turn off
    -- below and are drawn black, as after loading the map.
    BORDERS = readCallTarget(sizeSite, K.SIZE_WORD + 4, "the map borders"),
    CHANGED = readCallTarget(scan(K.AOB_ALL_CHANGED, "the map redraw"), K.ALL_CHANGED, "the map redraw"),
    PAD = C.luaPad(function()
      -- every tile the resize marked as border (0x10 / 0x20) is off, whatever the tweak did
      local R = C.resolvePipette(G)
      local T, on, flagged = R.tileMap, 0, 0
      for y = 0, K.MAP_SIZE - 1 do
        local row = rd32(R.rows + y * 12)
        for x = 0, K.MAP_SIZE - 1 do
          local at = R.validTiles + y * K.MAP_SIZE + x
          if rd8(at) ~= 0 then
            if (rd32(T + R.logic + (row + x) * 4) & K.MAP_BORDER) ~= 0 then
              core.writeByte(at, 0)
              flagged = flagged + 1
            else
              on = on + 1
            end
          end
        end
      end
      log(INFO, string.format("%s: map size %d: %d tiles on, %d border tiles turned off", MODULE_NAME,
        rd32(sizeWord), on, flagged))
    end, "the map size change"),
    AFTER_THIS = rd32(site + 1), BACK = site + K.SIZE_TAIL.size,
  }))
end

-- 47.2: the map editor's camera goes one tile further on every side, so the edge tiles show whole.
function C.patchCameraEdge(self, G)
  local site = scan(K.AOB_CAMERA_CLAMP, "the camera bounds")
  patchJump(self, site, K.CAMERA_CLAMP.size, core.allocateAssembly(templates.cameraEdge, {
    GAME_MODE = C.gameModeOf(G), MAP_EDITOR = K.MAP_EDITOR, TILE_X = K.CAMERA_EDGE.x, TILE_Y = K.CAMERA_EDGE.y,
    BACK = site + K.CAMERA_CLAMP.size,
  }))
end

-- Keeps leave the ground as it is in the map editor: placeKeep's two calls of the ground painter
-- (keep tiles: earth and stones 6 around, or thick scrub 3 around on scrub and oasis grass; the
-- campfire area likewise) do nothing there.
function C.patchKeepGround(self, G)
  local stub = core.allocateAssembly(templates.keepGround, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR,
    PAINT = readCallTarget(scan(K.AOB_KEEP_GROUND[1], "the keep's ground painting"), K.KEEP_GROUND_CALL, "the ground painter"),
  })
  for _, pattern in ipairs(K.AOB_KEEP_GROUND) do
    local site = scan(pattern, "the keep's ground painting") + K.KEEP_GROUND_CALL
    C.patchCall(self, site, stub)
  end
end

-- The keep panel's choices: in the map editor placeKeep stops after the keep and its doors
-- (keep only) or before the stockpile.
function C.patchKeepParts(self, G, data)
  local campfire = scan(K.AOB_KEEP_CAMPFIRE, "the keep's campfire area")
  local stockpile = scan(K.AOB_KEEP_STOCKPILE, "the keep's stockpile")
  local epilogue = stockpile + K.KEEP_EPILOGUE[1]
  expectBytes(epilogue, K.KEEP_EPILOGUE[2], "the end of placeKeep")
  local function stop(site, size, modes, replay)
    patchJump(self, site, size, core.allocateAssembly(templates.keepPart .. replay .. "\njmp BACK\n", {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, KEEP_MODE = data.keepMode, FIRST_MODE = modes[1],
      SECOND_MODE = modes[2] or modes[1], EPILOGUE = epilogue, BACK = site + size, TABLE = rd32(site + 7),
    }))
  end
  stop(campfire, K.KEEP_CAMPFIRE_SIZE, { K.KEEP_ONLY }, "mov eax,[esp+0x3C]\nmov ecx,[esp+0x48]")
  stop(stockpile, K.KEEP_STOCKPILE_SIZE, { K.KEEP_ONLY, K.KEEP_NO_STOCKPILE }, "mov eax,[esp+0x3C]\nmov edi,[eax*8+TABLE]")

  -- The placement check and the preview leave out the same parts.
  local function leaveOut(site, size, modes, replay, done, table)
    patchJump(self, site, size, core.allocateAssembly(templates.keepPart .. replay .. "\njmp BACK\n", {
      GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, KEEP_MODE = data.keepMode, FIRST_MODE = modes[1],
      SECOND_MODE = modes[2] or modes[1], EPILOGUE = done, BACK = site + size, TABLE = table,
    }))
  end
  local KC, KP = K.KEEP_CHECK, K.KEEP_PREVIEW
  local check = scan(K.AOB_KEEP_CHECK, "the keep placement check")
  local checkStockpile = check + KC.stockpile
  expectBytes(checkStockpile, { 0x8B, 0x44, 0x24, 0x4C, 0x8B, 0x98 }, "the keep placement check")
  expectBytes(checkStockpile + KC.done, KC.doneBytes, "the end of the placement check")
  local preview = scan(K.AOB_KEEP_PREVIEW, "the keep preview")
  local previewStockpile = scan(K.AOB_KEEP_PREVIEW_STOCKPILE, "the keep preview")
  expectBytes(previewStockpile + KP.done, KP.doneBytes, "the keep preview")
  leaveOut(check, KC.size, { K.KEEP_ONLY }, "mov eax,[esp+0x48]\nshl eax,5", checkStockpile + KC.done, 0)
  leaveOut(checkStockpile, KC.stockpileSize, { K.KEEP_ONLY, K.KEEP_NO_STOCKPILE }, "mov eax,[esp+0x4C]\nmov ebx,[eax+TABLE]",
    checkStockpile + KC.done, rd32(checkStockpile + KC.table))
  leaveOut(preview, KP.size, { K.KEEP_ONLY }, "shl edx,5\nadd ebp,[edx+TABLE]", previewStockpile + KP.done,
    rd32(preview + KP.table))
  leaveOut(previewStockpile, KP.stockpileSize, { K.KEEP_ONLY, K.KEEP_NO_STOCKPILE }, "mov eax,[esp+0x38]\nmov ebp,[eax+TABLE]",
    previewStockpile + KP.done, rd32(previewStockpile + KP.stockpileTable))
end

-- The game's language for the names it has no text for: German or English.
function C.language()
  local file = io.open(K.TEXT_FILE, "rb")
  if file == nil then return "en" end
  local data = file:read("a")
  file:close()
  if #data < K.TEXT_START + 4 * K.TEXT_GROUPS then return "en" end
  local at = K.TEXT_START + 1 + 2 * string.unpack("<I4", data, 1 + 4 * K.TEXT_GROUP)
  local index = 0
  while index < K.TEXT_INDEX and at < #data do
    if data:byte(at) == 0 and data:byte(at + 1) == 0 then index = index + 1 end
    at = at + 2
  end
  local chars = {}
  while at < #data and not (data:byte(at) == 0 and data:byte(at + 1) == 0) and #chars < 32 do
    chars[#chars + 1] = data:sub(at, at)
    at = at + 2
  end
  return table.concat(chars) == K.GERMAN_TEXT and "de" or "en"
end

-- All eight player shields beside the minimap on every map type. The shields' render function,
-- in the map editor, shows players 1-5 on scenario maps and only player 1 on other single
-- player maps (`cmp [map type],ebp / jne <shown>`): the jne becomes a jmp.
K.AOB_PLAYER_SHIELDS = "B8 F7 FF FF FF 2B C6 39 2D ? ? ? ? 75 ? 39 1D ? ? ? ? 75 ? 83 F8 05 7E"
K.PLAYER_SHIELDS_JUMP = 0x0D
function C.patchAllPlayers(self)
  local site = scan(K.AOB_PLAYER_SHIELDS, "the player shields") + K.PLAYER_SHIELDS_JUMP
  self.saved = self.saved or {}
  table.insert(self.saved, { address = site, bytes = core.readBytes(site, 1) })
  core.writeCodeByte(site, 0xEB)
end

-- The manor house and the stronghold in the keeps menu on multiplayer maps too. isMapperAvailable
-- refuses placement ids 60 (manor house) and 62-64 there in the map editor (`cmp edx,0x3C / je
-- <no> / cmp edx,0x3D / jle <yes> / cmp edx,0x40 / jle <no>`); 0x3F and 0x3E leave only 63-64 out.
K.AOB_MAPPER_KEEPS = "83 3D ? ? ? ? 01 7C 17 83 FA 3C 74 E3 83 FA 3D 7E 05 83 FA 40 7E D9"
K.MAPPER_KEEPS = { first = 0x0B, second = 0x10 }
function C.patchAllKeeps(self)
  local site = scan(K.AOB_MAPPER_KEEPS, "the keep buttons' availability")
  self.saved = self.saved or {}
  for _, at in ipairs({ K.MAPPER_KEEPS.first, K.MAPPER_KEEPS.second }) do
    table.insert(self.saved, { address = site + at, bytes = core.readBytes(site + at, 1) })
  end
  core.writeCodeByte(site + K.MAPPER_KEEPS.first, 0x3F)
  core.writeCodeByte(site + K.MAPPER_KEEPS.second, 0x3E)
end

-- Damaged walls: in the map editor, with the choice on, every wall tile placeWalls builds or
-- repairs gets the damaged look (its damage byte; the height stays).
-- A dust cloud whose speed is 0 skips its step instead of dividing by zero (all four steps).
function C.patchDustClouds(self)
  local D = K.DUST_STEP
  local sites = {}
  for _, kind in ipairs({ { K.AOB_DUST_X, D.x, D.xSize }, { K.AOB_DUST_Y, 0, D.ySize } }) do
    local from, found = 0x400000, {}
    while #found <= D.sites do
      local ok, at = pcall(core.scanForAOB, kind[1], from, 0x600000)
      if not ok or at == nil or at == 0 then break end
      found[#found + 1] = at
      from = at + 1
    end
    if #found ~= D.sites then error(MODULE_NAME .. ": the dust clouds' steps are not the ones this module knows") end
    for _, at in ipairs(found) do
      -- The step's code ends in `jge rel8`: its next instruction is the negative case, its
      -- target the positive one, and the step ends 10 bytes after that.
      local step = at + kind[2]
      local negative = step + kind[3]
      expectBytes(negative - 2, { 0x7D }, "the dust clouds' steps")
      local positive = negative + (rd8(negative - 1) & 0xFF)
      sites[#sites + 1] = { site = step, size = kind[3], stub = core.allocateAssembly(templates.dustStep, {
        STEP_NEGATIVE = negative, STEP_POSITIVE = positive, STEP_SKIP = positive + D.skip,
      }) }
    end
  end
  for _, s in ipairs(sites) do patchJump(self, s.site, s.size, s.stub) end
end

function C.patchDamagedWalls(self, G, data)
  local site = scan(K.AOB_WALL_TILE_DONE, "the wall placement")
  local damage = rd32(scan(K.AOB_WALL_DAMAGE, "the wall drawing") + K.WALL_DAMAGE_OPERAND)
  local R = C.resolvePipette(G)
  local W = C.wallWords()
  patchJump(self, site, K.WALL_TILE_DONE_SIZE, core.allocateAssembly(templates.damagedWall, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, FLAG = data.damagedWalls, DAMAGE = damage,
    CRENEL_HEIGHT = W.height, LOGIC = R.logic, BASE = R.defaultHeight, LIVE = R.height,
    CLEAR_MOAT = readCallTarget(site, K.WALL_CLEAR_MOAT_CALL, "the wall placement"),
    BACK = site + K.WALL_TILE_DONE_SIZE,
  }))
end

-- The building hover text of castle mode ("Player 1's Keep") moves left, clear of the building
-- counts. The code is the map editor's branch only.
function C.patchHoverText(self)
  local site = scan(K.AOB_HOVER_TEXT, "the building hover text")
  patchJump(self, site, K.HOVER_TEXT_SIZE, core.allocateAssembly(templates.hoverTextLeft, {
    SHIFT = K.HOVER_TEXT_SHIFT, PLAYER = rd32(site + K.HOVER_TEXT_PLAYER), BACK = site + K.HOVER_TEXT_SIZE,
  }))
end

-- Tower ruins get the size of their tower (the game has none for them) in the map editor.
function C.patchRuinSizes(self, G)
  local size = scan(K.AOB_BUILDING_SIZE, "the building sizes")
  patchJump(self, size, K.BUILDING_SIZE_START, core.allocateAssembly(templates.ruinSize, {
    GAME_MODE = G.gameMode, MAP_EDITOR = K.MAP_EDITOR, FIRST_RUIN = K.TOWER_RUINS[1],
    LAST_RUIN = K.TOWER_RUINS[#K.TOWER_RUINS], TOWER_FROM_RUIN = K.TOWER_RUINS[1] - K.FIRST_TOWER,
    SIZE_BASE = C.signedByte(size + 6) & 0xFFFFFFFF, BACK = size + K.BUILDING_SIZE_START,
  }))
end

function C.enable(self, O)
  -- What the landscape menu found, if it ran: its constructor no longer pushes the table the
  -- search looks for once the module's copy is in.
  local G = self.landscape
  if G == nil then
    G = {}
    resolveMenu(G)
    resolveDrawing(G)
  end
  local B = C.resolve(G)
  local data = nil
  if O.buildingCounts or O.towerRuins or O.armyExtras or O.statues or O.barrier or O.keepParts or O.damagedWalls
      or O.undo or O.moatKinds or O.ruinedCathedral then
    local newTable
    C.owner = self                         -- for patches made while the table is built
    newTable, data = C.build(G, B, O)
    core.writeCodeInteger(B.site + 1, newTable)
    local construct = core.exposeCode(B.constructor, 2, 1)
    local function ensure()
      if rd32(B.menu) == B.table then construct(B.menu, newTable) end
    end
    ensure()
    hooks.registerHookCallback("afterInit", ensure)
  end
  -- Each patch on its own, so that one the game does not match leaves the others working.
  local function try(wanted, patch, what, ...)
    if not wanted then return end
    local ok, problem = pcall(patch, self, ...)
    if not ok then log(WARNING, tostring(problem) .. "; " .. what .. " left out") end
  end
  try(O.towerRuins, C.patchRuinSizes, "tower ruins", G)
  try(O.severalKeeps or O.looseBuildings, C.patchSeveralBuildings, "several keeps and storage buildings", G, O)
  try(O.looseBuildings, C.patchEmptyStorage, "any number of empty storage buildings", G)
  try(O.towerEngines, C.patchTowerEngines, "tower engines anywhere", G)
  try(O.keepParts, C.patchKeepParts, "the keep choices", G, data)
  try(O.keepGround, C.patchKeepGround, "keeps leaving the ground as it is", G)
  try(O.damagedWalls, C.patchDamagedWalls, "damaged walls", G, data)
  try(O.wallTools, C.patchWallTools, "wall tools", G, data)
  try(O.allPlayers, C.patchAllPlayers, "all player shields")
  try(O.allKeeps, C.patchAllKeeps, "all keeps")
  try(O.hoverTextLeft, C.patchHoverText, "the hover text move")
  try(O.moatKinds and data ~= nil, C.patchMoatClick, "the moat kinds", data)
  try(O.moatKinds or O.moatRemoval, C.patchMoatModes, "the moat modes", O.moatKinds, O.moatRemoval)
  try(O.moatOnMarsh, C.patchMoatMarsh, "moat on marsh")
  try(O.variantPanels, C.patchVariantLocks, "the variant panels", G)
  log(INFO, string.format("%s: build menu changed (menu 0x%X, items 0x%X)", MODULE_NAME, B.menu, B.table))
end

---------------------------------------------------------------------------------------
-- Always keep the menu up to date
---------------------------------------------------------------------------------------

local function enableRedraw(self)
  local site = scan(AOB_MENU_REDRAW, "the main loop's menu redraw") + MENU_REDRAW_SITE
  expectBytes(site, { 0x39, 0x1D }, "the menu redraw test")
  expectBytes(site + 6, { 0x0F, 0x85 }, "the menu redraw test")
  local stub = core.allocateAssembly(templates.menuRedraw, {
    COUNTDOWN = rd32(site + 2),
    GAME_MODE = rd32(scan(AOB_GAME_MODE, "the game mode") + GAME_MODE_OPERAND),
    FULL = site + MENU_REDRAW_SIZE + rd32(site + 8),
    PARTIAL = site + MENU_REDRAW_SIZE,
  })
  patchJump(self, site, MENU_REDRAW_SIZE, stub)
  log(INFO, string.format("%s: menu always kept up to date (0x%X)", MODULE_NAME, site))
end

---------------------------------------------------------------------------------------
-- Enable
---------------------------------------------------------------------------------------

local function enable(self, config)
  config = config or {}
  -- Undo first: its buttons go into the menus below.
  if setting(config, "undo", "enabled") == true then
    local ok, problem = pcall(C.enableUndo, self)
    if not ok then
      self.undo = nil
      log(WARNING, tostring(problem) .. "; the editor has no undo")
    end
  end
  local O = {
    counts = setting(config, "counts", "enabled") == true,
    shown = setting(config, "counts", "shown") == true,
    growth = setting(config, "trees", "growth_from_brush") == true,
    apple = setting(config, "trees", "apple") == true,
    shrubs = setting(config, "trees", "shrubs") == true,
    felled = setting(config, "trees", "felled") == true,
    obstacles = setting(config, "trees", "obstacles") == true,
    rocksAndWater = setting(config, "trees", "rocks_and_water") == true,
    sortedRows = setting(config, "trees", "sorted_rows") == true,
    randomMix = setting(config, "trees", "random_mix") == true,
    textures = setting(config, "textures", "gravel_and_iron") == true,
    variants = setting(config, "rocks", "variants") == true,
    extraRock = setting(config, "rocks", "extra_rock") == true,
    herds = setting(config, "herds", "panel") == true,
    invisibleRocks = setting(config, "rocks", "invisible") == true,
    noStacking = setting(config, "trees", "no_shrub_stacking") == true,
    treePreview = setting(config, "trees", "preview") == true,
    noHeightsIron = setting(config, "textures", "no_heights_iron") == true,
    waterDecorations = setting(config, "water", "decorations") == true,
    foamOnSea = setting(config, "water", "foam_on_sea") == true,
    maxHeight = setting(config, "heights", "max_height") == true,
    heightTools = setting(config, "heights", "tool_options") == true,
    lostRocks = setting(config, "rocks", "remove_lost") == true,
    invertKey = setting(config, "heights", "invert_key_on") == true and setting(config, "heights", "invert_key") or nil,
    textureMask = setting(config, "textures", "mask") == true,
    maskByType = setting(config, "textures", "mask_by_type") == true,
    birdButtons = setting(config, "herds", "bird_bins") == true,
    animalBin = setting(config, "herds", "animal_bin") == true,
    groupWarning = setting(config, "herds", "group_warning") == true,
    eraserChoice = setting(config, "eraser", "choice") == true,
    eraseGulls = setting(config, "eraser", "seagulls") == true,
    spreadOrder = setting(config, "trees", "spread_order") == true,
    spreadOutlines = setting(config, "trees", "spread_outlines") == true,
    compass = setting(config, "menu", "compass") == true,
    undo = self.undo,
  }
  if setting(config, "pipette", "enabled") == true then
    O.pipette = {
      selectKeyOn = setting(config, "pipette", "select_key_on") == true, selectKey = setting(config, "pipette", "select_key"),
      readKeyOn = setting(config, "pipette", "read_key_on") == true, readKey = setting(config, "pipette", "read_key"),
      anyKeyOn = setting(config, "pipette", "any_tile_key_on") == true, anyKey = setting(config, "pipette", "any_tile_key"),
    }
  end
  local castle = {
    buildingCounts = setting(config, "castle", "building_counts") == true,
    towerRuins = setting(config, "castle", "tower_ruins") == true,
    armyExtras = setting(config, "castle", "tunnel_and_tents") == true,
    statues = setting(config, "castle", "statues_and_shrines") == true,
    variantPanels = setting(config, "castle", "variant_panels") == true,
    ruinedCathedral = setting(config, "castle", "ruined_cathedral") == true,
    barrier = setting(config, "castle", "barrier") == true,
    severalKeeps = setting(config, "castle", "several_keeps") == true,
    looseBuildings = setting(config, "castle", "several_storage_and_recruitment") == true,
    towerEngines = setting(config, "castle", "tower_engines_anywhere") == true,
    keepParts = setting(config, "castle", "keep_parts") == true,
    keepGround = setting(config, "castle", "keep_ground") == true,
    rotation = setting(config, "castle", "rotation") == true,
    unitColour = setting(config, "castle", "unit_colour") == true,
    compass = setting(config, "menu", "compass") == true,
    damagedWalls = setting(config, "castle", "damaged_walls") == true,
    allPlayers = setting(config, "castle", "all_players") == true,
    allKeeps = setting(config, "castle", "all_keeps") == true,
    playerZero = setting(config, "castle", "player_zero") == true,
    keepCrests = setting(config, "castle", "keep_crests") == true,
    crestTooltip = setting(config, "castle", "keep_crest_tooltip") == true,
    wallTools = setting(config, "castle", "wall_tools") == true,
    hoverTextLeft = setting(config, "castle", "hover_text_left") == true,
    moatKinds = setting(config, "castle", "moat_kinds") == true,
    moatOnMarsh = setting(config, "castle", "moat_on_marsh") == true,
    moatRemoval = setting(config, "castle", "moat_removal_keeps_ground") == true,
    undo = self.undo,
  }
  if O.counts or O.growth or O.apple or O.shrubs or O.felled or O.obstacles or O.rocksAndWater or O.sortedRows
      or O.textures
      or O.variants or O.herds or O.invisibleRocks or O.noStacking or O.noHeightsIron or O.waterDecorations
      or O.undo or O.pipette or O.treePreview or O.maxHeight or O.heightTools or O.lostRocks
      or O.textureMask or O.birdButtons or O.animalBin or O.groupWarning or O.eraserChoice or O.eraseGulls
      or O.spreadOrder or O.spreadOutlines or O.compass then
    local ok, problem = pcall(enableMenu, self, O)
    if not ok then log(WARNING, tostring(problem) .. "; the editor menu is left as it is") end
  end
  local settings = {
    lockedMaps = setting(config, "map_settings", "show_locked") == true,
    settingsButton = setting(config, "map_settings", "button") == true,
    settingsMenu = setting(config, "map_settings", "menu") == true,
  }
  if settings.lockedMaps or settings.settingsButton or settings.settingsMenu then
    local ok, problem = pcall(function()
      local G = self.landscape
      if G == nil then
        G = {}
        resolveMenu(G)
        resolveDrawing(G)
      end
      C.enableMapSettings(self, settings, G)
    end)
    if not ok then log(WARNING, tostring(problem) .. "; the map settings are left as they are") end
  end
  if castle.buildingCounts or castle.towerRuins or castle.armyExtras or castle.statues or castle.barrier
      or castle.severalKeeps or castle.looseBuildings or castle.towerEngines or castle.keepParts
      or castle.damagedWalls or castle.hoverTextLeft or castle.undo or castle.moatKinds or castle.moatOnMarsh
      or castle.moatRemoval or castle.ruinedCathedral or castle.allPlayers or castle.allKeeps or castle.playerZero or castle.keepCrests or castle.wallTools
      or castle.keepGround or castle.rotation or castle.compass or castle.unitColour then
    local ok, problem = pcall(C.enable, self, castle)
    if not ok then log(WARNING, tostring(problem) .. "; the build menu is left as it is") end
  end
  if setting(config, "rocks", "signpost") == true then
    local ok, problem = pcall(enableSignpost, self)
    if not ok then log(WARNING, tostring(problem) .. "; skirmish maps keep their own Rocks menu") end
  end
  if setting(config, "brushes", "full_shape") == true then
    local ok, problem = pcall(C.patchBrushShape, self)
    if not ok then log(WARNING, tostring(problem) .. "; the brushes keep their missing corner") end
  end
  if setting(config, "rocks", "erase_invisible") == true then
    local ok, problem = pcall(C.patchEraser, self)
    if not ok then log(WARNING, tostring(problem) .. "; the eraser leaves invisible rocks") end
  end
  if setting(config, "rocks", "random_preview") == true then
    local ok, problem = pcall(enableRandomPreview, self)
    if not ok then log(WARNING, tostring(problem) .. "; the random rotation is left as it is") end
  end
  for _, entry in ipairs({ { "size_refresh", C.patchSizeRefresh, "smaller map sizes need a reload" },
      { "camera_edge", C.patchCameraEdge, "the camera stops short of the map edge" } }) do
    if setting(config, "map_settings", entry[1]) == true then
      local ok, problem = pcall(function()
        local G = self.landscape
        if G == nil then
          G = {}
          resolveMenu(G)
          resolveDrawing(G)
        end
        entry[2](self, G)
      end)
      if not ok then log(WARNING, tostring(problem) .. "; " .. entry[3]) end
    end
  end
  if setting(config, "menu", "compass_turn") == true then
    local ok, problem = pcall(function()
      local G = self.landscape
      if G == nil then
        G = {}
        resolveMenu(G)
        resolveDrawing(G)
      end
      C.patchCompassTurn(self, G)
    end)
    if not ok then log(WARNING, tostring(problem) .. "; the compass turns the map one way only") end
  end
  if setting(config, "menu", "dust_clouds") == true then
    local ok, problem = pcall(C.patchDustClouds, self)
    if not ok then log(WARNING, tostring(problem) .. "; dust clouds are left as they are") end
  end
  if setting(config, "menu", "always_update") == true then
    local ok, problem = pcall(enableRedraw, self)
    if not ok then log(WARNING, tostring(problem) .. "; the menu is redrawn as usual") end
  end
end

local function disable(self, config)
  if self.saved ~= nil then
    for i = #self.saved, 1, -1 do
      core.writeCode(self.saved[i].address, self.saved[i].bytes)
    end
    self.saved = nil
  end
  if self.shownFlag ~= nil then
    wr32(self.shownFlag, 0)
  end
end

return {
  enable = enable,
  disable = disable,
}
