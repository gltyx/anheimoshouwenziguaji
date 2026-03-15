-- ============================================================================
-- Slider Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Value slider with track and thumb
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class SliderProps : WidgetProps
---@field value number|nil Current value (default: min)
---@field min number|nil Minimum value (default: 0)
---@field max number|nil Maximum value (default: 1)
---@field step number|nil Step increment
---@field disabled boolean|nil Is slider disabled
---@field trackHeight number|nil Track height (default: 4)
---@field thumbSize number|nil Thumb size (default: 16)
---@field onChange fun(self: Slider, value: number)|nil Change callback
---@field onChangeEnd fun(self: Slider, value: number)|nil Change end callback

---@class Slider : Widget
---@operator call(SliderProps?): Slider
---@field props SliderProps
---@field new fun(self, props: SliderProps?): Slider
---@field state {hovered: boolean, dragging: boolean}
---@field AddChild fun(self, child: Widget): self Add child widget
---@field RemoveChild fun(self, child: Widget): self Remove child widget
local Slider = Widget:Extend("Slider")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props SliderProps?
function Slider:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("Slider")
    props.trackHeight = props.trackHeight or themeStyle.trackHeight or 4
    props.thumbSize = props.thumbSize or themeStyle.thumbSize or 16

    -- Default range
    props.min = props.min or 0
    props.max = props.max or 1
    props.value = props.value or props.min

    -- Set widget height based on thumb size
    props.height = props.height or math.max(props.thumbSize + 8, 24)

    -- Initialize state
    self.state = {
        hovered = false,
        dragging = false,
    }

    Widget.Init(self, props)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Slider:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local value = props.value
    local min = props.min
    local max = props.max
    local disabled = props.disabled
    local trackHeight = props.trackHeight
    local thumbSize = props.thumbSize

    -- Calculate normalized value (0-1)
    local normalizedValue = (value - min) / (max - min)
    normalizedValue = math.max(0, math.min(1, normalizedValue))

    -- Track dimensions
    local trackX = l.x + thumbSize / 2
    local trackWidth = l.w - thumbSize
    local trackY = l.y + (l.h - trackHeight) / 2
    local trackRadius = trackHeight / 2

    -- Thumb position
    local thumbX = trackX + normalizedValue * trackWidth - thumbSize / 2
    local thumbY = l.y + (l.h - thumbSize) / 2

    -- Colors
    local trackBgColor = disabled and Theme.Color("disabled") or Theme.Color("surface")
    local trackFillColor = disabled and Theme.Color("disabledText") or Theme.Color("primary")
    local thumbColor

    if disabled then
        thumbColor = Theme.Color("disabledText")
    elseif state.dragging then
        thumbColor = Theme.Color("primaryPressed") or Style.Darken(Theme.Color("primary"), 0.2)
    elseif state.hovered then
        thumbColor = Theme.Color("primaryHover") or Style.Lighten(Theme.Color("primary"), 0.1)
    else
        thumbColor = Theme.Color("primary")
    end

    -- Draw track background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, trackX, trackY, trackWidth, trackHeight, trackRadius)
    nvgFillColor(nvg, nvgRGBA(trackBgColor[1], trackBgColor[2], trackBgColor[3], trackBgColor[4] or 255))
    nvgFill(nvg)

    -- Draw track fill (from left to thumb)
    local fillWidth = normalizedValue * trackWidth
    if fillWidth > 0 then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, trackX, trackY, fillWidth, trackHeight, trackRadius)
        nvgFillColor(nvg, nvgRGBA(trackFillColor[1], trackFillColor[2], trackFillColor[3], trackFillColor[4] or 255))
        nvgFill(nvg)
    end

    -- Draw thumb shadow
    if not disabled then
        nvgBeginPath(nvg)
        nvgCircle(nvg, thumbX + thumbSize / 2, thumbY + thumbSize / 2 + 1, thumbSize / 2)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
        nvgFill(nvg)
    end

    -- Draw thumb
    nvgBeginPath(nvg)
    nvgCircle(nvg, thumbX + thumbSize / 2, thumbY + thumbSize / 2, thumbSize / 2)
    nvgFillColor(nvg, nvgRGBA(thumbColor[1], thumbColor[2], thumbColor[3], thumbColor[4] or 255))
    nvgFill(nvg)

    -- Draw thumb border
    nvgBeginPath(nvg)
    nvgCircle(nvg, thumbX + thumbSize / 2, thumbY + thumbSize / 2, thumbSize / 2)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Slider:OnMouseEnter()
    if not self.props.disabled then
        self:SetState({ hovered = true })
    end
end

function Slider:OnMouseLeave()
    if not self.state.dragging then
        self:SetState({ hovered = false })
    end
end

function Slider:OnPointerDown(event)
    Widget.OnPointerDown(self, event)

    if not self.props.disabled and event:IsPrimaryAction() then
        self:SetState({ dragging = true })
        self:UpdateValueFromPosition(event.x)
    end
end

function Slider:OnPointerMove(event)
    Widget.OnPointerMove(self, event)

    if self.state.dragging then
        self:UpdateValueFromPosition(event.x)
    end
end

function Slider:OnPointerUp(event)
    Widget.OnPointerUp(self, event)

    if self.state.dragging then
        self:SetState({ dragging = false })
        if self.props.onChangeEnd then
            self.props.onChangeEnd(self, self.props.value)
        end
    end
end

-- Pan gesture support for mobile
-- Returns true if Slider handles this pan gesture (prevents ScrollView from scrolling)
function Slider:OnPanStart(event)
    if not self.props.disabled then
        self:SetState({ dragging = true })
        self:UpdateValueFromPosition(event.x)
        return true  -- We're handling this pan gesture
    end
    return false
end

function Slider:OnPanMove(event)
    if self.state.dragging then
        self:UpdateValueFromPosition(event.x)
    end
end

function Slider:OnPanEnd(event)
    if self.state.dragging then
        self:SetState({ dragging = false })
        if self.props.onChangeEnd then
            self.props.onChangeEnd(self, self.props.value)
        end
    end
end

-- ============================================================================
-- Internal
-- ============================================================================

--- Update value from pointer X position
---@param x number
function Slider:UpdateValueFromPosition(x)
    -- Use GetAbsoluteLayoutForHitTest for proper scroll offset handling
    local l = self:GetAbsoluteLayoutForHitTest()
    local thumbSize = self.props.thumbSize

    local trackX = l.x + thumbSize / 2
    local trackWidth = l.w - thumbSize

    -- Calculate normalized value
    local normalizedValue = (x - trackX) / trackWidth
    normalizedValue = math.max(0, math.min(1, normalizedValue))

    -- Convert to actual value
    local min = self.props.min
    local max = self.props.max
    local newValue = min + normalizedValue * (max - min)

    -- Apply step if defined
    local step = self.props.step
    if step and step > 0 then
        newValue = math.floor(newValue / step + 0.5) * step
    end

    -- Clamp to range
    newValue = math.max(min, math.min(max, newValue))

    self:SetValue(newValue)
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set value
---@param value number
---@return Slider self
function Slider:SetValue(value)
    local min = self.props.min
    local max = self.props.max
    value = math.max(min, math.min(max, value))

    if self.props.value ~= value then
        self.props.value = value
        if self.props.onChange then
            self.props.onChange(self, value)
        end
    end

    return self
end

--- Get value
---@return number
function Slider:GetValue()
    return self.props.value
end

--- Set range
---@param min number
---@param max number
---@return Slider self
function Slider:SetRange(min, max)
    self.props.min = min
    self.props.max = max
    -- Clamp current value to new range
    self.props.value = math.max(min, math.min(max, self.props.value))
    return self
end

--- Set disabled state
---@param disabled boolean
---@return Slider self
function Slider:SetDisabled(disabled)
    self.props.disabled = disabled
    if disabled then
        self:SetState({ hovered = false, dragging = false })
    end
    return self
end

-- ============================================================================
-- Stateful
-- ============================================================================

function Slider:IsStateful()
    return true
end

return Slider
