-- EditorActions.lua - 撤销/重做系统
-- 简化实现，支持核心操作的撤销/重做

-- =======================
-- 全局变量
-- =======================
undoStack = undoStack or {}
undoStackPos = undoStackPos or 0
MAX_UNDOSTACK_SIZE = MAX_UNDOSTACK_SIZE or 256

-- =======================
-- EditAction 基类（使用表模拟类）
-- =======================
EditAction = {}
EditAction.__index = EditAction

function EditAction:new()
    local obj = {}
    setmetatable(obj, self)
    return obj
end

function EditAction:Undo()
    -- 由子类实现
end

function EditAction:Redo()
    -- 由子类实现
end

-- =======================
-- EditActionGroup - 组操作
-- =======================
EditActionGroup = {}
EditActionGroup.__index = EditActionGroup

function EditActionGroup:new()
    local obj = {
        actions = {}
    }
    setmetatable(obj, self)
    return obj
end

function EditActionGroup:Undo()
    -- 反向执行撤销
    for i = #self.actions, 1, -1 do
        self.actions[i]:Undo()
    end
end

function EditActionGroup:Redo()
    -- 正向执行重做
    for i = 1, #self.actions do
        self.actions[i]:Redo()
    end
end

-- =======================
-- CreateNodeAction - 创建节点操作
-- =======================
CreateNodeAction = setmetatable({}, {__index = EditAction})
CreateNodeAction.__index = CreateNodeAction

function CreateNodeAction:new()
    local obj = EditAction:new()
    setmetatable(obj, self)
    obj.nodeID = 0
    obj.parentID = 0
    obj.nodeData = nil
    return obj
end

function CreateNodeAction:Define(node)
    if node == nil then
        return
    end

    self.nodeID = node:GetID()
    self.parentID = node.parent:GetID()
    self.nodeData = XMLFile()
    local rootElem = self.nodeData:CreateRoot("node")
    node:SaveXML(rootElem)
end

function CreateNodeAction:Undo()
    local parent = editorScene:GetNode(self.parentID)
    local node = editorScene:GetNode(self.nodeID)
    if parent ~= nil and node ~= nil then
        parent:RemoveChild(node)
        if hierarchyList then
            hierarchyList:ClearSelection()
        end
    end
end

function CreateNodeAction:Redo()
    local parent = editorScene:GetNode(self.parentID)
    if parent ~= nil and self.nodeData ~= nil then
        -- 判断是否是replicated节点
        local isReplicated = (self.nodeID >= 0x01000000)
        local node = parent:CreateChild("", isReplicated and REPLICATED or LOCAL, self.nodeID)
        node:LoadXML(self.nodeData:GetRoot())
        if FocusNode then
            FocusNode(node)
        end
    end
end

-- =======================
-- DeleteNodeAction - 删除节点操作
-- =======================
DeleteNodeAction = setmetatable({}, {__index = EditAction})
DeleteNodeAction.__index = DeleteNodeAction

function DeleteNodeAction:new()
    local obj = EditAction:new()
    setmetatable(obj, self)
    obj.nodeID = 0
    obj.parentID = 0
    obj.nodeData = nil
    return obj
end

function DeleteNodeAction:Define(node)
    if node == nil then
        return
    end

    self.nodeID = node:GetID()
    self.parentID = node.parent:GetID()
    self.nodeData = XMLFile()
    local rootElem = self.nodeData:CreateRoot("node")
    node:SaveXML(rootElem)
end

function DeleteNodeAction:Undo()
    local parent = editorScene:GetNode(self.parentID)
    if parent ~= nil and self.nodeData ~= nil then
        local isReplicated = (self.nodeID >= 0x01000000)
        local node = parent:CreateChild("", isReplicated and REPLICATED or LOCAL, self.nodeID)
        node:LoadXML(self.nodeData:GetRoot())
        if FocusNode then
            FocusNode(node)
        end
    end
end

function DeleteNodeAction:Redo()
    local parent = editorScene:GetNode(self.parentID)
    local node = editorScene:GetNode(self.nodeID)
    if parent ~= nil and node ~= nil then
        parent:RemoveChild(node)
        if hierarchyList then
            hierarchyList:ClearSelection()
        end
    end
end

-- =======================
-- CreateComponentAction - 创建组件操作
-- =======================
CreateComponentAction = setmetatable({}, {__index = EditAction})
CreateComponentAction.__index = CreateComponentAction

function CreateComponentAction:new()
    local obj = EditAction:new()
    setmetatable(obj, self)
    obj.nodeID = 0
    obj.componentID = 0
    obj.componentType = ""
    obj.componentData = nil
    return obj
end

function CreateComponentAction:Define(component)
    if component == nil then
        return
    end

    self.nodeID = component.node:GetID()
    self.componentID = component:GetID()
    self.componentType = component:GetTypeName()
    self.componentData = XMLFile()
    local rootElem = self.componentData:CreateRoot("component")
    component:SaveXML(rootElem)
end

function CreateComponentAction:Undo()
    local node = editorScene:GetNode(self.nodeID)
    local component = editorScene:GetComponent(self.componentID)
    if node ~= nil and component ~= nil then
        node:RemoveComponent(component)
    end
end

function CreateComponentAction:Redo()
    local node = editorScene:GetNode(self.nodeID)
    if node ~= nil and self.componentData ~= nil then
        local isReplicated = (self.componentID >= 0x01000000)
        local component = node:CreateComponent(self.componentType, isReplicated and REPLICATED or LOCAL, self.componentID)
        if component ~= nil then
            component:LoadXML(self.componentData:GetRoot())
            component:ApplyAttributes()
        end
    end
end

-- =======================
-- DeleteComponentAction - 删除组件操作
-- =======================
DeleteComponentAction = setmetatable({}, {__index = EditAction})
DeleteComponentAction.__index = DeleteComponentAction

function DeleteComponentAction:new()
    local obj = EditAction:new()
    setmetatable(obj, self)
    obj.nodeID = 0
    obj.componentID = 0
    obj.componentType = ""
    obj.componentData = nil
    return obj
end

function DeleteComponentAction:Define(component)
    if component == nil then
        return
    end

    self.nodeID = component.node:GetID()
    self.componentID = component:GetID()
    self.componentType = component:GetTypeName()
    self.componentData = XMLFile()
    local rootElem = self.componentData:CreateRoot("component")
    component:SaveXML(rootElem)
end

function DeleteComponentAction:Undo()
    local node = editorScene:GetNode(self.nodeID)
    if node ~= nil and self.componentData ~= nil then
        local isReplicated = (self.componentID >= 0x01000000)
        local component = node:CreateComponent(self.componentType, isReplicated and REPLICATED or LOCAL, self.componentID)
        if component ~= nil then
            component:LoadXML(self.componentData:GetRoot())
            component:ApplyAttributes()
        end
    end
end

function DeleteComponentAction:Redo()
    local node = editorScene:GetNode(self.nodeID)
    local component = editorScene:GetComponent(self.componentID)
    if node ~= nil and component ~= nil then
        node:RemoveComponent(component)
    end
end

-- =======================
-- EditNodeTransformAction - 编辑节点变换
-- =======================
EditNodeTransformAction = setmetatable({}, {__index = EditAction})
EditNodeTransformAction.__index = EditNodeTransformAction

function EditNodeTransformAction:new()
    local obj = EditAction:new()
    setmetatable(obj, self)
    obj.nodeIDs = {}
    obj.oldTransforms = {}
    obj.newTransforms = {}
    return obj
end

function EditNodeTransformAction:Define(nodes)
    if nodes == nil or #nodes == 0 then
        return
    end

    for i = 1, #nodes do
        local node = nodes[i]
        if node ~= nil then
            table.insert(self.nodeIDs, node:GetID())
            table.insert(self.oldTransforms, {
                position = node.position,
                rotation = node.rotation,
                scale = node.scale
            })
            table.insert(self.newTransforms, {
                position = node.position,
                rotation = node.rotation,
                scale = node.scale
            })
        end
    end
end

function EditNodeTransformAction:SetNew(nodes)
    if nodes == nil or #nodes == 0 then
        return
    end

    for i = 1, #nodes do
        local node = nodes[i]
        if node ~= nil and i <= #self.newTransforms then
            self.newTransforms[i] = {
                position = node.position,
                rotation = node.rotation,
                scale = node.scale
            }
        end
    end
end

function EditNodeTransformAction:Undo()
    for i = 1, #self.nodeIDs do
        local node = editorScene:GetNode(self.nodeIDs[i])
        if node ~= nil and self.oldTransforms[i] ~= nil then
            node.position = self.oldTransforms[i].position
            node.rotation = self.oldTransforms[i].rotation
            node.scale = self.oldTransforms[i].scale
        end
    end
end

function EditNodeTransformAction:Redo()
    for i = 1, #self.nodeIDs do
        local node = editorScene:GetNode(self.nodeIDs[i])
        if node ~= nil and self.newTransforms[i] ~= nil then
            node.position = self.newTransforms[i].position
            node.rotation = self.newTransforms[i].rotation
            node.scale = self.newTransforms[i].scale
        end
    end
end

-- =======================
-- 撤销/重做栈管理
-- =======================

function SaveEditAction(action)
    if action == nil then
        return
    end

    -- 如果在栈中间，删除后面的所有操作
    if undoStackPos < #undoStack then
        for i = #undoStack, undoStackPos + 1, -1 do
            table.remove(undoStack, i)
        end
    end

    -- 添加新操作
    table.insert(undoStack, action)
    undoStackPos = #undoStack

    -- 限制栈大小
    if #undoStack > MAX_UNDOSTACK_SIZE then
        table.remove(undoStack, 1)
        undoStackPos = undoStackPos - 1
    end
end

function SaveEditActionGroup(group)
    if group == nil or #group.actions == 0 then
        return
    end

    SaveEditAction(group)
end

function Undo()
    if undoStackPos > 0 then
        local action = undoStack[undoStackPos]
        if action ~= nil then
            action:Undo()
            undoStackPos = undoStackPos - 1

            if UpdateHierarchyItem then
                UpdateHierarchyItem(editorScene, false)
            end
            if UpdateAttributeInspector then
                UpdateAttributeInspector()
            end

            print("Undo: " .. undoStackPos .. "/" .. #undoStack)
        end
    end
end

function Redo()
    if undoStackPos < #undoStack then
        undoStackPos = undoStackPos + 1
        local action = undoStack[undoStackPos]
        if action ~= nil then
            action:Redo()

            if UpdateHierarchyItem then
                UpdateHierarchyItem(editorScene, false)
            end
            if UpdateAttributeInspector then
                UpdateAttributeInspector()
            end

            print("Redo: " .. undoStackPos .. "/" .. #undoStack)
        end
    end
end

function ClearEditActions()
    undoStack = {}
    undoStackPos = 0
    print("Undo stack cleared")
end

function CanUndo()
    return undoStackPos > 0
end

function CanRedo()
    return undoStackPos < #undoStack
end

-- =======================
-- 辅助函数
-- =======================

function IsReplicatedID(id)
    -- ID >= 0x01000000 表示 replicated
    return id >= 0x01000000
end

print("EditorActions: Undo/Redo system loaded")
