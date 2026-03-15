--[[
EditorImport.lua - Urho3D Editor Import Functions

Provides asset import functionality including:
- Model importing (via AssetImporter)
- Animation importing
- Scene importing (including Tundra .txml format)
- Material and texture conversion
- Parent-child relationship handling
- Physics component setup

Converted from EditorImport.as
--]]

-- Import options
importOptions = "-t"

-- ParentAssignment class
ParentAssignment = {}
ParentAssignment.__index = ParentAssignment

function ParentAssignment:new()
    local self = setmetatable({}, ParentAssignment)
    self.childID = 0
    self.parentName = ""
    return self
end

-- AssetMapping class
AssetMapping = {}
AssetMapping.__index = AssetMapping

function AssetMapping:new()
    local self = setmetatable({}, AssetMapping)
    self.assetName = ""
    self.fullAssetName = ""
    return self
end

-- Global asset mappings
assetMappings = {}
assetImporterPath = ""

function ExecuteAssetImporter(args)
    if assetImporterPath == "" then
        local exeSuffix = ""
        if GetPlatform() == "Windows" then
            exeSuffix = ".exe"
        end

        assetImporterPath = fileSystem.programDir .. "tool/AssetImporter" .. exeSuffix
        if not fileSystem:FileExists(assetImporterPath) then
            assetImporterPath = fileSystem.programDir .. "AssetImporter" .. exeSuffix
        end
    end

    return fileSystem:SystemRun(assetImporterPath, args)
end

function ImportAnimation(fileName)
    if fileName == "" then
        return
    end

    ui.cursor.shape = CS_BUSY

    local modelName = "Models/" .. GetFileName(fileName) .. ".ani"
    local outFileName = sceneResourcePath .. modelName
    fileSystem:CreateDir(sceneResourcePath .. "Models")

    local args = {}
    table.insert(args, "anim")
    table.insert(args, "\"" .. fileName .. "\"")
    table.insert(args, "\"" .. outFileName .. "\"")
    table.insert(args, "-p \"" .. sceneResourcePath .. "\"")

    local options = importOptions:Trimmed():Split(' ')
    for i = 1, #options do
        table.insert(args, options[i])
    end

    if ExecuteAssetImporter(args) == 0 then
        -- Success
    else
        log:Error("Failed to execute AssetImporter to import model")
    end
end

function ImportModel(fileName)
    if fileName == "" then
        return
    end

    ui.cursor.shape = CS_BUSY

    local modelName = "Models/" .. GetFileName(fileName) .. ".mdl"
    local outFileName = sceneResourcePath .. modelName
    fileSystem:CreateDir(sceneResourcePath .. "Models")

    local args = {}
    table.insert(args, "model")
    table.insert(args, "\"" .. fileName .. "\"")
    table.insert(args, "\"" .. outFileName .. "\"")
    table.insert(args, "-p \"" .. sceneResourcePath .. "\"")

    local options = importOptions:Trimmed():Split(' ')
    for i = 1, #options do
        table.insert(args, options[i])
    end

    if applyMaterialList then
        table.insert(args, "-l")
    end

    if ExecuteAssetImporter(args) == 0 then
        local newNode = editorScene:CreateChild(GetFileName(fileName))
        local newModel = newNode:CreateComponent("StaticModel")
        newNode.position = GetNewNodePosition()
        newModel.model = cache:GetResource("Model", modelName)
        newModel:ApplyMaterialList()

        local action = CreateNodeAction()
        action:Define(newNode)
        SaveEditAction(action)
        SetSceneModified()

        FocusNode(newNode)
    else
        log:Error("Failed to execute AssetImporter to import model")
    end
end

function ImportScene(fileName)
    if fileName == "" then
        return
    end

    ui.cursor.shape = CS_BUSY

    if GetExtension(fileName) == ".txml" then
        ImportTundraScene(fileName)
    else
        local options = importOptions:Trimmed():Split(' ')
        local isBinary = false
        for i = 1, #options do
            if options[i] == "-b" then
                isBinary = true
            end
        end
        local tempSceneName = sceneResourcePath .. (isBinary and TEMP_BINARY_SCENE_NAME or TEMP_SCENE_NAME)

        local args = {}
        table.insert(args, "scene")
        table.insert(args, "\"" .. fileName .. "\"")
        table.insert(args, "\"" .. tempSceneName .. "\"")
        table.insert(args, "-p \"" .. sceneResourcePath .. "\"")

        for i = 1, #options do
            table.insert(args, options[i])
        end

        if applyMaterialList then
            table.insert(args, "-l")
        end

        if ExecuteAssetImporter(args) == 0 then
            skipMruScene = true
            LoadScene(tempSceneName)
            fileSystem:Delete(tempSceneName)
            UpdateWindowTitle()
        else
            log:Error("Failed to execute AssetImporter to import scene")
        end
    end
end

function ImportTundraScene(fileName)
    fileSystem:CreateDir(sceneResourcePath .. "Materials")
    fileSystem:CreateDir(sceneResourcePath .. "Models")
    fileSystem:CreateDir(sceneResourcePath .. "Textures")

    local source = XMLFile()
    source:Load(File(fileName, FILE_READ))
    local filePath = GetPath(fileName)

    local sceneElem = source.root
    local entityElem = sceneElem:GetChild("entity")

    local convertedMaterials = {}
    local convertedMeshes = {}
    local parentAssignments = {}

    -- Read scene directory structure
    local fileNames = fileSystem:ScanDir(filePath, "*.*", SCAN_FILES, true)
    for i = 1, #fileNames do
        local mapping = AssetMapping:new()
        mapping.assetName = GetFileNameAndExtension(fileNames[i])
        mapping.fullAssetName = fileNames[i]
        table.insert(assetMappings, mapping)
    end

    ResetScene()

    editorScene:CreateComponent("PhysicsWorld")
    editorScene.physicsWorld.gravity = Vector3(0, -9.81, 0)

    -- Create zone & global light
    local zoneNode = editorScene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000, 1000)
    zone.ambientColor = Color(0.364, 0.364, 0.364)
    zone.fogColor = Color(0.707792, 0.770537, 0.831373)
    zone.fogStart = 100.0
    zone.fogEnd = 500.0

    local lightNode = editorScene:CreateChild("GlobalLight")
    local light = lightNode:CreateComponent("Light")
    lightNode.rotation = Quaternion(60, 30, 0)
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(0.639, 0.639, 0.639)
    light.castShadows = true
    light.shadowCascade = CascadeParameters(5, 15.0, 50.0, 0.0, 0.9)

    -- Loop through scene entities
    while not entityElem:IsNull() do
        local nodeName = ""
        local meshName = ""
        local parentName = ""
        local meshPos = Vector3(0, 0, 0)
        local meshRot = Vector3(0, 0, 0)
        local meshScale = Vector3(1, 1, 1)
        local pos = Vector3(0, 0, 0)
        local rot = Vector3(0, 0, 0)
        local scale = Vector3(1, 1, 1)
        local castShadows = false
        local drawDistance = 0
        local materialNames = {}

        local shapeType = -1
        local mass = 0.0
        local bodySize = Vector3(0, 0, 0)
        local trigger = false
        local kinematic = false
        local collisionLayer = 0
        local collisionMask = 0
        local collisionMeshName = ""

        local compElem = entityElem:GetChild("component")
        while not compElem:IsNull() do
            local compType = compElem:GetAttribute("type")

            if compType == "EC_Mesh" or compType == "Mesh" then
                local coords = GetComponentAttribute(compElem, "Transform"):Split(',')
                meshPos = GetVector3FromStrings(coords, 1)
                meshPos.z = -meshPos.z
                meshRot = GetVector3FromStrings(coords, 4)
                meshScale = GetVector3FromStrings(coords, 7)
                meshName = GetComponentAttribute(compElem, "Mesh ref")
                castShadows = GetComponentAttribute(compElem, "Cast shadows"):ToBool()
                drawDistance = GetComponentAttribute(compElem, "Draw distance"):ToFloat()
                materialNames = GetComponentAttribute(compElem, "Mesh materials"):Split(';')
                ProcessRef(meshName)
                for i = 1, #materialNames do
                    ProcessRef(materialNames[i])
                end
            end

            if compType == "EC_Name" or compType == "Name" then
                nodeName = GetComponentAttribute(compElem, "name")
            end

            if compType == "EC_Placeable" or compType == "Placeable" then
                local coords = GetComponentAttribute(compElem, "Transform"):Split(',')
                pos = GetVector3FromStrings(coords, 1)
                pos.z = -pos.z
                rot = GetVector3FromStrings(coords, 4)
                scale = GetVector3FromStrings(coords, 7)
                parentName = GetComponentAttribute(compElem, "Parent entity ref")
            end

            if compType == "EC_RigidBody" or compType == "RigidBody" then
                shapeType = tonumber(GetComponentAttribute(compElem, "Shape type")) or -1
                mass = tonumber(GetComponentAttribute(compElem, "Mass")) or 0.0
                bodySize = GetComponentAttribute(compElem, "Size"):ToVector3()
                collisionMeshName = GetComponentAttribute(compElem, "Collision mesh ref")
                trigger = GetComponentAttribute(compElem, "Phantom"):ToBool()
                kinematic = GetComponentAttribute(compElem, "Kinematic"):ToBool()
                collisionLayer = tonumber(GetComponentAttribute(compElem, "Collision Layer")) or 0
                collisionMask = tonumber(GetComponentAttribute(compElem, "Collision Mask")) or 0
                ProcessRef(collisionMeshName)
            end

            compElem = compElem:GetNext("component")
        end

        if (shapeType == 4 or shapeType == 6) and collisionMeshName:Trimmed() == "" then
            collisionMeshName = meshName
        end

        if meshName ~= "" or shapeType >= 0 then
            for i = 1, #materialNames do
                ConvertMaterial(materialNames[i], filePath, convertedMaterials)
            end

            ConvertModel(meshName, filePath, convertedMeshes)
            ConvertModel(collisionMeshName, filePath, convertedMeshes)

            local newNode = editorScene:CreateChild(nodeName)

            local quat = GetTransformQuaternion(rot)
            local meshQuat = GetTransformQuaternion(meshRot)
            local finalQuat = quat * meshQuat
            local finalScale = scale * meshScale
            local finalPos = pos + quat * (scale * meshPos)

            newNode:SetTransform(finalPos, finalQuat, finalScale)

            if meshName ~= "" then
                local model = newNode:CreateComponent("StaticModel")
                model.model = cache:GetResource("Model", GetOutModelName(meshName))
                model.drawDistance = drawDistance
                model.castShadows = castShadows
                model.material = cache:GetResource("Material", "Materials/DefaultGrey.xml")

                for i = 1, #materialNames do
                    local mat = cache:GetResource("Material", GetOutMaterialName(materialNames[i]))
                    if mat ~= nil then
                        model:SetMaterial(i - 1, mat)
                    end
                end
            end

            if shapeType >= 0 then
                local body = newNode:CreateComponent("RigidBody")

                bodySize.x = bodySize.x / meshScale.x
                bodySize.y = bodySize.y / meshScale.y
                bodySize.z = bodySize.z / meshScale.z

                local shape = newNode:CreateComponent("CollisionShape")

                if shapeType == 0 then
                    shape:SetBox(bodySize)
                elseif shapeType == 1 then
                    shape:SetSphere(bodySize.x)
                elseif shapeType == 2 then
                    shape:SetCylinder(bodySize.x, bodySize.y)
                elseif shapeType == 3 then
                    shape:SetCapsule(bodySize.x, bodySize.y)
                elseif shapeType == 4 then
                    shape:SetTriangleMesh(cache:GetResource("Model", GetOutModelName(collisionMeshName)), 0, bodySize)
                elseif shapeType == 6 then
                    shape:SetConvexHull(cache:GetResource("Model", GetOutModelName(collisionMeshName)), 0, bodySize)
                end

                body.collisionLayer = collisionLayer
                body.collisionMask = collisionMask
                body.trigger = trigger
                body.mass = mass
            end

            if parentName ~= "" then
                local assignment = ParentAssignment:new()
                assignment.childID = newNode.id
                assignment.parentName = parentName
                table.insert(parentAssignments, assignment)
            end
        end

        entityElem = entityElem:GetNext("entity")
    end

    -- Process parent assignments
    for i = 1, #parentAssignments do
        local childNode = editorScene:GetNode(parentAssignments[i].childID)
        local parentNode = editorScene:GetChild(parentAssignments[i].parentName, true)
        if childNode ~= nil and parentNode ~= nil then
            childNode.parent = parentNode
        end
    end

    UpdateHierarchyItem(editorScene, true)
    UpdateWindowTitle()
    assetMappings = {}
end

function GetFullAssetName(assetName)
    for i = 1, #assetMappings do
        if assetMappings[i].assetName == assetName then
            return assetMappings[i].fullAssetName
        end
    end
    return assetName
end

function GetTransformQuaternion(rotEuler)
    local rotateX = Quaternion(-rotEuler.x, Vector3(1, 0, 0))
    local rotateY = Quaternion(-rotEuler.y, Vector3(0, 1, 0))
    local rotateZ = Quaternion(-rotEuler.z, Vector3(0, 0, -1))
    return rotateZ * rotateY * rotateX
end

function GetComponentAttribute(compElem, name)
    local attrElem = compElem:GetChild("attribute")
    while not attrElem:IsNull() do
        if attrElem:GetAttribute("name") == name then
            return attrElem:GetAttribute("value")
        end
        attrElem = attrElem:GetNext("attribute")
    end
    return ""
end

function GetVector3FromStrings(coords, startIndex)
    return Vector3(
        tonumber(coords[startIndex]) or 0,
        tonumber(coords[startIndex + 1]) or 0,
        tonumber(coords[startIndex + 2]) or 0
    )
end

function ProcessRef(ref)
    if type(ref) == "table" then
        -- Handle array of refs
        for i = 1, #ref do
            ref[i] = ProcessRefString(ref[i])
        end
    else
        -- Handle single string ref (modify in place via return)
        return ProcessRefString(ref)
    end
end

function ProcessRefString(refStr)
    if refStr:StartsWith("local://") then
        return refStr:Substring(8)
    elseif refStr:StartsWith("file://") then
        return refStr:Substring(7)
    end
    return refStr
end

function GetOutModelName(ref)
    return "Models/" .. GetFullAssetName(ref):Replaced('/', '_'):Replaced(".mesh", ".mdl")
end

function GetOutMaterialName(ref)
    return "Materials/" .. GetFullAssetName(ref):Replaced('/', '_'):Replaced(".material", ".xml")
end

function GetOutTextureName(ref)
    return "Textures/" .. GetFullAssetName(ref):Replaced('/', '_')
end

function ConvertModel(modelName, filePath, convertedModels)
    if modelName:Trimmed() == "" then
        return
    end

    for i = 1, #convertedModels do
        if convertedModels[i] == modelName then
            return
        end
    end

    local meshFileName = filePath .. GetFullAssetName(modelName)
    local xmlFileName = filePath .. GetFullAssetName(modelName) .. ".xml"
    local outFileName = sceneResourcePath .. GetOutModelName(modelName)

    local cmdLine = "ogrexmlconverter \"" .. meshFileName .. "\" \"" .. xmlFileName .. "\""
    if not fileSystem:FileExists(xmlFileName) then
        fileSystem:SystemCommand(cmdLine:Replaced('/', '\\'))
    end

    if not fileSystem:FileExists(outFileName) then
        local args = {}
        table.insert(args, "\"" .. xmlFileName .. "\"")
        table.insert(args, "\"" .. outFileName .. "\"")
        table.insert(args, "-a")
        fileSystem:SystemRun(fileSystem.programDir .. "tool/OgreImporter", args)
    end

    table.insert(convertedModels, modelName)
end

function ConvertMaterial(materialName, filePath, convertedMaterials)
    if materialName:Trimmed() == "" then
        return
    end

    for i = 1, #convertedMaterials do
        if convertedMaterials[i] == materialName then
            return
        end
    end

    local fileName = filePath .. GetFullAssetName(materialName)
    local outFileName = sceneResourcePath .. GetOutMaterialName(materialName)

    if not fileSystem:FileExists(fileName) then
        return
    end

    local mask = false
    local twoSided = false
    local uvScaleSet = false
    local textureName = ""
    local uvScale = Vector2(1, 1)
    local diffuse = Color(1, 1, 1, 1)

    local file = File(fileName, FILE_READ)
    while not file.eof do
        local line = file:ReadLine():Trimmed()

        if line:StartsWith("alpha_rejection") or line:StartsWith("scene_blend alpha_blend") then
            mask = true
        end

        if line:StartsWith("cull_hardware none") then
            twoSided = true
        end

        if textureName == "" and line:StartsWith("texture ") then
            textureName = line:Substring(8)
            textureName = ProcessRefString(textureName)
        end

        if not uvScaleSet and line:StartsWith("scale ") then
            uvScale = line:Substring(6):ToVector2()
            uvScaleSet = true
        end

        if line:StartsWith("diffuse ") then
            diffuse = line:Substring(8):ToColor()
        end
    end

    local outMat = XMLFile()
    local rootElem = outMat:CreateRoot("material")
    local techniqueElem = rootElem:CreateChild("technique")

    if twoSided then
        local cullElem = rootElem:CreateChild("cull")
        cullElem:SetAttribute("value", "none")
        local shadowCullElem = rootElem:CreateChild("shadowcull")
        shadowCullElem:SetAttribute("value", "none")
    end

    if textureName ~= "" then
        techniqueElem:SetAttribute("name", mask and "Techniques/DiffAlphaMask.xml" or "Techniques/Diff.xml")

        local outTextureName = GetOutTextureName(textureName)
        local textureElem = rootElem:CreateChild("texture")
        textureElem:SetAttribute("unit", "diffuse")
        textureElem:SetAttribute("name", outTextureName)

        fileSystem:Copy(filePath .. GetFullAssetName(textureName), sceneResourcePath .. outTextureName)
    else
        techniqueElem:SetAttribute("name", "NoTexture.xml")
    end

    if uvScale ~= Vector2(1, 1) then
        local uScaleElem = rootElem:CreateChild("parameter")
        uScaleElem:SetAttribute("name", "UOffset")
        uScaleElem:SetVector3("value", Vector3(1 / uvScale.x, 0, 0))

        local vScaleElem = rootElem:CreateChild("parameter")
        vScaleElem:SetAttribute("name", "VOffset")
        vScaleElem:SetVector3("value", Vector3(0, 1 / uvScale.y, 0))
    end

    if diffuse ~= Color(1, 1, 1, 1) then
        local diffuseElem = rootElem:CreateChild("parameter")
        diffuseElem:SetAttribute("name", "MatDiffColor")
        diffuseElem:SetColor("value", diffuse)
    end

    local outFile = File(outFileName, FILE_WRITE)
    outMat:Save(outFile)
    outFile:Close()

    table.insert(convertedMaterials, materialName)
end
