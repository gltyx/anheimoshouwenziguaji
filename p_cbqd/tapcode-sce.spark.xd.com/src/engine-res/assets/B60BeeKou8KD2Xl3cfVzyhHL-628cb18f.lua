-- Urho3D editor

-- Temporary stubs for missing functions and variables
-- These will be replaced when modules are loaded

-- Global variables (normally defined in various modules)
uiRecentScenes = {}
sceneResourcePath = ""
uiImportPath = ""
globalVarNames = VariantMap()

-- Camera/View variables
viewNearClip = 0.1
viewFarClip = 1000.0
viewFov = 45.0
cameraBaseSpeed = 10.0
limitRotation = false
viewportMode = 1
mouseOrbitMode = 0
mmbPanMode = false
rotateAroundSelect = false

-- Object editing variables
cameraFlyMode = false
hotKeyMode = 0
newNodeMode = 0
moveStep = 0.5
rotateStep = 5.0
scaleStep = 0.1
moveSnap = false
rotateSnap = false
scaleSnap = false
applyMaterialList = false
importOptions = ""
pickMode = 0
axisMode = 0
revertOnPause = false

-- Resource path variables
rememberResourcePath = true

-- Rendering variables
renderPathName = "Forward"
gammaCorrection = false
HDR = false

-- UI variables
uiMinOpacity = 0.3
uiMaxOpacity = 0.7

-- Hierarchy/Inspector variables
showInternalUIElement = false
showTemporaryObject = false
nodeTextColor = Color(1.0, 1.0, 1.0)
componentTextColor = Color(0.7, 1.0, 0.7)
normalTextColor = Color(1.0, 1.0, 1.0)
modifiedTextColor = Color(1.0, 0.8, 0.5)
nonEditableTextColor = Color(0.7, 0.7, 0.7)
showNonEditableAttribute = false

-- View/Grid variables
showGrid = true
grid2DMode = false
gridSize = 16
gridSubdivisions = 4
gridScale = 1.0
gridColor = Color(0.2, 0.2, 0.2)
gridSubdivisionColor = Color(0.1, 0.1, 0.1)

-- Console variables
consoleCommandInterpreter = ""

-- Cubemap variables
cubeMapGen_Name = ""
cubeMapGen_Path = "Textures/Cubemaps/"
cubeMapGen_Size = 128
cubemapDefaultOutputPath = "Textures/Cubemaps/"

-- Tags variables
defaultTags = ""

-- Particle effect variables
particleEffectWindow = nil
particleEffectEmitter = nil
particleResetTimer = 0.0
editParticleEffect = nil

-- Attributes dirty flag
attributesFullDirty = false

-- Scene/Node editing variables (for Gizmo and EditorScene)
editNodes = {}
selectedNodes = {}
selectedComponents = {}
selectedUIElements = {}
editNode = nil
editComponent = nil
editUIElement = nil
editorScene = nil
camera = nil
cameraNode = nil
editMode = 0  -- Will be set to EDIT_SELECT
axisMode = 0  -- Will be set to AXIS_WORLD
orbiting = false
snapScale = 1.0
messageBoxCallback = nil
viewports = {nil}  -- At least one viewport

-- Edit mode constants
EDIT_MOVE = 0
EDIT_ROTATE = 1
EDIT_SCALE = 2
EDIT_SELECT = 3

-- Axis mode constants
AXIS_WORLD = 0
AXIS_LOCAL = 1

-- Helper function for array size (handles both Urho3D arrays and Lua tables)
function GetArraySize(arr)
    if arr == nil then
        return 0
    elseif type(arr) == "table" then
        return #arr
    elseif arr.Size ~= nil then
        return arr:Size()
    else
        return 0
    end
end

-- Utility functions

-- Load editor UI from XML file
function LoadEditorUI(path)
    local xmlFile = cache:GetResource("XMLFile", path)
    if xmlFile == nil then
        print("ERROR: Failed to load XML file: " .. path)
        return nil
    end
    local element = ui:LoadLayout(xmlFile)
    if element == nil then
        print("ERROR: Failed to load UI layout from: " .. path)
    end
    return element
end

-- Stub functions (will be defined in modules)
-- CreateScene - Implemented in EditorScene.lua
function LoadSoundTypes(elem) end
function UpdateViewParameters() end
function SetResourcePath(path, remember) end
function LoadScene(path) return false end
-- ResetScene - Implemented in EditorScene.lua
function CreateUI() end
function CreateRootUIElement() end
function DoResourceBrowserWork() end
-- UpdateView - Implemented in EditorView.lua
-- UpdateViewports - Implemented in EditorView.lua
-- UpdateStats - Implemented in EditorView.lua
function UpdateScene(timeStep) end
function UpdateTestAnimation(timeStep) end
function UpdateGizmo() end
function UpdateDirtyUI() end
function UpdateViewDebugIcons() end
function UpdateOrigins() end
function UpdatePaintSelection() end
function EditorSubscribeToEvents() end
function SaveSoundTypes(elem) end
function GetShadowResolution() return 1024 end
function SetShadowResolution(res) end
function AxisMode(value) return value end
function ShadowQuality(value) return value end
function HandleExitRequested() end
function GetActiveViewportCameraRay() return Ray() end
function UpdateNodeAttributes() end
function SaveEditActionGroup(group) end
function SetSceneModified() end
Transform = {}
EditActionGroup = {}
EditNodeTransformAction = {}

-- Module loading order is important - EditorUI must load BEFORE other modules
-- so its stubs don't override real implementations
require "LuaScripts/Editor/EditorUI"  -- Load first (has stubs)
require "LuaScripts/Editor/EditorView"  -- ENABLED - Core framework (simplified)
require "LuaScripts/Editor/EditorScene"  -- ENABLED
require "LuaScripts/Editor/EditorGizmo"  -- ENABLED
require "LuaScripts/Editor/EditorHierarchyWindow"  -- Load AFTER EditorUI to override stub
require "LuaScripts/Editor/AttributeEditor"  -- ENABLED - Attribute editing system
require "LuaScripts/Editor/EditorInspectorWindow"  -- ENABLED - Property inspector (minimal)
require "LuaScripts/Editor/EditorActions"  -- ENABLED - Undo/Redo system
require "LuaScripts/Editor/EditorUIElement"  -- ENABLED - UI element editing
require "LuaScripts/Editor/EditorMaterial"  -- ENABLED - Material editor
require "LuaScripts/Editor/EditorParticleEffect"  -- ENABLED - Particle effect editor
require "LuaScripts/Editor/EditorSettings"  -- ENABLED - Editor settings dialog
require "LuaScripts/Editor/EditorPreferences"  -- ENABLED - Editor preferences dialog
require "LuaScripts/Editor/EditorToolBar"  -- ENABLED - Main toolbar
require "LuaScripts/Editor/EditorResourceBrowser"  -- ENABLED - Resource browser with drag&drop
require "LuaScripts/Editor/EditorSecondaryToolbar"  -- ENABLED - Secondary toolbar
require "LuaScripts/Editor/EditorImport"  -- ENABLED - Asset import
require "LuaScripts/Editor/EditorExport"  -- ENABLED - OBJ export
require "LuaScripts/Editor/EditorSpawn"  -- ENABLED - Object spawning
require "LuaScripts/Editor/EditorSoundType"  -- ENABLED - Sound type manager
require "LuaScripts/Editor/EditorTerrain"  -- ENABLED - Terrain editor
require "LuaScripts/Editor/EditorLayers"  -- ENABLED - Layer/mask management
require "LuaScripts/Editor/EditorColorWheel"  -- ENABLED - HSV color wheel
require "LuaScripts/Editor/EditorEventsHandlers"  -- ENABLED - Event dispatcher (load last)
require "LuaScripts/Editor/EditorViewDebugIcons"  -- ENABLED - Debug icon system
require "LuaScripts/Editor/EditorViewSelectableOrigins"  -- ENABLED - Scene origin markers
require "LuaScripts/Editor/EditorViewPaintSelection"  -- ENABLED - Brush selection tool
require "LuaScripts/Editor/EditorCubeCapture"  -- ENABLED - Cubemap generation

configFileName = nil

function Start()
    -- Assign the value ASAP because configFileName is needed on exit, including exit on error
    configFileName = fileSystem:GetAppPreferencesDir("urho3d", "Editor") .. "Config.xml"
    localization:LoadJSONFile("EditorStrings.json")

    if engine.headless then
        ErrorDialog("Urho3D Editor", "Headless mode is not supported. The program will now exit.")
        engine:Exit()
        return
    end

    -- Use the first frame to setup when the resolution is initialized
    SubscribeToEvent("Update", "FirstFrame")

    SubscribeToEvent(input, "ExitRequested", "HandleExitRequested")

    -- Disable Editor auto exit, check first if it is OK to exit
    engine.autoExit = false
    -- Pause completely when minimized to save OS resources, reduce defocused framerate
    engine.pauseMinimized = true
    engine.maxInactiveFps = 10
    -- Enable console commands from the editor script
    if script ~= nil then
        script.defaultScriptFile = scriptFile
    end
    -- Enable automatic resource reloading
    cache.autoReloadResources = true
    -- Return resources which exist but failed to load due to error, so that we will not lose resource refs
    cache.returnFailedResources = true
    -- Use OS mouse without grabbing it
    input.mouseVisible = true
    -- If input is scaled the double the UI size (High DPI display)
    if input.inputScale ~= Vector2.ONE then
        -- Should we use the inputScale itself to scale UI?
        ui.scale = 2
        -- When UI scale is increased, also set the UI atlas to nearest filtering to avoid artifacts
        -- (there is no padding) and to have a sharper look
        local uiTex = cache:GetResource("Texture2D", "Textures/UI.png")
        if uiTex ~= nil then
            uiTex.filterMode = FILTER_NEAREST
        end
    end
    -- Use system clipboard to allow transport of text in & out from the editor
    ui.useSystemClipboard = true
end

function FirstFrame()
    -- Create root scene node
    CreateScene()
    -- Load editor settings and preferences
    LoadConfig()
    -- Create user interface for the editor
    CreateUI()
    -- Create root UI element where all 'editable' UI elements would be parented to
    CreateRootUIElement()
    -- Load the initial scene if provided
    ParseArguments()
    -- Switch to real frame handler after initialization
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("ReloadFinished", "HandleReloadFinishOrFail")
    SubscribeToEvent("ReloadFailed", "HandleReloadFinishOrFail")
    EditorSubscribeToEvents()
end

function Stop()
    SaveConfig()
end

function ParseArguments()
    local arguments = GetArguments()
    if arguments == nil then
        ResetScene()
        return
    end

    local loaded = false

    -- Scan for a scene to load
    local i = 1
    local argCount = (type(arguments) == "table" and #arguments or arguments:Size())
    while i < argCount do
        local arg = arguments[i]
        if type(arg) == "string" then
            arg = string.lower(arg)
        elseif type(arg) == "userdata" and arg.GetString then
            arg = string.lower(arg:GetString())
        end

        if arg == "-scene" then
            i = i + 1
            if i < argCount then
                loaded = LoadScene(arguments[i])
                break
            end
        end
        if string.lower(arguments[i]) == "-language" then
            i = i + 1
            if i < argCount then
                localization:SetLanguage(arguments[i])
                break
            end
        end
        i = i + 1
    end

    if not loaded then
        ResetScene()
    end
end

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    DoResourceBrowserWork()
    UpdateView(timeStep)
    UpdateViewports(timeStep)
    UpdateStats(timeStep)
    UpdateScene(timeStep)
    UpdateTestAnimation(timeStep)
    UpdateGizmo()
    UpdateDirtyUI()
    UpdateViewDebugIcons()
    UpdateOrigins()
    UpdatePaintSelection()

    -- Handle Particle Editor looping.
    if particleEffectWindow ~= nil and particleEffectWindow.visible then
        if not particleEffectEmitter.emitting then
            if particleResetTimer == 0.0 then
                particleResetTimer = editParticleEffect.maxTimeToLive + 0.2
            else
                particleResetTimer = Max(particleResetTimer - timeStep, 0.0)
                if particleResetTimer <= 0.0001 then
                    particleEffectEmitter:Reset()
                    particleResetTimer = 0.0
                end
            end
        end
    end
end

function HandleReloadFinishOrFail(eventType, eventData)
    local res = GetEventSender()
    -- Only refresh inspector when reloading scripts (script attributes may change)
    if res ~= nil and (res.typeName == "ScriptFile" or res.typeName == "LuaFile") then
        attributesFullDirty = true
    end
end

function LoadConfig()
    if not fileSystem:FileExists(configFileName) then
        return
    end

    local config = XMLFile()
    config:Load(File(configFileName, FILE_READ))

    local configElem = config.root
    if configElem.isNull then
        return
    end

    local cameraElem = configElem:GetChild("camera")
    local objectElem = configElem:GetChild("object")
    local renderingElem = configElem:GetChild("rendering")
    local uiElem = configElem:GetChild("ui")
    local hierarchyElem = configElem:GetChild("hierarchy")
    local inspectorElem = configElem:GetChild("attributeinspector")
    local viewElem = configElem:GetChild("view")
    local resourcesElem = configElem:GetChild("resources")
    local consoleElem = configElem:GetChild("console")
    local varNamesElem = configElem:GetChild("varnames")
    local soundTypesElem = configElem:GetChild("soundtypes")
    local cubeMapElem = configElem:GetChild("cubegen")
    local defaultTagsElem = configElem:GetChild("tags")

    if not cameraElem.isNull then
        if cameraElem:HasAttribute("nearclip") then viewNearClip = cameraElem:GetFloat("nearclip") end
        if cameraElem:HasAttribute("farclip") then viewFarClip = cameraElem:GetFloat("farclip") end
        if cameraElem:HasAttribute("fov") then viewFov = cameraElem:GetFloat("fov") end
        if cameraElem:HasAttribute("speed") then cameraBaseSpeed = cameraElem:GetFloat("speed") end
        if cameraElem:HasAttribute("limitrotation") then limitRotation = cameraElem:GetBool("limitrotation") end
        if cameraElem:HasAttribute("viewportmode") then viewportMode = cameraElem:GetUInt("viewportmode") end
        if cameraElem:HasAttribute("mouseorbitmode") then mouseOrbitMode = cameraElem:GetInt("mouseorbitmode") end
        if cameraElem:HasAttribute("mmbpan") then mmbPanMode = cameraElem:GetBool("mmbpan") end
        if cameraElem:HasAttribute("rotatearoundselect") then rotateAroundSelect = cameraElem:GetBool("rotatearoundselect") end

        UpdateViewParameters()
    end

    if not objectElem.isNull then
        if objectElem:HasAttribute("cameraflymode") then cameraFlyMode = objectElem:GetBool("cameraflymode") end
        if objectElem:HasAttribute("hotkeymode") then hotKeyMode = objectElem:GetInt("hotkeymode") end
        if objectElem:HasAttribute("newnodemode") then newNodeMode = objectElem:GetInt("newnodemode") end
        if objectElem:HasAttribute("movestep") then moveStep = objectElem:GetFloat("movestep") end
        if objectElem:HasAttribute("rotatestep") then rotateStep = objectElem:GetFloat("rotatestep") end
        if objectElem:HasAttribute("scalestep") then scaleStep = objectElem:GetFloat("scalestep") end
        if objectElem:HasAttribute("movesnap") then moveSnap = objectElem:GetBool("movesnap") end
        if objectElem:HasAttribute("rotatesnap") then rotateSnap = objectElem:GetBool("rotatesnap") end
        if objectElem:HasAttribute("scalesnap") then scaleSnap = objectElem:GetBool("scalesnap") end
        if objectElem:HasAttribute("applymateriallist") then applyMaterialList = objectElem:GetBool("applymateriallist") end
        if objectElem:HasAttribute("importoptions") then importOptions = objectElem:GetAttribute("importoptions") end
        if objectElem:HasAttribute("pickmode") then pickMode = objectElem:GetInt("pickmode") end
        if objectElem:HasAttribute("axismode") then axisMode = AxisMode(objectElem:GetInt("axismode")) end
        if objectElem:HasAttribute("revertonpause") then revertOnPause = objectElem:GetBool("revertonpause") end
    end

    if not resourcesElem.isNull then
        if resourcesElem:HasAttribute("rememberresourcepath") then rememberResourcePath = resourcesElem:GetBool("rememberresourcepath") end
        if rememberResourcePath and resourcesElem:HasAttribute("resourcepath") then
            local newResourcePath = resourcesElem:GetAttribute("resourcepath")
            if fileSystem:DirExists(newResourcePath) then
                SetResourcePath(resourcesElem:GetAttribute("resourcepath"), false)
            end
        end
        if resourcesElem:HasAttribute("importpath") then
            local newImportPath = resourcesElem:GetAttribute("importpath")
            if fileSystem:DirExists(newImportPath) then
                uiImportPath = newImportPath
            end
        end
        if resourcesElem:HasAttribute("recentscenes") then
            uiRecentScenes = resourcesElem:GetAttribute("recentscenes"):Split(';')
        end
    end

    if not renderingElem.isNull then
        if renderingElem:HasAttribute("renderpath") then renderPathName = renderingElem:GetAttribute("renderpath") end
        if renderingElem:HasAttribute("texturequality") then renderer.textureQuality = renderingElem:GetInt("texturequality") end
        if renderingElem:HasAttribute("materialquality") then renderer.materialQuality = renderingElem:GetInt("materialquality") end
        if renderingElem:HasAttribute("shadowresolution") then SetShadowResolution(renderingElem:GetInt("shadowresolution")) end
        if renderingElem:HasAttribute("shadowquality") then renderer.shadowQuality = ShadowQuality(renderingElem:GetInt("shadowquality")) end
        if renderingElem:HasAttribute("maxoccludertriangles") then renderer.maxOccluderTriangles = renderingElem:GetInt("maxoccludertriangles") end
        if renderingElem:HasAttribute("specularlighting") then renderer.specularLighting = renderingElem:GetBool("specularlighting") end
        if renderingElem:HasAttribute("dynamicinstancing") then renderer.dynamicInstancing = renderingElem:GetBool("dynamicinstancing") end
        if renderingElem:HasAttribute("framelimiter") then engine.maxFps = (renderingElem:GetBool("framelimiter") and 200 or 0) end
        if renderingElem:HasAttribute("gammacorrection") then gammaCorrection = renderingElem:GetBool("gammacorrection") end
        if renderingElem:HasAttribute("hdr") then HDR = renderingElem:GetBool("hdr") end
    end

    if not uiElem.isNull then
        if uiElem:HasAttribute("minopacity") then uiMinOpacity = uiElem:GetFloat("minopacity") end
        if uiElem:HasAttribute("maxopacity") then uiMaxOpacity = uiElem:GetFloat("maxopacity") end
        if uiElem:HasAttribute("languageindex") then localization:SetLanguage(uiElem:GetInt("languageindex")) end
    end

    if not hierarchyElem.isNull then
        if hierarchyElem:HasAttribute("showinternaluielement") then showInternalUIElement = hierarchyElem:GetBool("showinternaluielement") end
        if hierarchyElem:HasAttribute("showtemporaryobject") then showTemporaryObject = hierarchyElem:GetBool("showtemporaryobject") end
        if inspectorElem:HasAttribute("nodecolor") then nodeTextColor = inspectorElem:GetColor("nodecolor") end
        if inspectorElem:HasAttribute("componentcolor") then componentTextColor = inspectorElem:GetColor("componentcolor") end
    end

    if not inspectorElem.isNull then
        if inspectorElem:HasAttribute("originalcolor") then normalTextColor = inspectorElem:GetColor("originalcolor") end
        if inspectorElem:HasAttribute("modifiedcolor") then modifiedTextColor = inspectorElem:GetColor("modifiedcolor") end
        if inspectorElem:HasAttribute("noneditablecolor") then nonEditableTextColor = inspectorElem:GetColor("noneditablecolor") end
        if inspectorElem:HasAttribute("shownoneditable") then showNonEditableAttribute = inspectorElem:GetBool("shownoneditable") end
    end

    if not viewElem.isNull then
        if viewElem:HasAttribute("defaultzoneambientcolor") then renderer.defaultZone.ambientColor = viewElem:GetColor("defaultzoneambientcolor") end
        if viewElem:HasAttribute("defaultzonefogcolor") then renderer.defaultZone.fogColor = viewElem:GetColor("defaultzonefogcolor") end
        if viewElem:HasAttribute("defaultzonefogstart") then renderer.defaultZone.fogStart = viewElem:GetInt("defaultzonefogstart") end
        if viewElem:HasAttribute("defaultzonefogend") then renderer.defaultZone.fogEnd = viewElem:GetInt("defaultzonefogend") end
        if viewElem:HasAttribute("showgrid") then showGrid = viewElem:GetBool("showgrid") end
        if viewElem:HasAttribute("grid2dmode") then grid2DMode = viewElem:GetBool("grid2dmode") end
        if viewElem:HasAttribute("gridsize") then gridSize = viewElem:GetInt("gridsize") end
        if viewElem:HasAttribute("gridsubdivisions") then gridSubdivisions = viewElem:GetInt("gridsubdivisions") end
        if viewElem:HasAttribute("gridscale") then gridScale = viewElem:GetFloat("gridscale") end
        if viewElem:HasAttribute("gridcolor") then gridColor = viewElem:GetColor("gridcolor") end
        if viewElem:HasAttribute("gridsubdivisioncolor") then gridSubdivisionColor = viewElem:GetColor("gridsubdivisioncolor") end
    end

    if not consoleElem.isNull then
        -- Console does not exist yet at this point, so store the string in a global variable
        if consoleElem:HasAttribute("commandinterpreter") then consoleCommandInterpreter = consoleElem:GetAttribute("commandinterpreter") end
    end

    if not varNamesElem.isNull then
        globalVarNames = varNamesElem:GetVariantMap()
    end

    if not soundTypesElem.isNull then
        LoadSoundTypes(soundTypesElem)
    end

    if not cubeMapElem.isNull then
        cubeMapGen_Name = (cubeMapElem:HasAttribute("name") and cubeMapElem:GetAttribute("name") or "")
        cubeMapGen_Path = (cubeMapElem:HasAttribute("path") and cubeMapElem:GetAttribute("path") or cubemapDefaultOutputPath)
        cubeMapGen_Size = (cubeMapElem:HasAttribute("size") and cubeMapElem:GetInt("size") or 128)
    else
        cubeMapGen_Name = ""
        cubeMapGen_Path = cubemapDefaultOutputPath
        cubeMapGen_Size = 128
    end

    if not defaultTagsElem.isNull then
        if defaultTagsElem:HasAttribute("tags") then defaultTags = defaultTagsElem:GetAttribute("tags") end
    end
end

function SaveConfig()
    local config = XMLFile()
    local configElem = config:CreateRoot("configuration")
    local cameraElem = configElem:CreateChild("camera")
    local objectElem = configElem:CreateChild("object")
    local renderingElem = configElem:CreateChild("rendering")
    local uiElem = configElem:CreateChild("ui")
    local hierarchyElem = configElem:CreateChild("hierarchy")
    local inspectorElem = configElem:CreateChild("attributeinspector")
    local viewElem = configElem:CreateChild("view")
    local resourcesElem = configElem:CreateChild("resources")
    local consoleElem = configElem:CreateChild("console")
    local varNamesElem = configElem:CreateChild("varnames")
    local soundTypesElem = configElem:CreateChild("soundtypes")
    local cubeGenElem = configElem:CreateChild("cubegen")
    local defaultTagsElem = configElem:CreateChild("tags")

    cameraElem:SetFloat("nearclip", viewNearClip)
    cameraElem:SetFloat("farclip", viewFarClip)
    cameraElem:SetFloat("fov", viewFov)
    cameraElem:SetFloat("speed", cameraBaseSpeed)
    cameraElem:SetBool("limitrotation", limitRotation)
    cameraElem:SetUInt("viewportmode", viewportMode)
    cameraElem:SetInt("mouseorbitmode", mouseOrbitMode)
    cameraElem:SetBool("mmbpan", mmbPanMode)
    cameraElem:SetBool("rotatearoundselect", rotateAroundSelect)

    objectElem:SetBool("cameraflymode", cameraFlyMode)
    objectElem:SetInt("hotkeymode", hotKeyMode)
    objectElem:SetInt("newnodemode", newNodeMode)
    objectElem:SetFloat("movestep", moveStep)
    objectElem:SetFloat("rotatestep", rotateStep)
    objectElem:SetFloat("scalestep", scaleStep)
    objectElem:SetBool("movesnap", moveSnap)
    objectElem:SetBool("rotatesnap", rotateSnap)
    objectElem:SetBool("scalesnap", scaleSnap)
    objectElem:SetBool("applymateriallist", applyMaterialList)
    objectElem:SetAttribute("importoptions", importOptions)
    objectElem:SetInt("pickmode", pickMode)
    objectElem:SetInt("axismode", axisMode)
    objectElem:SetBool("revertonpause", revertOnPause)

    resourcesElem:SetBool("rememberresourcepath", rememberResourcePath)
    resourcesElem:SetAttribute("resourcepath", sceneResourcePath)
    resourcesElem:SetAttribute("importpath", uiImportPath)
    resourcesElem:SetAttribute("recentscenes", table.concat(uiRecentScenes, ";"))

    if renderer ~= nil and graphics ~= nil then
        renderingElem:SetAttribute("renderpath", renderPathName)
        renderingElem:SetInt("texturequality", renderer.textureQuality)
        renderingElem:SetInt("materialquality", renderer.materialQuality)
        renderingElem:SetInt("shadowresolution", GetShadowResolution())
        renderingElem:SetInt("maxoccludertriangles", renderer.maxOccluderTriangles)
        renderingElem:SetBool("specularlighting", renderer.specularLighting)
        renderingElem:SetInt("shadowquality", renderer.shadowQuality)
        renderingElem:SetBool("dynamicinstancing", renderer.dynamicInstancing)
    end

    renderingElem:SetBool("framelimiter", engine.maxFps > 0)
    renderingElem:SetBool("gammacorrection", gammaCorrection)
    renderingElem:SetBool("hdr", HDR)

    uiElem:SetFloat("minopacity", uiMinOpacity)
    uiElem:SetFloat("maxopacity", uiMaxOpacity)
    uiElem:SetInt("languageindex", localization.languageIndex)

    hierarchyElem:SetBool("showinternaluielement", showInternalUIElement)
    hierarchyElem:SetBool("showtemporaryobject", showTemporaryObject)
    inspectorElem:SetColor("nodecolor", nodeTextColor)
    inspectorElem:SetColor("componentcolor", componentTextColor)

    inspectorElem:SetColor("originalcolor", normalTextColor)
    inspectorElem:SetColor("modifiedcolor", modifiedTextColor)
    inspectorElem:SetColor("noneditablecolor", nonEditableTextColor)
    inspectorElem:SetBool("shownoneditable", showNonEditableAttribute)

    viewElem:SetBool("showgrid", showGrid)
    viewElem:SetBool("grid2dmode", grid2DMode)
    viewElem:SetColor("defaultzoneambientcolor", renderer.defaultZone.ambientColor)
    viewElem:SetColor("defaultzonefogcolor", renderer.defaultZone.fogColor)
    viewElem:SetFloat("defaultzonefogstart", renderer.defaultZone.fogStart)
    viewElem:SetFloat("defaultzonefogend", renderer.defaultZone.fogEnd)
    viewElem:SetInt("gridsize", gridSize)
    viewElem:SetInt("gridsubdivisions", gridSubdivisions)
    viewElem:SetFloat("gridscale", gridScale)
    viewElem:SetColor("gridcolor", gridColor)
    viewElem:SetColor("gridsubdivisioncolor", gridSubdivisionColor)

    consoleElem:SetAttribute("commandinterpreter", console.commandInterpreter)

    varNamesElem:SetVariantMap(globalVarNames)

    cubeGenElem:SetAttribute("name", cubeMapGen_Name)
    cubeGenElem:SetAttribute("path", cubeMapGen_Path)
    cubeGenElem:SetAttribute("size", cubeMapGen_Size)

    defaultTagsElem:SetAttribute("tags", defaultTags)

    SaveSoundTypes(soundTypesElem)

    config:Save(File(configFileName, FILE_WRITE))
end

function MakeBackup(fileName)
    fileSystem:Rename(fileName, fileName .. ".old")
end

function RemoveBackup(success, fileName)
    if success then
        fileSystem:Delete(fileName .. ".old")
    end
end
