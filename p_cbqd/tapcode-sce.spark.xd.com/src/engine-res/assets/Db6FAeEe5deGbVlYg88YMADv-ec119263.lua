-- CharacterDemo2 with Dual AnimationStateMachine (DefaultMale)
-- This sample demonstrates:
--     - Dual FSM design: Normal FSM and Armed FSM with smooth transition
--     - Normal FSM (1 layer): Full-body Locomotion + Jump animations
--     - Armed FSM (3 layers):
--       * Layer 0 (Base): RifleLocomotion BlendSpace (full body)
--       * Layer 1 (LowerBody): Jump animations with LowerBody BoneMask
--       * Layer 2 (UpperBody): Shoot/Reload with UpperBody BoneMask
--     - BlendSpace1D for smooth speed-based animation blending
--     - Q: Toggle FSM (Normal/Armed) | Left Click: Shoot | R: Reload
--     - Walk mode enabled: walk by default, hold Shift to run

require "LuaScripts/Utilities/Sample"
require "LuaScripts/Utilities/Touch"

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type CharacterComponent
local character_ = nil
---@type AnimationStateMachine
local stateMachine_ = nil
---@type JSONFile
local normalFSMFile_ = nil
---@type JSONFile
local armedFSMFile_ = nil
-- 当前状态机类型: "normal" or "armed"
local currentFSMType_ = "normal"
---@type AimOffset
local aimOffset_ = nil
---@type VirtualButton
local jumpButton_ = nil
---@type Text
local stateText_ = nil
-- 持枪状态
local isArmed_ = false
-- 瞄准状态（鼠标右键按住）
local isAiming_ = false

-- 越肩视角相机参数
local CameraConfig = {
    -- 普通状态（不持枪）
    normal = {
        distance = 5.0,
        offset = Vector3(0.0, 1.7, 0.0),  -- 正后方
        fov = 45.0,
    },
    -- 持枪状态（越肩视角）
    armed = {
        distance = 4.0,
        offset = Vector3(0.6, 1.6, 0.0),  -- 向右偏移
        fov = 45.0,
    },
    -- 瞄准状态（拉近）
    aiming = {
        distance = 2.0,
        offset = Vector3(0.4, 1.5, 0.0),  -- 更靠近肩膀
        fov = 32.0,  -- 更窄视野（放大效果）
    },
    -- 过渡速度
    transitionSpeed = 8.0,
}

-- 当前相机参数（用于平滑过渡）
local currentCameraDistance = 5.0
local currentCameraOffset = Vector3(0.0, 1.7, 0.0)
local currentCameraFOV = 45.0

-- NanoVG 准心
local nvgContext_ = nil
local CrosshairConfig = {
    -- 准心样式
    size = 12,           -- 准心大小（半长度）
    thickness = 2,       -- 线条粗细
    gap = 4,             -- 中心间隙
    dotRadius = 2,       -- 中心点半径

    -- 颜色配置
    normalColor = { 255, 255, 255, 200 },    -- 普通颜色（白色）
    aimingColor = { 255, 50, 50, 255 },      -- 瞄准颜色（红色）

    -- 瞄准时动画
    aimingScale = 0.7,   -- 瞄准时缩小比例
}

-- class MovingPlatform

local PLATFORM_STATE_START = 0
local PLATFORM_STATE_MOVETO_FINISH = 1
local PLATFORM_STATE_MOVETO_START = 2
local PLATFORM_STATE_FINISH = 3

MovingPlatform = ScriptObject()

function MovingPlatform:Start()
    self.maxLiftSpeed_ = 5.0
    self.minLiftSpeed_ = 1.5
    self.curLiftSpeed_ = 0.0
end

function MovingPlatform:Initialize()
    local platformNode = scene_:CreateChild("MovingPlatformDisk1")
    platformNode.position = Vector3(26.1357, 7.00645, -34.7563)
    platformNode.rotation = Quaternion(1, 0, 0, 0)
    platformNode.scale = Vector3(0.01, 0.01, 0.01)
    -- mark the platform as moving
    platformNode:SetVar(StringHash("IsMovingPlatform"), true)

    local model = cache:GetResource("Model", "Platforms/Scenes/Models/disk.mdl")

    -- create platform model
    local modelComp = platformNode:CreateComponent("StaticModel")
    modelComp.model = model
    modelComp.material = cache:GetResource("Material", "Platforms/Materials/playgroundMat.xml")
    modelComp.castShadows = true

    -- create platform RigidBody
    local body = platformNode:CreateComponent("RigidBody")
    body.friction = 1
    body.linearFactor = Vector3(1, 0, 1)
    body.angularFactor = Vector3.ZERO
    body.collisionLayer = CollisionLayerPlatform
    body.collisionMask = CollisionMaskPlatform
    body.useGravity = false

    -- create platform CollisionShape
    local shape = platformNode:CreateComponent("CollisionShape")
    shape:SetTriangleMesh(model, 0, Vector3.ONE, Vector3(0, -5, 0))

    -- positions
    self.platformNode_ = platformNode
    self.initialPosition_ = platformNode.worldPosition
    self.finishPosition_ = platformNode.worldPosition + Vector3(0, 0, 20.0)
    self.directionToFinish_ = (self.finishPosition_ - self.initialPosition_):Normalized()

    -- state
    self.platformState_ = PLATFORM_STATE_MOVETO_FINISH
    self.curLiftSpeed_ = self.maxLiftSpeed_
end

function MovingPlatform:FixedUpdate(timeStep)
    local platformPos = self.platformNode_.position
    local newPos = platformPos

    -- move platform
    if self.platformState_ == PLATFORM_STATE_MOVETO_FINISH then
        local curDistance  = self.finishPosition_ - platformPos
        local curDirection = curDistance:Normalized()
        local dist = curDistance:Length()
        local dotd = self.directionToFinish_:DotProduct(curDirection)

        if dotd > 0.0 then
            -- slow down near the end
            if dist < 1.0 then
                self.curLiftSpeed_ = self.curLiftSpeed_ * 0.92
            end
            self.curLiftSpeed_ = Clamp(self.curLiftSpeed_, self.minLiftSpeed_, self.maxLiftSpeed_)
            newPos = newPos + curDirection * self.curLiftSpeed_ * timeStep
        else
            newPos = self.finishPosition_;
            self.curLiftSpeed_ = self.maxLiftSpeed_
            self.platformState_ = PLATFORM_STATE_MOVETO_START
        end
        self.platformNode_.position = newPos
    elseif self.platformState_ == PLATFORM_STATE_MOVETO_START then
        local curDistance  = self.initialPosition_ - platformPos
        local curDirection = curDistance:Normalized()
        local dist = curDistance:Length()
        local dotd = self.directionToFinish_:DotProduct(curDirection)

        if dotd < 0.0 then
            -- slow down near the end
            if dist < 1.0 then
                self.curLiftSpeed_ = self.curLiftSpeed_ * 0.92
            end
            self.curLiftSpeed_ = Clamp(self.curLiftSpeed_, self.minLiftSpeed_, self.maxLiftSpeed_)
            newPos = newPos + curDirection * self.curLiftSpeed_ * timeStep
        else
            newPos = self.initialPosition_
            self.curLiftSpeed_ = self.maxLiftSpeed_
            self.platformState_ = PLATFORM_STATE_MOVETO_FINISH
        end

        self.platformNode_.position = newPos
    end
end

function Start()
    SampleStart()

    -- Create static scene content
    CreateScene()

    -- Create the controllable character with AnimationStateMachine + BlendSpace
    CreateCharacter()

    -- Create the UI content
    CreateInstructions()

    -- Create NanoVG context for crosshair
    CreateNanoVGContext()

    -- Subscribe to necessary events
    SubscribeToEvents()

    -- Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_RELATIVE)

    -- Create jump button (mobile)
    CreateJumpButton()
end

function Stop()
    -- Clean up NanoVG context
    if nvgContext_ ~= nil then
        nvgDelete(nvgContext_)
        nvgContext_ = nil
    end
end

function CreateNanoVGContext()
    nvgContext_ = nvgCreate(1)  -- 1 = edge anti-alias on
    if nvgContext_ == nil then
        print("WARNING: Failed to create NanoVG context for crosshair")
    end
end

function CreateJumpButton()
    if not touchEnabled then return end

    local isMobile = VirtualControls.IsMobile()
    local btnRadius = isMobile and 70 or 50
    local posOffset = isMobile and 160 or 120

    jumpButton_ = VirtualControls.CreateButton({
        position = Vector2(-posOffset, -posOffset),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = btnRadius,
        label = "Jump",
        opacity = 0.5,
        activeOpacity = 0.9,
        color = {100, 200, 255},
        pressedColor = {150, 230, 255},
    })
end

local function CreateFloor(modelPath, position)
    local model = cache:GetResource("Model", modelPath)

    local floorNode = scene_:CreateChild("FloorNode")
    floorNode.position = position
    floorNode.rotation = Quaternion(1, 0, 0, 0)
    floorNode.scale = Vector3(0.01, 0.01, 0.01)

    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel.model = model
    floorModel.material = cache:GetResource("Material", "Platforms/Materials/playgroundMat.xml")
    floorModel.castShadows = true

    local body = floorNode:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = floorNode:CreateComponent("CollisionShape")
    shape:SetTriangleMesh(model, 0, Vector3.ONE, Vector3(0, -5, 0))
end

local function CreateRamp(modelPath, position, useConvexHull)
    local model = cache:GetResource("Model", modelPath)

    local rampNode = scene_:CreateChild("RampNode")
    rampNode.position = position
    rampNode.rotation = Quaternion(1, 0, 0, 0)
    rampNode.scale = Vector3(0.01, 0.01, 0.01)

    local rampModel = rampNode:CreateComponent("StaticModel")
    rampModel.model = model
    rampModel.material = cache:GetResource("Material", "Platforms/Materials/playgroundMat.xml")
    rampModel.castShadows = true

    local body = rampNode:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = rampNode:CreateComponent("CollisionShape")
    if useConvexHull then
        shape:SetConvexHull(model, 0, Vector3.ONE, Vector3(0, -5, 0))
    else
        shape:SetTriangleMesh(model, 0, Vector3.ONE, Vector3(0, -5, 0))
    end
end

local function CreateFloors()
    -- Create base floor
    CreateFloor("Platforms/Scenes/Models/base.mdl", Vector3(0, 0, 0))

    -- Create upper floor
    CreateFloor("Platforms/Scenes/Models/upperFloor.mdl", Vector3(30.16, 6.98797, 10.0099))

    -- Creat ramp1
    CreateRamp("Platforms/Scenes/Models/ramp.mdl", Vector3(13.5771, 6.23965, 10.9272), false)

    -- Create ramp2
    CreateRamp("Platforms/Scenes/Models/ramp2.mdl", Vector3(-22.8933, 2.63165, -23.6786), true)

    -- Create ramp3
    CreateRamp("Platforms/Scenes/Models/ramp3.mdl", Vector3(-15.2665, 1.9782, -43.135), true)
end

function CreateScene()
    scene_ = Scene:new()

    -- Create scene subsystem components
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")
    scene_:CreateComponent("DebugRenderer")

    -- Create camera and define viewport. Camera does not necessarily have to belong to the scene
    cameraNode_ = Node()
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 300.0

    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- Load LightGroup assets and serialize Nodes from LightGroup assets.
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    -- Create floors
    CreateFloors()

    -- Create moving platform
    local movingPlatform = scene_:CreateScriptObject("MovingPlatform")
    movingPlatform:Initialize()
end

function CreateCharacter()
    local objectNode = scene_:CreateChild("Player")
    objectNode:SetPosition(Vector3(28.0, 8.0, -4.0))

    -- Spin node
    local modelNode = objectNode:CreateChild("ModelNode")

    -- Loading character prefabs XML
    local prefabFile = cache:GetResource("XMLFile", "DefaultMale/DefaultMale.prefab")
    if prefabFile then
        local success = modelNode:LoadXML(prefabFile:GetRoot())
        if not success then
            print("ERROR: Failed to load player prefab")
        end
    else
        print("ERROR: Player prefab not found, using fallback")
    end

    -- The prefab may already contain animation control components, so we use GetOrCreate.
    modelNode:GetOrCreateComponent("AnimationController")

    -- Create AnimationStateMachine with dual FSM support
    -- Normal FSM: single layer full-body animations
    -- Armed FSM: 3 layers (Base + LowerBody jump + UpperBody shoot/reload)
    stateMachine_ = modelNode:CreateComponent("AnimationStateMachine")

    -- Preload both FSM files
    normalFSMFile_ = cache:GetResource("JSONFile", "urhox-libs/Animation/FSM/DefaultMale_Normal.fsm")
    armedFSMFile_ = cache:GetResource("JSONFile", "urhox-libs/Animation/FSM/DefaultMale_Armed.fsm")

    -- Start with Normal FSM (default)
    if normalFSMFile_ ~= nil then
        stateMachine_:LoadFromJSONFile(normalFSMFile_)
        stateMachine_:Start()
        currentFSMType_ = "normal"
        print("AnimationStateMachine started with Normal FSM")
    else
        print("Warning: DefaultMale_Normal.fsm not found!")
    end

    if armedFSMFile_ == nil then
        print("Warning: DefaultMale_Armed.fsm not found!")
    end

    -- Create AimOffset component for procedural upper body aiming
    -- This rotates spine/neck/head bones based on camera pitch
    aimOffset_ = modelNode:CreateComponent("AimOffset")
    -- Configure bone weights: (boneName, pitchWeight, yawWeight)
    -- Total pitch weight ~1.0 for full vertical tracking
    -- Total yaw weight ~0.5 for partial horizontal tracking (character still faces forward)
    -- AddBone(boneName, pitchWeight, yawWeight)
    -- Total weight ~1.0 means full rotation distributed across bones
    aimOffset_:AddBone("Bip001 Spine", 0.40, 0.40)
    aimOffset_:AddBone("Bip001 Spine1", 0.35, 0.35)
    aimOffset_:AddBone("Bip001 Spine2", 0.25, 0.25)
    aimOffset_:SetMaxPitch(50)     -- Limit pitch to avoid extreme bending
    aimOffset_:SetMaxYaw(30)       -- Limit yaw to prevent extreme twisting
    aimOffset_:SetSmoothSpeed(12)  -- Smooth transition speed
    aimOffset_:SetYawCompensation(0)  -- Compensate for rifle animation's inherent spine rotation
    -- Note: enabled_ defaults to false, will be enabled when armed
    print("AimOffset component created with " .. aimOffset_.numBones .. " bones")

    -- Create rigidbody, and set non-zero mass so that the body becomes dynamic
    local body = objectNode:CreateComponent("RigidBody")
    body:SetCollisionLayerAndMask(CollisionLayerCharacter, CollisionMaskCharacter)
    body:SetMass(1)
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    -- Set a capsule shape for collision
    local shape = objectNode:CreateComponent("CollisionShape")
    shape:SetCapsule(0.7, 1.8, Vector3(0.0, 0.86, 0.0))

    -- Create character controller
    local kinematicCharacter = objectNode:CreateComponent("KinematicCharacterController")
    kinematicCharacter:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)

    -- Create character component.
    -- CharacterComponent handles physics movement, AnimationStateMachine handles animation
    character_ = objectNode:CreateComponent("CharacterComponent")

    -- Set air control parameters
    character_:SetAirControlFactor(0.6)

    -- Enable walk mode: walk by default, hold Shift to run
    character_:SetEnableWalkMode(true)
end

-- Switch to Armed FSM with smooth transition
function SwitchToArmedFSM()
    print("SwitchToArmedFSM called, currentFSMType_=" .. currentFSMType_)
    if currentFSMType_ == "armed" then
        print("Already armed, skipping")
        return
    end
    if armedFSMFile_ == nil then
        print("ERROR: armedFSMFile_ is nil!")
        return
    end
    if stateMachine_ == nil then
        print("ERROR: stateMachine_ is nil!")
        return
    end
    print("Loading Armed FSM...")

    -- Save current parameters
    local moveSpeed = stateMachine_:GetFloat("moveSpeed")
    local isGrounded = stateMachine_:GetBool("isGrounded")

    -- Note: C++ LoadFromJSON already handles stopping old animations

    -- Load Armed FSM
    stateMachine_:LoadFromJSONFile(armedFSMFile_)
    stateMachine_:Start()

    -- Restore parameters
    stateMachine_:SetFloat("moveSpeed", moveSpeed)
    stateMachine_:SetBool("isGrounded", isGrounded)

    currentFSMType_ = "armed"
    print("Switched to Armed FSM")
end

-- Switch to Normal FSM with smooth transition
function SwitchToNormalFSM()
    if currentFSMType_ == "normal" then return end
    if normalFSMFile_ == nil or stateMachine_ == nil then return end

    -- Save current parameters
    local moveSpeed = stateMachine_:GetFloat("moveSpeed")
    local isGrounded = stateMachine_:GetBool("isGrounded")

    -- Note: C++ LoadFromJSON already handles stopping old animations

    -- Load Normal FSM
    stateMachine_:LoadFromJSONFile(normalFSMFile_)
    stateMachine_:Start()

    -- Restore parameters
    stateMachine_:SetFloat("moveSpeed", moveSpeed)
    stateMachine_:SetBool("isGrounded", isGrounded)

    currentFSMType_ = "normal"
    print("Switched to Normal FSM")
end

function CreateInstructions()
    -- Construct new Text object, set string to display and font to use
    local instructionText = ui.root:CreateChild("Text")
    instructionText.text = "Dual FSM Demo: Normal (1 layer) / Armed (3 layers)\n" ..
        "Armed: Base(RifleMove) + LowerBody(Jump) + UpperBody(Shoot/Reload)\n"..
        "WASD: Move | Shift: Run | Space: Jump | Q: Toggle FSM | LMB: Shoot | RMB: Aim | R: Reload"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 15)
    -- The text has multiple rows. Center them in relation to each other
    instructionText.textAlignment = HA_CENTER

    -- Position the text at top center (avoid blocking crosshair)
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_TOP
    instructionText:SetPosition(0, 10)

    -- Create state display text at bottom
    stateText_ = ui.root:CreateChild("Text")
    stateText_:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 18)
    stateText_.horizontalAlignment = HA_CENTER
    stateText_.verticalAlignment = VA_BOTTOM
    stateText_:SetPosition(0, -30)
    stateText_.color = Color(1.0, 1.0, 0.0)
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate")
    SubscribeToEvent(nvgContext_, "NanoVGRender", "HandleCrosshairRender")
    UnsubscribeFromEvent("SceneUpdate")
end

function HandleUpdate(eventType, eventData)
    if character_ == nil then
        return
    end

    -- Clear previous controls
    character_.controls:Set(CTRL_FORWARD + CTRL_BACK + CTRL_LEFT + CTRL_RIGHT + CTRL_JUMP + CTRL_RUN, false)

    -- Update controls using touch utility
    if touchEnabled then UpdateTouches(character_.controls) end

    -- Update controls using keys
    if ui.focusElement == nil then
        if not touchEnabled or not useGyroscope then
            if input:GetKeyDown(KEY_W) then character_.controls:Set(CTRL_FORWARD, true) end
            if input:GetKeyDown(KEY_S) then character_.controls:Set(CTRL_BACK, true) end
            if input:GetKeyDown(KEY_A) then character_.controls:Set(CTRL_LEFT, true) end
            if input:GetKeyDown(KEY_D) then character_.controls:Set(CTRL_RIGHT, true) end
        end
        if input:GetKeyDown(KEY_SPACE) then character_.controls:Set(CTRL_JUMP, true) end
        if input:GetKeyDown(KEY_SHIFT) then character_.controls:Set(CTRL_RUN, true) end

        -- Use jump button
        if touchEnabled and jumpButton_ and jumpButton_.isPressed then
            character_.controls:Set(CTRL_JUMP, true)
        end

        -- Use virtual joystick for character movement
        if touchEnabled and sampleJoystick_ then
            local jx = sampleJoystick_.x
            local jy = sampleJoystick_.y
            local threshold = 0.1

            if jy < -threshold then character_.controls:Set(CTRL_FORWARD, true) end
            if jy > threshold then character_.controls:Set(CTRL_BACK, true) end
            if jx < -threshold then character_.controls:Set(CTRL_LEFT, true) end
            if jx > threshold then character_.controls:Set(CTRL_RIGHT, true) end
        end

        -- Add character yaw & pitch from the mouse motion or touch input
        if touchEnabled then
            for i=0, input.numTouches - 1 do
                local state = input:GetTouch(i)
                -- Exclude touches occupied by virtual controls
                local isOccupied = VirtualControls.IsTouchOccupied(state.touchID)
                if not state.touchedElement and not isOccupied then -- Touch on empty space
                    local camera = cameraNode_:GetComponent("Camera")
                    if not camera then return end

                    character_.controls.yaw = character_.controls.yaw + TOUCH_SENSITIVITY * camera.fov / graphics.height * state.delta.x
                    character_.controls.pitch = character_.controls.pitch + TOUCH_SENSITIVITY * camera.fov / graphics.height * state.delta.y
                end
            end
        else
            character_.controls.yaw = character_.controls.yaw + input.mouseMoveX * YAW_SENSITIVITY
            character_.controls.pitch = character_.controls.pitch + input.mouseMoveY * YAW_SENSITIVITY
        end
        -- Limit pitch
        character_.controls.pitch = Clamp(character_.controls.pitch, -80.0, 80.0)

        -- When armed, character faces camera direction (combat mode)
        -- When not armed, character faces move direction (exploration mode)
        character_.autoRotateToMoveDir = not isArmed_
        -- Combat mode uses slower rotation speed for more natural movement
        character_.rotationSpeed = isArmed_ and 180.0 or 1440.0

        -- Turn on/off gyroscope on mobile platform
        if input:GetKeyPress(KEY_G) then
            useGyroscope = not useGyroscope
        end

        -- Q: Toggle armed state (切换持枪状态) and switch FSM
        if input:GetKeyPress(KEY_Q) then
            local wasArmed = isArmed_
            isArmed_ = not isArmed_
            print("Armed: " .. tostring(isArmed_))

            -- Switch FSM based on armed state
            if isArmed_ then
                SwitchToArmedFSM()
                -- When entering armed mode, force character to face camera direction
                local characterNode = character_:GetNode()
                characterNode.worldRotation = Quaternion(0, character_.controls.yaw, 0)
            else
                SwitchToNormalFSM()
            end
        end

        -- Shoot (mouse left button) - only when armed
        if isArmed_ and input:GetMouseButtonPress(MOUSEB_LEFT) then
            if stateMachine_ then
                stateMachine_:SetTrigger("shoot")
            end
        end

        -- Reload (R key) - only when armed
        if isArmed_ and input:GetKeyPress(KEY_R) then
            if stateMachine_ then
                stateMachine_:SetTrigger("reload")
            end
        end

        -- Aim (mouse right button hold) - only when armed
        if isArmed_ then
            isAiming_ = input:GetMouseButtonDown(MOUSEB_RIGHT)
        else
            isAiming_ = false
        end

        -- Debug keys for AnimationStateMachine
        if input:GetKeyPress(KEY_F5) and stateMachine_ then
            stateMachine_:DebugPrintState()
        end
        if input:GetKeyPress(KEY_F6) and stateMachine_ then
            stateMachine_:DebugPrintParameters()
        end
        if input:GetKeyPress(KEY_F7) and aimOffset_ then
            aimOffset_:DebugPrintBones()
        end
    end
end

function HandlePostUpdate(eventType, eventData)
    if character_ == nil then
        return
    end

    local timeStep = eventData["TimeStep"]:GetFloat()

    -- Update AnimationStateMachine parameters from CharacterComponent state
    -- Must be in PostUpdate (after FixedUpdate) to get current frame's physics state
    if stateMachine_ ~= nil then
        local moveSpeed = character_:GetMoveSpeed()
        local isGrounded = character_:IsOnGround()
        local isJumping = character_:IsJumping()

        -- Trigger jump animation on jump start frame
        if character_:IsJumpStarted() then
            stateMachine_:SetTrigger("jump")
        end

        -- Note: When isJumping is true AND we haven't left the ground yet,
        -- force isGrounded to false (physics update delay in jump frame)
        local effectiveGrounded = isGrounded and not isJumping

        stateMachine_:SetFloat("moveSpeed", moveSpeed)
        stateMachine_:SetBool("isGrounded", effectiveGrounded)
        -- Note: isArmed is no longer needed as we use separate FSMs for normal/armed states
    end

    -- Update AimOffset component
    -- Enable when armed, set target angles from camera
    if aimOffset_ ~= nil then
        aimOffset_:SetEnabled(isArmed_)
        if isArmed_ then
            -- Get actual camera pitch from camera node
            local cameraPitch = cameraNode_.worldRotation:PitchAngle()
            aimOffset_:SetTargetPitch(cameraPitch)

            -- Calculate relative yaw: camera direction vs character facing
            local characterNode = character_:GetNode()
            local characterYaw = characterNode.worldRotation:YawAngle()
            local cameraYaw = cameraNode_.worldRotation:YawAngle()
            local relativeYaw = cameraYaw - characterYaw

            -- Normalize to -180 to 180 range
            while relativeYaw > 180 do relativeYaw = relativeYaw - 360 end
            while relativeYaw < -180 do relativeYaw = relativeYaw + 360 end

            aimOffset_:SetTargetYaw(relativeYaw)
        end
    end

    -- Get camera lookat dir from character yaw + pitch
    local characterNode = character_:GetNode()
    local rot = Quaternion(character_.controls.yaw, Vector3(0.0, 1.0, 0.0))
    local dir = rot * Quaternion(character_.controls.pitch, Vector3.RIGHT)

    -- Determine target camera parameters based on state
    local targetConfig
    if isAiming_ then
        targetConfig = CameraConfig.aiming
    elseif isArmed_ then
        targetConfig = CameraConfig.armed
    else
        targetConfig = CameraConfig.normal
    end

    -- Smooth transition using exponential decay
    local lerpFactor = 1.0 - math.exp(-CameraConfig.transitionSpeed * timeStep)

    -- Smooth transition camera parameters
    currentCameraDistance = Lerp(currentCameraDistance, targetConfig.distance, lerpFactor)
    currentCameraOffset = currentCameraOffset:Lerp(targetConfig.offset, lerpFactor)
    currentCameraFOV = Lerp(currentCameraFOV, targetConfig.fov, lerpFactor)

    -- Apply FOV to camera
    local camera = cameraNode_:GetComponent("Camera")
    if camera then
        camera.fov = currentCameraFOV
    end

    -- Third person camera: position behind the character with offset (over-the-shoulder when armed)
    local aimPoint = characterNode.position + rot * currentCameraOffset

    -- Collide camera ray with static physics objects to ensure we see the character properly
    local rayDir = dir * Vector3(0.0, 0.0, -1.0)
    local rayDistance = currentCameraDistance
    local result = scene_:GetComponent("PhysicsWorld"):RaycastSingle(Ray(aimPoint, rayDir), rayDistance, CollisionMaskCamera)
    if result.body ~= nil then
        rayDistance = Min(rayDistance, result.distance)
    end
    rayDistance = Clamp(rayDistance, CAMERA_MIN_DIST, currentCameraDistance)

    cameraNode_.position = aimPoint + rayDir * rayDistance
    cameraNode_.rotation = dir
end

function HandlePostRenderUpdate(eventType, eventData)
    -- Update state display showing multi-layer info
    if stateText_ ~= nil and stateMachine_ ~= nil then
        -- Layer 0 (Base) state
        local baseState = stateMachine_:GetCurrentState(0)
        local speed = stateMachine_:GetFloat("moveSpeed")
        local isGrounded = stateMachine_:GetBool("isGrounded")

        -- Layer 1 (UpperBody) state
        local upperBodyState = stateMachine_:GetCurrentState(1)

        -- Show BlendSpace info when in Locomotion state
        -- DefaultMale BlendSpace: speed=0 Idle, speed=2 Walk, speed=5 Run
        local blendInfo = ""
        if baseState == "Locomotion" then
            -- Calculate blend weights based on speed (matches BlendSpace1D logic)
            if speed <= 0 then
                blendInfo = "Idle:100%"
            elseif speed >= 5 then
                blendInfo = "Run:100%"
            elseif speed <= 2 then
                local t = speed / 2.0
                blendInfo = string.format("Idle:%.0f%% Walk:%.0f%%", (1-t)*100, t*100)
            else
                local t = (speed - 2) / 3.0
                blendInfo = string.format("Walk:%.0f%% Run:%.0f%%", (1-t)*100, t*100)
            end
        end

        -- Build status text
        local armedStatus = isArmed_ and (isAiming_ and "Aiming" or "Armed") or "Normal"
        local fsmInfo = "FSM: " .. currentFSMType_

        -- Layer 1 info for Armed FSM
        local lowerBodyState = ""
        if currentFSMType_ == "armed" then
            lowerBodyState = stateMachine_:GetCurrentState(1)
        end

        if currentFSMType_ == "armed" then
            stateText_:SetText(string.format(
                "%s | Base: %s | Lower: %s | Upper: %s | Speed: %.2f | %s",
                fsmInfo, baseState, lowerBodyState, upperBodyState, speed, armedStatus
            ))
        else
            stateText_:SetText(string.format(
                "%s | Base: %s | Speed: %.2f | %s | %s",
                fsmInfo, baseState, speed, armedStatus, blendInfo
            ))
        end
    end
end

-- NanoVG crosshair rendering
function HandleCrosshairRender(eventType, eventData)
    -- Only show crosshair when armed
    if not isArmed_ or nvgContext_ == nil then
        return
    end

    local gfx = GetGraphics()
    local width = gfx:GetWidth()
    local height = gfx:GetHeight()

    -- Begin NanoVG frame
    nvgBeginFrame(nvgContext_, width, height, 1.0)

    -- Draw crosshair at screen center
    DrawCrosshair(nvgContext_, width / 2, height / 2)

    -- End NanoVG frame
    nvgEndFrame(nvgContext_)
end

function DrawCrosshair(ctx, cx, cy)
    local cfg = CrosshairConfig

    -- Determine color and scale based on aiming state
    local color = isAiming_ and cfg.aimingColor or cfg.normalColor
    local scale = isAiming_ and cfg.aimingScale or 1.0

    local size = cfg.size * scale
    local gap = cfg.gap * scale
    local thickness = cfg.thickness

    -- Set color
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4]))
    nvgStrokeWidth(ctx, thickness)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4]))

    -- Draw crosshair lines (4 lines with gap in center)
    nvgBeginPath(ctx)

    -- Top line
    nvgMoveTo(ctx, cx, cy - gap - size)
    nvgLineTo(ctx, cx, cy - gap)

    -- Bottom line
    nvgMoveTo(ctx, cx, cy + gap)
    nvgLineTo(ctx, cx, cy + gap + size)

    -- Left line
    nvgMoveTo(ctx, cx - gap - size, cy)
    nvgLineTo(ctx, cx - gap, cy)

    -- Right line
    nvgMoveTo(ctx, cx + gap, cy)
    nvgLineTo(ctx, cx + gap + size, cy)

    nvgStroke(ctx)

    -- Draw center dot
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, cfg.dotRadius * scale)
    nvgFill(ctx)
end

-- Create XML patch instructions for screen joystick layout specific to this sample app
function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element\">" ..
        "        <element type=\"Button\">" ..
        "            <attribute name=\"Name\" value=\"Button3\" />" ..
        "            <attribute name=\"Position\" value=\"-120 -120\" />" ..
        "            <attribute name=\"Size\" value=\"96 96\" />" ..
        "            <attribute name=\"Horiz Alignment\" value=\"Right\" />" ..
        "            <attribute name=\"Vert Alignment\" value=\"Bottom\" />" ..
        "            <attribute name=\"Texture\" value=\"Texture2D;Textures/TouchInput.png\" />" ..
        "            <attribute name=\"Image Rect\" value=\"96 0 192 96\" />" ..
        "            <attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
        "            <attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
        "            <element type=\"Text\">" ..
        "                <attribute name=\"Name\" value=\"Label\" />" ..
        "                <attribute name=\"Horiz Alignment\" value=\"Center\" />" ..
        "                <attribute name=\"Vert Alignment\" value=\"Center\" />" ..
        "                <attribute name=\"Color\" value=\"0 0 0 1\" />" ..
        "                <attribute name=\"Text\" value=\"Gyroscope\" />" ..
        "            </element>" ..
        "            <element type=\"Text\">" ..
        "                <attribute name=\"Name\" value=\"KeyBinding\" />" ..
        "                <attribute name=\"Text\" value=\"G\" />" ..
        "            </element>" ..
        "        </element>" ..
        "    </add>" ..
        "    <remove sel=\"/element/element[./attribute[@name='Name' and @value='Button0']]/attribute[@name='Is Visible']\" />" ..
        "    <replace sel=\"/element/element[./attribute[@name='Name' and @value='Button0']]/element[./attribute[@name='Name' and @value='Label']]/attribute[@name='Text']/@value\">1st/3rd</replace>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Button0']]\">" ..
        "        <element type=\"Text\">" ..
        "            <attribute name=\"Name\" value=\"KeyBinding\" />" ..
        "            <attribute name=\"Text\" value=\"F\" />" ..
        "        </element>" ..
        "    </add>" ..
        "    <remove sel=\"/element/element[./attribute[@name='Name' and @value='Button1']]/attribute[@name='Is Visible']\" />" ..
        "    <replace sel=\"/element/element[./attribute[@name='Name' and @value='Button1']]/element[./attribute[@name='Name' and @value='Label']]/attribute[@name='Text']/@value\">Jump</replace>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Button1']]\">" ..
        "        <element type=\"Text\">" ..
        "            <attribute name=\"Name\" value=\"KeyBinding\" />" ..
        "            <attribute name=\"Text\" value=\"SPACE\" />" ..
        "        </element>" ..
        "    </add>" ..
        "</patch>"
end
