--[[
================================================================================
  99_DesignResolutionTest.lua - 设计分辨率适配方式演示 Demo
================================================================================

【用途】
  本 Demo 演示基于设计分辨率（Design Resolution）的 UI 适配方式。
  这是游戏开发中最常用的适配方案（Cocos2d、Unity Canvas Scaler 等都采用此方式）。

【适配方式：设计分辨率适配（SHOW_ALL 策略）】
  核心公式：
    scaleX = 物理宽度 / 设计宽度
    scaleY = 物理高度 / 设计高度
    scale = min(scaleX, scaleY)  -- 保证设计内容完全可见
    虚拟分辨率 = 物理分辨率 / scale

  特点：
    - 以"设计分辨率"为基准定义 UI 尺寸（如 1920×1080 下的 300×300）
    - 不同设备上，元素的"屏幕占比"基本一致
    - 宽高比不同时会有额外可见区域（而非黑边）
    - 适用于：游戏、展示类应用

  示例：
    物理分辨率 2560×1440，设计分辨率 1920×1080 时：
    scaleX = 2560/1920 = 1.333, scaleY = 1440/1080 = 1.333
    scale = 1.333，虚拟分辨率 = 1920×1080（刚好匹配）

【测试内容】
  1. 左上角信息面板：显示物理/设计/虚拟分辨率、缩放比例、DPR 等
  2. 左下角设计分辨率切换器：点击循环切换不同预设（16:9、4:3、竖屏等）
  3. 右上角 NanoVG 绘制：蓝色 300×300、黄色 150×150 方块
  4. 右下角 UI 组件：红色 300×300、绿色 150×150 方块
  5. 背景网格和标尺：用于测量和验证尺寸
  6. 设计区域边界：绿色虚线标出设计安全区

【验证方法】
  - 切换设计分辨率后，方块的"屏幕占比"会变化（与 DPR 适配不同）
  - 设计区域内的内容始终完全可见
  - 设计区域外的部分是"额外可见区域"

【相关文件】
  - 99_DprResolutionTest.lua: 基于 DPR 的适配方式（另一种适配方案）

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
local designDisplayText = nil
local designModeText = nil
local designContainer = nil  -- 设计区域容器（子元素坐标相对于设计区域）
local customDesignMode = false  -- 是否使用自定义设计分辨率

-- NVG 滑块状态（物理像素坐标）
local nvgSlider = {
    draggingHeight = false,  -- 是否正在拖拽高度滑块
    draggingWidth = false,   -- 是否正在拖拽宽度滑块
    -- 基准尺寸（物理像素）
    trackLength = 200,
    trackThickness = 24,      -- 绘制粗细
    hitAreaThickness = 60,    -- 触摸检测区域（更大，更容易点中）
    knobLength = 30,
    offsetFromCenter = 120,   -- 距离屏幕中心的偏移
}

-- 设计分辨率预设（不同宽高比）
local designPresets = {
    {name = "1920×1080", w = 1920, h = 1080, ratio = "16:9"},
    {name = "1280×720",  w = 1280, h = 720,  ratio = "16:9"},
    {name = "1920×1200", w = 1920, h = 1200, ratio = "16:10"},
    {name = "2048×1536", w = 2048, h = 1536, ratio = "4:3"},
    {name = "1024×768",  w = 1024, h = 768,  ratio = "4:3"},
    {name = "1080×1920", w = 1080, h = 1920, ratio = "9:16 竖屏"},
    {name = "750×1334",  w = 750,  h = 1334, ratio = "iPhone"},
}
local currentPresetIndex = 1

-- 分辨率信息
local resInfo = {
    deviceWidth = 0,      -- 物理宽度
    deviceHeight = 0,     -- 物理高度
    designWidth = 1920,   -- 设计宽度
    designHeight = 1080,  -- 设计高度
    virtualWidth = 0,     -- 虚拟宽度（UI坐标系）
    virtualHeight = 0,    -- 虚拟高度
    scale = 1.0,          -- 缩放比例
    scaleX = 1.0,         -- X方向缩放
    scaleY = 1.0,         -- Y方向缩放
    offsetX = 0,          -- 设计区域X偏移
    offsetY = 0,          -- 设计区域Y偏移
    dpr = 1.0,            -- 系统 DPR（只读显示）
    uiScale = 1.0
}

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
    SubscribeToEvent("NanoVGRender", "HandleRender")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    UpdateInfoText()
    UpdateDesignDisplay()
    
    -- NVG 滑块输入处理（支持鼠标和触摸，物理像素坐标）
    local input = GetInput()
    local s = nvgSlider
    
    -- 获取输入位置和按下状态（先鼠标，有触摸时覆盖）
    local pointerX = input:GetMousePosition().x
    local pointerY = input:GetMousePosition().y
    local pointerDown = input:GetMouseButtonDown(MOUSEB_LEFT)
    
    -- 有触摸时覆盖鼠标状态
    if input:GetNumTouches() > 0 then
        local touch = input:GetTouch(0)
        pointerX = touch.position.x
        pointerY = touch.position.y
        pointerDown = true
    end
    
    local deviceW = resInfo.deviceWidth or 800
    local deviceH = resInfo.deviceHeight or 600
    local centerX = deviceW / 2
    local centerY = deviceH / 2
    local hitThick = s.hitAreaThickness or 60
    
    -- 高度滑块触摸检测区域
    local hTrackX = centerX - s.offsetFromCenter - hitThick / 2
    local hTrackY = centerY - s.trackLength / 2
    local hTrackW = hitThick
    local hTrackH = s.trackLength
    
    -- 宽度滑块触摸检测区域
    local wTrackX = centerX - s.trackLength / 2
    local wTrackY = centerY + s.offsetFromCenter - hitThick / 2
    local wTrackW = s.trackLength
    local wTrackH = hitThick
    
    -- 检测按下/触摸
    if pointerDown then
        -- 只有在还没开始拖拽时，才判断是否在区域内开始新的拖拽
        if not s.draggingHeight and not s.draggingWidth then
            -- 判断是否在高度滑块区域
            if pointerX >= hTrackX and pointerX <= hTrackX + hTrackW and
               pointerY >= hTrackY and pointerY <= hTrackY + hTrackH then
                s.draggingHeight = true
            -- 判断是否在宽度滑块区域
            elseif pointerX >= wTrackX and pointerX <= wTrackX + wTrackW and
                   pointerY >= wTrackY and pointerY <= wTrackY + wTrackH then
                s.draggingWidth = true
            end
        end
        
        -- 已经在拖拽，持续更新值（不管手指是否还在区域内）
        if s.draggingHeight then
            local localY = pointerY - hTrackY
            local ratio = localY / hTrackH
            ratio = math.max(0, math.min(1, ratio))
            local val = math.floor((400 + ratio * 2800) / 10) * 10
            if val ~= resInfo.designHeight then
                resInfo.designHeight = val
                customDesignMode = true
                UpdateResolutionInfo()
                UpdateDesignDisplay()
            end
        end
        
        if s.draggingWidth then
            local localX = pointerX - wTrackX
            local ratio = localX / wTrackW
            ratio = math.max(0, math.min(1, ratio))
            local val = math.floor((400 + ratio * 2800) / 10) * 10
            if val ~= resInfo.designWidth then
                resInfo.designWidth = val
                customDesignMode = true
                UpdateResolutionInfo()
                UpdateDesignDisplay()
            end
        end
    else
        -- 松开，停止拖拽
        s.draggingHeight = false
        s.draggingWidth = false
    end
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
    
    -- 系统 DPR（只读）
    resInfo.dpr = graphics:GetDPR()
    
    -- 当前设计分辨率（非自定义模式时从预设获取）
    if not customDesignMode then
        local preset = designPresets[currentPresetIndex]
        resInfo.designWidth = preset.w
        resInfo.designHeight = preset.h
    end
    
    -- 计算缩放比例（SHOW_ALL 策略：取小的，保证内容完全可见）
    resInfo.scaleX = resInfo.deviceWidth / resInfo.designWidth
    resInfo.scaleY = resInfo.deviceHeight / resInfo.designHeight
    resInfo.scale = math.min(resInfo.scaleX, resInfo.scaleY)
    
    -- 虚拟分辨率（UI坐标系实际可用范围）
    resInfo.virtualWidth = resInfo.deviceWidth / resInfo.scale
    resInfo.virtualHeight = resInfo.deviceHeight / resInfo.scale
    
    -- 设计区域在虚拟坐标系中的偏移（居中）
    resInfo.offsetX = (resInfo.virtualWidth - resInfo.designWidth) / 2
    resInfo.offsetY = (resInfo.virtualHeight - resInfo.designHeight) / 2
    
    -- 设置 UI 系统缩放
    local uiRoot = ui:GetRoot()
    ui:SetScale(Vector2(resInfo.scale, resInfo.scale))
    
    -- 更新 UI 缩放值
    local uiScaleVec = ui:GetScale()
    resInfo.uiScale = uiScaleVec.x
    
    -- 设置 scale 后的 UI Root 尺寸
    resInfo.uiRootWidth = uiRoot:GetWidth()
    resInfo.uiRootHeight = uiRoot:GetHeight()
    
    -- 更新设计区域容器的位置和大小
    if designContainer then
        designContainer:SetPosition(math.floor(resInfo.offsetX), math.floor(resInfo.offsetY))
        designContainer:SetSize(math.floor(resInfo.designWidth), math.floor(resInfo.designHeight))
    end
    
    -- 强制所有子元素重新计算布局
    uiRoot:UpdateLayout()
end

function CreateUI()
    local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")

    -- ========== 设计区域容器（子元素坐标相对于设计区域）==========
    designContainer = UIElement:new()
    designContainer:SetPosition(math.floor(resInfo.offsetX), math.floor(resInfo.offsetY))
    designContainer:SetSize(math.floor(resInfo.designWidth), math.floor(resInfo.designHeight))
    designContainer:SetClipChildren(true)  -- 裁剪超出设计区域的内容
    ui.root:AddChild(designContainer)

    -- 测试：设计区域左上角的小方块
    local cornerBox = Window:new()
    cornerBox:SetStyleAuto()
    cornerBox:SetSize(180, 60)
    cornerBox:SetPosition(50, 50)  -- 向内偏移
    cornerBox.color = Color(1, 0.5, 0, 0.5)  -- 橙色半透明
    designContainer:AddChild(cornerBox)

    local cornerLabel = Text:new()
    cornerLabel:SetStyleAuto()
    cornerLabel.text = "UI 180x60（设计空间）"
    cornerLabel:SetFont(font, 13)
    cornerLabel.color = Color(1, 1, 1)
    cornerLabel:SetAlignment(HA_CENTER, VA_CENTER)
    cornerBox:AddChild(cornerLabel)

    -- 测试：设计区域右下角的小方块
    local cornerBox2 = Window:new()
    cornerBox2:SetStyleAuto()
    cornerBox2:SetSize(180, 60)
    cornerBox2:SetAlignment(HA_RIGHT, VA_BOTTOM)
    cornerBox2:SetPosition(-50, -50)  -- 向内偏移
    cornerBox2.color = Color(0, 0.8, 1, 0.5)  -- 青色半透明
    designContainer:AddChild(cornerBox2)

    local cornerLabel2 = Text:new()
    cornerLabel2:SetStyleAuto()
    cornerLabel2.text = "UI 180x60（设计空间）"
    cornerLabel2:SetFont(font, 13)
    cornerLabel2.color = Color(1, 1, 1)
    cornerLabel2:SetAlignment(HA_CENTER, VA_CENTER)
    cornerBox2:AddChild(cornerLabel2)

    -- ========== 左上角：信息面板 ==========
    infoPanel = Window:new()
    infoPanel:SetStyleAuto()
    infoPanel:SetLayout(LM_VERTICAL, 6, IntRect(12, 12, 12, 12))
    infoPanel:SetAlignment(HA_LEFT, VA_TOP)
    infoPanel:SetPosition(45, 45)
    infoPanel.color = Color(0.1, 0.2, 0.4, 0.85)
    ui.root:AddChild(infoPanel)

    local title = Text:new()
    title:SetStyleAuto()
    title.text = "设计分辨率测试"
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
    uiBoxContainer = UIElement:new()
    uiBoxContainer:SetLayout(LM_VERTICAL, 10)
    uiBoxContainer:SetAlignment(HA_RIGHT, VA_BOTTOM)
    uiBoxContainer:SetPosition(-20, -20)
    ui.root:AddChild(uiBoxContainer)

    -- 150x150 绿色测量框
    local measureBox2 = Window:new()
    measureBox2:SetStyleAuto()
    measureBox2:SetSize(150, 150)
    measureBox2:SetMinSize(150, 150)
    measureBox2.color = Color(0.3, 1, 0.3, 0.7)
    measureBox2:SetBringToBack(true)
    uiBoxContainer:AddChild(measureBox2)

    local boxLabel2 = Text:new()
    boxLabel2:SetStyleAuto()
    boxLabel2.text = "UI 150x150（屏幕空间）"
    boxLabel2:SetFont(font, 13)
    boxLabel2.color = Color(1, 1, 1)
    boxLabel2:SetAlignment(HA_CENTER, VA_CENTER)
    measureBox2:AddChild(boxLabel2)

    -- 300x300 红色测量框
    measureBox = Window:new()
    measureBox:SetStyleAuto()
    measureBox:SetSize(300, 300)
    measureBox:SetMinSize(300, 300)
    measureBox.color = Color(1, 0.3, 0.3, 0.7)
    measureBox:SetBringToBack(true)
    uiBoxContainer:AddChild(measureBox)

    local boxLabel = Text:new()
    boxLabel:SetStyleAuto()
    boxLabel.text = "UI 300x300（屏幕空间）"
    boxLabel:SetFont(font, 15)
    boxLabel.color = Color(1, 1, 1)
    boxLabel:SetAlignment(HA_CENTER, VA_CENTER)
    measureBox:AddChild(boxLabel)

    -- ========== 左下角：设计分辨率切换按钮 ==========
    interactPanel = Button:new()
    interactPanel:SetStyleAuto()
    interactPanel:SetLayout(LM_VERTICAL, 8, IntRect(20, 20, 20, 20))
    interactPanel:SetAlignment(HA_LEFT, VA_BOTTOM)
    interactPanel:SetPosition(45, -20)
    interactPanel:SetMinSize(180, 100)
    interactPanel.color = Color(0.2, 0.2, 0.35, 0.9)
    ui.root:AddChild(interactPanel)

    -- 标题
    local switchTitle = Text:new()
    switchTitle:SetStyleAuto()
    switchTitle.text = "点击切换设计分辨率"
    switchTitle:SetFont(font, 13)
    switchTitle.color = Color(0.8, 0.9, 1.0)
    switchTitle:SetAlignment(HA_CENTER, VA_TOP)
    switchTitle:SetEnabled(false)
    interactPanel:AddChild(switchTitle)

    -- 当前设计分辨率显示
    designDisplayText = Text:new()
    designDisplayText:SetStyleAuto()
    designDisplayText:SetFont(font, 22)
    designDisplayText.color = Color(1, 1, 0.6)
    designDisplayText:SetAlignment(HA_CENTER, VA_CENTER)
    designDisplayText:SetEnabled(false)
    interactPanel:AddChild(designDisplayText)

    -- 宽高比提示
    designModeText = Text:new()
    designModeText:SetStyleAuto()
    designModeText:SetFont(font, 12)
    designModeText.color = Color(0.7, 0.8, 0.9)
    designModeText:SetAlignment(HA_CENTER, VA_BOTTOM)
    designModeText:SetEnabled(false)
    interactPanel:AddChild(designModeText)

    UpdateDesignDisplay()

    local lastClickTime = 0

    -- 点击事件：循环切换设计分辨率预设
    SubscribeToEvent(interactPanel, "Pressed", function()
        local currentTime = time:GetElapsedTime()
        if currentTime - lastClickTime < 0.3 then
            return
        end
        lastClickTime = currentTime
        
        -- 切到下一个预设
        currentPresetIndex = (currentPresetIndex % #designPresets) + 1
        customDesignMode = false  -- 切换预设时退出自定义模式
        
        UpdateResolutionInfo()
        UpdateDesignDisplay()
        UpdateInfoText()
    end)

    -- NVG 滑块会在 DrawNvgSliders 中绘制，在 HandleUpdate 中处理鼠标
end

function UpdateDesignDisplay()
    if designDisplayText == nil then return end
    
    if customDesignMode then
        designDisplayText.text = string.format("%d×%d", math.floor(resInfo.designWidth), math.floor(resInfo.designHeight))
        designModeText.text = "自定义"
        designModeText.color = Color(1, 0.8, 0.4)
    else
        local preset = designPresets[currentPresetIndex]
        designDisplayText.text = preset.name
        designModeText.text = preset.ratio
        designModeText.color = Color(0.7, 0.8, 0.9)
    end
end

function UpdateInfoText()
    if infoText == nil then return end
    
    local ratioText = customDesignMode and "自定义" or designPresets[currentPresetIndex].ratio
    
    local text = string.format(
        "物理分辨率: %.0f × %.0f\n" ..
        "设计分辨率: %.0f × %.0f (%s)\n" ..
        "虚拟分辨率: %.0f × %.0f\n" ..
        "---\n" ..
        "缩放比例: %.3f (X:%.3f Y:%.3f)\n" ..
        "设计区域偏移: (%.1f, %.1f)\n" ..
        "---\n" ..
        "UI Root: %.0f × %.0f\n" ..
        "DPR: %.1f (系统)",
        resInfo.deviceWidth, resInfo.deviceHeight,
        resInfo.designWidth, resInfo.designHeight, ratioText,
        resInfo.virtualWidth, resInfo.virtualHeight,
        resInfo.scale, resInfo.scaleX, resInfo.scaleY,
        resInfo.offsetX, resInfo.offsetY,
        resInfo.uiRootWidth or 0, resInfo.uiRootHeight or 0,
        resInfo.dpr
    )
    infoText.text = text
end

function HandleScreenMode(eventType, eventData)
    UpdateResolutionInfo()
    UpdateInfoText()
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then return end

    nvgBeginFrame(nvgContext, resInfo.virtualWidth, resInfo.virtualHeight, resInfo.scale)
    
    DrawResolutionTest(nvgContext, resInfo.virtualWidth, resInfo.virtualHeight)
    
    nvgEndFrame(nvgContext)
    
    -- 绘制 NVG 滑块（物理像素坐标，单独的 frame）
    DrawNvgSliders(nvgContext)
end

-- 绘制 NVG 滑块（物理像素坐标）
function DrawNvgSliders(ctx)
    local deviceW = resInfo.deviceWidth or 800
    local deviceH = resInfo.deviceHeight or 600
    
    -- 用物理像素开始一个新的 frame（scale=1）
    nvgBeginFrame(ctx, deviceW, deviceH, 1.0)
    
    local centerX = deviceW / 2
    local centerY = deviceH / 2
    local s = nvgSlider
    
    -- ========== 高度滑块（垂直，屏幕中心左侧） ==========
    local hTrackX = centerX - s.offsetFromCenter - s.trackThickness / 2
    local hTrackY = centerY - s.trackLength / 2
    local hTrackW = s.trackThickness
    local hTrackH = s.trackLength
    
    -- 轨道背景
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, hTrackX, hTrackY, hTrackW, hTrackH, 4)
    nvgFillColor(ctx, nvgRGBA(60, 60, 80, 200))
    nvgFill(ctx)
    
    -- 滑块
    local hRatio = (resInfo.designHeight - 400) / 2800
    hRatio = math.max(0, math.min(1, hRatio))
    local hKnobY = hTrackY + hRatio * (hTrackH - s.knobLength)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, hTrackX, hKnobY, hTrackW, s.knobLength, 4)
    if s.draggingHeight then
        nvgFillColor(ctx, nvgRGBA(100, 200, 255, 255))
    else
        nvgFillColor(ctx, nvgRGBA(50, 150, 220, 255))
    end
    nvgFill(ctx)
    
    -- 高度数值标签
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 150, 255))
        nvgText(ctx, hTrackX - 10, centerY, tostring(math.floor(resInfo.designHeight)), nil)
        
        nvgFontSize(ctx, 11)
        nvgFillColor(ctx, nvgRGBA(180, 200, 220, 255))
        nvgText(ctx, hTrackX - 10, centerY - 18, "高度", nil)
    end
    
    -- ========== 宽度滑块（水平，屏幕中心下侧） ==========
    local wTrackX = centerX - s.trackLength / 2
    local wTrackY = centerY + s.offsetFromCenter - s.trackThickness / 2
    local wTrackW = s.trackLength
    local wTrackH = s.trackThickness
    
    -- 轨道背景
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, wTrackX, wTrackY, wTrackW, wTrackH, 4)
    nvgFillColor(ctx, nvgRGBA(60, 60, 80, 200))
    nvgFill(ctx)
    
    -- 滑块
    local wRatio = (resInfo.designWidth - 400) / 2800
    wRatio = math.max(0, math.min(1, wRatio))
    local wKnobX = wTrackX + wRatio * (wTrackW - s.knobLength)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, wKnobX, wTrackY, s.knobLength, wTrackH, 4)
    if s.draggingWidth then
        nvgFillColor(ctx, nvgRGBA(100, 200, 255, 255))
    else
        nvgFillColor(ctx, nvgRGBA(50, 150, 220, 255))
    end
    nvgFill(ctx)
    
    -- 宽度数值标签
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 150, 255))
        nvgText(ctx, centerX, wTrackY + wTrackH + 8, tostring(math.floor(resInfo.designWidth)), nil)
        
        nvgFontSize(ctx, 11)
        nvgFillColor(ctx, nvgRGBA(180, 200, 220, 255))
        nvgText(ctx, centerX + 40, wTrackY + wTrackH + 10, "宽度", nil)
    end
    
    nvgEndFrame(ctx)
end

function DrawResolutionTest(ctx, width, height)
    -- 绘制网格背景（每 100 像素）
    DrawGrid(ctx, width, height, 100, nvgRGBA(120, 120, 140, 255))
    
    -- 绘制更细的网格（每 50 像素）
    DrawGrid(ctx, width, height, 50, nvgRGBA(80, 80, 100, 255))

    -- 绘制标尺
    DrawRuler(ctx, width, height)

    -- 绘制设计区域边界（在标尺上层）
    DrawDesignBounds(ctx, width, height)

    -- 绘制测量参考图形
    DrawMeasureShapes(ctx, width, height)

    -- 绘制中心十字线
    DrawCenterCross(ctx, width, height)

    -- 绘制信息
    DrawInfo(ctx, width, height)
end

function DrawDesignBounds(ctx, width, height)
    local x = resInfo.offsetX
    local y = resInfo.offsetY
    local w = resInfo.designWidth
    local h = resInfo.designHeight
    
    -- 绘制设计区域外的半透明遮罩（额外可见区域）
    nvgBeginPath(ctx)
    -- 上方遮罩
    if y > 0 then
        nvgRect(ctx, 0, 0, width, y)
    end
    -- 下方遮罩
    if y + h < height then
        nvgRect(ctx, 0, y + h, width, height - y - h)
    end
    -- 左侧遮罩
    if x > 0 then
        nvgRect(ctx, 0, y, x, h)
    end
    -- 右侧遮罩
    if x + w < width then
        nvgRect(ctx, x + w, y, width - x - w, h)
    end
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 60))
    nvgFill(ctx)
    
    -- 绘制设计区域边界线（绿色粗线）
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgStrokeColor(ctx, nvgRGBA(100, 255, 100, 200))
    nvgStrokeWidth(ctx, 4)
    nvgStroke(ctx)
    
    -- 四角标记
    local cornerSize = 40
    nvgStrokeWidth(ctx, 5)
    nvgStrokeColor(ctx, nvgRGBA(100, 255, 100, 255))
    
    -- 左上角
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + cornerSize)
    nvgLineTo(ctx, x, y)
    nvgLineTo(ctx, x + cornerSize, y)
    nvgStroke(ctx)
    
    -- 右上角
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + w - cornerSize, y)
    nvgLineTo(ctx, x + w, y)
    nvgLineTo(ctx, x + w, y + cornerSize)
    nvgStroke(ctx)
    
    -- 左下角
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + h - cornerSize)
    nvgLineTo(ctx, x, y + h)
    nvgLineTo(ctx, x + cornerSize, y + h)
    nvgStroke(ctx)
    
    -- 右下角
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + w - cornerSize, y + h)
    nvgLineTo(ctx, x + w, y + h)
    nvgLineTo(ctx, x + w, y + h - cornerSize)
    nvgStroke(ctx)
    
    -- ========== NVG 基于设计坐标系的测试绘制 ==========
    -- 使用 nvgTranslate 偏移到设计区域原点
    nvgSave(ctx)
    nvgTranslate(ctx, x, y)  -- 现在 (0,0) 就是设计区域左上角
    
    -- 设计区域左上角的小方块 - 紫色半透明，向内偏移
    nvgBeginPath(ctx)
    nvgRect(ctx, 50, 50, 180, 60)
    nvgFillColor(ctx, nvgRGBA(180, 100, 255, 128))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 13)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, 50 + 90, 50 + 30, "NVG 180x60（设计空间）", nil)
    end
    
    -- 设计区域右下角的小方块 - 粉色半透明，向内偏移
    nvgBeginPath(ctx)
    nvgRect(ctx, w - 50 - 180, h - 50 - 60, 180, 60)
    nvgFillColor(ctx, nvgRGBA(255, 100, 180, 128))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    
    if fontId ~= -1 then
        nvgText(ctx, w - 50 - 90, h - 50 - 30, "NVG 180x60（设计空间）", nil)
    end
    
    nvgRestore(ctx)
end

function DrawGrid(ctx, width, height, step, color)
    nvgBeginPath(ctx)
    nvgStrokeColor(ctx, color)
    nvgStrokeWidth(ctx, 1)

    for x = 0, width, step do
        nvgMoveTo(ctx, x, 0)
        nvgLineTo(ctx, x, height)
    end

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
        nvgFontSize(ctx, 14)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))

        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        for x = 100, width, 100 do
            nvgText(ctx, x, rulerSize - tickLarge - 1, tostring(x), nil)
        end

        -- 左侧数字（旋转90度，刻度值直接对应 y 坐标）
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        for y = 100, height, 100 do
            if y >= rulerSize then
                nvgSave(ctx)
                nvgTranslate(ctx, rulerSize / 2, y)
                nvgRotate(ctx, -math.pi / 2)
                nvgText(ctx, 0, 0, tostring(y), nil)
                nvgRestore(ctx)
            end
        end

        nvgFontSize(ctx, 16)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 100, 255))
        nvgText(ctx, rulerSize / 2, rulerSize / 2, "px", nil)
    end
end

function DrawMeasureShapes(ctx, width, height)
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

    -- 150x150 黄框
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
        nvgFontSize(ctx, 15)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))

        nvgText(ctx, nvgBox1X + 150, nvgBoxY + 150, "NVG 300x300（屏幕空间）", nil)
        nvgText(ctx, nvgBox2X + 75, nvgBoxY + 75, "NVG 150x150（屏幕空间）", nil)
    end

    -- 圆形测试
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

    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, 5)
    nvgFillColor(ctx, nvgRGBA(255, 255, 0, 255))
    nvgFill(ctx)

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

    local cx = width / 2
    local cy = height / 2
    
    nvgFontFaceId(ctx, fontId)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    
    -- 设计区域尺寸（绿色，准星上方第一行）
    nvgFontSize(ctx, 28)
    nvgFillColor(ctx, nvgRGBA(100, 255, 100, 255))
    nvgText(ctx, cx, cy - 110, string.format("设计区域 %d×%d", resInfo.designWidth, resInfo.designHeight), nil)
    
    -- 提示文字（黄色，准星上方第二行）
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(255, 255, 150, 220))
    nvgText(ctx, cx, cy - 75, "右上NVG vs 右下UI - 尺寸应相同 | 绿框=设计安全区", nil)
end

function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end
