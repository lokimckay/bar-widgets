function widget:GetInfo()
    return {
        name = "Unit Shader",
        desc = "Sample shader that draws a pawn at mouse click position",
        author = "sneyed",
        date = "2024",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

--[[-------------------------------------------------------------------

    # Unit Shader

    Sample shader that draws a pawn at mouse click position.
    Meant as a introduction / reference for creating your first BAR shader widgets.

    ## Useful references
        - https://www.youtube.com/watch?v=hLAMZdN1lw4&ab_channel=beherith66
        - https://www.youtube.com/watch?v=f4s1h2YETNY&t=718s&ab_channel=kishimisu
        - https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/LuaShader.lua
        - https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/gfx_DrawUnitShape_GL4.lua

--]] -------------------------------------------------------------------

-- Shader
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevboidtable.lua") -- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevboidtable.lua
local shader

-- Instance VBO table
local iT
local iTConfig = {
    SKINSUPPORT = Script.IsEngineMinVersion(105, 0, 1653) and 1 or 0
}
local iTLayout = {
    {id = 6, name = "worldposrot", size = 4},
    {id = 7, name = "parameters", size = 4},
    {id = 8, name = "overrideteam", type = GL.UNSIGNED_INT, size = 2},
    {id = 9, name = "instData", type = GL.UNSIGNED_INT, size = 4}
}

-- Vars
local widgetSlug = "gfx_unit_shader"
local pawnId = UnitDefNames["armpw"].id
local pawnIds = {}

-- Vertex shader
local vsSrc = [[
#version 420
#extension GL_ARB_shader_storage_buffer_object : require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;
#if (SKINSUPPORT == 0)
  layout (location = 5) in uint pieceIndex;
#else
  layout (location = 5) in uvec2 bonesInfo; //boneIDs, boneWeights
  #define pieceIndex (bonesInfo.x & 0x000000FFu)
#endif
layout (location = 6) in vec4 worldposrot;
layout (location = 7) in vec4 parameters; // x = alpha, y = isstatic, z = globalteamcoloramount, w = selectionanimation
layout (location = 8) in uvec2 overrideteam; // x = override teamcolor if < 256
layout (location = 9) in uvec4 instData;

#line 15000
layout(std140, binding=0) buffer MatrixBuffer {
  mat4 mat[];
};

out vec2 v_uv;
out vec4 v_parameters;
out vec4 myTeamColor;
out vec3 worldPos;

void main() {
  uint baseIndex = instData.x;

  // dynamic models have one extra matrix, as their first matrix is their world pos/offset
  mat4 modelMatrix = mat[baseIndex];
  uint isDynamic = 1u; //default dynamic model
  if (parameters.y > 0.5) isDynamic = 0u;  //if paramy == 1 then the unit is static
  mat4 pieceMatrix = mat[baseIndex + pieceIndex + isDynamic];

  vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);

  // Make the rotation matrix around Y and rotate the model
  mat3 rotY = rotation3dY(worldposrot.w);
  localModelPos.xyz = rotY * localModelPos.xyz;

  vec4 worldModelPos = localModelPos;
  if (parameters.y < 0.5) worldModelPos = modelMatrix*localModelPos;
  worldModelPos.xyz += worldposrot.xyz; //Place it in the world

  uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
  if (overrideteam.x < 255u) teamIndex = overrideteam.x;

  myTeamColor = vec4(teamColor[teamIndex].rgb, parameters.x); // pass alpha through

  v_parameters = parameters;
  v_uv = uv.xy;
  worldPos = worldModelPos.xyz;
  gl_Position = cameraViewProj * worldModelPos;
}
]]

-- Fragment Shader
local fsSrc = [[
#version 420

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform sampler2D tex1;
uniform sampler2D tex2;

in vec2 v_uv;
in vec4 v_parameters; // x = alpha, y = isstatic, z = globalteamcoloramount, w = selectionanimation
in vec4 myTeamColor;
in vec3 worldPos;

out vec4 fragColor;

#line 25000
void main() {
  vec4 modelColor = texture(tex1, v_uv.xy);
  vec4 extraColor = texture(tex2, v_uv.xy);
  modelColor += modelColor * extraColor.r; // emission
  modelColor.a *= extraColor.a; // basic model transparency
  modelColor.rgb = mix(modelColor.rgb, myTeamColor.rgb, modelColor.a); // apply teamcolor

  modelColor.a *= myTeamColor.a; // shader define transparency
  modelColor.rgb = mix(modelColor.rgb, myTeamColor.rgb, v_parameters.z); //globalteamcoloramount override
  if (v_parameters.w > 0){
    modelColor.rgb = mix(modelColor.rgb, vec3(1.0), v_parameters.w * fract(worldPos.y * 0.03 + (timeInfo.x + timeInfo.w) * 0.05));
  }

  fragColor = vec4(modelColor.rgb, myTeamColor.a);
}
]]

local function makeInstanceVBO()
    local vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
    local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
    vertexVBO:ModelsVBO()
    indexVBO:ModelsVBO()

    local instDataSlot = 9
    iT = makeInstanceVBOTable(iTLayout, nil, widgetSlug, instDataSlot,
                              "unitDefID") -- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevboidtable.lua
    iT.VAO = makeVAOandAttach(vertexVBO, iT.instanceVBO, indexVBO) -- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevboidtable.lua#L78
    iT.indexVBO = indexVBO
    iT.vertexVBO = vertexVBO
end

local function initGL4()
    if not gl.CreateShader then return false end
    makeInstanceVBO()

    local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
    fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs) -- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/LuaShader.lua#L56
    vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
    fsSrc = fsSrc:gsub("//__DEFINES__",
                       LuaShader.CreateShaderDefinesString(iTConfig))
    vsSrc = vsSrc:gsub("//__DEFINES__",
                       LuaShader.CreateShaderDefinesString(iTConfig))

    shader = LuaShader({
        vertex = vsSrc,
        fragment = fsSrc,
        uniformInt = {tex1 = 0, tex2 = 1}
    }, widgetSlug)
    local shaderCompiled = shader:Initialize()
    return shaderCompiled
end

local function AddPawn(id, px, pz)
    local py = Spring.GetGroundHeight(px, pz)
    local rotY = 0
    local alpha = 1
    local isStatic = 1
    local teamColor = 0
    local highlight = 0
    local teamID = 256
    -- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevboidtable.lua#L200
    pushElementInstance(iT, {
        px, py, pz, rotY, alpha, isStatic, teamColor, highlight, teamID, 0, 0,
        0, 0, 0
    }, id, true, nil, pawnId, "unitDefID")
end

local function RemovePawn(id) popElementInstance(iT, id, true) end -- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevboidtable.lua#L285
local function RemoveAllPawns() for i = 1, #pawnIds do RemovePawn(pawnIds[i]) end end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
    Spring.Echo("Unit Shader enabled")
    if not initGL4() then widgetHandler:RemoveWidget() end
    local mousePos = {Spring.GetMouseState()}
    AddPawn(pawnIds[#pawnIds + 1], mousePos[1], mousePos[2])
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#MousePress
function widget:MousePress(x, y)
    if (iT.usedElements > 0) then
        local desc, args = Spring.TraceScreenRay(x, y, true) -- https://springrts.com/wiki/Lua_UnsyncedRead#TraceScreenRay
        if desc == nil then return end
        local px, py, pz = args[1], args[2], args[3]
        AddPawn(pawnIds[#pawnIds + 1], px, pz)
    end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
    RemoveAllPawns()
    if iT and iT.VAO then iT.VAO:Delete() end
    if shader then shader:Finalize() end
    Spring.Echo("Unit Shader disabled")
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#DrawWorld
function widget:DrawWorld()
    if (iT.usedElements > 0) then
        gl.Culling(GL.BACK)
        gl.DepthMask(true)
        gl.DepthTest(GL.LEQUAL)
        shader:Activate()
        gl.UnitShapeTextures(pawnId, true)
        iT.VAO:Submit()
        shader:Deactivate()
        gl.UnitShapeTextures(pawnId, false)
        gl.Culling(false)
        gl.DepthMask(false)
        gl.DepthTest(false)
    end
end
