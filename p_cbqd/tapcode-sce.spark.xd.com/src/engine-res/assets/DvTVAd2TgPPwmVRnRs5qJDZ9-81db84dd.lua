-- NanoVG Bloom/Glow Example
-- Demonstrates how to simulate bloom effect with NanoVG gradients

require "LuaScripts/Utilities/Sample"

local vg = nil
local fontId = -1

-- Bloom parameters (recommended values)
local BLOOM_INNER_ALPHA = 0.45   -- Center brightness
local BLOOM_MID_ALPHA = 0.6      -- Gradient start point
local BLOOM_OUTER_ALPHA = 0.1    -- Bloom range multiplier
local BLOOM_SIZE = 2.0           -- Base size multiplier

function Start()
    SampleStart()
    graphics.windowTitle = "NanoVG Bloom Example"

    vg = nvgCreate(1)
    fontId = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    SampleInitMouseMode(MM_FREE)
    SubscribeToEvent(vg, "NanoVGRender", "HandleRender")
end

function Stop()
    if vg then nvgDelete(vg) end
end

--- Draw bloom effect for a circle
-- @param x, y: center position
-- @param radius: core circle radius
-- @param r, g, b: HDR color (can be > 1.0)
function DrawCircleBloom(x, y, radius, r, g, b)
    local maxRadius = radius * BLOOM_SIZE * (1.0 + BLOOM_OUTER_ALPHA * 3.0)
    local innerR = radius * BLOOM_MID_ALPHA * 0.5
    local alpha = BLOOM_INNER_ALPHA

    nvgBeginPath(vg)
    nvgCircle(vg, x, y, maxRadius)
    local grad = nvgRadialGradient(vg, x, y, innerR, maxRadius,
        nvgRGBAf(r, g, b, alpha),
        nvgRGBAf(r, g, b, 0))
    nvgFillPaint(vg, grad)
    nvgFill(vg)
end

--- Draw bloom effect for a rounded rectangle
-- @param x, y: top-left position
-- @param w, h: size
-- @param cornerRadius: corner radius
-- @param feather: bloom spread distance
-- @param r, g, b: HDR color
function DrawRectBloom(x, y, w, h, cornerRadius, feather, r, g, b)
    local alpha = BLOOM_INNER_ALPHA

    nvgBeginPath(vg)
    nvgRect(vg, x - feather, y - feather, w + feather * 2, h + feather * 2)
    local grad = nvgBoxGradient(vg, x, y, w, h, cornerRadius, feather,
        nvgRGBAf(r, g, b, alpha),
        nvgRGBAf(r, g, b, 0))
    nvgFillPaint(vg, grad)
    nvgFill(vg)
end

--- Draw a glowing circle (bloom + core)
function DrawGlowingCircle(x, y, radius, r, g, b, brightness)
    local hdrR, hdrG, hdrB = r * brightness, g * brightness, b * brightness

    -- Only draw bloom when brightness > 1
    if brightness > 1.0 then
        DrawCircleBloom(x, y, radius, hdrR, hdrG, hdrB)
    end

    -- Draw core circle
    nvgBeginPath(vg)
    nvgCircle(vg, x, y, radius)
    nvgFillColor(vg, nvgRGBAf(math.min(1, hdrR), math.min(1, hdrG), math.min(1, hdrB), 1))
    nvgFill(vg)
end

--- Draw a glowing rounded rectangle (bloom + core)
function DrawGlowingRect(x, y, w, h, cornerRadius, r, g, b, brightness)
    local hdrR, hdrG, hdrB = r * brightness, g * brightness, b * brightness
    local feather = math.max(w, h) * 0.3 * BLOOM_SIZE

    -- Only draw bloom when brightness > 1
    if brightness > 1.0 then
        DrawRectBloom(x, y, w, h, cornerRadius, feather, hdrR, hdrG, hdrB)
    end

    -- Draw core rectangle
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, cornerRadius)
    nvgFillColor(vg, nvgRGBAf(math.min(1, hdrR), math.min(1, hdrG), math.min(1, hdrB), 1))
    nvgFill(vg)
end

function HandleRender(eventType, eventData)
    local width = graphics.width
    local height = graphics.height
    local time = GetTime():GetElapsedTime()

    nvgBeginFrame(vg, width, height, 1.0)

    -- Dark background
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, width, height)
    nvgFillColor(vg, nvgRGBA(15, 15, 25, 255))
    nvgFill(vg)

    -- Title
    if fontId ~= -1 then
        nvgFontFaceId(vg, fontId)
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, width / 2, 20, "NanoVG Bloom Example", nil)

        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(150, 150, 150, 255))
        nvgText(vg, width / 2, 50, "Circle: RadialGradient | Rectangle: BoxGradient", nil)
    end

    -- Animated brightness
    local brightness = 1.5 + math.sin(time) * 0.5  -- 1.0 ~ 2.0

    -- Glowing circles
    DrawGlowingCircle(width * 0.25, height * 0.4, 40, 1.0, 0.3, 0.3, brightness)  -- Red
    DrawGlowingCircle(width * 0.5, height * 0.4, 40, 0.3, 1.0, 0.3, brightness)   -- Green
    DrawGlowingCircle(width * 0.75, height * 0.4, 40, 0.3, 0.5, 1.0, brightness)  -- Blue

    -- Glowing rectangles
    DrawGlowingRect(width * 0.15, height * 0.65, 120, 60, 8, 1.0, 0.8, 0.2, brightness)  -- Yellow
    DrawGlowingRect(width * 0.45, height * 0.65, 120, 60, 8, 0.2, 1.0, 1.0, brightness)  -- Cyan
    DrawGlowingRect(width * 0.75, height * 0.65, 120, 60, 8, 1.0, 0.3, 0.8, brightness)  -- Magenta

    -- Brightness indicator
    if fontId ~= -1 then
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 255))
        nvgText(vg, width / 2, height - 40, string.format("Brightness: %.2f", brightness), nil)
    end

    nvgEndFrame(vg)
end

function GetScreenJoystickPatchString()
    return "<patch><add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\"><attribute name=\"Is Visible\" value=\"false\" /></add></patch>"
end
