-- Yoga Layout + NanoVG Example
-- This sample demonstrates:
--     - Using Yoga flexbox layout to position UI elements
--     - Rendering laid-out elements with NanoVG
--     - All major layout modes: flexDirection, justifyContent, alignItems
--     - Flex grow/shrink, wrap, gap, absolute positioning
--     - Padding, margin, and min/max dimensions

require "LuaScripts/Utilities/Sample"

-- Global state
local nvgContext = nil
local fontId = -1
local rootNode = nil
local layoutNodes = {}
local currentDemo = 1
local demoCount = 16

-- Interaction state
local hoveredNode = nil
local pressedNode = nil
local clickCount = 0  -- For demo purposes

-- Navigation buttons (for touch/mobile)
local navButtons = {}
local NAV_BUTTON_SIZE = 60
local NAV_BUTTON_MARGIN = 20

-- Color palette
local COLORS = {
    { r = 0.96, g = 0.26, b = 0.21, a = 1.0 },  -- Red
    { r = 0.30, g = 0.69, b = 0.31, a = 1.0 },  -- Green
    { r = 0.13, g = 0.59, b = 0.95, a = 1.0 },  -- Blue
    { r = 1.00, g = 0.76, b = 0.03, a = 1.0 },  -- Amber
    { r = 0.61, g = 0.15, b = 0.69, a = 1.0 },  -- Purple
    { r = 0.00, g = 0.74, b = 0.83, a = 1.0 },  -- Cyan
}

function Start()
    SampleStart()

    -- Create NanoVG context
    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- Load font
    fontId = nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf")

    -- Initialize first demo
    SetupDemo(currentDemo)

    -- Create navigation buttons for touch/mobile
    CreateNavButtons()

    CreateInstructions()
    SampleInitMouseMode(MM_FREE)

    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("ScreenMode", "HandleScreenModeChanged")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    -- Touch events for mobile
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
end

function Stop()
    -- Debug: Log live node count before cleanup
    print("YGNode live count before cleanup: " .. YGNodeGetLiveCount())

    CleanupLayout()

    -- Debug: Log live node count after cleanup (should be 0 if all nodes are freed)
    print("YGNode live count after cleanup: " .. YGNodeGetLiveCount())

    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

function CleanupLayout()
    if rootNode ~= nil then
        YGNodeFreeRecursive(rootNode)
        rootNode = nil
    end
    layoutNodes = {}
    hoveredNode = nil
    pressedNode = nil
end

function CreateInstructions()
    local instructionText = Text:new()
    instructionText.text = "Arrow Left/Right or tap < > buttons to switch demos, 1-9/0/Q-Y for direct access"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 15)
    instructionText.color = Color(1.0, 1.0, 1.0)
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_TOP
    instructionText:SetPosition(0, 10)
    ui.root:AddChild(instructionText)
end

function CreateNavButtons()
    local graphics = GetGraphics()
    local screenWidth = graphics:GetWidth()
    local screenHeight = graphics:GetHeight()

    navButtons = {}

    -- Previous button (left side)
    local prevBtn = {
        x = NAV_BUTTON_MARGIN,
        y = screenHeight / 2 - NAV_BUTTON_SIZE / 2,
        w = NAV_BUTTON_SIZE,
        h = NAV_BUTTON_SIZE,
        label = "<",
        color = { r = 0.2, g = 0.6, b = 0.9, a = 0.8 },
        isPressed = false,
        isHovered = false,
        onClick = function()
            currentDemo = currentDemo - 1
            if currentDemo < 1 then currentDemo = demoCount end
            SetupDemo(currentDemo)
        end
    }
    table.insert(navButtons, prevBtn)

    -- Next button (right side)
    local nextBtn = {
        x = screenWidth - NAV_BUTTON_SIZE - NAV_BUTTON_MARGIN,
        y = screenHeight / 2 - NAV_BUTTON_SIZE / 2,
        w = NAV_BUTTON_SIZE,
        h = NAV_BUTTON_SIZE,
        label = ">",
        color = { r = 0.2, g = 0.6, b = 0.9, a = 0.8 },
        isPressed = false,
        isHovered = false,
        onClick = function()
            currentDemo = currentDemo + 1
            if currentDemo > demoCount then currentDemo = 1 end
            SetupDemo(currentDemo)
        end
    }
    table.insert(navButtons, nextBtn)
end

function UpdateNavButtonPositions()
    local graphics = GetGraphics()
    local screenWidth = graphics:GetWidth()
    local screenHeight = graphics:GetHeight()

    if #navButtons >= 2 then
        -- Update prev button position
        navButtons[1].x = NAV_BUTTON_MARGIN
        navButtons[1].y = screenHeight / 2 - NAV_BUTTON_SIZE / 2

        -- Update next button position
        navButtons[2].x = screenWidth - NAV_BUTTON_SIZE - NAV_BUTTON_MARGIN
        navButtons[2].y = screenHeight / 2 - NAV_BUTTON_SIZE / 2
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- Keys 1-9 for demos 1-9
    if key >= KEY_1 and key <= KEY_9 then
        currentDemo = key - KEY_1 + 1
        SetupDemo(currentDemo)
    -- Key 0 for demo 10
    elseif key == KEY_0 then
        currentDemo = 10
        SetupDemo(currentDemo)
    -- Keys Q-W for demos 11-16
    elseif key == KEY_Q then
        currentDemo = 11
        SetupDemo(currentDemo)
    elseif key == KEY_W then
        currentDemo = 12
        SetupDemo(currentDemo)
    elseif key == KEY_E then
        currentDemo = 13
        SetupDemo(currentDemo)
    elseif key == KEY_R then
        currentDemo = 14
        SetupDemo(currentDemo)
    elseif key == KEY_T then
        currentDemo = 15
        SetupDemo(currentDemo)
    elseif key == KEY_Y then
        currentDemo = 16
        SetupDemo(currentDemo)
    -- Arrow keys for prev/next
    elseif key == KEY_LEFT then
        currentDemo = currentDemo - 1
        if currentDemo < 1 then currentDemo = demoCount end
        SetupDemo(currentDemo)
    elseif key == KEY_RIGHT then
        currentDemo = currentDemo + 1
        if currentDemo > demoCount then currentDemo = 1 end
        SetupDemo(currentDemo)
    end
end

function HandleScreenModeChanged(eventType, eventData)
    -- Update navigation button positions
    UpdateNavButtonPositions()

    -- Recalculate layout when window size changes
    if rootNode ~= nil then
        SetupDemo(currentDemo)
    end
end

-------------------------------------------------
-- Mouse interaction handlers
-------------------------------------------------
function HitTestNavButtons(mouseX, mouseY)
    for i, btn in ipairs(navButtons) do
        if mouseX >= btn.x and mouseX <= btn.x + btn.w and
           mouseY >= btn.y and mouseY <= btn.y + btn.h then
            return btn
        end
    end
    return nil
end

function GetNodeBounds(item)
    local x = YGNodeLayoutGetLeft(item.node)
    local y = YGNodeLayoutGetTop(item.node)
    local w = YGNodeLayoutGetWidth(item.node)
    local h = YGNodeLayoutGetHeight(item.node)

    -- Get parent offset for correct positioning
    local parent = YGNodeGetParent(item.node)
    while parent ~= nil and parent ~= rootNode do
        x = x + YGNodeLayoutGetLeft(parent)
        y = y + YGNodeLayoutGetTop(parent)
        parent = YGNodeGetParent(parent)
    end

    return x, y, w, h
end

function HitTest(mouseX, mouseY)
    -- Test in reverse order (top-most first)
    for i = #layoutNodes, 1, -1 do
        local item = layoutNodes[i]
        if item.interactive then
            local x, y, w, h = GetNodeBounds(item)
            if mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h then
                return item
            end
        end
    end
    return nil
end

function HandleMouseMove(eventType, eventData)
    local mouseX = eventData["X"]:GetInt()
    local mouseY = eventData["Y"]:GetInt()

    -- Check nav buttons first
    local navBtn = HitTestNavButtons(mouseX, mouseY)
    for _, btn in ipairs(navButtons) do
        btn.isHovered = (btn == navBtn)
    end

    local hitNode = HitTest(mouseX, mouseY)

    -- Handle hover state changes
    if hitNode ~= hoveredNode then
        -- Exit previous hover
        if hoveredNode ~= nil and hoveredNode.onHoverExit then
            hoveredNode.onHoverExit(hoveredNode)
        end
        -- Enter new hover
        if hitNode ~= nil and hitNode.onHoverEnter then
            hitNode.onHoverEnter(hitNode)
        end
        hoveredNode = hitNode
    end

    -- Handle hover update
    if hoveredNode ~= nil and hoveredNode.onHover then
        hoveredNode.onHover(hoveredNode, mouseX, mouseY)
    end
end

function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end

    local mouseX = eventData["X"]:GetInt()
    local mouseY = eventData["Y"]:GetInt()

    -- Check nav buttons first
    local navBtn = HitTestNavButtons(mouseX, mouseY)
    if navBtn ~= nil then
        navBtn.isPressed = true
        return
    end

    local hitNode = HitTest(mouseX, mouseY)
    if hitNode ~= nil then
        pressedNode = hitNode
        hitNode.isPressed = true
        if hitNode.onPress then
            hitNode.onPress(hitNode)
        end
    end
end

function HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end

    local mouseX = eventData["X"]:GetInt()
    local mouseY = eventData["Y"]:GetInt()

    -- Check nav buttons first
    local navBtn = HitTestNavButtons(mouseX, mouseY)
    for _, btn in ipairs(navButtons) do
        if btn.isPressed then
            btn.isPressed = false
            -- If released on the same button, trigger click
            if btn == navBtn and btn.onClick then
                btn.onClick()
            end
        end
    end

    if pressedNode ~= nil then
        pressedNode.isPressed = false

        -- Check if release is on the same node (click)
        local hitNode = HitTest(mouseX, mouseY)
        if hitNode == pressedNode and pressedNode.onClick then
            pressedNode.onClick(pressedNode)
        end

        if pressedNode.onRelease then
            pressedNode.onRelease(pressedNode)
        end

        pressedNode = nil
    end
end

-------------------------------------------------
-- Touch interaction handlers (mobile support)
-------------------------------------------------
function HandleTouchBegin(eventType, eventData)
    local touchX = eventData["X"]:GetInt()
    local touchY = eventData["Y"]:GetInt()

    -- Check nav buttons first
    local navBtn = HitTestNavButtons(touchX, touchY)
    if navBtn ~= nil then
        navBtn.isPressed = true
        navBtn.isHovered = true
        return
    end

    local hitNode = HitTest(touchX, touchY)
    if hitNode ~= nil then
        pressedNode = hitNode
        hitNode.isPressed = true
        hoveredNode = hitNode
        if hitNode.onPress then
            hitNode.onPress(hitNode)
        end
        if hitNode.onHoverEnter then
            hitNode.onHoverEnter(hitNode)
        end
    end
end

function HandleTouchEnd(eventType, eventData)
    local touchX = eventData["X"]:GetInt()
    local touchY = eventData["Y"]:GetInt()

    -- Check nav buttons first
    local navBtn = HitTestNavButtons(touchX, touchY)
    for _, btn in ipairs(navButtons) do
        if btn.isPressed then
            btn.isPressed = false
            btn.isHovered = false
            -- If released on the same button, trigger click
            if btn == navBtn and btn.onClick then
                btn.onClick()
            end
        end
    end

    if pressedNode ~= nil then
        pressedNode.isPressed = false

        -- Check if release is on the same node (click)
        local hitNode = HitTest(touchX, touchY)
        if hitNode == pressedNode and pressedNode.onClick then
            pressedNode.onClick(pressedNode)
        end

        if pressedNode.onRelease then
            pressedNode.onRelease(pressedNode)
        end

        -- Clear hover state on touch end
        if pressedNode.onHoverExit then
            pressedNode.onHoverExit(pressedNode)
        end
        if hoveredNode == pressedNode then
            hoveredNode = nil
        end

        pressedNode = nil
    end
end

function HandleTouchMove(eventType, eventData)
    local touchX = eventData["X"]:GetInt()
    local touchY = eventData["Y"]:GetInt()

    -- Update nav button hover states during drag
    local navBtn = HitTestNavButtons(touchX, touchY)
    for _, btn in ipairs(navButtons) do
        btn.isHovered = (btn == navBtn and btn.isPressed)
    end

    -- Update hover state for pressed node during drag
    if pressedNode ~= nil then
        local hitNode = HitTest(touchX, touchY)
        if hitNode ~= pressedNode then
            -- Dragged outside pressed node
            if pressedNode == hoveredNode and pressedNode.onHoverExit then
                pressedNode.onHoverExit(pressedNode)
            end
            hoveredNode = hitNode
            if hitNode ~= nil and hitNode.onHoverEnter then
                hitNode.onHoverEnter(hitNode)
            end
        end

        -- Update hover for the currently hovered node
        if hoveredNode ~= nil and hoveredNode.onHover then
            hoveredNode.onHover(hoveredNode, touchX, touchY)
        end
    end
end

function SetupDemo(demoIndex)
    CleanupLayout()

    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    if demoIndex == 1 then
        SetupFlexDirectionDemo(width, height)
    elseif demoIndex == 2 then
        SetupJustifyContentDemo(width, height)
    elseif demoIndex == 3 then
        SetupAlignItemsDemo(width, height)
    elseif demoIndex == 4 then
        SetupFlexGrowShrinkDemo(width, height)
    elseif demoIndex == 5 then
        SetupFlexWrapDemo(width, height)
    elseif demoIndex == 6 then
        SetupGapDemo(width, height)
    elseif demoIndex == 7 then
        SetupAbsolutePositionDemo(width, height)
    elseif demoIndex == 8 then
        SetupNestedLayoutDemo(width, height)
    elseif demoIndex == 9 then
        SetupHolyGrailDemo(width, height)
    elseif demoIndex == 10 then
        SetupFormLayoutDemo(width, height)
    elseif demoIndex == 11 then
        SetupCardGridDemo(width, height)
    elseif demoIndex == 12 then
        SetupChatUIDemo(width, height)
    elseif demoIndex == 13 then
        SetupDashboardDemo(width, height)
    elseif demoIndex == 14 then
        SetupPercentageDemo(width, height)
    elseif demoIndex == 15 then
        SetupMinMaxDemo(width, height)
    elseif demoIndex == 16 then
        SetupComplexNestedDemo(width, height)
    end

    -- Calculate layout
    YGNodeCalculateLayout(rootNode, width, height, YGDirectionLTR)

    print("Demo " .. demoIndex .. " layout calculated")
end

-------------------------------------------------
-- Demo 1: FlexDirection (Row vs Column)
-------------------------------------------------
function SetupFlexDirectionDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifySpaceEvenly)
    YGNodeStyleSetAlignItems(rootNode, YGAlignCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 20)

    -- Left container: Column layout
    local leftBox = CreateContainer(300, 400)
    YGNodeStyleSetFlexDirection(leftBox.node, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(leftBox.node, YGJustifySpaceEvenly)
    YGNodeStyleSetAlignItems(leftBox.node, YGAlignCenter)
    YGNodeInsertChild(rootNode, leftBox.node, 0)
    leftBox.label = "FlexDirection: Column"
    table.insert(layoutNodes, leftBox)

    for i = 1, 3 do
        local child = CreateBox(80, 60, COLORS[i])
        YGNodeInsertChild(leftBox.node, child.node, i - 1)
        table.insert(layoutNodes, child)
    end

    -- Right container: Row layout
    local rightBox = CreateContainer(300, 400)
    YGNodeStyleSetFlexDirection(rightBox.node, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(rightBox.node, YGJustifySpaceEvenly)
    YGNodeStyleSetAlignItems(rightBox.node, YGAlignCenter)
    YGNodeInsertChild(rootNode, rightBox.node, 1)
    rightBox.label = "FlexDirection: Row"
    table.insert(layoutNodes, rightBox)

    for i = 1, 3 do
        local child = CreateBox(60, 80, COLORS[i + 3])
        YGNodeInsertChild(rightBox.node, child.node, i - 1)
        table.insert(layoutNodes, child)
    end
end

-------------------------------------------------
-- Demo 2: JustifyContent
-------------------------------------------------
function SetupJustifyContentDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionRow)
    YGNodeStyleSetFlexWrap(rootNode, YGWrapWrap)
    YGNodeStyleSetAlignContent(rootNode, YGAlignSpaceAround)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 10)

    local justifyModes = {
        { mode = YGJustifyFlexStart, label = "FlexStart" },
        { mode = YGJustifyCenter, label = "Center" },
        { mode = YGJustifyFlexEnd, label = "FlexEnd" },
        { mode = YGJustifySpaceBetween, label = "SpaceBetween" },
        { mode = YGJustifySpaceAround, label = "SpaceAround" },
        { mode = YGJustifySpaceEvenly, label = "SpaceEvenly" },
    }

    local boxWidth = (width - 40) / 3

    for i, item in ipairs(justifyModes) do
        local container = CreateContainer(boxWidth - 10, 120)
        YGNodeStyleSetFlexDirection(container.node, YGFlexDirectionRow)
        YGNodeStyleSetJustifyContent(container.node, item.mode)
        YGNodeStyleSetAlignItems(container.node, YGAlignCenter)
        YGNodeStyleSetMargin(container.node, YGEdgeAll, 5)
        YGNodeInsertChild(rootNode, container.node, i - 1)
        container.label = item.label
        table.insert(layoutNodes, container)

        for j = 1, 3 do
            local child = CreateBox(30, 40, COLORS[j])
            YGNodeInsertChild(container.node, child.node, j - 1)
            table.insert(layoutNodes, child)
        end
    end
end

-------------------------------------------------
-- Demo 3: AlignItems
-------------------------------------------------
function SetupAlignItemsDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifySpaceEvenly)
    YGNodeStyleSetAlignItems(rootNode, YGAlignCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 20)

    local alignModes = {
        { mode = YGAlignFlexStart, label = "FlexStart" },
        { mode = YGAlignCenter, label = "Center" },
        { mode = YGAlignFlexEnd, label = "FlexEnd" },
        { mode = YGAlignStretch, label = "Stretch" },
    }

    for i, item in ipairs(alignModes) do
        local container = CreateContainer(150, 300)
        YGNodeStyleSetFlexDirection(container.node, YGFlexDirectionRow)
        YGNodeStyleSetJustifyContent(container.node, YGJustifySpaceEvenly)
        YGNodeStyleSetAlignItems(container.node, item.mode)
        YGNodeInsertChild(rootNode, container.node, i - 1)
        container.label = item.label
        table.insert(layoutNodes, container)

        local heights = { 40, 60, 80 }
        for j = 1, 3 do
            local h = heights[j]
            if item.mode == YGAlignStretch then
                h = 0  -- Will be auto-calculated
            end
            local child = CreateBox(30, h, COLORS[j])
            if item.mode == YGAlignStretch then
                YGNodeStyleSetHeightAuto(child.node)
            end
            YGNodeInsertChild(container.node, child.node, j - 1)
            table.insert(layoutNodes, child)
        end
    end
end

-------------------------------------------------
-- Demo 4: Flex Grow/Shrink
-------------------------------------------------
function SetupFlexGrowShrinkDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifySpaceEvenly)
    YGNodeStyleSetAlignItems(rootNode, YGAlignCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 40)

    -- Grow demo
    local growContainer = CreateContainer(width - 100, 150)
    YGNodeStyleSetFlexDirection(growContainer.node, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(growContainer.node, YGAlignStretch)
    YGNodeInsertChild(rootNode, growContainer.node, 0)
    growContainer.label = "Flex Grow (1:2:1)"
    table.insert(layoutNodes, growContainer)

    local growValues = { 1, 2, 1 }
    for i = 1, 3 do
        local child = CreateBox(50, 0, COLORS[i])
        YGNodeStyleSetFlexGrow(child.node, growValues[i])
        YGNodeInsertChild(growContainer.node, child.node, i - 1)
        child.label = "grow=" .. growValues[i]
        table.insert(layoutNodes, child)
    end

    -- Shrink demo
    local shrinkContainer = CreateContainer(width - 100, 150)
    YGNodeStyleSetFlexDirection(shrinkContainer.node, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(shrinkContainer.node, YGAlignStretch)
    YGNodeInsertChild(rootNode, shrinkContainer.node, 1)
    shrinkContainer.label = "Flex Shrink (1:2:1)"
    table.insert(layoutNodes, shrinkContainer)

    local shrinkValues = { 1, 2, 1 }
    for i = 1, 3 do
        local child = CreateBox(300, 0, COLORS[i + 3])
        YGNodeStyleSetFlexShrink(child.node, shrinkValues[i])
        YGNodeInsertChild(shrinkContainer.node, child.node, i - 1)
        child.label = "shrink=" .. shrinkValues[i]
        table.insert(layoutNodes, child)
    end
end

-------------------------------------------------
-- Demo 5: Flex Wrap
-------------------------------------------------
function SetupFlexWrapDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionRow)
    YGNodeStyleSetFlexWrap(rootNode, YGWrapWrap)
    YGNodeStyleSetAlignContent(rootNode, YGAlignFlexStart)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 20)

    for i = 1, 15 do
        local child = CreateBox(100, 80, COLORS[((i - 1) % 6) + 1])
        YGNodeStyleSetMargin(child.node, YGEdgeAll, 10)
        YGNodeInsertChild(rootNode, child.node, i - 1)
        child.label = tostring(i)
        table.insert(layoutNodes, child)
    end
end

-------------------------------------------------
-- Demo 6: Gap
-------------------------------------------------
function SetupGapDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifySpaceEvenly)
    YGNodeStyleSetAlignItems(rootNode, YGAlignCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 30)

    -- No gap
    local noGapContainer = CreateContainer(200, 300)
    YGNodeStyleSetFlexDirection(noGapContainer.node, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(noGapContainer.node, YGJustifyFlexStart)
    YGNodeStyleSetAlignItems(noGapContainer.node, YGAlignCenter)
    YGNodeInsertChild(rootNode, noGapContainer.node, 0)
    noGapContainer.label = "No Gap"
    table.insert(layoutNodes, noGapContainer)

    for i = 1, 4 do
        local child = CreateBox(60, 50, COLORS[i])
        YGNodeInsertChild(noGapContainer.node, child.node, i - 1)
        table.insert(layoutNodes, child)
    end

    -- Row gap
    local rowGapContainer = CreateContainer(200, 300)
    YGNodeStyleSetFlexDirection(rowGapContainer.node, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(rowGapContainer.node, YGJustifyFlexStart)
    YGNodeStyleSetAlignItems(rowGapContainer.node, YGAlignCenter)
    YGNodeStyleSetGap(rowGapContainer.node, YGGutterRow, 20)
    YGNodeInsertChild(rootNode, rowGapContainer.node, 1)
    rowGapContainer.label = "Row Gap: 20"
    table.insert(layoutNodes, rowGapContainer)

    for i = 1, 4 do
        local child = CreateBox(60, 50, COLORS[i])
        YGNodeInsertChild(rowGapContainer.node, child.node, i - 1)
        table.insert(layoutNodes, child)
    end

    -- All gap
    local allGapContainer = CreateContainer(200, 300)
    YGNodeStyleSetFlexDirection(allGapContainer.node, YGFlexDirectionRow)
    YGNodeStyleSetFlexWrap(allGapContainer.node, YGWrapWrap)
    YGNodeStyleSetJustifyContent(allGapContainer.node, YGJustifyFlexStart)
    YGNodeStyleSetAlignContent(allGapContainer.node, YGAlignFlexStart)
    YGNodeStyleSetGap(allGapContainer.node, YGGutterAll, 15)
    YGNodeInsertChild(rootNode, allGapContainer.node, 2)
    allGapContainer.label = "All Gap: 15"
    table.insert(layoutNodes, allGapContainer)

    for i = 1, 6 do
        local child = CreateBox(50, 50, COLORS[i])
        YGNodeInsertChild(allGapContainer.node, child.node, i - 1)
        table.insert(layoutNodes, child)
    end
end

-------------------------------------------------
-- Demo 7: Absolute Positioning
-------------------------------------------------
function SetupAbsolutePositionDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 50)

    -- Relative container
    local container = CreateContainer(width - 100, height - 100)
    YGNodeStyleSetFlexDirection(container.node, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(container.node, YGJustifyCenter)
    YGNodeStyleSetAlignItems(container.node, YGAlignCenter)
    YGNodeInsertChild(rootNode, container.node, 0)
    container.label = "Relative Container"
    table.insert(layoutNodes, container)

    -- Center child (relative)
    local centerChild = CreateBox(100, 100, COLORS[1])
    YGNodeInsertChild(container.node, centerChild.node, 0)
    centerChild.label = "Relative"
    table.insert(layoutNodes, centerChild)

    -- Top-left absolute child
    local topLeft = CreateBox(80, 80, COLORS[2])
    YGNodeStyleSetPositionType(topLeft.node, YGPositionTypeAbsolute)
    YGNodeStyleSetPosition(topLeft.node, YGEdgeTop, 10)
    YGNodeStyleSetPosition(topLeft.node, YGEdgeLeft, 10)
    YGNodeInsertChild(container.node, topLeft.node, 1)
    topLeft.label = "Absolute TL"
    table.insert(layoutNodes, topLeft)

    -- Top-right absolute child
    local topRight = CreateBox(80, 80, COLORS[3])
    YGNodeStyleSetPositionType(topRight.node, YGPositionTypeAbsolute)
    YGNodeStyleSetPosition(topRight.node, YGEdgeTop, 10)
    YGNodeStyleSetPosition(topRight.node, YGEdgeRight, 10)
    YGNodeInsertChild(container.node, topRight.node, 2)
    topRight.label = "Absolute TR"
    table.insert(layoutNodes, topRight)

    -- Bottom-left absolute child
    local bottomLeft = CreateBox(80, 80, COLORS[4])
    YGNodeStyleSetPositionType(bottomLeft.node, YGPositionTypeAbsolute)
    YGNodeStyleSetPosition(bottomLeft.node, YGEdgeBottom, 10)
    YGNodeStyleSetPosition(bottomLeft.node, YGEdgeLeft, 10)
    YGNodeInsertChild(container.node, bottomLeft.node, 3)
    bottomLeft.label = "Absolute BL"
    table.insert(layoutNodes, bottomLeft)

    -- Bottom-right absolute child
    local bottomRight = CreateBox(80, 80, COLORS[5])
    YGNodeStyleSetPositionType(bottomRight.node, YGPositionTypeAbsolute)
    YGNodeStyleSetPosition(bottomRight.node, YGEdgeBottom, 10)
    YGNodeStyleSetPosition(bottomRight.node, YGEdgeRight, 10)
    YGNodeInsertChild(container.node, bottomRight.node, 4)
    bottomRight.label = "Absolute BR"
    table.insert(layoutNodes, bottomRight)
end

-------------------------------------------------
-- Demo 8: Nested Layout (Real-world example)
-------------------------------------------------
function SetupNestedLayoutDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 20)

    -- Header
    local header = CreateContainer(0, 60)
    YGNodeStyleSetWidthPercent(header.node, 100)
    YGNodeStyleSetFlexDirection(header.node, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(header.node, YGJustifySpaceBetween)
    YGNodeStyleSetAlignItems(header.node, YGAlignCenter)
    YGNodeStyleSetPadding(header.node, YGEdgeHorizontal, 20)
    YGNodeInsertChild(rootNode, header.node, 0)
    header.label = "Header"
    header.color = { r = 0.2, g = 0.2, b = 0.3, a = 1.0 }
    table.insert(layoutNodes, header)

    local logo = CreateBox(40, 40, COLORS[1])
    YGNodeInsertChild(header.node, logo.node, 0)
    table.insert(layoutNodes, logo)

    local navContainer = YGNodeNew()
    YGNodeStyleSetFlexDirection(navContainer, YGFlexDirectionRow)
    YGNodeStyleSetGap(navContainer, YGGutterColumn, 20)
    YGNodeInsertChild(header.node, navContainer, 1)

    for i = 1, 3 do
        local navItem = CreateBox(60, 30, COLORS[i + 1])
        YGNodeInsertChild(navContainer, navItem.node, i - 1)
        table.insert(layoutNodes, navItem)
    end

    -- Main content area
    local main = YGNodeNew()
    YGNodeStyleSetFlexGrow(main, 1)
    YGNodeStyleSetFlexDirection(main, YGFlexDirectionRow)
    YGNodeStyleSetMargin(main, YGEdgeVertical, 10)
    YGNodeInsertChild(rootNode, main, 1)

    -- Sidebar
    local sidebar = CreateContainer(200, 0)
    YGNodeStyleSetFlexDirection(sidebar.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(sidebar.node, YGEdgeAll, 10)
    YGNodeStyleSetGap(sidebar.node, YGGutterRow, 10)
    YGNodeInsertChild(main, sidebar.node, 0)
    sidebar.label = "Sidebar"
    sidebar.color = { r = 0.15, g = 0.15, b = 0.2, a = 1.0 }
    table.insert(layoutNodes, sidebar)

    for i = 1, 4 do
        local sideItem = CreateBox(0, 40, COLORS[i])
        YGNodeStyleSetWidthPercent(sideItem.node, 100)
        YGNodeInsertChild(sidebar.node, sideItem.node, i - 1)
        table.insert(layoutNodes, sideItem)
    end

    -- Content
    local content = CreateContainer(0, 0)
    YGNodeStyleSetFlexGrow(content.node, 1)
    YGNodeStyleSetFlexDirection(content.node, YGFlexDirectionRow)
    YGNodeStyleSetFlexWrap(content.node, YGWrapWrap)
    YGNodeStyleSetAlignContent(content.node, YGAlignFlexStart)
    YGNodeStyleSetPadding(content.node, YGEdgeAll, 10)
    YGNodeStyleSetGap(content.node, YGGutterAll, 10)
    YGNodeStyleSetMargin(content.node, YGEdgeLeft, 10)
    YGNodeInsertChild(main, content.node, 1)
    content.label = "Content"
    content.color = { r = 0.12, g = 0.12, b = 0.15, a = 1.0 }
    table.insert(layoutNodes, content)

    for i = 1, 6 do
        local card = CreateBox(150, 100, COLORS[((i - 1) % 6) + 1])
        YGNodeInsertChild(content.node, card.node, i - 1)
        table.insert(layoutNodes, card)
    end

    -- Footer
    local footer = CreateContainer(0, 50)
    YGNodeStyleSetWidthPercent(footer.node, 100)
    YGNodeStyleSetFlexDirection(footer.node, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(footer.node, YGJustifyCenter)
    YGNodeStyleSetAlignItems(footer.node, YGAlignCenter)
    YGNodeInsertChild(rootNode, footer.node, 2)
    footer.label = "Footer"
    footer.color = { r = 0.2, g = 0.2, b = 0.3, a = 1.0 }
    table.insert(layoutNodes, footer)
end

-------------------------------------------------
-- Demo 9: Holy Grail Layout (Classic 3-column)
-------------------------------------------------
function SetupHolyGrailDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 10)

    -- Header (full width)
    local header = CreateContainer(0, 80)
    YGNodeStyleSetWidthPercent(header.node, 100)
    YGNodeStyleSetFlexDirection(header.node, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(header.node, YGJustifyCenter)
    YGNodeStyleSetAlignItems(header.node, YGAlignCenter)
    YGNodeInsertChild(rootNode, header.node, 0)
    header.label = "Header"
    header.color = { r = 0.4, g = 0.2, b = 0.6, a = 1.0 }
    table.insert(layoutNodes, header)

    -- Middle section (3 columns)
    local middle = YGNodeNew()
    YGNodeStyleSetFlexGrow(middle, 1)
    YGNodeStyleSetFlexDirection(middle, YGFlexDirectionRow)
    YGNodeStyleSetMargin(middle, YGEdgeVertical, 10)
    YGNodeInsertChild(rootNode, middle, 1)

    -- Left sidebar (fixed width)
    local leftSidebar = CreateContainer(180, 0)
    YGNodeStyleSetFlexDirection(leftSidebar.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(leftSidebar.node, YGEdgeAll, 10)
    YGNodeStyleSetGap(leftSidebar.node, YGGutterRow, 8)
    YGNodeInsertChild(middle, leftSidebar.node, 0)
    leftSidebar.label = "Nav"
    leftSidebar.color = { r = 0.2, g = 0.4, b = 0.3, a = 1.0 }
    table.insert(layoutNodes, leftSidebar)

    -- Main content (flexible) - declared early so nav items can reference it
    local mainContent = CreateContainer(0, 0)

    local selectedNav = nil
    for i = 1, 5 do
        local navIndex = i
        local navItem = CreateButton(0, 35, COLORS[((i - 1) % 6) + 1], "Nav " .. i, function(self)
            print("Nav " .. navIndex .. " clicked!")
            -- Update main content label
            mainContent.label = "Content: Nav " .. navIndex
            -- Visual feedback
            if selectedNav then
                selectedNav.label = "Nav " .. selectedNav.navIndex
            end
            self.label = "→ Nav " .. navIndex
            selectedNav = self
            self.navIndex = navIndex
        end)
        navItem.navIndex = navIndex
        YGNodeStyleSetWidthPercent(navItem.node, 100)
        YGNodeInsertChild(leftSidebar.node, navItem.node, i - 1)
        table.insert(layoutNodes, navItem)
    end

    -- Main content setup
    YGNodeStyleSetFlexGrow(mainContent.node, 1)
    YGNodeStyleSetFlexDirection(mainContent.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(mainContent.node, YGEdgeAll, 15)
    YGNodeStyleSetMargin(mainContent.node, YGEdgeHorizontal, 10)
    YGNodeInsertChild(middle, mainContent.node, 1)
    mainContent.label = "Main Content"
    mainContent.color = { r = 0.15, g = 0.15, b = 0.2, a = 1.0 }
    table.insert(layoutNodes, mainContent)

    -- Content items
    local article = CreateBox(0, 200, COLORS[1])
    YGNodeStyleSetWidthPercent(article.node, 100)
    YGNodeInsertChild(mainContent.node, article.node, 0)
    article.label = "Article"
    table.insert(layoutNodes, article)

    local comments = CreateBox(0, 100, COLORS[2])
    YGNodeStyleSetWidthPercent(comments.node, 100)
    YGNodeStyleSetMargin(comments.node, YGEdgeTop, 10)
    YGNodeInsertChild(mainContent.node, comments.node, 1)
    comments.label = "Comments"
    table.insert(layoutNodes, comments)

    -- Right sidebar (fixed width)
    local rightSidebar = CreateContainer(150, 0)
    YGNodeStyleSetFlexDirection(rightSidebar.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(rightSidebar.node, YGEdgeAll, 10)
    YGNodeStyleSetGap(rightSidebar.node, YGGutterRow, 8)
    YGNodeInsertChild(middle, rightSidebar.node, 2)
    rightSidebar.label = "Ads"
    rightSidebar.color = { r = 0.3, g = 0.25, b = 0.2, a = 1.0 }
    table.insert(layoutNodes, rightSidebar)

    for i = 1, 3 do
        local adItem = CreateBox(0, 80, COLORS[i + 2])
        YGNodeStyleSetWidthPercent(adItem.node, 100)
        YGNodeInsertChild(rightSidebar.node, adItem.node, i - 1)
        adItem.label = "Ad " .. i
        table.insert(layoutNodes, adItem)
    end

    -- Footer
    local footer = CreateContainer(0, 60)
    YGNodeStyleSetWidthPercent(footer.node, 100)
    YGNodeStyleSetJustifyContent(footer.node, YGJustifyCenter)
    YGNodeStyleSetAlignItems(footer.node, YGAlignCenter)
    YGNodeInsertChild(rootNode, footer.node, 2)
    footer.label = "Footer"
    footer.color = { r = 0.4, g = 0.2, b = 0.6, a = 1.0 }
    table.insert(layoutNodes, footer)
end

-------------------------------------------------
-- Demo 10: Form Layout (Label + Input pairs)
-------------------------------------------------
function SetupFormLayoutDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifyCenter)
    YGNodeStyleSetAlignItems(rootNode, YGAlignCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 40)

    -- Form container
    local form = CreateContainer(500, 0)
    YGNodeStyleSetFlexDirection(form.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(form.node, YGEdgeAll, 30)
    YGNodeStyleSetGap(form.node, YGGutterRow, 20)
    YGNodeInsertChild(rootNode, form.node, 0)
    form.label = "Form"
    form.color = { r = 0.12, g = 0.12, b = 0.18, a = 1.0 }
    table.insert(layoutNodes, form)

    local fields = { "Username", "Email", "Password", "Confirm" }

    for i, fieldName in ipairs(fields) do
        -- Row container
        local row = YGNodeNew()
        YGNodeStyleSetFlexDirection(row, YGFlexDirectionRow)
        YGNodeStyleSetAlignItems(row, YGAlignCenter)
        YGNodeStyleSetWidthPercent(row, 100)
        YGNodeInsertChild(form.node, row, i - 1)

        -- Label
        local label = CreateBox(120, 40, { r = 0.25, g = 0.25, b = 0.3, a = 1.0 })
        YGNodeStyleSetJustifyContent(label.node, YGJustifyFlexEnd)
        YGNodeStyleSetAlignItems(label.node, YGAlignCenter)
        YGNodeStyleSetPadding(label.node, YGEdgeRight, 10)
        YGNodeInsertChild(row, label.node, 0)
        label.label = fieldName
        table.insert(layoutNodes, label)

        -- Input field
        local input = CreateBox(0, 40, COLORS[i])
        YGNodeStyleSetFlexGrow(input.node, 1)
        YGNodeStyleSetMargin(input.node, YGEdgeLeft, 15)
        YGNodeInsertChild(row, input.node, 1)
        input.label = "Input"
        table.insert(layoutNodes, input)
    end

    -- Button row
    local buttonRow = YGNodeNew()
    YGNodeStyleSetFlexDirection(buttonRow, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(buttonRow, YGJustifyFlexEnd)
    YGNodeStyleSetWidthPercent(buttonRow, 100)
    YGNodeStyleSetMargin(buttonRow, YGEdgeTop, 10)
    YGNodeStyleSetGap(buttonRow, YGGutterColumn, 15)
    YGNodeInsertChild(form.node, buttonRow, #fields)

    local cancelBtn = CreateButton(100, 45, { r = 0.4, g = 0.4, b = 0.45, a = 1.0 }, "Cancel", function(self)
        print("Cancel button clicked!")
        form.label = "Form (Cancelled)"
    end)
    YGNodeInsertChild(buttonRow, cancelBtn.node, 0)
    table.insert(layoutNodes, cancelBtn)

    local submitBtn = CreateButton(100, 45, COLORS[3], "Submit", function(self)
        clickCount = clickCount + 1
        print("Submit button clicked! Count: " .. clickCount)
        form.label = "Form (Submitted: " .. clickCount .. ")"
    end)
    YGNodeInsertChild(buttonRow, submitBtn.node, 1)
    table.insert(layoutNodes, submitBtn)
end

-------------------------------------------------
-- Demo 11: Card Grid (Responsive cards)
-------------------------------------------------
function SetupCardGridDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionRow)
    YGNodeStyleSetFlexWrap(rootNode, YGWrapWrap)
    YGNodeStyleSetAlignContent(rootNode, YGAlignFlexStart)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifyCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 20)
    YGNodeStyleSetGap(rootNode, YGGutterAll, 20)

    for i = 1, 12 do
        -- Card container
        local card = CreateContainer(200, 250)
        YGNodeStyleSetFlexDirection(card.node, YGFlexDirectionColumn)
        YGNodeStyleSetPadding(card.node, YGEdgeAll, 0)
        YGNodeInsertChild(rootNode, card.node, i - 1)
        card.color = { r = 0.15, g = 0.15, b = 0.2, a = 1.0 }
        table.insert(layoutNodes, card)

        -- Card image
        local cardImage = CreateBox(0, 120, COLORS[((i - 1) % 6) + 1])
        YGNodeStyleSetWidthPercent(cardImage.node, 100)
        YGNodeInsertChild(card.node, cardImage.node, 0)
        cardImage.label = "Image"
        table.insert(layoutNodes, cardImage)

        -- Card content area
        local cardContent = YGNodeNew()
        YGNodeStyleSetFlexGrow(cardContent, 1)
        YGNodeStyleSetFlexDirection(cardContent, YGFlexDirectionColumn)
        YGNodeStyleSetPadding(cardContent, YGEdgeAll, 12)
        YGNodeStyleSetJustifyContent(cardContent, YGJustifySpaceBetween)
        YGNodeInsertChild(card.node, cardContent, 1)

        -- Title
        local title = CreateBox(0, 25, { r = 0.3, g = 0.3, b = 0.35, a = 1.0 })
        YGNodeStyleSetWidthPercent(title.node, 100)
        YGNodeInsertChild(cardContent, title.node, 0)
        title.label = "Card " .. i
        table.insert(layoutNodes, title)

        -- Description
        local desc = CreateBox(0, 40, { r = 0.2, g = 0.2, b = 0.25, a = 1.0 })
        YGNodeStyleSetWidthPercent(desc.node, 100)
        YGNodeInsertChild(cardContent, desc.node, 1)
        desc.label = "Description"
        table.insert(layoutNodes, desc)

        -- Button
        local cardIndex = i
        local button = CreateButton(0, 30, COLORS[3], "Action", function(self)
            print("Card " .. cardIndex .. " action clicked!")
            title.label = "Card " .. cardIndex .. " (Clicked!)"
        end)
        YGNodeStyleSetWidthPercent(button.node, 100)
        YGNodeInsertChild(cardContent, button.node, 2)
        table.insert(layoutNodes, button)
    end
end

-------------------------------------------------
-- Demo 12: Chat UI (Message bubbles)
-------------------------------------------------
function SetupChatUIDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifyCenter)
    YGNodeStyleSetAlignItems(rootNode, YGAlignCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 20)

    -- Chat container
    local chatContainer = CreateContainer(500, height - 100)
    YGNodeStyleSetFlexDirection(chatContainer.node, YGFlexDirectionColumn)
    YGNodeInsertChild(rootNode, chatContainer.node, 0)
    chatContainer.color = { r = 0.1, g = 0.1, b = 0.12, a = 1.0 }
    table.insert(layoutNodes, chatContainer)

    -- Chat header
    local chatHeader = CreateBox(0, 50, { r = 0.2, g = 0.3, b = 0.4, a = 1.0 })
    YGNodeStyleSetWidthPercent(chatHeader.node, 100)
    YGNodeStyleSetJustifyContent(chatHeader.node, YGJustifyCenter)
    YGNodeStyleSetAlignItems(chatHeader.node, YGAlignCenter)
    YGNodeInsertChild(chatContainer.node, chatHeader.node, 0)
    chatHeader.label = "Chat Room"
    table.insert(layoutNodes, chatHeader)

    -- Messages area
    local messagesArea = YGNodeNew()
    YGNodeStyleSetFlexGrow(messagesArea, 1)
    YGNodeStyleSetFlexDirection(messagesArea, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(messagesArea, YGEdgeAll, 15)
    YGNodeStyleSetGap(messagesArea, YGGutterRow, 10)
    YGNodeInsertChild(chatContainer.node, messagesArea, 1)

    -- Messages (alternating left/right)
    local messages = {
        { text = "Hello!", sender = "other", width = 100 },
        { text = "Hi there!", sender = "me", width = 120 },
        { text = "How are you?", sender = "other", width = 150 },
        { text = "I'm good, thanks!", sender = "me", width = 180 },
        { text = "Nice weather today", sender = "other", width = 200 },
        { text = "Yes, perfect for a walk", sender = "me", width = 220 },
        { text = "See you later!", sender = "other", width = 160 },
    }

    for i, msg in ipairs(messages) do
        local row = YGNodeNew()
        YGNodeStyleSetFlexDirection(row, YGFlexDirectionRow)
        YGNodeStyleSetWidthPercent(row, 100)
        if msg.sender == "me" then
            YGNodeStyleSetJustifyContent(row, YGJustifyFlexEnd)
        else
            YGNodeStyleSetJustifyContent(row, YGJustifyFlexStart)
        end
        YGNodeInsertChild(messagesArea, row, i - 1)

        local bubble = CreateBox(msg.width, 40,
            msg.sender == "me" and COLORS[3] or { r = 0.3, g = 0.3, b = 0.35, a = 1.0 })
        YGNodeInsertChild(row, bubble.node, 0)
        bubble.label = msg.text
        table.insert(layoutNodes, bubble)
    end

    -- Input area
    local inputArea = YGNodeNew()
    YGNodeStyleSetFlexDirection(inputArea, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(inputArea, 100)
    YGNodeStyleSetHeight(inputArea, 60)
    YGNodeStyleSetPadding(inputArea, YGEdgeAll, 10)
    YGNodeStyleSetGap(inputArea, YGGutterColumn, 10)
    YGNodeStyleSetAlignItems(inputArea, YGAlignCenter)
    YGNodeInsertChild(chatContainer.node, inputArea, 2)

    local textInput = CreateBox(0, 40, { r = 0.2, g = 0.2, b = 0.25, a = 1.0 })
    YGNodeStyleSetFlexGrow(textInput.node, 1)
    YGNodeInsertChild(inputArea, textInput.node, 0)
    textInput.label = "Type message..."
    table.insert(layoutNodes, textInput)

    local messageCount = #messages
    local sendBtn = CreateButton(80, 40, COLORS[3], "Send", function(self)
        messageCount = messageCount + 1
        print("Send clicked! Message #" .. messageCount)
        chatHeader.label = "Chat Room (" .. messageCount .. " msgs)"
    end)
    YGNodeInsertChild(inputArea, sendBtn.node, 1)
    table.insert(layoutNodes, sendBtn)
end

-------------------------------------------------
-- Demo 13: Dashboard (Statistics panels)
-------------------------------------------------
function SetupDashboardDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 20)
    YGNodeStyleSetGap(rootNode, YGGutterRow, 20)

    -- Stats row (4 cards)
    local statsRow = YGNodeNew()
    YGNodeStyleSetFlexDirection(statsRow, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(statsRow, 100)
    YGNodeStyleSetGap(statsRow, YGGutterColumn, 15)
    YGNodeInsertChild(rootNode, statsRow, 0)

    local stats = {
        { label = "Users", value = "12,345", color = COLORS[1] },
        { label = "Revenue", value = "$54,321", color = COLORS[2] },
        { label = "Orders", value = "1,234", color = COLORS[3] },
        { label = "Growth", value = "+23%", color = COLORS[4] },
    }

    for i, stat in ipairs(stats) do
        local statIndex = i
        local card = CreateButton(0, 100, stat.color, stat.label .. "\n" .. stat.value, function(self)
            print(stat.label .. " card clicked!")
            self.label = stat.label .. "\n" .. stat.value .. "\n(Selected)"
        end)
        YGNodeStyleSetFlexGrow(card.node, 1)
        YGNodeStyleSetFlexDirection(card.node, YGFlexDirectionColumn)
        YGNodeStyleSetJustifyContent(card.node, YGJustifyCenter)
        YGNodeStyleSetAlignItems(card.node, YGAlignCenter)
        YGNodeInsertChild(statsRow, card.node, i - 1)
        table.insert(layoutNodes, card)
    end

    -- Charts row (2 charts)
    local chartsRow = YGNodeNew()
    YGNodeStyleSetFlexDirection(chartsRow, YGFlexDirectionRow)
    YGNodeStyleSetFlexGrow(chartsRow, 1)
    YGNodeStyleSetWidthPercent(chartsRow, 100)
    YGNodeStyleSetGap(chartsRow, YGGutterColumn, 15)
    YGNodeInsertChild(rootNode, chartsRow, 1)

    -- Left chart (line chart placeholder)
    local lineChart = CreateContainer(0, 0)
    YGNodeStyleSetFlexGrow(lineChart.node, 2)
    YGNodeStyleSetFlexDirection(lineChart.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(lineChart.node, YGEdgeAll, 15)
    YGNodeInsertChild(chartsRow, lineChart.node, 0)
    lineChart.label = "Sales Trend"
    lineChart.color = { r = 0.12, g = 0.12, b = 0.18, a = 1.0 }
    table.insert(layoutNodes, lineChart)

    -- Simulated bar chart
    local barsContainer = YGNodeNew()
    YGNodeStyleSetFlexGrow(barsContainer, 1)
    YGNodeStyleSetFlexDirection(barsContainer, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(barsContainer, YGAlignFlexEnd)
    YGNodeStyleSetJustifyContent(barsContainer, YGJustifySpaceEvenly)
    YGNodeStyleSetPadding(barsContainer, YGEdgeAll, 10)
    YGNodeInsertChild(lineChart.node, barsContainer, 0)

    local barHeights = { 60, 90, 45, 120, 80, 100, 70 }
    for i, h in ipairs(barHeights) do
        local bar = CreateBox(30, h, COLORS[((i - 1) % 6) + 1])
        YGNodeInsertChild(barsContainer, bar.node, i - 1)
        table.insert(layoutNodes, bar)
    end

    -- Right chart (pie chart placeholder)
    local pieChart = CreateContainer(0, 0)
    YGNodeStyleSetFlexGrow(pieChart.node, 1)
    YGNodeStyleSetFlexDirection(pieChart.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(pieChart.node, YGEdgeAll, 15)
    YGNodeInsertChild(chartsRow, pieChart.node, 1)
    pieChart.label = "Categories"
    pieChart.color = { r = 0.12, g = 0.12, b = 0.18, a = 1.0 }
    table.insert(layoutNodes, pieChart)

    -- Legend items
    local legendContainer = YGNodeNew()
    YGNodeStyleSetFlexGrow(legendContainer, 1)
    YGNodeStyleSetFlexDirection(legendContainer, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(legendContainer, YGJustifySpaceEvenly)
    YGNodeStyleSetPadding(legendContainer, YGEdgeAll, 10)
    YGNodeInsertChild(pieChart.node, legendContainer, 0)

    local categories = { "Electronics", "Clothing", "Food", "Other" }
    for i, cat in ipairs(categories) do
        local legendRow = YGNodeNew()
        YGNodeStyleSetFlexDirection(legendRow, YGFlexDirectionRow)
        YGNodeStyleSetAlignItems(legendRow, YGAlignCenter)
        YGNodeStyleSetGap(legendRow, YGGutterColumn, 10)
        YGNodeInsertChild(legendContainer, legendRow, i - 1)

        local colorBox = CreateBox(20, 20, COLORS[i])
        YGNodeInsertChild(legendRow, colorBox.node, 0)
        table.insert(layoutNodes, colorBox)

        local label = CreateBox(100, 25, { r = 0.2, g = 0.2, b = 0.25, a = 1.0 })
        YGNodeInsertChild(legendRow, label.node, 1)
        label.label = cat
        table.insert(layoutNodes, label)
    end

    -- Bottom table
    local tableContainer = CreateContainer(0, 150)
    YGNodeStyleSetWidthPercent(tableContainer.node, 100)
    YGNodeStyleSetFlexDirection(tableContainer.node, YGFlexDirectionColumn)
    YGNodeInsertChild(rootNode, tableContainer.node, 2)
    tableContainer.label = "Recent Orders"
    tableContainer.color = { r = 0.12, g = 0.12, b = 0.18, a = 1.0 }
    table.insert(layoutNodes, tableContainer)

    -- Table header
    local tableHeader = YGNodeNew()
    YGNodeStyleSetFlexDirection(tableHeader, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(tableHeader, 100)
    YGNodeStyleSetHeight(tableHeader, 40)
    YGNodeStyleSetPadding(tableHeader, YGEdgeHorizontal, 15)
    YGNodeInsertChild(tableContainer.node, tableHeader, 0)

    local headers = { "ID", "Customer", "Amount", "Status" }
    for i, h in ipairs(headers) do
        local headerCell = CreateBox(0, 35, { r = 0.2, g = 0.2, b = 0.3, a = 1.0 })
        YGNodeStyleSetFlexGrow(headerCell.node, 1)
        YGNodeStyleSetMargin(headerCell.node, YGEdgeHorizontal, 2)
        YGNodeInsertChild(tableHeader, headerCell.node, i - 1)
        headerCell.label = h
        table.insert(layoutNodes, headerCell)
    end

    -- Table rows
    for row = 1, 2 do
        local tableRow = YGNodeNew()
        YGNodeStyleSetFlexDirection(tableRow, YGFlexDirectionRow)
        YGNodeStyleSetWidthPercent(tableRow, 100)
        YGNodeStyleSetHeight(tableRow, 40)
        YGNodeStyleSetPadding(tableRow, YGEdgeHorizontal, 15)
        YGNodeInsertChild(tableContainer.node, tableRow, row)

        local rowData = { "#" .. (1000 + row), "Customer " .. row, "$" .. (100 * row), row == 1 and "Shipped" or "Pending" }
        for i, d in ipairs(rowData) do
            local cell = CreateBox(0, 35, { r = 0.15, g = 0.15, b = 0.2, a = 1.0 })
            YGNodeStyleSetFlexGrow(cell.node, 1)
            YGNodeStyleSetMargin(cell.node, YGEdgeHorizontal, 2)
            YGNodeInsertChild(tableRow, cell.node, i - 1)
            cell.label = d
            table.insert(layoutNodes, cell)
        end
    end
end

-------------------------------------------------
-- Demo 14: Percentage-based Layout
-------------------------------------------------
function SetupPercentageDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 30)
    YGNodeStyleSetGap(rootNode, YGGutterRow, 20)

    -- Row 1: 50% / 50%
    local row1 = YGNodeNew()
    YGNodeStyleSetFlexDirection(row1, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(row1, 100)
    YGNodeStyleSetHeightPercent(row1, 20)
    YGNodeStyleSetGap(row1, YGGutterColumn, 10)
    YGNodeInsertChild(rootNode, row1, 0)

    local box1a = CreateBox(0, 0, COLORS[1])
    YGNodeStyleSetWidthPercent(box1a.node, 50)
    YGNodeStyleSetHeightPercent(box1a.node, 100)
    YGNodeInsertChild(row1, box1a.node, 0)
    box1a.label = "50%"
    table.insert(layoutNodes, box1a)

    local box1b = CreateBox(0, 0, COLORS[2])
    YGNodeStyleSetWidthPercent(box1b.node, 50)
    YGNodeStyleSetHeightPercent(box1b.node, 100)
    YGNodeInsertChild(row1, box1b.node, 1)
    box1b.label = "50%"
    table.insert(layoutNodes, box1b)

    -- Row 2: 33% / 33% / 33%
    local row2 = YGNodeNew()
    YGNodeStyleSetFlexDirection(row2, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(row2, 100)
    YGNodeStyleSetHeightPercent(row2, 20)
    YGNodeStyleSetGap(row2, YGGutterColumn, 10)
    YGNodeInsertChild(rootNode, row2, 1)

    for i = 1, 3 do
        local box = CreateBox(0, 0, COLORS[i + 2])
        YGNodeStyleSetWidthPercent(box.node, 33)
        YGNodeStyleSetHeightPercent(box.node, 100)
        YGNodeInsertChild(row2, box.node, i - 1)
        box.label = "33%"
        table.insert(layoutNodes, box)
    end

    -- Row 3: 25% / 50% / 25%
    local row3 = YGNodeNew()
    YGNodeStyleSetFlexDirection(row3, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(row3, 100)
    YGNodeStyleSetHeightPercent(row3, 20)
    YGNodeStyleSetGap(row3, YGGutterColumn, 10)
    YGNodeInsertChild(rootNode, row3, 2)

    local box3a = CreateBox(0, 0, COLORS[1])
    YGNodeStyleSetWidthPercent(box3a.node, 25)
    YGNodeStyleSetHeightPercent(box3a.node, 100)
    YGNodeInsertChild(row3, box3a.node, 0)
    box3a.label = "25%"
    table.insert(layoutNodes, box3a)

    local box3b = CreateBox(0, 0, COLORS[4])
    YGNodeStyleSetWidthPercent(box3b.node, 50)
    YGNodeStyleSetHeightPercent(box3b.node, 100)
    YGNodeInsertChild(row3, box3b.node, 1)
    box3b.label = "50%"
    table.insert(layoutNodes, box3b)

    local box3c = CreateBox(0, 0, COLORS[1])
    YGNodeStyleSetWidthPercent(box3c.node, 25)
    YGNodeStyleSetHeightPercent(box3c.node, 100)
    YGNodeInsertChild(row3, box3c.node, 2)
    box3c.label = "25%"
    table.insert(layoutNodes, box3c)

    -- Row 4: 20% each (5 items)
    local row4 = YGNodeNew()
    YGNodeStyleSetFlexDirection(row4, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(row4, 100)
    YGNodeStyleSetHeightPercent(row4, 20)
    YGNodeStyleSetGap(row4, YGGutterColumn, 10)
    YGNodeInsertChild(rootNode, row4, 3)

    for i = 1, 5 do
        local box = CreateBox(0, 0, COLORS[((i - 1) % 6) + 1])
        YGNodeStyleSetWidthPercent(box.node, 20)
        YGNodeStyleSetHeightPercent(box.node, 100)
        YGNodeInsertChild(row4, box.node, i - 1)
        box.label = "20%"
        table.insert(layoutNodes, box)
    end
end

-------------------------------------------------
-- Demo 15: Min/Max Constraints
-------------------------------------------------
function SetupMinMaxDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetJustifyContent(rootNode, YGJustifySpaceEvenly)
    YGNodeStyleSetAlignItems(rootNode, YGAlignCenter)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 40)

    -- Row 1: MinWidth demo
    local row1Container = CreateContainer(width - 100, 120)
    YGNodeStyleSetFlexDirection(row1Container.node, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(row1Container.node, YGAlignStretch)
    YGNodeInsertChild(rootNode, row1Container.node, 0)
    row1Container.label = "MinWidth: 100px (flexGrow)"
    table.insert(layoutNodes, row1Container)

    for i = 1, 4 do
        local child = CreateBox(0, 0, COLORS[i])
        YGNodeStyleSetFlexGrow(child.node, 1)
        YGNodeStyleSetMinWidth(child.node, 100)
        YGNodeInsertChild(row1Container.node, child.node, i - 1)
        child.label = "min:100"
        table.insert(layoutNodes, child)
    end

    -- Row 2: MaxWidth demo
    local row2Container = CreateContainer(width - 100, 120)
    YGNodeStyleSetFlexDirection(row2Container.node, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(row2Container.node, YGAlignStretch)
    YGNodeStyleSetJustifyContent(row2Container.node, YGJustifySpaceEvenly)
    YGNodeInsertChild(rootNode, row2Container.node, 1)
    row2Container.label = "MaxWidth: 150px"
    table.insert(layoutNodes, row2Container)

    for i = 1, 4 do
        local child = CreateBox(200, 0, COLORS[i + 1])
        YGNodeStyleSetMaxWidth(child.node, 150)
        YGNodeInsertChild(row2Container.node, child.node, i - 1)
        child.label = "max:150"
        table.insert(layoutNodes, child)
    end

    -- Row 3: MinHeight/MaxHeight demo
    local row3Container = CreateContainer(width - 100, 200)
    YGNodeStyleSetFlexDirection(row3Container.node, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(row3Container.node, YGAlignCenter)
    YGNodeStyleSetJustifyContent(row3Container.node, YGJustifySpaceEvenly)
    YGNodeInsertChild(rootNode, row3Container.node, 2)
    row3Container.label = "MinHeight:50 / MaxHeight:150"
    table.insert(layoutNodes, row3Container)

    local heights = { 30, 80, 200, 100 }
    for i, h in ipairs(heights) do
        local child = CreateBox(80, h, COLORS[((i - 1) % 6) + 1])
        YGNodeStyleSetMinHeight(child.node, 50)
        YGNodeStyleSetMaxHeight(child.node, 150)
        YGNodeInsertChild(row3Container.node, child.node, i - 1)
        child.label = "h:" .. h
        table.insert(layoutNodes, child)
    end
end

-------------------------------------------------
-- Demo 16: Complex Nested Layout
-------------------------------------------------
function SetupComplexNestedDemo(width, height)
    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, width)
    YGNodeStyleSetHeight(rootNode, height)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(rootNode, YGEdgeAll, 15)

    -- Top toolbar
    local toolbar = CreateContainer(0, 50)
    YGNodeStyleSetWidthPercent(toolbar.node, 100)
    YGNodeStyleSetFlexDirection(toolbar.node, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(toolbar.node, YGJustifySpaceBetween)
    YGNodeStyleSetAlignItems(toolbar.node, YGAlignCenter)
    YGNodeStyleSetPadding(toolbar.node, YGEdgeHorizontal, 15)
    YGNodeInsertChild(rootNode, toolbar.node, 0)
    toolbar.color = { r = 0.15, g = 0.2, b = 0.25, a = 1.0 }
    table.insert(layoutNodes, toolbar)

    -- Toolbar left
    local toolbarLeft = YGNodeNew()
    YGNodeStyleSetFlexDirection(toolbarLeft, YGFlexDirectionRow)
    YGNodeStyleSetGap(toolbarLeft, YGGutterColumn, 10)
    YGNodeInsertChild(toolbar.node, toolbarLeft, 0)

    for i = 1, 3 do
        local btn = CreateBox(35, 35, COLORS[i])
        YGNodeInsertChild(toolbarLeft, btn.node, i - 1)
        table.insert(layoutNodes, btn)
    end

    -- Toolbar right
    local toolbarRight = YGNodeNew()
    YGNodeStyleSetFlexDirection(toolbarRight, YGFlexDirectionRow)
    YGNodeStyleSetGap(toolbarRight, YGGutterColumn, 10)
    YGNodeInsertChild(toolbar.node, toolbarRight, 1)

    for i = 1, 2 do
        local btn = CreateBox(35, 35, COLORS[i + 3])
        YGNodeInsertChild(toolbarRight, btn.node, i - 1)
        table.insert(layoutNodes, btn)
    end

    -- Main area
    local mainArea = YGNodeNew()
    YGNodeStyleSetFlexGrow(mainArea, 1)
    YGNodeStyleSetFlexDirection(mainArea, YGFlexDirectionRow)
    YGNodeStyleSetMargin(mainArea, YGEdgeTop, 10)
    YGNodeInsertChild(rootNode, mainArea, 1)

    -- Left panel (tree view)
    local leftPanel = CreateContainer(220, 0)
    YGNodeStyleSetFlexDirection(leftPanel.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(leftPanel.node, YGEdgeAll, 10)
    YGNodeInsertChild(mainArea, leftPanel.node, 0)
    leftPanel.label = "Explorer"
    leftPanel.color = { r = 0.1, g = 0.1, b = 0.14, a = 1.0 }
    table.insert(layoutNodes, leftPanel)

    -- Tree items with indentation
    local treeItems = {
        { level = 0, text = "Project" },
        { level = 1, text = "src" },
        { level = 2, text = "main.cpp" },
        { level = 2, text = "utils.cpp" },
        { level = 1, text = "include" },
        { level = 2, text = "main.h" },
        { level = 1, text = "assets" },
        { level = 2, text = "textures" },
        { level = 3, text = "logo.png" },
    }

    for i, item in ipairs(treeItems) do
        local treeRow = YGNodeNew()
        YGNodeStyleSetFlexDirection(treeRow, YGFlexDirectionRow)
        YGNodeStyleSetWidthPercent(treeRow, 100)
        YGNodeStyleSetMargin(treeRow, YGEdgeLeft, item.level * 15)
        YGNodeStyleSetMargin(treeRow, YGEdgeBottom, 3)
        YGNodeInsertChild(leftPanel.node, treeRow, i - 1)

        local treeItem = CreateBox(0, 25, { r = 0.2, g = 0.2, b = 0.25, a = 1.0 })
        YGNodeStyleSetFlexGrow(treeItem.node, 1)
        YGNodeInsertChild(treeRow, treeItem.node, 0)
        treeItem.label = item.text
        table.insert(layoutNodes, treeItem)
    end

    -- Center panel (editor)
    local centerPanel = CreateContainer(0, 0)
    YGNodeStyleSetFlexGrow(centerPanel.node, 1)
    YGNodeStyleSetFlexDirection(centerPanel.node, YGFlexDirectionColumn)
    YGNodeStyleSetMargin(centerPanel.node, YGEdgeHorizontal, 10)
    YGNodeInsertChild(mainArea, centerPanel.node, 1)
    centerPanel.color = { r = 0.08, g = 0.08, b = 0.1, a = 1.0 }
    table.insert(layoutNodes, centerPanel)

    -- Tab bar
    local tabBar = YGNodeNew()
    YGNodeStyleSetFlexDirection(tabBar, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(tabBar, 100)
    YGNodeStyleSetHeight(tabBar, 35)
    YGNodeInsertChild(centerPanel.node, tabBar, 0)

    local tabs = { "main.cpp", "utils.cpp", "main.h" }
    for i, tabName in ipairs(tabs) do
        local tab = CreateBox(100, 35, i == 1 and COLORS[3] or { r = 0.15, g = 0.15, b = 0.2, a = 1.0 })
        YGNodeInsertChild(tabBar, tab.node, i - 1)
        tab.label = tabName
        table.insert(layoutNodes, tab)
    end

    -- Editor content (code lines)
    local editorContent = YGNodeNew()
    YGNodeStyleSetFlexGrow(editorContent, 1)
    YGNodeStyleSetFlexDirection(editorContent, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(editorContent, YGEdgeAll, 10)
    YGNodeInsertChild(centerPanel.node, editorContent, 1)

    for i = 1, 12 do
        local lineRow = YGNodeNew()
        YGNodeStyleSetFlexDirection(lineRow, YGFlexDirectionRow)
        YGNodeStyleSetWidthPercent(lineRow, 100)
        YGNodeStyleSetMargin(lineRow, YGEdgeBottom, 2)
        YGNodeInsertChild(editorContent, lineRow, i - 1)

        local lineNum = CreateBox(30, 18, { r = 0.15, g = 0.15, b = 0.2, a = 1.0 })
        YGNodeInsertChild(lineRow, lineNum.node, 0)
        lineNum.label = tostring(i)
        table.insert(layoutNodes, lineNum)

        local lineContent = CreateBox(0, 18, { r = 0.12, g = 0.12, b = 0.15, a = 1.0 })
        YGNodeStyleSetFlexGrow(lineContent.node, 1)
        YGNodeStyleSetMargin(lineContent.node, YGEdgeLeft, 5)
        YGNodeInsertChild(lineRow, lineContent.node, 1)
        table.insert(layoutNodes, lineContent)
    end

    -- Right panel (properties)
    local rightPanel = CreateContainer(200, 0)
    YGNodeStyleSetFlexDirection(rightPanel.node, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(rightPanel.node, YGEdgeAll, 10)
    YGNodeInsertChild(mainArea, rightPanel.node, 2)
    rightPanel.label = "Properties"
    rightPanel.color = { r = 0.1, g = 0.1, b = 0.14, a = 1.0 }
    table.insert(layoutNodes, rightPanel)

    -- Property items
    local properties = { "Name", "Type", "Size", "Modified" }
    for i, prop in ipairs(properties) do
        local propRow = YGNodeNew()
        YGNodeStyleSetFlexDirection(propRow, YGFlexDirectionColumn)
        YGNodeStyleSetWidthPercent(propRow, 100)
        YGNodeStyleSetMargin(propRow, YGEdgeBottom, 10)
        YGNodeInsertChild(rightPanel.node, propRow, i - 1)

        local propLabel = CreateBox(0, 20, { r = 0.2, g = 0.2, b = 0.25, a = 1.0 })
        YGNodeStyleSetWidthPercent(propLabel.node, 100)
        YGNodeInsertChild(propRow, propLabel.node, 0)
        propLabel.label = prop
        table.insert(layoutNodes, propLabel)

        local propValue = CreateBox(0, 25, COLORS[i])
        YGNodeStyleSetWidthPercent(propValue.node, 100)
        YGNodeStyleSetMargin(propValue.node, YGEdgeTop, 3)
        YGNodeInsertChild(propRow, propValue.node, 1)
        propValue.label = "Value"
        table.insert(layoutNodes, propValue)
    end

    -- Bottom panel (terminal)
    local bottomPanel = CreateContainer(0, 120)
    YGNodeStyleSetWidthPercent(bottomPanel.node, 100)
    YGNodeStyleSetFlexDirection(bottomPanel.node, YGFlexDirectionColumn)
    YGNodeStyleSetMargin(bottomPanel.node, YGEdgeTop, 10)
    YGNodeInsertChild(rootNode, bottomPanel.node, 2)
    bottomPanel.label = "Terminal"
    bottomPanel.color = { r = 0.05, g = 0.05, b = 0.08, a = 1.0 }
    table.insert(layoutNodes, bottomPanel)

    -- Terminal tabs
    local terminalTabs = YGNodeNew()
    YGNodeStyleSetFlexDirection(terminalTabs, YGFlexDirectionRow)
    YGNodeStyleSetWidthPercent(terminalTabs, 100)
    YGNodeStyleSetHeight(terminalTabs, 30)
    YGNodeInsertChild(bottomPanel.node, terminalTabs, 0)

    local termTabs = { "Terminal", "Output", "Problems" }
    for i, tabName in ipairs(termTabs) do
        local tab = CreateBox(80, 30, i == 1 and { r = 0.1, g = 0.1, b = 0.12, a = 1.0 } or { r = 0.07, g = 0.07, b = 0.09, a = 1.0 })
        YGNodeInsertChild(terminalTabs, tab.node, i - 1)
        tab.label = tabName
        table.insert(layoutNodes, tab)
    end
end

-------------------------------------------------
-- Helper functions
-------------------------------------------------
function CreateBox(width, height, color)
    local node = YGNodeNew()
    if width > 0 then
        YGNodeStyleSetWidth(node, width)
    end
    if height > 0 then
        YGNodeStyleSetHeight(node, height)
    end
    return { node = node, color = color, label = nil }
end

function CreateContainer(width, height)
    local node = YGNodeNew()
    if width > 0 then
        YGNodeStyleSetWidth(node, width)
    end
    if height > 0 then
        YGNodeStyleSetHeight(node, height)
    end
    return { node = node, color = { r = 0.1, g = 0.1, b = 0.12, a = 1.0 }, label = nil, isContainer = true }
end

function CreateButton(width, height, color, label, onClick)
    local node = YGNodeNew()
    if width > 0 then
        YGNodeStyleSetWidth(node, width)
    end
    if height > 0 then
        YGNodeStyleSetHeight(node, height)
    end
    return {
        node = node,
        color = color,
        label = label,
        interactive = true,
        onClick = onClick,
        onHoverEnter = function(self)
            -- Optional: could play sound or animate
        end,
        onHoverExit = function(self)
            -- Optional: reset state
        end
    }
end

function HandleRender(eventType, eventData)
    if nvgContext == nil or rootNode == nil then
        return
    end

    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()

    nvgBeginFrame(nvgContext, width, height, 1.0)

    -- Draw background
    nvgBeginPath(nvgContext)
    nvgRect(nvgContext, 0, 0, width, height)
    nvgFillColor(nvgContext, nvgRGBf(0.08, 0.08, 0.1))
    nvgFill(nvgContext)

    -- Draw demo title
    nvgFontFaceId(nvgContext, fontId)
    nvgFontSize(nvgContext, 24)
    nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvgContext, nvgRGBf(1, 1, 1))
    local demoTitles = {
        "Demo 1: FlexDirection",
        "Demo 2: JustifyContent",
        "Demo 3: AlignItems",
        "Demo 4: Flex Grow/Shrink",
        "Demo 5: Flex Wrap",
        "Demo 6: Gap",
        "Demo 7: Absolute Positioning",
        "Demo 8: Nested Layout",
        "Demo 9: Holy Grail Layout",
        "Demo 10: Form Layout",
        "Demo 11: Card Grid",
        "Demo 12: Chat UI",
        "Demo 13: Dashboard",
        "Demo 14: Percentage Layout",
        "Demo 15: Min/Max Constraints",
        "Demo 16: Complex Nested"
    }
    nvgText(nvgContext, width / 2, 40, demoTitles[currentDemo], nil)

    -- Draw all layout nodes
    for _, item in ipairs(layoutNodes) do
        DrawLayoutNode(item)
    end

    -- Draw navigation buttons
    DrawNavButtons()

    nvgEndFrame(nvgContext)
end

function DrawNavButtons()
    for _, btn in ipairs(navButtons) do
        local r, g, b, a = btn.color.r, btn.color.g, btn.color.b, btn.color.a or 1.0

        -- Adjust color for hover/pressed state
        if btn.isPressed then
            r = r * 0.6
            g = g * 0.6
            b = b * 0.6
        elseif btn.isHovered then
            r = math.min(1.0, r * 1.3)
            g = math.min(1.0, g * 1.3)
            b = math.min(1.0, b * 1.3)
        end

        -- Draw button background (rounded circle-like)
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, btn.x, btn.y, btn.w, btn.h, btn.w / 2)
        nvgFillColor(nvgContext, nvgRGBAf(r, g, b, a))
        nvgFill(nvgContext)

        -- Draw border on hover
        if btn.isHovered then
            nvgStrokeColor(nvgContext, nvgRGBAf(1, 1, 1, 0.6))
            nvgStrokeWidth(nvgContext, 2)
            nvgStroke(nvgContext)
        end

        -- Draw label (< or >)
        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 32)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBf(1, 1, 1))
        nvgText(nvgContext, btn.x + btn.w / 2, btn.y + btn.h / 2, btn.label, nil)
    end
end

function DrawLayoutNode(item)
    local x = YGNodeLayoutGetLeft(item.node)
    local y = YGNodeLayoutGetTop(item.node)
    local w = YGNodeLayoutGetWidth(item.node)
    local h = YGNodeLayoutGetHeight(item.node)

    -- Get parent offset for correct positioning
    local parent = YGNodeGetParent(item.node)
    while parent ~= nil and parent ~= rootNode do
        x = x + YGNodeLayoutGetLeft(parent)
        y = y + YGNodeLayoutGetTop(parent)
        parent = YGNodeGetParent(parent)
    end

    -- Calculate color based on interaction state
    local r, g, b, a = item.color.r, item.color.g, item.color.b, item.color.a or 1.0
    local cornerRadius = 4

    if item.interactive then
        if item.isPressed then
            -- Pressed: darken
            r = r * 0.7
            g = g * 0.7
            b = b * 0.7
        elseif item == hoveredNode then
            -- Hovered: brighten
            r = math.min(1.0, r * 1.3)
            g = math.min(1.0, g * 1.3)
            b = math.min(1.0, b * 1.3)
        end
    end

    -- Draw box
    nvgBeginPath(nvgContext)
    nvgRoundedRect(nvgContext, x, y, w, h, cornerRadius)

    if item.isContainer then
        nvgFillColor(nvgContext, nvgRGBAf(r, g, b, 0.8))
        nvgFill(nvgContext)
        nvgStrokeColor(nvgContext, nvgRGBAf(0.4, 0.4, 0.5, 1))
        nvgStrokeWidth(nvgContext, 1)
        nvgStroke(nvgContext)
    else
        nvgFillColor(nvgContext, nvgRGBAf(r, g, b, a))
        nvgFill(nvgContext)
    end

    -- Draw hover/interactive border for interactive elements
    if item.interactive and item == hoveredNode then
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x, y, w, h, cornerRadius)
        nvgStrokeColor(nvgContext, nvgRGBAf(1, 1, 1, 0.5))
        nvgStrokeWidth(nvgContext, 2)
        nvgStroke(nvgContext)
    end

    -- Draw label
    if item.label ~= nil then
        nvgFontFaceId(nvgContext, fontId)
        -- Dynamic font size based on element size, min 14, max 20
        local fontSize = math.max(14, math.min(20, math.min(w / 6, h / 2)))
        nvgFontSize(nvgContext, fontSize)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBf(1, 1, 1))
        nvgText(nvgContext, x + w / 2, y + h / 2, item.label, nil)
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
