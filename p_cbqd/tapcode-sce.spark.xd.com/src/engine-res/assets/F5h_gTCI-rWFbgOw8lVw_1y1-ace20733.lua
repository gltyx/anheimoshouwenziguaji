-- ============================================================================
-- Tooltip Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Hover tooltip with auto-positioning
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local UI = require("urhox-libs/UI/Core/UI")

---@class TooltipProps : WidgetProps
---@field content string|nil Tooltip text content
---@field position string|nil "top" | "bottom" | "left" | "right" (default: "top")
---@field delay number|nil Show delay in seconds (default: 0.3)
---@field offset number|nil Offset from target (default: 8)
---@field maxWidth number|nil Maximum width (default: 250)

---@class Tooltip : Widget
---@operator call(TooltipProps?): Tooltip
---@field props TooltipProps
---@field new fun(self, props: TooltipProps?): Tooltip
local Tooltip = Widget:Extend("Tooltip")

-- Arrow size
local ARROW_SIZE = 6

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props TooltipProps?
function Tooltip:Init(props)
    props = props or {}

    -- Tooltip content
    self.content_ = props.content or ""
    self.position_ = props.position or "top"  -- top, bottom, left, right
    self.delay_ = props.delay or 0.3  -- 300ms delay
    self.offset_ = props.offset or 8
    self.maxWidth_ = props.maxWidth or 250

    -- State
    self.isShowing_ = false
    self.opacity_ = 0
    self.hoverTimer_ = 0
    self.isHovered_ = false
    self.triggerBounds_ = nil

    Widget.Init(self, props)

    -- Handle children (trigger element)
    if props.children and #props.children > 0 then
        self.triggerChild_ = props.children[1]
        self:AddChild(self.triggerChild_)

        -- Wrap child's OnPointerEnter/OnPointerLeave to show tooltip
        local originalEnter = self.triggerChild_.OnPointerEnter
        local originalLeave = self.triggerChild_.OnPointerLeave
        local tooltipSelf = self

        self.triggerChild_.OnPointerEnter = function(widget, event)
            tooltipSelf.isHovered_ = true
            tooltipSelf.hoverTimer_ = 0
            if originalEnter then
                originalEnter(widget, event)
            end
        end

        self.triggerChild_.OnPointerLeave = function(widget, event)
            tooltipSelf.isHovered_ = false
            tooltipSelf.isShowing_ = false
            tooltipSelf.hoverTimer_ = 0
            if originalLeave then
                originalLeave(widget, event)
            end
        end
    end
end

-- ============================================================================
-- Update
-- ============================================================================

function Tooltip:Update(dt)
    local animSpeed = 8

    -- Update hover timer
    if self.isHovered_ and self.hoverTimer_ < self.delay_ then
        self.hoverTimer_ = self.hoverTimer_ + dt
        if self.hoverTimer_ >= self.delay_ then
            self.isShowing_ = true
        end
    end

    -- Animate opacity
    local targetOpacity = self.isShowing_ and 1 or 0
    if self.opacity_ < targetOpacity then
        self.opacity_ = math.min(targetOpacity, self.opacity_ + dt * animSpeed)
    elseif self.opacity_ > targetOpacity then
        self.opacity_ = math.max(targetOpacity, self.opacity_ - dt * animSpeed)
    end
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Tooltip:Render(nvg)
    -- Update trigger bounds
    if self.triggerChild_ then
        local l = self.triggerChild_:GetAbsoluteLayoutForHitTest()
        if l and l.w > 0 then
            self.triggerBounds_ = { x = l.x, y = l.y, w = l.w, h = l.h }
        end
    end

    -- Queue tooltip as overlay if visible
    if self.opacity_ > 0 and self.triggerBounds_ then
        UI.QueueOverlay(function(overlayNvg)
            self:RenderTooltip(overlayNvg)
        end)
    end
end

function Tooltip:RenderTooltip(nvg)
    local text = self.content_
    local position = self.position_
    local offset = self.offset_
    local maxWidth = self.maxWidth_
    local borderRadius = 6
    local arrowSize = ARROW_SIZE

    local fontFamily = Theme.FontFamily()
    local fontSize = Theme.FontSizeOf("small")
    local padding = 8

    -- Measure text
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, fontSize)

    local textWidth = nvgTextBounds(nvg, 0, 0, text) or 0
    if textWidth <= 0 then
        textWidth = #text * fontSize * 0.5
    end
    textWidth = math.min(textWidth, maxWidth)

    local tooltipWidth = textWidth + padding * 2
    local tooltipHeight = fontSize + padding * 2

    -- Get screen size
    local screenWidth = UI.GetWidth() or 800
    local screenHeight = UI.GetHeight() or 600

    -- Calculate position based on trigger bounds
    local tb = self.triggerBounds_
    local tx, ty, tw, th = tb.x, tb.y, tb.w, tb.h
    local x, y, arrowX, arrowY, arrowDir

    if position == "top" then
        x = tx + tw / 2 - tooltipWidth / 2
        y = ty - tooltipHeight - offset - arrowSize
        arrowX = tx + tw / 2
        arrowY = y + tooltipHeight
        arrowDir = "down"

        -- Flip to bottom if out of bounds
        if y < 0 then
            y = ty + th + offset + arrowSize
            arrowY = y - arrowSize
            arrowDir = "up"
        end
    elseif position == "bottom" then
        x = tx + tw / 2 - tooltipWidth / 2
        y = ty + th + offset + arrowSize
        arrowX = tx + tw / 2
        arrowY = y - arrowSize
        arrowDir = "up"

        -- Flip to top if out of bounds
        if y + tooltipHeight > screenHeight then
            y = ty - tooltipHeight - offset - arrowSize
            arrowY = y + tooltipHeight
            arrowDir = "down"
        end
    elseif position == "left" then
        x = tx - tooltipWidth - offset - arrowSize
        y = ty + th / 2 - tooltipHeight / 2
        arrowX = x + tooltipWidth
        arrowY = ty + th / 2
        arrowDir = "right"

        -- Flip to right if out of bounds
        if x < 0 then
            x = tx + tw + offset + arrowSize
            arrowX = x - arrowSize
            arrowDir = "left"
        end
    elseif position == "right" then
        x = tx + tw + offset + arrowSize
        y = ty + th / 2 - tooltipHeight / 2
        arrowX = x - arrowSize
        arrowY = ty + th / 2
        arrowDir = "left"

        -- Flip to left if out of bounds
        if x + tooltipWidth > screenWidth then
            x = tx - tooltipWidth - offset - arrowSize
            arrowX = x + tooltipWidth
            arrowDir = "right"
        end
    end

    -- Clamp to screen bounds
    x = math.max(4, math.min(screenWidth - tooltipWidth - 4, x))
    y = math.max(4, math.min(screenHeight - tooltipHeight - 4, y))

    local alpha = self.opacity_

    -- Colors
    local bgColor = { 40, 40, 40, math.floor(240 * alpha) }
    local textColor = { 255, 255, 255, math.floor(255 * alpha) }

    -- Draw shadow
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - 1, y + 1, tooltipWidth + 2, tooltipHeight + 2, borderRadius + 1)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(40 * alpha)))
    nvgFill(nvg)

    -- Draw background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, tooltipWidth, tooltipHeight, borderRadius)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    nvgFill(nvg)

    -- Draw arrow
    nvgBeginPath(nvg)
    if arrowDir == "down" then
        nvgMoveTo(nvg, arrowX - arrowSize, arrowY)
        nvgLineTo(nvg, arrowX, arrowY + arrowSize)
        nvgLineTo(nvg, arrowX + arrowSize, arrowY)
    elseif arrowDir == "up" then
        nvgMoveTo(nvg, arrowX - arrowSize, arrowY + arrowSize)
        nvgLineTo(nvg, arrowX, arrowY)
        nvgLineTo(nvg, arrowX + arrowSize, arrowY + arrowSize)
    elseif arrowDir == "left" then
        nvgMoveTo(nvg, arrowX + arrowSize, arrowY - arrowSize)
        nvgLineTo(nvg, arrowX, arrowY)
        nvgLineTo(nvg, arrowX + arrowSize, arrowY + arrowSize)
    elseif arrowDir == "right" then
        nvgMoveTo(nvg, arrowX, arrowY - arrowSize)
        nvgLineTo(nvg, arrowX + arrowSize, arrowY)
        nvgLineTo(nvg, arrowX, arrowY + arrowSize)
    end
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
    nvgFill(nvg)

    -- Draw text
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, fontSize)
    nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4]))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgText(nvg, x + tooltipWidth / 2, y + tooltipHeight / 2, text)
end

-- ============================================================================
-- Input Handling
-- ============================================================================

function Tooltip:PointInBounds(px, py, bounds)
    if not bounds then return false end
    return px >= bounds.x and px <= bounds.x + bounds.w and
           py >= bounds.y and py <= bounds.y + bounds.h
end

function Tooltip:OnPointerEnter(event)
    self.isHovered_ = true
    self.hoverTimer_ = 0
end

function Tooltip:OnPointerLeave(event)
    self.isHovered_ = false
    self.isShowing_ = false
    self.hoverTimer_ = 0
end

function Tooltip:HitTest(x, y)
    -- Hit test on trigger bounds
    if self.triggerBounds_ and self:PointInBounds(x, y, self.triggerBounds_) then
        return true
    end
    return false
end

-- ============================================================================
-- Public Methods
-- ============================================================================

function Tooltip:SetContent(content)
    self.content_ = content
end

function Tooltip:SetPosition(position)
    self.position_ = position
end

return Tooltip
