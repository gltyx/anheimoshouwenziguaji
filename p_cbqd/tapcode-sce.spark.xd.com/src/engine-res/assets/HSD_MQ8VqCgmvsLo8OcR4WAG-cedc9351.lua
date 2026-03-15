-- Primitives.lua
-- 基础几何体生成器（使用 CustomGeometry）
-- 提供半球、弧形、圆锥等引擎内置模型不支持的形状
--
-- 使用方式：
--   local Primitives = require "urhox-libs.Geometry.Primitives"
--   local geom = Primitives.Hemisphere(node, { radius = 0.5, isUpper = true })

---@class Primitives
local Primitives = {}

-- ============================================================================
-- 内部工具函数
-- ============================================================================

---球面坐标转笛卡尔坐标
---@param radius number 半径
---@param theta number 纬度角 (0 = 北极, π = 南极)
---@param phi number 经度角 (0 ~ 2π)
---@return Vector3
local function SpherePoint(radius, theta, phi)
    local x = radius * math.sin(theta) * math.cos(phi)
    local y = radius * math.cos(theta)
    local z = radius * math.sin(theta) * math.sin(phi)
    return Vector3(x, y, z)
end

---获取默认颜色
---@param color Color|nil 用户提供的颜色
---@param default Color 默认颜色
---@return Color
local function GetColor(color, default)
    if color then
        return color
    end
    return default or Color(1, 1, 1, 1)
end

---设置材质到 CustomGeometry
---@param geom CustomGeometry 几何体组件
---@param technique string 技术路径
local function SetDefaultMaterial(geom, technique)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", technique))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 1.0)))
    mat:SetShaderParameter("MatSpecColor", Variant(Color(0.3, 0.3, 0.3, 16.0)))
    geom:SetMaterial(mat)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

---创建半球几何体
---用于水果切割效果、穹顶、碗形等场景
---@param node Node 要附加几何体的节点
---@param options table|nil 配置选项 { radius, segments, rings, isUpper, outerColor, innerColor, technique }
---@return CustomGeometry|nil 创建的几何体组件
function Primitives.Hemisphere(node, options)
    if not node then
        log:Write(LOG_ERROR, "Primitives.Hemisphere: node is nil")
        return nil
    end

    options = options or {}
    local radius = options.radius or 0.5
    local segments = options.segments or 16
    local rings = options.rings or math.floor(segments / 2)
    local isUpper = options.isUpper
    if isUpper == nil then isUpper = true end
    local outerColor = GetColor(options.outerColor, Color(1, 1, 1, 1))
    local innerColor = GetColor(options.innerColor, Color(0.9, 0.9, 0.9, 1))
    local technique = options.technique or "Techniques/DiffVCol.xml"

    local geom = node:CreateComponent("CustomGeometry")
    geom:SetNumGeometries(1)
    geom:BeginGeometry(0, TRIANGLE_LIST)

    -- ========================================
    -- 生成半球外表面
    -- ========================================
    for ring = 0, rings - 1 do
        for seg = 0, segments - 1 do
            local theta1, theta2

            if isUpper then
                -- 上半球: theta 从 0 (北极) 到 π/2 (赤道)
                theta1 = ring * (math.pi / 2) / rings
                theta2 = (ring + 1) * (math.pi / 2) / rings
            else
                -- 下半球: theta 从 π/2 (赤道) 到 π (南极)
                theta1 = (math.pi / 2) + ring * (math.pi / 2) / rings
                theta2 = (math.pi / 2) + (ring + 1) * (math.pi / 2) / rings
            end

            local phi1 = seg * (2 * math.pi) / segments
            local phi2 = (seg + 1) * (2 * math.pi) / segments

            -- 计算四个顶点
            local p1 = SpherePoint(radius, theta1, phi1)
            local p2 = SpherePoint(radius, theta1, phi2)
            local p3 = SpherePoint(radius, theta2, phi1)
            local p4 = SpherePoint(radius, theta2, phi2)

            -- 第一个三角形 (p1 -> p3 -> p2)
            geom:DefineVertex(p1)
            geom:DefineNormal(p1:Normalized())
            geom:DefineColor(outerColor)

            geom:DefineVertex(p3)
            geom:DefineNormal(p3:Normalized())
            geom:DefineColor(outerColor)

            geom:DefineVertex(p2)
            geom:DefineNormal(p2:Normalized())
            geom:DefineColor(outerColor)

            -- 第二个三角形 (p2 -> p3 -> p4)
            geom:DefineVertex(p2)
            geom:DefineNormal(p2:Normalized())
            geom:DefineColor(outerColor)

            geom:DefineVertex(p3)
            geom:DefineNormal(p3:Normalized())
            geom:DefineColor(outerColor)

            geom:DefineVertex(p4)
            geom:DefineNormal(p4:Normalized())
            geom:DefineColor(outerColor)
        end
    end

    -- ========================================
    -- 生成切面 (圆形底面)
    -- ========================================
    local cutY = 0  -- 切面在 Y=0 处
    local cutNormal = isUpper and Vector3(0, -1, 0) or Vector3(0, 1, 0)

    for seg = 0, segments - 1 do
        local phi1 = seg * (2 * math.pi) / segments
        local phi2 = (seg + 1) * (2 * math.pi) / segments

        local center = Vector3(0, cutY, 0)
        local edge1 = Vector3(radius * math.cos(phi1), cutY, radius * math.sin(phi1))
        local edge2 = Vector3(radius * math.cos(phi2), cutY, radius * math.sin(phi2))

        -- 中心点
        geom:DefineVertex(center)
        geom:DefineNormal(cutNormal)
        geom:DefineColor(innerColor)

        -- 根据半球类型调整绕序
        if isUpper then
            geom:DefineVertex(edge2)
            geom:DefineNormal(cutNormal)
            geom:DefineColor(innerColor)

            geom:DefineVertex(edge1)
            geom:DefineNormal(cutNormal)
            geom:DefineColor(innerColor)
        else
            geom:DefineVertex(edge1)
            geom:DefineNormal(cutNormal)
            geom:DefineColor(innerColor)

            geom:DefineVertex(edge2)
            geom:DefineNormal(cutNormal)
            geom:DefineColor(innerColor)
        end
    end

    geom:Commit()

    -- 设置默认材质
    SetDefaultMaterial(geom, technique)

    return geom
end

---创建弧形/扇形几何体
---用于扇形菜单、饼图、弧形墙壁等场景
---@param node Node 要附加几何体的节点
---@param options table|nil 配置选项 { innerRadius, outerRadius, startAngle, endAngle, height, segments, color, technique }
---@return CustomGeometry|nil
function Primitives.Arc(node, options)
    if not node then
        log:Write(LOG_ERROR, "Primitives.Arc: node is nil")
        return nil
    end

    options = options or {}
    local innerRadius = options.innerRadius or 0
    local outerRadius = options.outerRadius or 1.0
    local startAngle = math.rad(options.startAngle or 0)
    local endAngle = math.rad(options.endAngle or 90)
    local height = options.height or 0.1
    local segments = options.segments or 16
    local color = GetColor(options.color, Color(1, 1, 1, 1))
    local technique = options.technique or "Techniques/DiffVCol.xml"

    local geom = node:CreateComponent("CustomGeometry")
    geom:SetNumGeometries(1)
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local halfHeight = height / 2
    local angleStep = (endAngle - startAngle) / segments

    -- 生成顶面和底面
    for face = 0, 1 do
        local y = face == 0 and halfHeight or -halfHeight
        local normal = face == 0 and Vector3(0, 1, 0) or Vector3(0, -1, 0)

        for i = 0, segments - 1 do
            local angle1 = startAngle + i * angleStep
            local angle2 = startAngle + (i + 1) * angleStep

            local outerX1 = outerRadius * math.cos(angle1)
            local outerZ1 = outerRadius * math.sin(angle1)
            local outerX2 = outerRadius * math.cos(angle2)
            local outerZ2 = outerRadius * math.sin(angle2)

            if innerRadius > 0 then
                -- 环形弧: 画四边形
                local innerX1 = innerRadius * math.cos(angle1)
                local innerZ1 = innerRadius * math.sin(angle1)
                local innerX2 = innerRadius * math.cos(angle2)
                local innerZ2 = innerRadius * math.sin(angle2)

                -- 两个三角形组成四边形
                if face == 0 then
                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX2, y, innerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                else
                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX2, y, innerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                end
            else
                -- 扇形: 从中心点画三角形
                if face == 0 then
                    geom:DefineVertex(Vector3(0, y, 0))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                else
                    geom:DefineVertex(Vector3(0, y, 0))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                end
            end
        end
    end

    -- 生成外侧面
    for i = 0, segments - 1 do
        local angle1 = startAngle + i * angleStep
        local angle2 = startAngle + (i + 1) * angleStep

        local x1 = outerRadius * math.cos(angle1)
        local z1 = outerRadius * math.sin(angle1)
        local x2 = outerRadius * math.cos(angle2)
        local z2 = outerRadius * math.sin(angle2)

        local normal1 = Vector3(math.cos(angle1), 0, math.sin(angle1))
        local normal2 = Vector3(math.cos(angle2), 0, math.sin(angle2))

        -- 外侧面四边形
        geom:DefineVertex(Vector3(x1, halfHeight, z1))
        geom:DefineNormal(normal1)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x1, -halfHeight, z1))
        geom:DefineNormal(normal1)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x2, -halfHeight, z2))
        geom:DefineNormal(normal2)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x1, halfHeight, z1))
        geom:DefineNormal(normal1)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x2, -halfHeight, z2))
        geom:DefineNormal(normal2)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x2, halfHeight, z2))
        geom:DefineNormal(normal2)
        geom:DefineColor(color)
    end

    -- 生成两端封面 (起始角和结束角)
    local function AddEndCap(angle, flipNormal)
        local cos_a = math.cos(angle)
        local sin_a = math.sin(angle)
        local normal = Vector3(sin_a * (flipNormal and 1 or -1), 0, cos_a * (flipNormal and -1 or 1))

        local outerX = outerRadius * cos_a
        local outerZ = outerRadius * sin_a

        if innerRadius > 0 then
            local innerX = innerRadius * cos_a
            local innerZ = innerRadius * sin_a

            if flipNormal then
                geom:DefineVertex(Vector3(innerX, halfHeight, innerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(innerX, halfHeight, innerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(innerX, -halfHeight, innerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)
            else
                geom:DefineVertex(Vector3(innerX, halfHeight, innerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(innerX, halfHeight, innerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(innerX, -halfHeight, innerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)
            end
        else
            -- 扇形端面 (从中心到外边)
            if flipNormal then
                geom:DefineVertex(Vector3(0, halfHeight, 0))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(0, halfHeight, 0))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(0, -halfHeight, 0))
                geom:DefineNormal(normal)
                geom:DefineColor(color)
            else
                geom:DefineVertex(Vector3(0, halfHeight, 0))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(0, halfHeight, 0))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(0, -halfHeight, 0))
                geom:DefineNormal(normal)
                geom:DefineColor(color)

                geom:DefineVertex(Vector3(outerX, -halfHeight, outerZ))
                geom:DefineNormal(normal)
                geom:DefineColor(color)
            end
        end
    end

    AddEndCap(startAngle, false)
    AddEndCap(endAngle, true)

    geom:Commit()
    SetDefaultMaterial(geom, technique)

    return geom
end

---创建圆台/圆锥几何体
---用于圆锥、截锥、漏斗等场景
---@param node Node 要附加几何体的节点
---@param options table|nil 配置选项 { bottomRadius, topRadius, height, segments, color, capTop, capBottom, technique }
---@return CustomGeometry|nil
function Primitives.Cone(node, options)
    if not node then
        log:Write(LOG_ERROR, "Primitives.Cone: node is nil")
        return nil
    end

    options = options or {}
    local bottomRadius = options.bottomRadius or 0.5
    local topRadius = options.topRadius or 0
    local height = options.height or 1.0
    local segments = options.segments or 16
    local color = GetColor(options.color, Color(1, 1, 1, 1))
    local capTop = options.capTop
    local capBottom = options.capBottom
    if capTop == nil then capTop = true end
    if capBottom == nil then capBottom = true end
    local technique = options.technique or "Techniques/DiffVCol.xml"

    local geom = node:CreateComponent("CustomGeometry")
    geom:SetNumGeometries(1)
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local halfHeight = height / 2
    local angleStep = (2 * math.pi) / segments

    -- 计算侧面法线的倾斜角
    local slopeAngle = math.atan2(bottomRadius - topRadius, height)
    local normalY = math.sin(slopeAngle)
    local normalScale = math.cos(slopeAngle)

    -- 生成侧面
    for i = 0, segments - 1 do
        local angle1 = i * angleStep
        local angle2 = (i + 1) * angleStep

        local cos1 = math.cos(angle1)
        local sin1 = math.sin(angle1)
        local cos2 = math.cos(angle2)
        local sin2 = math.sin(angle2)

        -- 四个顶点
        local p1 = Vector3(bottomRadius * cos1, -halfHeight, bottomRadius * sin1)
        local p2 = Vector3(bottomRadius * cos2, -halfHeight, bottomRadius * sin2)
        local p3 = Vector3(topRadius * cos1, halfHeight, topRadius * sin1)
        local p4 = Vector3(topRadius * cos2, halfHeight, topRadius * sin2)

        -- 法线
        local n1 = Vector3(cos1 * normalScale, normalY, sin1 * normalScale):Normalized()
        local n2 = Vector3(cos2 * normalScale, normalY, sin2 * normalScale):Normalized()

        if topRadius > 0 then
            -- 圆台: 两个三角形
            geom:DefineVertex(p1)
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(p2)
            geom:DefineNormal(n2)
            geom:DefineColor(color)

            geom:DefineVertex(p3)
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(p3)
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(p2)
            geom:DefineNormal(n2)
            geom:DefineColor(color)

            geom:DefineVertex(p4)
            geom:DefineNormal(n2)
            geom:DefineColor(color)
        else
            -- 圆锥: 只需一个三角形
            local apex = Vector3(0, halfHeight, 0)
            local apexNormal = Vector3(0, 1, 0)  -- 顶点法线向上

            geom:DefineVertex(p1)
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(p2)
            geom:DefineNormal(n2)
            geom:DefineColor(color)

            geom:DefineVertex(apex)
            geom:DefineNormal(apexNormal)
            geom:DefineColor(color)
        end
    end

    -- 生成底面
    if capBottom and bottomRadius > 0 then
        local normal = Vector3(0, -1, 0)
        for i = 0, segments - 1 do
            local angle1 = i * angleStep
            local angle2 = (i + 1) * angleStep

            geom:DefineVertex(Vector3(0, -halfHeight, 0))
            geom:DefineNormal(normal)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(bottomRadius * math.cos(angle2), -halfHeight, bottomRadius * math.sin(angle2)))
            geom:DefineNormal(normal)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(bottomRadius * math.cos(angle1), -halfHeight, bottomRadius * math.sin(angle1)))
            geom:DefineNormal(normal)
            geom:DefineColor(color)
        end
    end

    -- 生成顶面
    if capTop and topRadius > 0 then
        local normal = Vector3(0, 1, 0)
        for i = 0, segments - 1 do
            local angle1 = i * angleStep
            local angle2 = (i + 1) * angleStep

            geom:DefineVertex(Vector3(0, halfHeight, 0))
            geom:DefineNormal(normal)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(topRadius * math.cos(angle1), halfHeight, topRadius * math.sin(angle1)))
            geom:DefineNormal(normal)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(topRadius * math.cos(angle2), halfHeight, topRadius * math.sin(angle2)))
            geom:DefineNormal(normal)
            geom:DefineColor(color)
        end
    end

    geom:Commit()
    SetDefaultMaterial(geom, technique)

    return geom
end

---创建圆环/甜甜圈几何体
---用于甜甜圈、轮胎、管道接头等场景
---@param node Node 要附加几何体的节点
---@param options table|nil 配置选项 { majorRadius, minorRadius, majorSegments, minorSegments, color, technique }
---@return CustomGeometry|nil
function Primitives.Torus(node, options)
    if not node then
        log:Write(LOG_ERROR, "Primitives.Torus: node is nil")
        return nil
    end

    options = options or {}
    local majorRadius = options.majorRadius or 0.5
    local minorRadius = options.minorRadius or 0.2
    local majorSegments = options.majorSegments or 24
    local minorSegments = options.minorSegments or 12
    local color = GetColor(options.color, Color(1, 1, 1, 1))
    local technique = options.technique or "Techniques/DiffVCol.xml"

    local geom = node:CreateComponent("CustomGeometry")
    geom:SetNumGeometries(1)
    geom:BeginGeometry(0, TRIANGLE_LIST)

    for i = 0, majorSegments - 1 do
        local theta1 = i * (2 * math.pi) / majorSegments
        local theta2 = (i + 1) * (2 * math.pi) / majorSegments

        local cos_t1 = math.cos(theta1)
        local sin_t1 = math.sin(theta1)
        local cos_t2 = math.cos(theta2)
        local sin_t2 = math.sin(theta2)

        for j = 0, minorSegments - 1 do
            local phi1 = j * (2 * math.pi) / minorSegments
            local phi2 = (j + 1) * (2 * math.pi) / minorSegments

            local cos_p1 = math.cos(phi1)
            local sin_p1 = math.sin(phi1)
            local cos_p2 = math.cos(phi2)
            local sin_p2 = math.sin(phi2)

            -- 计算四个顶点
            local function TorusPoint(cos_t, sin_t, cos_p, sin_p)
                local x = (majorRadius + minorRadius * cos_p) * cos_t
                local y = minorRadius * sin_p
                local z = (majorRadius + minorRadius * cos_p) * sin_t
                return Vector3(x, y, z)
            end

            local function TorusNormal(cos_t, sin_t, cos_p, sin_p)
                local x = cos_p * cos_t
                local y = sin_p
                local z = cos_p * sin_t
                return Vector3(x, y, z):Normalized()
            end

            local p1 = TorusPoint(cos_t1, sin_t1, cos_p1, sin_p1)
            local p2 = TorusPoint(cos_t2, sin_t2, cos_p1, sin_p1)
            local p3 = TorusPoint(cos_t1, sin_t1, cos_p2, sin_p2)
            local p4 = TorusPoint(cos_t2, sin_t2, cos_p2, sin_p2)

            local n1 = TorusNormal(cos_t1, sin_t1, cos_p1, sin_p1)
            local n2 = TorusNormal(cos_t2, sin_t2, cos_p1, sin_p1)
            local n3 = TorusNormal(cos_t1, sin_t1, cos_p2, sin_p2)
            local n4 = TorusNormal(cos_t2, sin_t2, cos_p2, sin_p2)

            -- 第一个三角形
            geom:DefineVertex(p1)
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(p2)
            geom:DefineNormal(n2)
            geom:DefineColor(color)

            geom:DefineVertex(p3)
            geom:DefineNormal(n3)
            geom:DefineColor(color)

            -- 第二个三角形
            geom:DefineVertex(p3)
            geom:DefineNormal(n3)
            geom:DefineColor(color)

            geom:DefineVertex(p2)
            geom:DefineNormal(n2)
            geom:DefineColor(color)

            geom:DefineVertex(p4)
            geom:DefineNormal(n4)
            geom:DefineColor(color)
        end
    end

    geom:Commit()
    SetDefaultMaterial(geom, technique)

    return geom
end

---创建圆盘几何体
---用于硬币、按钮、盖子等扁平圆形物体
---@param node Node 要附加几何体的节点
---@param options table|nil 配置选项 { radius, innerRadius, height, segments, color, technique }
---@return CustomGeometry|nil
function Primitives.Disc(node, options)
    if not node then
        log:Write(LOG_ERROR, "Primitives.Disc: node is nil")
        return nil
    end

    options = options or {}
    local radius = options.radius or 0.5
    local innerRadius = options.innerRadius or 0
    local height = options.height or 0.05
    local segments = options.segments or 24
    local color = GetColor(options.color, Color(1, 1, 1, 1))
    local technique = options.technique or "Techniques/DiffVCol.xml"

    local geom = node:CreateComponent("CustomGeometry")
    geom:SetNumGeometries(1)
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local halfHeight = height / 2
    local angleStep = (2 * math.pi) / segments

    -- 顶面和底面
    for face = 0, 1 do
        local y = face == 0 and halfHeight or -halfHeight
        local normal = face == 0 and Vector3(0, 1, 0) or Vector3(0, -1, 0)

        for i = 0, segments - 1 do
            local angle1 = i * angleStep
            local angle2 = (i + 1) * angleStep

            local outerX1 = radius * math.cos(angle1)
            local outerZ1 = radius * math.sin(angle1)
            local outerX2 = radius * math.cos(angle2)
            local outerZ2 = radius * math.sin(angle2)

            if innerRadius > 0 then
                -- 环形
                local innerX1 = innerRadius * math.cos(angle1)
                local innerZ1 = innerRadius * math.sin(angle1)
                local innerX2 = innerRadius * math.cos(angle2)
                local innerZ2 = innerRadius * math.sin(angle2)

                if face == 0 then
                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX2, y, innerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                else
                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX1, y, innerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(innerX2, y, innerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                end
            else
                -- 实心圆盘
                if face == 0 then
                    geom:DefineVertex(Vector3(0, y, 0))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                else
                    geom:DefineVertex(Vector3(0, y, 0))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX2, y, outerZ2))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)

                    geom:DefineVertex(Vector3(outerX1, y, outerZ1))
                    geom:DefineNormal(normal)
                    geom:DefineColor(color)
                end
            end
        end
    end

    -- 外侧面
    for i = 0, segments - 1 do
        local angle1 = i * angleStep
        local angle2 = (i + 1) * angleStep

        local x1 = radius * math.cos(angle1)
        local z1 = radius * math.sin(angle1)
        local x2 = radius * math.cos(angle2)
        local z2 = radius * math.sin(angle2)

        local n1 = Vector3(math.cos(angle1), 0, math.sin(angle1))
        local n2 = Vector3(math.cos(angle2), 0, math.sin(angle2))

        geom:DefineVertex(Vector3(x1, halfHeight, z1))
        geom:DefineNormal(n1)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x1, -halfHeight, z1))
        geom:DefineNormal(n1)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x2, -halfHeight, z2))
        geom:DefineNormal(n2)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x1, halfHeight, z1))
        geom:DefineNormal(n1)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x2, -halfHeight, z2))
        geom:DefineNormal(n2)
        geom:DefineColor(color)

        geom:DefineVertex(Vector3(x2, halfHeight, z2))
        geom:DefineNormal(n2)
        geom:DefineColor(color)
    end

    -- 内侧面（如果有内半径）
    if innerRadius > 0 then
        for i = 0, segments - 1 do
            local angle1 = i * angleStep
            local angle2 = (i + 1) * angleStep

            local x1 = innerRadius * math.cos(angle1)
            local z1 = innerRadius * math.sin(angle1)
            local x2 = innerRadius * math.cos(angle2)
            local z2 = innerRadius * math.sin(angle2)

            local n1 = Vector3(-math.cos(angle1), 0, -math.sin(angle1))
            local n2 = Vector3(-math.cos(angle2), 0, -math.sin(angle2))

            geom:DefineVertex(Vector3(x1, halfHeight, z1))
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(x2, -halfHeight, z2))
            geom:DefineNormal(n2)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(x1, -halfHeight, z1))
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(x1, halfHeight, z1))
            geom:DefineNormal(n1)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(x2, halfHeight, z2))
            geom:DefineNormal(n2)
            geom:DefineColor(color)

            geom:DefineVertex(Vector3(x2, -halfHeight, z2))
            geom:DefineNormal(n2)
            geom:DefineColor(color)
        end
    end

    geom:Commit()
    SetDefaultMaterial(geom, technique)

    return geom
end

return Primitives

