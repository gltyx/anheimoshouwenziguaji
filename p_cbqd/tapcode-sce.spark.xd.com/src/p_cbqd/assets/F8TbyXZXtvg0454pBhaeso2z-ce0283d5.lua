-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 技能 + 宝石面板
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")
local UI = require("urhox-libs/UI")
local UC = require("ui_common")
local UISettings = require("ui_market_settings")
local qc, panelTitle, subTabBar = UC.qc, UC.panelTitle, UC.subTabBar

local M = {}

-- ============================================================================
-- 技能面板
-- ============================================================================
function M.buildSkillsPanel(ctx)
    local player = ctx.player
    local children = {}

    -- 碎片概览
    local fragTexts = {}
    for _, sq in ipairs(CFG.SKILL_QUALITIES) do
        local cnt = player.skillFragments[sq.id] or 0
        if cnt > 0 then fragTexts[#fragTexts + 1] = sq.name .. ":" .. cnt end
    end

    -- 子标签切换栏: 技能 | 宝石 (紫色调)
    children[#children + 1] = subTabBar(
        { {label = "⚡ 技能", view = "skills"}, {label = "💎 宝石", view = "gems"} },
        "skills", ctx, {110, 60, 160, 255}
    )

    -- 统计已装备/未装备
    local equippedCount = SYS.getEquippedCount(player)
    children[#children + 1] = panelTitle("⚡", "技能 (" .. #player.skills .. "个 | 装备" .. equippedCount .. "/" .. SYS.MAX_EQUIPPED_SKILLS .. ")")

    if #fragTexts > 0 then
        children[#children + 1] = UI.Label {
            text = "📦 碎片: " .. table.concat(fragTexts, " "),
            fontSize = 22, color = {140, 140, 160, 255},
        }
    end

    -- 分解结果提示
    if ctx.skillMsg then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 10,
            backgroundColor = {30, 42, 30, 255},
            borderRadius = 8,
            children = {
                UI.Label { text = ctx.skillMsg, fontSize = 24, color = {180, 255, 180, 255} },
            },
        }
    end

    if #player.skills == 0 then
        children[#children + 1] = UI.Label {
            text = "暂无技能，请前往黑市购买",
            fontSize = 26, color = {100, 100, 120, 255},
            paddingVertical = 16,
        }
    end

    -- 构建单个技能行的通用函数
    local function buildSkillRow(skill, idx, isEquipped)
        local sq = CFG.SKILL_QUALITIES[skill.quality]
        local mult = SYS.getSkillMult(skill)
        local skillIdx = idx
        local nextLv = skill.enhance + 1
        local rate = CFG.ENHANCE_RATES[nextLv] or 5

        local actionBtns = {}
        -- 强化
        actionBtns[#actionBtns + 1] = UI.Button {
            text = "强化(" .. rate .. "%)",
            fontSize = 20, height = 48, paddingHorizontal = 8,
            variant = "primary",
            onClick = function() if ctx.onEnhanceSkill then ctx.onEnhanceSkill(skillIdx) end end,
        }
        if isEquipped then
            actionBtns[#actionBtns + 1] = UI.Button {
                text = "卸下", fontSize = 20, height = 48, paddingHorizontal = 8,
                variant = "outline",
                onClick = function() if ctx.onUnequipSkill then ctx.onUnequipSkill(skillIdx) end end,
            }
        else
            actionBtns[#actionBtns + 1] = UI.Button {
                text = "装备", fontSize = 20, height = 48, paddingHorizontal = 8,
                variant = "success", disabled = equippedCount >= SYS.MAX_EQUIPPED_SKILLS,
                onClick = function() if ctx.onEquipSkill then ctx.onEquipSkill(skillIdx) end end,
            }
        end

        -- 锁定
        actionBtns[#actionBtns + 1] = UI.Button {
            text = skill.locked and "🔓" or "🔒", fontSize = 20, height = 48, paddingHorizontal = 6,
            variant = "ghost",
            onClick = function() if ctx.onToggleLock then ctx.onToggleLock("skill", skillIdx) end end,
        }
        -- 分解
        actionBtns[#actionBtns + 1] = UI.Button {
            text = "分解", fontSize = 20, height = 48, paddingHorizontal = 8,
            variant = "danger", disabled = skill.locked or isEquipped,
            onClick = function() if ctx.onDecomposeSkill then ctx.onDecomposeSkill(skillIdx) end end,
        }

        local bgColor = isEquipped and {35, 40, 55, 255} or {28, 28, 40, 255}
        return UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            paddingVertical = 8,
            paddingHorizontal = 10,
            gap = 8,
            backgroundColor = bgColor,
            borderRadius = 6,
            children = {
                UI.Panel {
                    flex = 1, flexShrink = 1,
                    children = {
                        UI.Label {
                            text = (skill.locked and "🔒" or "") .. "[" .. sq.name .. "] " .. skill.name .. (skill.enhance > 0 and (" +" .. skill.enhance) or ""),
                            fontSize = 24, color = qc(sq.color),
                        },
                        UI.Label {
                            text = mult .. "% 伤害 | CD:" .. skill.cd .. "s",
                            fontSize = 20, color = {120, 120, 140, 255},
                        },
                    },
                },
                table.unpack(actionBtns),
            },
        }
    end

    -- === 已装备技能区域 ===
    local equippedItems = {}
    local unequippedItems = {}
    for idx, skill in ipairs(player.skills) do
        if skill.equipped then
            equippedItems[#equippedItems + 1] = buildSkillRow(skill, idx, true)
        else
            unequippedItems[#unequippedItems + 1] = buildSkillRow(skill, idx, false)
        end
    end

    -- 已装备标题
    children[#children + 1] = UI.Label {
        text = "⚔️ 已装备 (" .. #equippedItems .. "/" .. SYS.MAX_EQUIPPED_SKILLS .. ")",
        fontSize = 24, color = {100, 200, 255, 255},
        paddingTop = 4,
    }

    if #equippedItems == 0 then
        children[#children + 1] = UI.Label {
            text = "无已装备技能",
            fontSize = 22, color = {100, 100, 120, 255},
            paddingVertical = 8,
        }
    end

    -- 将已装备和未装备合在一个滚动区域
    local allItems = {}
    for _, item in ipairs(equippedItems) do
        allItems[#allItems + 1] = item
    end

    if #unequippedItems > 0 then
        allItems[#allItems + 1] = UI.Label {
            text = "📦 未装备 (" .. #unequippedItems .. "个)",
            fontSize = 24, color = {160, 160, 180, 255},
            paddingTop = 8,
        }
        for _, item in ipairs(unequippedItems) do
            allItems[#allItems + 1] = item
        end
    end

    children[#children + 1] = ctx.wrapScroll("skills", {
        width = "100%", flexGrow = 1, flexBasis = 0,
        gap = 4, children = allItems,
    })

    -- 自动分解设置（固定在底部，不随滚动）
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexShrink = 0,
        paddingVertical = 6,
        paddingHorizontal = 10,
        backgroundColor = {32, 28, 42, 255},
        borderRadius = 6,
        children = UISettings.buildSkillDecomposeChildren(ctx),
    }

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12, gap = 8,
        children = children,
    }
end

-- ============================================================================
-- 宝石面板
-- ============================================================================
function M.buildGemsPanel(ctx)
    local player = ctx.player
    local children = {}

    -- 子标签切换栏: 技能 | 宝石 (紫色调)
    children[#children + 1] = subTabBar(
        { {label = "⚡ 技能", view = "skills"}, {label = "💎 宝石", view = "gems"} },
        "gems", ctx, {110, 60, 160, 255}
    )

    children[#children + 1] = panelTitle("💎", "宝石背包 (" .. #player.gemBag .. "颗)")

    -- 碎片概览
    local fragTexts = {}
    for _, gq in ipairs(CFG.GEM_QUALITIES) do
        local cnt = player.gemFragments[gq.id] or 0
        if cnt > 0 then fragTexts[#fragTexts + 1] = gq.name .. ":" .. cnt end
    end
    if #fragTexts > 0 then
        children[#children + 1] = UI.Label {
            text = "📦 碎片: " .. table.concat(fragTexts, " "),
            fontSize = 22, color = {140, 140, 160, 255},
        }
    end

    -- 操作结果提示
    if ctx.gemMsg then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 10,
            backgroundColor = {30, 42, 30, 255},
            borderRadius = 8,
            children = {
                UI.Label { text = ctx.gemMsg, fontSize = 24, color = {180, 255, 180, 255} },
            },
        }
    end

    if #player.gemBag == 0 then
        children[#children + 1] = UI.Label {
            text = "暂无宝石，击杀怪物或前往黑市购买",
            fontSize = 26, color = {100, 100, 120, 255},
            paddingVertical = 16,
        }
    end

    local gemItems = {}
    for idx, gem in ipairs(player.gemBag) do
        local gc = SYS.getGemQualityColor(gem.qualityIdx)
        local affixStrs = {}
        local gemEnhMult = 1 + (gem.enhance or 0) * 0.1
        for _, ga in ipairs(gem.affixes) do
            local displayVal = math.floor(ga.value * gemEnhMult)
            affixStrs[#affixStrs + 1] = SYS.formatGemStat(ga.id, displayVal)
        end
        local gemIdx = idx
        local nextLv = (gem.enhance or 0) + 1
        local rate = CFG.ENHANCE_RATES[nextLv] or 5

        local actionBtns = {}
        -- 强化
        actionBtns[#actionBtns + 1] = UI.Button {
            text = "强化(" .. rate .. "%)",
            fontSize = 20, height = 48, paddingHorizontal = 8,
            variant = "primary",
            onClick = function() if ctx.onEnhanceGem then ctx.onEnhanceGem(gemIdx) end end,
        }
        -- 锁定
        actionBtns[#actionBtns + 1] = UI.Button {
            text = gem.locked and "🔓" or "🔒", fontSize = 20, height = 48, paddingHorizontal = 6,
            variant = "ghost",
            onClick = function() if ctx.onToggleLock then ctx.onToggleLock("gem", gemIdx) end end,
        }
        -- 分解
        actionBtns[#actionBtns + 1] = UI.Button {
            text = "分解", fontSize = 20, height = 48, paddingHorizontal = 8,
            variant = "danger", disabled = gem.locked,
            onClick = function() if ctx.onDecomposeGem then ctx.onDecomposeGem(gemIdx) end end,
        }

        local enhText = (gem.enhance or 0) > 0 and (" +" .. gem.enhance) or ""
        gemItems[#gemItems + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            paddingVertical = 6,
            paddingHorizontal = 10,
            gap = 8,
            backgroundColor = {28, 28, 40, 255},
            borderRadius = 6,
            children = {
                UI.Panel {
                    flex = 1, flexShrink = 1,
                    children = {
                        UI.Label {
                            text = (gem.locked and "🔒" or "") .. gem.name .. enhText,
                            fontSize = 24, color = qc(gc),
                        },
                        UI.Label {
                            text = table.concat(affixStrs, " | "),
                            fontSize = 20, color = {120, 160, 120, 255},
                        },
                    },
                },
                table.unpack(actionBtns),
            },
        }
    end

    children[#children + 1] = ctx.wrapScroll("gems", {
        width = "100%", flexGrow = 1, flexBasis = 0,
        gap = 4, children = gemItems,
    })

    -- 自动分解设置（固定在底部，不随滚动）
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexShrink = 0,
        paddingVertical = 6,
        paddingHorizontal = 10,
        backgroundColor = {32, 28, 42, 255},
        borderRadius = 6,
        children = UISettings.buildGemDecomposeChildren(ctx),
    }

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12, gap = 8,
        children = children,
    }
end

return M
