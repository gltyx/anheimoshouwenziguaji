-- EditorSettings.lua - Converted from EditorSettings.as
-- Editor settings dialog for Urho3D editor

-- Global variables
subscribedToEditorSettings = false
settingsDialog = nil
defaultTags = ""

-- Helper function to trim whitespace from strings
local function Trim(s)
    if type(s) ~= "string" then
        return tostring(s)
    end
    return s:match("^%s*(.-)%s*$")
end

-- Create the editor settings dialog window
function CreateEditorSettingsDialog()
    if settingsDialog ~= nil then
        return
    end

    settingsDialog = LoadEditorUI("UI/EditorSettingsDialog.xml")
    ui.root:AddChild(settingsDialog)
    settingsDialog.opacity = uiMaxOpacity
    settingsDialog.height = 440
    CenterDialog(settingsDialog)
    UpdateEditorSettingsDialog()
    HideEditorSettingsDialog()
end

-- Update editor settings dialog with current values
function UpdateEditorSettingsDialog()
    if settingsDialog == nil then
        return
    end

    local nearClipEdit = settingsDialog:GetChild("NearClipEdit", true)
    nearClipEdit.text = tostring(viewNearClip)

    local farClipEdit = settingsDialog:GetChild("FarClipEdit", true)
    farClipEdit.text = tostring(viewFarClip)

    local fovEdit = settingsDialog:GetChild("FOVEdit", true)
    fovEdit.text = tostring(viewFov)

    local speedEdit = settingsDialog:GetChild("SpeedEdit", true)
    speedEdit.text = tostring(cameraBaseSpeed)

    local limitRotationToggle = settingsDialog:GetChild("LimitRotationToggle", true)
    limitRotationToggle.checked = limitRotation

    local mouseOrbitEdit = settingsDialog:GetChild("MouseOrbitEdit", true)
    mouseOrbitEdit.selection = mouseOrbitMode

    local middleMousePanToggle = settingsDialog:GetChild("MiddleMousePanToggle", true)
    middleMousePanToggle.checked = mmbPanMode

    local rotateAroundSelectToggle = settingsDialog:GetChild("RotateAroundSelectionToggle", true)
    rotateAroundSelectToggle.checked = rotateAroundSelect

    local hotKeysModeEdit = settingsDialog:GetChild("HotKeysModeEdit", true)
    hotKeysModeEdit.selection = hotKeyMode

    local newNodeModeEdit = settingsDialog:GetChild("NewNodeModeEdit", true)
    newNodeModeEdit.selection = newNodeMode

    local moveStepEdit = settingsDialog:GetChild("MoveStepEdit", true)
    moveStepEdit.text = tostring(moveStep)
    local moveSnapToggle = settingsDialog:GetChild("MoveSnapToggle", true)
    moveSnapToggle.checked = moveSnap

    local rotateStepEdit = settingsDialog:GetChild("RotateStepEdit", true)
    rotateStepEdit.text = tostring(rotateStep)
    local rotateSnapToggle = settingsDialog:GetChild("RotateSnapToggle", true)
    rotateSnapToggle.checked = rotateSnap

    local scaleStepEdit = settingsDialog:GetChild("ScaleStepEdit", true)
    scaleStepEdit.text = tostring(scaleStep)
    local scaleSnapToggle = settingsDialog:GetChild("ScaleSnapToggle", true)
    scaleSnapToggle.checked = scaleSnap

    local applyMaterialListToggle = settingsDialog:GetChild("ApplyMaterialListToggle", true)
    applyMaterialListToggle.checked = applyMaterialList

    local rememberResourcePathToggle = settingsDialog:GetChild("RememberResourcePathToggle", true)
    rememberResourcePathToggle.checked = rememberResourcePath

    local importOptionsEdit = settingsDialog:GetChild("ImportOptionsEdit", true)
    importOptionsEdit.text = importOptions

    local pickModeEdit = settingsDialog:GetChild("PickModeEdit", true)
    pickModeEdit.selection = pickMode

    local renderPathNameEdit = settingsDialog:GetChild("RenderPathNameEdit", true)
    renderPathNameEdit.text = renderPathName

    local pickRenderPathButton = settingsDialog:GetChild("PickRenderPathButton", true)

    local textureQualityEdit = settingsDialog:GetChild("TextureQualityEdit", true)
    textureQualityEdit.selection = renderer.textureQuality

    local materialQualityEdit = settingsDialog:GetChild("MaterialQualityEdit", true)
    materialQualityEdit.selection = renderer.materialQuality

    local shadowResolutionEdit = settingsDialog:GetChild("ShadowResolutionEdit", true)
    shadowResolutionEdit.selection = GetShadowResolution()

    local shadowQualityEdit = settingsDialog:GetChild("ShadowQualityEdit", true)
    shadowQualityEdit.selection = renderer.shadowQuality

    local maxOccluderTrianglesEdit = settingsDialog:GetChild("MaxOccluderTrianglesEdit", true)
    maxOccluderTrianglesEdit.text = tostring(renderer.maxOccluderTriangles)

    local specularLightingToggle = settingsDialog:GetChild("SpecularLightingToggle", true)
    specularLightingToggle.checked = renderer.specularLighting

    local dynamicInstancingToggle = settingsDialog:GetChild("DynamicInstancingToggle", true)
    dynamicInstancingToggle.checked = renderer.dynamicInstancing

    local frameLimiterToggle = settingsDialog:GetChild("FrameLimiterToggle", true)
    frameLimiterToggle.checked = engine.maxFps > 0

    local gammaCorrectionToggle = settingsDialog:GetChild("GammaCorrectionToggle", true)
    gammaCorrectionToggle.checked = gammaCorrection

    local HDRToggle = settingsDialog:GetChild("HDRToggle", true)
    HDRToggle.checked = HDR

    local cubemapPath = settingsDialog:GetChild("CubeMapGenPath", true)
    cubemapPath.text = cubeMapGen_Path
    local cubemapName = settingsDialog:GetChild("CubeMapGenKey", true)
    cubemapName.text = cubeMapGen_Name
    local cubemapSize = settingsDialog:GetChild("CubeMapGenSize", true)
    cubemapSize.text = tostring(cubeMapGen_Size)

    local defaultTagsEdit = settingsDialog:GetChild("DefaultTagsEdit", true)
    defaultTagsEdit.text = Trim(defaultTags)

    -- Subscribe to events once
    if not subscribedToEditorSettings then
        SubscribeToEvent(nearClipEdit, "TextChanged", "EditCameraNearClip")
        SubscribeToEvent(nearClipEdit, "TextFinished", "EditCameraNearClip")
        SubscribeToEvent(farClipEdit, "TextChanged", "EditCameraFarClip")
        SubscribeToEvent(farClipEdit, "TextFinished", "EditCameraFarClip")
        SubscribeToEvent(fovEdit, "TextChanged", "EditCameraFOV")
        SubscribeToEvent(fovEdit, "TextFinished", "EditCameraFOV")
        SubscribeToEvent(speedEdit, "TextChanged", "EditCameraSpeed")
        SubscribeToEvent(speedEdit, "TextFinished", "EditCameraSpeed")
        SubscribeToEvent(limitRotationToggle, "Toggled", "EditLimitRotation")
        SubscribeToEvent(middleMousePanToggle, "Toggled", "EditMiddleMousePan")
        SubscribeToEvent(rotateAroundSelectToggle, "Toggled", "EditRotateAroundSelect")
        SubscribeToEvent(mouseOrbitEdit, "ItemSelected", "EditMouseOrbitMode")
        SubscribeToEvent(hotKeysModeEdit, "ItemSelected", "EditHotKeyMode")
        SubscribeToEvent(newNodeModeEdit, "ItemSelected", "EditNewNodeMode")
        SubscribeToEvent(moveStepEdit, "TextChanged", "EditMoveStep")
        SubscribeToEvent(moveStepEdit, "TextFinished", "EditMoveStep")
        SubscribeToEvent(rotateStepEdit, "TextChanged", "EditRotateStep")
        SubscribeToEvent(rotateStepEdit, "TextFinished", "EditRotateStep")
        SubscribeToEvent(scaleStepEdit, "TextChanged", "EditScaleStep")
        SubscribeToEvent(scaleStepEdit, "TextFinished", "EditScaleStep")
        SubscribeToEvent(moveSnapToggle, "Toggled", "EditMoveSnap")
        SubscribeToEvent(rotateSnapToggle, "Toggled", "EditRotateSnap")
        SubscribeToEvent(scaleSnapToggle, "Toggled", "EditScaleSnap")
        SubscribeToEvent(rememberResourcePathToggle, "Toggled", "EditRememberResourcePath")
        SubscribeToEvent(applyMaterialListToggle, "Toggled", "EditApplyMaterialList")
        SubscribeToEvent(importOptionsEdit, "TextChanged", "EditImportOptions")
        SubscribeToEvent(importOptionsEdit, "TextFinished", "EditImportOptions")
        SubscribeToEvent(pickModeEdit, "ItemSelected", "EditPickMode")
        SubscribeToEvent(renderPathNameEdit, "TextFinished", "EditRenderPathName")
        SubscribeToEvent(pickRenderPathButton, "Released", "PickRenderPath")
        SubscribeToEvent(textureQualityEdit, "ItemSelected", "EditTextureQuality")
        SubscribeToEvent(materialQualityEdit, "ItemSelected", "EditMaterialQuality")
        SubscribeToEvent(shadowResolutionEdit, "ItemSelected", "EditShadowResolution")
        SubscribeToEvent(shadowQualityEdit, "ItemSelected", "EditShadowQuality")
        SubscribeToEvent(maxOccluderTrianglesEdit, "TextChanged", "EditMaxOccluderTriangles")
        SubscribeToEvent(maxOccluderTrianglesEdit, "TextFinished", "EditMaxOccluderTriangles")
        SubscribeToEvent(specularLightingToggle, "Toggled", "EditSpecularLighting")
        SubscribeToEvent(dynamicInstancingToggle, "Toggled", "EditDynamicInstancing")
        SubscribeToEvent(frameLimiterToggle, "Toggled", "EditFrameLimiter")
        SubscribeToEvent(gammaCorrectionToggle, "Toggled", "EditGammaCorrection")
        SubscribeToEvent(HDRToggle, "Toggled", "EditHDR")
        SubscribeToEvent(settingsDialog:GetChild("CloseButton", true), "Released", "HideEditorSettingsDialog")

        SubscribeToEvent(cubemapPath, "TextChanged", "EditCubemapPath")
        SubscribeToEvent(cubemapPath, "TextFinished", "EditCubemapPath")
        SubscribeToEvent(cubemapName, "TextChanged", "EditCubemapName")
        SubscribeToEvent(cubemapName, "TextFinished", "EditCubemapName")
        SubscribeToEvent(cubemapSize, "TextChanged", "EditCubemapSize")
        SubscribeToEvent(cubemapSize, "TextFinished", "EditCubemapSize")

        SubscribeToEvent(defaultTagsEdit, "TextFinished", "EditDefaultTags")

        subscribedToEditorSettings = true
    end
end

-- Toggle settings dialog visibility
function ToggleEditorSettingsDialog()
    if settingsDialog.visible == false then
        ShowEditorSettingsDialog()
    else
        HideEditorSettingsDialog()
    end
    return true
end

-- Show the settings dialog
function ShowEditorSettingsDialog()
    UpdateEditorSettingsDialog()
    settingsDialog.visible = true
    settingsDialog:BringToFront()
end

-- Hide the settings dialog
function HideEditorSettingsDialog()
    settingsDialog.visible = false
end

-- Event handlers for camera settings

function EditCameraNearClip(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    viewNearClip = tonumber(edit.text) or viewNearClip
    UpdateViewParameters()
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(camera.nearClip)
    end
end

function EditCameraFarClip(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    viewFarClip = tonumber(edit.text) or viewFarClip
    UpdateViewParameters()
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(camera.farClip)
    end
end

function EditCameraFOV(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    viewFov = tonumber(edit.text) or viewFov
    UpdateViewParameters()
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(camera.fov)
    end
end

function EditCameraSpeed(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    cameraBaseSpeed = math.max(tonumber(edit.text) or cameraBaseSpeed, 1.0)
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(cameraBaseSpeed)
    end
end

function EditLimitRotation(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    limitRotation = edit.checked
end

function EditMouseOrbitMode(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    mouseOrbitMode = edit.selection
end

function EditMiddleMousePan(eventType, eventData)
    mmbPanMode = eventData["Element"]:GetPtr().checked
end

function EditRotateAroundSelect(eventType, eventData)
    rotateAroundSelect = eventData["Element"]:GetPtr().checked
end

function EditHotKeyMode(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    hotKeyMode = edit.selection
    MessageBox("Please, restart Urho editor for applying changes.\n", " Notify ")
end

function EditNewNodeMode(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    newNodeMode = edit.selection
end

-- Event handlers for snap/step settings

function EditMoveStep(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    moveStep = math.max(tonumber(edit.text) or moveStep, 0.0)
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(moveStep)
    end
end

function EditRotateStep(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    rotateStep = math.max(tonumber(edit.text) or rotateStep, 0.0)
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(rotateStep)
    end
end

function EditScaleStep(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    scaleStep = math.max(tonumber(edit.text) or scaleStep, 0.0)
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(scaleStep)
    end
end

function EditMoveSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    moveSnap = edit.checked
    toolBarDirty = true
end

function EditRotateSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    rotateSnap = edit.checked
    toolBarDirty = true
end

function EditScaleSnap(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    scaleSnap = edit.checked
    toolBarDirty = true
end

-- Event handlers for resource settings

function EditRememberResourcePath(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    rememberResourcePath = edit.checked
end

function EditApplyMaterialList(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    applyMaterialList = edit.checked
end

function EditImportOptions(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    importOptions = Trim(edit.text)
end

function EditPickMode(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    pickMode = edit.selection
end

-- Event handlers for render path settings

function EditRenderPathName(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    SetRenderPath(edit.text)
end

function PickRenderPath(eventType, eventData)
    CreateFileSelector("Load render path", "Load", "Cancel", uiRenderPathPath, uiRenderPathFilters, uiRenderPathFilter)
    SubscribeToEvent(uiFileSelector, "FileSelected", "HandleLoadRenderPath")
end

function HandleLoadRenderPath(eventType, eventData)
    CloseFileSelector(uiRenderPathFilter, uiRenderPathPath)
    SetRenderPath(GetResourceNameFromFullName(ExtractFileName(eventData)))
    local renderPathNameEdit = settingsDialog:GetChild("RenderPathNameEdit", true)
    renderPathNameEdit.text = renderPathName
end

-- Event handlers for graphics quality settings

function EditTextureQuality(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.textureQuality = edit.selection
end

function EditMaterialQuality(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.materialQuality = edit.selection
end

function EditShadowResolution(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    SetShadowResolution(edit.selection)
end

function EditShadowQuality(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.shadowQuality = edit.selection
end

function EditMaxOccluderTriangles(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.maxOccluderTriangles = tonumber(edit.text) or renderer.maxOccluderTriangles
    if eventType == StringHash("TextFinished") then
        edit.text = tostring(renderer.maxOccluderTriangles)
    end
end

function EditSpecularLighting(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.specularLighting = edit.checked
end

function EditDynamicInstancing(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.dynamicInstancing = edit.checked
end

function EditFrameLimiter(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    engine.maxFps = edit.checked and 200 or 0
end

function EditGammaCorrection(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    SetGammaCorrection(edit.checked)
end

function EditHDR(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    SetHDR(edit.checked)
end

-- Event handlers for cubemap generation settings

function EditCubemapPath(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    cubeMapGen_Path = edit.text
end

function EditCubemapName(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    cubeMapGen_Name = edit.text
end

function EditCubemapSize(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    cubeMapGen_Size = tonumber(edit.text) or cubeMapGen_Size
end

-- Event handler for default tags

function EditDefaultTags(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    defaultTags = edit.text
end
