-- Urho3D editor selectable scene node origins (view markers)
-- Converted from AngelScript to Lua

-- Constants
local DEFAULT_SHOW_NAMES_FOR_ALL = false
local ORIGIN_STEP_UPDATE = 10
local NAMES_SIZE = 11
local ORIGIN_NODEID_VAR = StringHash("OriginNodeID")
local ORIGIN_COLOR = Color(1.0, 1.0, 1.0, 1.0)
local ORIGIN_COLOR_SELECTED = Color(0.0, 1.0, 1.0, 1.0)
local ORIGIN_COLOR_DISABLED = Color(1.0, 0.0, 0.0, 1.0)
local ORIGIN_COLOR_TEXT = Color(1.0, 1.0, 1.0, 0.3)
local ORIGIN_COLOR_SELECTED_TEXT = Color(1.0, 1.0, 1.0, 1.0)
local ORIGIN_ICON_SIZE = IntVector2(14, 14)
local ORIGIN_ICON_SIZE_SELECTED = IntVector2(18, 18)
local ORIGINS_VISIBLITY_RANGE = 32.0
local ORIGINOFFSETICON = IntVector2(8, 8)
local ORIGINOFFSETICONSELECTED = IntVector2(10, 8)

-- Global variables
showNamesForAll = DEFAULT_SHOW_NAMES_FOR_ALL
EditorOriginShow = false
rebuildSceneOrigins = true
isOriginsHovered = false

EditorOriginUITimeToUpdate = 0
EditorOriginUITimeToSceneNodeRead = 0
prevSelectedID = 0
selectedNodeInfoState = 0
originHoveredIndex = -1

EditorOriginUIContainer = nil
selectedNodeName = nil
selectedNodeOrigin = nil

selectedNodeOriginChilds = {}
selectedNodeNameChilds = {}
originsNodes = {}
originsIcons = {}
originsNames = {}

function CreateOriginsContainer()
    if editorScene == nil then return end
    EditorOriginUIContainer = UIElement()
    EditorOriginUIContainer.position = IntVector2(0, 0)
    EditorOriginUIContainer:SetSize(graphics.width, graphics.height)
    EditorOriginUIContainer.priority = -1000
    EditorOriginUIContainer.focusMode = FM_NOTFOCUSABLE
    EditorOriginUIContainer.bringToBack = true
    EditorOriginUIContainer.name = "DebugOriginsContainer"
    EditorOriginUIContainer.temporary = true
    ui.root:AddChild(EditorOriginUIContainer)
end

function HandleOriginToggled(eventType, eventData)
    local origin = eventData["Element"]:GetPtr()
    if origin == nil then return end

    if EditorPaintSelectionShow then return end

    if IsSceneOrigin(origin) then
        local nodeID = origin:GetVar(ORIGIN_NODEID_VAR):GetInt()
        if editorScene ~= nil then
            local goBackAndSelectNodeParent = input:GetQualifierDown(QUAL_CTRL)
            local multiSelect = input:GetQualifierDown(QUAL_SHIFT)

            local handle = editorScene:GetNode(nodeID)
            if handle ~= nil then
                local selectedNodeByOrigin = handle
                if selectedNodeByOrigin ~= nil then
                    if goBackAndSelectNodeParent then
                        SelectNode(selectedNodeByOrigin.parent, false)
                    else
                        SelectNode(selectedNodeByOrigin, multiSelect)
                    end
                end
            end
        end
    end
end

function ShowOrigins(isVisible)
    if isVisible == nil then isVisible = true end
    EditorOriginShow = isVisible

    if EditorOriginUIContainer == nil then
        CreateOriginsContainer()
    end

    EditorOriginUIContainer.visible = isVisible
end

function UpdateOrigins()
    -- Early out if Origins are disabled
    if not EditorOriginShow then return end

    CheckKeyboardQualifers()

    if editorScene == nil or EditorOriginUITimeToUpdate > time.systemTime then return end

    EditorOriginUIContainer = ui.root:GetChild("DebugOriginsContainer", false)

    -- Since editor not clear UIs when loading new scenes, this creation called once per Editor's starting event
    -- for other scenes we use the same container
    if EditorOriginUIContainer == nil then
        CreateOriginsContainer()
    end

    if EditorOriginUIContainer ~= nil then
        -- Set visibility for all origins
        EditorOriginUIContainer.visible = EditorOriginShow

        if viewportMode ~= VIEWPORT_SINGLE then
            EditorOriginUIContainer.visible = false
        end

        -- Forced read nodes for some reason:
        if #originsNodes < 1 or rebuildSceneOrigins then
            originsNodes = editorScene:GetChildren(true)
            -- If we don't have free origins icons in arrays, resize x 2
            if #originsIcons < #originsNodes then
                EditorOriginUIContainer:RemoveAllChildren()
                originsIcons = {}
                originsNames = {}

                local newSize = #originsNodes * 2
                for i = 1, newSize do
                    originsIcons[i] = nil
                    originsNames[i] = nil
                end

                if #originsIcons > 0 then
                    for i = 1, #originsIcons do
                        CreateOrigin(i, false)
                    end
                end
            end
            -- If this rebuild pass after new scene loading or add/delete node - reset flag to default
            if rebuildSceneOrigins then
                rebuildSceneOrigins = false
            end
        end

        if #originsNodes > 0 then
            -- Get selected node for feeding proper array's UIElements with style coloring and additional info on ALT
            local selectedNode = nil
            if #selectedNodes > 0 then
                selectedNode = selectedNodes[1]
            elseif #selectedComponents > 0 then
                selectedNode = selectedComponents[1].node
            end

            -- Update existed origins (every 10 ms)
            if #originsNodes > 0 then
                for i = 1, #originsNodes do
                    local eyeDir = originsNodes[i].worldPosition - cameraNode.worldPosition
                    local distance = eyeDir:Length()
                    eyeDir:Normalize()
                    local cameraDir = (cameraNode.worldRotation * Vector3(0.0, 0.0, 1.0)):Normalized()
                    local angleCameraDirVsDirToNode = eyeDir:DotProduct(cameraDir)

                    -- if node in range and in camera view (clip back side)
                    if distance < ORIGINS_VISIBLITY_RANGE and angleCameraDirVsDirToNode > 0.7 then
                        -- turn on origin and move
                        MoveOrigin(i, true)

                        if isThisNodeOneOfSelected(originsNodes[i]) then
                            ShowSelectedNodeOrigin(originsNodes[i], i)
                            originsNames[i].visible = true
                        else
                            if showNamesForAll or (isOriginsHovered and originHoveredIndex == i) then
                                originsNames[i].text = NodeInfo(originsNodes[i], selectedNodeInfoState)
                            end
                        end
                    else
                        -- turn-off origin
                        VisibilityOrigin(i, false)
                    end
                end

                -- Hide non used origins
                for j = #originsNodes + 1, #originsIcons do
                    VisibilityOrigin(j, false)
                end
            end
        end
    end

    EditorOriginUITimeToUpdate = time.systemTime + ORIGIN_STEP_UPDATE
end

function isThisNodeOneOfSelected(node)
    if #selectedNodes < 1 then return false end

    for i = 1, #selectedNodes do
        if node == selectedNodes[i] then
            return true
        end
    end

    return false
end

function ShowSelectedNodeOrigin(node, index)
    if node ~= nil then
        -- just keep node's text and node's origin icon position in actual view
        local vp = activeViewport.viewport
        local sp = activeViewport.camera:WorldToScreenPoint(node.worldPosition)
        originsIcons[index].position = IntVector2(
            math.floor(vp.rect.left + sp.x * vp.rect.right) - ORIGINOFFSETICONSELECTED.x,
            math.floor(vp.rect.top + sp.y * vp.rect.bottom) - ORIGINOFFSETICONSELECTED.y
        )
        originsNames[index].color = ORIGIN_COLOR_SELECTED_TEXT

        if originsNodes[index].enabled then
            originsIcons[index].color = ORIGIN_COLOR_SELECTED
        else
            originsIcons[index].color = ORIGIN_COLOR_DISABLED
        end

        originsIcons[index]:SetFixedSize(ORIGIN_ICON_SIZE_SELECTED.x, ORIGIN_ICON_SIZE_SELECTED.y)

        -- if selected node changed, reset some vars
        if prevSelectedID ~= node:GetID() then
            prevSelectedID = node:GetID()
            selectedNodeInfoState = 0
            originsIcons[index]:SetVar(ORIGIN_NODEID_VAR, Variant(node:GetID()))
        end

        -- We always update to keep and feed alt-info with actual info about node components
        local components = node:GetComponents()
        local componentsShortInfo = {}
        local componentsDetailInfo = {}
        -- Add std info node name + tags
        originsNames[index].text = NodeInfo(node, selectedNodeInfoState) .. "\n"
    end
end

function CreateOrigin(index, isVisible)
    if isVisible == nil then isVisible = false end
    if #originsIcons < index then return end

    originsIcons[index] = BorderImage("Icon")
    originsIcons[index].temporary = true
    originsIcons[index]:SetFixedSize(ORIGIN_ICON_SIZE.x, ORIGIN_ICON_SIZE.y)
    originsIcons[index].texture = cache:GetResource("Texture2D", "Textures/Editor/EditorIcons.png")
    originsIcons[index].imageRect = IntRect(0, 0, 14, 14)
    originsIcons[index].priority = -1000
    originsIcons[index].color = ORIGIN_COLOR
    originsIcons[index].bringToBack = true
    originsIcons[index].enabled = true
    originsIcons[index].selected = true
    originsIcons[index].visible = isVisible
    EditorOriginUIContainer:AddChild(originsIcons[index])

    originsNames[index] = Text()
    originsNames[index].visible = false
    originsNames[index]:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), NAMES_SIZE)
    originsNames[index].color = ORIGIN_COLOR_TEXT
    originsNames[index].temporary = true
    originsNames[index].bringToBack = true
    originsNames[index].priority = -1000
    originsNames[index].enabled = false

    EditorOriginUIContainer:AddChild(originsNames[index])
end

function MoveOrigin(index, isVisible)
    if isVisible == nil then isVisible = false end
    if #originsIcons < index then return end
    if originsIcons[index] == nil then return end
    if originsNodes[index].temporary then
        originsIcons[index].visible = false
        originsNames[index].visible = false
        return
    end

    local vp = activeViewport.viewport
    local sp = activeViewport.camera:WorldToScreenPoint(originsNodes[index].worldPosition)

    originsIcons[index]:SetFixedSize(ORIGIN_ICON_SIZE.x, ORIGIN_ICON_SIZE.y)

    if originsNodes[index].enabled then
        originsIcons[index].color = ORIGIN_COLOR
    else
        originsIcons[index].color = ORIGIN_COLOR_DISABLED
    end

    originsIcons[index].position = IntVector2(
        math.floor(vp.rect.left + sp.x * vp.rect.right) - ORIGINOFFSETICON.x,
        math.floor(vp.rect.top + sp.y * vp.rect.bottom) - ORIGINOFFSETICON.y
    )
    originsIcons[index].visible = isVisible
    originsIcons[index]:SetVar(ORIGIN_NODEID_VAR, Variant(originsNodes[index]:GetID()))

    originsNames[index].position = IntVector2(
        10 + math.floor(vp.rect.left + sp.x * vp.rect.right),
        -5 + math.floor(vp.rect.top + sp.y * vp.rect.bottom)
    )

    if isOriginsHovered and originHoveredIndex == index then
        originsNames[index].visible = true
        originsNames[index].color = ORIGIN_COLOR_SELECTED_TEXT
    else
        originsNames[index].visible = showNamesForAll and isVisible or false
        originsNames[index].color = ORIGIN_COLOR_TEXT
    end
end

function VisibilityOrigin(index, isVisible)
    if isVisible == nil then isVisible = false end
    originsIcons[index].visible = isVisible
    originsNames[index].visible = isVisible
end

function IsSceneOrigin(element)
    if #originsIcons < 1 then return false end

    for i = 1, #originsIcons do
        if element == originsIcons[i] then
            originHoveredIndex = i
            return true
        end
    end

    originHoveredIndex = -1
    return false
end

function CheckKeyboardQualifers()
    -- if pressed alt we inc state for info
    local showAltInfo = input:GetKeyPress(KEY_ALT)
    if showAltInfo then
        if selectedNodeInfoState < 3 then selectedNodeInfoState = selectedNodeInfoState + 1 end
    end

    -- if pressed ctrl we reset info state
    local hideAltInfo = input:GetQualifierDown(QUAL_CTRL)
    if hideAltInfo then
        selectedNodeInfoState = 0
    end

    local showNameForOther = false

    -- In-B.mode Key_Space are busy by quick menu, so we use other key for B.mode
    if hotKeyMode == HOTKEYS_MODE_BLENDER then
        showNameForOther = (input:GetKeyPress(KEY_TAB) and ui.focusElement == nil)
    else
        showNameForOther = (input:GetKeyPress(KEY_SPACE) and ui.focusElement == nil)
    end

    if showNameForOther then
        showNamesForAll = not showNamesForAll
    end
end

function NodeInfo(node, st)
    local result = ""
    if node ~= editorScene then
        if node.name == "" then
            result = "Node"
        else
            result = node.name
        end

        -- Add node's tags if they are exist
        if st > 0 and #node.tags > 0 then
            result = result .. "\n["
            for i = 1, #node.tags do
                result = result .. " " .. node.tags[i]
            end
            result = result .. " ] "
        end
    else
        result = "Scene Origin"
    end

    return result
end

function HandleSceneLoadedForOrigins()
    rebuildSceneOrigins = true
end

function HandleOriginsHoverBegin(eventType, eventData)
    local origin = eventData["Element"]:GetPtr()
    if origin == nil then
        return
    end

    if IsSceneOrigin(origin) then
        local data = VariantMap()
        data["Element"] = Variant(originsIcons[originHoveredIndex])
        data["Id"] = Variant(originHoveredIndex)
        data["NodeId"] = Variant(originsIcons[originHoveredIndex]:GetVar(ORIGIN_NODEID_VAR):GetInt())
        SendEvent(EDITOR_EVENT_ORIGIN_START_HOVER, data)
        isOriginsHovered = true
    end
end

function HandleOriginsHoverEnd(eventType, eventData)
    local origin = eventData["Element"]:GetPtr()
    if origin == nil then
        return
    end

    if IsSceneOrigin(origin) then
        local data = VariantMap()
        data["Element"] = Variant(originsIcons[originHoveredIndex])
        data["Id"] = Variant(originHoveredIndex)
        data["NodeId"] = Variant(originsIcons[originHoveredIndex]:GetVar(ORIGIN_NODEID_VAR):GetInt())
        SendEvent(EDITOR_EVENT_ORIGIN_END_HOVER, data)
        isOriginsHovered = false
    end
end
