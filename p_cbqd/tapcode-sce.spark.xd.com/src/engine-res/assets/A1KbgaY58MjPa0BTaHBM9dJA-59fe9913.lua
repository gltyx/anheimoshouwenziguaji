-- Urho3D material editor
-- Converted from AngelScript to Lua

-- Helper function to get texture unit name
function GetTextureUnitName(unit)
    local names = {"diffuse", "normal", "specular", "emissive", "environment", "lightramp", "lightshape", "shadowmap"}
    if unit >= 0 and unit < #names then
        return names[unit + 1]  -- Lua 1-based
    end
    return "custom" .. unit
end

-- Material editor global variables
materialWindow = nil
editMaterial = nil
oldMaterialState = nil
inMaterialRefresh = true
materialPreview = nil
previewScene = nil
previewCameraNode = nil
previewLightNode = nil
previewLight = nil
previewModelNode = nil
previewModel = nil

function CreateMaterialEditor()
    if materialWindow ~= nil then
        return
    end

    materialWindow = LoadEditorUI("UI/EditorMaterialWindow.xml")
    ui.root:AddChild(materialWindow)
    materialWindow.opacity = uiMaxOpacity

    InitMaterialPreview()
    InitModelPreviewList()
    RefreshMaterialEditor()

    local height = math.min(ui.root.height - 60, 600)
    materialWindow:SetSize(400, height)
    CenterDialog(materialWindow)

    HideMaterialEditor()

    SubscribeToEvent(materialWindow:GetChild("NewButton", true), "Released", "NewMaterial")
    SubscribeToEvent(materialWindow:GetChild("RevertButton", true), "Released", "RevertMaterial")
    SubscribeToEvent(materialWindow:GetChild("SaveButton", true), "Released", "SaveMaterial")
    SubscribeToEvent(materialWindow:GetChild("SaveAsButton", true), "Released", "SaveMaterialAs")
    SubscribeToEvent(materialWindow:GetChild("CloseButton", true), "Released", "HideMaterialEditor")
    SubscribeToEvent(materialWindow:GetChild("NewParameterDropDown", true), "ItemSelected", "CreateShaderParameter")
    SubscribeToEvent(materialWindow:GetChild("DeleteParameterButton", true), "Released", "DeleteShaderParameter")
    SubscribeToEvent(materialWindow:GetChild("NewTechniqueButton", true), "Released", "NewTechnique")
    SubscribeToEvent(materialWindow:GetChild("DeleteTechniqueButton", true), "Released", "DeleteTechnique")
    SubscribeToEvent(materialWindow:GetChild("SortTechniquesButton", true), "Released", "SortTechniques")
    SubscribeToEvent(materialWindow:GetChild("VSDefinesEdit", true), "TextFinished", "EditVSDefines")
    SubscribeToEvent(materialWindow:GetChild("PSDefinesEdit", true), "TextFinished", "EditPSDefines")
    SubscribeToEvent(materialWindow:GetChild("ConstantBiasEdit", true), "TextChanged", "EditConstantBias")
    SubscribeToEvent(materialWindow:GetChild("ConstantBiasEdit", true), "TextFinished", "EditConstantBias")
    SubscribeToEvent(materialWindow:GetChild("SlopeBiasEdit", true), "TextChanged", "EditSlopeBias")
    SubscribeToEvent(materialWindow:GetChild("SlopeBiasEdit", true), "TextFinished", "EditSlopeBias")
    SubscribeToEvent(materialWindow:GetChild("RenderOrderEdit", true), "TextChanged", "EditRenderOrder")
    SubscribeToEvent(materialWindow:GetChild("RenderOrderEdit", true), "TextFinished", "EditRenderOrder")
    SubscribeToEvent(materialWindow:GetChild("CullModeEdit", true), "ItemSelected", "EditCullMode")
    SubscribeToEvent(materialWindow:GetChild("ShadowCullModeEdit", true), "ItemSelected", "EditShadowCullMode")
    SubscribeToEvent(materialWindow:GetChild("FillModeEdit", true), "ItemSelected", "EditFillMode")
    SubscribeToEvent(materialWindow:GetChild("OcclusionEdit", true), "Toggled", "EditOcclusion")
    SubscribeToEvent(materialWindow:GetChild("AlphaToCoverageEdit", true), "Toggled", "EditAlphaToCoverage")
    SubscribeToEvent(materialWindow:GetChild("LineAntiAliasEdit", true), "Toggled", "EditLineAntiAlias")
end

function ToggleMaterialEditor()
    if materialWindow.visible == false then
        ShowMaterialEditor()
    else
        HideMaterialEditor()
    end
    return true
end

function ShowMaterialEditor()
    RefreshMaterialEditor()
    materialWindow.visible = true
    materialWindow:BringToFront()
end

function HideMaterialEditor()
    materialWindow.visible = false
end

function InitMaterialPreview()
    previewScene = Scene()
    previewScene.name = "PreviewScene"
    previewScene:CreateComponent("Octree")

    local zoneNode = previewScene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.ambientColor = Color(0.15, 0.15, 0.15)
    zone.fogColor = Color(0, 0, 0)
    zone.fogStart = 10.0
    zone.fogEnd = 100.0

    previewCameraNode = previewScene:CreateChild("PreviewCamera")
    previewCameraNode.position = Vector3(0, 0, -1.5)
    local camera = previewCameraNode:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 100.0

    previewLightNode = previewScene:CreateChild("PreviewLight")
    previewLightNode.direction = Vector3(0.5, -0.5, 0.5)
    previewLight = previewLightNode:CreateComponent("Light")
    previewLight.lightType = LIGHT_DIRECTIONAL
    previewLight.specularIntensity = 0.5

    previewModelNode = previewScene:CreateChild("PreviewModel")
    previewModelNode.rotation = Quaternion(0, 0, 0)
    previewModel = previewModelNode:CreateComponent("StaticModel")
    previewModel.model = cache:GetResource("Model", "Models/Sphere.mdl")

    materialPreview = materialWindow:GetChild("MaterialPreview", true)
    materialPreview:SetFixedHeight(100)
    materialPreview:SetView(previewScene, camera)

    -- Set render path (viewport may not be available immediately)
    if materialPreview.viewport ~= nil then
        materialPreview.viewport.renderPath = renderPath
    end
    materialPreview.autoUpdate = false

    SubscribeToEvent(materialPreview, "DragMove", "RotateMaterialPreview")
end

function InitModelPreviewList()
    local modelPreview = materialWindow:GetChild("ModelPreview", true)
    modelPreview.selection = 1
    SubscribeToEvent(materialWindow:GetChild("ModelPreview", true), "ItemSelected", "EditModelPreviewChange")
end

function EditMaterial(mat)
    if editMaterial ~= nil then
        UnsubscribeFromEvent(editMaterial, "ReloadFinished")
    end

    editMaterial = mat

    if editMaterial ~= nil then
        SubscribeToEvent(editMaterial, "ReloadFinished", "RefreshMaterialEditor")
    end

    ShowMaterialEditor()
end

function RefreshMaterialEditor()
    RefreshMaterialPreview()
    RefreshMaterialName()
    RefreshMaterialTechniques()
    RefreshMaterialTextures()
    RefreshMaterialShaderParameters()
    RefreshMaterialMiscParameters()
end

function RefreshMaterialPreview()
    previewModel.material = editMaterial
    materialPreview:QueueUpdate()
end

function RefreshMaterialName()
    local container = materialWindow:GetChild("NameContainer", true)
    container:RemoveAllChildren()

    local nameEdit = CreateAttributeLineEdit(container, nil, 0, 0)
    if editMaterial ~= nil then
        nameEdit.text = editMaterial.name
    end
    SubscribeToEvent(nameEdit, "TextFinished", "EditMaterialName")

    local pickButton = CreateResourcePickerButton(container, nil, 0, 0, "smallButtonPick")
    SubscribeToEvent(pickButton, "Released", "PickEditMaterial")
end

function RefreshMaterialTechniques(fullUpdate)
    if fullUpdate == nil then fullUpdate = true end
    local list = materialWindow:GetChild("TechniqueList", true)

    if editMaterial == nil then
        return
    end

    if fullUpdate == true then
        list:RemoveAllItems()

        for i = 0, editMaterial.numTechniques - 1 do
            local entry = editMaterial:GetTechniqueEntry(i)

            local container = UIElement()
            container:SetLayout(LM_HORIZONTAL, 4)
            container:SetFixedHeight(ATTR_HEIGHT)
            list:AddItem(container)

            local nameEdit = CreateAttributeLineEdit(container, nil, i, 0)
            nameEdit.name = "TechniqueNameEdit" .. tostring(i)

            local pickButton = CreateResourcePickerButton(container, nil, i, 0, "smallButtonPick")
            SubscribeToEvent(pickButton, "Released", "PickMaterialTechnique")
            local openButton = CreateResourcePickerButton(container, nil, i, 0, "smallButtonOpen")
            SubscribeToEvent(openButton, "Released", "OpenResource")

            if entry.technique ~= nil then
                nameEdit.text = entry.technique.name
            end

            SubscribeToEvent(nameEdit, "TextFinished", "EditMaterialTechnique")

            local container2 = UIElement()
            container2:SetLayout(LM_HORIZONTAL, 4)
            container2:SetFixedHeight(ATTR_HEIGHT)
            list:AddItem(container2)

            local text = container2:CreateChild("Text")
            text:SetStyle("EditorAttributeText")
            text.text = "Quality"
            local attrEdit = CreateAttributeLineEdit(container2, nil, i, 0)
            attrEdit.text = tostring(entry.qualityLevel)
            SubscribeToEvent(attrEdit, "TextChanged", "EditTechniqueQuality")
            SubscribeToEvent(attrEdit, "TextFinished", "EditTechniqueQuality")

            text = container2:CreateChild("Text")
            text:SetStyle("EditorAttributeText")
            text.text = "LOD Distance"
            attrEdit = CreateAttributeLineEdit(container2, nil, i, 0)
            attrEdit.text = tostring(entry.lodDistance)
            SubscribeToEvent(attrEdit, "TextChanged", "EditTechniqueLodDistance")
            SubscribeToEvent(attrEdit, "TextFinished", "EditTechniqueLodDistance")
        end
    else
        for i = 0, editMaterial.numTechniques - 1 do
            local entry = editMaterial:GetTechniqueEntry(i)

            local nameEdit = materialWindow:GetChild("TechniqueNameEdit" .. tostring(i), true)
            if nameEdit == nil then
                goto continue
            end

            nameEdit.text = entry.technique ~= nil and entry.technique.name or ""
            ::continue::
        end
    end
end

function RefreshMaterialTextures(fullUpdate)
    if fullUpdate == nil then fullUpdate = true end

    if fullUpdate then
        local list = materialWindow:GetChild("TextureList", true)
        list:RemoveAllItems()

        for i = 0, MAX_MATERIAL_TEXTURE_UNITS - 1 do
            local tuName = GetTextureUnitName(i)
            tuName = string.upper(string.sub(tuName, 1, 1)) .. string.sub(tuName, 2)

            local parent = CreateAttributeEditorParentWithSeparatedLabel(list, "Unit " .. i .. " " .. tuName, i, 0, false)

            local container = UIElement()
            container:SetLayout(LM_HORIZONTAL, 4, IntRect(10, 0, 4, 0))
            container:SetFixedHeight(ATTR_HEIGHT)
            parent:AddChild(container)

            local nameEdit = CreateAttributeLineEdit(container, nil, i, 0)
            nameEdit.name = "TextureNameEdit" .. tostring(i)

            local pickButton = CreateResourcePickerButton(container, nil, i, 0, "smallButtonPick")
            SubscribeToEvent(pickButton, "Released", "PickMaterialTexture")
            local openButton = CreateResourcePickerButton(container, nil, i, 0, "smallButtonOpen")
            SubscribeToEvent(openButton, "Released", "OpenResource")

            if editMaterial ~= nil then
                local texture = editMaterial:GetTexture(i)
                if texture ~= nil then
                    nameEdit.text = texture.name
                end
            end

            SubscribeToEvent(nameEdit, "TextFinished", "EditMaterialTexture")
        end
    else
        for i = 0, MAX_MATERIAL_TEXTURE_UNITS - 1 do
            local nameEdit = materialWindow:GetChild("TextureNameEdit" .. tostring(i), true)
            if nameEdit == nil then
                goto continue
            end

            local textureName = ""
            if editMaterial ~= nil then
                local texture = editMaterial:GetTexture(i)
                if texture ~= nil then
                    textureName = texture.name
                end
            end

            nameEdit.text = textureName
            ::continue::
        end
    end
end

function RefreshMaterialShaderParameters()
    local list = materialWindow:GetChild("ShaderParameterList", true)
    list:RemoveAllItems()
    if editMaterial == nil then
        return
    end

    local parameterNames = editMaterial.shaderParameterNames

    for i = 1, #parameterNames do
        local varType = editMaterial:GetShaderParameter(parameterNames[i]).type
        local value = editMaterial:GetShaderParameter(parameterNames[i])
        local parent = CreateAttributeEditorParent(list, parameterNames[i], 0, 0)
        local numCoords = 1
        if varType >= VAR_VECTOR2 and varType <= VAR_VECTOR4 then
            numCoords = varType - VAR_FLOAT + 1
        end

        local coordValues = {}
        local valueStr = value:ToString()
        for coord in string.gmatch(valueStr, "[^%s]+") do
            table.insert(coordValues, coord)
        end

        for j = 1, numCoords do
            local attrEdit = CreateAttributeLineEdit(parent, nil, 0, 0)
            attrEdit:SetVar("Coordinate", Variant(j - 1))
            attrEdit:SetVar("Name", Variant(parameterNames[i]))
            attrEdit.text = coordValues[j] or "0"

            CreateDragSlider(attrEdit)

            SubscribeToEvent(attrEdit, "TextChanged", "EditShaderParameter")
            SubscribeToEvent(attrEdit, "TextFinished", "EditShaderParameter")
        end
    end
end

function RefreshMaterialMiscParameters()
    if editMaterial == nil then
        return
    end

    inMaterialRefresh = true

    local bias = editMaterial.depthBias
    local attrEdit = materialWindow:GetChild("ConstantBiasEdit", true)
    attrEdit.text = tostring(bias.constantBias)
    attrEdit = materialWindow:GetChild("SlopeBiasEdit", true)
    attrEdit.text = tostring(bias.slopeScaledBias)
    attrEdit = materialWindow:GetChild("RenderOrderEdit", true)
    attrEdit.text = tostring(editMaterial.renderOrder)
    attrEdit = materialWindow:GetChild("VSDefinesEdit", true)
    attrEdit.text = editMaterial.vertexShaderDefines
    attrEdit = materialWindow:GetChild("PSDefinesEdit", true)
    attrEdit.text = editMaterial.pixelShaderDefines

    local attrList = materialWindow:GetChild("CullModeEdit", true)
    attrList.selection = editMaterial.cullMode
    attrList = materialWindow:GetChild("ShadowCullModeEdit", true)
    attrList.selection = editMaterial.shadowCullMode
    attrList = materialWindow:GetChild("FillModeEdit", true)
    attrList.selection = editMaterial.fillMode

    local attrCheckBox = materialWindow:GetChild("OcclusionEdit", true)
    attrCheckBox.checked = editMaterial.occlusion
    attrCheckBox = materialWindow:GetChild("AlphaToCoverageEdit", true)
    attrCheckBox.checked = editMaterial.alphaToCoverage
    attrCheckBox = materialWindow:GetChild("LineAntiAliasEdit", true)
    attrCheckBox.checked = editMaterial.lineAntiAlias

    inMaterialRefresh = false
end

function RotateMaterialPreview(eventType, eventData)
    local elemX = eventData["ElementX"]:GetInt()
    local elemY = eventData["ElementY"]:GetInt()

    if materialPreview.height > 0 and materialPreview.width > 0 then
        local yaw = ((materialPreview.height / 2) - elemY) * (90.0 / materialPreview.height)
        local pitch = ((materialPreview.width / 2) - elemX) * (90.0 / materialPreview.width)

        previewModelNode.rotation = previewModelNode.rotation:Slerp(Quaternion(yaw, pitch, 0), 0.1)
        materialPreview:QueueUpdate()
    end
end

function EditMaterialName(eventType, eventData)
    local nameEdit = eventData["Element"]:GetPtr()
    local newMaterialName = nameEdit.text:Trimmed()
    if newMaterialName ~= "" then
        local newMaterial = cache:GetResource("Material", newMaterialName)
        if newMaterial ~= nil then
            EditMaterial(newMaterial)
        end
    end
end

function PickEditMaterial()
    resourcePicker = GetResourcePicker(StringHash("Material"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath == "" then
        lastPath = sceneResourcePath
    end
    CreateFileSelector(localization:Get("Pick ") .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter, false)
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickEditMaterialDone")
end

function PickEditMaterialDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local resourceName = eventData["FileName"]:GetString()
    local res = GetPickedResource(resourceName)

    if res ~= nil then
        EditMaterial(res)
    end

    resourcePicker = nil
end

function NewMaterial()
    EditMaterial(Material())
end

function RevertMaterial()
    if editMaterial == nil then
        return
    end

    BeginMaterialEdit()
    cache:ReloadResource(editMaterial)
    EndMaterialEdit()

    RefreshMaterialEditor()
end

function SaveMaterial()
    if editMaterial == nil or editMaterial.name == "" then
        return
    end

    local fullName = cache:GetResourceFileName(editMaterial.name)
    if fullName == "" then
        return
    end

    MakeBackup(fullName)
    local saveFile = File(fullName, FILE_WRITE)
    local success
    if GetExtension(fullName) == ".json" then
        local json = JSONFile()
        editMaterial:Save(json.root)
        success = json:Save(saveFile)
    else
        success = editMaterial:Save(saveFile)
    end
    RemoveBackup(success, fullName)
end

function SaveMaterialAs()
    if editMaterial == nil then
        return
    end

    resourcePicker = GetResourcePicker(StringHash("Material"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath == "" then
        lastPath = sceneResourcePath
    end
    CreateFileSelector("Save material as", "Save", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter)
    SubscribeToEvent(uiFileSelector, "FileSelected", "SaveMaterialAsDone")
end

function SaveMaterialAsDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()
    resourcePicker = nil

    if editMaterial == nil then
        return
    end

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local fullName = eventData["FileName"]:GetString()

    -- Add default extension for saving if not specified
    local filter = eventData["Filter"]:GetString()
    if GetExtension(fullName) == "" and filter ~= "*.*" then
        fullName = fullName .. string.sub(filter, 2)
    end

    MakeBackup(fullName)
    local saveFile = File(fullName, FILE_WRITE)
    local success
    if GetExtension(fullName) == ".json" then
        local json = JSONFile()
        editMaterial:Save(json.root)
        success = json:Save(saveFile)
    else
        success = editMaterial:Save(saveFile)
    end

    if success then
        saveFile:Close()
        RemoveBackup(true, fullName)

        -- Load the new resource to update the name in the editor
        local newMat = cache:GetResource("Material", GetResourceNameFromFullName(fullName))
        if newMat ~= nil then
            EditMaterial(newMat)
        end
    end
end

function EditModelPreviewChange(eventType, eventData)
    if materialPreview == nil then
        return
    end

    previewModelNode.scale = Vector3(1.0, 1.0, 1.0)

    local element = eventData["Element"]:GetPtr()

    if element.selection == 0 then
        previewModel.model = cache:GetResource("Model", "Models/Box.mdl")
    elseif element.selection == 1 then
        previewModel.model = cache:GetResource("Model", "Models/Sphere.mdl")
    elseif element.selection == 2 then
        previewModel.model = cache:GetResource("Model", "Models/Plane.mdl")
    elseif element.selection == 3 then
        previewModel.model = cache:GetResource("Model", "Models/Cylinder.mdl")
        previewModelNode.scale = Vector3(0.8, 0.8, 0.8)
    elseif element.selection == 4 then
        previewModel.model = cache:GetResource("Model", "Models/Cone.mdl")
    elseif element.selection == 5 then
        previewModel.model = cache:GetResource("Model", "Models/TeaPot.mdl")
    end

    materialPreview:QueueUpdate()
end

function EditShaderParameter(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local attrEdit = eventData["Element"]:GetPtr()
    local coordinate = attrEdit:GetVar("Coordinate"):GetUInt()

    local name = attrEdit:GetVar("Name"):GetString()

    local oldValue = editMaterial:GetShaderParameter(name)
    local coordValues = {}
    local oldValueStr = oldValue:ToString()
    for coord in string.gmatch(oldValueStr, "[^%s]+") do
        table.insert(coordValues, coord)
    end

    if oldValue.type ~= VAR_BOOL then
        coordValues[coordinate + 1] = tostring(tonumber(attrEdit.text))
    else
        coordValues[coordinate + 1] = attrEdit.text
    end

    local valueString = ""
    for i = 1, #coordValues do
        valueString = valueString .. coordValues[i]
        valueString = valueString .. " "
    end

    local newValue = Variant()
    newValue:FromString(oldValue.type, valueString)

    BeginMaterialEdit()
    editMaterial:SetShaderParameter(name, newValue)
    EndMaterialEdit()
end

function CreateShaderParameter(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local nameEdit = materialWindow:GetChild("ParameterNameEdit", true)
    local newName = nameEdit.text:Trimmed()
    if newName == "" then
        return
    end

    local dropDown = eventData["Element"]:GetPtr()
    local newValue

    if dropDown.selection == 0 then
        newValue = Variant(0.0)
    elseif dropDown.selection == 1 then
        newValue = Variant(Vector2(0, 0))
    elseif dropDown.selection == 2 then
        newValue = Variant(Vector3(0, 0, 0))
    elseif dropDown.selection == 3 then
        newValue = Variant(Vector4(0, 0, 0, 0))
    elseif dropDown.selection == 4 then
        newValue = Variant(0)
    elseif dropDown.selection == 5 then
        newValue = Variant(false)
    end

    BeginMaterialEdit()
    editMaterial:SetShaderParameter(newName, newValue)
    EndMaterialEdit()

    RefreshMaterialShaderParameters()
end

function DeleteShaderParameter()
    if editMaterial == nil then
        return
    end

    local nameEdit = materialWindow:GetChild("ParameterNameEdit", true)
    local name = nameEdit.text:Trimmed()
    if name == "" then
        return
    end

    BeginMaterialEdit()
    editMaterial:RemoveShaderParameter(name)
    EndMaterialEdit()

    RefreshMaterialShaderParameters()
end

function PickMaterialTexture(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local button = eventData["Element"]:GetPtr()
    resourcePickIndex = button:GetVar("Index"):GetUInt()

    resourcePicker = GetResourcePicker(StringHash("Texture2D"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath == "" then
        lastPath = sceneResourcePath
    end
    CreateFileSelector(localization:Get("Pick ") .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter, false)
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickMaterialTextureDone")
end

function PickMaterialTextureDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local resourceName = eventData["FileName"]:GetString()
    local res = GetPickedResource(resourceName)

    if res ~= nil and editMaterial ~= nil then
        BeginMaterialEdit()
        editMaterial:SetTexture(resourcePickIndex, res)
        EndMaterialEdit()

        RefreshMaterialTextures(false)
    end

    resourcePicker = nil
end

function EditMaterialTexture(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local attrEdit = eventData["Element"]:GetPtr()
    local textureName = attrEdit.text:Trimmed()
    local index = attrEdit:GetVar("Index"):GetUInt()

    BeginMaterialEdit()

    if textureName ~= "" then
        local textureType = GetExtension(textureName) == ".xml" and "TextureCube" or "Texture2D"
        local texture = cache:GetResource(textureType, textureName)
        editMaterial:SetTexture(index, texture)
    else
        editMaterial:SetTexture(index, nil)
    end

    EndMaterialEdit()
end

function NewTechnique()
    if editMaterial == nil then
        return
    end

    BeginMaterialEdit()
    editMaterial.numTechniques = editMaterial.numTechniques + 1
    EndMaterialEdit()

    RefreshMaterialTechniques()
end

function DeleteTechnique()
    if editMaterial == nil or editMaterial.numTechniques < 2 then
        return
    end

    BeginMaterialEdit()
    editMaterial.numTechniques = editMaterial.numTechniques - 1
    EndMaterialEdit()

    RefreshMaterialTechniques()
end

function PickMaterialTechnique(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local button = eventData["Element"]:GetPtr()
    resourcePickIndex = button:GetVar("Index"):GetUInt()

    resourcePicker = GetResourcePicker(StringHash("Technique"))
    if resourcePicker == nil then
        return
    end

    local lastPath = resourcePicker.lastPath
    if lastPath == "" then
        lastPath = sceneResourcePath
    end
    CreateFileSelector(localization:Get("Pick ") .. resourcePicker.typeName, "OK", "Cancel", lastPath, resourcePicker.filters, resourcePicker.lastFilter, false)
    SubscribeToEvent(uiFileSelector, "FileSelected", "PickMaterialTechniqueDone")
end

function PickMaterialTechniqueDone(eventType, eventData)
    StoreResourcePickerPath()
    CloseFileSelector()

    if not eventData["OK"]:GetBool() then
        resourcePicker = nil
        return
    end

    local resourceName = eventData["FileName"]:GetString()
    local res = GetPickedResource(resourceName)

    if res ~= nil and editMaterial ~= nil then
        BeginMaterialEdit()
        local entry = editMaterial:GetTechniqueEntry(resourcePickIndex)
        editMaterial:SetTechnique(resourcePickIndex, res, entry.qualityLevel, entry.lodDistance)
        EndMaterialEdit()

        RefreshMaterialTechniques(false)
    end

    resourcePicker = nil
end

function EditMaterialTechnique(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local attrEdit = eventData["Element"]:GetPtr()
    local techniqueName = attrEdit.text:Trimmed()
    local index = attrEdit:GetVar("Index"):GetUInt()

    BeginMaterialEdit()

    local newTech
    if techniqueName ~= "" then
        newTech = cache:GetResource("Technique", techniqueName)
    end

    local entry = editMaterial:GetTechniqueEntry(index)
    editMaterial:SetTechnique(index, newTech, entry.qualityLevel, entry.lodDistance)

    EndMaterialEdit()
end

function EditTechniqueQuality(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local attrEdit = eventData["Element"]:GetPtr()
    local newQualityLevel = tonumber(attrEdit.text) or 0
    local index = attrEdit:GetVar("Index"):GetUInt()

    BeginMaterialEdit()
    local entry = editMaterial:GetTechniqueEntry(index)
    editMaterial:SetTechnique(index, entry.technique, newQualityLevel, entry.lodDistance)
    EndMaterialEdit()
end

function EditTechniqueLodDistance(eventType, eventData)
    if editMaterial == nil then
        return
    end

    local attrEdit = eventData["Element"]:GetPtr()
    local newLodDistance = tonumber(attrEdit.text) or 0.0
    local index = attrEdit:GetVar("Index"):GetUInt()

    BeginMaterialEdit()
    local entry = editMaterial:GetTechniqueEntry(index)
    editMaterial:SetTechnique(index, entry.technique, entry.qualityLevel, newLodDistance)
    EndMaterialEdit()
end

function SortTechniques()
    if editMaterial == nil then
        return
    end

    BeginMaterialEdit()
    editMaterial:SortTechniques()
    EndMaterialEdit()

    RefreshMaterialTechniques()
end

function EditConstantBias(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    local bias = editMaterial.depthBias
    bias.constantBias = tonumber(attrEdit.text) or 0.0
    editMaterial.depthBias = bias

    EndMaterialEdit()
end

function EditSlopeBias(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    local bias = editMaterial.depthBias
    bias.slopeScaledBias = tonumber(attrEdit.text) or 0.0
    editMaterial.depthBias = bias

    EndMaterialEdit()
end

function EditRenderOrder(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.renderOrder = tonumber(attrEdit.text) or 0

    EndMaterialEdit()
end

function EditCullMode(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.cullMode = attrEdit.selection

    EndMaterialEdit()
end

function EditShadowCullMode(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.shadowCullMode = attrEdit.selection

    EndMaterialEdit()
end

function EditFillMode(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.fillMode = attrEdit.selection

    EndMaterialEdit()
end

function EditOcclusion(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.occlusion = attrEdit.checked

    EndMaterialEdit()
end

function EditAlphaToCoverage(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.alphaToCoverage = attrEdit.checked

    EndMaterialEdit()
end

function EditLineAntiAlias(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.lineAntiAlias = attrEdit.checked

    EndMaterialEdit()
end

function EditVSDefines(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.vertexShaderDefines = attrEdit.text:Trimmed()

    EndMaterialEdit()
end

function EditPSDefines(eventType, eventData)
    if editMaterial == nil or inMaterialRefresh then
        return
    end

    BeginMaterialEdit()

    local attrEdit = eventData["Element"]:GetPtr()
    editMaterial.pixelShaderDefines = attrEdit.text:Trimmed()

    EndMaterialEdit()
end

function BeginMaterialEdit()
    if editMaterial == nil then
        return
    end

    oldMaterialState = XMLFile()
    local materialElem = oldMaterialState:CreateRoot("material")
    editMaterial:Save(materialElem)
end

function EndMaterialEdit()
    if editMaterial == nil then
        return
    end
    if not dragEditAttribute then
        local action = EditMaterialAction()
        action:Define(editMaterial, oldMaterialState)
        SaveEditAction(action)
    end

    materialPreview:QueueUpdate()
end
