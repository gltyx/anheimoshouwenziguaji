--[[
================================================================================
  99_UIScalerFullDemo.lua - UIScaler 组件完整测绘示例
================================================================================

【用途】
  本 Demo 展示如何使用 UIScaler 组件进行基于设计分辨率的 UI 适配。
  UIScaler 封装了设计分辨率适配的核心逻辑，提供开箱即用的 SHOW_ALL 策略。

【UIScaler 组件用法】
  require "LuaScripts/Utilities/UIScaler"
  
  local uiScaler = CreateUIScaler(nil, 1920, 1080)  -- 设计分辨率 1920×1080
  
  -- 访问属性
  uiScaler.scaleFactor      -- 缩放因子
  uiScaler.scaledWidth      -- 虚拟宽度（UI 坐标系）
  uiScaler.scaledHeight     -- 虚拟高度
  uiScaler.designOriginX    -- 设计区域原点 X（用于 NVG 偏移）
  uiScaler.designOriginY    -- 设计区域原点 Y
  uiScaler.designContainer  -- 设计区域 UI 容器
  
  -- NVG 绘制
  nvgBeginFrame(ctx, uiScaler.scaledWidth, uiScaler.scaledHeight, uiScaler.scaleFactor)
  nvgTranslate(ctx, uiScaler.designOriginX, uiScaler.designOriginY)
  -- 现在 (0,0) 就是设计区域左上角

【测试内容】
  1. 左上角信息面板：显示 UIScaler 各属性值
  2. 左下角设计分辨率切换器：循环切换不同预设
  3. 右上角 NanoVG 绘制：蓝色 300×300、黄色 150×150 方块
  4. 右下角 UI 组件：红色 300×300、绿色 150×150 方块
  5. 设计区域边界：绿色边框标出设计安全区
  6. 设计空间 UI/NVG 对比：验证坐标系对齐

【与 99_DesignResolutionTest.lua 对比】
  本示例使用 UIScaler 组件，代码更简洁：
  - 无需手动计算 scale/virtualWidth/offset
  - 无需手动调用 ui:SetScale()
  - 无需手动管理 designContainer 的位置和大小
  - ScreenMode 事件自动处理

================================================================================
--]]

require "LuaScripts/Utilities/Sample"
require "LuaScripts/Utilities/UIScaler"

---@type NVGContextWrapper|nil
local nvgContext = nil
local fontId = -1

---@type UIScaler
local uiScaler = nil

-- UI 元素
local infoText = nil
local measureBox = nil
local uiBoxContainer = nil
local interactPanel = nil
local infoPanel = nil
local designDisplayText = nil
local designModeText = nil
local scaleModeButton = nil
local scaleModeText = nil
local clipButton = nil
local clipText = nil

-- NVG 滑块状态（物理像素坐标）
local nvgSlider = {
    draggingHeight = false,
    draggingWidth = false,
    trackLength = 300,       -- 滑块轨道长度
    trackThickness = 36,     -- 轨道粗细
    hitAreaThickness = 80,   -- 触摸检测区域
    knobLength = 50,         -- 滑块长度
    offsetFromCenter = 200,  -- 距离屏幕中心的偏移
}

-- 设计分辨率预设
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
local customDesignMode = false

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
        print("WARNING: Failed to load font")
    end

    -- ========== 使用 UIScaler 组件 ==========
    local preset = designPresets[currentPresetIndex]
    uiScaler = CreateUIScaler(nil, preset.w, preset.h, false)

    -- 创建 UI 元素
    CreateUI()

    SampleInitMouseMode(MM_FREE)

    -- 订阅事件
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    UpdateInfoText()
    UpdateDesignDisplay()
    
    -- NVG 滑块输入处理
    HandleSliderInput()
end

function HandleSliderInput()
    local input = GetInput()
    local s = nvgSlider
    
    local pointerX = input:GetMousePosition().x
    local pointerY = input:GetMousePosition().y
    local pointerDown = input:GetMouseButtonDown(MOUSEB_LEFT)
    
    if input:GetNumTouches() > 0 then
        local touch = input:GetTouch(0)
        pointerX = touch.position.x
        pointerY = touch.position.y
        pointerDown = true
    end
    
    local deviceW = uiScaler.deviceWidth
    local deviceH = uiScaler.deviceHeight
    local centerX = deviceW / 2
    local centerY = deviceH / 2
    local hitThick = s.hitAreaThickness
    
    local hTrackX = centerX - s.offsetFromCenter - hitThick / 2
    local hTrackY = centerY - s.trackLength / 2
    local hTrackW = hitThick
    local hTrackH = s.trackLength
    
    local wTrackX = centerX - s.trackLength / 2
    local wTrackY = centerY + s.offsetFromCenter - hitThick / 2
    local wTrackW = s.trackLength
    local wTrackH = hitThick
    
    if pointerDown then
        if not s.draggingHeight and not s.draggingWidth then
            if pointerX >= hTrackX and pointerX <= hTrackX + hTrackW and
               pointerY >= hTrackY and pointerY <= hTrackY + hTrackH then
                s.draggingHeight = true
            elseif pointerX >= wTrackX and pointerX <= wTrackX + wTrackW and
                   pointerY >= wTrackY and pointerY <= wTrackY + wTrackH then
                s.draggingWidth = true
            end
        end
        
        if s.draggingHeight then
            local ratio = math.max(0, math.min(1, (pointerY - hTrackY) / hTrackH))
            local val = math.floor((400 + ratio * 2800) / 10) * 10
            if val ~= uiScaler.designHeight then
                customDesignMode = true
                uiScaler:SetDesignSize(uiScaler.designWidth, val)
            end
        end
        
        if s.draggingWidth then
            local ratio = math.max(0, math.min(1, (pointerX - wTrackX) / wTrackW))
            local val = math.floor((400 + ratio * 2800) / 10) * 10
            if val ~= uiScaler.designWidth then
                customDesignMode = true
                uiScaler:SetDesignSize(val, uiScaler.designHeight)
            end
        end
    else
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

function CreateUI()
    local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")

    -- ========== 设计区域内的 UI（使用 uiScaler.designContainer）==========
    local container = uiScaler.designContainer

    -- 左上角测试方块
    local cornerBox = Window:new()
    cornerBox:SetStyleAuto()
    cornerBox:SetSize(180, 60)
    cornerBox:SetPosition(50, 50)
    cornerBox.color = Color(1, 0.5, 0, 0.5)
    container:AddChild(cornerBox)

    local cornerLabel = Text:new()
    cornerLabel:SetStyleAuto()
    cornerLabel.text = "UI 180x60（设计空间）"
    cornerLabel:SetFont(font, 13)
    cornerLabel.color = Color(1, 1, 1)
    cornerLabel:SetAlignment(HA_CENTER, VA_CENTER)
    cornerBox:AddChild(cornerLabel)

    -- 右下角测试方块
    local cornerBox2 = Window:new()
    cornerBox2:SetStyleAuto()
    cornerBox2:SetSize(180, 60)
    cornerBox2:SetAlignment(HA_RIGHT, VA_BOTTOM)
    cornerBox2:SetPosition(-50, -50)
    cornerBox2.color = Color(0, 0.8, 1, 0.5)
    container:AddChild(cornerBox2)

    local cornerLabel2 = Text:new()
    cornerLabel2:SetStyleAuto()
    cornerLabel2.text = "UI 180x60（设计空间）"
    cornerLabel2:SetFont(font, 13)
    cornerLabel2.color = Color(1, 1, 1)
    cornerLabel2:SetAlignment(HA_CENTER, VA_CENTER)
    cornerBox2:AddChild(cornerLabel2)

    -- 左边大方框（一半超出设计区域）
    local leftOverflowBox = Window:new()
    leftOverflowBox:SetStyleAuto()
    leftOverflowBox:SetSize(400, 300)
    leftOverflowBox:SetAlignment(HA_LEFT, VA_CENTER)
    leftOverflowBox:SetPosition(-200, 0)  -- 一半超出左边
    leftOverflowBox.color = Color(1, 0.3, 0.5, 0.6)
    container:AddChild(leftOverflowBox)

    local leftLabel = Text:new()
    leftLabel:SetStyleAuto()
    leftLabel.text = "左侧溢出\n400×300\n测试 clipChildren"
    leftLabel:SetFont(font, 14)
    leftLabel.color = Color(1, 1, 1)
    leftLabel:SetTextAlignment(HA_CENTER)
    leftLabel:SetAlignment(HA_CENTER, VA_CENTER)
    leftOverflowBox:AddChild(leftLabel)

    -- 右边大方框（一半超出设计区域）
    local rightOverflowBox = Window:new()
    rightOverflowBox:SetStyleAuto()
    rightOverflowBox:SetSize(400, 300)
    rightOverflowBox:SetAlignment(HA_RIGHT, VA_CENTER)
    rightOverflowBox:SetPosition(200, 0)  -- 一半超出右边
    rightOverflowBox.color = Color(0.3, 0.5, 1, 0.6)
    container:AddChild(rightOverflowBox)

    local rightLabel = Text:new()
    rightLabel:SetStyleAuto()
    rightLabel.text = "右侧溢出\n400×300\n测试 clipChildren"
    rightLabel:SetFont(font, 14)
    rightLabel.color = Color(1, 1, 1)
    rightLabel:SetTextAlignment(HA_CENTER)
    rightLabel:SetAlignment(HA_CENTER, VA_CENTER)
    rightOverflowBox:AddChild(rightLabel)

    -- ========== 屏幕空间 UI（直接加到 ui.root）==========
    
    -- 左上角：信息面板
    infoPanel = Window:new()
    infoPanel:SetStyleAuto()
    infoPanel:SetLayout(LM_VERTICAL, 6, IntRect(12, 12, 12, 12))
    infoPanel:SetAlignment(HA_LEFT, VA_TOP)
    infoPanel:SetPosition(45, 45)
    infoPanel.color = Color(0.1, 0.2, 0.4, 0.85)
    ui.root:AddChild(infoPanel)

    local title = Text:new()
    title:SetStyleAuto()
    title.text = "UIScaler 组件测试"
    title:SetFont(font, 16)
    title.color = Color(1, 1, 0.6)
    infoPanel:AddChild(title)

    infoText = Text:new()
    infoText:SetStyleAuto()
    infoText:SetFont(font, 13)
    infoText.color = Color(1, 1, 1)
    infoPanel:AddChild(infoText)

    UpdateInfoText()

    -- 右下角：UI 测量方块
    uiBoxContainer = UIElement:new()
    uiBoxContainer:SetLayout(LM_VERTICAL, 10)
    uiBoxContainer:SetAlignment(HA_RIGHT, VA_BOTTOM)
    uiBoxContainer:SetPosition(-20, -20)
    ui.root:AddChild(uiBoxContainer)

    local measureBox2 = Window:new()
    measureBox2:SetStyleAuto()
    measureBox2:SetSize(150, 150)
    measureBox2:SetMinSize(150, 150)
    measureBox2.color = Color(0.3, 1, 0.3, 0.7)
    uiBoxContainer:AddChild(measureBox2)

    local boxLabel2 = Text:new()
    boxLabel2:SetStyleAuto()
    boxLabel2.text = "UI 150x150（屏幕空间）"
    boxLabel2:SetFont(font, 13)
    boxLabel2.color = Color(1, 1, 1)
    boxLabel2:SetAlignment(HA_CENTER, VA_CENTER)
    measureBox2:AddChild(boxLabel2)

    measureBox = Window:new()
    measureBox:SetStyleAuto()
    measureBox:SetSize(300, 300)
    measureBox:SetMinSize(300, 300)
    measureBox.color = Color(1, 0.3, 0.3, 0.7)
    uiBoxContainer:AddChild(measureBox)

    local boxLabel = Text:new()
    boxLabel:SetStyleAuto()
    boxLabel.text = "UI 300x300（屏幕空间）"
    boxLabel:SetFont(font, 15)
    boxLabel.color = Color(1, 1, 1)
    boxLabel:SetAlignment(HA_CENTER, VA_CENTER)
    measureBox:AddChild(boxLabel)

    -- 左下角：设计分辨率切换按钮
    interactPanel = Button:new()
    interactPanel:SetStyleAuto()
    interactPanel:SetLayout(LM_VERTICAL, 8, IntRect(20, 20, 20, 20))
    interactPanel:SetAlignment(HA_LEFT, VA_BOTTOM)
    interactPanel:SetPosition(45, -20)
    interactPanel:SetMinSize(180, 100)
    interactPanel.color = Color(0.2, 0.2, 0.35, 0.9)
    ui.root:AddChild(interactPanel)

    local switchTitle = Text:new()
    switchTitle:SetStyleAuto()
    switchTitle.text = "点击切换设计分辨率"
    switchTitle:SetFont(font, 13)
    switchTitle.color = Color(0.8, 0.9, 1.0)
    switchTitle:SetAlignment(HA_CENTER, VA_TOP)
    switchTitle:SetEnabled(false)
    interactPanel:AddChild(switchTitle)

    designDisplayText = Text:new()
    designDisplayText:SetStyleAuto()
    designDisplayText:SetFont(font, 22)
    designDisplayText.color = Color(1, 1, 0.6)
    designDisplayText:SetAlignment(HA_CENTER, VA_CENTER)
    designDisplayText:SetEnabled(false)
    interactPanel:AddChild(designDisplayText)

    designModeText = Text:new()
    designModeText:SetStyleAuto()
    designModeText:SetFont(font, 12)
    designModeText.color = Color(0.7, 0.8, 0.9)
    designModeText:SetAlignment(HA_CENTER, VA_BOTTOM)
    designModeText:SetEnabled(false)
    interactPanel:AddChild(designModeText)

    UpdateDesignDisplay()

    local lastClickTime = 0
    SubscribeToEvent(interactPanel, "Pressed", function()
        local currentTime = time:GetElapsedTime()
        if currentTime - lastClickTime < 0.3 then return end
        lastClickTime = currentTime
        
        currentPresetIndex = (currentPresetIndex % #designPresets) + 1
        customDesignMode = false
        
        local preset = designPresets[currentPresetIndex]
        uiScaler:SetDesignSize(preset.w, preset.h)
        
        UpdateDesignDisplay()
        UpdateInfoText()
    end)

    -- 右上角：缩放模式切换按钮
    -- UIRoot 顶部：缩放模式切换按钮
    scaleModeButton = Button:new()
    scaleModeButton:SetStyleAuto()
    scaleModeButton:SetLayout(LM_VERTICAL, 8, IntRect(20, 14, 20, 14))
    scaleModeButton:SetAlignment(HA_CENTER, VA_TOP)
    scaleModeButton:SetPosition(-95, 45)  -- 顶部居中偏左，避开标尺(35px)
    scaleModeButton:SetMinSize(170, 75)
    scaleModeButton.color = Color(0.35, 0.2, 0.4, 0.9)
    ui.root:AddChild(scaleModeButton)

    local scaleModeTitle = Text:new()
    scaleModeTitle:SetStyleAuto()
    scaleModeTitle.text = "缩放模式"
    scaleModeTitle:SetFont(font, 14)
    scaleModeTitle.color = Color(0.9, 0.8, 1.0)
    scaleModeTitle:SetAlignment(HA_CENTER, VA_TOP)
    scaleModeTitle:SetEnabled(false)
    scaleModeButton:AddChild(scaleModeTitle)

    scaleModeText = Text:new()
    scaleModeText:SetStyleAuto()
    scaleModeText:SetFont(font, 22)
    scaleModeText.color = Color(1, 0.8, 0.4)
    scaleModeText:SetAlignment(HA_CENTER, VA_CENTER)
    scaleModeText:SetEnabled(false)
    scaleModeButton:AddChild(scaleModeText)

    UpdateScaleModeDisplay()

    local lastScaleModeClickTime = 0
    SubscribeToEvent(scaleModeButton, "Pressed", function()
        local currentTime = time:GetElapsedTime()
        if currentTime - lastScaleModeClickTime < 0.3 then return end
        lastScaleModeClickTime = currentTime
        
        -- 切换缩放模式
        if uiScaler.scaleMode == CONTAIN_MODE then
            uiScaler:SetScaleMode(COVER_MODE)
        else
            uiScaler:SetScaleMode(CONTAIN_MODE)
        end
        
        UpdateScaleModeDisplay()
        UpdateInfoText()
    end)

    -- UIRoot 顶部：clipChildren 切换按钮
    clipButton = Button:new()
    clipButton:SetStyleAuto()
    clipButton:SetLayout(LM_VERTICAL, 8, IntRect(20, 14, 20, 14))
    clipButton:SetAlignment(HA_CENTER, VA_TOP)
    clipButton:SetPosition(95, 45)  -- 顶部居中偏右，与缩放模式按钮并排，避开标尺
    clipButton:SetMinSize(170, 75)
    clipButton.color = Color(0.2, 0.3, 0.35, 0.9)
    ui.root:AddChild(clipButton)

    local clipTitle = Text:new()
    clipTitle:SetStyleAuto()
    clipTitle.text = "裁剪溢出"
    clipTitle:SetFont(font, 14)
    clipTitle.color = Color(0.8, 0.9, 1.0)
    clipTitle:SetAlignment(HA_CENTER, VA_TOP)
    clipTitle:SetEnabled(false)
    clipButton:AddChild(clipTitle)

    clipText = Text:new()
    clipText:SetStyleAuto()
    clipText:SetFont(font, 22)
    clipText:SetAlignment(HA_CENTER, VA_CENTER)
    clipText:SetEnabled(false)
    clipButton:AddChild(clipText)

    UpdateClipDisplay()

    local lastClipClickTime = 0
    SubscribeToEvent(clipButton, "Pressed", function()
        local currentTime = time:GetElapsedTime()
        if currentTime - lastClipClickTime < 0.3 then return end
        lastClipClickTime = currentTime
        
        -- 切换 clipChildren
        uiScaler:SetClipChildren(not uiScaler.clipChildren)
        
        UpdateClipDisplay()
        UpdateInfoText()
    end)
end

function UpdateDesignDisplay()
    if designDisplayText == nil or uiScaler == nil then return end
    
    if customDesignMode then
        designDisplayText.text = string.format("%d×%d", uiScaler.designWidth, uiScaler.designHeight)
        designModeText.text = "自定义"
        designModeText.color = Color(1, 0.8, 0.4)
    else
        local preset = designPresets[currentPresetIndex]
        designDisplayText.text = preset.name
        designModeText.text = preset.ratio
        designModeText.color = Color(0.7, 0.8, 0.9)
    end
end

local function GetScaleModeName()
    if uiScaler.scaleMode == COVER_MODE then
        return "COVER"
    else
        return "CONTAIN"
    end
end

function UpdateScaleModeDisplay()
    if scaleModeText == nil or uiScaler == nil then return end
    
    scaleModeText.text = GetScaleModeName()
    if uiScaler.scaleMode == COVER_MODE then
        scaleModeText.color = Color(1, 0.5, 0.3)
        scaleModeButton.color = Color(0.4, 0.2, 0.2, 0.9)
    else
        scaleModeText.color = Color(0.4, 1, 0.6)
        scaleModeButton.color = Color(0.2, 0.35, 0.25, 0.9)
    end
end

function UpdateClipDisplay()
    if clipText == nil or uiScaler == nil then return end
    
    if uiScaler.clipChildren then
        clipText.text = "ON"
        clipText.color = Color(0.4, 1, 0.6)
        clipButton.color = Color(0.2, 0.35, 0.25, 0.9)
    else
        clipText.text = "OFF"
        clipText.color = Color(1, 0.5, 0.3)
        clipButton.color = Color(0.4, 0.25, 0.2, 0.9)
    end
end

function UpdateInfoText()
    if infoText == nil or uiScaler == nil then return end
    
    local ratioText = customDesignMode and "自定义" or designPresets[currentPresetIndex].ratio
    local dpr = graphics:GetDPR()
    
    local text = string.format(
        "deviceWidth/Height: %.0f × %.0f\n" ..
        "designWidth/Height: %.0f × %.0f (%s)\n" ..
        "scaledWidth/Height: %.0f × %.0f\n" ..
        "---\n" ..
        "scaleMode: %s\n" ..
        "scaleFactor: %.3f\n" ..
        "designOriginX/Y: (%.1f, %.1f)\n" ..
        "---\n" ..
        "DPR: %.2f (系统)\n" ..
        "clipChildren: %s",
        uiScaler.deviceWidth, uiScaler.deviceHeight,
        uiScaler.designWidth, uiScaler.designHeight, ratioText,
        uiScaler.scaledWidth, uiScaler.scaledHeight,
        GetScaleModeName(),
        uiScaler.scaleFactor,
        uiScaler.designOriginX, uiScaler.designOriginY,
        dpr,
        tostring(uiScaler.clipChildren)
    )
    infoText.text = text
end

function HandleRender(eventType, eventData)
    if nvgContext == nil or uiScaler == nil then return end

    -- 使用 UIScaler 属性进行 NVG 绘制
    nvgBeginFrame(nvgContext, uiScaler.scaledWidth, uiScaler.scaledHeight, uiScaler.scaleFactor)
    
    DrawResolutionTest(nvgContext, uiScaler.scaledWidth, uiScaler.scaledHeight)
    
    nvgEndFrame(nvgContext)
    
    -- 绘制 NVG 滑块（物理像素坐标）
    DrawNvgSliders(nvgContext)
end

function DrawNvgSliders(ctx)
    local deviceW = uiScaler.deviceWidth
    local deviceH = uiScaler.deviceHeight
    
    nvgBeginFrame(ctx, deviceW, deviceH, 1.0)
    
    local centerX = deviceW / 2
    local centerY = deviceH / 2
    local s = nvgSlider
    
    -- 高度滑块
    local hTrackX = centerX - s.offsetFromCenter - s.trackThickness / 2
    local hTrackY = centerY - s.trackLength / 2
    
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, hTrackX, hTrackY, s.trackThickness, s.trackLength, 4)
    nvgFillColor(ctx, nvgRGBA(60, 60, 80, 200))
    nvgFill(ctx)
    
    local hRatio = math.max(0, math.min(1, (uiScaler.designHeight - 400) / 2800))
    local hKnobY = hTrackY + hRatio * (s.trackLength - s.knobLength)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, hTrackX, hKnobY, s.trackThickness, s.knobLength, 4)
    nvgFillColor(ctx, s.draggingHeight and nvgRGBA(100, 200, 255, 255) or nvgRGBA(50, 150, 220, 255))
    nvgFill(ctx)
    
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 24)
        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 150, 255))
        nvgText(ctx, hTrackX - 15, centerY, tostring(uiScaler.designHeight), nil)
        nvgFontSize(ctx, 18)
        nvgFillColor(ctx, nvgRGBA(180, 200, 220, 255))
        nvgText(ctx, hTrackX - 15, centerY - 30, "高度", nil)
    end
    
    -- 宽度滑块
    local wTrackX = centerX - s.trackLength / 2
    local wTrackY = centerY + s.offsetFromCenter - s.trackThickness / 2
    
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, wTrackX, wTrackY, s.trackLength, s.trackThickness, 4)
    nvgFillColor(ctx, nvgRGBA(60, 60, 80, 200))
    nvgFill(ctx)
    
    local wRatio = math.max(0, math.min(1, (uiScaler.designWidth - 400) / 2800))
    local wKnobX = wTrackX + wRatio * (s.trackLength - s.knobLength)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, wKnobX, wTrackY, s.knobLength, s.trackThickness, 4)
    nvgFillColor(ctx, s.draggingWidth and nvgRGBA(100, 200, 255, 255) or nvgRGBA(50, 150, 220, 255))
    nvgFill(ctx)
    
    if fontId ~= -1 then
        nvgFontSize(ctx, 24)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 150, 255))
        nvgText(ctx, centerX, wTrackY + s.trackThickness + 12, tostring(uiScaler.designWidth), nil)
        nvgFontSize(ctx, 18)
        nvgFillColor(ctx, nvgRGBA(180, 200, 220, 255))
        nvgText(ctx, centerX + 60, wTrackY + s.trackThickness + 14, "宽度", nil)
    end
    
    nvgEndFrame(ctx)
end

function DrawResolutionTest(ctx, width, height)
    DrawGrid(ctx, width, height, 100, nvgRGBA(120, 120, 140, 255))
    DrawGrid(ctx, width, height, 50, nvgRGBA(80, 80, 100, 255))
    DrawRuler(ctx, width, height)
    DrawDesignBounds(ctx, width, height)
    DrawMeasureShapes(ctx, width, height)
    DrawCenterCross(ctx, width, height)
    DrawInfo(ctx, width, height)
end

function DrawDesignBounds(ctx, width, height)
    local x = uiScaler.designOriginX
    local y = uiScaler.designOriginY
    local w = uiScaler.designWidth
    local h = uiScaler.designHeight
    
    -- 设计区域外的遮罩
    nvgBeginPath(ctx)
    if y > 0 then nvgRect(ctx, 0, 0, width, y) end
    if y + h < height then nvgRect(ctx, 0, y + h, width, height - y - h) end
    if x > 0 then nvgRect(ctx, 0, y, x, h) end
    if x + w < width then nvgRect(ctx, x + w, y, width - x - w, h) end
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 60))
    nvgFill(ctx)
    
    -- 设计区域边界线
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgStrokeColor(ctx, nvgRGBA(100, 255, 100, 200))
    nvgStrokeWidth(ctx, 4)
    nvgStroke(ctx)
    
    -- 四角标记
    local cornerSize = 40
    nvgStrokeWidth(ctx, 5)
    nvgStrokeColor(ctx, nvgRGBA(100, 255, 100, 255))
    
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + cornerSize)
    nvgLineTo(ctx, x, y)
    nvgLineTo(ctx, x + cornerSize, y)
    nvgStroke(ctx)
    
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + w - cornerSize, y)
    nvgLineTo(ctx, x + w, y)
    nvgLineTo(ctx, x + w, y + cornerSize)
    nvgStroke(ctx)
    
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + h - cornerSize)
    nvgLineTo(ctx, x, y + h)
    nvgLineTo(ctx, x + cornerSize, y + h)
    nvgStroke(ctx)
    
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + w - cornerSize, y + h)
    nvgLineTo(ctx, x + w, y + h)
    nvgLineTo(ctx, x + w, y + h - cornerSize)
    nvgStroke(ctx)
    
    -- ========== NVG 设计空间绘制（使用 designOriginX/Y 偏移）==========
    nvgSave(ctx)
    nvgTranslate(ctx, x, y)  -- 偏移到设计区域原点
    
    -- 左上角紫色方块
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
    
    -- 右下角粉色方块
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

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, rulerSize)
    nvgFillColor(ctx, nvgRGBA(40, 40, 50, 230))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, rulerSize, rulerSize, height - rulerSize)
    nvgFillColor(ctx, nvgRGBA(40, 40, 50, 230))
    nvgFill(ctx)

    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 200))
    nvgStrokeWidth(ctx, 1)

    nvgBeginPath(ctx)
    for x = 0, width, 10 do
        local tick = x % 100 == 0 and 16 or (x % 50 == 0 and 10 or 5)
        nvgMoveTo(ctx, x, rulerSize)
        nvgLineTo(ctx, x, rulerSize - tick)
    end
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    for y = rulerSize, height, 10 do
        local tick = y % 100 == 0 and 16 or (y % 50 == 0 and 10 or 5)
        nvgMoveTo(ctx, rulerSize, y)
        nvgLineTo(ctx, rulerSize - tick, y)
    end
    nvgStroke(ctx)

    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 14)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))

        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        for x = 100, width, 100 do
            nvgText(ctx, x, rulerSize - 17, tostring(x), nil)
        end

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
        nvgFillColor(ctx, nvgRGBA(255, 255, 100, 255))
        nvgText(ctx, rulerSize / 2, rulerSize / 2, "px", nil)
    end
end

function DrawMeasureShapes(ctx, width, height)
    local rulerSize = 35
    local nvgBoxY = rulerSize + 10
    
    local nvgBox1X = width - 300 - 20
    nvgBeginPath(ctx)
    nvgRect(ctx, nvgBox1X, nvgBoxY, 300, 300)
    nvgFillColor(ctx, nvgRGBA(100, 150, 255, 150))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(100, 150, 255, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    local nvgBox2X = nvgBox1X - 150 - 20
    nvgBeginPath(ctx)
    nvgRect(ctx, nvgBox2X, nvgBoxY, 150, 150)
    nvgFillColor(ctx, nvgRGBA(255, 200, 100, 150))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 200, 100, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 15)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, nvgBox1X + 150, nvgBoxY + 150, "NVG 300x300（屏幕空间）", nil)
        nvgText(ctx, nvgBox2X + 75, nvgBoxY + 75, "NVG 150x150（屏幕空间）", nil)
    end

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
    
    nvgFontSize(ctx, 28)
    nvgFillColor(ctx, nvgRGBA(100, 255, 100, 255))
    nvgText(ctx, cx, cy - 110, string.format("设计区域 %d×%d", uiScaler.designWidth, uiScaler.designHeight), nil)
    
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(255, 255, 150, 220))
    nvgText(ctx, cx, cy - 75, "右上NVG vs 右下UI - 尺寸应相同 | 绿框=设计安全区", nil)
end

function GetScreenJoystickPatchString()
    return "<patch><add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\"><attribute name=\"Is Visible\" value=\"false\" /></add></patch>"
end

