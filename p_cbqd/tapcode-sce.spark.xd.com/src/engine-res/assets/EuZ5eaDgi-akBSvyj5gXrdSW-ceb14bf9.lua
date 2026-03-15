-- EditorToolBar.lua - Manually rewritten from EditorToolBar.as
-- Complete hand translation from AngelScript to Lua

-- Global variables
local subscribedToEditorToolBar = false
local toolBarDirty = true
local toolBar = nil
local VIEW_MODE = StringHash("VIEW_MODE")

-- Create the editor toolbar
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

    -- Run/Pause/Revert group
    local runUpdateGroup = CreateGroup("RunUpdateGroup", LM_HORIZONTAL)
    runUpdateGroup:AddChild(CreateToolBarToggle("RunUpdatePlay"))
    runUpdateGroup:AddChild(CreateToolBarToggle("RunUpdatePause"))
    runUpdateGroup:AddChild(CreateToolBarToggle("RevertOnPause"))
    FinalizeGroupHorizontal(runUpdateGroup, "ToolBarToggle")
    toolBar:AddChild(runUpdateGroup)

    toolBar:AddChild(CreateToolBarSpacer(4))

    -- Edit mode group (Move/Rotate/Scale/Select)
    local editModeGroup = CreateGroup("EditModeGroup", LM_HORIZONTAL)
    editModeGroup:AddChild(CreateToolBarToggle("EditMove"))
    editModeGroup:AddChild(CreateToolBarToggle("EditRotate"))
    editModeGroup:AddChild(CreateToolBarToggle("EditScale"))
    editModeGroup:AddChild(CreateToolBarToggle("EditSelect"))
    FinalizeGroupHorizontal(editModeGroup, "ToolBarToggle")
    toolBar:AddChild(editModeGroup)

    -- Axis mode group (World/Local)
    local axisModeGroup = CreateGroup("AxisModeGroup", LM_HORIZONTAL)
    axisModeGroup:AddChild(CreateToolBarToggle("AxisWorld"))
    axisModeGroup:AddChild(CreateToolBarToggle("AxisLocal"))
    FinalizeGroupHorizontal(axisModeGroup, "ToolBarToggle")
    toolBar:AddChild(axisModeGroup)

    toolBar:AddChild(CreateToolBarSpacer(4))

    -- Snap toggles
    toolBar:AddChild(CreateToolBarToggle("MoveSnap"))
    toolBar:AddChild(CreateToolBarToggle("RotateSnap"))
    toolBar:AddChild(CreateToolBarToggle("ScaleSnap"))

    -- Snap scale mode group
    local snapScaleModeGroup = CreateGroup("SnapScaleModeGroup", LM_HORIZONTAL)
    snapScaleModeGroup:AddChild(CreateToolBarToggle("SnapScaleHalf"))
    snapScaleModeGroup:AddChild(CreateToolBarToggle("SnapScaleQuarter"))
    FinalizeGroupHorizontal(snapScaleModeGroup, "ToolBarToggle")
    toolBar:AddChild(snapScaleModeGroup)

    toolBar:AddChild(CreateToolBarSpacer(4))

    -- Pick mode group
    local pickModeGroup = CreateGroup("PickModeGroup", LM_HORIZONTAL)
    pickModeGroup:AddChild(CreateToolBarToggle("PickGeometries"))
    pickModeGroup:AddChild(CreateToolBarToggle("PickLights"))
    pickModeGroup:AddChild(CreateToolBarToggle("PickZones"))
    pickModeGroup:AddChild(CreateToolBarToggle("PickRigidBodies"))
    pickModeGroup:AddChild(CreateToolBarToggle("PickUIElements"))
    FinalizeGroupHorizontal(pickModeGroup, "ToolBarToggle")
    toolBar:AddChild(pickModeGroup)

    toolBar:AddChild(CreateToolBarSpacer(4))

    -- Fill mode group
    local fillModeGroup = CreateGroup("FillModeGroup", LM_HORIZONTAL)
    fillModeGroup:AddChild(CreateToolBarToggle("FillPoint"))
    fillModeGroup:AddChild(CreateToolBarToggle("FillWireFrame"))
    fillModeGroup:AddChild(CreateToolBarToggle("FillSolid"))
    FinalizeGroupHorizontal(fillModeGroup, "ToolBarToggle")
    toolBar:AddChild(fillModeGroup)

    toolBar:AddChild(CreateToolBarSpacer(4))

    -- Origin toggle
    local originGroup = CreateGroup("OriginGroup", LM_HORIZONTAL)
    originGroup:AddChild(CreateToolBarToggle("ShowOrigin"))
    FinalizeGroupHorizontal(originGroup, "ToolBarToggle")
    toolBar:AddChild(originGroup)

    toolBar:AddChild(CreateToolBarSpacer(4))

    -- Viewport mode dropdown
    local viewportModeList = DropDownList()
    viewportModeList:SetStyleAuto()
    viewportModeList:SetMaxSize(100, 18)
    viewportModeList:AddItem(CreateViewPortModeText("Single", VIEWPORT_SINGLE))
    viewportModeList:AddItem(CreateViewPortModeText("1 Top / 1 Bottom", bit.bor(VIEWPORT_TOP, VIEWPORT_BOTTOM)))
    viewportModeList:AddItem(CreateViewPortModeText("1 Left / 1 Right", bit.bor(VIEWPORT_LEFT, VIEWPORT_RIGHT)))
    viewportModeList:AddItem(CreateViewPortModeText("Top Left / 3", bit.bor(bit.bor(VIEWPORT_TOP_LEFT, VIEWPORT_TOP_RIGHT), bit.bor(VIEWPORT_BOTTOM_LEFT, VIEWPORT_BOTTOM_RIGHT))))
    viewportModeList:AddItem(CreateViewPortModeText("Top Right / 3", bit.bor(bit.bor(VIEWPORT_TOP_LEFT, VIEWPORT_TOP_RIGHT), bit.bor(VIEWPORT_BOTTOM_LEFT, VIEWPORT_BOTTOM_RIGHT))))
    viewportModeList:AddItem(CreateViewPortModeText("Bottom Left / 3", bit.bor(bit.bor(VIEWPORT_TOP_LEFT, VIEWPORT_TOP_RIGHT), bit.bor(VIEWPORT_BOTTOM_LEFT, VIEWPORT_BOTTOM_RIGHT))))
    viewportModeList:AddItem(CreateViewPortModeText("Bottom Right / 3", bit.bor(bit.bor(VIEWPORT_TOP_LEFT, VIEWPORT_TOP_RIGHT), bit.bor(VIEWPORT_BOTTOM_LEFT, VIEWPORT_BOTTOM_RIGHT))))
    viewportModeList:AddItem(CreateViewPortModeText("1 Top / 2 Bottom", bit.bor(bit.bor(VIEWPORT_TOP, VIEWPORT_BOTTOM_LEFT), VIEWPORT_BOTTOM_RIGHT)))
    viewportModeList:AddItem(CreateViewPortModeText("2 Top / 1 Bottom", bit.bor(bit.bor(VIEWPORT_TOP_LEFT, VIEWPORT_TOP_RIGHT), VIEWPORT_BOTTOM)))
    viewportModeList:AddItem(CreateViewPortModeText("1 Left / 2 Right", bit.bor(bit.bor(VIEWPORT_LEFT, VIEWPORT_TOP_RIGHT), VIEWPORT_BOTTOM_RIGHT)))
    viewportModeList:AddItem(CreateViewPortModeText("2 Left / 1 Right", bit.bor(bit.bor(VIEWPORT_TOP_LEFT, VIEWPORT_BOTTOM_LEFT), VIEWPORT_RIGHT)))

    -- Set current selection
    local numItems = tonumber(viewportModeList.numItems) or 0
    for i = 0, numItems - 1 do
        local item = viewportModeList:GetItem(i)
        if item ~= nil and item:GetVar(VIEW_MODE):GetUInt() == viewportMode then
            viewportModeList.selection = i
            break
        end
    end

    toolBar:AddChild(viewportModeList)
    SubscribeToEvent(viewportModeList, "ItemSelected", "ToolBarSetViewportMode")
end

-- Create a toolbar toggle button
function CreateToolBarToggle(title)
    local toggle = CheckBox()
    toggle.name = title
    toggle:SetStyleAuto()
    toggle:SetFixedSize(40, 40)

    CreateToolBarIcon(toggle)
    
    CreateToolTip(toggle, title, IntVector2(toggle.width + 10, toggle.height - 10))

    return toggle
end

-- Create icon for toolbar button
function CreateToolBarIcon(element)
    local icon = BorderImage("Icon")
    icon.defaultStyle = iconStyle
    icon.style = element.name  -- Set style to element name (e.g., "RunUpdatePlay")
    icon:SetFixedSize(30, 30)
    icon.blendMode = BLEND_ALPHA
    element:AddChild(icon)
end

-- Create a button group
function CreateGroup(title, layoutMode)
    local group = UIElement()
    group.name = title
    group.defaultStyle = uiStyle
    group.layoutMode = layoutMode
    return group
end

-- Finalize horizontal button group with proper styles
function FinalizeGroupHorizontal(group, baseStyle)
    local numChildren = tonumber(group.numChildren) or 0
    for i = 0, numChildren - 1 do
        local child = group:GetChild(i)
        if child ~= nil then
            if i == 0 and i < numChildren - 1 then
                child.style = baseStyle .. "GroupLeft"
            elseif i < numChildren - 1 then
                child.style = baseStyle .. "GroupMiddle"
            else
                child.style = baseStyle .. "GroupRight"
            end
        end
    end
    group.maxSize = group.size
end

-- Create a spacer element
function CreateToolBarSpacer(width)
    local spacer = UIElement()
    spacer:SetFixedWidth(width)
    return spacer
end

-- Create tooltip for button
function CreateToolTip(parent, title, offset)
    local toolTip = ToolTip()
    parent:AddChild(toolTip)
    toolTip.name = "ToolTip"

    local textElement = Text()
    toolTip:AddChild(textElement)
    textElement.name = "Text"
    textElement:SetStyle("ToolTipText")
    textElement.text = title
    textElement:SetPosition(offset)

    return toolTip
end

-- Create viewport mode text item
function CreateViewPortModeText(text_, mode)
    local text = Text()
    text.text = text_
    text:SetVar(VIEW_MODE, Variant(mode))
    text.style = "EditorEnumAttributeText"
    return text
end

-- Update toolbar button states
function UpdateDirtyToolBar()
    if toolBar == nil or not toolBarDirty then
        return
    end

    -- Already implemented in temp file - to be integrated

    toolBarDirty = false
end

-- Event handlers (simplified - just toggle the state)
function ToolBarRunUpdatePlay(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        StartSceneUpdate()
    end
    toolBarDirty = true
end

function ToolBarRunUpdatePause(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        StopSceneUpdate()
    end
    toolBarDirty = true
end

function ToolBarRevertOnPause(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    revertOnPause = edit.checked
    toolBarDirty = true
end

function ToolBarEditModeMove(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        editMode = EDIT_MOVE
    end
    toolBarDirty = true
end

function ToolBarEditModeRotate(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        editMode = EDIT_ROTATE
    end
    toolBarDirty = true
end

function ToolBarEditModeScale(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        editMode = EDIT_SCALE
    end
    toolBarDirty = true
end

function ToolBarEditModeSelect(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        editMode = EDIT_SELECT
    end
    toolBarDirty = true
end

function ToolBarAxisModeWorld(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        axisMode = AXIS_WORLD
    end
    toolBarDirty = true
end

function ToolBarAxisModeLocal(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        axisMode = AXIS_LOCAL
    end
    toolBarDirty = true
end

-- Snap toggles
function ToolBarMoveSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    moveSnap = edit.checked
    toolBarDirty = true
end

function ToolBarRotateSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    rotateSnap = edit.checked
    toolBarDirty = true
end

function ToolBarScaleSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    scaleSnap = edit.checked
    toolBarDirty = true
end

-- Snap scale modes
function ToolBarSnapScaleModeHalf(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        snapScaleMode = SNAP_SCALE_HALF
        snapScale = 0.5
    elseif snapScaleMode == SNAP_SCALE_HALF then
        snapScaleMode = SNAP_SCALE_FULL
        snapScale = 1.0
    end
    toolBarDirty = true
end

function ToolBarSnapScaleModeQuarter(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        snapScaleMode = SNAP_SCALE_QUARTER
        snapScale = 0.25
    elseif snapScaleMode == SNAP_SCALE_QUARTER then
        snapScaleMode = SNAP_SCALE_FULL
        snapScale = 1.0
    end
    toolBarDirty = true
end

-- Pick mode handlers
function ToolBarPickModeGeometries(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        pickMode = PICK_GEOMETRIES
    end
    toolBarDirty = true
end

function ToolBarPickModeLights(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        pickMode = PICK_LIGHTS
    end
    toolBarDirty = true
end

function ToolBarPickModeZones(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        pickMode = PICK_ZONES
    end
    toolBarDirty = true
end

function ToolBarPickModeRigidBodies(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        pickMode = PICK_RIGIDBODIES
    end
    toolBarDirty = true
end

function ToolBarPickModeUIElements(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        pickMode = PICK_UI_ELEMENTS
    end
    toolBarDirty = true
end

-- Fill mode handlers
function ToolBarFillModePoint(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        fillMode = FILL_POINT
    end
    toolBarDirty = true
end

function ToolBarFillModeWireFrame(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        fillMode = FILL_WIREFRAME
    end
    toolBarDirty = true
end

function ToolBarFillModeSolid(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    if edit.checked then
        fillMode = FILL_SOLID
    end
    toolBarDirty = true
end

-- Origin toggle
function ToolBarShowOrigin(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    EditorOriginShow = edit.checked
    toolBarDirty = true
end

-- Viewport mode selection
function ToolBarSetViewportMode(eventType, eventData)
    local dropDown = eventData["Element"]:GetPtr()
    local selected = dropDown.selectedItem
    dropDown.focus = false
    local mode = selected:GetVar(VIEW_MODE):GetUInt()
    SetViewportMode(mode)
end

-- NOTE: UpdateDirtyToolBar() function is very long (~130 lines)
-- It needs to be added from the AS version or temp_UpdateDirtyToolBar.lua
function UpdateDirtyToolBar()
    if toolBar == nil or not toolBarDirty then
        return
    end

    local runUpdatePlayToggle = toolBar:GetChild("RunUpdatePlay", true)
    if runUpdatePlayToggle.checked ~= runUpdate then
        runUpdatePlayToggle.checked = runUpdate
    end

    local runUpdatePauseToggle = toolBar:GetChild("RunUpdatePause", true)
    if runUpdatePauseToggle.checked ~= (not runUpdate) then
        runUpdatePauseToggle.checked = not runUpdate
    end

    local revertOnPauseToggle = toolBar:GetChild("RevertOnPause", true)
    if revertOnPauseToggle.checked ~= revertOnPause then
        revertOnPauseToggle.checked = revertOnPause
    end

    local editMoveToggle = toolBar:GetChild("EditMove", true)
    if editMoveToggle.checked ~= (editMode == EDIT_MOVE) then
        editMoveToggle.checked = (editMode == EDIT_MOVE)
    end

    local editRotateToggle = toolBar:GetChild("EditRotate", true)
    if editRotateToggle.checked ~= (editMode == EDIT_ROTATE) then
        editRotateToggle.checked = (editMode == EDIT_ROTATE)
    end

    local editScaleToggle = toolBar:GetChild("EditScale", true)
    if editScaleToggle.checked ~= (editMode == EDIT_SCALE) then
        editScaleToggle.checked = (editMode == EDIT_SCALE)
    end

    local editSelectToggle = toolBar:GetChild("EditSelect", true)
    if editSelectToggle.checked ~= (editMode == EDIT_SELECT) then
        editSelectToggle.checked = (editMode == EDIT_SELECT)
    end

    local axisWorldToggle = toolBar:GetChild("AxisWorld", true)
    if axisWorldToggle.checked ~= (axisMode == AXIS_WORLD) then
        axisWorldToggle.checked = (axisMode == AXIS_WORLD)
    end

    local axisLocalToggle = toolBar:GetChild("AxisLocal", true)
    if axisLocalToggle.checked ~= (axisMode == AXIS_LOCAL) then
        axisLocalToggle.checked = (axisMode == AXIS_LOCAL)
    end

    local moveSnapToggle = toolBar:GetChild("MoveSnap", true)
    if moveSnapToggle.checked ~= moveSnap then
        moveSnapToggle.checked = moveSnap
    end

    local rotateSnapToggle = toolBar:GetChild("RotateSnap", true)
    if rotateSnapToggle.checked ~= rotateSnap then
        rotateSnapToggle.checked = rotateSnap
    end

    local scaleSnapToggle = toolBar:GetChild("ScaleSnap", true)
    if scaleSnapToggle.checked ~= scaleSnap then
        scaleSnapToggle.checked = scaleSnap
    end

    local snapStepHalfToggle = toolBar:GetChild("SnapScaleHalf", true)
    if snapStepHalfToggle.checked ~= (snapScaleMode == SNAP_SCALE_HALF) then
        snapStepHalfToggle.checked = (snapScaleMode == SNAP_SCALE_HALF)
    end

    local snapStepQuarterToggle = toolBar:GetChild("SnapScaleQuarter", true)
    if snapStepQuarterToggle.checked ~= (snapScaleMode == SNAP_SCALE_QUARTER) then
        snapStepQuarterToggle.checked = (snapScaleMode == SNAP_SCALE_QUARTER)
    end

    local pickGeometriesToggle = toolBar:GetChild("PickGeometries", true)
    if pickGeometriesToggle.checked ~= (pickMode == PICK_GEOMETRIES) then
        pickGeometriesToggle.checked = (pickMode == PICK_GEOMETRIES)
    end

    local pickLightsToggle = toolBar:GetChild("PickLights", true)
    if pickLightsToggle.checked ~= (pickMode == PICK_LIGHTS) then
        pickLightsToggle.checked = (pickMode == PICK_LIGHTS)
    end

    local pickZonesToggle = toolBar:GetChild("PickZones", true)
    if pickZonesToggle.checked ~= (pickMode == PICK_ZONES) then
        pickZonesToggle.checked = (pickMode == PICK_ZONES)
    end

    local pickRigidBodiesToggle = toolBar:GetChild("PickRigidBodies", true)
    if pickRigidBodiesToggle.checked ~= (pickMode == PICK_RIGIDBODIES) then
        pickRigidBodiesToggle.checked = (pickMode == PICK_RIGIDBODIES)
    end

    local pickUIElementsToggle = toolBar:GetChild("PickUIElements", true)
    if pickUIElementsToggle.checked ~= (pickMode == PICK_UI_ELEMENTS) then
        pickUIElementsToggle.checked = (pickMode == PICK_UI_ELEMENTS)
    end

    local fillPointToggle = toolBar:GetChild("FillPoint", true)
    if fillPointToggle.checked ~= (fillMode == FILL_POINT) then
        fillPointToggle.checked = (fillMode == FILL_POINT)
    end

    local fillWireFrameToggle = toolBar:GetChild("FillWireFrame", true)
    if fillWireFrameToggle.checked ~= (fillMode == FILL_WIREFRAME) then
        fillWireFrameToggle.checked = (fillMode == FILL_WIREFRAME)
    end

    local fillSolidToggle = toolBar:GetChild("FillSolid", true)
    if fillSolidToggle.checked ~= (fillMode == FILL_SOLID) then
        fillSolidToggle.checked = (fillMode == FILL_SOLID)
    end

    local showOriginToggle = toolBar:GetChild("ShowOrigin", true)
    if showOriginToggle.checked ~= (EditorOriginShow == true) then
        showOriginToggle.checked = (EditorOriginShow == true)
    end

    -- Subscribe to events if not already subscribed
    if not subscribedToEditorToolBar then
        SubscribeToEvent(runUpdatePlayToggle, "Toggled", "ToolBarRunUpdatePlay")
        SubscribeToEvent(runUpdatePauseToggle, "Toggled", "ToolBarRunUpdatePause")
        SubscribeToEvent(revertOnPauseToggle, "Toggled", "ToolBarRevertOnPause")

        SubscribeToEvent(editMoveToggle, "Toggled", "ToolBarEditModeMove")
        SubscribeToEvent(editRotateToggle, "Toggled", "ToolBarEditModeRotate")
        SubscribeToEvent(editScaleToggle, "Toggled", "ToolBarEditModeScale")
        SubscribeToEvent(editSelectToggle, "Toggled", "ToolBarEditModeSelect")

        SubscribeToEvent(axisWorldToggle, "Toggled", "ToolBarAxisModeWorld")
        SubscribeToEvent(axisLocalToggle, "Toggled", "ToolBarAxisModeLocal")

        SubscribeToEvent(moveSnapToggle, "Toggled", "ToolBarMoveSnap")
        SubscribeToEvent(rotateSnapToggle, "Toggled", "ToolBarRotateSnap")
        SubscribeToEvent(scaleSnapToggle, "Toggled", "ToolBarScaleSnap")

        SubscribeToEvent(snapStepHalfToggle, "Toggled", "ToolBarSnapScaleModeHalf")
        SubscribeToEvent(snapStepQuarterToggle, "Toggled", "ToolBarSnapScaleModeQuarter")

        SubscribeToEvent(pickGeometriesToggle, "Toggled", "ToolBarPickModeGeometries")
        SubscribeToEvent(pickLightsToggle, "Toggled", "ToolBarPickModeLights")
        SubscribeToEvent(pickZonesToggle, "Toggled", "ToolBarPickModeZones")
        SubscribeToEvent(pickRigidBodiesToggle, "Toggled", "ToolBarPickModeRigidBodies")
        SubscribeToEvent(pickUIElementsToggle, "Toggled", "ToolBarPickModeUIElements")

        SubscribeToEvent(fillPointToggle, "Toggled", "ToolBarFillModePoint")
        SubscribeToEvent(fillWireFrameToggle, "Toggled", "ToolBarFillModeWireFrame")
        SubscribeToEvent(fillSolidToggle, "Toggled", "ToolBarFillModeSolid")

        SubscribeToEvent(showOriginToggle, "Toggled", "ToolBarShowOrigin")

        subscribedToEditorToolBar = true
    end

    toolBarDirty = false
end
