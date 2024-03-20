function widget:GetInfo()
    return {
        name = "Screen Shader",
        desc = "Sample shader that draws animating circles on the screen",
        author = "sneyed",
        date = "2024",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

--[[-------------------------------------------------------------------

    # Screen Shader

    Sample shader that draws animating circles on the screen
    Meant as a introduction / reference for creating your first BAR shader widget.

    ## Useful references
        - https://www.youtube.com/watch?v=hLAMZdN1lw4&ab_channel=beherith66
        - https://www.youtube.com/watch?v=f4s1h2YETNY&t=718s&ab_channel=kishimisu
        - https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/LuaShader.lua

--]] -------------------------------------------------------------------

-- Shader
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevbotable.lua") -- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevbotable.lua
local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
local shader

-- Fragment shader
local fsSrc = [[
#version 420

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

out vec4 output_color;

void main() {
  #line 10000
  vec2 uv = (gl_FragCoord.xy * 2 - viewGeometry.xy) / viewGeometry.y;
  float distance = abs(length(uv));
  float frequency = 10.0;
  vec3 col = vec3(1.0, 0.0, 0.0);

  distance = sin(distance * frequency - timeInfo.y);
  distance = step(0.1, distance);

  col *= distance;
  output_color.rgba = vec4(col, 0.25);
}
]]

local function initGL4()
    local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
    fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs) -- 
    fsSrc = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString({}))
    shader = LuaShader({fragment = fsSrc}, "gfx_screen_shader")
    local shaderCompiled = shader:Initialize()
    return shaderCompiled
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
    Spring.Echo("Screen Shader enabled")
    if not initGL4() then widgetHandler:RemoveWidget() end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
    if shader then shader:Finalize() end
    Spring.Echo("Screen Shader disabled")
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#DrawScreen
function widget:DrawScreen()
    if Spring.IsGUIHidden() then return end
    if not shader then return end
    gl.UseShader(shader.shaderObj)
    gl.TexRect(0, vsy, vsx, 0)
    gl.UseShader(0)
end
