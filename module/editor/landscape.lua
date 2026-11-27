local layout = require("editor.layout")
local templates = layout.templates
local MODULE_NAME = layout.MODULE_NAME
local K = layout.K
local C = layout.C
local memory = require("editor.memory")
local scan = memory.scan
local scanUnique = memory.scanUnique
local expectBytes = memory.expectBytes
local rd32 = memory.rd32
local native = require("editor.native")
local resolveMenu = native.resolveMenu
local resolveDrawing = native.resolveDrawing
local resolveCounters = native.resolveCounters
local resolveRocks = native.resolveRocks
local resolveHerds = native.resolveHerds
local buildTable = require("editor.landscape_menu").buildTable
local menu_install = require("editor.menu_install")
local installTable = menu_install.installTable
local patchJump = menu_install.patchJump
local patchTrees = require("editor.vegetation").patchTrees
local patchRocks = require("editor.terrain_patches").patchRocks
local patchHerds = require("editor.landscape_controls").patchHerds

local function reportFrameFailure(data, problem)
  if data.groupWarning ~= nil then log(ERROR, "The herd limit warning is off.") end
  if data.treePreviewItem ~= nil then log(WARNING, "Vegetation preview is only available while the editor menu is open.") end
  if data.heights ~= nil then log(WARNING, "Height brush settings will stay set when leaving the editor.") end
  log(WARNING, tostring(problem))
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
      log(ERROR, "The rock variant row is off.")
      log(WARNING, tostring(problem))
      O.variants = false
    end
  end
  if O.herds then
    local ok, problem = pcall(resolveHerds, G)
    if not ok then
      log(ERROR, "The herd size and behavior panel is off.")
      log(WARNING, tostring(problem))
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
    if not ok then
      log(ERROR, "The texture mask is off.")
      log(WARNING, tostring(problem))
    end
  end
  if data.heights ~= nil then
    local ok, problem = pcall(C.patchHeightTools, self, G, data)
    if not ok then log(WARNING, tostring(problem) .. "; the height tools keep breaking rocks") end
  end
  if data.heights ~= nil or data.mask ~= nil then
    local ok, problem = pcall(C.patchHeightFilters, self, G, data)
    if not ok then log(WARNING, tostring(problem) .. "; the height tools change every tile under the brush") end
  end
  if data.pipette ~= nil then
    local ok, problem = pcall(C.patchPipettePreview, self, data.pipette, data.pipetteRead)
    if not ok then log(WARNING, tostring(problem) .. "; the pipette shows the whole brush while taking a tile") end
  end
  if data.eraserChoice or O.eraseGulls then
    local ok, problem = pcall(C.patchEraserChoice, self, G, data.eraserChoice, O.eraseGulls)
    if not ok then
      if data.eraserChoice then log(ERROR, "The eraser mode choices are off.") end
      if O.eraseGulls then log(ERROR, "Erasing flying seagulls is off.") end
      log(WARNING, tostring(problem))
    end
  end
  self.shownFlag = data.shown
  self.landscape = G
  data.installed = true          -- the menu is in: the module's actions may act on it
  if data.heights ~= nil or data.treePreviewPad ~= nil or data.groupWarning ~= nil then
    local ok, problem = pcall(C.patchFrame, self, G, data)
    if ok then return data end
    reportFrameFailure(data, problem)
  end
end

-- Skirmish maps get the Rocks tab with the signpost: the jl past `mov eax, 239` always jumps.
local function enableSignpost(self)
  local site = scan(K.AOB_SIGNPOST, "the Rocks button") + K.SIGNPOST_JUMP
  expectBytes(site, { K.JL_SHORT }, "the Rocks button")
  self.saved = self.saved or {}
  table.insert(self.saved, { address = site, bytes = { K.JL_SHORT } })
  core.writeCode(site, { K.JMP_SHORT })
end

-- The editor's random mode turns after each rock placement instead of on a timer.
local function enableRandomPreview(self)
  local site = scanUnique(K.AOB_RANDOM_ROCK, "the random rock button") + K.RANDOM_ROCK_MODE
  local turn = scanUnique(K.AOB_ROCK_TURN, "placeRock's rotation")
  local gameMode = C.gameModeOf()
  if rd32(turn + 2) ~= K.TILE_MAP.rotation then
    error(MODULE_NAME .. ": placeRock uses a different rotation field")
  end
  local placed = core.allocate(4, true)
  local stub = core.allocateAssembly(templates.rockTurn, {
    GAME_MODE = gameMode, MAP_EDITOR = K.MAP_EDITOR, ROTATION = K.TILE_MAP.rotation,
    MODE = K.TILE_MAP.mode, TURN_MODE = K.ROCK_TURN_MODE, BACK = turn + 6, PLACED = placed,
  })
  local mode = core.allocateAssembly(templates.randomRockMode, {
    MODE = rd32(site + 2), TURN_MODE = K.ROCK_TURN_MODE, BACK = site + K.RANDOM_ROCK_MODE_SIZE,
  })
  patchJump(self, turn, 6, stub)
  patchJump(self, site, K.RANDOM_ROCK_MODE_SIZE, mode)
  return placed
end

return {
  enableMenu = enableMenu,
  reportFrameFailure = reportFrameFailure,
  enableSignpost = enableSignpost,
  enableRandomPreview = enableRandomPreview,
}
