-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 右侧内容面板 (入口路由)
-- 将各面板委托到子模块: ui_combat, ui_inventory, ui_skills_gems, ui_market_settings
-- ============================================================================
local UICombat = require("ui_combat")
local UIInventory = require("ui_inventory")
local UISkillsGems = require("ui_skills_gems")
local UIMarketSettings = require("ui_market_settings")
local UILeft = require("ui_left")

local M = {}

-- 战斗面板
M.buildCombatPanel = UICombat.buildCombatPanel

-- 人物属性面板
M.buildStatsPanel = UILeft.buildStatsPanel

-- 背包面板
M.buildInventoryPanel = UIInventory.buildInventoryPanel

-- 装备面板
M.buildEquipPanel = UIInventory.buildEquipPanel

-- 装备详情面板
M.buildEquipDetailPanel = UIInventory.buildEquipDetailPanel

-- 技能面板
M.buildSkillsPanel = UISkillsGems.buildSkillsPanel

-- 宝石面板
M.buildGemsPanel = UISkillsGems.buildGemsPanel

-- 黑市面板
M.buildMarketPanel = UIMarketSettings.buildMarketPanel

-- 概率显示条
M.buildProbDisplay = UIMarketSettings.buildProbDisplay

-- 宝石镶嵌选择面板
M.buildGemSelectPanel = UIInventory.buildGemSelectPanel

-- 设置面板
M.buildSettingsPanel = UIMarketSettings.buildSettingsPanel

-- 精英副本面板
M.buildElitePanel = UIMarketSettings.buildElitePanel

return M
