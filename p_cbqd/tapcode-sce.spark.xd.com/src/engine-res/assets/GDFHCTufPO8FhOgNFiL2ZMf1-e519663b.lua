-- Bullet Physics SIMD 性能基准测试
-- 直接测试 Bullet 向量/矩阵运算的实际性能

require "LuaScripts/Utilities/Sample"

function Start()
    SampleStart()
    CreateScene()
    CreateInstructions()
    CreateButton()
    SetupViewport()
    
    -- 强制显示鼠标
    input.mouseVisible = true
    input.mouseMode = MM_FREE
    
    print("")
    print("========================================")
    print("Bullet Physics SIMD Benchmark")
    print("========================================")
    print("Instructions:")
    print("  CLICK the button below to run benchmark")
    print("========================================")
    print("")
    print("Ready! Waiting for button click...")
    
    SubscribeToEvents()
end

function CreateScene()
    scene_ = Scene()
end

function CreateInstructions()
    local instructionText = ui.root:CreateChild("Text")
    instructionText.name = "Instructions"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 16)
    instructionText.textAlignment = HA_CENTER
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_TOP
    instructionText:SetPosition(0, 10)
    instructionText:SetColor(Color(1, 1, 0))
    instructionText.text = "╔═══════════════════════════════════════════╗\n" ..
                           "║ Bullet Physics SIMD Benchmark             ║\n" ..
                           "╠═══════════════════════════════════════════╣\n" ..
                           "║                                           ║\n" ..
                           "║ This benchmark measures the actual        ║\n" ..
                           "║ performance of Bullet's core operations:  ║\n" ..
                           "║                                           ║\n" ..
                           "║   • btVector3 (add, dot, cross, etc.)     ║\n" ..
                           "║   • btMatrix3x3 (multiply, inverse)       ║\n" ..
                           "║   • btTransform (compose, inverse)        ║\n" ..
                           "║                                           ║\n" ..
                           "║ CLICK button below to run benchmark       ║\n" ..
                           "║                                           ║\n" ..
                           "╚═══════════════════════════════════════════╝"
    
    -- 创建结果显示区域
    local resultText = ui.root:CreateChild("Text")
    resultText.name = "ResultText"
    resultText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 14)
    resultText.textAlignment = HA_LEFT
    resultText.horizontalAlignment = HA_LEFT
    resultText.verticalAlignment = VA_TOP
    resultText:SetPosition(20, 300)
    resultText:SetColor(Color(0, 1, 0))
    resultText.text = "Waiting for test..."
end

function CreateButton()
    -- 按钮容器
    local buttonContainer = ui.root:CreateChild("UIElement")
    buttonContainer.name = "ButtonContainer"
    buttonContainer:SetAlignment(HA_CENTER, VA_CENTER)
    buttonContainer:SetSize(300, 80)
    buttonContainer:SetPosition(0, 200)
    
    -- 创建运行按钮
    local runButton = buttonContainer:CreateChild("Button")
    runButton.name = "RunButton"
    runButton:SetSize(280, 60)
    runButton:SetPosition(10, 10)
    runButton:SetAlignment(HA_CENTER, VA_CENTER)
    
    -- 按钮背景
    runButton:SetStyle("Button", cache:GetResource("XMLFile", "UI/DefaultStyle.xml"))
    runButton:SetColor(Color(0.0, 1.0, 0.5, 0.9))
    
    -- 按钮文字
    local runButtonText = runButton:CreateChild("Text")
    runButtonText.name = "ButtonText"
    runButtonText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 22)
    runButtonText.textAlignment = HA_CENTER
    runButtonText:SetAlignment(HA_CENTER, VA_CENTER)
    runButtonText.text = "RUN BENCHMARK"
    runButtonText:SetColor(Color(1, 1, 1))
    
    -- 订阅按钮点击事件
    SubscribeToEvent(runButton, "Released", "HandleRunButtonClick")
end

function HandleRunButtonClick()
    print("")
    print("========================================")
    print("Running Bullet Physics SIMD Benchmark...")
    print("========================================")
    
    local resultText = ui.root:GetChild("ResultText", true)
    if resultText then
        resultText.text = "⏳ Running benchmark...\n\n(This may take 5-10 seconds)\n\nPlease wait..."
        resultText:SetColor(Color(1, 1, 0))
    end
    
    -- 发送事件请求基准测试（由 C++ 的 BulletBenchmark 响应）
    print("Sending RunBenchmark event...")
    local eventData = VariantMap()
    eventData["Iterations"] = 1000000
    SendEvent("RunBenchmark", eventData)
    print("✅ Event sent, waiting for results...")
end

function SetupViewport()
    cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(0, 0, -10)
    local camera = cameraNode:CreateComponent("Camera")
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    -- 订阅基准测试完成事件
    SubscribeToEvent("BenchmarkCompleted", "HandleBenchmarkCompleted")
    print("✅ Subscribed to BenchmarkCompleted event")
end

function HandleBenchmarkCompleted(eventType, eventData)
    print("📩 BenchmarkCompleted event received!")
    
    local results = eventData["Results"]:GetString()
    print("Results length: " .. #results)
    
    local resultText = ui.root:GetChild("ResultText", true)
    if resultText then
        if results and #results > 10 then
            resultText.text = results
            resultText:SetColor(Color(0, 1, 0))
            print("✅ Results displayed on UI!")
        else
            resultText.text = "❌ Error: Received empty results"
            resultText:SetColor(Color(1, 0, 0))
            print("⚠️ Results string is empty or too short")
        end
    else
        print("⚠️ Warning: ResultText UI element not found")
    end
end

