-- Urho3D editor layer window
-- Converted from AngelScript to Lua

-- Edit mask type enumeration
EDIT_VIEW_MASK = 0
EDIT_LIGHT_MASK = 1
EDIT_SHADOW_MASK = 2
EDIT_ZONE_MASK = 3

-- Global variables
local lineEditType = StringHash("LineEdit")
local eventTypeMouseButtonDown = StringHash("MouseButtonDown")
local eventTypeMouseMove = StringHash("MouseMove")

bits = {}
layerWindow = nil
layerWindowPosition = IntVector2(0, 0)
patternMaskNode = nil
previousEdit = EDIT_SELECT
toggleBusy = false
editMaskType = 0

function CreateLayerEditor()
    if layerWindow ~= nil then
        return
    end

    layerWindow = LoadEditorUI("UI/EditorLayersWindow.xml")
    ui.root:AddChild(layerWindow)
    layerWindow.opacity = uiMaxOpacity

    HideLayerEditor()

    -- Resize bits array
    for i = 1, MAX_BITMASK_BITS do
        bits[i] = nil
    end

    local editMaskModeList = layerWindow:GetChild("LayerModeEdit", true)
    SubscribeToEvent(editMaskModeList, "ItemSelected", "HandleLayerModeEdit")

    for i = 0, MAX_BITMASK_BITS - 1 do
        bits[i + 1] = layerWindow:GetChild("Bit" .. tostring(i), true)
        bits[i + 1]:SetVar("index", Variant(i))
        SubscribeToEvent(bits[i + 1], "Toggled", "ToggleBits")
    end
end

function ShowLayerEditor()
    -- avoid to show layer window when we type text in LineEdit
    if ui.focusElement ~= nil and ui.focusElement.type == lineEditType and lastSelectedNode.Get() == nil then
        return false
    end

    -- to avoid when we close dialog with selected other node
    local node = lastSelectedNode.Get()
    patternMaskNode = node

    -- just change position if already opened
    if layerWindow.visible == true then
        HideLayerEditor()
        return true
    end

    -- to prevent manipulation until we change mask for one or group nodes
    previousEdit = editMode
    editMode = EDIT_SELECT

    -- get mask type from pattern node
    EstablishSelectedNodeBitMaskToPanel()

    layerWindowPosition = ui.cursorPosition
    layerWindow.position = layerWindowPosition
    layerWindowPosition.x = layerWindowPosition.x + layerWindow.width / 2
    layerWindow.visible = true
    layerWindow:BringToFront()

    return true
end

function HideLayerEditor()
    layerWindow.visible = false
    editMode = previousEdit
end

function EstablishSelectedNodeBitMaskToPanel()
    if #selectedNodes < 1 then return end
    local node = patternMaskNode

    if node ~= nil then
        -- find first drawable to get mask
        local components = node:GetComponents()

        local firstDrawableInNode = nil
        if #components > 0 then
            firstDrawableInNode = components[1]
        end

        if firstDrawableInNode ~= nil then
            local showMask = 0

            if editMaskType == EDIT_VIEW_MASK then
                showMask = firstDrawableInNode.viewMask
            elseif editMaskType == EDIT_LIGHT_MASK then
                showMask = firstDrawableInNode.lightMask
            elseif editMaskType == EDIT_SHADOW_MASK then
                showMask = firstDrawableInNode.shadowMask
            elseif editMaskType == EDIT_ZONE_MASK then
                showMask = firstDrawableInNode.zoneMask
            end

            SetupBitsPanel(showMask)
        end
    end
end

function SetupBitsPanel(mask)
    for i = 0, 7 do
        if bit.band(bit.lshift(1, i), mask) ~= 0 then
            bits[i + 1].checked = true
        else
            bits[i + 1].checked = false
        end
    end
end

function ChangeNodeViewMask(node, group, mask)
    local components = node:GetComponents()
    if #components > 0 then
        for componentIndex = 1, #components do
            local component = components[componentIndex]
            local drawable = component
            if drawable ~= nil then
                -- Save before modification
                local action = CreateDrawableMaskAction()
                action:Define(drawable, editMaskType)
                table.insert(group.actions, action)

                if editMaskType == EDIT_VIEW_MASK then
                    drawable.viewMask = mask
                elseif editMaskType == EDIT_LIGHT_MASK then
                    drawable.lightMask = mask
                elseif editMaskType == EDIT_SHADOW_MASK then
                    drawable.shadowMask = mask
                elseif editMaskType == EDIT_ZONE_MASK then
                    drawable.zoneMask = mask
                end
            end
        end
    end
end

function EstablishBitMaskToSelectedNodes()
    if #selectedNodes < 1 then return end

    -- Group for storing undo actions
    local group = EditActionGroup()

    for indexNode = 1, #selectedNodes do
        local node = selectedNodes[indexNode]
        if node ~= nil then
            local mask = 0
            for i = 0, MAX_BITMASK_BITS - 1 do
                mask = bit.bor(mask, bits[i + 1].checked and bit.lshift(1, i) or 0)
            end

            if mask == MAX_BITMASK_VALUE then
                mask = -1
            end

            ChangeNodeViewMask(node, group, mask)
            local children = node:GetChildren(true)
            if #children > 0 then
                for i = 1, #children do
                    ChangeNodeViewMask(children[i], group, mask)
                end
            end
        end
    end

    SaveEditActionGroup(group)
    SetSceneModified()
end

function HandleLayerModeEdit(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    editMaskType = edit.selection
    EstablishSelectedNodeBitMaskToPanel()
end

function HandleMaskTypeScroll(eventType, eventData)
    if not layerWindow:IsInside(ui.cursorPosition, true) then return end

    local listView = layerWindow:GetChild("LayerModeEdit", true)
    editMaskType = listView.selection

    local wheel = eventData["Wheel"]:GetInt()

    if wheel > 0 then
        if editMaskType > 0 then editMaskType = editMaskType - 1 end
    elseif wheel < 0 then
        if editMaskType < 3 then editMaskType = editMaskType + 1 end
    end

    listView.selection = editMaskType
    EstablishSelectedNodeBitMaskToPanel()
end

function HandleHideLayerEditor(eventType, eventData)
    if layerWindow.visible == false then return end

    -- if layer window not in focus and mouse follow away - close layer window
    if eventType == eventTypeMouseMove then
        local mousePos = IntVector2()
        mousePos.x = eventData["X"]:GetInt()
        mousePos.y = eventData["Y"]:GetInt()

        local a = Vector2(layerWindowPosition.x, layerWindowPosition.y)
        local b = Vector2(mousePos.x, mousePos.y)
        local dir = a - b
        local distance = dir:Length()

        if distance > layerWindow.width then
            HideLayerEditor()
        end
    -- if user click on scene - close layer window
    elseif eventType == eventTypeMouseButtonDown then
        if ui.focusElement == nil then
            HideLayerEditor()
        end
    end
end

-- Every time when we click on bits they are immediately established for all selected nodes for masks
function ToggleBits(eventType, eventData)
    if toggleBusy then return end
    toggleBusy = true

    local cb = eventData["Element"]:GetPtr()
    local bitIndex = cb:GetVar("index"):GetInt()

    if bitIndex < MAX_BITMASK_BITS then
        -- batch bits invert if pressed ctrl or alt
        if input:GetKeyDown(KEY_CTRL) then
            local bit = true
            bits[bitIndex + 1].checked = bit

            for i = 0, MAX_BITMASK_BITS - 1 do
                if i ~= bitIndex then
                    bits[i + 1].checked = not bit
                end
            end
        elseif input:GetKeyDown(KEY_ALT) then
            local bit = false
            bits[bitIndex + 1].checked = bit

            for i = 0, MAX_BITMASK_BITS - 1 do
                if i ~= bitIndex then
                    bits[i + 1].checked = not bit
                end
            end
        end

        EstablishBitMaskToSelectedNodes()
    end

    toggleBusy = false
end
