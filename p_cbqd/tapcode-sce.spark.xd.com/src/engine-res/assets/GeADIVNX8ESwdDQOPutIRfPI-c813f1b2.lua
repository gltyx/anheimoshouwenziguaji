--[[
EditorCubeCapture.lua - Urho3D Editor Cubemap Capture

Provides environment cubemap generation functionality including:
- Automatic cubemap rendering from zone positions
- Multi-face capture (6 faces per cubemap)
- Zone texture assignment
- Batch processing support
- IBL (Image-Based Lighting) preparation

Converted from EditorCubeCapture.as
--]]

-- Settings
cubeMapGen_Name = ""
cubeMapGen_Path = ""
cubeMapGen_Size = 0

-- Active capture tasks
activeCubeCapture = {}
cloneZones = {}
disabledZones = {}
cubemapDefaultOutputPath = "Textures/Cubemaps"

function PrepareZonesForCubeRendering()
    -- Only clone zones when we aren't actively processing
    if #cloneZones > 0 then
        return
    end

    local zones = editorScene:GetComponents("Zone", true)
    for i = 1, #zones do
        local srcZone = zones[i]
        if srcZone.enabled then
            local cloneZone = srcZone.node:CreateComponent("Zone")
            cloneZone.zoneMask = srcZone.zoneMask
            cloneZone.priority = srcZone.priority
            cloneZone.boundingBox = srcZone.boundingBox

            cloneZone.ambientColor = srcZone.ambientColor
            cloneZone.ambientGradient = srcZone.ambientGradient

            cloneZone.fogColor = srcZone.fogColor
            cloneZone.fogStart = srcZone.fogStart
            cloneZone.fogEnd = srcZone.fogEnd
            cloneZone.fogHeight = srcZone.fogHeight
            cloneZone.fogHeightScale = srcZone.fogHeightScale
            cloneZone.heightFog = srcZone.heightFog

            srcZone.enabled = false

            table.insert(cloneZones, cloneZone)
            table.insert(disabledZones, srcZone)
        end
    end

    -- Hide grid and debugIcons until bake
    if grid ~= nil then
        grid.viewMask = 0
    end
    if debugIconsNode ~= nil then
        debugIconsNode.enabled = false
    end
    debugRenderDisabled = true
end

function UnprepareZonesForCubeRendering()
    -- Clean up the clones
    for i = 1, #cloneZones do
        cloneZones[i]:Remove()
    end
    cloneZones = {}

    -- Reenable anyone we disabled
    for i = 1, #disabledZones do
        disabledZones[i].enabled = true
    end
    disabledZones = {}

    -- Show grid and debug icons
    if grid ~= nil then
        grid.viewMask = 0x80000000
    end
    if debugIconsNode ~= nil then
        debugIconsNode.enabled = true
    end
    debugRenderDisabled = false
end

-- EditorCubeCapture class
EditorCubeCapture = ScriptObject()

function EditorCubeCapture:Start()
    PrepareZonesForCubeRendering()

    -- Store name and path
    self.name_ = cubeMapGen_Name
    self.path_ = sceneResourcePath .. cubeMapGen_Path
    self.updateCycle_ = 0

    self.camNode_ = scene:CreateChild("RenderCamera")
    self.camera_ = self.camNode_:GetOrCreateComponent("Camera")
    self.camera_.fov = 90.0
    self.camera_.nearClip = 0.0001
    self.camera_.aspectRatio = 1.0
    self.camNode_.worldPosition = self.target_.node.worldPosition

    self.viewport_ = Viewport(scene, self.camera_)
    self.viewport_.renderPath = renderer.viewports[0].renderPath

    self.updateCycle_ = 0
end

function EditorCubeCapture:BeginCapture()
    -- Construct render surface
    self.renderImage_ = Texture2D()
    self.renderImage_:SetSize(cubeMapGen_Size, cubeMapGen_Size, GetRGBAFormat(), TEXTURE_RENDERTARGET)

    self.renderSurface_ = self.renderImage_.renderSurface
    self.renderSurface_.viewports[0] = self.viewport_
    self.renderSurface_.updateMode = SURFACE_UPDATEALWAYS

    self:SubscribeToEvent("BeginFrame", "HandlePreRender")
    self:SubscribeToEvent("EndFrame", "HandlePostRender")
end

function EditorCubeCapture:Stop()
    if self.camNode_ ~= nil then
        self.camNode_:Remove()
    end
    self.camNode_ = nil
    self.viewport_ = nil
    self.renderSurface_ = nil

    self:UnsubscribeFromEvent("BeginFrame")
    self:UnsubscribeFromEvent("EndFrame")

    self:WriteXML()

    -- Remove ourselves from the processing list
    for i = 1, #activeCubeCapture do
        if activeCubeCapture[i] == self then
            table.remove(activeCubeCapture, i)
            break
        end
    end

    if #activeCubeCapture == 0 then
        UnprepareZonesForCubeRendering()
    else
        activeCubeCapture[1]:BeginCapture()
    end
end

function EditorCubeCapture:HandlePreRender(eventType, eventData)
    if self.camNode_ ~= nil then
        self.updateCycle_ = self.updateCycle_ + 1

        if self.updateCycle_ < 7 then
            self.camNode_.worldRotation = self:RotationOf(self:GetFaceForCycle(self.updateCycle_))
        else
            self:Stop()
        end
    end
end

function EditorCubeCapture:HandlePostRender(eventType, eventData)
    local img = self.renderImage_:GetImage()
    local sceneName = (editorScene.name ~= nil and editorScene.name ~= "") and (editorScene.name .. "/") or ""
    local path = self.path_ .. "/" .. sceneName
    fileSystem:CreateDir(path)
    path = path .. "/" .. tostring(self.target_.id) .. "_" .. self:GetFaceName(self:GetFaceForCycle(self.updateCycle_)) .. ".png"
    img:SavePNG(path)
end

function EditorCubeCapture:WriteXML()
    local sceneName = (editorScene.name ~= nil and editorScene.name ~= "") and ("/" .. editorScene.name .. "/") or ""
    local basePath = AddTrailingSlash(self.path_ .. sceneName)
    local cubeName = (self.name_ ~= nil and self.name_ ~= "") and (self.name_ .. "_") or ""
    local xmlPath = basePath .. "/" .. self.name_ .. tostring(self.target_.id) .. ".xml"
    local file = XMLFile()
    local rootElem = file:CreateRoot("cubemap")

    for i = 0, 5 do
        local faceElem = rootElem:CreateChild("face")
        faceElem:SetAttribute("name", GetResourceNameFromFullName(basePath .. cubeName .. tostring(self.target_.id) .. "_" .. self:GetFaceName(i) .. ".png"))
    end

    file:Save(File(xmlPath, FILE_WRITE), "    ")

    local ref = ResourceRef()
    ref.type = StringHash("TextureCube")
    ref.name = GetResourceNameFromFullName(xmlPath)
    self.target_:SetAttribute("Zone Texture", Variant(ref))
end

function EditorCubeCapture:GetFaceForCycle(cycle)
    if cycle == 1 then
        return FACE_POSITIVE_X
    elseif cycle == 2 then
        return FACE_POSITIVE_Y
    elseif cycle == 3 then
        return FACE_POSITIVE_Z
    elseif cycle == 4 then
        return FACE_NEGATIVE_X
    elseif cycle == 5 then
        return FACE_NEGATIVE_Y
    elseif cycle == 6 then
        return FACE_NEGATIVE_Z
    end
    return FACE_POSITIVE_X
end

function EditorCubeCapture:GetFaceName(face)
    if face == FACE_POSITIVE_X then
        return "PosX"
    elseif face == FACE_POSITIVE_Y then
        return "PosY"
    elseif face == FACE_POSITIVE_Z then
        return "PosZ"
    elseif face == FACE_NEGATIVE_X then
        return "NegX"
    elseif face == FACE_NEGATIVE_Y then
        return "NegY"
    elseif face == FACE_NEGATIVE_Z then
        return "NegZ"
    end
    return "PosX"
end

function EditorCubeCapture:RotationOf(face)
    local result = Quaternion()

    if face == FACE_POSITIVE_X then
        result = Quaternion(0, 90, 0)
    elseif face == FACE_NEGATIVE_X then
        result = Quaternion(0, -90, 0)
    elseif face == FACE_POSITIVE_Y then
        result = Quaternion(-90, 0, 0)
    elseif face == FACE_NEGATIVE_Y then
        result = Quaternion(90, 0, 0)
    elseif face == FACE_POSITIVE_Z then
        result = Quaternion(0, 0, 0)
    elseif face == FACE_NEGATIVE_Z then
        result = Quaternion(0, 180, 0)
    end

    return result
end

-- Create EditorCubeCapture instance for a zone
function CreateEditorCubeCapture(forZone)
    local capture = EditorCubeCapture()
    capture.target_ = forZone
    capture.updateCycle_ = 0
    capture:Start()
    return capture
end

-- Start cubemap capture for zone
function StartCubemapCapture(zone)
    local capture = CreateEditorCubeCapture(zone)
    table.insert(activeCubeCapture, capture)

    -- If this is the first one, start it immediately
    if #activeCubeCapture == 1 then
        capture:BeginCapture()
    end
end
