-- ============================================================================
-- Tabs Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Tab navigation with content panels
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class TabItem
---@field id string|number Tab identifier
---@field label string Tab label
---@field icon string|nil Icon name (optional)
---@field disabled boolean|nil Is tab disabled
---@field content Widget|nil Tab content widget

---@class TabsProps : WidgetProps
---@field tabs TabItem[]|nil List of tabs
---@field activeTab string|number|nil Currently active tab ID
---@field variant string|nil "line" | "enclosed" | "pills" (default: "line")
---@field orientation string|nil "horizontal" | "vertical" (default: "horizontal")
---@field tabHeight number|nil Tab height (default: 40)
---@field tabWidth number|nil Tab width for vertical orientation (default: 120)
---@field onChange fun(self: Tabs, tabId: string|number, tab: TabItem?)|nil Tab change callback

---@class Tabs : Widget
---@operator call(TabsProps?): Tabs
---@field props TabsProps
---@field new fun(self, props: TabsProps?): Tabs
---@field state {hoveredTab: string|number|nil}
local Tabs = Widget:Extend("Tabs")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props TabsProps?
function Tabs:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("Tabs")
    props.tabHeight = props.tabHeight or themeStyle.tabHeight or 40
    props.borderRadius = props.borderRadius or themeStyle.borderRadius or 6

    -- Default settings
    props.tabs = props.tabs or {}
    props.variant = props.variant or "line"
    props.orientation = props.orientation or "horizontal"

    -- Set default active tab
    if not props.activeTab and #props.tabs > 0 then
        props.activeTab = props.tabs[1].id
    end

    -- Set default height for horizontal tabs (header only)
    if props.orientation ~= "vertical" and not props.height then
        props.height = props.tabHeight
    end

    -- Flex direction based on orientation
    if props.orientation == "vertical" then
        props.flexDirection = "row"
    else
        props.flexDirection = "column"
    end

    -- Initialize state
    self.state = {
        hoveredTab = nil,
    }

    -- Animation state for indicator
    self.indicatorX_ = 0
    self.indicatorWidth_ = 0
    self.targetIndicatorX_ = 0
    self.targetIndicatorWidth_ = 0

    -- Tab content widgets
    self.tabContents_ = {}

    Widget.Init(self, props)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Tabs:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local tabs = props.tabs
    local activeTab = props.activeTab
    local variant = props.variant
    local orientation = props.orientation
    local tabHeight = props.tabHeight
    local borderRadius = props.borderRadius

    if #tabs == 0 then
        return
    end

    -- Store values for hit testing
    self.scaledTabHeight_ = tabHeight
    self.scaledTabWidth_ = props.tabWidth or 120

    -- Draw background if set
    if props.backgroundColor then
        self:RenderBackground(nvg, props.backgroundColor, borderRadius)
    end

    -- Calculate and cache layout for CustomRenderChildren
    if orientation == "vertical" then
        self.headerWidth_ = self.scaledTabWidth_
        self.headerHeight_ = l.h
        self.headerX_ = l.x
        self.headerY_ = l.y
        self.contentX_ = l.x + self.headerWidth_
        self.contentY_ = l.y
        self.contentWidth_ = l.w - self.headerWidth_
        self.contentHeight_ = l.h
    else
        self.headerWidth_ = l.w
        self.headerHeight_ = tabHeight
        self.headerX_ = l.x
        self.headerY_ = l.y
        self.contentX_ = l.x
        self.contentY_ = l.y + tabHeight
        self.contentWidth_ = l.w
        self.contentHeight_ = l.h - tabHeight
    end

    -- Draw tab header
    self:RenderTabHeader(nvg, self.headerX_, self.headerY_, self.headerWidth_, self.headerHeight_, tabs, activeTab, variant, orientation)

    -- Content area is rendered in CustomRenderChildren for proper child recursion
end

--- Custom child rendering for tab content
--- Renders tab content with proper child recursion via renderFn
---@param nvg NVGContextWrapper
---@param renderFn function Recursive render function
function Tabs:CustomRenderChildren(nvg, renderFn)
    -- Render tab content with recursive render function
    self:RenderTabContentWithRenderFn(nvg, self.contentX_, self.contentY_, self.contentWidth_, self.contentHeight_, self.props.activeTab, renderFn)

    -- Render standard children (if any, respecting z-index order)
    local renderList = self:GetRenderChildren()
    for i = 1, #renderList do
        renderFn(renderList[i], nvg)
    end
end

--- Render tab header with all tabs
function Tabs:RenderTabHeader(nvg, x, y, width, height, tabs, activeTab, variant, orientation)
    local borderRadius = self.props.borderRadius
    local fontFamily = Theme.FontFamily()

    -- Draw header background based on variant
    if variant == "enclosed" then
        local bgColor = Theme.Color("surface")
        nvgBeginPath(nvg)
        if orientation == "vertical" then
            nvgRoundedRectVarying(nvg, x, y, width, height, borderRadius, 0, 0, borderRadius)
        else
            nvgRoundedRectVarying(nvg, x, y, width, height, borderRadius, borderRadius, 0, 0)
        end
        nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
        nvgFill(nvg)
    end

    -- Calculate tab dimensions
    local tabWidth, tabHeight
    if orientation == "vertical" then
        tabWidth = width
        tabHeight = self.props.tabHeight
    else
        tabWidth = width / #tabs
        tabHeight = height
    end

    -- Store tab layouts for hit testing
    self.tabLayouts_ = {}

    -- Render each tab
    for i, tab in ipairs(tabs) do
        local tabX, tabY

        if orientation == "vertical" then
            tabX = x
            tabY = y + (i - 1) * tabHeight
        else
            tabX = x + (i - 1) * tabWidth
            tabY = y
        end

        -- Store layout (relative to header origin for hit testing)
        self.tabLayouts_[tab.id] = {
            x = tabX - x,  -- relative to header X
            y = tabY - y,  -- relative to header Y
            w = tabWidth,
            h = tabHeight,
            index = i,
        }

        local isActive = tab.id == activeTab
        local isHovered = self.state.hoveredTab == tab.id
        local isDisabled = tab.disabled

        -- Update indicator target for active tab
        if isActive then
            if orientation == "vertical" then
                self.targetIndicatorX_ = tabY
                self.targetIndicatorWidth_ = tabHeight
            else
                self.targetIndicatorX_ = tabX
                self.targetIndicatorWidth_ = tabWidth
            end
        end

        self:RenderTab(nvg, tab, tabX, tabY, tabWidth, tabHeight, isActive, isHovered, isDisabled, variant, orientation)
    end

    -- Draw indicator line (for "line" variant)
    if variant == "line" then
        self:RenderIndicator(nvg, x, y, width, height, orientation)
    end

    -- Draw bottom border for line variant
    if variant == "line" and orientation == "horizontal" then
        local borderColor = Theme.Color("border")
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, y + height)
        nvgLineTo(nvg, x + width, y + height)
        nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], 100))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end
end

--- Render a single tab
function Tabs:RenderTab(nvg, tab, x, y, width, height, isActive, isHovered, isDisabled, variant, orientation)
    local borderRadius = self.props.borderRadius
    local fontFamily = Theme.FontFamily()
    local padding = 12
    local pillMargin = 4

    -- Determine colors
    local bgColor, textColor

    if isDisabled then
        bgColor = nil
        textColor = Theme.Color("disabledText")
    elseif isActive then
        if variant == "pills" then
            bgColor = Theme.Color("primary")
            textColor = { 255, 255, 255, 255 }
        elseif variant == "enclosed" then
            bgColor = Theme.Color("background")
            textColor = Theme.Color("primary")
        else
            bgColor = nil
            textColor = Theme.Color("primary")
        end
    elseif isHovered then
        if variant == "pills" then
            bgColor = Theme.Color("surfaceHover") or Style.Lighten(Theme.Color("surface"), 0.1)
        else
            bgColor = nil
        end
        textColor = Theme.Color("text")
    else
        bgColor = nil
        textColor = Theme.Color("textSecondary")
    end

    -- Draw background
    if bgColor then
        nvgBeginPath(nvg)
        if variant == "pills" then
            nvgRoundedRect(nvg, x + pillMargin, y + pillMargin, width - pillMargin * 2, height - pillMargin * 2, borderRadius)
        elseif variant == "enclosed" and isActive then
            if orientation == "vertical" then
                nvgRoundedRectVarying(nvg, x, y, width + 1, height, borderRadius, 0, 0, borderRadius)
            else
                nvgRoundedRectVarying(nvg, x, y, width, height + 1, borderRadius, borderRadius, 0, 0)
            end
        else
            nvgRect(nvg, x, y, width, height)
        end
        nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
        nvgFill(nvg)
    end

    -- Draw hover background for non-pill variants
    if isHovered and not isActive and not isDisabled and variant ~= "pills" then
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, width, height)
        nvgFillColor(nvg, nvgRGBA(128, 128, 128, 20))
        nvgFill(nvg)
    end

    -- Draw label
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, Theme.FontSizeOf("body"))
    nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgText(nvg, x + width / 2, y + height / 2, tab.label, nil)
end

--- Render the active tab indicator
function Tabs:RenderIndicator(nvg, headerX, headerY, headerWidth, headerHeight, orientation)
    -- Animate indicator position
    local speed = 0.2
    self.indicatorX_ = self.indicatorX_ + (self.targetIndicatorX_ - self.indicatorX_) * speed
    self.indicatorWidth_ = self.indicatorWidth_ + (self.targetIndicatorWidth_ - self.indicatorWidth_) * speed

    local indicatorColor = Theme.Color("primary")
    local indicatorThickness = 3

    nvgBeginPath(nvg)

    if orientation == "vertical" then
        -- Vertical indicator on left side
        nvgRoundedRect(nvg,
            headerX,
            self.indicatorX_,
            indicatorThickness,
            self.indicatorWidth_,
            indicatorThickness / 2
        )
    else
        -- Horizontal indicator at bottom
        nvgRoundedRect(nvg,
            self.indicatorX_,
            headerY + headerHeight - indicatorThickness,
            self.indicatorWidth_,
            indicatorThickness,
            indicatorThickness / 2
        )
    end

    nvgFillColor(nvg, nvgRGBA(indicatorColor[1], indicatorColor[2], indicatorColor[3], indicatorColor[4] or 255))
    nvgFill(nvg)
end

--- Render tab content area with recursive render function
--- This version uses renderFn for proper child recursion
---@param nvg NVGContextWrapper
---@param x number Content X position
---@param y number Content Y position
---@param width number Content width
---@param height number Content height
---@param activeTab string|number Active tab ID
---@param renderFn function Recursive render function
function Tabs:RenderTabContentWithRenderFn(nvg, x, y, width, height, activeTab, renderFn)
    -- Only render if we have content area
    if not x or not height or height <= 0 then
        return
    end

    -- Draw content background
    local bgColor = Theme.Color("background")
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, width, height)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
    nvgFill(nvg)

    -- Find and render active tab content
    local activeContent = self.tabContents_[activeTab]
    if activeContent then
        nvgSave(nvg)
        nvgIntersectScissor(nvg, x, y, width, height)

        -- Set content render offset and size (for widgets not in Yoga tree)
        activeContent.renderOffsetX_ = x
        activeContent.renderOffsetY_ = y
        activeContent.renderWidth_ = width
        activeContent.renderHeight_ = height

        -- Calculate Yoga layout for content subtree (since it's not in main Yoga tree)
        -- Yoga works in base pixels, pass width/height directly
        if activeContent.node then
            activeContent:SetWidth(width)
            activeContent:SetHeight(height)
            YGNodeCalculateLayout(activeContent.node, width, height, YGDirectionLTR)
        end

        -- Use renderFn for proper recursive rendering of content and its children
        renderFn(activeContent, nvg)

        nvgRestore(nvg)
    end
end

--- [DEPRECATED] Render tab content area (for backward compatibility)
--- Use RenderTabContentWithRenderFn in CustomRenderChildren instead
function Tabs:RenderTabContent(nvg, x, y, width, height, activeTab)
    -- This method is kept for backward compatibility
    -- New code should use CustomRenderChildren which calls RenderTabContentWithRenderFn
    if not x or not height or height <= 0 then
        return
    end

    local bgColor = Theme.Color("background")
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, width, height)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
    nvgFill(nvg)

    local activeContent = self.tabContents_[activeTab]
    if activeContent then
        nvgSave(nvg)
        nvgIntersectScissor(nvg, x, y, width, height)

        activeContent.renderOffsetX_ = x
        activeContent.renderOffsetY_ = y
        activeContent.renderWidth_ = width
        activeContent.renderHeight_ = height

        if activeContent.node then
            activeContent:SetWidth(width)
            activeContent:SetHeight(height)
            YGNodeCalculateLayout(activeContent.node, width, height, YGDirectionLTR)
        end

        activeContent:Render(nvg)

        nvgRestore(nvg)
    end
end

-- ============================================================================
-- Update
-- ============================================================================

function Tabs:Update(dt)
    -- Update active tab content
    local activeContent = self.tabContents_[self.props.activeTab]
    if activeContent and activeContent.Update then
        activeContent:Update(dt)
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

--- Check if point is in header area (returns true) or content area (returns false)
function Tabs:IsInHeaderArea(localX, localY)
    local props = self.props

    -- Use values stored during render for consistent hit testing
    if props.orientation == "vertical" then
        local headerWidth = self.scaledTabWidth_ or (props.tabWidth or 120)
        return localX < headerWidth
    else
        local tabHeight = self.scaledTabHeight_ or props.tabHeight
        return localY < tabHeight
    end
end

--- Get active tab content widget
function Tabs:GetActiveContent()
    return self.tabContents_[self.props.activeTab]
end

--- Get children for hit testing (used by UI.findWidgetAt)
function Tabs:GetHitTestChildren()
    local content = self:GetActiveContent()
    if content and content.renderOffsetX_ then
        return { content }
    end
    return nil
end

function Tabs:OnMouseEnter()
    -- Handled by OnPointerMove
end

function Tabs:OnMouseLeave()
    self:SetState({ hoveredTab = nil })
end

function Tabs:OnPointerMove(event)
    Widget.OnPointerMove(self, event)

    local l = self:GetAbsoluteLayoutForHitTest()
    local localX = event.x - l.x
    local localY = event.y - l.y

    if self:IsInHeaderArea(localX, localY) then
        -- Handle header hover
        local hoveredTab = nil
        for tabId, layout in pairs(self.tabLayouts_ or {}) do
            if localX >= layout.x and localX <= layout.x + layout.w
                and localY >= layout.y and localY <= layout.y + layout.h then
                hoveredTab = tabId
                break
            end
        end

        if self.state.hoveredTab ~= hoveredTab then
            self:SetState({ hoveredTab = hoveredTab })
        end
    else
        -- Clear header hover
        if self.state.hoveredTab then
            self:SetState({ hoveredTab = nil })
        end
    end
end

function Tabs:OnPointerDown(event)
    Widget.OnPointerDown(self, event)

    if not event then return end

    local l = self:GetAbsoluteLayoutForHitTest()
    local localX = event.x - l.x
    local localY = event.y - l.y

    -- Forward to content if in content area
    if not self:IsInHeaderArea(localX, localY) then
        local content = self:GetActiveContent()
        if content and content.OnPointerDown then
            content:OnPointerDown(event)
        end
    end
end

function Tabs:OnPointerUp(event)
    Widget.OnPointerUp(self, event)

    if not event then return end

    local l = self:GetAbsoluteLayoutForHitTest()
    local localX = event.x - l.x
    local localY = event.y - l.y

    -- Forward to content if in content area
    if not self:IsInHeaderArea(localX, localY) then
        local content = self:GetActiveContent()
        if content and content.OnPointerUp then
            content:OnPointerUp(event)
        end
    end
end

function Tabs:OnClick(event)
    if not event then return end

    -- Get widget's screen position (for hit testing)
    local l = self:GetAbsoluteLayoutForHitTest()

    -- Convert event coordinates to local coordinates relative to Tabs widget
    local localX = event.x - l.x
    local localY = event.y - l.y

    if self:IsInHeaderArea(localX, localY) then
        -- Check which tab was clicked using local coordinates
        -- tabLayouts_ stores coordinates relative to header origin (0,0)
        for tabId, layout in pairs(self.tabLayouts_ or {}) do
            if localX >= layout.x and localX <= layout.x + layout.w
                and localY >= layout.y and localY <= layout.y + layout.h then

                -- Find tab and check if disabled
                for _, tab in ipairs(self.props.tabs) do
                    if tab.id == tabId and not tab.disabled then
                        self:SetActiveTab(tabId)
                        break
                    end
                end
                break
            end
        end
    end
    -- Content area clicks are handled by normal event propagation
    -- Do NOT forward clicks to content here - it causes infinite recursion
end

-- ============================================================================
-- Content Management
-- ============================================================================

--- Set content for a tab
---@param tabId string|number
---@param content Widget
---@return Tabs self
function Tabs:SetTabContent(tabId, content)
    if self.tabContents_[tabId] then
        self.tabContents_[tabId].parent = nil
    end
    self.tabContents_[tabId] = content
    if content then
        content.parent = self
    end
    return self
end

--- Get content for a tab
---@param tabId string|number
---@return Widget|nil
function Tabs:GetTabContent(tabId)
    return self.tabContents_[tabId]
end

--- Remove content for a tab
---@param tabId string|number
---@return Tabs self
function Tabs:RemoveTabContent(tabId)
    if self.tabContents_[tabId] then
        self.tabContents_[tabId].parent = nil
        self.tabContents_[tabId] = nil
    end
    return self
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set active tab
---@param tabId string|number
---@return Tabs self
function Tabs:SetActiveTab(tabId)
    if self.props.activeTab ~= tabId then
        -- Notify old content of mouse leave (clear hover state)
        local oldContent = self.tabContents_[self.props.activeTab]
        if oldContent and oldContent.OnMouseLeave then
            oldContent:OnMouseLeave()
        end

        self.props.activeTab = tabId

        -- Find tab object
        local tab = nil
        for _, t in ipairs(self.props.tabs) do
            if t.id == tabId then
                tab = t
                break
            end
        end

        if self.props.onChange then
            self.props.onChange(self, tabId, tab)
        end
    end
    return self
end

--- Get active tab ID
---@return string|number
function Tabs:GetActiveTab()
    return self.props.activeTab
end

--- Add a tab
---@param tab TabItem
---@param content Widget|nil
---@return Tabs self
function Tabs:AddTab(tab, content)
    table.insert(self.props.tabs, tab)
    if content then
        self:SetTabContent(tab.id, content)
    end

    -- Set as active if first tab
    if #self.props.tabs == 1 then
        self.props.activeTab = tab.id
    end

    return self
end

--- Remove a tab by ID
---@param tabId string|number
---@return Tabs self
function Tabs:RemoveTab(tabId)
    for i, tab in ipairs(self.props.tabs) do
        if tab.id == tabId then
            table.remove(self.props.tabs, i)
            self:RemoveTabContent(tabId)

            -- Switch to another tab if active was removed
            if self.props.activeTab == tabId and #self.props.tabs > 0 then
                self.props.activeTab = self.props.tabs[1].id
            end
            break
        end
    end
    return self
end

--- Update tab properties
---@param tabId string|number
---@param updates table { label, disabled, etc }
---@return Tabs self
function Tabs:UpdateTab(tabId, updates)
    for _, tab in ipairs(self.props.tabs) do
        if tab.id == tabId then
            for k, v in pairs(updates) do
                tab[k] = v
            end
            break
        end
    end
    return self
end

--- Set tabs
---@param tabs TabItem[]
---@return Tabs self
function Tabs:SetTabs(tabs)
    self.props.tabs = tabs or {}

    -- Clear content
    for tabId, content in pairs(self.tabContents_) do
        content.parent = nil
    end
    self.tabContents_ = {}

    -- Reset active tab
    if #self.props.tabs > 0 then
        self.props.activeTab = self.props.tabs[1].id
    else
        self.props.activeTab = nil
    end

    return self
end

--- Get tab count
---@return number
function Tabs:GetTabCount()
    return #self.props.tabs
end

--- Set variant
---@param variant string "line" | "enclosed" | "pills"
---@return Tabs self
function Tabs:SetVariant(variant)
    self.props.variant = variant
    return self
end

--- Set orientation
---@param orientation string "horizontal" | "vertical"
---@return Tabs self
function Tabs:SetOrientation(orientation)
    self.props.orientation = orientation
    if orientation == "vertical" then
        self.props.flexDirection = "row"
    else
        self.props.flexDirection = "column"
    end
    return self
end

--- Navigate to next tab
---@return Tabs self
function Tabs:NextTab()
    local tabs = self.props.tabs
    local activeTab = self.props.activeTab

    for i, tab in ipairs(tabs) do
        if tab.id == activeTab then
            -- Find next non-disabled tab
            for j = i + 1, #tabs do
                if not tabs[j].disabled then
                    self:SetActiveTab(tabs[j].id)
                    return self
                end
            end
            -- Wrap to beginning
            for j = 1, i - 1 do
                if not tabs[j].disabled then
                    self:SetActiveTab(tabs[j].id)
                    return self
                end
            end
            break
        end
    end

    return self
end

--- Navigate to previous tab
---@return Tabs self
function Tabs:PrevTab()
    local tabs = self.props.tabs
    local activeTab = self.props.activeTab

    for i, tab in ipairs(tabs) do
        if tab.id == activeTab then
            -- Find previous non-disabled tab
            for j = i - 1, 1, -1 do
                if not tabs[j].disabled then
                    self:SetActiveTab(tabs[j].id)
                    return self
                end
            end
            -- Wrap to end
            for j = #tabs, i + 1, -1 do
                if not tabs[j].disabled then
                    self:SetActiveTab(tabs[j].id)
                    return self
                end
            end
            break
        end
    end

    return self
end

-- ============================================================================
-- Stateful
-- ============================================================================

function Tabs:IsStateful()
    return true
end

return Tabs
