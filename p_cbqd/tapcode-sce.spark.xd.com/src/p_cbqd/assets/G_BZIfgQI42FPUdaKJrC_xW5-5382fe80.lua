-- test_input.lua  原始输入测试（不使用UI库）
require "LuaScripts/Utilities/Sample"

local clickCount = 0
local lastEvent = "none"
local lastX = 0
local lastY = 0
local font = -1

function Start()
    log:Write(LOG_INFO, "[INPUT_TEST] Start() called")
    SampleStart()
    SampleInitMouseMode(MM_FREE)

    -- 订阅原始鼠标事件
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")

    -- 订阅触摸事件
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("TouchMove", "HandleTouchMove")

    -- 订阅UI点击事件
    SubscribeToEvent("UIMouseClick", "HandleUIMouseClick")
    SubscribeToEvent("UIMouseClickEnd", "HandleUIMouseClickEnd")
    SubscribeToEvent("Click", "HandleClick")

    -- 订阅 NanoVG 渲染
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")

    log:Write(LOG_INFO, "[INPUT_TEST] All events subscribed")
end

function HandleMouseDown(eventType, eventData)
    clickCount = clickCount + 1
    lastEvent = "MouseDown"
    lastX = eventData:GetInt("X") or 0
    lastY = eventData:GetInt("Y") or 0
    log:Write(LOG_INFO, "[INPUT_TEST] MouseDown x=" .. lastX .. " y=" .. lastY .. " count=" .. clickCount)
end

function HandleMouseUp(eventType, eventData)
    lastEvent = "MouseUp"
    log:Write(LOG_INFO, "[INPUT_TEST] MouseUp")
end

function HandleMouseMove(eventType, eventData)
    lastX = eventData:GetInt("X") or 0
    lastY = eventData:GetInt("Y") or 0
end

function HandleTouchBegin(eventType, eventData)
    clickCount = clickCount + 1
    lastEvent = "TouchBegin"
    lastX = eventData:GetInt("X") or 0
    lastY = eventData:GetInt("Y") or 0
    log:Write(LOG_INFO, "[INPUT_TEST] TouchBegin x=" .. lastX .. " y=" .. lastY .. " count=" .. clickCount)
end

function HandleTouchEnd(eventType, eventData)
    lastEvent = "TouchEnd"
    log:Write(LOG_INFO, "[INPUT_TEST] TouchEnd")
end

function HandleTouchMove(eventType, eventData)
    lastX = eventData:GetInt("X") or 0
    lastY = eventData:GetInt("Y") or 0
end

function HandleUIMouseClick(eventType, eventData)
    log:Write(LOG_INFO, "[INPUT_TEST] UIMouseClick")
    lastEvent = "UIMouseClick"
end

function HandleUIMouseClickEnd(eventType, eventData)
    log:Write(LOG_INFO, "[INPUT_TEST] UIMouseClickEnd")
    lastEvent = "UIMouseClickEnd"
end

function HandleClick(eventType, eventData)
    log:Write(LOG_INFO, "[INPUT_TEST] Click event")
    lastEvent = "Click"
end

function HandleNanoVGRender(eventType, eventData)
    local nvg = eventData:GetPtr("nanoVGContext", "NanoVG")
    if not nvg then return end

    if font < 0 then
        font = nvgCreateFont(nvg, "sans", "Fonts/MiSans-Regular.ttf")
    end
    if font < 0 then return end

    local w = graphics.width
    local h = graphics.height

    -- 背景
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, w, h)
    nvgFillColor(nvg, nvgRGBA(15, 15, 25, 255))
    nvgFill(nvg)

    -- 标题
    nvgFontSize(nvg, 28)
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
    nvgText(nvg, w/2, 60, "Raw Input Test")

    -- 屏幕尺寸
    nvgFontSize(nvg, 18)
    nvgFillColor(nvg, nvgRGBA(180, 180, 180, 255))
    nvgText(nvg, w/2, 100, "Screen: " .. w .. "x" .. h)

    -- 点击计数
    nvgFontSize(nvg, 36)
    nvgFillColor(nvg, nvgRGBA(100, 255, 100, 255))
    nvgText(nvg, w/2, h/2 - 40, "Clicks: " .. clickCount)

    -- 最后事件
    nvgFontSize(nvg, 22)
    nvgFillColor(nvg, nvgRGBA(200, 200, 255, 255))
    nvgText(nvg, w/2, h/2 + 10, "Last: " .. lastEvent)

    -- 坐标
    nvgFontSize(nvg, 20)
    nvgFillColor(nvg, nvgRGBA(255, 180, 100, 255))
    nvgText(nvg, w/2, h/2 + 50, "X=" .. lastX .. " Y=" .. lastY)

    -- 提示
    nvgFontSize(nvg, 16)
    nvgFillColor(nvg, nvgRGBA(150, 150, 150, 255))
    nvgText(nvg, w/2, h - 40, "Click/touch anywhere on screen")

    -- 画一个可视化的点击位置
    if clickCount > 0 then
        nvgBeginPath(nvg)
        nvgCircle(nvg, lastX, lastY, 20)
        nvgFillColor(nvg, nvgRGBA(255, 100, 100, 128))
        nvgFill(nvg)
    end
end

function HandleUpdate(eventType, eventData)
end
