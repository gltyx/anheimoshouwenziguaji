-- ============================================================================
-- TextField Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Text input field with cursor and selection
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

-- UTF-8 helper functions
local function utf8Len(str)
    local len = 0
    local i = 1
    while i <= #str do
        local byte = string.byte(str, i)
        if byte < 128 then
            i = i + 1
        elseif byte < 224 then
            i = i + 2
        elseif byte < 240 then
            i = i + 3
        else
            i = i + 4
        end
        len = len + 1
    end
    return len
end

-- Get byte position of the n-th UTF-8 character
local function utf8BytePos(str, charPos)
    if charPos <= 0 then return 0 end
    local bytePos = 0
    local charCount = 0
    local i = 1
    while i <= #str and charCount < charPos do
        local byte = string.byte(str, i)
        if byte < 128 then
            i = i + 1
        elseif byte < 224 then
            i = i + 2
        elseif byte < 240 then
            i = i + 3
        else
            i = i + 4
        end
        charCount = charCount + 1
        bytePos = i - 1
    end
    if charCount < charPos then
        return #str
    end
    return bytePos
end

-- Get UTF-8 substring by character positions (1-based, inclusive)
local function utf8Sub(str, startChar, endChar)
    local startByte = startChar <= 1 and 1 or (utf8BytePos(str, startChar - 1) + 1)
    local endByte = endChar and utf8BytePos(str, endChar) or #str
    return string.sub(str, startByte, endByte)
end

---@class TextFieldProps : WidgetProps
---@field value string|nil Current text value
---@field placeholder string|nil Placeholder text
---@field disabled boolean|nil Is input disabled
---@field password boolean|nil Show as password (dots)
---@field maxLength number|nil Maximum character length
---@field fontSize number|nil Font size
---@field onChange fun(self: TextField, value: string)|nil Value change callback
---@field onSubmit fun(self: TextField, value: string)|nil Submit callback (Enter key)
---@field onFocus fun(self: TextField)|nil Focus callback
---@field onBlur fun(self: TextField)|nil Blur callback

---@class TextField : Widget
---@operator call(TextFieldProps?): TextField
---@field props TextFieldProps
---@field new fun(self, props: TextFieldProps?): TextField
---@field state {focused: boolean, cursorPos: number, cursorBlink: boolean, selectionStart: number|nil, selectionEnd: number|nil}
local TextField = Widget:Extend("TextField")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props TextFieldProps?
function TextField:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("TextField")
    props.height = props.height or themeStyle.height or 40
    props.borderRadius = props.borderRadius or themeStyle.borderRadius or 4
    -- fontSize stored in pt, converted at render time
    props.fontSize = props.fontSize or themeStyle.fontSize or Theme.BaseFontSize("body")
    props.paddingHorizontal = props.paddingHorizontal or themeStyle.paddingHorizontal or 12

    -- Default value
    props.value = props.value or ""
    props.placeholder = props.placeholder or ""

    -- Initialize state (cursorPos is character position, not byte position)
    self.state = {
        focused = false,
        cursorPos = utf8Len(props.value or ""),
        cursorBlink = true,
        selectionStart = nil,
        selectionEnd = nil,
        scrollX = 0,  -- horizontal scroll offset for long text
    }

    -- Cursor blink timer
    self.blinkTimer_ = 0

    -- Cache for click-to-cursor calculation
    self.charPositions_ = {}  -- x positions of each character boundary
    self.textAreaX_ = 0       -- cached text area start x
    self.scrollX_ = 0         -- cached scroll offset for click calculation
    self.isDragging_ = false  -- is user dragging to select text

    Widget.Init(self, props)
end

-- Helper: Calculate cursor position from x coordinate
function TextField:GetCursorPosFromX(x)
    local textAreaX = self.textAreaX_ or 0
    local scrollX = self.scrollX_ or 0
    local charPositions = self.charPositions_ or { 0 }

    -- Convert x to text-relative position (accounting for scroll)
    local relativeX = x - textAreaX + scrollX

    -- Find the closest character boundary
    local cursorPos = 0
    local minDist = math.abs(relativeX - (charPositions[1] or 0))

    for i = 1, #charPositions do
        local charX = charPositions[i] or 0
        local dist = math.abs(relativeX - charX)
        if dist < minDist then
            minDist = dist
            cursorPos = i - 1  -- charPositions is 1-indexed, cursorPos is 0-indexed
        end
    end

    return cursorPos
end

-- Helper: Check if there is a selection
function TextField:HasSelection()
    local state = self.state
    return state.selectionStart ~= nil and state.selectionEnd ~= nil
        and state.selectionStart ~= state.selectionEnd
end

-- Helper: Get ordered selection range (start <= end)
function TextField:GetSelectionRange()
    local state = self.state
    if not self:HasSelection() then
        return nil, nil
    end
    local s, e = state.selectionStart, state.selectionEnd
    if s > e then
        s, e = e, s
    end
    return s, e
end

-- Helper: Delete selected text and return new value and cursor pos
function TextField:DeleteSelection()
    local value = self.props.value or ""
    local selStart, selEnd = self:GetSelectionRange()
    if not selStart then
        return value, self.state.cursorPos
    end

    local beforeSel = selStart > 0 and utf8Sub(value, 1, selStart) or ""
    local afterSel = utf8Sub(value, selEnd + 1)
    local newValue = beforeSel .. afterSel

    return newValue, selStart
end

-- Helper: Clear selection
function TextField:ClearSelection()
    self.state.selectionStart = nil
    self.state.selectionEnd = nil
end

-- ============================================================================
-- Rendering
-- ============================================================================

function TextField:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local disabled = props.disabled
    local focused = state.focused
    local value = props.value or ""
    local placeholder = props.placeholder or ""
    local isPassword = props.password

    -- Colors
    local bgColor = disabled and Theme.Color("disabled") or Theme.Color("surface")
    local borderColor = focused and Theme.Color("borderFocus") or Theme.Color("border")
    local textColor = disabled and Theme.Color("disabledText") or Theme.Color("text")
    local placeholderColor = Theme.Color("textSecondary")
    local borderRadius = props.borderRadius

    -- Draw background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
    nvgFill(nvg)

    -- Draw border
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
    nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 255))
    nvgStrokeWidth(nvg, focused and 2 or 1)
    nvgStroke(nvg)

    -- Set up text rendering
    local fontFamily = Theme.FontFamily()
    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, Theme.FontSize(props.fontSize))

    local padding = props.paddingHorizontal
    local textAreaX = l.x + padding
    local textAreaWidth = l.w - padding * 2
    local textY = l.y + l.h / 2

    -- Display text or placeholder
    local valueLen = utf8Len(value)
    local displayText = value
    if isPassword and valueLen > 0 then
        displayText = string.rep("●", valueLen)
    end

    -- Cache values for click-to-cursor calculation
    self.textAreaX_ = textAreaX

    if #displayText > 0 then
        -- Calculate and cache character positions for click-to-cursor
        -- nvgTextBounds returns base pixels (it internally handles scale conversion)
        local charPositions = { 0 }  -- position 0 is at x=0
        for i = 1, valueLen do
            local subText = isPassword
                and string.rep("●", i)
                or utf8Sub(value, 1, i)
            local charX = nvgTextBounds(nvg, 0, 0, subText)
            charPositions[i + 1] = charX
        end
        self.charPositions_ = charPositions

        -- Calculate cursor position for scrolling
        local cursorOffset = charPositions[state.cursorPos + 1] or 0

        -- Update scroll to keep cursor visible
        local scrollX = state.scrollX or 0
        if cursorOffset - scrollX > textAreaWidth then
            -- Cursor is past the right edge
            scrollX = cursorOffset - textAreaWidth + 2
        elseif cursorOffset < scrollX then
            -- Cursor is past the left edge
            scrollX = cursorOffset
        end
        -- Clamp scroll
        local totalTextWidth = charPositions[valueLen + 1] or 0
        local maxScroll = math.max(0, totalTextWidth - textAreaWidth)
        scrollX = math.max(0, math.min(scrollX, maxScroll))
        state.scrollX = scrollX
        self.scrollX_ = scrollX  -- cache for click calculation

        -- Clip text area
        nvgSave(nvg)
        nvgIntersectScissor(nvg, textAreaX, l.y, textAreaWidth, l.h)

        -- Draw selection highlight
        if self:HasSelection() then
            local selStart, selEnd = self:GetSelectionRange()
            local selStartX = charPositions[selStart + 1] or 0
            local selEndX = charPositions[selEnd + 1] or 0

            local selectionColor = Theme.Color("primary") or { 66, 133, 244, 100 }
            nvgBeginPath(nvg)
            nvgRect(nvg,
                textAreaX + selStartX - scrollX,
                l.y + 6,
                selEndX - selStartX,
                l.h - 12
            )
            nvgFillColor(nvg, nvgRGBA(selectionColor[1], selectionColor[2], selectionColor[3], 100))
            nvgFill(nvg)
        end

        -- Draw text with scroll offset
        nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(nvg, textAreaX - scrollX, textY, displayText, nil)

        -- Draw cursor if focused
        if focused and state.cursorBlink then
            local cursorX = textAreaX + cursorOffset - scrollX

            -- Draw cursor line
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cursorX, l.y + 8)
            nvgLineTo(nvg, cursorX, l.y + l.h - 8)
            nvgStrokeColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], 255))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
        end

        nvgRestore(nvg)
    else
        -- Clear char positions cache for empty text
        self.charPositions_ = { 0 }
        self.scrollX_ = 0
        -- Draw placeholder
        nvgFillColor(nvg, nvgRGBA(placeholderColor[1], placeholderColor[2], placeholderColor[3], placeholderColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(nvg, textAreaX, textY, placeholder, nil)

        -- Draw cursor at start if focused
        if focused and state.cursorBlink then
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, textAreaX, l.y + 8)
            nvgLineTo(nvg, textAreaX, l.y + l.h - 8)
            nvgStrokeColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], 255))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
        end
    end
end

-- ============================================================================
-- Update (for cursor blink)
-- ============================================================================

function TextField:Update(dt)
    if self.state.focused then
        self.blinkTimer_ = self.blinkTimer_ + dt
        if self.blinkTimer_ >= 0.5 then
            self.blinkTimer_ = 0
            self.state.cursorBlink = not self.state.cursorBlink
        end
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function TextField:OnFocus()
    if not self.props.disabled then
        self:SetState({ focused = true, cursorBlink = true })
        self.blinkTimer_ = 0
        -- Enable text input (SDL_StartTextInput)
        if input then
            input:SetScreenKeyboardVisible(true)
        end
    end
    if self.props.onFocus then
        self.props.onFocus(self)
    end
end

function TextField:OnBlur()
    self:SetState({ focused = false })
    -- Disable text input (SDL_StopTextInput)
    if input then
        input:SetScreenKeyboardVisible(false)
    end
    if self.props.onBlur then
        self.props.onBlur(self)
    end
end

function TextField:OnKeyDown(key)
    if not self.state.focused or self.props.disabled then return end

    local value = self.props.value or ""
    local cursorPos = self.state.cursorPos  -- character position
    local valueLen = utf8Len(value)
    local hasSelection = self:HasSelection()

    -- Check for Ctrl modifier
    local ctrlDown = input and input:GetQualifierDown(QUAL_CTRL)

    -- Handle Ctrl+A (Select All)
    if ctrlDown and key == KEY_A then
        self:SelectAll()
        return
    end

    -- Handle Ctrl+C (Copy)
    if ctrlDown and key == KEY_C then
        if self:HasSelection() then
            local selStart, selEnd = self:GetSelectionRange()
            local selectedText = utf8Sub(value, selStart + 1, selEnd)
            ui:SetClipboardText(selectedText)
        end
        return
    end

    -- Handle Ctrl+X (Cut)
    if ctrlDown and key == KEY_X then
        if self:HasSelection() then
            local selStart, selEnd = self:GetSelectionRange()
            local selectedText = utf8Sub(value, selStart + 1, selEnd)
            ui:SetClipboardText(selectedText)
            local newValue, newCursorPos = self:DeleteSelection()
            self:SetValue(newValue)
            self:SetState({ cursorPos = newCursorPos })
            self:ClearSelection()
        end
        return
    end

    -- Handle Ctrl+V (Paste)
    if ctrlDown and key == KEY_V then
        local clipText = ui:GetClipboardText()
        if clipText and #clipText > 0 then
            self:OnTextInput(clipText)
        end
        return
    end

    -- Handle special keys
    if key == KEY_BACKSPACE then
        if hasSelection then
            -- Delete selected text
            local newValue, newCursorPos = self:DeleteSelection()
            self:SetValue(newValue)
            self:SetState({ cursorPos = newCursorPos })
            self:ClearSelection()
        elseif cursorPos > 0 then
            -- Delete character before cursor (UTF-8 aware)
            local beforeCursor = cursorPos > 1 and utf8Sub(value, 1, cursorPos - 1) or ""
            local afterCursor = cursorPos < valueLen and utf8Sub(value, cursorPos + 1) or ""
            local newValue = beforeCursor .. afterCursor
            self:SetValue(newValue)
            self:SetState({ cursorPos = cursorPos - 1 })
        end
    elseif key == KEY_DELETE then
        if hasSelection then
            -- Delete selected text
            local newValue, newCursorPos = self:DeleteSelection()
            self:SetValue(newValue)
            self:SetState({ cursorPos = newCursorPos })
            self:ClearSelection()
        elseif cursorPos < valueLen then
            -- Delete character after cursor (UTF-8 aware)
            local beforeCursor = cursorPos > 0 and utf8Sub(value, 1, cursorPos) or ""
            local afterCursor = cursorPos + 1 < valueLen and utf8Sub(value, cursorPos + 2) or ""
            local newValue = beforeCursor .. afterCursor
            self:SetValue(newValue)
        end
    elseif key == KEY_LEFT then
        if hasSelection then
            -- Move cursor to start of selection
            local selStart, _ = self:GetSelectionRange()
            self:SetState({ cursorPos = selStart, cursorBlink = true })
            self:ClearSelection()
        elseif cursorPos > 0 then
            self:SetState({ cursorPos = cursorPos - 1, cursorBlink = true })
        end
        self.blinkTimer_ = 0
    elseif key == KEY_RIGHT then
        if hasSelection then
            -- Move cursor to end of selection
            local _, selEnd = self:GetSelectionRange()
            self:SetState({ cursorPos = selEnd, cursorBlink = true })
            self:ClearSelection()
        elseif cursorPos < valueLen then
            self:SetState({ cursorPos = cursorPos + 1, cursorBlink = true })
        end
        self.blinkTimer_ = 0
    elseif key == KEY_HOME then
        self:ClearSelection()
        self:SetState({ cursorPos = 0, cursorBlink = true })
        self.blinkTimer_ = 0
    elseif key == KEY_END then
        self:ClearSelection()
        self:SetState({ cursorPos = valueLen, cursorBlink = true })
        self.blinkTimer_ = 0
    elseif key == KEY_RETURN or key == KEY_KP_ENTER then
        if self.props.onSubmit then
            self.props.onSubmit(self, value)
        end
    end
end

function TextField:OnTextInput(text)
    if not self.state.focused or self.props.disabled then
        return
    end

    local value = self.props.value or ""
    local cursorPos = self.state.cursorPos  -- character position
    local maxLength = self.props.maxLength

    -- If there's a selection, delete it first
    if self:HasSelection() then
        value, cursorPos = self:DeleteSelection()
        self:ClearSelection()
    end

    local valueLen = utf8Len(value)

    -- Check max length (in characters)
    if maxLength and valueLen >= maxLength then
        return
    end

    -- Insert text at cursor position (using UTF-8 aware functions)
    local beforeCursor = cursorPos > 0 and utf8Sub(value, 1, cursorPos) or ""
    local afterCursor = cursorPos < valueLen and utf8Sub(value, cursorPos + 1) or ""
    local newValue = beforeCursor .. text .. afterCursor

    -- Apply max length (in characters)
    local textCharLen = utf8Len(text)
    if maxLength and utf8Len(newValue) > maxLength then
        newValue = utf8Sub(newValue, 1, maxLength)
        textCharLen = maxLength - valueLen
    end

    self:SetValue(newValue)
    local newCursorPos = cursorPos + textCharLen
    self:SetState({ cursorPos = newCursorPos, cursorBlink = true })
    self.blinkTimer_ = 0
end

function TextField:OnPointerDown(event)
    Widget.OnPointerDown(self, event)

    if not self.props.disabled then
        local newCursorPos = self:GetCursorPosFromX(event.x)

        -- Start selection
        self.isDragging_ = true
        self:SetState({
            cursorPos = newCursorPos,
            selectionStart = newCursorPos,
            selectionEnd = newCursorPos,
            cursorBlink = true
        })
        self.blinkTimer_ = 0
    end
end

function TextField:OnPointerMove(event)
    if self.isDragging_ and not self.props.disabled then
        local newCursorPos = self:GetCursorPosFromX(event.x)

        -- Update selection end and cursor position
        self:SetState({
            cursorPos = newCursorPos,
            selectionEnd = newCursorPos,
            cursorBlink = true
        })
        self.blinkTimer_ = 0
    end
end

function TextField:OnPointerUp(event)
    Widget.OnPointerUp(self, event)
    self.isDragging_ = false

    -- If selection start equals end, clear selection
    if self.state.selectionStart == self.state.selectionEnd then
        self:ClearSelection()
    end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set the text value
---@param value string
---@return TextField self
function TextField:SetValue(value)
    local oldValue = self.props.value
    self.props.value = value

    if value ~= oldValue and self.props.onChange then
        self.props.onChange(self, value)
    end

    return self
end

--- Get the text value
---@return string
function TextField:GetValue()
    return self.props.value or ""
end

--- Set placeholder text
---@param placeholder string
---@return TextField self
function TextField:SetPlaceholder(placeholder)
    self.props.placeholder = placeholder
    return self
end

--- Set disabled state
---@param disabled boolean
---@return TextField self
function TextField:SetDisabled(disabled)
    self.props.disabled = disabled
    if disabled then
        self:SetState({ focused = false })
    end
    return self
end

--- Clear the text
---@return TextField self
function TextField:Clear()
    self:SetValue("")
    self:SetState({ cursorPos = 0 })
    return self
end

--- Select all text
function TextField:SelectAll()
    local value = self.props.value or ""
    local valueLen = utf8Len(value)
    self:SetState({
        selectionStart = 0,
        selectionEnd = valueLen,
        cursorPos = valueLen,
    })
end

--- Alias for SetValue (for API consistency with Label)
---@param text string
---@return TextField self
function TextField:SetText(text)
    return self:SetValue(text)
end

--- Alias for GetValue (for API consistency with Label)
---@return string
function TextField:GetText()
    return self:GetValue()
end

-- ============================================================================
-- Stateful
-- ============================================================================

function TextField:IsStateful()
    return true
end

return TextField
