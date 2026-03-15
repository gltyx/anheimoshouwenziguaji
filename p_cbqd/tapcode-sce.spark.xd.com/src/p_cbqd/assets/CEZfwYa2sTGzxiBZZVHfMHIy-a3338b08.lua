-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 全屏界面 (加载/错误/踢线/版本过旧)
-- ============================================================================
local UI = require("urhox-libs/UI")
local CFG = require("config")

local M = {}

-- ============================================================================
-- 版本比较
-- ============================================================================

--- 比较版本号 (如 "1.0.9" > "1.0.0")
--- @return number  -1: a<b, 0: a==b, 1: a>b
function M.compareVersion(a, b)
    if not a or not b then return 0 end
    local function split(v)
        local parts = {}
        for n in tostring(v):gmatch("(%d+)") do
            parts[#parts + 1] = tonumber(n) or 0
        end
        return parts
    end
    local pa, pb = split(a), split(b)
    local len = math.max(#pa, #pb)
    for i = 1, len do
        local na, nb = pa[i] or 0, pb[i] or 0
        if na < nb then return -1 end
        if na > nb then return 1 end
    end
    return 0
end

-- ============================================================================
-- 加载中界面
-- ============================================================================

--- 显示加载中界面
---@param msg string|nil
---@return table rootPanel
function M.buildLoadingScreen(msg)
    return UI.SafeAreaView {
        edges = "all",
        width = "100%",
        height = "100%",
        backgroundColor = {20, 20, 30, 255},
        children = {
            UI.Panel {
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                gap = 20,
                children = {
                    UI.Label {
                        text = "⚔️ 暗黑挂机爽刷装备版本 ⚔️",
                        fontSize = 44, fontWeight = "bold",
                        color = {255, 215, 0, 255},
                    },
                    UI.Label {
                        text = msg or "正在加载存档...",
                        fontSize = 32,
                        color = {180, 180, 200, 255},
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 加载失败界面
-- ============================================================================

--- 显示加载失败界面(带重试)
---@param errMsg string|nil
---@param onRetry function 重试回调
---@param onNewGame function 新建角色回调
---@return table rootPanel
function M.buildLoadErrorScreen(errMsg, onRetry, onNewGame)
    return UI.SafeAreaView {
        edges = "all",
        width = "100%",
        height = "100%",
        backgroundColor = {20, 20, 30, 255},
        children = {
            UI.Panel {
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                gap = 20,
                children = {
                    UI.Label {
                        text = "⚔️ 暗黑挂机爽刷装备版本 ⚔️",
                        fontSize = 44, fontWeight = "bold",
                        color = {255, 215, 0, 255},
                    },
                    UI.Label {
                        text = "存档加载失败",
                        fontSize = 36,
                        color = {255, 100, 100, 255},
                    },
                    UI.Label {
                        text = errMsg or "未知错误",
                        fontSize = 28,
                        color = {200, 150, 150, 255},
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = 20,
                        children = {
                            UI.Button {
                                text = "重试",
                                fontSize = 32,
                                width = 160, height = 56,
                                variant = "primary",
                                onClick = onRetry,
                            },
                            UI.Button {
                                text = "新建角色",
                                fontSize = 32,
                                width = 160, height = 56,
                                onClick = onNewGame,
                            },
                        },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 被踢下线界面
-- ============================================================================

--- 构建被踢下线提示界面
---@param onRelogin function 重新登录回调
---@return table rootPanel
function M.buildKickedScreen(onRelogin)
    return UI.SafeAreaView {
        edges = "all",
        width = "100%",
        height = "100%",
        backgroundColor = {20, 20, 30, 255},
        children = {
            UI.Panel {
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                gap = 24,
                children = {
                    UI.Label {
                        text = "账号已在其他设备登录",
                        fontSize = 40, fontWeight = "bold",
                        color = {255, 100, 100, 255},
                    },
                    UI.Label {
                        text = "当前设备已安全保存存档并下线",
                        fontSize = 32,
                        color = {180, 180, 200, 255},
                    },
                    UI.Label {
                        text = "如需继续游戏，请点击重新登录",
                        fontSize = 28,
                        color = {140, 140, 160, 255},
                    },
                    UI.Button {
                        text = "重新登录",
                        fontSize = 32,
                        width = 200, height = 60,
                        variant = "primary",
                        onClick = onRelogin,
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 版本过旧界面
-- ============================================================================

--- 构建版本过旧提示界面
---@param savedVer string 云端/存档版本
---@param currentVer string 当前代码版本
---@return table rootPanel
function M.buildOutdatedScreen(savedVer, currentVer)
    return UI.SafeAreaView {
        edges = "all",
        width = "100%",
        height = "100%",
        backgroundColor = {20, 20, 30, 255},
        children = {
            UI.Panel {
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                gap = 24,
                children = {
                    UI.Label {
                        text = "发现新版本",
                        fontSize = 44, fontWeight = "bold",
                        color = {255, 215, 0, 255},
                    },
                    UI.Label {
                        text = "当前版本: v" .. tostring(currentVer),
                        fontSize = 32,
                        color = {180, 180, 200, 255},
                    },
                    UI.Label {
                        text = "最新版本: v" .. tostring(savedVer),
                        fontSize = 32,
                        color = {100, 255, 200, 255},
                    },
                    UI.Label {
                        text = "请关闭后重新打开游戏",
                        fontSize = 32, fontWeight = "bold",
                        color = {255, 200, 100, 255},
                    },
                },
            },
        },
    }
end

return M
