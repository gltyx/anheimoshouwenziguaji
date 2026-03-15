--[[
    EditorResourceBrowser.lua - Resource Browser for UrhoX Editor (Lua Version)

    This module provides a comprehensive resource browsing system for the editor:
    - Scans all resource directories and catalogs files by type
    - Provides UI for browsing directories and files
    - Supports search, filtering by resource type
    - Drag-and-drop support for materials, models, and prefabs
    - 3D preview of models, materials, and particle effects
    - Context menus for resource operations

    Main Classes:
    - BrowserDir: Represents a directory in the resource tree
    - BrowserFile: Represents a file with type detection and metadata
    - ResourceType: Helper class for resource type sorting

    Converted from AngelScript to Lua
--]]

-- Global variables
browserWindow = nil
browserFilterWindow = nil
browserDirList = nil
browserFileList = nil
browserSearch = nil
browserDragFile = nil
browserDragNode = nil
browserDragComponent = nil
resourceBrowserPreview = nil
resourcePreviewScene = nil
resourcePreviewNode = nil
resourcePreviewCameraNode = nil
resourcePreviewLightNode = nil
resourcePreviewLight = nil
browserSearchSortMode = 0

rootDir = nil
browserFiles = {}
browserDirs = {}
activeResourceTypeFilters = {}
activeResourceDirFilters = {}

browserFilesToScan = {}
local BROWSER_WORKER_ITEMS_PER_TICK = 10
local BROWSER_SEARCH_LIMIT = 50
local BROWSER_SORT_MODE_ALPHA = 1
local BROWSER_SORT_MODE_SEARCH = 2

-- Resource type constants
local RESOURCE_TYPE_UNUSABLE = -2
local RESOURCE_TYPE_UNKNOWN = -1
local RESOURCE_TYPE_NOTSET = 0
local RESOURCE_TYPE_SCENE = 1
local RESOURCE_TYPE_SCRIPTFILE = 2
local RESOURCE_TYPE_MODEL = 3
local RESOURCE_TYPE_MATERIAL = 4
local RESOURCE_TYPE_ANIMATION = 5
local RESOURCE_TYPE_IMAGE = 6
local RESOURCE_TYPE_SOUND = 7
local RESOURCE_TYPE_TEXTURE = 8
local RESOURCE_TYPE_FONT = 9
local RESOURCE_TYPE_PREFAB = 10
local RESOURCE_TYPE_TECHNIQUE = 11
local RESOURCE_TYPE_PARTICLEEFFECT = 12
local RESOURCE_TYPE_UIELEMENT = 13
local RESOURCE_TYPE_UIELEMENTS = 14
local RESOURCE_TYPE_ANIMATION_SETTINGS = 15
local RESOURCE_TYPE_RENDERPATH = 16
local RESOURCE_TYPE_TEXTURE_ATLAS = 17
local RESOURCE_TYPE_2D_PARTICLE_EFFECT = 18
local RESOURCE_TYPE_TEXTURE_3D = 19
local RESOURCE_TYPE_CUBEMAP = 20
local RESOURCE_TYPE_PARTICLEEMITTER = 21
local RESOURCE_TYPE_2D_ANIMATION_SET = 22
local RESOURCE_TYPE_GENERIC_XML = 23
local RESOURCE_TYPE_GENERIC_JSON = 24

local NUMBER_OF_VALID_RESOURCE_TYPES = 24

-- Type identification constants (using strings instead of StringHash)
local XML_TYPE_SCENE = "scene"
local XML_TYPE_NODE = "node"
local XML_TYPE_MATERIAL = "material"
local XML_TYPE_TECHNIQUE = "technique"
local XML_TYPE_PARTICLEEFFECT = "particleeffect"
local XML_TYPE_PARTICLEEMITTER = "particleemitter"
local XML_TYPE_TEXTURE = "texture"
local XML_TYPE_ELEMENT = "element"
local XML_TYPE_ELEMENTS = "elements"
local XML_TYPE_ANIMATION_SETTINGS = "animation"
local XML_TYPE_RENDERPATH = "renderpath"
local XML_TYPE_TEXTURE_ATLAS = "TextureAtlas"
local XML_TYPE_2D_PARTICLE_EFFECT = "particleEmitterConfig"
local XML_TYPE_TEXTURE_3D = "texture3d"
local XML_TYPE_CUBEMAP = "cubemap"
local XML_TYPE_SPRITER_DATA = "spriter_data"
local XML_TYPE_GENERIC = "xml"

local JSON_TYPE_SCENE = "scene"
local JSON_TYPE_NODE = "node"
local JSON_TYPE_MATERIAL = "material"
local JSON_TYPE_TECHNIQUE = "technique"
local JSON_TYPE_PARTICLEEFFECT = "particleeffect"
local JSON_TYPE_PARTICLEEMITTER = "particleemitter"
local JSON_TYPE_TEXTURE = "texture"
local JSON_TYPE_ELEMENT = "element"
local JSON_TYPE_ELEMENTS = "elements"
local JSON_TYPE_ANIMATION_SETTINGS = "animation"
local JSON_TYPE_RENDERPATH = "renderpath"
local JSON_TYPE_TEXTURE_ATLAS = "TextureAtlas"
local JSON_TYPE_2D_PARTICLE_EFFECT = "particleEmitterConfig"
local JSON_TYPE_TEXTURE_3D = "texture3d"
local JSON_TYPE_CUBEMAP = "cubemap"
local JSON_TYPE_SPRITER_DATA = "spriter_data"
local JSON_TYPE_GENERIC = "json"

local BINARY_TYPE_SCENE = "USCN"
local BINARY_TYPE_PACKAGE = "UPAK"
local BINARY_TYPE_COMPRESSED_PACKAGE = "ULZ4"
local BINARY_TYPE_ANGELSCRIPT = "ASBC"
local BINARY_TYPE_MODEL = "UMDL"
local BINARY_TYPE_MODEL2 = "UMD2"
local BINARY_TYPE_SHADER = "USHD"
local BINARY_TYPE_ANIMATION = "UANI"

local EXTENSION_TYPE_TTF = ".ttf"
local EXTENSION_TYPE_OTF = ".otf"
local EXTENSION_TYPE_OGG = ".ogg"
local EXTENSION_TYPE_WAV = ".wav"
local EXTENSION_TYPE_DDS = ".dds"
local EXTENSION_TYPE_PNG = ".png"
local EXTENSION_TYPE_JPG = ".jpg"
local EXTENSION_TYPE_JPEG = ".jpeg"
local EXTENSION_TYPE_HDR = ".hdr"
local EXTENSION_TYPE_BMP = ".bmp"
local EXTENSION_TYPE_TGA = ".tga"
local EXTENSION_TYPE_KTX = ".ktx"
local EXTENSION_TYPE_PVR = ".pvr"
local EXTENSION_TYPE_OBJ = ".obj"
local EXTENSION_TYPE_FBX = ".fbx"
local EXTENSION_TYPE_COLLADA = ".dae"
local EXTENSION_TYPE_BLEND = ".blend"
local EXTENSION_TYPE_ANGELSCRIPT = ".as"
local EXTENSION_TYPE_LUASCRIPT = ".lua"
local EXTENSION_TYPE_HLSL = ".hlsl"
local EXTENSION_TYPE_GLSL = ".glsl"
local EXTENSION_TYPE_FRAGMENTSHADER = ".frag"
local EXTENSION_TYPE_VERTEXSHADER = ".vert"
local EXTENSION_TYPE_HTML = ".html"

-- Variable name constants
local TEXT_VAR_FILE_ID = "browser_file_id"
local TEXT_VAR_DIR_ID = "browser_dir_id"
local TEXT_VAR_RESOURCE_TYPE = "resource_type"
local TEXT_VAR_RESOURCE_DIR_ID = "resource_dir_id"

local BROWSER_FILE_SOURCE_RESOURCE_DIR = 1

-- Global state variables
local browserDirIndex = 1
local browserFileIndex = 1
local selectedBrowserDirectory = nil
local selectedBrowserFile = nil
local browserStatusMessage = nil
local browserResultsMessage = nil
local ignoreRefreshBrowserResults = false
local resourceDirsCache = ""

-- ==================== Main Functions ====================

function CreateResourceBrowser()
    if browserWindow ~= nil then
        return
    end

    CreateResourceBrowserUI()
    InitResourceBrowserPreview()
    RebuildResourceDatabase()
end

function RebuildResourceDatabase()
    if browserWindow == nil then
        return
    end

    local newResourceDirsCache = table.concat(cache.resourceDirs, ";")
    ScanResourceDirectories()
    if newResourceDirsCache ~= resourceDirsCache then
        resourceDirsCache = newResourceDirsCache
        PopulateResourceDirFilters()
    end
    PopulateBrowserDirectories()
    PopulateResourceBrowserFilesByDirectory(rootDir)
end

function ScanResourceDirectories()
    browserDirs = {}
    browserFiles = {}
    browserFilesToScan = {}

    rootDir = BrowserDir:new("")
    browserDirs[""] = rootDir

    -- Collect all items and sort them afterwards
    for i = 1, #cache.resourceDirs do
        if not TableContains(activeResourceDirFilters, i - 1) then
            ScanResourceDir(i - 1)
        end
    end
end

-- Worker function to process file type detection without blocking UI
function DoResourceBrowserWork()
    if #browserFilesToScan == 0 then
        return
    end

    local counter = 0
    local scanItem = browserFilesToScan[1]
    while counter < BROWSER_WORKER_ITEMS_PER_TICK do
        scanItem:DetermainResourceType()

        -- Next item
        table.remove(browserFilesToScan, 1)
        if #browserFilesToScan > 0 then
            scanItem = browserFilesToScan[1]
        else
            break
        end
        counter = counter + 1
    end

    if #browserFilesToScan > 0 then
        browserStatusMessage.text = localization:Get("Files left to scan: ") .. #browserFilesToScan
    else
        browserStatusMessage.text = localization:Get("Scan complete")
    end
end

function CreateResourceBrowserUI()
    browserWindow = LoadEditorUI("UI/EditorResourceBrowser.xml")
    browserDirList = browserWindow:GetChild("DirectoryList", true)
    browserFileList = browserWindow:GetChild("FileList", true)
    browserSearch = browserWindow:GetChild("Search", true)
    browserStatusMessage = browserWindow:GetChild("StatusMessage", true)
    browserResultsMessage = browserWindow:GetChild("ResultsMessage", true)
    browserWindow.opacity = uiMaxOpacity

    browserFilterWindow = LoadEditorUI("UI/EditorResourceFilterWindow.xml")
    CreateResourceFilterUI()
    HideResourceFilterWindow()

    local height = math.min(ui.root.height / 4, 300)
    browserWindow:SetSize(900, height)
    browserWindow:SetPosition(35, ui.root.height - height - 25)

    CloseContextMenu()
    ui.root:AddChild(browserWindow)
    ui.root:AddChild(browserFilterWindow)

    SubscribeToEvent(browserWindow:GetChild("CloseButton", true), "Released", "HideResourceBrowserWindow")
    SubscribeToEvent(browserWindow:GetChild("RescanButton", true), "Released", "HandleRescanResourceBrowserClick")
    SubscribeToEvent(browserWindow:GetChild("FilterButton", true), "Released", "ToggleResourceFilterWindow")
    SubscribeToEvent(browserDirList, "SelectionChanged", "HandleResourceBrowserDirListSelectionChange")
    SubscribeToEvent(browserSearch, "TextChanged", "HandleResourceBrowserSearchTextChange")
    SubscribeToEvent(browserFileList, "ItemClicked", "HandleBrowserFileClick")
    SubscribeToEvent(browserFileList, "SelectionChanged", "HandleResourceBrowserFileListSelectionChange")
    SubscribeToEvent(cache, "FileChanged", "HandleFileChanged")
end

function CreateResourceFilterUI()
    local toggleAllTypes = browserFilterWindow:GetChild("ToggleAllTypes", true)
    local toggleAllResourceDirs = browserFilterWindow:GetChild("ToggleAllResourceDirs", true)
    SubscribeToEvent(toggleAllTypes, "Toggled", "HandleResourceTypeFilterToggleAllTypesToggled")
    SubscribeToEvent(toggleAllResourceDirs, "Toggled", "HandleResourceDirFilterToggleAllTypesToggled")
    SubscribeToEvent(browserFilterWindow:GetChild("CloseButton", true), "Released", "HideResourceFilterWindow")

    local columns = 2
    local col1 = browserFilterWindow:GetChild("TypeFilterColumn1", true)
    local col2 = browserFilterWindow:GetChild("TypeFilterColumn2", true)

    -- Use array to sort items
    local sorted = {}
    for i = 1, NUMBER_OF_VALID_RESOURCE_TYPES do
        table.insert(sorted, ResourceType:new(i, ResourceTypeName(i)))
    end

    -- 2 unknown types are reserved for the top, the rest are alphabetized
    table.sort(sorted, function(a, b) return a:opCmp(b) < 0 end)
    table.insert(sorted, 1, ResourceType:new(RESOURCE_TYPE_UNKNOWN, ResourceTypeName(RESOURCE_TYPE_UNKNOWN)))
    table.insert(sorted, 1, ResourceType:new(RESOURCE_TYPE_UNUSABLE, ResourceTypeName(RESOURCE_TYPE_UNUSABLE)))
    local halfColumns = math.ceil(#sorted / columns)

    for i = 1, #sorted do
        local type = sorted[i]
        local resourceTypeHolder = UIElement:new()
        if i <= halfColumns then
            col1:AddChild(resourceTypeHolder)
        else
            col2:AddChild(resourceTypeHolder)
        end

        resourceTypeHolder.layoutMode = LM_HORIZONTAL
        resourceTypeHolder.layoutSpacing = 4

        local label = Text:new()
        label:SetStyle("EditorAttributeText")
        label.text = type.name
        local checkbox = CheckBox:new()
        checkbox.name = tostring(type.id)
        checkbox:SetStyleAuto()
        checkbox:SetVar(TEXT_VAR_RESOURCE_TYPE, Variant(i - 1))
        checkbox.checked = true
        SubscribeToEvent(checkbox, "Toggled", "HandleResourceTypeFilterToggled")

        resourceTypeHolder:AddChild(checkbox)
        resourceTypeHolder:AddChild(label)
    end
end

function CreateDirList(dir, parentUI)
    local dirText = Text:new()
    browserDirList:InsertItem(browserDirList.numItems, dirText, parentUI)
    dirText:SetStyle("FileSelectorListText")
    dirText.text = (#dir.resourceKey == 0) and localization:Get("Root") or dir.name
    dirText.name = dir.resourceKey
    dirText:SetVar(TEXT_VAR_DIR_ID, Variant(dir.resourceKey))

    -- Sort directories alphabetically
    browserSearchSortMode = BROWSER_SORT_MODE_ALPHA
    table.sort(dir.children, function(a, b) return a:opCmp(b) < 0 end)

    for i = 1, #dir.children do
        CreateDirList(dir.children[i], dirText)
    end
end

function CreateFileList(file)
    local fileText = Text:new()
    fileText:SetStyle("FileSelectorListText")
    fileText.layoutMode = LM_HORIZONTAL
    browserFileList:InsertItem(browserFileList.numItems, fileText)
    file.browserFileListRow = fileText
    InitializeBrowserFileListRow(fileText, file)
end

function InitializeBrowserFileListRow(fileText, file)
    fileText:RemoveAllChildren()
    fileText:SetVar(TEXT_VAR_FILE_ID, Variant(file.id))
    fileText:SetVar(TEXT_VAR_RESOURCE_TYPE, Variant(file.resourceType))
    if file.resourceType > 0 then
        fileText.dragDropMode = DD_SOURCE
    end

    do
        local text = Text:new()
        fileText:AddChild(text)
        text:SetStyle("FileSelectorListText")
        text.text = file.fullname
        text.name = file.resourceKey
    end

    do
        local text = Text:new()
        fileText:AddChild(text)
        text:SetStyle("FileSelectorListText")
        text.text = file:ResourceTypeName()
    end

    if file.resourceType == RESOURCE_TYPE_MATERIAL or
       file.resourceType == RESOURCE_TYPE_MODEL or
       file.resourceType == RESOURCE_TYPE_PARTICLEEFFECT or
       file.resourceType == RESOURCE_TYPE_PREFAB then
        SubscribeToEvent(fileText, "DragBegin", "HandleBrowserFileDragBegin")
        SubscribeToEvent(fileText, "DragEnd", "HandleBrowserFileDragEnd")
    end
end

function InitResourceBrowserPreview()
    resourcePreviewScene = Scene("PreviewScene")
    resourcePreviewScene:CreateComponent("Octree")
    local physicsWorld = resourcePreviewScene:CreateComponent("PhysicsWorld")
    physicsWorld.enabled = false
    physicsWorld.gravity = Vector3(0.0, 0.0, 0.0)

    local zoneNode = resourcePreviewScene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000, 1000)
    zone.ambientColor = Color(0.15, 0.15, 0.15)
    zone.fogColor = Color(0, 0, 0)
    zone.fogStart = 10.0
    zone.fogEnd = 100.0

    resourcePreviewCameraNode = resourcePreviewScene:CreateChild("PreviewCamera")
    resourcePreviewCameraNode.position = Vector3(0, 0, -1.5)
    local camera = resourcePreviewCameraNode:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 100.0

    resourcePreviewLightNode = resourcePreviewScene:CreateChild("PreviewLight")
    resourcePreviewLightNode.direction = Vector3(0.5, -0.5, 0.5)
    resourcePreviewLight = resourcePreviewLightNode:CreateComponent("Light")
    resourcePreviewLight.lightType = LIGHT_DIRECTIONAL
    resourcePreviewLight.specularIntensity = 0.5

    resourceBrowserPreview = browserWindow:GetChild("ResourceBrowserPreview", true)
    resourceBrowserPreview:SetFixedHeight(200)
    resourceBrowserPreview:SetFixedWidth(266)
    resourceBrowserPreview:SetView(resourcePreviewScene, camera)
    resourceBrowserPreview.autoUpdate = false

    resourcePreviewNode = resourcePreviewScene:CreateChild("PreviewNodeContainer")

    SubscribeToEvent(resourceBrowserPreview, "DragMove", "RotateResourceBrowserPreview")

    RefreshBrowserPreview()
end

-- ==================== Event Handlers ====================

-- Opens a contextual menu based on what resource item was actioned
function HandleBrowserFileClick(eventType, eventData)
    if eventData["Button"]:GetInt() ~= MOUSEB_RIGHT then
        return
    end

    local uiElement = eventData["Item"]:GetPtr()
    local file = GetBrowserFileFromUIElement(uiElement)

    if file == nil then
        return
    end

    local actions = {}
    if file.resourceType == RESOURCE_TYPE_MATERIAL then
        table.insert(actions, CreateBrowserFileActionMenu("Edit", "HandleBrowserEditResource", file))
    elseif file.resourceType == RESOURCE_TYPE_MODEL then
        table.insert(actions, CreateBrowserFileActionMenu("Instance Animated Model", "HandleBrowserInstantiateAnimatedModel", file))
        table.insert(actions, CreateBrowserFileActionMenu("Instance Static Model", "HandleBrowserInstantiateStaticModel", file))
    elseif file.resourceType == RESOURCE_TYPE_PREFAB then
        table.insert(actions, CreateBrowserFileActionMenu("Instance Prefab", "HandleBrowserInstantiatePrefab", file))
        table.insert(actions, CreateBrowserFileActionMenu("Instance in Spawner", "HandleBrowserInstantiateInSpawnEditor", file))
    elseif file.fileType == EXTENSION_TYPE_OBJ or
           file.fileType == EXTENSION_TYPE_COLLADA or
           file.fileType == EXTENSION_TYPE_FBX or
           file.fileType == EXTENSION_TYPE_BLEND then
        table.insert(actions, CreateBrowserFileActionMenu("Import Model", "HandleBrowserImportModel", file))
        table.insert(actions, CreateBrowserFileActionMenu("Import Scene", "HandleBrowserImportScene", file))
    elseif file.resourceType == RESOURCE_TYPE_UIELEMENT then
        table.insert(actions, CreateBrowserFileActionMenu("Open UI Layout", "HandleBrowserOpenUILayout", file))
    elseif file.resourceType == RESOURCE_TYPE_SCENE then
        table.insert(actions, CreateBrowserFileActionMenu("Load Scene", "HandleBrowserLoadScene", file))
    elseif file.resourceType == RESOURCE_TYPE_SCRIPTFILE then
        table.insert(actions, CreateBrowserFileActionMenu("Execute Script", "HandleBrowserRunScript", file))
    elseif file.resourceType == RESOURCE_TYPE_PARTICLEEFFECT then
        table.insert(actions, CreateBrowserFileActionMenu("Edit", "HandleBrowserEditResource", file))
    end

    table.insert(actions, CreateBrowserFileActionMenu("Open", "HandleBrowserOpenResource", file))

    ActivateContextMenu(actions)
end

function GetBrowserDir(path)
    return browserDirs[path]
end

-- Makes sure the entire directory tree exists and new dir is linked to parent
function InitBrowserDir(path)
    local browserDir = browserDirs[path]
    if browserDir ~= nil then
        return browserDir
    end

    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        table.insert(parts, part)
    end

    local finishedParts = {}
    if #parts > 0 then
        local parent = rootDir
        for i = 1, #parts do
            table.insert(finishedParts, parts[i])
            local currentPath = table.concat(finishedParts, "/")
            browserDir = browserDirs[currentPath]
            if browserDir == nil then
                browserDir = BrowserDir:new(currentPath)
                browserDirs[currentPath] = browserDir
                table.insert(parent.children, browserDir)
            end
            parent = browserDir
        end
        return browserDir
    end
    return nil
end

function ScanResourceDir(resourceDirIndex)
    local resourceDir = cache.resourceDirs[resourceDirIndex + 1]
    ScanResourceDirFiles("", resourceDirIndex)
    local dirs = fileSystem:ScanDir(resourceDir, "*", SCAN_DIRS, true)
    for i = 1, #dirs do
        local path = dirs[i]
        if not string.match(path, "%.$") then
            InitBrowserDir(path)
            ScanResourceDirFiles(path, resourceDirIndex)
        end
    end
end

function ScanResourceDirFiles(path, resourceDirIndex)
    local fullPath = cache.resourceDirs[resourceDirIndex + 1] .. path
    if not fileSystem:DirExists(fullPath) then
        return
    end

    local dir = GetBrowserDir(path)
    if dir == nil then
        return
    end

    -- Get files in directory
    local dirFiles = fileSystem:ScanDir(fullPath, "*.*", SCAN_FILES, false)

    -- Add new files
    for x = 1, #dirFiles do
        local filename = dirFiles[x]
        local browserFile = dir:AddFile(filename, resourceDirIndex, BROWSER_FILE_SOURCE_RESOURCE_DIR)
        table.insert(browserFiles, browserFile)
        table.insert(browserFilesToScan, browserFile)
    end
end

function ToggleResourceBrowserWindow()
    if browserWindow.visible == false then
        ShowResourceBrowserWindow()
    else
        HideResourceBrowserWindow()
    end
    return true
end

function ShowResourceBrowserWindow()
    browserWindow.visible = true
    browserWindow:BringToFront()
    ui.focusElement = browserSearch
end

function HideResourceBrowserWindow()
    browserWindow.visible = false
end

function ToggleResourceFilterWindow()
    if browserFilterWindow.visible then
        HideResourceFilterWindow()
    else
        ShowResourceFilterWindow()
    end
end

function HideResourceFilterWindow()
    browserFilterWindow.visible = false
end

function ShowResourceFilterWindow()
    local x = browserWindow.position.x + browserWindow.width - browserFilterWindow.width
    local y = browserWindow.position.y - browserFilterWindow.height - 1
    browserFilterWindow.position = IntVector2(x, y)
    browserFilterWindow.visible = true
    browserFilterWindow:BringToFront()
end

function PopulateResourceDirFilters()
    local resourceDirs = browserFilterWindow:GetChild("DirFilters", true)
    resourceDirs:RemoveAllChildren()
    activeResourceDirFilters = {}
    for i = 1, #cache.resourceDirs do
        local resourceDirHolder = UIElement:new()
        resourceDirs:AddChild(resourceDirHolder)
        resourceDirHolder.layoutMode = LM_HORIZONTAL
        resourceDirHolder.layoutSpacing = 4
        resourceDirHolder:SetFixedHeight(16)

        local label = Text:new()
        label:SetStyle("EditorAttributeText")
        local resourceDir = cache.resourceDirs[i] or ""
        local programDir = fileSystem.programDir or ""
        label.text = string.gsub(resourceDir, programDir, "")
        local checkbox = CheckBox:new()
        checkbox.name = tostring(i - 1)
        checkbox:SetStyleAuto()
        checkbox:SetVar(TEXT_VAR_RESOURCE_DIR_ID, Variant(i - 1))
        checkbox.checked = true
        SubscribeToEvent(checkbox, "Toggled", "HandleResourceDirFilterToggled")

        resourceDirHolder:AddChild(checkbox)
        resourceDirHolder:AddChild(label)
    end
end

function PopulateBrowserDirectories()
    browserDirList:RemoveAllItems()
    CreateDirList(rootDir)
    browserDirList.selection = 0
end

function PopulateResourceBrowserFilesByDirectory(dir)
    selectedBrowserDirectory = dir
    browserFileList:RemoveAllItems()
    if dir == nil then
        return
    end

    local files = {}
    for x = 1, #dir.files do
        local file = dir.files[x]
        if not TableContains(activeResourceTypeFilters, file.resourceType) then
            table.insert(files, file)
        end
    end

    -- Sort alphabetically
    browserSearchSortMode = BROWSER_SORT_MODE_ALPHA
    table.sort(files, function(a, b) return a:opCmp(b) < 0 end)
    PopulateResourceBrowserResults(files)
    browserResultsMessage.text = localization:Get("Showing files: ") .. #files
end

function PopulateResourceBrowserBySearch()
    local query = browserSearch.text

    local scores = {}
    local scored = {}
    local filtered = {}

    for x = 1, #browserFiles do
        local file = browserFiles[x]
        file.sortScore = -1
        if not TableContains(activeResourceTypeFilters, file.resourceType) and
           not TableContains(activeResourceDirFilters, file.resourceSourceIndex) then
            local find = string.find(string.lower(file.fullname), string.lower(query), 1, true)
            if find ~= nil then
                local fudge = #query - #file.fullname
                local score = find * math.abs(fudge * 2) + math.abs(fudge)
                file.sortScore = score
                table.insert(scored, file)
                table.insert(scores, score)
            end
        end
    end

    -- Cut down for faster sort
    if #scored > BROWSER_SEARCH_LIMIT then
        table.sort(scores)
        local scoreThreshold = scores[BROWSER_SEARCH_LIMIT]
        for x = 1, #scored do
            local file = scored[x]
            if file.sortScore <= scoreThreshold then
                table.insert(filtered, file)
            end
        end
    else
        filtered = scored
    end

    browserSearchSortMode = BROWSER_SORT_MODE_ALPHA
    table.sort(filtered, function(a, b) return a:opCmp(b) < 0 end)
    PopulateResourceBrowserResults(filtered)
    browserResultsMessage.text = "Showing top " .. #filtered .. " of " .. #scored .. " results"
end

function PopulateResourceBrowserResults(files)
    browserFileList:RemoveAllItems()
    for i = 1, #files do
        CreateFileList(files[i])
    end
end

function RefreshBrowserResults()
    if #browserSearch.text == 0 then
        browserDirList.visible = true
        PopulateResourceBrowserFilesByDirectory(selectedBrowserDirectory)
    else
        browserDirList.visible = false
        PopulateResourceBrowserBySearch()
    end
end

function HandleResourceTypeFilterToggleAllTypesToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr()
    local filterHolder = browserFilterWindow:GetChild("TypeFilters", true)
    local children = filterHolder:GetChildren(true)

    ignoreRefreshBrowserResults = true
    for i = 1, #children do
        local filter = tolua.cast(children[i], "CheckBox")
        if filter ~= nil then
            filter.checked = checkbox.checked
        end
    end
    ignoreRefreshBrowserResults = false
    RefreshBrowserResults()
end

function HandleResourceTypeFilterToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr()
    local resourceTypeVar = checkbox:GetVar(TEXT_VAR_RESOURCE_TYPE)
    if resourceTypeVar:IsEmpty() then
        return
    end

    local resourceType = resourceTypeVar:GetInt()
    local find = TableFind(activeResourceTypeFilters, resourceType)

    if checkbox.checked and find ~= -1 then
        table.remove(activeResourceTypeFilters, find)
    elseif not checkbox.checked and find == -1 then
        table.insert(activeResourceTypeFilters, resourceType)
    end

    if not ignoreRefreshBrowserResults then
        RefreshBrowserResults()
    end
end

function HandleResourceDirFilterToggleAllTypesToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr()
    local filterHolder = browserFilterWindow:GetChild("DirFilters", true)
    local children = filterHolder:GetChildren(true)

    ignoreRefreshBrowserResults = true
    for i = 1, #children do
        local filter = tolua.cast(children[i], "CheckBox")
        if filter ~= nil then
            filter.checked = checkbox.checked
        end
    end
    ignoreRefreshBrowserResults = false
    RebuildResourceDatabase()
end

function HandleResourceDirFilterToggled(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr()
    local resourceDirVar = checkbox:GetVar(TEXT_VAR_RESOURCE_DIR_ID)
    if resourceDirVar:IsEmpty() then
        return
    end

    local resourceDir = resourceDirVar:GetInt()
    local find = TableFind(activeResourceDirFilters, resourceDir)

    if checkbox.checked and find ~= -1 then
        table.remove(activeResourceDirFilters, find)
    elseif not checkbox.checked and find == -1 then
        table.insert(activeResourceDirFilters, resourceDir)
    end

    if not ignoreRefreshBrowserResults then
        RebuildResourceDatabase()
    end
end

function HandleRescanResourceBrowserClick(eventType, eventData)
    RebuildResourceDatabase()
end

function HandleResourceBrowserDirListSelectionChange(eventType, eventData)
    if browserDirList.selection == M_MAX_UNSIGNED then
        return
    end

    local uiElement = browserDirList:GetItem(browserDirList.selection)
    local dir = GetBrowserDir(uiElement:GetVar(TEXT_VAR_DIR_ID):GetString())
    if dir == nil then
        return
    end

    PopulateResourceBrowserFilesByDirectory(dir)
end

function HandleResourceBrowserFileListSelectionChange(eventType, eventData)
    if browserFileList.selection == M_MAX_UNSIGNED then
        return
    end

    local uiElement = browserFileList:GetItem(browserFileList.selection)
    local file = GetBrowserFileFromUIElement(uiElement)
    if file == nil then
        return
    end

    if resourcePreviewNode ~= nil then
        resourcePreviewNode:Remove()
    end

    resourcePreviewNode = resourcePreviewScene:CreateChild("PreviewNodeContainer")
    CreateResourcePreview(file:GetFullPath(), resourcePreviewNode)

    if resourcePreviewNode ~= nil then
        local boxes = {}
        local staticModels = resourcePreviewNode:GetComponents("StaticModel", true)
        local animatedModels = resourcePreviewNode:GetComponents("AnimatedModel", true)

        for i = 1, #staticModels do
            table.insert(boxes, tolua.cast(staticModels[i], "StaticModel").worldBoundingBox)
        end

        for i = 1, #animatedModels do
            table.insert(boxes, tolua.cast(animatedModels[i], "AnimatedModel").worldBoundingBox)
        end

        if #boxes > 0 then
            local camPosition = Vector3(0.0, 0.0, -1.2)
            local biggestBox = boxes[1]
            for i = 2, #boxes do
                if boxes[i].size.length > biggestBox.size.length then
                    biggestBox = boxes[i]
                end
            end
            resourcePreviewCameraNode.position = biggestBox.center + camPosition * biggestBox.size.length
        end

        resourcePreviewScene:AddChild(resourcePreviewNode)
        RefreshBrowserPreview()
    end
end

function HandleResourceBrowserSearchTextChange(eventType, eventData)
    RefreshBrowserResults()
end

function GetBrowserFileFromId(id)
    if id == 0 then
        return nil
    end

    for i = 1, #browserFiles do
        local file = browserFiles[i]
        if file.id == id then
            return file
        end
    end
    return nil
end

function GetBrowserFileFromUIElement(element)
    if element == nil then
        return nil
    end
    local fileIdVar = element:GetVar(TEXT_VAR_FILE_ID)
    if fileIdVar:IsEmpty() then
        return nil
    end
    return GetBrowserFileFromId(fileIdVar:GetUInt())
end

function GetBrowserFileFromPath(path)
    for i = 1, #browserFiles do
        local file = browserFiles[i]
        if path == file:GetFullPath() then
            return file
        end
    end
    return nil
end

function HandleBrowserEditResource(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file == nil then
        return
    end

    if file.resourceType == RESOURCE_TYPE_MATERIAL then
        local material = cache:GetResource("Material", file.resourceKey)
        if material ~= nil then
            EditMaterial(material)
        end
    end

    if file.resourceType == RESOURCE_TYPE_PARTICLEEFFECT then
        local particleEffect = cache:GetResource("ParticleEffect", file.resourceKey)
        if particleEffect ~= nil then
            EditParticleEffect(particleEffect)
        end
    end
end

function HandleBrowserOpenResource(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        OpenResource(file.resourceKey)
    end
end

function HandleBrowserImportScene(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        ImportScene(file:GetFullPath())
    end
end

function HandleBrowserImportModel(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        ImportModel(file:GetFullPath())
    end
end

function HandleBrowserOpenUILayout(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        OpenUILayout(file:GetFullPath())
    end
end

function HandleBrowserInstantiateStaticModel(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        CreateModelWithStaticModel(file.resourceKey, editNode)
    end
end

function HandleBrowserInstantiateAnimatedModel(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        CreateModelWithAnimatedModel(file.resourceKey, editNode)
    end
end

function HandleBrowserInstantiatePrefab(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        LoadNode(file:GetFullPath())
    end
end

function HandleBrowserInstantiateInSpawnEditor(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        spawnedObjectsNames = {}
        spawnedObjectsNames[1] = VerifySpawnedObjectFile(file:GetPath())
        RefreshPickedObjects()
        ShowSpawnEditor()
    end
end

function HandleBrowserLoadScene(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        LoadScene(file:GetFullPath())
    end
end

function HandleBrowserRunScript(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    local file = GetBrowserFileFromUIElement(element)
    if file ~= nil then
        ExecuteScript(ExtractFileName(eventData))
    end
end

function HandleBrowserFileDragBegin(eventType, eventData)
    local uiElement = eventData["Element"]:GetPtr()
    browserDragFile = GetBrowserFileFromUIElement(uiElement)
end

function HandleBrowserFileDragEnd(eventType, eventData)
    if browserDragFile == nil then
        return
    end

    local element = ui:GetElementAt(ui.cursor.screenPosition)
    if element ~= nil then
        return
    end

    if browserDragFile.resourceType == RESOURCE_TYPE_MATERIAL then
        local model = tolua.cast(GetDrawableAtMousePostion(), "StaticModel")
        if model ~= nil then
            AssignMaterial(model, browserDragFile.resourceKey)
        end
    elseif browserDragFile.resourceType == RESOURCE_TYPE_PREFAB then
        LoadNode(browserDragFile:GetFullPath(), nil, true)
    elseif browserDragFile.resourceType == RESOURCE_TYPE_MODEL then
        local createdNode = CreateNode(REPLICATED, true)
        local model = cache:GetResource("Model", browserDragFile.resourceKey)
        if model.skeleton.numBones > 0 then
            local am = createdNode:CreateComponent("AnimatedModel")
            am.model = model
        else
            local sm = createdNode:CreateComponent("StaticModel")
            sm.model = model
        end

        AdjustNodePositionByAABB(createdNode)
    end

    browserDragFile = nil
    browserDragComponent = nil
    browserDragNode = nil
end

function HandleFileChanged(eventType, eventData)
    local filename = eventData["FileName"]:GetString()
    local file = GetBrowserFileFromPath(filename)

    if file == nil then
        -- TODO: new file logic when watchers are supported
        return
    else
        file:FileChanged()
    end
end

function CreateBrowserFileActionMenu(text, handler, browserFile)
    local menu = CreateContextMenuItem(text, handler)
    if browserFile ~= nil then
        menu:SetVar(TEXT_VAR_FILE_ID, Variant(browserFile.id))
    end
    return menu
end

-- ==================== Resource Type Detection ====================

function GetResourceType(path, fileTypeOut, useCache)
    if useCache == nil then useCache = false end

    local fileType = {}
    if GetExtensionType(path, fileType) or GetBinaryType(path, fileType, useCache) or GetXmlType(path, fileType, useCache) then
        if fileTypeOut ~= nil then
            fileTypeOut[1] = fileType[1]
        end
        return GetResourceTypeFromFileType(fileType[1])
    end

    return RESOURCE_TYPE_UNKNOWN
end

function GetResourceTypeFromFileType(fileType)
    -- Binary filetypes
    if fileType == BINARY_TYPE_SCENE then
        return RESOURCE_TYPE_SCENE
    elseif fileType == BINARY_TYPE_PACKAGE then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == BINARY_TYPE_COMPRESSED_PACKAGE then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == BINARY_TYPE_ANGELSCRIPT then
        return RESOURCE_TYPE_SCRIPTFILE
    elseif fileType == BINARY_TYPE_MODEL or fileType == BINARY_TYPE_MODEL2 then
        return RESOURCE_TYPE_MODEL
    elseif fileType == BINARY_TYPE_SHADER then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == BINARY_TYPE_ANIMATION then
        return RESOURCE_TYPE_ANIMATION

    -- XML filetypes
    elseif fileType == XML_TYPE_SCENE then
        return RESOURCE_TYPE_SCENE
    elseif fileType == XML_TYPE_NODE then
        return RESOURCE_TYPE_PREFAB
    elseif fileType == XML_TYPE_MATERIAL then
        return RESOURCE_TYPE_MATERIAL
    elseif fileType == XML_TYPE_TECHNIQUE then
        return RESOURCE_TYPE_TECHNIQUE
    elseif fileType == XML_TYPE_PARTICLEEFFECT then
        return RESOURCE_TYPE_PARTICLEEFFECT
    elseif fileType == XML_TYPE_PARTICLEEMITTER then
        return RESOURCE_TYPE_PARTICLEEMITTER
    elseif fileType == XML_TYPE_TEXTURE then
        return RESOURCE_TYPE_TEXTURE
    elseif fileType == XML_TYPE_ELEMENT then
        return RESOURCE_TYPE_UIELEMENT
    elseif fileType == XML_TYPE_ELEMENTS then
        return RESOURCE_TYPE_UIELEMENTS
    elseif fileType == XML_TYPE_ANIMATION_SETTINGS then
        return RESOURCE_TYPE_ANIMATION_SETTINGS
    elseif fileType == XML_TYPE_RENDERPATH then
        return RESOURCE_TYPE_RENDERPATH
    elseif fileType == XML_TYPE_TEXTURE_ATLAS then
        return RESOURCE_TYPE_TEXTURE_ATLAS
    elseif fileType == XML_TYPE_2D_PARTICLE_EFFECT then
        return RESOURCE_TYPE_2D_PARTICLE_EFFECT
    elseif fileType == XML_TYPE_TEXTURE_3D then
        return RESOURCE_TYPE_TEXTURE_3D
    elseif fileType == XML_TYPE_CUBEMAP then
        return RESOURCE_TYPE_CUBEMAP
    elseif fileType == XML_TYPE_SPRITER_DATA then
        return RESOURCE_TYPE_2D_ANIMATION_SET
    elseif fileType == XML_TYPE_GENERIC then
        return RESOURCE_TYPE_GENERIC_XML

    -- JSON filetypes
    elseif fileType == JSON_TYPE_SCENE then
        return RESOURCE_TYPE_SCENE
    elseif fileType == JSON_TYPE_NODE then
        return RESOURCE_TYPE_PREFAB
    elseif fileType == JSON_TYPE_MATERIAL then
        return RESOURCE_TYPE_MATERIAL
    elseif fileType == JSON_TYPE_TECHNIQUE then
        return RESOURCE_TYPE_TECHNIQUE
    elseif fileType == JSON_TYPE_PARTICLEEFFECT then
        return RESOURCE_TYPE_PARTICLEEFFECT
    elseif fileType == JSON_TYPE_PARTICLEEMITTER then
        return RESOURCE_TYPE_PARTICLEEMITTER
    elseif fileType == JSON_TYPE_TEXTURE then
        return RESOURCE_TYPE_TEXTURE
    elseif fileType == JSON_TYPE_ELEMENT then
        return RESOURCE_TYPE_UIELEMENT
    elseif fileType == JSON_TYPE_ELEMENTS then
        return RESOURCE_TYPE_UIELEMENTS
    elseif fileType == JSON_TYPE_ANIMATION_SETTINGS then
        return RESOURCE_TYPE_ANIMATION_SETTINGS
    elseif fileType == JSON_TYPE_RENDERPATH then
        return RESOURCE_TYPE_RENDERPATH
    elseif fileType == JSON_TYPE_TEXTURE_ATLAS then
        return RESOURCE_TYPE_TEXTURE_ATLAS
    elseif fileType == JSON_TYPE_2D_PARTICLE_EFFECT then
        return RESOURCE_TYPE_2D_PARTICLE_EFFECT
    elseif fileType == JSON_TYPE_TEXTURE_3D then
        return RESOURCE_TYPE_TEXTURE_3D
    elseif fileType == JSON_TYPE_CUBEMAP then
        return RESOURCE_TYPE_CUBEMAP
    elseif fileType == JSON_TYPE_SPRITER_DATA then
        return RESOURCE_TYPE_2D_ANIMATION_SET
    elseif fileType == JSON_TYPE_GENERIC then
        return RESOURCE_TYPE_GENERIC_JSON

    -- Extension filetypes
    elseif fileType == EXTENSION_TYPE_TTF then
        return RESOURCE_TYPE_FONT
    elseif fileType == EXTENSION_TYPE_OTF then
        return RESOURCE_TYPE_FONT
    elseif fileType == EXTENSION_TYPE_OGG then
        return RESOURCE_TYPE_SOUND
    elseif fileType == EXTENSION_TYPE_WAV then
        return RESOURCE_TYPE_SOUND
    elseif fileType == EXTENSION_TYPE_DDS then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_PNG then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_JPG then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_JPEG then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_HDR then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_BMP then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_TGA then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_KTX then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_PVR then
        return RESOURCE_TYPE_IMAGE
    elseif fileType == EXTENSION_TYPE_OBJ then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_FBX then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_COLLADA then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_BLEND then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_ANGELSCRIPT then
        return RESOURCE_TYPE_SCRIPTFILE
    elseif fileType == EXTENSION_TYPE_LUASCRIPT then
        return RESOURCE_TYPE_SCRIPTFILE
    elseif fileType == EXTENSION_TYPE_HLSL then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_GLSL then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_FRAGMENTSHADER then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_VERTEXSHADER then
        return RESOURCE_TYPE_UNUSABLE
    elseif fileType == EXTENSION_TYPE_HTML then
        return RESOURCE_TYPE_UNUSABLE
    end

    return RESOURCE_TYPE_UNKNOWN
end

function GetExtensionType(path, fileTypeOut)
    local ext = string.lower(GetExtension(path))
    local fileType = nil

    if ext == EXTENSION_TYPE_TTF then
        fileType = EXTENSION_TYPE_TTF
    elseif ext == EXTENSION_TYPE_OTF then
        fileType = EXTENSION_TYPE_OTF
    elseif ext == EXTENSION_TYPE_OGG then
        fileType = EXTENSION_TYPE_OGG
    elseif ext == EXTENSION_TYPE_WAV then
        fileType = EXTENSION_TYPE_WAV
    elseif ext == EXTENSION_TYPE_DDS then
        fileType = EXTENSION_TYPE_DDS
    elseif ext == EXTENSION_TYPE_PNG then
        fileType = EXTENSION_TYPE_PNG
    elseif ext == EXTENSION_TYPE_JPG then
        fileType = EXTENSION_TYPE_JPG
    elseif ext == EXTENSION_TYPE_JPEG then
        fileType = EXTENSION_TYPE_JPEG
    elseif ext == EXTENSION_TYPE_HDR then
        fileType = EXTENSION_TYPE_HDR
    elseif ext == EXTENSION_TYPE_BMP then
        fileType = EXTENSION_TYPE_BMP
    elseif ext == EXTENSION_TYPE_TGA then
        fileType = EXTENSION_TYPE_TGA
    elseif ext == EXTENSION_TYPE_KTX then
        fileType = EXTENSION_TYPE_KTX
    elseif ext == EXTENSION_TYPE_PVR then
        fileType = EXTENSION_TYPE_PVR
    elseif ext == EXTENSION_TYPE_OBJ then
        fileType = EXTENSION_TYPE_OBJ
    elseif ext == EXTENSION_TYPE_FBX then
        fileType = EXTENSION_TYPE_FBX
    elseif ext == EXTENSION_TYPE_COLLADA then
        fileType = EXTENSION_TYPE_COLLADA
    elseif ext == EXTENSION_TYPE_BLEND then
        fileType = EXTENSION_TYPE_BLEND
    elseif ext == EXTENSION_TYPE_ANGELSCRIPT then
        fileType = EXTENSION_TYPE_ANGELSCRIPT
    elseif ext == EXTENSION_TYPE_LUASCRIPT then
        fileType = EXTENSION_TYPE_LUASCRIPT
    elseif ext == EXTENSION_TYPE_HLSL then
        fileType = EXTENSION_TYPE_HLSL
    elseif ext == EXTENSION_TYPE_GLSL then
        fileType = EXTENSION_TYPE_GLSL
    elseif ext == EXTENSION_TYPE_FRAGMENTSHADER then
        fileType = EXTENSION_TYPE_FRAGMENTSHADER
    elseif ext == EXTENSION_TYPE_VERTEXSHADER then
        fileType = EXTENSION_TYPE_VERTEXSHADER
    elseif ext == EXTENSION_TYPE_HTML then
        fileType = EXTENSION_TYPE_HTML
    else
        return false
    end

    if fileTypeOut ~= nil then
        fileTypeOut[1] = fileType
    end
    return true
end

function GetBinaryType(path, fileTypeOut, useCache)
    if useCache == nil then useCache = false end

    local file
    if useCache then
        file = cache:GetFile(path)
        if file == nil then
            return false
        end
    else
        file = File()
        if not file:Open(path) then
            return false
        end
    end

    if file.size == 0 then
        return false
    end

    local typeStr = file:ReadFileID()
    local fileType = nil

    if typeStr == BINARY_TYPE_SCENE then
        fileType = BINARY_TYPE_SCENE
    elseif typeStr == BINARY_TYPE_PACKAGE then
        fileType = BINARY_TYPE_PACKAGE
    elseif typeStr == BINARY_TYPE_COMPRESSED_PACKAGE then
        fileType = BINARY_TYPE_COMPRESSED_PACKAGE
    elseif typeStr == BINARY_TYPE_ANGELSCRIPT then
        fileType = BINARY_TYPE_ANGELSCRIPT
    elseif typeStr == BINARY_TYPE_MODEL or typeStr == BINARY_TYPE_MODEL2 then
        fileType = BINARY_TYPE_MODEL
    elseif typeStr == BINARY_TYPE_SHADER then
        fileType = BINARY_TYPE_SHADER
    elseif typeStr == BINARY_TYPE_ANIMATION then
        fileType = BINARY_TYPE_ANIMATION
    else
        return false
    end

    if fileTypeOut ~= nil then
        fileTypeOut[1] = fileType
    end
    return true
end

function GetXmlType(path, fileTypeOut, useCache)
    if useCache == nil then useCache = false end

    if #GetFileName(path) == 0 then
        return false  -- .gitignore etc.
    end

    local extension = GetExtension(path)
    if extension == ".txt" or extension == ".json" or extension == ".icns" or extension == ".atlas" then
        return false
    end

    local name = ""
    if useCache then
        local xml = cache:GetResource("XMLFile", path)
        if xml == nil then
            return false
        end
        name = xml.root.name
    else
        local file = File()
        if not file:Open(path) then
            return false
        end

        if file.size == 0 then
            return false
        end

        local xml = XMLFile()
        if xml:Load(file) then
            name = xml.root.name
        else
            return false
        end
    end

    local found = false
    if #name > 0 then
        found = true
        local fileType = nil

        if name == XML_TYPE_SCENE then
            fileType = XML_TYPE_SCENE
        elseif name == XML_TYPE_NODE then
            fileType = XML_TYPE_NODE
        elseif name == XML_TYPE_MATERIAL then
            fileType = XML_TYPE_MATERIAL
        elseif name == XML_TYPE_TECHNIQUE then
            fileType = XML_TYPE_TECHNIQUE
        elseif name == XML_TYPE_PARTICLEEFFECT then
            fileType = XML_TYPE_PARTICLEEFFECT
        elseif name == XML_TYPE_PARTICLEEMITTER then
            fileType = XML_TYPE_PARTICLEEMITTER
        elseif name == XML_TYPE_TEXTURE then
            fileType = XML_TYPE_TEXTURE
        elseif name == XML_TYPE_ELEMENT then
            fileType = XML_TYPE_ELEMENT
        elseif name == XML_TYPE_ELEMENTS then
            fileType = XML_TYPE_ELEMENTS
        elseif name == XML_TYPE_ANIMATION_SETTINGS then
            fileType = XML_TYPE_ANIMATION_SETTINGS
        elseif name == XML_TYPE_RENDERPATH then
            fileType = XML_TYPE_RENDERPATH
        elseif name == XML_TYPE_TEXTURE_ATLAS then
            fileType = XML_TYPE_TEXTURE_ATLAS
        elseif name == XML_TYPE_2D_PARTICLE_EFFECT then
            fileType = XML_TYPE_2D_PARTICLE_EFFECT
        elseif name == XML_TYPE_TEXTURE_3D then
            fileType = XML_TYPE_TEXTURE_3D
        elseif name == XML_TYPE_CUBEMAP then
            fileType = XML_TYPE_CUBEMAP
        elseif name == XML_TYPE_SPRITER_DATA then
            fileType = XML_TYPE_SPRITER_DATA
        else
            fileType = XML_TYPE_GENERIC
        end

        if fileTypeOut ~= nil then
            fileTypeOut[1] = fileType
        end
    end
    return found
end

function ResourceTypeName(resourceType)
    if resourceType == RESOURCE_TYPE_UNUSABLE then
        return "Unusable"
    elseif resourceType == RESOURCE_TYPE_UNKNOWN then
        return "Unknown"
    elseif resourceType == RESOURCE_TYPE_NOTSET then
        return "Uninitialized"
    elseif resourceType == RESOURCE_TYPE_SCENE then
        return "Scene"
    elseif resourceType == RESOURCE_TYPE_SCRIPTFILE then
        return "Script File"
    elseif resourceType == RESOURCE_TYPE_MODEL then
        return "Model"
    elseif resourceType == RESOURCE_TYPE_MATERIAL then
        return "Material"
    elseif resourceType == RESOURCE_TYPE_ANIMATION then
        return "Animation"
    elseif resourceType == RESOURCE_TYPE_IMAGE then
        return "Image"
    elseif resourceType == RESOURCE_TYPE_SOUND then
        return "Sound"
    elseif resourceType == RESOURCE_TYPE_TEXTURE then
        return "Texture"
    elseif resourceType == RESOURCE_TYPE_FONT then
        return "Font"
    elseif resourceType == RESOURCE_TYPE_PREFAB then
        return "Prefab"
    elseif resourceType == RESOURCE_TYPE_TECHNIQUE then
        return "Render Technique"
    elseif resourceType == RESOURCE_TYPE_PARTICLEEFFECT then
        return "Particle Effect"
    elseif resourceType == RESOURCE_TYPE_PARTICLEEMITTER then
        return "Particle Emitter"
    elseif resourceType == RESOURCE_TYPE_UIELEMENT then
        return "UI Element"
    elseif resourceType == RESOURCE_TYPE_UIELEMENTS then
        return "UI Elements"
    elseif resourceType == RESOURCE_TYPE_ANIMATION_SETTINGS then
        return "Animation Settings"
    elseif resourceType == RESOURCE_TYPE_RENDERPATH then
        return "Render Path"
    elseif resourceType == RESOURCE_TYPE_TEXTURE_ATLAS then
        return "Texture Atlas"
    elseif resourceType == RESOURCE_TYPE_2D_PARTICLE_EFFECT then
        return "2D Particle Effect"
    elseif resourceType == RESOURCE_TYPE_TEXTURE_3D then
        return "Texture 3D"
    elseif resourceType == RESOURCE_TYPE_CUBEMAP then
        return "Cubemap"
    elseif resourceType == RESOURCE_TYPE_2D_ANIMATION_SET then
        return "2D Animation Set"
    else
        return ""
    end
end

-- ==================== BrowserDir Class ====================

BrowserDir = {
    id = 0,
    resourceKey = "",
    name = "",
    children = {},
    files = {}
}

function BrowserDir:new(path)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self

    obj.resourceKey = path
    local parent = GetParentPath(path)
    obj.name = string.gsub(path, parent, "")
    obj.id = browserDirIndex
    browserDirIndex = browserDirIndex + 1
    obj.children = {}
    obj.files = {}

    return obj
end

function BrowserDir:opCmp(b)
    if self.name < b.name then
        return -1
    elseif self.name > b.name then
        return 1
    else
        return 0
    end
end

function BrowserDir:AddFile(name, resourceSourceIndex, sourceType)
    local path = (#self.resourceKey > 0) and (self.resourceKey .. "/" .. name) or name
    local file = BrowserFile:new(path, resourceSourceIndex, sourceType)
    table.insert(self.files, file)
    return file
end

-- ==================== BrowserFile Class ====================

BrowserFile = {
    id = 0,
    resourceSourceIndex = 0,
    resourceKey = "",
    name = "",
    fullname = "",
    extension = "",
    fileType = "",
    resourceType = 0,
    sourceType = 0,
    sortScore = 0,
    browserFileListRow = nil
}

function BrowserFile:new(path, resourceSourceIndex_, sourceType_)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self

    obj.sourceType = sourceType_
    obj.resourceSourceIndex = resourceSourceIndex_
    obj.resourceKey = path
    obj.name = GetFileName(path)
    obj.extension = GetExtension(path)
    obj.fullname = GetFileNameAndExtension(path)
    obj.id = browserFileIndex
    browserFileIndex = browserFileIndex + 1
    obj.resourceType = 0
    obj.sortScore = 0
    obj.fileType = ""

    return obj
end

function BrowserFile:opCmp(b)
    if browserSearchSortMode == 1 then
        if self.fullname < b.fullname then
            return -1
        elseif self.fullname > b.fullname then
            return 1
        else
            return 0
        end
    else
        return self.sortScore - b.sortScore
    end
end

function BrowserFile:GetResourceSource()
    if self.sourceType == BROWSER_FILE_SOURCE_RESOURCE_DIR then
        return cache.resourceDirs[self.resourceSourceIndex + 1]
    else
        return "Unknown"
    end
end

function BrowserFile:GetFullPath()
    return cache.resourceDirs[self.resourceSourceIndex + 1] .. self.resourceKey
end

function BrowserFile:GetPath()
    return self.resourceKey
end

function BrowserFile:DetermainResourceType()
    local fileType = {}
    self.resourceType = GetResourceType(self:GetFullPath(), fileType, false)
    if fileType[1] ~= nil then
        self.fileType = fileType[1]
    end

    local browserFileListRow_ = self.browserFileListRow
    if browserFileListRow_ ~= nil then
        InitializeBrowserFileListRow(browserFileListRow_, self)
    end
end

function BrowserFile:ResourceTypeName()
    return ResourceTypeName(self.resourceType)
end

function BrowserFile:FileChanged()
    if not fileSystem:FileExists(self:GetFullPath()) then
        -- File was deleted
    else
        -- File was modified
    end
end

-- ==================== ResourceType Class ====================

ResourceType = {
    id = 0,
    name = ""
}

function ResourceType:new(id_, name_)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self

    obj.id = id_
    obj.name = name_

    return obj
end

function ResourceType:opCmp(b)
    if self.name < b.name then
        return -1
    elseif self.name > b.name then
        return 1
    else
        return 0
    end
end

-- ==================== Preview Functions ====================

function CreateResourcePreview(path, previewNode)
    resourceBrowserPreview.autoUpdate = false
    local resourceType = GetResourceType(path, nil, false)
    if resourceType > 0 then
        local file = File()
        file:Open(path)

        if resourceType == RESOURCE_TYPE_MODEL then
            local model = Model()
            if model:Load(file) then
                local staticModel = previewNode:CreateComponent("StaticModel")
                staticModel.model = model
                return
            end
        elseif resourceType == RESOURCE_TYPE_MATERIAL then
            local material = Material()
            if material:Load(file) then
                local staticModel = previewNode:CreateComponent("StaticModel")
                staticModel.model = cache:GetResource("Model", "Models/Sphere.mdl")
                staticModel.material = material
                return
            end
        elseif resourceType == RESOURCE_TYPE_IMAGE then
            local image = Image()
            if image:Load(file) then
                local staticModel = previewNode:CreateComponent("StaticModel")
                staticModel.model = cache:GetResource("Model", "Models/Editor/ImagePlane.mdl")
                local material = cache:GetResource("Material", "Materials/Editor/TexturedUnlit.xml")
                local texture = Texture2D()
                texture:SetData(image, true)
                material:SetTexture(TU_DIFFUSE, texture)
                staticModel.material = material
                return
            end
        elseif resourceType == RESOURCE_TYPE_PREFAB then
            if GetExtension(path) == ".xml" then
                local xmlFile = XMLFile()
                if xmlFile:Load(file) then
                    if previewNode:LoadXML(xmlFile.root) and
                       (previewNode:GetComponents("StaticModel", true).size > 0 or
                        previewNode:GetComponents("AnimatedModel", true).size > 0) then
                        return
                    end
                end
            else
                if previewNode:Load(file) and
                   (previewNode:GetComponents("StaticModel", true).size > 0 or
                    previewNode:GetComponents("AnimatedModel", true).size > 0) then
                    return
                end
            end

            previewNode:RemoveAllChildren()
            previewNode:RemoveAllComponents()
        elseif resourceType == RESOURCE_TYPE_PARTICLEEFFECT then
            local particleEffect = ParticleEffect()
            if particleEffect:Load(file) then
                local particleEmitter = previewNode:CreateComponent("ParticleEmitter")
                particleEmitter.effect = particleEffect
                particleEffect.activeTime = 0.0
                particleEmitter:Reset()
                resourceBrowserPreview.autoUpdate = true
                return
            end
        end
    end

    -- Default "no preview" display
    local staticModel = previewNode:CreateComponent("StaticModel")
    staticModel.model = cache:GetResource("Model", "Models/Editor/ImagePlane.mdl")
    local material = cache:GetResource("Material", "Materials/Editor/TexturedUnlit.xml")
    local texture = Texture2D()
    local noPreviewImage = cache:GetResource("Image", "Textures/Editor/NoPreviewAvailable.png")
    texture:SetData(noPreviewImage, false)
    material:SetTexture(TU_DIFFUSE, texture)
    staticModel.material = material
end

function RotateResourceBrowserPreview(eventType, eventData)
    local elemX = eventData["ElementX"]:GetInt()
    local elemY = eventData["ElementY"]:GetInt()

    if resourceBrowserPreview.height > 0 and resourceBrowserPreview.width > 0 then
        local yaw = ((resourceBrowserPreview.height / 2) - elemY) * (90.0 / resourceBrowserPreview.height)
        local pitch = ((resourceBrowserPreview.width / 2) - elemX) * (90.0 / resourceBrowserPreview.width)

        resourcePreviewNode.rotation = resourcePreviewNode.rotation:Slerp(Quaternion(yaw, pitch, 0), 0.1)
        RefreshBrowserPreview()
    end
end

function RefreshBrowserPreview()
    resourceBrowserPreview:QueueUpdate()
end

-- ==================== Utility Functions ====================

function TableContains(table, value)
    for i = 1, #table do
        if table[i] == value then
            return true
        end
    end
    return false
end

function TableFind(table, value)
    for i = 1, #table do
        if table[i] == value then
            return i
        end
    end
    return -1
end
