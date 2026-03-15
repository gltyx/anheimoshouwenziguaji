-- ============================================================================
-- Card Widget
-- UrhoX UI Library - Yoga + NanoVG
-- Card container with header, body, footer sections
-- Uses internal Yoga containers for proper layout of nested widgets
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local Theme = require("urhox-libs/UI/Core/Theme")

---@class CardProps : WidgetProps
---@field variant string|nil "elevated" | "outlined" | "filled" (default: "elevated")
---@field elevation number|nil Shadow elevation 0-5 (default: 2)
---@field hoverable boolean|nil Enable hover effect
---@field clickable boolean|nil Enable click effect
---@field header Widget|string|nil Header content or title string
---@field footer Widget|nil Footer content
---@field coverImage string|nil Cover image path
---@field coverHeight number|nil Cover image height (default: 160)

---@class Card : Widget
---@operator call(CardProps?): Card
---@field props CardProps
---@field new fun(self, props: CardProps?): Card
---@field SetHeader fun(self, header: Widget|string): Card
---@field AddBody fun(self, child: Widget): Card
---@field AddAction fun(self, button: Widget): Card
local Card = Widget:Extend("Card")

-- ============================================================================
-- Constructor
-- ============================================================================

---@param props CardProps?
function Card:Init(props)
    props = props or {}

    -- Apply theme defaults
    local themeStyle = Theme.ComponentStyle("Card")
    props.borderRadius = props.borderRadius or themeStyle.borderRadius or 12

    -- Default settings
    props.variant = props.variant or "elevated"
    props.elevation = props.elevation or 2
    props.hoverable = props.hoverable or false
    props.clickable = props.clickable or false
    props.coverHeight = props.coverHeight or 160

    -- Default flex layout - column direction for header/body/footer
    props.flexDirection = props.flexDirection or "column"

    -- Default padding for direct children (when not using SetHeader/AddBody)
    props.padding = props.padding or 16
    props.gap = props.gap or 8

    -- Clip content that overflows card bounds
    props.overflow = props.overflow or "hidden"

    -- State
    self.state = {
        hovered = false,
        pressed = false,
    }

    -- Internal containers (real Yoga children)
    self.headerContainer_ = nil  -- Created on demand
    self.bodyContainer_ = nil    -- Created on demand
    self.footerContainer_ = nil  -- Created on demand

    -- Image handle (for cover image feature)
    self.coverImageHandle_ = nil

    Widget.Init(self, props)
end

-- ============================================================================
-- Internal: Create containers on demand
-- ============================================================================

--- Clear Card's own padding when using internal containers
function Card:ClearCardPadding()
    if self.props.padding ~= 0 then
        self.props.padding = 0
        YGNodeStyleSetPadding(self.node, YGEdgeAll, 0)
    end
    if self.props.gap ~= 0 then
        self.props.gap = 0
        YGNodeStyleSetGap(self.node, YGGutterAll, 0)
    end
end

--- Create or get header container
function Card:GetOrCreateHeaderContainer()
    if not self.headerContainer_ then
        -- Clear Card's padding when using internal containers
        self:ClearCardPadding()

        local Panel = require("urhox-libs/UI/Widgets/Panel")
        self.headerContainer_ = Panel:new({
            width = "100%",
            flexDirection = "column",
            padding = 16,
            paddingBottom = 12,
            backgroundColor = false,  -- Transparent, Card handles background
            borderRadius = 0,
        })
        -- Insert at beginning
        self:InsertChild(self.headerContainer_, 1)
    end
    return self.headerContainer_
end

--- Create or get body container
function Card:GetOrCreateBodyContainer()
    if not self.bodyContainer_ then
        -- Clear Card's padding when using internal containers
        self:ClearCardPadding()

        local Panel = require("urhox-libs/UI/Widgets/Panel")
        self.bodyContainer_ = Panel:new({
            width = "100%",
            flexDirection = "column",
            padding = 16,
            paddingTop = 12,
            paddingBottom = 12,
            flexGrow = 1,
            gap = 8,
            backgroundColor = false,  -- Transparent, Card handles background
            borderRadius = 0,
        })
        -- Insert after header (if exists) or at beginning
        local insertIndex = self.headerContainer_ and 2 or 1
        self:InsertChild(self.bodyContainer_, insertIndex)
    end
    return self.bodyContainer_
end

--- Create or get footer container
function Card:GetOrCreateFooterContainer()
    if not self.footerContainer_ then
        -- Clear Card's padding when using internal containers
        self:ClearCardPadding()

        local Panel = require("urhox-libs/UI/Widgets/Panel")
        self.footerContainer_ = Panel:new({
            width = "100%",
            flexDirection = "row",
            justifyContent = "flex-end",
            padding = 16,
            paddingTop = 12,
            gap = 8,
            backgroundColor = false,  -- Transparent, Card handles background
            borderRadius = 0,
        })
        -- Always add at end
        self:AddChild(self.footerContainer_)
    end
    return self.footerContainer_
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Card:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local props = self.props
    local state = self.state

    local variant = props.variant
    local elevation = props.elevation
    local borderRadius = props.borderRadius
    local hoverable = props.hoverable
    local clickable = props.clickable

    -- Adjust elevation on hover/press
    local currentElevation = elevation
    if state.pressed and clickable then
        currentElevation = math.max(0, elevation - 1)
    elseif state.hovered and (hoverable or clickable) then
        currentElevation = elevation + 1
    end

    -- Draw shadow (for elevated variant)
    if variant == "elevated" and currentElevation > 0 then
        self:RenderShadow(nvg, l.x, l.y, l.w, l.h, borderRadius, currentElevation)
    end

    -- Get background color
    local bgColor
    if variant == "filled" then
        bgColor = Theme.Color("surface")
    else
        bgColor = Theme.Color("background")
    end

    -- Draw background
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
    nvgFillColor(nvg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 255))
    nvgFill(nvg)

    -- Draw border (for outlined variant)
    if variant == "outlined" then
        local borderColor = Theme.Color("border")
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
        nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 255))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    -- Draw hover overlay
    if state.hovered and (hoverable or clickable) then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, borderRadius)
        nvgFillColor(nvg, nvgRGBA(128, 128, 128, 15))
        nvgFill(nvg)
    end

    -- Draw separators (after children so layout is computed)
    self:RenderSeparators(nvg, l)
end

--- Render separators between sections
function Card:RenderSeparators(nvg, l)
    local borderColor = Theme.Color("border")
    local padding = 16

    nvgSave(nvg)
    nvgLineCap(nvg, NVG_BUTT)

    -- Header separator
    if self.headerContainer_ and (self.bodyContainer_ or self.footerContainer_) then
        local hl = self.headerContainer_:GetAbsoluteLayout()
        local separatorY = math.floor(hl.y + hl.h) + 0.5

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, l.x + padding, separatorY)
        nvgLineTo(nvg, l.x + l.w - padding, separatorY)
        nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], 150))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    -- Footer separator
    if self.footerContainer_ and (self.headerContainer_ or self.bodyContainer_) then
        local fl = self.footerContainer_:GetAbsoluteLayout()
        local separatorY = math.floor(fl.y) + 0.5

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, l.x + padding, separatorY)
        nvgLineTo(nvg, l.x + l.w - padding, separatorY)
        nvgStrokeColor(nvg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], 150))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end

    nvgRestore(nvg)
end

--- Render card shadow
function Card:RenderShadow(nvg, x, y, w, h, radius, elevation)
    -- Multiple shadow layers for depth
    local shadows = {
        { offset = 1, blur = 2, alpha = 0.05 },
        { offset = 2, blur = 4, alpha = 0.05 },
        { offset = 4, blur = 8, alpha = 0.05 },
        { offset = 8, blur = 16, alpha = 0.04 },
        { offset = 16, blur = 32, alpha = 0.03 },
    }

    for i = 1, math.min(elevation, #shadows) do
        local s = shadows[i]
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x - s.blur/2, y + s.offset, w + s.blur, h + s.blur/2, radius + 2)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(255 * s.alpha)))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Card:OnMouseEnter()
    if self.props.hoverable or self.props.clickable then
        self:SetState({ hovered = true })
    end
end

function Card:OnMouseLeave()
    self:SetState({ hovered = false, pressed = false })
end

function Card:OnPointerDown(event)
    if not event then return end
    if self.props.clickable and event:IsPrimaryAction() then
        self:SetState({ pressed = true })
    end
end

function Card:OnPointerUp(event)
    if not event then return end
    if event:IsPrimaryAction() then
        self:SetState({ pressed = false })
    end
end

function Card:OnClick()
    if self.props.clickable and self.props.onClick then
        self.props.onClick(self)
    end
end

-- ============================================================================
-- Content Management
-- ============================================================================

--- Set header content
---@param header Widget|string Header widget or title string
---@return Card self
function Card:SetHeader(header)
    local container = self:GetOrCreateHeaderContainer()

    -- Clear existing content
    container:ClearChildren()

    if type(header) == "string" then
        -- Create a Label for string header
        local Label = require("urhox-libs/UI/Widgets/Label")
        container:AddChild(Label:new({
            text = header,
            fontSize = Theme.BaseFontSize("subtitle"),
            fontWeight = "bold",
            color = Theme.Color("text"),
        }))
    else
        -- Add widget directly
        container:AddChild(header)
    end

    return self
end

--- Add content to body
---@param child Widget
---@return Card self
function Card:AddBody(child)
    local container = self:GetOrCreateBodyContainer()
    container:AddChild(child)
    return self
end

--- Clear body content
---@return Card self
function Card:ClearBody()
    if self.bodyContainer_ then
        self.bodyContainer_:ClearChildren()
    end
    return self
end

--- Set footer content
---@param footer Widget
---@return Card self
function Card:SetFooter(footer)
    local container = self:GetOrCreateFooterContainer()

    -- Clear existing content
    container:ClearChildren()

    -- Add widget
    container:AddChild(footer)

    return self
end

--- Add action button to footer
---@param button Widget
---@return Card self
function Card:AddAction(button)
    local container = self:GetOrCreateFooterContainer()
    container:AddChild(button)
    return self
end

--- Set cover image
---@param imagePath string|nil
---@return Card self
function Card:SetCoverImage(imagePath)
    self.props.coverImage = imagePath
    self.coverImageHandle_ = nil
    -- Note: Actual image loading would be handled by engine integration
    return self
end

--- Set cover height
---@param height number
---@return Card self
function Card:SetCoverHeight(height)
    self.props.coverHeight = height
    return self
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--- Set variant
---@param variant string "elevated" | "outlined" | "filled"
---@return Card self
function Card:SetVariant(variant)
    self.props.variant = variant
    return self
end

--- Set elevation
---@param elevation number 0-5
---@return Card self
function Card:SetElevation(elevation)
    self.props.elevation = math.max(0, math.min(5, elevation))
    return self
end

--- Set hoverable
---@param hoverable boolean
---@return Card self
function Card:SetHoverable(hoverable)
    self.props.hoverable = hoverable
    return self
end

--- Set clickable
---@param clickable boolean
---@return Card self
function Card:SetClickable(clickable)
    self.props.clickable = clickable
    return self
end

-- ============================================================================
-- Stateful
-- ============================================================================

function Card:IsStateful()
    return true
end

-- ============================================================================
-- Static Helpers
-- ============================================================================

--- Create a simple card with title and content
---@param title string
---@param content string|Widget
---@param options table|nil
---@return Card
function Card.Simple(title, content, options)
    local Label = require("urhox-libs/UI/Widgets/Label")

    options = options or {}

    local card = Card:new(options)
    card:SetHeader(title)

    if type(content) == "string" then
        card:AddBody(Label:new({
            text = content,
            color = Theme.Color("textSecondary"),
        }))
    else
        card:AddBody(content)
    end

    return card
end

--- Create an action card with buttons
---@param options table { title, content, actions }
---@return Card
function Card.Action(options)
    local Label = require("urhox-libs/UI/Widgets/Label")

    options = options or {}

    local card = Card:new({
        variant = options.variant,
        elevation = options.elevation,
        width = options.width,
    })

    if options.title then
        card:SetHeader(options.title)
    end

    if options.content then
        if type(options.content) == "string" then
            card:AddBody(Label:new({
                text = options.content,
                color = Theme.Color("textSecondary"),
            }))
        else
            card:AddBody(options.content)
        end
    end

    if options.actions and #options.actions > 0 then
        for _, action in ipairs(options.actions) do
            card:AddAction(action)
        end
    end

    return card
end

--- Create a media card with cover image
---@param options table { image, title, subtitle, content }
---@return Card
function Card.Media(options)
    local Label = require("urhox-libs/UI/Widgets/Label")
    local Panel = require("urhox-libs/UI/Widgets/Panel")

    options = options or {}

    local card = Card:new({
        variant = options.variant or "elevated",
        width = options.width,
        coverImage = options.image,
        coverHeight = options.coverHeight or 160,
    })

    -- Title and subtitle as header
    if options.title or options.subtitle then
        local header = Panel:new({
            flexDirection = "column",
            gap = 4,
        })

        if options.title then
            header:AddChild(Label:new({
                text = options.title,
                fontSize = Theme.BaseFontSize("subtitle"),
                color = Theme.Color("text"),
            }))
        end

        if options.subtitle then
            header:AddChild(Label:new({
                text = options.subtitle,
                fontSize = Theme.BaseFontSize("body"),
                color = Theme.Color("textSecondary"),
            }))
        end

        card:SetHeader(header)
    end

    -- Content
    if options.content then
        if type(options.content) == "string" then
            card:AddBody(Label:new({
                text = options.content,
                color = Theme.Color("textSecondary"),
            }))
        else
            card:AddBody(options.content)
        end
    end

    return card
end

return Card
