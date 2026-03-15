-- ============================================================================
-- Timeline Widget
-- Display events or activities in chronological order
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local UI = require("urhox-libs/UI/Core/UI")

---@class TimelineItem
---@field title string|nil Item title
---@field description string|nil Item description
---@field time string|nil Time/date label
---@field label string|nil Alternative to time
---@field icon string|nil Item icon
---@field color string|table|nil Item color (theme name or RGBA table)
---@field onClick fun(item: TimelineItem, index: number)|nil Item click callback

---@class TimelineProps : WidgetProps
---@field items TimelineItem[]|nil Timeline items array
---@field position string|nil "left" | "right" | "alternate" (default: "right")
---@field size string|nil "sm" | "md" | "lg" (default: "md")
---@field variant string|nil "default" | "outlined" | "filled" (default: "default")
---@field connectorStyle string|nil "solid" | "dashed" | "dotted" (default: "solid")
---@field showConnector boolean|nil Show connector lines (default: true)
---@field lineColor table|nil Connector line color (default: border)
---@field dotColor table|nil Dot color (default: primary)
---@field dotSize number|nil Custom dot size
---@field lineWidth number|nil Custom line width
---@field fontSize number|nil Custom font size
---@field titleSize number|nil Custom title font size
---@field gap number|nil Gap between items
---@field contentGap number|nil Gap between content elements
---@field onItemClick fun(timeline: Timeline, item: TimelineItem, index: number)|nil Item click callback

---@class Timeline : Widget
---@operator call(TimelineProps?): Timeline
---@field props TimelineProps
---@field new fun(self, props: TimelineProps?): Timeline
local Timeline = Widget:Extend("Timeline")

-- ============================================================================
-- Size presets
-- ============================================================================

local SIZE_PRESETS = {
    sm = { dotSize = 10, lineWidth = 2, fontSize = 12, titleSize = 13, gap = 12, contentGap = 4 },
    md = { dotSize = 14, lineWidth = 2, fontSize = 14, titleSize = 15, gap = 16, contentGap = 6 },
    lg = { dotSize = 18, lineWidth = 3, fontSize = 16, titleSize = 18, gap = 20, contentGap = 8 },
}

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props TimelineProps?
function Timeline:Init(props)
    props = props or {}

    -- Timeline props
    self.items_ = props.items or {}
    self.position_ = props.position or "right"  -- left, right, alternate
    self.size_ = props.size or "md"
    self.variant_ = props.variant or "default"  -- default, outlined, filled
    self.connectorStyle_ = props.connectorStyle or "solid"  -- solid, dashed, dotted
    self.showConnector_ = props.showConnector ~= false  -- default true

    -- Colors
    self.lineColor_ = props.lineColor or Theme.Color("border")
    self.dotColor_ = props.dotColor or Theme.Color("primary")

    -- Callbacks
    self.onItemClick_ = props.onItemClick

    -- State
    self.hoverIndex_ = nil

    -- Calculate dimensions
    local sizePreset = SIZE_PRESETS[self.size_] or SIZE_PRESETS.md
    self.dotSize_ = props.dotSize or sizePreset.dotSize
    self.lineWidth_ = props.lineWidth or sizePreset.lineWidth
    self.fontSize_ = props.fontSize or Theme.FontSize(sizePreset.fontSize)
    self.titleSize_ = props.titleSize or sizePreset.titleSize
    self.gap_ = props.gap or sizePreset.gap
    self.contentGap_ = props.contentGap or sizePreset.contentGap

    props.flexDirection = "column"

    Widget.Init(self, props)

    -- Calculate and set height
    self:UpdateHeight()
end

-- ============================================================================
-- Height Calculation
-- ============================================================================

function Timeline:CalculateTotalHeight()
    local itemCount = #self.items_
    if itemCount == 0 then return self.dotSize_ + self.gap_ * 2 end

    local totalHeight = 0

    for i, item in ipairs(self.items_) do
        local itemHeight = 0

        -- Time/label
        if item.time or item.label then
            itemHeight = itemHeight + self.fontSize_ + self.contentGap_
        end

        -- Title
        if item.title then
            itemHeight = itemHeight + self.titleSize_ + self.contentGap_
        end

        -- Description
        if item.description then
            itemHeight = itemHeight + self.fontSize_
        end

        -- Minimum height per item
        itemHeight = math.max(itemHeight, self.dotSize_ + self.gap_)

        totalHeight = totalHeight + itemHeight + self.gap_
    end

    return totalHeight
end

function Timeline:UpdateHeight()
    local height = self:CalculateTotalHeight()
    self:SetStyle({ height = height })  -- SetStyle auto-triggers layout dirty
end

-- ============================================================================
-- Items Management
-- ============================================================================

function Timeline:GetItems()
    return self.items_
end

function Timeline:SetItems(items)
    self.items_ = items or {}
    self:UpdateHeight()
end

function Timeline:AddItem(item)
    table.insert(self.items_, item)
    self:UpdateHeight()
end

function Timeline:RemoveItem(index)
    table.remove(self.items_, index)
    self:UpdateHeight()
end

-- ============================================================================
-- Drawing Helpers
-- ============================================================================

function Timeline:GetItemColor(item, index)
    if item.color then
        if type(item.color) == "string" then
            return Theme.Color(item.color)
        end
        return item.color
    end
    return self.dotColor_
end

function Timeline:DrawDot(nvg, x, y, item, index, isHovered)
    self:DrawDotScaled(nvg, x, y, item, index, isHovered, self.dotSize_)
end

function Timeline:DrawDotScaled(nvg, x, y, item, index, isHovered, size)
    local color = self:GetItemColor(item, index)
    local radius = size / 2

    local nvgColor = Theme.ToNvgColor(color)

    if self.variant_ == "outlined" then
        -- Outlined dot
        nvgBeginPath(nvg)
        nvgCircle(nvg, x, y, radius)
        nvgStrokeColor(nvg, nvgColor)
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        if isHovered then
            nvgBeginPath(nvg)
            nvgCircle(nvg, x, y, radius - 2)
            nvgFillColor(nvg, nvgColor)
            nvgFill(nvg)
        end
    elseif self.variant_ == "filled" then
        -- Filled dot with border
        nvgBeginPath(nvg)
        nvgCircle(nvg, x, y, radius)
        nvgFillColor(nvg, nvgColor)
        nvgFill(nvg)

        -- White inner circle
        if not item.icon then
            nvgBeginPath(nvg)
            nvgCircle(nvg, x, y, radius * 0.4)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
            nvgFill(nvg)
        end
    else
        -- Default: solid dot
        nvgBeginPath(nvg)
        nvgCircle(nvg, x, y, radius)
        nvgFillColor(nvg, nvgColor)
        nvgFill(nvg)
    end

    -- Draw icon if provided
    if item.icon then
        nvgFontSize(nvg, size * 0.6)
        nvgFontFace(nvg, Theme.FontFamily())
        nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)

        local iconColor = (self.variant_ == "outlined") and nvgColor or nvgRGBA(255, 255, 255, 255)
        nvgFillColor(nvg, iconColor)
        nvgText(nvg, x, y, item.icon)
    end
end

function Timeline:DrawConnector(nvg, x1, y1, x2, y2)
    self:DrawConnectorScaled(nvg, x1, y1, x2, y2, self.lineWidth_)
end

function Timeline:DrawConnectorScaled(nvg, x1, y1, x2, y2, lineWidth)
    if not self.showConnector_ then return end

    nvgBeginPath(nvg)

    if self.connectorStyle_ == "dashed" then
        -- Dashed line
        local dashLen = 4
        local gapLen = 3
        local totalLen = math.abs(y2 - y1)
        local currentY = y1

        while currentY < y2 - dashLen do
            nvgMoveTo(nvg, x1, currentY)
            nvgLineTo(nvg, x1, math.min(currentY + dashLen, y2))
            currentY = currentY + dashLen + gapLen
        end
    elseif self.connectorStyle_ == "dotted" then
        -- Dotted line
        local dotGap = 4
        local currentY = y1

        while currentY < y2 do
            nvgBeginPath(nvg)
            nvgCircle(nvg, x1, currentY, lineWidth * 0.5)
            nvgFillColor(nvg, Theme.ToNvgColor(self.lineColor_))
            nvgFill(nvg)
            currentY = currentY + dotGap
        end
        return
    else
        -- Solid line
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
    end

    nvgStrokeColor(nvg, Theme.ToNvgColor(self.lineColor_))
    nvgStrokeWidth(nvg, lineWidth)
    nvgStroke(nvg)
end

-- ============================================================================
-- Render
-- ============================================================================

function Timeline:Render(nvg)
    local x, y = self:GetAbsolutePosition()
    local w, h = self:GetComputedSize()
    local theme = Theme.GetTheme()

    -- Render background (if any)
    Widget.Render(self, nvg)

    local itemCount = #self.items_
    if itemCount == 0 then return end

    -- Size values (no scale needed - nvgScale handles it)
    local dotSize = self.dotSize_
    local lineWidth = self.lineWidth_
    local gap = self.gap_
    local contentGap = self.contentGap_
    local fontSize = Theme.FontSize(SIZE_PRESETS[self.size_].fontSize)
    local titleSize = Theme.FontSize(SIZE_PRESETS[self.size_].titleSize)

    -- Calculate layout
    local contentWidth = w - dotSize - gap * 2
    local dotCenterX

    if self.position_ == "left" then
        dotCenterX = x + w - dotSize / 2 - gap
    elseif self.position_ == "alternate" then
        dotCenterX = x + w / 2
        contentWidth = (w - dotSize - gap * 2) / 2
    else  -- right (default)
        dotCenterX = x + dotSize / 2 + gap
    end

    -- Store item positions for hit testing
    self.itemPositions_ = {}

    local currentY = y

    for i, item in ipairs(self.items_) do
        local isHovered = self.hoverIndex_ == i
        local isAlternateLeft = self.position_ == "alternate" and (i % 2 == 0)

        -- Calculate content position
        local contentX
        local textAlign

        if self.position_ == "left" then
            contentX = x + gap
            textAlign = NVG_ALIGN_RIGHT
        elseif isAlternateLeft then
            contentX = x + gap
            textAlign = NVG_ALIGN_RIGHT
        else
            contentX = dotCenterX + dotSize / 2 + gap
            textAlign = NVG_ALIGN_LEFT
        end

        -- Calculate item height
        local itemHeight = 0

        -- Time/label above or beside
        if item.time or item.label then
            itemHeight = itemHeight + fontSize + contentGap
        end

        -- Title
        if item.title then
            itemHeight = itemHeight + titleSize + contentGap
        end

        -- Description
        if item.description then
            itemHeight = itemHeight + fontSize
        end

        -- Minimum height
        itemHeight = math.max(itemHeight, dotSize + gap)

        -- Draw connector to next item (before dot so dot is on top)
        if i < itemCount then
            local connectorY1 = currentY + dotSize / 2
            local connectorY2 = currentY + itemHeight + gap
            self:DrawConnectorScaled(nvg, dotCenterX, connectorY1, dotCenterX, connectorY2, lineWidth)
        end

        -- Draw dot
        self:DrawDotScaled(nvg, dotCenterX, currentY + dotSize / 2, item, i, isHovered, dotSize)

        -- Draw content
        local textY = currentY

        -- Time/label (opposite side for alternate, or above for others)
        if item.time or item.label then
            local timeText = item.time or item.label
            nvgFontSize(nvg, fontSize * 0.9)
            nvgFontFace(nvg, Theme.FontFamily())

            if self.position_ == "alternate" then
                -- Draw on opposite side
                local oppositeX = isAlternateLeft and (dotCenterX + dotSize / 2 + gap) or (dotCenterX - dotSize / 2 - gap)
                local oppositeAlign = isAlternateLeft and NVG_ALIGN_LEFT or NVG_ALIGN_RIGHT
                nvgTextAlign(nvg, oppositeAlign + NVG_ALIGN_TOP)
                nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
                nvgText(nvg, oppositeX, textY, timeText)
            else
                -- Draw above title
                nvgTextAlign(nvg, textAlign + NVG_ALIGN_TOP)
                nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
                local timeX = (self.position_ == "left" or isAlternateLeft) and (contentX + contentWidth) or contentX
                nvgText(nvg, timeX, textY, timeText)
                textY = textY + fontSize + contentGap
            end
        end

        -- Title
        if item.title then
            nvgFontSize(nvg, titleSize)
            nvgFontFace(nvg, Theme.FontFamily())
            nvgTextAlign(nvg, textAlign + NVG_ALIGN_TOP)

            local titleColor = isHovered and Theme.Color("primary") or Theme.Color("text")
            nvgFillColor(nvg, Theme.ToNvgColor(titleColor))

            local titleX = (self.position_ == "left" or isAlternateLeft) and (contentX + contentWidth) or contentX
            nvgText(nvg, titleX, textY, item.title)
            textY = textY + titleSize + contentGap
        end

        -- Description
        if item.description then
            nvgFontSize(nvg, fontSize)
            nvgFontFace(nvg, Theme.FontFamily())
            nvgTextAlign(nvg, textAlign + NVG_ALIGN_TOP)
            nvgFillColor(nvg, Theme.NvgColor("textSecondary"))

            local descX = (self.position_ == "left" or isAlternateLeft) and (contentX + contentWidth) or contentX
            nvgText(nvg, descX, textY, item.description)
        end

        -- Store position for hit testing
        self.itemPositions_[i] = {
            x1 = x,
            x2 = x + w,
            y1 = currentY,
            y2 = currentY + itemHeight,
            item = item,
            index = i,
        }

        currentY = currentY + itemHeight + gap
    end
end

-- ============================================================================
-- Input Handling
-- ============================================================================

function Timeline:GetItemAtPosition(screenX, screenY)
    if not self.itemPositions_ then return nil end

    -- Get offset between render coords and screen coords
    local renderX, renderY = self:GetAbsolutePosition()
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    local offsetX = renderX - hitTest.x
    local offsetY = renderY - hitTest.y

    -- Convert screen coords to render coords
    local px = screenX + offsetX
    local py = screenY + offsetY

    for i, pos in ipairs(self.itemPositions_) do
        if px >= pos.x1 and px <= pos.x2 and py >= pos.y1 and py <= pos.y2 then
            return pos
        end
    end

    return nil
end

function Timeline:OnPointerMove(event)
    if not event then return end

    local itemPos = self:GetItemAtPosition(event.x, event.y)

    if itemPos then
        self.hoverIndex_ = itemPos.index
    else
        self.hoverIndex_ = nil
    end
end

function Timeline:OnMouseLeave()
    self.hoverIndex_ = nil
end

function Timeline:OnClick(event)
    if not event then return end

    local itemPos = self:GetItemAtPosition(event.x, event.y)

    if itemPos then
        if self.onItemClick_ then
            self.onItemClick_(self, itemPos.item, itemPos.index)
        end

        if itemPos.item.onClick then
            itemPos.item.onClick(itemPos.item, itemPos.index)
        end
    end
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create timeline from simple data
---@param items table[] Array of {title, description, time}
---@param props table|nil Additional props
---@return Timeline
function Timeline.FromData(items, props)
    props = props or {}
    props.items = items
    return Timeline(props)
end

--- Create an activity timeline
---@param activities table[] Array of activity items
---@param props table|nil Additional props
---@return Timeline
function Timeline.Activity(activities, props)
    props = props or {}
    props.items = activities
    props.size = props.size or "sm"
    return Timeline(props)
end

--- Create a history/changelog timeline
---@param entries table[] Array of history entries
---@param props table|nil Additional props
---@return Timeline
function Timeline.History(entries, props)
    props = props or {}

    local items = {}
    for _, entry in ipairs(entries) do
        table.insert(items, {
            title = entry.version or entry.title,
            description = entry.description or entry.changes,
            time = entry.date or entry.time,
            icon = entry.icon,
            color = entry.color,
        })
    end

    props.items = items
    return Timeline(props)
end

--- Create an order tracking timeline
---@param steps table[] Array of tracking steps
---@param currentStep number Current step index
---@param props table|nil Additional props
---@return Timeline
function Timeline.OrderTracking(steps, currentStep, props)
    props = props or {}

    local items = {}
    for i, step in ipairs(steps) do
        local item = {
            title = step.title or step.label,
            description = step.description,
            time = step.time,
        }

        if i < currentStep then
            item.color = "success"
            item.icon = "V"  -- checkmark
        elseif i == currentStep then
            item.color = "primary"
        else
            item.color = Theme.Color("border")
        end

        table.insert(items, item)
    end

    props.items = items
    props.variant = "filled"
    return Timeline(props)
end

--- Create a process/workflow timeline
---@param steps table[] Array of process steps
---@param props table|nil Additional props
---@return Timeline
function Timeline.Process(steps, props)
    props = props or {}

    local items = {}
    for i, step in ipairs(steps) do
        table.insert(items, {
            title = step.title or ("Step " .. i),
            description = step.description,
            icon = tostring(i),
            color = step.color or (step.completed and "success" or "primary"),
        })
    end

    props.items = items
    props.variant = "filled"
    return Timeline(props)
end

--- Create an alternating timeline
---@param items table[] Array of items
---@param props table|nil Additional props
---@return Timeline
function Timeline.Alternate(items, props)
    props = props or {}
    props.items = items
    props.position = "alternate"
    return Timeline(props)
end

return Timeline
