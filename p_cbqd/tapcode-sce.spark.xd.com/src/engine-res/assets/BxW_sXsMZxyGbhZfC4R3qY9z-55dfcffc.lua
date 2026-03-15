-- Editor main event handlers
-- This module acts as a central event dispatcher, routing events to appropriate module handlers

-- Custom editor events
EDITOR_EVENT_SCENE_LOADED = "EditorEventSceneLoaded"
EDITOR_EVENT_ORIGIN_START_HOVER = "EditorEventOriginStartHover"
EDITOR_EVENT_ORIGIN_END_HOVER = "EditorEventOriginEndHover"

-- Subscribe to all editor events
function EditorSubscribeToEvents()
    -- Input events
    SubscribeToEvent("KeyDown", "EditorMainHandleKeyDown")
    SubscribeToEvent("KeyUp", "EditorMainHandleKeyUp")

    SubscribeToEvent("MouseMove", "EditorMainHandleMouseMove")
    SubscribeToEvent("MouseWheel", "EditorMainHandleMouseWheel")
    SubscribeToEvent("MouseButtonDown", "EditorMainHandleMouseButtonDown")
    SubscribeToEvent("MouseButtonUp", "EditorMainHandleMouseButtonUp")

    -- Render events
    SubscribeToEvent("PostRenderUpdate", "EditorMainHandlePostRenderUpdate")

    -- UI events
    SubscribeToEvent("UIMouseClick", "EditorMainHandleUIMouseClick")
    SubscribeToEvent("UIMouseClickEnd", "EditorMainHandleUIMouseClickEnd")

    -- View events
    SubscribeToEvent("BeginViewUpdate", "EditorMainHandleBeginViewUpdate")
    SubscribeToEvent("EndViewUpdate", "EditorMainHandleEndViewUpdate")
    SubscribeToEvent("BeginViewRender", "EditorMainHandleBeginViewRender")
    SubscribeToEvent("EndViewRender", "EditorMainHandleEndViewRender")

    -- Custom editor events
    SubscribeToEvent(EDITOR_EVENT_SCENE_LOADED, "EditorMainHandleSceneLoaded")

    -- Hover events
    SubscribeToEvent("HoverBegin", "EditorMainHandleHoverBegin")
    SubscribeToEvent("HoverEnd", "EditorMainHandleHoverEnd")

    SubscribeToEvent(EDITOR_EVENT_ORIGIN_START_HOVER, "EditorMainHandleOriginStartHover")
    SubscribeToEvent(EDITOR_EVENT_ORIGIN_END_HOVER, "EditorMainHandleOriginEndHover")

    -- Scene events
    SubscribeToEvent("NodeAdded", "EditorMainHandleNodeAdded")
    SubscribeToEvent("NodeRemoved", "EditorMainHandleNodeRemoved")
    SubscribeToEvent("NodeNameChanged", "EditorMainHandleNodeNameChanged")
end

-- Key down event dispatcher
function EditorMainHandleKeyDown(eventType, eventData)
    -- EditorUI handler
    if HandleKeyDown then
        HandleKeyDown(eventType, eventData)
    end

    -- EditorColorWheel handler
    if HandleColorWheelKeyDown then
        HandleColorWheelKeyDown(eventType, eventData)
    end
end

-- Key up event dispatcher
function EditorMainHandleKeyUp(eventType, eventData)
    -- EditorUI handler
    if UnfadeUI then
        UnfadeUI()
    end
end

-- Mouse move event dispatcher
function EditorMainHandleMouseMove(eventType, eventData)
    -- EditorView handler
    if ViewMouseMove then
        ViewMouseMove()
    end

    -- EditorColorWheel handler
    if HandleColorWheelMouseMove then
        HandleColorWheelMouseMove(eventType, eventData)
    end

    -- EditorLayer handler
    if HandleHideLayerEditor then
        HandleHideLayerEditor(eventType, eventData)
    end

    -- PaintSelection handler
    if HandlePaintSelectionMouseMove then
        HandlePaintSelectionMouseMove(eventType, eventData)
    end
end

-- Mouse wheel event dispatcher
function EditorMainHandleMouseWheel(eventType, eventData)
    -- EditorColorWheel handler
    if HandleColorWheelMouseWheel then
        HandleColorWheelMouseWheel(eventType, eventData)
    end

    -- EditorLayer handler
    if HandleMaskTypeScroll then
        HandleMaskTypeScroll(eventType, eventData)
    end

    -- PaintSelection handler
    if HandlePaintSelectionWheel then
        HandlePaintSelectionWheel(eventType, eventData)
    end
end

-- Mouse button down event dispatcher
function EditorMainHandleMouseButtonDown(eventType, eventData)
    -- EditorColorWheel handler
    if HandleColorWheelMouseButtonDown then
        HandleColorWheelMouseButtonDown(eventType, eventData)
    end

    -- EditorLayer handler
    if HandleHideLayerEditor then
        HandleHideLayerEditor(eventType, eventData)
    end
end

-- Mouse button up event dispatcher
function EditorMainHandleMouseButtonUp(eventType, eventData)
    -- EditorUI handler
    if UnfadeUI then
        UnfadeUI()
    end
end

-- Post render update event dispatcher
function EditorMainHandlePostRenderUpdate(eventType, eventData)
    -- EditorView handler
    if HandlePostRenderUpdate then
        HandlePostRenderUpdate()
    end
end

-- UI mouse click event dispatcher
function EditorMainHandleUIMouseClick(eventType, eventData)
    -- EditorView handler
    if ViewMouseClick then
        ViewMouseClick()
    end

    -- EditorViewSelectableOrigins handler
    if HandleOriginToggled then
        HandleOriginToggled(eventType, eventData)
    end
end

-- UI mouse click end event dispatcher
function EditorMainHandleUIMouseClickEnd(eventType, eventData)
    -- EditorView handler
    if ViewMouseClickEnd then
        ViewMouseClickEnd()
    end
end

-- Begin view update event dispatcher
function EditorMainHandleBeginViewUpdate(eventType, eventData)
    -- EditorView handler
    if HandleBeginViewUpdate then
        HandleBeginViewUpdate(eventType, eventData)
    end
end

-- End view update event dispatcher
function EditorMainHandleEndViewUpdate(eventType, eventData)
    -- EditorView handler
    if HandleEndViewUpdate then
        HandleEndViewUpdate(eventType, eventData)
    end
end

-- Begin view render event dispatcher
function EditorMainHandleBeginViewRender(eventType, eventData)
    if HandleBeginViewRender then
        HandleBeginViewRender(eventType, eventData)
    end
end

-- End view render event dispatcher
function EditorMainHandleEndViewRender(eventType, eventData)
    if HandleEndViewRender then
        HandleEndViewRender(eventType, eventData)
    end
end

-- Scene loaded event dispatcher
function EditorMainHandleSceneLoaded(eventType, eventData)
    -- EditorViewSelectableOrigins handler
    if HandleSceneLoadedForOrigins then
        HandleSceneLoadedForOrigins()
    end
end

-- Hover begin event dispatcher
function EditorMainHandleHoverBegin(eventType, eventData)
    -- EditorViewSelectableOrigins handler
    if HandleOriginsHoverBegin then
        HandleOriginsHoverBegin(eventType, eventData)
    end
end

-- Hover end event dispatcher
function EditorMainHandleHoverEnd(eventType, eventData)
    -- EditorViewSelectableOrigins handler
    if HandleOriginsHoverEnd then
        HandleOriginsHoverEnd(eventType, eventData)
    end
end

-- Node added event dispatcher
function EditorMainHandleNodeAdded(eventType, eventData)
    -- Only handle events from editor scene
    local sender = GetEventSender()
    if sender == nil or sender ~= editorScene then
        return
    end

    -- EditorHierarchyWindow handler
    if HandleNodeAdded then
        HandleNodeAdded(eventType, eventData)
    end

    -- EditorViewSelectableOrigins handler
    if rebuildSceneOrigins ~= nil then
        rebuildSceneOrigins = true
    end
end

-- Node removed event dispatcher
function EditorMainHandleNodeRemoved(eventType, eventData)
    -- Only handle events from editor scene
    local sender = GetEventSender()
    if sender == nil or sender ~= editorScene then
        return
    end

    -- EditorHierarchyWindow handler
    if HandleNodeRemoved then
        HandleNodeRemoved(eventType, eventData)
    end

    -- EditorViewSelectableOrigins handler
    if rebuildSceneOrigins ~= nil then
        rebuildSceneOrigins = true
    end
end

-- Node name changed event dispatcher
function EditorMainHandleNodeNameChanged(eventType, eventData)
    -- Only handle events from editor scene
    local sender = GetEventSender()
    if sender == nil or sender ~= editorScene then
        return
    end

    -- EditorHierarchyWindow handler
    if HandleNodeNameChanged then
        HandleNodeNameChanged(eventType, eventData)
    end
end

-- Origin start hover event dispatcher
function EditorMainHandleOriginStartHover(eventType, eventData)
    -- Placeholder for future implementation
end

-- Origin end hover event dispatcher
function EditorMainHandleOriginEndHover(eventType, eventData)
    -- Placeholder for future implementation
end
