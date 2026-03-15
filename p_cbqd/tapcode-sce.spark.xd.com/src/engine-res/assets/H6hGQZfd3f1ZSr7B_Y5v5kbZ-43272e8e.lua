-- Urho3D editor preferences dialog

-- Global variables
subscribedToEditorPreferences = false
preferencesDialog = nil

-- LineEdit controls for colors
nodeItemTextColorEditR = nil
nodeItemTextColorEditG = nil
nodeItemTextColorEditB = nil
componentItemTextColorEditR = nil
componentItemTextColorEditG = nil
componentItemTextColorEditB = nil

originalAttributeTextColorEditR = nil
originalAttributeTextColorEditG = nil
originalAttributeTextColorEditB = nil
modifiedAttributeTextColorEditR = nil
modifiedAttributeTextColorEditG = nil
modifiedAttributeTextColorEditB = nil
nonEditableAttributeTextColorEditR = nil
nonEditableAttributeTextColorEditG = nil
nonEditableAttributeTextColorEditB = nil

defaultZoneAmbientColorEditR = nil
defaultZoneAmbientColorEditG = nil
defaultZoneAmbientColorEditB = nil
defaultZoneFogColorEditR = nil
defaultZoneFogColorEditG = nil
defaultZoneFogColorEditB = nil

gridColorEditR = nil
gridColorEditG = nil
gridColorEditB = nil
gridSubdivisionColorEditR = nil
gridSubdivisionColorEditG = nil
gridSubdivisionColorEditB = nil

function CreateEditorPreferencesDialog()
    if preferencesDialog ~= nil then
        return
    end

    preferencesDialog = LoadEditorUI("UI/EditorPreferencesDialog.xml")
    ui.root:AddChild(preferencesDialog)
    preferencesDialog.opacity = uiMaxOpacity
    preferencesDialog.height = 440
    CenterDialog(preferencesDialog)

    local languageSelector = preferencesDialog:GetChild("LanguageSelector", true) ---@cast languageSelector DropDownList
    for i = 0, localization:GetNumLanguages() - 1 do
        local choice = Text:new()
        languageSelector:AddItem(choice)
        choice.style = "FileSelectorFilterText"
        choice.text = localization:GetLanguage(i)
    end

    nodeItemTextColorEditR = preferencesDialog:GetChild("NodeItemTextColor.r", true)
    nodeItemTextColorEditG = preferencesDialog:GetChild("NodeItemTextColor.g", true)
    nodeItemTextColorEditB = preferencesDialog:GetChild("NodeItemTextColor.b", true)
    componentItemTextColorEditR = preferencesDialog:GetChild("ComponentItemTextColor.r", true)
    componentItemTextColorEditG = preferencesDialog:GetChild("ComponentItemTextColor.g", true)
    componentItemTextColorEditB = preferencesDialog:GetChild("ComponentItemTextColor.b", true)

    originalAttributeTextColorEditR = preferencesDialog:GetChild("OriginalAttributeTextColor.r", true)
    originalAttributeTextColorEditG = preferencesDialog:GetChild("OriginalAttributeTextColor.g", true)
    originalAttributeTextColorEditB = preferencesDialog:GetChild("OriginalAttributeTextColor.b", true)
    modifiedAttributeTextColorEditR = preferencesDialog:GetChild("ModifiedAttributeTextColor.r", true)
    modifiedAttributeTextColorEditG = preferencesDialog:GetChild("ModifiedAttributeTextColor.g", true)
    modifiedAttributeTextColorEditB = preferencesDialog:GetChild("ModifiedAttributeTextColor.b", true)
    nonEditableAttributeTextColorEditR = preferencesDialog:GetChild("NonEditableAttributeTextColor.r", true)
    nonEditableAttributeTextColorEditG = preferencesDialog:GetChild("NonEditableAttributeTextColor.g", true)
    nonEditableAttributeTextColorEditB = preferencesDialog:GetChild("NonEditableAttributeTextColor.b", true)

    defaultZoneAmbientColorEditR = preferencesDialog:GetChild("DefaultZoneAmbientColor.r", true)
    defaultZoneAmbientColorEditG = preferencesDialog:GetChild("DefaultZoneAmbientColor.g", true)
    defaultZoneAmbientColorEditB = preferencesDialog:GetChild("DefaultZoneAmbientColor.b", true)
    defaultZoneFogColorEditR = preferencesDialog:GetChild("DefaultZoneFogColor.r", true)
    defaultZoneFogColorEditG = preferencesDialog:GetChild("DefaultZoneFogColor.g", true)
    defaultZoneFogColorEditB = preferencesDialog:GetChild("DefaultZoneFogColor.b", true)

    gridColorEditR = preferencesDialog:GetChild("GridColor.r", true)
    gridColorEditG = preferencesDialog:GetChild("GridColor.g", true)
    gridColorEditB = preferencesDialog:GetChild("GridColor.b", true)
    gridSubdivisionColorEditR = preferencesDialog:GetChild("GridSubdivisionColor.r", true)
    gridSubdivisionColorEditG = preferencesDialog:GetChild("GridSubdivisionColor.g", true)
    gridSubdivisionColorEditB = preferencesDialog:GetChild("GridSubdivisionColor.b", true)

    UpdateEditorPreferencesDialog()
    HideEditorPreferencesDialog()
end

function UpdateEditorPreferencesDialog()
    if preferencesDialog == nil then
        return
    end

    local languageSelector = preferencesDialog:GetChild("LanguageSelector", true)
    languageSelector.selection = localization:GetLanguageIndex()

    local uiMinOpacityEdit = preferencesDialog:GetChild("UIMinOpacity", true)
    uiMinOpacityEdit.text = tostring(uiMinOpacity)

    local uiMaxOpacityEdit = preferencesDialog:GetChild("UIMaxOpacity", true)
    uiMaxOpacityEdit.text = tostring(uiMaxOpacity)

    local showInternalUIElementToggle = preferencesDialog:GetChild("ShowInternalUIElement", true)
    showInternalUIElementToggle.checked = showInternalUIElement

    local showTemporaryObjectToggle = preferencesDialog:GetChild("ShowTemporaryObject", true)
    showTemporaryObjectToggle.checked = showTemporaryObject

    nodeItemTextColorEditR.text = tostring(nodeTextColor.r)
    nodeItemTextColorEditG.text = tostring(nodeTextColor.g)
    nodeItemTextColorEditB.text = tostring(nodeTextColor.b)

    componentItemTextColorEditR.text = tostring(componentTextColor.r)
    componentItemTextColorEditG.text = tostring(componentTextColor.g)
    componentItemTextColorEditB.text = tostring(componentTextColor.b)

    local showNonEditableAttributeToggle = preferencesDialog:GetChild("ShowNonEditableAttribute", true)
    showNonEditableAttributeToggle.checked = showNonEditableAttribute

    originalAttributeTextColorEditR.text = tostring(normalTextColor.r)
    originalAttributeTextColorEditG.text = tostring(normalTextColor.g)
    originalAttributeTextColorEditB.text = tostring(normalTextColor.b)

    modifiedAttributeTextColorEditR.text = tostring(modifiedTextColor.r)
    modifiedAttributeTextColorEditG.text = tostring(modifiedTextColor.g)
    modifiedAttributeTextColorEditB.text = tostring(modifiedTextColor.b)

    nonEditableAttributeTextColorEditR.text = tostring(nonEditableTextColor.r)
    nonEditableAttributeTextColorEditG.text = tostring(nonEditableTextColor.g)
    nonEditableAttributeTextColorEditB.text = tostring(nonEditableTextColor.b)

    defaultZoneAmbientColorEditR.text = tostring(renderer.defaultZone.ambientColor.r)
    defaultZoneAmbientColorEditG.text = tostring(renderer.defaultZone.ambientColor.g)
    defaultZoneAmbientColorEditB.text = tostring(renderer.defaultZone.ambientColor.b)

    defaultZoneFogColorEditR.text = tostring(renderer.defaultZone.fogColor.r)
    defaultZoneFogColorEditG.text = tostring(renderer.defaultZone.fogColor.g)
    defaultZoneFogColorEditB.text = tostring(renderer.defaultZone.fogColor.b)

    local defaultZoneFogStartEdit = preferencesDialog:GetChild("DefaultZoneFogStart", true)
    defaultZoneFogStartEdit.text = tostring(renderer.defaultZone.fogStart)
    local defaultZoneFogEndEdit = preferencesDialog:GetChild("DefaultZoneFogEnd", true)
    defaultZoneFogEndEdit.text = tostring(renderer.defaultZone.fogEnd)

    local showGridToggle = preferencesDialog:GetChild("ShowGrid", true)
    showGridToggle.checked = showGrid

    local grid2DModeToggle = preferencesDialog:GetChild("Grid2DMode", true)
    grid2DModeToggle.checked = grid2DMode

    local gridSizeEdit = preferencesDialog:GetChild("GridSize", true)
    gridSizeEdit.text = tostring(gridSize)

    local gridSubdivisionsEdit = preferencesDialog:GetChild("GridSubdivisions", true)
    gridSubdivisionsEdit.text = tostring(gridSubdivisions)

    local gridScaleEdit = preferencesDialog:GetChild("GridScale", true)
    gridScaleEdit.text = tostring(gridScale)

    gridColorEditR.text = tostring(gridColor.r)
    gridColorEditG.text = tostring(gridColor.g)
    gridColorEditB.text = tostring(gridColor.b)
    gridSubdivisionColorEditR.text = tostring(gridSubdivisionColor.r)
    gridSubdivisionColorEditG.text = tostring(gridSubdivisionColor.g)
    gridSubdivisionColorEditB.text = tostring(gridSubdivisionColor.b)

    if not subscribedToEditorPreferences then
        SubscribeToEvent(uiMinOpacityEdit, "TextFinished", "EditUIMinOpacity")
        SubscribeToEvent(uiMaxOpacityEdit, "TextFinished", "EditUIMaxOpacity")
        SubscribeToEvent(showInternalUIElementToggle, "Toggled", "ToggleShowInternalUIElement")
        SubscribeToEvent(showTemporaryObjectToggle, "Toggled", "ToggleShowTemporaryObject")
        SubscribeToEvent(nodeItemTextColorEditR, "TextFinished", "EditNodeTextColor")
        SubscribeToEvent(nodeItemTextColorEditG, "TextFinished", "EditNodeTextColor")
        SubscribeToEvent(nodeItemTextColorEditB, "TextFinished", "EditNodeTextColor")
        SubscribeToEvent(componentItemTextColorEditR, "TextFinished", "EditComponentTextColor")
        SubscribeToEvent(componentItemTextColorEditG, "TextFinished", "EditComponentTextColor")
        SubscribeToEvent(componentItemTextColorEditB, "TextFinished", "EditComponentTextColor")
        SubscribeToEvent(showNonEditableAttributeToggle, "Toggled", "ToggleShowNonEditableAttribute")
        SubscribeToEvent(originalAttributeTextColorEditR, "TextFinished", "EditOriginalAttributeTextColor")
        SubscribeToEvent(originalAttributeTextColorEditG, "TextFinished", "EditOriginalAttributeTextColor")
        SubscribeToEvent(originalAttributeTextColorEditB, "TextFinished", "EditOriginalAttributeTextColor")
        SubscribeToEvent(modifiedAttributeTextColorEditR, "TextFinished", "EditModifiedAttributeTextColor")
        SubscribeToEvent(modifiedAttributeTextColorEditG, "TextFinished", "EditModifiedAttributeTextColor")
        SubscribeToEvent(modifiedAttributeTextColorEditB, "TextFinished", "EditModifiedAttributeTextColor")
        SubscribeToEvent(nonEditableAttributeTextColorEditR, "TextFinished", "EditNonEditableAttributeTextColor")
        SubscribeToEvent(nonEditableAttributeTextColorEditG, "TextFinished", "EditNonEditableAttributeTextColor")
        SubscribeToEvent(nonEditableAttributeTextColorEditB, "TextFinished", "EditNonEditableAttributeTextColor")
        SubscribeToEvent(defaultZoneAmbientColorEditR, "TextFinished", "EditDefaultZoneAmbientColor")
        SubscribeToEvent(defaultZoneAmbientColorEditG, "TextFinished", "EditDefaultZoneAmbientColor")
        SubscribeToEvent(defaultZoneAmbientColorEditB, "TextFinished", "EditDefaultZoneAmbientColor")
        SubscribeToEvent(defaultZoneFogColorEditR, "TextFinished", "EditDefaultZoneFogColor")
        SubscribeToEvent(defaultZoneFogColorEditG, "TextFinished", "EditDefaultZoneFogColor")
        SubscribeToEvent(defaultZoneFogColorEditB, "TextFinished", "EditDefaultZoneFogColor")
        SubscribeToEvent(defaultZoneFogStartEdit, "TextFinished", "EditDefaultZoneFogStart")
        SubscribeToEvent(defaultZoneFogEndEdit, "TextFinished", "EditDefaultZoneFogEnd")
        SubscribeToEvent(showGridToggle, "Toggled", "ToggleShowGrid")
        SubscribeToEvent(grid2DModeToggle, "Toggled", "ToggleGrid2DMode")
        SubscribeToEvent(gridSizeEdit, "TextFinished", "EditGridSize")
        SubscribeToEvent(gridSubdivisionsEdit, "TextFinished", "EditGridSubdivisions")
        SubscribeToEvent(gridScaleEdit, "TextFinished", "EditGridScale")
        SubscribeToEvent(gridColorEditR, "TextFinished", "EditGridColor")
        SubscribeToEvent(gridColorEditG, "TextFinished", "EditGridColor")
        SubscribeToEvent(gridColorEditB, "TextFinished", "EditGridColor")
        SubscribeToEvent(languageSelector, "ItemSelected", "EditLanguageSelector")
        SubscribeToEvent(gridSubdivisionColorEditR, "TextFinished", "EditGridSubdivisionColor")
        SubscribeToEvent(gridSubdivisionColorEditG, "TextFinished", "EditGridSubdivisionColor")
        SubscribeToEvent(gridSubdivisionColorEditB, "TextFinished", "EditGridSubdivisionColor")
        SubscribeToEvent(preferencesDialog:GetChild("CloseButton", true), "Released", "HideEditorPreferencesDialog")
        subscribedToEditorPreferences = true
    end
end

function EditLanguageSelector(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    localization:SetLanguage(edit.selection)
end

function ToggleEditorPreferencesDialog()
    if preferencesDialog.visible == false then
        ShowEditorPreferencesDialog()
    else
        HideEditorPreferencesDialog()
    end
    return true
end

function ShowEditorPreferencesDialog()
    UpdateEditorPreferencesDialog()
    preferencesDialog.visible = true
    preferencesDialog:BringToFront()
end

function HideEditorPreferencesDialog()
    preferencesDialog.visible = false
end

function EditUIMinOpacity(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    uiMinOpacity = tonumber(edit.text)
    edit.text = tostring(uiMinOpacity)
    FadeUI()
    UnfadeUI()
end

function EditUIMaxOpacity(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    uiMaxOpacity = tonumber(edit.text)
    edit.text = tostring(uiMaxOpacity)
    FadeUI()
    UnfadeUI()
end

function ToggleShowInternalUIElement(eventType, eventData)
    local checkbox = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox")
    showInternalUIElement = checkbox.checked
    UpdateHierarchyItem(editorUIElement, true)
end

function ToggleShowTemporaryObject(eventType, eventData)
    local checkbox = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox")
    showTemporaryObject = checkbox.checked
    UpdateHierarchyItem(editorScene, true)
    UpdateHierarchyItem(editorUIElement, true)
end

function EditNodeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    nodeTextColor = Color(tonumber(nodeItemTextColorEditR.text), tonumber(nodeItemTextColorEditG.text), tonumber(nodeItemTextColorEditB.text))
    if edit.name == "NodeItemTextColor.r" then
        edit.text = tostring(nodeTextColor.r)
    elseif edit.name == "NodeItemTextColor.g" then
        edit.text = tostring(nodeTextColor.g)
    elseif edit.name == "NodeItemTextColor.b" then
        edit.text = tostring(nodeTextColor.b)
    end
    UpdateHierarchyItem(editorScene)
end

function EditComponentTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    componentTextColor = Color(tonumber(componentItemTextColorEditR.text), tonumber(componentItemTextColorEditG.text), tonumber(componentItemTextColorEditB.text))
    if edit.name == "ComponentItemTextColor.r" then
        edit.text = tostring(componentTextColor.r)
    elseif edit.name == "ComponentItemTextColor.g" then
        edit.text = tostring(componentTextColor.g)
    elseif edit.name == "ComponentItemTextColor.b" then
        edit.text = tostring(componentTextColor.b)
    end
    UpdateHierarchyItem(editorScene)
end

function ToggleShowNonEditableAttribute(eventType, eventData)
    local checkbox = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox")
    showNonEditableAttribute = checkbox.checked
    UpdateAttributeInspector(true)
end

function EditOriginalAttributeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    normalTextColor = Color(tonumber(originalAttributeTextColorEditR.text), tonumber(originalAttributeTextColorEditG.text), tonumber(originalAttributeTextColorEditB.text))
    if edit.name == "OriginalAttributeTextColor.r" then
        edit.text = tostring(normalTextColor.r)
    elseif edit.name == "OriginalAttributeTextColor.g" then
        edit.text = tostring(normalTextColor.g)
    elseif edit.name == "OriginalAttributeTextColor.b" then
        edit.text = tostring(normalTextColor.b)
    end
    UpdateAttributeInspector(false)
end

function EditModifiedAttributeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    modifiedTextColor = Color(tonumber(modifiedAttributeTextColorEditR.text), tonumber(modifiedAttributeTextColorEditG.text), tonumber(modifiedAttributeTextColorEditB.text))
    if edit.name == "ModifiedAttributeTextColor.r" then
        edit.text = tostring(modifiedTextColor.r)
    elseif edit.name == "ModifiedAttributeTextColor.g" then
        edit.text = tostring(modifiedTextColor.g)
    elseif edit.name == "ModifiedAttributeTextColor.b" then
        edit.text = tostring(modifiedTextColor.b)
    end
    UpdateAttributeInspector(false)
end

function EditNonEditableAttributeTextColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    nonEditableTextColor = Color(tonumber(nonEditableAttributeTextColorEditR.text), tonumber(nonEditableAttributeTextColorEditG.text), tonumber(nonEditableAttributeTextColorEditB.text))
    if edit.name == "NonEditableAttributeTextColor.r" then
        edit.text = tostring(nonEditableTextColor.r)
    elseif edit.name == "NonEditableAttributeTextColor.g" then
        edit.text = tostring(nonEditableTextColor.g)
    elseif edit.name == "NonEditableAttributeTextColor.b" then
        edit.text = tostring(nonEditableTextColor.b)
    end
    UpdateAttributeInspector(false)
end

function EditDefaultZoneAmbientColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.defaultZone.ambientColor = Color(tonumber(defaultZoneAmbientColorEditR.text), tonumber(defaultZoneAmbientColorEditG.text), tonumber(defaultZoneAmbientColorEditB.text))
    if edit.name == "DefaultZoneAmbientColor.r" then
        edit.text = tostring(renderer.defaultZone.ambientColor.r)
    elseif edit.name == "DefaultZoneAmbientColor.g" then
        edit.text = tostring(renderer.defaultZone.ambientColor.g)
    elseif edit.name == "DefaultZoneAmbientColor.b" then
        edit.text = tostring(renderer.defaultZone.ambientColor.b)
    end
end

function EditDefaultZoneFogColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.defaultZone.fogColor = Color(tonumber(defaultZoneFogColorEditR.text), tonumber(defaultZoneFogColorEditG.text), tonumber(defaultZoneFogColorEditB.text))
    if edit.name == "DefaultZoneFogColor.r" then
        edit.text = tostring(renderer.defaultZone.fogColor.r)
    elseif edit.name == "DefaultZoneFogColor.g" then
        edit.text = tostring(renderer.defaultZone.fogColor.g)
    elseif edit.name == "DefaultZoneFogColor.b" then
        edit.text = tostring(renderer.defaultZone.fogColor.b)
    end
end

function EditDefaultZoneFogStart(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.defaultZone.fogStart = tonumber(edit.text)
    edit.text = tostring(renderer.defaultZone.fogStart)
end

function EditDefaultZoneFogEnd(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    renderer.defaultZone.fogEnd = tonumber(edit.text)
    edit.text = tostring(renderer.defaultZone.fogEnd)
end

function ToggleShowGrid(eventType, eventData)
    local checkbox = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox")
    showGrid = checkbox.checked
    UpdateGrid(false)
end

function ToggleGrid2DMode(eventType, eventData)
    local checkbox = tolua.cast(eventData["Element"]:GetPtr(), "CheckBox")
    grid2DMode = checkbox.checked
    UpdateGrid()
end

function EditGridSize(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    gridSize = tonumber(edit.text)
    edit.text = tostring(gridSize)
    UpdateGrid()
end

function EditGridSubdivisions(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    gridSubdivisions = tonumber(edit.text)
    edit.text = tostring(gridSubdivisions)
    UpdateGrid()
end

function EditGridScale(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    gridScale = tonumber(edit.text)
    edit.text = tostring(gridScale)
    UpdateGrid(false)
end

function EditGridColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    gridColor = Color(tonumber(gridColorEditR.text), tonumber(gridColorEditG.text), tonumber(gridColorEditB.text))
    if edit.name == "GridColor.r" then
        edit.text = tostring(gridColor.r)
    elseif edit.name == "GridColor.g" then
        edit.text = tostring(gridColor.g)
    elseif edit.name == "GridColor.b" then
        edit.text = tostring(gridColor.b)
    end
    UpdateGrid()
end

function EditGridSubdivisionColor(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()
    gridSubdivisionColor = Color(tonumber(gridSubdivisionColorEditR.text), tonumber(gridSubdivisionColorEditG.text), tonumber(gridSubdivisionColorEditB.text))
    if edit.name == "GridSubdivisionColor.r" then
        edit.text = tostring(gridSubdivisionColor.r)
    elseif edit.name == "GridSubdivisionColor.g" then
        edit.text = tostring(gridSubdivisionColor.g)
    elseif edit.name == "GridSubdivisionColor.b" then
        edit.text = tostring(gridSubdivisionColor.b)
    end
    UpdateGrid()
end
