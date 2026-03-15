-- ============================================================================
-- List Widget
-- UrhoX UI Library - Yoga + NanoVG
-- List container with items, selection, grouping, and nested support
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local Style = require("urhox-libs/UI/Core/Style")

---@class ListItem
---@field id string|number Unique item identifier
---@field text string Primary text
---@field secondaryText string|nil Secondary text line
---@field icon string|nil Icon name or path
---@field avatar table|nil Avatar props { name, src, initials }
---@field trailing Widget|string|nil Trailing content (widget or text)
---@field disabled boolean|nil Is item disabled
---@field divider boolean|nil Show divider after this item
---@field items ListItem[]|nil Nested items (for expandable lists)
---@field expanded boolean|nil Is nested list expanded

---@class ListProps : WidgetProps
---@field items ListItem[]|nil List of items
---@field variant string|nil "simple" | "inset" | "dense" (default: "simple")
---@field selectable boolean|nil Enable item selection
---@field multiSelect boolean|nil Allow multiple selection
---@field selected table|nil Selected item id(s)
---@field showDividers boolean|nil Show dividers between all items
---@field expandable boolean|nil Enable nested list expansion
---@field onSelect fun(self: List, selected: table|nil)|nil Selection change callback
---@field onItemClick fun(self: List, item: ListItem)|nil Item click callback
---@field onItemDoubleClick fun(self: List, item: ListItem)|nil Item double-click callback

---@class List : Widget
---@operator call(ListProps?): List
---@field props ListProps
---@field new fun(self, props: ListProps?): List
local List = Widget:Extend("List")

-- Size presets
local VARIANT_SIZES = {
    simple = { itemHeight = 48, padding = 16, fontSize = 14 },
    inset = { itemHeight = 48, padding = 24, fontSize = 14 },
    dense = { itemHeight = 36, padding = 16, fontSize = 13 },
}

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props ListProps?
function List:Init(props)
    props = props or {}

    -- Default settings
    self.items_ = props.items or {}
    self.variant_ = props.variant or "simple"
    self.selectable_ = props.selectable or false
    self.multiSelect_ = props.multiSelect or false
    self.selected_ = props.selected or {}
    self.showDividers_ = props.showDividers or false
    self.expandable_ = props.expandable or false

    -- State
    self.hoveredItem_ = nil
    self.pressedItem_ = nil
    self.expandedItems_ = {}

    -- Initialize expanded state from items
    if self.expandable_ then
        self:InitExpandedFromItems(self.items_)
    end

    -- Default flex layout
    props.flexDirection = props.flexDirection or "column"

    -- Auto-calculate height if not specified
    if not props.height then
        props.height = self:CalculateTotalHeight()
    end

    Widget.Init(self, props)
end

--- Initialize expanded state from items with expanded = true
function List:InitExpandedFromItems(items, depth)
    depth = depth or 0
    for i, item in ipairs(items) do
        local itemKey = item.id or item.text or item.primary or item.label or (depth .. "_" .. i)
        if item.items and item.expanded then
            self.expandedItems_[itemKey] = true
        end
        if item.items then
            self:InitExpandedFromItems(item.items, depth + 1)
        end
    end
end

--- Calculate total height needed to display all visible items
function List:CalculateTotalHeight()
    local variant = VARIANT_SIZES[self.variant_] or VARIANT_SIZES.simple
    return self:CalculateItemsHeight(self.items_, variant, 0)
end

function List:CalculateItemsHeight(items, variant, depth)
    local totalHeight = 0
    for i, item in ipairs(items) do
        totalHeight = totalHeight + self:CalculateItemHeight(item, variant)
        -- Add nested items height if expanded
        local itemKey = item.id or item.text or item.primary or item.label or (depth .. "_" .. i)
        if item.items and self.expandable_ and self.expandedItems_[itemKey] then
            totalHeight = totalHeight + self:CalculateItemsHeight(item.items, variant, depth + 1)
        end
    end
    return totalHeight
end

--- Update height after expand/collapse
function List:UpdateHeight()
    local newHeight = self:CalculateTotalHeight()
    self:SetHeight(newHeight)
end

-- ============================================================================
-- Rendering
-- ============================================================================

function List:Render(nvg)
    local x, y = self:GetAbsolutePosition()
    local w, h = self:GetComputedSize()

    -- Draw background
    Widget.Render(self, nvg)

    -- Reset item positions for hit testing
    self.itemPositions_ = {}

    -- Render items
    local currentY = y
    currentY = self:RenderItems(nvg, self.items_, x, currentY, w, 0)
end

--- Render list items recursively
function List:RenderItems(nvg, items, x, y, width, depth)
    local variant = VARIANT_SIZES[self.variant_] or VARIANT_SIZES.simple

    -- Size values (no scale needed - nvgScale handles it)
    local indentWidth = 24
    local indent = depth * indentWidth
    local variantPadding = variant.padding

    for i, item in ipairs(items) do
        local itemHeight = self:CalculateItemHeight(item, variant)
        local itemX = x + indent
        local itemWidth = width - indent

        -- Generate item key (id or text/primary/label or index)
        local itemKey = item.id or item.text or item.primary or item.label or (depth .. "_" .. i)

        -- Check if item is selected
        local isSelected = self:IsSelected(itemKey)
        local isHovered = self.hoveredItem_ == itemKey
        local isPressed = self.pressedItem_ == itemKey
        local isDisabled = item.disabled == true

        -- Store item position for hit testing
        self.itemPositions_[itemKey] = {
            x1 = itemX,
            x2 = itemX + itemWidth,
            y1 = y,
            y2 = y + itemHeight,
            item = item,
            itemKey = itemKey,
            depth = depth,
        }

        -- Draw item background
        self:RenderItemBackground(nvg, itemX, y, itemWidth, itemHeight, isSelected, isHovered, isPressed, isDisabled)

        -- Draw item content
        self:RenderItemContent(nvg, item, itemX, y, itemWidth, itemHeight, variant, depth, isDisabled, itemKey)

        -- Draw divider
        if self.showDividers_ or item.divider then
            if i < #items or item.divider then
                self:RenderDivider(nvg, x + variantPadding, y + itemHeight, width - variantPadding * 2)
            end
        end

        y = y + itemHeight

        -- Render nested items if expanded
        if item.items and self.expandable_ and self.expandedItems_[itemKey] then
            y = self:RenderItems(nvg, item.items, x, y, width, depth + 1)
        end
    end

    return y
end

--- Calculate item height
function List:CalculateItemHeight(item, variant)
    local baseHeight = variant.itemHeight
    local secondaryText = item.secondaryText or item.secondary
    if secondaryText then
        baseHeight = baseHeight + 20 -- Extra space for secondary text
    end
    return baseHeight
end

--- Render item background
function List:RenderItemBackground(nvg, x, y, width, height, isSelected, isHovered, isPressed, isDisabled)
    local bgColor = nil

    if isDisabled then
        -- No background change for disabled
    elseif isPressed then
        local primary = Theme.Color("primary")
        bgColor = { primary[1], primary[2], primary[3], 40 }
    elseif isSelected then
        local primary = Theme.Color("primary")
        bgColor = { primary[1], primary[2], primary[3], 25 }
    elseif isHovered then
        bgColor = { 128, 128, 128, 20 }
    end

    if bgColor then
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, width, height)
        nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4]))
        nvgFill(nvg)
    end
end

--- Render item content
function List:RenderItemContent(nvg, item, x, y, width, height, variant, depth, isDisabled, itemKey)
    local padding = variant.padding
    local fontSize = Theme.FontSize(variant.fontSize)

    local contentX = x + padding
    local contentWidth = width - padding * 2

    local fontFamily = Theme.FontFamily()
    local textColor = isDisabled and Theme.Color("textDisabled") or Theme.Color("text")
    local secondaryColor = isDisabled and Theme.Color("textDisabled") or Theme.Color("textSecondary")

    -- Draw expand/collapse icon for nested items
    if item.items and self.expandable_ then
        local isExpanded = self.expandedItems_[itemKey]
        local iconSize = 20
        local iconX = contentX
        local iconY = y + (height - iconSize) / 2

        nvgFontFace(nvg, fontFamily)
        nvgFontSize(nvg, iconSize)
        nvgFillColor(nvg, nvgRGBA(secondaryColor[1], secondaryColor[2], secondaryColor[3], secondaryColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)

        local icon = isExpanded and "v" or ">" -- Simple arrow indicators
        nvgText(nvg, iconX + iconSize / 2, iconY + iconSize / 2, icon, nil)

        contentX = contentX + iconSize + 8
        contentWidth = contentWidth - iconSize - 8
    end

    -- Draw avatar if present
    if item.avatar then
        local avatarSize = height - 16
        local avatarX = contentX
        local avatarY = y + 8

        self:RenderAvatar(nvg, item.avatar, avatarX, avatarY, avatarSize)

        contentX = contentX + avatarSize + 12
        contentWidth = contentWidth - avatarSize - 12
    end

    -- Draw icon if present (and no avatar)
    if item.icon and not item.avatar then
        local iconSize = 24
        local iconX = contentX
        local iconY = y + (height - iconSize) / 2

        -- Simple icon placeholder (circle with letter)
        nvgBeginPath(nvg)
        nvgCircle(nvg, iconX + iconSize / 2, iconY + iconSize / 2, iconSize / 2)
        nvgFillColor(nvg, nvgRGBA(secondaryColor[1], secondaryColor[2], secondaryColor[3], 50))
        nvgFill(nvg)

        nvgFontFace(nvg, fontFamily)
        nvgFontSize(nvg, Theme.FontSizeOf("small"))
        nvgFillColor(nvg, nvgRGBA(secondaryColor[1], secondaryColor[2], secondaryColor[3], secondaryColor[4] or 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
        nvgText(nvg, iconX + iconSize / 2, iconY + iconSize / 2, string.sub(item.icon, 1, 1), nil)

        contentX = contentX + iconSize + 12
        contentWidth = contentWidth - iconSize - 12
    end

    -- Calculate trailing width
    local trailingWidth = 0
    if item.trailing then
        if type(item.trailing) == "string" then
            nvgFontFace(nvg, fontFamily)
            nvgFontSize(nvg, fontSize - 2)
            trailingWidth = nvgTextBounds(nvg, 0, 0, item.trailing, nil, nil) + 8
        else
            -- Widget trailing
            local tl = item.trailing:GetLayout()
            trailingWidth = tl.w + 8
        end
        contentWidth = contentWidth - trailingWidth
    end

    -- Get text content (support both text/secondaryText and primary/secondary naming)
    local primaryText = item.text or item.primary or item.label or ""
    local secondaryText = item.secondaryText or item.secondary

    -- Draw primary text
    local textY = y + height / 2
    if secondaryText then
        textY = y + height / 2 - 10
    end

    nvgFontFace(nvg, fontFamily)
    nvgFontSize(nvg, fontSize)
    nvgFillColor(nvg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(nvg, contentX, textY, primaryText)

    -- Draw secondary text
    if secondaryText then
        nvgFontSize(nvg, fontSize - 2)
        nvgFillColor(nvg, nvgRGBA(secondaryColor[1], secondaryColor[2], secondaryColor[3], secondaryColor[4] or 255))
        nvgText(nvg, contentX, textY + 20, secondaryText)
    end

    -- Draw trailing content
    if item.trailing then
        local trailingX = x + width - padding - trailingWidth + 8
        local trailingY = y + height / 2

        if type(item.trailing) == "string" then
            nvgFontFace(nvg, fontFamily)
            nvgFontSize(nvg, fontSize - 2)
            nvgFillColor(nvg, nvgRGBA(secondaryColor[1], secondaryColor[2], secondaryColor[3], secondaryColor[4] or 255))
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgText(nvg, trailingX, trailingY, item.trailing, nil)
        else
            -- Render widget
            item.trailing.renderOffsetX_ = trailingX
            item.trailing.renderOffsetY_ = y + (height - item.trailing:GetLayout().h) / 2
            item.trailing:Render(nvg)
        end
    end
end

--- Render avatar
function List:RenderAvatar(nvg, avatar, x, y, size)
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
    local bgColor = { 99, 102, 241, 255 } -- Default indigo
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
    nvgFontSize(nvg, size * 0.4)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgText(nvg, x + size / 2, y + size / 2, initials, nil)
end

--- Render divider line
function List:RenderDivider(nvg, x, y, width)
    local borderColor = Theme.Color("border")
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x, y)
    nvgLineTo(nvg, x + width, y)
    nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], 50))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
end

-- ============================================================================
-- Selection
-- ============================================================================

--- Check if an item is selected
function List:IsSelected(itemId)
    if type(self.selected_) == "table" then
        for _, id in ipairs(self.selected_) do
            if id == itemId then
                return true
            end
        end
        return false
    end
    return self.selected_ == itemId
end

--- Select an item
function List:SelectItem(itemId)
    if not self.selectable_ then
        return
    end

    local newSelected

    if self.multiSelect_ then
        newSelected = {}
        local found = false
        for _, id in ipairs(self.selected_ or {}) do
            if id == itemId then
                found = true
            else
                table.insert(newSelected, id)
            end
        end
        if not found then
            table.insert(newSelected, itemId)
        end
    else
        if self:IsSelected(itemId) then
            newSelected = {}
        else
            newSelected = { itemId }
        end
    end

    self.selected_ = newSelected

    if self.props.onSelect then
        if self.multiSelect_ then
            self.props.onSelect(self, newSelected)
        else
            self.props.onSelect(self, newSelected[1])
        end
    end
end

-- ============================================================================
-- Hit Testing
-- ============================================================================

--- Find item at position using stored item positions
function List:GetItemAtPosition(screenX, screenY)
    if not self.itemPositions_ then return nil end

    -- Convert screen coords to render coords
    local l = self:GetAbsoluteLayout()
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    local px = screenX + (l.x - hitTest.x)
    local py = screenY + (l.y - hitTest.y)

    for id, pos in pairs(self.itemPositions_) do
        if px >= pos.x1 and px <= pos.x2 and py >= pos.y1 and py <= pos.y2 then
            return pos
        end
    end

    return nil
end

function List:HitTest(x, y)
    -- Convert screen coords to render coords
    local l = self:GetAbsoluteLayout()
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    local px = x + (l.x - hitTest.x)
    local py = y + (l.y - hitTest.y)

    -- Check if within horizontal bounds
    if px < l.x or px > l.x + l.w then
        return false
    end

    -- Check if within any rendered item
    if self.itemPositions_ then
        for _, pos in pairs(self.itemPositions_) do
            if px >= pos.x1 and px <= pos.x2 and py >= pos.y1 and py <= pos.y2 then
                return true
            end
        end
    end

    -- Fallback to layout bounds
    if py >= l.y and py <= l.y + l.h then
        return true
    end

    return false
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function List:OnPointerMove(event)
    if not event then return end

    local itemPos = self:GetItemAtPosition(event.x, event.y)
    local hoveredKey = itemPos and itemPos.itemKey or nil

    if hoveredKey ~= self.hoveredItem_ then
        self.hoveredItem_ = hoveredKey
    end
end

function List:OnMouseLeave()
    self.hoveredItem_ = nil
    self.pressedItem_ = nil
end

function List:OnPointerDown(event)
    if not event then return end

    local itemPos = self:GetItemAtPosition(event.x, event.y)
    if itemPos and not itemPos.item.disabled then
        self.pressedItem_ = itemPos.itemKey
    end
end

function List:OnPointerUp(event)
    self.pressedItem_ = nil
end

function List:OnClick(event)
    if not event then return end

    local itemPos = self:GetItemAtPosition(event.x, event.y)
    if not itemPos or itemPos.item.disabled then
        return
    end

    local item = itemPos.item
    local itemKey = itemPos.itemKey

    -- Handle expandable items
    if item.items and self.expandable_ then
        self.expandedItems_[itemKey] = not self.expandedItems_[itemKey]
        self:UpdateHeight()
    end

    -- Handle selection
    if self.selectable_ then
        self:SelectItem(itemKey)
    end

    -- Fire click callback
    if self.props.onItemClick then
        self.props.onItemClick(self, item)
    end
end

function List:OnDoubleTap(event)
    if not event then return end

    local itemPos = self:GetItemAtPosition(event.x, event.y)
    if not itemPos or itemPos.item.disabled then
        return
    end

    local item = itemPos.item

    -- Fire double-click callback
    if self.props.onItemDoubleClick then
        self.props.onItemDoubleClick(self, item)
    end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set items
---@param items ListItem[]
---@return List self
function List:SetItems(items)
    self.items_ = items
    self:UpdateHeight()
    return self
end

--- Get items
---@return ListItem[]
function List:GetItems()
    return self.items_
end

--- Add an item
---@param item ListItem
---@param index number|nil Insert position (default: end)
---@return List self
function List:AddItem(item, index)
    if index then
        table.insert(self.items_, index, item)
    else
        table.insert(self.items_, item)
    end
    self:UpdateHeight()
    return self
end

--- Remove an item by id
---@param itemId string|number
---@return List self
function List:RemoveItem(itemId)
    for i = #self.items_, 1, -1 do
        if self.items_[i].id == itemId then
            table.remove(self.items_, i)
            break
        end
    end
    self:UpdateHeight()
    return self
end

--- Get selected item(s)
---@return table
function List:GetSelected()
    return self.selected_
end

--- Set selected item(s)
---@param selected table|string|number
---@return List self
function List:SetSelected(selected)
    if type(selected) ~= "table" then
        selected = { selected }
    end
    self.selected_ = selected
    return self
end

--- Clear selection
---@return List self
function List:ClearSelection()
    self.selected_ = {}
    if self.props.onSelect then
        self.props.onSelect(self, self.multiSelect_ and {} or nil)
    end
    return self
end

--- Expand an item
---@param itemId string|number
---@return List self
function List:ExpandItem(itemId)
    self.expandedItems_[itemId] = true
    self:UpdateHeight()
    return self
end

--- Collapse an item
---@param itemId string|number
---@return List self
function List:CollapseItem(itemId)
    self.expandedItems_[itemId] = false
    self:UpdateHeight()
    return self
end

--- Toggle item expansion
---@param itemId string|number
---@return List self
function List:ToggleItem(itemId)
    self.expandedItems_[itemId] = not self.expandedItems_[itemId]
    self:UpdateHeight()
    return self
end

--- Expand all items
---@return List self
function List:ExpandAll()
    local function expandRecursive(items)
        for _, item in ipairs(items) do
            if item.items then
                self.expandedItems_[item.id] = true
                expandRecursive(item.items)
            end
        end
    end
    expandRecursive(self.items_)
    self:UpdateHeight()
    return self
end

--- Collapse all items
---@return List self
function List:CollapseAll()
    self.expandedItems_ = {}
    self:UpdateHeight()
    return self
end

--- Set variant
---@param variant string "simple" | "inset" | "dense"
---@return List self
function List:SetVariant(variant)
    self.variant_ = variant
    self:UpdateHeight()
    return self
end

--- Set show dividers
---@param show boolean
---@return List self
function List:SetShowDividers(show)
    self.showDividers_ = show
    return self
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a simple list from string array
---@param items string[] Array of strings
---@param options table|nil List options
---@return List
function List.FromStrings(items, options)
    options = options or {}

    local listItems = {}
    for i, text in ipairs(items) do
        table.insert(listItems, {
            id = i,
            text = text,
        })
    end

    options.items = listItems
    return List:new(options)
end

--- Create a navigation list
---@param items table[] Array of { id, text, icon, onClick }
---@param options table|nil List options
---@return List
function List.Navigation(items, options)
    options = options or {}

    local listItems = {}
    for _, item in ipairs(items) do
        table.insert(listItems, {
            id = item.id or item.text,
            text = item.text,
            icon = item.icon,
            disabled = item.disabled,
        })
    end

    options.items = listItems
    options.selectable = true
    options.onItemClick = function(list, item)
        for _, srcItem in ipairs(items) do
            if (srcItem.id or srcItem.text) == item.id and srcItem.onClick then
                srcItem.onClick(item)
                break
            end
        end
    end

    return List:new(options)
end

--- Create a settings list with toggles/values
---@param items table[] Array of { id, text, secondaryText, trailing }
---@param options table|nil List options
---@return List
function List.Settings(items, options)
    options = options or {}

    local listItems = {}
    for _, item in ipairs(items) do
        table.insert(listItems, {
            id = item.id or item.text,
            text = item.text,
            secondaryText = item.secondaryText,
            trailing = item.trailing,
            disabled = item.disabled,
            divider = item.divider,
        })
    end

    options.items = listItems
    options.showDividers = options.showDividers ~= false

    return List:new(options)
end

return List
