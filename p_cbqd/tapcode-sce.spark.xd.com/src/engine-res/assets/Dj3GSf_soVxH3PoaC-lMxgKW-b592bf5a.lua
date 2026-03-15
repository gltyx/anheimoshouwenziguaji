-- ============================================================================
-- ColorPicker Widget
-- Color selection with HSV picker and presets
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local UI = require("urhox-libs/UI/Core/UI")

---@class ColorPickerProps : WidgetProps
---@field size string|nil "sm" | "md" | "lg" (default: "md")
---@field variant string|nil "outlined" | "filled" (default: "outlined")
---@field disabled boolean|nil Disable the picker
---@field showAlpha boolean|nil Show alpha channel slider
---@field showInput boolean|nil Show hex input (default: true)
---@field showPresets boolean|nil Show preset colors (default: true)
---@field presets string[]|nil Custom preset colors array
---@field value table|nil Initial value {r, g, b, a} or {h, s, v, a}
---@field color string|nil Initial hex color
---@field fontSize number|nil Custom font size
---@field pickerSize number|nil Color picker popup size
---@field swatchSize number|nil Preset swatch size
---@field onChange fun(picker: ColorPicker, value: table)|nil Value change callback
---@field onOpen fun(picker: ColorPicker)|nil Open callback
---@field onClose fun(picker: ColorPicker)|nil Close callback

---@class ColorPicker : Widget
---@operator call(ColorPickerProps?): ColorPicker
---@field props ColorPickerProps
---@field new fun(self, props: ColorPickerProps?): ColorPicker
local ColorPicker = Widget:Extend("ColorPicker")

-- ============================================================================
-- Size presets
-- ============================================================================

local SIZE_PRESETS = {
    sm = { height = 36, fontSize = 12, padding = 8, swatchSize = 20, pickerSize = 180 },
    md = { height = 44, fontSize = 14, padding = 12, swatchSize = 28, pickerSize = 220 },
    lg = { height = 52, fontSize = 16, padding = 16, swatchSize = 36, pickerSize = 260 },
}

-- ============================================================================
-- Color utilities
-- ============================================================================

local function hsvToRgb(h, s, v)
    local r, g, b

    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    local mod = i % 6
    if mod == 0 then r, g, b = v, t, p
    elseif mod == 1 then r, g, b = q, v, p
    elseif mod == 2 then r, g, b = p, v, t
    elseif mod == 3 then r, g, b = p, q, v
    elseif mod == 4 then r, g, b = t, p, v
    elseif mod == 5 then r, g, b = v, p, q
    end

    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

local function rgbToHsv(r, g, b)
    r, g, b = r / 255, g / 255, b / 255

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local h, s, v
    v = max

    local d = max - min
    s = max == 0 and 0 or d / max

    if max == min then
        h = 0
    else
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        elseif max == b then
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return h, s, v
end

local function rgbToHex(r, g, b, a)
    if a and a < 255 then
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    end
    return string.format("#%02X%02X%02X", r, g, b)
end

local function hexToRgb(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then
        return tonumber(hex:sub(1,2), 16),
               tonumber(hex:sub(3,4), 16),
               tonumber(hex:sub(5,6), 16),
               255
    elseif #hex == 8 then
        return tonumber(hex:sub(1,2), 16),
               tonumber(hex:sub(3,4), 16),
               tonumber(hex:sub(5,6), 16),
               tonumber(hex:sub(7,8), 16)
    end
    return 0, 0, 0, 255
end

-- Default preset colors
local DEFAULT_PRESETS = {
    -- Row 1: Reds/Pinks
    "#F44336", "#E91E63", "#9C27B0", "#673AB7",
    -- Row 2: Blues/Cyans
    "#3F51B5", "#2196F3", "#03A9F4", "#00BCD4",
    -- Row 3: Greens/Limes
    "#009688", "#4CAF50", "#8BC34A", "#CDDC39",
    -- Row 4: Yellows/Oranges
    "#FFEB3B", "#FFC107", "#FF9800", "#FF5722",
    -- Row 5: Grays
    "#795548", "#9E9E9E", "#607D8B", "#000000",
}

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props ColorPickerProps?
function ColorPicker:Init(props)
    props = props or {}

    -- ColorPicker props
    self.size_ = props.size or "md"
    self.variant_ = props.variant or "outlined"  -- outlined, filled
    self.disabled_ = props.disabled or false
    self.showAlpha_ = props.showAlpha or false
    self.showInput_ = props.showInput ~= false  -- default true
    self.showPresets_ = props.showPresets ~= false  -- default true
    self.presets_ = props.presets or DEFAULT_PRESETS

    -- Initial color (HSV internally)
    self.hue_ = 0
    self.saturation_ = 1
    self.value_ = 1
    self.alpha_ = 255

    if props.value then
        self:SetValue(props.value)
    elseif props.color then
        self:SetHex(props.color)
    end

    -- UI state
    self.isOpen_ = false
    self.dragging_ = nil  -- "sv", "hue", "alpha"
    self.hoverPreset_ = nil

    -- Callbacks
    self.onChange_ = props.onChange
    self.onOpen_ = props.onOpen
    self.onClose_ = props.onClose

    -- Calculate dimensions
    local sizePreset = SIZE_PRESETS[self.size_] or SIZE_PRESETS.md
    self.fontSize_ = props.fontSize or Theme.FontSize(sizePreset.fontSize)
    self.padding_ = props.padding or sizePreset.padding
    self.pickerSize_ = props.pickerSize or sizePreset.pickerSize
    self.swatchSize_ = props.swatchSize or sizePreset.swatchSize
    self.inputHeight_ = props.height or sizePreset.height

    -- Popup dimensions
    self.sliderHeight_ = 16
    self.sliderGap_ = 12
    self.presetSize_ = 24
    self.presetGap_ = 4

    props.width = props.width or 160
    props.height = self.inputHeight_

    Widget.Init(self, props)
end

-- ============================================================================
-- Color Management
-- ============================================================================

function ColorPicker:GetValue()
    local r, g, b = hsvToRgb(self.hue_, self.saturation_, self.value_)
    return {
        r = r, g = g, b = b, a = self.alpha_,
        h = self.hue_, s = self.saturation_, v = self.value_,
        hex = rgbToHex(r, g, b, self.showAlpha_ and self.alpha_ or nil),
    }
end

function ColorPicker:SetValue(value)
    if value.h ~= nil then
        self.hue_ = value.h
        self.saturation_ = value.s
        self.value_ = value.v
        self.alpha_ = value.a or 255
    elseif value.r ~= nil then
        self.hue_, self.saturation_, self.value_ = rgbToHsv(value.r, value.g, value.b)
        self.alpha_ = value.a or 255
    end
end

function ColorPicker:GetRGB()
    local r, g, b = hsvToRgb(self.hue_, self.saturation_, self.value_)
    return r, g, b, self.alpha_
end

function ColorPicker:SetRGB(r, g, b, a)
    self.hue_, self.saturation_, self.value_ = rgbToHsv(r, g, b)
    self.alpha_ = a or 255
    self:NotifyChange()
end

function ColorPicker:GetHex()
    local r, g, b = hsvToRgb(self.hue_, self.saturation_, self.value_)
    return rgbToHex(r, g, b, self.showAlpha_ and self.alpha_ or nil)
end

function ColorPicker:SetHex(hex)
    local r, g, b, a = hexToRgb(hex)
    self.hue_, self.saturation_, self.value_ = rgbToHsv(r, g, b)
    self.alpha_ = a
end

function ColorPicker:GetNvgColor()
    local r, g, b = hsvToRgb(self.hue_, self.saturation_, self.value_)
    return nvgRGBA(r, g, b, self.alpha_)
end

function ColorPicker:NotifyChange()
    if self.onChange_ then
        self.onChange_(self, self:GetValue())
    end
end

-- ============================================================================
-- Popup Control
-- ============================================================================

function ColorPicker:Open()
    if self.disabled_ then return end
    self.isOpen_ = true
    UI.PushOverlay(self)
    if self.onOpen_ then self.onOpen_(self) end
end

function ColorPicker:Close()
    self.isOpen_ = false
    self.dragging_ = nil
    UI.PopOverlay(self)
    if self.onClose_ then self.onClose_(self) end
end

function ColorPicker:Toggle()
    if self.isOpen_ then
        self:Close()
    else
        self:Open()
    end
end

-- ============================================================================
-- Render
-- ============================================================================

function ColorPicker:Render(nvg)
    local x, y = self:GetAbsolutePosition()
    local w, h = self:GetComputedSize()
    local theme = Theme.GetTheme()

    -- Store positions for hit testing (use HitTest coords for consistency with overlay)
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    self.inputBounds_ = { x = hitTest.x, y = hitTest.y, w = hitTest.w, h = hitTest.h }

    -- Determine colors
    local borderColor = self.isOpen_ and Theme.NvgColor("primary") or Theme.NvgColor("border")
    local bgColor = Theme.NvgColor("surface")

    if self.disabled_ then
        borderColor = Theme.NvgColor("borderDisabled")
        bgColor = Theme.NvgColor("surfaceDisabled")
    end

    -- Draw input field background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, Theme.Radius("sm"))

    if self.variant_ == "filled" then
        nvgFillColor(nvg, Theme.NvgColor("surfaceVariant"))
    else
        nvgFillColor(nvg, bgColor)
    end
    nvgFill(nvg)

    if self.variant_ == "outlined" then
        nvgStrokeColor(nvg, borderColor)
        nvgStrokeWidth(nvg, self.isOpen_ and 2 or 1)
        nvgStroke(nvg)
    end

    -- Draw color swatch
    local swatchX = x + self.padding_
    local swatchY = y + (h - self.swatchSize_) / 2
    local swatchW = self.swatchSize_
    local swatchH = self.swatchSize_

    -- Checkerboard pattern for alpha
    if self.showAlpha_ and self.alpha_ < 255 then
        local checkSize = 4
        for cy = 0, swatchH - 1, checkSize do
            for cx = 0, swatchW - 1, checkSize do
                local isLight = ((cx / checkSize) + (cy / checkSize)) % 2 == 0
                nvgBeginPath(nvg)
                nvgRect(nvg, swatchX + cx, swatchY + cy, checkSize, checkSize)
                nvgFillColor(nvg, isLight and nvgRGBA(255, 255, 255, 255) or nvgRGBA(200, 200, 200, 255))
                nvgFill(nvg)
            end
        end
    end

    -- Color fill
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, swatchX, swatchY, swatchW, swatchH, 4)
    nvgFillColor(nvg, self:GetNvgColor())
    nvgFill(nvg)
    nvgStrokeColor(nvg, Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- Draw hex text
    local hexText = self:GetHex()
    local textX = swatchX + swatchW + 8
    nvgFontSize(nvg, self.fontSize_)
    nvgFontFace(nvg, Theme.FontFamily())
    nvgFillColor(nvg, self.disabled_ and Theme.NvgColor("textDisabled") or Theme.NvgColor("text"))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(nvg, textX, y + h / 2, hexText)

    -- Draw dropdown arrow
    local arrowX = x + w - self.padding_
    local arrowY = y + h / 2  -- Arrow uses simple center
    nvgBeginPath(nvg)
    if self.isOpen_ then
        nvgMoveTo(nvg, arrowX - 4, arrowY + 2)
        nvgLineTo(nvg, arrowX, arrowY - 2)
        nvgLineTo(nvg, arrowX + 4, arrowY + 2)
    else
        nvgMoveTo(nvg, arrowX - 4, arrowY - 2)
        nvgLineTo(nvg, arrowX, arrowY + 2)
        nvgLineTo(nvg, arrowX + 4, arrowY - 2)
    end
    nvgStrokeColor(nvg, Theme.NvgColor("textSecondary"))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- Queue popup to render as overlay (on top of everything)
    if self.isOpen_ then
        UI.QueueOverlay(function(nvg_)
            self:RenderPopup(nvg_)
        end)
    end
end

function ColorPicker:RenderPopup(nvg)
    -- Use GetAbsoluteLayoutForHitTest because overlay renders outside ScrollView's nvgTranslate
    local l = self:GetAbsoluteLayoutForHitTest()
    local px = l.x
    local py = l.y + l.h + 4  -- Position below input field

    local theme = Theme.GetTheme()

    -- Dimensions (no scale needed - nvgScale handles it)
    local pickerSize = self.pickerSize_
    local sliderHeight = self.sliderHeight_
    local sliderGap = self.sliderGap_
    local presetSize = self.presetSize_
    local presetGap = self.presetGap_
    local contentPadding = 16
    local borderRadius = 8

    -- Calculate popup size (must match contentY layout exactly)
    local popW = pickerSize + contentPadding * 2
    -- Start with top padding (contentY starts at py + contentPadding)
    local popH = contentPadding
    -- SV picker + gap (contentY += pickerSize + sliderGap)
    popH = popH + pickerSize + sliderGap
    -- Hue slider + gap (contentY += sliderHeight + sliderGap, always adds gap)
    popH = popH + sliderHeight + sliderGap

    if self.showAlpha_ then
        -- Alpha slider + gap (contentY += sliderHeight + sliderGap)
        popH = popH + sliderHeight + sliderGap
    end

    if self.showPresets_ then
        local presetsPerRow = math.floor((popW - contentPadding) / (presetSize + presetGap))
        local presetRows = math.ceil(#self.presets_ / presetsPerRow)
        -- contentY += presetRows * (presetSize + presetGap) + 8
        popH = popH + presetRows * (presetSize + presetGap) + 8
    end

    if self.showInput_ then
        -- Get actual font height using nvgTextMetrics
        nvgFontSize(nvg, self.fontSize_)
        nvgFontFace(nvg, Theme.FontFamily())
        local ascender, descender, lineh = nvgTextMetrics(nvg)
        -- HexInput needs: lineh for text + padding
        local hexInputHeight = lineh + self.padding_
        popH = popH + hexInputHeight
        -- Store for RenderHexInput to use
        self.hexInputHeight_ = hexInputHeight
    end

    -- Bottom padding
    popH = popH + 8

    self.popupBounds_ = { x = px, y = py, w = popW, h = popH }

    -- Shadow
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px + 2, py + 2, popW, popH, borderRadius)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
    nvgFill(nvg)

    -- Background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px, py, popW, popH, borderRadius)
    nvgFillColor(nvg, Theme.NvgColor("surface"))
    nvgFill(nvg)
    nvgStrokeColor(nvg, Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    local contentX = px + contentPadding
    local contentY = py + contentPadding

    -- Saturation/Value picker
    self:RenderSVPicker(nvg, contentX, contentY, pickerSize)
    contentY = contentY + pickerSize + sliderGap

    -- Hue slider
    self:RenderHueSlider(nvg, contentX, contentY, pickerSize, sliderHeight)
    contentY = contentY + sliderHeight + sliderGap

    -- Alpha slider (optional)
    if self.showAlpha_ then
        self:RenderAlphaSlider(nvg, contentX, contentY, pickerSize, sliderHeight)
        contentY = contentY + sliderHeight + sliderGap
    end

    -- Presets (optional)
    if self.showPresets_ then
        self:RenderPresets(nvg, contentX, contentY, pickerSize, presetSize, presetGap)
        local presetsPerRow = math.floor(pickerSize / (presetSize + presetGap))
        local presetRows = math.ceil(#self.presets_ / presetsPerRow)
        contentY = contentY + presetRows * (presetSize + presetGap) + 8
    end

    -- Hex input display (optional)
    if self.showInput_ then
        self:RenderHexInput(nvg, contentX, contentY, popW - contentPadding * 2)
    end
end

function ColorPicker:RenderSVPicker(nvg, x, y, size)
    self.svBounds_ = { x = x, y = y, w = size, h = size }

    -- Draw saturation gradient (white to hue color)
    local hueR, hueG, hueB = hsvToRgb(self.hue_, 1, 1)

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, size, size)

    -- Horizontal gradient: white to hue color
    local gradH = nvgLinearGradient(nvg, x, y, x + size, y,
        nvgRGBA(255, 255, 255, 255),
        nvgRGBA(hueR, hueG, hueB, 255))
    nvgFillPaint(nvg, gradH)
    nvgFill(nvg)

    -- Vertical gradient: transparent to black
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, size, size)
    local gradV = nvgLinearGradient(nvg, x, y, x, y + size,
        nvgRGBA(0, 0, 0, 0),
        nvgRGBA(0, 0, 0, 255))
    nvgFillPaint(nvg, gradV)
    nvgFill(nvg)

    -- Border
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, size, size)
    nvgStrokeColor(nvg, Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- Draw cursor
    local cursorX = x + self.saturation_ * size
    local cursorY = y + (1 - self.value_) * size

    nvgBeginPath(nvg)
    nvgCircle(nvg, cursorX, cursorY, 8)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    nvgBeginPath(nvg)
    nvgCircle(nvg, cursorX, cursorY, 6)
    nvgStrokeColor(nvg, nvgRGBA(0, 0, 0, 255))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
end

function ColorPicker:RenderHueSlider(nvg, x, y, w, h)
    self.hueBounds_ = { x = x, y = y, w = w, h = h }
    local borderRadius = 4

    -- Draw hue gradient
    local segments = 6
    local segW = w / segments

    for i = 0, segments - 1 do
        local r1, g1, b1 = hsvToRgb(i / segments, 1, 1)
        local r2, g2, b2 = hsvToRgb((i + 1) / segments, 1, 1)

        nvgBeginPath(nvg)
        nvgRect(nvg, x + i * segW, y, segW + 1, h)

        local grad = nvgLinearGradient(nvg, x + i * segW, y, x + (i + 1) * segW, y,
            nvgRGBA(r1, g1, b1, 255),
            nvgRGBA(r2, g2, b2, 255))
        nvgFillPaint(nvg, grad)
        nvgFill(nvg)
    end

    -- Border
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, borderRadius)
    nvgStrokeColor(nvg, Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- Draw cursor
    local cursorX = x + self.hue_ * w
    local cursorW = 8
    local cursorPad = 2
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cursorX - cursorW / 2, y - cursorPad, cursorW, h + cursorPad * 2, 2)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(0, 0, 0, 128))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
end

function ColorPicker:RenderAlphaSlider(nvg, x, y, w, h)
    self.alphaBounds_ = { x = x, y = y, w = w, h = h }
    local borderRadius = 4

    -- Checkerboard background
    local checkSize = 4
    nvgSave(nvg)
    nvgIntersectScissor(nvg, x, y, w, h)

    for cy = 0, h - 1, checkSize do
        for cx = 0, w - 1, checkSize do
            local isLight = (math.floor(cx / checkSize) + math.floor(cy / checkSize)) % 2 == 0
            nvgBeginPath(nvg)
            nvgRect(nvg, x + cx, y + cy, checkSize, checkSize)
            nvgFillColor(nvg, isLight and nvgRGBA(255, 255, 255, 255) or nvgRGBA(200, 200, 200, 255))
            nvgFill(nvg)
        end
    end

    nvgRestore(nvg)

    -- Alpha gradient
    local r, g, b = hsvToRgb(self.hue_, self.saturation_, self.value_)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, borderRadius)
    local grad = nvgLinearGradient(nvg, x, y, x + w, y,
        nvgRGBA(r, g, b, 0),
        nvgRGBA(r, g, b, 255))
    nvgFillPaint(nvg, grad)
    nvgFill(nvg)

    -- Border
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, borderRadius)
    nvgStrokeColor(nvg, Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- Draw cursor
    local cursorX = x + (self.alpha_ / 255) * w
    local cursorW = 8
    local cursorPad = 2
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cursorX - cursorW / 2, y - cursorPad, cursorW, h + cursorPad * 2, 2)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(0, 0, 0, 128))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
end

function ColorPicker:RenderPresets(nvg, x, y, pickerSize, presetSize, presetGap)
    local presetsPerRow = math.floor(pickerSize / (presetSize + presetGap))
    local borderRadius = 4

    self.presetBounds_ = {}

    for i, preset in ipairs(self.presets_) do
        local row = math.floor((i - 1) / presetsPerRow)
        local col = (i - 1) % presetsPerRow

        local px = x + col * (presetSize + presetGap)
        local py = y + row * (presetSize + presetGap)

        self.presetBounds_[i] = { x = px, y = py, w = presetSize, h = presetSize }

        local r, g, b = hexToRgb(preset)

        -- Draw preset swatch
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px, py, presetSize, presetSize, borderRadius)
        nvgFillColor(nvg, nvgRGBA(r, g, b, 255))
        nvgFill(nvg)

        -- Hover effect
        if self.hoverPreset_ == i then
            nvgStrokeColor(nvg, Theme.NvgColor("primary"))
            nvgStrokeWidth(nvg, 2)
        else
            nvgStrokeColor(nvg, Theme.NvgColor("border"))
            nvgStrokeWidth(nvg, 1)
        end
        nvgStroke(nvg)
    end
end

function ColorPicker:RenderHexInput(nvg, x, y, w)
    local theme = Theme.GetTheme()

    -- Use the pre-calculated height from RenderPopup
    local allocatedHeight = self.hexInputHeight_ or (self.fontSize_ * 1.5 + self.padding_)
    local textY = y + allocatedHeight / 2

    -- Label
    nvgFontSize(nvg, self.fontSize_ * 0.85)
    nvgFontFace(nvg, Theme.FontFamily())
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
    nvgText(nvg, x, textY, "HEX:")

    -- Value
    nvgFontSize(nvg, self.fontSize_)
    nvgFillColor(nvg, Theme.NvgColor("text"))
    nvgText(nvg, x + 40, textY, self:GetHex())
end

-- ============================================================================
-- Input Handling
-- ============================================================================

function ColorPicker:PointInBounds(px, py, bounds)
    if not bounds then return false end
    return px >= bounds.x and px <= bounds.x + bounds.w and
           py >= bounds.y and py <= bounds.y + bounds.h
end

function ColorPicker:HitTest(x, y)
    -- Use GetAbsoluteLayoutForHitTest for proper scroll offset handling
    local l = self:GetAbsoluteLayoutForHitTest()

    -- Check input area
    if x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h then
        return true
    end

    -- When open, capture ALL clicks (for closing on click outside)
    if self.isOpen_ then
        return true
    end

    return false
end

function ColorPicker:OnPointerMove(event)
    if not event then return end

    -- Use event coords directly (all bounds are in HitTest coords)
    local px = event.x
    local py = event.y

    -- Handle dragging
    if self.dragging_ then
        if self.dragging_ == "sv" then
            local s = math.max(0, math.min(1, (px - self.svBounds_.x) / self.svBounds_.w))
            local v = math.max(0, math.min(1, 1 - (py - self.svBounds_.y) / self.svBounds_.h))
            self.saturation_ = s
            self.value_ = v
            self:NotifyChange()
        elseif self.dragging_ == "hue" then
            local h = math.max(0, math.min(1, (px - self.hueBounds_.x) / self.hueBounds_.w))
            self.hue_ = h
            self:NotifyChange()
        elseif self.dragging_ == "alpha" then
            local a = math.max(0, math.min(1, (px - self.alphaBounds_.x) / self.alphaBounds_.w))
            self.alpha_ = math.floor(a * 255)
            self:NotifyChange()
        end
        return
    end

    -- Hover detection for presets
    self.hoverPreset_ = nil
    if self.presetBounds_ then
        for i, bounds in ipairs(self.presetBounds_) do
            if self:PointInBounds(px, py, bounds) then
                self.hoverPreset_ = i
                break
            end
        end
    end
end

function ColorPicker:OnPointerLeave(event)
    self.hoverPreset_ = nil
end

function ColorPicker:OnPointerDown(event)
    if not event then return false end

    -- Use event coords directly (all bounds are in HitTest coords)
    local px = event.x
    local py = event.y

    -- Check if clicking on input field
    if self:PointInBounds(px, py, self.inputBounds_) then
        self:Toggle()
        return true
    end

    -- If not open, nothing else to check
    if not self.isOpen_ then return false end

    -- Check if clicking outside popup
    if not self:PointInBounds(px, py, self.popupBounds_) then
        self:Close()
        return true
    end

    -- Check SV picker
    if self:PointInBounds(px, py, self.svBounds_) then
        self.dragging_ = "sv"
        local s = math.max(0, math.min(1, (px - self.svBounds_.x) / self.svBounds_.w))
        local v = math.max(0, math.min(1, 1 - (py - self.svBounds_.y) / self.svBounds_.h))
        self.saturation_ = s
        self.value_ = v
        self:NotifyChange()
        return true
    end

    -- Check Hue slider
    if self:PointInBounds(px, py, self.hueBounds_) then
        self.dragging_ = "hue"
        local h = math.max(0, math.min(1, (px - self.hueBounds_.x) / self.hueBounds_.w))
        self.hue_ = h
        self:NotifyChange()
        return true
    end

    -- Check Alpha slider
    if self.showAlpha_ and self:PointInBounds(px, py, self.alphaBounds_) then
        self.dragging_ = "alpha"
        local a = math.max(0, math.min(1, (px - self.alphaBounds_.x) / self.alphaBounds_.w))
        self.alpha_ = math.floor(a * 255)
        self:NotifyChange()
        return true
    end

    -- Check presets
    if self.presetBounds_ then
        for i, bounds in ipairs(self.presetBounds_) do
            if self:PointInBounds(px, py, bounds) then
                self:SetHex(self.presets_[i])
                self:NotifyChange()
                return true
            end
        end
    end

    return false
end

function ColorPicker:OnPointerUp(event)
    self.dragging_ = nil
end

function ColorPicker:OnClick(event)
    -- Handled by OnPointerDown for drag support
    return false
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a basic color picker
---@param props table|nil
---@return ColorPicker
function ColorPicker.Basic(props)
    return ColorPicker(props)
end

--- Create a color picker with alpha channel
---@param props table|nil
---@return ColorPicker
function ColorPicker.WithAlpha(props)
    props = props or {}
    props.showAlpha = true
    return ColorPicker(props)
end

--- Create a compact color picker (no presets)
---@param props table|nil
---@return ColorPicker
function ColorPicker.Compact(props)
    props = props or {}
    props.showPresets = false
    props.showInput = false
    props.size = "sm"
    return ColorPicker(props)
end

--- Create a color picker with custom presets
---@param presets string[] Array of hex colors
---@param props table|nil
---@return ColorPicker
function ColorPicker.WithPresets(presets, props)
    props = props or {}
    props.presets = presets
    return ColorPicker(props)
end

--- Create a grayscale color picker
---@param props table|nil
---@return ColorPicker
function ColorPicker.Grayscale(props)
    props = props or {}
    props.presets = {
        "#000000", "#1A1A1A", "#333333", "#4D4D4D",
        "#666666", "#808080", "#999999", "#B3B3B3",
        "#CCCCCC", "#E6E6E6", "#F2F2F2", "#FFFFFF",
    }
    return ColorPicker(props)
end

--- Create a material design color picker
---@param props table|nil
---@return ColorPicker
function ColorPicker.Material(props)
    props = props or {}
    props.presets = {
        "#F44336", "#E91E63", "#9C27B0", "#673AB7",
        "#3F51B5", "#2196F3", "#03A9F4", "#00BCD4",
        "#009688", "#4CAF50", "#8BC34A", "#CDDC39",
        "#FFEB3B", "#FFC107", "#FF9800", "#FF5722",
    }
    return ColorPicker(props)
end

return ColorPicker
