-- ============================================================================
-- Widget Base Class
-- UrhoX UI Library - Yoga + NanoVG
-- ============================================================================
--
-- ⚠️ IMPORTANT: Layout uses Yoga engine (like React Native), NOT CSS Flexbox!
--
-- ============================================================================
-- 📦 BOX MODEL: Yoga uses BORDER-BOX (like CSS box-sizing: border-box)
-- ============================================================================
--
-- When you set width/height explicitly:
--   - Padding is INSIDE the width/height (does NOT add to total size)
--   - width = content + padding + border
--
-- When width/height is "auto":
--   - Padding INCREASES the total size
--   - Total size = content + padding + border
--
-- Example:
--   { width = 100, paddingHorizontal = 20 }
--   → Total width = 100 (explicit)
--   → Content area = 100 - 20 - 20 = 60
--
--   { paddingHorizontal = 20, children = { {width = 60} } }
--   → Total width = 60 + 20 + 20 = 100 (auto-sized)
--
-- YGNodeLayoutGetWidth() returns border-box width (includes padding)
-- See: 3rd/yoga/website/docs/styling/width-height.mdx
--
-- ============================================================================
-- 🔄 FLEXBOX DIFFERENCES FROM CSS
-- ============================================================================
--
-- Key differences from CSS:
--   ┌─────────────┬─────────────┬─────────────┐
--   │ Property    │ CSS Default │ Yoga Default│
--   ├─────────────┼─────────────┼─────────────┤
--   │ flexShrink  │ 1 (shrink)  │ 0 (no shrink)│
--   │ flexDirection│ row        │ column      │
--   └─────────────┴─────────────┴─────────────┘
--
-- Common issue: Children overflow parent container
--   - Yoga elements do NOT shrink by default (flexShrink = 0)
--   - If total children size > container size, content will overflow
--
-- Solutions:
--   1. Set flexShrink = 1 on children that should shrink
--   2. Increase container size
--   3. Remove fixed height from container (let it grow)
--   4. Use ScrollView for scrollable content
--
-- ============================================================================

local Style = require("urhox-libs/UI/Core/Style")
local Theme = require("urhox-libs/UI/Core/Theme")
local ImageCache = require("urhox-libs/UI/Core/ImageCache")
local Transition = require("urhox-libs/UI/Core/Transition")

-- Layout dirty callback (set by UI.lua to avoid circular dependency)
local onLayoutDirty_ = nil

-- Transition system callback (set by UI.lua to track widgets with active transitions)
local onTransitionStart_ = nil
local onTransitionEnd_ = nil

-- ============================================================================
-- Props Type Definition
-- ============================================================================

--- RGBA color as array {r, g, b, a} where values are 0-255
---@alias RGBAColor {[1]: number, [2]: number, [3]: number, [4]: number?}

---@class WidgetProps
---@field [string] any Allow custom extension properties
---@field id string|nil Widget identifier
---@field visible boolean|nil Visibility (default: true)
---@field children Widget[]|nil Child widgets
--- Layout - Size
---@field width number|string|nil Width (number, "auto", or "XX%")
---@field height number|string|nil Height (number, "auto", or "XX%")
---@field minWidth number|string|nil Minimum width
---@field maxWidth number|string|nil Maximum width
---@field minHeight number|string|nil Minimum height
---@field maxHeight number|string|nil Maximum height
--- Layout - Flexbox
---@field flexDirection string|nil "row" | "column" | "row-reverse" | "column-reverse"
---@field justifyContent string|nil "flex-start" | "center" | "flex-end" | "space-between" | "space-around" | "space-evenly"
---@field alignItems string|nil "flex-start" | "center" | "flex-end" | "stretch" | "baseline"
---@field alignSelf string|nil "auto" | "flex-start" | "center" | "flex-end" | "stretch" | "baseline"
---@field alignContent string|nil Align content for wrapped lines
---@field flexWrap string|nil "no-wrap" | "wrap" | "wrap-reverse"
---@field flexGrow number|nil Flex grow factor
---@field flexShrink number|nil Flex shrink factor
---@field flexBasis number|string|nil Flex basis
---@field flex number|nil Shorthand for flex grow/shrink/basis
--- Layout - Gap
---@field gap number|string|nil Gap between children
---@field rowGap number|string|nil Row gap
---@field columnGap number|string|nil Column gap
--- Layout - Margin
---@field margin number|string|table|nil Margin: number (all sides), "X%" (percent), "auto", or table
---  Table forms: { left=N, right=N, top=N, bottom=N, horizontal=N, vertical=N } (named keys, values can be number/"X%"/"auto")
---  CSS shorthand: { all }, { vert, horiz }, { top, horiz, bottom }, { top, right, bottom, left }
---@field marginTop number|string|nil Top margin
---@field marginRight number|string|nil Right margin
---@field marginBottom number|string|nil Bottom margin
---@field marginLeft number|string|nil Left margin
---@field marginHorizontal number|string|nil Horizontal margin
---@field marginVertical number|string|nil Vertical margin
--- Layout - Padding
---@field padding number|string|table|nil Padding: number (all sides), "X%" (percent), or table
---  Table forms: { left=N, right=N, top=N, bottom=N, horizontal=N, vertical=N } (named keys, values can be number/"X%")
---  CSS shorthand: { all }, { vert, horiz }, { top, horiz, bottom }, { top, right, bottom, left }
---@field paddingTop number|string|nil Top padding
---@field paddingRight number|string|nil Right padding
---@field paddingBottom number|string|nil Bottom padding
---@field paddingLeft number|string|nil Left padding
---@field paddingHorizontal number|string|nil Horizontal padding
---@field paddingVertical number|string|nil Vertical padding
--- Layout - Position
---@field position string|nil "relative" | "absolute"
---@field top number|string|nil Top position
---@field right number|string|nil Right position
---@field bottom number|string|nil Bottom position
---@field left number|string|nil Left position
---@field overflow string|nil "visible" | "hidden" | "scroll"
---@field aspectRatio number|nil Aspect ratio (e.g. 16/9), Yoga calculates the other dimension
--- Appearance
---@field backgroundColor RGBAColor|false|nil Background color or false to disable
---@field backgroundImage string|nil Background image path
---@field backgroundFit string|nil "fill" | "contain" | "cover"
---@field backgroundSlice table|nil 9-slice {left, top, right, bottom}
---@field imageTint RGBAColor|nil Tint color for background image (multiplicative blend)
---@field borderRadius number|table|nil Border radius: number (uniform) or {TL, TR, BR, BL} (per-corner)
---@field borderRadiusTopLeft number|nil Top-left corner radius (overrides borderRadius)
---@field borderRadiusTopRight number|nil Top-right corner radius (overrides borderRadius)
---@field borderRadiusBottomRight number|nil Bottom-right corner radius (overrides borderRadius)
---@field borderRadiusBottomLeft number|nil Bottom-left corner radius (overrides borderRadius)
---@field borderColor RGBAColor|nil Border color (uniform)
---@field borderWidth number|table|nil Border width: number (uniform) or table
---  Table forms: { top=N, bottom=N, left=N, right=N, horizontal=N, vertical=N } (named keys)
---  CSS shorthand: { all }, { vert, horiz }, { top, horiz, bottom }, { top, right, bottom, left }
---@field borderTopWidth number|nil Top border width
---@field borderTopColor RGBAColor|nil Top border color
---@field borderBottomWidth number|nil Bottom border width
---@field borderBottomColor RGBAColor|nil Bottom border color
---@field borderLeftWidth number|nil Left border width
---@field borderLeftColor RGBAColor|nil Left border color
---@field borderRightWidth number|nil Right border width
---@field borderRightColor RGBAColor|nil Right border color
---@field shape string|nil "rect" | "circle"
---@field backgroundGradient table|nil { type="linear"|"radial", direction, from={RGBA}, to={RGBA} }
--- Shadow
---@field backdropBlur number|nil Backdrop blur intensity (visual approximation, not true Gaussian)
---@field boxShadow table|nil Enhanced shadow array: { {x, y, blur, spread, color, inset}, ... }
---@field shadowBlur number|nil Shadow blur radius (legacy, use boxShadow for advanced)
---@field shadowX number|nil Shadow X offset
---@field shadowY number|nil Shadow Y offset
---@field shadowColor RGBAColor|nil Shadow color
--- Pointer Events
---@field onPointerEnter fun(event: PointerEvent, widget: Widget)|nil
---@field onPointerLeave fun(event: PointerEvent, widget: Widget)|nil
---@field onPointerDown fun(event: PointerEvent, widget: Widget)|nil
---@field onPointerUp fun(event: PointerEvent, widget: Widget)|nil
---@field onPointerMove fun(event: PointerEvent, widget: Widget)|nil
---@field onPointerCancel fun(event: PointerEvent, widget: Widget)|nil
--- Gesture Events
---@field onClick fun(widget: Widget, event?: PointerEvent)|nil
---@field onTap fun(event: GestureEvent, widget: Widget)|nil
---@field onDoubleTap fun(event: GestureEvent, widget: Widget)|nil
---@field onLongPress fun(event: GestureEvent, widget: Widget)|nil
---@field onLongPressStart fun(event: GestureEvent, widget: Widget)|nil
---@field onLongPressEnd fun(event: GestureEvent, widget: Widget)|nil
---@field onSwipe fun(event: GestureEvent, widget: Widget)|nil
---@field onSwipeLeft fun(event: GestureEvent, widget: Widget)|nil
---@field onSwipeRight fun(event: GestureEvent, widget: Widget)|nil
---@field onSwipeUp fun(event: GestureEvent, widget: Widget)|nil
---@field onSwipeDown fun(event: GestureEvent, widget: Widget)|nil
---@field onPan fun(event: GestureEvent, widget: Widget)|nil
---@field onPanStart fun(event: GestureEvent, widget: Widget)|nil
---@field onPanMove fun(event: GestureEvent, widget: Widget)|nil
---@field onPanEnd fun(event: GestureEvent, widget: Widget)|nil
---@field onPinch fun(event: GestureEvent, widget: Widget)|nil
---@field onPinchStart fun(event: GestureEvent, widget: Widget)|nil
---@field onPinchMove fun(event: GestureEvent, widget: Widget)|nil
---@field onPinchEnd fun(event: GestureEvent, widget: Widget)|nil
--- Focus Events
---@field onFocus fun(widget: Widget)|nil
---@field onBlur fun(widget: Widget)|nil
--- Behavior
---@field pointerEvents string|nil "auto" | "none" | "box-none" | "box-only"
---@field allowOverflow boolean|nil Allow content to overflow bounds
--- Typography
---@field fontFamily string|nil Font family name
--- Transitions & Transforms
---@field transition table|string|nil Transition config: { properties, duration, easing } or "all 0.3s easeOut"
---@field opacity number|nil Opacity 0.0~1.0 (default: 1.0, affects entire subtree)
---@field scale number|nil Uniform scale (default: 1.0)
---@field rotate number|nil Rotation in degrees (default: 0)
---@field translateX number|nil X translation in base pixels (default: 0)
---@field translateY number|nil Y translation in base pixels (default: 0)
---@field transformOrigin string|table|nil "center" | "top-left" | { x, y } (default: "center")
---@field visibility string|nil "visible" | "hidden" (default: "visible", hidden keeps layout space)
---@field cursor string|nil Cursor style: "default"|"pointer"|"text"|"move"|"not-allowed"|"crosshair"
---@field position string|nil "sticky" for sticky positioning in ScrollView (vertical only)
---@field stickyOffset number|nil Offset from top when sticky (default: 0)
---@field clipPath string|table|nil Clip shape: "circle"|"ellipse"|{type="circle",radius=N}|{type="ellipse",rx=N,ry=N}

---@class Widget
---@operator call(WidgetProps?): Widget
---@field node YGNodeRef Yoga layout node
---@field parent Widget|nil Parent widget
---@field children Widget[] Child widgets
---@field props WidgetProps Widget properties
---@field new fun(self, props: WidgetProps?): self Constructor
---@field _virtualListIndex integer|nil VirtualList item index (set by VirtualList)
---@field state table Internal state (for stateful widgets)
---@field id string|nil Optional ID for lookup
---@field _className string Widget class name
---@field absoluteLayout table|nil Override absolute layout {x, y, w, h}
---@field renderOffsetX_ number|nil Render offset X (set by ScrollView)
---@field renderOffsetY_ number|nil Render offset Y (set by ScrollView)
---@field renderWidth_ number|nil Render width override
---@field renderHeight_ number|nil Render height override
---@field bodyChildren_ Widget[]|nil Body children (for Card-like widgets)
---@field borderRadius_ number|nil Border radius
---@field GetScroll fun(self): number, number|nil Get scroll position (ScrollView)
---@field GetHitTestChildren fun(self): Widget[]|nil Get children for hit testing
---@field GetPriorityHitAreas fun(self): table[]|nil Get priority hit areas
---@field CustomRenderChildren fun(self, nvg: NVGContextWrapper, renderFn: function)|nil Custom children render
---@field Update fun(self, dt: number)|nil Update callback (for animated widgets)
---@field AddChild fun(self, child: Widget): self Add child widget (overrides UIElement:AddChild)
---@field RemoveChild fun(self, child: Widget): self Remove child widget (overrides UIElement:RemoveChild)
---@field Remove fun(self): Widget Remove widget from parent (can be re-added later)
---@field Destroy fun(self): nil Destroy widget and release resources
local Widget = {}
Widget.__index = Widget
Widget._className = "Widget"

-- Widget types that can be safely auto-upgraded to ScrollView when overflow="scroll".
-- Only "pure containers" qualify — widgets whose Init() adds no structural logic beyond
-- theme defaults and background rendering. Complex widgets (Card, Tabs, etc.) are excluded
-- because their Init() sets up internal structure that would be lost in the upgrade.
local SCROLL_UPGRADEABLE_ = { Widget = true, Panel = true }

-- ============================================================================
-- Class Inheritance
-- ============================================================================

--- Create a new widget class that extends Widget
---@param name string Class name
---@return table New widget class
function Widget:Extend(name)
    local class = {}
    class.__index = class
    class._className = name
    class._super = self
    setmetatable(class, {
        __index = self,
        __call = function(cls, props)
            return cls:new(props)
        end
    })
    return class
end

-- ============================================================================
-- Setter Map (property routing optimization)
-- ============================================================================

--- Pre-build setter map for a class: { propName = setterFn, ... }
--- Walks the full inheritance chain; subclass setters take priority.
--- Called once per class on first instantiation, shared across all instances.
local function buildSetterMap(class)
    local map = {}
    local current = class
    while current do
        for key, val in pairs(current) do
            if type(val) == "function" and #key > 3 and key:sub(1, 3) == "Set" then
                local prop = key:sub(4, 4):lower() .. key:sub(5)
                if map[prop] == nil then
                    map[prop] = val
                end
            end
        end
        local mt = getmetatable(current)
        current = mt and type(mt.__index) == "table" and mt.__index or nil
    end
    return map
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

--- Create a new widget instance
---@param props WidgetProps? Properties
---@return self
function Widget:new(props)
    props = props or {}

    -- ========================================================================
    -- L0 Defense: overflow="scroll"|"auto" → transparent ScrollView upgrade
    -- ========================================================================
    -- AI models trained on CSS naturally write overflow="scroll" or overflow="auto"
    -- to make containers scrollable. In Yoga, overflow only controls clipping
    -- (visible/hidden/scroll), and "auto" isn't even a valid Yoga value (falls
    -- through to YGOverflowVisible). For simple container types (Panel, Widget),
    -- transparently return a ScrollView instead.
    -- Complex widgets (Card, Tabs, etc.) are excluded to preserve their Init() logic.
    if (props.overflow == "scroll" or props.overflow == "auto")
        and SCROLL_UPGRADEABLE_[self._className] then
        local ScrollView = require("urhox-libs/UI/Widgets/ScrollView")
        local originalClass = self._className or "Widget"
        local originalOverflow = props.overflow
        props.overflow = nil  -- ScrollView.Init sets overflow="hidden" internally
        if props.scrollY == nil then
            props.scrollY = true
        end
        print(string.format(
            '[UI] %s{overflow="%s"} → auto-upgraded to ScrollView. '
            .. "Use UI.ScrollView directly to suppress this message.",
            originalClass, originalOverflow
        ))
        return ScrollView:new(props)
    end

    -- ========================================================================
    -- Transparent Property Routing
    -- ========================================================================
    -- Widget instances support property-style access:
    --   widget.text = "Hello"   →  routes to widget:SetText("Hello")
    --   print(widget.text)      →  reads from widget.props.text
    --
    -- This works via __index/__newindex metatable hooks with naming convention:
    --   prop "foo" → looks for "SetFoo" method on the class
    --   If found: writes route to setter, reads route to self.props
    --   If not found: normal rawset/rawget behavior
    --
    -- IMPORTANT: Basic field initialization happens BEFORE setmetatable,
    -- so constructor assignments (props, state, children, etc.) go through
    -- rawset and are NOT intercepted by __newindex.
    -- ========================================================================

    -- Step 1: Initialize all internal fields BEFORE setting metatable.
    -- These assignments are plain table sets, no __newindex interception.
    local instance = {}
    instance._className = self._className or "Widget"
    instance.props = props
    instance.state = {}
    instance.children = {}
    instance.parent = nil
    instance.id = props.id
    -- Normalize visible to boolean (nil → true, false → false)
    -- Single source of truth: props.visible (consistent with all other props)
    props.visible = props.visible ~= false

    -- Create Yoga node
    instance.node = YGNodeNew()

    -- Transition system fields (compact: empty table = no allocation overhead)
    instance.transitions_ = {}     -- Active transition pool
    instance.renderProps_ = {}     -- Interpolated values for rendering
    instance.transitionConfig_ = nil  -- Parsed transition config (lazy)
    instance.initialized_ = false  -- Suppress transitions during construction
    instance.animation_ = nil      -- Active keyframe animation (nil = none)
    instance.eventListeners_ = nil -- Lazy: created on first OnEvent() call

    -- Step 2: Set metatable with property routing.
    -- From this point on, assignments to instance go through __newindex.
    local class = self

    -- Lazy-build setter map (once per class, shared across all instances).
    -- Maps property names to setter functions: { text = SetText, visible = SetVisible, ... }
    -- Eliminates per-access string operations (sub/upper/concat).
    local setterMap = rawget(class, '_setterMap')
    if not setterMap then
        setterMap = buildSetterMap(class)
        rawset(class, '_setterMap', setterMap)
    end

    -- Lazy-init negative cache (once per class, shared across all instances).
    -- Records keys that are neither methods nor properties → O(1) return nil.
    local noMethod = rawget(class, '_noMethod')
    if not noMethod then
        noMethod = {}
        rawset(class, '_noMethod', noMethod)
    end

    setmetatable(instance, {
        __index = function(t, key)
            -- 1. Fast path: known non-existent key (no method, no property)
            if noMethod[key] then return nil end

            -- 2. Class lookup (methods, class fields)
            local v = class[key]
            if v ~= nil then
                -- Cache functions on instance: next access is C-level rawget,
                -- bypasses __index entirely.
                if type(v) == "function" then
                    rawset(t, key, v)
                end
                return v
            end

            -- 3. Property read routing (O(1) map lookup, zero string allocation)
            --    e.g. widget.text → props.text (because SetText exists)
            if setterMap[key] then
                return rawget(t, "props")[key]
            end

            -- 4. Not found anywhere → record in negative cache
            noMethod[key] = true
            return nil
        end,

        __newindex = function(t, key, value)
            -- 1. Key exists on instance (construction fields, cached methods)
            --    → direct rawset, never route through setters.
            --    Preserves: self.state = {} → rawset (not SetState merge)
            if rawget(t, key) ~= nil then
                rawset(t, key, value)
                return
            end

            -- 2. Property routing: setter exists → call it directly
            --    e.g. widget.text = "Hello" → SetText(widget, "Hello")
            local setter = setterMap[key]
            if setter then
                setter(t, value)
                return
            end

            -- 3. No matching setter → normal rawset
            rawset(t, key, value)
        end,
    })

    -- Step 3: Init / Build (metatable is active, method calls work normally)

    -- Call Init if subclass overrides it (this will chain to Widget.Init)
    if class.Init ~= Widget.Init then
        instance:Init(props)
    else
        -- No subclass Init override, do base init directly
        instance:ApplyStyleToYoga(props)
        instance:ProcessChildren(props)
    end

    -- Auto-process Build() if subclass implements it
    -- Build() returns an array of child widgets to be added
    -- This enables declarative UI composition (like React/Flutter)
    local hasBuild = instance.Build ~= nil
    local buildDifferent = instance.Build ~= Widget.Build
    if hasBuild and buildDifferent then
        local buildChildren = instance:Build()
        if buildChildren then
            for _, child in ipairs(buildChildren) do
                if child then
                    instance:AddChild(child)
                end
            end
        end
    end

    -- Parse transition config from initial props (lazy)
    if props.transition then
        instance.transitionConfig_ = Transition.ParseConfig(props.transition)
    end

    -- Mark as initialized: from now on, SetStyle changes may trigger transitions
    instance.initialized_ = true

    return instance
end

--- Build child widgets (override in subclasses for declarative composition)
--- Return an array of child widgets to be automatically added.
--- This is called after Init() during widget construction.
---
--- Usage:
---   function MyWidget:Build()
---       return {
---           UI.Panel { ... },
---           UI.Label { text = "Hello" },
---       }
---   end
---
---@return Widget[]|nil Array of child widgets, or nil
function Widget:Build()
    return nil
end

--- Expand borderWidth table shorthand into per-side properties.
--- Supports named keys: { top=N, bottom=N, left=N, right=N, horizontal=N, vertical=N }
--- CSS array shorthand: {all}, {vert, horiz}, {top, horiz, bottom}, {top, right, bottom, left}
---@param style table Props or style table to expand in-place
local function expandBorderWidthTable(style)
    local bw = style.borderWidth
    if type(bw) ~= "table" then return end

    -- CSS array shorthand
    if #bw > 0 then
        if #bw == 1 then
            style.borderTopWidth = style.borderTopWidth or bw[1]
            style.borderRightWidth = style.borderRightWidth or bw[1]
            style.borderBottomWidth = style.borderBottomWidth or bw[1]
            style.borderLeftWidth = style.borderLeftWidth or bw[1]
        elseif #bw == 2 then
            style.borderTopWidth = style.borderTopWidth or bw[1]
            style.borderBottomWidth = style.borderBottomWidth or bw[1]
            style.borderRightWidth = style.borderRightWidth or bw[2]
            style.borderLeftWidth = style.borderLeftWidth or bw[2]
        elseif #bw == 3 then
            style.borderTopWidth = style.borderTopWidth or bw[1]
            style.borderRightWidth = style.borderRightWidth or bw[2]
            style.borderLeftWidth = style.borderLeftWidth or bw[2]
            style.borderBottomWidth = style.borderBottomWidth or bw[3]
        elseif #bw >= 4 then
            style.borderTopWidth = style.borderTopWidth or bw[1]
            style.borderRightWidth = style.borderRightWidth or bw[2]
            style.borderBottomWidth = style.borderBottomWidth or bw[3]
            style.borderLeftWidth = style.borderLeftWidth or bw[4]
        end
    end

    -- Named keys (override array values)
    if bw.top then style.borderTopWidth = bw.top end
    if bw.right then style.borderRightWidth = bw.right end
    if bw.bottom then style.borderBottomWidth = bw.bottom end
    if bw.left then style.borderLeftWidth = bw.left end
    if bw.horizontal then
        style.borderLeftWidth = style.borderLeftWidth or bw.horizontal
        style.borderRightWidth = style.borderRightWidth or bw.horizontal
    end
    if bw.vertical then
        style.borderTopWidth = style.borderTopWidth or bw.vertical
        style.borderBottomWidth = style.borderBottomWidth or bw.vertical
    end

    -- Clear the table value — per-side props now hold the data
    style.borderWidth = nil
end

--- Base initialization (called by subclasses via Widget.Init(self, props))
---@param props WidgetProps Properties
function Widget:Init(props)
    -- Normalize color properties (convert string formats to RGBA tables)
    Style.NormalizeColorProps(props)

    -- Expand borderWidth table shorthand into per-side properties
    expandBorderWidthTable(props)

    -- Apply style from props
    self:ApplyStyleToYoga(props)

    -- Process children
    self:ProcessChildren(props)
end

--- Process children from props
---@param props WidgetProps Properties
function Widget:ProcessChildren(props)
    -- Process children from props.children
    if props.children then
        for i, child in ipairs(props.children) do
            self:AddChild(child)
        end
    end

    -- Also process array part of props as children
    for i = 1, #props do
        if props[i] then
            self:AddChild(props[i])
        end
    end
end

--- Destroy widget and release resources
function Widget:Destroy()
    -- Cancel all active transitions/animations and unregister from update loop
    local hadActive = #self.transitions_ > 0 or (self.animation_ and self.animation_.active)
    if #self.transitions_ > 0 then
        Transition.CancelAll(self.transitions_)
    end
    self.animation_ = nil
    if hadActive and onTransitionEnd_ then
        onTransitionEnd_(self)
    end

    -- Destroy children first
    for i = #self.children, 1, -1 do
        self.children[i]:Destroy()
    end
    self.children = {}

    -- Remove from parent
    if self.parent then
        self.parent:RemoveChild(self)
    end

    -- Free Yoga node
    if self.node then
        YGNodeFree(self.node)
        self.node = nil
    end
end

--- Remove widget from parent (can be re-added to another parent later)
---@return Widget self for chaining
function Widget:Remove()
    if self.parent then
        self.parent:RemoveChild(self)
    end
    return self
end

-- ============================================================================
-- Visibility
-- ============================================================================

--- Check if widget is visible
---@return boolean
function Widget:IsVisible()
    return self.props.visible ~= false
end

--- Set widget visibility
---@param visible boolean
---@return Widget self for chaining
function Widget:SetVisible(visible)
    self.props.visible = visible
    return self
end

--- Show widget
---@return Widget self for chaining
function Widget:Show()
    self.props.visible = true
    return self
end

--- Hide widget
---@return Widget self for chaining
function Widget:Hide()
    self.props.visible = false
    return self
end

-- ============================================================================
-- Transition System
-- ============================================================================

--- Update active transitions. Called by UI.lua for widgets with active transitions.
---@param dt number Delta time in seconds
function Widget:BaseUpdate(dt)
    local hasTransitions = false
    local hasAnimation = false

    -- Update property transitions
    local pool = self.transitions_
    if #pool > 0 then
        hasTransitions = Transition.Update(pool, dt)
        -- Copy interpolated values to renderProps_ for rendering
        for i = 1, #pool do
            local entry = pool[i]
            self.renderProps_[entry[1]] = entry[8]  -- [1]=prop name, [8]=current value
        end
    end

    -- Update keyframe animation
    local anim = self.animation_
    if anim and anim.active then
        local interpolated = Transition.UpdateKeyframeAnimation(anim, dt)
        if interpolated then
            -- Write interpolated keyframe values to renderProps_
            for k, v in pairs(interpolated) do
                self.renderProps_[k] = v
            end
            hasAnimation = true
        end
        if not anim.active then
            -- fillMode "forwards" or "both": persist final values to props
            local fm = anim.fillMode
            if (fm == "forwards" or fm == "both") and interpolated then
                for k, v in pairs(interpolated) do
                    self.props[k] = v
                end
            end
            -- Animation finished: clear reference
            self.animation_ = nil
        end
    end

    if not hasTransitions and not hasAnimation then
        -- All transitions/animations completed: clean up renderProps_
        for k in pairs(self.renderProps_) do
            self.renderProps_[k] = nil
        end
        -- Notify UI.lua to stop tracking this widget
        if onTransitionEnd_ then
            onTransitionEnd_(self)
        end
    end
end

--- Get the current render value for a property.
--- Returns the interpolated transition value if a transition is active,
--- otherwise falls back to the prop value.
---@param propName string Property name
---@return any Current value for rendering
function Widget:GetRenderProp(propName)
    local rv = self.renderProps_[propName]
    if rv ~= nil then return rv end
    return self.props[propName]
end

--- Check if this widget has any active transitions or animations
---@return boolean
function Widget:HasActiveTransitions()
    return #self.transitions_ > 0 or (self.animation_ ~= nil and self.animation_.active)
end

--- Set transition system callbacks (called by UI.lua)
---@param onStart function(widget) Called when a widget starts its first transition
---@param onEnd function(widget) Called when all transitions on a widget complete
function Widget.SetTransitionCallbacks(onStart, onEnd)
    onTransitionStart_ = onStart
    onTransitionEnd_ = onEnd
end

--- Get the onTransitionStart callback.
--- Used by subclasses (e.g. Button) that start transitions directly via Transition.Start()
--- instead of going through SetStyle(), so they can notify UI.lua for tracking.
---@return function|nil
function Widget.GetTransitionStartCallback()
    return onTransitionStart_
end

-- ============================================================================
-- Keyframe Animation
-- ============================================================================

--- Start a keyframe animation on this widget.
--- Animates multiple properties through keyframe stops over a duration.
--- Keyframe values are written to renderProps_ and take priority over transitions.
---
--- Example:
---   widget:Animate({
---       keyframes = {
---           [0]   = { opacity = 0, translateY = 20 },
---           [0.5] = { opacity = 1, translateY = 5 },
---           [1]   = { opacity = 1, translateY = 0 },
---       },
---       duration = 0.5,
---       easing = "easeOut",
---       loop = true,
---       direction = "alternate",
---       onComplete = function() end,
---   })
---
---@param config table Animation config { keyframes, duration, easing, loop, direction, fillMode, onComplete }
---@return Widget self for chaining
function Widget:Animate(config)
    if not config or not config.keyframes then return self end

    -- Stop any existing animation
    self.animation_ = nil

    -- Create the keyframe animation
    self.animation_ = Transition.CreateKeyframeAnimation(config)

    -- fillMode "backwards" or "both": apply first keyframe to renderProps_ immediately
    -- (prevents one-frame flash of prop values before first BaseUpdate)
    local fm = self.animation_.fillMode
    if fm == "backwards" or fm == "both" then
        local initT = (self.animation_.direction == "reverse") and 1 or 0
        local firstFrame = Transition.InterpolateKeyframes(self.animation_.keyframes, initT)
        if firstFrame then
            for k, v in pairs(firstFrame) do
                self.renderProps_[k] = v
            end
        end
    end

    -- Register with UI.lua for update tracking (same mechanism as transitions)
    if onTransitionStart_ then
        onTransitionStart_(self)
    end

    return self
end

--- Stop the current keyframe animation.
--- Clears renderProps_ for animated properties (snaps to current prop values).
---@return Widget self for chaining
function Widget:StopAnimation()
    if self.animation_ then
        self.animation_.active = false
        self.animation_ = nil

        -- If no transitions either, clean up and unregister
        if #self.transitions_ == 0 then
            for k in pairs(self.renderProps_) do
                self.renderProps_[k] = nil
            end
            if onTransitionEnd_ then
                onTransitionEnd_(self)
            end
        end
    end
    return self
end

-- ============================================================================
-- Child Management
-- ============================================================================

-- ====================================================================
-- Internal: auto-fix maxHeight/maxWidth parent when flexGrow+flexBasis=0 child is added
-- ====================================================================
-- When a child with flexGrow + flexBasis=0 is added to a parent that has
-- maxHeight/maxWidth but no explicit height/width on the MAIN axis, Yoga
-- can't distribute flex space (parent size is indefinite).
-- Fix: convert maxHeight→height (column) or maxWidth→width (row).
--
-- Direction-aware: only fixes the main axis.
-- - column/column-reverse: flexGrow distributes height → fix maxHeight
-- - row/row-reverse: flexGrow distributes width → fix maxWidth
-- Cross-axis max* is left untouched (it doesn't block flex distribution).
--
-- Trade-off: parent always occupies its max size (no longer auto-shrinks).
-- This is acceptable: "always at max size" >> "content invisible (zero size)".
local function autoFixMaxSizeParent(parent, child)
    if not child.props then return end
    -- flex is a shorthand: flex=1 → flexGrow=1, flexShrink=1, flexBasis=0 in Yoga.
    -- But in Lua props, only props.flex is set (flexGrow/flexBasis stay nil).
    -- Must check both props.flexGrow and props.flex.
    local hasFlexGrow = (child.props.flexGrow and child.props.flexGrow > 0)
                     or (child.props.flex and child.props.flex > 0)
    if not hasFlexGrow then return end
    -- flex=N implies flexBasis=0 at Yoga level, so treat it as flexBasis==0
    local hasFlexBasis0 = child.props.flexBasis == 0
                       or (child.props.flex and child.props.flex > 0 and child.props.flexBasis == nil)
    if not hasFlexBasis0 then return end

    -- Determine main axis from parent's flexDirection (default: column)
    local dir = parent.props.flexDirection or "column"
    local isVertical = (dir == "column" or dir == "column-reverse")

    local maxProp, sizeProp, setPercent, setAbsolute
    if isVertical then
        maxProp = "maxHeight"
        sizeProp = "height"
        setPercent = YGNodeStyleSetHeightPercent
        setAbsolute = YGNodeStyleSetHeight
    else
        maxProp = "maxWidth"
        sizeProp = "width"
        setPercent = YGNodeStyleSetWidthPercent
        setAbsolute = YGNodeStyleSetWidth
    end

    -- Only fix if parent has max* but no explicit size on the main axis
    if not parent.props[maxProp] then return end
    if parent.props[sizeProp] then return end

    local maxVal = parent.props[maxProp]
    parent.props[sizeProp] = maxVal

    -- Apply to Yoga node immediately
    if type(maxVal) == "string" and maxVal:match("%%$") then
        setPercent(parent.node, tonumber(maxVal:match("([%d%.]+)")) or 100)
    elseif maxVal == "auto" then
        -- max*="auto" is a no-op, don't convert
        parent.props[sizeProp] = nil
    else
        setAbsolute(parent.node, maxVal)
    end

    -- Keep max* as-is (redundant but harmless; Yoga has no "unset" API)
    if parent.props[sizeProp] then
        local flexVal = child.props.flexGrow or child.props.flex or 0
        print(string.format(
            "[UI] Auto-fix: '%s' %s=%s → %s=%s "
            .. "(child '%s' has flex/flexGrow=%g + flexBasis=0, needs parent with definite size). "
            .. "Set %s explicitly to suppress.",
            parent.props.id or parent._className or "parent",
            maxProp, tostring(maxVal), sizeProp, tostring(maxVal),
            child.props.id or child._className or "child",
            flexVal,
            sizeProp
        ))
    end
end

--- Add a child widget
---@param child Widget
---@return Widget self for chaining
function Widget:AddChild(child)
    if not child then return self end

    -- Type check: must be a Widget object
    local childType = type(child)
    if childType ~= "table" or not child.Render then
        local hint = childType == "table" and " (table without Render method - did you forget table.unpack(children)?)" or ""
        error("Widget:AddChild() expects a Widget object, got " .. childType .. hint, 2)
    end

    -- Remove from previous parent
    if child.parent then
        child.parent:RemoveChild(child)
    end

    -- Add to children array
    table.insert(self.children, child)
    child.parent = self

    -- Add to Yoga tree
    YGNodeInsertChild(self.node, child.node, #self.children - 1)

    -- Auto-fix maxHeight parent for flex distribution
    autoFixMaxSizeParent(self, child)

    -- Invalidate z-index sort cache:
    -- Must re-sort if new child has zIndex, OR if cache exists (new child missing from cache)
    if child.props.zIndex or self.sortedChildren_ then
        self.needsZSort_ = true
    end

    -- Notify layout system
    if onLayoutDirty_ then onLayoutDirty_() end

    return self
end

--- Remove a child widget
---@param child Widget
---@return Widget self for chaining
function Widget:RemoveChild(child)
    for i, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, i)
            child.parent = nil
            YGNodeRemoveChild(self.node, child.node)
            -- Invalidate z-index sort cache
            if self.sortedChildren_ then
                self.needsZSort_ = true
            end
            -- Notify layout system
            if onLayoutDirty_ then onLayoutDirty_() end
            break
        end
    end
    return self
end

--- Insert a child widget at specific index
---@param child Widget
---@param index number 1-based index
---@return Widget self for chaining
function Widget:InsertChild(child, index)
    -- Type check: must be a Widget object
    local childType = type(child)
    if childType ~= "table" or not child.Render then
        local hint = childType == "table" and " (table without Render method - did you forget table.unpack(children)?)" or ""
        error("Widget:InsertChild() expects a Widget object, got " .. childType .. hint, 2)
    end

    -- Remove from previous parent (same as AddChild)
    if child.parent then
        child.parent:RemoveChild(child)
    end

    index = math.max(1, math.min(index, #self.children + 1))
    table.insert(self.children, index, child)
    child.parent = self

    -- Add to Yoga tree at correct position (0-based)
    YGNodeInsertChild(self.node, child.node, index - 1)

    -- Auto-fix maxHeight parent for flex distribution
    autoFixMaxSizeParent(self, child)

    -- Invalidate z-index sort cache:
    -- Must re-sort if new child has zIndex, OR if cache exists (new child missing from cache)
    if child.props.zIndex or self.sortedChildren_ then
        self.needsZSort_ = true
    end

    -- Notify layout system
    if onLayoutDirty_ then onLayoutDirty_() end

    return self
end

--- Remove all children
---@return Widget self for chaining
function Widget:ClearChildren()
    if #self.children == 0 then return self end

    for i = #self.children, 1, -1 do
        local child = self.children[i]
        child.parent = nil
        YGNodeRemoveChild(self.node, child.node)
        table.remove(self.children, i)
    end

    -- Notify layout system
    if onLayoutDirty_ then onLayoutDirty_() end

    return self
end

--- Alias for ClearChildren
Widget.RemoveAllChildren = Widget.ClearChildren

--- Find child by ID recursively
---@param id string
---@return Widget|nil
function Widget:FindById(id)
    if self.id == id then
        return self
    end
    for _, child in ipairs(self.children) do
        local found = child:FindById(id)
        if found then
            return found
        end
    end
    return nil
end

--- Get number of children
---@return number
function Widget:GetNumChildren()
    return #self.children
end

--- Get child at index (1-based)
---@param index number 1-based index
---@return Widget|nil
function Widget:GetChildAt(index)
    return self.children[index]
end

--- Get children array (returns the internal table directly, do not modify)
---@return Widget[]
function Widget:GetChildren()
    return self.children
end

-- ============================================================================
-- Style & Layout
-- ============================================================================

--- Apply a single padding value (handles number and percentage string)
--- Warns on invalid value types (aligned with project "proactive feedback" principle)
---@param node YGNodeRef
---@param edge number YGEdge constant
---@param value number|string The padding value
local function applyPaddingValue(node, edge, value)
    if type(value) == "string" and value:match("%%$") then
        YGNodeStyleSetPaddingPercent(node, edge, tonumber(value:match("([%d%.]+)")) or 0)
    elseif type(value) == "number" then
        YGNodeStyleSetPadding(node, edge, value)
    else
        print("[UI Warning] Invalid padding value: " .. tostring(value) .. " (" .. type(value) .. "). Expected number or \"N%\".")
    end
end

--- Apply a single margin value (handles number, percentage string, and "auto")
--- Warns on invalid value types (aligned with project "proactive feedback" principle)
---@param node YGNodeRef
---@param edge number YGEdge constant
---@param value number|string The margin value
local function applyMarginValue(node, edge, value)
    if value == "auto" then
        YGNodeStyleSetMarginAuto(node, edge)
    elseif type(value) == "string" and value:match("%%$") then
        YGNodeStyleSetMarginPercent(node, edge, tonumber(value:match("([%d%.]+)")) or 0)
    elseif type(value) == "number" then
        YGNodeStyleSetMargin(node, edge, value)
    else
        print("[UI Warning] Invalid margin value: " .. tostring(value) .. " (" .. type(value) .. "). Expected number, \"N%\", or \"auto\".")
    end
end

--- Apply style properties to Yoga node
--- All values are in base pixels (Yoga works in base pixel space)
---@param style table
function Widget:ApplyStyleToYoga(style)
    if not style or not self.node then return end

    local node = self.node

    -- Size
    local width = style.width
    if width then
        if type(width) == "string" and width:match("%%$") then
            YGNodeStyleSetWidthPercent(node, tonumber(width:match("([%d%.]+)")) or 100)
        elseif width == "auto" then
            YGNodeStyleSetWidthAuto(node)
        else
            YGNodeStyleSetWidth(node, width)
        end
    end
    local height = style.height
    if height then
        if type(height) == "string" and height:match("%%$") then
            YGNodeStyleSetHeightPercent(node, tonumber(height:match("([%d%.]+)")) or 100)
        elseif height == "auto" then
            YGNodeStyleSetHeightAuto(node)
        else
            YGNodeStyleSetHeight(node, height)
        end
    end
    if style.minWidth then
        if style.minWidth == "max-content" then
            YGNodeStyleSetMinWidthMaxContent(node)
        elseif style.minWidth == "fit-content" then
            YGNodeStyleSetMinWidthFitContent(node)
        elseif style.minWidth == "stretch" then
            YGNodeStyleSetMinWidthStretch(node)
        elseif type(style.minWidth) == "string" and style.minWidth:match("%%$") then
            YGNodeStyleSetMinWidthPercent(node, tonumber(style.minWidth:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMinWidth(node, style.minWidth)
        end
    end
    if style.maxWidth then
        if style.maxWidth == "max-content" then
            YGNodeStyleSetMaxWidthMaxContent(node)
        elseif style.maxWidth == "fit-content" then
            YGNodeStyleSetMaxWidthFitContent(node)
        elseif style.maxWidth == "stretch" then
            YGNodeStyleSetMaxWidthStretch(node)
        elseif type(style.maxWidth) == "string" and style.maxWidth:match("%%$") then
            YGNodeStyleSetMaxWidthPercent(node, tonumber(style.maxWidth:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMaxWidth(node, style.maxWidth)
        end
    end
    if style.minHeight then
        if style.minHeight == "max-content" then
            YGNodeStyleSetMinHeightMaxContent(node)
        elseif style.minHeight == "fit-content" then
            YGNodeStyleSetMinHeightFitContent(node)
        elseif style.minHeight == "stretch" then
            YGNodeStyleSetMinHeightStretch(node)
        elseif type(style.minHeight) == "string" and style.minHeight:match("%%$") then
            YGNodeStyleSetMinHeightPercent(node, tonumber(style.minHeight:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMinHeight(node, style.minHeight)
        end
    end
    if style.maxHeight then
        if style.maxHeight == "max-content" then
            YGNodeStyleSetMaxHeightMaxContent(node)
        elseif style.maxHeight == "fit-content" then
            YGNodeStyleSetMaxHeightFitContent(node)
        elseif style.maxHeight == "stretch" then
            YGNodeStyleSetMaxHeightStretch(node)
        elseif type(style.maxHeight) == "string" and style.maxHeight:match("%%$") then
            YGNodeStyleSetMaxHeightPercent(node, tonumber(style.maxHeight:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMaxHeight(node, style.maxHeight)
        end
    end

    -- Flex direction
    if style.flexDirection then
        YGNodeStyleSetFlexDirection(node, Style.FlexDirectionToYoga(style.flexDirection))
    end

    -- Justify content
    if style.justifyContent then
        YGNodeStyleSetJustifyContent(node, Style.JustifyContentToYoga(style.justifyContent))
    end

    -- Align items
    if style.alignItems then
        YGNodeStyleSetAlignItems(node, Style.AlignItemsToYoga(style.alignItems))
    end

    -- Align self
    if style.alignSelf then
        YGNodeStyleSetAlignSelf(node, Style.AlignSelfToYoga(style.alignSelf))
    end

    -- Align content (default to stretch like CSS, only affects flexWrap multiline)
    YGNodeStyleSetAlignContent(node, Style.AlignContentToYoga(style.alignContent or "stretch"))

    -- Flex properties
    if style.flexWrap then
        YGNodeStyleSetFlexWrap(node, Style.WrapToYoga(style.flexWrap))
    end
    if style.flexGrow then YGNodeStyleSetFlexGrow(node, style.flexGrow) end
    if style.flexShrink then YGNodeStyleSetFlexShrink(node, style.flexShrink) end
    if style.flexBasis then
        if style.flexBasis == "auto" then
            YGNodeStyleSetFlexBasisAuto(node)
        elseif style.flexBasis == "max-content" then
            YGNodeStyleSetFlexBasisMaxContent(node)
        elseif style.flexBasis == "fit-content" then
            YGNodeStyleSetFlexBasisFitContent(node)
        elseif style.flexBasis == "stretch" then
            YGNodeStyleSetFlexBasisStretch(node)
        elseif type(style.flexBasis) == "string" and style.flexBasis:match("%%$") then
            YGNodeStyleSetFlexBasisPercent(node, tonumber(style.flexBasis:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetFlexBasis(node, style.flexBasis)
        end
    end
    if style.flex then YGNodeStyleSetFlex(node, style.flex) end

    -- Gap
    if style.gap then
        if type(style.gap) == "string" and style.gap:match("%%$") then
            YGNodeStyleSetGapPercent(node, YGGutterAll, tonumber(style.gap:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetGap(node, YGGutterAll, style.gap)
        end
    end
    if style.rowGap then
        if type(style.rowGap) == "string" and style.rowGap:match("%%$") then
            YGNodeStyleSetGapPercent(node, YGGutterRow, tonumber(style.rowGap:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetGap(node, YGGutterRow, style.rowGap)
        end
    end
    if style.columnGap then
        if type(style.columnGap) == "string" and style.columnGap:match("%%$") then
            YGNodeStyleSetGapPercent(node, YGGutterColumn, tonumber(style.columnGap:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetGap(node, YGGutterColumn, style.columnGap)
        end
    end

    -- Margin
    if style.margin then
        if type(style.margin) == "table" then
            local m = style.margin
            -- CSS array shorthand: {all}, {vert, horiz}, {top, horiz, bottom}, {top, right, bottom, left}
            if #m > 0 then
                if #m == 1 then
                    applyMarginValue(node, YGEdgeAll, m[1])
                elseif #m == 2 then
                    applyMarginValue(node, YGEdgeVertical, m[1])
                    applyMarginValue(node, YGEdgeHorizontal, m[2])
                elseif #m == 3 then
                    applyMarginValue(node, YGEdgeTop, m[1])
                    applyMarginValue(node, YGEdgeHorizontal, m[2])
                    applyMarginValue(node, YGEdgeBottom, m[3])
                elseif #m >= 4 then
                    applyMarginValue(node, YGEdgeTop, m[1])
                    applyMarginValue(node, YGEdgeRight, m[2])
                    applyMarginValue(node, YGEdgeBottom, m[3])
                    applyMarginValue(node, YGEdgeLeft, m[4])
                end
            end
            -- Named keys (can coexist with or override array values)
            if m.top then applyMarginValue(node, YGEdgeTop, m.top) end
            if m.right then applyMarginValue(node, YGEdgeRight, m.right) end
            if m.bottom then applyMarginValue(node, YGEdgeBottom, m.bottom) end
            if m.left then applyMarginValue(node, YGEdgeLeft, m.left) end
            if m.horizontal then applyMarginValue(node, YGEdgeHorizontal, m.horizontal) end
            if m.vertical then applyMarginValue(node, YGEdgeVertical, m.vertical) end
        elseif style.margin == "auto" then
            YGNodeStyleSetMarginAuto(node, YGEdgeAll)
        elseif type(style.margin) == "string" and style.margin:match("%%$") then
            YGNodeStyleSetMarginPercent(node, YGEdgeAll, tonumber(style.margin:match("([%d%.]+)")) or 0)
        elseif type(style.margin) == "number" then
            YGNodeStyleSetMargin(node, YGEdgeAll, style.margin)
        end
    end
    if style.marginTop then
        if style.marginTop == "auto" then
            YGNodeStyleSetMarginAuto(node, YGEdgeTop)
        elseif type(style.marginTop) == "string" and style.marginTop:match("%%$") then
            YGNodeStyleSetMarginPercent(node, YGEdgeTop, tonumber(style.marginTop:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMargin(node, YGEdgeTop, style.marginTop)
        end
    end
    if style.marginRight then
        if style.marginRight == "auto" then
            YGNodeStyleSetMarginAuto(node, YGEdgeRight)
        elseif type(style.marginRight) == "string" and style.marginRight:match("%%$") then
            YGNodeStyleSetMarginPercent(node, YGEdgeRight, tonumber(style.marginRight:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMargin(node, YGEdgeRight, style.marginRight)
        end
    end
    if style.marginBottom then
        if style.marginBottom == "auto" then
            YGNodeStyleSetMarginAuto(node, YGEdgeBottom)
        elseif type(style.marginBottom) == "string" and style.marginBottom:match("%%$") then
            YGNodeStyleSetMarginPercent(node, YGEdgeBottom, tonumber(style.marginBottom:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMargin(node, YGEdgeBottom, style.marginBottom)
        end
    end
    if style.marginLeft then
        if style.marginLeft == "auto" then
            YGNodeStyleSetMarginAuto(node, YGEdgeLeft)
        elseif type(style.marginLeft) == "string" and style.marginLeft:match("%%$") then
            YGNodeStyleSetMarginPercent(node, YGEdgeLeft, tonumber(style.marginLeft:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMargin(node, YGEdgeLeft, style.marginLeft)
        end
    end
    if style.marginHorizontal then
        if style.marginHorizontal == "auto" then
            YGNodeStyleSetMarginAuto(node, YGEdgeHorizontal)
        elseif type(style.marginHorizontal) == "string" and style.marginHorizontal:match("%%$") then
            YGNodeStyleSetMarginPercent(node, YGEdgeHorizontal, tonumber(style.marginHorizontal:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMargin(node, YGEdgeHorizontal, style.marginHorizontal)
        end
    end
    if style.marginVertical then
        if style.marginVertical == "auto" then
            YGNodeStyleSetMarginAuto(node, YGEdgeVertical)
        elseif type(style.marginVertical) == "string" and style.marginVertical:match("%%$") then
            YGNodeStyleSetMarginPercent(node, YGEdgeVertical, tonumber(style.marginVertical:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetMargin(node, YGEdgeVertical, style.marginVertical)
        end
    end

    -- Padding
    if style.padding then
        if type(style.padding) == "table" then
            local p = style.padding
            -- CSS array shorthand: {all}, {vert, horiz}, {top, horiz, bottom}, {top, right, bottom, left}
            if #p > 0 then
                if #p == 1 then
                    applyPaddingValue(node, YGEdgeAll, p[1])
                elseif #p == 2 then
                    applyPaddingValue(node, YGEdgeVertical, p[1])
                    applyPaddingValue(node, YGEdgeHorizontal, p[2])
                elseif #p == 3 then
                    applyPaddingValue(node, YGEdgeTop, p[1])
                    applyPaddingValue(node, YGEdgeHorizontal, p[2])
                    applyPaddingValue(node, YGEdgeBottom, p[3])
                elseif #p >= 4 then
                    applyPaddingValue(node, YGEdgeTop, p[1])
                    applyPaddingValue(node, YGEdgeRight, p[2])
                    applyPaddingValue(node, YGEdgeBottom, p[3])
                    applyPaddingValue(node, YGEdgeLeft, p[4])
                end
            end
            -- Named keys (can coexist with or override array values)
            if p.top then applyPaddingValue(node, YGEdgeTop, p.top) end
            if p.right then applyPaddingValue(node, YGEdgeRight, p.right) end
            if p.bottom then applyPaddingValue(node, YGEdgeBottom, p.bottom) end
            if p.left then applyPaddingValue(node, YGEdgeLeft, p.left) end
            if p.horizontal then applyPaddingValue(node, YGEdgeHorizontal, p.horizontal) end
            if p.vertical then applyPaddingValue(node, YGEdgeVertical, p.vertical) end
        elseif type(style.padding) == "string" and style.padding:match("%%$") then
            YGNodeStyleSetPaddingPercent(node, YGEdgeAll, tonumber(style.padding:match("([%d%.]+)")) or 0)
        elseif type(style.padding) == "number" then
            YGNodeStyleSetPadding(node, YGEdgeAll, style.padding)
        end
    end
    if style.paddingTop then
        if type(style.paddingTop) == "string" and style.paddingTop:match("%%$") then
            YGNodeStyleSetPaddingPercent(node, YGEdgeTop, tonumber(style.paddingTop:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPadding(node, YGEdgeTop, style.paddingTop)
        end
    end
    if style.paddingRight then
        if type(style.paddingRight) == "string" and style.paddingRight:match("%%$") then
            YGNodeStyleSetPaddingPercent(node, YGEdgeRight, tonumber(style.paddingRight:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPadding(node, YGEdgeRight, style.paddingRight)
        end
    end
    if style.paddingBottom then
        if type(style.paddingBottom) == "string" and style.paddingBottom:match("%%$") then
            YGNodeStyleSetPaddingPercent(node, YGEdgeBottom, tonumber(style.paddingBottom:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPadding(node, YGEdgeBottom, style.paddingBottom)
        end
    end
    if style.paddingLeft then
        if type(style.paddingLeft) == "string" and style.paddingLeft:match("%%$") then
            YGNodeStyleSetPaddingPercent(node, YGEdgeLeft, tonumber(style.paddingLeft:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPadding(node, YGEdgeLeft, style.paddingLeft)
        end
    end
    if style.paddingHorizontal then
        if type(style.paddingHorizontal) == "string" and style.paddingHorizontal:match("%%$") then
            YGNodeStyleSetPaddingPercent(node, YGEdgeHorizontal, tonumber(style.paddingHorizontal:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPadding(node, YGEdgeHorizontal, style.paddingHorizontal)
        end
    end
    if style.paddingVertical then
        if type(style.paddingVertical) == "string" and style.paddingVertical:match("%%$") then
            YGNodeStyleSetPaddingPercent(node, YGEdgeVertical, tonumber(style.paddingVertical:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPadding(node, YGEdgeVertical, style.paddingVertical)
        end
    end

    -- Position
    if style.position then
        YGNodeStyleSetPositionType(node, Style.PositionTypeToYoga(style.position))
    end
    if style.top then
        if type(style.top) == "string" and style.top:match("%%$") then
            YGNodeStyleSetPositionPercent(node, YGEdgeTop, tonumber(style.top:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPosition(node, YGEdgeTop, style.top)
        end
    end
    if style.right then
        if type(style.right) == "string" and style.right:match("%%$") then
            YGNodeStyleSetPositionPercent(node, YGEdgeRight, tonumber(style.right:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPosition(node, YGEdgeRight, style.right)
        end
    end
    if style.bottom then
        if type(style.bottom) == "string" and style.bottom:match("%%$") then
            YGNodeStyleSetPositionPercent(node, YGEdgeBottom, tonumber(style.bottom:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPosition(node, YGEdgeBottom, style.bottom)
        end
    end
    if style.left then
        if type(style.left) == "string" and style.left:match("%%$") then
            YGNodeStyleSetPositionPercent(node, YGEdgeLeft, tonumber(style.left:match("([%d%.]+)")) or 0)
        else
            YGNodeStyleSetPosition(node, YGEdgeLeft, style.left)
        end
    end

    -- Aspect ratio
    if style.aspectRatio then
        YGNodeStyleSetAspectRatio(node, style.aspectRatio)

        -- Yoga workaround: Yoga computes aspectRatio from unconstrained percentage
        -- width/height BEFORE applying maxWidth/maxHeight. CSS applies aspect-ratio
        -- AFTER max constraints. To match CSS behavior, we add the missing reverse
        -- constraint: percentage width + maxWidth → add maxHeight = maxWidth / aspectRatio
        --             percentage height + maxHeight → add maxWidth = maxHeight * aspectRatio
        -- This lets Yoga's maxHeight/maxWidth cap the oversized dimension.
        local ar = style.aspectRatio
        local w = style.width
        local h = style.height
        if type(w) == "string" and w:match("%%$") and style.maxWidth and not style.maxHeight then
            YGNodeStyleSetMaxHeight(node, style.maxWidth / ar)
        end
        if type(h) == "string" and h:match("%%$") and style.maxHeight and not style.maxWidth then
            YGNodeStyleSetMaxWidth(node, style.maxHeight * ar)
        end
    end

    -- Overflow (critical for ScrollView)
    if style.overflow then
        -- Warn about overflow="scroll"/"auto" misuse:
        -- Yoga's overflow only controls clipping, NOT scrolling behavior.
        -- ScrollView.Init forces overflow="hidden" before reaching here,
        -- so this warning only fires for non-ScrollView widgets (not in whitelist).
        if style.overflow == "scroll" or style.overflow == "auto" then
            print(string.format(
                '[UI Warning] overflow="%s" on %s has no scrolling effect. '
                .. "Yoga overflow only controls clipping. Use UI.ScrollView for scrollable content.",
                style.overflow, self._className or "Widget"
            ))
        end

        local overflowMap = {
            ["visible"] = YGOverflowVisible,
            ["hidden"] = YGOverflowHidden,
            ["scroll"] = YGOverflowScroll,
        }
        local overflow = overflowMap[style.overflow] or YGOverflowVisible
        YGNodeStyleSetOverflow(node, overflow)
    end
end

--- Set style and update Yoga node
---@param style table
---@return Widget self
function Widget:SetStyle(style)
    -- Normalize color properties (convert string formats to RGBA tables)
    Style.NormalizeColorProps(style)
    -- Expand borderWidth table shorthand into per-side properties
    expandBorderWidthTable(style)
    self:ApplyStyleToYoga(style)

    -- Update transition config if provided
    if style.transition ~= nil then
        self.transitionConfig_ = Transition.ParseConfig(style.transition)
    end

    -- Check for transitionable property changes
    local config = self.transitionConfig_
    if config and self.initialized_ then
        local wasEmpty = #self.transitions_ == 0
        for k, v in pairs(style) do
            -- Skip non-transitionable props and the transition config itself
            if k ~= "transition" and Transition.ConfigIncludesProperty(config, k) then
                local oldVal = self.props[k]
                if oldVal ~= nil and oldVal ~= v then
                    -- Start or redirect transition (from current rendered value to new value)
                    local currentVal = self.renderProps_[k] or oldVal
                    local dur, eas = Transition.GetPropertyConfig(config, k)
                    Transition.Start(self.transitions_, k, currentVal, v, dur, eas)
                end
            end
        end
        -- Notify UI.lua to track this widget for updates (only on first transition)
        if wasEmpty and #self.transitions_ > 0 and onTransitionStart_ then
            onTransitionStart_(self)
        end
    end

    -- Merge style props (always update props to the target value)
    for k, v in pairs(style) do
        self.props[k] = v
    end

    -- Invalidate parent's z-index sort cache if zIndex changed
    if style.zIndex and self.parent then
        self.parent.needsZSort_ = true
    end

    -- Notify layout system (style changes may affect layout)
    if onLayoutDirty_ then onLayoutDirty_() end
    return self
end

--- Set width in base pixels
---@param width number Width in base pixels
---@return Widget self
function Widget:SetWidth(width)
    YGNodeStyleSetWidth(self.node, width)
    self.props.width = width
    if onLayoutDirty_ then onLayoutDirty_() end
    return self
end

--- Set height in base pixels
---@param height number Height in base pixels
---@return Widget self
function Widget:SetHeight(height)
    YGNodeStyleSetHeight(self.node, height)
    self.props.height = height
    if onLayoutDirty_ then onLayoutDirty_() end
    return self
end

--- Get layout result (relative to parent)
--- Returns coordinates in BASE PIXELS (design-time units)
--- Yoga works in base pixel space, returns base pixels directly
---@return table { x, y, w, h }
function Widget:GetLayout()
    return {
        x = YGNodeLayoutGetLeft(self.node),
        y = YGNodeLayoutGetTop(self.node),
        w = YGNodeLayoutGetWidth(self.node),
        h = YGNodeLayoutGetHeight(self.node),
    }
end

--- Get absolute layout (accumulated from root)
--- Note: This returns the RENDER position (used by NanoVG after nvgTranslate)
--- For HitTest, use GetAbsoluteLayoutForHitTest which accounts for scroll offset
---@return table { x, y, w, h }
function Widget:GetAbsoluteLayout()
    -- Use manually set absolute layout if available (for custom positioning)
    -- This allows widgets to bypass Yoga layout for manual positioning
    if self.absoluteLayout then
        return self.absoluteLayout
    end

    -- Fixed positioning: viewport-relative coordinates set by UI.Render
    if self.fixedOffset_ then
        local layout = self:GetLayout()
        return { x = self.fixedOffset_[1], y = self.fixedOffset_[2], w = layout.w, h = layout.h }
    end

    local layout = self:GetLayout()
    local x, y = layout.x, layout.y

    -- Apply render offset/size if set (for manually positioned children like Tab content)
    if self.renderOffsetX_ then
        return {
            x = self.renderOffsetX_,
            y = self.renderOffsetY_ or y,
            w = self.renderWidth_ or layout.w,
            h = self.renderHeight_ or layout.h
        }
    end

    local p = self.parent
    while p do
        -- Fixed parent: use fixed position as absolute base, stop walking
        if p.fixedOffset_ then
            x = x + p.fixedOffset_[1]
            y = y + p.fixedOffset_[2]
            break
        end
        -- If parent has render offset, use it directly and stop traversal
        if p.renderOffsetX_ then
            x = x + p.renderOffsetX_
            y = y + (p.renderOffsetY_ or 0)
            break
        end
        local pl = p:GetLayout()
        x = x + pl.x
        y = y + pl.y
        p = p.parent
    end

    return { x = x, y = y, w = layout.w, h = layout.h }
end

--- Get absolute layout for HitTest (accounts for scroll offset)
--- This returns the VISUAL position on screen
---@return table { x, y, w, h }
function Widget:GetAbsoluteLayoutForHitTest()
    -- Use manually set absolute layout if available (for custom positioning)
    if self.absoluteLayout then
        return self.absoluteLayout
    end

    -- Fixed positioning: viewport-relative coordinates (no scroll offset applies)
    if self.fixedOffset_ then
        local layout = self:GetLayout()
        return { x = self.fixedOffset_[1], y = self.fixedOffset_[2], w = layout.w, h = layout.h }
    end

    local layout = self:GetLayout()
    local x, y = layout.x, layout.y
    local w, h = layout.w, layout.h

    -- Apply render offset/size if set
    if self.renderOffsetX_ then
        x = self.renderOffsetX_
        y = self.renderOffsetY_ or y
        w = self.renderWidth_ or w
        h = self.renderHeight_ or h
        -- Still need to account for scroll offset from ancestors
        local p = self.parent
        while p do
            if p.GetScroll then
                local sx, sy = p:GetScroll()
                x = x - sx
                y = y - sy
            end
            p = p.parent
        end
        return { x = x, y = y, w = w, h = h }
    end

    local p = self.parent
    while p do
        -- Fixed parent: use fixed position as absolute base, stop walking
        -- No scroll offset applies (fixed is relative to viewport, not scroll container)
        if p.fixedOffset_ then
            x = x + p.fixedOffset_[1]
            y = y + p.fixedOffset_[2]
            return { x = x, y = y, w = w, h = h }
        end
        -- If parent has render offset, use it directly and stop traversal
        if p.renderOffsetX_ then
            x = x + p.renderOffsetX_
            y = y + (p.renderOffsetY_ or 0)
            -- Check if THIS parent also has scroll offset (e.g., ScrollView as tab content)
            if p.GetScroll then
                local sx, sy = p:GetScroll()
                x = x - sx
                y = y - sy
            end
            -- Still need to continue for scroll offset from ancestors
            p = p.parent
            while p do
                if p.GetScroll then
                    local sx, sy = p:GetScroll()
                    x = x - sx
                    y = y - sy
                end
                p = p.parent
            end
            break
        end
        local pl = p:GetLayout()
        x = x + pl.x
        y = y + pl.y
        -- Account for scroll offset if parent is scrollable
        if p.GetScroll then
            local sx, sy = p:GetScroll()
            x = x - sx
            y = y - sy
        end
        p = p.parent
    end

    return { x = x, y = y, w = w, h = h }
end

--- Get absolute position (x, y)
---@return number x, number y
function Widget:GetAbsolutePosition()
    local l = self:GetAbsoluteLayout()
    return l.x, l.y
end

--- Get computed size (w, h)
---@return number w, number h
function Widget:GetComputedSize()
    local l = self:GetLayout()
    return l.w, l.h
end

-- ============================================================================
-- Rendering
-- ============================================================================

--- Render the widget (override in subclasses)
--- NOTE: Framework handles child rendering automatically via UI.Render().
--- Only implement self-drawing here. Children are rendered automatically.
---@param nvg NVGContextWrapper
function Widget:Render(nvg)
    -- Default: render background (shadow + color + image + border)
    -- Children are rendered by framework automatically
    self:RenderFullBackground(nvg)
end

--- Custom child rendering hook (optional override)
--- Implement this if your widget needs special handling before/after rendering children.
--- Examples: ScrollView (scroll offset + clipping), Panel with overflow="hidden"
---
--- Usage:
---   function MyWidget:CustomRenderChildren(nvg, renderFn)
---       nvgSave(nvg)
---       nvgIntersectScissor(nvg, ...)  -- IMPORTANT: use IntersectScissor (not nvgScissor) to preserve parent clipping
---       nvgTranslate(nvg, ...)  -- Apply transform
---
---       for _, child in ipairs(self.children) do
---           renderFn(child, nvg)  -- Recursively render each child
---       end
---
---       nvgRestore(nvg)
---       self:RenderOverlays(nvg)  -- Render things on top of children
---   end
---
-- ---@param nvg NVGContextWrapper
-- ---@param renderFn function(widget, nvg) The recursive render function to call for each child
-- function Widget:CustomRenderChildren(nvg, renderFn)
--     -- Default implementation (not defined = framework handles it)
-- end

--- Get children list in correct render order (respecting z-index).
--- Use this in CustomRenderChildren instead of self.children directly
--- to ensure z-index sorting works for widgets with custom render logic.
---@return Widget[] Children list (sorted by zIndex if needed, or self.children)
function Widget:GetRenderChildren()
    local children = self.children
    if self.needsZSort_ then
        local sorted = {}
        for i = 1, #children do
            sorted[i] = children[i]
        end
        table.sort(sorted, function(a, b)
            return (a.props.zIndex or 0) < (b.props.zIndex or 0)
        end)
        self.sortedChildren_ = sorted
        self.needsZSort_ = false
    end
    return self.sortedChildren_ or children
end

--- Render background with color and border radius
---@param nvg NVGContextWrapper
---@param color RGBAColor|nil RGBA color
---@param radius number|nil Border radius
function Widget:RenderBackground(nvg, color, radius)
    if not color then return end

    local l = self:GetAbsoluteLayout()
    radius = radius or self.props.borderRadius or 0

    nvgBeginPath(nvg)
    if radius > 0 then
        nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, radius)
    else
        nvgRect(nvg, l.x, l.y, l.w, l.h)
    end
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(nvg)
end

--- Render border
---@param nvg NVGContextWrapper
---@param color RGBAColor|nil RGBA color
---@param width number|nil Border width
---@param radius number|nil Border radius
function Widget:RenderBorder(nvg, color, width, radius)
    if not color or not width or width <= 0 then return end

    local l = self:GetAbsoluteLayout()
    radius = radius or self.props.borderRadius or 0

    nvgBeginPath(nvg)
    if radius > 0 then
        nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, radius)
    else
        nvgRect(nvg, l.x, l.y, l.w, l.h)
    end
    nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(nvg, width)
    nvgStroke(nvg)
end

-- ============================================================================
-- Shape Support
-- ============================================================================

--- Calculate shape geometry for rendering
--- For "circle" shape, returns centered circle geometry
---@param l table Layout { x, y, w, h }
---@param shape string|nil Shape type: "square", "rounded", "circle" (default: "rounded")
---@param radius number Scaled border radius (used for "rounded" shape)
---@return table { shape, x, y, w, h, radius, centerX, centerY, circleRadius }
function Widget:GetShapeGeometry(l, shape, radius)
    shape = shape or "rounded"

    if shape == "circle" then
        -- Circle: use min(width, height) as diameter, centered
        local diameter = math.min(l.w, l.h)
        local circleRadius = diameter / 2
        local offsetX = (l.w - diameter) / 2
        local offsetY = (l.h - diameter) / 2
        return {
            shape = "circle",
            x = l.x + offsetX,
            y = l.y + offsetY,
            w = diameter,
            h = diameter,
            radius = circleRadius,
            centerX = l.x + l.w / 2,
            centerY = l.y + l.h / 2,
            circleRadius = circleRadius,
        }
    elseif shape == "ellipse" then
        -- Ellipse: fill the widget bounds (rx = w/2, ry = h/2)
        return {
            shape = "ellipse",
            x = l.x,
            y = l.y,
            w = l.w,
            h = l.h,
            radius = math.min(l.w, l.h) / 2,
            centerX = l.x + l.w / 2,
            centerY = l.y + l.h / 2,
            rx = l.w / 2,
            ry = l.h / 2,
        }
    elseif shape == "square" then
        -- Square: no border radius
        return {
            shape = "square",
            x = l.x,
            y = l.y,
            w = l.w,
            h = l.h,
            radius = 0,
        }
    else
        -- Rounded (default): use borderRadius
        -- radius can be a number (uniform) or table {TL, TR, BR, BL} (per-corner)
        if type(radius) == "table" then
            return {
                shape = "rounded",
                x = l.x,
                y = l.y,
                w = l.w,
                h = l.h,
                radius = math.max(radius[1] or 0, radius[2] or 0, radius[3] or 0, radius[4] or 0),
                cornerRadii = { radius[1] or 0, radius[2] or 0, radius[3] or 0, radius[4] or 0 },
            }
        else
            return {
                shape = "rounded",
                x = l.x,
                y = l.y,
                w = l.w,
                h = l.h,
                radius = radius,
            }
        end
    end
end

--- Create NVG path for shape
---@param nvg NVGContextWrapper
---@param geom table Shape geometry from GetShapeGeometry
function Widget:CreateShapePath(nvg, geom)
    nvgBeginPath(nvg)
    if geom.shape == "circle" then
        nvgCircle(nvg, geom.centerX, geom.centerY, geom.circleRadius)
    elseif geom.shape == "ellipse" then
        nvgEllipse(nvg, geom.centerX, geom.centerY, geom.rx, geom.ry)
    elseif geom.cornerRadii then
        -- Per-corner radius: {TL, TR, BR, BL}
        local cr = geom.cornerRadii
        nvgRoundedRectVarying(nvg, geom.x, geom.y, geom.w, geom.h,
            cr[1], cr[2], cr[3], cr[4])
    elseif geom.radius > 0 then
        nvgRoundedRect(nvg, geom.x, geom.y, geom.w, geom.h, geom.radius)
    else
        nvgRect(nvg, geom.x, geom.y, geom.w, geom.h)
    end
end

-- ============================================================================
-- Gradient Background Rendering
-- ============================================================================

--- Resolve gradient direction to start/end coordinates
---@param direction string|number Direction spec
---@param x number Layout x
---@param y number Layout y
---@param w number Layout width
---@param h number Layout height
---@return number sx, number sy, number ex, number ey
local function resolveGradientDirection(direction, x, y, w, h)
    if type(direction) == "number" then
        -- Angle in degrees (0 = to-top, 90 = to-right, 180 = to-bottom)
        local rad = direction * math.pi / 180
        local cx, cy = x + w * 0.5, y + h * 0.5
        local dx = math.sin(rad) * w * 0.5
        local dy = -math.cos(rad) * h * 0.5
        return cx - dx, cy - dy, cx + dx, cy + dy
    end
    -- String presets
    if direction == "to-right" then return x, y + h * 0.5, x + w, y + h * 0.5 end
    if direction == "to-left" then return x + w, y + h * 0.5, x, y + h * 0.5 end
    if direction == "to-top" then return x + w * 0.5, y + h, x + w * 0.5, y end
    if direction == "to-bottom-right" then return x, y, x + w, y + h end
    if direction == "to-bottom-left" then return x + w, y, x, y + h end
    if direction == "to-top-right" then return x, y + h, x + w, y end
    if direction == "to-top-left" then return x + w, y + h, x, y end
    -- Default: "to-bottom"
    return x + w * 0.5, y, x + w * 0.5, y + h
end

--- Render gradient background
---@param nvg NVGContextWrapper
---@param geom table Shape geometry
---@param gradient table { type, direction, from, to }
function Widget:RenderGradientBackground(nvg, geom, gradient)
    local fromColor = gradient.from
    local toColor = gradient.to
    if not fromColor or not toColor then return end

    local c1 = nvgRGBA(fromColor[1], fromColor[2], fromColor[3], fromColor[4] or 255)
    local c2 = nvgRGBA(toColor[1], toColor[2], toColor[3], toColor[4] or 255)

    local paint
    if gradient.type == "radial" then
        local cx = geom.x + geom.w * 0.5
        local cy = geom.y + geom.h * 0.5
        local innerR = gradient.innerRadius or 0
        local outerR = gradient.outerRadius or math.max(geom.w, geom.h) * 0.5
        paint = nvgRadialGradient(nvg, cx, cy, innerR, outerR, c1, c2)
    else
        -- Linear gradient (default)
        local sx, sy, ex, ey = resolveGradientDirection(
            gradient.direction or "to-bottom", geom.x, geom.y, geom.w, geom.h)
        paint = nvgLinearGradient(nvg, sx, sy, ex, ey, c1, c2)
    end

    self:CreateShapePath(nvg, geom)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

-- ============================================================================
-- Backdrop Blur Approximation
-- ============================================================================

--- Render backdrop blur visual approximation
--- Uses a semi-transparent frosted overlay effect (not true Gaussian blur).
--- True backdrop-blur requires render-to-texture + shader pipeline.
---@param nvg NVGContextWrapper
---@param geom table Shape geometry
---@param blurAmount number Blur intensity (higher = more opaque frost)
function Widget:RenderBackdropBlur(nvg, geom, blurAmount)
    -- Frosted glass approximation: layered semi-transparent fills
    -- Layer 1: dark overlay to desaturate
    local alpha1 = math.min(255, blurAmount * 3)
    self:CreateShapePath(nvg, geom)
    nvgFillColor(nvg, nvgRGBA(128, 128, 128, math.floor(alpha1 * 0.3)))
    nvgFill(nvg)

    -- Layer 2: box gradient for soft edge blur effect
    local feather = blurAmount * 2
    local paint = nvgBoxGradient(nvg,
        geom.x + feather * 0.1, geom.y + feather * 0.1,
        geom.w - feather * 0.2, geom.h - feather * 0.2,
        geom.radius, feather,
        nvgRGBA(200, 200, 200, math.floor(math.min(255, blurAmount * 2.5))),
        nvgRGBA(220, 220, 220, math.floor(math.min(255, blurAmount * 1.5)))
    )
    self:CreateShapePath(nvg, geom)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

-- ============================================================================
-- Per-Side Border Rendering
-- ============================================================================

--- Render individual side borders
---@param nvg NVGContextWrapper
---@param l table Layout { x, y, w, h }
function Widget:RenderPerSideBorders(nvg, l)
    local props = self.props
    -- Default color from uniform borderColor prop
    local defaultColor = props.borderColor

    -- Helper: draw one side
    local function drawSide(width, color, x1, y1, x2, y2)
        if not width or width <= 0 then return end
        if not color then return end
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
        nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
        nvgStrokeWidth(nvg, width)
        nvgStroke(nvg)
    end

    local x, y, w, h = l.x, l.y, l.w, l.h

    -- Top border
    drawSide(props.borderTopWidth,
        props.borderTopColor or defaultColor,
        x, y + 0.5, x + w, y + 0.5)

    -- Bottom border
    drawSide(props.borderBottomWidth,
        props.borderBottomColor or defaultColor,
        x, y + h - 0.5, x + w, y + h - 0.5)

    -- Left border
    drawSide(props.borderLeftWidth,
        props.borderLeftColor or defaultColor,
        x + 0.5, y, x + 0.5, y + h)

    -- Right border
    drawSide(props.borderRightWidth,
        props.borderRightColor or defaultColor,
        x + w - 0.5, y, x + w - 0.5, y + h)
end

-- ============================================================================
-- Shadow Rendering
-- ============================================================================

--- Render box shadow
--- NOTE: All values are in BASE PIXELS - nvgScale handles conversion to screen pixels
---@param nvg NVGContextWrapper
---@param l table|nil Layout { x, y, w, h }, uses GetAbsoluteLayout if nil
---@param shapeOverride string|nil Shape override
function Widget:RenderShadow(nvg, l, shapeOverride)
    local props = self.props
    local rp = self.renderProps_
    local blur = rp.shadowBlur or props.shadowBlur
    if not blur or blur <= 0 then return end

    l = l or self:GetAbsoluteLayout()
    -- No scale multiplication needed - nvgScale in UI.Render handles it

    local sx = rp.shadowOffsetX or props.shadowX or 0
    local sy = rp.shadowOffsetY or props.shadowY or 0
    local sblur = blur
    local color = rp.shadowColor or props.shadowColor or {0, 0, 0, 50}
    local radius = rp.borderRadius or props.borderRadius or 0
    local shape = shapeOverride or props.shape

    -- Check for per-corner border radius
    local hasTL = props.borderRadiusTopLeft
    local hasTR = props.borderRadiusTopRight
    local hasBR = props.borderRadiusBottomRight
    local hasBL = props.borderRadiusBottomLeft
    if hasTL or hasTR or hasBR or hasBL then
        local base = type(radius) == "number" and radius or 0
        radius = { hasTL or base, hasTR or base, hasBR or base, hasBL or base }
    end

    -- Get shape geometry
    local geom = self:GetShapeGeometry(l, shape, radius)

    -- Use box gradient to simulate shadow (works for both rect and circle)
    local shadowPaint = nvgBoxGradient(nvg,
        geom.x + sx, geom.y + sy,
        geom.w, geom.h,
        geom.radius + sblur * 0.5,
        sblur,
        nvgRGBA(color[1], color[2], color[3], color[4] or 50),
        nvgRGBA(0, 0, 0, 0)
    )

    nvgBeginPath(nvg)
    -- Draw larger rect to contain shadow
    nvgRect(nvg, geom.x + sx - sblur * 2, geom.y + sy - sblur * 2, geom.w + sblur * 4, geom.h + sblur * 4)
    -- Cut out the widget area (shadow only outside)
    if geom.shape == "circle" then
        nvgCircle(nvg, geom.centerX, geom.centerY, geom.circleRadius)
    elseif geom.cornerRadii then
        local cr = geom.cornerRadii
        nvgRoundedRectVarying(nvg, l.x, l.y, l.w, l.h, cr[1], cr[2], cr[3], cr[4])
    elseif geom.radius > 0 then
        nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, geom.radius)
    else
        nvgRect(nvg, l.x, l.y, l.w, l.h)
    end
    nvgPathWinding(nvg, NVG_HOLE)
    nvgFillPaint(nvg, shadowPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- Enhanced Box Shadow Rendering
-- ============================================================================

--- Render enhanced box shadows (spread / inset / multiple)
---@param nvg NVGContextWrapper
---@param geom table Shape geometry
---@param shadows table Array of shadow definitions { x, y, blur, spread, color, inset }
function Widget:RenderBoxShadows(nvg, geom, shadows)
    for i = 1, #shadows do
        local s = shadows[i]
        local sx = s.x or 0
        local sy = s.y or 0
        local sblur = s.blur or 0
        local spread = s.spread or 0
        local color = s.color or {0, 0, 0, 50}
        local inset = s.inset

        if inset then
            -- Inset shadow: draw inside the widget with clip
            nvgSave(nvg)
            -- Clip to widget shape
            self:CreateShapePath(nvg, geom)
            nvgFill(nvg)  -- Establish clip region via fill

            -- Draw inset shadow using inverted box gradient
            local innerX = geom.x + sx + spread
            local innerY = geom.y + sy + spread
            local innerW = geom.w - spread * 2
            local innerH = geom.h - spread * 2
            local innerR = math.max(0, geom.radius - spread)

            local shadowPaint = nvgBoxGradient(nvg,
                innerX, innerY, innerW, innerH,
                innerR + sblur * 0.5, sblur,
                nvgRGBA(0, 0, 0, 0),
                nvgRGBA(color[1], color[2], color[3], color[4] or 50)
            )

            -- Draw fill rect covering the widget, with inner box gradient
            nvgBeginPath(nvg)
            -- Outer bounds (widget shape)
            if geom.cornerRadii then
                local cr = geom.cornerRadii
                nvgRoundedRectVarying(nvg, geom.x, geom.y, geom.w, geom.h,
                    cr[1], cr[2], cr[3], cr[4])
            elseif geom.radius > 0 then
                nvgRoundedRect(nvg, geom.x, geom.y, geom.w, geom.h, geom.radius)
            else
                nvgRect(nvg, geom.x, geom.y, geom.w, geom.h)
            end
            nvgFillPaint(nvg, shadowPaint)
            nvgFill(nvg)

            nvgRestore(nvg)
        else
            -- Outer shadow: expanded box gradient with hole cutout
            local shadowX = geom.x + sx - spread
            local shadowY = geom.y + sy - spread
            local shadowW = geom.w + spread * 2
            local shadowH = geom.h + spread * 2
            local shadowR = math.max(0, geom.radius + spread)

            local shadowPaint = nvgBoxGradient(nvg,
                shadowX, shadowY, shadowW, shadowH,
                shadowR + sblur * 0.5, sblur,
                nvgRGBA(color[1], color[2], color[3], color[4] or 50),
                nvgRGBA(0, 0, 0, 0)
            )

            nvgBeginPath(nvg)
            -- Large rect to contain shadow
            nvgRect(nvg,
                shadowX - sblur * 2, shadowY - sblur * 2,
                shadowW + sblur * 4, shadowH + sblur * 4)
            -- Cut out the widget area
            if geom.shape == "circle" then
                nvgCircle(nvg, geom.centerX, geom.centerY, geom.circleRadius)
            elseif geom.cornerRadii then
                local cr = geom.cornerRadii
                nvgRoundedRectVarying(nvg, geom.x, geom.y, geom.w, geom.h,
                    cr[1], cr[2], cr[3], cr[4])
            elseif geom.radius > 0 then
                nvgRoundedRect(nvg, geom.x, geom.y, geom.w, geom.h, geom.radius)
            else
                nvgRect(nvg, geom.x, geom.y, geom.w, geom.h)
            end
            nvgPathWinding(nvg, NVG_HOLE)
            nvgFillPaint(nvg, shadowPaint)
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- Background Image Rendering
-- ============================================================================

--- Render background image with fit mode
---@param nvg NVGContextWrapper
---@param imagePath string Image file path
---@param l table|nil Layout { x, y, w, h }
---@param fit string|nil "cover", "contain", "fill", "sliced"
---@param slice table|nil Nine-slice insets {top, right, bottom, left}
---@param radius number|nil Border radius
---@param tint RGBAColor|nil Tint color (multiplicative blend)
function Widget:RenderBackgroundImage(nvg, imagePath, l, fit, slice, radius, tint)
    if not imagePath or imagePath == "" then return end

    l = l or self:GetAbsoluteLayout()
    fit = fit or "fill"
    radius = radius or 0

    -- Get image handle from cache
    local imgHandle = ImageCache.Get(imagePath)
    if not imgHandle or imgHandle <= 0 then return end

    local imgW, imgH = ImageCache.GetSize(imagePath)
    if imgW <= 0 or imgH <= 0 then return end

    if fit == "sliced" and slice then
        self:RenderSlicedImage(nvg, imgHandle, imgW, imgH, l, slice, radius, tint)
    else
        self:RenderFitImage(nvg, imgHandle, imgW, imgH, l, fit, radius, tint)
    end
end

--- Render image with cover/contain/fill fit
---@param nvg NVGContextWrapper
---@param imgHandle number Image handle
---@param imgW number Image width
---@param imgH number Image height
---@param l table Layout { x, y, w, h }
---@param fit string "cover", "contain", "fill"
---@param radius number Border radius
---@param tint RGBAColor|nil Tint color (multiplicative blend)
function Widget:RenderFitImage(nvg, imgHandle, imgW, imgH, l, fit, radius, tint)
    local drawX, drawY, drawW, drawH = l.x, l.y, l.w, l.h
    local imgRatio = imgW / imgH
    local boxRatio = l.w / l.h

    if fit == "cover" then
        -- Fill container, may crop
        if imgRatio > boxRatio then
            -- Image is wider, fit height
            drawH = l.h
            drawW = l.h * imgRatio
            drawX = l.x - (drawW - l.w) / 2
            drawY = l.y
        else
            -- Image is taller, fit width
            drawW = l.w
            drawH = l.w / imgRatio
            drawX = l.x
            drawY = l.y - (drawH - l.h) / 2
        end
    elseif fit == "contain" then
        -- Fit inside container, may have empty space
        if imgRatio > boxRatio then
            -- Image is wider, fit width
            drawW = l.w
            drawH = l.w / imgRatio
            drawX = l.x
            drawY = l.y + (l.h - drawH) / 2
        else
            -- Image is taller, fit height
            drawH = l.h
            drawW = l.h * imgRatio
            drawX = l.x + (l.w - drawW) / 2
            drawY = l.y
        end
    end
    -- fit == "fill": use l.x, l.y, l.w, l.h directly (stretch)

    -- Create image pattern (with optional tint for multiplicative color blend)
    local imgPaint
    if tint then
        imgPaint = nvgImagePatternTinted(nvg, drawX, drawY, drawW, drawH, 0, imgHandle,
            nvgRGBA(tint[1], tint[2], tint[3], tint[4] or 255))
    else
        imgPaint = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgHandle, 1)
    end

    nvgBeginPath(nvg)
    if radius > 0 then
        nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, radius)
    else
        nvgRect(nvg, l.x, l.y, l.w, l.h)
    end
    nvgFillPaint(nvg, imgPaint)
    nvgFill(nvg)
end

--- Render nine-sliced image
--- NOTE: All values are in BASE PIXELS - nvgScale handles conversion to screen pixels
---@param nvg NVGContextWrapper
---@param imgHandle number Image handle
---@param imgW number Image width
---@param imgH number Image height
---@param l table Layout { x, y, w, h }
---@param slice table Nine-slice insets {top, right, bottom, left}
---@param radius number Border radius (ignored for sliced)
---@param tint RGBAColor|nil Tint color (multiplicative blend)
function Widget:RenderSlicedImage(nvg, imgHandle, imgW, imgH, l, slice, radius, tint)
    -- No scale multiplication needed - nvgScale in UI.Render handles it
    local top = slice[1] or 0
    local right = slice[2] or 0
    local bottom = slice[3] or 0
    local left = slice[4] or 0

    -- Source slice sizes (in image pixels)
    local srcTop = slice[1] or 0
    local srcRight = slice[2] or 0
    local srcBottom = slice[3] or 0
    local srcLeft = slice[4] or 0

    -- Calculate regions
    local x, y, w, h = l.x, l.y, l.w, l.h
    local centerW = w - left - right
    local centerH = h - top - bottom
    local srcCenterW = imgW - srcLeft - srcRight
    local srcCenterH = imgH - srcTop - srcBottom

    -- Pre-compute tint color once (outside loop for 9 draw calls)
    local tintColor = tint and nvgRGBA(tint[1], tint[2], tint[3], tint[4] or 255) or nil

    -- Helper to draw a slice
    local function drawSlice(dx, dy, dw, dh, sx, sy, sw, sh)
        if dw <= 0 or dh <= 0 or sw <= 0 or sh <= 0 then return end

        -- Calculate UV coordinates
        local u0 = sx / imgW
        local v0 = sy / imgH
        local u1 = (sx + sw) / imgW
        local v1 = (sy + sh) / imgH

        -- Create pattern for this slice
        -- Map source region to destination region
        local scaleX = dw / sw
        local scaleY = dh / sh
        local ox = dx - sx * scaleX
        local oy = dy - sy * scaleY

        local imgPaint
        if tintColor then
            imgPaint = nvgImagePatternTinted(nvg, ox, oy, imgW * scaleX, imgH * scaleY, 0, imgHandle, tintColor)
        else
            imgPaint = nvgImagePattern(nvg, ox, oy, imgW * scaleX, imgH * scaleY, 0, imgHandle, 1)
        end

        nvgBeginPath(nvg)
        nvgRect(nvg, dx, dy, dw, dh)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    end

    -- Draw 9 slices
    -- Top-left corner
    drawSlice(x, y, left, top, 0, 0, srcLeft, srcTop)
    -- Top edge
    drawSlice(x + left, y, centerW, top, srcLeft, 0, srcCenterW, srcTop)
    -- Top-right corner
    drawSlice(x + left + centerW, y, right, top, imgW - srcRight, 0, srcRight, srcTop)

    -- Left edge
    drawSlice(x, y + top, left, centerH, 0, srcTop, srcLeft, srcCenterH)
    -- Center
    drawSlice(x + left, y + top, centerW, centerH, srcLeft, srcTop, srcCenterW, srcCenterH)
    -- Right edge
    drawSlice(x + left + centerW, y + top, right, centerH, imgW - srcRight, srcTop, srcRight, srcCenterH)

    -- Bottom-left corner
    drawSlice(x, y + top + centerH, left, bottom, 0, imgH - srcBottom, srcLeft, srcBottom)
    -- Bottom edge
    drawSlice(x + left, y + top + centerH, centerW, bottom, srcLeft, imgH - srcBottom, srcCenterW, srcBottom)
    -- Bottom-right corner
    drawSlice(x + left + centerW, y + top + centerH, right, bottom, imgW - srcRight, imgH - srcBottom, srcRight, srcBottom)
end

--- Render complete background (shadow + color + image + border)
--- Convenience method for subclasses
--- NOTE: All values are in BASE PIXELS - nvgScale handles conversion to screen pixels
---@param nvg NVGContextWrapper
---@param overrides table|nil Override props { backgroundColor, backgroundImage, shape, ... }
function Widget:RenderFullBackground(nvg, overrides)
    local props = self.props
    local rp = self.renderProps_
    overrides = overrides or {}

    local l = self:GetAbsoluteLayout()
    -- No scale multiplication needed - nvgScale in UI.Render handles it
    -- Use transition-aware values: renderProps_ (interpolated) > overrides > props
    local radius = overrides.borderRadius or (rp.borderRadius or props.borderRadius) or 0
    local shape = overrides.shape or props.shape

    -- clipPath overrides shape for the widget's own content rendering
    -- Supports: "circle", "ellipse", { type = "circle", radius = N }, { type = "ellipse", rx = N, ry = N }
    local clipPath = props.clipPath
    if clipPath then
        if clipPath == "circle" then
            shape = "circle"
        elseif clipPath == "ellipse" then
            shape = "ellipse"
        elseif type(clipPath) == "table" then
            if clipPath.type == "circle" then
                shape = "circle"
            elseif clipPath.type == "ellipse" then
                shape = "ellipse"
            end
        end
    end

    -- Check for per-corner border radius (individual props override uniform radius)
    local hasTL = props.borderRadiusTopLeft
    local hasTR = props.borderRadiusTopRight
    local hasBR = props.borderRadiusBottomRight
    local hasBL = props.borderRadiusBottomLeft
    if hasTL or hasTR or hasBR or hasBL then
        -- Per-corner radius: individual props override the base radius
        local base = type(radius) == "number" and radius or 0
        radius = {
            hasTL or base,
            hasTR or base,
            hasBR or base,
            hasBL or base,
        }
    end

    -- Get shape geometry
    local geom = self:GetShapeGeometry(l, shape, radius)

    -- Apply custom clipPath dimensions if specified
    if clipPath and type(clipPath) == "table" then
        if clipPath.type == "circle" and clipPath.radius and geom.shape == "circle" then
            geom.circleRadius = clipPath.radius
            geom.radius = clipPath.radius
        elseif clipPath.type == "ellipse" and geom.shape == "ellipse" then
            if clipPath.rx then geom.rx = clipPath.rx end
            if clipPath.ry then geom.ry = clipPath.ry end
        end
    end

    -- 1. Shadow (boxShadow array takes precedence over legacy shadowBlur props)
    if not overrides.skipShadow then
        local boxShadow = props.boxShadow
        if boxShadow then
            self:RenderBoxShadows(nvg, geom, boxShadow)
        else
            self:RenderShadow(nvg, l, shape)
        end
    end

    -- 1b. Backdrop blur approximation (renders before background color)
    local backdropBlur = props.backdropBlur
    if backdropBlur and backdropBlur > 0 then
        self:RenderBackdropBlur(nvg, geom, backdropBlur)
    end

    -- 2. Background color (transition-aware)
    local bgColor = overrides.backgroundColor or rp.backgroundColor or props.backgroundColor
    if bgColor then
        self:CreateShapePath(nvg, geom)
        nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
        nvgFill(nvg)
    end

    -- 2b. Background gradient (renders on top of solid color)
    local gradient = overrides.backgroundGradient or props.backgroundGradient
    if gradient then
        self:RenderGradientBackground(nvg, geom, gradient)
    end

    -- 3. Background image
    local bgImage = overrides.backgroundImage or props.backgroundImage
    if bgImage then
        local fit = overrides.backgroundFit or props.backgroundFit or "fill"
        local slice = overrides.backgroundSlice or props.backgroundSlice
        local tint = overrides.imageTint or rp.imageTint or props.imageTint
        -- For circle shape, use the circle geometry for image clipping
        if geom.shape == "circle" then
            self:RenderBackgroundImage(nvg, bgImage, geom, fit, slice, geom.radius, tint)
        else
            self:RenderBackgroundImage(nvg, bgImage, l, fit, slice, geom.radius, tint)
        end
    end

    -- 4. Border (transition-aware)
    -- Check for per-side borders first
    local hasPerSide = props.borderTopWidth or props.borderBottomWidth
        or props.borderLeftWidth or props.borderRightWidth
    if hasPerSide then
        self:RenderPerSideBorders(nvg, l)
    else
        -- Uniform border
        local borderColor = overrides.borderColor or rp.borderColor or props.borderColor
        -- No scale multiplication needed - nvgScale in UI.Render handles it
        local borderWidth = overrides.borderWidth or (rp.borderWidth or props.borderWidth) or 0
        if borderColor and borderWidth > 0 then
            self:CreateShapePath(nvg, geom)
            nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 255))
            nvgStrokeWidth(nvg, borderWidth)
            nvgStroke(nvg)
        end
    end
end

-- ============================================================================
-- Hit Testing
-- ============================================================================

--- Hit test - check if point is inside widget
--- Respects shape property for accurate hit detection
---@param x number
---@param y number
---@return boolean
function Widget:HitTest(x, y)
    local l = self:GetAbsoluteLayoutForHitTest()

    -- Guard against NaN dimensions (uncalculated Yoga nodes)
    -- Must be checked before any arithmetic to avoid NaN propagation
    if l.w ~= l.w or l.h ~= l.h or l.x ~= l.x or l.y ~= l.y then
        return false
    end

    -- For circle shape, use distance-based hit test
    if self.props.shape == "circle" then
        local diameter = math.min(l.w, l.h)
        local radius = diameter / 2
        local centerX = l.x + l.w / 2
        local centerY = l.y + l.h / 2
        local dx = x - centerX
        local dy = y - centerY
        return (dx * dx + dy * dy) <= (radius * radius)
    end

    -- Default: rectangular hit test
    return x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h
end

--- Dispatch event to registered listeners (via OnEvent).
---@param eventName string
---@param ... any Arguments to pass to handlers
local function dispatchEvent(self, eventName, ...)
    local listeners = self.eventListeners_
    if not listeners then return end
    local list = listeners[eventName]
    if not list then return end
    for i = 1, #list do
        list[i](...)
    end
end

-- ============================================================================
-- Pointer Events (Unified - cross-platform)
-- ============================================================================

--- Called when pointer enters the widget
---@param event PointerEvent
function Widget:OnPointerEnter(event)
    if self.props.onPointerEnter then
        self.props.onPointerEnter(event, self)
    end
    dispatchEvent(self, "pointerenter", event, self)
    self:OnMouseEnter()
end

--- Called when pointer leaves the widget
---@param event PointerEvent
function Widget:OnPointerLeave(event)
    if self.props.onPointerLeave then
        self.props.onPointerLeave(event, self)
    end
    dispatchEvent(self, "pointerleave", event, self)
    self:OnMouseLeave()
end

--- Called when pointer is pressed down
---@param event PointerEvent
function Widget:OnPointerDown(event)
    dispatchEvent(self, "pointerdown", event, self)
    self:OnMouseDown(event.x, event.y, event.button)
    if self.props.onPointerDown then
        self.props.onPointerDown(event, self)
    elseif self.parent then
        self.parent:OnPointerDown(event)
    end
end

--- Called when pointer is released
---@param event PointerEvent
function Widget:OnPointerUp(event)
    dispatchEvent(self, "pointerup", event, self)
    self:OnMouseUp(event.x, event.y, event.button)
    if self.props.onPointerUp then
        self.props.onPointerUp(event, self)
    elseif self.parent then
        self.parent:OnPointerUp(event)
    end
end

--- Called when pointer moves over widget
---@param event PointerEvent
function Widget:OnPointerMove(event)
    if self.props.onPointerMove then
        self.props.onPointerMove(event, self)
    end
    dispatchEvent(self, "pointermove", event, self)
end

--- Called when pointer interaction is cancelled
---@param event PointerEvent
function Widget:OnPointerCancel(event)
    if self.props.onPointerCancel then
        self.props.onPointerCancel(event, self)
    end
    dispatchEvent(self, "pointercancel", event, self)
end

-- ============================================================================
-- Legacy Mouse Events (for backward compatibility)
-- ============================================================================

--- Called when mouse enters the widget (legacy)
function Widget:OnMouseEnter()
    -- Override in subclass
end

--- Called when mouse leaves the widget (legacy)
function Widget:OnMouseLeave()
    -- Override in subclass
end

--- Called when mouse button is pressed (legacy)
---@param x number
---@param y number
---@param button number
function Widget:OnMouseDown(x, y, button)
    -- Override in subclass
end

--- Called when mouse button is released (legacy)
---@param x number
---@param y number
---@param button number
function Widget:OnMouseUp(x, y, button)
    -- Override in subclass
end

-- ============================================================================
-- Click Event
-- ============================================================================

--- Called when widget is clicked/tapped
---@param event PointerEvent|nil
function Widget:OnClick(event)
    dispatchEvent(self, "click", event, self)
    if self.props.onClick then
        self.props.onClick(self, event)
    elseif self.parent then
        self.parent:OnClick(event)
    end
end

-- ============================================================================
-- Gesture Events
-- ============================================================================

--- Called on tap gesture
---@param event GestureEvent
function Widget:OnTap(event)
    dispatchEvent(self, "tap", event, self)
    if self.props.onTap then
        self.props.onTap(event, self)
    elseif self.parent then
        self.parent:OnTap(event)
    end
end

--- Called on double tap gesture
---@param event GestureEvent
function Widget:OnDoubleTap(event)
    dispatchEvent(self, "doubletap", event, self)
    if self.props.onDoubleTap then
        self.props.onDoubleTap(event, self)
    elseif self.parent then
        self.parent:OnDoubleTap(event)
    end
end

--- Called when long press starts
---@param event GestureEvent
function Widget:OnLongPressStart(event)
    dispatchEvent(self, "longpressstart", event, self)
    if self.props.onLongPressStart or self.props.onLongPress then
        if self.props.onLongPressStart then
            self.props.onLongPressStart(event, self)
        end
        if self.props.onLongPress then
            self.props.onLongPress(event, self)
        end
    elseif self.parent then
        self.parent:OnLongPressStart(event)
    end
end

--- Called when long press ends
---@param event GestureEvent
function Widget:OnLongPressEnd(event)
    dispatchEvent(self, "longpressend", event, self)
    if self.props.onLongPressEnd then
        self.props.onLongPressEnd(event, self)
    elseif self.parent then
        self.parent:OnLongPressEnd(event)
    end
end

--- Called on swipe gesture
---@param event GestureEvent
function Widget:OnSwipe(event)
    dispatchEvent(self, "swipe", event, self)
    local hasHandler = self.props.onSwipe
        or (event.direction == "left" and self.props.onSwipeLeft)
        or (event.direction == "right" and self.props.onSwipeRight)
        or (event.direction == "up" and self.props.onSwipeUp)
        or (event.direction == "down" and self.props.onSwipeDown)

    if hasHandler then
        if self.props.onSwipe then
            self.props.onSwipe(event, self)
        end
        -- Call direction-specific handlers
        if event.direction == "left" and self.props.onSwipeLeft then
            self.props.onSwipeLeft(event, self)
        elseif event.direction == "right" and self.props.onSwipeRight then
            self.props.onSwipeRight(event, self)
        elseif event.direction == "up" and self.props.onSwipeUp then
            self.props.onSwipeUp(event, self)
        elseif event.direction == "down" and self.props.onSwipeDown then
            self.props.onSwipeDown(event, self)
        end
    elseif self.parent then
        self.parent:OnSwipe(event)
    end
end

--- Called when pan gesture starts
---@param event GestureEvent
function Widget:OnPanStart(event)
    if self.props.onPanStart then
        self.props.onPanStart(event, self)
    end
    dispatchEvent(self, "panstart", event, self)
end

--- Called during pan gesture
---@param event GestureEvent
function Widget:OnPanMove(event)
    if self.props.onPanMove then
        self.props.onPanMove(event, self)
    end
    if self.props.onPan then
        self.props.onPan(event, self)
    end
    dispatchEvent(self, "panmove", event, self)
end

--- Called when pan gesture ends
---@param event GestureEvent
function Widget:OnPanEnd(event)
    if self.props.onPanEnd then
        self.props.onPanEnd(event, self)
    end
    dispatchEvent(self, "panend", event, self)
end

--- Called when pinch gesture starts (multi-touch)
---@param event GestureEvent
function Widget:OnPinchStart(event)
    if self.props.onPinchStart then
        self.props.onPinchStart(event, self)
    end
    dispatchEvent(self, "pinchstart", event, self)
end

--- Called during pinch gesture
---@param event GestureEvent
function Widget:OnPinchMove(event)
    if self.props.onPinchMove then
        self.props.onPinchMove(event, self)
    end
    if self.props.onPinch then
        self.props.onPinch(event, self)
    end
    dispatchEvent(self, "pinchmove", event, self)
end

--- Called when pinch gesture ends
---@param event GestureEvent
function Widget:OnPinchEnd(event)
    if self.props.onPinchEnd then
        self.props.onPinchEnd(event, self)
    end
    dispatchEvent(self, "pinchend", event, self)
end

-- ============================================================================
-- Focus Events
-- ============================================================================

--- Called when widget receives focus
function Widget:OnFocus()
    if self.props.onFocus then
        self.props.onFocus(self)
    end
    dispatchEvent(self, "focus", self)
end

--- Called when widget loses focus
function Widget:OnBlur()
    if self.props.onBlur then
        self.props.onBlur(self)
    end
    dispatchEvent(self, "blur", self)
end

-- ============================================================================
-- Event Listener API (imperative, post-construction)
-- ============================================================================

--- Register an event listener.
--- Event names: "pointerenter", "pointerleave", "pointerdown", "pointerup",
--- "pointermove", "pointercancel", "click", "tap", "doubletap",
--- "longpressstart", "longpressend", "swipe", "panstart", "panmove", "panend",
--- "pinchstart", "pinchmove", "pinchend", "focus", "blur"
---@param eventName string Event name (lowercase)
---@param handler function Callback function (receives same args as the OnXxx method)
---@return Widget self for chaining
function Widget:OnEvent(eventName, handler)
    if not self.eventListeners_ then
        self.eventListeners_ = {}
    end
    local list = self.eventListeners_[eventName]
    if not list then
        list = {}
        self.eventListeners_[eventName] = list
    end
    list[#list + 1] = handler
    return self
end

--- Remove an event listener. If handler is nil, removes all listeners for the event.
---@param eventName string Event name (lowercase)
---@param handler function|nil Specific handler to remove, or nil to remove all
---@return Widget self for chaining
function Widget:OffEvent(eventName, handler)
    if not self.eventListeners_ then return self end
    if not handler then
        self.eventListeners_[eventName] = nil
        return self
    end
    local list = self.eventListeners_[eventName]
    if list then
        for i = #list, 1, -1 do
            if list[i] == handler then
                table.remove(list, i)
            end
        end
    end
    return self
end

-- ============================================================================
-- State (for Stateful widgets)
-- ============================================================================

--- Update state and trigger re-render
---@param newState table
function Widget:SetState(newState)
    for k, v in pairs(newState) do
        self.state[k] = v
    end
    -- Note: actual re-render is handled by UI manager
end

--- Get current state
---@return table
function Widget:GetState()
    return self.state
end

-- ============================================================================
-- Utility
-- ============================================================================

--- Get prop value with default
---@param key string
---@param default any
---@return any
function Widget:GetProp(key, default)
    local value = self.props[key]
    if value == nil then
        return default
    end
    return value
end

--- Check if widget is stateful (has internal state that changes)
---@return boolean
function Widget:IsStateful()
    return false  -- Override in stateful widgets
end

-- ============================================================================
-- Layout Overflow Detection (Development Aid)
-- ============================================================================

-- Global flag to enable/disable overflow warnings
Widget.OverflowWarningsEnabled = true

-- Track warned widgets to avoid spam (reset each layout cycle)
local warnedWidgets_ = {}

--- Reset overflow warnings (call before each layout check)
function Widget.ResetOverflowWarnings()
    warnedWidgets_ = {}
end

--- Check if children overflow this widget's bounds
--- Call after layout calculation to detect potential issues
---@param recursive boolean|nil Check children recursively (default true)
function Widget:CheckOverflow(recursive)
    if not Widget.OverflowWarningsEnabled then return end
    if recursive == nil then recursive = true end

    local l = self:GetLayout()
    if not l or l.w <= 0 or l.h <= 0 then return end

    -- Skip widgets that are designed to overflow (ScrollView content, etc.)
    if self.props.allowOverflow then return end

    -- Calculate children bounds (only in-flow children)
    local childrenHeight = 0
    local childrenWidth = 0
    local isColumn = (self.props.flexDirection or "column") == "column"
    local visibleChildren = 0

    for _, child in ipairs(self.children) do
        if child:IsVisible() then
            -- Skip absolutely positioned children: they are out of normal flex flow
            -- (e.g. Modal, Drawer, Popover) and don't contribute to overflow
            if child.props.position == "absolute" then
                -- still recurse into them below, but don't count their size
            else
                visibleChildren = visibleChildren + 1
                local cl = child:GetLayout()
                if cl then
                    if isColumn then
                        childrenHeight = childrenHeight + cl.h
                        childrenWidth = math.max(childrenWidth, cl.w)
                    else
                        childrenWidth = childrenWidth + cl.w
                        childrenHeight = math.max(childrenHeight, cl.h)
                    end
                end
            end
        end
    end

    -- Add gap spacing
    local gap = self.props.gap or 0
    if visibleChildren > 1 then
        local totalGap = gap * (visibleChildren - 1)
        if isColumn then
            childrenHeight = childrenHeight + totalGap
        else
            childrenWidth = childrenWidth + totalGap
        end
    end

    -- Check for overflow
    local widgetId = self.props.id or self._className or "Widget"
    local overflowH = childrenHeight > l.h + 1  -- +1 for float tolerance
    local overflowW = childrenWidth > l.w + 1

    if (overflowH or overflowW) and not warnedWidgets_[self] then
        warnedWidgets_[self] = true
        local msg = string.format(
            "[Layout Warning] Overflow in '%s': children=%dx%d, container=%dx%d. " ..
            "Consider: flexShrink=1 on children, or increase container size.",
            widgetId,
            math.floor(childrenWidth), math.floor(childrenHeight),
            math.floor(l.w), math.floor(l.h)
        )
        print(msg)
    end

    -- Recursively check children (including absolute-positioned ones)
    if recursive then
        for _, child in ipairs(self.children) do
            child:CheckOverflow(true)
        end
    end
end

-- Make Widget callable: Widget { props }
setmetatable(Widget, {
    __call = function(cls, props)
        return cls:new(props)
    end
})

-- ============================================================================
-- Static Methods for Layout Callback
-- ============================================================================

--- Set layout dirty callback (called by UI.lua)
---@param callback function|nil
function Widget.SetLayoutDirtyCallback(callback)
    onLayoutDirty_ = callback
end

--- Notify layout changed (internal use)
local function notifyLayoutDirty()
    if onLayoutDirty_ then
        onLayoutDirty_()
    end
end

-- Expose for internal use
Widget._notifyLayoutDirty = notifyLayoutDirty

return Widget
