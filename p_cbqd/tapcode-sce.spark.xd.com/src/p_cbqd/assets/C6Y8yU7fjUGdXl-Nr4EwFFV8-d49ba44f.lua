-- ============================================================================
-- 伤害飘字系统 (独立 NanoVG 上下文，渲染在 UI 之上)
-- 从 main.lua 拆分出来的独立模块
-- ============================================================================
local M = {}

-- 设计分辨率 (与 UI 系统保持一致)
local DESIGN_W = 750
local DESIGN_H = 1334

-- 内部状态
local dmgFloats = {}          -- { {value, isCrit, isSkill, isMob, elapsed, offsetX}, ... }
local nvgDmg = nil            -- 伤害飘字专用 NanoVG 上下文
local nvgDmgFont = -1         -- 伤害飘字字体 ID
local OUTLINE_OFFSETS = {{-1.5,0},{1.5,0},{0,-1.5},{0,1.5},{-1,-1},{1,-1},{-1,1},{1,1}}

-- 外部可设置的开关和锚点
M.enabled = true              -- main.lua 设置: showDmgFloat and currentView == "combat"
M.anchorX = 375               -- 怪物飘字锚点 X (设计分辨率坐标, 由外部根据怪物面板位置设置)
M.anchorY = 300               -- 怪物飘字锚点 Y (设计分辨率坐标, 由外部根据怪物面板位置设置)
M.playerAnchorX = 375         -- 玩家血条飘字锚点 X (受伤飘字显示在玩家血条中间)
M.playerAnchorY = 80          -- 玩家血条飘字锚点 Y

-- ============================================================================
-- 初始化与清理
-- ============================================================================
function M.init()
    nvgDmg = nvgCreate(1)
    if nvgDmg then
        nvgSetRenderOrder(nvgDmg, 999995)  -- > UI(999990), 保证在 UI 之上
        nvgDmgFont = nvgCreateFont(nvgDmg, "dmgfont", "Fonts/MiSans-Bold.ttf")
        SubscribeToEvent(nvgDmg, "NanoVGRender", "HandleDmgFloatRender")
        print("[飘字] NanoVG 上下文创建成功, fontId=" .. nvgDmgFont)
    else
        print("[飘字] NanoVG 上下文创建失败!")
    end
end

function M.cleanup()
    if nvgDmg then
        nvgDelete(nvgDmg)
        nvgDmg = nil
    end
end

-- ============================================================================
-- 飘字数据管理
-- ============================================================================

--- 添加飘字伤害
---@param value number 伤害数值
---@param isCrit boolean 是否暴击
---@param isSkill boolean 是否技能伤害
---@param isMob boolean 是否怪物对玩家的伤害
function M.add(value, isCrit, isSkill, isMob)
    if not M.enabled then return end
    dmgFloats[#dmgFloats + 1] = {
        value = value,
        isCrit = isCrit or false,
        isSkill = isSkill or false,
        isMob = isMob or false,
        elapsed = 0,
        offsetX = (math.random() - 0.5) * 50,  -- 随机水平偏移 (设计分辨率坐标)
    }
end

--- 更新飘字动画 (每帧调用)
function M.update(dt)
    if #dmgFloats == 0 then return end
    local i = 1
    while i <= #dmgFloats do
        dmgFloats[i].elapsed = dmgFloats[i].elapsed + dt
        if dmgFloats[i].elapsed > 2.0 then
            table.remove(dmgFloats, i)
        else
            i = i + 1
        end
    end
end

--- 清空所有飘字
function M.clear()
    dmgFloats = {}
end

--- 是否有正在显示的飘字
function M.hasFloats()
    return #dmgFloats > 0
end

-- ============================================================================
-- NanoVG 渲染 (全局函数，通过 SubscribeToEvent 绑定)
-- ============================================================================
function HandleDmgFloatRender(eventType, eventData)
    if not nvgDmg or #dmgFloats == 0 or not M.enabled then return end

    local gfx = GetGraphics()
    local physW = gfx:GetWidth()
    local physH = gfx:GetHeight()

    -- 使用与 UI 系统相同的设计分辨率模式
    local scale = math.min(physW / DESIGN_W, physH / DESIGN_H)
    local logicalW = physW / scale
    local logicalH = physH / scale

    nvgBeginFrame(nvgDmg, logicalW, logicalH, scale)

    nvgFontFaceId(nvgDmg, nvgDmgFont)

    -- 飘字锚点: 由外部设置 (设计分辨率坐标)
    local mobAnchorX = M.anchorX
    local mobAnchorY = M.anchorY
    local playerAnchorX = M.playerAnchorX
    local playerAnchorY = M.playerAnchorY

    for _, f in ipairs(dmgFloats) do
        local t = f.elapsed
        local lifeT = t / 2.0

        local riseY = -80 * (1 - (1 - lifeT) * (1 - lifeT))
        local alpha = 1.0
        if lifeT > 0.5 then
            alpha = 1.0 - (lifeT - 0.5) * 2.0
        end
        if alpha <= 0 then goto continueFloat end

        local sc = 1.0
        if f.isCrit then
            if t < 0.15 then
                sc = 1.0 + 1.0 * (t / 0.15)
            elseif t < 0.35 then
                sc = 2.0 - 0.7 * ((t - 0.15) / 0.2)
            else
                sc = 1.3
            end
        end

        -- 受伤飘字(isMob)锚定在玩家血条中间，其他锚定在怪物面板
        local aX = f.isMob and playerAnchorX or mobAnchorX
        local aY = f.isMob and playerAnchorY or mobAnchorY
        local x = aX + f.offsetX
        local y = aY + riseY
        local intAlpha = math.floor(alpha * 255)

        local fSize, cr, cg, cb
        if f.isMob then
            fSize = f.isCrit and 32 or 22
            cr, cg, cb = f.isCrit and 255 or 255, f.isCrit and 50 or 120, f.isCrit and 50 or 100
        elseif f.isSkill then
            fSize = f.isCrit and 36 or 26
            cr, cg, cb = 255, f.isCrit and 200 or 180, f.isCrit and 50 or 80
        else
            fSize = f.isCrit and 38 or 22
            if f.isCrit then
                cr, cg, cb = 255, 230, 50
            else
                cr, cg, cb = 240, 240, 255
            end
        end

        fSize = fSize * sc

        local text
        if f.isCrit then
            text = tostring(f.value) .. "!"
        elseif f.isMob then
            text = "-" .. tostring(f.value)
        else
            text = tostring(f.value)
        end

        nvgFontSize(nvgDmg, fSize)
        nvgTextAlign(nvgDmg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        local outAlpha = math.floor(alpha * 220)
        nvgFillColor(nvgDmg, nvgRGBA(0, 0, 0, outAlpha))
        for _, o in ipairs(OUTLINE_OFFSETS) do
            nvgText(nvgDmg, x + o[1], y + o[2], text)
        end

        nvgFillColor(nvgDmg, nvgRGBA(cr, cg, cb, intAlpha))
        nvgText(nvgDmg, x, y, text)

        if f.isCrit and alpha > 0.2 then
            local glowAlpha = math.floor(alpha * 80)
            nvgFontSize(nvgDmg, fSize * 1.08)
            nvgFillColor(nvgDmg, nvgRGBA(255, 255, 200, glowAlpha))
            nvgText(nvgDmg, x, y, text)
        end

        ::continueFloat::
    end

    nvgEndFrame(nvgDmg)
end

return M
