-- ============================================================================
-- SafeAreaView Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Container that applies safe area insets as padding
-- ============================================================================
--
-- Usage:
--   local root = SafeAreaView({
--       edges = "all",  -- or { "top", "bottom" }
--       children = { ... }
--   })
--
-- Props:
--   edges: "all" (default) | "none" | { "top", "bottom", "left", "right" }
--   mode: "padding" (default) | "margin"
--   ... all other Widget/Panel props
--
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class SafeAreaViewProps : WidgetProps
---@field edges string|string[]|nil Which edges to apply safe area: "all" | "none" | "horizontal" | "vertical" | array of "top"/"bottom"/"left"/"right" (default: "all")
---@field mode string|nil "padding" | "margin" (default: "padding")

---@class SafeAreaView : Widget
---@operator call(SafeAreaViewProps?): SafeAreaView
---@field props SafeAreaViewProps
---@field new fun(self, props: SafeAreaViewProps?): SafeAreaView
local SafeAreaView = Widget:Extend("SafeAreaView")

-- ============================================================================
-- Internal: Get safe area insets
-- ============================================================================

local function getSafeAreaInsets()
    -- GetSafeAreaInsets returns Rect with min.x=left, min.y=top, max.x=right, max.y=bottom
    local rect = GetSafeAreaInsets(false)
    -- Get UI scale for conversion to base pixels
    local scale = Theme.GetScale()
    return {
        left = rect.min.x / scale,
        top = rect.min.y / scale,
        right = rect.max.x / scale,
        bottom = rect.max.y / scale
    }
end

-- ============================================================================
-- Internal: Parse edges configuration
-- ============================================================================

local function parseEdges(edges)
    if edges == "all" or edges == nil then
        return { top = true, bottom = true, left = true, right = true }
    elseif edges == "none" then
        return { top = false, bottom = false, left = false, right = false }
    elseif edges == "horizontal" then
        return { top = false, bottom = false, left = true, right = true }
    elseif edges == "vertical" then
        return { top = true, bottom = true, left = false, right = false }
    elseif type(edges) == "table" then
        local result = { top = false, bottom = false, left = false, right = false }
        for _, edge in ipairs(edges) do
            result[edge] = true
        end
        return result
    end
    return { top = true, bottom = true, left = true, right = true }
end

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props SafeAreaViewProps?
function SafeAreaView:Init(props)
    props = props or {}

    -- Store edges configuration for later updates
    self.edgesConfig_ = parseEdges(props.edges)
    self.mode_ = props.mode or "padding"

    -- Cache screen size for change detection
    self.lastScreenWidth_ = graphics.width
    self.lastScreenHeight_ = graphics.height

    -- Get current safe area insets
    local insets = getSafeAreaInsets()
    self.lastInsets_ = insets

    -- Apply safe area as padding or margin
    self:ApplySafeAreaInsets(props, insets)

    -- Apply theme defaults for Panel-like appearance
    local themeStyle = Theme.ComponentStyle("SafeAreaView") or {}
    Style.ApplyDefaults(props, themeStyle)

    Widget.Init(self, props)
end

-- ============================================================================
-- Apply Safe Area Insets
-- ============================================================================

function SafeAreaView:ApplySafeAreaInsets(props, insets)
    local edges = self.edgesConfig_
    local mode = self.mode_

    if mode == "padding" then
        -- Merge with existing padding
        props.paddingLeft = (props.paddingLeft or 0) + (edges.left and insets.left or 0)
        props.paddingTop = (props.paddingTop or 0) + (edges.top and insets.top or 0)
        props.paddingRight = (props.paddingRight or 0) + (edges.right and insets.right or 0)
        props.paddingBottom = (props.paddingBottom or 0) + (edges.bottom and insets.bottom or 0)
    else -- margin
        props.marginLeft = (props.marginLeft or 0) + (edges.left and insets.left or 0)
        props.marginTop = (props.marginTop or 0) + (edges.top and insets.top or 0)
        props.marginRight = (props.marginRight or 0) + (edges.right and insets.right or 0)
        props.marginBottom = (props.marginBottom or 0) + (edges.bottom and insets.bottom or 0)
    end
end

-- ============================================================================
-- Update: Check for safe area changes only when screen size changes
-- ============================================================================

function SafeAreaView:Update(dt)
    -- Only check safe area when screen size changes (rotation, etc.)
    local w, h = graphics.width, graphics.height
    if w ~= self.lastScreenWidth_ or h ~= self.lastScreenHeight_ then
        self.lastScreenWidth_ = w
        self.lastScreenHeight_ = h

        -- Screen size changed, check if safe area also changed
        local insets = getSafeAreaInsets()
        local last = self.lastInsets_

        if insets.left ~= last.left or insets.top ~= last.top or
           insets.right ~= last.right or insets.bottom ~= last.bottom then
            self:UpdateSafeAreaPadding(insets)
            self.lastInsets_ = insets
        end
    end
end

function SafeAreaView:UpdateSafeAreaPadding(insets)
    local edges = self.edgesConfig_
    local mode = self.mode_
    local last = self.lastInsets_

    if mode == "padding" then
        -- Calculate delta and apply to Yoga node
        local deltaLeft = (edges.left and insets.left or 0) - (edges.left and last.left or 0)
        local deltaTop = (edges.top and insets.top or 0) - (edges.top and last.top or 0)
        local deltaRight = (edges.right and insets.right or 0) - (edges.right and last.right or 0)
        local deltaBottom = (edges.bottom and insets.bottom or 0) - (edges.bottom and last.bottom or 0)

        -- Get current padding and add delta
        local currentLeft = YGNodeStyleGetPadding(self.node, YGEdgeLeft).value or 0
        local currentTop = YGNodeStyleGetPadding(self.node, YGEdgeTop).value or 0
        local currentRight = YGNodeStyleGetPadding(self.node, YGEdgeRight).value or 0
        local currentBottom = YGNodeStyleGetPadding(self.node, YGEdgeBottom).value or 0

        YGNodeStyleSetPadding(self.node, YGEdgeLeft, currentLeft + deltaLeft)
        YGNodeStyleSetPadding(self.node, YGEdgeTop, currentTop + deltaTop)
        YGNodeStyleSetPadding(self.node, YGEdgeRight, currentRight + deltaRight)
        YGNodeStyleSetPadding(self.node, YGEdgeBottom, currentBottom + deltaBottom)
    else -- margin
        local deltaLeft = (edges.left and insets.left or 0) - (edges.left and last.left or 0)
        local deltaTop = (edges.top and insets.top or 0) - (edges.top and last.top or 0)
        local deltaRight = (edges.right and insets.right or 0) - (edges.right and last.right or 0)
        local deltaBottom = (edges.bottom and insets.bottom or 0) - (edges.bottom and last.bottom or 0)

        local currentLeft = YGNodeStyleGetMargin(self.node, YGEdgeLeft).value or 0
        local currentTop = YGNodeStyleGetMargin(self.node, YGEdgeTop).value or 0
        local currentRight = YGNodeStyleGetMargin(self.node, YGEdgeRight).value or 0
        local currentBottom = YGNodeStyleGetMargin(self.node, YGEdgeBottom).value or 0

        YGNodeStyleSetMargin(self.node, YGEdgeLeft, currentLeft + deltaLeft)
        YGNodeStyleSetMargin(self.node, YGEdgeTop, currentTop + deltaTop)
        YGNodeStyleSetMargin(self.node, YGEdgeRight, currentRight + deltaRight)
        YGNodeStyleSetMargin(self.node, YGEdgeBottom, currentBottom + deltaBottom)
    end
end

-- ============================================================================
-- Rendering
-- ============================================================================

function SafeAreaView:Render(nvg)
    -- Render background if specified
    self:RenderFullBackground(nvg)
end

-- ============================================================================
-- Stateless
-- ============================================================================

function SafeAreaView:IsStateful()
    return false
end

return SafeAreaView
