-- AttributeEditor.lua - 属性编辑器
--
-- 功能：
-- - 创建和管理属性编辑UI
-- - 支持多种类型属性编辑（Int, Float, Bool, String, Vector3, Color等）
-- - 资源引用编辑器
-- - 变量和标签管理

-- =======================
-- 常量定义
-- =======================
MIN_NODE_ATTRIBUTES = 4
MAX_NODE_ATTRIBUTES = 8
ATTRNAME_WIDTH = 150
ATTR_HEIGHT = 19

-- StringHash for event types
TEXT_CHANGED_EVENT_TYPE = StringHash("TextChanged")

-- =======================
-- 全局状态变量
-- =======================
inLoadAttributeEditor = false
inEditAttribute = false
inUpdateBitSelection = false
showNonEditableAttribute = false

-- =======================
-- 颜色定义
-- =======================
normalTextColor = Color(1.0, 1.0, 1.0)
modifiedTextColor = Color(1.0, 0.8, 0.5)
nonEditableTextColor = Color(0.7, 0.7, 0.7)

-- =======================
-- 资源路径配置
-- =======================
sceneResourcePath = nil  -- 将在初始化时设置
rememberResourcePath = true

-- =======================
-- 位掩码编辑器配置
-- =======================
MAX_BITMASK_BITS = 8
MAX_BITMASK_VALUE = (1 << MAX_BITMASK_BITS) - 1  -- 255
nonEditableBitSelectorColor = Color(0.5, 0.5, 0.5)
editableBitSelectorColor = Color(1.0, 1.0, 1.0)

-- =======================
-- 例外属性列表
-- =======================
-- 不应该连续编辑的字符串属性
noTextChangedAttrs = {
    ["Script File"] = true,
    ["Class Name"] = true,
    ["Script Object Type"] = true,
    ["Script File Name"] = true
}

-- 应该使用位选择编辑器的属性
bitSelectionAttrs = {
    ["Collision Mask"] = true,
    ["Collision Layer"] = true,
    ["Light Mask"] = true,
    ["Zone Mask"] = true,
    ["View Mask"] = true,
    ["Shadow Mask"] = true
}

-- =======================
-- 其他全局变量
-- =======================
testAnimState = nil  -- WeakHandle for testing animations
dragEditAttribute = false

-- =======================
-- 辅助函数：设置可编辑状态
-- =======================
function SetEditable(element, editable)
    if element == nil then
        return element
    end

    element.editable = editable

    local color = editable and element:GetColor(C_BOTTOMRIGHT) or nonEditableTextColor
    element:SetColor(C_TOPLEFT, color)
    element:SetColor(C_BOTTOMLEFT, color)
    element:SetColor(C_TOPRIGHT, color)

    return element
end

-- =======================
-- 辅助函数：设置值（LineEdit）
-- =======================
function SetValueLineEdit(element, value, sameValue)
    element.text = sameValue and value or STRIKED_OUT
    element.cursorPosition = 0
    return element
end

-- =======================
-- 辅助函数：设置值（CheckBox）
-- =======================
function SetValueCheckBox(element, value, sameValue)
    element.checked = sameValue and value or false
    return element
end

-- =======================
-- 辅助函数：设置值（DropDownList）
-- =======================
function SetValueDropDownList(element, value, sameValue)
    element.selection = sameValue and value or M_MAX_UNSIGNED
    return element
end

-- =======================
-- 创建属性编辑器父容器（带分离标签）
-- =======================
function CreateAttributeEditorParentWithSeparatedLabel(list, name, index, subIndex, suppressedSeparatedLabel)
    suppressedSeparatedLabel = suppressedSeparatedLabel or false

    local editorParent = UIElement:new()
    editorParent.name = "Edit" .. tostring(index) .. "_" .. tostring(subIndex)
    editorParent:SetVar(StringHash("Index"), Variant(index))
    editorParent:SetVar(StringHash("SubIndex"), Variant(subIndex))
    editorParent:SetLayout(LM_VERTICAL, 2)
    list:AddItem(editorParent)

    if suppressedSeparatedLabel then
        local placeHolder = UIElement:new()
        placeHolder.name = name
        editorParent:AddChild(placeHolder)
    else
        local attrNameText = Text:new()
        editorParent:AddChild(attrNameText)
        attrNameText.style = "EditorAttributeText"
        attrNameText.text = name
    end

    return editorParent
end

-- =======================
-- 创建属性编辑器父容器（作为列表子项）
-- =======================
function CreateAttributeEditorParentAsListChild(list, name, index, subIndex)
    local editorParent = UIElement:new()
    editorParent.name = "Edit" .. tostring(index) .. "_" .. tostring(subIndex)
    editorParent:SetVar(StringHash("Index"), Variant(index))
    editorParent:SetVar(StringHash("SubIndex"), Variant(subIndex))
    editorParent:SetLayout(LM_HORIZONTAL)
    list:AddChild(editorParent)

    local placeHolder = UIElement:new()
    placeHolder.name = name
    editorParent:AddChild(placeHolder)

    return editorParent
end

-- =======================
-- 创建属性编辑器父容器（标准）
-- =======================
function CreateAttributeEditorParent(list, name, index, subIndex)
    local editorParent = UIElement:new()
    editorParent.name = "Edit" .. tostring(index) .. "_" .. tostring(subIndex)
    editorParent:SetVar(StringHash("Index"), Variant(index))
    editorParent:SetVar(StringHash("SubIndex"), Variant(subIndex))
    editorParent:SetLayout(LM_HORIZONTAL)
    editorParent:SetFixedHeight(ATTR_HEIGHT)
    list:AddItem(editorParent)

    local attrNameText = Text:new()
    editorParent:AddChild(attrNameText)
    attrNameText.style = "EditorAttributeText"
    attrNameText.text = name
    attrNameText:SetFixedWidth(ATTRNAME_WIDTH)

    return editorParent
end

-- =======================
-- 创建属性行编辑器
-- =======================
function CreateAttributeLineEdit(parent, serializables, index, subIndex)
    local attrEdit = LineEdit:new()
    parent:AddChild(attrEdit)
    attrEdit.dragDropMode = DD_TARGET
    attrEdit.style = "EditorAttributeEdit"
    attrEdit:SetFixedHeight(ATTR_HEIGHT - 2)
    attrEdit:SetVar(StringHash("Index"), Variant(index))
    attrEdit:SetVar(StringHash("SubIndex"), Variant(subIndex))
    SetAttributeEditorID(attrEdit, serializables)

    return attrEdit
end

-- =======================
-- 创建位掩码选择器
-- =======================
function CreateAttributeBitSelector(parent, serializables, index, subIndex)
    local container = UIElement:new()
    parent:AddChild(container)
    parent:SetFixedHeight(38)
    container:SetFixedWidth(16 * 4 + 4)

    -- 创建 2x4 的位选择器网格
    for i = 0, 1 do
        for j = 0, 3 do
            local bitBox = CheckBox:new()
            bitBox.name = "BitSelect_" .. tostring(i * 4 + j)
            container:AddChild(bitBox)
            bitBox.position = IntVector2(16 * j, 16 * i)
            bitBox.style = "CheckBox"
            bitBox:SetFixedHeight(16)

            SubscribeToEvent(bitBox, "Toggled", "HandleBitSelectionToggled")
        end
    end

    local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex)
    attrEdit.name = "LineEdit"
    SubscribeToEvent(attrEdit, "TextChanged", "HandleBitSelectionEdit")
    SubscribeToEvent(attrEdit, "TextFinished", "HandleBitSelectionEdit")
    return attrEdit
end

-- =======================
-- 更新位选择器
-- =======================
function UpdateBitSelection(parent)
    local mask = 0
    for i = 0, MAX_BITMASK_BITS - 1 do
        local bitBox = parent:GetChild("BitSelect_" .. tostring(i), true)
        if bitBox and bitBox.checked then
            mask = bit.bor(mask, bit.lshift(1, i))
        end
    end

    if mask == MAX_BITMASK_VALUE then
        mask = -1
    end

    inUpdateBitSelection = true
    local attrEdit = parent.parent:GetChild("LineEdit", true)
    if attrEdit then
        attrEdit.text = tostring(mask)
    end
    inUpdateBitSelection = false
end

-- =======================
-- 设置位选择器
-- =======================
function SetBitSelection(parent, value)
    local mask = value
    local enabled = true

    if mask == -1 then
        mask = MAX_BITMASK_VALUE
    elseif mask > MAX_BITMASK_VALUE then
        enabled = false
    end

    for i = 0, MAX_BITMASK_BITS - 1 do
        local bitBox = parent:GetChild("BitSelect_" .. tostring(i), true)
        if bitBox then
            bitBox.enabled = enabled
            if not enabled then
                bitBox.color = nonEditableBitSelectorColor
            else
                bitBox.color = editableBitSelectorColor
            end

            if bit.band(bit.lshift(1, i), mask) ~= 0 then
                bitBox.checked = true
            else
                bitBox.checked = false
            end
        end
    end
end

-- =======================
-- 事件处理：位选择器切换
-- =======================
function HandleBitSelectionToggled(eventType, eventData)
    if inUpdateBitSelection then
        return
    end

    local bitBox = eventData["Element"]:GetPtr()
    UpdateBitSelection(bitBox.parent)
end

-- =======================
-- 事件处理：位选择器编辑
-- =======================
function HandleBitSelectionEdit(eventType, eventData)
    if not inUpdateBitSelection then
        local attrEdit = eventData["Element"]:GetPtr()

        inUpdateBitSelection = true
        SetBitSelection(attrEdit.parent, tonumber(attrEdit.text) or 0)
        inUpdateBitSelection = false
    end

    EditAttribute(eventType, eventData)
end

-- =======================
-- 获取属性编辑器父容器
-- =======================
function GetAttributeEditorParent(parent, index, subIndex)
    local name = "Edit" .. tostring(index) .. "_" .. tostring(subIndex)
    return parent:GetChild(name, true)
end

-- =======================
-- 创建字符串属性编辑器
-- =======================
function CreateStringAttributeEditor(list, serializables, info, index, subIndex)
    local parent = CreateAttributeEditorParent(list, info.name, index, subIndex)
    local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex)
    attrEdit.dragDropMode = DD_TARGET

    -- 某些属性不订阅连续编辑（避免不必要的错误）
    if not noTextChangedAttrs[info.name] then
        SubscribeToEvent(attrEdit, "TextChanged", "EditAttribute")
    end
    SubscribeToEvent(attrEdit, "TextFinished", "EditAttribute")

    return parent
end

-- =======================
-- 创建布尔属性编辑器
-- =======================
function CreateBoolAttributeEditor(list, serializables, info, index, subIndex)
    local isUIElement = (tolua.type(serializables[1]) == "UIElement")
    local parent

    if info.name == (isUIElement and "Is Visible" or "Is Enabled") then
        parent = CreateAttributeEditorParentAsListChild(list, info.name, index, subIndex)
    else
        parent = CreateAttributeEditorParent(list, info.name, index, subIndex)
    end

    local attrEdit = CheckBox:new()
    parent:AddChild(attrEdit)
    attrEdit.style = AUTO_STYLE
    attrEdit:SetVar(StringHash("Index"), Variant(index))
    attrEdit:SetVar(StringHash("SubIndex"), Variant(subIndex))
    SetAttributeEditorID(attrEdit, serializables)
    SubscribeToEvent(attrEdit, "Toggled", "EditAttribute")

    return parent
end

-- =======================
-- 创建数值属性编辑器（Float, Vector2/3/4, Color, Quaternion等）
-- =======================
function CreateNumAttributeEditor(list, serializables, info, index, subIndex)
    local parent = CreateAttributeEditorParent(list, info.name, index, subIndex)
    local attrType = info.type
    local numCoords = 1

    if attrType == VAR_VECTOR2 or attrType == VAR_INTVECTOR2 then
        numCoords = 2
    elseif attrType == VAR_VECTOR3 or attrType == VAR_INTVECTOR3 or attrType == VAR_QUATERNION then
        numCoords = 3
    elseif attrType == VAR_VECTOR4 or attrType == VAR_COLOR or attrType == VAR_INTRECT or attrType == VAR_RECT then
        numCoords = 4
    end

    for i = 0, numCoords - 1 do
        local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex)
        attrEdit:SetVar(StringHash("Coordinate"), Variant(i))

        -- 暂时不实现拖拽滑块（CreateDragSlider）

        SubscribeToEvent(attrEdit, "TextChanged", "EditAttribute")
        SubscribeToEvent(attrEdit, "TextFinished", "EditAttribute")
    end

    return parent
end

-- =======================
-- 创建整数属性编辑器
-- =======================
function CreateIntAttributeEditor(list, serializables, info, index, subIndex)
    local parent = CreateAttributeEditorParent(list, info.name, index, subIndex)

    -- 检查是否是位掩码属性
    if bitSelectionAttrs[info.name] then
        local attrEdit = CreateAttributeBitSelector(parent, serializables, index, subIndex)
        return parent
    end

    -- 检查是否有枚举
    if info.enumNames == nil or #info.enumNames == 0 then
        -- 没有枚举，创建数值编辑器
        local attrEdit = CreateAttributeLineEdit(parent, serializables, index, subIndex)

        -- 暂时不实现拖拽滑块（CreateDragSlider）

        -- 如果属性名不包含"Count"，则订阅连续编辑
        if not info.name:find("Count") then
            SubscribeToEvent(attrEdit, "TextChanged", "EditAttribute")
        end
        SubscribeToEvent(attrEdit, "TextFinished", "EditAttribute")

        -- 如果是 NodeID 属性，设置为拖拽目标
        if info.name:find("NodeID") or info.name:find("Node ID") or (info.mode & AM_NODEID ~= 0) then
            attrEdit.dragDropMode = DD_TARGET
        end
    else
        -- 有枚举，创建下拉列表
        local attrEdit = DropDownList:new()
        parent:AddChild(attrEdit)
        attrEdit.style = AUTO_STYLE
        attrEdit:SetFixedHeight(ATTR_HEIGHT - 2)
        attrEdit.resizePopup = true
        attrEdit.placeholderText = STRIKED_OUT
        attrEdit:SetVar(StringHash("Index"), Variant(index))
        attrEdit:SetVar(StringHash("SubIndex"), Variant(subIndex))
        attrEdit:SetLayout(LM_HORIZONTAL, 0, IntRect(4, 1, 4, 1))
        SetAttributeEditorID(attrEdit, serializables)

        for i = 1, #info.enumNames do
            local choice = Text:new()
            attrEdit:AddItem(choice)
            choice.style = "EditorEnumAttributeText"
            choice.text = info.enumNames[i]
        end
        SubscribeToEvent(attrEdit, "ItemSelected", "EditAttribute")
    end

    return parent
end

-- =======================
-- 创建属性编辑器（总入口）
-- =======================
function CreateAttributeEditor(list, serializables, info, index, subIndex, suppressedSeparatedLabel)
    subIndex = subIndex or 0
    suppressedSeparatedLabel = suppressedSeparatedLabel or false

    local parent
    local attrType = info.type

    if attrType == VAR_STRING or attrType == VAR_BUFFER then
        parent = CreateStringAttributeEditor(list, serializables, info, index, subIndex)
    elseif attrType == VAR_BOOL then
        parent = CreateBoolAttributeEditor(list, serializables, info, index, subIndex)
    elseif (attrType >= VAR_FLOAT and attrType <= VAR_VECTOR4) or
           attrType == VAR_QUATERNION or attrType == VAR_COLOR or
           attrType == VAR_INTVECTOR2 or attrType == VAR_INTVECTOR3 or
           attrType == VAR_INTRECT or attrType == VAR_DOUBLE or attrType == VAR_RECT then
        parent = CreateNumAttributeEditor(list, serializables, info, index, subIndex)
    elseif attrType == VAR_INT then
        parent = CreateIntAttributeEditor(list, serializables, info, index, subIndex)
    -- 暂时不支持 VAR_RESOURCEREF, VAR_RESOURCEREFLIST, VAR_VARIANTVECTOR, VAR_VARIANTMAP
    -- 这些将在后续阶段实现
    end

    return parent
end

-- =======================
-- 加载属性编辑器值
-- =======================
function LoadAttributeEditor(parent, value, info, editable, sameValue)
    if parent == nil then
        return
    end

    local index = parent:GetVar(StringHash("Index")):GetUInt()

    -- 假设第一个子元素是标签
    local label = parent:GetChild(0)
    if label and label.type == UI_ELEMENT_TYPE and label.numChildren > 0 then
        label = label:GetChild(0)
    end
    if label and label.type == TEXT_TYPE then
        local modified = false
        if info.defaultValue == nil or info.defaultValue.type == VAR_NONE then
            modified = not value:IsZero()
        else
            modified = (value ~= info.defaultValue)
        end
        label.color = (editable and (modified and modifiedTextColor or normalTextColor) or nonEditableTextColor)
    end

    local attrType = info.type
    if attrType == VAR_FLOAT or attrType == VAR_DOUBLE or attrType == VAR_STRING or attrType == VAR_BUFFER then
        SetEditable(SetValueLineEdit(parent:GetChild(1), value:ToString(), sameValue), editable and sameValue)
    elseif attrType == VAR_BOOL then
        SetEditable(SetValueCheckBox(parent:GetChild(1), value:GetBool(), sameValue), editable and sameValue)
    elseif attrType == VAR_INT then
        if bitSelectionAttrs[info.name] then
            SetEditable(SetValueLineEdit(parent:GetChild("LineEdit", true), value:ToString(), sameValue), editable and sameValue)
        elseif info.enumNames == nil or #info.enumNames == 0 then
            SetEditable(SetValueLineEdit(parent:GetChild(1), value:ToString(), sameValue), editable and sameValue)
        else
            SetEditable(SetValueDropDownList(parent:GetChild(1), value:GetInt(), sameValue), editable and sameValue)
        end
    elseif attrType >= VAR_VECTOR2 and attrType <= VAR_VECTOR4 then
        -- 处理多坐标值
        local numCoords = GetNumCoords(attrType)
        for i = 0, numCoords - 1 do
            local coord = parent:GetChild(i + 1)
            if coord then
                local coordValue = GetCoordinate(value, attrType, i)
                SetEditable(SetValueLineEdit(coord, tostring(coordValue), sameValue), editable and sameValue)
            end
        end
    end
end

-- =======================
-- 辅助函数：获取坐标数量
-- =======================
function GetNumCoords(varType)
    if varType == VAR_VECTOR2 or varType == VAR_INTVECTOR2 then
        return 2
    elseif varType == VAR_VECTOR3 or varType == VAR_INTVECTOR3 or varType == VAR_QUATERNION then
        return 3
    elseif varType == VAR_VECTOR4 or varType == VAR_COLOR or varType == VAR_INTRECT or varType == VAR_RECT then
        return 4
    end
    return 1
end

-- =======================
-- 辅助函数：获取坐标值
-- =======================
function GetCoordinate(value, varType, index)
    if varType == VAR_VECTOR2 then
        local v = value:GetVector2()
        return index == 0 and v.x or v.y
    elseif varType == VAR_VECTOR3 then
        local v = value:GetVector3()
        if index == 0 then return v.x
        elseif index == 1 then return v.y
        else return v.z end
    elseif varType == VAR_VECTOR4 then
        local v = value:GetVector4()
        if index == 0 then return v.x
        elseif index == 1 then return v.y
        elseif index == 2 then return v.z
        else return v.w end
    elseif varType == VAR_COLOR then
        local c = value:GetColor()
        if index == 0 then return c.r
        elseif index == 1 then return c.g
        elseif index == 2 then return c.b
        else return c.a end
    elseif varType == VAR_QUATERNION then
        local q = value:GetQuaternion()
        if index == 0 then return q.x
        elseif index == 1 then return q.y
        else return q.z end
    end
    return 0
end

-- =======================
-- UpdateAttributes - 核心函数，更新属性列表
-- =======================
function UpdateAttributes(serializables, list, fullUpdate)
    if serializables == nil or #serializables == 0 then
        return
    end

    -- 检查属性结构是否变化
    local count = GetAttributeEditorCount(serializables)
    if not fullUpdate then
        if list.contentElement.numChildren ~= count then
            fullUpdate = true
        end
    end

    -- 记住旧的滚动位置
    local oldViewPos = list.viewPosition

    -- 如果需要完全更新，清空列表
    if fullUpdate then
        list:RemoveAllItems()
        -- 移除非internal的子元素
        for i = list.numChildren - 1, 0, -1 do
            local child = list:GetChild(i)
            if child and not child.internal then
                child:Remove()
            end
        end
    end

    -- 遍历第一个对象的所有属性
    local firstObj = serializables[1]
    local numAttrs = firstObj:GetNumAttributes()

    for i = 0, numAttrs - 1 do
        local info = firstObj:GetAttributeInfo(i)

        -- 跳过不可编辑的属性
        if showNonEditableAttribute or (info.mode & AM_NOEDIT == 0) then
            -- 获取默认值
            info.defaultValue = firstObj:GetAttributeDefault(i)

            -- 如果需要完全更新，创建属性编辑器
            if fullUpdate then
                CreateAttributeEditor(list, serializables, info, i, 0)
            end

            -- 加载属性值
            LoadAttributeEditorFromList(list, serializables, info, i)
        end
    end

    -- 恢复滚动位置
    if fullUpdate then
        list.viewPosition = oldViewPos
    end
end

-- =======================
-- LoadAttributeEditor - 从列表加载属性
-- =======================
function LoadAttributeEditorFromList(list, serializables, info, index)
    local editable = (info.mode & AM_NOEDIT == 0)

    local parent = GetAttributeEditorParent(list, index, 0)
    if parent == nil then
        return
    end

    inLoadAttributeEditor = true

    local sameName = true
    local sameValue = true
    local value = serializables[1]:GetAttribute(index)
    local values = {}

    -- 检查所有对象的属性是否相同
    for i = 1, #serializables do
        local obj = serializables[i]
        local objNumAttrs = obj:GetNumAttributes()
        if index >= objNumAttrs or obj:GetAttributeInfo(index).name ~= info.name then
            sameName = false
            break
        end

        local val = obj:GetAttribute(index)
        if val ~= value then
            sameValue = false
        end
        table.insert(values, val)
    end

    -- 如果属性名相同，加载值
    if sameName then
        LoadAttributeEditor(parent, value, info, editable, sameValue)
    else
        parent.visible = false
    end

    inLoadAttributeEditor = false
end

-- =======================
-- GetAttributeEditorCount - 计算属性编辑器数量
-- =======================
function GetAttributeEditorCount(serializables)
    local count = 0

    if #serializables == 0 then
        return 0
    end

    local firstObj = serializables[1]
    local numAttrs = firstObj:GetNumAttributes()
    for i = 0, numAttrs - 1 do
        local info = firstObj:GetAttributeInfo(i)
        if showNonEditableAttribute or (info.mode & AM_NOEDIT == 0) then
            -- 跳过特殊属性（如Tags, Is Enabled等）
            if info.name ~= "Tags" and
               info.name ~= "Is Enabled" and
               info.name ~= "Is Visible" then
                count = count + 1
            end
        end
    end

    return count
end

-- =======================
-- 编辑属性 - 核心函数
-- =======================
function EditAttribute(eventType, eventData)
    -- 防止在加载时触发编辑
    if inLoadAttributeEditor then
        return
    end

    local attrEdit = eventData["Element"]:GetPtr()
    if attrEdit == nil then
        return
    end

    local parent = attrEdit.parent
    local serializables = GetAttributeEditorTargets(attrEdit)
    if serializables == nil or #serializables == 0 then
        return
    end

    local indexVar = attrEdit:GetVar(StringHash("Index"))
    local subIndexVar = attrEdit:GetVar(StringHash("SubIndex"))
    local coordinateVar = attrEdit:GetVar(StringHash("Coordinate"))

    if indexVar:IsEmpty() then
        return
    end

    local index = indexVar:GetUInt()
    local subIndex = subIndexVar:IsEmpty() and 0 or subIndexVar:GetUInt()
    local coordinate = coordinateVar:IsEmpty() and 0 or coordinateVar:GetUInt()
    local intermediateEdit = (eventType == TEXT_CHANGED_EVENT_TYPE)

    -- 调用预编辑回调
    if not PreEditAttribute(serializables, index) then
        return
    end

    inEditAttribute = true

    local oldValues = {}

    if not dragEditAttribute then
        -- 保存旧值用于撤销
        for i = 1, #serializables do
            table.insert(oldValues, serializables[i]:GetAttribute(index))
        end
    end

    -- 从编辑器存储属性值
    StoreAttributeEditor(parent, serializables, index, subIndex, coordinate)

    -- 应用属性
    for i = 1, #serializables do
        serializables[i]:ApplyAttributes()
    end

    if not dragEditAttribute then
        -- 调用后编辑回调
        PostEditAttribute(serializables, index, oldValues)
    end

    inEditAttribute = false

    -- 如果不是中间编辑，标记属性需要刷新
    if not intermediateEdit then
        attributesDirty = true
    end
end

-- =======================
-- StoreAttributeEditor - 从UI存储属性值到对象
-- =======================
function StoreAttributeEditor(parent, serializables, index, subIndex, coordinate)
    if parent == nil or serializables == nil or #serializables == 0 then
        return
    end

    local firstObj = serializables[1]
    local info = firstObj:GetAttributeInfo(index)
    local attrType = info.type

    -- 根据属性类型从UI获取值
    if attrType == VAR_STRING or attrType == VAR_BUFFER then
        local lineEdit = parent:GetChild(1)
        if lineEdit and lineEdit.text ~= STRIKED_OUT then
            for i = 1, #serializables do
                serializables[i]:SetAttribute(index, Variant(lineEdit.text))
            end
        end
    elseif attrType == VAR_BOOL then
        local checkBox = parent:GetChild(1)
        if checkBox then
            for i = 1, #serializables do
                serializables[i]:SetAttribute(index, Variant(checkBox.checked))
            end
        end
    elseif attrType == VAR_INT then
        if bitSelectionAttrs[info.name] then
            local lineEdit = parent:GetChild("LineEdit", true)
            if lineEdit and lineEdit.text ~= STRIKED_OUT then
                local value = tonumber(lineEdit.text) or 0
                for i = 1, #serializables do
                    serializables[i]:SetAttribute(index, Variant(value))
                end
            end
        elseif info.enumNames and #info.enumNames > 0 then
            local dropDown = parent:GetChild(1)
            if dropDown and dropDown.selection ~= M_MAX_UNSIGNED then
                for i = 1, #serializables do
                    serializables[i]:SetAttribute(index, Variant(dropDown.selection))
                end
            end
        else
            local lineEdit = parent:GetChild(1)
            if lineEdit and lineEdit.text ~= STRIKED_OUT then
                local value = tonumber(lineEdit.text) or 0
                for i = 1, #serializables do
                    serializables[i]:SetAttribute(index, Variant(value))
                end
            end
        end
    elseif attrType == VAR_FLOAT or attrType == VAR_DOUBLE then
        local lineEdit = parent:GetChild(1)
        if lineEdit and lineEdit.text ~= STRIKED_OUT then
            local value = tonumber(lineEdit.text) or 0.0
            for i = 1, #serializables do
                serializables[i]:SetAttribute(index, Variant(value))
            end
        end
    elseif attrType == VAR_VECTOR3 then
        -- 获取3个坐标值
        local coords = {}
        for c = 0, 2 do
            local lineEdit = parent:GetChild(c + 1)
            if lineEdit and lineEdit.text ~= STRIKED_OUT then
                coords[c] = tonumber(lineEdit.text) or 0.0
            else
                coords[c] = 0.0
            end
        end
        local newVec = Vector3(coords[0], coords[1], coords[2])
        for i = 1, #serializables do
            serializables[i]:SetAttribute(index, Variant(newVec))
        end
    elseif attrType == VAR_QUATERNION then
        -- Quaternion 作为欧拉角编辑
        local coords = {}
        for c = 0, 2 do
            local lineEdit = parent:GetChild(c + 1)
            if lineEdit and lineEdit.text ~= STRIKED_OUT then
                coords[c] = tonumber(lineEdit.text) or 0.0
            else
                coords[c] = 0.0
            end
        end
        local newQuat = Quaternion(coords[0], coords[1], coords[2])
        for i = 1, #serializables do
            serializables[i]:SetAttribute(index, Variant(newQuat))
        end
    elseif attrType == VAR_COLOR then
        -- 获取4个颜色分量
        local coords = {}
        for c = 0, 3 do
            local lineEdit = parent:GetChild(c + 1)
            if lineEdit and lineEdit.text ~= STRIKED_OUT then
                coords[c] = tonumber(lineEdit.text) or 0.0
            else
                coords[c] = 0.0
            end
        end
        local newColor = Color(coords[0], coords[1], coords[2], coords[3])
        for i = 1, #serializables do
            serializables[i]:SetAttribute(index, Variant(newColor))
        end
    end
end

-- =======================
-- 占位函数（由调用者实现）
-- =======================

function SetAttributeEditorID(attrEdit, serializables)
    -- 由调用者实现
    -- 设置属性编辑器的ID，用于追踪哪些可序列化对象被编辑
end

function PreEditAttribute(serializables, index)
    -- 由调用者实现
    -- 在编辑属性前调用，返回是否允许编辑
    return true
end

function PostEditAttribute(serializables, index, oldValues)
    -- 由调用者实现
    -- 在编辑属性后调用，用于撤销/重做系统
end

function GetAttributeEditorTargets(attrEdit)
    -- 由调用者实现
    -- 获取属性编辑器的目标可序列化对象数组
    return nil
end

function GetVariableName(hash)
    -- 由调用者实现
    -- 根据 StringHash 获取变量名称
    return ""
end

-- Create a drag slider for numeric line edits
function CreateDragSlider(parent)
    local dragSld = Button()
    dragSld:SetStyle("EditorDragSlider")
    dragSld:SetFixedHeight(ATTR_HEIGHT - 3)
    dragSld:SetFixedWidth(dragSld.height)
    dragSld:SetAlignment(HA_RIGHT, VA_TOP)
    dragSld.focusMode = FM_NOTFOCUSABLE
    parent:AddChild(dragSld)

    SubscribeToEvent(dragSld, "DragBegin", "LineDragBegin")
    SubscribeToEvent(dragSld, "DragMove", "LineDragMove")
    SubscribeToEvent(dragSld, "DragEnd", "LineDragEnd")
    SubscribeToEvent(dragSld, "DragCancel", "LineDragCancel")

    return dragSld
end

-- Drag slider event handlers
function LineDragBegin(eventType, eventData)
    local label = eventData["Element"]:GetPtr()
    local x = eventData["X"]:GetInt()
    label:SetVar("posX", Variant(x))

    -- Store the old value before dragging
    dragEditAttribute = false
    local selectedNumEditor = label.parent

    selectedNumEditor:SetVar("DragBeginValue", Variant(selectedNumEditor.text))
    selectedNumEditor.cursorPosition = 0

    -- Set mouse mode to user preference
    if SetMouseMode then
        SetMouseMode(true)
    end
end

function LineDragMove(eventType, eventData)
    local label = eventData["Element"]:GetPtr()
    local selectedNumEditor = label.parent

    -- Prevent undo
    dragEditAttribute = true

    local x = eventData["X"]:GetInt()
    local val = input.mouseMoveX

    local fieldVal = tonumber(selectedNumEditor.text) or 0.0
    fieldVal = fieldVal + val / 100.0
    label:SetVar("posX", Variant(x))
    selectedNumEditor.text = tostring(fieldVal)
    selectedNumEditor.cursorPosition = 0
end

function LineDragEnd(eventType, eventData)
    local label = eventData["Element"]:GetPtr()
    local selectedNumEditor = label.parent

    -- Prepare the attributes to store an undo with:
    -- - old value = drag begin value
    -- - new value = final value

    local finalValue = selectedNumEditor.text
    -- Reset attribute to begin value, and prevent undo
    dragEditAttribute = true
    local beginValue = selectedNumEditor:GetVar("DragBeginValue")
    if not beginValue:IsEmpty() then
        selectedNumEditor.text = beginValue:GetString()
    end

    -- Store final value, allow undo
    dragEditAttribute = false
    selectedNumEditor.text = finalValue
    selectedNumEditor.cursorPosition = 0

    -- Revert mouse to normal behaviour
    if SetMouseMode then
        SetMouseMode(false)
    end
end

function LineDragCancel(eventType, eventData)
    local label = eventData["Element"]:GetPtr()

    -- Reset value to what it was when drag edit began, preventing undo
    dragEditAttribute = true
    local selectedNumEditor = label.parent
    local beginValue = selectedNumEditor:GetVar("DragBeginValue")
    if not beginValue:IsEmpty() then
        selectedNumEditor.text = beginValue:GetString()
    end
    selectedNumEditor.cursorPosition = 0

    -- Revert mouse to normal behaviour
    if SetMouseMode then
        SetMouseMode(false)
    end
end

-- Create a resource picker button
function CreateResourcePickerButton(container, serializables, index, subIndex, text)
    local button = Button()
    container:AddChild(button)
    button:SetStyle(AUTO_STYLE)
    button:SetFixedSize(36, ATTR_HEIGHT - 2)
    button:SetVar("Index", Variant(index))
    button:SetVar("SubIndex", Variant(subIndex))
    SetAttributeEditorID(button, serializables)

    local buttonText = Text()
    button:AddChild(buttonText)
    buttonText:SetStyle("EditorAttributeText")
    buttonText:SetAlignment(HA_CENTER, VA_CENTER)
    buttonText.text = text
    buttonText.autoLocalizable = true

    return button
end

-- Open resource file in system default application (event handler version)
function OpenResource(eventType, eventData)
    local button = eventData["Element"]:GetPtr()
    local attrEdit = button.parent:GetChild(0)

    local fileName = Trim(attrEdit.text)
    if fileName == "" then
        return
    end

    OpenResourceByName(fileName)
end

-- Open resource file by name
function OpenResourceByName(fileName)
    local resourceDirs = cache.resourceDirs
    for i = 1, #resourceDirs do
        local fullPath = resourceDirs[i] .. fileName
        if fileSystem:FileExists(fullPath) then
            fileSystem:SystemOpen(fullPath, "")
            return
        end
    end
end

-- Helper to trim whitespace
function Trim(s)
    if type(s) ~= "string" then
        return tostring(s)
    end
    return s:match("^%s*(.-)%s*$")
end

-- =======================
-- 初始化函数
-- =======================
function InitAttributeEditor()
    -- 初始化资源路径
    if sceneResourcePath == nil then
        sceneResourcePath = fileSystem:GetProgramDir() .. "Data/"
    end
end

print("[AttributeEditor] 基础框架已加载（阶段1）")
