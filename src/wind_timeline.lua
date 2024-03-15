function widget:GetInfo()
	return {
		name = "Wind Timeline",
		desc = "Displays wind strength over time",
		author = "sneyed",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[-------------------------------------------------------------------

Widget description here

--]] -------------------------------------------------------------------

-- Config

--[[-------------------------------------------------------------------
Shouldn't need to edit past this point
--]] -------------------------------------------------------------------

-- Debugging
local logPrefix = "[WT]: "
local widgetName = "Wind Timeline"
local widgetSlug = "gui_wind_timeline"
local debugMode = false -- enable to print debugging messages to the console
-- Shader
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevboidtable.lua")
local shader

local vsSrc =
	[[
#version 420
#line 10000

//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 world_pos;
layout (location = 1) in vec4 color;

out DataVS {
  vec4 vertex_color;
};

void main()
{
    gl_Position = world_pos;
    vertex_color = color;
}
]]

local fsSrc =
	[[
#version 420
#line 20000

in DataVS {
  vec4 vertex_color;
};

out vec4 output_color;

#line 25000
void main() {
  output_color.rgba = vec4(1, 0, 0, 1));
}
]]

-- Prints a message to the console if debugMode is enabled
local function DebugLog(message)
	if debugMode then
		Spring.Echo(logPrefix .. tostring(message))
	end
end

-- Returns true if widget can run
local function CheckCompat()
	if not initGL4() then
		return false
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
	DebugLog(widgetName .. " widget enabled")
	if not CheckCompat() then
		widgetHandler:RemoveWidget()
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
	if shader then
		shader:Finalize()
	end
	DebugLog(widgetName .. " widget disabled")
end

local function initGL4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	shader = LuaShader(
		{
			vertex = vsSrc,
			fragment = fsSrc,
		},
		widgetSlug
	)
	local shaderCompiled = shader:Initialize()
	return shaderCompiled
end
