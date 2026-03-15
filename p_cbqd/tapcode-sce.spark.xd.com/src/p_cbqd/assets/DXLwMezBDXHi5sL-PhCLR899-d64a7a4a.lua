-- test_button.lua  用Urho3D原生UI Button测试点击
require "LuaScripts/Utilities/Sample"

function Start()
    SampleStart()
    SampleInitMouseMode(MM_FREE)

    log:Write(LOG_INFO, "[NATIVE] Start()")

    local style = cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
    ui.root.defaultStyle = style

    -- 创建原生 Button
    local button = ui.root:CreateChild("Button")
    button:SetName("TestBtn")
    button:SetSize(300, 80)
    button:SetPosition(
        math.floor((graphics.width - 300) / 2),
        math.floor((graphics.height - 80) / 2)
    )
    button:SetStyleAuto()

    -- 按钮文字
    local text = button:CreateChild("Text")
    text:SetName("BtnText")
    text:SetText("NATIVE CLICK ME")
    text:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 24)
    text:SetAlignment(HA_CENTER, VA_CENTER)
    text:SetColor(Color(1, 1, 1, 1))

    -- 标题文字
    local title = ui.root:CreateChild("Text")
    title:SetText("Native Urho3D Button Test")
    title:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 28)
    title:SetColor(Color(1, 0.85, 0, 1))
    title:SetAlignment(HA_CENTER, VA_TOP)
    title:SetPosition(0, 40)

    -- 状态文字
    local status = ui.root:CreateChild("Text")
    status:SetName("StatusText")
    status:SetText("Waiting for click...")
    status:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 20)
    status:SetColor(Color(0.7, 0.7, 0.7, 1))
    status:SetAlignment(HA_CENTER, VA_TOP)
    status:SetPosition(0, 80)

    -- 订阅原生按钮点击事件
    SubscribeToEvent(button, "Released", "HandleButtonReleased")
    SubscribeToEvent(button, "Pressed", "HandleButtonPressed")
    SubscribeToEvent(button, "Click", "HandleButtonClick")

    -- 也订阅原始鼠标事件做对比
    SubscribeToEvent("MouseButtonDown", "HandleRawMouse")
    SubscribeToEvent("Update", "HandleUpdate")

    log:Write(LOG_INFO, "[NATIVE] Screen=" .. graphics.width .. "x" .. graphics.height)
    log:Write(LOG_INFO, "[NATIVE] Button pos=(" .. button.position.x .. "," .. button.position.y .. ") size=" .. button.width .. "x" .. button.height)
    log:Write(LOG_INFO, "[NATIVE] Ready")
end

local clickCount = 0

function HandleButtonReleased(eventType, eventData)
    clickCount = clickCount + 1
    log:Write(LOG_INFO, "[NATIVE] Released! count=" .. clickCount)
    local status = ui.root:GetChild("StatusText", true)
    if status then
        status:SetText("SUCCESS! Released count=" .. clickCount)
        status:SetColor(Color(0.4, 1, 0.4, 1))
    end
end

function HandleButtonPressed(eventType, eventData)
    log:Write(LOG_INFO, "[NATIVE] Pressed!")
end

function HandleButtonClick(eventType, eventData)
    log:Write(LOG_INFO, "[NATIVE] Click!")
end

function HandleRawMouse(eventType, eventData)
    local x = eventData:GetInt("X") or 0
    local y = eventData:GetInt("Y") or 0
    log:Write(LOG_INFO, "[NATIVE] raw(" .. x .. "," .. y .. ") clicks=" .. clickCount)
end

function HandleUpdate(eventType, eventData)
end
