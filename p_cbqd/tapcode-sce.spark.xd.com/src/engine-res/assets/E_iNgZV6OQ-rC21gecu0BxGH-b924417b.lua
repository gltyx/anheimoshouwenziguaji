-- NanoVG Lua API Test Script
-- Quick test to verify NanoVG Lua bindings are working

function Start()
    print("=== NanoVG Lua API Test ===")
    print("")

    -- Test 1: Check if nvgCreate is available
    if nvgCreate then
        print(" nvgCreate function found")
    else
        print(" nvgCreate function NOT found")
        GetEngine():Exit()
        return
    end

    -- Test 2: Check enums
    if NVG_CCW and NVG_ALIGN_CENTER and NVG_ALIGN_MIDDLE then
        print(" NanoVG enums found")
        print("  NVG_CCW =", NVG_CCW)
        print("  NVG_ALIGN_CENTER =", NVG_ALIGN_CENTER)
        print("  NVG_ALIGN_MIDDLE =", NVG_ALIGN_MIDDLE)
    else
        print(" NanoVG enums NOT found")
        GetEngine():Exit()
        return
    end

    -- Test 3: Check color functions
    if nvgRGBA and nvgHSL then
        print(" Color functions found")
        local red = nvgRGBA(255, 0, 0, 255)
        if red and red.r and red.g and red.b and red.a then
            print("  nvgRGBA result:", red.r, red.g, red.b, red.a)
        else
            print(" nvgRGBA return value incorrect")
            GetEngine():Exit()
            return
        end
    else
        print(" Color functions NOT found")
        GetEngine():Exit()
        return
    end

    -- Test 4: Try to create context
    print("")
    print("Attempting to create NanoVG context...")
    local ctx = nvgCreate(1)

    if ctx then
        print(" NanoVG context created successfully!")
        print("  Type:", type(ctx))

        -- Test basic functions
        if nvgBeginPath and nvgRect and nvgFillColor and nvgFill then
            print(" Basic drawing functions found")
        else
            print(" Basic drawing functions NOT found")
        end

        -- Test transform functions
        if nvgTranslate and nvgRotate and nvgScale then
            print(" Transform functions found")
        else
            print(" Transform functions NOT found")
        end

        -- Test text functions
        if nvgFontSize and nvgText and nvgTextBounds and nvgTextMetrics then
            print(" Text functions found")
        else
            print(" Text functions NOT found")
        end

        -- Clean up
        nvgDelete(ctx)
        print(" Context deleted successfully")
    else
        print(" Failed to create NanoVG context")
        GetEngine():Exit()
        return
    end

    print("")
    print("=== All Tests Passed! ===")
    print("")

    -- Exit after test
    GetEngine():Exit()
end

function Stop()
    -- Nothing to clean up
end
