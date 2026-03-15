-- ============================================================================
-- Input Release API Test
-- Tests: GetKeyRelease, GetScancodeRelease, GetMouseButtonRelease, GetQualifierRelease
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- Log messages
local logMessages_ = {}
local maxLogMessages_ = 20

-- Test state
local keyDownCount_ = 0
local keyReleaseCount_ = 0
local mouseDownCount_ = 0
local mouseReleaseCount_ = 0

-- Status display
local statusText_ = nil

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function AddLog(message)
    local timestamp = string.format("[%.2f]", time.elapsedTime)
    table.insert(logMessages_, timestamp .. " " .. message)
    if #logMessages_ > maxLogMessages_ then
        table.remove(logMessages_, 1)
    end
    print(message)
end

-- ============================================================================
-- Main Functions
-- ============================================================================

function Start()
    SampleStart()

    -- Set mouse mode to make sure mouse events are captured
    input:SetMouseVisible(true)
    input:SetMouseGrabbed(false)
    input:SetMouseMode(MM_FREE)

    -- Create instructions text
    local instructions =
        "INPUT RELEASE API TEST\n" ..
        "======================\n" ..
        "APIs being tested:\n" ..
        "- GetKeyRelease(key)\n" ..
        "- GetScancodeRelease(scancode)\n" ..
        "- GetMouseButtonRelease(button)\n" ..
        "- GetQualifierRelease(qualifier)\n\n" ..
        "Try pressing and releasing:\n" ..
        "- Keys: W/A/S/D, Q/E, SPACE, RETURN\n" ..
        "- Mouse: Left/Right/Middle click\n" ..
        "- Modifiers: Shift/Ctrl/Alt\n\n" ..
        "Press R to clear log | ESC to exit"

    local instructionText = ui.root:CreateChild("Text")
    instructionText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 12)
    instructionText.text = instructions
    instructionText.color = Color(0.9, 0.9, 0.9)
    instructionText:SetPosition(10, 10)

    -- Create status display (real-time state)
    statusText_ = ui.root:CreateChild("Text", "StatusText")
    statusText_:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 11)
    statusText_.color = Color(1.0, 1.0, 0.5)
    statusText_:SetPosition(400, 10)

    -- Create log display
    CreateLogDisplay()

    -- Subscribe to events
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    -- Debug: Print constant values
    AddLog("=== Constant Values ===")
    AddLog("MOUSEB_LEFT=" .. tostring(MOUSEB_LEFT) .. " RIGHT=" .. tostring(MOUSEB_RIGHT) .. " MIDDLE=" .. tostring(MOUSEB_MIDDLE))
    AddLog("QUAL_SHIFT=" .. tostring(QUAL_SHIFT) .. " CTRL=" .. tostring(QUAL_CTRL) .. " ALT=" .. tostring(QUAL_ALT))
    AddLog("KEY_LSHIFT=" .. tostring(KEY_LSHIFT) .. " KEY_RSHIFT=" .. tostring(KEY_RSHIFT))
    AddLog("SCANCODE_Q=" .. tostring(SCANCODE_Q) .. " SCANCODE_E=" .. tostring(SCANCODE_E))
    AddLog("=== Test Started ===")
end

function CreateLogDisplay()
    local logText = ui.root:CreateChild("Text", "LogText")
    logText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 11)
    logText.color = Color(0.0, 1.0, 0.5)
    logText:SetPosition(10, 220)
end

function UpdateLogDisplay()
    local logText = ui.root:GetChild("LogText", true)
    if logText then
        logText.text = "=== Event Log ===\n" .. table.concat(logMessages_, "\n")
    end
end

function UpdateStatusDisplay()
    if not statusText_ then return end

    local status = "=== Real-time Status ===\n"

    -- Mouse button states
    local lDown = input:GetMouseButtonDown(MOUSEB_LEFT) and "DOWN" or "up"
    local rDown = input:GetMouseButtonDown(MOUSEB_RIGHT) and "DOWN" or "up"
    local mDown = input:GetMouseButtonDown(MOUSEB_MIDDLE) and "DOWN" or "up"
    status = status .. "Mouse: L=" .. lDown .. " R=" .. rDown .. " M=" .. mDown .. "\n"

    -- Qualifier states
    local shiftDown = input:GetQualifierDown(QUAL_SHIFT) and "DOWN" or "up"
    local ctrlDown = input:GetQualifierDown(QUAL_CTRL) and "DOWN" or "up"
    local altDown = input:GetQualifierDown(QUAL_ALT) and "DOWN" or "up"
    status = status .. "Qualifiers: Shift=" .. shiftDown .. " Ctrl=" .. ctrlDown .. " Alt=" .. altDown .. "\n"

    -- Key states
    local wDown = input:GetKeyDown(KEY_W) and "DOWN" or "up"
    local qDown = input:GetKeyDown(KEY_Q) and "DOWN" or "up"
    local lshiftDown = input:GetKeyDown(KEY_LSHIFT) and "DOWN" or "up"
    status = status .. "Keys: W=" .. wDown .. " Q=" .. qDown .. " LShift=" .. lshiftDown .. "\n"

    -- Scancode states
    local scQDown = input:GetScancodeDown(SCANCODE_Q) and "DOWN" or "up"
    local scEDown = input:GetScancodeDown(SCANCODE_E) and "DOWN" or "up"
    status = status .. "Scancodes: Q=" .. scQDown .. " E=" .. scEDown .. "\n"

    -- Counters
    status = status .. "\nCounters:\n"
    status = status .. "Key Press/Release: " .. keyDownCount_ .. "/" .. keyReleaseCount_ .. "\n"
    status = status .. "Mouse Press/Release: " .. mouseDownCount_ .. "/" .. mouseReleaseCount_

    statusText_.text = status
end

-- ============================================================================
-- Update Handler - Polling-based detection
-- ============================================================================

function HandleUpdate(eventType, eventData)
    -- Test GetKeyRelease with common keys
    local testKeys = {
        {key = KEY_A, name = "A"},
        {key = KEY_S, name = "S"},
        {key = KEY_D, name = "D"},
        {key = KEY_W, name = "W"},
        {key = KEY_Q, name = "Q"},
        {key = KEY_E, name = "E"},
        {key = KEY_SPACE, name = "SPACE"},
        {key = KEY_RETURN, name = "RETURN"},
        {key = KEY_LSHIFT, name = "LSHIFT"},
        {key = KEY_RSHIFT, name = "RSHIFT"},
        {key = KEY_LCTRL, name = "LCTRL"},
        {key = KEY_RCTRL, name = "RCTRL"},
        {key = KEY_LALT, name = "LALT"},
        {key = KEY_RALT, name = "RALT"},
    }

    for _, k in ipairs(testKeys) do
        if input:GetKeyPress(k.key) then
            keyDownCount_ = keyDownCount_ + 1
            AddLog("KEY PRESS: " .. k.name)
        end
        if input:GetKeyRelease(k.key) then
            keyReleaseCount_ = keyReleaseCount_ + 1
            AddLog("KEY RELEASE: " .. k.name)
        end
    end

    -- Test GetScancodeRelease
    local testScancodes = {
        {sc = SCANCODE_Q, name = "Q"},
        {sc = SCANCODE_E, name = "E"},
        {sc = SCANCODE_W, name = "W"},
    }

    for _, s in ipairs(testScancodes) do
        if input:GetScancodePress(s.sc) then
            AddLog("SCANCODE PRESS: " .. s.name)
        end
        if input:GetScancodeRelease(s.sc) then
            AddLog("SCANCODE RELEASE: " .. s.name)
        end
    end

    -- Test GetMouseButtonRelease
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        mouseDownCount_ = mouseDownCount_ + 1
        AddLog("MOUSE PRESS: LEFT")
    end
    if input:GetMouseButtonRelease(MOUSEB_LEFT) then
        mouseReleaseCount_ = mouseReleaseCount_ + 1
        AddLog("MOUSE RELEASE: LEFT")
    end

    if input:GetMouseButtonPress(MOUSEB_RIGHT) then
        mouseDownCount_ = mouseDownCount_ + 1
        AddLog("MOUSE PRESS: RIGHT")
    end
    if input:GetMouseButtonRelease(MOUSEB_RIGHT) then
        mouseReleaseCount_ = mouseReleaseCount_ + 1
        AddLog("MOUSE RELEASE: RIGHT")
    end

    if input:GetMouseButtonPress(MOUSEB_MIDDLE) then
        mouseDownCount_ = mouseDownCount_ + 1
        AddLog("MOUSE PRESS: MIDDLE")
    end
    if input:GetMouseButtonRelease(MOUSEB_MIDDLE) then
        mouseReleaseCount_ = mouseReleaseCount_ + 1
        AddLog("MOUSE RELEASE: MIDDLE")
    end

    -- Test GetQualifierRelease (these use GetKeyRelease internally)
    if input:GetQualifierPress(QUAL_SHIFT) then
        AddLog("QUALIFIER PRESS: SHIFT")
    end
    if input:GetQualifierRelease(QUAL_SHIFT) then
        AddLog("QUALIFIER RELEASE: SHIFT")
    end

    if input:GetQualifierPress(QUAL_CTRL) then
        AddLog("QUALIFIER PRESS: CTRL")
    end
    if input:GetQualifierRelease(QUAL_CTRL) then
        AddLog("QUALIFIER RELEASE: CTRL")
    end

    if input:GetQualifierPress(QUAL_ALT) then
        AddLog("QUALIFIER PRESS: ALT")
    end
    if input:GetQualifierRelease(QUAL_ALT) then
        AddLog("QUALIFIER RELEASE: ALT")
    end

    -- Clear log with R key
    if input:GetKeyRelease(KEY_R) then
        logMessages_ = {}
        keyDownCount_ = 0
        keyReleaseCount_ = 0
        mouseDownCount_ = 0
        mouseReleaseCount_ = 0
        AddLog("Log cleared")
    end

    UpdateLogDisplay()
    UpdateStatusDisplay()
end

-- ============================================================================
-- Event-based handlers (for comparison)
-- ============================================================================

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_ESCAPE then
        engine:Exit()
    end
end
