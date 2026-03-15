-- EditorViewDebugIcons.lua
-- Editor debug icons system for visualizing components in the 3D viewport
-- Displays icons for lights, cameras, sound sources, zones, and other components
-- To add new standard debug icons, add items to IconsTypes, iconsTypesMaterials, and componentTypes arrays

-- Icon type enumeration
ICON_POINT_LIGHT = 0
ICON_SPOT_LIGHT = 1
ICON_DIRECTIONAL_LIGHT = 2
ICON_CAMERA = 3
ICON_SOUND_SOURCE = 4
ICON_SOUND_SOURCE_3D = 5
ICON_SOUND_LISTENERS = 6
ICON_ZONE = 7
ICON_SPLINE_PATH = 8
ICON_TRIGGER = 9
ICON_CUSTOM_GEOMETRY = 10
ICON_PARTICLE_EMITTER = 11
ICON_COUNT = 12

-- Icon color type enumeration
ICON_COLOR_DEFAULT = 0
ICON_COLOR_SPLINE_PATH_BEGIN = 1
ICON_COLOR_SPLINE_PATH_END = 2

-- Debug icon colors
debugIconsColors = {
    Color(1, 1, 1),  -- Default white
    Color(1, 1, 0),  -- Spline path begin (yellow)
    Color(0, 1, 0)   -- Spline path end (green)
}

-- Material paths for each icon type
iconsTypesMaterials = {
    "DebugIconPointLight.xml",
    "DebugIconSpotLight.xml",
    "DebugIconLight.xml",
    "DebugIconCamera.xml",
    "DebugIconSoundSource.xml",
    "DebugIconSoundSource.xml",
    "DebugIconSoundListener.xml",
    "DebugIconZone.xml",
    "DebugIconSplinePathPoint.xml",
    "DebugIconCollisionTrigger.xml",
    "DebugIconCustomGeometry.xml",
    "DebugIconParticleEmitter.xml"
}

-- Component type names corresponding to each icon
componentTypes = {
    "Light",
    "Light",
    "Light",
    "Camera",
    "SoundSource",
    "SoundSource3D",
    "SoundListener",
    "Zone",
    "SplinePath",
    "RigidBody",
    "CustomGeometry",
    "ParticleEmitter"
}

debugIconsSet = {}
debugIconsNode = nil
stepDebugIconsUpdate = 100  -- ms
timeToNextDebugIconsUpdate = 0
stepDebugIconsUpdateSplinePath = 1000  -- ms
timeToNextDebugIconsUpdateSplinePath = 0
splinePathResolution = 16
splineStep = 1.0 / splinePathResolution
debugIconsShow = true
debugIconsSize = Vector2(64, 64)
debugIconsSizeSmall = debugIconsSize / 1.5
debugIconsPlacement = {}
debugIconsPlacementIndent = 1.0
debugIconsOrthoDistance = 15.0
debugIconAlphaThreshold = 0.1
maxDistance = 50.0

function CreateDebugIcons(tempNode)
    if editorScene == nil then
        return
    end

    -- Resize array to ICON_COUNT
    debugIconsSet = {}
    for i = 1, ICON_COUNT do
        debugIconsSet[i] = nil
    end

    for i = 0, ICON_COUNT - 1 do
        local billboardSet = tempNode:CreateComponent("BillboardSet")
        billboardSet.material = cache:GetResource("Material", "Materials/Editor/" .. iconsTypesMaterials[i + 1])
        billboardSet.sorted = true
        billboardSet.temporary = true
        billboardSet.fixedScreenSize = true
        billboardSet.viewMask = 0x80000000

        debugIconsSet[i + 1] = billboardSet
    end
end

function UpdateViewDebugIcons()
    if editorScene == nil then
        return
    end

    if timeToNextDebugIconsUpdate ~= nil and time ~= nil and time.systemTime ~= nil then
        if timeToNextDebugIconsUpdate > time.systemTime then
            return
        end
    end

    debugIconsNode = editorScene:GetChild("DebugIconsContainer", true)

    if debugIconsNode == nil then
        debugIconsNode = editorScene:CreateChild("DebugIconsContainer", LOCAL)
        debugIconsNode.temporary = true
    end

    -- Check if debugIconsNode has any BillboardSet component, add all at once if not
    local isBSExist = debugIconsNode:GetComponent("BillboardSet")
    if isBSExist == nil then
        CreateDebugIcons(debugIconsNode)
    end

    if debugIconsSet[ICON_POINT_LIGHT + 1] ~= nil then
        for i = 0, ICON_COUNT - 1 do
            debugIconsSet[i + 1].enabled = debugIconsShow
        end
    end

    if debugIconsShow == false then
        return
    end

    -- Skip if activeViewport not initialized yet
    if activeViewport == nil or activeViewport.cameraNode == nil or activeViewport.camera == nil then
        return
    end

    local camPos = activeViewport.cameraNode.worldPosition
    local isOrthographic = activeViewport.camera.orthographic
    debugIconsPlacement = {}

    for iconType = 0, ICON_COUNT - 1 do
        if debugIconsSet[iconType + 1] ~= nil then
            -- SplinePath update resolution
            if iconType == ICON_SPLINE_PATH and timeToNextDebugIconsUpdateSplinePath > time.systemTime then
                goto continue
            end

            local nodes = editorScene:GetChildrenWithComponent(componentTypes[iconType + 1], true)

            -- Clear old data
            if iconType == ICON_SPLINE_PATH then
                ClearCommit(ICON_SPLINE_PATH, ICON_SPLINE_PATH + 1, #nodes * splinePathResolution)
            elseif iconType == ICON_POINT_LIGHT or iconType == ICON_SPOT_LIGHT or iconType == ICON_DIRECTIONAL_LIGHT then
                ClearCommit(ICON_POINT_LIGHT, ICON_DIRECTIONAL_LIGHT + 1, #nodes)
            else
                ClearCommit(iconType, iconType + 1, #nodes)
            end

            if #nodes > 0 then
                -- Fill with new data
                for i = 1, #nodes do
                    local component = nodes[i]:GetComponent(componentTypes[iconType + 1])
                    if component then
                        local finalIconColor = debugIconsColors[ICON_COLOR_DEFAULT + 1]
                        local distance = (camPos - nodes[i].worldPosition).length
                        if isOrthographic then
                            distance = debugIconsOrthoDistance
                        end
                        local iconsOffset = debugIconsPlacement[nodes[i].ID] or 0
                        local iconsYPos = 0

                        if iconType == ICON_SPLINE_PATH then
                            local sp = tolua.cast(component, "SplinePath")
                            if sp ~= nil then
                                if sp.length > 0.01 then
                                    for step = 0, splinePathResolution - 1 do
                                        local index = ((i - 1) * splinePathResolution) + step
                                        local splinePoint = sp:GetPoint(splineStep * step)
                                        local bb = debugIconsSet[ICON_SPLINE_PATH + 1]:GetBillboard(index)
                                        local stepDistance = (camPos - splinePoint).length
                                        if isOrthographic then
                                            stepDistance = debugIconsOrthoDistance
                                        end

                                        if step == 0 then
                                            -- SplinePath start
                                            bb.color = debugIconsColors[ICON_COLOR_SPLINE_PATH_BEGIN + 1]
                                            bb.size = debugIconsSize
                                            bb.position = splinePoint
                                        elseif (step + 1) >= (splinePathResolution - splineStep) then
                                            -- SplinePath end
                                            bb.color = debugIconsColors[ICON_COLOR_SPLINE_PATH_END + 1]
                                            bb.size = debugIconsSize
                                            bb.position = splinePoint
                                        else
                                            -- SplinePath middle points
                                            bb.color = finalIconColor
                                            bb.size = debugIconsSizeSmall
                                            bb.position = splinePoint
                                        end
                                        bb.enabled = sp.enabled

                                        -- Blend icon relatively by distance to it
                                        bb.color = Color(bb.color.r, bb.color.g, bb.color.b, 1.2 - 1.0 / (maxDistance / stepDistance))
                                        if bb.color.a < debugIconAlphaThreshold then
                                            bb.enabled = false
                                        end
                                    end
                                end
                            end
                        else
                            local bb = debugIconsSet[iconType + 1]:GetBillboard(i - 1)

                            if iconType == ICON_TRIGGER then
                                local rigidbody = tolua.cast(component, "RigidBody")
                                if rigidbody ~= nil then
                                    if rigidbody.trigger == false then
                                        goto continue_inner
                                    end
                                end
                            elseif iconType == ICON_POINT_LIGHT or iconType == ICON_SPOT_LIGHT or iconType == ICON_DIRECTIONAL_LIGHT then
                                local light = tolua.cast(component, "Light")
                                if light ~= nil then
                                    if light.lightType == LIGHT_POINT then
                                        bb = debugIconsSet[ICON_POINT_LIGHT + 1]:GetBillboard(i - 1)
                                    elseif light.lightType == LIGHT_DIRECTIONAL then
                                        bb = debugIconsSet[ICON_DIRECTIONAL_LIGHT + 1]:GetBillboard(i - 1)
                                    elseif light.lightType == LIGHT_SPOT then
                                        bb = debugIconsSet[ICON_SPOT_LIGHT + 1]:GetBillboard(i - 1)
                                    end

                                    finalIconColor = light.effectiveColor
                                end
                            end

                            bb.position = nodes[i].worldPosition
                            bb.size = debugIconsSize

                            -- Blend icon relatively by distance to it
                            bb.color = Color(finalIconColor.r, finalIconColor.g, finalIconColor.b, 1.2 - 1.0 / (maxDistance / distance))
                            bb.enabled = component.enabled

                            -- Discard billboard if it almost transparent
                            if bb.color.a < debugIconAlphaThreshold then
                                bb.enabled = false
                            end
                            IncrementIconPlacement(bb.enabled, nodes[i], 1)

                            ::continue_inner::
                        end
                    end
                end
                Commit(iconType, iconType + 1)

                -- SplinePath update resolution
                if iconType == ICON_SPLINE_PATH then
                    timeToNextDebugIconsUpdateSplinePath = time.systemTime + stepDebugIconsUpdateSplinePath
                end
            end

            ::continue::
        end
    end

    timeToNextDebugIconsUpdate = time.systemTime + stepDebugIconsUpdate
end

function ClearCommit(beginIdx, endIdx, newLength)
    for i = beginIdx, endIdx - 1 do
        local iconSet = debugIconsSet[i + 1]
        if iconSet then
            iconSet.numBillboards = newLength

            for j = 0, newLength - 1 do
                local bb = iconSet:GetBillboard(j)
                bb.enabled = false
            end

            iconSet:Commit()
        end
    end
end

function Commit(beginIdx, endIdx)
    for i = beginIdx, endIdx - 1 do
        local iconSet = debugIconsSet[i + 1]
        if iconSet then
            iconSet:Commit()
        end
    end
end

function IncrementIconPlacement(componentEnabled, node, offset)
    if componentEnabled == true then
        local oldPlacement = debugIconsPlacement[node.ID] or 0
        debugIconsPlacement[node.ID] = oldPlacement + offset
    end
end
