-- Urho3D editor hierarchy window handling

-- Item type constants
local ITEM_NONE = 0
local ITEM_NODE = 1
local ITEM_COMPONENT = 2
local ITEM_UI_ELEMENT = 3
local NO_ITEM = 0xFFFFFFFF

-- Type hashes
local SCENE_TYPE = StringHash("Scene")
local NODE_TYPE = StringHash("Node")
local STATICMODEL_TYPE = StringHash("StaticModel")
local ANIMATEDMODEL_TYPE = StringHash("AnimatedModel")
local STATICMODELGROUP_TYPE = StringHash("StaticModelGroup")
local SPLINEPATH_TYPE = StringHash("SplinePath")
local CONSTRAINT_TYPE = StringHash("Constraint")

-- Variable name constants
local NO_CHANGE = string.char(0)
local TYPE_VAR = StringHash("Type")
local NODE_ID_VAR = StringHash("NodeID")
local COMPONENT_ID_VAR = StringHash("ComponentID")
local UI_ELEMENT_ID_VAR = StringHash("UIElementID")
local DRAGDROPCONTENT_VAR = StringHash("DragDropContent")

nodeTextColor = Color(1.0, 1.0, 1.0)
componentTextColor = Color(0.7, 1.0, 0.7)

hierarchyWindow = nil
hierarchyList = nil
showID = true

-- UIElement ID management
local UI_ELEMENT_BASE_ID = 1
uiElementNextID = UI_ELEMENT_BASE_ID

showInternalUIElement = false
showTemporaryObject = false
suppressUIElementChanges = false
hierarchyUpdateSelections = {}

function CreateHierarchyWindow()
    if hierarchyWindow ~= nil then
        return
    end

    -- Load window from XML (includes proper ListView style with hierarchy support)
    hierarchyWindow = LoadEditorUI("UI/EditorHierarchyWindow.xml")
    if hierarchyWindow == nil then
        print("ERROR: Failed to load EditorHierarchyWindow.xml")
        return
    end

    hierarchyList = hierarchyWindow:GetChild("HierarchyList", true)
    if hierarchyList == nil then
        print("ERROR: HierarchyList not found in loaded UI")
        return
    end

    ui.root:AddChild(hierarchyWindow)

    local height = Min(ui.root.height - 60, 500)
    hierarchyWindow:SetSize(300, height)
    hierarchyWindow:SetPosition(35, 100)
    hierarchyWindow.opacity = uiMaxOpacity
    hierarchyWindow:BringToFront()

    -- Set selection to happen on click end
    hierarchyList.selectOnClickEnd = true
    hierarchyList.highlightMode = HM_ALWAYS  -- 始终高亮
    hierarchyList.hierarchyMode = true  -- 启用层级模式，允许选择子项

    -- Set drag & drop target mode on the list background
    hierarchyList.contentElement.dragDropMode = DD_TARGET
    hierarchyList.scrollPanel.dragDropMode = DD_TARGET

    -- Initial update - show scene nodes
    UpdateHierarchyItem(editorScene, true)

    -- Subscribe to selection events
    SubscribeToEvent(hierarchyList, "SelectionChanged", "HandleHierarchyListSelectionChange")
    SubscribeToEvent(hierarchyList, "ItemClicked", "HandleHierarchyItemClick")
    SubscribeToEvent(hierarchyList, "ItemDoubleClicked", "HandleHierarchyListDoubleClick")
end

function ToggleHierarchyWindow()
    if hierarchyWindow.visible == false then
        ShowHierarchyWindow()
    else
        HideHierarchyWindow()
    end
    return true
end

function ShowHierarchyWindow()
    hierarchyWindow.visible = true
    hierarchyWindow:BringToFront()
end

function HideHierarchyWindow()
    if viewportMode == VIEWPORT_COMPACT then
        return
    end
    hierarchyWindow.visible = false
end

-- UpdateHierarchyItem - supports two calling conventions:
-- 1. UpdateHierarchyItem(serializable, clear) - Refresh entire tree from root
-- 2. UpdateHierarchyItem(itemIndex, serializable, parentItem) - Update/Insert at specific index
function UpdateHierarchyItem(param1, param2, param3)
    if hierarchyList == nil then
        print("ERROR: hierarchyList is nil!")
        return
    end

    -- Detect calling convention based on first parameter type
    if type(param1) == "number" then
        -- Version 2: UpdateHierarchyItem(itemIndex, serializable, parentItem)
        local itemIndex = param1
        local serializable = param2
        local parentItem = param3

        -- If serializable is nil, remove the item at itemIndex
        if serializable == nil then
            if itemIndex ~= NO_ITEM and itemIndex ~= M_MAX_UNSIGNED then
                hierarchyList:RemoveItem(itemIndex)
            end
            return itemIndex
        end

        -- Otherwise, insert/update at itemIndex
        return UpdateHierarchyItemRecursive(itemIndex, serializable, parentItem)
    else
        -- Version 1: UpdateHierarchyItem(serializable, clear)
        local serializable = param1
        local clear = param2 or false

        if serializable == nil then
            print("ERROR: serializable is nil!")
            return
        end

        print("UpdateHierarchyItem called for: " .. tostring(serializable))

        -- Clear list if requested
        if clear then
            hierarchyList:RemoveAllItems()
        end

        -- Use recursive version to build tree
        UpdateHierarchyItemRecursive(0, serializable, nil)

        print("UpdateHierarchyItem completed")
    end
end

-- Recursive version that builds the tree structure
function UpdateHierarchyItemRecursive(itemIndex, serializable, parentItem)
    if serializable == nil then
        return itemIndex
    end

    -- Disable layout update for performance
    hierarchyList.contentElement:DisableLayoutUpdate()

    -- Determine item type
    local itemType = ITEM_NONE
    local typeName = serializable.typeName or serializable:GetTypeName()

    if typeName == "Scene" or typeName == "Node" then
        itemType = ITEM_NODE
    elseif serializable.GetNode ~= nil then  -- Has GetNode method = Component
        itemType = ITEM_COMPONENT
    end

    -- Create text item
    local text = Text()
    text:SetStyle("FileSelectorListText")

    -- Insert item into list
    if parentItem ~= nil then
        hierarchyList:InsertItem(itemIndex, text, parentItem)
    else
        hierarchyList:InsertItem(itemIndex, text)
    end

    -- Increment index for children
    itemIndex = itemIndex + 1

    -- Setup based on type
    if itemType == ITEM_NODE then
        local node = serializable

        -- Set text and color
        local nodeName = (node.name ~= "" and node.name or "Node")
        if typeName == "Scene" then
            nodeName = "Scene"
        end

        local nodeID = node:GetID()
        if showID then
            text.text = nodeName .. " [" .. tostring(nodeID) .. "]"
        else
            text.text = nodeName
        end
        text.color = nodeTextColor

        -- Add icon for node
        IconizeUIElement(text, typeName)
        SetIconEnabledColor(text, node.enabled)

        -- Store node info
        text:SetVar(NODE_ID_VAR, Variant(nodeID))
        text:SetVar(TYPE_VAR, Variant(ITEM_NODE))

        print("Added node: " .. text.text)

        -- Add components as children
        -- Note: Use GetComponent() with 0-based index
        local numComponents = tonumber(node:GetNumComponents()) or 0
        if numComponents > 0 then
            for i = 0, numComponents - 1 do
                local component = node:GetComponent(i)
                if component ~= nil then
                    if showTemporaryObject or not component.temporary then
                        AddComponentItem(itemIndex, component, text)
                        itemIndex = itemIndex + 1
                    end
                end
            end
        end

        -- Recursively add child nodes
        -- Note: Urho3D API uses 0-based indexing for GetChild()
        local numChildren = tonumber(node:GetNumChildren()) or 0
        if numChildren > 0 then
            for i = 0, numChildren - 1 do
                local childNode = node:GetChild(i)
                if childNode ~= nil then
                    if showTemporaryObject or not childNode.temporary then
                        itemIndex = UpdateHierarchyItemRecursive(itemIndex, childNode, text)
                    end
                end
            end
        end

    elseif itemType == ITEM_COMPONENT then
        local component = serializable

        -- Set text and color
        text.text = component.typeName or component:GetTypeName()
        text.color = componentTextColor

        -- Store component info
        local componentID = component:GetID()
        text:SetVar(COMPONENT_ID_VAR, Variant(componentID))
        text:SetVar(TYPE_VAR, Variant(ITEM_COMPONENT))
    end

    -- Enable layout update
    hierarchyList.contentElement:EnableLayoutUpdate()
    hierarchyList.contentElement:UpdateLayout()

    return itemIndex
end

-- Event handlers

-- Selection tracking
local inSelectionModify = false

-- Helper: Get node from list index
function GetListNode(index)
    local item = hierarchyList:GetItem(index)
    if item == nil then
        return nil
    end

    local nodeIDVar = item:GetVar(NODE_ID_VAR)
    if nodeIDVar:IsEmpty() then
        return nil
    end

    return editorScene:GetNode(nodeIDVar:GetUInt())
end

-- Helper: Get component from list index
function GetListComponent(index)
    local item = hierarchyList:GetItem(index)
    return GetListComponentFromItem(item)
end

-- Helper: Get component from item
function GetListComponentFromItem(item)
    if item == nil then
        return nil
    end

    local typeVar = item:GetVar(TYPE_VAR)
    if typeVar:IsEmpty() or typeVar:GetInt() ~= ITEM_COMPONENT then
        return nil
    end

    local componentIDVar = item:GetVar(COMPONENT_ID_VAR)
    if componentIDVar:IsEmpty() then
        return nil
    end

    return editorScene:GetComponent(componentIDVar:GetUInt())
end

function HandleHierarchyListSelectionChange(eventType, eventData)
    if inSelectionModify then
        return
    end

    -- Clear previous selections (matching AS version)
    selectedNodes = {}
    selectedComponents = {}
    selectedUIElements = {}

    -- Get all selected indices
    -- Try multiple methods to support different Lua binding implementations
    local indices = {}

    -- Method 1: Try accessing selections property (if it's a table)
    local success = pcall(function()
        local selections = hierarchyList.selections
        if selections ~= nil and type(selections) == "table" then
            for i = 1, #selections do
                table.insert(indices, selections[i])
            end
            print("DEBUG: Got " .. #indices .. " selections from .selections property")
        end
    end)

    -- Method 2: Try GetSelections() with different access patterns
    if #indices == 0 then
        success = pcall(function()
            local selectionsVector = hierarchyList:GetSelections()
            if selectionsVector ~= nil then
                -- Try table-like access
                if type(selectionsVector) == "table" then
                    for i = 1, #selectionsVector do
                        table.insert(indices, selectionsVector[i])
                    end
                    print("DEBUG: GetSelections() returned table with " .. #indices .. " items")
                -- Try userdata with Size() method
                elseif type(selectionsVector) == "userdata" and selectionsVector.Size then
                    local numSelections = selectionsVector:Size()
                    if numSelections > 0 then
                        for i = 0, numSelections - 1 do
                            table.insert(indices, selectionsVector:At(i))
                        end
                        print("DEBUG: GetSelections() userdata with " .. #indices .. " items")
                    end
                end
            end
        end)
    end

    -- Method 3: Fallback to single selection
    if #indices == 0 then
        local singleSel = hierarchyList.selection
        if singleSel ~= NO_ITEM then
            print("DEBUG: Fallback to single selection: " .. singleSel)
            table.insert(indices, singleSel)
        end
    end

    print("DEBUG: Total selections: " .. #indices)

    -- Process all selected items (matching AS logic)
    for i = 1, #indices do
        local index = indices[i]
        local item = hierarchyList:GetItem(index)

        if item ~= nil then
            local typeVar = item:GetVar(TYPE_VAR)
            if not typeVar:IsEmpty() then
                local itemType = typeVar:GetInt()

                if itemType == ITEM_COMPONENT then
                    local comp = GetListComponent(index)
                    if comp ~= nil then
                        table.insert(selectedComponents, comp)
                        print("DEBUG: Selected component: " .. comp:GetTypeName())
                    end
                elseif itemType == ITEM_NODE then
                    local node = GetListNode(index)
                    if node ~= nil then
                        table.insert(selectedNodes, node)
                        print("DEBUG: Selected node: " .. node.name .. " [" .. node:GetID() .. "]")
                    end
                elseif itemType == ITEM_UI_ELEMENT then
                    -- UI element support (for future)
                    print("DEBUG: UI element selected (not yet implemented)")
                end
            end
        end
    end

    print("DEBUG: After processing - Nodes: " .. #selectedNodes .. ", Components: " .. #selectedComponents)

    -- If only one node selected, use it for editing
    if #selectedNodes == 1 then
        editNode = selectedNodes[1]
    else
        editNode = nil
    end

    -- If selection contains only components, and they have a common node, use it for editing
    if #selectedNodes == 0 and #selectedComponents > 0 then
        local commonNode = nil
        for i = 1, #selectedComponents do
            if i == 1 then
                commonNode = selectedComponents[i].node
            else
                if selectedComponents[i].node ~= commonNode then
                    commonNode = nil
                    break
                end
            end
        end
        editNode = commonNode
        print("DEBUG: Components only - common node: " .. tostring(commonNode))
    end

    -- Now check if the component(s) can be edited
    if #selectedComponents > 0 then
        if editNode == nil then
            -- Must have same type
            local compType = selectedComponents[1]:GetType()
            local sameType = true
            for i = 2, #selectedComponents do
                if selectedComponents[i]:GetType() ~= compType then
                    sameType = false
                    break
                end
            end
            if sameType then
                editComponents = selectedComponents
                editComponent = selectedComponents[1]
                print("DEBUG: Components with same type - editing " .. #editComponents .. " components")
            else
                editComponents = {}
                editComponent = nil
                print("DEBUG: Components with different types - cannot edit")
            end
        else
            editComponents = selectedComponents
            editComponent = selectedComponents[1]
            numEditableComponentsPerNode = #selectedComponents
            print("DEBUG: Components with common node - editing " .. #editComponents .. " components")
        end
    else
        editComponents = {}
        editComponent = nil
    end

    -- If just nodes selected, and no components, show as many matching components for editing as possible
    -- (Matching AS logic at line 772-798)
    if #selectedNodes > 0 and #selectedComponents == 0 and selectedNodes[1]:GetNumComponents() > 0 then
        local count = 0
        for j = 0, selectedNodes[1]:GetNumComponents() - 1 do
            local comp = selectedNodes[1]:GetComponent(j)
            if comp ~= nil then
                local compType = comp:GetType()
                local sameType = true

                -- Check if other selected nodes have the same component type at the same index
                for i = 2, #selectedNodes do
                    if selectedNodes[i]:GetNumComponents() <= j then
                        sameType = false
                        break
                    end
                    local otherComp = selectedNodes[i]:GetComponent(j)
                    if otherComp == nil or otherComp:GetType() ~= compType then
                        sameType = false
                        break
                    end
                end

                -- If same type, add all nodes' components at this index to editComponents
                if sameType then
                    count = count + 1
                    for i = 1, #selectedNodes do
                        local nodeComp = selectedNodes[i]:GetComponent(j)
                        if nodeComp ~= nil then
                            table.insert(editComponents, nodeComp)
                        end
                    end
                end
            end
        end
        if count > 1 then
            numEditableComponentsPerNode = count
        end
        print("DEBUG: Auto-added " .. #editComponents .. " components from selected nodes")
    end

    -- Set editNodes (matching AS logic at line 800-810)
    if #selectedNodes == 0 and editNode ~= nil then
        editNodes = {editNode}
    else
        editNodes = selectedNodes

        -- Cannot multi-edit on scene and node(s) together
        if #editNodes > 1 and editNodes[1] == editorScene then
            table.remove(editNodes, 1)
            print("DEBUG: Removed scene from multi-edit")
        end
    end

    print("DEBUG: Final editNodes: " .. #editNodes .. ", editComponents: " .. #editComponents)

    -- Update UI
    UpdateAttributeInspector(true)
end

function HandleHierarchyItemClick()
    print("Hierarchy item clicked")
end

function HandleHierarchyListDoubleClick(eventType, eventData)
    -- Get the item that was double-clicked
    local item = eventData["Item"]:GetPtr()
    if item == nil then
        return
    end

    local itemType = item:GetVar(TYPE_VAR):GetInt()

    print("Double-clicked item type: " .. itemType)

    -- Handle node location (simplified - just print for now)
    if itemType == ITEM_NODE then
        local nodeID = item:GetVar(NODE_ID_VAR):GetUInt()
        local node = editorScene:GetNode(nodeID)
        if node ~= nil then
            print("Double-clicked node: " .. node.name .. " - TODO: Locate camera to node")
            -- TODO: Implement LocateNodes() to move camera to node
        end
    elseif itemType == ITEM_COMPONENT then
        print("Double-clicked component - TODO: Locate to component")
        -- TODO: Implement LocateComponents()
    end

    -- Toggle expand/collapse
    local selection = hierarchyList.selection
    if selection ~= NO_ITEM then
        local isExpanded = hierarchyList:IsExpanded(selection)

        -- Only expand if not already expanded and left mouse button
        local button = eventData["Button"]:GetInt()
        if not isExpanded and button == MOUSEB_LEFT then
            hierarchyList:ToggleExpand(selection)
            print("Toggled expand state")
        end
    end
end

-- Get list index by node/component object
function GetListIndex(serializable)
    if serializable == nil then
        return NO_ITEM
    end

    -- Determine if it's a node or component
    local nodeID = nil
    local componentID = nil

    if serializable.GetID ~= nil then
        local typeName = serializable:GetTypeName()
        if typeName == "Node" or typeName == "Scene" then
            nodeID = serializable:GetID()
        elseif serializable.GetNode ~= nil then
            -- It's a component
            componentID = serializable:GetID()
        end
    end

    -- Search through list items
    local numItems = hierarchyList.numItems
    for i = 0, numItems - 1 do
        local item = hierarchyList:GetItem(i)
        if item ~= nil then
            local typeVar = item:GetVar(TYPE_VAR)
            if not typeVar:IsEmpty() then
                local itemType = typeVar:GetInt()

                if itemType == ITEM_NODE and nodeID ~= nil then
                    local itemNodeID = item:GetVar(NODE_ID_VAR)
                    if not itemNodeID:IsEmpty() and itemNodeID:GetUInt() == nodeID then
                        return i
                    end
                elseif itemType == ITEM_COMPONENT and componentID ~= nil then
                    local itemCompID = item:GetVar(COMPONENT_ID_VAR)
                    if not itemCompID:IsEmpty() and itemCompID:GetUInt() == componentID then
                        return i
                    end
                end
            end
        end
    end

    return NO_ITEM
end

-- Get list index by component
function GetComponentListIndex(component)
    if component == nil then
        return NO_ITEM
    end
    return GetListIndex(component)
end

-- Update hierarchy item text and icon color
function UpdateHierarchyItemText(itemIndex, iconEnabled, textTitle)
    if itemIndex == NO_ITEM then
        return
    end

    local text = hierarchyList:GetItem(itemIndex)
    if text == nil then
        return
    end

    -- Update icon color based on enabled state
    if iconEnabled then
        text.color = Color(1.0, 1.0, 1.0)
    else
        text.color = Color(0.5, 0.5, 0.5)
    end

    -- Update text if provided
    if textTitle ~= nil and textTitle ~= NO_CHANGE then
        text.text = textTitle
    end
end

-- Event handlers

function HandleComponentAdded(eventType, eventData)
    if suppressSceneChanges then
        return
    end

    -- Insert the newly added component at last component position
    -- but before the first child node position of the parent node
    local node = eventData["Node"]:GetPtr()
    local component = eventData["Component"]:GetPtr()

    if node == nil or component == nil then
        return
    end

    if showTemporaryObject or (not node.temporary and not component.temporary) then
        local nodeIndex = GetListIndex(node)
        if nodeIndex ~= NO_ITEM then
            -- Find the insertion point (before first child node)
            local insertIndex = nodeIndex + 1
            local numChildren = node:GetNumChildren()

            -- Calculate index: after all existing components, before children
            local numComponents = node:GetNumComponents()
            insertIndex = nodeIndex + numComponents

            -- Add the component item
            local nodeItem = hierarchyList:GetItem(nodeIndex)
            AddComponentItem(insertIndex, component, nodeItem)

            print("Component added: " .. component:GetTypeName() .. " at index " .. insertIndex)
        end
    end
end

function HandleComponentRemoved(eventType, eventData)
    if suppressSceneChanges then
        return
    end

    local node = eventData["Node"]:GetPtr()
    local component = eventData["Component"]:GetPtr()

    if node == nil or component == nil then
        return
    end

    if showTemporaryObject or (not node.temporary and not component.temporary) then
        local index = GetComponentListIndex(component)
        if index ~= NO_ITEM then
            hierarchyList:RemoveItem(index)
            print("Component removed: " .. component:GetTypeName() .. " from index " .. index)
        end
    end
end

function HandleNodeEnabledChanged(eventType, eventData)
    if suppressSceneChanges then
        return
    end

    local node = eventData["Node"]:GetPtr()
    if node == nil then
        return
    end

    if showTemporaryObject or not node.temporary then
        local index = GetListIndex(node)
        UpdateHierarchyItemText(index, node.enabled)
        -- Mark attributes as dirty to refresh inspector
        if UpdateAttributeInspector then
            UpdateAttributeInspector(false)
        end
    end
end

function HandleComponentEnabledChanged(eventType, eventData)
    if suppressSceneChanges then
        return
    end

    local node = eventData["Node"]:GetPtr()
    local component = eventData["Component"]:GetPtr()

    if node == nil or component == nil then
        return
    end

    if showTemporaryObject or (not node.temporary and not component.temporary) then
        local index = GetComponentListIndex(component)
        UpdateHierarchyItemText(index, component.enabledEffective)
        -- Mark attributes as dirty to refresh inspector
        if UpdateAttributeInspector then
            UpdateAttributeInspector(false)
        end
    end
end

function HandleTemporaryChanged(eventType, eventData)
    if suppressSceneChanges then
        return
    end

    -- Get the serializable object that sent the event
    local serializable = eventData["Serializable"]:GetPtr()
    if serializable == nil then
        return
    end

    -- Check if it's a node
    local typeName = serializable:GetTypeName()
    if typeName == "Node" or typeName == "Scene" then
        local node = tolua.cast(serializable, "Node")
        if node ~= nil and node.scene == editorScene then
            if showTemporaryObject then
                local index = GetListIndex(node)
                UpdateHierarchyItemText(index, node.enabled)
            elseif not node.temporary and GetListIndex(node) == NO_ITEM then
                UpdateHierarchyItem(node, false)
            elseif node.temporary then
                local index = GetListIndex(node)
                if index ~= NO_ITEM then
                    hierarchyList:RemoveItem(index)
                end
            end
        end
    end
end

function HandleShowID(eventType, eventData)
    local checkBox = eventData["Element"]:GetPtr()
    if checkBox ~= nil then
        showID = checkBox.checked
        UpdateHierarchyItem(editorScene, true)
    end
end

-- Expand/Collapse functionality
function ExpandCollapseHierarchy(eventType, eventData)
    local button = eventData["Element"]:GetPtr()
    if button == nil then
        return
    end

    local enable = (button.name == "ExpandButton")

    -- Get selections
    local indices = {}
    local singleSel = hierarchyList.selection
    if singleSel ~= NO_ITEM then
        table.insert(indices, singleSel)
    end

    -- Expand or collapse all selected items
    for i = 1, #indices do
        hierarchyList:Expand(indices[i], enable, false)
    end
end

function CollapseHierarchy(eventType, eventData)
    -- Collapse all items
    local numItems = hierarchyList.numItems
    for i = 0, numItems - 1 do
        hierarchyList:Expand(i, false, true)
    end

    -- Expand only the root (scene)
    if numItems > 0 then
        hierarchyList:Expand(0, true, false)
    end
end

-- Drag & drop handlers (basic stubs for now)
function HandleDragDropTest(eventType, eventData)
    -- TODO: Implement drag & drop testing
    -- This requires resource browser integration
    eventData["Accept"] = false
end

function HandleDragDropFinish(eventType, eventData)
    -- TODO: Implement drag & drop finish
    -- This requires resource browser integration
    eventData["Accept"] = false
end

-- Stub for editorUIElement
editorUIElement = nil
uiElementCopyBuffer = {}

-- UIElement support variables
local MODIFIED_VAR = StringHash("Modified")

-- Get or assign UIElement ID
function GetUIElementID(element)
    local elementID = element:GetVar(UI_ELEMENT_ID_VAR)
    if elementID:IsEmpty() then
        -- Generate new ID
        elementID = Variant(uiElementNextID)
        uiElementNextID = uiElementNextID + 1
        -- Store the generated ID
        element:SetVar(UI_ELEMENT_ID_VAR, elementID)
    end
    return elementID
end

-- Get UIElement title for display
function GetUIElementTitle(element)
    local modifiedStr = ""
    local modifiedVar = element:GetVar(MODIFIED_VAR)
    if not modifiedVar:IsEmpty() and modifiedVar:GetBool() then
        modifiedStr = "*"
    end

    local name = element.name
    if name == "" then
        name = element.typeName
    end

    local ret = name .. modifiedStr .. " [" .. tostring(GetUIElementID(element):GetUInt()) .. "]"

    if element.temporary then
        ret = ret .. " (Temp)"
    end

    return ret
end

-- Handle UI element added event
function HandleUIElementAdded(eventType, eventData)
    if suppressUIElementChanges then
        return
    end

    local element = eventData["Element"]:GetPtr()
    if (showInternalUIElement or not element.internal) and (showTemporaryObject or not element.temporary) then
        UpdateHierarchyItem(element, false)
    end
end

-- Handle UI element removed event
function HandleUIElementRemoved(eventType, eventData)
    if suppressUIElementChanges then
        return
    end

    local element = eventData["Element"]:GetPtr()
    local index = GetListIndex(element)
    if index ~= NO_ITEM then
        hierarchyList:RemoveItem(index)
    end
end

-- Helper function to get component title
function GetComponentTitle(component)
    local title = component.typeName or component:GetTypeName()

    if showID then
        if not component.replicated then
            title = title .. " (Local)"
        end
        if component.temporary then
            title = title .. " (Temp)"
        end
    end

    return title
end

-- Add a component item to the hierarchy
function AddComponentItem(itemIndex, component, parentItem)
    local text = Text()
    text:SetStyle("FileSelectorListText")

    -- 调试：检查InsertItem是否成功
    hierarchyList:InsertItem(itemIndex, text, parentItem)

    -- 验证item是否正确添加
    local addedItem = hierarchyList:GetItem(itemIndex)
    if addedItem == text then
        print("  Component item added successfully at index " .. itemIndex)
    else
        print("  ERROR: Component item NOT added correctly! Expected " .. tostring(text) .. ", got " .. tostring(addedItem))
    end

    text:SetVar(TYPE_VAR, Variant(ITEM_COMPONENT))
    text:SetVar(NODE_ID_VAR, Variant(component.node:GetID()))
    text:SetVar(COMPONENT_ID_VAR, Variant(component:GetID()))

    text.text = GetComponentTitle(component)
    text.color = componentTextColor
    text.dragDropMode = DD_SOURCE_AND_TARGET

    -- Add icon for component
    local componentTypeName = component.typeName or component:GetTypeName()
    IconizeUIElement(text, componentTypeName)
    SetIconEnabledColor(text, component.enabledEffective)

    print("  Added component: " .. text.text)

    return itemIndex
end
