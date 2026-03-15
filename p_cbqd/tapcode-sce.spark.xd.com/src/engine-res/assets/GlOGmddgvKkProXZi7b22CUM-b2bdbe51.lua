-- EditorSoundType.lua
-- Urho3D Sound Type manager for the editor
-- Manages sound type mappings and master gain settings for different audio categories

soundTypeEditorWindow = nil
mappings = {}

DEFAULT_SOUND_TYPES_COUNT = 1

-- SoundTypeMapping class (Lua table-based OOP)
SoundTypeMapping = {}
SoundTypeMapping.__index = SoundTypeMapping

function SoundTypeMapping:new(key, value)
    local obj = {}
    setmetatable(obj, SoundTypeMapping)

    if key then
        obj.key = key
        obj.value = Clamp(tonumber(value) or 0.0, 0.0, 1.0)
    else
        obj.key = ""
        obj.value = 0.0
    end

    return obj
end

function SoundTypeMapping:Update(value)
    self.value = Clamp(tonumber(value) or 0.0, 0.0, 1.0)
    audio:SetMasterGain(self.key, self.value)
end

function CreateSoundTypeEditor()
    if soundTypeEditorWindow ~= nil then
        return
    end

    soundTypeEditorWindow = cache:GetResource("XMLFile", "UI/EditorSoundTypeWindow.xml")
    if soundTypeEditorWindow ~= nil then
        soundTypeEditorWindow = ui:LoadLayout(soundTypeEditorWindow)
        ui.root:AddChild(soundTypeEditorWindow)
        soundTypeEditorWindow.opacity = uiMaxOpacity

        InitSoundTypeEditorWindow()
        RefreshSoundTypeEditorWindow()

        local height = Min(ui.root.height - 60, 750)
        soundTypeEditorWindow:SetSize(400, 0)
        CenterDialog(soundTypeEditorWindow)

        HideSoundTypeEditor()

        SubscribeToEvent(soundTypeEditorWindow:GetChild("CloseButton", true), "Released", "HideSoundTypeEditor")
        SubscribeToEvent(soundTypeEditorWindow:GetChild("AddButton", true), "Released", "AddSoundTypeMapping")
        SubscribeToEvent(soundTypeEditorWindow:GetChild("MasterValue", true), "TextFinished", "EditGain")
    end
end

function InitSoundTypeEditorWindow()
    if mappings[SOUND_MASTER] == nil then
        mappings[SOUND_MASTER] = SoundTypeMapping:new(SOUND_MASTER, audio:GetMasterGain(SOUND_MASTER))
    end

    -- Get mapping keys (skip the first DEFAULT_SOUND_TYPES_COUNT items)
    local keys = {}
    for k, v in pairs(mappings) do
        table.insert(keys, k)
    end

    local count = 0
    for i, key in ipairs(keys) do
        count = count + 1
        if count > DEFAULT_SOUND_TYPES_COUNT then
            local mapping = mappings[key]
            if mapping then
                AddUserUIElements(key, mapping.value)
            end
        end
    end
end

function RefreshSoundTypeEditorWindow()
    RefreshDefaults(soundTypeEditorWindow:GetChild("DefaultsContainer", true))
    RefreshUser(soundTypeEditorWindow:GetChild("UserContainer", true))
end

function RefreshDefaults(root)
    if root then
        UpdateMappingValue(SOUND_MASTER, root:GetChild(SOUND_MASTER, true))
    end
end

function RefreshUser(root)
    if not root then
        return
    end

    local keys = {}
    for k, v in pairs(mappings) do
        table.insert(keys, k)
    end

    local count = 0
    for i, key in ipairs(keys) do
        count = count + 1
        if count > DEFAULT_SOUND_TYPES_COUNT then
            UpdateMappingValue(key, root:GetChild(key, true))
        end
    end
end

function UpdateMappingValue(key, root)
    if root then
        local value = root:GetChild(key .. "Value")
        local mapping = mappings[key]

        if mapping and value then
            value.text = tostring(mapping.value)
            root:SetVar(StringHash("DragDropContent"), Variant(mapping.key))
        end
    end
end

function AddUserUIElements(key, gain)
    local container = soundTypeEditorWindow:GetChild("UserContainer", true)
    if not container then
        return
    end

    local itemParent = UIElement()
    container:AddItem(itemParent)

    itemParent.style = "ListRow"
    itemParent.name = key
    itemParent.layoutSpacing = 10

    local keyText = Text()
    local gainEdit = LineEdit()
    local removeButton = Button()

    itemParent:AddChild(keyText)
    itemParent:AddChild(gainEdit)
    itemParent:AddChild(removeButton)
    itemParent.dragDropMode = DD_SOURCE

    keyText.text = key
    keyText.textAlignment = HA_LEFT
    keyText:SetStyleAuto()

    gainEdit.maxLength = 4
    gainEdit.maxWidth = 2147483647
    gainEdit.minWidth = 100
    gainEdit.name = key .. "Value"
    gainEdit.text = tostring(gain)
    gainEdit:SetStyleAuto()

    removeButton.style = "CloseButton"

    SubscribeToEvent(removeButton, "Released", "DeleteSoundTypeMapping")
    SubscribeToEvent(gainEdit, "TextFinished", "EditGain")
end

function AddSoundTypeMapping(eventType, eventData)
    local button = eventData["Element"]:GetPtr()
    local key = button.parent:GetChild("Key")
    local gain = button.parent:GetChild("Gain")

    if key and gain and key.text ~= "" and gain.text ~= "" and mappings[key.text] == nil then
        local mapping = SoundTypeMapping:new(key.text, tonumber(gain.text) or 0.0)
        mappings[key.text] = mapping
        AddUserUIElements(key.text, mapping.value)
    end

    if key then
        key.text = ""
    end
    if gain then
        gain.text = ""
    end

    RefreshSoundTypeEditorWindow()
end

function DeleteSoundTypeMapping(eventType, eventData)
    local button = eventData["Element"]:GetPtr()
    local parent = button.parent

    if parent then
        mappings[parent.name] = nil
        parent:Remove()
    end
end

function EditGain(eventType, eventData)
    local input = eventData["Element"]:GetPtr()
    if not input then
        return
    end

    local key = input.parent.name
    local mapping = mappings[key]

    if mapping then
        mapping:Update(tonumber(input.text) or 0.0)
    end

    RefreshSoundTypeEditorWindow()
end

function ToggleSoundTypeEditor()
    if soundTypeEditorWindow.visible == false then
        ShowSoundTypeEditor()
    else
        HideSoundTypeEditor()
    end
    return true
end

function ShowSoundTypeEditor()
    RefreshSoundTypeEditorWindow()
    soundTypeEditorWindow.visible = true
    soundTypeEditorWindow:BringToFront()
end

function HideSoundTypeEditor()
    if soundTypeEditorWindow then
        soundTypeEditorWindow.visible = false
    end
end

function SaveSoundTypes(root)
    for key, mapping in pairs(mappings) do
        if mapping then
            root:SetFloat(key, mapping.value)
        end
    end
end

function LoadSoundTypes(root)
    if not root then
        return
    end

    local numAttributes = root.numAttributes
    for i = 0, numAttributes - 1 do
        local key = root:GetAttributeName(i)
        local gain = root:GetFloat(key)

        if key ~= "" and mappings[key] == nil then
            mappings[key] = SoundTypeMapping:new(key, gain)
        end
    end
end
