--[[
================================================================================
EditorParticleEffect.lua - Particle Effect Editor Module
================================================================================

Description:
    Complete particle effect editor implementation with real-time 3D preview,
    comprehensive property editing, and visual feedback. This is the most
    complex editor module with 1700+ lines of functionality.

Features:
    - Real-time 3D preview with interactive camera
    - Live particle effect editing and preview
    - Color frame animation editor
    - Texture frame animation editor
    - Full particle system property editor
    - Material picker integration
    - Save/Load/Revert functionality
    - Undo/Redo support
    - Interactive 3D gizmo and grid
    - Drag-slider input for all numeric values

Architecture:
    - Preview System: 3D scene with camera, lighting, and grid
    - Property Editors: Dedicated UI for each particle property
    - Frame Editors: Dynamic list views for color/texture animations
    - State Management: XML-based undo/redo system
    - Resource Integration: Picker dialogs for materials and effects

Editor UI Layout:
    +--------------------------------------------------+
    | Particle Effect Editor                    [X]    |
    +--------------------------------------------------+
    | [New] [Revert] [Save] [Save As] [Close]         |
    | Name: [_____________________________] [Pick]     |
    +--------------------------------------------------+
    |                3D Preview Window                 |
    |              (Interactive Camera)                |
    |              [Reset] [Show Grid]                 |
    +--------------------------------------------------+
    | Basic Properties (Expanded Sections):            |
    |   - Forces & Physics                             |
    |   - Timing & Emission                            |
    |   - Size & Rotation                              |
    |   - Emitter Shape & Behavior                     |
    +--------------------------------------------------+
    | Material: [_____________________] [Pick]         |
    +--------------------------------------------------+
    | Color Frames:                                    |
    |   [New] [Remove] [Sort]                          |
    |   +--------------------------------------------+  |
    |   | Time: 0.0  Color: [R] [G] [B] [A]         |  |
    |   | Time: 1.0  Color: [R] [G] [B] [A]         |  |
    |   +--------------------------------------------+  |
    +--------------------------------------------------+
    | Texture Frames:                                  |
    |   [New] [Remove] [Sort]                          |
    |   +--------------------------------------------+  |
    |   | Time: 0.0  UV: [MinX] [MinY] [MaxX] [MaxY]|  |
    |   +--------------------------------------------+  |
    +--------------------------------------------------+

Particle System Properties (Comprehensive):
    1. Forces & Physics:
       - Constant Force (Vector3)
       - Direction Range (Vector3 min/max)
       - Damping Force

    2. Timing:
       - Active Time
       - Inactive Time
       - Time To Live (min/max)

    3. Emission:
       - Num Particles
       - Emission Rate (min/max)
       - Emitter Size (Vector3)
       - Emitter Shape (Sphere/Box)

    4. Particle Properties:
       - Size (Vector2 min/max)
       - Velocity (min/max)
       - Rotation (min/max)
       - Rotation Speed (min/max)
       - Size Add
       - Size Multiply

    5. Rendering:
       - Material
       - Face Camera Mode (6 modes)
       - Scaled
       - Sorted
       - Relative
       - Fixed Screen Size
       - Animation LOD Bias

    6. Animation:
       - Color Frames (time + RGBA)
       - Texture Frames (time + UV rect)

Preview System:
    - 3D Scene: Dedicated scene for particle preview
    - Camera: Interactive orbital camera
    - Lighting: Directional light with configurable intensity
    - Grid: Configurable axis-aligned grid
    - Gizmo: 3D axes indicator
    - Controls:
      * Mouse Drag: Rotate camera (orbital)
      * Shift + Drag: Zoom in/out
      * Reset Button: Reset to default view

Frame Editors:
    - Color Frames:
      * Time value (0.0 - 1.0)
      * RGBA color (0.0 - 1.0 each)
      * Sorted by time automatically
      * Add/Remove dynamically

    - Texture Frames:
      * Time value (0.0 - 1.0)
      * UV rectangle (min.x, min.y, max.x, max.y)
      * Sorted by time automatically
      * Add/Remove dynamically

State Management:
    - Begin/End Edit: Captures old state for undo
    - XML Serialization: Stores complete effect state
    - Action System: Integration with editor undo/redo
    - Auto-reset: Emitter resets on property changes

Usage:
    -- Show editor with new effect
    CreateParticleEffectEditor()
    ShowParticleEffectEditor()

    -- Edit existing effect
    local effect = cache:GetResource("ParticleEffect", "Particle/Smoke.xml")
    EditParticleEffect(effect)

    -- Toggle editor visibility
    ToggleParticleEffectEditor()

Dependencies:
    - EditorUI.lua: UI loading and styling
    - EditorActions.lua: Undo/redo system
    - EditorView.lua: Resource picker integration
    - UI/EditorParticleEffectWindow.xml: UI layout definition

Constants:
    - EMITTER_SPHERE, EMITTER_BOX: Emitter shape types
    - FC_NONE, FC_ROTATE_XYZ, FC_ROTATE_Y, FC_LOOKAT_XYZ,
      FC_LOOKAT_Y, FC_DIRECTION: Face camera modes
    - M_MAX_UNSIGNED: Maximum unsigned int (for selection checks)

Notes:
    - Largest editor module (1700+ lines)
    - Real-time preview updates on all changes
    - Automatic frame sorting for animations
    - Drag sliders on all numeric inputs
    - Material picker integration
    - Full undo/redo support
    - Live particle system visualization

Author: Converted from AngelScript to Lua
Date: 2025-01-22
Version: 1.0
================================================================================
--]]

-- Module state variables
particleEffectWindow = nil
editParticleEffect = nil
oldParticleEffectState = nil
inParticleEffectRefresh = false

-- Preview scene components
particleEffectPreview = nil
particlePreviewCamera = nil
particlePreviewScene = nil
particleEffectPreviewNode = nil
particleEffectPreviewGizmoNode = nil
particleEffectPreviewGridNode = nil
particleEffectPreviewGrid = nil
particlePreviewCameraNode = nil
particlePreviewLightNode = nil
particlePreviewLight = nil
particleEffectEmitter = nil

-- Preview state
particleResetTimer = 0
showParticlePreviewAxes = true
particleViewCamDir = Vector3()
particleViewCamRot = Vector3()
particleViewCamDist = 0

-- Gizmo positioning
local gizmoOffset = 0.1
local gizmoOffsetX = 0
local gizmoOffsetY = 0

--------------------------------------------------------------------------------
-- Window Creation and Initialization
--------------------------------------------------------------------------------

function CreateParticleEffectEditor()
    if particleEffectWindow ~= nil then
        return
    end

    particleEffectWindow = LoadEditorUI("UI/EditorParticleEffectWindow.xml")
    ui.root:AddChild(particleEffectWindow)
    particleEffectWindow.opacity = uiMaxOpacity

    InitParticleEffectPreview()
    InitParticleEffectBasicAttributes()
    RefreshParticleEffectEditor()

    local width = math.min(ui.root.width - 60, 800)
    local height = math.min(ui.root.height - 60, 600)
    particleEffectWindow:SetSize(width, height)
    CenterDialog(particleEffectWindow)

    HideParticleEffectEditor()

    -- Button events
    SubscribeToEvent(particleEffectWindow:GetChild("NewButton", true), "Released", "NewParticleEffect")
    SubscribeToEvent(particleEffectWindow:GetChild("RevertButton", true), "Released", "RevertParticleEffect")
    SubscribeToEvent(particleEffectWindow:GetChild("SaveButton", true), "Released", "SaveParticleEffect")
    SubscribeToEvent(particleEffectWindow:GetChild("SaveAsButton", true), "Released", "SaveParticleEffectAs")
    SubscribeToEvent(particleEffectWindow:GetChild("CloseButton", true), "Released", "HideParticleEffectEditor")

    -- Color frame events
    SubscribeToEvent(particleEffectWindow:GetChild("NewColorFrame", true), "Released", "EditParticleEffectColorFrameNew")
    SubscribeToEvent(particleEffectWindow:GetChild("RemoveColorFrame", true), "Released", "EditParticleEffectColorFrameRemove")
    SubscribeToEvent(particleEffectWindow:GetChild("ColorFrameSort", true), "Released", "EditParticleEffectColorFrameSort")

    -- Texture frame events
    SubscribeToEvent(particleEffectWindow:GetChild("NewTextureFrame", true), "Released", "EditParticleEffectTextureFrameNew")
    SubscribeToEvent(particleEffectWindow:GetChild("RemoveTextureFrame", true), "Released", "EditParticleEffectTextureFrameRemove")
    SubscribeToEvent(particleEffectWindow:GetChild("TextureFrameSort", true), "Released", "EditParticleEffectTextureFrameSort")

    -- Property change events (TextChanged for live preview)
    local textChangedElements = {
        "ConstantForceX", "ConstantForceY", "ConstantForceZ",
        "DirectionMinX", "DirectionMinY", "DirectionMinZ",
        "DirectionMaxX", "DirectionMaxY", "DirectionMaxZ",
        "DampingForce", "ActiveTime", "InactiveTime",
        "ParticleSizeMinX", "ParticleSizeMinY",
        "ParticleSizeMaxX", "ParticleSizeMaxY",
        "TimeToLiveMin", "TimeToLiveMax",
        "VelocityMin", "VelocityMax",
        "RotationMin", "RotationMax",
        "RotationSpeedMin", "RotationSpeedMax",
        "SizeAdd", "SizeMultiply", "AnimationLodBias",
        "NumParticles",
        "EmitterSizeX", "EmitterSizeY", "EmitterSizeZ",
        "EmissionRateMin", "EmissionRateMax"
    }

    local handlers = {
        ConstantForceX = "EditParticleEffectConstantForce",
        ConstantForceY = "EditParticleEffectConstantForce",
        ConstantForceZ = "EditParticleEffectConstantForce",
        DirectionMinX = "EditParticleEffectDirection",
        DirectionMinY = "EditParticleEffectDirection",
        DirectionMinZ = "EditParticleEffectDirection",
        DirectionMaxX = "EditParticleEffectDirection",
        DirectionMaxY = "EditParticleEffectDirection",
        DirectionMaxZ = "EditParticleEffectDirection",
        DampingForce = "EditParticleEffectDampingForce",
        ActiveTime = "EditParticleEffectActiveTime",
        InactiveTime = "EditParticleEffectInactiveTime",
        ParticleSizeMinX = "EditParticleEffectParticleSize",
        ParticleSizeMinY = "EditParticleEffectParticleSize",
        ParticleSizeMaxX = "EditParticleEffectParticleSize",
        ParticleSizeMaxY = "EditParticleEffectParticleSize",
        TimeToLiveMin = "EditParticleEffectTimeToLive",
        TimeToLiveMax = "EditParticleEffectTimeToLive",
        VelocityMin = "EditParticleEffectVelocity",
        VelocityMax = "EditParticleEffectVelocity",
        RotationMin = "EditParticleEffectRotation",
        RotationMax = "EditParticleEffectRotation",
        RotationSpeedMin = "EditParticleEffectRotationSpeed",
        RotationSpeedMax = "EditParticleEffectRotationSpeed",
        SizeAdd = "EditParticleEffectSizeAdd",
        SizeMultiply = "EditParticleEffectSizeMultiply",
        AnimationLodBias = "EditParticleEffectAnimationLodBias",
        NumParticles = "EditParticleEffectNumParticles",
        EmitterSizeX = "EditParticleEffectEmitterSize",
        EmitterSizeY = "EditParticleEffectEmitterSize",
        EmitterSizeZ = "EditParticleEffectEmitterSize",
        EmissionRateMin = "EditParticleEffectEmissionRate",
        EmissionRateMax = "EditParticleEffectEmissionRate"
    }

    -- Subscribe to TextChanged events
    for _, name in ipairs(textChangedElements) do
        local element = particleEffectWindow:GetChild(name, true)
        if element ~= nil then
            SubscribeToEvent(element, "TextChanged", handlers[name])
            SubscribeToEvent(element, "TextFinished", handlers[name])
        end
    end

    -- Dropdown and checkbox events
    SubscribeToEvent(particleEffectWindow:GetChild("EmitterShape", true), "ItemSelected", "EditParticleEffectEmitterShape")
    SubscribeToEvent(particleEffectWindow:GetChild("Scaled", true), "Toggled", "EditParticleEffectScaled")
    SubscribeToEvent(particleEffectWindow:GetChild("Sorted", true), "Toggled", "EditParticleEffectSorted")
    SubscribeToEvent(particleEffectWindow:GetChild("Relative", true), "Toggled", "EditParticleEffectRelative")
    SubscribeToEvent(particleEffectWindow:GetChild("FixedScreenSize", true), "Toggled", "EditParticleEffectFixedScreenSize")
    SubscribeToEvent(particleEffectWindow:GetChild("FaceCameraMode", true), "ItemSelected", "EditParticleEffectFaceCameraMode")

    -- Preview controls
    SubscribeToEvent(particleEffectWindow:GetChild("ResetViewport", true), "Released", "ParticleEffectResetViewport")
    SubscribeToEvent(particleEffectWindow:GetChild("ShowGrid", true), "Toggled", "ParticleEffectShowGrid")
end

--------------------------------------------------------------------------------
-- Gizmo and Camera Management
--------------------------------------------------------------------------------

function SetGizmoPosition()
    local screenPos = Vector3(gizmoOffsetX, gizmoOffsetY, 25.0)
    local newPos = particlePreviewCamera:ScreenToWorldPoint(screenPos)
    particleEffectPreviewGizmoNode.position = newPos
end

function ResetCameraTransformation()
    particlePreviewCameraNode.position = Vector3(0, 0, -5)
    particlePreviewCameraNode:LookAt(Vector3(0, 0, 0))
    particleViewCamDir = particlePreviewCameraNode.position * -1.0

    -- Manually set initial rotation because eulerAngles always return 0 on first frame
    particleViewCamRot = Vector3(0.0, 180.0, 0.0)

    particleViewCamDist = particleViewCamDir.length
    particleViewCamDir:Normalize()
end

function ParticleEffectResetViewport(eventType, eventData)
    ResetCameraTransformation()
    SetGizmoPosition()
    particleEffectPreview:QueueUpdate()
end

function ParticleEffectShowGrid(eventType, eventData)
    local element = eventData["Element"]:GetPtr()
    showParticlePreviewAxes = element.checked
    particleEffectPreviewGridNode.enabled = showParticlePreviewAxes
    particleEffectPreview:QueueUpdate()
end

--------------------------------------------------------------------------------
-- Color Frame Management
--------------------------------------------------------------------------------

function EditParticleEffectColorFrameNew(eventType, eventData)
    if inParticleEffectRefresh then
        return
    end

    if editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local num = editParticleEffect.numColorFrames
    editParticleEffect.numColorFrames = num + 1
    RefreshParticleEffectColorFrames()

    EndParticleEffectEdit()
end

function EditParticleEffectColorFrameRemove(eventType, eventData)
    if inParticleEffectRefresh then
        return
    end

    if editParticleEffect == nil then
        return
    end

    local lv = particleEffectWindow:GetChild("ColorFrameListView", true)
    if lv ~= nil and lv.selection ~= M_MAX_UNSIGNED then
        BeginParticleEffectEdit()

        editParticleEffect:RemoveColorFrame(lv.selection)
        RefreshParticleEffectColorFrames()

        EndParticleEffectEdit()
    end
end

function EditParticleEffectColorFrameSort(eventType, eventData)
    RefreshParticleEffectColorFrames()
end

function EditParticleEffectColorFrame(eventType, eventData)
    if inParticleEffectRefresh then
        return
    end

    if editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    local i = element:GetVar("ColorFrame"):GetInt()
    local cf = editParticleEffect:GetColorFrame(i)

    if element.name == "ColorTime" then
        cf.time = tonumber(element.text)
    elseif element.name == "ColorR" then
        cf.color = Color(tonumber(element.text), cf.color.g, cf.color.b, cf.color.a)
    elseif element.name == "ColorG" then
        cf.color = Color(cf.color.r, tonumber(element.text), cf.color.b, cf.color.a)
    elseif element.name == "ColorB" then
        cf.color = Color(cf.color.r, cf.color.g, tonumber(element.text), cf.color.a)
    elseif element.name == "ColorA" then
        cf.color = Color(cf.color.r, cf.color.g, cf.color.b, tonumber(element.text))
    end

    editParticleEffect:SetColorFrame(i, cf)
    particleEffectEmitter:Reset()

    EndParticleEffectEdit()
end

--------------------------------------------------------------------------------
-- Texture Frame Management
--------------------------------------------------------------------------------

function EditParticleEffectTextureFrameNew(eventType, eventData)
    if inParticleEffectRefresh then
        return
    end

    if editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local num = editParticleEffect.numTextureFrames
    editParticleEffect.numTextureFrames = num + 1
    RefreshParticleEffectTextureFrames()

    EndParticleEffectEdit()
end

function EditParticleEffectTextureFrameRemove(eventType, eventData)
    if inParticleEffectRefresh then
        return
    end

    if editParticleEffect == nil then
        return
    end

    local lv = particleEffectWindow:GetChild("TextureFrameListView", true)
    if lv ~= nil and lv.selection ~= M_MAX_UNSIGNED then
        BeginParticleEffectEdit()

        editParticleEffect:RemoveTextureFrame(lv.selection)
        RefreshParticleEffectTextureFrames()

        EndParticleEffectEdit()
    end
end

function EditParticleEffectTextureFrameSort(eventType, eventData)
    RefreshParticleEffectTextureFrames()
end

function EditParticleEffectTextureFrame(eventType, eventData)
    if inParticleEffectRefresh then
        return
    end

    if editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    local i = element:GetVar("TextureFrame"):GetInt()
    local tf = editParticleEffect:GetTextureFrame(i)

    if element.name == "TextureTime" then
        tf.time = tonumber(element.text)
    elseif element.name == "TextureMinX" then
        tf.uv = Rect(tonumber(element.text), tf.uv.min.y, tf.uv.max.x, tf.uv.max.y)
    elseif element.name == "TextureMinY" then
        tf.uv = Rect(tf.uv.min.x, tonumber(element.text), tf.uv.max.x, tf.uv.max.y)
    elseif element.name == "TextureMaxX" then
        tf.uv = Rect(tf.uv.min.x, tf.uv.min.y, tonumber(element.text), tf.uv.max.y)
    elseif element.name == "TextureMaxY" then
        tf.uv = Rect(tf.uv.min.x, tf.uv.min.y, tf.uv.max.x, tonumber(element.text))
    end

    editParticleEffect:SetTextureFrame(i, tf)
    particleEffectEmitter:Reset()

    EndParticleEffectEdit()
end

--------------------------------------------------------------------------------
-- Drag Slider Initialization
--------------------------------------------------------------------------------

function InitParticleEffectBasicAttributes()
    -- Create drag sliders for all numeric input fields
    local sliderElements = {
        "ConstantForceX", "ConstantForceY", "ConstantForceZ",
        "DirectionMinX", "DirectionMinY", "DirectionMinZ",
        "DirectionMaxX", "DirectionMaxY", "DirectionMaxZ",
        "DampingForce", "ActiveTime", "InactiveTime",
        "ParticleSizeMinX", "ParticleSizeMinY",
        "ParticleSizeMaxX", "ParticleSizeMaxY",
        "TimeToLiveMin", "TimeToLiveMax",
        "VelocityMin", "VelocityMax",
        "RotationMin", "RotationMax",
        "RotationSpeedMin", "RotationSpeedMax",
        "SizeAdd", "SizeMultiply", "AnimationLodBias",
        "NumParticles",
        "EmitterSizeX", "EmitterSizeY", "EmitterSizeZ",
        "EmissionRateMin", "EmissionRateMax"
    }

    for _, name in ipairs(sliderElements) do
        local element = particleEffectWindow:GetChild(name, true)
        if element ~= nil then
            CreateDragSlider(tolua.cast(element, "LineEdit"))
        end
    end
end

--------------------------------------------------------------------------------
-- Property Editors - Forces and Physics
--------------------------------------------------------------------------------

function EditParticleEffectConstantForce(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    local v = editParticleEffect.constantForce

    if element.name == "ConstantForceX" then
        editParticleEffect.constantForce = Vector3(tonumber(element.text), v.y, v.z)
    elseif element.name == "ConstantForceY" then
        editParticleEffect.constantForce = Vector3(v.x, tonumber(element.text), v.z)
    elseif element.name == "ConstantForceZ" then
        editParticleEffect.constantForce = Vector3(v.x, v.y, tonumber(element.text))
    end

    EndParticleEffectEdit()
end

function EditParticleEffectDirection(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    local vMin = editParticleEffect.minDirection
    local vMax = editParticleEffect.maxDirection

    if element.name == "DirectionMinX" then
        editParticleEffect.minDirection = Vector3(tonumber(element.text), vMin.y, vMin.z)
    elseif element.name == "DirectionMinY" then
        editParticleEffect.minDirection = Vector3(vMin.x, tonumber(element.text), vMin.z)
    elseif element.name == "DirectionMinZ" then
        editParticleEffect.minDirection = Vector3(vMin.x, vMin.y, tonumber(element.text))
    elseif element.name == "DirectionMaxX" then
        editParticleEffect.maxDirection = Vector3(tonumber(element.text), vMax.y, vMax.z)
    elseif element.name == "DirectionMaxY" then
        editParticleEffect.maxDirection = Vector3(vMax.x, tonumber(element.text), vMax.z)
    elseif element.name == "DirectionMaxZ" then
        editParticleEffect.maxDirection = Vector3(vMax.x, vMax.y, tonumber(element.text))
    end

    EndParticleEffectEdit()
end

function EditParticleEffectDampingForce(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.dampingForce = tonumber(element.text)

    EndParticleEffectEdit()
end

--------------------------------------------------------------------------------
-- Property Editors - Timing
--------------------------------------------------------------------------------

function EditParticleEffectActiveTime(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.activeTime = tonumber(element.text)
    particleEffectEmitter:Reset()

    EndParticleEffectEdit()
end

function EditParticleEffectInactiveTime(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.inactiveTime = tonumber(element.text)
    particleEffectEmitter:Reset()

    EndParticleEffectEdit()
end

function EditParticleEffectTimeToLive(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()

    if element.name == "TimeToLiveMin" then
        editParticleEffect.minTimeToLive = tonumber(element.text)
    elseif element.name == "TimeToLiveMax" then
        editParticleEffect.maxTimeToLive = tonumber(element.text)
    end

    EndParticleEffectEdit()
end

--------------------------------------------------------------------------------
-- Property Editors - Size and Rotation
--------------------------------------------------------------------------------

function EditParticleEffectParticleSize(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    local vMin = editParticleEffect.minParticleSize
    local vMax = editParticleEffect.maxParticleSize

    if element.name == "ParticleSizeMinX" then
        editParticleEffect.minParticleSize = Vector2(tonumber(element.text), vMin.y)
    elseif element.name == "ParticleSizeMinY" then
        editParticleEffect.minParticleSize = Vector2(vMin.x, tonumber(element.text))
    elseif element.name == "ParticleSizeMaxX" then
        editParticleEffect.maxParticleSize = Vector2(tonumber(element.text), vMax.y)
    elseif element.name == "ParticleSizeMaxY" then
        editParticleEffect.maxParticleSize = Vector2(vMax.x, tonumber(element.text))
    end

    EndParticleEffectEdit()
end

function EditParticleEffectVelocity(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()

    if element.name == "VelocityMin" then
        editParticleEffect.minVelocity = tonumber(element.text)
    elseif element.name == "VelocityMax" then
        editParticleEffect.maxVelocity = tonumber(element.text)
    end

    EndParticleEffectEdit()
end

function EditParticleEffectRotation(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()

    if element.name == "RotationMin" then
        editParticleEffect.minRotation = tonumber(element.text)
    elseif element.name == "RotationMax" then
        editParticleEffect.maxRotation = tonumber(element.text)
    end

    EndParticleEffectEdit()
end

function EditParticleEffectRotationSpeed(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()

    if element.name == "RotationSpeedMin" then
        editParticleEffect.minRotationSpeed = tonumber(element.text)
    elseif element.name == "RotationSpeedMax" then
        editParticleEffect.maxRotationSpeed = tonumber(element.text)
    end

    EndParticleEffectEdit()
end

function EditParticleEffectSizeAdd(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.sizeAdd = tonumber(element.text)

    EndParticleEffectEdit()
end

function EditParticleEffectSizeMultiply(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.sizeMul = tonumber(element.text)

    EndParticleEffectEdit()
end

function EditParticleEffectAnimationLodBias(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.animationLodBias = tonumber(element.text)

    EndParticleEffectEdit()
end

--------------------------------------------------------------------------------
-- Property Editors - Emission
--------------------------------------------------------------------------------

function EditParticleEffectNumParticles(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.numParticles = math.floor(tonumber(element.text))
    particleEffectEmitter:ApplyEffect()

    EndParticleEffectEdit()
end

function EditParticleEffectEmitterSize(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    local v = editParticleEffect.emitterSize

    if element.name == "EmitterSizeX" then
        editParticleEffect.emitterSize = Vector3(tonumber(element.text), v.y, v.z)
    elseif element.name == "EmitterSizeY" then
        editParticleEffect.emitterSize = Vector3(v.x, tonumber(element.text), v.z)
    elseif element.name == "EmitterSizeZ" then
        editParticleEffect.emitterSize = Vector3(v.x, v.y, tonumber(element.text))
    end

    EndParticleEffectEdit()
end

function EditParticleEffectEmissionRate(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()

    if element.name == "EmissionRateMin" then
        editParticleEffect.minEmissionRate = tonumber(element.text)
    elseif element.name == "EmissionRateMax" then
        editParticleEffect.maxEmissionRate = tonumber(element.text)
    end

    EndParticleEffectEdit()
end

function EditParticleEffectEmitterShape(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()

    if element.selection == 0 then
        editParticleEffect.emitterType = EMITTER_SPHERE
    elseif element.selection == 1 then
        editParticleEffect.emitterType = EMITTER_BOX
    end

    EndParticleEffectEdit()
end

--------------------------------------------------------------------------------
-- Property Editors - Rendering
--------------------------------------------------------------------------------

function EditParticleEffectFaceCameraMode(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()

    if element.selection == 0 then
        editParticleEffect.faceCameraMode = FC_NONE
    elseif element.selection == 1 then
        editParticleEffect.faceCameraMode = FC_ROTATE_XYZ
    elseif element.selection == 2 then
        editParticleEffect.faceCameraMode = FC_ROTATE_Y
    elseif element.selection == 3 then
        editParticleEffect.faceCameraMode = FC_LOOKAT_XYZ
    elseif element.selection == 4 then
        editParticleEffect.faceCameraMode = FC_LOOKAT_Y
    elseif element.selection == 5 then
        editParticleEffect.faceCameraMode = FC_DIRECTION
    end

    particleEffectEmitter:ApplyEffect()

    EndParticleEffectEdit()
end

function EditParticleEffectMaterial(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    local element = eventData["Element"]:GetPtr()
    local res = cache:GetResource("Material", element.text)

    if res ~= nil then
        BeginParticleEffectEdit()

        editParticleEffect.material = res
        particleEffectEmitter:ApplyEffect()

        EndParticleEffectEdit()
    end
end

function PickEditParticleEffectMaterial()
    resourcePicker = GetResourcePicker(StringHash("Material"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath:Empty() then
        lastPath = sceneResourcePath
    end
    CreateFileSelector(localization:Get("Pick ") .. resourcePicker.typeName, "OK", "Cancel",
                      lastPath, resourcePicker.filters, resourcePicker.lastFilter, false)
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickEditParticleEffectMaterialDone")
end

function PickEditParticleEffectMaterialDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local resourceName = eventData["FileName"]:GetString()
    local res = GetPickedResource(resourceName)

    if res ~= nil and editParticleEffect ~= nil and particleEffectEmitter ~= nil then
        editParticleEffect.material = res
        particleEffectEmitter:ApplyEffect()
        RefreshParticleEffectMaterial()
    end

    resourcePicker = nil
end

function EditParticleEffectScaled(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.scaled = element.checked
    particleEffectEmitter:ApplyEffect()

    EndParticleEffectEdit()
end

function EditParticleEffectSorted(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.sorted = element.checked
    particleEffectEmitter:ApplyEffect()

    EndParticleEffectEdit()
end

function EditParticleEffectRelative(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.relative = element.checked
    particleEffectEmitter:ApplyEffect()

    EndParticleEffectEdit()
end

function EditParticleEffectFixedScreenSize(eventType, eventData)
    if inParticleEffectRefresh or editParticleEffect == nil or particleEffectEmitter == nil then
        return
    end

    BeginParticleEffectEdit()

    local element = eventData["Element"]:GetPtr()
    editParticleEffect.fixedScreenSize = element.checked
    particleEffectEmitter:ApplyEffect()

    EndParticleEffectEdit()
end

--------------------------------------------------------------------------------
-- Window Visibility
--------------------------------------------------------------------------------

function ToggleParticleEffectEditor()
    if particleEffectWindow.visible == false then
        ShowParticleEffectEditor()
    else
        HideParticleEffectEditor()
    end
    return true
end

function ShowParticleEffectEditor()
    RefreshParticleEffectEditor()
    particleEffectWindow.visible = true
    particleEffectWindow:BringToFront()
end

function HideParticleEffectEditor()
    if particleEffectWindow ~= nil then
        particleEffectWindow.visible = false
    end
end

--------------------------------------------------------------------------------
-- Preview Grid
--------------------------------------------------------------------------------

function UpdateParticleEffectPreviewGrid()
    local gridSize = 8
    local gridSubdivisions = 3

    local size = math.floor(gridSize / 2) * 2
    local halfSizeScaled = size / 2
    local scale = 1.0
    local subdivisionSize = math.floor(2.0 ^ gridSubdivisions)

    if subdivisionSize > 0 then
        size = size * subdivisionSize
        scale = scale / subdivisionSize
    end

    local halfSize = math.floor(size / 2)

    particleEffectPreviewGrid:BeginGeometry(0, LINE_LIST)
    local lineOffset = -halfSizeScaled

    for i = 0, size do
        local lineCenter = (i == halfSize)
        local lineSubdiv = (math.fmod(i, subdivisionSize) ~= 0)

        if not grid2DMode then
            particleEffectPreviewGrid:DefineVertex(Vector3(lineOffset, 0.0, halfSizeScaled))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridZColor or (lineSubdiv and gridSubdivisionColor or gridColor))
            particleEffectPreviewGrid:DefineVertex(Vector3(lineOffset, 0.0, -halfSizeScaled))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridZColor or (lineSubdiv and gridSubdivisionColor or gridColor))

            particleEffectPreviewGrid:DefineVertex(Vector3(-halfSizeScaled, 0.0, lineOffset))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridXColor or (lineSubdiv and gridSubdivisionColor or gridColor))
            particleEffectPreviewGrid:DefineVertex(Vector3(halfSizeScaled, 0.0, lineOffset))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridXColor or (lineSubdiv and gridSubdivisionColor or gridColor))
        else
            particleEffectPreviewGrid:DefineVertex(Vector3(lineOffset, halfSizeScaled, 0.0))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridYColor or (lineSubdiv and gridSubdivisionColor or gridColor))
            particleEffectPreviewGrid:DefineVertex(Vector3(lineOffset, -halfSizeScaled, 0.0))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridYColor or (lineSubdiv and gridSubdivisionColor or gridColor))

            particleEffectPreviewGrid:DefineVertex(Vector3(-halfSizeScaled, lineOffset, 0.0))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridXColor or (lineSubdiv and gridSubdivisionColor or gridColor))
            particleEffectPreviewGrid:DefineVertex(Vector3(halfSizeScaled, lineOffset, 0.0))
            particleEffectPreviewGrid:DefineColor(lineCenter and gridXColor or (lineSubdiv and gridSubdivisionColor or gridColor))
        end

        lineOffset = lineOffset + scale
    end

    particleEffectPreviewGrid:Commit()
end

--------------------------------------------------------------------------------
-- Preview Scene Initialization
--------------------------------------------------------------------------------

function InitParticleEffectPreview()
    particlePreviewScene = Scene()
    particlePreviewScene.name = "particlePreviewScene"
    particlePreviewScene:CreateComponent("Octree")

    local zoneNode = particlePreviewScene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000, 1000)
    zone.ambientColor = Color(0.15, 0.15, 0.15)
    zone.fogColor = Color(0, 0, 0)
    zone.fogStart = 10.0
    zone.fogEnd = 1000.0

    particlePreviewCameraNode = particlePreviewScene:CreateChild("PreviewCamera")
    particlePreviewCamera = particlePreviewCameraNode:CreateComponent("Camera")
    particlePreviewCamera.nearClip = 0.1
    particlePreviewCamera.farClip = 1000.0
    particlePreviewCamera.fov = 45.0

    particlePreviewLightNode = particlePreviewScene:CreateChild("particlePreviewLight")
    particlePreviewLightNode.direction = Vector3(0.5, -0.5, 0.5)
    particlePreviewLight = particlePreviewLightNode:CreateComponent("Light")
    particlePreviewLight.lightType = LIGHT_DIRECTIONAL
    particlePreviewLight.specularIntensity = 0.5

    particleEffectPreviewNode = particlePreviewScene:CreateChild("PreviewEmitter")
    particleEffectPreviewNode.rotation = Quaternion(0, 0, 0)

    ResetCameraTransformation()

    particleEffectPreviewGizmoNode = particlePreviewScene:CreateChild("Gizmo")
    local gizmo = particleEffectPreviewGizmoNode:CreateComponent("StaticModel")
    gizmo.model = cache:GetResource("Model", "Models/Editor/Axes.mdl")
    gizmo:SetMaterial(0, cache:GetResource("Material", "Materials/Editor/RedUnlit.xml"))
    gizmo:SetMaterial(1, cache:GetResource("Material", "Materials/Editor/GreenUnlit.xml"))
    gizmo:SetMaterial(2, cache:GetResource("Material", "Materials/Editor/BlueUnlit.xml"))
    gizmo.occludee = false

    particleEffectPreviewGridNode = particlePreviewScene:CreateChild("Grid")
    particleEffectPreviewGrid = particleEffectPreviewGridNode:CreateComponent("CustomGeometry")
    particleEffectPreviewGrid.numGeometries = 1
    particleEffectPreviewGrid.material = cache:GetResource("Material", "Materials/VColUnlit.xml")
    particleEffectPreviewGrid.viewMask = 0x80000000
    particleEffectPreviewGrid.occludee = false

    UpdateParticleEffectPreviewGrid()

    particleEffectEmitter = particleEffectPreviewNode:CreateComponent("ParticleEmitter")
    editParticleEffect = CreateNewParticleEffect()
    particleEffectEmitter.effect = editParticleEffect

    particleEffectPreview = particleEffectWindow:GetChild("ParticleEffectPreview", true)
    particleEffectPreview:SetView(particlePreviewScene, particlePreviewCamera)

    -- Set render path (viewport may not be available immediately)
    if particleEffectPreview.viewport ~= nil then
        particleEffectPreview.viewport.renderPath = renderPath
    end

    SubscribeToEvent(particleEffectPreview, "DragMove", "NavigateParticleEffectPreview")
    SubscribeToEvent(particleEffectPreview, "Resized", "ResizeParticleEffectPreview")
end

function CreateNewParticleEffect()
    local effect = ParticleEffect()
    local res = cache:GetResource("Material", "Materials/Particle.xml")
    if res == nil then
        log:Error("Could not load default material for new particle effect.")
    end
    effect.material = res
    effect:AddColorTime(Color(1, 1, 1, 1), 0.0)
    return effect
end

--------------------------------------------------------------------------------
-- Effect Loading and Editing
--------------------------------------------------------------------------------

function EditParticleEffect(effect)
    if effect == nil then
        return
    end

    if editParticleEffect ~= nil then
        UnsubscribeFromEvent(editParticleEffect, "ReloadFinished")
    end

    if not effect.name:Empty() then
        cache:ReloadResource(effect)
    end

    editParticleEffect = effect
    particleEffectEmitter.effect = editParticleEffect

    if editParticleEffect ~= nil then
        SubscribeToEvent(editParticleEffect, "ReloadFinished", "RefreshParticleEffectEditor")
    end

    ShowParticleEffectEditor()
end

function RefreshParticleEffectEditor()
    inParticleEffectRefresh = true

    RefreshParticleEffectPreview()
    RefreshParticleEffectName()
    RefreshParticleEffectBasicAttributes()
    RefreshParticleEffectMaterial()
    RefreshParticleEffectColorFrames()
    RefreshParticleEffectTextureFrames()

    inParticleEffectRefresh = false
end

--------------------------------------------------------------------------------
-- Color Frame Refresh
--------------------------------------------------------------------------------

function RefreshParticleEffectColorFrames()
    if editParticleEffect == nil then
        return
    end

    editParticleEffect:SortColorFrames()

    local lv = particleEffectWindow:GetChild("ColorFrameListView", true)
    if lv == nil then
        return
    end

    lv:RemoveAllItems()

    for i = 0, editParticleEffect.numColorFrames - 1 do
        local colorFrame = editParticleEffect:GetColorFrame(i)

        local container = Button()
        lv:AddItem(container)
        container.style = "Button"
        container.imageRect = IntRect(18, 2, 30, 14)
        container.minSize = IntVector2(0, 20)
        container.maxSize = IntVector2(2147483647, 20)
        container.layoutMode = LM_HORIZONTAL
        container.layoutBorder = IntRect(3, 1, 3, 1)
        container.layoutSpacing = 4

        local labelContainer = UIElement()
        container:AddChild(labelContainer)
        labelContainer.style = "HorizontalPanel"
        labelContainer.minSize = IntVector2(0, 16)
        labelContainer.maxSize = IntVector2(2147483647, 16)
        labelContainer.verticalAlignment = VA_CENTER

        -- Time edit
        do
            local le = LineEdit()
            labelContainer:AddChild(le)
            le.name = "ColorTime"
            le:SetVar("ColorFrame", Variant(i))
            le.style = "LineEdit"
            le.minSize = IntVector2(0, 16)
            le.maxSize = IntVector2(40, 16)
            le.text = tostring(colorFrame.time)
            le.cursorPosition = 0
            CreateDragSlider(le)

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectColorFrame")
        end

        local textContainer = UIElement()
        labelContainer:AddChild(textContainer)
        textContainer.minSize = IntVector2(0, 16)
        textContainer.maxSize = IntVector2(2147483647, 16)
        textContainer.verticalAlignment = VA_CENTER

        local t = Text()
        textContainer:AddChild(t)
        t.style = "Text"
        t.text = "Color"
        t.autoLocalizable = true

        local editContainer = UIElement()
        container:AddChild(editContainer)
        editContainer.style = "HorizontalPanel"
        editContainer.minSize = IntVector2(0, 16)
        editContainer.maxSize = IntVector2(2147483647, 16)
        editContainer.verticalAlignment = VA_CENTER

        -- R, G, B, A edits
        local components = {"ColorR", "ColorG", "ColorB", "ColorA"}
        local values = {colorFrame.color.r, colorFrame.color.g, colorFrame.color.b, colorFrame.color.a}

        for j = 1, 4 do
            local le = LineEdit()
            editContainer:AddChild(le)
            le.name = components[j]
            le:SetVar("ColorFrame", Variant(i))
            le.style = "LineEdit"
            le.text = tostring(values[j])
            le.cursorPosition = 0
            CreateDragSlider(le)

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectColorFrame")
        end
    end
end

--------------------------------------------------------------------------------
-- Texture Frame Refresh
--------------------------------------------------------------------------------

function RefreshParticleEffectTextureFrames()
    if editParticleEffect == nil then
        return
    end

    editParticleEffect:SortTextureFrames()

    local lv = particleEffectWindow:GetChild("TextureFrameListView", true)
    if lv == nil then
        return
    end

    lv:RemoveAllItems()

    for i = 0, editParticleEffect.numTextureFrames - 1 do
        local textureFrame = editParticleEffect:GetTextureFrame(i)
        if textureFrame == nil then
            goto continue
        end

        local container = Button()
        lv:AddItem(container)
        container.style = "Button"
        container.imageRect = IntRect(18, 2, 30, 14)
        container.minSize = IntVector2(0, 20)
        container.maxSize = IntVector2(2147483647, 20)
        container.layoutMode = LM_HORIZONTAL
        container.layoutBorder = IntRect(1, 1, 1, 1)
        container.layoutSpacing = 4

        local labelContainer = UIElement()
        container:AddChild(labelContainer)
        labelContainer.style = "HorizontalPanel"
        labelContainer.minSize = IntVector2(0, 16)
        labelContainer.maxSize = IntVector2(2147483647, 16)
        labelContainer.verticalAlignment = VA_CENTER

        -- Time edit
        do
            local le = LineEdit()
            labelContainer:AddChild(le)
            le.name = "TextureTime"
            le:SetVar("TextureFrame", Variant(i))
            le.style = "LineEdit"
            le.minSize = IntVector2(0, 16)
            le.maxSize = IntVector2(40, 16)
            le.text = tostring(textureFrame.time)
            le.cursorPosition = 0
            CreateDragSlider(le)

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectTextureFrame")
        end

        local textContainer = UIElement()
        labelContainer:AddChild(textContainer)
        textContainer.minSize = IntVector2(0, 16)
        textContainer.maxSize = IntVector2(2147483647, 16)
        textContainer.verticalAlignment = VA_CENTER

        local t = Text()
        textContainer:AddChild(t)
        t.style = "Text"
        t.text = "Texture"
        t.autoLocalizable = true

        local editContainer = UIElement()
        container:AddChild(editContainer)
        editContainer.style = "HorizontalPanel"
        editContainer.minSize = IntVector2(0, 16)
        editContainer.maxSize = IntVector2(2147483647, 16)
        editContainer.verticalAlignment = VA_CENTER

        -- MinX, MinY, MaxX, MaxY edits
        local components = {"TextureMinX", "TextureMinY", "TextureMaxX", "TextureMaxY"}
        local values = {textureFrame.uv.min.x, textureFrame.uv.min.y, textureFrame.uv.max.x, textureFrame.uv.max.y}

        for j = 1, 4 do
            local le = LineEdit()
            editContainer:AddChild(le)
            le.name = components[j]
            le:SetVar("TextureFrame", Variant(i))
            le.style = "LineEdit"
            le.text = tostring(values[j])
            le.cursorPosition = 0
            CreateDragSlider(le)

            SubscribeToEvent(le, "TextChanged", "EditParticleEffectTextureFrame")
        end

        ::continue::
    end
end

--------------------------------------------------------------------------------
-- UI Refresh Functions
--------------------------------------------------------------------------------

function RefreshParticleEffectPreview()
    if particleEffectEmitter == nil or editParticleEffect == nil then
        return
    end

    local checkbox = tolua.cast(particleEffectWindow:GetChild("ShowGrid", true), "CheckBox")
    checkbox.checked = showParticlePreviewAxes
    particleEffectEmitter.effect = editParticleEffect
    particleEffectEmitter:Reset()
    particleEffectPreview:QueueUpdate()
end

function RefreshParticleEffectName()
    local container = particleEffectWindow:GetChild("NameContainer", true)
    if container == nil then
        return
    end

    container:RemoveAllChildren()

    local nameEdit = CreateAttributeLineEdit(container, nil, 0, 0)
    if editParticleEffect ~= nil then
        nameEdit.text = editParticleEffect.name
    end
    SubscribeToEvent(nameEdit, "TextFinished", "EditParticleEffectName")

    local pickButton = CreateResourcePickerButton(container, nil, 0, 0, "smallButtonPick")
    SubscribeToEvent(pickButton, "Released", "PickEditParticleEffect")
end

function RefreshParticleEffectBasicAttributes()
    if editParticleEffect == nil then
        return
    end

    -- Helper function to set LineEdit text
    local function setLineEdit(name, value)
        local element = tolua.cast(particleEffectWindow:GetChild(name, true), "LineEdit")
        element.text = tostring(value)
    end

    -- Constant Force
    setLineEdit("ConstantForceX", editParticleEffect.constantForce.x)
    setLineEdit("ConstantForceY", editParticleEffect.constantForce.y)
    setLineEdit("ConstantForceZ", editParticleEffect.constantForce.z)

    -- Direction
    setLineEdit("DirectionMinX", editParticleEffect.minDirection.x)
    setLineEdit("DirectionMinY", editParticleEffect.minDirection.y)
    setLineEdit("DirectionMinZ", editParticleEffect.minDirection.z)
    setLineEdit("DirectionMaxX", editParticleEffect.maxDirection.x)
    setLineEdit("DirectionMaxY", editParticleEffect.maxDirection.y)
    setLineEdit("DirectionMaxZ", editParticleEffect.maxDirection.z)

    -- Physics
    setLineEdit("DampingForce", editParticleEffect.dampingForce)
    setLineEdit("ActiveTime", editParticleEffect.activeTime)
    setLineEdit("InactiveTime", editParticleEffect.inactiveTime)

    -- Particle Size
    setLineEdit("ParticleSizeMinX", editParticleEffect.minParticleSize.x)
    setLineEdit("ParticleSizeMinY", editParticleEffect.minParticleSize.y)
    setLineEdit("ParticleSizeMaxX", editParticleEffect.maxParticleSize.x)
    setLineEdit("ParticleSizeMaxY", editParticleEffect.maxParticleSize.y)

    -- Time To Live
    setLineEdit("TimeToLiveMin", editParticleEffect.minTimeToLive)
    setLineEdit("TimeToLiveMax", editParticleEffect.maxTimeToLive)

    -- Velocity
    setLineEdit("VelocityMin", editParticleEffect.minVelocity)
    setLineEdit("VelocityMax", editParticleEffect.maxVelocity)

    -- Rotation
    setLineEdit("RotationMin", editParticleEffect.minRotation)
    setLineEdit("RotationMax", editParticleEffect.maxRotation)
    setLineEdit("RotationSpeedMin", editParticleEffect.minRotationSpeed)
    setLineEdit("RotationSpeedMax", editParticleEffect.maxRotationSpeed)

    -- Size modifiers
    setLineEdit("SizeAdd", editParticleEffect.sizeAdd)
    setLineEdit("SizeMultiply", editParticleEffect.sizeMul)
    setLineEdit("AnimationLodBias", editParticleEffect.animationLodBias)

    -- Emission
    setLineEdit("NumParticles", editParticleEffect.numParticles)
    setLineEdit("EmitterSizeX", editParticleEffect.emitterSize.x)
    setLineEdit("EmitterSizeY", editParticleEffect.emitterSize.y)
    setLineEdit("EmitterSizeZ", editParticleEffect.emitterSize.z)
    setLineEdit("EmissionRateMin", editParticleEffect.minEmissionRate)
    setLineEdit("EmissionRateMax", editParticleEffect.maxEmissionRate)

    -- Emitter Shape
    local emitterShapeList = tolua.cast(particleEffectWindow:GetChild("EmitterShape", true), "DropDownList")
    if editParticleEffect.emitterType == EMITTER_SPHERE then
        emitterShapeList.selection = 0
    elseif editParticleEffect.emitterType == EMITTER_BOX then
        emitterShapeList.selection = 1
    end

    -- Face Camera Mode
    local faceCameraModeList = tolua.cast(particleEffectWindow:GetChild("FaceCameraMode", true), "DropDownList")
    if editParticleEffect.faceCameraMode == FC_NONE then
        faceCameraModeList.selection = 0
    elseif editParticleEffect.faceCameraMode == FC_ROTATE_XYZ then
        faceCameraModeList.selection = 1
    elseif editParticleEffect.faceCameraMode == FC_ROTATE_Y then
        faceCameraModeList.selection = 2
    elseif editParticleEffect.faceCameraMode == FC_LOOKAT_XYZ then
        faceCameraModeList.selection = 3
    elseif editParticleEffect.faceCameraMode == FC_LOOKAT_Y then
        faceCameraModeList.selection = 4
    elseif editParticleEffect.faceCameraMode == FC_DIRECTION then
        faceCameraModeList.selection = 5
    end

    -- Checkboxes
    tolua.cast(particleEffectWindow:GetChild("Scaled", true), "CheckBox").checked = editParticleEffect.scaled
    tolua.cast(particleEffectWindow:GetChild("Sorted", true), "CheckBox").checked = editParticleEffect.sorted
    tolua.cast(particleEffectWindow:GetChild("Relative", true), "CheckBox").checked = editParticleEffect.relative
    tolua.cast(particleEffectWindow:GetChild("FixedScreenSize", true), "CheckBox").checked = editParticleEffect.fixedScreenSize
end

function RefreshParticleEffectMaterial()
    local container = particleEffectWindow:GetChild("ParticleMaterialContainer", true)
    if container == nil then
        return
    end

    container:RemoveAllChildren()

    local nameEdit = CreateAttributeLineEdit(container, nil, 0, 0)
    if editParticleEffect ~= nil then
        if editParticleEffect.material ~= nil then
            nameEdit.text = editParticleEffect.material.name
        else
            nameEdit.text = "Materials/Particle.xml"
            local res = cache:GetResource("Material", "Materials/Particle.xml")
            if res ~= nil then
                editParticleEffect.material = res
            end
        end
    end

    SubscribeToEvent(nameEdit, "TextFinished", "EditParticleEffectMaterial")

    local pickButton = CreateResourcePickerButton(container, nil, 0, 0, "smallButtonPick")
    SubscribeToEvent(pickButton, "Released", "PickEditParticleEffectMaterial")
end

--------------------------------------------------------------------------------
-- Preview Camera Navigation
--------------------------------------------------------------------------------

function NavigateParticleEffectPreview(eventType, eventData)
    local dx = eventData["DX"]:GetInt()
    local dy = eventData["DY"]:GetInt()

    if particleEffectPreview.height > 0 and particleEffectPreview.width > 0 then
        if not input:GetKeyDown(KEY_LSHIFT) then
            particleViewCamRot.x = particleViewCamRot.x - dy * 20 * time.timeStep
            particleViewCamRot.y = particleViewCamRot.y + dx * 20 * time.timeStep
            particleViewCamRot.x = Clamp(particleViewCamRot.x, -89.5, 89.5)
        else
            particleViewCamDist = particleViewCamDist + dy * 1.5 * time.timeStep
            particleViewCamDist = particleViewCamDist - dx * 1.5 * time.timeStep
            particleViewCamDist = math.max(particleViewCamDist, 0.2)
        end

        particlePreviewCameraNode.position = particleEffectPreviewNode.position +
            Quaternion(particleViewCamRot.x, particleViewCamRot.y, 0) * particleViewCamDir * particleViewCamDist
        particlePreviewCameraNode:LookAt(particleEffectPreviewNode.position)

        SetGizmoPosition()
        particleEffectPreview:QueueUpdate()
    end
end

function ResizeParticleEffectPreview(eventType, eventData)
    local width = particleEffectPreview.width
    local height = particleEffectPreview.height

    -- Manually set aspect ratio because first frame is always returning aspect ratio of 1
    local aspectRatio = width / height
    particlePreviewCamera.aspectRatio = aspectRatio

    gizmoOffsetX = gizmoOffset
    gizmoOffsetY = 1.0 - gizmoOffset * aspectRatio

    if width > height then
        aspectRatio = height / width
        gizmoOffsetY = 1.0 - gizmoOffset
        gizmoOffsetX = gizmoOffset * aspectRatio
    end

    SetGizmoPosition()
    particleEffectPreview:QueueUpdate()
end

--------------------------------------------------------------------------------
-- Effect Name and Picker
--------------------------------------------------------------------------------

function EditParticleEffectName(eventType, eventData)
    local nameEdit = eventData["Element"]:GetPtr()
    local newParticleEffectName = nameEdit.text:Trimmed()

    if not newParticleEffectName:Empty() and
       not (editParticleEffect ~= nil and newParticleEffectName == editParticleEffect.name) then
        local newParticleEffect = cache:GetResource("ParticleEffect", newParticleEffectName)
        if newParticleEffect ~= nil then
            EditParticleEffect(newParticleEffect)
        end
    end
end

function PickEditParticleEffect()
    resourcePicker = GetResourcePicker(StringHash("ParticleEffect"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath:Empty() then
        lastPath = sceneResourcePath
    end
    CreateFileSelector(localization:Get("Pick ") .. resourcePicker.typeName, "OK", "Cancel",
                      lastPath, resourcePicker.filters, resourcePicker.lastFilter, false)
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickEditParticleEffectDone")
end

function PickEditParticleEffectDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local resourceName = eventData["FileName"]:GetString()
    local res = GetPickedResource(resourceName)

    if res ~= nil then
        EditParticleEffect(tolua.cast(res, "ParticleEffect"))
    end

    resourcePicker = nil
end

--------------------------------------------------------------------------------
-- File Operations
--------------------------------------------------------------------------------

function NewParticleEffect()
    BeginParticleEffectEdit()

    EditParticleEffect(CreateNewParticleEffect())

    EndParticleEffectEdit()
end

function RevertParticleEffect()
    if inParticleEffectRefresh or editParticleEffect == nil then
        return
    end

    if editParticleEffect.name:Empty() then
        NewParticleEffect()
        return
    end

    BeginParticleEffectEdit()

    cache:ReloadResource(editParticleEffect)

    EndParticleEffectEdit()

    RefreshParticleEffectEditor()
end

function SaveParticleEffect()
    if editParticleEffect == nil or editParticleEffect.name:Empty() then
        return
    end

    local fullName = cache:GetResourceFileName(editParticleEffect.name)
    if fullName:Empty() then
        return
    end

    local saveFile = File(fullName, FILE_WRITE)
    editParticleEffect:Save(saveFile)
end

function SaveParticleEffectAs()
    if editParticleEffect == nil then
        return
    end

    resourcePicker = GetResourcePicker(StringHash("ParticleEffect"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath:Empty() then
        lastPath = sceneResourcePath
    end
    CreateFileSelector("Save particle effect as", "Save", "Cancel", lastPath,
                      resourcePicker.filters, resourcePicker.lastFilter, true)
    SubscribeToEvent(uiFileSelector, "FileSelected", "SaveParticleEffectAsDone")
end

function SaveParticleEffectAsDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()
    resourcePicker = nil

    if editParticleEffect == nil then
        return
    end

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local fullName = eventData["FileName"]:GetString()

    -- Add default extension for saving if not specified
    local filter = eventData["Filter"]:GetString()
    if GetExtension(fullName):Empty() and filter ~= "*.*" then
        fullName = fullName .. filter:Substring(1)
    end

    local saveFile = File(fullName, FILE_WRITE)
    if editParticleEffect:Save(saveFile) then
        saveFile:Close()

        -- Load the new resource to update the name in the editor
        local newEffect = cache:GetResource("ParticleEffect", GetResourceNameFromFullName(fullName))
        if newEffect ~= nil then
            EditParticleEffect(newEffect)
        end
    end
end

--------------------------------------------------------------------------------
-- Edit State Management
--------------------------------------------------------------------------------

function BeginParticleEffectEdit()
    if editParticleEffect == nil then
        return
    end

    inParticleEffectRefresh = true

    oldParticleEffectState = XMLFile()
    local particleElem = oldParticleEffectState:CreateRoot("particleeffect")
    editParticleEffect:Save(particleElem)
end

function EndParticleEffectEdit()
    if editParticleEffect == nil then
        return
    end

    if not dragEditAttribute then
        local action = EditParticleEffectAction()
        action:Define(particleEffectEmitter, editParticleEffect, oldParticleEffectState)
        SaveEditAction(action)
    end

    inParticleEffectRefresh = false

    particleEffectPreview:QueueUpdate()
end
