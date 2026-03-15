-- ============================================================================
-- Menu Widget
-- Context menu, dropdown menu, and navigation menu component
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")

---@class MenuItem
---@field id string|number|nil Item identifier
---@field label string|nil Item label
---@field text string|nil Alias for label
---@field icon string|nil Icon name
---@field shortcut string|nil Keyboard shortcut text
---@field disabled boolean|nil Is item disabled
---@field checked boolean|nil Show checkmark
---@field type string|nil "item" | "divider" | "header" | "submenu"
---@field items MenuItem[]|nil Submenu items

---@class MenuProps : WidgetProps
---@field items MenuItem[]|nil Menu items
---@field size string|nil "sm" | "md" | "lg" (default: "md")
---@field variant string|nil "elevated" | "outlined" | "flat" (default: "elevated")
---@field dense boolean|nil Use dense layout
---@field showIcons boolean|nil Show icons (default: true)
---@field showShortcuts boolean|nil Show shortcuts (default: true)
---@field isOpen boolean|nil Menu open state
---@field anchorX number|nil Anchor X position
---@field anchorY number|nil Anchor Y position
---@field anchorOrigin string|nil Anchor origin "top-left" | "top-right" | "bottom-left" | "bottom-right"
---@field fontSize number|nil Custom font size
---@field iconSize number|nil Custom icon size
---@field onItemClick fun(self: Menu, item: MenuItem)|nil Item click callback
---@field onClose fun(self: Menu)|nil Close callback

---@class Menu : Widget
---@operator call(MenuProps?): Menu
---@field props MenuProps
---@field new fun(self, props: MenuProps?): Menu
---@field AddChild fun(self, child: Widget): self Add child widget
---@field RemoveChild fun(self, child: Widget): self Remove child widget
local Menu = Widget:Extend("Menu")

-- ============================================================================
-- Size presets
-- ============================================================================

local SIZE_PRESETS = {
    sm = { itemHeight = 28, fontSize = 12, iconSize = 14, padding = 6, minWidth = 120 },
    md = { itemHeight = 36, fontSize = 14, iconSize = 18, padding = 8, minWidth = 160 },
    lg = { itemHeight = 44, fontSize = 16, iconSize = 22, padding = 10, minWidth = 200 },
}

-- ============================================================================
-- Item types
-- ============================================================================

local ITEM_TYPES = {
    item = "item",
    divider = "divider",
    header = "header",
    submenu = "submenu",
}

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props MenuProps?
function Menu:Init(props)
    props = props or {}

    -- Menu props
    self.items_ = props.items or {}
    self.size_ = props.size or "md"
    self.variant_ = props.variant or "elevated"  -- elevated, outlined, flat
    self.dense_ = props.dense or false
    self.showIcons_ = props.showIcons ~= false  -- default true
    self.showShortcuts_ = props.showShortcuts ~= false  -- default true

    -- Position (for popup menus)
    self.anchorX_ = props.anchorX or 0
    self.anchorY_ = props.anchorY or 0
    self.anchorOrigin_ = props.anchorOrigin or "top-left"  -- top-left, top-right, bottom-left, bottom-right

    -- Callbacks
    self.onItemClick_ = props.onItemClick
    self.onClose_ = props.onClose

    -- State
    self.isOpen_ = props.isOpen or true
    self.hoverIndex_ = nil
    self.activeSubmenu_ = nil
    self.submenuWidget_ = nil

    -- Calculate dimensions
    local sizePreset = SIZE_PRESETS[self.size_] or SIZE_PRESETS.md
    self.itemHeight_ = self.dense_ and (sizePreset.itemHeight * 0.8) or sizePreset.itemHeight
    self.fontSize_ = props.fontSize or Theme.FontSize(sizePreset.fontSize)
    self.iconSize_ = props.iconSize or sizePreset.iconSize
    self.padding_ = props.padding or sizePreset.padding
    self.minWidth_ = props.minWidth or sizePreset.minWidth

    -- Calculate height based on items
    local totalHeight = self.padding_ * 2
    for _, item in ipairs(self.items_) do
        if item.type == "divider" then
            totalHeight = totalHeight + 9  -- divider height + margins
        elseif item.type == "header" then
            totalHeight = totalHeight + self.itemHeight_ * 0.8
        else
            totalHeight = totalHeight + self.itemHeight_
        end
    end

    props.width = props.width or self.minWidth_
    props.height = props.height or totalHeight
    props.borderRadius = props.borderRadius or 8

    Widget.Init(self, props)
end

-- ============================================================================
-- Menu State
-- ============================================================================

--- Check if Menu is visible
---@return boolean
function Menu:IsVisible()
    return self.props.visible ~= false and self.isOpen_
end

function Menu:IsOpen()
    return self.isOpen_
end

function Menu:Open(x, y)
    self.isOpen_ = true
    if x then self.anchorX_ = x end
    if y then self.anchorY_ = y end
end

function Menu:Close()
    self.isOpen_ = false
    self.hoverIndex_ = nil
    self:CloseSubmenu()
    if self.onClose_ then
        self.onClose_(self)
    end
end

function Menu:Toggle()
    if self.isOpen_ then
        self:Close()
    else
        self:Open()
    end
end

-- ============================================================================
-- Items Management
-- ============================================================================

function Menu:GetItems()
    return self.items_
end

function Menu:SetItems(items)
    self.items_ = items or {}
end

function Menu:AddItem(item)
    table.insert(self.items_, item)
end

function Menu:RemoveItem(index)
    table.remove(self.items_, index)
end

-- ============================================================================
-- Submenu Management
-- ============================================================================

function Menu:OpenSubmenu(item, x, y)
    self:CloseSubmenu()

    if item.items and #item.items > 0 then
        self.activeSubmenu_ = item
        self.submenuWidget_ = Menu {
            items = item.items,
            size = self.size_,
            variant = self.variant_,
            dense = self.dense_,
            anchorX = x,
            anchorY = y,
            onItemClick = function(menu, clickedItem, index)
                if self.onItemClick_ then
                    self.onItemClick_(self, clickedItem, index)
                end
                self:Close()
            end,
        }
    end
end

function Menu:CloseSubmenu()
    self.activeSubmenu_ = nil
    self.submenuWidget_ = nil
end

-- ============================================================================
-- Drawing Helpers
-- ============================================================================

function Menu:DrawIcon(nvg, x, y, icon, color, iconSize)
    nvgFontSize(nvg, iconSize)
    nvgFontFace(nvg, Theme.FontFamily())
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, color)
    nvgText(nvg, x, y, icon)
end

function Menu:DrawCheckmark(nvg, x, y, color, iconSize)
    local size = iconSize * 0.5

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x - size * 0.5, y)
    nvgLineTo(nvg, x - size * 0.1, y + size * 0.4)
    nvgLineTo(nvg, x + size * 0.5, y - size * 0.3)
    nvgStrokeColor(nvg, color)
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
end

function Menu:DrawSubmenuArrow(nvg, x, y, color, fontSize)
    local size = fontSize * 0.3

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x - size * 0.3, y - size)
    nvgLineTo(nvg, x + size * 0.5, y)
    nvgLineTo(nvg, x - size * 0.3, y + size)
    nvgStrokeColor(nvg, color)
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
end

-- ============================================================================
-- Render
-- ============================================================================

function Menu:Render(nvg)
    local x, y = self:GetAbsolutePosition()
    local w, h = self:GetComputedSize()
    local theme = Theme.GetTheme()

    -- Size values (no scale needed - nvgScale handles it)
    local itemHeight = self.itemHeight_
    local fontSize = Theme.FontSize(SIZE_PRESETS[self.size_].fontSize)
    local iconSize = self.iconSize_
    local padding = self.padding_
    local borderRadius = self.borderRadius_ or 8

    -- Apply anchor position
    x = x + self.anchorX_
    y = y + self.anchorY_

    -- Draw shadow for elevated variant
    if self.variant_ == "elevated" then
        -- Shadow layers
        for i = 3, 1, -1 do
            local shadowOffset = i
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x - shadowOffset, y + shadowOffset * 2, w + shadowOffset * 2, h + shadowOffset * 2, borderRadius + shadowOffset)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 15 * i))
            nvgFill(nvg)
        end
    end

    -- Draw background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, borderRadius)
    nvgFillColor(nvg, Theme.NvgColor("surface"))
    nvgFill(nvg)

    -- Draw border for outlined variant
    if self.variant_ == "outlined" then
        nvgStrokeColor(nvg, Theme.NvgColor("border"))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    -- Store item positions for hit testing
    self.itemPositions_ = {}

    local currentY = y + padding
    local contentX = x + padding
    local contentWidth = w - padding * 2

    -- Calculate icon column width
    local hasIcons = false
    local hasCheckable = false
    local hasSubmenu = false

    for _, item in ipairs(self.items_) do
        if item.icon then hasIcons = true end
        if item.checked ~= nil then hasCheckable = true end
        if item.items then hasSubmenu = true end
    end

    local iconColWidth = (hasIcons or hasCheckable) and (iconSize + padding) or 0
    local arrowColWidth = hasSubmenu and (iconSize) or 0

    for i, item in ipairs(self.items_) do
        if item.type == "divider" then
            -- Draw divider
            currentY = currentY + 4
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, contentX, currentY)
            nvgLineTo(nvg, contentX + contentWidth, currentY)
            nvgStrokeColor(nvg, Theme.NvgColor("border"))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
            currentY = currentY + 5
        elseif item.type == "header" then
            -- Draw header
            local headerHeight = itemHeight * 0.8
            nvgFontSize(nvg, fontSize * 0.85)
            nvgFontFace(nvg, Theme.FontFamily())
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
            nvgText(nvg, contentX + iconColWidth, currentY + headerHeight / 2, item.label or item.text or "")
            currentY = currentY + headerHeight
        else
            -- Draw menu item
            local itemY = currentY
            local isHovered = self.hoverIndex_ == i
            local isDisabled = item.disabled
            local isActive = item == self.activeSubmenu_

            -- Hover/active background
            if (isHovered or isActive) and not isDisabled then
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, contentX, itemY, contentWidth, itemHeight, 4)
                local primaryColor = Theme.Color("primary")
                nvgFillColor(nvg, nvgTransRGBAf(nvgRGBA(primaryColor[1], primaryColor[2], primaryColor[3], primaryColor[4] or 255), 0.1))
                nvgFill(nvg)
            end

            -- Text color
            local textColor
            if isDisabled then
                textColor = Theme.NvgColor("textDisabled")
            elseif isHovered or isActive then
                textColor = Theme.NvgColor("primary")
            else
                textColor = Theme.NvgColor("text")
            end

            local textX = contentX + iconColWidth + padding
            local centerY = itemY + itemHeight / 2

            -- Draw check mark or icon
            if item.checked then
                self:DrawCheckmark(nvg, contentX + iconColWidth / 2, centerY, textColor, iconSize)
            elseif item.icon and self.showIcons_ then
                self:DrawIcon(nvg, contentX + iconColWidth / 2, centerY, item.icon, textColor, iconSize)
            end

            -- Draw label
            nvgFontSize(nvg, fontSize)
            nvgFontFace(nvg, Theme.FontFamily())
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, textColor)
            nvgText(nvg, textX, centerY, item.label or item.text or "")

            -- Draw shortcut
            if item.shortcut and self.showShortcuts_ then
                nvgFontSize(nvg, fontSize * 0.85)
                nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
                nvgText(nvg, x + w - padding - arrowColWidth - padding, centerY, item.shortcut)
            end

            -- Draw submenu arrow
            if item.items and #item.items > 0 then
                self:DrawSubmenuArrow(nvg, x + w - padding - arrowColWidth / 2, centerY, textColor, fontSize)
            end

            -- Store position for hit testing
            self.itemPositions_[i] = {
                x1 = contentX,
                x2 = contentX + contentWidth,
                y1 = itemY,
                y2 = itemY + itemHeight,
                item = item,
                index = i,
            }

            currentY = currentY + itemHeight
        end
    end

    -- Render submenu
    if self.submenuWidget_ then
        self.submenuWidget_:Render(nvg)
    end
end

-- ============================================================================
-- Input Handling
-- ============================================================================

function Menu:GetItemAtPosition(screenX, screenY)
    if not self.itemPositions_ then return nil end

    -- Get offset between render coords and screen coords
    local renderX, renderY = self:GetAbsolutePosition()
    local hitTest = self:GetAbsoluteLayoutForHitTest()
    local offsetX = renderX - hitTest.x
    local offsetY = renderY - hitTest.y

    -- Convert screen coords to render coords
    local px = screenX + offsetX
    local py = screenY + offsetY

    -- Use pairs instead of ipairs because itemPositions_ may have gaps (dividers/headers don't store positions)
    for i, pos in pairs(self.itemPositions_) do
        if px >= pos.x1 and px <= pos.x2 and py >= pos.y1 and py <= pos.y2 then
            return pos
        end
    end

    return nil
end

function Menu:OnPointerMove(event)
    if not event then return end
    if not self.isOpen_ then return end

    -- Check submenu first
    if self.submenuWidget_ then
        self.submenuWidget_:OnPointerMove(event)
    end

    local itemPos = self:GetItemAtPosition(event.x, event.y)

    if itemPos and not itemPos.item.disabled and itemPos.item.type ~= "divider" and itemPos.item.type ~= "header" then
        self.hoverIndex_ = itemPos.index

        -- Open submenu on hover
        if itemPos.item.items and #itemPos.item.items > 0 then
            local x, y = self:GetAbsolutePosition()
            local w = self:GetComputedSize()
            self:OpenSubmenu(itemPos.item, x + w + self.anchorX_, itemPos.y1 - y)
        else
            self:CloseSubmenu()
        end
    else
        self.hoverIndex_ = nil
    end
end

function Menu:OnMouseLeave()
    -- Don't clear hover if moving to submenu
    if not self.submenuWidget_ then
        self.hoverIndex_ = nil
    end
end

function Menu:OnClick(event)
    if not event then return end
    if not self.isOpen_ then return end

    -- Check submenu first
    if self.submenuWidget_ then
        self.submenuWidget_:OnClick(event)
        return
    end

    local itemPos = self:GetItemAtPosition(event.x, event.y)

    if itemPos and not itemPos.item.disabled then
        local item = itemPos.item

        -- Skip dividers and headers
        if item.type == "divider" or item.type == "header" then
            return
        end

        -- Handle checkable items
        if item.checked ~= nil then
            item.checked = not item.checked
        end

        -- Skip if has submenu (handled by hover)
        if item.items and #item.items > 0 then
            return
        end

        -- Call item onClick
        if item.onClick then
            item.onClick(item, itemPos.index)
        end

        -- Call menu onItemClick
        if self.onItemClick_ then
            self.onItemClick_(self, item, itemPos.index)
        end

        -- Close menu after selection (unless specified otherwise)
        if item.keepOpen ~= true then
            self:Close()
        end
    end
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a simple menu from labels
---@param labels string[] Array of labels
---@param onClick function Click handler
---@param props table|nil Additional props
---@return Menu
function Menu.FromLabels(labels, onClick, props)
    props = props or {}

    local items = {}
    for i, label in ipairs(labels) do
        if label == "-" or label == "---" then
            table.insert(items, { type = "divider" })
        else
            table.insert(items, {
                label = label,
                onClick = function(item, index)
                    if onClick then onClick(label, index) end
                end,
            })
        end
    end

    props.items = items
    return Menu(props)
end

--- Create a context menu
---@param items table[] Menu items
---@param x number X position
---@param y number Y position
---@param props table|nil Additional props
---@return Menu
function Menu.Context(items, x, y, props)
    props = props or {}
    props.items = items
    props.anchorX = x
    props.anchorY = y
    props.variant = props.variant or "elevated"
    return Menu(props)
end

--- Create an action menu (common actions)
---@param actions table Action handlers { onCut, onCopy, onPaste, onDelete, ... }
---@param props table|nil Additional props
---@return Menu
function Menu.Actions(actions, props)
    props = props or {}

    local items = {}

    if actions.onUndo then
        table.insert(items, { label = "Undo", icon = "U", shortcut = "Ctrl+Z", onClick = actions.onUndo })
    end
    if actions.onRedo then
        table.insert(items, { label = "Redo", icon = "R", shortcut = "Ctrl+Y", onClick = actions.onRedo })
    end
    if actions.onUndo or actions.onRedo then
        table.insert(items, { type = "divider" })
    end

    if actions.onCut then
        table.insert(items, { label = "Cut", icon = "X", shortcut = "Ctrl+X", onClick = actions.onCut })
    end
    if actions.onCopy then
        table.insert(items, { label = "Copy", icon = "C", shortcut = "Ctrl+C", onClick = actions.onCopy })
    end
    if actions.onPaste then
        table.insert(items, { label = "Paste", icon = "V", shortcut = "Ctrl+V", onClick = actions.onPaste })
    end
    if actions.onCut or actions.onCopy or actions.onPaste then
        table.insert(items, { type = "divider" })
    end

    if actions.onSelectAll then
        table.insert(items, { label = "Select All", shortcut = "Ctrl+A", onClick = actions.onSelectAll })
    end
    if actions.onDelete then
        table.insert(items, { label = "Delete", icon = "D", shortcut = "Del", onClick = actions.onDelete })
    end

    props.items = items
    return Menu(props)
end

--- Create a navigation menu
---@param routes table[] Array of { label, path, icon, children }
---@param onNavigate function Navigation handler
---@param props table|nil Additional props
---@return Menu
function Menu.Navigation(routes, onNavigate, props)
    props = props or {}

    local function buildItems(routeList)
        local items = {}
        for _, route in ipairs(routeList) do
            local item = {
                label = route.label,
                icon = route.icon,
                onClick = function()
                    if onNavigate then onNavigate(route.path, route) end
                end,
            }

            if route.children and #route.children > 0 then
                item.items = buildItems(route.children)
            end

            table.insert(items, item)
        end
        return items
    end

    props.items = buildItems(routes)
    return Menu(props)
end

--- Create a select menu (single selection)
---@param options table[] Array of { label, value }
---@param selectedValue any Currently selected value
---@param onSelect function Selection handler
---@param props table|nil Additional props
---@return Menu
function Menu.Select(options, selectedValue, onSelect, props)
    props = props or {}

    local items = {}
    for _, opt in ipairs(options) do
        table.insert(items, {
            label = opt.label,
            checked = opt.value == selectedValue,
            onClick = function()
                if onSelect then onSelect(opt.value, opt) end
            end,
        })
    end

    props.items = items
    return Menu(props)
end

return Menu
