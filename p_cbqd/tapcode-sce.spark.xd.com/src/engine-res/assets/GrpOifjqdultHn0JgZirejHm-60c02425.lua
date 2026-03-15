--[[
================================================================================
  99_DprResolutionTest.lua - DPR 适配方式演示 Demo
================================================================================

【用途】
  本 Demo 演示基于 DPR（Device Pixel Ratio，设备像素比）的 UI 适配方式。
  通过可视化的方式展示分辨率相关概念，帮助理解 DPR 适配的工作原理。

【适配方式：DPR 适配】
  核心公式：
    逻辑分辨率 = 物理分辨率 / DPR
    UI缩放比例 = DPR

  特点：
    - 以"逻辑像素"为单位定义 UI 尺寸（如 300x300）
    - 不同 DPR 设备上，元素的"物理尺寸"（厘米/英寸）保持一致
    - 高 DPR 设备能显示更多内容，低 DPR 设备显示更少内容
    - 适用于：工具类应用、需要精确物理尺寸的场景

  示例：
    物理分辨率 2560x1440，DPR=2.0 时：
    逻辑分辨率 = 2560/2 x 1440/2 = 1280x720
    一个 300x300 的 UI 元素占用 600x600 物理像素

【测试内容】
  1. 左上角信息面板：显示物理/逻辑分辨率、DPR、UI Root 尺寸等
  2. 左下角 DPR 切换器：点击循环切换模拟不同 DPR（1x ~ 4x）
  3. 右上角 NanoVG 绘制：蓝色 300x300、黄色 150x150 方块
  4. 右下角 UI 组件：红色 300x300、绿色 150x150 方块
  5. 背景网格和标尺：用于测量和验证尺寸

【验证方法】
  - NVG 绘制的方块与 UI 组件的方块尺寸应始终相同
  - 切换 DPR 后，方块的"逻辑尺寸"不变，但占用的屏幕比例会变化
  - 标尺刻度可用于验证绘制精度

【相关文件】
  - 100_DesignResolutionTest.lua: 基于设计分辨率的适配方式（另一种适配方案）

================================================================================
--]]

require "LuaScripts/Utilities/Sample"

---@type NVGContextWrapper|nil
local nvgContext = nil
local fontId = -1

-- UI 元素
local infoText = nil
local measureBox = nil
local uiBoxContainer = nil
local interactPanel = nil
local infoPanel = nil
local dprDisplayText = nil
local dprModeText = nil

-- 分辨率信息
local resInfo = {
    logicWidth = 0,
    logicHeight = 0,
    deviceWidth = 0,
    deviceHeight = 0,
    dpr = 1.0,
    uiScale = 1.0
}

-- DPR 控制
local systemDpr = 1.0      -- 系统原始 DPR
local customDpr = nil      -- 用户自定义 DPR（nil 表示使用系统值）

function Start()
    SampleStart()

    -- 创建 NanoVG 上下文
    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- 加载字体
    fontId = nvgCreateFont(nvgContext, "misans", "Fonts/MiSans-Regular.ttf")
    if fontId == -1 then
        print("WARNING: Failed to load font, text will not be displayed")
    end

    -- 更新分辨率信息
    UpdateResolutionInfo()

    -- 创建 UI 元素
    CreateUI()

    SampleInitMouseMode(MM_FREE)

    -- 订阅事件
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    -- C++ bug 已修复，不再需要每帧强制设置
    -- 更新显示
    UpdateInfoText()
    UpdateDprDisplay()
end

function Stop()
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

function UpdateResolutionInfo()
    local graphics = GetGraphics()
    
    -- 物理分辨率 (device pixels)
    resInfo.deviceWidth = graphics:GetWidth()
    resInfo.deviceHeight = graphics:GetHeight()
    
    -- 系统 DPR
    systemDpr = graphics:GetDPR()
    
    -- 使用自定义 DPR 或系统 DPR
    resInfo.dpr = customDpr or systemDpr
    
    -- 逻辑分辨率 (自己算: 物理 / DPR)
    resInfo.logicWidth = math.floor(resInfo.deviceWidth / resInfo.dpr)
    resInfo.logicHeight = math.floor(resInfo.deviceHeight / resInfo.dpr)
    
    -- 设置 scale 前的 UI Root 尺寸
    local uiRoot = ui:GetRoot()
    local beforeW, beforeH = uiRoot:GetWidth(), uiRoot:GetHeight()
    
    -- 设置 UI 系统缩放（根据 DPR 自动缩放）
    ui:SetScale(Vector2(resInfo.dpr, resInfo.dpr))
    
    -- 更新 UI 缩放值
    local uiScaleVec = ui:GetScale()
    resInfo.uiScale = uiScaleVec.x
    
    -- 设置 scale 后的 UI Root 尺寸
    resInfo.uiRootWidth = uiRoot:GetWidth()
    resInfo.uiRootHeight = uiRoot:GetHeight()
    
    -- ★ 关键：强制所有子元素重新计算布局
    uiRoot:UpdateLayout()
    
    print(string.format("[Resolution] device=%.0fx%.0f, logic=%.0fx%.0f, dpr=%.2f (system=%.2f, custom=%s)",
        resInfo.deviceWidth, resInfo.deviceHeight,
        resInfo.logicWidth, resInfo.logicHeight,
        resInfo.dpr, systemDpr, customDpr and tostring(customDpr) or "nil"))
    print(string.format("[UIRoot] before=%.0fx%.0f, after=%.0fx%.0f, scale=%.2f",
        beforeW, beforeH,
        resInfo.uiRootWidth, resInfo.uiRootHeight,
        resInfo.uiScale))
    
    -- 打印 UI 组件的实际位置和尺寸
    PrintUIDebugInfo()
end

function PrintUIDebugInfo()
    if infoPanel then
        local pos = infoPanel:GetPosition()
        local size = infoPanel:GetSize()
        local screenPos = infoPanel:GetScreenPosition()
        print(string.format("[infoPanel] pos=(%d,%d) size=%dx%d screenPos=(%d,%d)",
            pos.x, pos.y, size.x, size.y, screenPos.x, screenPos.y))
    end
    
    if uiBoxContainer then
        local pos = uiBoxContainer:GetPosition()
        local size = uiBoxContainer:GetSize()
        local screenPos = uiBoxContainer:GetScreenPosition()
        print(string.format("[uiBoxContainer] pos=(%d,%d) size=%dx%d screenPos=(%d,%d)",
            pos.x, pos.y, size.x, size.y, screenPos.x, screenPos.y))
    end
    
    if interactPanel then
        local pos = interactPanel:GetPosition()
        local size = interactPanel:GetSize()
        local screenPos = interactPanel:GetScreenPosition()
        print(string.format("[interactPanel] pos=(%d,%d) size=%dx%d screenPos=(%d,%d)",
            pos.x, pos.y, size.x, size.y, screenPos.x, screenPos.y))
    end
end

function CreateUI()
    local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")

    -- ========== 左上角：信息面板 ==========
    infoPanel = Window:new()  -- 去掉 local，保存到全局变量
    infoPanel:SetStyleAuto()
    infoPanel:SetLayout(LM_VERTICAL, 6, IntRect(12, 12, 12, 12))
    infoPanel:SetAlignment(HA_LEFT, VA_TOP)
    infoPanel:SetPosition(45, 45)
    infoPanel.color = Color(0.1, 0.2, 0.4, 0.85)
    ui.root:AddChild(infoPanel)

    local title = Text:new()
    title:SetStyleAuto()
    title.text = "分辨率测试"
    title:SetFont(font, 16)
    title.color = Color(1, 1, 0.6)
    infoPanel:AddChild(title)

    infoText = Text:new()
    infoText:SetStyleAuto()
    infoText:SetFont(font, 13)
    infoText.color = Color(1, 1, 1)
    infoPanel:AddChild(infoText)

    UpdateInfoText()

    -- ========== 右下角：UI 测量方块（竖排）==========
    uiBoxContainer = UIElement:new()  -- 去掉 local
    uiBoxContainer:SetLayout(LM_VERTICAL, 10)  -- 竖排布局
    uiBoxContainer:SetAlignment(HA_RIGHT, VA_BOTTOM)
    uiBoxContainer:SetPosition(-20, -20)
    ui.root:AddChild(uiBoxContainer)

    -- 150x150 绿色测量框（用 Window 实现边框效果）
    local measureBox2 = Window:new()
    measureBox2:SetStyleAuto()
    measureBox2:SetSize(150, 150)
    measureBox2:SetMinSize(150, 150)  -- 确保参与布局计算
    measureBox2.color = Color(0.3, 1, 0.3, 0.7)
    measureBox2:SetBringToBack(true)
    uiBoxContainer:AddChild(measureBox2)

    local boxLabel2 = Text:new()
    boxLabel2:SetStyleAuto()
    boxLabel2.text = "UI 150"
    boxLabel2:SetFont(font, 14)
    boxLabel2.color = Color(1, 1, 1)
    boxLabel2:SetAlignment(HA_CENTER, VA_CENTER)
    measureBox2:AddChild(boxLabel2)

    -- 300x300 红色测量框
    measureBox = Window:new()
    measureBox:SetStyleAuto()
    measureBox:SetSize(300, 300)
    measureBox:SetMinSize(300, 300)  -- 确保参与布局计算
    measureBox.color = Color(1, 0.3, 0.3, 0.7)
    measureBox:SetBringToBack(true)
    uiBoxContainer:AddChild(measureBox)

    local boxLabel = Text:new()
    boxLabel:SetStyleAuto()
    boxLabel.text = "UI 300x300"
    boxLabel:SetFont(font, 18)
    boxLabel.color = Color(1, 1, 1)
    boxLabel:SetAlignment(HA_CENTER, VA_CENTER)
    measureBox:AddChild(boxLabel)

    -- ========== 左下角：DPR 切换按钮（整个区域可点击）==========
    interactPanel = Button:new()  -- 用 Button 代替 Window，整个区域可点击
    interactPanel:SetStyleAuto()
    interactPanel:SetLayout(LM_VERTICAL, 8, IntRect(20, 20, 20, 20))
    interactPanel:SetAlignment(HA_LEFT, VA_BOTTOM)
    interactPanel:SetPosition(45, -20)
    interactPanel:SetMinSize(160, 100)
    interactPanel.color = Color(0.2, 0.3, 0.2, 0.9)  -- 深绿色
    ui.root:AddChild(interactPanel)

    -- 标题（禁用输入，让点击穿透到按钮）
    local dprTitle = Text:new()
    dprTitle:SetStyleAuto()
    dprTitle.text = "点击模拟 DPR"
    dprTitle:SetFont(font, 14)
    dprTitle.color = Color(0.8, 0.9, 1.0)
    dprTitle:SetAlignment(HA_CENTER, VA_TOP)
    dprTitle:SetEnabled(false)  -- 禁用输入
    interactPanel:AddChild(dprTitle)

    -- 当前 DPR 显示（大字）
    dprDisplayText = Text:new()  -- 全局变量，方便更新
    dprDisplayText:SetStyleAuto()
    dprDisplayText:SetFont(font, 28)
    dprDisplayText.color = Color(1, 1, 0.6)
    dprDisplayText:SetAlignment(HA_CENTER, VA_CENTER)
    dprDisplayText:SetEnabled(false)  -- 禁用输入
    interactPanel:AddChild(dprDisplayText)

    -- 模式提示
    dprModeText = Text:new()  -- 全局变量
    dprModeText:SetStyleAuto()
    dprModeText:SetFont(font, 12)
    dprModeText.color = Color(0.7, 0.8, 0.9)
    dprModeText:SetAlignment(HA_CENTER, VA_BOTTOM)
    dprModeText:SetEnabled(false)  -- 禁用输入
    interactPanel:AddChild(dprModeText)

    -- 更新 DPR 显示
    UpdateDprDisplay()

    -- DPR 档位列表：1 -> 1.5 -> 2 -> 2.5 -> 3 -> 3.5 -> 4 -> 原始(0)
    local dprLevels = {1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 0}  -- 0 表示原始
    local lastClickTime = 0  -- 防抖用

    -- 点击事件：循环切换 DPR
    SubscribeToEvent(interactPanel, "Pressed", function()
        -- 防抖：300ms 内的重复点击忽略
        local currentTime = time:GetElapsedTime()
        if currentTime - lastClickTime < 0.3 then
            print("[DPR] Debounced, ignoring duplicate click")
            return
        end
        lastClickTime = currentTime
        
        -- 找到当前档位索引
        local foundIndex = #dprLevels  -- 默认最后一个（原始）
        local currentValue = customDpr or 0  -- nil 转为 0
        for i, v in ipairs(dprLevels) do
            if currentValue == v then
                foundIndex = i
                break
            end
        end
        -- 切到下一档
        local nextIndex = (foundIndex % #dprLevels) + 1
        local nextValue = dprLevels[nextIndex]
        -- 0 表示原始，转回 nil
        if nextValue == 0 then
            customDpr = nil
        else
            customDpr = nextValue
        end
        
        UpdateResolutionInfo()
        UpdateDprDisplay()
        UpdateInfoText()
        print(string.format("[DPR] Switched to %s", customDpr and tostring(customDpr) or "system"))
    end)
end

-- 更新 DPR 显示文本
function UpdateDprDisplay()
    if dprDisplayText == nil then return end
    
    if customDpr then
        dprDisplayText.text = string.format("%.1fx", customDpr)
        dprModeText.text = "自定义"
        dprModeText.color = Color(1, 0.8, 0.4)
    else
        dprDisplayText.text = string.format("%.1fx", systemDpr)
        dprModeText.text = "设备原始"
        dprModeText.color = Color(0.4, 1, 0.6)
    end
end

function UpdateInfoText()
    if infoText == nil then return end
    
    local dprMode = customDpr and string.format("%.1f (自定义)", customDpr) or string.format("%.1f (系统)", systemDpr)
    
    local text = string.format(
        "物理分辨率 (device): %.0f x %.0f\n" ..
        "逻辑分辨率 (logic):  %.0f x %.0f\n" ..
        "DPR: %.1f [%s]\n" ..
        "---\n" ..
        "UI Root: %.0f x %.0f\n" ..
        "UI Scale: %.1f\n" ..
        "---\n" ..
        "NVG 绘制: %.0f x %.0f (逻辑)",
        resInfo.deviceWidth, resInfo.deviceHeight,
        resInfo.logicWidth, resInfo.logicHeight,
        resInfo.dpr, dprMode,
        resInfo.uiRootWidth or 0, resInfo.uiRootHeight or 0,
        resInfo.uiScale,
        resInfo.logicWidth, resInfo.logicHeight
    )
    infoText.text = text
end

function HandleScreenMode(eventType, eventData)
    UpdateResolutionInfo()
    UpdateInfoText()
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then return end

    -- 使用缓存的分辨率信息（在 ScreenMode 事件中更新）
    nvgBeginFrame(nvgContext, resInfo.logicWidth, resInfo.logicHeight, resInfo.dpr)
    
    DrawResolutionTest(nvgContext, resInfo.logicWidth, resInfo.logicHeight)
    
    nvgEndFrame(nvgContext)
end

function DrawResolutionTest(ctx, width, height)
    -- 绘制网格背景（每 100 像素）- 粗线，亮灰色
    DrawGrid(ctx, width, height, 100, nvgRGBA(120, 120, 140, 255))
    
    -- 绘制更细的网格（每 50 像素）- 细线，暗灰色
    DrawGrid(ctx, width, height, 50, nvgRGBA(80, 80, 100, 255))

    -- 绘制标尺
    DrawRuler(ctx, width, height)

    -- 绘制测量参考图形
    DrawMeasureShapes(ctx, width, height)

    -- 绘制中心十字线
    DrawCenterCross(ctx, width, height)

    -- 绘制信息
    DrawInfo(ctx, width, height)
end

function DrawGrid(ctx, width, height, step, color)
    nvgBeginPath(ctx)
    nvgStrokeColor(ctx, color)
    nvgStrokeWidth(ctx, 1)

    -- 垂直线
    for x = 0, width, step do
        nvgMoveTo(ctx, x, 0)
        nvgLineTo(ctx, x, height)
    end

    -- 水平线
    for y = 0, height, step do
        nvgMoveTo(ctx, 0, y)
        nvgLineTo(ctx, width, y)
    end

    nvgStroke(ctx)
end

function DrawRuler(ctx, width, height)
    local rulerSize = 35
    local tickSmall = 5
    local tickMedium = 10
    local tickLarge = 16

    -- 顶部标尺背景
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, rulerSize)
    nvgFillColor(ctx, nvgRGBA(40, 40, 50, 230))
    nvgFill(ctx)

    -- 左侧标尺背景
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, rulerSize, rulerSize, height - rulerSize)
    nvgFillColor(ctx, nvgRGBA(40, 40, 50, 230))
    nvgFill(ctx)

    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 200))
    nvgStrokeWidth(ctx, 1)

    -- 顶部标尺刻度
    nvgBeginPath(ctx)
    for x = 0, width, 10 do
        local tick = tickSmall
        if x % 100 == 0 then
            tick = tickLarge
        elseif x % 50 == 0 then
            tick = tickMedium
        end
        nvgMoveTo(ctx, x, rulerSize)
        nvgLineTo(ctx, x, rulerSize - tick)
    end
    nvgStroke(ctx)

    -- 左侧标尺刻度（刻度值直接对应 y 坐标，与网格线对齐）
    nvgBeginPath(ctx)
    for y = rulerSize, height, 10 do
        local tick = tickSmall
        if y % 100 == 0 then
            tick = tickLarge
        elseif y % 50 == 0 then
            tick = tickMedium
        end
        nvgMoveTo(ctx, rulerSize, y)
        nvgLineTo(ctx, rulerSize - tick, y)
    end
    nvgStroke(ctx)

    -- 标尺数字
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 14)  -- 加大字体
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))

        -- 顶部数字（显示完整：100, 200, 300...）
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        for x = 100, width, 100 do
            nvgText(ctx, x, rulerSize - tickLarge - 1, tostring(x), nil)
        end

        -- 左侧数字（旋转90度，刻度值直接对应 y 坐标）
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        for y = 100, height, 100 do
            if y >= rulerSize then  -- 确保在可见区域
                nvgSave(ctx)
                nvgTranslate(ctx, rulerSize / 2, y)
                nvgRotate(ctx, -math.pi / 2)  -- 旋转 -90 度
                nvgText(ctx, 0, 0, tostring(y), nil)
                nvgRestore(ctx)
            end
        end

        -- 左上角显示单位 px（加大加粗）
        nvgFontSize(ctx, 16)  -- 加大字体
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 100, 255))  -- 更亮的黄色
        nvgText(ctx, rulerSize / 2, rulerSize / 2, "px", nil)
    end
end

function DrawMeasureShapes(ctx, width, height)
    -- NVG 方块在右上角横排布局
    local rulerSize = 35
    local nvgBoxY = rulerSize + 10
    
    -- 300x300 蓝框（最右边）
    local nvgBox1X = width - 300 - 20
    
    nvgBeginPath(ctx)
    nvgRect(ctx, nvgBox1X, nvgBoxY, 300, 300)
    nvgFillColor(ctx, nvgRGBA(100, 150, 255, 150))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(100, 150, 255, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    -- 150x150 黄框（在 300 框左边）
    local nvgBox2X = nvgBox1X - 150 - 20
    
    nvgBeginPath(ctx)
    nvgRect(ctx, nvgBox2X, nvgBoxY, 150, 150)
    nvgFillColor(ctx, nvgRGBA(255, 200, 100, 150))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 200, 100, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    -- 标签
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 16)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))

        nvgText(ctx, nvgBox1X + 150, nvgBoxY + 150, "NVG 300x300", nil)
        nvgText(ctx, nvgBox2X + 75, nvgBoxY + 75, "NVG 150", nil)
    end

    -- 圆形测试（在黄框下方）
    local circleX = nvgBox2X + 75
    local circleY = nvgBoxY + 150 + 40 + 50
    
    nvgBeginPath(ctx)
    nvgCircle(ctx, circleX, circleY, 50)
    nvgFillColor(ctx, nvgRGBA(255, 100, 150, 150))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    if fontId ~= -1 then
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(ctx, circleX, circleY, "r=50", nil)
    end
end

function DrawCenterCross(ctx, width, height)
    local cx = width / 2
    local cy = height / 2
    local size = 50

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - size, cy)
    nvgLineTo(ctx, cx + size, cy)
    nvgMoveTo(ctx, cx, cy - size)
    nvgLineTo(ctx, cx, cy + size)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 0, 200))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- 中心点
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, 5)
    nvgFillColor(ctx, nvgRGBA(255, 255, 0, 255))
    nvgFill(ctx)

    -- 坐标标注
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
        nvgFillColor(ctx, nvgRGBA(255, 255, 0, 255))
        nvgText(ctx, cx + 10, cy - 5, string.format("中心 (%d, %d)", math.floor(cx), math.floor(cy)), nil)
    end
end

function DrawInfo(ctx, width, height)
    if fontId == -1 then return end

    nvgFontFaceId(ctx, fontId)
    nvgFontSize(ctx, 13)
    
    -- 中间提示
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 255, 150, 200))
    nvgText(ctx, width / 2, 40, "右上NVG vs 右下UI - 尺寸应相同", nil)
end

function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end

