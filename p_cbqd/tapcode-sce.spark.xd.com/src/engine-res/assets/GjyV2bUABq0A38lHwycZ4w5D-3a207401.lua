-- ============================================================================
-- SimpleGrid Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Equal-width column grid layout via flex wrap
-- ============================================================================
--
-- NOTE: This is NOT a CSS Grid implementation. It uses Yoga flex-wrap
-- to create equal-width columns. Same-row items have independent heights
-- (no cross-axis alignment like CSS Grid's grid-template-rows).
--
-- Good for: inventory grids, card lists, image galleries, icon grids.
-- NOT suitable for: complex 2D grid layouts requiring row+column alignment.
--
-- IMPLEMENTATION NOTE (fixed columns + gap):
-- Yoga's flex-wrap line-breaking uses flexBasis + columnGap to decide when
-- to wrap. Percentage flexBasis (e.g. 25%) + pixel gap always causes wrong
-- column count (4×25% + 3×8px > 100% → wraps to 3 columns).
-- Fix: on first layout pass, use percentage basis without columnGap (correct
-- column count, no gap). In Render, read actual pixel width and set exact
-- pixel flexBasis + columnGap. Second frame renders correctly.
--
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class SimpleGridProps : WidgetProps
---@field columns number|nil Number of columns (default: 4)
---@field minColumnWidth number|nil Minimum column width for responsive columns (overrides columns)
---@field gap number|nil Gap between items (both row and column)

---@class SimpleGrid : Widget
---@operator call(SimpleGridProps?): SimpleGrid
---@field props SimpleGridProps
---@field new fun(self, props: SimpleGridProps?): SimpleGrid
local SimpleGrid = Widget:Extend("SimpleGrid")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props SimpleGridProps?
function SimpleGrid:Init(props)
    props = props or {}

    -- Grid layout: row direction with wrap
    props.flexDirection = "row"
    props.flexWrap = "wrap"

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("SimpleGrid")
    Style.ApplyDefaults(props, themeStyle)

    -- Store grid config
    self.columns_ = props.columns or 4
    self.minColumnWidth_ = props.minColumnWidth
    self.gap_ = props.gap or 0

    if self.minColumnWidth_ then
        -- Responsive mode: pixel-based flexBasis works fine with columnGap
        if self.gap_ > 0 then
            props.columnGap = props.columnGap or self.gap_
            props.rowGap = props.rowGap or self.gap_
        end
    else
        -- Fixed columns: set rowGap only.
        -- columnGap is deferred to Render (after computing pixel widths).
        -- First frame: items at percentage basis without columnGap → correct column count, no gap.
        -- Second frame: pixel widths + columnGap → correct column count with gap.
        if self.gap_ > 0 then
            props.rowGap = props.rowGap or self.gap_
        end
    end

    Widget.Init(self, props)
end

-- ============================================================================
-- Child Management Override
-- ============================================================================

--- Override AddChild to set flex basis on children
---@param child Widget
---@return SimpleGrid self
function SimpleGrid:AddChild(child)
    if not child then return self end

    -- Calculate and set flex basis for equal-width columns
    self:ApplyChildBasis_(child)

    -- Call parent AddChild
    Widget.AddChild(self, child)
    return self
end

--- Apply flex basis to a child based on column configuration.
--- Uses SetStyle to apply both props AND Yoga node properties.
---@param child Widget
function SimpleGrid:ApplyChildBasis_(child)
    local style = {}

    if self.minColumnWidth_ then
        -- Responsive: let children grow, set minWidth + flexBasis for proper wrapping
        if not child.props.minWidth then style.minWidth = self.minColumnWidth_ end
        if not child.props.flexBasis then style.flexBasis = self.minColumnWidth_ end
        if not child.props.flexGrow then style.flexGrow = 1 end
        if not child.props.flexShrink then style.flexShrink = 1 end
    else
        -- Fixed columns: percentage basis as initial layout hint.
        -- Will be overridden with exact pixel values in Render.
        if not child.props.flexBasis then
            style.flexBasis = tostring(math.floor(10000 / self.columns_) / 100) .. "%"
        end
        if not child.props.flexGrow then style.flexGrow = 0 end
        if not child.props.flexShrink then style.flexShrink = 0 end
    end

    -- Apply to both props and Yoga node
    if next(style) then
        child:SetStyle(style)
    end
end

-- ============================================================================
-- Rendering
-- ============================================================================

function SimpleGrid:Render(nvg)
    -- Fixed columns with gap: compute exact pixel widths from actual layout.
    -- (Percentage flexBasis + pixel columnGap causes wrong column count in Yoga)
    if not self.minColumnWidth_ and self.gap_ > 0 then
        local w = YGNodeLayoutGetWidth(self.node)
        if w > 0 and w ~= self.lastLayoutWidth_ then
            self.lastLayoutWidth_ = w
            local columns = self.columns_
            local gap = self.gap_
            local totalGap = (columns - 1) * gap
            local itemWidth = (w - totalGap) / columns
            for _, child in ipairs(self.children) do
                child:SetStyle({ flexBasis = itemWidth })
            end
            -- Enable columnGap now that children have pixel-based flexBasis
            if not self.gapApplied_ then
                YGNodeStyleSetGap(self.node, YGGutterColumn, gap)
                self.props.columnGap = gap
                self.gapApplied_ = true
            end
        end
    end

    self:RenderFullBackground(nvg)
end

--- Custom child rendering with clipping for overflow="hidden"
---@param nvg NVGContextWrapper
---@param renderFn function Recursive render function
function SimpleGrid:CustomRenderChildren(nvg, renderFn)
    local props = self.props
    local renderList = self:GetRenderChildren()

    if props.overflow == "hidden" then
        local l = self:GetAbsoluteLayout()
        nvgSave(nvg)
        nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)
        for i = 1, #renderList do
            renderFn(renderList[i], nvg)
        end
        nvgRestore(nvg)
    else
        for i = 1, #renderList do
            renderFn(renderList[i], nvg)
        end
    end
end

-- ============================================================================
-- Stateless
-- ============================================================================

function SimpleGrid:IsStateful()
    return false
end

return SimpleGrid
