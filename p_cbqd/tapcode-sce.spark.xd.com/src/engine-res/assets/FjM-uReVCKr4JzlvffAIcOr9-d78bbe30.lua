-- ============================================================================
-- Toggle Widget (Switch)
-- UrhoX UI Library - Yoga + NanoVG
-- iOS-style toggle switch
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class ToggleProps : WidgetProps
---@field value boolean|nil Is toggle on
---@field disabled boolean|nil Is toggle disabled
---@field label string|nil Label text
---@field trackWidth number|nil Track width (default: 48)
---@field trackHeight number|nil Track height (default: 26)
---@field thumbSize number|nil Thumb size (default: 22)
---@field onChange fun(self: Toggle, value: boolean)|nil Change callback

---@class Toggle : Widget
---@operator call(ToggleProps?): Toggle
---@field props ToggleProps
---@field new fun(self, props: ToggleProps?): Toggle
---@field state {hovered: boolean, pressed: boolean}
local Toggle = Widget:Extend("Toggle")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props ToggleProps?
function Toggle:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("Toggle")
    props.trackWidth = props.trackWidth or themeStyle.width or 48
    props.trackHeight = props.trackHeight or themeStyle.height or 26
    props.thumbSize = props.thumbSize or themeStyle.thumbSize or 22

    -- Layout for label
    props.flexDirection = "row"
    props.alignItems = "center"
    props.gap = props.gap or 8

    -- Set widget size
    props.height = props.height or props.trackHeight

    -- Default width: track + gap + label estimate
    if not props.width then
        local labelWidth = 0
        if props.label and #props.label > 0 then
            labelWidth = #props.label * 14 * 0.55 + (props.gap or 8)
        end
        props.width = props.trackWidth + labelWidth
    end

    -- Initialize state
    self.state = {
        hovered = false,
        pressed = false,
    }

    Widget.Init(self, props)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Toggle:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local value = props.value
    local disabled = props.disabled
    local trackWidth = props.trackWidth
    local trackHeight = props.trackHeight
    local thumbSize = props.thumbSize
    local label = props.label

    -- Track position (vertically centered)
    local trackX = l.x
    local trackY = l.y + (l.h - trackHeight) / 2
    local trackRadius = trackHeight / 2

    -- Thumb position
    local thumbPadding = (trackHeight - thumbSize) / 2
    local thumbX = value
        and (trackX + trackWidth - thumbSize - thumbPadding)
        or (trackX + thumbPadding)
    local thumbY = trackY + thumbPadding

    -- Colors
    local trackColor, thumbColor

    if disabled then
        trackColor = Theme.Color("disabled")
        thumbColor = Theme.Color("disabledText")
    else
        if value then
            if state.pressed then
                trackColor = Theme.Color("primaryPressed") or Style.Darken(Theme.Color("primary"), 0.2)
            elseif state.hovered then
                trackColor = Theme.Color("primaryHover") or Style.Lighten(Theme.Color("primary"), 0.1)
            else
                trackColor = Theme.Color("primary")
            end
        else
            if state.hovered then
                trackColor = Theme.Color("surfaceHover") or Style.Lighten(Theme.Color("surface"), 0.1)
            else
                trackColor = Theme.Color("surface")
            end
        end
        thumbColor = { 255, 255, 255, 255 }
    end

    -- Draw track
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, trackX, trackY, trackWidth, trackHeight, trackRadius)
    nvgFillColor(nvg, nvgRGBA(trackColor[1], trackColor[2], trackColor[3], trackColor[4] or 255))
    nvgFill(nvg)

    -- Draw track border when off
    if not value and not disabled then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, trackX, trackY, trackWidth, trackHeight, trackRadius)
        nvgStrokeColor(nvg, nvgRGBA(Theme.Color("border")[1], Theme.Color("border")[2], Theme.Color("border")[3], 255))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    -- Draw thumb shadow
    if not disabled then
        nvgBeginPath(nvg)
        nvgCircle(nvg, thumbX + thumbSize / 2, thumbY + thumbSize / 2 + 1, thumbSize / 2)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
        nvgFill(nvg)
    end

    -- Draw thumb
    nvgBeginPath(nvg)
    nvgCircle(nvg, thumbX + thumbSize / 2, thumbY + thumbSize / 2, thumbSize / 2)
    nvgFillColor(nvg, nvgRGBA(thumbColor[1], thumbColor[2], thumbColor[3], thumbColor[4] or 255))
    nvgFill(nvg)

    -- Draw label
    if label and #label > 0 then
        local fontFamily = Theme.FontFamily()
        local textColor = disabled and Theme.Color("disabledText") or Theme.Color("text")
        local gap = props.gap or 8

        nvgFontFace(nvg, fontFamily)
        nvgFontSize(nvg, Theme.FontSizeOf("body"))
        nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(nvg, trackX + trackWidth + gap, l.y + l.h / 2, label, nil)
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Toggle:OnMouseEnter()
    if not self.props.disabled then
        self:SetState({ hovered = true })
    end
end

function Toggle:OnMouseLeave()
    self:SetState({ hovered = false, pressed = false })
end

function Toggle:OnPointerDown(event)
    if not event then return end
    if not self.props.disabled and event:IsPrimaryButton() then
        self:SetState({ pressed = true })
    end
end

function Toggle:OnPointerUp(event)
    if not event then return end
    if event:IsPrimaryButton() then
        self:SetState({ pressed = false })
    end
end

function Toggle:OnClick()
    if not self.props.disabled then
        self:Toggle()
    end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Toggle the value
---@return Toggle self
function Toggle:Toggle()
    local newValue = not self.props.value
    self.props.value = newValue

    if self.props.onChange then
        self.props.onChange(self, newValue)
    end

    return self
end

--- Set value
---@param value boolean
---@return Toggle self
function Toggle:SetValue(value)
    if self.props.value ~= value then
        self.props.value = value
        if self.props.onChange then
            self.props.onChange(self, value)
        end
    end
    return self
end

--- Get value
---@return boolean
function Toggle:GetValue()
    return self.props.value == true
end

--- Set label text
---@param label string
---@return Toggle self
function Toggle:SetLabel(label)
    self.props.label = label
    return self
end

--- Set disabled state
---@param disabled boolean
---@return Toggle self
function Toggle:SetDisabled(disabled)
    self.props.disabled = disabled
    if disabled then
        self:SetState({ hovered = false, pressed = false })
    end
    return self
end

-- ============================================================================
-- Stateful
-- ============================================================================

function Toggle:IsStateful()
    return true
end

return Toggle
