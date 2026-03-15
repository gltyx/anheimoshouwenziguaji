--[[
  EditorUIElement.lua - Urho3D editor UI-element handling

  This module provides functionality for:
  - Creating, opening, and managing UI elements in the editor
  - Loading and saving UI layouts
  - UI element selection, copy, paste, cut, delete operations
  - UI element hierarchy management
  - Style management for UI elements

  Converted from Scripts/Editor/EditorUIElement.as
--]]

-- Module variables
editorUIElement = nil
uiElementDefaultStyle = nil
availableStyles = {}

editUIElement = nil
selectedUIElements = {}
editUIElements = {}

uiElementCopyBuffer = {}

suppressUIElementChanges = false

-- StringHash constants converted to strings
local FILENAME_VAR = "FileName"
local MODIFIED_VAR = "Modified"
local CHILD_ELEMENT_FILENAME_VAR = "ChildElemFileName"

-- Clear UI element selection
function ClearUIElementSelection()
    editUIElement = nil
    selectedUIElements = {}
    editUIElements = {}
end

-- Create the root UI element for the editor
function CreateRootUIElement()
    -- Create a root UIElement only once here, do not confuse this with ui.root itself
    editorUIElement = ui.root:CreateChild("UIElement")
    editorUIElement.name = "UI"
    editorUIElement:SetSize(graphics.width, graphics.height)
    editorUIElement.traversalMode = TM_DEPTH_FIRST  -- This is needed for root-like element to prevent artifacts
    editorUIElement.priority = -1000  -- All user-created UI elements have lowest priority so they do not cover editor's windows

    -- This is needed to distinguish our own element events from Editor's UI element events
    editorUIElement.elementEventSender = true
    SubscribeToEvent(editorUIElement, "ElementAdded", "HandleUIElementAdded")
    SubscribeToEvent(editorUIElement, "ElementRemoved", "HandleUIElementRemoved")

    -- Since this root UIElement is not being handled by above handlers, update it into hierarchy list manually as another list root item
    UpdateHierarchyItem(M_MAX_UNSIGNED, editorUIElement, nil)
end

-- Create a new UI element
function NewUIElement(typeName)
    -- If no edit element then parented to root
    local parent = editUIElement ~= nil and editUIElement or editorUIElement
    local element = parent:CreateChild(typeName)

    if element ~= nil then
        -- Use the predefined UI style if set, otherwise use editor's own UI style
        local defaultStyle = uiElementDefaultStyle ~= nil and uiElementDefaultStyle or uiStyle

        if editUIElement == nil then
            -- If parented to root, set the internal variables
            element.vars[FILENAME_VAR] = ""
            element.vars[MODIFIED_VAR] = false
            -- set a default UI style
            element.defaultStyle = defaultStyle
            -- and position the newly created element at center
            CenterDialog(element)
        end

        -- Apply the auto style
        element.style = AUTO_STYLE
        -- Do not allow UI subsystem to reorder children while editing the element in the editor
        element.sortChildren = false

        -- Create an undo action for the create
        local action = CreateUIElementAction:new()
        action:Define(element)
        SaveEditAction(action)
        SetUIElementModified(element)

        FocusUIElement(element)
    end

    return true
end

-- Reset sortChildren flag recursively
function ResetSortChildren(element)
    element.sortChildren = false

    -- Perform the action recursively for child elements
    for i = 0, element.numChildren - 1 do
        ResetSortChildren(element.children[i])
    end
end

-- Open a UI layout from file
function OpenUILayout(fileName)
    if fileName == "" then
        return
    end

    ui.cursor.shape = CS_BUSY

    -- Check if the UI element has been opened before
    if editorUIElement:GetChild(FILENAME_VAR, Variant(fileName)) ~= nil then
        MessageBox("UI element is already opened.\n" .. fileName)
        return
    end

    -- Always load from the filesystem, not from resource paths
    if not fileSystem:FileExists(fileName) then
        MessageBox("No such file.\n" .. fileName)
        return
    end

    local file = File(fileName, FILE_READ)
    if not file.open then
        MessageBox("Could not open file.\n" .. fileName)
        return
    end

    -- Add the UI layout's resource path in case it's necessary
    SetResourcePath(GetPath(fileName), true, true)

    local xmlFile = XMLFile()
    xmlFile:Load(file)

    suppressUIElementChanges = true

    -- If uiElementDefaultStyle is not set then automatically fallback to use the editor's own default style
    local element = ui:LoadLayout(xmlFile, uiElementDefaultStyle)
    if element ~= nil then
        element.vars[FILENAME_VAR] = fileName
        element.vars[MODIFIED_VAR] = false

        -- Do not allow UI subsystem to reorder children while editing the element in the editor
        ResetSortChildren(element)
        -- Register variable names from the 'enriched' XMLElement, if any
        RegisterUIElementVar(xmlFile.root)

        editorUIElement:AddChild(element)

        UpdateHierarchyItem(element)
        FocusUIElement(element)

        ClearEditActions()
    else
        MessageBox("Could not load UI layout successfully!\nSee Urho3D.log for more detail.")
    end

    suppressUIElementChanges = false
end

-- Close the current UI layout
function CloseUILayout()
    ui.cursor.shape = CS_BUSY

    if messageBoxCallback == nil then
        for i = 1, #selectedUIElements do
            local element = GetTopLevelUIElement(selectedUIElements[i])
            if element ~= nil and element.vars[MODIFIED_VAR]:GetBool() then
                local messageBox = MessageBox("UI layout has been modified.\nContinue to close?", "Warning")
                if messageBox.window ~= nil then
                    local cancelButton = messageBox.window:GetChild("CancelButton", true)
                    cancelButton.visible = true
                    cancelButton.focus = true
                    SubscribeToEvent(messageBox, "MessageACK", "HandleMessageAcknowledgement")
                    messageBoxCallback = CloseUILayout
                    return false
                end
            end
        end
    else
        messageBoxCallback = nil
    end

    suppressUIElementChanges = true

    for i = 1, #selectedUIElements do
        local element = GetTopLevelUIElement(selectedUIElements[i])
        if element ~= nil then
            element:Remove()
            UpdateHierarchyItem(GetListIndex(element), nil, nil)
        end
    end
    hierarchyList:ClearSelection()
    ClearEditActions()

    suppressUIElementChanges = false

    return true
end

-- Close all UI layouts
function CloseAllUILayouts()
    ui.cursor.shape = CS_BUSY

    if messageBoxCallback == nil then
        for i = 0, editorUIElement.numChildren - 1 do
            local element = editorUIElement.children[i]
            if element ~= nil and element.vars[MODIFIED_VAR]:GetBool() then
                local messageBox = MessageBox("UI layout has been modified.\nContinue to close?", "Warning")
                if messageBox.window ~= nil then
                    local cancelButton = messageBox.window:GetChild("CancelButton", true)
                    cancelButton.visible = true
                    cancelButton.focus = true
                    SubscribeToEvent(messageBox, "MessageACK", "HandleMessageAcknowledgement")
                    messageBoxCallback = CloseAllUILayouts
                    return false
                end
            end
        end
    else
        messageBoxCallback = nil
    end

    suppressUIElementChanges = true

    editorUIElement:RemoveAllChildren()
    UpdateHierarchyItem(editorUIElement, true)

    -- Reset element ID number generator
    uiElementNextID = UI_ELEMENT_BASE_ID + 1

    hierarchyList:ClearSelection()
    ClearEditActions()

    suppressUIElementChanges = false

    return true
end

-- Save UI layout to file
function SaveUILayout(fileName)
    if fileName == "" then
        return false
    end

    ui.cursor.shape = CS_BUSY

    MakeBackup(fileName)
    local file = File(fileName, FILE_WRITE)
    if not file.open then
        MessageBox("Could not open file.\n" .. fileName)
        return false
    end

    local element = GetTopLevelUIElement(editUIElement)
    if element == nil then
        return false
    end

    local elementData = XMLFile()
    local rootElem = elementData:CreateRoot("element")
    local success = element:SaveXML(rootElem)
    RemoveBackup(success, fileName)

    if success then
        FilterInternalVars(rootElem)
        success = elementData:Save(file)
        if success then
            element.vars[FILENAME_VAR] = fileName
            SetUIElementModified(element, false)
        end
    end

    if not success then
        MessageBox("Could not save UI layout successfully!\nSee Urho3D.log for more detail.")
    end

    return success
end

-- Save UI layout with existing filename
function SaveUILayoutWithExistingName()
    ui.cursor.shape = CS_BUSY

    local element = GetTopLevelUIElement(editUIElement)
    if element == nil then
        return false
    end

    local fileName = element:GetVar(FILENAME_VAR):GetString()
    if fileName == "" then
        return PickFile()  -- No name yet, so pick one
    else
        return SaveUILayout(fileName)
    end
end

-- Load a child UI element from file
function LoadChildUIElement(fileName)
    if fileName == "" then
        return
    end

    ui.cursor.shape = CS_BUSY

    if not fileSystem:FileExists(fileName) then
        MessageBox("No such file.\n" .. fileName)
        return
    end

    local file = File(fileName, FILE_READ)
    if not file.open then
        MessageBox("Could not open file.\n" .. fileName)
        return
    end

    local xmlFile = XMLFile()
    xmlFile:Load(file)

    suppressUIElementChanges = true

    if editUIElement:LoadChildXML(xmlFile, uiElementDefaultStyle ~= nil and uiElementDefaultStyle or uiStyle) ~= nil then
        local rootElem = xmlFile.root
        local index = rootElem:HasAttribute("index") and rootElem:GetUInt("index") or (editUIElement.numChildren - 1)
        local element = editUIElement.children[index]
        ResetSortChildren(element)
        RegisterUIElementVar(xmlFile.root)
        element.vars[CHILD_ELEMENT_FILENAME_VAR] = fileName

        if index == editUIElement.numChildren - 1 then
            UpdateHierarchyItem(element)
        else
            -- If not last child, find the list index of the next sibling as the insertion index
            UpdateHierarchyItem(GetListIndex(editUIElement.children[index + 1]), element, hierarchyList.items[GetListIndex(editUIElement)])
        end

        SetUIElementModified(element)

        -- Create an undo action for the load
        local action = CreateUIElementAction:new()
        action:Define(element)
        SaveEditAction(action)

        FocusUIElement(element)
    end

    suppressUIElementChanges = false
end

-- Save child UI element to file
function SaveChildUIElement(fileName)
    if fileName == "" then
        return false
    end

    ui.cursor.shape = CS_BUSY

    MakeBackup(fileName)
    local file = File(fileName, FILE_WRITE)
    if not file.open then
        MessageBox("Could not open file.\n" .. fileName)
        return false
    end

    local elementData = XMLFile()
    local rootElem = elementData:CreateRoot("element")
    local success = editUIElement:SaveXML(rootElem)
    RemoveBackup(success, fileName)

    if success then
        FilterInternalVars(rootElem)
        success = elementData:Save(file)
        if success then
            editUIElement.vars[CHILD_ELEMENT_FILENAME_VAR] = fileName
        end
    end

    if not success then
        MessageBox("Could not save child UI element successfully!\nSee Urho3D.log for more detail.")
    end

    return success
end

-- Set the default UI style file
function SetUIElementDefaultStyle(fileName)
    if fileName == "" then
        return
    end

    ui.cursor.shape = CS_BUSY

    -- Always load from the filesystem, not from resource paths
    if not fileSystem:FileExists(fileName) then
        MessageBox("No such file.\n" .. fileName)
        return
    end

    local file = File(fileName, FILE_READ)
    if not file.open then
        MessageBox("Could not open file.\n" .. fileName)
        return
    end

    uiElementDefaultStyle = XMLFile()
    uiElementDefaultStyle:Load(file)

    -- Remove the existing style list to ensure it gets repopulated again with the new default style file
    availableStyles = {}

    -- Refresh Attribute Inspector when it is currently showing attributes of UI-element item type as the existing styles in the style drop down list are not valid anymore
    if #editUIElements > 0 then
        attributesFullDirty = true
    end
end

-- XPathQuery stub (Lua binding may not have this class, using alternative method)
local function CreateXPathQuery(query)
    return {
        query = query,
        Evaluate = function(self, xmlElement)
            -- Use XMLElement's SelectMultiple method as alternative
            local results = xmlElement:SelectMultiple(self.query)
            return {
                firstResult = (results and #results > 0) and results[1] or nil,
                results = results or {}
            }
        end
    }
end

-- Prepare XPath query object only once and use it multiple times
local filterInternalVarsQuery = CreateXPathQuery("//attribute[@name='Variables']/variant")

-- Filter internal variables from XML element
function FilterInternalVars(source)
    local resultSet = filterInternalVarsQuery:Evaluate(source)
    local resultElem = resultSet.firstResult

    while resultElem:NotNull() do
        local name = GetVarName(resultElem:GetUInt("hash"))
        if name == "" then
            local parent = resultElem.parent

            -- If variable name is empty (or unregistered) then it is an internal variable and should be removed
            if parent:RemoveChild(resultElem) then
                -- If parent does not have any children anymore then remove the parent also
                if not parent:HasChild("variant") then
                    parent.parent:RemoveChild(parent)
                end
            end
        else
            -- If it is registered then it is a user-defined variable, so 'enrich' the XMLElement to store the variable name in plaintext
            resultElem:SetAttribute("name", name)
        end

        resultElem = resultElem.nextResult
    end
end

-- XPath query for registering UI element variables
local registerUIElemenVarsQuery = CreateXPathQuery("//attribute[@name='Variables']/variant/@name")

-- Register UI element variable names
function RegisterUIElementVar(source)
    local resultSet = registerUIElemenVarsQuery:Evaluate(source)
    local resultAttr = resultSet.firstResult  -- Since we are selecting attribute, the resultset is in attribute context

    while resultAttr:NotNull() do
        local name = resultAttr:GetAttribute()
        globalVarNames[name] = name
        resultAttr = resultAttr.nextResult
    end
end

-- Get the top level UI element (one that contains FILENAME_VAR)
function GetTopLevelUIElement(element)
    -- Only top level UI-element contains the FILENAME_VAR
    while element ~= nil and not element.vars:Contains(FILENAME_VAR) do
        element = element.parent
    end
    return element
end

-- Set the modified flag for a UI element
function SetUIElementModified(element, flag)
    if flag == nil then
        flag = true
    end

    element = GetTopLevelUIElement(element)
    if element ~= nil and element:GetVar(MODIFIED_VAR):GetBool() ~= flag then
        element.vars[MODIFIED_VAR] = flag
        UpdateHierarchyItemText(GetListIndex(element), element.visible, GetUIElementTitle(element))
    end
end

-- XPath query for getting available styles
local availableStylesXPathQuery = CreateXPathQuery("/elements/element[@auto='false']/@type")

-- Get available styles from default style file
function GetAvailableStyles()
    -- Use the predefined UI style if set, otherwise use editor's own UI style
    local defaultStyle = uiElementDefaultStyle ~= nil and uiElementDefaultStyle or uiStyle
    local rootElem = defaultStyle.root
    local resultSet = availableStylesXPathQuery:Evaluate(rootElem)
    local resultElem = resultSet.firstResult

    while resultElem:NotNull() do
        table.insert(availableStyles, resultElem:GetAttribute())
        resultElem = resultElem.nextResult
    end

    table.sort(availableStyles)
end

-- Populate the style dropdown list
function PopulateStyleList(styleList)
    if #availableStyles == 0 then
        GetAvailableStyles()
    end

    for i = 1, #availableStyles do
        local choice = Text()
        styleList:AddItem(choice)
        choice.style = "EditorEnumAttributeText"
        choice.text = availableStyles[i]
    end
end

-- Cut UI elements (copy + delete)
function UIElementCut()
    return UIElementCopy() and UIElementDelete()
end

-- Copy UI elements to clipboard
function UIElementCopy()
    ui.cursor.shape = CS_BUSY

    uiElementCopyBuffer = {}

    for i = 1, #selectedUIElements do
        local xml = XMLFile()
        local rootElem = xml:CreateRoot("element")
        selectedUIElements[i]:SaveXML(rootElem)
        table.insert(uiElementCopyBuffer, xml)
    end

    return true
end

-- Reset duplicate element IDs recursively
function ResetDuplicateID(element)
    -- If it is a duplicate copy then the element ID need to be regenerated by resetting it now to empty
    if GetListIndex(element) ~= NO_ITEM then
        element.vars[UI_ELEMENT_ID_VAR] = Variant()
    end

    -- Perform the action recursively for child elements
    for i = 0, element.numChildren - 1 do
        ResetDuplicateID(element.children[i])
    end
end

-- Paste UI elements from clipboard
function UIElementPaste(duplication)
    if duplication == nil then
        duplication = false
    end

    ui.cursor.shape = CS_BUSY

    -- Group for storing undo actions
    local group = EditActionGroup:new()

    -- Have to update manually because the element ID var is not set yet when the E_ELEMENTADDED event is sent
    suppressUIElementChanges = true

    for i = 1, #uiElementCopyBuffer do
        local rootElem = uiElementCopyBuffer[i].root

        local pasteElement

        if not duplication then
            pasteElement = editUIElement
        else
            if editUIElement.parent ~= nil then
                pasteElement = editUIElement.parent
            else
                pasteElement = editUIElement
            end
        end

        if pasteElement:LoadChildXML(rootElem, nil) ~= nil then
            local element = pasteElement.children[pasteElement.numChildren - 1]

            ResetDuplicateID(element)
            UpdateHierarchyItem(element)
            SetUIElementModified(pasteElement)

            -- Create an undo action
            local action = CreateUIElementAction:new()
            action:Define(element)
            table.insert(group.actions, action)
        end
    end

    SaveEditActionGroup(group)

    suppressUIElementChanges = false

    return true
end

-- Duplicate UI elements
function UIElementDuplicate()
    ui.cursor.shape = CS_BUSY

    -- Save current copy buffer
    local copy = {}
    for i = 1, #uiElementCopyBuffer do
        copy[i] = uiElementCopyBuffer[i]
    end

    UIElementCopy()
    UIElementPaste(true)

    -- Restore copy buffer
    uiElementCopyBuffer = copy

    return true
end

-- Delete selected UI elements
function UIElementDelete()
    ui.cursor.shape = CS_BUSY

    BeginSelectionModify()

    -- Clear the selection now to prevent deleted elements from being reselected
    hierarchyList:ClearSelection()

    -- Group for storing undo actions
    local group = EditActionGroup:new()

    for i = 1, #selectedUIElements do
        local element = selectedUIElements[i]
        if element.parent ~= nil then  -- Not already deleted
            local index = GetListIndex(element)

            -- Create undo action
            local action = DeleteUIElementAction:new()
            action:Define(element)
            table.insert(group.actions, action)

            SetUIElementModified(element)
            element:Remove()

            -- If deleting only one element, select the next item in the same index
            if #selectedUIElements == 1 then
                hierarchyList.selection = index
            end
        end
    end

    SaveEditActionGroup(group)

    EndSelectionModify()
    return true
end

-- Select all UI elements
function UIElementSelectAll()
    BeginSelectionModify()
    local indices = {}
    local baseIndex = GetListIndex(editorUIElement)
    table.insert(indices, baseIndex)
    local baseIndent = hierarchyList.items[baseIndex].indent

    for i = baseIndex + 1, hierarchyList.numItems - 1 do
        if hierarchyList.items[i].indent <= baseIndent then
            break
        end
        table.insert(indices, i)
    end

    hierarchyList:SetSelections(indices)
    EndSelectionModify()

    return true
end

-- Reset selected UI elements to default values
function UIElementResetToDefault()
    ui.cursor.shape = CS_BUSY

    -- Group for storing undo actions
    local group = EditActionGroup:new()

    -- Reset selected elements to their default values
    for i = 1, #selectedUIElements do
        local element = selectedUIElements[i]

        local action = ResetAttributesAction:new()
        action:Define(element)
        table.insert(group.actions, action)

        element:ResetToDefault()
        action:SetInternalVars(element)
        element:ApplyAttributes()

        for j = 0, element.numAttributes - 1 do
            PostEditAttribute(element, j)
        end

        SetUIElementModified(element)
    end

    SaveEditActionGroup(group)
    attributesFullDirty = true

    return true
end

-- Change the parent of a UI element
function UIElementChangeParent(sourceElement, targetElement)
    local action = ReparentUIElementAction:new()
    action:Define(sourceElement, targetElement)
    SaveEditAction(action)

    sourceElement.parent = targetElement
    SetUIElementModified(targetElement)
    return sourceElement.parent == targetElement
end

-- Reorder UI element within parent
function UIElementReorder(sourceElement, targetElement)
    if sourceElement == nil or targetElement == nil or sourceElement.parent == nil or sourceElement.parent ~= targetElement.parent then
        return false
    end

    if sourceElement == targetElement then
        return true  -- No-op
    end

    local parent = sourceElement.parent
    local destIndex = parent:FindChild(targetElement)
    Print("Reorder to dest index " .. destIndex)

    local action = ReorderUIElementAction:new()
    action:Define(sourceElement, destIndex)
    SaveEditAction(action)
    PerformReorder(parent, sourceElement, destIndex)

    return true
end

-- Perform the reorder operation
function PerformReorder(parent, child, destIndex)
    suppressSceneChanges = true

    parent:RemoveChild(child)
    parent:InsertChild(destIndex, child)
    UpdateHierarchyItem(parent)  -- Force update to make sure the order is current
    SetUIElementModified(parent)

    suppressSceneChanges = false
end
