-- click_helper.lua  原生Urho3D按钮覆盖层
-- 用于解决UI库Button.onPress在web预览中不工作的问题
-- 创建透明的原生Urho3D按钮叠加在UI库渲染的视觉元素上方
local M = {}

local buttons = {}    -- 所有已注册的原生按钮
local style = nil

function M.init()
    style = cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
    ui.root.defaultStyle = style
end

--- 清除所有已注册的原生按钮
function M.clear()
    for _, btn in ipairs(buttons) do
        if btn.element then
            btn.element:Remove()
        end
    end
    buttons = {}
end

--- 创建一个透明的原生按钮覆盖层
--- @param x number 屏幕X坐标
--- @param y number 屏幕Y坐标
--- @param w number 宽度
--- @param h number 高度
--- @param callback function 点击回调
--- @param name string|nil 按钮名称（调试用）
function M.addButton(x, y, w, h, callback, name)
    local btn = ui.root:CreateChild("Button")
    btn:SetName(name or "cb_" .. #buttons)
    btn:SetPosition(math.floor(x), math.floor(y))
    btn:SetSize(math.floor(w), math.floor(h))
    btn:SetOpacity(0)  -- 完全透明
    btn.focusMode = FM_NOTFOCUSABLE

    SubscribeToEvent(btn, "Released", function(eventType, eventData)
        if callback then callback() end
    end)

    table.insert(buttons, { element = btn, callback = callback, name = name })
    return btn
end

--- 在屏幕底部创建标签栏按钮
--- @param tabs table  { {id=string, label=string}, ... }
--- @param onSelect function(tabId)  选中回调
--- @param tabHeight number  标签栏高度（默认44）
function M.addTabBar(tabs, onSelect, tabHeight)
    tabHeight = tabHeight or 44
    local sw = graphics.width
    local sh = graphics.height
    local tabW = math.floor(sw / #tabs)
    local tabY = sh - tabHeight

    for i, tab in ipairs(tabs) do
        local x = (i - 1) * tabW
        -- 最后一个标签占满剩余宽度
        local w = (i == #tabs) and (sw - x) or tabW
        M.addButton(x, tabY, w, tabHeight, function()
            if onSelect then onSelect(tab.id) end
        end, "tab_" .. tab.id)
    end
end

--- 在屏幕中央垂直排列按钮（用于职业选择等）
--- @param items table  { {label=string, callback=function}, ... }
--- @param btnWidth number  按钮宽度
--- @param btnHeight number  按钮高度
--- @param gap number  按钮间距
--- @param offsetY number|nil  垂直偏移（正值向下）
function M.addCenteredButtons(items, btnWidth, btnHeight, gap, offsetY)
    offsetY = offsetY or 0
    local sw = graphics.width
    local sh = graphics.height
    local totalH = #items * btnHeight + (#items - 1) * gap
    local startX = (sw - btnWidth) / 2
    local startY = (sh - totalH) / 2 + offsetY

    for i, item in ipairs(items) do
        local y = startY + (i - 1) * (btnHeight + gap)
        M.addButton(startX, y, btnWidth, btnHeight, item.callback, item.label or ("btn_" .. i))
    end
end

--- 在指定Y位置创建一行水平按钮（用于面板内的操作栏）
--- @param items table  { {label=string, callback=function, width=number}, ... }
--- @param y number  Y坐标
--- @param height number  按钮高度
--- @param marginX number  左右边距
--- @param gap number  按钮间距
function M.addButtonRow(items, y, height, marginX, gap)
    marginX = marginX or 10
    gap = gap or 6
    local sw = graphics.width
    local totalGap = gap * (#items - 1)
    local totalMargin = marginX * 2
    local btnW = math.floor((sw - totalMargin - totalGap) / #items)
    local x = marginX

    for i, item in ipairs(items) do
        local w = item.width or btnW
        M.addButton(x, y, w, height, item.callback, item.label or ("row_btn_" .. i))
        x = x + w + gap
    end
end

return M
