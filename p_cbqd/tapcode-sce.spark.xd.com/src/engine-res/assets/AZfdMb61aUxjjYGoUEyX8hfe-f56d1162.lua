-- ============================================================================
-- Chip Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Compact element for tags, filters, selections, and actions
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")
local UI = require("urhox-libs/UI/Core/UI")

---@class ChipProps : WidgetProps
---@field label string|nil Chip text
---@field variant string|nil "filled" | "outlined" | "soft"
---@field color string|nil "default" | "primary" | "secondary" | "success" | "warning" | "error"
---@field size string|nil "sm" | "md" | "lg" (default: "md")
---@field icon string|nil Leading icon
---@field avatar table|nil Avatar props { name, src, initials }
---@field deletable boolean|nil Show delete button
---@field removable boolean|nil Alias for deletable
---@field selectable boolean|nil Enable selection
---@field selected boolean|nil Is selected
---@field disabled boolean|nil Is disabled
---@field onDelete fun(self: Chip)|nil Delete callback
---@field onRemove fun(self: Chip)|nil Alias for onDelete
---@field onSelect fun(self: Chip, selected: boolean)|nil Selection callback

---@class Chip : Widget
---@operator call(ChipProps?): Chip
---@field props ChipProps
---@field new fun(self, props: ChipProps?): Chip
local Chip = Widget:Extend("Chip")

-- Size presets
local SIZE_PRESETS = {
    sm = { height = 24, fontSize = 11, padding = 8, iconSize = 14, avatarSize = 18 },
    md = { height = 32, fontSize = 13, padding = 12, iconSize = 16, avatarSize = 24 },
    lg = { height = 40, fontSize = 14, padding = 16, iconSize = 20, avatarSize = 32 },
}

-- Color presets
local COLOR_PRESETS = {
    default = "textSecondary",
    primary = "primary",
    secondary = "secondary",
    success = "success",
    warning = "warning",
    error = "error",
}

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props ChipProps?
function Chip:Init(props)
    props = props or {}

    -- Aliases (handle common AI hallucinations)
    if props.removable ~= nil then props.deletable = props.removable end
    if props.onRemove ~= nil then props.onDelete = props.onRemove end

    -- Default settings
    props.label = props.label or ""
    props.variant = props.variant or "filled"
    props.color = props.color or "default"
    props.size = props.size or "md"
    props.deletable = props.deletable or false
    props.selectable = props.selectable or false
    props.selected = props.selected or false
    props.disabled = props.disabled or false

    -- Set default size based on size preset
    local sizePreset = SIZE_PRESETS[props.size] or SIZE_PRESETS.md
    props.height = props.height or sizePreset.height

    -- Calculate width based on label using precise measurement
    if not props.width and props.label then
        local nvgFontSize = Theme.FontSize(sizePreset.fontSize)
        local textWidth = UI.MeasureTextWidth(props.label, nvgFontSize, Theme.FontFamily())
        local deleteWidth = props.deletable and (sizePreset.iconSize + 4) or 0
        local iconWidth = props.icon and (sizePreset.iconSize + 4) or 0
        local avatarWidth = props.avatar and (sizePreset.avatarSize + 4) or 0
        props.width = textWidth + deleteWidth + iconWidth + avatarWidth + sizePreset.padding * 2
    end

    -- State
    self.state = {
        hovered = false,
        pressed = false,
        deleteHovered = false,
    }

    Widget.Init(self, props)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Chip:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local sizePreset = SIZE_PRESETS[props.size] or SIZE_PRESETS.md
    local chipHeight = sizePreset.height
    local fontSize = Theme.FontSize(sizePreset.fontSize)
    local padding = sizePreset.padding
    local iconSize = sizePreset.iconSize
    local avatarSize = sizePreset.avatarSize

    local fontFamily = Theme.FontFamily()

    -- Calculate chip width
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, fontSize)
    local textWidth = nvgTextBounds(nvg, 0, 0, props.label, nil, nil)

    local contentWidth = textWidth
    local leftPadding = padding
    local rightPadding = padding

    -- Avatar space
    if props.avatar then
        contentWidth = contentWidth + avatarSize + 6
        leftPadding = 4
    end

    -- Icon space
    if props.icon and not props.avatar then
        contentWidth = contentWidth + iconSize + 4
        leftPadding = padding - 4
    end

    -- Delete button space
    if props.deletable then
        contentWidth = contentWidth + iconSize + 4
        rightPadding = 4
    end

    local chipWidth = props.width or (contentWidth + leftPadding + rightPadding)

    -- Position
    local x = l.x
    local y = l.y + (l.h - chipHeight) / 2
    local borderRadius = chipHeight / 2

    -- Get colors
    local bgColor, textColor, borderColor = self:GetColors()

    -- Draw background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, chipWidth, chipHeight, borderRadius)

    if props.variant == "outlined" then
        nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 255))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    else
        nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
        nvgFill(nvg)
    end

    -- Hover/press overlay
    if not props.disabled then
        if state.pressed then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x, y, chipWidth, chipHeight, borderRadius)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
            nvgFill(nvg)
        elseif state.hovered and not state.deleteHovered then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x, y, chipWidth, chipHeight, borderRadius)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 15))
            nvgFill(nvg)
        end
    end

    -- Selection indicator
    if props.selectable and props.selected then
        -- Checkmark or highlight
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, chipWidth, chipHeight, borderRadius)
        nvgStrokeColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], 200))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)
    end

    -- Content X position
    local contentX = x + leftPadding
    local centerY = y + chipHeight / 2

    -- Draw avatar
    if props.avatar then
        self:RenderAvatar(nvg, contentX, centerY - avatarSize / 2, avatarSize)
        contentX = contentX + avatarSize + 6
    end

    -- Draw icon
    if props.icon and not props.avatar then
        self:RenderIcon(nvg, props.icon, contentX, centerY, iconSize, textColor)
        contentX = contentX + iconSize + 4
    end

    -- Draw label
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, fontSize)
    nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(nvg, contentX, centerY, props.label, nil)

    -- Draw delete button
    if props.deletable then
        local deleteX = x + chipWidth - rightPadding - iconSize
        self:RenderDeleteButton(nvg, deleteX, centerY, iconSize, textColor)
    end
end

--- Get colors based on variant and color
function Chip:GetColors()
    local props = self.props
    local state = self.state
    local colorKey = COLOR_PRESETS[props.color] or "textSecondary"
    local baseColor = Theme.Color(colorKey)

    local bgColor, textColor, borderColor

    if props.disabled then
        local disabledBg = Theme.Color("surface")
        local disabledText = Theme.Color("textDisabled")
        return disabledBg, disabledText, disabledBg
    end

    if props.variant == "filled" then
        if props.color == "default" then
            bgColor = Theme.Color("surface")
            textColor = Theme.Color("text")
        else
            bgColor = baseColor
            textColor = { 255, 255, 255, 255 }
        end
        borderColor = bgColor
    elseif props.variant == "outlined" then
        bgColor = { 0, 0, 0, 0 }
        textColor = props.color == "default" and Theme.Color("text") or baseColor
        borderColor = props.color == "default" and Theme.Color("border") or baseColor
    else -- soft
        if props.color == "default" then
            bgColor = Theme.Color("surface")
            textColor = Theme.Color("text")
        else
            bgColor = { baseColor[1], baseColor[2], baseColor[3], 30 }
            textColor = baseColor
        end
        borderColor = bgColor
    end

    return bgColor, textColor, borderColor
end

--- Render avatar
function Chip:RenderAvatar(nvg, x, y, size)
    local avatar = self.props.avatar
    local fontFamily = Theme.FontFamily()

    -- Get initials
    local initials = avatar.initials
    if not initials and avatar.name then
        local parts = {}
        for part in string.gmatch(avatar.name, "%S+") do
            table.insert(parts, part)
        end
        if #parts >= 2 then
            initials = string.upper(string.sub(parts[1], 1, 1) .. string.sub(parts[#parts], 1, 1))
        else
            initials = string.upper(string.sub(avatar.name, 1, math.min(2, #avatar.name)))
        end
    end
    initials = initials or "?"

    -- Calculate color from name
    local bgColor = { 99, 102, 241, 255 }
    if avatar.name then
        local hash = 0
        for i = 1, #avatar.name do
            hash = hash + string.byte(avatar.name, i)
        end
        local colors = {
            { 239, 68, 68 }, { 249, 115, 22 }, { 34, 197, 94 },
            { 59, 130, 246 }, { 99, 102, 241 }, { 168, 85, 247 },
        }
        bgColor = colors[(hash % #colors) + 1]
    end

    -- Draw circle
    nvgBeginPath(nvg)
    nvgCircle(nvg, x + size / 2, y + size / 2, size / 2)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], 255))
    nvgFill(nvg)

    -- Draw initials
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, size * 0.45)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgText(nvg, x + size / 2, y + size / 2, initials, nil)
end

--- Render icon
function Chip:RenderIcon(nvg, icon, x, y, size, color)
    local fontFamily = Theme.FontFamily()

    -- Render icon (supports emoji and multi-byte UTF-8 characters)
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, size)
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    -- Use utf8.offset to correctly extract first UTF-8 character
    local firstChar = icon
    if utf8 and utf8.offset then
        local endPos = utf8.offset(icon, 2)
        if endPos then
            firstChar = string.sub(icon, 1, endPos - 1)
        end
    end
    nvgText(nvg, x + size / 2, y, firstChar, nil)
end

--- Render delete button
function Chip:RenderDeleteButton(nvg, x, y, size, color)
    local state = self.state
    local radius = size / 2

    -- Hover background
    if state.deleteHovered then
        nvgBeginPath(nvg)
        nvgCircle(nvg, x + radius, y, radius + 2)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
        nvgFill(nvg)
    end

    -- X icon
    local iconSize = size * 0.4
    local cx = x + radius
    local cy = y

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - iconSize, cy - iconSize)
    nvgLineTo(nvg, cx + iconSize, cy + iconSize)
    nvgMoveTo(nvg, cx + iconSize, cy - iconSize)
    nvgLineTo(nvg, cx - iconSize, cy + iconSize)
    nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
end

-- ============================================================================
-- Hit Testing
-- ============================================================================

--- Check if point is on delete button
function Chip:IsOnDeleteButton(screenX, screenY)
    if not self.props.deletable then
        return false
    end

    local l = self:GetAbsoluteLayout()

    -- Convert screen coords to render coords
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    local x = screenX + (l.x - hitTest.x)
    local y = screenY + (l.y - hitTest.y)

    local sizePreset = SIZE_PRESETS[self.props.size] or SIZE_PRESETS.md
    local chipHeight = sizePreset.height
    local iconSize = sizePreset.iconSize
    local rightPadding = 4

    local chipY = l.y + (l.h - chipHeight) / 2
    local deleteX = l.x + l.w - rightPadding - iconSize
    local deleteY = chipY + chipHeight / 2

    local dx = x - (deleteX + iconSize / 2)
    local dy = y - deleteY
    local distance = math.sqrt(dx * dx + dy * dy)

    return distance <= iconSize
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Chip:OnMouseEnter()
    if not self.props.disabled then
        self:SetState({ hovered = true })
    end
end

function Chip:OnMouseLeave()
    self:SetState({ hovered = false, pressed = false, deleteHovered = false })
end

function Chip:OnPointerMove(event)
    if not event then return end

    if self.props.deletable and not self.props.disabled then
        local onDelete = self:IsOnDeleteButton(event.x, event.y)
        if onDelete ~= self.state.deleteHovered then
            self:SetState({ deleteHovered = onDelete })
        end
    end
end

function Chip:OnPointerDown(event)
    if not event then return end

    if not self.props.disabled then
        self:SetState({ pressed = true })
    end
end

function Chip:OnPointerUp(event)
    self:SetState({ pressed = false })
end

function Chip:OnClick(event)
    if not event then return end
    if self.props.disabled then
        return
    end

    -- Check delete button
    if self.props.deletable and self:IsOnDeleteButton(event.x, event.y) then
        if self.props.onDelete then
            self.props.onDelete(self)
        end
        return
    end

    -- Handle selection
    if self.props.selectable then
        self.props.selected = not self.props.selected
        if self.props.onSelect then
            self.props.onSelect(self, self.props.selected)
        end
    end

    -- Fire click callback
    if self.props.onClick then
        self.props.onClick(self)
    end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set label
---@param label string
---@return Chip self
function Chip:SetLabel(label)
    self.props.label = label
    return self
end

--- Get label
---@return string
function Chip:GetLabel()
    return self.props.label
end

--- Set variant
---@param variant string "filled" | "outlined" | "soft"
---@return Chip self
function Chip:SetVariant(variant)
    self.props.variant = variant
    return self
end

--- Set color
---@param color string
---@return Chip self
function Chip:SetColor(color)
    self.props.color = color
    return self
end

--- Set size
---@param size string "sm" | "md" | "lg"
---@return Chip self
function Chip:SetSize(size)
    self.props.size = size
    return self
end

--- Set selected
---@param selected boolean
---@return Chip self
function Chip:SetSelected(selected)
    self.props.selected = selected
    return self
end

--- Is selected
---@return boolean
function Chip:IsSelected()
    return self.props.selected == true
end

--- Set disabled
---@param disabled boolean
---@return Chip self
function Chip:SetDisabled(disabled)
    self.props.disabled = disabled
    return self
end

--- Set deletable
---@param deletable boolean
---@return Chip self
function Chip:SetDeletable(deletable)
    self.props.deletable = deletable
    return self
end

--- Set icon
---@param icon string|nil
---@return Chip self
function Chip:SetIcon(icon)
    self.props.icon = icon
    return self
end

--- Set avatar
---@param avatar table|nil
---@return Chip self
function Chip:SetAvatar(avatar)
    self.props.avatar = avatar
    return self
end

-- ============================================================================
-- Stateful
-- ============================================================================

function Chip:IsStateful()
    return true
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a filter chip (selectable)
---@param label string
---@param options table|nil
---@return Chip
function Chip.Filter(label, options)
    options = options or {}
    options.label = label
    options.selectable = true
    options.variant = options.variant or "outlined"
    return Chip:new(options)
end

--- Create an input chip (deletable)
---@param label string
---@param options table|nil
---@return Chip
function Chip.Input(label, options)
    options = options or {}
    options.label = label
    options.deletable = true
    options.variant = options.variant or "filled"
    return Chip:new(options)
end

--- Create an action chip (clickable)
---@param label string
---@param onClick function
---@param options table|nil
---@return Chip
function Chip.Action(label, onClick, options)
    options = options or {}
    options.label = label
    options.onClick = onClick
    options.variant = options.variant or "outlined"
    return Chip:new(options)
end

--- Create a chip group
---@param chips Chip[] Array of chips
---@param options table|nil { singleSelect, onChange }
---@return Widget
function Chip.Group(chips, options)
    local Panel = require("urhox-libs/UI/Widgets/Panel")

    options = options or {}
    local singleSelect = options.singleSelect or false

    local group = Panel:new({
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
        alignItems = "center",
    })

    for _, chip in ipairs(chips) do
        if singleSelect then
            local originalOnSelect = chip.props.onSelect
            chip.props.onSelect = function(c, selected)
                if selected then
                    -- Deselect all others
                    for _, other in ipairs(chips) do
                        if other ~= c and other.props.selected then
                            other.props.selected = false
                        end
                    end
                end
                if originalOnSelect then
                    originalOnSelect(c, selected)
                end
                if options.onChange then
                    local selectedChips = {}
                    for _, ch in ipairs(chips) do
                        if ch.props.selected then
                            table.insert(selectedChips, ch)
                        end
                    end
                    options.onChange(selectedChips)
                end
            end
        end
        group:AddChild(chip)
    end

    return group
end

return Chip
