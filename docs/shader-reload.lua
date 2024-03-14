local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")

local vsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.frag.glsl"
local gsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.geom.glsl"

local lastshaderupdate = nil
local shaderSourceCache = {}
local function checkShaderUpdates(vssrcpath, fssrcpath, gssrcpath, shadername,
                                  delaytime)
    if lastshaderupdate == nil or
        Spring.DiffTimers(Spring.GetTimer(), lastshaderupdate) >
        (delaytime or 0.25) then
        lastshaderupdate = Spring.GetTimer()
        local vsSrcNew = vssrcpath and VFS.LoadFile(vssrcpath)
        local fsSrcNew = fssrcpath and VFS.LoadFile(fssrcpath)
        local gsSrcNew = gssrcpath and VFS.LoadFile(gssrcpath)
        if vsSrcNew == shaderSourceCache.vsSrc and fsSrcNew ==
            shaderSourceCache.fsSrc and gsSrcNew == shaderSourceCache.gsSrc then
            -- Spring.Echo("No change in shaders")
            return nil
        else
            local compilestarttime = Spring.GetTimer()
            shaderSourceCache.vsSrc = vsSrcNew
            shaderSourceCache.fsSrc = fsSrcNew
            shaderSourceCache.gsSrc = gsSrcNew

            local engineUniformBufferDefs =
                LuaShader.GetEngineUniformBufferDefs()
            if vsSrcNew then
                vsSrcNew = vsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__",
                                         engineUniformBufferDefs)
                vsSrcNew = vsSrcNew:gsub("//__DEFINES__",
                                         LuaShader.CreateShaderDefinesString(
                                             shaderConfig))
            end
            if fsSrcNew then
                fsSrcNew = fsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__",
                                         engineUniformBufferDefs)
                fsSrcNew = fsSrcNew:gsub("//__DEFINES__",
                                         LuaShader.CreateShaderDefinesString(
                                             shaderConfig))
            end
            if gsSrcNew then
                gsSrcNew = gsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__",
                                         engineUniformBufferDefs)
                gsSrcNew = gsSrcNew:gsub("//__DEFINES__",
                                         LuaShader.CreateShaderDefinesString(
                                             shaderConfig))
            end
            local reinitshader = LuaShader({
                vertex = vsSrcNew,
                fragment = fsSrcNew,
                geometry = gsSrcNew,
                uniformInt = {heightmapTex = 0, miniMapTex = 1},
                uniformFloat = {fadeDistance = 3000}
            }, shadername)
            local shaderCompiled = reinitshader:Initialize()

            Spring.Echo(shadername, " recompiled in ", Spring.DiffTimers(
                            Spring.GetTimer(), compilestarttime, true), "ms at",
                        Spring.GetGameFrame())
            if shaderCompiled then
                return reinitshader
            else
                return nil
            end
        end
    end
    return nil
end

function widget:Update()
    decalShader = checkShaderUpdates(vsSrcPath, fsSrcPath, gsSrcPath,
                                     "Decals GL4") or decalShader
end

function widget:Initialize()
    decalShader = checkShaderUpdates(vsSrcPath, fsSrcPath, gsSrcPath,
                                     "Decals GL4") or decalShader
end
