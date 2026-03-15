-- ============================================================================
-- ProgressBar Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Progress bar with optional label
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class ProgressBarProps : WidgetProps
---@field value number|nil Current value (default: 0)
---@field max number|nil Maximum value (default: 1)
---@field showLabel boolean|nil Show percentage label
---@field variant string|nil "primary" | "success" | "warning" | "error"
---@field indeterminate boolean|nil Indeterminate (loading) mode

---@class ProgressBar : Widget
---@operator call(ProgressBarProps?): ProgressBar
---@field props ProgressBarProps
---@field new fun(self, props: ProgressBarProps?): ProgressBar
local ProgressBar = Widget:Extend("ProgressBar")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props ProgressBarProps?
function ProgressBar:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("ProgressBar")
    props.height = props.height or themeStyle.height or 8
    props.borderRadius = props.borderRadius or themeStyle.borderRadius or 4

    -- Default values
    props.value = props.value or 0
    props.max = props.max or 1
    props.variant = props.variant or "primary"

    -- Indeterminate animation state
    self.animOffset_ = 0

    Widget.Init(self, props)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function ProgressBar:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props

    local value = props.value
    local max = props.max
    local borderRadius = props.borderRadius
    local indeterminate = props.indeterminate
    local showLabel = props.showLabel
    local variant = props.variant

    -- Calculate progress (0-1)
    local progress = math.max(0, math.min(1, value / max))

    -- Get colors based on variant
    local bgColor = Theme.Color("surface")
    local fillColor

    if variant == "success" then
        fillColor = Theme.Color("success")
    elseif variant == "warning" then
        fillColor = Theme.Color("warning")
    elseif variant == "error" then
        fillColor = Theme.Color("error")
    else
        fillColor = Theme.Color("primary")
    end

    -- Draw track background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
    nvgFill(nvg)

    if indeterminate then
        -- Indeterminate animation
        local barWidth = l.w * 0.3
        local offset = self.animOffset_
        local barX = l.x + (l.w + barWidth) * offset - barWidth

        -- Clip to track bounds
        nvgSave(nvg)
        nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, l.y, barWidth, l.h, borderRadius)
        nvgFillColor(nvg, nvgRGBA(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 255))
        nvgFill(nvg)

        nvgRestore(nvg)
    else
        -- Determinate progress fill
        local fillWidth = l.w * progress
        if fillWidth > 0 then
            nvgBeginPath(nvg)
            if fillWidth < l.w then
                -- Partial fill - only round left corners
                nvgRoundedRectVarying(nvg, l.x, l.y, fillWidth, l.h,
                    borderRadius, 0, 0, borderRadius)
            else
                -- Full fill - round all corners
                nvgRoundedRect(nvg, l.x, l.y, fillWidth, l.h, borderRadius)
            end
            nvgFillColor(nvg, nvgRGBA(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 255))
            nvgFill(nvg)
        end
    end

    -- Draw label
    if showLabel and not indeterminate then
        local percent = math.floor(progress * 100)
        local labelText = string.format("%d%%", percent)

        local fontFamily = Theme.FontFamily()
        local textColor = Theme.Color("text")

        nvgFontFace(nvg, fontFamily)
        nvgFontSize(nvg, Theme.FontSizeOf("small"))
        nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
        nvgText(nvg, l.x + l.w / 2, l.y + l.h / 2, labelText, nil)
    end
end

-- ============================================================================
-- Update (for indeterminate animation)
-- ============================================================================

function ProgressBar:Update(dt)
    if self.props.indeterminate then
        self.animOffset_ = self.animOffset_ + dt * 0.5  -- Speed
        if self.animOffset_ > 1 then
            self.animOffset_ = 0
        end
    end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set progress value
---@param value number
---@return ProgressBar self
function ProgressBar:SetValue(value)
    self.props.value = math.max(0, math.min(self.props.max, value))
    return self
end

--- Get progress value
---@return number
function ProgressBar:GetValue()
    return self.props.value
end

--- Get progress as percentage (0-100)
---@return number
function ProgressBar:GetPercent()
    return (self.props.value / self.props.max) * 100
end

--- Set maximum value
---@param max number
---@return ProgressBar self
function ProgressBar:SetMax(max)
    self.props.max = max
    return self
end

--- Set variant
---@param variant string "primary" | "success" | "warning" | "error"
---@return ProgressBar self
function ProgressBar:SetVariant(variant)
    self.props.variant = variant
    return self
end

--- Set indeterminate mode
---@param indeterminate boolean
---@return ProgressBar self
function ProgressBar:SetIndeterminate(indeterminate)
    self.props.indeterminate = indeterminate
    if indeterminate then
        self.animOffset_ = 0
    end
    return self
end

--- Show/hide label
---@param show boolean
---@return ProgressBar self
function ProgressBar:SetShowLabel(show)
    self.props.showLabel = show
    return self
end

-- ============================================================================
-- Stateless (unless indeterminate)
-- ============================================================================

function ProgressBar:IsStateful()
    return self.props.indeterminate == true
end

return ProgressBar
