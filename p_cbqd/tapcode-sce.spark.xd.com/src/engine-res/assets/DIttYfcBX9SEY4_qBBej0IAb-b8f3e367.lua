-- NanoVG Basic Example
-- This sample demonstrates:
--     - Creating a NanoVG context with automatic BGFX ViewId management
--     - Drawing basic shapes (rectangles, circles, rounded rectangles)
--     - Using gradients and colors
--     - Rendering text with custom fonts
--     - Using the native NanoVG C API from Lua

require "LuaScripts/Utilities/Sample"

local nvgContext = nil
local fontId = -1

function Start()
    -- Execute the common startup for samples
    SampleStart()

    -- Create the NanoVG context
    -- Parameter: edgeAntiAlias (1=on, 0=off)
    nvgContext = nvgCreate(1)

    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    print("NanoVG context created successfully")

    -- Create font from TTF file
    fontId = nvgCreateFont(nvgContext, "misans", "Fonts/MiSans-Regular.ttf")

    if fontId == -1 then
        print("ERROR: Failed to create font from Fonts/MiSans-Regular.ttf")
    else
        print("Font loaded successfully, fontId = " .. fontId)
    end

    -- Create instructions text
    CreateInstructions()

    -- Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_FREE)

    -- Subscribe to render event
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
end

function Stop()
    -- Clean up NanoVG context
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
        print("NanoVG context deleted")
    end
end

function CreateInstructions()
    -- Construct new Text object
    local instructionText = Text:new()

    instructionText.text =
        "NanoVG Basic Example\n" ..
        "Drawing vector graphics with native NanoVG API"

    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 15)
    instructionText.color = Color(1.0, 1.0, 1.0)
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_TOP
    instructionText:SetPosition(0, 10)

    ui.root:AddChild(instructionText)
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then
        print("ERROR: nvgContext is nil")
        return
    end

    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    -- Begin NanoVG frame (ViewId is automatically managed)
    nvgBeginFrame(nvgContext, width, height, 1.0)

    -- Draw demo graphics
    DrawDemo(nvgContext, width, height)

    -- End NanoVG frame
    nvgEndFrame(nvgContext)
end

function DrawDemo(ctx, width, height)
    local time = GetTime():GetElapsedTime()

    -- Draw background gradient
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    local bg = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(20, 30, 40, 255),
        nvgRGBA(10, 15, 20, 255))
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    -- Draw some shapes
    -- Circle
    nvgBeginPath(ctx)
    local cx = width * 0.25
    local cy = height * 0.3
    local radius = 80 + math.sin(time * 2) * 20
    nvgCircle(ctx, cx, cy, radius)
    nvgFillColor(ctx, nvgRGBA(255, 100, 50, 200))
    nvgFill(ctx)

    -- Rounded rectangle
    nvgBeginPath(ctx)
    local rx = width * 0.6
    local ry = height * 0.3
    local rw = 150
    local rh = 100
    nvgRoundedRect(ctx, rx, ry, rw, rh, 10)
    nvgFillColor(ctx, nvgRGBA(50, 150, 255, 200))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    -- Render text if font is loaded
    if fontId ~= -1 then
        -- Title text
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 48)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, width * 0.5, height * 0.15, "NanoVG 字体渲染测试😀", nil)

        -- Subtitle text
        nvgFontSize(ctx, 24)
        nvgFillColor(ctx, nvgRGBA(200, 200, 200, 255))
        nvgText(ctx, width * 0.5, height * 0.15 + 50, "使用 MiSans 字体🚀", nil)

        -- Animated text
        nvgFontSize(ctx, 32)
        local alpha = math.floor(128 + 127 * math.sin(time * 3))
        nvgFillColor(ctx, nvgRGBA(100, 255, 100, alpha))
        nvgText(ctx, width * 0.5, height * 0.65, "动态文字效果🎉", nil)

        -- Info text with different sizes
        nvgFontSize(ctx, 18)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 200, 100, 255))
        nvgText(ctx, 20, height - 100, "左侧圆形 - 动态半径", nil)
        nvgText(ctx, 20, height - 70, "右侧矩形 - 圆角边框", nil)
        nvgText(ctx, 20, height - 40, "中文字体渲染 - MiSans", nil)
    end
end

-- Create XML patch instructions for screen joystick layout specific to this sample app
function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end
