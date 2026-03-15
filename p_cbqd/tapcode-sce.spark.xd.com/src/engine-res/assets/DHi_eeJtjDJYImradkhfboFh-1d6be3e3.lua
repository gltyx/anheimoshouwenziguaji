--[[
EditorExport.lua - Urho3D Editor Export Functions

Provides scene/model export functionality including:
- Export scene to OBJ format
- Export selected objects to OBJ
- Coordinate system conversion (Z-up, right-handed)
- Automatic debug drawable filtering

Converted from EditorExport.as
--]]

-- Export settings
objExportZUp_ = false
objExportRightHanded_ = true

function ExportSceneToOBJ(fileName)
    if fileName == "" then
        MessageBox("File name for OBJ export unspecified")
        return
    end

    -- Append obj extension if missing
    if GetExtension(fileName) == "" then
        fileName = fileName .. ".obj"
    end

    local octree = scene:GetComponent("Octree")
    if octree == nil then
        MessageBox("Octree missing from scene")
        return
    end

    local drawables = octree:GetAllDrawables()
    if #drawables == 0 then
        MessageBox("No drawables to export in the scene")
        return
    end

    RemoveDebugDrawables(drawables)

    local file = File(fileName, FILE_WRITE)
    if WriteDrawablesToOBJ(drawables, file, objExportZUp_, objExportRightHanded_) then
        MessageBox("OBJ file written to " .. fileName, "Success")
        file:Close()
    else
        MessageBox("Unable to write OBJ file")
        file:Close()
        fileSystem:Delete(fileName)
    end
end

function ExportSelectedToOBJ(fileName)
    if fileName == "" then
        MessageBox("File name for OBJ export unspecified")
        return
    end

    if GetExtension(fileName) == "" then
        fileName = fileName .. ".obj"
    end

    local drawables = {}

    -- Add any explicitly selected drawables
    for i = 1, #selectedComponents do
        local drawable = selectedComponents[i]
        if drawable ~= nil and drawable:GetType() == "Drawable" then
            table.insert(drawables, drawable)
        end
    end

    -- Add drawables of any selected nodes
    for i = 1, #selectedNodes do
        local components = selectedNodes[i]:GetComponents()
        for j = 1, #components do
            local drawable = components[j]
            if drawable ~= nil and drawable:GetType() == "Drawable" then
                -- Check if not already in list
                local found = false
                for k = 1, #drawables do
                    if drawables[k] == drawable then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(drawables, drawable)
                end
            end
        end
    end

    RemoveDebugDrawables(drawables)

    if #drawables > 0 then
        local file = File(fileName, FILE_WRITE)
        if WriteDrawablesToOBJ(drawables, file, objExportZUp_, objExportRightHanded_) then
            MessageBox("OBJ file written to " .. fileName, "Success")
            file:Close()
        else
            MessageBox("Unable to write OBJ file")
            file:Close()
            fileSystem:Delete(fileName)
        end
    else
        MessageBox("No selected drawables to export to OBJ")
    end
end

function RemoveDebugDrawables(drawables)
    local i = 1
    while i <= #drawables do
        local drawable = drawables[i]
        if drawable.node ~= nil then
            local nodeName = drawable.node.name
            if nodeName == "EditorGizmo" or nodeName == "DebugIconsContainer" or nodeName == "EditorGrid" then
                table.remove(drawables, i)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

function HandleOBJZUpChanged(eventType, eventData)
    local checkBox = eventData["Element"]:GetPtr()
    objExportZUp_ = checkBox.checked
end

function HandleOBJRightHandedChanged(eventType, eventData)
    local checkBox = eventData["Element"]:GetPtr()
    objExportRightHanded_ = checkBox.checked
end
