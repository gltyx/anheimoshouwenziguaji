-- HSV Color Wheel
-- Converted from AngelScript to Lua

-- Global color wheel variables
colorWheelWindow = nil
colorCursor = nil
colorWheel = nil

closeButton = nil
okButton = nil
cancelButton = nil

bwGradient = nil
bwCursor = nil

AGradient = nil
ACursor = nil

rLineEdit = nil
gLineEdit = nil
bLineEdit = nil

hLineEdit = nil
sLineEdit = nil
vLineEdit = nil

aLineEdit = nil

colorCheck = nil
colorFastItem = {}
colorFast = {}
colorFastSelectedIndex = -1
colorFastHoverIndex = -1

lastColorWheelWindowPosition = IntVector2(0, 0)

isColorWheelHovering = false
isBWGradientHovering = false
isAGradientHovering = false

wheelIncomingColor = Color(1, 1, 1, 1)
wheelColor = Color(1, 1, 1, 1)
colorHValue = 1
colorSValue = 1
colorVValue = 1
colorAValue = 0.5
high = 0
aValue = 1

-- Constants
local IMAGE_SIZE = 256
local HALF_IMAGE_SIZE = 128
local MAX_ANGLE = 360
local ROUND_VALUE_MAX = 0.99
local ROUND_VALUE_MIN = 0.01

-- Event types for external handlers
eventTypeWheelChangeColor = "WheelChangeColor"
eventTypeWheelSelectColor = "WheelSelectColor"
eventTypeWheelDiscardColor = "WheelDiscardColor"

function CreateColorWheel()
    if colorWheelWindow ~= nil then
        return
    end

    colorWheelWindow = LoadEditorUI("UI/EditorColorWheel.xml")
    ui.root:AddChild(colorWheelWindow)
    colorWheelWindow.opacity = uiMaxOpacity

    colorWheel = colorWheelWindow:GetChild("ColorWheel", true)
    colorCursor = colorWheelWindow:GetChild("ColorCursor", true)

    closeButton = colorWheelWindow:GetChild("CloseButton", true)
    okButton = colorWheelWindow:GetChild("okButton", true)
    cancelButton = colorWheelWindow:GetChild("cancelButton", true)

    colorCheck = colorWheelWindow:GetChild("ColorCheck", true)
    bwGradient = colorWheelWindow:GetChild("BWGradient", true)
    bwCursor = colorWheelWindow:GetChild("BWCursor", true)

    AGradient = colorWheelWindow:GetChild("AGradient", true)
    ACursor = colorWheelWindow:GetChild("ACursor", true)

    rLineEdit = colorWheelWindow:GetChild("R", true)
    gLineEdit = colorWheelWindow:GetChild("G", true)
    bLineEdit = colorWheelWindow:GetChild("B", true)

    hLineEdit = colorWheelWindow:GetChild("H", true)
    sLineEdit = colorWheelWindow:GetChild("S", true)
    vLineEdit = colorWheelWindow:GetChild("V", true)

    aLineEdit = colorWheelWindow:GetChild("A", true)

    -- Resize arrays
    for i = 1, 8 do
        colorFastItem[i] = nil
        colorFast[i] = nil
    end

    -- Init some gradient for fast colors palette
    for i = 0, 7 do
        colorFastItem[i + 1] = colorWheelWindow:GetChild("h" .. tostring(i), true)
        colorFast[i + 1] = Color(i * 0.125, i * 0.125, i * 0.125)
        colorFastItem[i + 1].color = colorFast[i + 1]
    end

    SubscribeToEvent(closeButton, "Pressed", "HandleWheelButtons")
    SubscribeToEvent(okButton, "Pressed", "HandleWheelButtons")
    SubscribeToEvent(cancelButton, "Pressed", "HandleWheelButtons")

    CenterDialog(colorWheelWindow)
    lastColorWheelWindowPosition = colorWheelWindow.position

    HideColorWheel()
end

function ShowColorWheelWithColor(oldColor)
    wheelIncomingColor = oldColor
    wheelColor = oldColor
    return ShowColorWheel()
end

function ShowColorWheel()
    if ui.focusElement ~= nil and colorWheelWindow.visible then
        return false
    end

    colorFastSelectedIndex = -1
    colorFastHoverIndex = -1

    EstablishColorWheelUIFromColor(wheelColor)

    colorWheelWindow.opacity = 1
    colorWheelWindow.position = lastColorWheelWindowPosition
    colorWheelWindow.visible = true
    colorWheelWindow:BringToFront()

    return true
end

function HideColorWheel()
    if colorWheelWindow.visible then
        colorWheelWindow.visible = false
        lastColorWheelWindowPosition = colorWheelWindow.position
    end
end

function HandleWheelButtons(eventType, eventData)
    local edit = eventData["Element"]:GetPtr()

    if edit == nil then return end

    if edit == cancelButton then
        local vm = VariantMap()
        vm["Color"] = Variant(wheelIncomingColor)
        SendEvent(eventTypeWheelDiscardColor, vm)
        HideColorWheel()
    end

    if edit == closeButton then
        local vm = VariantMap()
        vm["Color"] = Variant(wheelIncomingColor)
        SendEvent(eventTypeWheelDiscardColor, vm)
        HideColorWheel()
    end

    if edit == okButton then
        local vm = VariantMap()
        vm["Color"] = Variant(wheelColor)
        SendEvent(eventTypeWheelSelectColor, vm)
        HideColorWheel()
    end
end

function HandleColorWheelKeyDown(eventType, eventData)
    if colorWheelWindow.visible == false then return end

    local key = eventData["Key"]:GetInt()

    if key == KEY_ESCAPE then
        SendEvent(eventTypeWheelDiscardColor, eventData)
        HideColorWheel()
    end
end

function HandleColorWheelMouseButtonDown(eventType, eventData)
    if colorWheelWindow.visible == false then return end

    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local button = eventData["Button"]:GetInt()

    if button == 1 then
        -- check for select
        if colorFastHoverIndex ~= -1 then
            colorFastSelectedIndex = colorFastHoverIndex
            EstablishColorWheelUIFromColor(colorFast[colorFastSelectedIndex + 1])
            SendEventChangeColor()
        end
    end
end

-- handler only for BWGradient
function HandleColorWheelMouseWheel(eventType, eventData)
    if colorWheelWindow.visible == false or not isBWGradientHovering then return end

    local multipler = 16
    local wheelValue = eventData["Wheel"]:GetInt()

    wheelValue = wheelValue * multipler

    if wheelValue ~= 0 then
        if wheelValue > 0 then
            high = high + wheelValue
            high = math.min(high, IMAGE_SIZE) -- limit BWGradient by high
        elseif wheelValue < 0 then
            high = high + wheelValue
            high = math.max(high, 0)
        end

        bwCursor:SetPosition(bwCursor.position.x, high - 7)
        colorVValue = (IMAGE_SIZE - high) / IMAGE_SIZE

        wheelColor:FromHSV(colorHValue, colorSValue, colorVValue, colorAValue)
        SendEventChangeColor()
        UpdateColorInformation()
    end
end

function HandleColorWheelMouseMove(eventType, eventData)
    if colorWheelWindow.visible == false then return end

    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    local button = eventData["Button"]:GetInt()

    if colorWheelWindow:IsInside(IntVector2(x, y), true) then
        colorWheelWindow.opacity = 1.0
    end

    local cwx = 0
    local cwy = 0
    local cx = 0
    local cy = 0
    local i = IntVector2()
    local inWheel = false

    isBWGradientHovering = false
    isColorWheelHovering = false

    -- if mouse cursor move on wheel rectangle
    if colorWheel:IsInside(IntVector2(x, y), true) then
        isColorWheelHovering = true
        -- get element pos win screen
        local ep = colorWheel.screenPosition

        -- math diff between mouse cursor & element pos = mouse pos on element
        cwx = x - ep.x
        cwy = y - ep.y

        -- shift mouse pos to center of wheel
        cx = cwx - HALF_IMAGE_SIZE
        cy = cwy - HALF_IMAGE_SIZE

        -- get direction vector of H on circle
        local d = Vector2(cx, cy)

        -- if out of circle place colorCursor back to circle
        if d:Length() > HALF_IMAGE_SIZE then
            d:Normalize()
            d = d * HALF_IMAGE_SIZE

            i = IntVector2(math.floor(d.x), math.floor(d.y))
            inWheel = false
        else
            inWheel = true
        end

        if isColorWheelHovering and inWheel and (input:GetMouseButtonDown(MOUSEB_LEFT) or input:GetMouseButtonDown(MOUSEB_RIGHT)) then
            local pointOnCircle = Vector2(cx, -cy)
            local angle = GetAngle(pointOnCircle)

            i = i + IntVector2(cwx, cwy)
            colorCursor.position = IntVector2(i.x - 7, i.y - 7)

            colorHValue = GetHueFromWheelDegAngle(angle)

            if colorHValue < ROUND_VALUE_MIN then colorHValue = 0.0 end
            if colorHValue > ROUND_VALUE_MAX then colorHValue = 1.0 end

            colorSValue = d:Length() / HALF_IMAGE_SIZE

            if colorSValue < ROUND_VALUE_MIN then colorSValue = 0.0 end
            if colorSValue > ROUND_VALUE_MAX then colorSValue = 1.0 end

            wheelColor:FromHSV(colorHValue, colorSValue, colorVValue, colorAValue)
            SendEventChangeColor()
            UpdateColorInformation()
        end
    -- if mouse cursor move on bwGradient rectangle
    elseif bwGradient:IsInside(IntVector2(x, y), true) then
        isBWGradientHovering = true
        local ep = bwGradient.screenPosition
        local high = y - ep.y

        if input:GetMouseButtonDown(MOUSEB_LEFT) or input:GetMouseButtonDown(MOUSEB_RIGHT) then
            bwCursor:SetPosition(bwCursor.position.x, high - 7)
            colorVValue = (IMAGE_SIZE - high) / IMAGE_SIZE

            if colorVValue < 0.01 then colorVValue = 0.0 end
            if colorVValue > 0.99 then colorVValue = 1.0 end

            wheelColor:FromHSV(colorHValue, colorSValue, colorVValue, colorAValue)
            SendEventChangeColor()
        end

        UpdateColorInformation()
    -- if mouse cursor move on AlphaGradient rectangle
    elseif AGradient:IsInside(IntVector2(x, y), true) then
        local ep = AGradient.screenPosition
        local aValue = x - ep.x

        if input:GetMouseButtonDown(MOUSEB_LEFT) or input:GetMouseButtonDown(MOUSEB_RIGHT) then
            ACursor:SetPosition(aValue - 7, ACursor.position.y)
            colorAValue = aValue / 200 -- 200pix image

            -- round values for min or max
            if colorAValue < 0.01 then colorAValue = 0.0 end
            if colorAValue > 0.99 then colorAValue = 1.0 end

            wheelColor:FromHSV(colorHValue, colorSValue, colorVValue, colorAValue)
            SendEventChangeColor()
        end

        UpdateColorInformation()
    end

    -- checking for history select
    for j = 0, 7 do
        if colorFastItem[j + 1]:IsInside(IntVector2(x, y), true) then
            colorFastHoverIndex = j
        end
    end
end

function UpdateColorInformation()
    -- fill UI from current color
    hLineEdit.text = string.sub(tostring(colorHValue), 1, 5)
    sLineEdit.text = string.sub(tostring(colorSValue), 1, 5)
    vLineEdit.text = string.sub(tostring(colorVValue), 1, 5)

    rLineEdit.text = string.sub(tostring(wheelColor.r), 1, 5)
    gLineEdit.text = string.sub(tostring(wheelColor.g), 1, 5)
    bLineEdit.text = string.sub(tostring(wheelColor.b), 1, 5)

    aLineEdit.text = string.sub(tostring(colorAValue), 1, 5)

    colorCheck.color = wheelColor
    colorWheel.color = Color(colorVValue, colorVValue, colorVValue)
    AGradient.color = Color(wheelColor.r, wheelColor.g, wheelColor.b)

    -- update selected fast-colors
    if colorFastSelectedIndex ~= -1 then
        colorFastItem[colorFastSelectedIndex + 1].color = wheelColor
        colorFast[colorFastSelectedIndex + 1] = wheelColor
    end
end

function SendEventChangeColor()
    local eventData = VariantMap()
    eventData["Color"] = Variant(wheelColor)
    SendEvent("WheelChangeColor", eventData)
end

function EstablishColorWheelUIFromColor(c)
    wheelColor = c
    colorHValue = c:Hue()
    colorSValue = c:SaturationHSV()
    colorVValue = c:Value()
    colorAValue = c.a

    -- convert color value to BWGradient high
    high = math.floor(IMAGE_SIZE - colorVValue * IMAGE_SIZE)
    bwCursor:SetPosition(bwCursor.position.x, high - 7)

    -- convert color alpha to shift on x-axis for ACursor
    aValue = 200 * colorAValue
    ACursor:SetPosition(math.floor(aValue - 7), ACursor.position.y)

    -- rotate vector to H-angle with scale(shifting) by S to calculate final point position
    local q = Quaternion(colorHValue * -MAX_ANGLE, Vector3(0, 0, 1))
    local pos = Vector3(1, 0, 0)
    pos = q * pos
    pos = pos * (colorSValue * HALF_IMAGE_SIZE)
    pos = pos + Vector3(HALF_IMAGE_SIZE, HALF_IMAGE_SIZE, 0)

    colorCursor.position = IntVector2(math.floor(pos.x) - 7, math.floor(pos.y) - 7)

    -- Update information on UI about color
    UpdateColorInformation()
end

function GetHueFromWheelDegAngle(angle)
    return angle / MAX_ANGLE
end

function GetAngle(point)
    local angle = math.atan2(point.y, point.x) * 180.0 / math.pi

    if angle < 0 then
        angle = angle + MAX_ANGLE
    end

    return angle
end
