-- TouchController.lua
-- 双指缩放、陀螺仪控制等触摸手势
-- 来源：从 Touch.lua 改进

---@class TouchController
local TouchController = {}

---@class TouchControllerConfig
---@field gyroscopeThreshold number
---@field cameraMinDist number
---@field cameraMaxDist number
---@field touchSensitivity number

---配置
---@type TouchControllerConfig
TouchController.config = {
    gyroscopeThreshold = 0.1,
    cameraMinDist = 1.0,
    cameraMaxDist = 20.0,
    touchSensitivity = 1.0
}

-- 状态
---@type boolean
TouchController.zoom = false
---@type boolean
TouchController.useGyroscope = false
---@type number
TouchController.cameraDistance = 5.0

---初始化触摸控制器
---@param options? {gyroscopeThreshold?: number, cameraMinDist?: number, cameraMaxDist?: number, touchSensitivity?: number, useGyroscope?: boolean, cameraDistance?: number} 配置选项
function TouchController.Initialize(options)
    options = options or {}
    
    -- 更新配置
    if options.gyroscopeThreshold then
        TouchController.config.gyroscopeThreshold = options.gyroscopeThreshold
    end
    if options.cameraMinDist then
        TouchController.config.cameraMinDist = options.cameraMinDist
    end
    if options.cameraMaxDist then
        TouchController.config.cameraMaxDist = options.cameraMaxDist
    end
    if options.touchSensitivity then
        TouchController.config.touchSensitivity = options.touchSensitivity
    end
    if options.useGyroscope ~= nil then
        TouchController.useGyroscope = options.useGyroscope
    end
    if options.cameraDistance then
        TouchController.cameraDistance = options.cameraDistance
    end
end

---更新触摸输入（在 HandleUpdate 中调用）
---@param controls? Controls 控制对象（可选，用于陀螺仪）
---@return {zoom: boolean, cameraDistance: number} 返回缩放状态和相机距离
function TouchController.Update(controls)
    TouchController.zoom = false -- 重置
    
    -- 双指缩放检测
    if input.numTouches == 2 then
        local touch1 = input:GetTouch(0)
        local touch2 = input:GetTouch(1)
        
        -- 检查缩放模式（两个触摸点反向移动，且不在 UI 元素上）
        if not touch1.touchedElement and not touch2.touchedElement then
            local oppositeDirection = (touch1.delta.y > 0 and touch2.delta.y < 0) or 
                                     (touch1.delta.y < 0 and touch2.delta.y > 0)
            
            if oppositeDirection then
                TouchController.zoom = true
                
                -- 判断缩放方向（放大/缩小）
                local currentDist = Abs(touch1.position.y - touch2.position.y)
                local lastDist = Abs(touch1.lastPosition.y - touch2.lastPosition.y)
                local sens = (currentDist > lastDist) and -1 or 1
                
                -- 更新相机距离
                local deltaY = Abs(touch1.delta.y - touch2.delta.y)
                TouchController.cameraDistance = TouchController.cameraDistance + 
                    deltaY * sens * TouchController.config.touchSensitivity / 50
                
                -- 限制范围
                TouchController.cameraDistance = Clamp(
                    TouchController.cameraDistance,
                    TouchController.config.cameraMinDist,
                    TouchController.config.cameraMaxDist
                )
            end
        end
    end
    
    -- 陀螺仪控制（通过虚拟摇杆模拟）
    if TouchController.useGyroscope and controls and input.numJoysticks > 0 then
        local joystick = input:GetJoystickByIndex(0)
        if joystick and joystick.numAxes >= 2 then
            local threshold = TouchController.config.gyroscopeThreshold
            
            if joystick:GetAxisPosition(0) < -threshold then
                controls:Set(CTRL_LEFT, true)
            end
            if joystick:GetAxisPosition(0) > threshold then
                controls:Set(CTRL_RIGHT, true)
            end
            if joystick:GetAxisPosition(1) < -threshold then
                controls:Set(CTRL_FORWARD, true)
            end
            if joystick:GetAxisPosition(1) > threshold then
                controls:Set(CTRL_BACK, true)
            end
        end
    end
    
    return {
        zoom = TouchController.zoom,
        cameraDistance = TouchController.cameraDistance
    }
end

---获取当前相机距离
---@return number
function TouchController.GetCameraDistance()
    return TouchController.cameraDistance
end

---设置相机距离
---@param distance number
function TouchController.SetCameraDistance(distance)
    TouchController.cameraDistance = Clamp(
        distance,
        TouchController.config.cameraMinDist,
        TouchController.config.cameraMaxDist
    )
end

---是否正在缩放
---@return boolean
function TouchController.IsZooming()
    return TouchController.zoom
end

---启用/禁用陀螺仪
---@param enable boolean
function TouchController.SetGyroscopeEnabled(enable)
    TouchController.useGyroscope = enable
end

---重置相机距离到默认值
function TouchController.ResetCameraDistance()
    TouchController.cameraDistance = 5.0
end

return TouchController

