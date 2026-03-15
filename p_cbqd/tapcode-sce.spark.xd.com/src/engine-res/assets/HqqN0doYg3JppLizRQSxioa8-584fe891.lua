-- ============================================================================
-- Button Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Interactive button with hover/pressed states
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")
local Transition = require("urhox-libs/UI/Core/Transition")
local UI = require("urhox-libs/UI/Core/UI")

---@class ButtonProps : WidgetProps
---@field text string|nil Button text
---@field disabled boolean|nil Is button disabled
---@field variant string|nil "primary" | "secondary" | "danger" | "success"
---@field hoverBackgroundColor RGBAColor|nil Hover state background color
---@field pressedBackgroundColor RGBAColor|nil Pressed state background color
---@field disabledBackgroundColor RGBAColor|nil Disabled state background color
---@field hoverBackgroundImage string|nil Hover state background image
---@field pressedBackgroundImage string|nil Pressed state background image
---@field disabledBackgroundImage string|nil Disabled state background image
---@field textColor RGBAColor|nil Custom text color
---@field fontSize number|nil Font size

---@class Button : Widget
---@operator call(ButtonProps?): Button
---@field props ButtonProps
---@field new fun(self, props: ButtonProps?): Button
---@field state {hovered: boolean, pressed: boolean}
---@field AddChild fun(self, child: Widget): self Add child widget
---@field RemoveChild fun(self, child: Widget): self Remove child widget
local Button = Widget:Extend("Button")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props ButtonProps?
function Button:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("Button")
    props.height = props.height or themeStyle.height or 44
    props.borderRadius = props.borderRadius or themeStyle.borderRadius or 8
    -- fontSize stored in pt, converted to px at render time
    props.fontSize = props.fontSize or themeStyle.fontSize or Theme.BaseFontSize("bodyLarge")
    props.paddingHorizontal = props.paddingHorizontal or themeStyle.paddingHorizontal or 16

    -- Default variant
    props.variant = props.variant or "primary"

    -- Buttons should NOT shrink: truncated button text is unusable UX.
    -- Use UI.ButtonGroup (flexWrap="wrap") to handle overflow at the container level.
    props.flexShrink = props.flexShrink or 0

    -- Calculate width based on text using precise measurement
    if not props.width and props.text then
        local nvgFontSize = Theme.FontSize(props.fontSize)
        local textWidth = UI.MeasureTextWidth(props.text, nvgFontSize, props.fontFamily)
        props.width = math.max(64, textWidth + props.paddingHorizontal * 2)
    elseif not props.width then
        -- No text prop: Button may be used with children (Icon + Label).
        -- Use minWidth instead of fixed width so Yoga can size from children.
        if not props.minWidth then
            props.minWidth = 64
        end
    end

    -- Initialize state
    self.state = {
        hovered = false,
        pressed = false,
    }

    Widget.Init(self, props)

    -- Auto-generate hover/pressed colors from backgroundColor if not specified
    -- (after Widget.Init, because it normalizes color props to RGBA table format)
    if props.backgroundColor then
        if not props.hoverBackgroundColor then
            props.hoverBackgroundColor = Style.Lighten(props.backgroundColor, 0.15)
        end
        if not props.pressedBackgroundColor then
            props.pressedBackgroundColor = Style.Darken(props.backgroundColor, 0.2)
        end
    end

    -- Cache initial background color for transition "from" value
    self.lastStateBgColor_ = self:ResolveStateBgColor()
end

-- ============================================================================
-- State Color Resolution
-- ============================================================================

--- Resolve the target background color based on current state (hovered/pressed/disabled/normal).
--- Does NOT consider renderProps_ (transition interpolation) — returns the raw target.
---@return table|nil RGBA color table
function Button:ResolveStateBgColor()
    local props = self.props
    local state = self.state

    -- When button has backgroundImage but no explicit backgroundColor,
    -- don't fall back to variant theme color (would overlay image with solid color)
    local hasImage = props.backgroundImage ~= nil

    if props.disabled then
        local c = props.disabledBackgroundColor or props.backgroundColor
        if not c and not (props.disabledBackgroundImage or hasImage) then
            c = Theme.Color("disabled")
        end
        return c
    elseif state.pressed then
        local c = props.pressedBackgroundColor
        if not c and not (props.pressedBackgroundImage or hasImage) then
            local colorName = self:GetVariantColorName()
            c = Theme.Color(colorName .. "Pressed") or Style.Darken(Theme.Color(colorName), 0.2)
        end
        return c
    elseif state.hovered then
        local c = props.hoverBackgroundColor
        if not c and not (props.hoverBackgroundImage or hasImage) then
            local colorName = self:GetVariantColorName()
            c = Theme.Color(colorName .. "Hover") or Style.Lighten(Theme.Color(colorName), 0.1)
        end
        return c
    else
        local c = props.backgroundColor
        if not c and not hasImage then
            local colorName = self:GetVariantColorName()
            c = Theme.Color(colorName)
        end
        return c
    end
end

--- Start a background color transition to the current state's target color.
--- Only triggers when the widget has a transition config that includes backgroundColor.
--- Does NOT modify props — writes to transitions_/renderProps_ only.
function Button:TransitionToStateBgColor()
    local config = self.transitionConfig_
    if not config then return end
    if not Transition.ConfigIncludesProperty(config, "backgroundColor") then return end

    local targetColor = self:ResolveStateBgColor()
    if not targetColor then return end

    -- Use current rendered color as "from" (ongoing transition or last resolved)
    local currentColor = self.renderProps_.backgroundColor or self.lastStateBgColor_
    if not currentColor then
        currentColor = targetColor  -- First time: no transition needed
    end

    -- Store resolved target so next transition can use it as "from" after renderProps_ clears
    self.lastStateBgColor_ = targetColor

    -- Skip if same color (avoid unnecessary transition)
    if currentColor[1] == targetColor[1] and currentColor[2] == targetColor[2]
        and currentColor[3] == targetColor[3] and (currentColor[4] or 255) == (targetColor[4] or 255) then
        return
    end

    local wasEmpty = #self.transitions_ == 0
    local dur, eas = Transition.GetPropertyConfig(config, "backgroundColor")
    Transition.Start(self.transitions_, "backgroundColor", currentColor, targetColor, dur, eas)

    -- Notify UI.lua to track this widget for BaseUpdate
    if wasEmpty and #self.transitions_ > 0 then
        local onStart = Widget.GetTransitionStartCallback()
        if onStart then onStart(self) end
    end
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Button:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local disabled = props.disabled
    local variant = props.variant
    -- No scale needed - nvgScale in UI.Render handles it
    local borderRadius = props.borderRadius or Theme.BaseRadius("md")

    -- Determine background color: prefer transition interpolated value, then state-based
    local bgColor = self.renderProps_.backgroundColor
    local bgImage, textColor

    if not bgColor then
        -- No active transition: resolve from state as before
        bgColor = self:ResolveStateBgColor()
    end

    -- Resolve background image and text color based on state
    if disabled then
        bgImage = props.disabledBackgroundImage or props.backgroundImage
        textColor = props.textColor or Theme.Color("disabledText")
    elseif state.pressed then
        bgImage = props.pressedBackgroundImage or props.backgroundImage
        textColor = props.textColor or Theme.Color("text")
    elseif state.hovered then
        bgImage = props.hoverBackgroundImage or props.backgroundImage
        textColor = props.textColor or Theme.Color("text")
    else
        bgImage = props.backgroundImage
        textColor = props.textColor or Theme.Color("text")
    end

    -- Render background using Widget base class method
    self:RenderFullBackground(nvg, {
        backgroundColor = bgColor,
        backgroundImage = bgImage,
        backgroundFit = props.backgroundFit,
        backgroundSlice = props.backgroundSlice,
        borderRadius = borderRadius,
    })

    -- Draw text (clipped to button border-box bounds, not content area).
    -- CSS clips at border-box edge, text can visually extend into padding.
    local text = props.text or ""
    if text ~= "" then
        nvgSave(nvg)
        nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)
        nvgFontFace(nvg, Theme.FontFamily())
        nvgFontSize(nvg, Theme.FontSize(props.fontSize))  -- Convert pt to px
        nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
        nvgText(nvg, l.x + l.w / 2, l.y + l.h / 2, text, nil)
        nvgRestore(nvg)
    end
end

--- Get variant color name
---@return string
function Button:GetVariantColorName()
    local variant = self.props.variant
    if variant == "secondary" then
        return "secondary"
    elseif variant == "danger" then
        return "error"
    elseif variant == "success" then
        return "success"
    else
        return "primary"
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Button:OnMouseEnter()
    if not self.props.disabled then
        self:SetState({ hovered = true })
        self:TransitionToStateBgColor()
    end
end

function Button:OnMouseLeave()
    self:SetState({ hovered = false, pressed = false })
    self:TransitionToStateBgColor()
end

function Button:OnPointerDown(event)
    if not event then return end
    if not self.props.disabled and event:IsPrimaryAction() then
        self:SetState({ pressed = true })
        self:TransitionToStateBgColor()
    end
end

function Button:OnPointerUp(event)
    if not event then return end
    if event:IsPrimaryAction() then
        self:SetState({ pressed = false })
        self:TransitionToStateBgColor()
    end
end

function Button:OnClick()
    if not self.props.disabled then
        if self.props.onClick then
            self.props.onClick(self)
        end
    end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set button text
---@param text string
---@return Button self
function Button:SetText(text)
    if self.props.text == text then
        return self
    end
    self.props.text = text
    -- Update width using precise measurement
    local nvgFontSize = Theme.FontSize(self.props.fontSize)
    local textWidth = UI.MeasureTextWidth(text, nvgFontSize, self.props.fontFamily)
    local padding = self.props.paddingHorizontal or 16
    local width = math.max(64, textWidth + padding * 2)
    self:SetWidth(width)
    return self
end

--- Set disabled state
---@param disabled boolean
---@return Button self
function Button:SetDisabled(disabled)
    self.props.disabled = disabled
    if disabled then
        self:SetState({ hovered = false, pressed = false })
    end
    return self
end

--- Check if button is disabled
---@return boolean
function Button:IsDisabled()
    return self.props.disabled == true
end

-- ============================================================================
-- Stateful
-- ============================================================================

function Button:IsStateful()
    return true
end

return Button
