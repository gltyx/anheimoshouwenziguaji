-- ============================================================================
-- DatePicker Widget
-- Date selection with calendar popup
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local UI = require("urhox-libs/UI/Core/UI")

---@class DatePickerProps : WidgetProps
---@field size string|nil "sm" | "md" | "lg" (default: "md")
---@field placeholder string|nil Placeholder text (default: "Select date")
---@field format string|nil Date format string (default: "yyyy-mm-dd")
---@field variant string|nil "outlined" | "filled" | "standard" (default: "outlined")
---@field disabled boolean|nil Disable the picker
---@field readOnly boolean|nil Read-only mode
---@field minDate table|nil Minimum date {year, month, day}
---@field maxDate table|nil Maximum date {year, month, day}
---@field selectionMode string|nil "single" | "range" | "multiple" (default: "single")
---@field value table|nil Initial value {year, month, day}
---@field selectedDate table|nil Alias for value
---@field rangeStart table|nil Range start date
---@field rangeEnd table|nil Range end date
---@field selectedDates table[]|nil Multiple selected dates
---@field primaryColor table|nil Primary color override
---@field fontSize number|nil Custom font size
---@field cellSize number|nil Calendar cell size
---@field headerSize number|nil Calendar header font size
---@field onChange fun(picker: DatePicker, value: table)|nil Value change callback
---@field onOpen fun(picker: DatePicker)|nil Open callback
---@field onClose fun(picker: DatePicker)|nil Close callback

---@class DatePicker : Widget
---@operator call(DatePickerProps?): DatePicker
---@field props DatePickerProps
---@field new fun(self, props: DatePickerProps?): DatePicker
local DatePicker = Widget:Extend("DatePicker")

-- ============================================================================
-- Size presets
-- ============================================================================

local SIZE_PRESETS = {
    sm = { height = 28, fontSize = 12, padding = 8, cellSize = 24, headerSize = 13 },
    md = { height = 36, fontSize = 14, padding = 12, cellSize = 32, headerSize = 15 },
    lg = { height = 44, fontSize = 16, padding = 16, cellSize = 40, headerSize = 17 },
}

-- ============================================================================
-- Date utilities
-- ============================================================================

local function getDaysInMonth(year, month)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 then
        -- Leap year check
        if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
            return 29
        end
    end
    return days[month]
end

local function getFirstDayOfMonth(year, month)
    -- Returns 0=Sunday, 1=Monday, ..., 6=Saturday
    local t = os.time({ year = year, month = month, day = 1 })
    return tonumber(os.date("%w", t))
end

local function formatDate(year, month, day, format)
    format = format or "yyyy-mm-dd"
    local result = format
    result = result:gsub("yyyy", string.format("%04d", year))
    result = result:gsub("yy", string.format("%02d", year % 100))
    result = result:gsub("mm", string.format("%02d", month))
    result = result:gsub("m", tostring(month))
    result = result:gsub("dd", string.format("%02d", day))
    result = result:gsub("d", tostring(day))
    return result
end

local function parseDate(dateStr)
    local year, month, day = dateStr:match("(%d+)-(%d+)-(%d+)")
    if year and month and day then
        return tonumber(year), tonumber(month), tonumber(day)
    end
    return nil, nil, nil
end

local function compareDates(y1, m1, d1, y2, m2, d2)
    if y1 ~= y2 then return y1 - y2 end
    if m1 ~= m2 then return m1 - m2 end
    return d1 - d2
end

local MONTH_NAMES = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
}

local MONTH_NAMES_SHORT = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
}

local WEEKDAY_NAMES = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props DatePickerProps?
function DatePicker:Init(props)
    props = props or {}

    -- DatePicker props
    self.size_ = props.size or "md"
    self.placeholder_ = props.placeholder or "Select date"
    self.format_ = props.format or "yyyy-mm-dd"
    self.variant_ = props.variant or "outlined"  -- outlined, filled, standard
    self.disabled_ = props.disabled or false
    self.readOnly_ = props.readOnly or false

    -- Date constraints
    self.minDate_ = props.minDate  -- { year, month, day }
    self.maxDate_ = props.maxDate

    -- Selection mode
    self.selectionMode_ = props.selectionMode or "single"  -- single, range, multiple

    -- Initial value
    self.selectedDate_ = props.value or props.selectedDate  -- { year, month, day }
    self.rangeStart_ = props.rangeStart
    self.rangeEnd_ = props.rangeEnd
    self.selectedDates_ = props.selectedDates or {}  -- For multiple mode

    -- Display state
    local now = os.date("*t")
    self.viewYear_ = self.selectedDate_ and self.selectedDate_.year or now.year
    self.viewMonth_ = self.selectedDate_ and self.selectedDate_.month or now.month

    -- UI state
    self.isOpen_ = false
    self.hoverDay_ = nil
    self.hoverNav_ = nil  -- "prev", "next", "month", "year"

    -- Callbacks
    self.onChange_ = props.onChange
    self.onOpen_ = props.onOpen
    self.onClose_ = props.onClose

    -- Colors
    self.primaryColor_ = props.primaryColor or Theme.Color("primary")

    -- Calculate dimensions
    local sizePreset = SIZE_PRESETS[self.size_] or SIZE_PRESETS.md
    self.inputHeight_ = props.height or sizePreset.height
    self.fontSize_ = props.fontSize or Theme.FontSize(sizePreset.fontSize)
    self.padding_ = props.padding or sizePreset.padding
    self.cellSize_ = props.cellSize or sizePreset.cellSize
    self.headerSize_ = props.headerSize or sizePreset.headerSize

    -- Calendar dimensions
    self.calendarWidth_ = self.cellSize_ * 7 + 16
    self.calendarHeight_ = self.cellSize_ * 7 + 60  -- Header + weekdays + 6 rows

    props.width = props.width or 200
    props.height = self.inputHeight_

    Widget.Init(self, props)
end

-- ============================================================================
-- Date Management
-- ============================================================================

function DatePicker:GetValue()
    if self.selectionMode_ == "range" then
        return { start = self.rangeStart_, ["end"] = self.rangeEnd_ }
    elseif self.selectionMode_ == "multiple" then
        return self.selectedDates_
    else
        return self.selectedDate_
    end
end

function DatePicker:SetValue(value)
    if self.selectionMode_ == "range" then
        self.rangeStart_ = value and value.start
        self.rangeEnd_ = value and value["end"]
    elseif self.selectionMode_ == "multiple" then
        self.selectedDates_ = value or {}
    else
        self.selectedDate_ = value
        if value then
            self.viewYear_ = value.year
            self.viewMonth_ = value.month
        end
    end
end

function DatePicker:Clear()
    self.selectedDate_ = nil
    self.rangeStart_ = nil
    self.rangeEnd_ = nil
    self.selectedDates_ = {}
end

function DatePicker:IsDateDisabled(year, month, day)
    if self.minDate_ then
        if compareDates(year, month, day, self.minDate_.year, self.minDate_.month, self.minDate_.day) < 0 then
            return true
        end
    end
    if self.maxDate_ then
        if compareDates(year, month, day, self.maxDate_.year, self.maxDate_.month, self.maxDate_.day) > 0 then
            return true
        end
    end
    return false
end

function DatePicker:IsDateSelected(year, month, day)
    if self.selectionMode_ == "single" then
        if self.selectedDate_ then
            return self.selectedDate_.year == year and
                   self.selectedDate_.month == month and
                   self.selectedDate_.day == day
        end
    elseif self.selectionMode_ == "range" then
        if self.rangeStart_ and self.rangeEnd_ then
            local cmpStart = compareDates(year, month, day, self.rangeStart_.year, self.rangeStart_.month, self.rangeStart_.day)
            local cmpEnd = compareDates(year, month, day, self.rangeEnd_.year, self.rangeEnd_.month, self.rangeEnd_.day)
            return cmpStart >= 0 and cmpEnd <= 0
        elseif self.rangeStart_ then
            return self.rangeStart_.year == year and
                   self.rangeStart_.month == month and
                   self.rangeStart_.day == day
        end
    elseif self.selectionMode_ == "multiple" then
        for _, date in ipairs(self.selectedDates_) do
            if date.year == year and date.month == month and date.day == day then
                return true
            end
        end
    end
    return false
end

function DatePicker:IsRangeEdge(year, month, day)
    if self.selectionMode_ ~= "range" then return false, false end

    local isStart = self.rangeStart_ and
                    self.rangeStart_.year == year and
                    self.rangeStart_.month == month and
                    self.rangeStart_.day == day
    local isEnd = self.rangeEnd_ and
                  self.rangeEnd_.year == year and
                  self.rangeEnd_.month == month and
                  self.rangeEnd_.day == day

    return isStart, isEnd
end

function DatePicker:SelectDate(year, month, day)
    if self:IsDateDisabled(year, month, day) then return end

    if self.selectionMode_ == "single" then
        self.selectedDate_ = { year = year, month = month, day = day }
        self.isOpen_ = false
        if self.onClose_ then self.onClose_(self) end
    elseif self.selectionMode_ == "range" then
        if not self.rangeStart_ or (self.rangeStart_ and self.rangeEnd_) then
            -- Start new range
            self.rangeStart_ = { year = year, month = month, day = day }
            self.rangeEnd_ = nil
        else
            -- Complete range
            local cmp = compareDates(year, month, day, self.rangeStart_.year, self.rangeStart_.month, self.rangeStart_.day)
            if cmp < 0 then
                -- Selected before start, swap
                self.rangeEnd_ = self.rangeStart_
                self.rangeStart_ = { year = year, month = month, day = day }
            else
                self.rangeEnd_ = { year = year, month = month, day = day }
            end
            self.isOpen_ = false
            if self.onClose_ then self.onClose_(self) end
        end
    elseif self.selectionMode_ == "multiple" then
        -- Toggle selection
        local found = false
        for i, date in ipairs(self.selectedDates_) do
            if date.year == year and date.month == month and date.day == day then
                table.remove(self.selectedDates_, i)
                found = true
                break
            end
        end
        if not found then
            table.insert(self.selectedDates_, { year = year, month = month, day = day })
        end
    end

    if self.onChange_ then
        self.onChange_(self, self:GetValue())
    end
end

-- ============================================================================
-- Navigation
-- ============================================================================

function DatePicker:PrevMonth()
    self.viewMonth_ = self.viewMonth_ - 1
    if self.viewMonth_ < 1 then
        self.viewMonth_ = 12
        self.viewYear_ = self.viewYear_ - 1
    end
end

function DatePicker:NextMonth()
    self.viewMonth_ = self.viewMonth_ + 1
    if self.viewMonth_ > 12 then
        self.viewMonth_ = 1
        self.viewYear_ = self.viewYear_ + 1
    end
end

function DatePicker:PrevYear()
    self.viewYear_ = self.viewYear_ - 1
end

function DatePicker:NextYear()
    self.viewYear_ = self.viewYear_ + 1
end

function DatePicker:GoToToday()
    local now = os.date("*t")
    self.viewYear_ = now.year
    self.viewMonth_ = now.month
end

-- ============================================================================
-- Popup Control
-- ============================================================================

function DatePicker:Open()
    if self.disabled_ or self.readOnly_ then return end
    self.isOpen_ = true
    UI.PushOverlay(self)
    if self.onOpen_ then self.onOpen_(self) end
end

function DatePicker:Close()
    self.isOpen_ = false
    self.hoverDay_ = nil
    UI.PopOverlay(self)
    if self.onClose_ then self.onClose_(self) end
end

function DatePicker:Toggle()
    if self.isOpen_ then
        self:Close()
    else
        self:Open()
    end
end

function DatePicker:IsOpen()
    return self.isOpen_
end

-- ============================================================================
-- Display Text
-- ============================================================================

function DatePicker:GetDisplayText()
    if self.selectionMode_ == "single" then
        if self.selectedDate_ then
            return formatDate(self.selectedDate_.year, self.selectedDate_.month, self.selectedDate_.day, self.format_)
        end
    elseif self.selectionMode_ == "range" then
        if self.rangeStart_ and self.rangeEnd_ then
            local startStr = formatDate(self.rangeStart_.year, self.rangeStart_.month, self.rangeStart_.day, self.format_)
            local endStr = formatDate(self.rangeEnd_.year, self.rangeEnd_.month, self.rangeEnd_.day, self.format_)
            return startStr .. " - " .. endStr
        elseif self.rangeStart_ then
            return formatDate(self.rangeStart_.year, self.rangeStart_.month, self.rangeStart_.day, self.format_) .. " - ..."
        end
    elseif self.selectionMode_ == "multiple" then
        local count = #self.selectedDates_
        if count > 0 then
            return count .. " date" .. (count > 1 and "s" or "") .. " selected"
        end
    end
    return nil
end

-- ============================================================================
-- Render
-- ============================================================================

function DatePicker:Render(nvg)
    local x, y = self:GetAbsolutePosition()
    local w, h = self:GetComputedSize()
    local theme = Theme.GetTheme()

    -- Store positions for hit testing (use HitTest coords for consistency with overlay)
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    self.inputBounds_ = { x = hitTest.x, y = hitTest.y, w = hitTest.w, h = hitTest.h }

    -- Determine colors
    local bgColor, borderColor, textColor

    if self.disabled_ then
        bgColor = Theme.NvgColor("surfaceDisabled")
        borderColor = Theme.NvgColor("borderDisabled")
        textColor = Theme.NvgColor("textDisabled")
    else
        bgColor = Theme.NvgColor("surface")
        borderColor = self.isOpen_ and Theme.ToNvgColor(self.primaryColor_) or Theme.NvgColor("border")
        textColor = Theme.NvgColor("text")
    end

    -- Draw input field
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, Theme.Radius("sm"))

    if self.variant_ == "filled" then
        nvgFillColor(nvg, Theme.NvgColor("surfaceVariant"))
        nvgFill(nvg)
    elseif self.variant_ == "outlined" then
        nvgFillColor(nvg, bgColor)
        nvgFill(nvg)
        nvgStrokeColor(nvg, borderColor)
        nvgStrokeWidth(nvg, self.isOpen_ and 2 or 1)
        nvgStroke(nvg)
    else  -- standard
        -- Bottom border only
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, y + h)
        nvgLineTo(nvg, x + w, y + h)
        nvgStrokeColor(nvg, borderColor)
        nvgStrokeWidth(nvg, self.isOpen_ and 2 or 1)
        nvgStroke(nvg)
    end

    -- Draw text
    local displayText = self:GetDisplayText()
    nvgFontSize(nvg, self.fontSize_)
    nvgFontFace(nvg, Theme.FontFamily())
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    if displayText then
        nvgFillColor(nvg, textColor)
        nvgText(nvg, x + self.padding_, y + h / 2, displayText)
    else
        nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
        nvgText(nvg, x + self.padding_, y + h / 2, self.placeholder_)
    end

    -- Draw calendar icon
    local iconX = x + w - self.padding_ - 12
    local iconY = y + h / 2
    nvgFontSize(nvg, self.fontSize_)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
    nvgText(nvg, iconX, iconY, "📅")

    -- Draw dropdown arrow
    local arrowX = x + w - self.padding_ / 2
    nvgBeginPath(nvg)
    if self.isOpen_ then
        nvgMoveTo(nvg, arrowX - 4, iconY + 2)
        nvgLineTo(nvg, arrowX, iconY - 2)
        nvgLineTo(nvg, arrowX + 4, iconY + 2)
    else
        nvgMoveTo(nvg, arrowX - 4, iconY - 2)
        nvgLineTo(nvg, arrowX, iconY + 2)
        nvgLineTo(nvg, arrowX + 4, iconY - 2)
    end
    nvgStrokeColor(nvg, Theme.NvgColor("textSecondary"))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- Queue calendar popup to render as overlay (on top of everything)
    if self.isOpen_ then
        UI.QueueOverlay(function(nvg_)
            self:RenderCalendar(nvg_)
        end)
    end
end

function DatePicker:RenderCalendar(nvg)
    -- Use GetAbsoluteLayoutForHitTest because overlay renders outside ScrollView's nvgTranslate
    local l = self:GetAbsoluteLayoutForHitTest()
    local px = l.x
    local py = l.y + l.h + 4  -- Position below input field

    local theme = Theme.GetTheme()

    -- Dimensions (no scale needed - nvgScale handles it)
    local cellSize = self.cellSize_
    local calW = cellSize * 7 + 16
    local calH = cellSize * 7 + 60
    local borderRadius = 8
    local contentPadding = 8
    local headerH = 32
    local navBtnSize = 24
    local navBtnRadius = 14
    local navBtnIconOffset = 12

    -- Store calendar bounds
    self.calendarBounds_ = { x = px, y = py, w = calW, h = calH }

    -- Shadow
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px + 2, py + 2, calW, calH, borderRadius)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
    nvgFill(nvg)

    -- Background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px, py, calW, calH, borderRadius)
    nvgFillColor(nvg, Theme.NvgColor("surface"))
    nvgFill(nvg)
    nvgStrokeColor(nvg, Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    local contentX = px + contentPadding
    local contentY = py + contentPadding

    -- Header: Month Year navigation
    local headerY = contentY

    -- Prev button
    local prevX = contentX
    local prevHover = self.hoverNav_ == "prev"
    if prevHover then
        nvgBeginPath(nvg)
        nvgCircle(nvg, prevX + navBtnIconOffset, headerY + headerH / 2, navBtnRadius)
        nvgFillColor(nvg, Theme.NvgColor("surfaceHover"))
        nvgFill(nvg)
    end
    nvgFontSize(nvg, Theme.FontSizeOf("bodyLarge"))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, Theme.NvgColor("text"))
    nvgText(nvg, prevX + navBtnIconOffset, headerY + headerH / 2, "◀")
    self.prevBtnBounds_ = { x = prevX, y = headerY, w = navBtnSize, h = headerH }

    -- Next button
    local nextX = px + calW - 32
    local nextHover = self.hoverNav_ == "next"
    if nextHover then
        nvgBeginPath(nvg)
        nvgCircle(nvg, nextX + navBtnIconOffset, headerY + headerH / 2, navBtnRadius)
        nvgFillColor(nvg, Theme.NvgColor("surfaceHover"))
        nvgFill(nvg)
    end
    nvgText(nvg, nextX + navBtnIconOffset, headerY + headerH / 2, "▶")
    self.nextBtnBounds_ = { x = nextX, y = headerY, w = navBtnSize, h = headerH }

    -- Month Year text
    local monthYearText = MONTH_NAMES[self.viewMonth_] .. " " .. self.viewYear_
    nvgFontSize(nvg, Theme.FontSize(self.headerSize_))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, Theme.NvgColor("text"))
    nvgText(nvg, px + calW / 2, headerY + headerH / 2, monthYearText)

    -- Weekday headers
    local weekdayY = headerY + headerH + 4
    nvgFontSize(nvg, self.fontSize_ * 0.85)
    nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)

    for i, dayName in ipairs(WEEKDAY_NAMES) do
        local dayX = contentX + (i - 1) * cellSize + cellSize / 2
        nvgText(nvg, dayX, weekdayY + cellSize / 2, dayName)
    end

    -- Calendar grid
    local gridY = weekdayY + cellSize
    local daysInMonth = getDaysInMonth(self.viewYear_, self.viewMonth_)
    local firstDay = getFirstDayOfMonth(self.viewYear_, self.viewMonth_)
    local today = os.date("*t")
    local cellPadding = 2

    self.dayCells_ = {}
    local day = 1
    local row = 0

    while day <= daysInMonth do
        for col = 0, 6 do
            if row == 0 and col < firstDay then
                -- Empty cell before month starts
            elseif day <= daysInMonth then
                local cellX = contentX + col * cellSize
                local cellY = gridY + row * cellSize
                local centerX = cellX + cellSize / 2
                local centerY = cellY + cellSize / 2

                local isSelected = self:IsDateSelected(self.viewYear_, self.viewMonth_, day)
                local isDisabled = self:IsDateDisabled(self.viewYear_, self.viewMonth_, day)
                local isToday = today.year == self.viewYear_ and today.month == self.viewMonth_ and today.day == day
                local isHovered = self.hoverDay_ == day
                local isStart, isEnd = self:IsRangeEdge(self.viewYear_, self.viewMonth_, day)

                -- Store cell bounds
                self.dayCells_[day] = { x = cellX, y = cellY, w = cellSize, h = cellSize }

                -- Draw range highlight (between start and end)
                if self.selectionMode_ == "range" and isSelected and not isStart and not isEnd then
                    nvgBeginPath(nvg)
                    nvgRect(nvg, cellX, cellY + cellPadding, cellSize, cellSize - cellPadding * 2)
                    local pc = self.primaryColor_
                    if type(pc) == "table" then
                        nvgFillColor(nvg, nvgRGBA(pc[1] or 0, pc[2] or 0, pc[3] or 0, 50))
                    else
                        nvgFillColor(nvg, nvgTransRGBAf(pc, 0.2))
                    end
                    nvgFill(nvg)
                end

                -- Draw selection/hover circle
                if isSelected or isHovered then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, centerX, centerY, cellSize / 2 - cellPadding)

                    if isSelected then
                        nvgFillColor(nvg, Theme.ToNvgColor(self.primaryColor_))
                    else
                        nvgFillColor(nvg, Theme.NvgColor("surfaceHover"))
                    end
                    nvgFill(nvg)
                end

                -- Draw today indicator
                if isToday and not isSelected then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, centerX, centerY, cellSize / 2 - cellPadding)
                    nvgStrokeColor(nvg, Theme.ToNvgColor(self.primaryColor_))
                    nvgStrokeWidth(nvg, 1)
                    nvgStroke(nvg)
                end

                -- Draw day number
                nvgFontSize(nvg, self.fontSize_)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)

                if isDisabled then
                    nvgFillColor(nvg, Theme.NvgColor("textDisabled"))
                elseif isSelected then
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                elseif isToday then
                    nvgFillColor(nvg, Theme.ToNvgColor(self.primaryColor_))
                else
                    nvgFillColor(nvg, Theme.NvgColor("text"))
                end

                nvgText(nvg, centerX, centerY, tostring(day))

                day = day + 1
            end
        end
        row = row + 1
    end

    -- Today button
    local todayBtnY = gridY + 6 * cellSize + 4
    local todayBtnW = 60
    local todayBtnH = 24
    local todayBtnX = px + (calW - todayBtnW) / 2
    local todayBtnRadius = 4

    local todayHover = self.hoverNav_ == "today"
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, todayBtnX, todayBtnY, todayBtnW, todayBtnH, todayBtnRadius)
    if todayHover then
        nvgFillColor(nvg, Theme.NvgColor("surfaceHover"))
    else
        nvgFillColor(nvg, Theme.NvgColor("surfaceVariant"))
    end
    nvgFill(nvg)

    nvgFontSize(nvg, self.fontSize_ * 0.9)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, Theme.ToNvgColor(self.primaryColor_))
    nvgText(nvg, todayBtnX + todayBtnW / 2, todayBtnY + todayBtnH / 2, "Today")

    self.todayBtnBounds_ = { x = todayBtnX, y = todayBtnY, w = todayBtnW, h = todayBtnH }
end

-- ============================================================================
-- Input Handling
-- ============================================================================

function DatePicker:PointInBounds(px, py, bounds)
    if not bounds then return false end
    return px >= bounds.x and px <= bounds.x + bounds.w and
           py >= bounds.y and py <= bounds.y + bounds.h
end

function DatePicker:HitTest(x, y)
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

function DatePicker:OnPointerMove(event)
    if not event then return end
    if not self.isOpen_ then return end

    -- Use event coords directly (all bounds are in HitTest coords)
    local px = event.x
    local py = event.y

    -- Check navigation buttons
    self.hoverNav_ = nil
    if self:PointInBounds(px, py, self.prevBtnBounds_) then
        self.hoverNav_ = "prev"
    elseif self:PointInBounds(px, py, self.nextBtnBounds_) then
        self.hoverNav_ = "next"
    elseif self:PointInBounds(px, py, self.todayBtnBounds_) then
        self.hoverNav_ = "today"
    end

    -- Check day cells
    self.hoverDay_ = nil
    if self.dayCells_ then
        for day, bounds in pairs(self.dayCells_) do
            if self:PointInBounds(px, py, bounds) then
                self.hoverDay_ = day
                break
            end
        end
    end
end

function DatePicker:OnMouseLeave(event)
    self.hoverDay_ = nil
    self.hoverNav_ = nil
end

function DatePicker:OnClick(event)
    if not event then return end

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

    -- Check if clicking outside calendar
    if not self:PointInBounds(px, py, self.calendarBounds_) then
        self:Close()
        return true
    end

    -- Check navigation buttons
    if self:PointInBounds(px, py, self.prevBtnBounds_) then
        self:PrevMonth()
        return true
    elseif self:PointInBounds(px, py, self.nextBtnBounds_) then
        self:NextMonth()
        return true
    elseif self:PointInBounds(px, py, self.todayBtnBounds_) then
        self:GoToToday()
        return true
    end

    -- Check day cells
    if self.dayCells_ then
        for day, bounds in pairs(self.dayCells_) do
            if self:PointInBounds(px, py, bounds) then
                self:SelectDate(self.viewYear_, self.viewMonth_, day)
                return true
            end
        end
    end

    return false
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a basic date picker
---@param props table|nil
---@return DatePicker
function DatePicker.Basic(props)
    return DatePicker(props)
end

--- Create a date range picker
---@param props table|nil
---@return DatePicker
function DatePicker.Range(props)
    props = props or {}
    props.selectionMode = "range"
    props.placeholder = props.placeholder or "Select date range"
    return DatePicker(props)
end

--- Create a multi-date picker
---@param props table|nil
---@return DatePicker
function DatePicker.Multiple(props)
    props = props or {}
    props.selectionMode = "multiple"
    props.placeholder = props.placeholder or "Select dates"
    return DatePicker(props)
end

--- Create a birthday picker
---@param props table|nil
---@return DatePicker
function DatePicker.Birthday(props)
    props = props or {}
    props.placeholder = props.placeholder or "Select birthday"
    props.format = props.format or "mm/dd/yyyy"
    -- Max date is today
    local now = os.date("*t")
    props.maxDate = props.maxDate or { year = now.year, month = now.month, day = now.day }
    return DatePicker(props)
end

--- Create a future date picker (for scheduling)
---@param props table|nil
---@return DatePicker
function DatePicker.Future(props)
    props = props or {}
    props.placeholder = props.placeholder or "Select future date"
    -- Min date is today
    local now = os.date("*t")
    props.minDate = props.minDate or { year = now.year, month = now.month, day = now.day }
    return DatePicker(props)
end

--- Create with specific date format
---@param format string Date format string
---@param props table|nil
---@return DatePicker
function DatePicker.WithFormat(format, props)
    props = props or {}
    props.format = format
    return DatePicker(props)
end

return DatePicker
