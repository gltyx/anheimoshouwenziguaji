-- ============================================================================
-- Color Format Test
-- Test various color string formats support
-- ============================================================================

local UI = require("urhox-libs/UI")

-- Initialize UI
UI.Init({
    theme = "dark",
    fonts = {
        { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
    },
})

-- Create root
local root = UI.Panel {
    id = "root",
    width = "100%",
    height = "100%",
    padding = 20,
    backgroundColor = "#1e1e28",  -- Hex format for background
}

-- Title
root:AddChild(UI.Label {
    text = "Color Format Test",
    fontSize = 24,
    fontColor = "#ffffff",  -- Hex white
    marginBottom = 20,
})

-- ScrollView
local scrollView = UI.ScrollView {
    width = "100%",
    flexGrow = 1,
    scrollY = true,
    showScrollbar = true,
}
root:AddChild(scrollView)

-- Content container
local content = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 20,
    backgroundColor = false,
}
scrollView:AddChild(content)

-- ============================================================================
-- Section 1: Hex Color Formats
-- ============================================================================
local section1 = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 10,
    padding = 16,
    backgroundColor = "#363646e6",  -- 8-digit hex with alpha
    borderRadius = 8,
}
content:AddChild(section1)

section1:AddChild(UI.Label {
    text = "Hex Color Formats",
    fontSize = 18,
    fontColor = "#fff",  -- Short 3-digit hex
})

local hexRow = UI.Panel {
    flexDirection = "row",
    gap = 10,
    flexWrap = "wrap",
}
section1:AddChild(hexRow)

-- 6-digit hex
hexRow:AddChild(UI.Panel {
    width = 80,
    height = 60,
    backgroundColor = "#ff6b6b",
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "#ff6b6b", fontSize = 10, fontColor = "#fff" },
})

-- 8-digit hex with alpha
hexRow:AddChild(UI.Panel {
    width = 80,
    height = 60,
    backgroundColor = "#4ecdc480",  -- 50% alpha
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "#4ecdc480", fontSize = 10, fontColor = "#fff" },
})

-- 3-digit short hex
hexRow:AddChild(UI.Panel {
    width = 80,
    height = 60,
    backgroundColor = "#f90",  -- Short for #ff9900
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "#f90", fontSize = 10, fontColor = "#fff" },
})

-- 4-digit short hex with alpha
hexRow:AddChild(UI.Panel {
    width = 80,
    height = 60,
    backgroundColor = "#f0f8",  -- Short for #ff00ff88
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "#f0f8", fontSize = 10, fontColor = "#fff" },
})

-- ============================================================================
-- Section 2: CSS RGB/RGBA Formats
-- ============================================================================
local section2 = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 10,
    padding = 16,
    backgroundColor = "rgba(54, 54, 70, 230)",  -- RGBA format
    borderRadius = 8,
}
content:AddChild(section2)

section2:AddChild(UI.Label {
    text = "CSS rgb() / rgba() Formats",
    fontSize = 18,
    fontColor = "rgb(255, 255, 255)",
})

local rgbRow = UI.Panel {
    flexDirection = "row",
    gap = 10,
    flexWrap = "wrap",
}
section2:AddChild(rgbRow)

-- rgb()
rgbRow:AddChild(UI.Panel {
    width = 100,
    height = 60,
    backgroundColor = "rgb(102, 126, 234)",
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "rgb()", fontSize = 12, fontColor = "#fff" },
})

-- rgba() with 0-1 alpha
rgbRow:AddChild(UI.Panel {
    width = 100,
    height = 60,
    backgroundColor = "rgba(118, 75, 162, 0.7)",
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "rgba(0.7)", fontSize = 12, fontColor = "#fff" },
})

-- rgba() with 0-255 alpha
rgbRow:AddChild(UI.Panel {
    width = 100,
    height = 60,
    backgroundColor = "rgba(240, 147, 43, 200)",
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "rgba(200)", fontSize = 12, fontColor = "#fff" },
})

-- ============================================================================
-- Section 3: RGBA Table (Original Format)
-- ============================================================================
local section3 = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 10,
    padding = 16,
    backgroundColor = { 54, 54, 70, 230 },  -- Original table format
    borderRadius = 8,
}
content:AddChild(section3)

section3:AddChild(UI.Label {
    text = "RGBA Table (Original Format)",
    fontSize = 18,
    fontColor = { 255, 255, 255, 255 },
})

local tableRow = UI.Panel {
    flexDirection = "row",
    gap = 10,
}
section3:AddChild(tableRow)

tableRow:AddChild(UI.Panel {
    width = 100,
    height = 60,
    backgroundColor = { 46, 204, 113, 255 },
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "{46,204,113}", fontSize = 10, fontColor = "#fff" },
})

tableRow:AddChild(UI.Panel {
    width = 100,
    height = 60,
    backgroundColor = { 231, 76, 60, 180 },  -- With alpha
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "{231,76,60,180}", fontSize = 9, fontColor = "#fff" },
})

-- ============================================================================
-- Section 4: Label Background Colors
-- ============================================================================
local section4 = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 10,
    padding = 16,
    backgroundColor = "#363646e6",
    borderRadius = 8,
}
content:AddChild(section4)

section4:AddChild(UI.Label {
    text = "Label Background Colors",
    fontSize = 18,
    fontColor = "#fff",
})

local labelRow = UI.Panel {
    flexDirection = "row",
    gap = 10,
    flexWrap = "wrap",
}
section4:AddChild(labelRow)

-- Label with hex background
labelRow:AddChild(UI.Label {
    text = "Hex Background",
    fontSize = 14,
    fontColor = "#fff",
    backgroundColor = "#e74c3c",
    padding = 8,
    borderRadius = 4,
})

-- Label with rgba background
labelRow:AddChild(UI.Label {
    text = "RGBA Background",
    fontSize = 14,
    fontColor = "#fff",
    backgroundColor = "rgba(52, 152, 219, 0.9)",
    padding = 8,
    borderRadius = 4,
})

-- Label with border
labelRow:AddChild(UI.Label {
    text = "With Border",
    fontSize = 14,
    fontColor = "#2ecc71",
    borderColor = "#2ecc71",
    borderWidth = 2,
    padding = 8,
    borderRadius = 4,
})

-- Label with background + border
labelRow:AddChild(UI.Label {
    text = "BG + Border",
    fontSize = 14,
    fontColor = "#fff",
    backgroundColor = "#9b59b6",
    borderColor = "#fff",
    borderWidth = 2,
    padding = 8,
    borderRadius = 4,
})

-- ============================================================================
-- Section 5: Dynamic Color Change
-- ============================================================================
local section5 = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 10,
    padding = 16,
    backgroundColor = "#363646e6",
    borderRadius = 8,
}
content:AddChild(section5)

section5:AddChild(UI.Label {
    text = "Dynamic Color Change (Click buttons)",
    fontSize = 18,
    fontColor = "#fff",
})

local dynamicPanel = UI.Panel {
    id = "dynamicPanel",
    width = "100%",
    height = 80,
    backgroundColor = "#3498db",
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
}
section5:AddChild(dynamicPanel)

local dynamicLabel = UI.Label {
    id = "dynamicLabel",
    text = "Current: #3498db",
    fontSize = 14,
    fontColor = "#fff",
}
dynamicPanel:AddChild(dynamicLabel)

local buttonRow = UI.Panel {
    flexDirection = "row",
    gap = 10,
    marginTop = 10,
}
section5:AddChild(buttonRow)

-- Color change buttons
local colors = {
    { label = "Hex #e74c3c", color = "#e74c3c" },
    { label = "Short #9b5", color = "#9b5" },
    { label = "rgba()", color = "rgba(155, 89, 182, 255)" },
    { label = "Table", color = { 26, 188, 156, 255 } },
}

for _, item in ipairs(colors) do
    buttonRow:AddChild(UI.Button {
        text = item.label,
        width = 120,
        onClick = function()
            -- Use SetStyle to change background color
            dynamicPanel:SetStyle({ backgroundColor = item.color })
            local displayText = type(item.color) == "table"
                and string.format("{%d,%d,%d}", item.color[1], item.color[2], item.color[3])
                or item.color
            dynamicLabel:SetText("Current: " .. displayText)
        end,
    })
end

-- ============================================================================
-- Section 6: Border Colors
-- ============================================================================
local section6 = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 10,
    padding = 16,
    backgroundColor = "#363646e6",
    borderRadius = 8,
}
content:AddChild(section6)

section6:AddChild(UI.Label {
    text = "Border Colors",
    fontSize = 18,
    fontColor = "#fff",
})

local borderRow = UI.Panel {
    flexDirection = "row",
    gap = 15,
}
section6:AddChild(borderRow)

borderRow:AddChild(UI.Panel {
    width = 80,
    height = 60,
    backgroundColor = false,
    borderColor = "#e74c3c",
    borderWidth = 3,
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "Hex", fontSize = 12, fontColor = "#e74c3c" },
})

borderRow:AddChild(UI.Panel {
    width = 80,
    height = 60,
    backgroundColor = false,
    borderColor = "rgb(46, 204, 113)",
    borderWidth = 3,
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "rgb()", fontSize = 12, fontColor = "rgb(46, 204, 113)" },
})

borderRow:AddChild(UI.Panel {
    width = 80,
    height = 60,
    backgroundColor = false,
    borderColor = "rgba(52, 152, 219, 0.8)",
    borderWidth = 3,
    borderRadius = 8,
    justifyContent = "center",
    alignItems = "center",
    UI.Label { text = "rgba()", fontSize = 12, fontColor = "#3498db" },
})

-- Set root
UI.SetRoot(root)
