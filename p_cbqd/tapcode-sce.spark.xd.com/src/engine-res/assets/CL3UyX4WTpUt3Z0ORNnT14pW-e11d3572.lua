-- Screen Space Effects Test
-- Tests: HiZ, GTAO (SSAO), SSR, Motion Vector
--
-- Run with: UrhoXRuntime.exe LuaScripts/98_ScreenSpaceTest.lua -deferred_rendering
--
-- Scene contains:
-- - Reflective floor (SSR test)
-- - Spheres with varying roughness (SSR roughness response)
-- - Corner geometry (SSAO occlusion test)
-- - Colored pillars (SSR color bleeding)
-- - Moving object (Motion Vector test)

require "LuaScripts/Utilities/Sample"

local movingNode = nil
local moveTime = 0.0

function Start()
    SampleStart()
    CreateScene()
    SetupViewport()
    SubscribeToEvents()
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- Zone (ambient + fog)
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.1, 0.1, 0.15, 2.0)
    zone.fogColor = Color(0.2, 0.2, 0.3)
    zone.fogStart = 50.0
    zone.fogEnd = 200.0

    -- Directional light
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(1.0, 0.95, 0.9)
    light.brightness = 1.5
    light:SetCastShadows(true)
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(10.0, 30.0, 100.0, 200.0, 0.8)

    -- Reflective floor (SSR test)
    local floorNode = scene_:CreateChild("Floor")
    floorNode.scale = Vector3(50.0, 1.0, 50.0)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel.model = cache:GetResource("Model", "Models/Plane.mdl")
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("Roughness", Variant(0.05))
    floorMat:SetShaderParameter("Metallic", Variant(1.0))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.8, 0.85, 1.0)))
    floorModel:SetMaterial(floorMat)

    -- Spheres with varying roughness
    for i = 0, 6 do
        local sphereNode = scene_:CreateChild("Sphere_" .. i)
        sphereNode.position = Vector3(-9.0 + i * 3.0, 1.5, 0.0)
        sphereNode.scale = Vector3(1.5, 1.5, 1.5)
        local sphereModel = sphereNode:CreateComponent("StaticModel")
        sphereModel.model = cache:GetResource("Model", "Models/Sphere.mdl")
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("Roughness", Variant(i / 6.0))
        mat:SetShaderParameter("Metallic", Variant(1.0))
        mat:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.7, 0.5, 1.0)))
        sphereModel:SetMaterial(mat)
        sphereModel:SetCastShadows(true)
    end

    -- Corner geometry (SSAO test)
    CreateCornerGeometry()

    -- Colored pillars (SSR test)
    local colors = {
        Color(0.8, 0.2, 0.2, 1.0),
        Color(0.2, 0.8, 0.2, 1.0),
        Color(0.2, 0.2, 0.8, 1.0),
    }
    for i = 1, 3 do
        local pillarNode = scene_:CreateChild("Pillar_" .. i)
        pillarNode.position = Vector3(-6.0 + (i-1) * 6.0, 3.0, -8.0)
        pillarNode.scale = Vector3(1.0, 6.0, 1.0)
        local pillarModel = pillarNode:CreateComponent("StaticModel")
        pillarModel.model = cache:GetResource("Model", "Models/Cylinder.mdl")
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("Roughness", Variant(0.3))
        mat:SetShaderParameter("Metallic", Variant(0.9))
        mat:SetShaderParameter("MatDiffColor", Variant(colors[i]))
        pillarModel:SetMaterial(mat)
        pillarModel:SetCastShadows(true)
    end

    -- Moving sphere (Motion Vector test)
    movingNode = scene_:CreateChild("MovingObject")
    movingNode.position = Vector3(0.0, 2.0, 5.0)
    local movingModel = movingNode:CreateComponent("StaticModel")
    movingModel.model = cache:GetResource("Model", "Models/Sphere.mdl")
    local movingMat = Material:new()
    movingMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    movingMat:SetShaderParameter("Roughness", Variant(0.2))
    movingMat:SetShaderParameter("Metallic", Variant(1.0))
    movingMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.8, 0.0, 1.0)))
    movingModel:SetMaterial(movingMat)
    movingModel:SetCastShadows(true)

    -- Camera
    cameraNode = scene_:CreateChild("Camera")
    cameraNode:CreateComponent("Camera")
    cameraNode.position = Vector3(0.0, 5.0, -15.0)
    cameraNode:LookAt(Vector3(0.0, 1.0, 0.0))
    yaw = cameraNode.rotation:YawAngle()
    pitch = cameraNode.rotation:PitchAngle()
end

function CreateCornerGeometry()
    -- Stacked boxes for SSAO corner test
    local positions = {
        Vector3(-8.0, 0.5, 8.0),
        Vector3(-5.0, 0.5, 8.0),
        Vector3(-8.0, 1.5, 8.0),
        Vector3(-8.0, 0.5, 5.0),
    }
    for i, pos in ipairs(positions) do
        local boxNode = scene_:CreateChild("AOBox_" .. i)
        boxNode.position = pos
        local boxModel = boxNode:CreateComponent("StaticModel")
        boxModel.model = cache:GetResource("Model", "Models/Box.mdl")
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("Roughness", Variant(0.8))
        mat:SetShaderParameter("Metallic", Variant(0.0))
        mat:SetShaderParameter("MatDiffColor", Variant(Color(0.6, 0.6, 0.6, 1.0)))
        boxModel:SetMaterial(mat)
        boxModel:SetCastShadows(true)
    end

    -- L-shaped wall
    local wallMat = Material:new()
    wallMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    wallMat:SetShaderParameter("Roughness", Variant(0.7))
    wallMat:SetShaderParameter("Metallic", Variant(0.0))
    wallMat:SetShaderParameter("MatDiffColor", Variant(Color(0.5, 0.5, 0.55, 1.0)))

    local base = scene_:CreateChild("CornerBase")
    base.position = Vector3(8.0, 0.5, 8.0)
    base.scale = Vector3(3.0, 1.0, 3.0)
    local baseModel = base:CreateComponent("StaticModel")
    baseModel.model = cache:GetResource("Model", "Models/Box.mdl")
    baseModel:SetMaterial(wallMat)
    baseModel:SetCastShadows(true)

    local wall1 = scene_:CreateChild("Wall1")
    wall1.position = Vector3(9.0, 1.5, 8.0)
    wall1.scale = Vector3(1.0, 2.0, 3.0)
    local wall1Model = wall1:CreateComponent("StaticModel")
    wall1Model.model = cache:GetResource("Model", "Models/Box.mdl")
    wall1Model:SetMaterial(wallMat)
    wall1Model:SetCastShadows(true)

    local wall2 = scene_:CreateChild("Wall2")
    wall2.position = Vector3(8.0, 1.5, 9.0)
    wall2.scale = Vector3(3.0, 2.0, 1.0)
    local wall2Model = wall2:CreateComponent("StaticModel")
    wall2Model.model = cache:GetResource("Model", "Models/Box.mdl")
    wall2Model:SetMaterial(wallMat)
    wall2Model:SetCastShadows(true)
end

function SetupViewport()
    renderer.hdrRendering = true
    local viewport = Viewport:new(scene_, cameraNode:GetComponent("Camera"))
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- Animate moving object
    moveTime = moveTime + timeStep
    if movingNode then
        local x = math.sin(moveTime) * 5.0
        local z = math.cos(moveTime * 0.7) * 3.0 + 5.0
        local y = 2.0 + math.sin(moveTime * 2.0) * 0.5
        movingNode.position = Vector3(x, y, z)
    end

    MoveCamera(timeStep)
end

function MoveCamera(timeStep)
    local MOVE_SPEED = 10.0
    local MOUSE_SENSITIVITY = 0.1

    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local mouseMove = input.mouseMove
        yaw = yaw + MOUSE_SENSITIVITY * mouseMove.x
        pitch = pitch + MOUSE_SENSITIVITY * mouseMove.y
        pitch = Clamp(pitch, -90.0, 90.0)
        cameraNode.rotation = Quaternion(pitch, yaw, 0.0)
    end

    if input:GetKeyDown(KEY_W) then
        cameraNode:Translate(Vector3(0.0, 0.0, 1.0) * MOVE_SPEED * timeStep)
    end
    if input:GetKeyDown(KEY_S) then
        cameraNode:Translate(Vector3(0.0, 0.0, -1.0) * MOVE_SPEED * timeStep)
    end
    if input:GetKeyDown(KEY_A) then
        cameraNode:Translate(Vector3(-1.0, 0.0, 0.0) * MOVE_SPEED * timeStep)
    end
    if input:GetKeyDown(KEY_D) then
        cameraNode:Translate(Vector3(1.0, 0.0, 0.0) * MOVE_SPEED * timeStep)
    end
    if input:GetKeyDown(KEY_Q) then
        cameraNode:Translate(Vector3(0.0, -1.0, 0.0) * MOVE_SPEED * timeStep)
    end
    if input:GetKeyDown(KEY_E) then
        cameraNode:Translate(Vector3(0.0, 1.0, 0.0) * MOVE_SPEED * timeStep)
    end
end
