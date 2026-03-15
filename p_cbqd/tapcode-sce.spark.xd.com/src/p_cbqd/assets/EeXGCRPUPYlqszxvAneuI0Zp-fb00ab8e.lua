-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 管理员CDK发放工具
-- 独立入口，build时使用 entry: "admin_tool.lua"
-- 功能: 生成评价礼包/VIP2/VIP3/节日礼包CDK，保存到 admin_cdks.json
-- 安全: 需要输入管理员密码才能进入
-- ============================================================================
---@diagnostic disable: undefined-global
local UI = require("urhox-libs/UI")

-- ============================================================================
-- 配置
-- ============================================================================
local ADMIN_PASSWORD = "admin2026"  -- 管理员密码，可自行修改
local CDK_FILE = "admin_cdks.json"

-- ============================================================================
-- 数据
-- ============================================================================
---@type table<string, table>
local cdkList = {}
local uiRoot_ = nil
local statusMsg = ""
local statusColor = {180, 180, 180, 255}
local isLoggedIn = false
local pwdInput = ""
local pwdError = ""

-- ============================================================================
-- CDK 存储
-- ============================================================================
local function loadCDKs()
    if not fileSystem:FileExists(CDK_FILE) then
        cdkList = {}
        return
    end
    local file = File(CDK_FILE, FILE_READ)
    if file:IsOpen() then
        local ok, data = pcall(cjson.decode, file:ReadString())
        file:Close()
        if ok and type(data) == "table" then
            cdkList = data
        else
            cdkList = {}
        end
    end
end

local function saveCDKs()
    local file = File(CDK_FILE, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(cdkList))
        file:Close()
    end
end

-- ============================================================================
-- CDK 生成
-- ============================================================================
local CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function generateCode(length)
    length = length or 8
    local code = ""
    for _ = 1, length do
        local idx = math.random(1, #CHARSET)
        code = code .. string.sub(CHARSET, idx, idx)
    end
    return code
end

local function generateUniqueCDK()
    for _ = 1, 100 do
        local code = generateCode(8)
        if not cdkList[code] then
            return code
        end
    end
    return generateCode(12)
end

local function createCDK(cdkType)
    local code = generateUniqueCDK()
    local now = os.date("%Y-%m-%d %H:%M")
    local info = {}

    if cdkType == "review" then
        info = { name = "评价礼包", type = "review", diamonds = 500, createdAt = now }
    elseif cdkType == "vip2" then
        info = { name = "VIP2礼包", type = "vip2", vipLevel = 2, createdAt = now }
    elseif cdkType == "vip3" then
        info = { name = "VIP3礼包", type = "vip3", vipLevel = 3, createdAt = now }
    elseif cdkType == "festival" then
        info = { name = "节日礼包", type = "festival", tickets = 1000, createdAt = now }
    end

    cdkList[code] = info
    saveCDKs()

    statusMsg = "已生成 [" .. info.name .. "] CDK: " .. code
    statusColor = {100, 255, 150, 255}
    refreshUI()
end

-- ============================================================================
-- 登录界面
-- ============================================================================
local function showLoginUI()
    uiRoot_ = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = {12, 12, 20, 255},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = "90%",
                maxWidth = 360,
                padding = 28,
                gap = 16,
                backgroundColor = {25, 25, 40, 240},
                borderRadius = 16,
                borderWidth = 1,
                borderColor = {60, 50, 100, 255},
                alignItems = "center",
                children = {
                    UI.Label { text = "🔒", fontSize = 36 },
                    UI.Label {
                        text = "管理员验证",
                        fontSize = 20, fontWeight = "bold",
                        color = {255, 215, 0, 255},
                    },
                    UI.Label {
                        text = "请输入管理员密码",
                        fontSize = 12,
                        color = {140, 140, 160, 255},
                    },
                    UI.TextField {
                        width = "100%", height = 40,
                        placeholder = "请输入密码...",
                        fontSize = 14,
                        value = pwdInput,
                        onChange = function(self, text)
                            pwdInput = text
                        end,
                    },
                    (pwdError ~= "") and UI.Label {
                        text = pwdError,
                        fontSize = 11,
                        color = {255, 80, 80, 255},
                    } or UI.Panel { width = 0, height = 0 },
                    UI.Button {
                        text = "登录",
                        fontSize = 14,
                        width = "100%", height = 42,
                        variant = "primary",
                        onClick = function()
                            if pwdInput == ADMIN_PASSWORD then
                                isLoggedIn = true
                                pwdError = ""
                                loadCDKs()
                                refreshUI()
                            else
                                pwdError = "密码错误，请重试"
                                showLoginUI()
                                UI.SetRoot(uiRoot_, true)
                            end
                        end,
                    },
                },
            },
        },
    }
    UI.SetRoot(uiRoot_, true)
end

-- ============================================================================
-- 主界面
-- ============================================================================
function refreshUI()
    if not isLoggedIn then
        showLoginUI()
        return
    end

    -- 统计数量
    local reviewCount, vip2Count, vip3Count, festivalCount = 0, 0, 0, 0
    local recentList = {}
    for code, info in pairs(cdkList) do
        if info.type == "review" then reviewCount = reviewCount + 1
        elseif info.type == "vip2" then vip2Count = vip2Count + 1
        elseif info.type == "vip3" then vip3Count = vip3Count + 1
        elseif info.type == "festival" then festivalCount = festivalCount + 1
        end
        recentList[#recentList + 1] = { code = code, info = info }
    end
    table.sort(recentList, function(a, b) return (a.info.createdAt or "") > (b.info.createdAt or "") end)

    -- CDK列表
    local listChildren = {}

    listChildren[#listChildren + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        paddingVertical = 6,
        paddingHorizontal = 10,
        backgroundColor = {40, 40, 60, 255},
        borderBottom = 1,
        borderColor = {60, 60, 80, 255},
        children = {
            UI.Label { text = "CDK码", fontSize = 11, fontWeight = "bold", color = {200, 200, 220, 255}, width = "35%" },
            UI.Label { text = "类型", fontSize = 11, fontWeight = "bold", color = {200, 200, 220, 255}, width = "25%" },
            UI.Label { text = "创建时间", fontSize = 11, fontWeight = "bold", color = {200, 200, 220, 255}, flex = 1 },
        },
    }

    for i, item in ipairs(recentList) do
        local typeColor = {180, 180, 180, 255}
        if item.info.type == "review" then
            typeColor = {255, 220, 100, 255}
        elseif item.info.type == "vip2" then
            typeColor = {180, 140, 255, 255}
        elseif item.info.type == "vip3" then
            typeColor = {255, 160, 80, 255}
        elseif item.info.type == "festival" then
            typeColor = {100, 220, 255, 255}
        end

        listChildren[#listChildren + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            paddingVertical = 5,
            paddingHorizontal = 10,
            backgroundColor = (i % 2 == 0) and {30, 30, 45, 255} or {25, 25, 38, 255},
            alignItems = "center",
            children = {
                UI.Label { text = item.code, fontSize = 12, fontWeight = "bold", color = {100, 255, 200, 255}, width = "35%" },
                UI.Label { text = item.info.name or "未知", fontSize = 11, color = typeColor, width = "25%" },
                UI.Label { text = item.info.createdAt or "-", fontSize = 10, color = {140, 140, 160, 255}, flex = 1 },
            },
        }
    end

    if #recentList == 0 then
        listChildren[#listChildren + 1] = UI.Panel {
            width = "100%", padding = 20, alignItems = "center",
            children = {
                UI.Label { text = "暂无CDK记录", fontSize = 12, color = {100, 100, 120, 255} },
                UI.Label { text = "点击上方按钮生成CDK", fontSize = 10, color = {80, 80, 100, 255} },
            },
        }
    end

    uiRoot_ = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = {18, 18, 28, 255},
        flexDirection = "column",
        children = {
            -- 顶部标题栏
            UI.Panel {
                width = "100%",
                padding = 12,
                backgroundColor = {30, 25, 45, 255},
                borderBottom = 2,
                borderColor = {80, 60, 140, 255},
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    UI.Label { text = "🔧", fontSize = 22 },
                    UI.Panel {
                        flex = 1,
                        children = {
                            UI.Label { text = "管理员CDK发放工具", fontSize = 18, fontWeight = "bold", color = {255, 215, 0, 255} },
                            UI.Label { text = "暗黑挂机爽刷装备版本 - 后台管理", fontSize = 10, color = {140, 130, 170, 255} },
                        },
                    },
                },
            },

            -- 生成按钮区
            UI.Panel {
                width = "100%",
                padding = 12,
                gap = 8,
                backgroundColor = {25, 25, 38, 255},
                children = {
                    UI.Label { text = "生成CDK", fontSize = 13, fontWeight = "bold", color = {200, 200, 220, 255} },

                    -- 第一行: 评价 + VIP2 + VIP3
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = 8,
                        children = {
                            UI.Button {
                                text = "⭐ 评价礼包\n(500💎)",
                                fontSize = 10,
                                flex = 1, height = 42,
                                variant = "warning",
                                onClick = function() createCDK("review") end,
                            },
                            UI.Button {
                                text = "💜 VIP2礼包",
                                fontSize = 10,
                                flex = 1, height = 42,
                                variant = "primary",
                                onClick = function() createCDK("vip2") end,
                            },
                            UI.Button {
                                text = "🔶 VIP3礼包",
                                fontSize = 10,
                                flex = 1, height = 42,
                                variant = "danger",
                                onClick = function() createCDK("vip3") end,
                            },
                        },
                    },

                    -- 第二行: 节日礼包
                    UI.Button {
                        text = "🎉 节日礼包 (1000🎫精英门票，每CDK限领一次)",
                        fontSize = 11,
                        width = "100%", height = 40,
                        variant = "success",
                        onClick = function() createCDK("festival") end,
                    },

                    -- 统计
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = 10,
                        paddingVertical = 4,
                        children = {
                            UI.Label { text = "⭐评价:" .. reviewCount, fontSize = 10, color = {255, 220, 100, 255} },
                            UI.Label { text = "💜VIP2:" .. vip2Count, fontSize = 10, color = {180, 140, 255, 255} },
                            UI.Label { text = "🔶VIP3:" .. vip3Count, fontSize = 10, color = {255, 160, 80, 255} },
                            UI.Label { text = "🎉节日:" .. festivalCount, fontSize = 10, color = {100, 220, 255, 255} },
                        },
                    },
                },
            },

            -- 状态消息
            (statusMsg ~= "") and UI.Panel {
                width = "100%",
                paddingHorizontal = 12, paddingVertical = 8,
                backgroundColor = {20, 40, 30, 255},
                borderLeft = 3,
                borderColor = {100, 255, 150, 255},
                children = {
                    UI.Label { text = statusMsg, fontSize = 12, fontWeight = "bold", color = statusColor },
                },
            } or UI.Panel { width = 0, height = 0 },

            -- 分割线
            UI.Panel { width = "100%", height = 1, backgroundColor = {50, 50, 70, 255} },

            -- CDK列表标题
            UI.Panel {
                width = "100%",
                paddingHorizontal = 12, paddingVertical = 6,
                flexDirection = "row", alignItems = "center",
                children = {
                    UI.Label { text = "📋 已生成的CDK列表", fontSize = 13, fontWeight = "bold", color = {200, 200, 220, 255}, flex = 1 },
                    UI.Label { text = "共" .. #recentList .. "个", fontSize = 10, color = {140, 140, 160, 255} },
                },
            },

            -- CDK列表
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                backgroundColor = {22, 22, 32, 255},
                children = listChildren,
            },
        },
    }

    UI.SetRoot(uiRoot_, true)
end

-- ============================================================================
-- 入口
-- ============================================================================
function Start()
    graphics.windowTitle = "暗黑挂机爽刷装备版本 - 管理员工具"
    math.randomseed(os.time())

    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 显示登录界面
    showLoginUI()

    print("=== 管理员CDK发放工具已启动 ===")
end

function Stop()
    UI.Shutdown()
end
