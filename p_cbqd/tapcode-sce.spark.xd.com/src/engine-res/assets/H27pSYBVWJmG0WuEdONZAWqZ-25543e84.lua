-- ============================================================================
-- Font Comparison Example
-- Compare NanoVG UI library (pt unit) vs Urho3D Text
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")
local Theme = require("urhox-libs/UI/core/Theme")

local gridNvgContext = nil

function Start()
    SampleStart()

    -- Initialize UI library with font
    UI.Init({
        theme = "dark",
        fonts = {
            { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
        },
        fontSizeMethod = "char",
    })

    -- Create NanoVG context for grid lines
    gridNvgContext = nvgCreate(1)

    -- Create UI comparison panel
    CreateUIComparison()

    -- Create Urho3D Text comparison
    CreateUrhoTextComparison()

    SampleInitMouseMode(MM_FREE)

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(gridNvgContext, "NanoVGRender", "HandleRender")

    print("===========================================")
    print("  Font Comparison: NanoVG UI vs Urho3D Text")
    print("  Top: NanoVG UI (pt -> px conversion)")
    print("  Bottom: Urho3D Text (pt)")
    print("===========================================")
end

function Stop()
    if gridNvgContext then
        nvgDelete(gridNvgContext)
        gridNvgContext = nil
    end
    UI.Shutdown()
end

-- Shared constants for alignment
local START_X = 0
local START_Y = 50
local PADDING = 10
local LINE_HEIGHT = 28

function CreateUIComparison()
    -- Create root panel for UI library test (transparent background to show grid lines)
    local root = UI.Panel {
        id = "fontTestRoot",
        width = 400,
        height = 10 * LINE_HEIGHT,
        x = START_X,
        y = START_Y,
        padding = 0,
        flexDirection = "column",
        backgroundColor = { 0, 0, 0, 0 },  -- Transparent
    }

    -- Title using Label
    root:AddChild(UI.Label {
        text = "NanoVG UI (pt unit)",
        fontSize = 12,
        fontColor = { 255, 255, 255, 255 },
        height = LINE_HEIGHT,
        verticalAlign = "top",
    })

    -- Test different font sizes (in pt) using Label
    local testSizes = {8, 9, 10, 11, 12, 14, 15, 18, 24}
    for _, pt in ipairs(testSizes) do
        root:AddChild(UI.Label {
            text = "Outlined tl (" .. pt .. "pt)",
            fontSize = pt,
            fontColor = { 255, 255, 255, 255 },
            height = LINE_HEIGHT,
            verticalAlign = "top",
        })
    end

    UI.SetRoot(root)
end

-- Store Urho start Y for grid drawing
local urhoStartY = 0

function CreateUrhoTextComparison()
    local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")

    -- Urho3D content starts below NanoVG panel
    -- NanoVG panel: 10 rows (title + 9 sizes) * LINE_HEIGHT
    urhoStartY = START_Y + 10 * LINE_HEIGHT + 20

    -- Title
    local title = Text:new()
    title.text = "Urho3D Text (pt unit)"
    title:SetFont(font, 12)
    title.color = Color(1.0, 1.0, 1.0)
    title:SetPosition(START_X, urhoStartY)
    ui.root:AddChild(title)

    -- Test same font sizes (in pt)
    local testSizes = {8, 9, 10, 11, 12, 14, 15, 18, 24}
    local y = urhoStartY + LINE_HEIGHT
    for _, pt in ipairs(testSizes) do
        local text = Text:new()
        text.text = "Outlined tl (" .. pt .. "pt)"
        text:SetFont(font, pt)
        text.color = Color(1.0, 1.0, 1.0)
        text:SetPosition(START_X, y)
        ui.root:AddChild(text)

        y = y + LINE_HEIGHT
    end
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    UI.Update(dt)
end

-- Direct NanoVG font ID (loaded separately from UI library)
local directFontId = -1

function DrawGridLines(ctx)
    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    nvgBeginFrame(ctx, width, height, 1.0)

    -- Load font if not loaded
    if directFontId == -1 then
        directFontId = nvgCreateFont(ctx, "direct-sans", "Fonts/MiSans-Regular.ttf")
        print("Direct font loaded: " .. directFontId)
    end

    -- Draw vertical lines every 10 pixels for alignment comparison
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 0, 150))  -- Yellow
    nvgStrokeWidth(ctx, 1)

    -- Draw lines every 10 pixels (full height)
    for x = 0, 400, 10 do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, 0)
        nvgLineTo(ctx, x, height)
        nvgStroke(ctx)
    end

    -- Draw a red line at x=0 for reference (left edge)
    nvgStrokeColor(ctx, nvgRGBA(255, 0, 0, 200))
    nvgStrokeWidth(ctx, 2)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, 0)
    nvgLineTo(ctx, 0, height)
    nvgStroke(ctx)

    -- Draw direct NanoVG text (bypassing UI library) for comparison
    -- This section uses NanoVG API directly with pt values
    if directFontId ~= -1 then
        local directY = urhoStartY + 10 * LINE_HEIGHT + 40

        nvgFontFaceId(ctx, directFontId)
        nvgFillColor(ctx, nvgRGBA(0, 255, 255, 255))  -- Cyan for direct NanoVG
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- Title
        nvgFontSize(ctx, 12)  -- 12pt directly
        nvgText(ctx, START_X, directY, "Direct NanoVG (pt unit)", nil)
        directY = directY + LINE_HEIGHT

        -- Test sizes
        local testSizes = {8, 9, 10, 11, 12, 14, 15, 18, 24}
        for _, pt in ipairs(testSizes) do
            nvgFontSize(ctx, pt)  -- pt value directly to NanoVG
            nvgText(ctx, START_X, directY, "Outlined tl (" .. pt .. "pt)", nil)
            directY = directY + LINE_HEIGHT
        end
    end

    nvgEndFrame(ctx)
end

function HandleRender(eventType, eventData)
    -- Draw grid lines first (behind text)
    if gridNvgContext then
        DrawGridLines(gridNvgContext)
    end

    -- Render UI on top
    UI.Render()
end
