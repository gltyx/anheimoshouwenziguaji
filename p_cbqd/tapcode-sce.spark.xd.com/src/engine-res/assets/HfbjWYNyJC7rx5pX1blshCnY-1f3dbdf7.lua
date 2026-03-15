-- ============================================================================
-- Theme System
-- UrhoX UI Library - Yoga + NanoVG
-- ============================================================================

local Theme = {}

-- Current active theme
local currentTheme = nil

-- UI scale factor (based on screen resolution, set by UI.Init)
local uiScale = 1.0

-- Font scale factor (1.0 = normal, for accessibility scaling)
local fontScale = 1.0

-- DPI conversion constant: pt to px at 96 DPI
-- px = pt × 96/72 = pt × 1.333...
local PT_TO_PX = 96 / 72  -- ≈ 1.333

-- Font size conversion ratio (set once at init, avoids runtime branching)
-- "pixel" mode: sizeRatio = PT_TO_PX (convert pt to px)
-- "char" mode: sizeRatio = 1.0 (pass pt directly)
local sizeRatio = PT_TO_PX

-- ============================================================================
-- Font Size Presets (base values before scaling)
-- Unit: points (pt), industry standard (same as Unity/Unreal)
-- At 96 DPI: 12pt = 16px, 18pt = 24px
-- ============================================================================
local FontSizes = {
    -- Display / 展示性大字 (用于 dropzone 图标等)
    display = 24,       -- 24pt = 32px

    -- Headings / 标题
    headline = 18,      -- 18pt = 24px 页面大标题
    title = 15,         -- 15pt = 20px 区块标题
    subtitle = 14,      -- 14pt ≈ 18px 副标题

    -- Body / 正文
    bodyLarge = 12,     -- 12pt = 16px 大号正文、按钮
    body = 11,          -- 11pt ≈ 14px 标准正文、输入框
    bodySmall = 10,     -- 10pt ≈ 13px 小号正文、文件名

    -- Small / 小号文字
    small = 9,          -- 9pt = 12px 提示文字、进度百分比
    caption = 8,        -- 8pt ≈ 11px 辅助文字、文件大小
    tiny = 8,           -- 8pt ≈ 10px 最小文字、排序箭头
}

-- ============================================================================
-- Theme Management
-- ============================================================================

--- Set the current theme
---@param theme table Theme definition
function Theme.SetTheme(theme)
    currentTheme = theme
end

--- Get the current theme
---@return table
function Theme.GetTheme()
    return currentTheme
end

--- Extend a base theme with overrides
---@param base table Base theme
---@param overrides table Override values
---@return table New theme
function Theme.ExtendTheme(base, overrides)
    local result = {}

    -- Deep copy base
    local function deepCopy(src, dst)
        for k, v in pairs(src) do
            if type(v) == "table" then
                dst[k] = {}
                deepCopy(v, dst[k])
            else
                dst[k] = v
            end
        end
    end

    deepCopy(base, result)

    -- Apply overrides (deep merge)
    local function deepMerge(src, dst)
        for k, v in pairs(src) do
            if type(v) == "table" and type(dst[k]) == "table" then
                deepMerge(v, dst[k])
            else
                dst[k] = v
            end
        end
    end

    if overrides then
        deepMerge(overrides, result)
    end

    return result
end

-- ============================================================================
-- Theme Access Helpers
-- ============================================================================

--- Get a color from the current theme
---@param name string Color name (e.g., "primary", "text")
---@return table RGBA color
function Theme.Color(name)
    if currentTheme and currentTheme.colors and currentTheme.colors[name] then
        return currentTheme.colors[name]
    end
    return { 128, 128, 128, 255 } -- fallback gray
end

--- Convert a color table {r, g, b, a} to NVGcolor
---@param c table|NVGcolor Color table or existing NVGcolor
---@return NVGcolor
function Theme.ToNvgColor(c)
    if type(c) == "table" then
        return nvgRGBA(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 255)
    end
    return c
end

--- Get a color from the current theme as NVGcolor (ready for nvgFillColor/nvgStrokeColor)
---@param name string Color name
---@return NVGcolor
function Theme.NvgColor(name)
    return Theme.ToNvgColor(Theme.Color(name))
end

--- Get a spacing value from the current theme (in base pixels)
--- nvgScale in UI.Render handles conversion to screen pixels
---@param name string Spacing name (e.g., "sm", "md", "lg")
---@return number Base pixel value
function Theme.Spacing(name)
    local value = 8  -- fallback
    if currentTheme and currentTheme.spacing and currentTheme.spacing[name] then
        value = currentTheme.spacing[name]
    end
    return value
end

--- Get a radius value from the current theme (in base pixels)
--- nvgScale in UI.Render handles conversion to screen pixels
---@param name string Radius name (e.g., "sm", "md", "lg")
---@return number Base pixel value
function Theme.Radius(name)
    local value = 4  -- fallback
    if currentTheme and currentTheme.radius and currentTheme.radius[name] then
        value = currentTheme.radius[name]
    end
    return value
end

--- Get base radius value from the current theme (without scaling)
---@param name string Radius name (e.g., "sm", "md", "lg")
---@return number
function Theme.BaseRadius(name)
    if currentTheme and currentTheme.radius and currentTheme.radius[name] then
        return currentTheme.radius[name]
    end
    return 4  -- fallback
end

--- Get typography settings from the current theme (with UI scale and font scale)
---@param name string Typography name (e.g., "body", "h1", "caption")
---@return table
function Theme.Typography(name)
    local typo
    if currentTheme and currentTheme.typography and currentTheme.typography[name] then
        typo = currentTheme.typography[name]
    else
        typo = { fontSize = 16 } -- fallback
    end
    -- Apply UI scale and font scale
    return { fontSize = math.floor((typo.fontSize or 16) * uiScale * fontScale) }
end

--- Get component default style from the current theme (raw design values, no scaling)
--- Scaling is applied at layout time in Widget:ApplyStyle()
---@param componentName string Component name (e.g., "Button", "Panel")
---@return table
function Theme.ComponentStyle(componentName)
    local style = {}
    if currentTheme and currentTheme.components and currentTheme.components[componentName] then
        -- Shallow copy to avoid modifying original (no scaling here)
        for k, v in pairs(currentTheme.components[componentName]) do
            style[k] = v
        end
    end
    return style
end

--- Get font family from the current theme (safe accessor)
---@return string Font family name
function Theme.FontFamily()
    if currentTheme and currentTheme.typography and currentTheme.typography.fontFamily then
        return currentTheme.typography.fontFamily
    end
    return "sans"
end

--- Get font face name based on family and weight
--- Maps fontFamily + fontWeight to actual NanoVG font face name
---@param fontFamily string|nil Font family name (default: theme's fontFamily)
---@param fontWeight string|nil "normal" | "bold" | "100"-"900" (default: "normal")
---@return string Font face name for nvgFontFace
function Theme.FontFace(fontFamily, fontWeight)
    local baseFamily = fontFamily or Theme.FontFamily()

    -- Normalize weight
    if fontWeight == nil or fontWeight == "normal" or fontWeight == "400" then
        return baseFamily
    end

    -- Bold weights: "bold", "700"
    if fontWeight == "bold" or fontWeight == "700" then
        return baseFamily .. "-bold"
    end

    -- Semi-bold / medium (500-600) - map to bold for now
    if fontWeight == "500" or fontWeight == "600" or fontWeight == "medium" or fontWeight == "semibold" then
        return baseFamily .. "-bold"
    end

    -- Heavy weights (800-900) - map to bold for now
    if fontWeight == "800" or fontWeight == "900" or fontWeight == "black" then
        return baseFamily .. "-bold"
    end

    -- Light weights (100-300) - not supported yet, fallback to regular
    -- TODO: Add light font support when available

    return baseFamily
end

--- Set font scale factor (for accessibility)
---@param scale number Scale factor (1.0 = normal, 1.25 = 25% larger)
function Theme.SetFontScale(scale)
    fontScale = scale or 1.0
end

--- Get font scale factor
---@return number Current font scale
function Theme.GetFontScale()
    return fontScale
end

--- Set UI scale factor (for resolution adaptation, called by UI.Init)
---@param scale number Scale factor based on screen resolution
function Theme.SetScale(scale)
    uiScale = scale or 1.0
end

--- Get UI scale factor
---@return number Current UI scale
function Theme.GetScale()
    return uiScale
end

--- Scale a value by current UI scale
---@param value number Value to scale
---@return number Scaled value
function Theme.Scale(value)
    return value * uiScale
end

--- Set font size method (internal use only, called by UI.Init)
--- Sets sizeRatio for optimal performance (no runtime branching in FontSize)
---@param method string "pixel" or "char"
function Theme.SetFontSizeMethod(method)
    if method == "char" then
        sizeRatio = 1.0  -- Pass pt directly to NanoVG
    else
        sizeRatio = PT_TO_PX  -- Convert pt to px (default)
    end
end

--- Get font size from point value for NanoVG (in BASE PIXELS)
--- nvgScale handles the conversion to screen pixels
--- Uses sizeRatio set at init time for optimal performance
---@param ptSize number Font size in points (pt)
---@return number Font size for NanoVG (base pixels, nvgScale will scale it)
function Theme.FontSize(ptSize)
    -- No uiScale - nvgScale in UI.Render handles it
    return ptSize * sizeRatio * fontScale
end

--- Get font size by semantic name for NanoVG (in BASE PIXELS)
--- nvgScale handles the conversion to screen pixels
---@param name string Font size name: "display", "headline", "title", "subtitle", "bodyLarge", "body", "bodySmall", "small", "caption", "tiny"
---@return number Font size for NanoVG (base pixels, nvgScale will scale it)
function Theme.FontSizeOf(name)
    local ptSize = FontSizes[name] or FontSizes.body
    -- No uiScale - nvgScale in UI.Render handles it
    return ptSize * sizeRatio * fontScale
end

--- Get base point size by semantic name (without conversion)
---@param name string Font size name
---@return number Base font size in points (pt)
function Theme.BaseFontSize(name)
    return FontSizes[name] or FontSizes.body
end

--- Get all font size presets (in points)
---@return table Font size presets table (values in pt)
function Theme.GetFontSizes()
    return FontSizes
end

-- ============================================================================
-- Default Theme
-- ============================================================================

Theme.defaultTheme = {
    colors = {
        -- Primary colors
        primary = { 70, 130, 180, 255 },
        primaryHover = { 90, 150, 200, 255 },
        primaryPressed = { 50, 110, 160, 255 },

        -- Secondary colors
        secondary = { 108, 117, 125, 255 },
        secondaryHover = { 128, 137, 145, 255 },
        secondaryPressed = { 88, 97, 105, 255 },

        -- Background colors
        background = { 30, 30, 40, 255 },
        surface = { 50, 55, 70, 230 },
        surfaceHover = { 60, 65, 80, 230 },

        -- Text colors
        text = { 255, 255, 255, 255 },
        textSecondary = { 180, 180, 180, 255 },
        textDisabled = { 100, 100, 100, 255 },

        -- Border
        border = { 100, 100, 120, 255 },
        borderFocus = { 70, 130, 180, 255 },

        -- Semantic colors
        success = { 80, 180, 80, 255 },
        successHover = { 100, 200, 100, 255 },
        warning = { 220, 180, 50, 255 },
        warningHover = { 240, 200, 70, 255 },
        error = { 220, 80, 80, 255 },
        errorHover = { 240, 100, 100, 255 },
        info = { 70, 150, 200, 255 },

        -- Disabled
        disabled = { 80, 80, 80, 255 },
        disabledText = { 120, 120, 120, 255 },

        -- Overlay
        overlay = { 0, 0, 0, 150 },

        -- Transparent
        transparent = { 0, 0, 0, 0 },

        -- Hover
        hover = { 255, 255, 255, 25 },
    },

    spacing = {
        xs = 4,
        sm = 8,
        md = 16,
        lg = 24,
        xl = 32,
        xxl = 48,
    },

    radius = {
        none = 0,
        sm = 4,
        md = 8,
        lg = 16,
        xl = 24,
        full = 9999,
    },

    typography = {
        fontFamily = "sans",
        -- Use FontSizes presets for consistency (values in pt)
        h1 = { fontSize = FontSizes.display },       -- 24pt = 32px
        h2 = { fontSize = FontSizes.headline },      -- 18pt = 24px
        h3 = { fontSize = FontSizes.title },         -- 15pt = 20px
        body = { fontSize = FontSizes.bodyLarge },   -- 12pt = 16px
        bodySmall = { fontSize = FontSizes.body },   -- 11pt ≈ 14px
        caption = { fontSize = FontSizes.small },    -- 9pt = 12px
    },

    components = {
        Button = {
            height = 44,
            paddingHorizontal = 16,
            borderRadius = 8,
            fontSize = FontSizes.bodyLarge,  -- 12pt = 16px
        },
        Panel = {
            borderRadius = 8,
        },
        TextField = {
            height = 40,
            paddingHorizontal = 12,
            borderRadius = 4,
            fontSize = FontSizes.body,  -- 11pt ≈ 14px
        },
        Checkbox = {
            size = 20,
            borderRadius = 4,
        },
        Toggle = {
            width = 48,
            height = 26,
            thumbSize = 22,
        },
        Slider = {
            trackHeight = 4,
            thumbSize = 16,
        },
        ProgressBar = {
            height = 8,
            borderRadius = 4,
        },
    },
}

-- Set default theme on load
Theme.SetTheme(Theme.defaultTheme)

return Theme
