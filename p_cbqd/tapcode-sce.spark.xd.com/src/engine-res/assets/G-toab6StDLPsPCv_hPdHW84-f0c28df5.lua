-- ============================================================================
-- Blittable Copy 全面测试用例
-- 测试所有 POD 类型的 blittable copy 功能
-- ============================================================================
--
-- 测试结果基准 (2025-12-03):
-- ========================================
--   值拷贝语义测试（核心验证）: 7/7 ✓
--     ★ Property返回值修改不影响原值
--     ★ 静态成员返回值修改不影响原值
--     ★ const& 方法返回值修改不影响原对象
--     ★ 操作符返回值修改不影响操作数
--   静态成员变量测试:  11/11 ✓
--   Property 访问测试:  4/4 ✓
--   操作符重载测试:     8/8 ✓
--   方法返回值测试:     5/5 ✓
--   所有 POD 类型构造: 18/18 ✓
--   边界情况测试:       4/4 ✓
--   性能测试:           4/4 ✓
-- ========================================
--   总计: 61/61 通过 (100%)
-- ========================================
--
-- 性能数据 (10000 次迭代 | DEBUG模式):
--   IntVector2 创建: 0.0300 秒
--   Vector3 创建:    0.0360 秒
--   Vector3 加法:    0.0170 秒
--   Property 访问:   0.0460 秒
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local testResults = {
    passed = 0,
    failed = 0,
    errors = {}
}

-- ============================================================================
-- 测试辅助函数
-- ============================================================================

local function test(name, func)
    local ok, err = pcall(func)
    if ok then
        testResults.passed = testResults.passed + 1
        print("✓ " .. name)
    else
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, { name = name, error = tostring(err) })
        print("✗ " .. name .. " - " .. tostring(err))
    end
end

local function assertEqual(expected, actual, msg)
    if expected ~= actual then
        error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertNotNil(value, msg)
    if value == nil then
        error((msg or "Assertion failed") .. ": value is nil")
    end
end

local function assertType(expected, value, msg)
    local t = type(value)
    if t ~= expected then
        error((msg or "Type assertion failed") .. ": expected " .. expected .. ", got " .. t)
    end
end

local function assertApproxEqual(expected, actual, epsilon, msg)
    epsilon = epsilon or 0.0001
    if math.abs(expected - actual) > epsilon then
        error((msg or "Approx assertion failed") .. ": expected ~" .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

-- ============================================================================
-- 测试值拷贝语义（核心测试）
-- ============================================================================

local function testValueCopySemantics()
    print("\n=== 值拷贝语义测试（核心验证）===")
    
    -- ★★★ 核心测试：修改返回值不影响原始值 ★★★
    test("★ Property返回值修改不影响原值", function()
        local pos1 = input.mousePosition  -- 获取返回值
        local originalX = pos1.x
        local originalY = pos1.y
        
        -- 修改返回值
        pos1.x = 99999
        pos1.y = 88888
        
        -- 重新获取，验证原始值没变
        local pos2 = input.mousePosition
        assertEqual(originalX, pos2.x, "原始 x 不应被修改")
        assertEqual(originalY, pos2.y, "原始 y 不应被修改")
    end)
    
    test("★ 静态成员返回值修改不影响原值", function()
        local zero1 = Vector3.ZERO  -- 获取静态成员
        
        -- 修改返回值
        zero1.x = 12345
        zero1.y = 67890
        zero1.z = 11111
        
        -- 重新获取，验证静态成员没变
        local zero2 = Vector3.ZERO
        assertApproxEqual(0, zero2.x, 0.001, "ZERO.x 不应被修改")
        assertApproxEqual(0, zero2.y, 0.001, "ZERO.y 不应被修改")
        assertApproxEqual(0, zero2.z, 0.001, "ZERO.z 不应被修改")
    end)
    
    test("★ const& 方法返回值修改不影响原对象", function()
        -- 创建一个 UI 元素来测试 GetPosition() (返回 const IntVector2&)
        local ui = GetUI()
        local root = ui:GetRoot()
        if root then
            local pos1 = root:GetPosition()  -- const IntVector2& 返回
            local originalX = pos1.x
            local originalY = pos1.y
            
            -- 修改返回值
            pos1.x = 99999
            pos1.y = 88888
            
            -- 重新获取，验证原对象没变
            local pos2 = root:GetPosition()
            assertEqual(originalX, pos2.x, "GetPosition().x 不应被修改")
            assertEqual(originalY, pos2.y, "GetPosition().y 不应被修改")
        else
            -- 如果没有 root，跳过测试
            print("    (跳过: 无 UI root)")
        end
    end)
    
    test("★ 操作符返回值修改不影响操作数", function()
        local v1 = Vector3(1, 2, 3)
        local v2 = Vector3(4, 5, 6)
        local sum = v1 + v2  -- 获取操作符返回值
        
        -- 修改返回值
        sum.x = 0
        sum.y = 0
        sum.z = 0
        
        -- 验证原操作数没变
        assertApproxEqual(1, v1.x, 0.001, "v1.x 不应被修改")
        assertApproxEqual(4, v2.x, 0.001, "v2.x 不应被修改")
        
        -- 重新计算，验证结果正确
        local sum2 = v1 + v2
        assertApproxEqual(5, sum2.x, 0.001, "新 sum.x 应该是 5")
    end)
    
    -- 基础构造测试
    test("IntVector2: 构造函数", function()
        local v1 = IntVector2(100, 200)
        local v2 = IntVector2(100, 200)
        assertNotNil(v1, "v1")
        assertNotNil(v2, "v2")
        assertEqual(v1.x, v2.x, "x value")
        assertEqual(v1.y, v2.y, "y value")
    end)
    
    test("Vector3: 构造函数", function()
        local v = Vector3(1.5, 2.5, 3.5)
        assertNotNil(v, "v")
        assertApproxEqual(1.5, v.x, 0.001, "x")
        assertApproxEqual(2.5, v.y, 0.001, "y")
        assertApproxEqual(3.5, v.z, 0.001, "z")
    end)
    
    test("Color: 构造函数", function()
        local c = Color(0.5, 0.6, 0.7, 1.0)
        assertNotNil(c, "c")
        assertApproxEqual(0.5, c.r, 0.001, "r")
        assertApproxEqual(0.6, c.g, 0.001, "g")
        assertApproxEqual(0.7, c.b, 0.001, "b")
        assertApproxEqual(1.0, c.a, 0.001, "a")
    end)
end

-- ============================================================================
-- 测试静态成员变量
-- ============================================================================

local function testStaticMembers()
    print("\n=== 静态成员变量测试 ===")
    
    test("Vector3.ZERO", function()
        local v = Vector3.ZERO
        assertNotNil(v, "ZERO")
        assertApproxEqual(0, v.x, 0.001, "x")
        assertApproxEqual(0, v.y, 0.001, "y")
        assertApproxEqual(0, v.z, 0.001, "z")
    end)
    
    test("Vector3.ONE", function()
        local v = Vector3.ONE
        assertNotNil(v, "ONE")
        assertApproxEqual(1, v.x, 0.001, "x")
        assertApproxEqual(1, v.y, 0.001, "y")
        assertApproxEqual(1, v.z, 0.001, "z")
    end)
    
    test("Vector3.UP", function()
        local v = Vector3.UP
        assertNotNil(v, "UP")
        assertApproxEqual(0, v.x, 0.001, "x")
        assertApproxEqual(1, v.y, 0.001, "y")
        assertApproxEqual(0, v.z, 0.001, "z")
    end)
    
    test("IntVector2.ZERO", function()
        local v = IntVector2.ZERO
        assertNotNil(v, "ZERO")
        assertEqual(0, v.x, "x")
        assertEqual(0, v.y, "y")
    end)
    
    test("IntVector2.ONE", function()
        local v = IntVector2.ONE
        assertNotNil(v, "ONE")
        assertEqual(1, v.x, "x")
        assertEqual(1, v.y, "y")
    end)
    
    test("Color.WHITE", function()
        local c = Color.WHITE
        assertNotNil(c, "WHITE")
        assertApproxEqual(1, c.r, 0.001, "r")
        assertApproxEqual(1, c.g, 0.001, "g")
        assertApproxEqual(1, c.b, 0.001, "b")
        assertApproxEqual(1, c.a, 0.001, "a")
    end)
    
    test("Color.BLACK", function()
        local c = Color.BLACK
        assertNotNil(c, "BLACK")
        assertApproxEqual(0, c.r, 0.001, "r")
        assertApproxEqual(0, c.g, 0.001, "g")
        assertApproxEqual(0, c.b, 0.001, "b")
        assertApproxEqual(1, c.a, 0.001, "a")
    end)
    
    test("Quaternion.IDENTITY", function()
        local q = Quaternion.IDENTITY
        assertNotNil(q, "IDENTITY")
        assertApproxEqual(1, q.w, 0.001, "w")
        assertApproxEqual(0, q.x, 0.001, "x")
        assertApproxEqual(0, q.y, 0.001, "y")
        assertApproxEqual(0, q.z, 0.001, "z")
    end)
    
    test("Matrix3.ZERO", function()
        local m = Matrix3.ZERO
        assertNotNil(m, "ZERO")
        -- Matrix3 没有直接的元素访问，只检查存在性
    end)
    
    test("Matrix3.IDENTITY", function()
        local m = Matrix3.IDENTITY
        assertNotNil(m, "IDENTITY")
    end)
    
    test("Matrix4.IDENTITY", function()
        local m = Matrix4.IDENTITY
        assertNotNil(m, "IDENTITY")
    end)
end

-- ============================================================================
-- 测试 Property 访问
-- ============================================================================

local function testPropertyAccess()
    print("\n=== Property 访问测试 ===")
    
    test("input.mousePosition (IntVector2 property)", function()
        local pos = input.mousePosition
        assertNotNil(pos, "mousePosition")
        assertType("userdata", pos, "type")
        -- 访问成员
        local x = pos.x
        local y = pos.y
        assertType("number", x, "x type")
        assertType("number", y, "y type")
    end)
    
    test("input.mousePosition.x 直接访问", function()
        local x = input.mousePosition.x
        assertType("number", x, "x type")
    end)
    
    test("input.mousePosition 多次访问返回一致的值", function()
        local pos1 = input.mousePosition
        local pos2 = input.mousePosition
        -- 在同一帧内，鼠标位置应该相同
        assertEqual(pos1.x, pos2.x, "x")
        assertEqual(pos1.y, pos2.y, "y")
    end)
    
    test("graphics.size (IntVector2 property)", function()
        local size = graphics.size
        assertNotNil(size, "size")
        assertType("userdata", size, "type")
        local w = size.x
        local h = size.y
        assertType("number", w, "width type")
        assertType("number", h, "height type")
    end)
end

-- ============================================================================
-- 测试操作符重载
-- ============================================================================

local function testOperators()
    print("\n=== 操作符重载测试 ===")
    
    test("Vector3 加法", function()
        local v1 = Vector3(1, 2, 3)
        local v2 = Vector3(4, 5, 6)
        local v3 = v1 + v2
        assertNotNil(v3, "result")
        assertApproxEqual(5, v3.x, 0.001, "x")
        assertApproxEqual(7, v3.y, 0.001, "y")
        assertApproxEqual(9, v3.z, 0.001, "z")
    end)
    
    test("Vector3 减法", function()
        local v1 = Vector3(5, 7, 9)
        local v2 = Vector3(1, 2, 3)
        local v3 = v1 - v2
        assertNotNil(v3, "result")
        assertApproxEqual(4, v3.x, 0.001, "x")
        assertApproxEqual(5, v3.y, 0.001, "y")
        assertApproxEqual(6, v3.z, 0.001, "z")
    end)
    
    test("Vector3 标量乘法", function()
        local v1 = Vector3(1, 2, 3)
        local v2 = v1 * 2
        assertNotNil(v2, "result")
        assertApproxEqual(2, v2.x, 0.001, "x")
        assertApproxEqual(4, v2.y, 0.001, "y")
        assertApproxEqual(6, v2.z, 0.001, "z")
    end)
    
    test("Vector3 取负 (用减法模拟)", function()
        local v1 = Vector3(1, 2, 3)
        local v2 = Vector3.ZERO - v1  -- tolua++ 不支持 __unm，用减法代替
        assertNotNil(v2, "result")
        assertApproxEqual(-1, v2.x, 0.001, "x")
        assertApproxEqual(-2, v2.y, 0.001, "y")
        assertApproxEqual(-3, v2.z, 0.001, "z")
    end)
    
    test("IntVector2 加法", function()
        local v1 = IntVector2(10, 20)
        local v2 = IntVector2(30, 40)
        local v3 = v1 + v2
        assertNotNil(v3, "result")
        assertEqual(40, v3.x, "x")
        assertEqual(60, v3.y, "y")
    end)
    
    test("IntVector2 减法", function()
        local v1 = IntVector2(50, 60)
        local v2 = IntVector2(10, 20)
        local v3 = v1 - v2
        assertNotNil(v3, "result")
        assertEqual(40, v3.x, "x")
        assertEqual(40, v3.y, "y")
    end)
    
    test("Color 加法", function()
        local c1 = Color(0.2, 0.3, 0.4, 1.0)
        local c2 = Color(0.1, 0.1, 0.1, 0.0)
        local c3 = c1 + c2
        assertNotNil(c3, "result")
        assertApproxEqual(0.3, c3.r, 0.001, "r")
        assertApproxEqual(0.4, c3.g, 0.001, "g")
        assertApproxEqual(0.5, c3.b, 0.001, "b")
    end)
    
    test("Quaternion 乘法", function()
        local q1 = Quaternion(0, 90, 0)  -- 绕 Y 轴旋转 90 度
        local q2 = Quaternion(90, 0, 0)  -- 绕 X 轴旋转 90 度
        local q3 = q1 * q2
        assertNotNil(q3, "result")
    end)
end

-- ============================================================================
-- 测试方法返回值
-- ============================================================================

local function testMethodReturns()
    print("\n=== 方法返回值测试 ===")
    
    test("Vector3:Normalized() 返回新的 Vector3", function()
        local v1 = Vector3(3, 0, 4)
        local v2 = v1:Normalized()
        assertNotNil(v2, "normalized")
        assertApproxEqual(0.6, v2.x, 0.001, "x")
        assertApproxEqual(0.0, v2.y, 0.001, "y")
        assertApproxEqual(0.8, v2.z, 0.001, "z")
    end)
    
    test("Vector3:Lerp() 返回新的 Vector3", function()
        local v1 = Vector3(0, 0, 0)
        local v2 = Vector3(10, 10, 10)
        local v3 = v1:Lerp(v2, 0.5)
        assertNotNil(v3, "lerp result")
        assertApproxEqual(5, v3.x, 0.001, "x")
        assertApproxEqual(5, v3.y, 0.001, "y")
        assertApproxEqual(5, v3.z, 0.001, "z")
    end)
    
    test("Color:Lerp() 返回新的 Color", function()
        local c1 = Color(0, 0, 0, 1)
        local c2 = Color(1, 1, 1, 1)
        local c3 = c1:Lerp(c2, 0.5)
        assertNotNil(c3, "lerp result")
        assertApproxEqual(0.5, c3.r, 0.001, "r")
        assertApproxEqual(0.5, c3.g, 0.001, "g")
        assertApproxEqual(0.5, c3.b, 0.001, "b")
    end)
    
    test("Quaternion:Inverse() 返回新的 Quaternion", function()
        local q1 = Quaternion(0, 45, 0)
        local q2 = q1:Inverse()
        assertNotNil(q2, "inverse")
    end)
    
    test("BoundingBox:Center() 返回 Vector3", function()
        local bb = BoundingBox(Vector3(-1, -1, -1), Vector3(1, 1, 1))
        local center = bb.center
        assertNotNil(center, "center")
        assertApproxEqual(0, center.x, 0.001, "x")
        assertApproxEqual(0, center.y, 0.001, "y")
        assertApproxEqual(0, center.z, 0.001, "z")
    end)
end

-- ============================================================================
-- 测试所有 POD 类型构造
-- ============================================================================

local function testAllPODTypes()
    print("\n=== 所有 POD 类型构造测试 ===")
    
    test("Vector2 构造", function()
        local v = Vector2(1.5, 2.5)
        assertNotNil(v, "v")
        assertApproxEqual(1.5, v.x, 0.001, "x")
        assertApproxEqual(2.5, v.y, 0.001, "y")
    end)
    
    test("Vector3 构造", function()
        local v = Vector3(1.5, 2.5, 3.5)
        assertNotNil(v, "v")
        assertApproxEqual(1.5, v.x, 0.001, "x")
        assertApproxEqual(2.5, v.y, 0.001, "y")
        assertApproxEqual(3.5, v.z, 0.001, "z")
    end)
    
    test("Vector4 构造", function()
        local v = Vector4(1.5, 2.5, 3.5, 4.5)
        assertNotNil(v, "v")
        assertApproxEqual(1.5, v.x, 0.001, "x")
        assertApproxEqual(2.5, v.y, 0.001, "y")
        assertApproxEqual(3.5, v.z, 0.001, "z")
        assertApproxEqual(4.5, v.w, 0.001, "w")
    end)
    
    test("IntVector2 构造", function()
        local v = IntVector2(100, 200)
        assertNotNil(v, "v")
        assertEqual(100, v.x, "x")
        assertEqual(200, v.y, "y")
    end)
    
    test("IntVector3 构造", function()
        local v = IntVector3(100, 200, 300)
        assertNotNil(v, "v")
        assertEqual(100, v.x, "x")
        assertEqual(200, v.y, "y")
        assertEqual(300, v.z, "z")
    end)
    
    test("IntRect 构造", function()
        local r = IntRect(10, 20, 100, 200)
        assertNotNil(r, "r")
        assertEqual(10, r.left, "left")
        assertEqual(20, r.top, "top")
        assertEqual(100, r.right, "right")
        assertEqual(200, r.bottom, "bottom")
    end)
    
    test("Rect 构造", function()
        local r = Rect(0.1, 0.2, 0.9, 0.8)
        assertNotNil(r, "r")
        assertApproxEqual(0.1, r.min.x, 0.001, "min.x")
        assertApproxEqual(0.2, r.min.y, 0.001, "min.y")
    end)
    
    test("Color 构造", function()
        local c = Color(0.5, 0.6, 0.7, 0.8)
        assertNotNil(c, "c")
        assertApproxEqual(0.5, c.r, 0.001, "r")
        assertApproxEqual(0.6, c.g, 0.001, "g")
        assertApproxEqual(0.7, c.b, 0.001, "b")
        assertApproxEqual(0.8, c.a, 0.001, "a")
    end)
    
    test("Quaternion 构造 (欧拉角)", function()
        local q = Quaternion(45, 90, 0)
        assertNotNil(q, "q")
        assertType("number", q.w, "w type")
        assertType("number", q.x, "x type")
        assertType("number", q.y, "y type")
        assertType("number", q.z, "z type")
    end)
    
    test("Quaternion 构造 (轴角)", function()
        local q = Quaternion(90, Vector3.UP)
        assertNotNil(q, "q")
    end)
    
    test("BoundingBox 构造", function()
        local bb = BoundingBox(Vector3(-1, -1, -1), Vector3(1, 1, 1))
        assertNotNil(bb, "bb")
    end)
    
    test("Sphere 构造", function()
        local s = Sphere(Vector3(0, 0, 0), 5.0)
        assertNotNil(s, "s")
        assertApproxEqual(5.0, s.radius, 0.001, "radius")
    end)
    
    test("Plane 构造", function()
        local p = Plane(Vector3.UP, Vector3.ZERO)  -- normal + point
        assertNotNil(p, "p")
    end)
    
    test("Ray 构造", function()
        local r = Ray(Vector3(0, 0, 0), Vector3(0, 0, 1))
        assertNotNil(r, "r")
    end)
    
    test("Matrix3 构造", function()
        local m = Matrix3()
        assertNotNil(m, "m")
    end)
    
    test("Matrix3x4 构造", function()
        local m = Matrix3x4()
        assertNotNil(m, "m")
    end)
    
    test("Matrix4 构造", function()
        local m = Matrix4()
        assertNotNil(m, "m")
    end)
    
    test("StringHash 构造", function()
        local h = StringHash("TestString")
        assertNotNil(h, "h")
    end)
end

-- ============================================================================
-- 性能测试
-- ============================================================================

local function testPerformance()
    print("\n=== 性能测试 ===")
    
    local iterations = 10000
    
    test("IntVector2 创建性能 (" .. iterations .. " 次)", function()
        local start = os.clock()
        for i = 1, iterations do
            local v = IntVector2(i, i * 2)
            local _ = v.x + v.y
        end
        local elapsed = os.clock() - start
        print("    耗时: " .. string.format("%.4f", elapsed) .. " 秒")
    end)
    
    test("Vector3 创建性能 (" .. iterations .. " 次)", function()
        local start = os.clock()
        for i = 1, iterations do
            local v = Vector3(i, i * 2, i * 3)
            local _ = v.x + v.y + v.z
        end
        local elapsed = os.clock() - start
        print("    耗时: " .. string.format("%.4f", elapsed) .. " 秒")
    end)
    
    test("Vector3 加法性能 (" .. iterations .. " 次)", function()
        local v1 = Vector3(1, 2, 3)
        local v2 = Vector3(4, 5, 6)
        local start = os.clock()
        for i = 1, iterations do
            local v3 = v1 + v2
        end
        local elapsed = os.clock() - start
        print("    耗时: " .. string.format("%.4f", elapsed) .. " 秒")
    end)
    
    test("Property 访问性能 (" .. iterations .. " 次)", function()
        local start = os.clock()
        for i = 1, iterations do
            local pos = input.mousePosition
            local _ = pos.x + pos.y
        end
        local elapsed = os.clock() - start
        print("    耗时: " .. string.format("%.4f", elapsed) .. " 秒")
    end)
end

-- ============================================================================
-- 边界情况测试
-- ============================================================================

local function testEdgeCases()
    print("\n=== 边界情况测试 ===")
    
    test("连续属性访问", function()
        -- 确保多次连续访问不会崩溃
        for i = 1, 100 do
            local x = input.mousePosition.x
            local y = input.mousePosition.y
        end
    end)
    
    test("嵌套表达式", function()
        local result = (Vector3(1, 2, 3) + Vector3(4, 5, 6)) * 2
        assertNotNil(result, "result")
        assertApproxEqual(10, result.x, 0.001, "x")
    end)
    
    test("方法链调用", function()
        local v = Vector3(3, 0, 4):Normalized()
        assertNotNil(v, "v")
        assertApproxEqual(1.0, v:Length(), 0.001, "length")
    end)
    
    test("静态成员多次访问", function()
        for i = 1, 100 do
            local zero = Vector3.ZERO
            local one = Vector3.ONE
            assertEqual(0, zero.x, "zero.x")
            assertEqual(1, one.x, "one.x")
        end
    end)
end

-- ============================================================================
-- 主函数
-- ============================================================================

function Start()
    SampleStart()
    
    print("========================================")
    print("  Blittable Copy 全面测试")
    print("========================================")
    
    -- 运行所有测试
    testValueCopySemantics()
    testStaticMembers()
    testPropertyAccess()
    testOperators()
    testMethodReturns()
    testAllPODTypes()
    testEdgeCases()
    testPerformance()
    
    -- 打印测试结果
    print("\n========================================")
    print("  测试结果汇总")
    print("========================================")
    print("通过: " .. testResults.passed)
    print("失败: " .. testResults.failed)
    
    if #testResults.errors > 0 then
        print("\n失败的测试:")
        for _, err in ipairs(testResults.errors) do
            print("  - " .. err.name)
            print("    " .. err.error)
        end
    end
    
    print("\n========================================")
    if testResults.failed == 0 then
        print("  ✓ 所有测试通过!")
    else
        print("  ✗ 有 " .. testResults.failed .. " 个测试失败")
    end
    print("========================================")
    
    -- 设置窗口
    SetLogoVisible(false)
end

function Stop()
end

