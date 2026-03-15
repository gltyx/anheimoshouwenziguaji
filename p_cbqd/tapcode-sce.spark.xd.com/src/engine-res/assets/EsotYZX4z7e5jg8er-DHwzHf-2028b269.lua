--[[
================================================================================
  99_UIScalerDemo.lua - UIScaler 组件使用演示
================================================================================

【UIScaler 组件说明】
  用于 UI 设计分辨率适配，支持 UI 组件和 NanoVG 绘制。

【CreateUIScaler 参数】
  CreateUIScaler(node, designW, designH, scaleMode, clipChildren)
  - node: 挂载节点，推荐传入场景节点(scene)，nil 则内部自动创建 Node
  - designW/designH: 设计分辨率（如 1920x1080）
  - scaleMode: CONTAIN_MODE(默认,完整显示有黑边) 或 COVER_MODE(填满可能裁剪)
  - clipChildren: 是否裁剪超出设计区域的内容（默认 false）

【四种使用场景】（坐标单位均基于逻辑分辨率）
  1. 屏幕空间 UI 组件 - 添加到 ui.root，始终贴合屏幕边缘
  2. 设计空间 UI 组件 - 添加到 designContainer，使用设计坐标
  3. 屏幕空间 NVG    - 直接绘制，始终贴合屏幕边缘
  4. 设计空间 NVG    - 先 nvgTranslate(designOriginX/Y) 偏移，再用设计坐标绘制

================================================================================
--]]

require "LuaScripts/Utilities/Sample"
require "LuaScripts/Utilities/UIScaler"

---@type UIScaler
local uiScaler = nil
local nvgCtx = nil
local fontId = -1

function Start()
    SampleStart()
    
    -- 创建 NanoVG 上下文
    nvgCtx = nvgCreate(1)
    if nvgCtx then
        fontId = nvgCreateFont(nvgCtx, "sans", "Fonts/MiSans-Regular.ttf")
    end
    
    -- 创建 UIScaler
    -- 参数1: 挂载节点，推荐传入 scene（场景节点），nil 则内部自动创建轻量 Node
    -- 参数4: CONTAIN_MODE=完整显示设计区域(可能有黑边)，COVER_MODE=填满屏幕(可能裁剪)
    -- 参数5: clipChildren=true 时裁剪超出 designContainer 的内容
    uiScaler = CreateUIScaler(nil, 1920, 1080, CONTAIN_MODE, false)
    
    CreateUI()
    SampleInitMouseMode(MM_FREE)
    SubscribeToEvent(nvgCtx, "NanoVGRender", "HandleRender")
end

function Stop()
    if nvgCtx then nvgDelete(nvgCtx) end
end

function CreateUI()
    local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")
    
    -- ==========================================
    -- Case 1: 屏幕空间 UI 组件（添加到 ui.root）
    -- 始终贴合屏幕边缘，不受设计区域影响
    -- ==========================================
    local screenBox = Window:new()
    screenBox:SetStyleAuto()
    screenBox:SetSize(220, 70)
    screenBox:SetAlignment(HA_RIGHT, VA_TOP)
    screenBox:SetPosition(-20, 20)
    screenBox.color = Color(0.8, 0.2, 0.2, 0.8)
    ui.root:AddChild(screenBox)
    
    local label1 = Text:new()
    label1:SetStyleAuto()
    label1.text = "屏幕空间 UI\n(ui.root)"
    label1:SetFont(font, 14)
    label1:SetAlignment(HA_CENTER, VA_CENTER)
    screenBox:AddChild(label1)
    
    -- ==========================================
    -- Case 2: 设计空间 UI 组件（添加到 designContainer）
    -- 使用设计坐标（1920x1080）布局
    -- ==========================================
    local designBox = Window:new()
    designBox:SetStyleAuto()
    designBox:SetSize(220, 70)
    designBox:SetPosition(50, 50)
    designBox.color = Color(0.2, 0.6, 0.2, 0.8)
    uiScaler.designContainer:AddChild(designBox)
    
    local label2 = Text:new()
    label2:SetStyleAuto()
    label2.text = "设计空间 UI\n(designContainer)"
    label2:SetFont(font, 14)
    label2:SetAlignment(HA_CENTER, VA_CENTER)
    designBox:AddChild(label2)
    
    -- 设计空间右下角
    local designBox2 = Window:new()
    designBox2:SetStyleAuto()
    designBox2:SetSize(220, 70)
    designBox2:SetAlignment(HA_RIGHT, VA_BOTTOM)
    designBox2:SetPosition(-50, -50)
    designBox2.color = Color(0.2, 0.5, 0.7, 0.8)
    uiScaler.designContainer:AddChild(designBox2)
    
    local label3 = Text:new()
    label3:SetStyleAuto()
    label3.text = "设计空间 UI\n右下角 (-50,-50)"
    label3:SetFont(font, 14)
    label3:SetAlignment(HA_CENTER, VA_CENTER)
    designBox2:AddChild(label3)
end

function HandleRender(eventType, eventData)
    if not nvgCtx or not uiScaler then return end
    
    -- NVG 帧参数：逻辑分辨率 = 物理分辨率 / scaleFactor
    nvgBeginFrame(nvgCtx, uiScaler.scaledWidth, uiScaler.scaledHeight, uiScaler.scaleFactor)
    
    -- ==========================================
    -- Case 3: 屏幕空间 NVG（直接绘制）
    -- ==========================================
    nvgBeginPath(nvgCtx)
    nvgRect(nvgCtx, uiScaler.scaledWidth - 240, uiScaler.scaledHeight - 90, 220, 70)
    nvgFillColor(nvgCtx, nvgRGBA(200, 100, 50, 200))
    nvgFill(nvgCtx)
    
    if fontId ~= -1 then
        nvgFontFaceId(nvgCtx, fontId)
        nvgFontSize(nvgCtx, 14)
        nvgTextAlign(nvgCtx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgCtx, nvgRGBA(255, 255, 255, 255))
        nvgText(nvgCtx, uiScaler.scaledWidth - 130, uiScaler.scaledHeight - 55, "屏幕空间 NVG")
    end
    
    -- ==========================================
    -- Case 4: 设计空间 NVG（偏移后绘制）
    -- 先 nvgTranslate 到设计原点，然后使用设计坐标绘制
    -- ==========================================
    nvgSave(nvgCtx)
    nvgTranslate(nvgCtx, uiScaler.designOriginX, uiScaler.designOriginY)
    
    -- 设计空间左下角
    nvgBeginPath(nvgCtx)
    nvgRect(nvgCtx, 50, uiScaler.designHeight - 120, 220, 70)
    nvgFillColor(nvgCtx, nvgRGBA(150, 50, 200, 200))
    nvgFill(nvgCtx)
    
    if fontId ~= -1 then
        nvgFillColor(nvgCtx, nvgRGBA(255, 255, 255, 255))
        nvgText(nvgCtx, 160, uiScaler.designHeight - 85, "设计空间 NVG")
    end
    
    -- 绘制设计区域边框（绿色虚线）
    nvgBeginPath(nvgCtx)
    nvgRect(nvgCtx, 0, 0, uiScaler.designWidth, uiScaler.designHeight)
    nvgStrokeColor(nvgCtx, nvgRGBA(100, 255, 100, 180))
    nvgStrokeWidth(nvgCtx, 2)
    nvgStroke(nvgCtx)
    
    nvgRestore(nvgCtx)
    
    nvgEndFrame(nvgCtx)
end
