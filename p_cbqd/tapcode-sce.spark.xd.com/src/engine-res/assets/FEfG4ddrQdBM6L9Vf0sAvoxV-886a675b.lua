-- Urho3D editor scene handling

-- Note: This module depends on EditorHierarchyWindow, EditorInspectorWindow, EditorCubeCapture
-- For now, we'll create stubs for their functions

-- Pick mode constants
local PICK_GEOMETRIES = 0
local PICK_LIGHTS = 1
local PICK_ZONES = 2
local PICK_RIGIDBODIES = 3
local PICK_UI_ELEMENTS = 4
local MAX_PICK_MODES = 5
local MAX_UNDOSTACK_SIZE = 256

-- Global scene variables
editorScene = nil

instantiateFileName = ""
instantiateMode = REPLICATED
sceneModified = false
runUpdate = false

selectedNodes = {}
selectedComponents = {}
editNode = nil
editNodes = {}
editComponents = {}
numEditableComponentsPerNode = 1

sceneCopyBuffer = {}

suppressSceneChanges = false
inSelectionModify = false
skipMruScene = false

undoStack = {}
undoStackPos = 0

revertOnPause = false
revertData = nil

lastOffsetForSmartDuplicate = Vector3()

function ClearSceneSelection()
    selectedNodes = {}
    selectedComponents = {}
    editNode = nil
    editNodes = {}
    editComponents = {}
    numEditableComponentsPerNode = 1

    HideGizmo()
end

function CreateScene()
    -- Create a scene only once here
    editorScene = Scene()

    -- Allow access to the scene from the console
    if script ~= nil then
        script.defaultScene = editorScene
    end

    -- Always pause the scene, and do updates manually
    editorScene.updateEnabled = false
end

function ResetScene()
    if ui.cursor ~= nil then
        ui.cursor.shape = CS_BUSY
    end

    if messageBoxCallback == nil and sceneModified then
        local messageBox = MessageBox("Scene has been modified.\nContinue to reset?", "Warning")
        if messageBox.window ~= nil then
            local cancelButton = messageBox.window:GetChild("CancelButton", true)
            cancelButton.visible = true
            cancelButton.focus = true
            SubscribeToEvent(messageBox, "MessageACK", "HandleMessageAcknowledgement")
            messageBoxCallback = ResetScene
            return false
        end
    else
        messageBoxCallback = nil
    end

    suppressSceneChanges = true

    -- Create a scene with default values, these will be overridden when loading scenes
    editorScene:Clear()
    editorScene:CreateComponent("Octree")
    editorScene:CreateComponent("DebugRenderer")

    -- Load LightGroup assets and serialize Nodes from LightGroup assets.
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = editorScene:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    -- Create skybox. The Skybox component is used like StaticModel, but it will be always located at the camera, giving the
    -- illusion of the box planes being far away. Use just the ordinary Box model and a suitable material, whose shader will
    -- generate the necessary 3D texture coordinates for cube mapping
    local skyNode = editorScene:CreateChild("Sky")
    skyNode:SetScale(500.0) -- The scale actually does not matter
    local skybox = skyNode:CreateComponent("Skybox")
    skybox.model = cache:GetResource("Model", "Models/Box.mdl")
    skybox.material = cache:GetResource("Material", "Materials/Skybox.xml")

    -- Create heightmap terrain with collision
    local terrainNode = editorScene:CreateChild("Terrain")
    terrainNode.position = Vector3(0.0, 0.0, 0.0)
    local terrain = terrainNode:CreateComponent("Terrain")
    terrain.patchSize = 64
    terrain.spacing = Vector3(2.0, 0.1, 2.0) -- Spacing between vertices and vertical resolution of the height map
    terrain.smoothing = true
    terrain.heightMap = cache:GetResource("Image", "Textures/HeightMap.png")
    terrain.material = cache:GetResource("Material", "Materials/Terrain.xml")
    -- The terrain consists of large triangles, which fits well for occlusion rendering, as a hill can occlude all
    -- terrain patches and other objects behind it
    terrain.occluder = true

    -- 创建3层测试节点结构
    local testParent = editorScene:CreateChild("TestParent")
    testParent.position = Vector3(10, 0, 0)
    local testChild = testParent:CreateChild("TestChild")
    testChild.position = Vector3(0, 5, 0)
    local testGrandChild = testChild:CreateChild("TestGrandChild")
    testGrandChild.position = Vector3(0, 0, 5)

    print("Created 3-level test node hierarchy: TestParent -> TestChild -> TestGrandChild")

    -- Release resources that became unused after the scene clear
    cache:ReleaseAllResources(false)

    sceneModified = false
    revertData = nil
    StopSceneUpdate()

    UpdateWindowTitle()
    DisableInspectorLock()
    UpdateHierarchyItem(editorScene, true)
    ClearEditActions()

    suppressSceneChanges = false

    ResetCamera()
    CreateGizmo()
    CreateGrid()
    SetActiveViewport(viewports[0])

    return true
end

function UpdateScene(timeStep)
    if runUpdate then
        editorScene:Update(timeStep)
    end
end

function StopSceneUpdate()
    runUpdate = false

    if revertOnPause and revertData ~= nil then
        editorScene:LoadXML(revertData.root)
        revertData = nil
    end
end

function StartSceneUpdate()
    if not runUpdate then
        if revertOnPause then
            revertData = XMLFile()
            editorScene:SaveXML(revertData.root)
        end
    end

    runUpdate = true
end

function ToggleSceneUpdate()
    if runUpdate then
        StopSceneUpdate()
    else
        StartSceneUpdate()
    end
    return runUpdate
end

function SetSceneModified()
    if not sceneModified then
        sceneModified = true
        UpdateWindowTitle()
    end
end

-- =======================
-- 场景加载/保存
-- =======================

function SetResourcePath(newPath, usePreferredDir, additive)
    usePreferredDir = usePreferredDir or false
    additive = additive or false

    if not additive then
        sceneResourcePath = newPath
    end

    -- 可以在这里添加资源路径到cache
    -- cache:AddResourceDir(newPath)
end

function GetResourceSubPath(fullPath)
    -- 简化实现：返回相对于sceneResourcePath的路径
    if fullPath:find(sceneResourcePath, 1, true) == 1 then
        return fullPath:sub(#sceneResourcePath + 1)
    end
    return fullPath
end

function LoadScene(fileName)
    if fileName == "" then
        return false
    end

    if not fileSystem:FileExists(fileName) then
        print("ERROR: Scene file does not exist: " .. fileName)
        return false
    end

    local file = File(fileName, FILE_READ)
    if not file.open then
        print("ERROR: Could not open scene file: " .. fileName)
        return false
    end

    if ui.cursor ~= nil then
        ui.cursor.shape = CS_BUSY
    end

    -- 添加场景资源路径
    local newScenePath = GetPath(fileName)
    if not rememberResourcePath or not sceneResourcePath:find(newScenePath, 1, true) then
        SetResourcePath(newScenePath)
    end

    suppressSceneChanges = true
    sceneModified = false
    revertData = nil
    StopSceneUpdate()

    local extension = GetExtension(fileName)
    local loaded = false

    if extension == ".xml" then
        loaded = editorScene:LoadXML(file)
    elseif extension == ".json" then
        loaded = editorScene:LoadJSON(file)
    else
        loaded = editorScene:Load(file)
    end

    -- 释放未使用的资源
    cache:ReleaseAllResources(false)

    -- 总是暂停场景
    editorScene.updateEnabled = false

    UpdateWindowTitle()
    DisableInspectorLock()
    UpdateHierarchyItem(editorScene, true)
    ClearEditActions()

    suppressSceneChanges = false

    if not skipMruScene then
        UpdateSceneMru(fileName)
    end
    skipMruScene = false

    ResetCamera()
    CreateGizmo()
    CreateGrid()
    if viewports and viewports[1] then
        SetActiveViewport(viewports[1])
    end

    print("Scene loaded: " .. fileName)
    return loaded
end

function SaveScene(fileName)
    if fileName == "" then
        return false
    end

    if ui.cursor ~= nil then
        ui.cursor.shape = CS_BUSY
    end

    -- 保存时取消暂停
    editorScene.updateEnabled = true

    -- 创建备份（简化实现）
    -- MakeBackup(fileName)

    local file = File(fileName, FILE_WRITE)
    local extension = GetExtension(fileName)
    local success = false

    if extension == ".xml" then
        success = editorScene:SaveXML(file)
    elseif extension == ".json" then
        success = editorScene:SaveJSON(file)
    else
        success = editorScene:Save(file)
    end

    -- 恢复暂停
    editorScene.updateEnabled = false

    if success then
        UpdateSceneMru(fileName)
        sceneModified = false
        UpdateWindowTitle()
        print("Scene saved: " .. fileName)
    else
        print("ERROR: Could not save scene: " .. fileName)
    end

    return success
end

function SaveSceneWithExistingName()
    if editorScene.fileName == "" or editorScene.fileName == "Temp.xml" then
        -- 需要选择文件名（这里简化处理）
        print("ERROR: No scene file name specified")
        return false
    else
        return SaveScene(editorScene.fileName)
    end
end

-- =======================
-- 节点创建/管理
-- =======================

function GetNewNodePosition(raycastToMouse)
    raycastToMouse = raycastToMouse or false

    if raycastToMouse then
        -- 简化实现：使用摄像机前方位置
        -- 完整实现需要射线检测
    end

    -- 默认返回摄像机前方10单位
    if camera then
        return camera.node.worldPosition + camera.node.worldDirection * Vector3(10, 10, 10)
    end

    return Vector3(0, 0, 0)
end

function CreateNode(mode, raycastToMouse)
    mode = mode or REPLICATED
    raycastToMouse = raycastToMouse or false

    local newNode
    if editNode ~= nil then
        newNode = editNode:CreateChild("", mode)
    else
        newNode = editorScene:CreateChild("", mode)
    end

    newNode.worldPosition = GetNewNodePosition(raycastToMouse)

    -- 创建撤销操作（简化实现）
    -- CreateNodeAction...
    -- SaveEditAction(action)

    SetSceneModified()
    FocusNode(newNode)

    return newNode
end

function CreateComponent(componentType)
    if editNode == nil then
        print("ERROR: No node selected")
        return
    end

    -- 检查场景全局组件
    if editNode == editorScene then
        -- 简化：跳过全局组件检查
    end

    -- 为所有选中的节点创建组件
    for i = 1, #editNodes do
        local node = editNodes[i]
        local newComponent = node:CreateComponent(componentType, node.replicated and REPLICATED or LOCAL)
        if newComponent ~= nil then
            newComponent:ApplyAttributes()
            -- 创建撤销操作（简化）
        end
    end

    SetSceneModified()
    -- 刷新Inspector
    if HandleHierarchyListSelectionChange then
        HandleHierarchyListSelectionChange()
    end
end

function LoadNode(fileName, parent, raycastToMouse)
    fileName = fileName or ""
    raycastToMouse = raycastToMouse or false

    if fileName == "" then
        return nil
    end

    if not fileSystem:FileExists(fileName) then
        print("ERROR: Node file does not exist: " .. fileName)
        return nil
    end

    local file = File(fileName, FILE_READ)
    if not file.open then
        print("ERROR: Could not open node file: " .. fileName)
        return nil
    end

    if ui.cursor ~= nil then
        ui.cursor.shape = CS_BUSY
    end

    -- 添加资源路径
    SetResourcePath(GetPath(fileName), true, true)

    local newNode = InstantiateNodeFromFile(file, GetNewNodePosition(raycastToMouse), Quaternion(), 1, parent, instantiateMode)
    if newNode ~= nil then
        FocusNode(newNode)
        instantiateFileName = fileName
    end

    return newNode
end

function InstantiateNodeFromFile(file, position, rotation, scaleMod, parent, mode)
    scaleMod = scaleMod or 1.0
    mode = mode or REPLICATED

    if file == nil then
        return nil
    end

    suppressSceneChanges = true

    local newNode
    local extension = GetExtension(file.name)

    if parent == nil then
        parent = editNode or editorScene
    end

    -- 读取节点
    if extension == ".xml" then
        newNode = parent:CreateChild("", mode)
        if newNode:LoadXML(file:GetRoot()) then
            newNode.position = position
            newNode.rotation = rotation
            if scaleMod ~= 1.0 then
                newNode.scale = newNode.scale * scaleMod
            end
        else
            newNode:Remove()
            newNode = nil
        end
    end

    suppressSceneChanges = false

    if newNode ~= nil then
        SetSceneModified()
    end

    return newNode
end

function SaveNode(fileName, node)
    if fileName == "" or node == nil then
        return false
    end

    local file = File(fileName, FILE_WRITE)
    local extension = GetExtension(fileName)
    local success = false

    if extension == ".xml" then
        success = node:SaveXML(file)
    elseif extension == ".json" then
        success = node:SaveJSON(file)
    else
        success = node:Save(file)
    end

    if success then
        print("Node saved: " .. fileName)
    else
        print("ERROR: Could not save node: " .. fileName)
    end

    return success
end

-- =======================
-- 场景编辑操作
-- =======================

function SceneDelete()
    if #selectedNodes == 0 and #selectedComponents == 0 then
        return
    end

    -- 删除选中的组件
    for i = 1, #selectedComponents do
        local component = selectedComponents[i]
        if component ~= nil then
            component:Remove()
        end
    end

    -- 删除选中的节点
    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil and node ~= editorScene then
            node:Remove()
        end
    end

    ClearSceneSelection()
    SetSceneModified()
    UpdateHierarchyItem(editorScene, true)
end

function SceneCut()
    SceneCopy()
    SceneDelete()
end

function SceneCopy()
    sceneCopyBuffer = {}

    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil and node ~= editorScene then
            local xmlFile = XMLFile()
            local rootElem = xmlFile:CreateRoot("node")
            node:SaveXML(rootElem)
            table.insert(sceneCopyBuffer, xmlFile)
        end
    end

    print("Copied " .. #sceneCopyBuffer .. " nodes to clipboard")
end

function ScenePaste(pasteToMouse)
    pasteToMouse = pasteToMouse or false

    if #sceneCopyBuffer == 0 then
        return
    end

    suppressSceneChanges = true
    ClearSceneSelection()

    local parent = editNode or editorScene
    local basePos = GetNewNodePosition(pasteToMouse)

    for i = 1, #sceneCopyBuffer do
        local xmlFile = sceneCopyBuffer[i]
        local newNode = parent:CreateChild("", REPLICATED)
        if newNode:LoadXML(xmlFile:GetRoot()) then
            newNode.position = basePos + Vector3(i - 1, 0, 0)
            table.insert(selectedNodes, newNode)
        else
            newNode:Remove()
        end
    end

    suppressSceneChanges = false

    SetSceneModified()
    UpdateHierarchyItem(editorScene, true)
    FocusNode(selectedNodes[1])

    print("Pasted " .. #selectedNodes .. " nodes")
end

function SceneDuplicate()
    SceneCopy()
    ScenePaste(false)
end

function SceneSelectAll()
    ClearSceneSelection()

    -- 选择场景的所有子节点
    local numChildren = editorScene:GetNumChildren(false)
    for i = 0, numChildren - 1 do
        local child = editorScene:GetChild(i, false)
        if child ~= nil then
            table.insert(selectedNodes, child)
        end
    end

    if #selectedNodes > 0 then
        editNode = selectedNodes[1]
        editNodes = selectedNodes
    end

    UpdateHierarchyItem(editorScene, true)
    print("Selected " .. #selectedNodes .. " nodes")
end

function SceneUnparent()
    if #selectedNodes == 0 then
        return
    end

    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil and node.parent ~= nil and node.parent ~= editorScene then
            local worldPos = node.worldPosition
            local worldRot = node.worldRotation
            local worldScale = node.worldScale

            editorScene:AddChild(node)

            node.worldPosition = worldPos
            node.worldRotation = worldRot
            node.worldScale = worldScale
        end
    end

    SetSceneModified()
    UpdateHierarchyItem(editorScene, true)
end

function SceneResetTransform()
    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil then
            node.position = Vector3(0, 0, 0)
            node.rotation = Quaternion()
            node.scale = Vector3(1, 1, 1)
        end
    end
    SetSceneModified()
end

function SceneResetPosition()
    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil then
            node.position = Vector3(0, 0, 0)
        end
    end
    SetSceneModified()
end

function SceneResetRotation()
    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil then
            node.rotation = Quaternion()
        end
    end
    SetSceneModified()
end

function SceneResetScale()
    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil then
            node.scale = Vector3(1, 1, 1)
        end
    end
    SetSceneModified()
end

function SceneToggleEnable()
    for i = 1, #selectedNodes do
        local node = selectedNodes[i]
        if node ~= nil then
            node.enabled = not node.enabled
        end
    end
    SetSceneModified()
end

-- =======================
-- 辅助函数
-- =======================

function FocusNode(node)
    if node == nil then
        return
    end

    ClearSceneSelection()
    table.insert(selectedNodes, node)
    editNode = node
    editNodes = {node}

    UpdateHierarchyItem(editorScene, false)
    print("Focused node: " .. (node.name ~= "" and node.name or "Unnamed"))
end

function FocusComponent(component)
    if component == nil then
        return
    end

    selectedComponents = {component}
    editComponent = component
    editComponents = {component}
end

function GetPath(fullPath)
    local lastSlash = fullPath:match("^.*()/")
    if lastSlash then
        return fullPath:sub(1, lastSlash)
    end
    return ""
end

function GetExtension(fullPath)
    local ext = fullPath:match("%.([^.]+)$")
    return ext and ("." .. ext:lower()) or ""
end

function UpdateSceneMru(fileName)
    -- 更新最近使用的场景列表（简化实现）
    print("MRU: " .. fileName)
end

-- =======================
-- Stub functions for dependencies (to be replaced when modules are loaded)
-- =======================

function UpdateWindowTitle() end
function DisableInspectorLock()
    if DisableInspectorLock then
        -- 调用 EditorInspectorWindow 的实现
    end
end
-- UpdateHierarchyItem - Implemented in EditorHierarchyWindow.lua
function ClearEditActions() end
function ResetCamera()
    if ResetCamera then
        -- 调用 EditorView 的实现
    end
end
function CreateGrid()
    if CreateGrid then
        -- 调用 EditorView 的实现
    end
end
function SetActiveViewport(viewport) end
function HandleMessageAcknowledgement() end
function HandleHierarchyListSelectionChange()
    if UpdateAttributeInspector then
        UpdateAttributeInspector()
    end
end

print("EditorScene: Core functions loaded (scene management, node operations)")


