-- ============================================================================
-- CSS Enhancement Test
-- Demonstrates Phase 0~3 features: Transition, Opacity, Transform,
-- Visibility, Aspect-Ratio, Gradient, Shadow, Keyframe Animation,
-- z-index, SimpleGrid, Sticky, Clip-Path, Text Props, BlendMode,
-- Scroll Snap, Position Fixed
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- Shared State
-- ============================================================================

local state = {
    animWidgets = {},     -- Widgets with demo animations
    toggleState = {},     -- Toggle states for interactive demos
}

-- ============================================================================
-- Create Main Layout
-- ============================================================================

local root = UI.Panel {
    id = "root",
    width = "100%",
    height = "100%",
    padding = 20,
    flexDirection = "column",
    backgroundColor = UI.Theme.Color("background"),
}

-- Title
root:AddChild(UI.Label {
    text = "CSS Enhancement Test (Phase 0~3)",
    fontSize = UI.Theme.FontSizeOf("headline"),
    fontWeight = "bold",
    color = UI.Theme.Color("text"),
    marginBottom = 20,
})

-- ScrollView
local scrollView = UI.ScrollView {
    width = "100%",
    flexGrow = 1,
    flexBasis = 0,
    scrollY = true,
    showScrollbar = true,
    scrollbarInteractive = true,
}
root:AddChild(scrollView)

-- Content container
local content = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 24,
    paddingBottom = 40,
}
scrollView:AddChild(content)

-- ============================================================================
-- Helper: Create Section
-- ============================================================================

local function createSection(title, subtitle)
    local section = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 12,
        padding = 16,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
    }

    section:AddChild(UI.Label {
        text = title,
        fontSize = UI.Theme.FontSizeOf("bodyLarge"),
        fontWeight = "bold",
        color = UI.Theme.Color("text"),
    })

    if subtitle then
        section:AddChild(UI.Label {
            text = subtitle,
            fontSize = UI.Theme.FontSizeOf("bodySmall"),
            color = UI.Theme.Color("textSecondary"),
        })
    end

    content:AddChild(section)
    return section
end

local function createLabel(text)
    return UI.Label {
        text = text,
        fontSize = UI.Theme.FontSizeOf("bodySmall"),
        color = UI.Theme.Color("textSecondary"),
        marginTop = 4,
    }
end

-- ============================================================================
-- Phase 0: Transition System
-- ============================================================================
do
    local section = createSection(
        "Phase 0-1: Transition System",
        "Hover/click buttons to see smooth property transitions"
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap", alignItems = "center" }
    section:AddChild(row)

    -- Button with color transition on hover (variant color, 0.3s)
    row:AddChild(UI.Button {
        text = "Hover 0.3s",
        variant = "primary",
        transition = "all 0.3s easeOut",
    })

    -- Button with custom colors + slower transition (0.5s)
    row:AddChild(UI.Button {
        text = "Hover 0.5s",
        backgroundColor = { 34, 197, 94, 255 },
        hoverBackgroundColor = { 239, 68, 68, 255 },
        pressedBackgroundColor = { 168, 85, 247, 255 },
        transition = {
            properties = { "backgroundColor" },
            duration = 0.5,
            easing = "easeInOut",
        },
    })

    -- Button with easeOutBack (bouncy feel)
    row:AddChild(UI.Button {
        text = "Bouncy",
        backgroundColor = { 168, 85, 247, 255 },
        hoverBackgroundColor = { 245, 158, 11, 255 },
        transition = "all 0.4s easeOutBack",
    })

    -- Button with comma-separated per-property transitions (CSS format)
    local commaBtn = UI.Button {
        text = "Comma Sep",
        backgroundColor = { 59, 130, 246, 255 },
        hoverBackgroundColor = { 239, 68, 68, 255 },
        transition = "backgroundColor 0.8s easeInOut, scale 0.3s easeOutBack, opacity 0.5s linear",
    }
    commaBtn:OnEvent("pointerenter", function()
        commaBtn:SetStyle({ scale = 1.1, opacity = 0.7 })
    end)
    commaBtn:OnEvent("pointerleave", function()
        commaBtn:SetStyle({ scale = 1.0, opacity = 1.0 })
    end)
    row:AddChild(commaBtn)

    -- Button with no transition (control group)
    row:AddChild(UI.Button {
        text = "No Transition",
        variant = "secondary",
    })

    section:AddChild(createLabel("Hover each button: 0.3s easeOut / 0.5s easeInOut / 0.4s easeOutBack / comma-sep (bg 0.8s, scale 0.3s, opacity 0.5s) / instant"))
end

-- ============================================================================
-- Phase 0: Opacity
-- ============================================================================
do
    local section = createSection(
        "Phase 0-2: Opacity",
        "Parent opacity multiplies with children (0.5 x 0.5 = 0.25)"
    )

    local row = UI.Row { gap = 16, alignItems = "flex-end", flexWrap = "wrap" }
    section:AddChild(row)

    -- Different opacity levels
    local opacities = { 1.0, 0.8, 0.6, 0.4, 0.2 }
    for _, alpha in ipairs(opacities) do
        local box = UI.Panel {
            width = 80,
            height = 60,
            backgroundColor = { 59, 130, 246, 255 },
            borderRadius = 6,
            opacity = alpha,
            justifyContent = "center",
            alignItems = "center",
        }
        box:AddChild(UI.Label {
            text = tostring(alpha),
            fontSize = 14,
            color = { 255, 255, 255, 255 },
        })
        row:AddChild(box)
    end

    -- Nested opacity demo
    section:AddChild(createLabel("Nested opacity inheritance:"))
    local parentBox = UI.Panel {
        width = 200,
        height = 80,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 8,
        opacity = 0.5,
        padding = 10,
        justifyContent = "center",
        alignItems = "center",
    }
    parentBox:AddChild(UI.Panel {
        width = 80,
        height = 40,
        backgroundColor = { 255, 255, 255, 255 },
        borderRadius = 4,
        opacity = 0.5,
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label {
        text = "0.25",
        fontSize = 12,
        color = { 0, 0, 0, 255 },
    }))
    section:AddChild(parentBox)
end

-- ============================================================================
-- Phase 0: Transform
-- ============================================================================
do
    local section = createSection(
        "Phase 0-3: Transform (scale / rotate / translate)",
        "Visual transforms applied via NanoVG, layout unchanged"
    )

    local row = UI.Row { gap = 40, alignItems = "center", flexWrap = "wrap", padding = 20 }
    section:AddChild(row)

    -- Scale
    local scaleBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = 8,
        scale = 1.3,
        justifyContent = "center",
        alignItems = "center",
    }
    scaleBox:AddChild(UI.Label { text = "1.3x", fontSize = 11, color = { 255, 255, 255, 255 } })
    row:AddChild(scaleBox)

    -- Rotate
    local rotateBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 168, 85, 247, 255 },
        borderRadius = 8,
        rotate = 15,
        justifyContent = "center",
        alignItems = "center",
    }
    rotateBox:AddChild(UI.Label { text = "15deg", fontSize = 11, color = { 255, 255, 255, 255 } })
    row:AddChild(rotateBox)

    -- Translate
    local translateBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 245, 158, 11, 255 },
        borderRadius = 8,
        translateX = 10,
        translateY = -10,
        justifyContent = "center",
        alignItems = "center",
    }
    translateBox:AddChild(UI.Label { text = "tx+10", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(translateBox)

    -- Combined
    local combinedBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 236, 72, 153, 255 },
        borderRadius = 8,
        scale = 1.1,
        rotate = -10,
        translateY = 5,
        transformOrigin = "center",
        justifyContent = "center",
        alignItems = "center",
    }
    combinedBox:AddChild(UI.Label { text = "combo", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(combinedBox)

    section:AddChild(createLabel("scale = 1.3 | rotate = 15 | translateX/Y | transformOrigin = \"center\""))
end

-- ============================================================================
-- Phase 0: Visibility
-- ============================================================================
do
    local section = createSection(
        "Phase 0-4: Visibility",
        "visibility=\"hidden\" keeps layout space, visible=false collapses"
    )

    local row = UI.Row { gap = 8, alignItems = "center" }
    section:AddChild(row)

    row:AddChild(UI.Panel {
        width = 60, height = 40,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = 4,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "A", fontSize = 14, color = { 255, 255, 255, 255 } }))

    row:AddChild(UI.Panel {
        width = 60, height = 40,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 4,
        visibility = "hidden",  -- Hidden but takes space
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "B", fontSize = 14, color = { 255, 255, 255, 255 } }))

    row:AddChild(UI.Panel {
        width = 60, height = 40,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = 4,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "C", fontSize = 14, color = { 255, 255, 255, 255 } }))

    section:AddChild(createLabel("A [B hidden] C — B is visibility=\"hidden\" (gap preserved between A and C)"))
end

-- ============================================================================
-- Phase 1: Aspect Ratio
-- ============================================================================
do
    local section = createSection(
        "Phase 1-1: Aspect Ratio",
        "YGNodeStyleSetAspectRatio — height auto-calculated from width"
    )

    local row = UI.Row { gap = 16, alignItems = "flex-end", flexWrap = "wrap" }
    section:AddChild(row)

    local ratios = { { 1, "1:1" }, { 16/9, "16:9" }, { 4/3, "4:3" }, { 2/1, "2:1" } }
    for _, info in ipairs(ratios) do
        local ratio, label = info[1], info[2]
        local box = UI.Panel {
            width = 100,
            aspectRatio = ratio,
            backgroundColor = { 59, 130, 246, 255 },
            borderRadius = 6,
            justifyContent = "center",
            alignItems = "center",
        }
        box:AddChild(UI.Label {
            text = label,
            fontSize = 13,
            color = { 255, 255, 255, 255 },
        })
        row:AddChild(box)
    end

    section:AddChild(createLabel("width = 100, aspectRatio = 16/9 → height auto 56.25"))
end

-- ============================================================================
-- Phase 1: Per-Corner Border Radius
-- ============================================================================
do
    local section = createSection(
        "Phase 1-2: Per-Corner Border Radius",
        "borderRadius = {TL, TR, BR, BL} or borderRadiusTopLeft etc."
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row)

    -- Table format
    row:AddChild(UI.Panel {
        width = 80, height = 60,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = { 20, 0, 20, 0 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{20,0,20,0}", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Individual props
    row:AddChild(UI.Panel {
        width = 80, height = 60,
        backgroundColor = { 168, 85, 247, 255 },
        borderRadiusTopLeft = 20,
        borderRadiusBottomRight = 20,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "TL+BR", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Tab-like top only
    row:AddChild(UI.Panel {
        width = 80, height = 60,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = { 12, 12, 0, 0 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Tab top", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Pill shape
    row:AddChild(UI.Panel {
        width = 120, height = 40,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 20,
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Pill", fontSize = 12, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 1: Gradient Background
-- ============================================================================
do
    local section = createSection(
        "Phase 1-3: Gradient Background",
        "backgroundGradient with linear/radial, direction presets and angles"
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row)

    -- Linear gradient to-bottom
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 59, 130, 246, 255 },
            to = { 147, 51, 234, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "to-bottom", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Linear gradient to-right
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = { 34, 197, 94, 255 },
            to = { 59, 130, 246, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "to-right", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Diagonal gradient (45 degrees)
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "linear",
            direction = 45,
            from = { 245, 158, 11, 255 },
            to = { 239, 68, 68, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "45deg", fontSize = 10, color = { 255, 255, 255, 255 } }))

    -- Radial gradient
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        borderRadius = 8,
        backgroundGradient = {
            type = "radial",
            from = { 255, 255, 255, 255 },
            to = { 59, 130, 246, 255 },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "radial", fontSize = 10, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 1: Per-Side Borders
-- ============================================================================
do
    local section = createSection(
        "Phase 1-4: Per-Side Borders",
        "borderTopWidth/Color, borderBottomWidth/Color etc."
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row)

    -- Bottom border only (underline style)
    row:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderBottomWidth = 3,
        borderBottomColor = { 59, 130, 246, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "bottom", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Left border (accent line)
    row:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderLeftWidth = 4,
        borderLeftColor = { 34, 197, 94, 255 },
        paddingLeft = 8,
        justifyContent = "center",
    }:AddChild(UI.Label { text = "left", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Top + Bottom
    row:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderTopWidth = 2,
        borderTopColor = { 239, 68, 68, 255 },
        borderBottomWidth = 2,
        borderBottomColor = { 239, 68, 68, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "top+btm", fontSize = 12, color = UI.Theme.Color("text") }))

    -- borderWidth table shorthand examples
    section:AddChild(createLabel("borderWidth table shorthand:"))
    local row2 = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(row2)

    -- CSS shorthand: {vert, horiz}
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { 1, 3 },
        borderColor = { 168, 85, 247, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{1, 3}", fontSize = 12, color = UI.Theme.Color("text") }))

    -- CSS shorthand: {top, horiz, bottom}
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { 4, 1, 2 },
        borderColor = { 245, 158, 11, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{4, 1, 2}", fontSize = 12, color = UI.Theme.Color("text") }))

    -- CSS shorthand: {top, right, bottom, left}
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { 1, 2, 3, 4 },
        borderColor = { 34, 197, 94, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "{1,2,3,4}", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Named keys: { top=N, left=N }
    row2:AddChild(UI.Panel {
        width = 100, height = 50,
        backgroundColor = UI.Theme.Color("surface"),
        borderWidth = { top = 3, left = 3 },
        borderColor = { 59, 130, 246, 255 },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "top+left", fontSize = 12, color = UI.Theme.Color("text") }))
end

-- ============================================================================
-- Phase 1: Enhanced Box Shadow
-- ============================================================================
do
    local section = createSection(
        "Phase 1-5: Enhanced Box Shadow",
        "boxShadow = { {x, y, blur, spread, color, inset} } — multiple shadows supported"
    )

    local row = UI.Row { gap = 24, flexWrap = "wrap", padding = 16 }
    section:AddChild(row)

    -- Simple drop shadow
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 60 } },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Drop", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Elevated shadow (multiple layers)
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 2, blur = 4, spread = 0, color = { 0, 0, 0, 30 } },
            { x = 0, y = 8, blur = 24, spread = -4, color = { 0, 0, 0, 40 } },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Elevated", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Inset shadow
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 2, blur = 8, spread = 0, color = { 0, 0, 0, 50 }, inset = true },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Inset", fontSize = 12, color = UI.Theme.Color("text") }))

    -- Glow effect
    row:AddChild(UI.Panel {
        width = 100, height = 70,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = 8,
        boxShadow = {
            { x = 0, y = 0, blur = 20, spread = 4, color = { 59, 130, 246, 100 } },
        },
        justifyContent = "center", alignItems = "center",
    }:AddChild(UI.Label { text = "Glow", fontSize = 12, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 1: Backdrop Blur
-- ============================================================================
do
    local section = createSection(
        "Phase 1-6: Backdrop Blur (Visual Approximation)",
        "backdropBlur = N — layered semi-transparent overlay"
    )

    -- Background with content behind the blur panels
    local bgContainer = UI.Panel {
        width = "100%",
        height = 120,
        flexDirection = "row",
        gap = 16,
        padding = 10,
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = { 59, 130, 246, 255 },
            to = { 147, 51, 234, 255 },
        },
        borderRadius = 8,
        alignItems = "center",
    }
    section:AddChild(bgContainer)

    -- Blur panel overlaid
    bgContainer:AddChild(UI.Panel {
        width = 140,
        height = 80,
        backdropBlur = 10,
        backgroundColor = { 255, 255, 255, 80 },
        borderRadius = 12,
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "blur=10", fontSize = 13, color = { 255, 255, 255, 255 } }))

    bgContainer:AddChild(UI.Panel {
        width = 140,
        height = 80,
        backdropBlur = 30,
        backgroundColor = { 255, 255, 255, 80 },
        borderRadius = 12,
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "blur=30", fontSize = 13, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Phase 2: z-index
-- ============================================================================
do
    local section = createSection(
        "Phase 2-1: z-index",
        "Higher zIndex renders on top among siblings"
    )

    -- Container with overlapping children
    local container = UI.Panel {
        width = 400,
        height = 100,
        flexDirection = "row",
    }
    section:AddChild(container)

    -- Three overlapping panels (using negative margins to overlap)
    local colors = {
        { 239, 68, 68, 220 },   -- red
        { 34, 197, 94, 220 },   -- green
        { 59, 130, 246, 220 },  -- blue
    }
    local names = { "R", "G", "B" }
    local zIndices = { 1, 3, 2 }  -- Green (3) should be on top
    local labels = { "R z=1", "G z=3", "B z=2" }

    for i = 1, 3 do
        local label = UI.Label { text = labels[i], fontSize = 12, color = { 255, 255, 255, 255 } }
        local panel = UI.Panel {
            width = 100,
            height = 80,
            backgroundColor = colors[i],
            borderRadius = 8,
            zIndex = zIndices[i],
            marginLeft = i > 1 and -20 or 0,
            justifyContent = "center",
            alignItems = "center",
            cursor = "pointer",
        }
        panel:AddChild(label)

        -- Capture loop variables
        local defaultText = labels[i]
        local name = names[i]
        panel.props.onPointerEnter = function()
            label:SetStyle({ text = name .. " hover" })
        end
        panel.props.onPointerLeave = function()
            label:SetStyle({ text = defaultText })
        end
        panel.props.onPointerDown = function()
            label:SetStyle({ text = name .. " click!" })
        end
        panel.props.onPointerUp = function()
            label:SetStyle({ text = name .. " hover" })
        end

        container:AddChild(panel)
    end

    section:AddChild(createLabel("Red(z=1) Green(z=3) Blue(z=2) — Green renders on top, hover/click to verify hit test"))
end

-- ============================================================================
-- Phase 2: SimpleGrid
-- ============================================================================
do
    local section = createSection(
        "Phase 2-2: SimpleGrid",
        "Equal-width column grid via flex wrap"
    )

    -- Fixed 4 columns
    section:AddChild(createLabel("columns = 4, gap = 8:"))
    local grid = UI.SimpleGrid {
        columns = 4,
        gap = 8,
        width = "100%",
    }
    section:AddChild(grid)

    for i = 1, 8 do
        local hue = (i - 1) * 40
        -- Approximate HSL-like colors
        local r = math.floor(128 + 80 * math.cos(math.rad(hue)))
        local g = math.floor(128 + 80 * math.cos(math.rad(hue + 120)))
        local b = math.floor(128 + 80 * math.cos(math.rad(hue + 240)))
        grid:AddChild(UI.Panel {
            height = 50,
            backgroundColor = { r, g, b, 255 },
            borderRadius = 6,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = tostring(i), fontSize = 14, color = { 255, 255, 255, 255 } }))
    end

    -- Responsive grid
    section:AddChild(createLabel("minColumnWidth = 120 (responsive):"))
    local gridResponsive = UI.SimpleGrid {
        minColumnWidth = 120,
        gap = 8,
        width = "100%",
    }
    section:AddChild(gridResponsive)

    for i = 1, 6 do
        gridResponsive:AddChild(UI.Panel {
            height = 40,
            backgroundColor = { 59, 130, 246, 200 },
            borderRadius = 6,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = "Item " .. i, fontSize = 12, color = { 255, 255, 255, 255 } }))
    end
end

-- ============================================================================
-- Phase 2: Cursor Style
-- ============================================================================
do
    local section = createSection(
        "Phase 2-3: Cursor Style",
        "cursor = \"pointer\" | \"text\" | \"move\" | \"not-allowed\" — hover to see"
    )

    local row = UI.Row { gap = 12, flexWrap = "wrap" }
    section:AddChild(row)

    local cursors = { "default", "pointer", "text", "move", "not-allowed", "crosshair" }
    for _, cursorName in ipairs(cursors) do
        row:AddChild(UI.Panel {
            width = 90,
            height = 50,
            backgroundColor = UI.Theme.Color("surfaceVariant"),
            borderRadius = 6,
            borderWidth = 1,
            borderColor = UI.Theme.Color("border"),
            cursor = cursorName,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = cursorName, fontSize = 11, color = UI.Theme.Color("text") }))
    end
end

-- ============================================================================
-- Phase 2: Sticky Position
-- ============================================================================
do
    local section = createSection(
        "Phase 2-4: Sticky Position (in ScrollView)",
        "position=\"sticky\" pins header to scroll viewport top"
    )

    -- Inner ScrollView to demo sticky
    local innerScroll = UI.ScrollView {
        width = "100%",
        height = 200,
        scrollY = true,
        showScrollbar = true,
        backgroundColor = UI.Theme.Color("surfaceVariant"),
        borderRadius = 8,
    }
    section:AddChild(innerScroll)

    local innerContent = UI.Panel {
        width = "100%",
        flexDirection = "column",
    }
    innerScroll:AddChild(innerContent)

    -- Sticky header
    innerContent:AddChild(UI.Panel {
        width = "100%",
        height = 40,
        position = "sticky",
        stickyOffset = 0,
        backgroundColor = { 59, 130, 246, 240 },
        justifyContent = "center",
        alignItems = "center",
        zIndex = 10,
    }:AddChild(UI.Label {
        text = "Sticky Header — scroll down!",
        fontSize = 13,
        fontWeight = "bold",
        color = { 255, 255, 255, 255 },
    }))

    -- Many items to scroll through
    for i = 1, 15 do
        innerContent:AddChild(UI.Panel {
            width = "100%",
            height = 44,
            paddingHorizontal = 16,
            borderBottomWidth = 1,
            borderBottomColor = UI.Theme.Color("border"),
            justifyContent = "center",
        }:AddChild(UI.Label {
            text = "List item " .. i,
            fontSize = 13,
            color = UI.Theme.Color("text"),
        }))
    end
end

-- ============================================================================
-- Phase 2: Keyframe Animation
-- ============================================================================
do
    local section = createSection(
        "Phase 2-5: Keyframe Animation",
        "widget:Animate({ keyframes, duration, loop, direction })"
    )

    local row = UI.Row { gap = 24, alignItems = "center", flexWrap = "wrap", padding = 16 }
    section:AddChild(row)

    -- Pulse animation (loop)
    local pulseBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 239, 68, 68, 255 },
        borderRadius = 30,
        justifyContent = "center",
        alignItems = "center",
    }
    pulseBox:AddChild(UI.Label { text = "Pulse", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(pulseBox)
    state.animWidgets.pulse = pulseBox

    -- Fade in/out animation (alternate)
    local fadeBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 59, 130, 246, 255 },
        borderRadius = 8,
        justifyContent = "center",
        alignItems = "center",
    }
    fadeBox:AddChild(UI.Label { text = "Fade", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(fadeBox)
    state.animWidgets.fade = fadeBox

    -- Slide animation (alternate)
    local slideBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 34, 197, 94, 255 },
        borderRadius = 8,
        justifyContent = "center",
        alignItems = "center",
    }
    slideBox:AddChild(UI.Label { text = "Slide", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(slideBox)
    state.animWidgets.slide = slideBox

    -- Spin animation
    local spinBox = UI.Panel {
        width = 60,
        height = 60,
        backgroundColor = { 168, 85, 247, 255 },
        borderRadius = 8,
        justifyContent = "center",
        alignItems = "center",
    }
    spinBox:AddChild(UI.Label { text = "Spin", fontSize = 10, color = { 255, 255, 255, 255 } })
    row:AddChild(spinBox)
    state.animWidgets.spin = spinBox

    -- Button to start/stop animations
    local btnRow = UI.Row { gap = 8 }
    section:AddChild(btnRow)

    btnRow:AddChild(UI.Button {
        text = "Start Animations",
        variant = "primary",
        onClick = function()
            -- Pulse: scale 1.0 → 1.2 → 1.0
            state.animWidgets.pulse:Animate({
                keyframes = {
                    [0]   = { scale = 1.0 },
                    [0.5] = { scale = 1.3 },
                    [1]   = { scale = 1.0 },
                },
                duration = 0.8,
                easing = "easeInOut",
                loop = true,
            })

            -- Fade: opacity 1.0 → 0.2 → 1.0
            state.animWidgets.fade:Animate({
                keyframes = {
                    [0] = { opacity = 1.0 },
                    [1] = { opacity = 0.2 },
                },
                duration = 1.0,
                easing = "easeInOut",
                loop = true,
                direction = "alternate",
            })

            -- Slide: translateX 0 → 30 → 0
            state.animWidgets.slide:Animate({
                keyframes = {
                    [0] = { translateX = 0 },
                    [1] = { translateX = 40 },
                },
                duration = 1.2,
                easing = "easeInOutCubic",
                loop = true,
                direction = "alternate",
            })

            -- Spin: rotate 0 → 360
            state.animWidgets.spin:Animate({
                keyframes = {
                    [0] = { rotate = 0 },
                    [1] = { rotate = 360 },
                },
                duration = 2.0,
                easing = "linear",
                loop = true,
            })
        end,
    })

    btnRow:AddChild(UI.Button {
        text = "Stop All",
        variant = "secondary",
        onClick = function()
            for _, w in pairs(state.animWidgets) do
                w:StopAnimation()
            end
        end,
    })
end

-- ============================================================================
-- Phase 2: Clip-Path
-- ============================================================================
do
    local section = createSection(
        "Phase 2-6: Clip-Path (Basic Shapes)",
        "clipPath = \"circle\" | \"ellipse\" — clips widget content to shape"
    )

    local row = UI.Row { gap = 24, alignItems = "center", flexWrap = "wrap" }
    section:AddChild(row)

    -- Circle clip
    row:AddChild(UI.Panel {
        width = 80,
        height = 80,
        clipPath = "circle",
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom-right",
            from = { 59, 130, 246, 255 },
            to = { 147, 51, 234, 255 },
        },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "Circle", fontSize = 11, color = { 255, 255, 255, 255 } }))

    -- Ellipse clip
    row:AddChild(UI.Panel {
        width = 120,
        height = 70,
        clipPath = "ellipse",
        backgroundGradient = {
            type = "radial",
            from = { 245, 158, 11, 255 },
            to = { 239, 68, 68, 255 },
        },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "Ellipse", fontSize = 11, color = { 255, 255, 255, 255 } }))

    -- Circle with custom radius
    row:AddChild(UI.Panel {
        width = 100,
        height = 100,
        clipPath = { type = "circle", radius = 40 },
        backgroundColor = { 34, 197, 94, 255 },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "r=40", fontSize = 11, color = { 255, 255, 255, 255 } }))

    -- Ellipse with image (if available)
    row:AddChild(UI.Panel {
        width = 80,
        height = 80,
        clipPath = "circle",
        backgroundColor = { 236, 72, 153, 255 },
        justifyContent = "center",
        alignItems = "center",
    }:AddChild(UI.Label { text = "Avatar", fontSize = 11, color = { 255, 255, 255, 255 } }))
end

-- ============================================================================
-- Combined Demo: Animated Card
-- ============================================================================
do
    local section = createSection(
        "Combined Demo: Interactive Card",
        "Transition + Gradient + Shadow + Transform + Opacity"
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap", padding = 8 }
    section:AddChild(row)

    -- Interactive card that responds to hover
    for i = 1, 3 do
        local colors = {
            { { 59, 130, 246, 255 }, { 147, 51, 234, 255 } },
            { { 34, 197, 94, 255 }, { 16, 185, 129, 255 } },
            { { 239, 68, 68, 255 }, { 245, 158, 11, 255 } },
        }

        local card = UI.Panel {
            width = 160,
            height = 100,
            borderRadius = 12,
            backgroundGradient = {
                type = "linear",
                direction = "to-bottom-right",
                from = colors[i][1],
                to = colors[i][2],
            },
            boxShadow = {
                { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 40 } },
            },
            scale = 1.0,
            translateY = 0,
            transition = "all 0.3s easeOut",
            cursor = "pointer",
            justifyContent = "center",
            alignItems = "center",
            flexDirection = "column",
            gap = 4,
        }
        card:AddChild(UI.Label {
            text = "Card " .. i,
            fontSize = 16,
            fontWeight = "bold",
            color = { 255, 255, 255, 255 },
        })
        card:AddChild(UI.Label {
            text = "Click to animate",
            fontSize = 11,
            color = { 255, 255, 255, 180 },
        })

        -- Toggle animation on click
        state.toggleState["card" .. i] = false
        card.props.onPointerDown = function()
            state.toggleState["card" .. i] = not state.toggleState["card" .. i]
            if state.toggleState["card" .. i] then
                card:SetStyle({ scale = 1.05, translateY = -4 })
            else
                card:SetStyle({ scale = 1.0, translateY = 0 })
            end
        end

        row:AddChild(card)
    end
end

-- ============================================================================
-- Phase 3: Text Properties
-- ============================================================================
do
    local section = createSection(
        "Phase 3-1~6: Text Properties",
        "lineHeight, letterSpacing, textDecoration, textTransform, whiteSpace, wordBreak"
    )

    -- lineHeight
    section:AddChild(createLabel("lineHeight (1.0 vs 2.0):"))
    local lhRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(lhRow)

    lhRow:AddChild(UI.Label {
        text = "lineHeight=1.0",
        fontSize = 14,
        lineHeight = 1.0,
        backgroundColor = { 59, 130, 246, 40 },
        padding = 4,
        borderRadius = 4,
    })
    lhRow:AddChild(UI.Label {
        text = "lineHeight=2.0",
        fontSize = 14,
        lineHeight = 2.0,
        backgroundColor = { 59, 130, 246, 40 },
        padding = 4,
        borderRadius = 4,
    })

    -- letterSpacing
    section:AddChild(createLabel("letterSpacing (0, 2, 5):"))
    local lsRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(lsRow)

    for _, spacing in ipairs({ 0, 2, 5 }) do
        lsRow:AddChild(UI.Label {
            text = "Space=" .. spacing,
            fontSize = 14,
            letterSpacing = spacing,
            backgroundColor = { 34, 197, 94, 40 },
            padding = 4,
            borderRadius = 4,
        })
    end

    -- textDecoration
    section:AddChild(createLabel("textDecoration:"))
    local tdRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(tdRow)

    tdRow:AddChild(UI.Label {
        text = "underline",
        fontSize = 14,
        textDecoration = "underline",
        fontColor = { 59, 130, 246, 255 },
    })
    tdRow:AddChild(UI.Label {
        text = "line-through",
        fontSize = 14,
        textDecoration = "line-through",
        fontColor = { 239, 68, 68, 255 },
    })
    tdRow:AddChild(UI.Label {
        text = "none (default)",
        fontSize = 14,
        textDecoration = "none",
    })

    -- textTransform
    section:AddChild(createLabel("textTransform:"))
    local ttRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(ttRow)

    ttRow:AddChild(UI.Label {
        text = "uppercase text",
        fontSize = 14,
        textTransform = "uppercase",
        fontColor = { 168, 85, 247, 255 },
    })
    ttRow:AddChild(UI.Label {
        text = "LOWERCASE TEXT",
        fontSize = 14,
        textTransform = "lowercase",
        fontColor = { 245, 158, 11, 255 },
    })
    ttRow:AddChild(UI.Label {
        text = "capitalize words",
        fontSize = 14,
        textTransform = "capitalize",
        fontColor = { 34, 197, 94, 255 },
    })

    -- whiteSpace + wordBreak
    section:AddChild(createLabel("whiteSpace=\"normal\" (auto-wrap) + wordBreak:"))
    local wsRow = UI.Row { gap = 16, flexWrap = "wrap" }
    section:AddChild(wsRow)

    wsRow:AddChild(UI.Panel {
        width = 160, flexShrink = 0,
        backgroundColor = { 59, 130, 246, 30 },
        borderRadius = 6,
        padding = 8,
        borderWidth = 1,
        borderColor = { 59, 130, 246, 80 },
    }:AddChild(UI.Label {
        text = "This is a long text that should wrap automatically within the container width.",
        fontSize = 12,
        whiteSpace = "normal",
        width = "100%",
    }))

    wsRow:AddChild(UI.Panel {
        width = 160, flexShrink = 0,
        backgroundColor = { 239, 68, 68, 30 },
        borderRadius = 6,
        padding = 8,
        borderWidth = 1,
        borderColor = { 239, 68, 68, 80 },
    }:AddChild(UI.Label {
        text = "Superlongwordthatcannotbreakeasily breaks here.",
        fontSize = 12,
        whiteSpace = "normal",
        wordBreak = "break-word",
        width = "100%",
    }))
end

-- ============================================================================
-- Phase 3: Blend Mode
-- ============================================================================
do
    local section = createSection(
        "Phase 3-7: Blend Mode",
        "blendMode = \"lighter\" | \"xor\" | \"destination-over\" etc."
    )

    local row = UI.Row { gap = 16, flexWrap = "wrap", padding = 8 }
    section:AddChild(row)

    -- Base blue panel with overlapping blend mode panels
    local modes = { "normal", "lighter", "xor", "destination-over" }
    for _, mode in ipairs(modes) do
        local container = UI.Panel {
            width = 100, height = 80,
            backgroundColor = { 59, 130, 246, 200 },
            borderRadius = 8,
            justifyContent = "flex-end",
            alignItems = "flex-end",
        }
        -- Overlapping red panel with blend mode
        container:AddChild(UI.Panel {
            width = 60, height = 50,
            backgroundColor = { 239, 68, 68, 200 },
            borderRadius = 6,
            blendMode = mode,
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label { text = mode, fontSize = 9, color = { 255, 255, 255, 255 } }))
        row:AddChild(container)
    end
end

-- ============================================================================
-- Phase 3: Scroll Snap
-- ============================================================================
do
    local section = createSection(
        "Phase 3-8: Scroll Snap",
        "scrollSnapType=\"y mandatory\" + scrollSnapAlign=\"start\" on children"
    )

    local snapScroll = UI.ScrollView {
        width = "100%",
        height = 180,
        scrollY = true,
        showScrollbar = true,
        backgroundColor = UI.Theme.Color("surfaceVariant"),
        borderRadius = 8,
        scrollSnapType = "y mandatory",
    }
    section:AddChild(snapScroll)

    local snapContent = UI.Panel {
        width = "100%",
        flexDirection = "column",
    }
    snapScroll:AddChild(snapContent)

    local snapColors = {
        { 59, 130, 246, 255 },
        { 34, 197, 94, 255 },
        { 239, 68, 68, 255 },
        { 168, 85, 247, 255 },
        { 245, 158, 11, 255 },
    }

    for i = 1, 5 do
        snapContent:AddChild(UI.Panel {
            width = "100%",
            height = 180,
            backgroundColor = snapColors[i],
            scrollSnapAlign = "start",
            justifyContent = "center",
            alignItems = "center",
        }:AddChild(UI.Label {
            text = "Snap Page " .. i,
            fontSize = 18,
            fontWeight = "bold",
            color = { 255, 255, 255, 255 },
        }))
    end

    section:AddChild(createLabel("Scroll up/down — snaps to each page boundary (mandatory)"))
end

-- ============================================================================
-- Phase 3: Position Fixed (floating button)
-- ============================================================================
do
    -- Fixed button at bottom-right of viewport (outside ScrollView)
    local fixedBtn = UI.Button {
        text = "Fixed!",
        variant = "primary",
        position = "fixed",
        bottom = 30,
        right = 30,
        width = 80,
        height = 40,
        borderRadius = 20,
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 60 } },
        },
        onClick = function(self)
            print("[Fixed Button] Clicked!")
        end,
    }
    root:AddChild(fixedBtn)
end

-- ============================================================================
-- Baseline Alignment
-- ============================================================================
do
    local section = createSection(
        "Baseline Alignment",
        "alignItems=\"baseline\" — different font sizes align on text baseline"
    )

    -- Row 1: different font sizes
    local row1 = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "baseline",
        gap = 12,
        padding = 12,
        backgroundColor = { 40, 45, 65, 180 },
        borderRadius = 8,
    }
    row1:AddChild(UI.Label { text = "24px", fontSize = 24, fontColor = { 255, 200, 100, 255 } })
    row1:AddChild(UI.Label { text = "16px", fontSize = 16, fontColor = { 150, 220, 255, 255 } })
    row1:AddChild(UI.Label { text = "12px", fontSize = 12, fontColor = { 180, 255, 180, 255 } })
    row1:AddChild(UI.Label { text = "32px", fontSize = 32, fontColor = { 255, 150, 200, 255 } })
    section:AddChild(createLabel("Different font sizes — text baselines should align"))
    section:AddChild(row1)

    -- Row 2: labels with padding
    local row2 = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "baseline",
        gap = 12,
        padding = 12,
        backgroundColor = { 40, 45, 65, 180 },
        borderRadius = 8,
    }
    row2:AddChild(UI.Label { text = "No pad", fontSize = 20, fontColor = { 255, 200, 100, 255 } })
    row2:AddChild(UI.Label { text = "Pad 8", fontSize = 20, fontColor = { 150, 220, 255, 255 }, padding = 8, backgroundColor = { 60, 50, 80, 180 } })
    row2:AddChild(UI.Label { text = "Pad 16", fontSize = 20, fontColor = { 180, 255, 180, 255 }, padding = 16, backgroundColor = { 60, 50, 80, 180 } })
    section:AddChild(createLabel("Same font size, different padding — baselines still aligned"))
    section:AddChild(row2)

    -- Row 3: contrast with center alignment
    local row3 = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 12,
        padding = 12,
        backgroundColor = { 40, 45, 65, 180 },
        borderRadius = 8,
    }
    row3:AddChild(UI.Label { text = "24px", fontSize = 24, fontColor = { 255, 200, 100, 255 } })
    row3:AddChild(UI.Label { text = "16px", fontSize = 16, fontColor = { 150, 220, 255, 255 } })
    row3:AddChild(UI.Label { text = "12px", fontSize = 12, fontColor = { 180, 255, 180, 255 } })
    row3:AddChild(UI.Label { text = "32px", fontSize = 32, fontColor = { 255, 150, 200, 255 } })
    section:AddChild(createLabel("Contrast: alignItems=\"center\" — vertical centers aligned instead"))
    section:AddChild(row3)
end

-- ============================================================================
-- Set Root
-- ============================================================================

UI.SetRoot(root)

-- ============================================================================
-- Auto-start keyframe animations after a short delay
-- ============================================================================

local eventNode = Node()
local eventHandler = eventNode:CreateScriptObject("LuaScriptObject")
local startTimer = 0.5  -- Start animations after 0.5s

eventHandler:SubscribeToEvent("Update", function(self, eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    if startTimer > 0 then
        startTimer = startTimer - dt
        if startTimer <= 0 then
            -- Auto-start the keyframe animations
            if state.animWidgets.pulse then
                state.animWidgets.pulse:Animate({
                    keyframes = {
                        [0]   = { scale = 1.0 },
                        [0.5] = { scale = 1.3 },
                        [1]   = { scale = 1.0 },
                    },
                    duration = 0.8,
                    easing = "easeInOut",
                    loop = true,
                })
            end
            if state.animWidgets.fade then
                state.animWidgets.fade:Animate({
                    keyframes = {
                        [0] = { opacity = 1.0 },
                        [1] = { opacity = 0.2 },
                    },
                    duration = 1.0,
                    easing = "easeInOut",
                    loop = true,
                    direction = "alternate",
                })
            end
            if state.animWidgets.slide then
                state.animWidgets.slide:Animate({
                    keyframes = {
                        [0] = { translateX = 0 },
                        [1] = { translateX = 40 },
                    },
                    duration = 1.2,
                    easing = "easeInOutCubic",
                    loop = true,
                    direction = "alternate",
                })
            end
            if state.animWidgets.spin then
                state.animWidgets.spin:Animate({
                    keyframes = {
                        [0] = { rotate = 0 },
                        [1] = { rotate = 360 },
                    },
                    duration = 2.0,
                    easing = "linear",
                    loop = true,
                })
            end
        end
    end
end)
