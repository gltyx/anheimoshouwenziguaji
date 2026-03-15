-- ============================================================================
-- Label Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Text display widget
-- 
-- IMPORTANT: Yoga uses border-box model!
-- When setting explicit width, padding is INSIDE the width (like CSS box-sizing: border-box).
-- So width must = textWidth + paddingLeft + paddingRight
-- Reference: 3rd/yoga/website/docs/styling/width-height.mdx
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")
local UI = require("urhox-libs/UI/Core/UI")

---@class LabelProps : WidgetProps
---@field text string|nil Text content
---@field fontSize number|nil Font size
---@field fontColor table|nil RGBA color
---@field fontFamily string|nil Font name (base family, e.g. "sans")
---@field fontWeight string|nil "normal" | "bold" | "100"-"900"
---@field textAlign string|nil "left" | "center" | "right"
---@field verticalAlign string|nil "top" | "middle" | "bottom"
---@field maxLines number|nil Maximum lines (truncate with ...)
---@field pointerEvents string|nil "auto" | "none" (default: "none")
---@field color table|nil Alias for fontColor
---@field lineHeight number|nil Line height multiplier (default: 1.4)
---@field letterSpacing number|nil Letter spacing in pixels
---@field textDecoration string|nil "none" | "underline" | "line-through"
---@field textTransform string|nil "none" | "uppercase" | "lowercase" | "capitalize"
---@field whiteSpace string|nil "nowrap" (default) | "normal" (auto-wrap)
---@field wordBreak string|nil "normal" | "break-word"

---@class Label : Widget
---@operator call(LabelProps?): Label
---@field props LabelProps
---@field new fun(self, props: LabelProps?): Label
local Label = Widget:Extend("Label")

-- ============================================================================
-- Helper: Calculate total padding
-- ============================================================================

---Calculate horizontal padding (left + right)
---@param props table
---@return number paddingLeft, number paddingRight
local function getHorizontalPadding(props)
    local pl = props.paddingLeft or props.paddingHorizontal or props.padding or 0
    local pr = props.paddingRight or props.paddingHorizontal or props.padding or 0
    return pl, pr
end

---Calculate vertical padding (top + bottom)
---@param props table
---@return number paddingTop, number paddingBottom
local function getVerticalPadding(props)
    local pt = props.paddingTop or props.paddingVertical or props.padding or 0
    local pb = props.paddingBottom or props.paddingVertical or props.padding or 0
    return pt, pb
end

---Apply textTransform to text string (pure, no side effects)
---@param text string
---@param transform string|nil
---@return string
local function applyTextTransform(text, transform)
    if not transform or transform == "none" then return text end
    if transform == "uppercase" then return string.upper(text) end
    if transform == "lowercase" then return string.lower(text) end
    if transform == "capitalize" then
        return text:gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. b end)
    end
    return text
end

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props LabelProps?
function Label:Init(props)
    props = props or {}

    -- Label defaults to not intercepting pointer events (like iOS UILabel)
    -- This prevents Label from stealing hover/click from parent Button
    -- Set pointerEvents = "auto" explicitly if you need clickable text
    props.pointerEvents = props.pointerEvents or "none"

    -- Apply typography defaults
    local typography = Theme.Typography("body")
    props.fontSize = props.fontSize or typography.fontSize
    props.fontFamily = props.fontFamily or Theme.FontFamily()
    props.fontColor = props.fontColor or Theme.Color("text")
    props.textAlign = props.textAlign or "left"
    props.verticalAlign = props.verticalAlign or "middle"

    local basePxSize = Theme.FontSize(props.fontSize)

    -- Calculate padding
    local pl, pr = getHorizontalPadding(props)
    local pt, pb = getVerticalPadding(props)

    -- Track user intent before applying defaults
    local userSetHeight = props.height ~= nil

    -- Set default height based on font size (with line height) + vertical padding
    -- IMPORTANT: Yoga uses border-box, so height must include padding
    if not props.height then
        local lh = props.lineHeight or 1.4
        props.height = math.ceil(basePxSize * lh) + pt + pb
    end

    -- Labels adapt to available space (text is clipped if shrunk below text width)
    props.flexShrink = props.flexShrink or 1

    -- Track whether width was explicitly set by user or auto-calculated from text.
    -- SetText() only recalculates width when autoWidth is true.
    self.autoWidth_ = not props.width

    -- Multiline mode: width from parent, height from content
    -- Auto-detect: text containing \n enables multiline when whiteSpace not explicitly set
    self.multiline_ = props.whiteSpace == "normal"
        or (props.whiteSpace == nil and props.text ~= nil and string.find(props.text, "\n", 1, true) ~= nil)
    if self.multiline_ then
        if self.autoWidth_ then
            -- No explicit width → stretch to fill parent (like CSS block element)
            props.alignSelf = props.alignSelf or "stretch"
            self.autoWidth_ = false  -- Don't measure single-line text width
        end
        -- Mark for auto-height (Render will calculate via nvgTextBoxBounds)
        if not userSetHeight then
            self.autoHeight_ = true
            -- Keep the initial single-line height from above; Render will correct it
        end
    end

    -- Cache display text (with textTransform applied) to avoid per-frame recomputation
    if props.text then
        self.displayText_ = applyTextTransform(props.text, props.textTransform)
    end

    -- Set initial width using precise measurement + horizontal padding
    -- IMPORTANT: Yoga uses border-box, so width must include padding
    if self.autoWidth_ and self.displayText_ then
        local nvgFontSize = Theme.FontSize(props.fontSize)
        local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
        local measuredWidth = UI.MeasureTextWidth(self.displayText_, nvgFontSize, fontFace, props.letterSpacing)
        if measuredWidth > 0 then
            -- width = content (text) + padding (border-box model)
            props.width = measuredWidth + pl + pr
            -- Cache measured text width for Render auto-wrap detection.
            -- Comparing against cached value (not live nvgTextBounds) avoids false positives
            -- from floating-point differences between Init measurement and Render measurement.
            self.measuredTextWidth_ = measuredWidth
            -- Cap auto-width to parent's available width (like CSS behavior).
            -- Without this, text with explicit pixel width bypasses Yoga's parent constraint,
            -- causing overflow when alignItems="center" (parent doesn't limit child width).
            -- Only when measuredWidth>0 to avoid affecting emoji labels (measurement returns 0).
            if not props.maxWidth then
                props.maxWidth = "100%"
            end
        end
    end

    Widget.Init(self, props)

    -- Set baseline value for Yoga alignItems="baseline" alignment
    -- Baseline = paddingTop + text ascender (distance from node top to text baseline)
    local nvgFontSize = Theme.FontSize(props.fontSize)
    local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
    local ascender = UI.MeasureTextBaseline(nvgFontSize, fontFace)
    YGNodeSetBaselineValue(self.node, pt + ascender)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Label:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props

    -- Render background if set (shadow + color + image + border)
    -- Yoga returns border-box dimensions, so background covers the full area including padding
    if props.backgroundColor or props.backgroundImage or props.borderColor then
        self:RenderFullBackground(nvg)
    end

    local text = self.displayText_ or props.text or ""
    if text == "" then
        return
    end

    -- Set font (convert pt to px for NanoVG)
    local fontFace = Theme.FontFace(props.fontFamily, props.fontWeight)
    nvgFontFace(nvg, fontFace)
    nvgFontSize(nvg, Theme.FontSize(props.fontSize))

    -- Always reset line height and letter spacing to prevent state leak
    -- between sibling widgets (NanoVG state persists across Render calls)
    nvgTextLineHeight(nvg, props.lineHeight or 1.0)
    nvgTextLetterSpacing(nvg, props.letterSpacing or 0)

    -- Set color
    local color = props.fontColor
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))

    -- Calculate content area (border-box minus padding)
    -- Since Yoga returns border-box, we need to inset for text positioning
    local pl, pr = getHorizontalPadding(props)
    local pt, pb = getVerticalPadding(props)

    local contentX = l.x + pl
    local contentY = l.y + pt
    local contentW = l.w - pl - pr
    local contentH = l.h - pt - pb

    -- Determine if we should use multiline rendering
    local useMultiline = self.multiline_
    local breakWidth = contentW

    -- Calculate position based on alignment within content area
    local x, y
    local hAlign, vAlign

    -- Horizontal align
    if props.textAlign == "center" then
        x = contentX + contentW / 2
        hAlign = NVG_ALIGN_CENTER_VISUAL
    elseif props.textAlign == "right" then
        x = contentX + contentW
        hAlign = NVG_ALIGN_RIGHT
    else
        x = contentX
        hAlign = NVG_ALIGN_LEFT
    end

    if useMultiline then
        -- nvgTextBox only recognizes NVG_ALIGN_LEFT/CENTER/RIGHT in its internal mask.
        -- NVG_ALIGN_CENTER_VISUAL (bit 7) is not included, causing text to not render.
        -- Map it to standard NVG_ALIGN_CENTER for multiline.
        local boxHAlign = hAlign
        if hAlign == NVG_ALIGN_CENTER_VISUAL then
            boxHAlign = NVG_ALIGN_CENTER
        end

        -- breakWidth safety: ensure at least 1px to prevent nvgTextBox rendering nothing
        breakWidth = math.max(1, contentW)

        -- Measure text height once (reused for auto-height and vertical alignment)
        nvgTextAlign(nvg, boxHAlign + NVG_ALIGN_TOP)
        local bounds = nvgTextBoxBounds(nvg, 0, 0, breakWidth, text)
        local textH = bounds and (bounds[4] - bounds[2]) or contentH

        -- Auto-height: recalculate when width changes (like RichText pattern)
        if self.autoHeight_ and contentW > 0 then
            if contentW ~= self.lastMultilineWidth_ then
                self.lastMultilineWidth_ = contentW
                if textH > 0 then
                    local mpt, mpb = getVerticalPadding(props)
                    local newHeight = math.ceil(textH) + mpt + mpb
                    if math.abs(newHeight - l.h) > 1 then
                        Widget.SetHeight(self, newHeight)
                    end
                end
            end
        end

        -- Vertical align
        if props.verticalAlign == "top" then
            y = contentY
        elseif props.verticalAlign == "bottom" then
            y = contentY + contentH - textH
        else
            y = contentY + (contentH - textH) / 2
        end

        -- Draw multiline text
        -- IMPORTANT: nvgTextBox x is always the LEFT edge of the text box.
        -- Alignment (center/right) is handled internally by NanoVG within breakWidth.
        -- This differs from nvgText where x is the alignment anchor point.
        if not self.autoWidth_ then
            nvgSave(nvg)
            nvgIntersectScissor(nvg, contentX, l.y, contentW, l.h)
        end
        nvgTextBox(nvg, contentX, y, breakWidth, text, nil)
        if not self.autoWidth_ then
            nvgRestore(nvg)
        end
    else
        -- Single-line rendering (default: whiteSpace = "nowrap")

        -- Auto-wrap: when maxWidth constrains layout width significantly below text measurement,
        -- switch to multiline rendering (like CSS white-space: normal).
        -- Uses cached measuredTextWidth_ from Init (not live nvgTextBounds) to avoid
        -- false positives from float precision / Yoga rounding differences.
        -- Auto-wrap tolerance: Yoga rounds layout values with PointScaleFactor (= UI scale).
        -- Max rounding error = 0.5 / scale. With small scale (large designSize on small screen),
        -- the error can exceed a fixed pixel threshold. Use scale-aware tolerance.
        local wrapTolerance = math.ceil(0.5 / (Theme.GetScale() or 1)) + 0.5
        if self.autoWidth_ and self.measuredTextWidth_ and contentW > 0
            and contentW < self.measuredTextWidth_ - wrapTolerance then
            local boxHAlign = hAlign
            if hAlign == NVG_ALIGN_CENTER_VISUAL then
                boxHAlign = NVG_ALIGN_CENTER
            end
            nvgTextAlign(nvg, boxHAlign + NVG_ALIGN_TOP)

            local wrapWidth = math.max(1, contentW)
            local bounds = nvgTextBoxBounds(nvg, 0, 0, wrapWidth, text)
            local textH = bounds and (bounds[4] - bounds[2]) or contentH

            -- Auto-adjust height for wrapped text (same pattern as multiline autoHeight_)
            if contentW ~= self.lastMultilineWidth_ then
                self.lastMultilineWidth_ = contentW
                if textH > 0 then
                    local mpt, mpb = getVerticalPadding(props)
                    local newHeight = math.ceil(textH) + mpt + mpb
                    if math.abs(newHeight - l.h) > 1 then
                        Widget.SetHeight(self, newHeight)
                    end
                end
            end

            -- Vertical align within (possibly outdated) content area
            if props.verticalAlign == "top" then
                y = contentY
            elseif props.verticalAlign == "bottom" then
                y = contentY + contentH - textH
            else
                y = contentY + (contentH - textH) / 2
            end

            nvgTextBox(nvg, contentX, y, wrapWidth, text, nil)
            return
        end

        -- Normal single-line path (text fits in layout width)
        -- Vertical align
        if props.verticalAlign == "top" then
            y = contentY
            vAlign = NVG_ALIGN_TOP
        elseif props.verticalAlign == "bottom" then
            y = contentY + contentH
            vAlign = NVG_ALIGN_BOTTOM
        else
            y = contentY + contentH / 2
            vAlign = NVG_ALIGN_MIDDLE
        end

        nvgTextAlign(nvg, hAlign + vAlign)

        -- Draw text: only clip when user set an explicit width (autoWidth_ = false).
        -- Auto-width labels are sized from text measurement; clipping them
        -- causes regressions (emoji measurement inaccuracy, sub-pixel rounding).
        local needClip = not self.autoWidth_
        if needClip then
            nvgSave(nvg)
            nvgIntersectScissor(nvg, contentX, l.y, contentW, l.h)
        end
        nvgText(nvg, x, y, text, nil)

        -- Draw text decoration (underline / line-through)
        local decoration = props.textDecoration
        if decoration and decoration ~= "none" then
            -- Get text metrics for line positioning
            local asc, desc, lineH = nvgTextMetrics(nvg)
            local textW2 = nvgTextBounds(nvg, x, y, text)

            -- Calculate text start X based on alignment
            local lineStartX
            if props.textAlign == "center" then
                lineStartX = x - textW2 / 2
            elseif props.textAlign == "right" then
                lineStartX = x - textW2
            else
                lineStartX = x
            end

            -- Draw the line
            nvgBeginPath(nvg)
            nvgStrokeWidth(nvg, 1)
            nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))

            if decoration == "underline" then
                -- Underline: below the baseline
                local lineY = y + desc * 0.5 + 1
                if vAlign == NVG_ALIGN_MIDDLE then
                    lineY = y + asc * 0.3 + 1
                elseif vAlign == NVG_ALIGN_TOP then
                    lineY = y + asc + 2
                end
                nvgMoveTo(nvg, lineStartX, lineY)
                nvgLineTo(nvg, lineStartX + textW2, lineY)
            elseif decoration == "line-through" then
                -- Strikethrough: middle of text
                local lineY = y
                if vAlign == NVG_ALIGN_MIDDLE then
                    lineY = y - asc * 0.15
                elseif vAlign == NVG_ALIGN_TOP then
                    lineY = y + asc * 0.4
                elseif vAlign == NVG_ALIGN_BOTTOM then
                    lineY = y - asc * 0.4
                end
                nvgMoveTo(nvg, lineStartX, lineY)
                nvgLineTo(nvg, lineStartX + textW2, lineY)
            end

            nvgStroke(nvg)
        end

        if needClip then
            nvgRestore(nvg)
        end
    end
end

-- ============================================================================
-- SetStyle Override
-- ============================================================================

--- Override SetStyle to update cached displayText_ when text or textTransform changes.
--- Widget:SetStyle merges props directly (bypasses SetText), so displayText_ would go stale.
---@param style table
---@return Label self
function Label:SetStyle(style)
    if style.text ~= nil or style.textTransform ~= nil then
        -- Let base SetStyle handle all props (yoga, transitions, merge)
        Widget.SetStyle(self, style)
        -- Rebuild cached display text from updated props
        self.displayText_ = applyTextTransform(self.props.text or "", self.props.textTransform)
        -- Multiline: reset cache to trigger height recalc
        if self.multiline_ then
            self.lastMultilineWidth_ = nil
            return self
        end
        -- Recalculate auto-width if needed
        if self.autoWidth_ and self.displayText_ ~= "" then
            local nvgFontSize = Theme.FontSize(self.props.fontSize)
            local fontFace = Theme.FontFace(self.props.fontFamily, self.props.fontWeight)
            local textWidth = UI.MeasureTextWidth(self.displayText_, nvgFontSize, fontFace, self.props.letterSpacing)
            if textWidth > 0 then
                self.measuredTextWidth_ = textWidth
                local pl, pr = getHorizontalPadding(self.props)
                Widget.SetWidth(self, textWidth + pl + pr)
            end
        end
        return self
    end
    return Widget.SetStyle(self, style)
end

-- ============================================================================
-- Text Manipulation
-- ============================================================================

--- Set text content
---@param text string
---@return Label self
function Label:SetText(text)
    -- Skip if text hasn't changed
    if self.props.text == text then
        return self
    end
    self.props.text = text

    -- Update cached display text
    self.displayText_ = applyTextTransform(text, self.props.textTransform)

    -- Multiline: reset cache to trigger height recalc in next Render
    if self.multiline_ then
        self.lastMultilineWidth_ = nil
        return self
    end

    -- Only recalculate width if it was auto-sized (no explicit width set by user).
    -- If user set width="100%" or width=200, we respect that and let text clip.
    if self.autoWidth_ then
        local nvgFontSize = Theme.FontSize(self.props.fontSize)
        local fontFace = Theme.FontFace(self.props.fontFamily, self.props.fontWeight)
        local textWidth = UI.MeasureTextWidth(self.displayText_, nvgFontSize, fontFace, self.props.letterSpacing)

        if textWidth > 0 then
            self.measuredTextWidth_ = textWidth
            local pl, pr = getHorizontalPadding(self.props)
            -- Use Widget.SetWidth directly to avoid triggering autoWidth_ = false
            Widget.SetWidth(self, textWidth + pl + pr)
        end
    end

    return self
end

--- Override SetWidth to disable auto-width recalculation in SetText
---@param width number Width in base pixels
---@return Label self
function Label:SetWidth(width)
    self.autoWidth_ = false
    if self.multiline_ then
        self.lastMultilineWidth_ = nil  -- Trigger height recalc
    end
    return Widget.SetWidth(self, width)
end

--- Override SetHeight to disable auto-height recalculation in multiline Render
---@param height number Height in base pixels
---@return Label self
function Label:SetHeight(height)
    self.autoHeight_ = false
    return Widget.SetHeight(self, height)
end

--- Get text content
---@return string
function Label:GetText()
    return self.props.text or ""
end

--- Set font size
---@param size number
---@return Label self
function Label:SetFontSize(size)
    self.props.fontSize = size

    -- Update baseline value for Yoga alignItems="baseline" alignment
    local nvgFontSize = Theme.FontSize(size)
    local fontFace = Theme.FontFace(self.props.fontFamily, self.props.fontWeight)
    local ascender = UI.MeasureTextBaseline(nvgFontSize, fontFace)
    local pt = self.props.paddingTop or self.props.paddingVertical or self.props.padding or 0
    YGNodeSetBaselineValue(self.node, pt + ascender)

    return self
end

--- Set font color
--- Supports multiple formats: RGBA table, hex string, or CSS rgb/rgba
---@param color table|string RGBA table or color string (e.g., "#ff0000", "rgba(255,0,0,1)")
---@return Label self
function Label:SetFontColor(color)
    self.props.fontColor = Style.ParseColor(color) or color
    return self
end

-- ============================================================================
-- Stateless
-- ============================================================================

function Label:IsStateful()
    return false
end

return Label
