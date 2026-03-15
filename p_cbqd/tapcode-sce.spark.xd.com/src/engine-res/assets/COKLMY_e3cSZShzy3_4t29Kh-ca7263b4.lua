-- ============================================================================
-- Drawer Widget
-- Sliding panel from screen edge
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")
local UI = require("urhox-libs/UI/Core/UI")

---@class DrawerProps : WidgetProps
---@field position string|nil "left" | "right" | "top" | "bottom" (default: "left")
---@field size number|nil Width for left/right, height for top/bottom (default: 300)
---@field variant string|nil "temporary" | "permanent" | "persistent" (default: "temporary")
---@field showOverlay boolean|nil Show overlay background for temporary variant (default: true)
---@field overlayOpacity number|nil Overlay opacity 0-1 (default: 0.5)
---@field elevation number|nil Shadow elevation (default: 16)
---@field animationDuration number|nil Open/close animation duration in seconds (default: 0.25)
---@field isOpen boolean|nil Initial open state
---@field onOpen fun(drawer: Drawer)|nil Called when drawer opens
---@field onClose fun(drawer: Drawer)|nil Called when drawer closes
---@field onChange fun(drawer: Drawer, isOpen: boolean)|nil Called when open state changes
---@field content Widget|fun(nvg: any, x: number, y: number, w: number, h: number)|nil Drawer content
---@field header string|Widget|fun(nvg: any, x: number, y: number, w: number, h: number)|nil Header content
---@field footer string|Widget|fun(nvg: any, x: number, y: number, w: number, h: number)|nil Footer content
---@field backgroundColor table|nil Background color (default: surface)
---@field headerHeight number|nil Header height (default: 56)
---@field showCloseButton boolean|nil Show close button (default: false)
---@field screenWidth number|nil Screen width for positioning
---@field screenHeight number|nil Screen height for positioning

---@class Drawer : Widget
---@operator call(DrawerProps?): Drawer
---@field props DrawerProps
---@field new fun(self, props: DrawerProps?): Drawer
local Drawer = Widget:Extend("Drawer")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props DrawerProps?
function Drawer:Init(props)
    props = props or {}

    -- Drawer props
    self.position_ = props.position or "left"  -- left, right, top, bottom
    self.size_ = props.size or 300  -- Width for left/right, height for top/bottom
    self.variant_ = props.variant or "temporary"  -- temporary, permanent, persistent

    -- Visual
    self.showOverlay_ = props.showOverlay ~= false  -- default true (for temporary)
    self.overlayOpacity_ = props.overlayOpacity or 0.5
    self.elevation_ = props.elevation or 16

    -- Animation
    self.animationDuration_ = props.animationDuration or 0.25

    -- State
    self.isOpen_ = props.isOpen or (self.variant_ == "permanent")
    self.animating_ = false
    self.animationProgress_ = self.isOpen_ and 1 or 0
    self.animationTarget_ = self.animationProgress_

    -- Callbacks
    self.onOpen_ = props.onOpen
    self.onClose_ = props.onClose
    self.onChange_ = props.onChange

    -- Content
    self.content_ = props.content  -- Child widget or render function
    self.header_ = props.header
    self.footer_ = props.footer

    -- Styling
    self.backgroundColor_ = props.backgroundColor or Theme.Color("surface")
    self.headerHeight_ = props.headerHeight or 56
    self.showCloseButton_ = props.showCloseButton or false

    -- Screen size (will be set during render)
    self.screenWidth_ = props.screenWidth or 800
    self.screenHeight_ = props.screenHeight or 600

    -- Drawer needs absolute positioning to overlay content
    -- HitTest is overridden to only intercept events when open
    props.position = "absolute"
    props.left = 0
    props.top = 0
    props.width = "100%"
    props.height = "100%"

    Widget.Init(self, props)
end

-- ============================================================================
-- Open/Close
-- ============================================================================

function Drawer:Open()
    if self.isOpen_ then return end

    self.isOpen_ = true
    self.animating_ = true
    self.animationTarget_ = 1

    -- Register as active overlay to receive events
    UI.PushOverlay(self)

    if self.onOpen_ then
        self.onOpen_(self)
    end

    if self.onChange_ then
        self.onChange_(self, true)
    end
end

function Drawer:Close()
    if not self.isOpen_ then return end
    if self.variant_ == "permanent" then return end

    self.isOpen_ = false
    self.animating_ = true
    self.animationTarget_ = 0

    -- Clear active overlay
    UI.PopOverlay(self)

    if self.onClose_ then
        self.onClose_(self)
    end

    if self.onChange_ then
        self.onChange_(self, false)
    end
end

function Drawer:Toggle()
    if self.isOpen_ then
        self:Close()
    else
        self:Open()
    end
end

function Drawer:IsOpen()
    return self.isOpen_
end

-- ============================================================================
-- Content
-- ============================================================================

function Drawer:SetContent(content)
    self.content_ = content
end

function Drawer:SetHeader(header)
    self.header_ = header
end

function Drawer:SetFooter(footer)
    self.footer_ = footer
end

-- ============================================================================
-- Update
-- ============================================================================

function Drawer:Update(dt)
    if self.animating_ then
        local speed = 1 / self.animationDuration_
        local diff = self.animationTarget_ - self.animationProgress_

        if math.abs(diff) < 0.01 then
            self.animationProgress_ = self.animationTarget_
            self.animating_ = false
        else
            self.animationProgress_ = self.animationProgress_ + diff * speed * dt * 4
        end
    end
end

-- ============================================================================
-- Render
-- ============================================================================

function Drawer:Render(nvg)
    -- Don't render if completely closed and not animating
    if self.animationProgress_ <= 0 and not self.animating_ then
        return
    end

    -- Queue drawer rendering as overlay to avoid parent transform issues
    UI.QueueOverlay(function(overlayNvg)
        self:RenderDrawerContent(overlayNvg)
    end)
end

function Drawer:RenderDrawerContent(nvg)
    -- Get screen size from UI
    local screenWidth = UI.GetWidth() or 800
    local screenHeight = UI.GetHeight() or 600
    self.screenWidth_ = screenWidth
    self.screenHeight_ = screenHeight

    local progress = self:EaseOutCubic(self.animationProgress_)

    -- Render overlay (for temporary variant)
    if self.showOverlay_ and self.variant_ == "temporary" then
        self:RenderOverlay(nvg, progress)
    end

    -- Calculate drawer position
    local x, y, w, h = self:CalculateDrawerBounds(progress)

    -- Store bounds for hit testing (now in screen coordinates)
    self.drawerBounds_ = { x = x, y = y, w = w, h = h }

    -- Shadow
    if self.elevation_ > 0 then
        local shadowBlur = self.elevation_

        if self.position_ == "left" then
            nvgBeginPath(nvg)
            nvgRect(nvg, x + w, y, shadowBlur, h)
            local grad = nvgLinearGradient(nvg, x + w, y, x + w + shadowBlur, y,
                nvgRGBA(0, 0, 0, 40), nvgRGBA(0, 0, 0, 0))
            nvgFillPaint(nvg, grad)
            nvgFill(nvg)
        elseif self.position_ == "right" then
            nvgBeginPath(nvg)
            nvgRect(nvg, x - shadowBlur, y, shadowBlur, h)
            local grad = nvgLinearGradient(nvg, x - shadowBlur, y, x, y,
                nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 40))
            nvgFillPaint(nvg, grad)
            nvgFill(nvg)
        elseif self.position_ == "top" then
            nvgBeginPath(nvg)
            nvgRect(nvg, x, y + h, w, shadowBlur)
            local grad = nvgLinearGradient(nvg, x, y + h, x, y + h + shadowBlur,
                nvgRGBA(0, 0, 0, 40), nvgRGBA(0, 0, 0, 0))
            nvgFillPaint(nvg, grad)
            nvgFill(nvg)
        elseif self.position_ == "bottom" then
            nvgBeginPath(nvg)
            nvgRect(nvg, x, y - shadowBlur, w, shadowBlur)
            local grad = nvgLinearGradient(nvg, x, y - shadowBlur, x, y,
                nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 40))
            nvgFillPaint(nvg, grad)
            nvgFill(nvg)
        end
    end

    -- Background
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, Theme.ToNvgColor(self.backgroundColor_))
    nvgFill(nvg)

    -- Clip content
    nvgSave(nvg)
    nvgIntersectScissor(nvg, x, y, w, h)

    local contentY = y

    -- Header
    if self.header_ then
        self:RenderHeader(nvg, x, contentY, w)
        contentY = contentY + self.headerHeight_

        -- Divider
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, contentY)
        nvgLineTo(nvg, x + w, contentY)
        nvgStrokeColor(nvg, Theme.NvgColor("border"))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    -- Content
    local contentHeight = h - (self.header_ and self.headerHeight_ or 0) - (self.footer_ and self.headerHeight_ or 0)
    if self.content_ then
        if type(self.content_) == "function" then
            self.content_(nvg, x, contentY, w, contentHeight)
        elseif self.content_.Render then
            -- It's a widget
            nvgSave(nvg)
            nvgTranslate(nvg, x, contentY)
            self.content_:Render(nvg)
            nvgRestore(nvg)
        end
    end

    -- Footer
    if self.footer_ then
        local footerY = y + h - self.headerHeight_

        -- Divider
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, footerY)
        nvgLineTo(nvg, x + w, footerY)
        nvgStrokeColor(nvg, Theme.NvgColor("border"))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)

        self:RenderFooter(nvg, x, footerY, w)
    end

    nvgRestore(nvg)

    -- Close button
    if self.showCloseButton_ then
        self:RenderCloseButton(nvg, x, y, w)
    end
end

function Drawer:RenderOverlay(nvg, progress)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, self.screenWidth_, self.screenHeight_)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(255 * self.overlayOpacity_ * progress)))
    nvgFill(nvg)

    self.overlayBounds_ = { x = 0, y = 0, w = self.screenWidth_, h = self.screenHeight_ }
end

function Drawer:RenderHeader(nvg, x, y, w)
    local theme = Theme.GetTheme()

    if type(self.header_) == "string" then
        -- Simple title
        nvgFontSize(nvg, Theme.FontSizeOf("subtitle"))
        nvgFontFace(nvg, Theme.FontFamily())
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, Theme.NvgColor("text"))
        nvgText(nvg, x + 16, y + self.headerHeight_ / 2, self.header_)
    elseif type(self.header_) == "function" then
        self.header_(nvg, x, y, w, self.headerHeight_)
    elseif self.header_.Render then
        nvgSave(nvg)
        nvgTranslate(nvg, x, y)
        self.header_:Render(nvg)
        nvgRestore(nvg)
    end
end

function Drawer:RenderFooter(nvg, x, y, w)
    local theme = Theme.GetTheme()

    if type(self.footer_) == "string" then
        nvgFontSize(nvg, Theme.FontSizeOf("body"))
        nvgFontFace(nvg, Theme.FontFamily())
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
        nvgText(nvg, x + 16, y + self.headerHeight_ / 2, self.footer_)
    elseif type(self.footer_) == "function" then
        self.footer_(nvg, x, y, w, self.headerHeight_)
    elseif self.footer_.Render then
        nvgSave(nvg)
        nvgTranslate(nvg, x, y)
        self.footer_:Render(nvg)
        nvgRestore(nvg)
    end
end

function Drawer:RenderCloseButton(nvg, x, y, w)
    local btnSize = 32
    local btnX, btnY

    if self.position_ == "left" then
        btnX = x + w - btnSize - 8
        btnY = y + 12
    elseif self.position_ == "right" then
        btnX = x + 8
        btnY = y + 12
    else
        btnX = x + w - btnSize - 8
        btnY = y + 12
    end

    self.closeButtonBounds_ = { x = btnX, y = btnY, w = btnSize, h = btnSize }

    -- Button background on hover
    if self.hoverCloseButton_ then
        nvgBeginPath(nvg)
        nvgCircle(nvg, btnX + btnSize / 2, btnY + btnSize / 2, btnSize / 2)
        nvgFillColor(nvg, Theme.NvgColor("surfaceHover"))
        nvgFill(nvg)
    end

    -- X icon
    local centerX = btnX + btnSize / 2
    local centerY = btnY + btnSize / 2
    local iconSize = 8

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, centerX - iconSize, centerY - iconSize)
    nvgLineTo(nvg, centerX + iconSize, centerY + iconSize)
    nvgMoveTo(nvg, centerX + iconSize, centerY - iconSize)
    nvgLineTo(nvg, centerX - iconSize, centerY + iconSize)
    nvgStrokeColor(nvg, Theme.NvgColor("text"))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
end

function Drawer:CalculateDrawerBounds(progress)
    local x, y, w, h

    if self.position_ == "left" then
        w = self.size_
        h = self.screenHeight_
        x = -w + (w * progress)
        y = 0
    elseif self.position_ == "right" then
        w = self.size_
        h = self.screenHeight_
        x = self.screenWidth_ - (w * progress)
        y = 0
    elseif self.position_ == "top" then
        w = self.screenWidth_
        h = self.size_
        x = 0
        y = -h + (h * progress)
    elseif self.position_ == "bottom" then
        w = self.screenWidth_
        h = self.size_
        x = 0
        y = self.screenHeight_ - (h * progress)
    end

    return x, y, w, h
end

-- ============================================================================
-- Easing
-- ============================================================================

function Drawer:EaseOutCubic(t)
    return 1 - math.pow(1 - t, 3)
end

-- ============================================================================
-- Hit Testing
-- ============================================================================

--- Override HitTest - only intercept events when open or animating
function Drawer:HitTest(x, y)
    -- Don't intercept events when closed
    if self.animationProgress_ <= 0 and not self.animating_ then
        return false
    end

    -- When open, check if click is on overlay or drawer
    return true
end

-- ============================================================================
-- Input Handling
-- ============================================================================

function Drawer:PointInBounds(px, py, bounds)
    if not bounds then return false end
    return px >= bounds.x and px <= bounds.x + bounds.w and
           py >= bounds.y and py <= bounds.y + bounds.h
end

function Drawer:OnPointerMove(event)
    if not event then return end
    if not self.isOpen_ and not self.animating_ then return end

    -- Drawer is a full-screen overlay, use event coords directly
    local px, py = event.x, event.y

    -- Check close button hover
    local wasHover = self.hoverCloseButton_
    self.hoverCloseButton_ = self.showCloseButton_ and
                             self.closeButtonBounds_ and
                             self:PointInBounds(px, py, self.closeButtonBounds_)
end

function Drawer:OnClick(event)
    if not event then return end

    -- Drawer is a full-screen overlay, use event coords directly
    local px, py = event.x, event.y

    -- Check close button
    if self.showCloseButton_ and self:PointInBounds(px, py, self.closeButtonBounds_) then
        self:Close()
        return true
    end

    -- Check click outside drawer (close for temporary variant)
    if self.variant_ == "temporary" then
        if not self:PointInBounds(px, py, self.drawerBounds_) then
            self:Close()
            return true
        end
    end

    return false
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a left drawer
---@param props table|nil
---@return Drawer
function Drawer.Left(props)
    props = props or {}
    props.position = "left"
    return Drawer(props)
end

--- Create a right drawer
---@param props table|nil
---@return Drawer
function Drawer.Right(props)
    props = props or {}
    props.position = "right"
    return Drawer(props)
end

--- Create a top drawer
---@param props table|nil
---@return Drawer
function Drawer.Top(props)
    props = props or {}
    props.position = "top"
    return Drawer(props)
end

--- Create a bottom drawer
---@param props table|nil
---@return Drawer
function Drawer.Bottom(props)
    props = props or {}
    props.position = "bottom"
    return Drawer(props)
end

--- Create a navigation drawer
---@param title string
---@param items table[] Menu items
---@param props table|nil
---@return Drawer
function Drawer.Navigation(title, items, props)
    props = props or {}
    props.header = title
    props.position = "left"
    props.size = props.size or 280
    props.showCloseButton = true

    -- Content will be rendered as menu items
    props.content = function(nvg, x, y, w, h)
        local theme = Theme.GetTheme()
        local itemHeight = 48
        local currentY = y + 8

        for i, item in ipairs(items) do
            local itemY = currentY + (i - 1) * itemHeight

            nvgFontSize(nvg, Theme.FontSizeOf("body"))
            nvgFontFace(nvg, Theme.FontFamily())
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

            -- Icon
            if item.icon then
                nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
                nvgText(nvg, x + 16, itemY + itemHeight / 2, item.icon)
            end

            -- Label
            nvgFillColor(nvg, Theme.NvgColor("text"))
            nvgText(nvg, x + 56, itemY + itemHeight / 2, item.label or item.text or "")
        end
    end

    return Drawer(props)
end

--- Create a bottom sheet drawer
---@param props table|nil
---@return Drawer
function Drawer.BottomSheet(props)
    props = props or {}
    props.position = "bottom"
    props.size = props.size or 400
    return Drawer(props)
end

return Drawer
