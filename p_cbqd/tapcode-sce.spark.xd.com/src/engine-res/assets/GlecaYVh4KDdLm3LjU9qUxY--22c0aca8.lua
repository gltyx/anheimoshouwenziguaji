-- 83_KinematicPlatform2.lua
-- 使用新角色的 KinematicPlatform 示例

require "LuaScripts/Utilities/Sample"
require "LuaScripts/Utilities/Touch"

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type CharacterComponent
local character_ = nil

-- class Lift

local LIFT_BUTTON_UP = 0
local LIFT_BUTTON_POPUP = 1 
local LIFT_BUTTON_DOWN = 2

local LIFT_STATE_START = 0
local LIFT_STATE_MOVETO_FINISH = 1
local LIFT_STATE_MOVETO_START = 2
local LIFT_STATE_FINISH = 3

Lift = ScriptObject()

function Lift:Start()
    self.liftState_ = LIFT_STATE_START
    self.liftButtonState_ = LIFT_BUTTON_UP
    self.maxLiftSpeed_ = 5.0
    self.minLiftSpeed_ = 1.5
    self.curLiftSpeed_ = 0.0
    self.buttonPressed_ = false
    self.buttonPressedHeight_ = 15.0
    self.standingOnButton_ = false
end

function Lift:FixedUpdate(timeStep)
    local liftPos = self.liftNode_.position
    local newPos = liftPos

    -- move lift
    if self.liftState_ == LIFT_STATE_MOVETO_FINISH then
        local curDistance  = self.finishPosition_ - liftPos
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
            self:SetTransitionCompleted(LIFT_STATE_FINISH)
        end
        self.liftNode_.position = newPos
    elseif self.liftState_ == LIFT_STATE_MOVETO_START then
        local curDistance  = self.initialPosition_ - liftPos
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
            self:SetTransitionCompleted(LIFT_STATE_START)
        end
        self.liftNode_.position = newPos
    end

    -- reenable button
    if not self.standingOnButton_ and 
        self.liftButtonState_ == LIFT_BUTTON_DOWN and
        (self.liftState_ == LIFT_STATE_START or self.liftState_ == LIFT_STATE_FINISH) then
        self.liftButtonState_ = LIFT_BUTTON_UP
        self:ButtonPressAnimate(false)
    end
end

function Lift:Initialize(liftNode, finishPosition)
    -- get other lift components
    self.liftNode_        = liftNode
    self.liftButtonNode_  = self.liftNode_:GetChild("LiftButton", true)

    -- positions
    self.initialPosition_   = self.liftNode_.worldPosition
    self.finishPosition_    = finishPosition
    self.directionToFinish_ = (self.finishPosition_ - self.initialPosition_):Normalized()
    self.totalDistance_     = (self.finishPosition_ - self.initialPosition_):Length()

    -- events
    SubscribeToEvent(self.liftButtonNode_, "NodeCollisionStart", "Lift:HandleButtonStartCollision")
    SubscribeToEvent(self.liftButtonNode_, "NodeCollisionEnd", "Lift:HandleButtonEndCollision")
end

function Lift:SetTransitionCompleted(toState)
    self.liftState_ = toState

    -- adjust button
    if self.liftButtonState_ == LIFT_BUTTON_UP then
        self:ButtonPressAnimate(false)
    end
end

function Lift:ButtonPressAnimate(pressed)
    if pressed then
        self.liftButtonNode_.position = self.liftButtonNode_.position + Vector3(0, -self.buttonPressedHeight_, 0)
        self.buttonPressed_ = true
    else
        self.liftButtonNode_.position = self.liftButtonNode_.position + Vector3(0, self.buttonPressedHeight_, 0)
        self.buttonPressed_ = false
    end
end

function Lift:HandleButtonStartCollision(eventType, eventData)
    self.standingOnButton_ = true;

    if self.liftButtonState_ == LIFT_BUTTON_UP then
        if self.liftState_ == LIFT_STATE_START then
            self.liftState_ = LIFT_STATE_MOVETO_FINISH
            self.liftButtonState_ = LIFT_BUTTON_DOWN
            self.curLiftSpeed_ = self.maxLiftSpeed_

            -- adjust button
            self:ButtonPressAnimate(true)

            -- SetUpdateEventMask(USE_FIXEDUPDATE)
        elseif self.liftState_ == LIFT_STATE_FINISH then
            self.liftState_ = LIFT_STATE_MOVETO_START
            self.liftButtonState_ = LIFT_BUTTON_DOWN
            self.curLiftSpeed_ = self.maxLiftSpeed_

            -- adjust button
            self:ButtonPressAnimate(true)

            -- self:SetUpdateEventMask(USE_FIXEDUPDATE);
        end
    end
end

function Lift:HandleButtonEndCollision()
    self.standingOnButton_ = false

    if self.liftButtonState_ == LIFT_BUTTON_DOWN then
        -- button animation
        if self.liftState_ == LIFT_STATE_START or self.liftState_ == LIFT_STATE_FINISH then
            self.liftButtonState_ = LIFT_BUTTON_UP
            self:ButtonPressAnimate(false)
        end
    end
end

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

function MovingPlatform:Initialize(platformNode, finishPosition, updateBodyOnPlatform)
    -- get other lift components
    self.platformNode_ = platformNode
    self.platformVolumdNode_ = self.platformNode_:GetChild("PlatformVolume", true)

    -- positions
    self.initialPosition_ = self.platformNode_.worldPosition
    self.finishPosition_ = finishPosition
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

-- class SplinePlatform



function Start()
    SampleStart()
    
    -- 设置日志级别为 INFO 以查看跳跃状态切换日志
    log:SetLevel(LOG_INFO)
    log:Write(LOG_INFO, "=== 83_KinematicPlatform2 Demo Started ===")
    log:Write(LOG_INFO, "Log level set to INFO for jump animation state transitions")

    -- Create static scene content
    CreateScene()

    -- Create the controllable character
    CreateCharacter()

    -- Create the UI content
    CreateInstructions()

    -- Subscribe to necessary events
    SubscribeToEvents()

    -- Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_RELATIVE)
end

function CreateScene()
    scene_ = Scene:new()

    cameraNode_ = Node:new()
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 300.0

    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- load scene
    local sceneFile = cache:GetFile("Platforms/Scenes/playGroundTest.xml")
    scene_:LoadXML(sceneFile)

    -- init platforms
    -- local lift = scene_:CreateScriptObject("Lift")
    -- local liftNode = scene_:GetChild("Lift", true)
    -- lift:Initialize(liftNode, liftNode.worldPosition + Vector3(0, 6.8f, 0))

    local movingPlatform = scene_:CreateScriptObject("MovingPlatform")
    local movingPlatNode = scene_:GetChild("movingPlatformDisk1", true)
    movingPlatform:Initialize(movingPlatNode, movingPlatNode.worldPosition + Vector3(0, 0, 20.0), true)

    -- local splinePlatform = scene_:CreateScriptObject("SplinePlatform")
    -- local splineNode = scene_:GetChild("splinePath1", true)
    -- splinePlatform:Initialize(splineNode)
end

-- 角色预制体 XML（内联，无需外部文件）
local CHARACTER_PREFAB_XML = [[
<?xml version="1.0"?>
<node>
    <attribute name="Is Enabled" value="true" />
    <attribute name="Name" value="Player" />
    <attribute name="Position" value="28.00 8.00 -4.00" />
    <attribute name="Rotation" value="1 0 0 0" />
    <attribute name="Scale" value="1.00 1.00 1.00" />
    <component type="RigidBody">
        <attribute name="Physics Position" value="28.00 8.00 -4.00" />
        <attribute name="Mass" value="1" />
        <attribute name="Linear Factor" value="0.00 0.00 0.00" />
        <attribute name="Angular Factor" value="0.00 0.00 0.00" />
        <attribute name="Collision Layer" value="4" />
        <attribute name="Collision Mask" value="65343" />
        <attribute name="Collision Event Mode" value="Always" />
    </component>
    <component type="CollisionShape">
        <attribute name="Shape Type" value="Capsule" />
        <attribute name="Size" value="0.70 1.80 0.70" />
        <attribute name="Offset Position" value="0.00 0.86 0.00" />
    </component>
    <component type="CharacterComponent">
        <attribute name="Animation Idle" value="SCECharacter/anim/idle_01.ani" />
        <attribute name="Animation Run" value="SCECharacter/anim/run_01.ani" />
        <!-- 模式1：使用独立的跳跃和空中动画 -->
        <!-- <attribute name="Animation Jump" value="SCECharacter/anim/jump_01.ani" /> -->
        <!-- <attribute name="Animation Air" value="SCECharacter/anim/jump_01.ani" /> -->
        
        <!-- 模式2：使用完整跳跃动画（三阶段）动画总长 1.47s -->
        <attribute name="Animation Full Jump" value="SCECharacter/anim/jump_01.ani" />
        <attribute name="Jump Start Duration" value="0.3" />
        <attribute name="Jump Air Duration" value="0.47" />
        <attribute name="Jump Land Duration" value="0.7" />
        <attribute name="Run Animation Speed" value="1.5" />
    </component>
    <component type="KinematicCharacterController">
        <attribute name="Collision Layer" value="128" />
        <attribute name="Collision Mask" value="65467" />
    </component>
    <node>
        <attribute name="Is Enabled" value="true" />
        <attribute name="Name" value="spinNode" />
        <attribute name="Position" value="0.00 0.00 0.00" />
        <attribute name="Rotation" value="0.5 -0.5 -0.5 -0.5" />
        <attribute name="Scale" value="0.01 0.01 0.01" />
        <component type="AnimatedModel">
            <attribute name="Model" value="Model;SCECharacter/model/m.mdl" />
            <attribute name="Material" value="Material;SCECharacter/materials/m0.xml;SCECharacter/materials/m1.xml" />
            <attribute name="Cast Shadows" value="true" />
        </component>
        <component type="AnimationController" />
    </node>
</node>
]]

function CreateCharacter()
    -- 从内联 XML 字符串创建角色
    local xmlFile = XMLFile:new()
    xmlFile:FromString(CHARACTER_PREFAB_XML)
    
    local objectNode = scene_:CreateChild("Player")
    objectNode:LoadXML(xmlFile:GetRoot())

    character_ = objectNode:GetComponent("CharacterComponent", true)
    
    -- 打印动画时长（通过 ResourceCache 获取 Animation 资源）
    local jumpAnimRes = cache:GetResource("Animation", "SCECharacter/anim/jump_01.ani")
    local idleAnimRes = cache:GetResource("Animation", "SCECharacter/anim/idle_01.ani")
    local runAnimRes = cache:GetResource("Animation", "SCECharacter/anim/run_01.ani")
    
    log:Write(LOG_INFO, "=== Animation Resources ===")
    if jumpAnimRes then
        log:Write(LOG_INFO, "Jump Animation Length: " .. tostring(jumpAnimRes.length) .. " seconds")
    end
    if idleAnimRes then
        log:Write(LOG_INFO, "Idle Animation Length: " .. tostring(idleAnimRes.length) .. " seconds")
    end
    if runAnimRes then
        log:Write(LOG_INFO, "Run Animation Length: " .. tostring(runAnimRes.length) .. " seconds")
    end
    
    -- 打印跳跃模式配置
    log:Write(LOG_INFO, "")
    log:Write(LOG_INFO, "=== Jump Mode Config ===")
    local fullJumpAnim = character_:GetAnimationFullJump()
    if fullJumpAnim ~= "" then
        log:Write(LOG_INFO, "✓ Using Mode 2 (Full Jump Animation)")
        log:Write(LOG_INFO, "  Full Jump Animation: " .. fullJumpAnim)
        if jumpAnimRes then
            log:Write(LOG_INFO, "  Total Animation Length: " .. tostring(jumpAnimRes.length) .. " seconds")
        end
    else
        log:Write(LOG_INFO, "✓ Using Mode 1 (Separate Jump/Air animations)")
        log:Write(LOG_INFO, "  Jump: " .. character_:GetAnimationJump())
        log:Write(LOG_INFO, "  Air: " .. character_:GetAnimationAir())
    end
    log:Write(LOG_INFO, "========================")
end

function CreateInstructions()
    -- Construct new Text object, set string to display and font to use
    local instructionText = ui.root:CreateChild("Text")
    instructionText.text = "Use WASD keys to drive, mouse/touch to rotate camera\n"..
        "F5 to save scene, F7 to load\n"..
        "[New Character Demo]"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 15)
    -- The text has multiple rows. Center them in relation to each other
    instructionText.textAlignment = HA_CENTER

    -- Position the text relative to the screen center
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_CENTER
    instructionText:SetPosition(0, 10)
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate")
    UnsubscribeFromEvent("SceneUpdate")
end

function HandleUpdate(eventType, eventData)
    if character_ == nil then
        return
    end

    -- Clear previous controls
    character_.controls:Set(CTRL_FORWARD + CTRL_BACK + CTRL_LEFT + CTRL_RIGHT + CTRL_JUMP, false)

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

        -- Add character yaw & pitch from the mouse motion or touch input
        if touchEnabled then
            for i=0, input.numTouches - 1 do
                local state = input:GetTouch(i)
                if not state.touchedElement then -- Touch on empty space
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

        -- Turn on/off gyroscope on mobile platform
        if input:GetKeyPress(KEY_G) then
            useGyroscope = not useGyroscope
        end
    end
end

function HandlePostUpdate(eventType, eventData)
    if character_ == nil then
        return
    end

    -- Get camera lookat dir from character yaw + pitch
    local characterNode = character_:GetNode()
    local rot = Quaternion(character_.controls.yaw, Vector3(0.0, 1.0, 0.0))
    local dir = rot * Quaternion(character_.controls.pitch, Vector3.RIGHT)

    -- Third person camera: position behind the character
    local aimPoint = characterNode.position + rot * Vector3(0.0, 1.7, 0.0) -- You can modify x Vector3 value to translate the fixed character position (indicative range[-2;2])

    -- Collide camera ray with static physics objects (layer bitmask 2) to ensure we see the character properly
    local rayDir = dir * Vector3(0.0, 0.0, -1.0) -- For indoor scenes you can use dir * Vector3(0.0, 0.0, -0.5) to prevent camera from crossing the walls
    local rayDistance = cameraDistance
    local result = scene_:GetComponent("PhysicsWorld"):RaycastSingle(Ray(aimPoint, rayDir), rayDistance, CollisionMaskCamera)
    if result.body ~= nil then
        rayDistance = Min(rayDistance, result.distance)
    end
    rayDistance = Clamp(rayDistance, CAMERA_MIN_DIST, cameraDistance)

    cameraNode_.position = aimPoint + rayDir * rayDistance
    cameraNode_.rotation = dir
end

function HandlePostRenderUpdate(eventType, eventData)

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

