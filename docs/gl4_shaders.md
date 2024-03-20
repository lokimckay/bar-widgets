# Creating GL4 shader widgets

## Questions

- What is diff between VBOTable and VBOIDTable?

## Learnings

- pushElementInstance actually renders stuff
- the `noupload` option of pushElementInstance is used when batching lots of calls, you need to manually push later using `uploadAllElements(instanceVBO)`

## Terms

vsSrc = vertex shader source
fsSrc = fragment shader source
VBO = vertex buffer object
VFS = virtual file system

## References

- Beherith Tut - https://www.youtube.com/watch?v=hLAMZdN1lw4&ab_channel=beherith66

### Make instance VBO table

## Engine Buffer Defs

- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/LuaShader.lua#L56

### VBO

- https://beyond-all-reason.github.io/spring/ldoc/classes/VBO.html#
- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaVBO.html
- https://beyond-all-reason.github.io/spring/ldoc/classes/VBO.html#VBO:Define

- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevboidtable.lua
- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevbotable.lua

### Rest

- OpenGL docs - https://openframeworks.cc/documentation/gl/
  - https://openframeworks.cc//documentation/gl/ofVboMesh/#!show_getVbo
- PushElementInstance - https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevboidtable.lua#L200
- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/Include/instancevbotable.lua
- https://www.khronos.org/opengl/wiki/Layout_Qualifier_(GLSL)
- https://antongerdelan.net/opengl/shaders.html
- Commander Wrecks Widget - https://gist.github.com/salinecitrine/09701103e2a6e52a5f9db52c41eb83cf
- DrawUnitShape - https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/gfx_DrawUnitShape_GL4.lua
- Hot reloading - https://springrts.com/phpbb/viewtopic.php?p=603899
