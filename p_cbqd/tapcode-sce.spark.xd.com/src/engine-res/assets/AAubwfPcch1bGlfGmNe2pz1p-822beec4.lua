-- Windows 11 Desktop Simulator
-- Built with Yoga Layout + NanoVG rendering
-- Demonstrates Windows 11 Fluent Design with:
--   - Rounded corners (8px radius)
--   - Centered taskbar with floating icons
--   - Mica/Acrylic material effects
--   - Floating Start Menu
--   - Modern window chrome
--   - Snap layouts support

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- Global State
-- ============================================================================
local nvgContext = nil
local fontId = -1
local fontBoldId = -1
local rootNode = nil
local layoutNodes = {}

-- Desktop state
local screenWidth = 1280
local screenHeight = 720
local isStartMenuOpen = false
local hoveredNode = nil
local pressedNode = nil
local activeWindow = nil
local windows = {}
local nextWindowId = 1

-- Dragging state
local draggingWindow = nil
local dragOffsetX = 0
local dragOffsetY = 0

-- Resizing state
local resizingWindow = nil
local resizeEdge = nil  -- "n", "s", "e", "w", "ne", "nw", "se", "sw"
local resizeStartX = 0
local resizeStartY = 0
local resizeStartWinX = 0
local resizeStartWinY = 0
local resizeStartWidth = 0
local resizeStartHeight = 0
local RESIZE_BORDER = 6  -- Border width for resize detection
local MIN_WINDOW_WIDTH = 200
local MIN_WINDOW_HEIGHT = 150

-- Animation state
local startMenuProgress = 0
local animationTime = 0

-- Calculator state
local calcDisplay = "0"
local calcOperator = nil
local calcPrevValue = nil
local calcNewInput = true

-- ============================================================================
-- Windows 11 Color Palette
-- ============================================================================
local Colors = {
    -- Background
    DesktopGradientTop = { r = 0.00, g = 0.35, b = 0.60, a = 1.0 },
    DesktopGradientBottom = { r = 0.00, g = 0.15, b = 0.35, a = 1.0 },

    -- Taskbar (Mica effect)
    TaskbarBg = { r = 0.08, g = 0.08, b = 0.10, a = 0.85 },
    TaskbarHover = { r = 1.0, g = 1.0, b = 1.0, a = 0.08 },
    TaskbarActive = { r = 1.0, g = 1.0, b = 1.0, a = 0.12 },

    -- Start Menu (Mica)
    StartMenuBg = { r = 0.12, g = 0.12, b = 0.14, a = 0.95 },
    StartMenuCard = { r = 0.18, g = 0.18, b = 0.20, a = 1.0 },

    -- Windows (Mica)
    WindowBg = { r = 0.98, g = 0.98, b = 0.98, a = 1.0 },
    WindowTitleBar = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
    WindowTitleBarInactive = { r = 0.90, g = 0.90, b = 0.90, a = 1.0 },
    WindowBorder = { r = 0.85, g = 0.85, b = 0.85, a = 1.0 },

    -- Buttons
    CloseHover = { r = 0.90, g = 0.18, b = 0.18, a = 1.0 },
    ButtonHover = { r = 0.92, g = 0.92, b = 0.92, a = 1.0 },

    -- Accent (Windows 11 Blue)
    Accent = { r = 0.00, g = 0.47, b = 0.84, a = 1.0 },
    AccentLight = { r = 0.38, g = 0.68, b = 0.95, a = 1.0 },
    AccentDark = { r = 0.00, g = 0.35, b = 0.65, a = 1.0 },

    -- Text
    TextLight = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    TextDark = { r = 0.10, g = 0.10, b = 0.10, a = 1.0 },
    TextGray = { r = 0.50, g = 0.50, b = 0.50, a = 1.0 },
    TextMuted = { r = 0.65, g = 0.65, b = 0.65, a = 1.0 },

    -- App Tiles
    TileBlue = { r = 0.00, g = 0.47, b = 0.84, a = 1.0 },
    TileGreen = { r = 0.10, g = 0.59, b = 0.32, a = 1.0 },
    TileOrange = { r = 0.95, g = 0.55, b = 0.15, a = 1.0 },
    TilePurple = { r = 0.55, g = 0.23, b = 0.67, a = 1.0 },
    TileCyan = { r = 0.00, g = 0.74, b = 0.83, a = 1.0 },
    TileYellow = { r = 0.95, g = 0.77, b = 0.06, a = 1.0 },
    TileRed = { r = 0.85, g = 0.25, b = 0.25, a = 1.0 },
    TileGray = { r = 0.45, g = 0.45, b = 0.45, a = 1.0 },
}

-- ============================================================================
-- Constants
-- ============================================================================
local TASKBAR_HEIGHT = 48
local TASKBAR_ICON_SIZE = 40
local TASKBAR_RADIUS = 0  -- Taskbar is not rounded in Win11 (full width)
local WINDOW_RADIUS = 8
local WINDOW_TITLE_HEIGHT = 32
local START_MENU_WIDTH = 560
local START_MENU_HEIGHT = 600
local START_MENU_RADIUS = 8
local DESKTOP_ICON_SIZE = 74
local BUTTON_RADIUS = 4
local TILE_RADIUS = 6

-- ============================================================================
-- Main Entry
-- ============================================================================
function Start()
    SampleStart()

    local graphics = GetGraphics()
    screenWidth = graphics:GetWidth()
    screenHeight = graphics:GetHeight()

    -- Create NanoVG context
    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- Load fonts
    fontId = nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf")
    fontBoldId = nvgCreateFont(nvgContext, "sans-bold", "Fonts/MiSans-Medium.ttf")
    if fontBoldId < 0 then
        fontBoldId = fontId
    end

    -- Setup desktop
    SetupDesktop()

    CreateInstructions()
    SampleInitMouseMode(MM_FREE)

    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("ScreenMode", "HandleScreenModeChanged")
end

function Stop()
    CleanupLayout()
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
    windows = {}
    hoveredNode = nil
    pressedNode = nil
    activeWindow = nil
end

function CreateInstructions()
    local instructionText = Text:new()
    instructionText.text = "Windows 11 Simulator | Click Start or desktop icons | ESC to exit"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 14)
    instructionText.color = Color(1.0, 1.0, 1.0)
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_TOP
    instructionText:SetPosition(0, 8)
    ui.root:AddChild(instructionText)
end

-- ============================================================================
-- Desktop Setup
-- ============================================================================
function SetupDesktop()
    CleanupLayout()

    rootNode = YGNodeNew()
    YGNodeStyleSetWidth(rootNode, screenWidth)
    YGNodeStyleSetHeight(rootNode, screenHeight)
    YGNodeStyleSetFlexDirection(rootNode, YGFlexDirectionColumn)

    -- Desktop area (takes remaining space)
    local desktopArea = YGNodeNew()
    YGNodeStyleSetFlexGrow(desktopArea, 1)
    YGNodeStyleSetFlexDirection(desktopArea, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(desktopArea, YGEdgeAll, 16)
    YGNodeInsertChild(rootNode, desktopArea, 0)
    table.insert(layoutNodes, {
        node = desktopArea,
        type = "desktop",
        interactive = false
    })

    -- Desktop icons (column layout on left side)
    local iconColumn = YGNodeNew()
    YGNodeStyleSetFlexDirection(iconColumn, YGFlexDirectionColumn)
    YGNodeStyleSetGap(iconColumn, YGGutterRow, 8)
    YGNodeInsertChild(desktopArea, iconColumn, 0)

    local icons = {
        { name = "This PC", icon = "folder", color = Colors.TileOrange, action = "files" },
        { name = "Recycle Bin", icon = "recycle", color = Colors.TileGray, action = nil },
        { name = "Notepad", icon = "notepad", color = Colors.TileBlue, action = "notepad" },
        { name = "Calculator", icon = "calc", color = Colors.TileGreen, action = "calculator" },
        { name = "Edge", icon = "browser", color = Colors.TileCyan, action = "browser" },
    }

    for i, iconData in ipairs(icons) do
        local icon = YGNodeNew()
        YGNodeStyleSetWidth(icon, DESKTOP_ICON_SIZE)
        YGNodeStyleSetHeight(icon, DESKTOP_ICON_SIZE + 24)
        YGNodeInsertChild(iconColumn, icon, i - 1)
        table.insert(layoutNodes, {
            node = icon,
            type = "desktop-icon",
            color = iconData.color,
            iconType = iconData.icon,
            label = iconData.name,
            action = iconData.action,
            interactive = true,
            onClick = function(self)
                if self.action then
                    LaunchApp(self.action)
                end
            end
        })
    end

    -- Taskbar (fixed at bottom)
    local taskbar = YGNodeNew()
    YGNodeStyleSetWidth(taskbar, screenWidth)
    YGNodeStyleSetHeight(taskbar, TASKBAR_HEIGHT)
    YGNodeStyleSetFlexDirection(taskbar, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(taskbar, YGJustifyCenter)
    YGNodeStyleSetAlignItems(taskbar, YGAlignCenter)
    YGNodeStyleSetPadding(taskbar, YGEdgeHorizontal, 12)
    YGNodeInsertChild(rootNode, taskbar, 1)
    table.insert(layoutNodes, {
        node = taskbar,
        type = "taskbar",
        color = Colors.TaskbarBg,
        interactive = false
    })

    -- Taskbar center section (icons)
    local taskbarCenter = YGNodeNew()
    YGNodeStyleSetFlexDirection(taskbarCenter, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(taskbarCenter, YGAlignCenter)
    YGNodeStyleSetGap(taskbarCenter, YGGutterColumn, 4)
    YGNodeInsertChild(taskbar, taskbarCenter, 0)

    -- Start button
    local startBtn = YGNodeNew()
    YGNodeStyleSetWidth(startBtn, TASKBAR_ICON_SIZE)
    YGNodeStyleSetHeight(startBtn, TASKBAR_ICON_SIZE)
    YGNodeInsertChild(taskbarCenter, startBtn, 0)
    table.insert(layoutNodes, {
        node = startBtn,
        type = "taskbar-icon",
        iconType = "windows",
        color = Colors.Accent,
        interactive = true,
        isStartButton = true,
        onClick = function(self)
            ToggleStartMenu()
        end
    })

    -- Search button
    local searchBtn = YGNodeNew()
    YGNodeStyleSetWidth(searchBtn, TASKBAR_ICON_SIZE)
    YGNodeStyleSetHeight(searchBtn, TASKBAR_ICON_SIZE)
    YGNodeInsertChild(taskbarCenter, searchBtn, 1)
    table.insert(layoutNodes, {
        node = searchBtn,
        type = "taskbar-icon",
        iconType = "search",
        color = Colors.TileGray,
        interactive = true,
        onClick = function(self) end
    })

    -- Pinned apps
    local pinnedApps = {
        { icon = "browser", color = Colors.TileCyan, action = "browser" },
        { icon = "folder", color = Colors.TileOrange, action = "files" },
        { icon = "notepad", color = Colors.TileBlue, action = "notepad" },
        { icon = "calc", color = Colors.TileGreen, action = "calculator" },
    }

    for i, app in ipairs(pinnedApps) do
        local appBtn = YGNodeNew()
        YGNodeStyleSetWidth(appBtn, TASKBAR_ICON_SIZE)
        YGNodeStyleSetHeight(appBtn, TASKBAR_ICON_SIZE)
        YGNodeInsertChild(taskbarCenter, appBtn, i + 1)
        table.insert(layoutNodes, {
            node = appBtn,
            type = "taskbar-icon",
            iconType = app.icon,
            color = app.color,
            action = app.action,
            interactive = true,
            onClick = function(self)
                if self.action then
                    LaunchApp(self.action)
                end
            end
        })
    end

    -- System tray (right side of taskbar)
    local systray = YGNodeNew()
    YGNodeStyleSetPositionType(systray, YGPositionTypeAbsolute)
    YGNodeStyleSetPosition(systray, YGEdgeRight, 12)
    YGNodeStyleSetPosition(systray, YGEdgeTop, 0)
    YGNodeStyleSetHeight(systray, TASKBAR_HEIGHT)
    YGNodeStyleSetWidth(systray, 140)
    YGNodeStyleSetFlexDirection(systray, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(systray, YGJustifyFlexEnd)
    YGNodeStyleSetAlignItems(systray, YGAlignCenter)
    YGNodeStyleSetGap(systray, YGGutterColumn, 4)
    YGNodeInsertChild(taskbar, systray, 1)
    table.insert(layoutNodes, {
        node = systray,
        type = "systray",
        interactive = false
    })

    -- Clock
    local clock = YGNodeNew()
    YGNodeStyleSetWidth(clock, 70)
    YGNodeStyleSetHeight(clock, 36)
    YGNodeInsertChild(systray, clock, 0)
    table.insert(layoutNodes, {
        node = clock,
        type = "clock",
        interactive = true,
        onClick = function(self) end
    })

    -- Calculate initial layout
    YGNodeCalculateLayout(rootNode, screenWidth, screenHeight, YGDirectionLTR)
end

-- ============================================================================
-- Start Menu
-- ============================================================================
function ToggleStartMenu()
    isStartMenuOpen = not isStartMenuOpen
end

function CreateStartMenuLayout()
    local nodes = {}

    -- Start menu container
    local startMenu = YGNodeNew()
    local menuX = (screenWidth - START_MENU_WIDTH) / 2
    local menuY = screenHeight - TASKBAR_HEIGHT - START_MENU_HEIGHT - 12

    YGNodeStyleSetPositionType(startMenu, YGPositionTypeAbsolute)
    YGNodeStyleSetPosition(startMenu, YGEdgeLeft, menuX)
    YGNodeStyleSetPosition(startMenu, YGEdgeTop, menuY)
    YGNodeStyleSetWidth(startMenu, START_MENU_WIDTH)
    YGNodeStyleSetHeight(startMenu, START_MENU_HEIGHT)
    YGNodeStyleSetFlexDirection(startMenu, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(startMenu, YGEdgeAll, 24)

    table.insert(nodes, {
        node = startMenu,
        type = "start-menu",
        color = Colors.StartMenuBg,
        interactive = false
    })

    -- Search bar
    local searchBar = YGNodeNew()
    YGNodeStyleSetWidthPercent(searchBar, 100)
    YGNodeStyleSetHeight(searchBar, 40)
    YGNodeStyleSetMargin(searchBar, YGEdgeBottom, 20)
    YGNodeInsertChild(startMenu, searchBar, 0)
    table.insert(nodes, {
        node = searchBar,
        type = "search-bar",
        color = { r = 0.22, g = 0.22, b = 0.24, a = 1.0 },
        label = "Type here to search",
        interactive = false
    })

    -- Pinned section title
    local pinnedTitle = YGNodeNew()
    YGNodeStyleSetWidthPercent(pinnedTitle, 100)
    YGNodeStyleSetHeight(pinnedTitle, 28)
    YGNodeStyleSetMargin(pinnedTitle, YGEdgeBottom, 12)
    YGNodeInsertChild(startMenu, pinnedTitle, 1)
    table.insert(nodes, {
        node = pinnedTitle,
        type = "section-title",
        label = "Pinned",
        interactive = false
    })

    -- Pinned apps grid
    local pinnedGrid = YGNodeNew()
    YGNodeStyleSetWidthPercent(pinnedGrid, 100)
    YGNodeStyleSetFlexGrow(pinnedGrid, 1)
    YGNodeStyleSetFlexDirection(pinnedGrid, YGFlexDirectionRow)
    YGNodeStyleSetFlexWrap(pinnedGrid, YGWrapWrap)
    YGNodeStyleSetAlignContent(pinnedGrid, YGAlignFlexStart)
    YGNodeStyleSetGap(pinnedGrid, YGGutterAll, 8)
    YGNodeInsertChild(startMenu, pinnedGrid, 2)

    local pinnedApps = {
        { name = "Edge", icon = "browser", color = Colors.TileCyan, action = "browser" },
        { name = "File Explorer", icon = "folder", color = Colors.TileOrange, action = "files" },
        { name = "Notepad", icon = "notepad", color = Colors.TileBlue, action = "notepad" },
        { name = "Calculator", icon = "calc", color = Colors.TileGreen, action = "calculator" },
        { name = "Settings", icon = "settings", color = Colors.TileGray, action = "settings" },
        { name = "About", icon = "info", color = Colors.TilePurple, action = "about" },
    }

    local tileWidth = 90
    local tileHeight = 80

    for i, app in ipairs(pinnedApps) do
        local tile = YGNodeNew()
        YGNodeStyleSetWidth(tile, tileWidth)
        YGNodeStyleSetHeight(tile, tileHeight)
        YGNodeInsertChild(pinnedGrid, tile, i - 1)
        table.insert(nodes, {
            node = tile,
            type = "app-tile",
            color = Colors.StartMenuCard,
            iconColor = app.color,
            iconType = app.icon,
            label = app.name,
            action = app.action,
            interactive = true,
            onClick = function(self)
                isStartMenuOpen = false
                if self.action then
                    LaunchApp(self.action)
                end
            end
        })
    end

    -- User section at bottom
    local userSection = YGNodeNew()
    YGNodeStyleSetWidthPercent(userSection, 100)
    YGNodeStyleSetHeight(userSection, 50)
    YGNodeStyleSetFlexDirection(userSection, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(userSection, YGAlignCenter)
    YGNodeStyleSetMargin(userSection, YGEdgeTop, 20)
    YGNodeStyleSetPadding(userSection, YGEdgeHorizontal, 8)
    YGNodeInsertChild(startMenu, userSection, 3)
    table.insert(nodes, {
        node = userSection,
        type = "user-section",
        interactive = false
    })

    -- User avatar
    local avatar = YGNodeNew()
    YGNodeStyleSetWidth(avatar, 32)
    YGNodeStyleSetHeight(avatar, 32)
    YGNodeInsertChild(userSection, avatar, 0)
    table.insert(nodes, {
        node = avatar,
        type = "avatar",
        color = Colors.Accent,
        interactive = true,
        onClick = function(self) end
    })

    -- User name
    local userName = YGNodeNew()
    YGNodeStyleSetFlexGrow(userName, 1)
    YGNodeStyleSetHeight(userName, 32)
    YGNodeStyleSetMargin(userName, YGEdgeLeft, 12)
    YGNodeInsertChild(userSection, userName, 1)
    table.insert(nodes, {
        node = userName,
        type = "user-name",
        label = "User",
        interactive = false
    })

    -- Power button
    local powerBtn = YGNodeNew()
    YGNodeStyleSetWidth(powerBtn, 32)
    YGNodeStyleSetHeight(powerBtn, 32)
    YGNodeInsertChild(userSection, powerBtn, 2)
    table.insert(nodes, {
        node = powerBtn,
        type = "power-button",
        interactive = true,
        onClick = function(self)
            engine:Exit()
        end
    })

    -- Calculate layout
    YGNodeCalculateLayout(startMenu, START_MENU_WIDTH, START_MENU_HEIGHT, YGDirectionLTR)

    return nodes, startMenu
end

-- ============================================================================
-- Window Management
-- ============================================================================
function CreateWindow(title, x, y, width, height, options)
    local win = {
        id = nextWindowId,
        title = title,
        x = x,
        y = y,
        width = width,
        height = height,
        savedX = x,
        savedY = y,
        savedWidth = width,
        savedHeight = height,
        isMaximized = false,
        isMinimized = false,
        color = options.color or Colors.Accent,
        contentNodes = {},
        rootNode = nil,
    }
    nextWindowId = nextWindowId + 1

    -- Create window layout
    win.rootNode = YGNodeNew()
    YGNodeStyleSetPositionType(win.rootNode, YGPositionTypeAbsolute)
    YGNodeStyleSetPosition(win.rootNode, YGEdgeLeft, x)
    YGNodeStyleSetPosition(win.rootNode, YGEdgeTop, y)
    YGNodeStyleSetWidth(win.rootNode, width)
    YGNodeStyleSetHeight(win.rootNode, height)
    YGNodeStyleSetFlexDirection(win.rootNode, YGFlexDirectionColumn)

    table.insert(win.contentNodes, {
        node = win.rootNode,
        type = "window",
        window = win,
        color = Colors.WindowBg,
        interactive = false
    })

    -- Title bar
    local titleBar = YGNodeNew()
    YGNodeStyleSetWidthPercent(titleBar, 100)
    YGNodeStyleSetHeight(titleBar, WINDOW_TITLE_HEIGHT)
    YGNodeStyleSetFlexDirection(titleBar, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(titleBar, YGAlignCenter)
    YGNodeStyleSetPadding(titleBar, YGEdgeHorizontal, 12)
    YGNodeInsertChild(win.rootNode, titleBar, 0)
    table.insert(win.contentNodes, {
        node = titleBar,
        type = "window-titlebar",
        window = win,
        color = Colors.WindowTitleBar,
        interactive = true,
        isDraggable = true,
        onClick = function(self)
            ActivateWindow(self.window)
        end
    })

    -- Window icon
    local winIcon = YGNodeNew()
    YGNodeStyleSetWidth(winIcon, 16)
    YGNodeStyleSetHeight(winIcon, 16)
    YGNodeInsertChild(titleBar, winIcon, 0)
    table.insert(win.contentNodes, {
        node = winIcon,
        type = "window-icon",
        color = win.color,
        interactive = false
    })

    -- Title text area (flexible)
    local titleArea = YGNodeNew()
    YGNodeStyleSetFlexGrow(titleArea, 1)
    YGNodeStyleSetHeight(titleArea, WINDOW_TITLE_HEIGHT)
    YGNodeStyleSetMargin(titleArea, YGEdgeLeft, 8)
    YGNodeInsertChild(titleBar, titleArea, 1)
    table.insert(win.contentNodes, {
        node = titleArea,
        type = "window-title-text",
        label = title,
        interactive = false
    })

    -- Window buttons
    local btnWidth = 46
    local btnHeight = WINDOW_TITLE_HEIGHT

    -- Minimize button
    local minBtn = YGNodeNew()
    YGNodeStyleSetWidth(minBtn, btnWidth)
    YGNodeStyleSetHeight(minBtn, btnHeight)
    YGNodeInsertChild(titleBar, minBtn, 2)
    table.insert(win.contentNodes, {
        node = minBtn,
        type = "window-button",
        buttonType = "minimize",
        window = win,
        interactive = true,
        onClick = function(self)
            self.window.isMinimized = true
        end
    })

    -- Maximize button
    local maxBtn = YGNodeNew()
    YGNodeStyleSetWidth(maxBtn, btnWidth)
    YGNodeStyleSetHeight(maxBtn, btnHeight)
    YGNodeInsertChild(titleBar, maxBtn, 3)
    table.insert(win.contentNodes, {
        node = maxBtn,
        type = "window-button",
        buttonType = "maximize",
        window = win,
        interactive = true,
        onClick = function(self)
            ToggleMaximize(self.window)
        end
    })

    -- Close button
    local closeBtn = YGNodeNew()
    YGNodeStyleSetWidth(closeBtn, btnWidth)
    YGNodeStyleSetHeight(closeBtn, btnHeight)
    YGNodeInsertChild(titleBar, closeBtn, 4)
    table.insert(win.contentNodes, {
        node = closeBtn,
        type = "window-button",
        buttonType = "close",
        window = win,
        interactive = true,
        onClick = function(self)
            CloseWindow(self.window)
        end
    })

    -- Content area
    local contentArea = YGNodeNew()
    YGNodeStyleSetFlexGrow(contentArea, 1)
    YGNodeStyleSetFlexDirection(contentArea, YGFlexDirectionColumn)
    YGNodeInsertChild(win.rootNode, contentArea, 1)
    win.contentArea = contentArea

    table.insert(windows, win)
    ActivateWindow(win)

    return win
end

function ActivateWindow(win)
    if activeWindow == win then return end
    activeWindow = win

    -- Move to front
    for i, w in ipairs(windows) do
        if w == win then
            table.remove(windows, i)
            table.insert(windows, win)
            break
        end
    end
end

function CloseWindow(win)
    for i, w in ipairs(windows) do
        if w == win then
            if win.rootNode then
                YGNodeFreeRecursive(win.rootNode)
            end
            table.remove(windows, i)
            break
        end
    end

    if activeWindow == win then
        activeWindow = #windows > 0 and windows[#windows] or nil
    end
end

function ToggleMaximize(win)
    if win.isMaximized then
        win.x = win.savedX
        win.y = win.savedY
        win.width = win.savedWidth
        win.height = win.savedHeight
        win.isMaximized = false
    else
        win.savedX = win.x
        win.savedY = win.y
        win.savedWidth = win.width
        win.savedHeight = win.height
        win.x = 0
        win.y = 0
        win.width = screenWidth
        win.height = screenHeight - TASKBAR_HEIGHT
        win.isMaximized = true
    end

    UpdateWindowLayout(win)
end

function UpdateWindowLayout(win)
    YGNodeStyleSetPosition(win.rootNode, YGEdgeLeft, win.x)
    YGNodeStyleSetPosition(win.rootNode, YGEdgeTop, win.y)
    YGNodeStyleSetWidth(win.rootNode, win.width)
    YGNodeStyleSetHeight(win.rootNode, win.height)
    YGNodeCalculateLayout(win.rootNode, win.width, win.height, YGDirectionLTR)
end

-- ============================================================================
-- Application Launchers
-- ============================================================================
function LaunchApp(appName)
    if appName == "notepad" then
        LaunchNotepad()
    elseif appName == "calculator" then
        LaunchCalculator()
    elseif appName == "files" then
        LaunchFileExplorer()
    elseif appName == "browser" then
        LaunchBrowser()
    elseif appName == "settings" then
        LaunchSettings()
    elseif appName == "about" then
        LaunchAbout()
    end
end

function LaunchNotepad()
    local win = CreateWindow("Notepad", 150, 60, 640, 480, { color = Colors.TileBlue })
    win.appType = "notepad"

    -- Menu bar
    local menuBar = YGNodeNew()
    YGNodeStyleSetWidthPercent(menuBar, 100)
    YGNodeStyleSetHeight(menuBar, 28)
    YGNodeStyleSetFlexDirection(menuBar, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(menuBar, YGAlignCenter)
    YGNodeStyleSetPadding(menuBar, YGEdgeHorizontal, 8)
    YGNodeInsertChild(win.contentArea, menuBar, 0)
    table.insert(win.contentNodes, {
        node = menuBar,
        type = "menu-bar",
        color = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
        interactive = false
    })

    local menus = {"File", "Edit", "Format", "View", "Help"}
    for i, menu in ipairs(menus) do
        local menuItem = YGNodeNew()
        YGNodeStyleSetWidth(menuItem, 48)
        YGNodeStyleSetHeight(menuItem, 24)
        YGNodeInsertChild(menuBar, menuItem, i - 1)
        table.insert(win.contentNodes, {
            node = menuItem,
            type = "menu-item",
            label = menu,
            interactive = true,
            onClick = function(self) end
        })
    end

    -- Text area
    local textArea = YGNodeNew()
    YGNodeStyleSetFlexGrow(textArea, 1)
    YGNodeStyleSetPadding(textArea, YGEdgeAll, 12)
    YGNodeInsertChild(win.contentArea, textArea, 1)
    table.insert(win.contentNodes, {
        node = textArea,
        type = "text-area",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        label = "Welcome to Windows 11 Notepad!\n\nThis is a simulation built with:\n  - Yoga Layout (Facebook's flexbox implementation)\n  - NanoVG (vector graphics library)\n  - UrhoX Game Engine\n\nFeatures demonstrated:\n  - Fluent Design System\n  - Rounded corners (8px radius)\n  - Mica/Acrylic materials\n  - Modern window chrome\n  - Centered taskbar",
        interactive = false
    })

    -- Status bar
    local statusBar = YGNodeNew()
    YGNodeStyleSetWidthPercent(statusBar, 100)
    YGNodeStyleSetHeight(statusBar, 24)
    YGNodeStyleSetFlexDirection(statusBar, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(statusBar, YGAlignCenter)
    YGNodeStyleSetPadding(statusBar, YGEdgeHorizontal, 12)
    YGNodeInsertChild(win.contentArea, statusBar, 2)
    table.insert(win.contentNodes, {
        node = statusBar,
        type = "status-bar",
        color = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
        label = "Ln 1, Col 1   |   UTF-8   |   Windows (CRLF)",
        interactive = false
    })

    UpdateWindowLayout(win)
end

function LaunchCalculator()
    local win = CreateWindow("Calculator", 300, 100, 320, 500, { color = Colors.TileGreen })
    win.appType = "calculator"

    -- Display
    local display = YGNodeNew()
    YGNodeStyleSetWidthPercent(display, 100)
    YGNodeStyleSetHeight(display, 100)
    YGNodeStyleSetPadding(display, YGEdgeAll, 16)
    YGNodeInsertChild(win.contentArea, display, 0)

    -- Reset calculator state
    calcDisplay = "0"
    calcOperator = nil
    calcPrevValue = nil
    calcNewInput = true

    table.insert(win.contentNodes, {
        node = display,
        type = "calc-display",
        color = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
        getLabel = function() return calcDisplay end,
        interactive = false
    })

    -- Button grid
    local btnGrid = YGNodeNew()
    YGNodeStyleSetFlexGrow(btnGrid, 1)
    YGNodeStyleSetFlexDirection(btnGrid, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(btnGrid, YGEdgeAll, 6)
    YGNodeStyleSetGap(btnGrid, YGGutterRow, 4)
    YGNodeInsertChild(win.contentArea, btnGrid, 1)

    local buttons = {
        {"%", "CE", "C", "<-"},
        {"1/x", "x2", "sqrt", "/"},
        {"7", "8", "9", "*"},
        {"4", "5", "6", "-"},
        {"1", "2", "3", "+"},
        {"+/-", "0", ".", "="},
    }

    for row, rowBtns in ipairs(buttons) do
        local rowNode = YGNodeNew()
        YGNodeStyleSetFlexGrow(rowNode, 1)
        YGNodeStyleSetFlexDirection(rowNode, YGFlexDirectionRow)
        YGNodeStyleSetGap(rowNode, YGGutterColumn, 4)
        YGNodeInsertChild(btnGrid, rowNode, row - 1)

        for col, btnText in ipairs(rowBtns) do
            local btn = YGNodeNew()
            YGNodeStyleSetFlexGrow(btn, 1)
            YGNodeInsertChild(rowNode, btn, col - 1)

            local isNumber = (btnText >= "0" and btnText <= "9") or btnText == "." or btnText == "+/-"
            local isEquals = btnText == "="

            local btnColor
            if isEquals then
                btnColor = Colors.Accent
            elseif isNumber then
                btnColor = { r = 0.98, g = 0.98, b = 0.98, a = 1.0 }
            else
                btnColor = { r = 0.94, g = 0.94, b = 0.94, a = 1.0 }
            end

            local displayText = btnText
            if btnText == "*" then displayText = "x"
            elseif btnText == "<-" then displayText = "<"
            end

            table.insert(win.contentNodes, {
                node = btn,
                type = "calc-button",
                color = btnColor,
                label = displayText,
                calcBtn = btnText,
                isEquals = isEquals,
                interactive = true,
                onClick = function(self)
                    HandleCalculatorButton(self.calcBtn)
                end
            })
        end
    end

    UpdateWindowLayout(win)
end

function HandleCalculatorButton(btn)
    if btn >= "0" and btn <= "9" then
        if calcNewInput then
            calcDisplay = btn
            calcNewInput = false
        else
            if calcDisplay == "0" then
                calcDisplay = btn
            else
                calcDisplay = calcDisplay .. btn
            end
        end
    elseif btn == "." then
        if calcNewInput then
            calcDisplay = "0."
            calcNewInput = false
        elseif not string.find(calcDisplay, "%.") then
            calcDisplay = calcDisplay .. "."
        end
    elseif btn == "C" or btn == "CE" then
        calcDisplay = "0"
        calcOperator = nil
        calcPrevValue = nil
        calcNewInput = true
    elseif btn == "<-" then
        if #calcDisplay > 1 then
            calcDisplay = string.sub(calcDisplay, 1, -2)
        else
            calcDisplay = "0"
        end
    elseif btn == "+/-" then
        local num = tonumber(calcDisplay)
        if num then
            calcDisplay = tostring(-num)
        end
    elseif btn == "%" then
        local num = tonumber(calcDisplay)
        if num then
            calcDisplay = tostring(num / 100)
        end
    elseif btn == "x2" then
        local num = tonumber(calcDisplay)
        if num then
            calcDisplay = tostring(num * num)
        end
    elseif btn == "sqrt" then
        local num = tonumber(calcDisplay)
        if num and num >= 0 then
            calcDisplay = tostring(math.sqrt(num))
        end
    elseif btn == "1/x" then
        local num = tonumber(calcDisplay)
        if num and num ~= 0 then
            calcDisplay = tostring(1 / num)
        end
    elseif btn == "/" or btn == "*" or btn == "-" or btn == "+" then
        if calcPrevValue and calcOperator and not calcNewInput then
            calcDisplay = CalculateResult()
        end
        calcPrevValue = calcDisplay
        calcOperator = btn
        calcNewInput = true
    elseif btn == "=" then
        if calcPrevValue and calcOperator then
            calcDisplay = CalculateResult()
            calcOperator = nil
            calcPrevValue = nil
            calcNewInput = true
        end
    end
end

function CalculateResult()
    local prev = tonumber(calcPrevValue)
    local curr = tonumber(calcDisplay)

    if not prev or not curr then return calcDisplay end

    local result = 0
    if calcOperator == "+" then
        result = prev + curr
    elseif calcOperator == "-" then
        result = prev - curr
    elseif calcOperator == "*" then
        result = prev * curr
    elseif calcOperator == "/" then
        if curr ~= 0 then
            result = prev / curr
        else
            return "Error"
        end
    end

    if result == math.floor(result) and math.abs(result) < 1e10 then
        return tostring(math.floor(result))
    else
        return string.format("%.10g", result)
    end
end

function LaunchFileExplorer()
    local win = CreateWindow("File Explorer", 100, 50, 800, 520, { color = Colors.TileOrange })
    win.appType = "files"

    -- Toolbar
    local toolbar = YGNodeNew()
    YGNodeStyleSetWidthPercent(toolbar, 100)
    YGNodeStyleSetHeight(toolbar, 44)
    YGNodeStyleSetFlexDirection(toolbar, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(toolbar, YGAlignCenter)
    YGNodeStyleSetPadding(toolbar, YGEdgeHorizontal, 12)
    YGNodeStyleSetGap(toolbar, YGGutterColumn, 8)
    YGNodeInsertChild(win.contentArea, toolbar, 0)
    table.insert(win.contentNodes, {
        node = toolbar,
        type = "toolbar",
        color = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
        interactive = false
    })

    -- Nav buttons
    local navBtns = {"<", ">", "^"}
    for i, symbol in ipairs(navBtns) do
        local btn = YGNodeNew()
        YGNodeStyleSetWidth(btn, 32)
        YGNodeStyleSetHeight(btn, 32)
        YGNodeInsertChild(toolbar, btn, i - 1)
        table.insert(win.contentNodes, {
            node = btn,
            type = "nav-button",
            label = symbol,
            color = { r = 0.90, g = 0.90, b = 0.90, a = 1.0 },
            interactive = true,
            onClick = function(self) end
        })
    end

    -- Address bar
    local addressBar = YGNodeNew()
    YGNodeStyleSetFlexGrow(addressBar, 1)
    YGNodeStyleSetHeight(addressBar, 32)
    YGNodeInsertChild(toolbar, addressBar, 3)
    table.insert(win.contentNodes, {
        node = addressBar,
        type = "address-bar",
        label = "> This PC > Local Disk (C:) > Users",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        interactive = false
    })

    -- Main area
    local mainArea = YGNodeNew()
    YGNodeStyleSetFlexGrow(mainArea, 1)
    YGNodeStyleSetFlexDirection(mainArea, YGFlexDirectionRow)
    YGNodeInsertChild(win.contentArea, mainArea, 1)

    -- Sidebar
    local sidebar = YGNodeNew()
    YGNodeStyleSetWidth(sidebar, 180)
    YGNodeStyleSetFlexDirection(sidebar, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(sidebar, YGEdgeAll, 8)
    YGNodeStyleSetGap(sidebar, YGGutterRow, 4)
    YGNodeInsertChild(mainArea, sidebar, 0)
    table.insert(win.contentNodes, {
        node = sidebar,
        type = "sidebar",
        color = { r = 0.97, g = 0.97, b = 0.97, a = 1.0 },
        interactive = false
    })

    local sideItems = {"Quick access", "Desktop", "Downloads", "Documents", "Pictures", "This PC"}
    for i, item in ipairs(sideItems) do
        local sideItem = YGNodeNew()
        YGNodeStyleSetWidthPercent(sideItem, 100)
        YGNodeStyleSetHeight(sideItem, 28)
        YGNodeInsertChild(sidebar, sideItem, i - 1)
        table.insert(win.contentNodes, {
            node = sideItem,
            type = "sidebar-item",
            label = item,
            interactive = true,
            onClick = function(self) end
        })
    end

    -- File list
    local fileList = YGNodeNew()
    YGNodeStyleSetFlexGrow(fileList, 1)
    YGNodeStyleSetFlexDirection(fileList, YGFlexDirectionColumn)
    YGNodeStyleSetPadding(fileList, YGEdgeAll, 8)
    YGNodeInsertChild(mainArea, fileList, 1)
    table.insert(win.contentNodes, {
        node = fileList,
        type = "file-list",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        interactive = false
    })

    local files = {
        { name = "Documents", type = "folder" },
        { name = "Pictures", type = "folder" },
        { name = "Downloads", type = "folder" },
        { name = "readme.txt", type = "file" },
        { name = "report.docx", type = "file" },
        { name = "photo.jpg", type = "file" },
    }

    for i, file in ipairs(files) do
        local fileItem = YGNodeNew()
        YGNodeStyleSetWidthPercent(fileItem, 100)
        YGNodeStyleSetHeight(fileItem, 28)
        YGNodeInsertChild(fileList, fileItem, i - 1)
        table.insert(win.contentNodes, {
            node = fileItem,
            type = "file-item",
            label = file.name,
            isFolder = file.type == "folder",
            interactive = true,
            onClick = function(self) end
        })
    end

    -- Status bar
    local statusBar = YGNodeNew()
    YGNodeStyleSetWidthPercent(statusBar, 100)
    YGNodeStyleSetHeight(statusBar, 24)
    YGNodeStyleSetPadding(statusBar, YGEdgeHorizontal, 12)
    YGNodeInsertChild(win.contentArea, statusBar, 2)
    table.insert(win.contentNodes, {
        node = statusBar,
        type = "status-bar",
        color = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
        label = "6 items",
        interactive = false
    })

    UpdateWindowLayout(win)
end

function LaunchBrowser()
    local win = CreateWindow("Microsoft Edge", 80, 30, 900, 600, { color = Colors.TileCyan })
    win.appType = "browser"

    -- Tab bar
    local tabBar = YGNodeNew()
    YGNodeStyleSetWidthPercent(tabBar, 100)
    YGNodeStyleSetHeight(tabBar, 38)
    YGNodeStyleSetFlexDirection(tabBar, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(tabBar, YGAlignCenter)
    YGNodeStyleSetPadding(tabBar, YGEdgeHorizontal, 8)
    YGNodeStyleSetGap(tabBar, YGGutterColumn, 4)
    YGNodeInsertChild(win.contentArea, tabBar, 0)
    table.insert(win.contentNodes, {
        node = tabBar,
        type = "tab-bar",
        color = { r = 0.94, g = 0.94, b = 0.94, a = 1.0 },
        interactive = false
    })

    -- Tab
    local tab = YGNodeNew()
    YGNodeStyleSetWidth(tab, 200)
    YGNodeStyleSetHeight(tab, 32)
    YGNodeInsertChild(tabBar, tab, 0)
    table.insert(win.contentNodes, {
        node = tab,
        type = "browser-tab",
        label = "Example Website",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        interactive = true,
        onClick = function(self) end
    })

    -- New tab button
    local newTabBtn = YGNodeNew()
    YGNodeStyleSetWidth(newTabBtn, 28)
    YGNodeStyleSetHeight(newTabBtn, 28)
    YGNodeInsertChild(tabBar, newTabBtn, 1)
    table.insert(win.contentNodes, {
        node = newTabBtn,
        type = "new-tab-button",
        label = "+",
        interactive = true,
        onClick = function(self) end
    })

    -- Address bar
    local navBar = YGNodeNew()
    YGNodeStyleSetWidthPercent(navBar, 100)
    YGNodeStyleSetHeight(navBar, 44)
    YGNodeStyleSetFlexDirection(navBar, YGFlexDirectionRow)
    YGNodeStyleSetAlignItems(navBar, YGAlignCenter)
    YGNodeStyleSetPadding(navBar, YGEdgeHorizontal, 8)
    YGNodeStyleSetGap(navBar, YGGutterColumn, 8)
    YGNodeInsertChild(win.contentArea, navBar, 1)
    table.insert(win.contentNodes, {
        node = navBar,
        type = "nav-bar",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        interactive = false
    })

    -- Nav buttons
    local navBtns = {"<", ">", "O"}
    for i, symbol in ipairs(navBtns) do
        local btn = YGNodeNew()
        YGNodeStyleSetWidth(btn, 32)
        YGNodeStyleSetHeight(btn, 32)
        YGNodeInsertChild(navBar, btn, i - 1)
        table.insert(win.contentNodes, {
            node = btn,
            type = "nav-button",
            label = symbol,
            interactive = true,
            onClick = function(self) end
        })
    end

    -- URL bar
    local urlBar = YGNodeNew()
    YGNodeStyleSetFlexGrow(urlBar, 1)
    YGNodeStyleSetHeight(urlBar, 32)
    YGNodeInsertChild(navBar, urlBar, 3)
    table.insert(win.contentNodes, {
        node = urlBar,
        type = "url-bar",
        label = "https://www.example.com",
        color = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
        interactive = false
    })

    -- Web content
    local webContent = YGNodeNew()
    YGNodeStyleSetFlexGrow(webContent, 1)
    YGNodeStyleSetFlexDirection(webContent, YGFlexDirectionColumn)
    YGNodeInsertChild(win.contentArea, webContent, 2)
    table.insert(win.contentNodes, {
        node = webContent,
        type = "web-content",
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        interactive = false
    })

    -- Page header
    local pageHeader = YGNodeNew()
    YGNodeStyleSetWidthPercent(pageHeader, 100)
    YGNodeStyleSetHeight(pageHeader, 80)
    YGNodeInsertChild(webContent, pageHeader, 0)
    table.insert(win.contentNodes, {
        node = pageHeader,
        type = "page-header",
        label = "Example Website",
        color = Colors.Accent,
        interactive = false
    })

    -- Page body
    local pageBody = YGNodeNew()
    YGNodeStyleSetFlexGrow(pageBody, 1)
    YGNodeStyleSetPadding(pageBody, YGEdgeAll, 24)
    YGNodeInsertChild(webContent, pageBody, 1)
    table.insert(win.contentNodes, {
        node = pageBody,
        type = "page-body",
        label = "Welcome to Example Website\n\nThis is a simulated web browser built with\nYoga Layout and NanoVG rendering.\n\nFeatures:\n  - Modern tab interface\n  - Navigation controls\n  - Address bar with HTTPS indicator\n  - Responsive content area",
        interactive = false
    })

    UpdateWindowLayout(win)
end

function LaunchSettings()
    local win = CreateWindow("Settings", 200, 80, 760, 520, { color = Colors.TileGray })
    win.appType = "settings"

    -- Header
    local header = YGNodeNew()
    YGNodeStyleSetWidthPercent(header, 100)
    YGNodeStyleSetHeight(header, 60)
    YGNodeStyleSetPadding(header, YGEdgeHorizontal, 24)
    YGNodeStyleSetAlignItems(header, YGAlignCenter)
    YGNodeInsertChild(win.contentArea, header, 0)
    table.insert(win.contentNodes, {
        node = header,
        type = "settings-header",
        label = "Settings",
        color = { r = 0.96, g = 0.96, b = 0.96, a = 1.0 },
        interactive = false
    })

    -- Settings grid
    local grid = YGNodeNew()
    YGNodeStyleSetFlexGrow(grid, 1)
    YGNodeStyleSetFlexDirection(grid, YGFlexDirectionRow)
    YGNodeStyleSetFlexWrap(grid, YGWrapWrap)
    YGNodeStyleSetPadding(grid, YGEdgeAll, 16)
    YGNodeStyleSetGap(grid, YGGutterAll, 12)
    YGNodeInsertChild(win.contentArea, grid, 1)

    local categories = {
        { name = "System", desc = "Display, sound, power", color = Colors.TileCyan },
        { name = "Bluetooth", desc = "Devices, printers", color = Colors.TileBlue },
        { name = "Network", desc = "Wi-Fi, VPN, proxy", color = Colors.TileGreen },
        { name = "Personalization", desc = "Background, colors", color = Colors.TilePurple },
        { name = "Apps", desc = "Default apps, features", color = Colors.TileOrange },
        { name = "Accounts", desc = "Your info, email", color = Colors.TileBlue },
        { name = "Time & Language", desc = "Date, region, speech", color = Colors.TileCyan },
        { name = "Privacy", desc = "Location, camera", color = Colors.TileRed },
    }

    local cardWidth = 350
    local cardHeight = 72

    for i, cat in ipairs(categories) do
        local card = YGNodeNew()
        YGNodeStyleSetWidth(card, cardWidth)
        YGNodeStyleSetHeight(card, cardHeight)
        YGNodeInsertChild(grid, card, i - 1)
        table.insert(win.contentNodes, {
            node = card,
            type = "settings-card",
            label = cat.name,
            sublabel = cat.desc,
            iconColor = cat.color,
            color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
            interactive = true,
            onClick = function(self) end
        })
    end

    UpdateWindowLayout(win)
end

function LaunchAbout()
    local win = CreateWindow("About Windows", 320, 150, 420, 360, { color = Colors.TilePurple })
    win.appType = "about"

    -- Header with Windows logo
    local header = YGNodeNew()
    YGNodeStyleSetWidthPercent(header, 100)
    YGNodeStyleSetHeight(header, 100)
    YGNodeStyleSetJustifyContent(header, YGJustifyCenter)
    YGNodeStyleSetAlignItems(header, YGAlignCenter)
    YGNodeInsertChild(win.contentArea, header, 0)
    table.insert(win.contentNodes, {
        node = header,
        type = "about-header",
        color = Colors.Accent,
        interactive = false
    })

    -- Content
    local content = YGNodeNew()
    YGNodeStyleSetFlexGrow(content, 1)
    YGNodeStyleSetPadding(content, YGEdgeAll, 24)
    YGNodeInsertChild(win.contentArea, content, 1)
    table.insert(win.contentNodes, {
        node = content,
        type = "about-content",
        label = "Windows 11 Simulator\n\nVersion 23H2 (OS Build 22631)\n\nBuilt with UrhoX Game Engine\n\nThis simulation demonstrates:\n  - Yoga Layout (flexbox)\n  - NanoVG rendering\n  - Windows 11 Fluent Design\n\n(c) 2024 UrhoX Project",
        interactive = false
    })

    -- OK button
    local btnRow = YGNodeNew()
    YGNodeStyleSetWidthPercent(btnRow, 100)
    YGNodeStyleSetHeight(btnRow, 50)
    YGNodeStyleSetFlexDirection(btnRow, YGFlexDirectionRow)
    YGNodeStyleSetJustifyContent(btnRow, YGJustifyFlexEnd)
    YGNodeStyleSetAlignItems(btnRow, YGAlignCenter)
    YGNodeStyleSetPadding(btnRow, YGEdgeHorizontal, 24)
    YGNodeInsertChild(win.contentArea, btnRow, 2)

    local okBtn = YGNodeNew()
    YGNodeStyleSetWidth(okBtn, 90)
    YGNodeStyleSetHeight(okBtn, 32)
    YGNodeInsertChild(btnRow, okBtn, 0)
    table.insert(win.contentNodes, {
        node = okBtn,
        type = "ok-button",
        label = "OK",
        color = Colors.Accent,
        window = win,
        interactive = true,
        onClick = function(self)
            CloseWindow(self.window)
        end
    })

    UpdateWindowLayout(win)
end

-- ============================================================================
-- Event Handlers
-- ============================================================================
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_ESCAPE then
        if isStartMenuOpen then
            isStartMenuOpen = false
        else
            engine:Exit()
        end
    end
end

function HandleScreenModeChanged(eventType, eventData)
    local graphics = GetGraphics()
    screenWidth = graphics:GetWidth()
    screenHeight = graphics:GetHeight()

    -- Save current windows state
    local savedWindows = {}
    for _, win in ipairs(windows) do
        table.insert(savedWindows, {
            title = win.title,
            x = win.x,
            y = win.y,
            width = win.width,
            height = win.height,
            color = win.color,
            appType = win.appType,
            isMinimized = win.isMinimized,
            isMaximized = win.isMaximized,
        })
    end

    -- Rebuild desktop layout
    SetupDesktop()

    -- Restore windows
    for _, saved in ipairs(savedWindows) do
        if saved.appType then
            LaunchApp(saved.appType)
            -- Restore position of the newly created window
            local newWin = windows[#windows]
            if newWin then
                newWin.x = saved.x
                newWin.y = saved.y
                newWin.isMinimized = saved.isMinimized
                newWin.isMaximized = saved.isMaximized
                if saved.isMaximized then
                    newWin.savedX = saved.x
                    newWin.savedY = saved.y
                    newWin.savedWidth = saved.width
                    newWin.savedHeight = saved.height
                    newWin.x = 0
                    newWin.y = 0
                    newWin.width = screenWidth
                    newWin.height = screenHeight - TASKBAR_HEIGHT
                end
                UpdateWindowLayout(newWin)
            end
        end
    end
end


function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    animationTime = animationTime + dt

    -- Animate start menu
    local targetProgress = isStartMenuOpen and 1 or 0
    startMenuProgress = startMenuProgress + (targetProgress - startMenuProgress) * math.min(1, dt * 12)
end

-- Detect which edge/corner of window the mouse is on for resizing
function GetResizeEdge(mouseX, mouseY, win)
    if win.isMaximized then return nil end
    
    local x, y, w, h = win.x, win.y, win.width, win.height
    local b = RESIZE_BORDER
    
    local onLeft = mouseX >= x - b and mouseX <= x + b
    local onRight = mouseX >= x + w - b and mouseX <= x + w + b
    local onTop = mouseY >= y - b and mouseY <= y + b
    local onBottom = mouseY >= y + h - b and mouseY <= y + h + b
    local inHorizontal = mouseX >= x - b and mouseX <= x + w + b
    local inVertical = mouseY >= y - b and mouseY <= y + h + b
    
    -- Corners first (they take priority)
    if onTop and onLeft then return "nw" end
    if onTop and onRight then return "ne" end
    if onBottom and onLeft then return "sw" end
    if onBottom and onRight then return "se" end
    
    -- Edges
    if onTop and inHorizontal then return "n" end
    if onBottom and inHorizontal then return "s" end
    if onLeft and inVertical then return "w" end
    if onRight and inVertical then return "e" end
    
    return nil
end

function GetAbsolutePosition(node, rootRef)
    local x = YGNodeLayoutGetLeft(node)
    local y = YGNodeLayoutGetTop(node)
    local parent = YGNodeGetParent(node)

    while parent ~= nil and parent ~= rootRef do
        x = x + YGNodeLayoutGetLeft(parent)
        y = y + YGNodeLayoutGetTop(parent)
        parent = YGNodeGetParent(parent)
    end

    return x, y
end

function HitTest(mouseX, mouseY, nodes, rootRef, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    for i = #nodes, 1, -1 do
        local item = nodes[i]
        if item.interactive then
            local x, y = GetAbsolutePosition(item.node, rootRef)
            x = x + offsetX
            y = y + offsetY
            local w = YGNodeLayoutGetWidth(item.node)
            local h = YGNodeLayoutGetHeight(item.node)

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

    -- Handle window resizing
    if resizingWindow then
        local dx = mouseX - resizeStartX
        local dy = mouseY - resizeStartY
        local newX, newY, newW, newH = resizeStartWinX, resizeStartWinY, resizeStartWidth, resizeStartHeight
        
        -- Calculate new dimensions based on edge being dragged
        if resizeEdge:find("e") then
            newW = math.max(MIN_WINDOW_WIDTH, resizeStartWidth + dx)
        end
        if resizeEdge:find("w") then
            local deltaW = math.min(dx, resizeStartWidth - MIN_WINDOW_WIDTH)
            newX = resizeStartWinX + deltaW
            newW = resizeStartWidth - deltaW
        end
        if resizeEdge:find("s") then
            newH = math.max(MIN_WINDOW_HEIGHT, resizeStartHeight + dy)
        end
        if resizeEdge:find("n") then
            local deltaH = math.min(dy, resizeStartHeight - MIN_WINDOW_HEIGHT)
            newY = resizeStartWinY + deltaH
            newH = resizeStartHeight - deltaH
        end
        
        resizingWindow.x = newX
        resizingWindow.y = newY
        resizingWindow.width = newW
        resizingWindow.height = newH
        UpdateWindowLayout(resizingWindow)
        return
    end

    -- Handle window dragging
    if draggingWindow then
        draggingWindow.x = mouseX - dragOffsetX
        draggingWindow.y = mouseY - dragOffsetY
        UpdateWindowLayout(draggingWindow)
        return
    end

    -- Hit test windows first (in reverse order - top to bottom)
    hoveredNode = nil
    for i = #windows, 1, -1 do
        local win = windows[i]
        if not win.isMinimized then
            local hit = HitTest(mouseX, mouseY, win.contentNodes, win.rootNode, win.x, win.y)
            if hit then
                hoveredNode = hit
                return
            end
        end
    end

    -- Hit test start menu
    if isStartMenuOpen and startMenuProgress > 0.5 then
        local startMenuNodes, startMenuRoot = CreateStartMenuLayout()
        local menuX = (screenWidth - START_MENU_WIDTH) / 2
        local menuY = screenHeight - TASKBAR_HEIGHT - START_MENU_HEIGHT - 12
        local hit = HitTest(mouseX, mouseY, startMenuNodes, startMenuRoot, menuX, menuY)
        if hit then
            hoveredNode = hit
            YGNodeFreeRecursive(startMenuRoot)
            return
        end
        YGNodeFreeRecursive(startMenuRoot)
    end

    -- Hit test desktop
    local hit = HitTest(mouseX, mouseY, layoutNodes, rootNode)
    if hit then
        hoveredNode = hit
    end
end

function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end

    local mouseX = eventData["X"]:GetInt()
    local mouseY = eventData["Y"]:GetInt()

    -- Check for window resize edges first (in reverse order)
    for i = #windows, 1, -1 do
        local win = windows[i]
        if not win.isMinimized and not win.isMaximized then
            local edge = GetResizeEdge(mouseX, mouseY, win)
            if edge then
                resizingWindow = win
                resizeEdge = edge
                resizeStartX = mouseX
                resizeStartY = mouseY
                resizeStartWinX = win.x
                resizeStartWinY = win.y
                resizeStartWidth = win.width
                resizeStartHeight = win.height
                ActivateWindow(win)
                return
            end
        end
    end

    -- Check windows content
    for i = #windows, 1, -1 do
        local win = windows[i]
        if not win.isMinimized then
            local hit = HitTest(mouseX, mouseY, win.contentNodes, win.rootNode, win.x, win.y)
            if hit then
                pressedNode = hit
                ActivateWindow(win)

                -- Check if dragging title bar
                if hit.isDraggable and not win.isMaximized then
                    draggingWindow = win
                    dragOffsetX = mouseX - win.x
                    dragOffsetY = mouseY - win.y
                end
                return
            end
        end
    end

    -- Check start menu
    if isStartMenuOpen and startMenuProgress > 0.5 then
        local startMenuNodes, startMenuRoot = CreateStartMenuLayout()
        local menuX = (screenWidth - START_MENU_WIDTH) / 2
        local menuY = screenHeight - TASKBAR_HEIGHT - START_MENU_HEIGHT - 12
        local hit = HitTest(mouseX, mouseY, startMenuNodes, startMenuRoot, menuX, menuY)
        if hit then
            pressedNode = hit
            YGNodeFreeRecursive(startMenuRoot)
            return
        end
        YGNodeFreeRecursive(startMenuRoot)

        -- Click outside start menu closes it
        if mouseX < menuX or mouseX > menuX + START_MENU_WIDTH or
           mouseY < menuY or mouseY > menuY + START_MENU_HEIGHT then
            isStartMenuOpen = false
        end
    end

    -- Check desktop
    local hit = HitTest(mouseX, mouseY, layoutNodes, rootNode)
    if hit then
        pressedNode = hit
    end
end

function HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end

    draggingWindow = nil
    resizingWindow = nil
    resizeEdge = nil

    if pressedNode and pressedNode.onClick then
        pressedNode.onClick(pressedNode)
    end
    pressedNode = nil
end

-- ============================================================================
-- Rendering
-- ============================================================================
function HandleRender(eventType, eventData)
    if nvgContext == nil then return end

    nvgBeginFrame(nvgContext, screenWidth, screenHeight, 1.0)

    -- Draw desktop background (gradient)
    DrawDesktopBackground()

    -- Draw desktop elements
    DrawLayoutNodes(layoutNodes, rootNode)

    -- Draw windows
    for i, win in ipairs(windows) do
        if not win.isMinimized then
            DrawWindow(win)
        end
    end

    -- Draw start menu
    if isStartMenuOpen or startMenuProgress > 0.01 then
        DrawStartMenu()
    end

    nvgEndFrame(nvgContext)
end

function DrawDesktopBackground()
    -- Draw gradient background
    local paint = nvgLinearGradient(nvgContext, 0, 0, 0, screenHeight,
        nvgRGBf(Colors.DesktopGradientTop.r, Colors.DesktopGradientTop.g, Colors.DesktopGradientTop.b),
        nvgRGBf(Colors.DesktopGradientBottom.r, Colors.DesktopGradientBottom.g, Colors.DesktopGradientBottom.b))
    nvgBeginPath(nvgContext)
    nvgRect(nvgContext, 0, 0, screenWidth, screenHeight)
    nvgFillPaint(nvgContext, paint)
    nvgFill(nvgContext)

    -- Subtle Windows logo watermark
    local logoSize = 60
    local logoGap = 6
    local logoX = screenWidth - 160
    local logoY = screenHeight - 200
    local logoAlpha = 0.04

    for i = 0, 1 do
        for j = 0, 1 do
            nvgBeginPath(nvgContext)
            nvgRect(nvgContext, logoX + j * (logoSize + logoGap), logoY + i * (logoSize + logoGap), logoSize, logoSize)
            nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, logoAlpha))
            nvgFill(nvgContext)
        end
    end
end

function DrawLayoutNodes(nodes, root)
    for _, item in ipairs(nodes) do
        local x, y = GetAbsolutePosition(item.node, root)
        local w = YGNodeLayoutGetWidth(item.node)
        local h = YGNodeLayoutGetHeight(item.node)

        if item.type == "taskbar" then
            DrawTaskbar(x, y, w, h, item)
        elseif item.type == "desktop-icon" then
            DrawDesktopIcon(x, y, w, h, item)
        elseif item.type == "taskbar-icon" then
            DrawTaskbarIcon(x, y, w, h, item)
        elseif item.type == "clock" then
            DrawClock(x, y, w, h, item)
        end
    end
end

function DrawTaskbar(x, y, w, h, item)
    -- Mica effect background
    nvgBeginPath(nvgContext)
    nvgRect(nvgContext, x, y, w, h)
    nvgFillColor(nvgContext, nvgRGBAf(item.color.r, item.color.g, item.color.b, item.color.a))
    nvgFill(nvgContext)

    -- Top border
    nvgBeginPath(nvgContext)
    nvgMoveTo(nvgContext, x, y)
    nvgLineTo(nvgContext, x + w, y)
    nvgStrokeColor(nvgContext, nvgRGBAf(1, 1, 1, 0.08))
    nvgStrokeWidth(nvgContext, 1)
    nvgStroke(nvgContext)
end

function DrawDesktopIcon(x, y, w, h, item)
    local isHovered = hoveredNode == item
    local isPressed = pressedNode == item

    -- Selection highlight
    if isHovered or isPressed then
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x, y, w, h, 4)
        nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, isPressed and 0.15 or 0.08))
        nvgFill(nvgContext)
    end

    -- Icon
    local iconSize = 48
    local iconX = x + (w - iconSize) / 2
    local iconY = y + 4
    DrawIcon(iconX, iconY, iconSize, item.iconType, item.color)

    -- Label with shadow
    if item.label then
        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 11)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

        -- Shadow
        nvgFillColor(nvgContext, nvgRGBAf(0, 0, 0, 0.5))
        nvgText(nvgContext, x + w/2 + 1, iconY + iconSize + 7, item.label, nil)

        -- Text
        nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
        nvgText(nvgContext, x + w/2, iconY + iconSize + 6, item.label, nil)
    end
end

function DrawTaskbarIcon(x, y, w, h, item)
    local isHovered = hoveredNode == item
    local isPressed = pressedNode == item

    -- Hover/press highlight
    if isHovered or isPressed then
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x + 2, y + 2, w - 4, h - 4, BUTTON_RADIUS)
        nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, isPressed and 0.15 or 0.08))
        nvgFill(nvgContext)
    end

    -- Icon
    local iconSize = 24
    local iconX = x + (w - iconSize) / 2
    local iconY = y + (h - iconSize) / 2
    DrawIcon(iconX, iconY, iconSize, item.iconType, item.color or Colors.TextLight)

    -- Active indicator
    if item.isActive then
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x + w/2 - 8, y + h - 4, 16, 3, 1.5)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.Accent.r, Colors.Accent.g, Colors.Accent.b, 1))
        nvgFill(nvgContext)
    end
end

function DrawClock(x, y, w, h, item)
    local timeStr = os.date("%H:%M")
    local dateStr = os.date("%Y/%m/%d")

    nvgFontFaceId(nvgContext, fontId)
    nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))

    nvgFontSize(nvgContext, 12)
    nvgText(nvgContext, x + w/2, y + h/2 - 7, timeStr, nil)

    nvgFontSize(nvgContext, 10)
    nvgText(nvgContext, x + w/2, y + h/2 + 7, dateStr, nil)
end

function DrawIcon(x, y, size, iconType, color)
    local c = color or Colors.TextLight

    if iconType == "windows" then
        -- Windows 11 logo (4 squares)
        local squareSize = size * 0.38
        local gap = size * 0.08
        local startX = x + (size - squareSize * 2 - gap) / 2
        local startY = y + (size - squareSize * 2 - gap) / 2

        for i = 0, 1 do
            for j = 0, 1 do
                nvgBeginPath(nvgContext)
                nvgRect(nvgContext, startX + j * (squareSize + gap), startY + i * (squareSize + gap), squareSize, squareSize)
                nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
                nvgFill(nvgContext)
            end
        end
    elseif iconType == "search" then
        -- Search icon (magnifying glass)
        local cx = x + size * 0.4
        local cy = y + size * 0.4
        local r = size * 0.25

        nvgBeginPath(nvgContext)
        nvgCircle(nvgContext, cx, cy, r)
        nvgStrokeColor(nvgContext, nvgRGBAf(1, 1, 1, 0.9))
        nvgStrokeWidth(nvgContext, 2)
        nvgStroke(nvgContext)

        nvgBeginPath(nvgContext)
        nvgMoveTo(nvgContext, cx + r * 0.7, cy + r * 0.7)
        nvgLineTo(nvgContext, x + size * 0.75, y + size * 0.75)
        nvgStroke(nvgContext)
    elseif iconType == "folder" then
        -- Folder icon
        local folderWidth = size * 0.8
        local folderHeight = size * 0.55
        local fx = x + (size - folderWidth) / 2
        local fy = y + (size - folderHeight) / 2 + size * 0.05

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, fx, fy, folderWidth, folderHeight, 3)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        -- Tab
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, fx, fy - size * 0.1, folderWidth * 0.4, size * 0.15, 2)
        nvgFill(nvgContext)
    elseif iconType == "browser" then
        -- Browser icon (circle with wave)
        nvgBeginPath(nvgContext)
        nvgCircle(nvgContext, x + size/2, y + size/2, size * 0.4)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        nvgBeginPath(nvgContext)
        nvgCircle(nvgContext, x + size/2, y + size/2, size * 0.25)
        nvgFillColor(nvgContext, nvgRGBAf(c.r * 0.7, c.g * 0.7, c.b * 0.7, 1))
        nvgFill(nvgContext)
    elseif iconType == "notepad" then
        -- Notepad icon
        local noteWidth = size * 0.6
        local noteHeight = size * 0.75
        local nx = x + (size - noteWidth) / 2
        local ny = y + (size - noteHeight) / 2

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, nx, ny, noteWidth, noteHeight, 2)
        nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
        nvgFill(nvgContext)

        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, nx, ny, noteWidth, size * 0.12)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        -- Lines
        for i = 0, 3 do
            nvgBeginPath(nvgContext)
            nvgRect(nvgContext, nx + noteWidth * 0.15, ny + noteHeight * 0.3 + i * noteHeight * 0.12, noteWidth * 0.7, 2)
            nvgFillColor(nvgContext, nvgRGBAf(0.7, 0.7, 0.7, 1))
            nvgFill(nvgContext)
        end
    elseif iconType == "calc" then
        -- Calculator icon
        local calcWidth = size * 0.55
        local calcHeight = size * 0.7
        local cx = x + (size - calcWidth) / 2
        local cy = y + (size - calcHeight) / 2

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, cx, cy, calcWidth, calcHeight, 3)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        -- Display
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, cx + calcWidth * 0.1, cy + calcHeight * 0.1, calcWidth * 0.8, calcHeight * 0.2)
        nvgFillColor(nvgContext, nvgRGBAf(0.8, 0.9, 0.8, 1))
        nvgFill(nvgContext)

        -- Buttons
        for i = 0, 2 do
            for j = 0, 2 do
                nvgBeginPath(nvgContext)
                nvgRect(nvgContext, cx + calcWidth * 0.1 + j * calcWidth * 0.28, cy + calcHeight * 0.4 + i * calcHeight * 0.18, calcWidth * 0.22, calcHeight * 0.14)
                nvgFillColor(nvgContext, nvgRGBAf(0.3, 0.3, 0.3, 1))
                nvgFill(nvgContext)
            end
        end
    elseif iconType == "recycle" then
        -- Recycle bin icon
        local binWidth = size * 0.5
        local binHeight = size * 0.55
        local bx = x + (size - binWidth) / 2
        local by = y + (size - binHeight) / 2 + size * 0.05

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, bx, by, binWidth, binHeight, 2)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        -- Lid
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, bx - binWidth * 0.1, by - size * 0.08, binWidth * 1.2, size * 0.1)
        nvgFill(nvgContext)
    elseif iconType == "settings" then
        -- Settings gear icon
        nvgBeginPath(nvgContext)
        nvgCircle(nvgContext, x + size/2, y + size/2, size * 0.35)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        nvgBeginPath(nvgContext)
        nvgCircle(nvgContext, x + size/2, y + size/2, size * 0.18)
        nvgFillColor(nvgContext, nvgRGBAf(c.r * 0.5, c.g * 0.5, c.b * 0.5, 1))
        nvgFill(nvgContext)
    elseif iconType == "info" then
        -- Info icon
        nvgBeginPath(nvgContext)
        nvgCircle(nvgContext, x + size/2, y + size/2, size * 0.35)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontBoldId)
        nvgFontSize(nvgContext, size * 0.45)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
        nvgText(nvgContext, x + size/2, y + size/2, "i", nil)
    else
        -- Default icon (colored square)
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x + size * 0.1, y + size * 0.1, size * 0.8, size * 0.8, 4)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)
    end
end

function DrawStartMenu()
    if startMenuProgress < 0.01 then return end

    local startMenuNodes, startMenuRoot = CreateStartMenuLayout()

    local menuX = (screenWidth - START_MENU_WIDTH) / 2
    local menuY = screenHeight - TASKBAR_HEIGHT - START_MENU_HEIGHT - 12

    -- Animate
    local offsetY = (1 - startMenuProgress) * 20
    local alpha = startMenuProgress

    nvgSave(nvgContext)
    nvgTranslate(nvgContext, 0, offsetY)
    nvgGlobalAlpha(nvgContext, alpha)

    -- Background with Mica effect
    nvgBeginPath(nvgContext)
    nvgRoundedRect(nvgContext, menuX, menuY, START_MENU_WIDTH, START_MENU_HEIGHT, START_MENU_RADIUS)
    nvgFillColor(nvgContext, nvgRGBAf(Colors.StartMenuBg.r, Colors.StartMenuBg.g, Colors.StartMenuBg.b, Colors.StartMenuBg.a))
    nvgFill(nvgContext)

    -- Border
    nvgBeginPath(nvgContext)
    nvgRoundedRect(nvgContext, menuX, menuY, START_MENU_WIDTH, START_MENU_HEIGHT, START_MENU_RADIUS)
    nvgStrokeColor(nvgContext, nvgRGBAf(1, 1, 1, 0.1))
    nvgStrokeWidth(nvgContext, 1)
    nvgStroke(nvgContext)

    -- Draw start menu elements
    for _, item in ipairs(startMenuNodes) do
        local x, y = GetAbsolutePosition(item.node, startMenuRoot)
        local w = YGNodeLayoutGetWidth(item.node)
        local h = YGNodeLayoutGetHeight(item.node)

        x = x + menuX
        y = y + menuY

        if item.type == "search-bar" then
            nvgBeginPath(nvgContext)
            nvgRoundedRect(nvgContext, x, y, w, h, 4)
            nvgFillColor(nvgContext, nvgRGBAf(item.color.r, item.color.g, item.color.b, 1))
            nvgFill(nvgContext)

            -- Search icon
            DrawIcon(x + 8, y + (h - 20) / 2, 20, "search", Colors.TextMuted)

            -- Placeholder text
            nvgFontFaceId(nvgContext, fontId)
            nvgFontSize(nvgContext, 13)
            nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvgContext, nvgRGBAf(Colors.TextMuted.r, Colors.TextMuted.g, Colors.TextMuted.b, 1))
            nvgText(nvgContext, x + 36, y + h/2, item.label, nil)
        elseif item.type == "section-title" then
            nvgFontFaceId(nvgContext, fontBoldId)
            nvgFontSize(nvgContext, 14)
            nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
            nvgText(nvgContext, x, y + h/2, item.label, nil)
        elseif item.type == "app-tile" then
            local isHovered = hoveredNode == item

            nvgBeginPath(nvgContext)
            nvgRoundedRect(nvgContext, x, y, w, h, TILE_RADIUS)
            local c = item.color
            if isHovered then
                nvgFillColor(nvgContext, nvgRGBAf(c.r * 1.2, c.g * 1.2, c.b * 1.2, 1))
            else
                nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
            end
            nvgFill(nvgContext)

            -- Icon
            local iconSize = 32
            DrawIcon(x + (w - iconSize) / 2, y + 12, iconSize, item.iconType, item.iconColor)

            -- Label
            nvgFontFaceId(nvgContext, fontId)
            nvgFontSize(nvgContext, 11)
            nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
            nvgText(nvgContext, x + w/2, y + h - 8, item.label, nil)
        elseif item.type == "avatar" then
            nvgBeginPath(nvgContext)
            nvgCircle(nvgContext, x + 16, y + 16, 16)
            nvgFillColor(nvgContext, nvgRGBAf(Colors.Accent.r, Colors.Accent.g, Colors.Accent.b, 1))
            nvgFill(nvgContext)

            nvgFontFaceId(nvgContext, fontBoldId)
            nvgFontSize(nvgContext, 14)
            nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
            nvgText(nvgContext, x + 16, y + 16, "U", nil)
        elseif item.type == "user-name" then
            nvgFontFaceId(nvgContext, fontId)
            nvgFontSize(nvgContext, 13)
            nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
            nvgText(nvgContext, x, y + h/2, item.label, nil)
        elseif item.type == "power-button" then
            local isHovered = hoveredNode == item

            if isHovered then
                nvgBeginPath(nvgContext)
                nvgRoundedRect(nvgContext, x, y, w, h, 4)
                nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 0.08))
                nvgFill(nvgContext)
            end

            -- Power icon
            nvgBeginPath(nvgContext)
            nvgCircle(nvgContext, x + w/2, y + h/2, 10)
            nvgStrokeColor(nvgContext, nvgRGBAf(1, 1, 1, 0.9))
            nvgStrokeWidth(nvgContext, 2)
            nvgStroke(nvgContext)

            nvgBeginPath(nvgContext)
            nvgMoveTo(nvgContext, x + w/2, y + h/2 - 10)
            nvgLineTo(nvgContext, x + w/2, y + h/2 - 2)
            nvgStroke(nvgContext)
        end
    end

    nvgRestore(nvgContext)

    YGNodeFreeRecursive(startMenuRoot)
end

function DrawWindow(win)
    local x = win.x
    local y = win.y
    local w = win.width
    local h = win.height
    local isActive = win == activeWindow

    -- Window shadow
    nvgBeginPath(nvgContext)
    nvgRoundedRect(nvgContext, x - 2, y, w + 4, h + 4, WINDOW_RADIUS + 2)
    nvgFillColor(nvgContext, nvgRGBAf(0, 0, 0, 0.25))
    nvgFill(nvgContext)

    -- Window background
    nvgBeginPath(nvgContext)
    nvgRoundedRect(nvgContext, x, y, w, h, WINDOW_RADIUS)
    nvgFillColor(nvgContext, nvgRGBAf(Colors.WindowBg.r, Colors.WindowBg.g, Colors.WindowBg.b, 1))
    nvgFill(nvgContext)

    -- Window border
    nvgBeginPath(nvgContext)
    nvgRoundedRect(nvgContext, x, y, w, h, WINDOW_RADIUS)
    nvgStrokeColor(nvgContext, nvgRGBAf(0, 0, 0, isActive and 0.2 or 0.1))
    nvgStrokeWidth(nvgContext, 1)
    nvgStroke(nvgContext)

    -- Clip to window
    nvgScissor(nvgContext, x, y, w, h)

    -- Draw window content
    for _, item in ipairs(win.contentNodes) do
        local ix, iy = GetAbsolutePosition(item.node, win.rootNode)
        local iw = YGNodeLayoutGetWidth(item.node)
        local ih = YGNodeLayoutGetHeight(item.node)

        ix = ix + x
        iy = iy + y

        DrawWindowElement(ix, iy, iw, ih, item, isActive)
    end

    nvgResetScissor(nvgContext)
end

function DrawWindowElement(x, y, w, h, item, isActive)
    local isHovered = hoveredNode == item
    local isPressed = pressedNode == item

    if item.type == "window-titlebar" then
        local c = isActive and Colors.WindowTitleBar or Colors.WindowTitleBarInactive
        nvgBeginPath(nvgContext)
        nvgRoundedRectVarying(nvgContext, x, y, w, h, WINDOW_RADIUS, WINDOW_RADIUS, 0, 0)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)
    elseif item.type == "window-icon" then
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x, y, w, h, 2)
        nvgFillColor(nvgContext, nvgRGBAf(item.color.r, item.color.g, item.color.b, 1))
        nvgFill(nvgContext)
    elseif item.type == "window-title-text" then
        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 12)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x, y + h/2, item.label or "", nil)
    elseif item.type == "window-button" then
        local bgColor = nil
        local iconColor = Colors.TextDark

        if item.buttonType == "close" then
            if isHovered or isPressed then
                bgColor = Colors.CloseHover
                iconColor = Colors.TextLight
            end
        else
            if isHovered or isPressed then
                bgColor = Colors.ButtonHover
            end
        end

        if bgColor then
            nvgBeginPath(nvgContext)
            if item.buttonType == "close" then
                nvgRoundedRectVarying(nvgContext, x, y, w, h, 0, WINDOW_RADIUS, 0, 0)
            else
                nvgRect(nvgContext, x, y, w, h)
            end
            nvgFillColor(nvgContext, nvgRGBAf(bgColor.r, bgColor.g, bgColor.b, 1))
            nvgFill(nvgContext)
        end

        -- Draw button icons
        local cx = x + w/2
        local cy = y + h/2

        nvgStrokeColor(nvgContext, nvgRGBAf(iconColor.r, iconColor.g, iconColor.b, 1))
        nvgStrokeWidth(nvgContext, 1)

        if item.buttonType == "minimize" then
            nvgBeginPath(nvgContext)
            nvgMoveTo(nvgContext, cx - 5, cy)
            nvgLineTo(nvgContext, cx + 5, cy)
            nvgStroke(nvgContext)
        elseif item.buttonType == "maximize" then
            nvgBeginPath(nvgContext)
            nvgRect(nvgContext, cx - 5, cy - 5, 10, 10)
            nvgStroke(nvgContext)
        elseif item.buttonType == "close" then
            nvgBeginPath(nvgContext)
            nvgMoveTo(nvgContext, cx - 4, cy - 4)
            nvgLineTo(nvgContext, cx + 4, cy + 4)
            nvgMoveTo(nvgContext, cx + 4, cy - 4)
            nvgLineTo(nvgContext, cx - 4, cy + 4)
            nvgStroke(nvgContext)
        end
    elseif item.type == "menu-bar" or item.type == "toolbar" or item.type == "status-bar" or item.type == "tab-bar" or item.type == "nav-bar" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, x, y, w, h)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        if item.label then
            nvgFontFaceId(nvgContext, fontId)
            nvgFontSize(nvgContext, 10)
            nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvgContext, nvgRGBAf(Colors.TextGray.r, Colors.TextGray.g, Colors.TextGray.b, 1))
            nvgText(nvgContext, x + 8, y + h/2, item.label, nil)
        end
    elseif item.type == "menu-item" then
        if isHovered then
            nvgBeginPath(nvgContext)
            nvgRoundedRect(nvgContext, x, y, w, h, 2)
            nvgFillColor(nvgContext, nvgRGBAf(0.9, 0.9, 0.9, 1))
            nvgFill(nvgContext)
        end

        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 11)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + w/2, y + h/2, item.label or "", nil)
    elseif item.type == "text-area" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, x, y, w, h)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        if item.label then
            nvgFontFaceId(nvgContext, fontId)
            nvgFontSize(nvgContext, 13)
            nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))

            -- Draw multiline text
            local lines = {}
            for line in string.gmatch(item.label .. "\n", "(.-)\n") do
                table.insert(lines, line)
            end
            for i, line in ipairs(lines) do
                nvgText(nvgContext, x + 8, y + 8 + (i - 1) * 18, line, nil)
            end
        end
    elseif item.type == "calc-display" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, x, y, w, h)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        -- Mode label
        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 12)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + 16, y + 12, "Standard", nil)

        -- Display value
        local displayValue = item.getLabel and item.getLabel() or "0"
        nvgFontFaceId(nvgContext, fontBoldId)
        nvgFontSize(nvgContext, 42)
        nvgTextAlign(nvgContext, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + w - 16, y + h - 12, displayValue, nil)
    elseif item.type == "calc-button" then
        local c = item.color
        local brightness = 1.0
        if isPressed then
            brightness = 0.85
        elseif isHovered then
            brightness = 0.92
        end

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x + 2, y + 2, w - 4, h - 4, BUTTON_RADIUS)
        nvgFillColor(nvgContext, nvgRGBAf(c.r * brightness, c.g * brightness, c.b * brightness, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 18)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(item.isEquals and 1 or Colors.TextDark.r, item.isEquals and 1 or Colors.TextDark.g, item.isEquals and 1 or Colors.TextDark.b, 1))
        nvgText(nvgContext, x + w/2, y + h/2, item.label or "", nil)
    elseif item.type == "nav-button" then
        local c = item.color or { r = 0.9, g = 0.9, b = 0.9, a = 1.0 }
        local brightness = 1.0
        if isHovered then brightness = 0.95 end

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x, y, w, h, BUTTON_RADIUS)
        nvgFillColor(nvgContext, nvgRGBAf(c.r * brightness, c.g * brightness, c.b * brightness, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontBoldId)
        nvgFontSize(nvgContext, 14)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextGray.r, Colors.TextGray.g, Colors.TextGray.b, 1))
        nvgText(nvgContext, x + w/2, y + h/2, item.label or "", nil)
    elseif item.type == "address-bar" or item.type == "url-bar" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x, y, w, h, BUTTON_RADIUS)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 12)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + 12, y + h/2, item.label or "", nil)
    elseif item.type == "sidebar" or item.type == "file-list" or item.type == "web-content" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, x, y, w, h)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)
    elseif item.type == "sidebar-item" then
        if isHovered then
            nvgBeginPath(nvgContext)
            nvgRoundedRect(nvgContext, x, y, w, h, 2)
            nvgFillColor(nvgContext, nvgRGBAf(0.9, 0.9, 0.9, 1))
            nvgFill(nvgContext)
        end

        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 11)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + 8, y + h/2, item.label or "", nil)
    elseif item.type == "file-item" then
        if isHovered then
            nvgBeginPath(nvgContext)
            nvgRoundedRect(nvgContext, x, y, w, h, 2)
            nvgFillColor(nvgContext, nvgRGBAf(0.92, 0.92, 0.92, 1))
            nvgFill(nvgContext)
        end

        -- File icon
        local iconColor = item.isFolder and Colors.TileYellow or Colors.TileGray
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x + 4, y + 4, 20, 20, 2)
        nvgFillColor(nvgContext, nvgRGBAf(iconColor.r, iconColor.g, iconColor.b, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 11)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + 30, y + h/2, item.label or "", nil)
    elseif item.type == "browser-tab" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRoundedRectVarying(nvgContext, x, y, w, h, 6, 6, 0, 0)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        -- Tab icon
        nvgBeginPath(nvgContext)
        nvgCircle(nvgContext, x + 20, y + h/2, 7)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TileCyan.r, Colors.TileCyan.g, Colors.TileCyan.b, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 11)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + 36, y + h/2, item.label or "", nil)

        -- Close button
        nvgFontSize(nvgContext, 12)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextGray.r, Colors.TextGray.g, Colors.TextGray.b, 1))
        nvgText(nvgContext, x + w - 16, y + h/2, "x", nil)
    elseif item.type == "new-tab-button" then
        if isHovered then
            nvgBeginPath(nvgContext)
            nvgRoundedRect(nvgContext, x, y, w, h, 4)
            nvgFillColor(nvgContext, nvgRGBAf(0.9, 0.9, 0.9, 1))
            nvgFill(nvgContext)
        end

        nvgFontFaceId(nvgContext, fontBoldId)
        nvgFontSize(nvgContext, 18)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextGray.r, Colors.TextGray.g, Colors.TextGray.b, 1))
        nvgText(nvgContext, x + w/2, y + h/2, item.label or "", nil)
    elseif item.type == "page-header" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, x, y, w, h)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontBoldId)
        nvgFontSize(nvgContext, 28)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
        nvgText(nvgContext, x + w/2, y + h/2, item.label or "", nil)
    elseif item.type == "page-body" then
        if item.label then
            nvgFontFaceId(nvgContext, fontId)
            nvgFontSize(nvgContext, 13)
            nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))

            local lines = {}
            for line in string.gmatch(item.label .. "\n", "(.-)\n") do
                table.insert(lines, line)
            end
            for i, line in ipairs(lines) do
                nvgText(nvgContext, x, y + (i - 1) * 20, line, nil)
            end
        end
    elseif item.type == "settings-header" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, x, y, w, h)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontBoldId)
        nvgFontSize(nvgContext, 24)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + 24, y + h/2, item.label or "", nil)
    elseif item.type == "settings-card" then
        local c = item.color
        local brightness = 1.0
        if isHovered then brightness = 0.98 end

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x, y, w, h, TILE_RADIUS)
        nvgFillColor(nvgContext, nvgRGBAf(c.r * brightness, c.g * brightness, c.b * brightness, 1))
        nvgFill(nvgContext)

        -- Icon
        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x + 16, y + 18, 36, 36, 4)
        nvgFillColor(nvgContext, nvgRGBAf(item.iconColor.r, item.iconColor.g, item.iconColor.b, 1))
        nvgFill(nvgContext)

        -- Title
        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 14)
        nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))
        nvgText(nvgContext, x + 64, y + 18, item.label or "", nil)

        -- Subtitle
        nvgFontSize(nvgContext, 11)
        nvgFillColor(nvgContext, nvgRGBAf(Colors.TextGray.r, Colors.TextGray.g, Colors.TextGray.b, 1))
        nvgText(nvgContext, x + 64, y + 38, item.sublabel or "", nil)
    elseif item.type == "about-header" then
        local c = item.color
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, x, y, w, h)
        nvgFillColor(nvgContext, nvgRGBAf(c.r, c.g, c.b, 1))
        nvgFill(nvgContext)

        -- Windows logo
        local logoSize = 28
        local logoGap = 4
        local logoX = x + (w - logoSize * 2 - logoGap) / 2
        local logoY = y + (h - logoSize * 2 - logoGap) / 2

        for i = 0, 1 do
            for j = 0, 1 do
                nvgBeginPath(nvgContext)
                nvgRect(nvgContext, logoX + j * (logoSize + logoGap), logoY + i * (logoSize + logoGap), logoSize, logoSize)
                nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
                nvgFill(nvgContext)
            end
        end
    elseif item.type == "about-content" then
        if item.label then
            nvgFontFaceId(nvgContext, fontId)
            nvgFontSize(nvgContext, 12)
            nvgTextAlign(nvgContext, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(nvgContext, nvgRGBAf(Colors.TextDark.r, Colors.TextDark.g, Colors.TextDark.b, 1))

            local lines = {}
            for line in string.gmatch(item.label .. "\n", "(.-)\n") do
                table.insert(lines, line)
            end
            for i, line in ipairs(lines) do
                nvgText(nvgContext, x, y + (i - 1) * 18, line, nil)
            end
        end
    elseif item.type == "ok-button" then
        local c = item.color
        local brightness = 1.0
        if isPressed then brightness = 0.85
        elseif isHovered then brightness = 1.1 end

        nvgBeginPath(nvgContext)
        nvgRoundedRect(nvgContext, x, y, w, h, BUTTON_RADIUS)
        nvgFillColor(nvgContext, nvgRGBAf(c.r * brightness, c.g * brightness, c.b * brightness, 1))
        nvgFill(nvgContext)

        nvgFontFaceId(nvgContext, fontId)
        nvgFontSize(nvgContext, 12)
        nvgTextAlign(nvgContext, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvgContext, nvgRGBAf(1, 1, 1, 1))
        nvgText(nvgContext, x + w/2, y + h/2, item.label or "", nil)
    end
end

-- ============================================================================
-- Screen Joystick Patch
-- ============================================================================
function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end
