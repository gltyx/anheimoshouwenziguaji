-- EditorInspectorWindow.lua - Manually rewritten from AS
-- Minimal viable version - displays basic node/component info
-- Full AttributeEditor implementation pending

-- Global variables
attributeInspectorWindow = nil
parentContainer = nil
inspectorLockButton = nil
applyMaterialList = true
attributesDirty = false
attributesFullDirty = false
inspectorLocked = false

-- Constants
local STRIKED_OUT = "——"  -- Two unicode EM DASH
local NODE_IDS_VAR = StringHash("NodeIDs")
local COMPONENT_IDS_VAR = StringHash("ComponentIDs")
local LABEL_WIDTH = 30

-- Create the attribute inspector window
function CreateAttributeInspectorWindow()
    if attributeInspectorWindow ~= nil then
        return
    end

    print("CreateAttributeInspectorWindow: Loading XML...")

    -- Load window from XML
    attributeInspectorWindow = LoadEditorUI("UI/EditorInspectorWindow.xml")
    if attributeInspectorWindow == nil then
        print("ERROR: Failed to load EditorInspectorWindow.xml")
        return
    end

    parentContainer = attributeInspectorWindow:GetChild("ParentContainer", true)
    if parentContainer == nil then
        print("ERROR: ParentContainer not found")
        return
    end

    ui.root:AddChild(attributeInspectorWindow)

    local height = Min(ui.root.height - 60, 500)
    attributeInspectorWindow:SetSize(344, height)
    -- Position on right side
    attributeInspectorWindow:SetPosition(ui.root.width - 10 - attributeInspectorWindow.width, 100)
    attributeInspectorWindow.opacity = uiMaxOpacity
    attributeInspectorWindow:BringToFront()

    inspectorLockButton = attributeInspectorWindow:GetChild("LockButton", true)

    print("CreateAttributeInspectorWindow: Created")

    UpdateAttributeInspector()

    -- Subscribe to events
    if inspectorLockButton ~= nil then
        SubscribeToEvent(inspectorLockButton, "Pressed", "ToggleInspectorLock")
    end

    local closeButton = attributeInspectorWindow:GetChild("CloseButton", true)
    if closeButton ~= nil then
        SubscribeToEvent(closeButton, "Pressed", "HideAttributeInspectorWindow")
    end
end

-- Helper: Convert node array to serializable array
function ToSerializableArray(nodes)
    local serializables = {}
    if nodes == nil then
        return serializables
    end
    for i = 1, #nodes do
        table.insert(serializables, nodes[i])
    end
    return serializables
end

-- Update attribute inspector to show selected objects
function UpdateAttributeInspector(fullUpdate)
    fullUpdate = fullUpdate or false

    if attributeInspectorWindow == nil or parentContainer == nil then
        return
    end

    if inspectorLocked then
        return
    end

    attributesDirty = false
    if fullUpdate then
        attributesFullDirty = false
    end

    -- If full update, clear all content
    if fullUpdate then
        parentContainer:RemoveAllChildren()
    end

    -- Show attribute editor for selected nodes and/or components
    if editNodes ~= nil and #editNodes > 0 then
        -- Create or get node attribute list
        local nodeAttributeList = parentContainer:GetChild("NodeAttributeList", true)
        if nodeAttributeList == nil then
            nodeAttributeList = ListView:new()
            nodeAttributeList.name = "NodeAttributeList"
            nodeAttributeList:SetStyleAuto()
            nodeAttributeList:SetFixedHeight(200)
            parentContainer:AddChild(nodeAttributeList)
        end

        -- Convert nodes to serializables
        local serializables = ToSerializableArray(editNodes)

        -- Call UpdateAttributes from AttributeEditor for nodes
        if UpdateAttributes then
            UpdateAttributes(serializables, nodeAttributeList, fullUpdate)
        end

        -- 如果也有Components，显示Components的属性
        if editComponents ~= nil and #editComponents > 0 then
            local compAttributeList = parentContainer:GetChild("CompAttributeList", true)
            if compAttributeList == nil then
                compAttributeList = ListView:new()
                compAttributeList.name = "CompAttributeList"
                compAttributeList:SetStyleAuto()
                compAttributeList:SetFixedHeight(200)
                parentContainer:AddChild(compAttributeList)
            end

            local compSerializables = {}
            for i = 1, #editComponents do
                table.insert(compSerializables, editComponents[i])
            end

            if UpdateAttributes then
                UpdateAttributes(compSerializables, compAttributeList, fullUpdate)
            end
        end
    elseif editNode ~= nil then
        -- Single node selected
        local attributeList = parentContainer:GetChild("AttributeList", true)
        if attributeList == nil then
            attributeList = ListView:new()
            attributeList.name = "AttributeList"
            attributeList:SetStyleAuto()
            attributeList:SetFixedHeight(400)
            parentContainer:AddChild(attributeList)
        end

        local serializables = {editNode}
        if UpdateAttributes then
            UpdateAttributes(serializables, attributeList, fullUpdate)
            print("UpdateAttributeInspector: Updated single node")
        end
    elseif editComponents ~= nil and #editComponents > 0 then
        -- Components selected
        local attributeList = parentContainer:GetChild("AttributeList", true)
        if attributeList == nil then
            attributeList = ListView:new()
            attributeList.name = "AttributeList"
            attributeList:SetStyleAuto()
            attributeList:SetFixedHeight(400)
            parentContainer:AddChild(attributeList)
        end

        -- Convert components to serializables
        local serializables = {}
        for i = 1, #editComponents do
            table.insert(serializables, editComponents[i])
        end

        -- Call UpdateAttributes from AttributeEditor
        if UpdateAttributes then
            UpdateAttributes(serializables, attributeList, fullUpdate)
            print("UpdateAttributeInspector: Updated components with AttributeEditor")
        end
    else
        -- Show "No selection" message
        local text = Text:new()
        text.text = "No object selected"
        text:SetFont("Fonts/Anonymous Pro.ttf", 12)
        text:SetColor(Color(0.7, 0.7, 0.7, 1))
        parentContainer:AddChild(text)
    end
end

-- Toggle inspector lock
function ToggleInspectorLock()
    inspectorLocked = not inspectorLocked
    if inspectorLockButton ~= nil then
        inspectorLockButton.style = inspectorLocked and "ToggledButton" or "Button"
    end
    print("Inspector locked: " .. tostring(inspectorLocked))
end

-- Hide inspector window
function HideAttributeInspectorWindow()
    if attributeInspectorWindow ~= nil then
        attributeInspectorWindow.visible = false
    end
end

-- Show inspector window
function ShowAttributeInspectorWindow()
    if attributeInspectorWindow ~= nil then
        attributeInspectorWindow.visible = true
        attributeInspectorWindow:BringToFront()
    end
end

-- Disable inspector lock
function DisableInspectorLock()
    inspectorLocked = false
    if inspectorLockButton ~= nil then
        inspectorLockButton.style = "Button"
    end
    UpdateAttributeInspector(true)
end

-- =======================
-- AttributeEditor 回调函数实现
-- =======================

function SetAttributeEditorID(attrEdit, serializables)
    if attrEdit == nil or serializables == nil then
        return
    end

    -- 存储节点ID列表或组件ID列表
    local nodeIDs = {}
    local componentIDs = {}

    for i = 1, #serializables do
        local obj = serializables[i]
        -- 检查是否是 Node
        if tolua.type(obj) == "Node" then
            table.insert(nodeIDs, obj:GetID())
        -- 检查是否是 Component
        elseif obj.node ~= nil then
            table.insert(componentIDs, obj:GetID())
        end
    end

    -- 将ID列表存储到attrEdit的vars中
    -- 简化实现：存储为字符串
    if #nodeIDs > 0 then
        attrEdit:SetVar(NODE_IDS_VAR, Variant(table.concat(nodeIDs, ",")))
    end
    if #componentIDs > 0 then
        attrEdit:SetVar(COMPONENT_IDS_VAR, Variant(table.concat(componentIDs, ",")))
    end
end

function GetAttributeEditorTargets(attrEdit)
    if attrEdit == nil then
        return {}
    end

    local targets = {}

    -- 从vars中获取NodeIDs
    local nodeIDsVar = attrEdit:GetVar(NODE_IDS_VAR)
    if not nodeIDsVar:IsEmpty() then
        local nodeIDsStr = nodeIDsVar:GetString()
        for idStr in string.gmatch(nodeIDsStr, "[^,]+") do
            local id = tonumber(idStr)
            if id and editorScene then
                local node = editorScene:GetNode(id)
                if node ~= nil then
                    table.insert(targets, node)
                end
            end
        end
    end

    -- 从vars中获取ComponentIDs
    local componentIDsVar = attrEdit:GetVar(COMPONENT_IDS_VAR)
    if not componentIDsVar:IsEmpty() then
        local componentIDsStr = componentIDsVar:GetString()
        for idStr in string.gmatch(componentIDsStr, "[^,]+") do
            local id = tonumber(idStr)
            if id and editorScene then
                local component = editorScene:GetComponent(id)
                if component ~= nil then
                    table.insert(targets, component)
                end
            end
        end
    end

    -- 如果没有找到，返回当前编辑的节点
    if #targets == 0 and editNode ~= nil then
        return {editNode}
    end

    return targets
end

function PreEditAttribute(serializables, index)
    -- 在编辑属性前调用
    -- 可以在这里添加验证逻辑
    return true
end

function PostEditAttribute(serializables, index, oldValues)
    -- 在编辑属性后调用
    -- 创建撤销操作（简化实现）
    -- TODO: 创建 EditAttributeAction 并保存到撤销栈

    -- 标记场景已修改
    if SetSceneModified then
        SetSceneModified()
    end

    -- 更新层级树（如果节点名称改变）
    if UpdateHierarchyItem and editorScene then
        UpdateHierarchyItem(editorScene, false)
    end
end

function GetVariableName(hash)
    -- 根据 StringHash 获取变量名称
    -- 简化实现：返回空字符串
    if globalVarNames and not globalVarNames:IsEmpty() then
        local nameVar = globalVarNames[hash]
        if nameVar and not nameVar:IsEmpty() then
            return nameVar:GetString()
        end
    end
    return ""
end

-- =======================
-- 辅助函数
-- =======================

function GetVarName(hash)
    return GetVariableName(hash)
end

print("EditorInspectorWindow: Loaded with AttributeEditor integration")
