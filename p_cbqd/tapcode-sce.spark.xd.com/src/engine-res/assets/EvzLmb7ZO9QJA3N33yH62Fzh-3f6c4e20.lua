-- HttpClient Test Suite
-- Integrated test suite with UI controls and auto-tests
-- Press buttons to run manual tests, or observe console for auto-tests

-- Global state
local http = nil
local testResults = {}
local autoTestsRunning = false

function Start()
    print("=== HttpClient Test Suite ===")
    print("")

    -- Get http instance
    http = GetHttp()
    if not http then
        print("ERROR: Cannot get http instance")
        return
    end

-- ========================================
-- UI Setup
-- ========================================

-- Create UI root if not exists
local ui = GetUI()
if not ui then
    print("ERROR: Cannot get UI")
    return
end

-- Show mouse cursor
local input = GetInput()
if input then
    input.mouseVisible = true
end

local root = ui.root
local cache = GetCache()
local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")

-- Get screen size for centering
local graphics = GetGraphics()
local screenWidth = graphics.width
local screenHeight = graphics.height

-- Create container (much larger)
local container = root:CreateChild("Window")
container.name = "TestContainer"
container:SetStyleAuto()
local panelWidth = 1200
local panelHeight = 900
container:SetSize(panelWidth, panelHeight)
-- Center the panel
container:SetPosition((screenWidth - panelWidth) / 2, (screenHeight - panelHeight) / 2)
container.opacity = 0.95
container:SetMovable(true)
-- Set dark background
container:SetColor(Color(0.15, 0.15, 0.15, 1.0))  -- 深灰色背景

-- Title
local title = container:CreateChild("Text")
title.name = "Title"
title:SetFont(font, 24)
title.text = "HttpClient Test Suite"
title:SetPosition(30, 20)
title:SetColor(Color(1, 1, 0))

-- Status display
local statusText = container:CreateChild("Text")
statusText.name = "Status"
statusText:SetFont(font, 16)
statusText.text = "Status: Ready"
statusText:SetPosition(30, 60)
statusText:SetColor(Color(1, 1, 1))  -- 纯白色，清晰可见

-- Divider
local divider1 = container:CreateChild("Text")
divider1:SetFont(font, 14)
divider1.text = string.rep("=", 130)
divider1:SetPosition(30, 100)
divider1:SetColor(Color(0.8, 0.8, 0.8))  -- 浅灰色，更清晰

-- ========================================
-- Helper Functions
-- ========================================

local function UpdateStatus(text, color)
    statusText.text = "Status: " .. text
    statusText:SetColor(color or Color(0.7, 0.7, 0.7))
end

local function LogTest(testName, success, message)
    local symbol = success and "✓" or "✗"
    local color = success and "[GREEN]" or "[RED]"
    print(string.format("%s %s %s: %s", symbol, color, testName, message or ""))
    
    testResults[testName] = success
end

-- ========================================
-- Test Functions
-- ========================================

-- Test 1: Simple GET
local function Test_SimpleGET()
    UpdateStatus("Running: Simple GET", Color(1, 1, 0))
    print("\n[TEST] Simple GET Request")
    
    local client = http:Create()
    client:SetUrl("https://httpbin.org/get")
        :SetMethod(HTTP_GET)
        :SetTimeout(10000)
        :OnSuccess(function(c, response)
            LogTest("Simple GET", true, 
                string.format("Status: %d, Size: %d bytes", 
                    response:GetStatusCode(), response:GetDownloadedBytes()))
            UpdateStatus("Test Complete: Simple GET", Color(0, 1, 0))
        end)
        :OnError(function(c, error)
            LogTest("Simple GET", false, error)
            UpdateStatus("Test Failed: Simple GET", Color(1, 0, 0))
        end)
        :Send()
end

-- Test 2: POST with Form Data
local function Test_POSTForm()
    UpdateStatus("Running: POST Form", Color(1, 1, 0))
    print("\n[TEST] POST Form Data")
    
    local client = http:Create()
    local postData = "username=testuser&password=test123&email=test@example.com"
    
    client:SetUrl("https://httpbin.org/post")
        :SetMethod(HTTP_POST)
        :SetBody(postData)
        :SetContentType("application/x-www-form-urlencoded")
        :OnSuccess(function(c, response)
            local data = response:GetDataAsString()
            local hasUsername = string.find(data, "testuser") ~= nil
            LogTest("POST Form", hasUsername, 
                string.format("Form data %s", hasUsername and "verified" or "missing"))
            UpdateStatus("Test Complete: POST Form", Color(0, 1, 0))
        end)
        :OnError(function(c, error)
            LogTest("POST Form", false, error)
            UpdateStatus("Test Failed: POST Form", Color(1, 0, 0))
        end)
        :Send()
end

-- Test 3: POST JSON
local function Test_POSTJSON()
    UpdateStatus("Running: POST JSON", Color(1, 1, 0))
    print("\n[TEST] POST JSON Data")
    
    local client = http:Create()
    local jsonData = '{"name":"Urho3D","engine":"UrhoX","test":true,"value":42}'
    
    client:SetUrl("https://httpbin.org/post")
        :SetMethod(HTTP_POST)
        :SetBody(jsonData)
        :SetContentType("application/json")
        :OnSuccess(function(c, response)
            local data = response:GetDataAsString()
            local hasJSON = string.find(data, "application/json") ~= nil
            LogTest("POST JSON", hasJSON,
                string.format("JSON content-type %s", hasJSON and "verified" or "missing"))
            UpdateStatus("Test Complete: POST JSON", Color(0, 1, 0))
        end)
        :OnError(function(c, error)
            LogTest("POST JSON", false, error)
            UpdateStatus("Test Failed: POST JSON", Color(1, 0, 0))
        end)
        :Send()
end

-- Test 4: Custom Headers
local function Test_CustomHeaders()
    UpdateStatus("Running: Custom Headers", Color(1, 1, 0))
    print("\n[TEST] Custom Headers")
    
    local client = http:Create()
    client:SetUrl("https://httpbin.org/headers")
        :SetMethod(HTTP_GET)
        :AddHeader("X-Test-Header", "TestValue123")
        :AddHeader("X-Custom-ID", "42")
        :OnSuccess(function(c, response)
            local data = response:GetDataAsString()
            local hasHeader = string.find(data, "X-Test-Header") ~= nil
            LogTest("Custom Headers", hasHeader,
                string.format("Headers %s", hasHeader and "sent correctly" or "missing"))
            UpdateStatus("Test Complete: Custom Headers", Color(0, 1, 0))
        end)
        :OnError(function(c, error)
            LogTest("Custom Headers", false, error)
            UpdateStatus("Test Failed: Custom Headers", Color(1, 0, 0))
        end)
        :Send()
end

-- Test 5: Query Parameters
local function Test_QueryParams()
    UpdateStatus("Running: Query Parameters", Color(1, 1, 0))
    print("\n[TEST] Query Parameters")
    
    local client = http:Create()
    client:SetUrl("https://httpbin.org/get")
        :SetMethod(HTTP_GET)
        :AddQuery("param1", "value1")
        :AddQuery("param2", "value2")
        :AddQuery("test", "123")
        :OnSuccess(function(c, response)
            local data = response:GetDataAsString()
            local hasParams = string.find(data, "param1") and string.find(data, "value1")
            LogTest("Query Parameters", hasParams,
                string.format("Parameters %s", hasParams and "added correctly" or "missing"))
            UpdateStatus("Test Complete: Query Params", Color(0, 1, 0))
        end)
        :OnError(function(c, error)
            LogTest("Query Parameters", false, error)
            UpdateStatus("Test Failed: Query Params", Color(1, 0, 0))
        end)
        :Send()
end

-- Test 6: Download Progress
local function Test_DownloadProgress()
    UpdateStatus("Running: Download Progress", Color(1, 1, 0))
    print("\n[TEST] Download Progress Tracking")
    
    local client = http:Create()
    local progressCalls = 0
    
    client:SetUrl("https://httpbin.org/bytes/20480")
        :SetMethod(HTTP_GET)
        :OnProgress(function(c, downloaded, total)
            progressCalls = progressCalls + 1
            if total > 0 and progressCalls % 5 == 0 then
                local percent = (downloaded / total) * 100
                print(string.format("  Progress: %.1f%% (%d/%d bytes)", percent, downloaded, total))
            end
        end)
        :OnSuccess(function(c, response)
            LogTest("Download Progress", progressCalls > 0,
                string.format("Progress callbacks: %d", progressCalls))
            UpdateStatus("Test Complete: Progress", Color(0, 1, 0))
        end)
        :OnError(function(c, error)
            LogTest("Download Progress", false, error)
            UpdateStatus("Test Failed: Progress", Color(1, 0, 0))
        end)
        :Send()
end

-- Test 7: Error Handling (Invalid URL)
local function Test_ErrorHandling()
    UpdateStatus("Running: Error Handling", Color(1, 1, 0))
    print("\n[TEST] Error Handling (Invalid URL)")
    
    local client = http:Create()
    client:SetUrl("http://this-is-an-invalid-domain-12345678.com/test")
        :SetMethod(HTTP_GET)
        :SetTimeout(5000)
        :OnSuccess(function(c, response)
            LogTest("Error Handling", false, "Should not succeed!")
            UpdateStatus("Test Failed: Error Handling", Color(1, 0, 0))
        end)
        :OnError(function(c, error)
            LogTest("Error Handling", true, "Error correctly caught: " .. error)
            UpdateStatus("Test Complete: Error Handling", Color(0, 1, 0))
        end)
        :Send()
end

-- Test 8: Request Cancellation
local function Test_Cancellation()
    UpdateStatus("Running: Cancellation", Color(1, 1, 0))
    print("\n[TEST] Request Cancellation")
    
    local client = http:Create()
    client:SetUrl("https://httpbin.org/delay/10")
        :OnSuccess(function(c, response)
            LogTest("Cancellation", false, "Should not succeed (cancelled)")
            UpdateStatus("Test Failed: Cancellation", Color(1, 0, 0))
        end)
        :OnError(function(c, error)
            LogTest("Cancellation", true, "Request cancelled: " .. error)
            UpdateStatus("Test Complete: Cancellation", Color(0, 1, 0))
        end)
        :Send()
    
    -- Cancel immediately
    print("  Cancelling request...")
    client:Cancel()
end

-- Test 9: Concurrent Requests
local function Test_Concurrent()
    UpdateStatus("Running: Concurrent Requests", Color(1, 1, 0))
    print("\n[TEST] Concurrent Requests")
    
    local count = 5
    local completed = 0
    local succeeded = 0
    
    for i = 1, count do
        local client = http:Create()
        client:SetUrl("https://httpbin.org/get?id=" .. i)
            :AddHeader("X-Request-ID", tostring(i))
            :OnSuccess(function(c, response)
                completed = completed + 1
                succeeded = succeeded + 1
                print(string.format("  Request #%d completed (%d/%d)", i, completed, count))
                
                if completed == count then
                    LogTest("Concurrent Requests", succeeded == count,
                        string.format("%d/%d succeeded", succeeded, count))
                    UpdateStatus("Test Complete: Concurrent", Color(0, 1, 0))
                end
            end)
            :OnError(function(c, error)
                completed = completed + 1
                print(string.format("  Request #%d failed: %s", i, error))
                
                if completed == count then
                    LogTest("Concurrent Requests", succeeded == count,
                        string.format("%d/%d succeeded", succeeded, count))
                    UpdateStatus("Test Complete: Concurrent", Color(0, 1, 0))
                end
            end)
            :Send()
    end
end

-- Test 10: Response Properties
local function Test_ResponseProperties()
    UpdateStatus("Running: Response Properties", Color(1, 1, 0))
    print("\n[TEST] Response Properties Access")
    
    local client = http:Create()
    client:SetUrl("https://httpbin.org/json")
        :OnSuccess(function(c, response)
            -- Test all properties
            local props = {
                statusCode = response.statusCode,
                statusText = response.statusText,
                success = response.success,
                downloadedBytes = response.downloadedBytes,
                totalBytes = response.totalBytes,
                progress = response.progress,
                dataAsString = response.dataAsString
            }
            
            local allValid = true
            for key, value in pairs(props) do
                if value == nil then
                    print(string.format("  ✗ Property '%s' is nil", key))
                    allValid = false
                else
                    print(string.format("  ✓ Property '%s' = %s", key, tostring(value):sub(1, 50)))
                end
            end
            
            LogTest("Response Properties", allValid, "All properties accessible")
            UpdateStatus("Test Complete: Properties", Color(0, 1, 0))
        end)
        :OnError(function(c, error)
            LogTest("Response Properties", false, error)
            UpdateStatus("Test Failed: Properties", Color(1, 0, 0))
        end)
        :Send()
end

-- ========================================
-- Create Test Buttons
-- ========================================

local buttonY = 130
local buttonHeight = 50
local buttonSpacing = 12

local tests = {
    {name = "Simple GET", func = Test_SimpleGET},
    {name = "POST Form", func = Test_POSTForm},
    {name = "POST JSON", func = Test_POSTJSON},
    {name = "Custom Headers", func = Test_CustomHeaders},
    {name = "Query Params", func = Test_QueryParams},
    {name = "Download Progress", func = Test_DownloadProgress},
    {name = "Error Handling", func = Test_ErrorHandling},
    {name = "Cancellation", func = Test_Cancellation},
    {name = "Concurrent", func = Test_Concurrent},
    {name = "Response Props", func = Test_ResponseProperties},
}

for i, test in ipairs(tests) do
    local button = container:CreateChild("Button")
    button:SetStyleAuto()
    button:SetSize(1140, buttonHeight)
    button:SetPosition(30, buttonY)
    buttonY = buttonY + buttonHeight + buttonSpacing
    
    local buttonText = button:CreateChild("Text")
    buttonText:SetFont(font, 16)
    buttonText.text = string.format("[%d] %s", i, test.name)
    buttonText:SetAlignment(HA_CENTER, VA_CENTER)
    buttonText:SetColor(Color(0, 0, 0, 1))  -- 黑色文字，在白色按钮上清晰可见
    
    -- Button click handler
    SubscribeToEvent(button, "Released", function()
        test.func()
    end)
end

-- Divider 2
buttonY = buttonY + 15
local divider2 = container:CreateChild("Text")
divider2:SetFont(font, 14)
divider2.text = string.rep("=", 130)
divider2:SetPosition(30, buttonY)
divider2:SetColor(Color(0.8, 0.8, 0.8))  -- 浅灰色，更清晰
buttonY = buttonY + 35

-- Run All Auto Tests button
local autoButton = container:CreateChild("Button")
autoButton:SetStyleAuto()
autoButton:SetSize(1140, buttonHeight + 10)
autoButton:SetPosition(30, buttonY)

local autoButtonText = autoButton:CreateChild("Text")
autoButtonText:SetFont(font, 18)
autoButtonText.text = "▶ [A] Run All Auto Tests ◀"
autoButtonText:SetAlignment(HA_CENTER, VA_CENTER)
autoButtonText:SetColor(Color(0, 0, 0, 1))  -- 黑色文字

SubscribeToEvent(autoButton, "Released", function()
    if autoTestsRunning then
        print("\nAuto tests already running!")
        return
    end
    
    autoTestsRunning = true
    UpdateStatus("Running Auto Tests...", Color(1, 1, 0))
    print("\n" .. string.rep("=", 60))
    print("RUNNING AUTO TESTS SEQUENCE")
    print(string.rep("=", 60))
    
    -- Run tests with delays using Update event
    local testIndex = 1
    local delayTimer = 0
    local testDelay = 2.0  -- 2 seconds between tests
    local updateHandler = nil
    
    updateHandler = function(eventType, eventData)
        local timeStep = eventData["TimeStep"]:GetFloat()
        delayTimer = delayTimer + timeStep
        
        if delayTimer >= testDelay and testIndex <= #tests then
            delayTimer = 0
            print(string.format("\n>>> Auto Test %d/%d: %s", testIndex, #tests, tests[testIndex].name))
            tests[testIndex].func()
            testIndex = testIndex + 1
        elseif testIndex > #tests then
            -- All tests done
            UnsubscribeFromEvent("Update", updateHandler)
            autoTestsRunning = false
            print("\n" .. string.rep("=", 60))
            print("AUTO TESTS COMPLETED")
            print(string.rep("=", 60))
            UpdateStatus("Auto Tests Complete", Color(0, 1, 0))
        end
    end
    
    SubscribeToEvent("Update", updateHandler)
    
    -- Run first test immediately
    if #tests > 0 then
        print(string.format("\n>>> Auto Test 1/%d: %s", #tests, tests[1].name))
        tests[1].func()
        testIndex = 2
    end
end)

buttonY = buttonY + buttonHeight + 25

-- Info text
local infoText = container:CreateChild("Text")
infoText:SetFont(font, 14)
infoText.text = "💡 Click buttons to run individual tests\n📊 Watch console for detailed output\n⌨️  Hotkeys: 1-9, 0 for quick access | A to run all tests"
infoText:SetPosition(30, buttonY)
infoText:SetColor(Color(1, 1, 1))  -- 纯白色，清晰可见

-- ========================================
-- Keyboard Shortcuts
-- ========================================

local function HandleKeyPress(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    -- Number keys 1-9, 0 for test 10
    if key >= KEY_1 and key <= KEY_9 then
        local index = key - KEY_1 + 1
        if tests[index] then
            print(string.format("\n[Hotkey] Running test: %s", tests[index].name))
            tests[index].func()
        end
    elseif key == KEY_0 then
        if tests[10] then
            print(string.format("\n[Hotkey] Running test: %s", tests[10].name))
            tests[10].func()
        end
    elseif key == KEY_A then
        -- Trigger auto tests by sending event
        local eventData = VariantMap()
        autoButton:SendEvent("Released", eventData)
    end
end

SubscribeToEvent("KeyDown", HandleKeyPress)

-- ========================================
-- Initial Info
-- ========================================

    print("\n=== Test Suite Ready ===")
    print("Active Requests: " .. (http.activeRequestCount or 0))
    print("\nHotkeys:")
    print("  1-9, 0: Run individual tests")
    print("  A: Run all auto tests")
    print("\nOr click the buttons in the UI window")
    print(string.rep("=", 60))
    print("")
end
