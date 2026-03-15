-- Urho3D spawn editor
-- Converted from AngelScript to Lua

-- Global spawn editor variables
positionOffsetX = nil
positionOffsetY = nil
positionOffsetZ = nil
randomRotationX = nil
randomRotationY = nil
randomRotationZ = nil
randomScaleMinEdit = nil
randomScaleMaxEdit = nil
numberSpawnedObjectsEdit = nil
spawnRadiusEdit = nil
spawnCountEdit = nil

spawnWindow = nil
positionOffset = Vector3(0, 0, 0)
randomRotation = Vector3(0, 0, 0)
randomScaleMin = 1
randomScaleMax = 1
spawnCount = 1
spawnRadius = 0
useNormal = true
alignToAABBBottom = true
spawnOnSelection = false
numberSpawnedObjects = 1
spawnedObjectsNames = {}

function CreateSpawnEditor()
    if spawnWindow ~= nil then
        return
    end

    spawnWindow = LoadEditorUI("UI/EditorSpawnWindow.xml")
    ui.root:AddChild(spawnWindow)
    spawnWindow.opacity = uiMaxOpacity

    local height = math.min(ui.root.height - 60, 500)
    spawnWindow:SetSize(300, height)
    CenterDialog(spawnWindow)

    HideSpawnEditor()
    SubscribeToEvent(spawnWindow:GetChild("CloseButton", true), "Released", "HideSpawnEditor")
    positionOffsetX = spawnWindow:GetChild("PositionOffset.x", true)
    positionOffsetY = spawnWindow:GetChild("PositionOffset.y", true)
    positionOffsetZ = spawnWindow:GetChild("PositionOffset.z", true)
    positionOffsetX.text = tostring(positionOffset.x)
    positionOffsetY.text = tostring(positionOffset.y)
    positionOffsetZ.text = tostring(positionOffset.z)
    randomRotationX = spawnWindow:GetChild("RandomRotation.x", true)
    randomRotationY = spawnWindow:GetChild("RandomRotation.y", true)
    randomRotationZ = spawnWindow:GetChild("RandomRotation.z", true)
    randomRotationX.text = tostring(randomRotation.x)
    randomRotationY.text = tostring(randomRotation.y)
    randomRotationZ.text = tostring(randomRotation.z)

    randomScaleMinEdit = spawnWindow:GetChild("RandomScaleMin", true)
    randomScaleMaxEdit = spawnWindow:GetChild("RandomScaleMax", true)
    randomScaleMinEdit.text = tostring(randomScaleMin)
    randomScaleMaxEdit.text = tostring(randomScaleMax)
    local useNormalToggle = spawnWindow:GetChild("UseNormal", true)
    useNormalToggle.checked = useNormal
    local alignToAABBBottomToggle = spawnWindow:GetChild("AlignToAABBBottom", true)
    alignToAABBBottomToggle.checked = alignToAABBBottom
    local spawnOnSelectionToggle = spawnWindow:GetChild("SpawnOnSelected", true)
    spawnOnSelectionToggle.checked = spawnOnSelection

    numberSpawnedObjectsEdit = spawnWindow:GetChild("NumberSpawnedObjects", true)
    numberSpawnedObjectsEdit.text = tostring(numberSpawnedObjects)

    spawnRadiusEdit = spawnWindow:GetChild("SpawnRadius", true)
    spawnCountEdit = spawnWindow:GetChild("SpawnCount", true)
    spawnRadiusEdit.text = tostring(spawnRadius)
    spawnCountEdit.text = tostring(spawnCount)

    SubscribeToEvent(positionOffsetX, "TextChanged", "EditPositionOffset")
    SubscribeToEvent(positionOffsetY, "TextChanged", "EditPositionOffset")
    SubscribeToEvent(positionOffsetZ, "TextChanged", "EditPositionOffset")
    SubscribeToEvent(randomRotationX, "TextChanged", "EditRandomRotation")
    SubscribeToEvent(randomRotationY, "TextChanged", "EditRandomRotation")
    SubscribeToEvent(randomRotationZ, "TextChanged", "EditRandomRotation")
    SubscribeToEvent(randomScaleMinEdit, "TextChanged", "EditRandomScale")
    SubscribeToEvent(randomScaleMaxEdit, "TextChanged", "EditRandomScale")
    SubscribeToEvent(spawnRadiusEdit, "TextChanged", "EditSpawnRadius")
    SubscribeToEvent(spawnCountEdit, "TextChanged", "EditSpawnCount")
    SubscribeToEvent(useNormalToggle, "Toggled", "ToggleUseNormal")
    SubscribeToEvent(alignToAABBBottomToggle, "Toggled", "ToggleAlignToAABBBottom")
    SubscribeToEvent(spawnOnSelectionToggle, "Toggled", "ToggleSpawnOnSelected")
    SubscribeToEvent(numberSpawnedObjectsEdit, "TextFinished", "UpdateNumberSpawnedObjects")
    SubscribeToEvent(spawnWindow:GetChild("SetSpawnMode", true), "Released", "SetSpawnMode")
    RefreshPickedObjects()
end

function ToggleSpawnEditor()
    if spawnWindow.visible == false then
        ShowSpawnEditor()
    else
        HideSpawnEditor()
    end
    return true
end

function ShowSpawnEditor()
    spawnWindow.visible = true
    spawnWindow:BringToFront()
end

function HideSpawnEditor()
    spawnWindow.visible = false
end

function PickSpawnObject()
    resourcePicker = GetResourcePicker(StringHash("Node"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath == "" then
        lastPath = sceneResourcePath
    end
    CreateFileSelector(localization:Get("Pick ") .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter, false)
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickSpawnObjectDone")
end

function EditPositionOffset(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    positionOffset = Vector3(tonumber(positionOffsetX.text) or 0, tonumber(positionOffsetY.text) or 0, tonumber(positionOffsetZ.text) or 0)
    UpdateHierarchyItem(editorScene)
end

function EditRandomRotation(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    randomRotation = Vector3(tonumber(randomRotationX.text) or 0, tonumber(randomRotationY.text) or 0, tonumber(randomRotationZ.text) or 0)
    UpdateHierarchyItem(editorScene)
end

function EditRandomScale(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    randomScaleMin = tonumber(randomScaleMinEdit.text) or 1
    randomScaleMax = tonumber(randomScaleMaxEdit.text) or 1
    UpdateHierarchyItem(editorScene)
end

function ToggleUseNormal(eventType, eventData)
    useNormal = eventData["Element"]:GetPtr().checked
end

function ToggleAlignToAABBBottom(eventType, eventData)
    alignToAABBBottom = eventData["Element"]:GetPtr().checked
end

function ToggleSpawnOnSelected(eventType, eventData)
    spawnOnSelection = eventData["Element"]:GetPtr().checked
end

function UpdateNumberSpawnedObjects(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    numberSpawnedObjects = tonumber(edit.text) or 1
    edit.text = tostring(numberSpawnedObjects)
    RefreshPickedObjects()
end

function EditSpawnRadius(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    spawnRadius = tonumber(edit.text) or 0
end

function EditSpawnCount(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    spawnCount = tonumber(edit.text) or 1
end

function RefreshPickedObjects()
    -- Resize array
    for i = 1, numberSpawnedObjects do
        if spawnedObjectsNames[i] == nil then
            spawnedObjectsNames[i] = ""
        end
    end

    local list = spawnWindow:GetChild("SpawnedObjects", true)
    list:RemoveAllItems()

    for i = 1, numberSpawnedObjects do
        local parent = CreateAttributeEditorParentWithSeparatedLabel(list, "Object " .. tostring(i), i - 1, 0, false)

        local container = UIElement()
        container:SetLayout(LM_HORIZONTAL, 4, IntRect(10, 0, 4, 0))
        container:SetFixedHeight(ATTR_HEIGHT)
        parent:AddChild(container)

        local nameEdit = CreateAttributeLineEdit(container, nil, i - 1, 0)
        nameEdit.name = "TextureNameEdit" .. tostring(i - 1)

        local pickButton = CreateResourcePickerButton(container, nil, i - 1, 0, "smallButtonPick")
        SubscribeToEvent(pickButton, "Released", "PickSpawnedObject")
        nameEdit.text = spawnedObjectsNames[i]

        SubscribeToEvent(nameEdit, "TextFinished", "EditSpawnedObjectName")
    end
end

function EditSpawnedObjectName(eventType, eventData)
    local nameEdit = eventData["Element"]:GetPtr()
    local index = nameEdit:GetVar("Index"):GetUInt()
    local resourceName = VerifySpawnedObjectFile(nameEdit.text)
    nameEdit.text = resourceName
    spawnedObjectsNames[index + 1] = resourceName
end

function VerifySpawnedObjectFile(resourceName)
    local file = cache:GetFile(resourceName)
    if file ~= nil then
        return resourceName
    else
        return ""
    end
end

function PickSpawnedObject(eventType, eventData)
    local button = eventData["Element"]:GetPtr()
    resourcePickIndex = button:GetVar("Index"):GetUInt()
    CreateFileSelector("Pick spawned object", "Pick", "Cancel", uiNodePath, uiSceneFilters, uiNodeFilter)

    SubscribeToEvent(uiFileSelector, "FileSelected", "PickSpawnedObjectNameDone")
end

function PickSpawnedObjectNameDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local resourceName = GetResourceNameFromFullName(eventData["FileName"]:GetString())
    spawnedObjectsNames[resourcePickIndex + 1] = VerifySpawnedObjectFile(resourceName)
    resourcePicker = nil
    RefreshPickedObjects()
end

function SetSpawnMode(eventType, eventData)
    editMode = EDIT_SPAWN
end

function PlaceObject(spawnPosition, normal)
    local spawnRotation = Quaternion()
    if useNormal then
        spawnRotation = Quaternion(Vector3(0, 1, 0), normal)
    end
    spawnRotation = Quaternion(math.random() * randomRotation.x * 2 - randomRotation.x,
        math.random() * randomRotation.y * 2 - randomRotation.y,
        math.random() * randomRotation.z * 2 - randomRotation.z) * spawnRotation

    local number = math.random(1, #spawnedObjectsNames)
    local file = cache:GetFile(spawnedObjectsNames[number])
    local scale = randomScaleMin + math.random() * (randomScaleMax - randomScaleMin)
    local spawnedObject = InstantiateNodeFromFile(file, spawnPosition + (spawnRotation * positionOffset), spawnRotation, scale)
    if spawnedObject == nil then
        spawnedObjectsNames[number] = spawnedObjectsNames[#spawnedObjectsNames]
        numberSpawnedObjects = numberSpawnedObjects - 1
        RefreshPickedObjects()
        return
    end
end

function GetSpawnPosition(cameraRay, maxDistance, randomRadius, allowNoHit)
    if randomRadius == nil then randomRadius = 0.0 end
    if allowNoHit == nil then allowNoHit = true end

    local position = Vector3()
    local normal = Vector3()

    if pickMode < PICK_RIGIDBODIES and editorScene.octree ~= nil then
        local result = editorScene.octree:RaycastSingle(cameraRay, RAY_TRIANGLE, maxDistance, DRAWABLE_GEOMETRY, 0x7fffffff)
        if result.drawable ~= nil then
            if randomRadius > 0 then
                local basePosition = RandomizeSpawnPosition(result.position, randomRadius)
                basePosition.y = basePosition.y + randomRadius
                result = editorScene.octree:RaycastSingle(Ray(basePosition, Vector3(0, -1, 0)), RAY_TRIANGLE, randomRadius * 2.0,
                    DRAWABLE_GEOMETRY, 0x7fffffff)
                if result.drawable ~= nil then
                    position = result.position
                    normal = result.normal
                    return true, position, normal
                end
            else
                position = result.position
                normal = result.normal
                return true, position, normal
            end
        end
    elseif editorScene.physicsWorld ~= nil then
        -- If we are not running the actual physics update, refresh collisions before raycasting
        if not runUpdate then
            editorScene.physicsWorld:UpdateCollisions()
        end

        local result = editorScene.physicsWorld:RaycastSingle(cameraRay, maxDistance)

        if result.body ~= nil then
            if randomRadius > 0 then
                local basePosition = RandomizeSpawnPosition(result.position, randomRadius)
                basePosition.y = basePosition.y + randomRadius
                result = editorScene.physicsWorld:RaycastSingle(Ray(basePosition, Vector3(0, -1, 0)), randomRadius * 2.0)
                if result.body ~= nil then
                    position = result.position
                    normal = result.normal
                    return true, position, normal
                end
            else
                position = result.position
                normal = result.normal
                return true, position, normal
            end
        end
    end

    position = cameraRay.origin + cameraRay.direction * maxDistance
    normal = Vector3(0, 1, 0)
    return allowNoHit, position, normal
end

function GetSpawnPositionOnNode(cameraRay, maxDistance, node, randomRadius, allowNoHit)
    if randomRadius == nil then randomRadius = 0.0 end
    if allowNoHit == nil then allowNoHit = true end

    local position = Vector3()
    local normal = Vector3()

    if pickMode < PICK_RIGIDBODIES and editorScene.octree ~= nil then
        local results = editorScene.octree:Raycast(cameraRay, RAY_TRIANGLE, maxDistance, DRAWABLE_GEOMETRY, 0x7fffffff)

        if #results > 0 then
            local result = results[1]

            for i = 1, #results do
                if results[i].node == node then
                    result = results[i]
                    break
                end
            end

            if randomRadius > 0 then
                local basePosition = RandomizeSpawnPosition(result.position, randomRadius)
                basePosition.y = basePosition.y + randomRadius
                local randomResults = editorScene.octree:Raycast(Ray(basePosition, Vector3(0, -1, 0)), RAY_TRIANGLE, randomRadius * 2.0, DRAWABLE_GEOMETRY, 0x7fffffff)

                if #randomResults == 0 then
                    position = result.position
                    normal = result.normal
                    return true, position, normal
                end

                result = randomResults[1]

                -- Find node in results
                for i = 1, #randomResults do
                    if randomResults[i].node == node then
                        result = randomResults[i]
                        break
                    end
                end

                position = result.position
                normal = result.normal
                return true, position, normal
            else
                position = result.position
                normal = result.normal
                return true, position, normal
            end
        end
    end

    position = cameraRay.origin + cameraRay.direction * maxDistance
    normal = Vector3(0, 1, 0)
    return allowNoHit, position, normal
end

function RandomizeSpawnPosition(position, randomRadius)
    local angle = math.random() * 360.0
    local distance = math.random() * randomRadius
    return position + Quaternion(0, angle, 0) * Vector3(0, 0, distance)
end

function SpawnObject()
    local selectedNode = nil

    if spawnOnSelection then
        if #selectedNodes > 0 then
            selectedNode = selectedNodes[1]
        end
    end

    if #spawnedObjectsNames == 0 then
        return
    end

    local view = activeViewport.viewport.rect

    for i = 1, spawnCount do
        local cameraRay = GetActiveViewportCameraRay()
        local position, normal
        local result = false

        if spawnOnSelection and selectedNode ~= nil then
            result, position, normal = GetSpawnPositionOnNode(cameraRay, camera.farClip, selectedNode, spawnRadius, false)
        else
            result, position, normal = GetSpawnPosition(cameraRay, camera.farClip, spawnRadius, false)
        end

        if result then
            PlaceObject(position, normal)
        end
    end
end
