-- ============================================================================
-- Style Utilities
-- UrhoX UI Library - Yoga + NanoVG
-- ============================================================================

local Style = {}

-- ============================================================================
-- Yoga Enum Maps (file-level for performance)
-- ============================================================================

local flexDirectionMap = {
    ["row"] = YGFlexDirectionRow,
    ["column"] = YGFlexDirectionColumn,
    ["row-reverse"] = YGFlexDirectionRowReverse,
    ["column-reverse"] = YGFlexDirectionColumnReverse,
}

local justifyContentMap = {
    ["flex-start"] = YGJustifyFlexStart,
    ["center"] = YGJustifyCenter,
    ["flex-end"] = YGJustifyFlexEnd,
    ["space-between"] = YGJustifySpaceBetween,
    ["space-around"] = YGJustifySpaceAround,
    ["space-evenly"] = YGJustifySpaceEvenly,
}

local alignItemsMap = {
    ["flex-start"] = YGAlignFlexStart,
    ["center"] = YGAlignCenter,
    ["flex-end"] = YGAlignFlexEnd,
    ["stretch"] = YGAlignStretch,
    ["baseline"] = YGAlignBaseline,
    ["space-between"] = YGAlignSpaceBetween,
    ["space-around"] = YGAlignSpaceAround,
    ["space-evenly"] = YGAlignSpaceEvenly,
}

local alignSelfMap = {
    ["auto"] = YGAlignAuto,
    ["flex-start"] = YGAlignFlexStart,
    ["center"] = YGAlignCenter,
    ["flex-end"] = YGAlignFlexEnd,
    ["stretch"] = YGAlignStretch,
    ["baseline"] = YGAlignBaseline,
    ["space-between"] = YGAlignSpaceBetween,
    ["space-around"] = YGAlignSpaceAround,
    ["space-evenly"] = YGAlignSpaceEvenly,
}

local alignContentMap = {
    ["flex-start"] = YGAlignFlexStart,
    ["center"] = YGAlignCenter,
    ["flex-end"] = YGAlignFlexEnd,
    ["stretch"] = YGAlignStretch,
    ["space-between"] = YGAlignSpaceBetween,
    ["space-around"] = YGAlignSpaceAround,
    ["space-evenly"] = YGAlignSpaceEvenly,
}

local positionTypeMap = {
    ["relative"] = YGPositionTypeRelative,
    ["absolute"] = YGPositionTypeAbsolute,
}

local wrapMap = {
    ["no-wrap"] = YGWrapNoWrap,
    ["wrap"] = YGWrapWrap,
    ["wrap-reverse"] = YGWrapWrapReverse,
}

local textAlignHorizontalMap = {
    ["left"] = NVG_ALIGN_LEFT,
    ["center"] = NVG_ALIGN_CENTER_VISUAL,
    ["right"] = NVG_ALIGN_RIGHT,
}

local textAlignVerticalMap = {
    ["top"] = NVG_ALIGN_TOP,
    ["middle"] = NVG_ALIGN_MIDDLE,
    ["bottom"] = NVG_ALIGN_BOTTOM,
    ["baseline"] = NVG_ALIGN_BASELINE,
}

-- ============================================================================
-- Yoga Enum Converters
-- ============================================================================

--- Convert flex direction string to Yoga enum
---@param str string "row" | "column" | "row-reverse" | "column-reverse"
---@return number Yoga enum value
function Style.FlexDirectionToYoga(str)
    return flexDirectionMap[str] or YGFlexDirectionColumn
end

--- Convert justify content string to Yoga enum
---@param str string
---@return number
function Style.JustifyContentToYoga(str)
    return justifyContentMap[str] or YGJustifyFlexStart
end

--- Convert align items string to Yoga enum
---@param str string
---@return number
function Style.AlignItemsToYoga(str)
    return alignItemsMap[str] or YGAlignStretch
end

--- Convert align self string to Yoga enum
---@param str string
---@return number
function Style.AlignSelfToYoga(str)
    return alignSelfMap[str] or YGAlignAuto
end

--- Convert align content string to Yoga enum
---@param str string
---@return number
function Style.AlignContentToYoga(str)
    return alignContentMap[str] or YGAlignStretch
end

--- Convert position type string to Yoga enum
---@param str string "relative" | "absolute"
---@return number
function Style.PositionTypeToYoga(str)
    return positionTypeMap[str] or YGPositionTypeRelative
end

--- Convert wrap string to Yoga enum
---@param str string "no-wrap" | "wrap" | "wrap-reverse"
---@return number
function Style.WrapToYoga(str)
    return wrapMap[str] or YGWrapNoWrap
end

-- ============================================================================
-- Style Merge
-- ============================================================================

--- Merge multiple style tables
---@vararg table
---@return table merged style
function Style.Merge(...)
    local result = {}
    for i = 1, select("#", ...) do
        local style = select(i, ...)
        if style then
            for k, v in pairs(style) do
                result[k] = v
            end
        end
    end
    return result
end

--- Apply default values to style table (modifies in place)
--- Only fills keys that are nil in style
---@param style table Table to modify
---@param defaults table Default values to apply
function Style.ApplyDefaults(style, defaults)
    if not style or not defaults then return end
    for k, v in pairs(defaults) do
        if style[k] == nil then
            style[k] = v
        end
    end
end

-- ============================================================================
-- Color Utilities
-- ============================================================================

--- Parse color from various formats
---@param color any
---@return table { r, g, b, a } or nil
function Style.ParseColor(color)
    if not color then
        return nil
    end

    -- Already RGBA table
    if type(color) == "table" then
        return {
            color[1] or 0,
            color[2] or 0,
            color[3] or 0,
            color[4] or 255
        }
    end

    -- Hex string: "#RGB", "#RGBA", "#RRGGBB" or "#RRGGBBAA"
    if type(color) == "string" then
        if color:sub(1, 1) == "#" then
            local hex = color:sub(2)
            if #hex == 3 then
                -- Short format #RGB -> #RRGGBB
                local r = hex:sub(1, 1)
                local g = hex:sub(2, 2)
                local b = hex:sub(3, 3)
                return {
                    tonumber(r .. r, 16) or 0,
                    tonumber(g .. g, 16) or 0,
                    tonumber(b .. b, 16) or 0,
                    255
                }
            elseif #hex == 4 then
                -- Short format #RGBA -> #RRGGBBAA
                local r = hex:sub(1, 1)
                local g = hex:sub(2, 2)
                local b = hex:sub(3, 3)
                local a = hex:sub(4, 4)
                return {
                    tonumber(r .. r, 16) or 0,
                    tonumber(g .. g, 16) or 0,
                    tonumber(b .. b, 16) or 0,
                    tonumber(a .. a, 16) or 255
                }
            elseif #hex == 6 then
                return {
                    tonumber(hex:sub(1, 2), 16) or 0,
                    tonumber(hex:sub(3, 4), 16) or 0,
                    tonumber(hex:sub(5, 6), 16) or 0,
                    255
                }
            elseif #hex == 8 then
                return {
                    tonumber(hex:sub(1, 2), 16) or 0,
                    tonumber(hex:sub(3, 4), 16) or 0,
                    tonumber(hex:sub(5, 6), 16) or 0,
                    tonumber(hex:sub(7, 8), 16) or 255
                }
            end
        end

        -- CSS format: rgb(r,g,b) or rgba(r,g,b,a)
        local r, g, b = color:match("rgb%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
        if r then
            return { tonumber(r), tonumber(g), tonumber(b), 255 }
        end

        local a
        r, g, b, a = color:match("rgba%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*([%d%.]+)%)")
        if r then
            local alpha = tonumber(a)
            if alpha <= 1 then alpha = alpha * 255 end
            return { tonumber(r), tonumber(g), tonumber(b), math.floor(alpha) }
        end
    end

    return nil
end

--- Convert color to RGBA table
---@param color any
---@return table { r, g, b, a }
function Style.ColorToRGBA(color)
    return Style.ParseColor(color) or { 0, 0, 0, 255 }
end

--- Lighten a color
---@param color table RGBA
---@param amount number 0-1
---@return table RGBA
function Style.Lighten(color, amount)
    return {
        math.min(255, color[1] + (255 - color[1]) * amount),
        math.min(255, color[2] + (255 - color[2]) * amount),
        math.min(255, color[3] + (255 - color[3]) * amount),
        color[4] or 255
    }
end

--- Darken a color
---@param color table RGBA
---@param amount number 0-1
---@return table RGBA
function Style.Darken(color, amount)
    return {
        math.max(0, color[1] * (1 - amount)),
        math.max(0, color[2] * (1 - amount)),
        math.max(0, color[3] * (1 - amount)),
        color[4] or 255
    }
end

--- Set alpha of a color
---@param color table RGBA
---@param alpha number 0-255
---@return table RGBA
function Style.WithAlpha(color, alpha)
    return { color[1], color[2], color[3], alpha }
end

-- List of known color property names (suffixed with "Color" or "color")
-- This is used by NormalizeColorProps to identify color properties
local colorPropertySuffixes = { "Color", "color", "Tint", "tint" }

--- Check if a property name is a color property
---@param name string Property name
---@return boolean
local function isColorProperty(name)
    for _, suffix in ipairs(colorPropertySuffixes) do
        if name:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

--- Normalize all color properties in a props table
--- Converts string color formats (hex, rgb, rgba) to RGBA tables
--- This allows users to write: backgroundColor = "#ff0000" or "rgba(255, 0, 0, 0.5)"
---@param props table Props table to normalize
---@return table The same props table (modified in place)
function Style.NormalizeColorProps(props)
    if not props then return props end

    for key, value in pairs(props) do
        -- Check if this is a color property by name suffix
        if type(key) == "string" and isColorProperty(key) then
            -- Only parse if value is a string (already RGBA tables are fine)
            if type(value) == "string" then
                local parsed = Style.ParseColor(value)
                if parsed then
                    props[key] = parsed
                end
            elseif type(value) == "table" and #value >= 3 then
                -- Ensure alpha channel exists for RGBA tables
                if not value[4] then
                    value[4] = 255
                end
            end
        end
    end

    return props
end

-- ============================================================================
-- NanoVG Text Align Converter
-- ============================================================================

--- Convert text align string to NanoVG flags
---@param horizontal string "left" | "center" | "right"
---@param vertical string "top" | "middle" | "bottom" | "baseline"
---@return number NanoVG align flags
function Style.TextAlignToNVG(horizontal, vertical)
    local h = textAlignHorizontalMap[horizontal or "left"] or NVG_ALIGN_LEFT
    local v = textAlignVerticalMap[vertical or "middle"] or NVG_ALIGN_MIDDLE
    return h + v
end

return Style
