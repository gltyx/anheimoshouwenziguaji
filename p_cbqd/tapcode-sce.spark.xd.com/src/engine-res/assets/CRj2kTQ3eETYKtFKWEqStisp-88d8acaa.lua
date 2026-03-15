-- ============================================================================
-- Dropdown Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Dropdown select with options list
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")
local UI = require("urhox-libs/UI/Core/UI")

---@class DropdownOption
---@field value any Option value
---@field label string Display text
---@field disabled boolean|nil Is option disabled

---@class DropdownProps : WidgetProps
---@field options DropdownOption[]|nil List of options
---@field value any|nil Currently selected value
---@field placeholder string|nil Placeholder text when no selection (default: "Select...")
---@field disabled boolean|nil Is dropdown disabled
---@field maxVisibleItems number|nil Max visible items in dropdown (default: 6)
---@field itemHeight number|nil Custom item height
---@field onChange fun(self: Dropdown, value: any, option: DropdownOption)|nil Change callback

---@class Dropdown : Widget
---@operator call(DropdownProps?): Dropdown
---@field props DropdownProps
---@field new fun(self, props: DropdownProps?): Dropdown
---@field state {isOpen: boolean, hovered: boolean, hoveredIndex: number|nil}
local Dropdown = Widget:Extend("Dropdown")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props DropdownProps?
function Dropdown:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("Dropdown")
    props.height = props.height or themeStyle.height or 36
    props.minWidth = props.minWidth or themeStyle.minWidth or 120
    props.borderRadius = props.borderRadius or themeStyle.borderRadius or 6

    -- Default values
    props.options = props.options or {}
    props.placeholder = props.placeholder or "Select..."

    -- Initialize state
    -- Note: isDragging MUST be in self.state because UI.lua gesture dispatcher
    -- checks target.state.isDragging to route OnPanMove/OnPanEnd events
    self.state = {
        isOpen = false,
        hovered = false,
        hoveredIndex = nil,
        isDragging = false,
    }

    -- Internal state (does not need to trigger re-render)
    self.dropdownHeight_ = 0
    self.maxVisibleItems_ = props.maxVisibleItems or 6
    self.itemHeight_ = props.itemHeight or 32
    self.scrollOffset_ = 0
    self.dragStartScrollOffset_ = 0
    self.wasDragging_ = false

    Widget.Init(self, props)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Dropdown:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local disabled = props.disabled
    local borderRadius = props.borderRadius
    local isOpen = state.isOpen
    local hovered = state.hovered

    -- Get current selection
    local selectedOption = self:GetSelectedOption()
    local displayText = selectedOption and selectedOption.label or props.placeholder
    local hasSelection = selectedOption ~= nil

    -- Colors
    local bgColor, borderColor, textColor, arrowColor

    if disabled then
        bgColor = Theme.Color("disabled")
        borderColor = Theme.Color("border")
        textColor = Theme.Color("disabledText")
        arrowColor = Theme.Color("disabledText")
    else
        if isOpen then
            bgColor = Theme.Color("surface")
            borderColor = Theme.Color("primary")
            textColor = hasSelection and Theme.Color("text") or Theme.Color("textSecondary")
            arrowColor = Theme.Color("primary")
        elseif hovered then
            bgColor = Theme.Color("surfaceHover") or Style.Lighten(Theme.Color("surface"), 0.05)
            borderColor = Theme.Color("primary")
            textColor = hasSelection and Theme.Color("text") or Theme.Color("textSecondary")
            arrowColor = Theme.Color("text")
        else
            bgColor = Theme.Color("surface")
            borderColor = Theme.Color("border")
            textColor = hasSelection and Theme.Color("text") or Theme.Color("textSecondary")
            arrowColor = Theme.Color("textSecondary")
        end
    end

    -- Draw trigger background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
    nvgFill(nvg)

    -- Draw border
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
    nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 255))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- Draw text
    local fontFamily = Theme.FontFamily()
    local padding = 12
    local arrowSize = 8

    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, Theme.FontSizeOf("body"))
    nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- Clip text to available width
    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x + padding, l.y, l.w - padding * 2 - arrowSize - 8, l.h)
    nvgText(nvg, l.x + padding, l.y + l.h / 2, displayText, nil)
    nvgRestore(nvg)

    -- Draw dropdown arrow
    local arrowX = l.x + l.w - padding - arrowSize / 2
    local arrowY = l.y + l.h / 2

    nvgBeginPath(nvg)
    if isOpen then
        -- Up arrow
        nvgMoveTo(nvg, arrowX - arrowSize / 2, arrowY + arrowSize / 4)
        nvgLineTo(nvg, arrowX, arrowY - arrowSize / 4)
        nvgLineTo(nvg, arrowX + arrowSize / 2, arrowY + arrowSize / 4)
    else
        -- Down arrow
        nvgMoveTo(nvg, arrowX - arrowSize / 2, arrowY - arrowSize / 4)
        nvgLineTo(nvg, arrowX, arrowY + arrowSize / 4)
        nvgLineTo(nvg, arrowX + arrowSize / 2, arrowY - arrowSize / 4)
    end
    nvgStrokeColor(nvg, nvgRGBA(arrowColor[1], arrowColor[2], arrowColor[3], arrowColor[4] or 255))
    nvgStrokeWidth(nvg, 2)
    nvgLineCap(nvg, NVG_ROUND)
    nvgLineJoin(nvg, NVG_ROUND)
    nvgStroke(nvg)

    -- Queue dropdown panel to render as overlay (on top of everything)
    if isOpen then
        UI.QueueOverlay(function(nvg_)
            self:RenderDropdownPanel(nvg_)
        end)
    end
end

--- Render the dropdown options panel
function Dropdown:RenderDropdownPanel(nvg)
    -- Use GetAbsoluteLayoutForHitTest because overlay renders outside ScrollView's nvgTranslate
    local l = self:GetAbsoluteLayoutForHitTest()
    local props = self.props
    local state = self.state
    local options = props.options
    local borderRadius = props.borderRadius

    if #options == 0 then
        return
    end

    -- Calculate panel dimensions
    local itemHeight = self.itemHeight_
    local visibleItems = math.min(#options, self.maxVisibleItems_)
    local panelHeight = visibleItems * itemHeight + 8  -- 8 for padding
    local panelY = l.y + l.h + 4  -- 4px gap

    self.dropdownHeight_ = panelHeight

    -- Panel background with shadow
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x - 2, panelY - 2, l.w + 4, panelHeight + 4, borderRadius + 2)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, panelY, l.w, panelHeight, borderRadius)
    nvgFillColor(nvg, nvgRGBA(Theme.Color("surface")[1], Theme.Color("surface")[2], Theme.Color("surface")[3], 255))
    nvgFill(nvg)

    -- Panel border
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, panelY, l.w, panelHeight, borderRadius)
    nvgStrokeColor(nvg, nvgRGBA(Theme.Color("border")[1], Theme.Color("border")[2], Theme.Color("border")[3], 255))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- Render options (with scroll offset support)
    local fontFamily = Theme.FontFamily()
    local padding = 12
    local scrollOffset = self.scrollOffset_
    local totalOptions = #options
    local hasScroll = totalOptions > visibleItems

    -- Clip options to panel (shrink right side when scrollbar is present)
    local scrollbarReserve = hasScroll and 12 or 0  -- scrollbarWidth(4) + margin(4) + gap(4)
    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, panelY + 4, l.w - scrollbarReserve, panelHeight - 8)

    local startIdx = scrollOffset + 1
    local endIdx = math.min(startIdx + visibleItems - 1, totalOptions)

    for i = startIdx, endIdx do
        local option = options[i]
        local displayIdx = i - startIdx  -- 0-based display position
        local itemY = panelY + 4 + displayIdx * itemHeight
        local isHovered = state.hoveredIndex == i
        local isSelected = props.value == option.value
        local isDisabled = option.disabled

        -- Item background (hover/selected)
        if isHovered and not isDisabled then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, l.x + 4, itemY, l.w - 8, itemHeight, 4)
            nvgFillColor(nvg, nvgRGBA(Theme.Color("primary")[1], Theme.Color("primary")[2], Theme.Color("primary")[3], 30))
            nvgFill(nvg)
        elseif isSelected then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, l.x + 4, itemY, l.w - 8, itemHeight, 4)
            nvgFillColor(nvg, nvgRGBA(Theme.Color("primary")[1], Theme.Color("primary")[2], Theme.Color("primary")[3], 20))
            nvgFill(nvg)
        end

        -- Item text
        local itemTextColor
        if isDisabled then
            itemTextColor = Theme.Color("disabledText")
        elseif isSelected then
            itemTextColor = Theme.Color("primary")
        else
            itemTextColor = Theme.Color("text")
        end

        nvgFontFace(nvg, fontFamily)
        nvgFontSize(nvg, Theme.FontSizeOf("body"))
        nvgFillColor(nvg, nvgRGBA(itemTextColor[1], itemTextColor[2], itemTextColor[3], itemTextColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(nvg, l.x + padding, itemY + itemHeight / 2, option.label, nil)

        -- Checkmark for selected item
        if isSelected then
            local checkX = l.x + l.w - padding - 8
            local checkY = itemY + itemHeight / 2

            nvgBeginPath(nvg)
            nvgMoveTo(nvg, checkX - 4, checkY)
            nvgLineTo(nvg, checkX - 1, checkY + 3)
            nvgLineTo(nvg, checkX + 4, checkY - 3)
            nvgStrokeColor(nvg, nvgRGBA(Theme.Color("primary")[1], Theme.Color("primary")[2], Theme.Color("primary")[3], 255))
            nvgStrokeWidth(nvg, 2)
            nvgLineCap(nvg, NVG_ROUND)
            nvgLineJoin(nvg, NVG_ROUND)
            nvgStroke(nvg)
        end
    end

    nvgRestore(nvg)

    -- Draw scrollbar indicator when there are more items than visible
    if hasScroll then
        self:RenderScrollbar(nvg, l, panelY, panelHeight, scrollOffset, visibleItems, totalOptions)
    end
end

--- Render scrollbar indicator for the dropdown panel
---@param nvg NVGContextWrapper
---@param l table Absolute layout of the trigger
---@param panelY number Y position of the dropdown panel
---@param panelHeight number Height of the dropdown panel
---@param scrollOffset number Current scroll offset
---@param visibleItems number Number of visible items
---@param totalOptions number Total number of options
function Dropdown:RenderScrollbar(nvg, l, panelY, panelHeight, scrollOffset, visibleItems, totalOptions)
    local scrollbarWidth = 4
    local scrollbarX = l.x + l.w - scrollbarWidth - 4
    local trackY = panelY + 4
    local trackHeight = panelHeight - 8
    local maxOffset = totalOptions - visibleItems

    -- Scrollbar track (subtle background)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, scrollbarX, trackY, scrollbarWidth, trackHeight, scrollbarWidth / 2)
    nvgFillColor(nvg, nvgRGBA(Theme.Color("border")[1], Theme.Color("border")[2], Theme.Color("border")[3], 60))
    nvgFill(nvg)

    -- Scrollbar thumb
    local thumbRatio = visibleItems / totalOptions
    local thumbHeight = math.max(20, trackHeight * thumbRatio)
    local thumbRange = trackHeight - thumbHeight
    local thumbY = trackY + (maxOffset > 0 and (scrollOffset / maxOffset * thumbRange) or 0)

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, scrollbarX, thumbY, scrollbarWidth, thumbHeight, scrollbarWidth / 2)
    nvgFillColor(nvg, nvgRGBA(Theme.Color("textSecondary")[1], Theme.Color("textSecondary")[2], Theme.Color("textSecondary")[3], 150))
    nvgFill(nvg)
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Dropdown:OnMouseEnter()
    if not self.props.disabled then
        self:SetState({ hovered = true })
    end
end

function Dropdown:OnMouseLeave()
    self:SetState({ hovered = false, hoveredIndex = nil })
end

function Dropdown:OnClick(event)
    if self.props.disabled then
        return
    end

    -- Check if click is in dropdown panel
    if self.state.isOpen and event then
        local l = self:GetAbsoluteLayoutForHitTest()
        local panelY = l.y + l.h + 4
        local panelHeight = self.dropdownHeight_

        if event.y >= panelY and event.y <= panelY + panelHeight then
            -- If we just finished a drag in the panel, skip selection
            if self.wasDragging_ then
                self.wasDragging_ = false
                return
            end

            -- Click in panel - select option (account for scroll offset)
            local itemHeight = self.itemHeight_
            local displayIndex = math.floor((event.y - panelY - 4) / itemHeight)  -- 0-based display position
            local clickIndex = displayIndex + self.scrollOffset_ + 1  -- 1-based actual option index

            if clickIndex >= 1 and clickIndex <= #self.props.options then
                local option = self.props.options[clickIndex]
                if not option.disabled then
                    self:SelectOption(option)
                end
            end
            return
        end
    end

    -- Click on trigger area - always handle (wasDragging_ does not block trigger clicks)
    self.wasDragging_ = false
    self:SetOpen(not self.state.isOpen)
end

function Dropdown:OnPointerDown(event)
    Widget.OnPointerDown(self, event)
end

function Dropdown:OnPointerMove(event)
    Widget.OnPointerMove(self, event)

    if self.state.isOpen then
        -- Use GetAbsoluteLayoutForHitTest for proper scroll offset handling
        local l = self:GetAbsoluteLayoutForHitTest()
        local panelY = l.y + l.h + 4
        local panelHeight = self.dropdownHeight_

        if event.y >= panelY and event.y <= panelY + panelHeight then
            local itemHeight = self.itemHeight_
            local displayIndex = math.floor((event.y - panelY - 4) / itemHeight)  -- 0-based display position
            local hoverIndex = displayIndex + self.scrollOffset_ + 1  -- 1-based actual option index

            if hoverIndex >= 1 and hoverIndex <= #self.props.options then
                if self.state.hoveredIndex ~= hoverIndex then
                    self:SetState({ hoveredIndex = hoverIndex })
                end
            else
                self:SetState({ hoveredIndex = nil })
            end
        else
            self:SetState({ hoveredIndex = nil })
        end
    end
end

function Dropdown:OnBlur()
    if self.state.isOpen then
        self:SetOpen(false)
    end
end

function Dropdown:OnWheel(dx, dy)
    if self.state.isOpen and #self.props.options > self.maxVisibleItems_ then
        -- dy > 0 means scroll up (show earlier items), dy < 0 means scroll down
        self.scrollOffset_ = self.scrollOffset_ - dy
        self:ClampScrollOffset()
    end
end

-- ============================================================================
-- Pan Gesture (Touch Drag Scrolling)
-- ============================================================================

function Dropdown:OnPanStart(event)
    -- Only handle pan when dropdown is open and has scrollable content
    if not self.state.isOpen then
        return false
    end
    if #self.props.options <= self.maxVisibleItems_ then
        return false
    end

    -- Check if pan starts inside the dropdown panel area
    local l = self:GetAbsoluteLayoutForHitTest()
    local panelY = l.y + l.h + 4
    local panelHeight = self.dropdownHeight_

    if event.x >= l.x and event.x <= l.x + l.w and
       event.y >= panelY and event.y <= panelY + panelHeight then
        -- Start dragging
        self.state.isDragging = true
        self.dragStartScrollOffset_ = self.scrollOffset_
        return true  -- We're handling this pan gesture
    end

    return false
end

function Dropdown:OnPanMove(event)
    if not self.state.isDragging then return end

    -- Convert pixel drag to scroll offset (items), snap to nearest integer
    local itemHeight = self.itemHeight_
    local deltaItems = -event.totalDeltaY / itemHeight
    self.scrollOffset_ = math.floor(self.dragStartScrollOffset_ + deltaItems + 0.5)
    self:ClampScrollOffset()
end

function Dropdown:OnPanEnd(event)
    if not self.state.isDragging then return end
    self.state.isDragging = false
    -- Mark that we just finished dragging, to prevent OnClick from selecting
    self.wasDragging_ = true
end

-- ============================================================================
-- Hit Test Override
-- ============================================================================

function Dropdown:HitTest(x, y)
    -- Use GetAbsoluteLayoutForHitTest for proper scroll offset handling
    local l = self:GetAbsoluteLayoutForHitTest()

    -- Check trigger area
    if x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h then
        return true
    end

    -- Check dropdown panel area if open
    if self.state.isOpen then
        local panelY = l.y + l.h + 4
        local panelHeight = self.dropdownHeight_

        if x >= l.x and x <= l.x + l.w and y >= panelY and y <= panelY + panelHeight then
            return true
        end
    end

    return false
end

-- ============================================================================
-- Internal
-- ============================================================================

--- Unified open/close logic. All open/close paths go through here.
---@param open boolean Whether to open or close the dropdown
function Dropdown:SetOpen(open)
    if open then
        self:ScrollToSelected()
        self:SetState({ isOpen = true })
        UI.SetActiveOverlay(self)
    else
        self:SetState({ isOpen = false, hoveredIndex = nil })
        UI.ClearActiveOverlay()
        -- Intentionally bypass SetState for isDragging (no re-render needed)
        self.state.isDragging = false
        self.wasDragging_ = false
    end
end

--- Clamp scroll offset to valid range
function Dropdown:ClampScrollOffset()
    local maxOffset = math.max(0, #self.props.options - self.maxVisibleItems_)
    self.scrollOffset_ = math.max(0, math.min(self.scrollOffset_, maxOffset))
end

--- Scroll to show the currently selected item when opening
function Dropdown:ScrollToSelected()
    local value = self.props.value
    if value == nil then
        self.scrollOffset_ = 0
        return
    end

    -- Find index of selected option
    for i, option in ipairs(self.props.options) do
        if option.value == value then
            -- Ensure selected item is visible
            if i <= self.scrollOffset_ then
                -- Selected item is above visible area
                self.scrollOffset_ = math.max(0, i - 1)
            elseif i > self.scrollOffset_ + self.maxVisibleItems_ then
                -- Selected item is below visible area
                self.scrollOffset_ = i - self.maxVisibleItems_
            end
            -- else: already visible, keep current offset
            self:ClampScrollOffset()
            return
        end
    end

    -- Value not found in options, reset
    self.scrollOffset_ = 0
end

--- Get currently selected option
---@return DropdownOption|nil
function Dropdown:GetSelectedOption()
    local value = self.props.value
    if value == nil then
        return nil
    end

    for _, option in ipairs(self.props.options) do
        if option.value == value then
            return option
        end
    end

    return nil
end

--- Select an option
---@param option DropdownOption
function Dropdown:SelectOption(option)
    if option.disabled then
        return
    end

    self.props.value = option.value
    self:SetOpen(false)

    if self.props.onChange then
        self.props.onChange(self, option.value, option)
    end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set selected value
---@param value any
---@return Dropdown self
function Dropdown:SetValue(value)
    if self.props.value ~= value then
        self.props.value = value
        if self.props.onChange then
            local option = self:GetSelectedOption()
            self.props.onChange(self, value, option)
        end
    end
    return self
end

--- Get selected value
---@return any
function Dropdown:GetValue()
    return self.props.value
end

--- Get selected option
---@return DropdownOption|nil
function Dropdown:GetSelected()
    return self:GetSelectedOption()
end

--- Set options
---@param options DropdownOption[]
---@return Dropdown self
function Dropdown:SetOptions(options)
    self.props.options = options or {}
    self.scrollOffset_ = 0
    -- Clear selection if current value not in new options
    if self.props.value ~= nil then
        local found = false
        for _, opt in ipairs(self.props.options) do
            if opt.value == self.props.value then
                found = true
                break
            end
        end
        if not found then
            self.props.value = nil
        end
    end
    return self
end

--- Add an option
---@param option DropdownOption
---@return Dropdown self
function Dropdown:AddOption(option)
    table.insert(self.props.options, option)
    return self
end

--- Remove option by value
---@param value any
---@return Dropdown self
function Dropdown:RemoveOption(value)
    for i, opt in ipairs(self.props.options) do
        if opt.value == value then
            table.remove(self.props.options, i)
            if self.props.value == value then
                self.props.value = nil
            end
            break
        end
    end
    return self
end

--- Open dropdown
---@return Dropdown self
function Dropdown:Open()
    if not self.props.disabled then
        self:SetOpen(true)
    end
    return self
end

--- Close dropdown
---@return Dropdown self
function Dropdown:Close()
    self:SetOpen(false)
    return self
end

--- Toggle dropdown
---@return Dropdown self
function Dropdown:Toggle()
    if not self.props.disabled then
        self:SetOpen(not self.state.isOpen)
    end
    return self
end

--- Set disabled state
---@param disabled boolean
---@return Dropdown self
function Dropdown:SetDisabled(disabled)
    self.props.disabled = disabled
    if disabled then
        self:SetState({ isOpen = false, hovered = false, hoveredIndex = nil })
    end
    return self
end

--- Check if dropdown is open
---@return boolean
function Dropdown:IsOpen()
    return self.state.isOpen == true
end

-- ============================================================================
-- Stateful
-- ============================================================================

function Dropdown:IsStateful()
    return true
end

return Dropdown
