-- Urho3D editor user interface

-- Global UI variables
uiStyle = nil
iconStyle = nil
uiMenuBar = nil
quickMenu = nil
recentSceneMenu = nil
mruScenesPopup = nil
quickMenuItems = {}
uiFileSelector = nil
consoleCommandInterpreter = ""
contextMenu = nil
stepColoringGroupUpdate = 100
timeToNextColoringGroupUpdate = 0

-- Constants
local UI_ELEMENT_TYPE = StringHash("UIElement")
local WINDOW_TYPE = StringHash("Window")
local MENU_TYPE = StringHash("Menu")
local TEXT_TYPE = StringHash("Text")
local CURSOR_TYPE = StringHash("Cursor")

local AUTO_STYLE = ""
local TEMP_SCENE_NAME = "_tempscene_.xml"
local TEMP_BINARY_SCENE_NAME = "_tempscene_.bin"
local CALLBACK_VAR = StringHash("Callback")
local INDENT_MODIFIED_BY_ICON_VAR = StringHash("IconIndented")
local VAR_CONTEXT_MENU_HANDLER = StringHash("ContextMenuHandler")

local SHOW_POPUP_INDICATOR = -1
local MAX_QUICK_MENU_ITEMS = 10
local maxRecentSceneCount = 5

-- File filters
uiSceneFilters = {"*.xml", "*.json", "*.bin", "*.*"}
uiElementFilters = {"*.xml"}
uiAllFilters = {"*.*"}
uiScriptFilters = {"*.lua", "*.*"}
uiParticleFilters = {"*.xml"}
uiRenderPathFilters = {"*.xml"}
uiExportPathFilters = {"*.obj"}
uiSceneFilter = 0
uiElementFilter = 0
uiNodeFilter = 0
uiImportFilter = 0
uiScriptFilter = 0
uiParticleFilter = 0
uiRenderPathFilter = 0
uiExportFilter = 0

-- Paths (initialize with nil check)
local progDir = (fileSystem and fileSystem.programDir) or ""
uiScenePath = progDir .. "Data/Scenes"
uiElementPath = progDir .. "Data/UI"
uiNodePath = progDir .. "Data/Objects"
uiImportPath = ""
uiExportPath = ""
uiScriptPath = progDir .. "Data/Scripts"
uiParticlePath = progDir .. "Data/Particles"
uiRenderPathPath = progDir .. "CoreData/RenderPaths"
uiRecentScenes = {}
screenshotDir = progDir .. "Screenshots"

uiFaded = false
uiMinOpacity = 0.3
uiMaxOpacity = 0.7
uiHidden = false

terrainEditor = nil

-- Helper function
function GetEditorUIXMLFile(path)
    return cache:GetResource("XMLFile", path)
end

function CreateUI()
    -- Remove all existing UI content in case we are reloading the editor script
    ui.root:RemoveAllChildren()

    uiStyle = GetEditorUIXMLFile("UI/DefaultStyle.xml")
    ui.root.defaultStyle = uiStyle
    iconStyle = GetEditorUIXMLFile("UI/EditorIcons.xml")

    if graphics ~= nil then
        graphics.windowIcon = cache:GetResource("Image", "Textures/UrhoIcon.png")
    end

    CreateCursor()
    CreateMenuBar()
    CreateToolBar()
    CreateSecondaryToolBar()
    CreateQuickMenu()
    CreateContextMenu()
    CreateHierarchyWindow()
    CreateAttributeInspectorWindow()
    CreateEditorSettingsDialog()
    CreateEditorPreferencesDialog()
    CreateMaterialEditor()
    CreateParticleEffectEditor()
    CreateSpawnEditor()
    CreateSoundTypeEditor()
    CreateStatsBar()
    CreateConsole()
    CreateDebugHud()
    CreateResourceBrowser()
    CreateCamera()
    CreateLayerEditor()
    CreateColorWheel()

    if terrainEditor ~= nil then
        terrainEditor:Create()
    end

    SubscribeToEvent("ScreenMode", "ResizeUI")
    SubscribeToEvent("MenuSelected", "HandleMenuSelected")
    SubscribeToEvent("ChangeLanguage", "HandleChangeLanguage")
    SubscribeToEvent("WheelChangeColor", "HandleWheelChangeColor")
    SubscribeToEvent("WheelSelectColor", "HandleWheelSelectColor")
    SubscribeToEvent("WheelDiscardColor", "HandleWheelDiscardColor")
end

function ResizeUI()
    if uiMenuBar ~= nil then
        uiMenuBar:SetFixedWidth(graphics.width)
    end

    if toolBar ~= nil then
        toolBar:SetFixedWidth(graphics.width)
    end

    if secondaryToolBar ~= nil then
        secondaryToolBar:SetFixedHeight(graphics.height)
    end

    -- Relayout windows
    local children = ui.root:GetChildren()
    for i = 0, GetArraySize(children) - 1 do
        if children[i].type == WINDOW_TYPE then
            AdjustPosition(children[i])
        end
    end

    -- Relayout root UI element
    if editorUIElement ~= nil then
        editorUIElement:SetSize(graphics.width, graphics.height)
    end

    -- Set new viewport area and reset the viewport layout
    viewportArea = IntRect(0, 0, graphics.width, graphics.height)
    SetViewportMode(viewportMode)
end

function AdjustPosition(window)
    local position = window.position
    local size = window.size
    local extEnd = position + size
    if extEnd.x > graphics.width then
        position.x = Max(10, graphics.width - size.x - 10)
    end
    if extEnd.y > graphics.height then
        position.y = Max(100, graphics.height - size.y - 10)
    end
    window.position = position
end

function CreateCursor()
    local cursor = Cursor("Cursor")
    cursor:SetStyleAuto(uiStyle)
    cursor:SetPosition(graphics.width / 2, graphics.height / 2)
    ui.cursor = cursor
    local platform = GetPlatform()
    if platform == "Android" or platform == "iOS" then
        ui.cursor.visible = false
    end
end

-- Simplified MenuBar implementation (just visible, functionality is stub)
function CreateMenuBar()
    uiMenuBar = BorderImage("MenuBar")
    ui.root:AddChild(uiMenuBar)
    uiMenuBar.enabled = true
    uiMenuBar.style = "EditorMenuBar"
    uiMenuBar:SetLayout(LM_HORIZONTAL)
    uiMenuBar.opacity = uiMaxOpacity
    uiMenuBar:SetFixedWidth(graphics.width)
    uiMenuBar:SetFixedHeight(20)

    -- Add a simple text to show the menu bar exists
    local titleText = Text()
    titleText.text = "Urho3D Editor (Lua)"
    titleText:SetFont("Fonts/Anonymous Pro.ttf", 12)
    titleText.textAlignment = HA_LEFT
    titleText:SetStyleAuto()
    uiMenuBar:AddChild(titleText)
end

-- Simplified ToolBar implementation
function CreateToolBar()
    toolBar = BorderImage("ToolBar")
    toolBar.style = "EditorToolBar"
    toolBar:SetLayout(LM_HORIZONTAL)
    toolBar.layoutSpacing = 4
    toolBar.layoutBorder = IntRect(8, 4, 4, 8)
    toolBar.opacity = uiMaxOpacity
    toolBar:SetFixedSize(graphics.width, 42)
    toolBar:SetPosition(0, uiMenuBar.height)
    ui.root:AddChild(toolBar)

    -- Add a simple text to show the toolbar exists
    local infoText = Text()
    infoText.text = "Toolbar [Scene loaded with test objects]"
    infoText:SetFont("Fonts/Anonymous Pro.ttf", 11)
    infoText:SetStyleAuto()
    toolBar:AddChild(infoText)
end
function CreateSecondaryToolBar() end
function CreateQuickMenu() end
function CreateContextMenu() end

function CloseContextMenu()
    if contextMenu == nil then
        return
    end
    contextMenu.enabled = false
    contextMenu.visible = false
end

function CenterDialog(element)
    local size = element.size
    element:SetPosition((ui.root.width - size.x) / 2, (ui.root.height - size.y) / 2)
end

function SetIconEnabledColor(element, enabled, partial)
    partial = partial or false
    local icon = element:GetChild("Icon")
    if icon ~= nil then
        if partial then
            icon:SetColor(C_TOPLEFT, Color(1, 1, 1, 1))
            icon:SetColor(C_BOTTOMLEFT, Color(1, 1, 1, 1))
            icon:SetColor(C_TOPRIGHT, Color(1, 0, 0, 1))
            icon:SetColor(C_BOTTOMRIGHT, Color(1, 0, 0, 1))
        else
            if enabled then
                icon.color = Color(1, 1, 1, 1)
            else
                icon.color = Color(1, 0, 0, 1)
            end
        end
    end
end

function IconizeUIElement(element, iconType)
    -- Check if the icon has been created before
    local icon = element:GetChild("Icon")

    -- If iconType is empty, it is a request to remove the existing icon
    if iconType == nil or iconType == "" then
        -- Remove the icon if it exists
        if icon ~= nil then
            icon:Remove()
        end

        -- Revert back the indent but only if it is indented by this function
        local indentModified = element:GetVar(StringHash("IndentModifiedByIcon"))
        if not indentModified:IsEmpty() and indentModified:GetBool() then
            element.indent = 0
        end

        return
    end

    -- The UI element must itself has been indented to reserve the space for the icon
    if element.indent == 0 then
        element.indent = 1
        element:SetVar(StringHash("IndentModifiedByIcon"), Variant(true))
    end

    -- If no icon yet then create one with the correct indent and size in respect to the UI element
    if icon == nil then
        -- The icon is placed at one indent level less than the UI element
        icon = BorderImage("Icon")
        icon.indent = element.indent - 1
        icon:SetFixedSize(element.indentWidth - 2, 14)
        element:InsertChild(0, icon)   -- Ensure icon is added as the first child
    end

    -- Set the icon type
    if not icon:SetStyle(iconType, iconStyle) then
        icon:SetStyle("Unknown", iconStyle)    -- If fails then use an 'unknown' icon type
    end
    icon.color = Color(1, 1, 1, 1)  -- Reset to enabled color
end

-- CreateHierarchyWindow() - Implemented in EditorHierarchyWindow.lua
function CreateAttributeInspectorWindow() end
function CreateEditorSettingsDialog() end
function CreateEditorPreferencesDialog() end
function CreateMaterialEditor() end
function CreateParticleEffectEditor() end
function CreateSpawnEditor() end
function CreateSoundTypeEditor() end
function CreateStatsBar() end
function CreateConsole() end
function CreateDebugHud() end
function CreateResourceBrowser() end
function CreateLayerEditor() end
function CreateColorWheel() end

-- Stub event handlers
function HandleMenuSelected() end
function HandleChangeLanguage() end
function HandleWheelChangeColor() end
function HandleWheelSelectColor() end
function HandleWheelDiscardColor() end

-- Additional stubs
editorUIElement = nil
toolBar = nil
secondaryToolBar = nil
