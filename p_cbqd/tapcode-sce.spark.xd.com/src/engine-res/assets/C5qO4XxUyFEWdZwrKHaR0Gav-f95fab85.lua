-- EditorViewPaintSelection.lua
-- Paint selection tool for the editor viewport
-- Allows brush-based selection and deselection of scene nodes
-- Activated by pressing the C key

PAINT_STEP_UPDATE = 16
PAINT_SELECTION_KEY = KEY_C

EditorPaintSelectionShow = false
EditorPaintSelectionUITimeToUpdate = 0

EditorPaintSelectionUIContainer = nil
paintSelectionImage = nil

paintSelectionBrushDefaultSize = IntVector2(96, 96)
paintSelectionBrushCurrentSize = IntVector2(96, 96)
paintSelectionBrushMinSize = IntVector2(64, 64)
paintSelectionBrushMaxSize = IntVector2(512, 512)
paintSelectionBrushStepSizeChange = IntVector2(16, 16)

function CreatePaintSelectionContainer()
    if editorScene == nil then
        return
    end

    EditorPaintSelectionUIContainer = UIElement()
    EditorPaintSelectionUIContainer.position = IntVector2(0, 0)
    EditorPaintSelectionUIContainer.size = IntVector2(graphics.width, graphics.height)
    EditorPaintSelectionUIContainer.priority = -5
    EditorPaintSelectionUIContainer.focusMode = FM_NOTFOCUSABLE
    EditorPaintSelectionUIContainer.bringToBack = true
    EditorPaintSelectionUIContainer.name = "DebugPaintSelectionContainer"
    EditorPaintSelectionUIContainer.temporary = true
    ui.root:AddChild(EditorPaintSelectionUIContainer)
end

function CreatePaintSelectionTool()
    paintSelectionImage = BorderImage("Icon")
    paintSelectionImage.temporary = true
    paintSelectionImage:SetFixedSize(paintSelectionBrushDefaultSize.x, paintSelectionBrushDefaultSize.y)
    paintSelectionImage.texture = cache:GetResource("Texture2D", "Textures/Editor/SelectionCircle.png")
    paintSelectionImage.imageRect = IntRect(0, 0, 512, 512)
    paintSelectionImage.priority = -5
    paintSelectionImage.color = Color(1, 1, 1)
    paintSelectionImage.bringToBack = true
    paintSelectionImage.enabled = false
    paintSelectionImage.selected = false
    paintSelectionImage.visible = true
    EditorPaintSelectionUIContainer:AddChild(paintSelectionImage)
end

function UpdatePaintSelection()
    PaintSelectionCheckKeyboard()

    -- Early out if disabled
    if not EditorPaintSelectionShow then
        return
    end

    if editorScene == nil or EditorPaintSelectionUITimeToUpdate > time.systemTime then
        return
    end

    EditorPaintSelectionUIContainer = ui.root:GetChild("DebugPaintSelectionContainer")

    if EditorPaintSelectionUIContainer == nil then
        CreatePaintSelectionContainer()
        CreatePaintSelectionTool()
    end

    if EditorPaintSelectionUIContainer ~= nil then
        -- Set visibility for all origins
        EditorPaintSelectionUIContainer.visible = EditorPaintSelectionShow

        if viewportMode ~= VIEWPORT_SINGLE then
            EditorPaintSelectionUIContainer.visible = false
        end

        if EditorPaintSelectionShow then
            local mp = input.mousePosition
            paintSelectionImage.position = IntVector2(
                mp.x - (paintSelectionBrushCurrentSize.x * 0.5),
                mp.y - (paintSelectionBrushCurrentSize.y * 0.5)
            )
        end
    end

    EditorPaintSelectionUITimeToUpdate = time.systemTime + PAINT_STEP_UPDATE
end

function PaintSelectionCheckKeyboard()
    local key = input:GetKeyPress(PAINT_SELECTION_KEY)

    if key and ui.focusElement == nil then
        EditorPaintSelectionShow = not EditorPaintSelectionShow
        if EditorPaintSelectionUIContainer ~= nil then
            EditorPaintSelectionUIContainer.visible = EditorPaintSelectionShow
        end

        if EditorPaintSelectionShow then
            -- When we start paint selection we change editmode to select
            editMode = EDIT_SELECT
            -- and also we show origins for proper origins update
            ShowOrigins(true)
            toolBarDirty = true
        end
    elseif EditorPaintSelectionShow and ui.focusElement == nil then
        if editMode ~= EDIT_SELECT then
            EditorPaintSelectionShow = false
            if EditorPaintSelectionUIContainer ~= nil then
                EditorPaintSelectionUIContainer.visible = false
            end
        end
    end

    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        EditorPaintSelectionShow = false
        if EditorPaintSelectionUIContainer ~= nil then
            EditorPaintSelectionUIContainer.visible = false
        end
    end
end

function SelectOriginsByPaintSelection(curPos, brushRadius, isOperationAddToSelection)
    if isOperationAddToSelection == nil then
        isOperationAddToSelection = true
    end

    if not EditorPaintSelectionShow or EditorPaintSelectionUIContainer == nil then
        return
    end

    for i = 1, #originsNodes do
        local v1 = Vector3(originsIcons[i].position.x, originsIcons[i].position.y, 0)
        local v2 = Vector3(curPos.x - ORIGINOFFSETICON.x, curPos.y - ORIGINOFFSETICON.y, 0)

        local distance = (v1 - v2).length
        local isThisOriginInCircle = distance < brushRadius

        local nodeID = originsIcons[i]:GetVar(StringHash(ORIGIN_NODEID_VAR)):GetInt()

        if isThisOriginInCircle then
            local handle = editorScene:GetNode(nodeID)
            if handle ~= nil then
                local node = handle
                if isOperationAddToSelection then
                    if node ~= nil and isThisNodeOneOfSelected(node) == false then
                        SelectNode(node, true)
                    end
                else
                    -- Deselect origins operation
                    if node ~= nil and isThisNodeOneOfSelected(node) == true then
                        DeselectNode(node)
                    end
                end
            end
        end
    end
end

function HandlePaintSelectionMouseMove(eventType, eventData)
    if not EditorPaintSelectionShow or EditorPaintSelectionUIContainer == nil then
        return
    end

    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local r = paintSelectionBrushCurrentSize.x * 0.5

    local mousePos = IntVector2(x, y)

    -- Select by mouse
    if input:GetMouseButtonDown(MOUSEB_LEFT) and not input:GetQualifierDown(QUAL_CTRL) then
        SelectOriginsByPaintSelection(mousePos, r, true)
    -- Deselect by mouse
    elseif input:GetMouseButtonDown(MOUSEB_LEFT) and input:GetQualifierDown(QUAL_CTRL) then
        SelectOriginsByPaintSelection(mousePos, r, false)
    end
end

function HandlePaintSelectionWheel(eventType, eventData)
    if not EditorPaintSelectionShow or EditorPaintSelectionUIContainer == nil then
        return
    end

    local wheelValue = eventData["Wheel"]:GetInt()

    if wheelValue ~= 0 then
        if wheelValue > 0 then
            paintSelectionBrushCurrentSize = paintSelectionBrushCurrentSize - paintSelectionBrushStepSizeChange
            paintSelectionBrushCurrentSize = IntVector2(
                Max(paintSelectionBrushCurrentSize.x, paintSelectionBrushMinSize.x),
                Max(paintSelectionBrushCurrentSize.y, paintSelectionBrushMinSize.y)
            )
        elseif wheelValue < 0 then
            paintSelectionBrushCurrentSize = paintSelectionBrushCurrentSize + paintSelectionBrushStepSizeChange
            paintSelectionBrushCurrentSize = IntVector2(
                Min(paintSelectionBrushCurrentSize.x, paintSelectionBrushMaxSize.x),
                Min(paintSelectionBrushCurrentSize.y, paintSelectionBrushMaxSize.y)
            )
        end
        paintSelectionImage:SetFixedSize(paintSelectionBrushCurrentSize.x, paintSelectionBrushCurrentSize.y)
    end
end
