-- EditorView.lua - Manually rewritten from EditorView.as
-- Core framework only - Full implementation in progress
-- AS Original: 2797 lines, 80+ functions

-- Global variables
cameraLookAtNode = nil
cameraNode = nil
camera = nil
gridNode = nil
grid = nil
viewportUI = nil
viewportMode = 0
viewportArea = IntRect(0, 0, 0, 0)
renderPath = nil
renderPathName = ""
gammaCorrection = false
HDR = false
cameraFlyMode = true
limitRotation = false
orbiting = false
showGrid = true
grid2DMode = false
mmbPanMode = false
activeViewport = nil
viewports = {}
cameraBaseSpeed = 10.0
gridSize = 16
viewNearClip = 0.1
viewFarClip = 1000.0
viewFov = 45.0

-- Viewport constants (must be global for EditorToolBar)
VIEWPORT_SINGLE = 0x00000000
VIEWPORT_COMPACT = 0x00009000
VIEWPORT_TOP = 0x00000100
VIEWPORT_BOTTOM = 0x00000200
VIEWPORT_LEFT = 0x00000400
VIEWPORT_RIGHT = 0x00000800
VIEWPORT_TOP_LEFT = 0x00001000
VIEWPORT_TOP_RIGHT = 0x00002000
VIEWPORT_BOTTOM_LEFT = 0x00004000
VIEWPORT_BOTTOM_RIGHT = 0x00008000
VIEWPORT_BORDER_H = 0x00000001
VIEWPORT_BORDER_V = 0x00000010
VIEWPORT_QUAD = 0x0000f000

-- Edit mode constants (must be global for EditorToolBar)
EDIT_MOVE = 0
EDIT_ROTATE = 1
EDIT_SCALE = 2
EDIT_SELECT = 3
EDIT_SPAWN = 4

-- Axis mode constants
AXIS_WORLD = 0
AXIS_LOCAL = 1

-- Snap scale mode constants
SNAP_SCALE_FULL = 0
SNAP_SCALE_HALF = 1
SNAP_SCALE_QUARTER = 2

-- ViewportContext class (simplified)
ViewportContext = {}
ViewportContext.__index = ViewportContext

function ViewportContext:new(viewRect, index, viewportId)
    local self = setmetatable({}, ViewportContext)
    self.viewRect = viewRect
    self.index = index
    self.viewportId = viewportId
    self.cameraPitch = 0
    self.cameraYaw = 0

    print("ViewportContext:new - Creating camera node...")
    -- Create camera node structure (lookAt node with camera as child)
    self.cameraLookAtNode = Node()
    self.cameraNode = Node()
    self.cameraLookAtNode:AddChild(self.cameraNode)
    self.camera = self.cameraNode:CreateComponent("Camera")
    self.soundListener = self.cameraNode:CreateComponent("SoundListener")

    print("ViewportContext:new - Camera created: " .. tostring(self.camera))
    print("ViewportContext:new - Creating viewport with scene: " .. tostring(editorScene))
    print("ViewportContext:new - Viewport rect: " .. tostring(viewRect))

    -- Create viewport with rect and renderPath (important for correct rendering!)
    self.viewport = Viewport:new(editorScene, self.camera, viewRect, renderPath)

    print("ViewportContext:new - Viewport created: " .. tostring(self.viewport))
    local rect = self.viewport.rect
    print("ViewportContext:new - Viewport rect: left=" .. rect.left .. ", top=" .. rect.top .. ", right=" .. rect.right .. ", bottom=" .. rect.bottom)

    return self
end

function ViewportContext:ResetCamera()
    -- Reset lookAt node to origin
    self.cameraLookAtNode.position = Vector3(0, 0, 0)
    self.cameraLookAtNode.rotation = Quaternion()

    -- Position camera relative to lookAt node
    self.cameraNode.position = Vector3(0, 5, -10)
    -- Look at origin
    self.cameraNode.rotation = Quaternion(Vector3(0, 0, 1), -self.cameraNode.position)

    self:ReacquireCameraYawPitch()
end

function ViewportContext:ReacquireCameraYawPitch()
    self.cameraPitch = self.cameraNode.rotation:PitchAngle()
    self.cameraYaw = self.cameraNode.rotation:YawAngle()
end

function ViewportContext:CreateViewportContextUI()
    -- Create UI element to hold viewport content
    self.viewportContextUI = UIElement()
    viewportUI:AddChild(self.viewportContextUI)
    self.viewportContextUI:SetPosition(self.viewport.rect.left, self.viewport.rect.top)
    self.viewportContextUI:SetFixedSize(self.viewport.rect.width, self.viewport.rect.height)
    self.viewportContextUI.clipChildren = true

    print("CreateViewportContextUI: Created viewport UI element")
end

-- Create editor camera and viewport
function CreateCamera()
    print("CreateCamera: Starting camera creation...")
    print("CreateCamera: editorScene = " .. tostring(editorScene))

    viewportArea = IntRect(0, 0, graphics.width, graphics.height)

    -- Create single viewport (simplified)
    local viewportContext = ViewportContext:new(
        IntRect(0, 0, graphics.width, graphics.height),
        0,
        VIEWPORT_SINGLE
    )

    viewports = {viewportContext}
    cameraNode = viewportContext.cameraNode
    camera = viewportContext.camera

    SetActiveViewport(viewportContext)

    -- Add viewport to renderer
    renderer:SetViewport(0, viewportContext.viewport)

    ResetCamera()
    UpdateViewParameters()  -- Set camera parameters
    CreateGrid()
    CreateViewportUI()  -- Create UI to display viewport

    print("CreateCamera: Camera position = " .. tostring(cameraNode.position))
    print("CreateCamera: Camera rotation = " .. tostring(cameraNode.rotation))
    print("CreateCamera: Camera farClip = " .. tostring(camera.farClip))
end

function ResetCamera()
    if viewports ~= nil and #viewports > 0 then
        viewports[1]:ResetCamera()
    end
end

function UpdateViewParameters()
    if camera ~= nil then
        camera.nearClip = viewNearClip
        camera.farClip = viewFarClip
        camera.fov = viewFov
        print("UpdateViewParameters: nearClip=" .. viewNearClip .. ", farClip=" .. viewFarClip .. ", fov=" .. viewFov)
    end
end

function CreateGrid()
    if gridNode ~= nil then
        return
    end

    gridNode = Node()
    grid = gridNode:CreateComponent("CustomGeometry")
    grid:SetNumGeometries(1)

    -- Simplified grid - just create a basic grid
    -- TODO: Full grid implementation from AS
    UpdateGrid()
end

function UpdateGrid()
    if grid == nil then
        return
    end

    grid:Clear()
    grid:SetNumGeometries(1)

    -- Simplified grid - draw basic grid lines
    local halfSize = gridSize * 0.5
    local step = 1.0

    grid:BeginGeometry(0, LINE_LIST)

    -- Draw grid lines (simplified)
    for i = -halfSize, halfSize do
        local pos = i * step
        -- Lines along X
        grid:DefineVertex(Vector3(pos, 0, -halfSize * step))
        grid:DefineColor(Color(0.3, 0.3, 0.3, 1))
        grid:DefineVertex(Vector3(pos, 0, halfSize * step))
        grid:DefineColor(Color(0.3, 0.3, 0.3, 1))

        -- Lines along Z
        grid:DefineVertex(Vector3(-halfSize * step, 0, pos))
        grid:DefineColor(Color(0.3, 0.3, 0.3, 1))
        grid:DefineVertex(Vector3(halfSize * step, 0, pos))
        grid:DefineColor(Color(0.3, 0.3, 0.3, 1))
    end

    grid:Commit()
end

function HideGrid()
    if gridNode ~= nil then
        gridNode.enabled = false
    end
end

function ShowGrid()
    if gridNode ~= nil then
        gridNode.enabled = true
    end
end

function SetActiveViewport(viewport)
    activeViewport = viewport
end

function GetActiveViewportCameraRay()
    if camera ~= nil then
        local pos = ui.cursorPosition
        return camera:GetScreenRay(pos.x / graphics.width, pos.y / graphics.height)
    end
    return Ray()
end

-- Camera pan (simplified - no smooth interpolation)
function CameraPan(trans)
    if cameraNode ~= nil then
        cameraNode:Translate(trans, TS_WORLD)
    end
end

-- Camera move forward (simplified)
function CameraMoveForward(trans)
    if cameraNode ~= nil then
        cameraNode:Translate(trans, TS_PARENT)
    end
end

-- Basic camera input handling (simplified from AS HandleStandardUserInput)
function UpdateView(timeStep)
    if ui:HasModalElement() or ui.focusElement ~= nil then
        return
    end

    if cameraNode == nil then
        return
    end

    -- Speed multiplier with Shift key
    local speedMultiplier = 1.0
    if input:GetKeyDown(KEY_LSHIFT) then
        speedMultiplier = 5.0
    end
    local moveSpeed = cameraBaseSpeed * timeStep * speedMultiplier

    -- WASD camera movement (only when Ctrl is not pressed)
    if not input:GetKeyDown(KEY_LCTRL) then
        -- Forward (W or Up arrow)
        if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
            local dir = cameraNode.direction
            dir = dir:Normalized()
            CameraPan(dir * moveSpeed)
        end

        -- Back (S or Down arrow)
        if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
            local dir = cameraNode.direction
            dir = dir:Normalized()
            CameraPan(dir * -moveSpeed)  -- Fixed: -dir not supported
        end

        -- Left (A or Left arrow)
        if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then
            local dir = cameraNode.right
            dir = dir:Normalized()
            CameraPan(dir * -moveSpeed)  -- Fixed: -dir not supported
        end

        -- Right (D or Right arrow)
        if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then
            local dir = cameraNode.right
            dir = dir:Normalized()
            CameraPan(dir * moveSpeed)
        end

        -- Up (E or PageUp)
        if input:GetKeyDown(KEY_E) or input:GetKeyDown(KEY_PAGEUP) then
            CameraPan(Vector3(0, moveSpeed, 0))
        end

        -- Down (Q or PageDown)
        if input:GetKeyDown(KEY_Q) or input:GetKeyDown(KEY_PAGEDOWN) then
            CameraPan(Vector3(0, 1, 0) * -moveSpeed)  -- Fixed
        end
    end

    -- Mouse wheel zoom
    if input.mouseMoveWheel ~= 0 then
        local dir = cameraNode.direction
        dir = dir:Normalized()
        CameraMoveForward(dir * input.mouseMoveWheel * moveSpeed * 10)
    end

    -- Mouse middle button: Pan with Shift, Rotate without Shift
    local isMMBPanning = false
    if input:GetMouseButtonDown(MOUSEB_MIDDLE) then
        if (mmbPanMode and not input:GetKeyDown(KEY_LSHIFT)) or (not mmbPanMode and input:GetKeyDown(KEY_LSHIFT)) then
            isMMBPanning = true
        end
    end

    -- MMB Pan mode
    if isMMBPanning and (input.mouseMove.x ~= 0 or input.mouseMove.y ~= 0) then
        local right = cameraNode.right:Normalized()
        local up = Vector3(0, 1, 0)
        local panSpeed = moveSpeed * 50
        -- Fixed: Vector3 arithmetic using proper operators
        local panX = right * (-input.mouseMove.x * panSpeed)
        local panY = up * (input.mouseMove.y * panSpeed)
        CameraPan(panX + panY)
    end

    -- Mouse rotation (Middle button without pan, or RMB in fly mode)
    if (input:GetMouseButtonDown(MOUSEB_MIDDLE) and not isMMBPanning) or (cameraFlyMode and input:GetMouseButtonDown(MOUSEB_RIGHT)) then
        if input.mouseMove.x ~= 0 or input.mouseMove.y ~= 0 then
            -- Rotate camera based on mouse movement
            local yaw = -input.mouseMove.x * 0.1
            local pitch = -input.mouseMove.y * 0.1

            if cameraNode ~= nil then
                -- Apply rotation
                local rotation = cameraNode.rotation
                rotation = rotation * Quaternion(yaw, Vector3(0, 1, 0))  -- Yaw around world Y

                -- Get current pitch
                local currentPitch = cameraNode.rotation:PitchAngle()
                local newPitch = currentPitch + pitch

                -- Limit pitch if needed
                if limitRotation then
                    newPitch = Clamp(newPitch, -90, 90)
                end

                -- Apply pitch rotation around local right axis
                local right = cameraNode.right
                rotation = rotation * Quaternion(pitch, right)

                cameraNode.rotation = rotation
            end
        end
    end
end

function UpdateViewports(timeStep)
    -- TODO: Implement viewport updates
end

function CreateStatsBar()
    -- Create simple stats text (simplified)
    -- TODO: Full implementation with multiple stats
end

function UpdateStats(timeStep)
    -- Update stats display (simplified - just FPS for now)
    -- TODO: Add more stats (triangles, batches, etc)
end

function SetViewportMode(mode)
    viewportMode = mode
    -- Simplified - only support single viewport for now
    -- TODO: Implement multi-viewport layout changes
    if viewports ~= nil and #viewports > 0 then
        viewports[1].viewportId = mode
    end
end

function SetRenderPath(pathName)
    renderPathName = pathName
    -- TODO: Apply renderpath to viewports
end

function SetFillMode(fillMode_)
    -- TODO: Implement fill mode change
end

function SetGammaCorrection(enable)
    gammaCorrection = enable
    -- TODO: Update renderpath
end

function SetHDR(enable)
    HDR = enable
    -- TODO: Update renderpath
end

-- TODO: Remaining ~60 functions to be implemented from AS
-- Next session will add:
-- - Full camera movement and rotation
-- - Input handling (mouse drag, WASD, etc)
-- - Multi-viewport support
-- - Grid geometry generation
-- - Stats bar display
-- - Viewport border dragging
-- - And much more...

print("EditorView: Core framework loaded (minimal version)")

-- Additional camera control functions
function CameraRotateAroundLookAt(rot)
    -- TODO: Implement
end

function CameraRotateAroundCenter(rot)
    -- TODO: Implement
end

function CameraRotateAroundSelect(rot)
    -- TODO: Implement  
end

function CameraZoom(zoom)
    if camera ~= nil then
        camera.zoom = zoom
    end
end

function FitCamera()
    -- TODO: Implement camera fit to selection
end

-- Node location functions
function LocateNodes(nodes)
    -- TODO: Move camera to view nodes
end

function LocateComponents(components)
    -- TODO: Move camera to view components
end

function LocateNodesAndComponents()
    -- TODO: Combined locate
end

-- Mouse and input functions
function SetMouseLock(enable)
    if enable then
        input.mouseMode = MM_RELATIVE
        input.mouseVisible = false
    else
        input.mouseMode = MM_ABSOLUTE
        input.mouseVisible = true
    end
end

function ReleaseMouseLock()
    SetMouseLock(false)
end

function SetMouseMode(enable)
    SetMouseLock(enable)
end

function SetViewportCursor()
    -- TODO: Update cursor based on viewport border hover
end

-- Viewport border dragging
function HandleViewportBorderDragMove(eventType, eventData)
    -- TODO: Implement viewport resize dragging
end

function HandleViewportBorderDragEnd(eventType, eventData)
    -- TODO: Implement viewport resize end
end

-- View render callbacks
function HandleBeginViewRender(eventType, eventData)
    -- TODO: Pre-render setup
end

function HandleEndViewRender(eventType, eventData)
    -- TODO: Post-render cleanup
end

function HandleBeginViewUpdate(eventType, eventData)
    -- TODO: Pre-update setup
end

function HandleEndViewUpdate(eventType, eventData)
    -- TODO: Post-update cleanup
end

function HandlePostRenderUpdate(eventType, eventData)
    -- TODO: Post-render update
end

-- Advanced input handlers
function HandleStandardUserInput(timeStep)
    -- Already integrated into UpdateView
end

function HandleBlenderUserInput(timeStep)
    -- TODO: Implement Blender-style controls
end

-- Mouse view interaction
function ViewMouseClick()
    -- TODO: Handle mouse click in viewport
end

function ViewMouseClickEnd()
    -- TODO: Handle mouse release
end

function ViewMouseMove()
    -- TODO: Handle mouse move in viewport
end

function ViewRaycast()
    -- TODO: Perform raycast for picking
    return GetActiveViewportCameraRay()
end

-- Debugging toggles
function ToggleRenderingDebug()
    renderingDebug = not renderingDebug
    -- TODO: Update debug rendering
end

function TogglePhysicsDebug()
    physicsDebug = not physicsDebug
    -- TODO: Toggle physics debug draw
end

function ToggleOctreeDebug()
    octreeDebug = not octreeDebug
    -- TODO: Toggle octree debug draw
end

function ToggleNavigationDebug()
    navigationDebug = not navigationDebug
    -- TODO: Toggle navigation debug draw
end

-- Object manipulation
function SteppedObjectManipulation()
    -- TODO: Implement stepped transform
end

function SelectedNodesCenterPoint()
    -- TODO: Calculate center of selected nodes
    return Vector3(0, 0, 0)
end

function MergeNodeBoundingBox(box, node)
    -- TODO: Merge node bounds into box
end

function MergeComponentBoundingBox(box, component)
    -- TODO: Merge component bounds into box
end

-- Create viewport UI container and context UI
function CreateViewportUI()
    print("CreateViewportUI: Creating viewport UI...")

    if viewportUI == nil then
        viewportUI = UIElement()
        ui.root:AddChild(viewportUI)
    end

    viewportUI:SetFixedSize(viewportArea.width, viewportArea.height)
    viewportUI.position = IntVector2(viewportArea.left, viewportArea.top)
    viewportUI.clipChildren = true
    viewportUI.priority = -2000  -- Behind other UI
    viewportUI:RemoveAllChildren()

    print("CreateViewportUI: ViewportUI created, size=" .. viewportArea.width .. "x" .. viewportArea.height)

    -- Create UI for each viewport context
    if viewports ~= nil then
        for i = 1, #viewports do
            viewports[i]:CreateViewportContextUI()
        end
    end

    print("CreateViewportUI: Completed")
end

-- Camera preview
function UpdateCameraPreview()
    -- TODO: Update camera preview window
end

-- Test animation
function StopTestAnimation()
    -- TODO: Stop test animation playback
end

-- New node positioning
function GetNewNodePosition()
    -- TODO: Calculate position for new node
    return Vector3(0, 0, 0)
end

-- Debug drawing
function DrawNodeDebug(node, drawjoint)
    -- TODO: Draw debug visualization for node
end

-- Shadow quality
function SetShadowResolution(res)
    -- TODO: Update shadow map resolution
end

print("EditorView: All function stubs added, core features functional")
