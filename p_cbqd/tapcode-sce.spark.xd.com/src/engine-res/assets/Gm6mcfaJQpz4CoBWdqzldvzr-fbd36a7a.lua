-- LuaScripts/Utilities/Previews/SceneGuard.lua
-- Scene-related guards and error prevention

-- Scene-level singleton components (only one per Scene allowed)
local SINGLETON_COMPONENTS = {
    PhysicsWorld = true,
    PhysicsWorld2D = true,
    Octree = true,
    DebugRenderer = true,
}

-- Hook CreateComponent/AddComponent to prevent multiple singleton components per Scene
-- Use rawset to bypass __newindex metamethod which causes recursion in tolua++
-- Prefer Scene's own method, fallback to Node's method
local Original_CreateComponent = Scene.CreateComponent or Node.CreateComponent
local Original_AddComponent = Scene.AddComponent or Node.AddComponent

rawset(Scene, 'CreateComponent', function(self, typeName, mode, id)
    if SINGLETON_COMPONENTS[typeName] then
        local existing = self:GetComponent(typeName)
        if existing then
            error("Scene already has a " .. typeName .. " component. Multiple " .. typeName .. "s per Scene is not supported.", 2)
        end
    end
    return Original_CreateComponent(self, typeName, mode or REPLICATED, id or 0)
end)

rawset(Scene, 'AddComponent', function(self, component, id, mode)
    local typeName = component:GetTypeName()
    if SINGLETON_COMPONENTS[typeName] then
        local existing = self:GetComponent(typeName)
        if existing and existing ~= component then
            error("Scene already has a " .. typeName .. " component. Multiple " .. typeName .. "s per Scene is not supported.", 2)
        end
    end
    return Original_AddComponent(self, component, id, mode)
end)
