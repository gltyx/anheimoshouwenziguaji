-- NanoVG Basic Example
-- This sample demonstrates:
--     - Creating a NanoVG context with automatic BGFX ViewId management
--     - Drawing basic shapes (rectangles, circles, rounded rectangles)
--     - Using gradients and colors
--     - Rendering text with custom fonts
--     - Using the native NanoVG C API from Lua

require "LuaScripts/Utilities/Sample"

---@type NVGContextWrapper|nil
local nvgContext = nil
---@type BorderImage
local canvasPanel = nil
---@type Texture2D
local nvgRenderTarget = nil
local fontId = -1

function Start()
    -- Execute the common startup for samples
    SampleStart()

    local graphics = GetGraphics()
    local rtWidth = graphics:GetWidth() * 0.5
    local rtHeight = graphics:GetHeight() * 0.5

    nvgRenderTarget = Texture2D:new()
    nvgRenderTarget:SetNumLevels(1)
    nvgRenderTarget:SetSize(rtWidth, rtHeight, Graphics:GetRGBAFormat(), TEXTURE_RENDERTARGET)
    nvgRenderTarget:SetFilterMode(FILTER_BILINEAR)

    -- Create the NanoVG context
    -- Parameter: edgeAntiAlias (1=on, 0=off)
    nvgContext = nvgCreate(1)

    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- Set render target for nvgContext
    nvgSetRenderTarget(nvgContext, nvgRenderTarget)

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

    -- Create Canvas Panel
    CreateCanvasPanel()

    -- Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_FREE)

    -- Subscribe to render event
    SubscribeToEvent("EndAllViewsRender", "HandleRender")
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

function CreateCanvasPanel()
    -- Create border image
    canvasPanel = BorderImage:new()
    -- Set render target as a texture for canvasPanel
    canvasPanel:SetTexture(nvgRenderTarget)
    canvasPanel:SetSize(nvgRenderTarget:GetWidth(), nvgRenderTarget:GetHeight())

    ui.root:AddChild(canvasPanel)
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then
        print("ERROR: nvgContext is nil")
        return
    end

    local width = canvasPanel:GetWidth()
    local height = canvasPanel:GetHeight()

    -- If you want to keep the canvas RT the same size as the UI components
    if nvgRenderTarget:GetWidth() ~= width or nvgRenderTarget:GetHeight() ~= height then
        nvgRenderTarget:SetSize(width, height, Graphics:GetRGBAFormat(), TEXTURE_RENDERTARGET)
    end

    -- Begin NanoVG frame (ViewId is automatically managed)
    nvgBeginFrame(nvgContext, width, height, 1.0)

    -- Draw demo
    DrawDemo(nvgContext, width, height)

    -- End NanoVG frame
    nvgEndFrame(nvgContext)
end

function DrawDemo(ctx, width, height)
    local time = GetTime():GetElapsedTime()

    -- Draw background with radial gradient
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    local bg = nvgRadialGradient(ctx, width * 0.5, height * 0.5, width * 0.1, width * 0.8,
        nvgRGBA(60, 40, 80, 255),
        nvgRGBA(20, 10, 30, 255))
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    -- Draw animated rotating rectangles
    nvgSave(ctx)
    nvgTranslate(ctx, width * 0.25, height * 0.35)
    nvgRotate(ctx, time * 0.5)
    nvgBeginPath(ctx)
    nvgRect(ctx, -40, -40, 80, 80)
    nvgFillColor(ctx, nvgRGBA(255, 180, 50, 200))
    nvgFill(ctx)
    nvgRestore(ctx)

    -- Draw pulsing circle
    nvgBeginPath(ctx)
    local cx = width * 0.75
    local cy = height * 0.35
    local radius = 50 + math.sin(time * 3) * 15
    nvgCircle(ctx, cx, cy, radius)
    local alpha = math.floor(150 + 105 * math.sin(time * 3))
    nvgFillColor(ctx, nvgRGBA(50, 200, 255, alpha))
    nvgFill(ctx)

    -- Draw rounded rectangles with stroke
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, width * 0.5 - 60, height * 0.6, 120, 60, 8)
    nvgFillColor(ctx, nvgRGBA(100, 255, 150, 180))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- Render text if font is loaded
    if fontId ~= -1 then
        -- Title text
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 36)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, width * 0.5, 40, "NanoVG UI 组件", nil)

        -- Subtitle with shadow effect
        nvgFontSize(ctx, 20)
        -- Shadow
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, 128))
        nvgText(ctx, width * 0.5 + 2, 72, "渲染到纹理", nil)
        -- Text
        nvgFillColor(ctx, nvgRGBA(200, 220, 255, 255))
        nvgText(ctx, width * 0.5, 70, "渲染到纹理", nil)

        -- Animated color text
        nvgFontSize(ctx, 28)
        local r = math.floor(128 + 127 * math.sin(time * 2))
        local g = math.floor(128 + 127 * math.sin(time * 2 + 2))
        local b = math.floor(128 + 127 * math.sin(time * 2 + 4))
        nvgFillColor(ctx, nvgRGBA(r, g, b, 255))
        nvgText(ctx, width * 0.5, height * 0.75, "动态颜色", nil)

        -- Info text
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 100, 255))
        nvgText(ctx, 10, height - 70, "左上：旋转矩形", nil)
        nvgText(ctx, 10, height - 50, "右上：脉动圆形", nil)
        nvgText(ctx, 10, height - 30, "中下：圆角矩形", nil)
        nvgText(ctx, 10, height - 10, "字体：MiSans", nil)
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
