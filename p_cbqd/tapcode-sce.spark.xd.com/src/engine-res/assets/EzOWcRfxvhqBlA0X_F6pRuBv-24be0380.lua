--[[
EditorTerrain.lua - Urho3D Terrain Editor

Provides terrain editing functionality including:
- Height manipulation (raise/lower, set, smooth)
- Brush-based editing with customizable size and opacity
- Terrain creation from scratch
- Visual brush feedback
- Undo/redo support for terrain modifications

Converted from EditorTerrain.as
--]]

-- Edit modes
local TERRAIN_EDITMODE_RAISELOWERHEIGHT = 0
local TERRAIN_EDITMODE_SETHEIGHT = 1
local TERRAIN_EDITMODE_SMOOTHHEIGHT = 3
local TERRAIN_EDITMODE_PAINTBRUSH = 4
local TERRAIN_EDITMODE_PAINTTREES = 5
local TERRAIN_EDITMODE_PAINTFOLIAGE = 6

-- TerrainEditorUpdateChanges class
TerrainEditorUpdateChanges = {}
TerrainEditorUpdateChanges.__index = TerrainEditorUpdateChanges

function TerrainEditorUpdateChanges:new()
    local self = setmetatable({}, TerrainEditorUpdateChanges)
    self.offset = IntVector2(0, 0)
    self.oldImage = nil
    self.newImage = nil
    return self
end

-- TerrainEditorBrushVisualizer class
TerrainEditorBrushVisualizer = {}
TerrainEditorBrushVisualizer.__index = TerrainEditorBrushVisualizer

function TerrainEditorBrushVisualizer:new()
    local self = setmetatable({}, TerrainEditorBrushVisualizer)
    self.node = nil
    self.customGeometry = nil
    self.addedToOctree = false
    return self
end

function TerrainEditorBrushVisualizer:Create()
    self.node = Node()
    self.customGeometry = self.node:CreateComponent("CustomGeometry")
    self.customGeometry.numGeometries = 1
    self.customGeometry.material = cache:GetResource("Material", "Materials/VColUnlit.xml")
    self.customGeometry.occludee = false
    self.customGeometry.enabled = true
end

function TerrainEditorBrushVisualizer:Hide()
    self.node.enabled = false
    self.addedToOctree = false
end

function TerrainEditorBrushVisualizer:Update(terrainComponent, position, radius)
    self.node.enabled = true
    self.node.position = Vector3(position.x, 0, position.z)

    -- Generate the circle
    self.customGeometry:BeginGeometry(0, LINE_STRIP)
    for i = 0, 360, 4 do
        local angle = i * M_PI / 180
        local x = radius * math.cos(angle / 0.0174532925)
        local z = radius * math.sin(angle / 0.0174532925)
        local y = terrainComponent:GetHeight(Vector3(position.x + x, 0, position.z + z))
        self.customGeometry:DefineVertex(Vector3(x, y + 0.25, z))
        self.customGeometry:DefineColor(Color(0, 1, 0))
    end
    self.customGeometry:Commit()

    if editorScene.octree ~= nil and not self.addedToOctree then
        editorScene.octree:AddManualDrawable(self.customGeometry)
        self.addedToOctree = true
    end
end

-- TerrainEditor class
TerrainEditor = {}
TerrainEditor.__index = TerrainEditor

function TerrainEditor:new()
    local self = setmetatable({}, TerrainEditor)
    self.dirty = true
    self.editMode = 0
    self.window = nil
    self.toolbar = nil
    self.currentToolDescText = nil
    self.brushes = {}
    self.selectedBrush = nil
    self.selectedBrushImage = nil
    self.scaledSelectedBrushImage = nil
    self.brushSizeSlider = nil
    self.brushOpacitySlider = nil
    self.brushHeightSlider = nil
    self.brushVisualizer = TerrainEditorBrushVisualizer:new()
    self.terrainsEdited = {}
    self.targetColor = Color(0, 0, 0)
    self.targetColorSelected = false
    return self
end

function TerrainEditor:Create()
    if self.window ~= nil then
        return
    end

    self.window = LoadEditorUI("UI/EditorTerrainWindow.xml")
    ui.root:AddChild(self.window)
    self.window.opacity = uiMaxOpacity

    local currentToolDesc = self.window:GetChild("CurrentToolDesc", true)
    currentToolDesc.layoutBorder = IntRect(8, 8, 8, 8)

    self.currentToolDescText = self.window:GetChild("CurrentToolDescText", true)

    local brushesContainer = self.window:GetChild("BrushesContainer", true)
    brushesContainer:SetScrollBarsVisible(true, false)
    brushesContainer.contentElement.layoutMode = LM_HORIZONTAL
    brushesContainer:SetFixedHeight(84)

    local settingsArea = self.window:GetChild("SettingsArea", true)
    settingsArea.layoutBorder = IntRect(8, 8, 8, 8)

    local createTerrainValue = self.window:GetChild("CreateTerrainValue", true)
    createTerrainValue.text = "1024"

    self.brushSizeSlider = self.window:GetChild("BrushSize", true)
    self.brushOpacitySlider = self.window:GetChild("BrushOpacity", true)
    self.brushHeightSlider = self.window:GetChild("BrushHeight", true)

    self.window.height = 300
    self.window:SetPosition(ui.root.width - 10 - self.window.width,
        attributeInspectorWindow.position.y + attributeInspectorWindow.height + 10)

    self:SubscribeToEvent(self.window:GetChild("RaiseLowerHeight", true), "Toggled", "OnEditModeSelected")
    self:SubscribeToEvent(self.window:GetChild("SetHeight", true), "Toggled", "OnEditModeSelected")
    self:SubscribeToEvent(self.window:GetChild("SmoothHeight", true), "Toggled", "OnEditModeSelected")
    self:SubscribeToEvent(self.window:GetChild("CloseButton", true), "Released", "Hide")
    self:SubscribeToEvent(self.window:GetChild("CreateTerrainButton", true), "Released", "CreateTerrain")
    self:SubscribeToEvent(self.brushSizeSlider, "DragEnd", "UpdateScaledBrush")

    self:LoadBrushes()
    self:Show()

    self.brushVisualizer:Create()
end

function TerrainEditor:Hide()
    self.window.visible = false
end

function TerrainEditor:HideBrushVisualizer()
    self.brushVisualizer:Hide()
end

function TerrainEditor:UpdateBrushVisualizer(terrainComponent, position)
    if self.scaledSelectedBrushImage == nil then
        self.brushVisualizer:Hide()
        return
    end
    self.brushVisualizer:Update(terrainComponent, position, self.scaledSelectedBrushImage.width / 2)
end

function TerrainEditor:Save()
    for i, terrain in ipairs(self.terrainsEdited) do
        if terrain ~= nil then
            local fileLocation = sceneResourcePath .. terrain:GetAttribute("Height Map"):GetResourceRef().name

            local chunks = fileLocation:Split('/')
            local parts = chunks[#chunks]:Split('.')
            local fileType = parts[2]

            if fileType == "png" then
                terrain.heightMap:SavePNG(fileLocation)
            elseif fileType == "jpg" then
                terrain.heightMap:SaveJPG(fileLocation, 100)
            elseif fileType == "bmp" then
                terrain.heightMap:SaveBMP(fileLocation)
            elseif fileType == "tga" then
                terrain.heightMap:SaveTGA(fileLocation)
            end
        end
    end
    self.terrainsEdited = {}
end

function TerrainEditor:Show()
    self.window.visible = true
    self.window:BringToFront()
    return true
end

function TerrainEditor:UpdateDirty()
    if not self.dirty then
        return
    end

    local raiseLowerHeight = self.window:GetChild("RaiseLowerHeight", true)
    local setHeight = self.window:GetChild("SetHeight", true)
    local smoothHeight = self.window:GetChild("SmoothHeight", true)

    raiseLowerHeight.checked = (self.editMode == TERRAIN_EDITMODE_RAISELOWERHEIGHT)
    setHeight.checked = (self.editMode == TERRAIN_EDITMODE_SETHEIGHT)
    smoothHeight.checked = (self.editMode == TERRAIN_EDITMODE_SMOOTHHEIGHT)

    raiseLowerHeight.enabled = not raiseLowerHeight.checked
    setHeight.enabled = not setHeight.checked
    smoothHeight.enabled = not smoothHeight.checked

    local terrainBrushes = self.window:GetChild("BrushesContainer", true)

    for i = 0, terrainBrushes.numItems - 1 do
        local checkbox = terrainBrushes.items[i]
        checkbox.checked = (checkbox == self.selectedBrush)
        checkbox.enabled = not checkbox.checked
    end

    self.dirty = false
end

function TerrainEditor:Work(terrainComponent, position)
    if self.selectedBrushImage == nil or self.scaledSelectedBrushImage == nil then
        return
    end

    SetSceneModified()

    -- Add terrain to list if not already tracked
    local found = false
    for _, terrain in ipairs(self.terrainsEdited) do
        if terrain == terrainComponent then
            found = true
            break
        end
    end
    if not found then
        table.insert(self.terrainsEdited, terrainComponent)
    end

    local updateChanges = TerrainEditorUpdateChanges:new()
    local pos = terrainComponent:WorldToHeightMap(position)

    if self.editMode == TERRAIN_EDITMODE_RAISELOWERHEIGHT then
        self:UpdateTerrainRaiseLower(terrainComponent.heightMap, pos, updateChanges)
    elseif self.editMode == TERRAIN_EDITMODE_SETHEIGHT then
        self:UpdateTerrainSetHeight(terrainComponent.heightMap, pos, updateChanges)
    elseif self.editMode == TERRAIN_EDITMODE_SMOOTHHEIGHT then
        self:UpdateTerrainSmooth(terrainComponent.heightMap, pos, updateChanges)
    end

    terrainComponent:ApplyHeightMap()
    self:UpdateBrushVisualizer(terrainComponent, position)

    local action = ModifyTerrainAction()
    action:Define(terrainComponent, updateChanges.offset, updateChanges.oldImage, updateChanges.newImage)
    SaveEditAction(action)
end

function TerrainEditor:NearestPowerOf2(value)
    if value < 2 then
        return 2
    end

    local i = 1
    while i <= 2048 do
        if value == i then
            return i
        end

        if value >= i and value <= i * 2 then
            if value < (i + i / 2) then
                return i
            else
                return i * 2
            end
        end

        i = i * 2
    end

    return 2048
end

function TerrainEditor:CreateTerrain()
    local fileName = "Textures/heightmap-" .. tostring(time.timeSinceEpoch) .. ".png"
    local fileLocation = sceneResourcePath .. fileName

    local node = CreateNode(LOCAL)
    node.position = Vector3(0, 0, 0)

    local lineEdit = self.window:GetChild("CreateTerrainValue", true)
    local lineEditLength = tonumber(lineEdit.text:Trimmed()) or 0

    if lineEditLength == 0 then
        lineEditLength = 1024
    end

    local image = Image()
    local length = self:NearestPowerOf2(lineEditLength) + 1
    image:SetSize(length, length, 3)

    self:UpdateTerrainSetConstantHeight(image, 0)

    if not fileSystem:DirExists(GetPath(fileLocation)) then
        fileSystem:CreateDir(GetPath(fileLocation))
    end
    image:SavePNG(fileLocation)

    local terrain = node:CreateComponent("Terrain")
    terrain.heightMap = image

    local res = cache:GetResource("Image", fileLocation)

    local ref = ResourceRef()
    ref.type = res.type
    ref.name = fileName
    terrain:SetAttribute("Height Map", Variant(ref))
    terrain:ApplyAttributes()

    SelectComponent(terrain, false)
end

function TerrainEditor:Difference(a, b)
    return (a > b) and (a - b) or (b - a)
end

function TerrainEditor:GetBrushImage(brushName)
    for _, brush in ipairs(self.brushes) do
        if brush.name == brushName then
            return brush
        end
    end
    return nil
end

function TerrainEditor:LoadBrush(fileLocation)
    local chunks = fileLocation:Split('/')
    local parts = chunks[#chunks]:Split('.')

    local image = cache:GetResource("Image", fileLocation)
    if image == nil then
        return nil
    end

    image.name = parts[1]
    table.insert(self.brushes, image)

    local texture = cache:GetResource("Texture2D", fileLocation)

    local brush = CheckBox(parts[1])
    brush.defaultStyle = uiStyle
    brush:SetStyle("TerrainEditorCheckbox")
    brush:SetFixedSize(64, 64)
    self:SubscribeToEvent(brush, "Toggled", "OnBrushSelected")

    local icon = BorderImage("Icon")
    icon.defaultStyle = iconStyle
    icon.texture = texture
    icon.imageRect = IntRect(0, 0, texture.width, texture.height)
    icon:SetFixedSize(64, 64)
    brush:AddChild(icon)

    return brush
end

function TerrainEditor:LoadBrushes()
    local terrainBrushes = self.window:GetChild("BrushesContainer", true)
    local brushPath = "Textures/Editor/TerrainBrushes/"

    local resourceDirs = cache.resourceDirs
    local brushesFileLocation = ""

    for i = 1, #resourceDirs do
        brushesFileLocation = resourceDirs[i] .. brushPath
        if fileSystem:DirExists(brushesFileLocation) then
            break
        end
    end

    if brushesFileLocation == "" then
        return
    end

    local files = fileSystem:ScanDir(brushesFileLocation, "*.*", SCAN_FILES, false)

    for i = 1, #files do
        local brush = self:LoadBrush(brushPath .. files[i])
        if brush ~= nil then
            terrainBrushes:AddItem(brush)
        end
    end
end

function TerrainEditor:OnEditModeSelected(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()

    if not edit.checked then
        return
    end

    if edit.name == "RaiseLowerHeight" then
        self:SetEditMode(TERRAIN_EDITMODE_RAISELOWERHEIGHT, "Raise or lower terrain")
    elseif edit.name == "SetHeight" then
        self:SetEditMode(TERRAIN_EDITMODE_SETHEIGHT, "Set height to specified height")
    elseif edit.name == "SmoothHeight" then
        self:SetEditMode(TERRAIN_EDITMODE_SMOOTHHEIGHT, "Smooth the terrain")
    elseif edit.name == "PaintBrush" then
        self:SetEditMode(TERRAIN_EDITMODE_PAINTBRUSH, "Paint textures onto the terrain")
    elseif edit.name == "PaintTrees" then
        self:SetEditMode(TERRAIN_EDITMODE_PAINTTREES, "Paint trees onto the terrain")
    elseif edit.name == "PaintFoliage" then
        self:SetEditMode(TERRAIN_EDITMODE_PAINTFOLIAGE, "Paint foliage onto the terrain")
    end
end

function TerrainEditor:OnBrushSelected(eventType, eventData)
    local checkbox = eventData["Element"]:GetPtr()
    if not checkbox.checked then
        return
    end
    self.selectedBrush = checkbox
    self.selectedBrushImage = self:GetBrushImage(self.selectedBrush.name)
    self:UpdateScaledBrush()
    self.dirty = true
end

function TerrainEditor:SetEditMode(mode, description)
    self.window:GetChild("BrushOpacityLabel", true).visible = (mode == TERRAIN_EDITMODE_RAISELOWERHEIGHT)
    self.window:GetChild("BrushHeightLabel", true).visible = (mode == TERRAIN_EDITMODE_SETHEIGHT)

    self.window:GetChild("BrushOpacity", true).visible = (mode == TERRAIN_EDITMODE_RAISELOWERHEIGHT)
    self.window:GetChild("BrushHeight", true).visible = (mode == TERRAIN_EDITMODE_SETHEIGHT)

    self.editMode = mode
    self.currentToolDescText.text = description
    self.dirty = true

    self.window.height = 0
end

function TerrainEditor:Smaller(a, b)
    return (a > b) and b or a
end

function TerrainEditor:UpdateScaledBrush()
    if self.selectedBrushImage == nil then
        return
    end
    local size = (self.brushSizeSlider.value / 25) + 0.5
    self.scaledSelectedBrushImage = self.selectedBrushImage:GetSubimage(
        IntRect(0, 0, self.selectedBrushImage.width, self.selectedBrushImage.height))
    self.scaledSelectedBrushImage:Resize(
        math.floor(self.selectedBrushImage.width * size),
        math.floor(self.selectedBrushImage.height * size))
end

function TerrainEditor:UpdateTerrainRaiseLower(terrainImage, position, updateChanges)
    local brushImageWidth = self.scaledSelectedBrushImage.width
    local brushImageHeight = self.scaledSelectedBrushImage.height

    updateChanges.offset = IntVector2(position.x - math.floor(brushImageWidth / 2),
        position.y - math.floor(brushImageHeight / 2))
    if updateChanges.offset.x < 0 then updateChanges.offset.x = 0 end
    if updateChanges.offset.y < 0 then updateChanges.offset.y = 0 end

    local boundsRect = IntRect(updateChanges.offset.x, updateChanges.offset.y,
        updateChanges.offset.x + brushImageWidth, updateChanges.offset.y + brushImageHeight)
    boundsRect = self:ClipIntRectToHeightmapBounds(terrainImage, boundsRect)

    updateChanges.oldImage = terrainImage:GetSubimage(boundsRect)

    local opacity = self.brushOpacitySlider.value / 25
    local modifier = (input:GetKeyDown(KEY_SHIFT) and -opacity or opacity) * 0.05

    for y = 0, brushImageHeight - 1 do
        for x = 0, brushImageWidth - 1 do
            local pos = IntVector2(position.x + x - math.floor(brushImageWidth / 2),
                position.y + y - math.floor(brushImageHeight / 2))
            local newColor = terrainImage:GetPixel(pos.x, pos.y)
            local brushColor = self.scaledSelectedBrushImage:GetPixel(x, y)

            newColor.r = newColor.r + brushColor.a * modifier
            newColor.g = newColor.g + brushColor.a * modifier
            newColor.b = newColor.b + brushColor.a * modifier
            terrainImage:SetPixel(pos.x, pos.y, newColor)
        end
    end

    local smoothUpdateChanges = TerrainEditorUpdateChanges:new()
    self:UpdateTerrainSmooth(terrainImage, position, smoothUpdateChanges)

    updateChanges.newImage = smoothUpdateChanges.newImage
end

function TerrainEditor:UpdateTerrainSmooth(terrainImage, position, updateChanges)
    local brushImageWidth = self.scaledSelectedBrushImage.width
    local brushImageHeight = self.scaledSelectedBrushImage.height

    updateChanges.offset = IntVector2(position.x - math.floor(brushImageWidth / 2),
        position.y - math.floor(brushImageHeight / 2))
    if updateChanges.offset.x < 0 then updateChanges.offset.x = 0 end
    if updateChanges.offset.y < 0 then updateChanges.offset.y = 0 end

    local boundsRect = IntRect(updateChanges.offset.x, updateChanges.offset.y,
        updateChanges.offset.x + brushImageWidth, updateChanges.offset.y + brushImageHeight)
    boundsRect = self:ClipIntRectToHeightmapBounds(terrainImage, boundsRect)

    updateChanges.oldImage = terrainImage:GetSubimage(boundsRect)

    for y = 0, brushImageHeight - 1 do
        for x = 0, brushImageWidth - 1 do
            local brushColor = self.scaledSelectedBrushImage:GetPixel(x, y)

            if brushColor.a ~= 0 then
                local pos = IntVector2(position.x + x - math.floor(brushImageWidth / 2),
                    position.y + y - math.floor(brushImageHeight / 2))

                if pos.x > 0 and pos.y > 0 and pos.x < terrainImage.width - 1 and pos.y < terrainImage.height - 1 then
                    local brp = terrainImage:GetPixel(pos.x + 1, pos.y + 1)
                    local rp = terrainImage:GetPixel(pos.x + 1, pos.y)
                    local trp = terrainImage:GetPixel(pos.x + 1, pos.y - 1)
                    local blp = terrainImage:GetPixel(pos.x - 1, pos.y + 1)
                    local lp = terrainImage:GetPixel(pos.x - 1, pos.y)
                    local tlp = terrainImage:GetPixel(pos.x - 1, pos.y - 1)
                    local bp = terrainImage:GetPixel(pos.x, pos.y + 1)
                    local cp = terrainImage:GetPixel(pos.x, pos.y)
                    local tp = terrainImage:GetPixel(pos.x, pos.y - 1)

                    local avgColor = Color(
                        (brp.r + rp.r + trp.r + blp.r + lp.r + tlp.r + bp.r + cp.r + tp.r) / 9,
                        (brp.g + rp.g + trp.g + blp.g + lp.g + tlp.g + bp.g + cp.g + tp.g) / 9,
                        (brp.b + rp.b + trp.b + blp.b + lp.b + tlp.b + bp.b + cp.b + tp.b) / 9
                    )

                    terrainImage:SetPixel(position.x + x - math.floor(brushImageWidth / 2),
                        position.y + y - math.floor(brushImageHeight / 2), avgColor)
                end
            end
        end
    end

    updateChanges.newImage = terrainImage:GetSubimage(boundsRect)
end

function TerrainEditor:UpdateTerrainSetHeight(terrainImage, position, updateChanges)
    local brushImageWidth = self.scaledSelectedBrushImage.width
    local brushImageHeight = self.scaledSelectedBrushImage.height

    updateChanges.offset = IntVector2(position.x - math.floor(brushImageWidth / 2),
        position.y - math.floor(brushImageHeight / 2))
    if updateChanges.offset.x < 0 then updateChanges.offset.x = 0 end
    if updateChanges.offset.y < 0 then updateChanges.offset.y = 0 end

    local boundsRect = IntRect(updateChanges.offset.x, updateChanges.offset.y,
        updateChanges.offset.x + brushImageWidth, updateChanges.offset.y + brushImageHeight)
    boundsRect = self:ClipIntRectToHeightmapBounds(terrainImage, boundsRect)

    updateChanges.oldImage = terrainImage:GetSubimage(boundsRect)

    local targetHeight = self.brushHeightSlider.value / 25

    for y = 0, brushImageHeight - 1 do
        for x = 0, brushImageWidth - 1 do
            local pos = IntVector2(position.x + x - math.floor(brushImageWidth / 2),
                position.y + y - math.floor(brushImageHeight / 2))
            local newColor = terrainImage:GetPixel(pos.x, pos.y)
            local brushColor = self.scaledSelectedBrushImage:GetPixel(x, y)

            newColor.r = newColor.r + (targetHeight - newColor.r) * brushColor.a
            newColor.g = newColor.g + (targetHeight - newColor.g) * brushColor.a
            newColor.b = newColor.b + (targetHeight - newColor.b) * brushColor.a

            if self:Difference(targetHeight, newColor.r) < 0.01 then newColor.r = targetHeight end
            if self:Difference(targetHeight, newColor.g) < 0.01 then newColor.g = targetHeight end
            if self:Difference(targetHeight, newColor.b) < 0.01 then newColor.b = targetHeight end

            terrainImage:SetPixel(pos.x, pos.y, newColor)
        end
    end

    updateChanges.newImage = terrainImage:GetSubimage(boundsRect)
end

function TerrainEditor:UpdateTerrainSetConstantHeight(terrainImage, height)
    height = Clamp(height, 0.0, 1.0)
    local newColor = Color(height, height, height)

    for y = 0, terrainImage.height - 1 do
        for x = 0, terrainImage.width - 1 do
            terrainImage:SetPixel(x, y, newColor)
        end
    end
end

function TerrainEditor:ClipIntRectToHeightmapBounds(terrainImage, intRect)
    if intRect.left > terrainImage.width then
        intRect.left = terrainImage.width
    end

    if intRect.right > terrainImage.width then
        intRect.right = terrainImage.width
    end

    if intRect.top > terrainImage.height then
        intRect.top = terrainImage.height
    end

    if intRect.bottom > terrainImage.height then
        intRect.bottom = terrainImage.height
    end

    return intRect
end

-- Helper method for subscribing to events (instance-based)
function TerrainEditor:SubscribeToEvent(element, eventName, handlerName)
    local handler = function(eventType, eventData)
        self[handlerName](self, eventType, eventData)
    end
    SubscribeToEvent(element, eventName, handler)
end

-- Global terrain editor instance
terrainEditor = nil

function CreateTerrainEditor()
    if terrainEditor == nil then
        terrainEditor = TerrainEditor:new()
    end
    return terrainEditor
end
