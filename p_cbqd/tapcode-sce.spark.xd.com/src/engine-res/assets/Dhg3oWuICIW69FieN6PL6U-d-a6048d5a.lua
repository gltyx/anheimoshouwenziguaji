-- ============================================================================
-- 云变量字符串存取测试脚本
-- 
-- 测试 clientScore API 对字符串及任意类型云变量的读写能力
--
-- 数据类型说明:
--   - values (回调第一个参数): 通过 Set/BatchSet():Set() 写入的任意类型值
--   - iscores (回调第二个参数): 通过 SetInt/Add/BatchSet():SetInt()/Add() 写入的整数
--   - 注意: sscores 参数已废弃，不再使用
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 全局变量
-- ============================================================================

local statusText = nil
local logText = nil
local testResults = {}

-- ============================================================================
-- 工具函数
-- ============================================================================

local function log(message)
    print("[CloudStringTest] " .. message)
    table.insert(testResults, message)
    if logText then
        logText.text = table.concat(testResults, "\n")
    end
end

local function updateStatus(status)
    if statusText then
        statusText.text = status
    end
end

-- ============================================================================
-- 测试函数
-- ============================================================================

-- 测试 1: 使用 clientScore:Set 写入字符串
-- 注意: clientScore:Set() 现在支持任意类型（字符串、表等），写入到 values
local function test1_SetString(callback)
    log("=== 测试 1: clientScore:Set() 写入字符串 ===")
    
    local testValue = "Hello World 你好世界 " .. os.date()
    log("写入值: " .. testValue)
    
    clientScore:Set("test_string", testValue, {
        ok = function()
            log("✓ Set 写入成功")
            callback(true)
        end,
        error = function(code, reason)
            log("✗ Set 写入失败: " .. tostring(reason) .. " (code: " .. tostring(code) .. ")")
            callback(false)
        end,
        timeout = function()
            log("✗ Set 写入超时")
            callback(false)
        end
    })
end

-- 测试 2: 使用 Get 方法读取字符串
local function test2_GetString(callback)
    log("=== 测试 2: clientScore:Get 读取字符串 ===")
    
    clientScore:Get("test_string", {
        ok = function(values, iscores)
            log("values.test_string = " .. tostring(values.test_string) .. " (" .. type(values.test_string) .. ")")
            log("iscores.test_string = " .. tostring(iscores.test_string) .. " (" .. type(iscores.test_string) .. ")")
            
            if values.test_string then
                log("✓ 从 values 读取成功: " .. values.test_string)
            else
                log("✗ 读取值为空")
            end
            callback(true)
        end,
        error = function(code, reason)
            log("✗ Get 读取失败: " .. tostring(reason))
            callback(false)
        end,
        timeout = function()
            log("✗ Get 读取超时")
            callback(false)
        end
    })
end

-- 测试 3: 使用 BatchSet 写入混合类型
local function test3_BatchSetMixed(callback)
    log("=== 测试 3: clientScore:BatchSet() 写入混合类型 ===")
    
    local testValue1 = "BatchSet String 1: " .. os.date()
    local testValue2 = "BatchSet String 2: 中文测试 🎮"
    
    log("写入 batch_str1: " .. testValue1)
    log("写入 batch_str2: " .. testValue2)
    log("写入 batch_int: 12345 (整数)")
    
    clientScore:BatchSet()
        :Set("batch_str1", testValue1)      -- 任意类型 -> values
        :Set("batch_str2", testValue2)      -- 任意类型 -> values
        :SetInt("batch_int", 12345)         -- 整数 -> iscores
        :Save("测试批量写入混合类型", {
            ok = function()
                log("✓ BatchSet 写入成功")
                callback(true)
            end,
            error = function(code, reason)
                log("✗ BatchSet 写入失败: " .. tostring(reason) .. " (code: " .. tostring(code) .. ")")
                callback(false)
            end,
            timeout = function()
                log("✗ BatchSet 写入超时")
                callback(false)
            end
        })
end

-- 测试 4: 使用 BatchGet 读取混合类型
local function test4_BatchGetMixed(callback)
    log("=== 测试 4: clientScore:BatchGet() 读取混合类型 ===")
    
    clientScore:BatchGet()
        :Key("batch_str1")
        :Key("batch_str2")
        :Key("batch_int")
        :Fetch({
            ok = function(values, iscores)
                log("--- values (任意类型) ---")
                log("  batch_str1 = " .. tostring(values.batch_str1) .. " (" .. type(values.batch_str1) .. ")")
                log("  batch_str2 = " .. tostring(values.batch_str2) .. " (" .. type(values.batch_str2) .. ")")
                log("  batch_int = " .. tostring(values.batch_int) .. " (" .. type(values.batch_int) .. ")")
                
                log("--- iscores (整数) ---")
                log("  batch_str1 = " .. tostring(iscores.batch_str1))
                log("  batch_str2 = " .. tostring(iscores.batch_str2))
                log("  batch_int = " .. tostring(iscores.batch_int))
                
                -- 验证: 字符串应该在 values 中，整数应该在 iscores 中
                if values.batch_str1 and values.batch_str2 then
                    log("✓ 字符串正确存储在 values 中")
                else
                    log("✗ 字符串未正确存储")
                end
                
                if iscores.batch_int == 12345 then
                    log("✓ 整数正确存储在 iscores 中")
                else
                    log("✗ 整数未正确存储")
                end
                
                callback(true)
            end,
            error = function(code, reason)
                log("✗ BatchGet 读取失败: " .. tostring(reason))
                callback(false)
            end,
            timeout = function()
                log("✗ BatchGet 读取超时")
                callback(false)
            end
        })
end

-- 测试 5: 长字符串测试
local function test5_LongString(callback)
    log("=== 测试 5: 长字符串测试 ===")
    
    -- 构建一个较长的字符串
    local longStr = string.rep("ABCDEFGHIJabcdefghij中文测试", 100)
    log("字符串长度: " .. #longStr .. " 字节")
    
    clientScore:Set("long_string", longStr, {
        ok = function()
            log("✓ 长字符串写入成功")
            -- 立即读取验证
            clientScore:Get("long_string", {
                ok = function(values, iscores)
                    local readValue = values.long_string
                    if readValue then
                        log("读取长度: " .. #readValue .. " 字节")
                        if readValue == longStr then
                            log("✓ 长字符串读写一致")
                        else
                            log("✗ 长字符串读写不一致")
                        end
                    else
                        log("✗ 长字符串读取为空")
                    end
                    callback(true)
                end,
                error = function(code, reason)
                    log("✗ 长字符串读取失败: " .. tostring(reason))
                    callback(false)
                end
            })
        end,
        error = function(code, reason)
            log("✗ 长字符串写入失败: " .. tostring(reason) .. " (code: " .. tostring(code) .. ")")
            callback(false)
        end
    })
end

-- 测试 6: Lua 表测试（JSON-like 结构）
local function test6_TableValue(callback)
    log("=== 测试 6: Lua 表测试 ===")
    
    -- 使用 Lua 表存储复杂数据（自动序列化）
    local tableData = {
        name = "测试玩家",
        level = 50,
        items = {1, 2, 3},
        settings = {sound = true, music = false}
    }
    log("表数据: " .. tostring(tableData))
    
    clientScore:Set("table_data", tableData, {
        ok = function()
            log("✓ 表写入成功")
            clientScore:Get("table_data", {
                ok = function(values, iscores)
                    local readValue = values.table_data
                    if readValue and type(readValue) == "table" then
                        log("读取表: name=" .. tostring(readValue.name) .. ", level=" .. tostring(readValue.level))
                        if readValue.name == tableData.name and readValue.level == tableData.level then
                            log("✓ 表读写一致")
                        else
                            log("✗ 表读写不一致")
                        end
                    else
                        log("✗ 表读取为空或类型错误: " .. type(readValue))
                    end
                    callback(true)
                end,
                error = function(code, reason)
                    log("✗ 表读取失败: " .. tostring(reason))
                    callback(false)
                end
            })
        end,
        error = function(code, reason)
            log("✗ 表写入失败: " .. tostring(reason) .. " (code: " .. tostring(code) .. ")")
            callback(false)
        end
    })
end

-- ============================================================================
-- 主测试流程
-- ============================================================================

local function runAllTests()
    log("开始云变量字符串存取测试...")
    log("用户 ID: " .. tostring(clientScore.userId))
    log("地图名称: " .. tostring(clientScore.mapName))
    log("")
    
    updateStatus("正在运行测试...")
    
    -- 串行执行测试（云变量 API 是异步的，回调会在操作完成后触发）
    test1_SetString(function(success1)
        test2_GetString(function(success2)
            test3_BatchSetMixed(function(success3)
                test4_BatchGetMixed(function(success4)
                    test5_LongString(function(success5)
                        test6_TableValue(function(success6)
                            log("")
                            log("=== 测试完成 ===")
                            updateStatus("测试完成")
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- ============================================================================
-- 场景初始化
-- ============================================================================

function Start()
    -- 创建示例场景
    SampleStart()
    
    -- 创建 UI
    CreateUI()
    
    -- 开始测试
    runAllTests()
end

function CreateUI()
    -- 状态文本
    statusText = ui.root:CreateChild("Text")
    statusText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 20)
    statusText.text = "云变量字符串测试"
    statusText.color = Color(1, 1, 0)
    statusText.horizontalAlignment = HA_CENTER
    statusText.verticalAlignment = VA_TOP
    statusText:SetPosition(0, 40)
    
    -- 日志文本
    logText = ui.root:CreateChild("Text")
    logText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 14)
    logText.text = ""
    logText.color = Color(0.9, 0.9, 0.9)
    logText.horizontalAlignment = HA_LEFT
    logText.verticalAlignment = VA_TOP
    logText:SetPosition(20, 80)
    logText.wordwrap = true
    logText:SetMaxWidth(graphics.width - 40)
end

function Stop()
    -- 清理
end
