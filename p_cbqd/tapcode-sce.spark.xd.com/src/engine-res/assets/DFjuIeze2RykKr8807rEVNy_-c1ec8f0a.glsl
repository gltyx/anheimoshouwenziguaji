#include "SSAORasterize/varying.def.sc"
$input a_position
$output v_texcoord0, v_screenPos

// Fullscreen quad vertex shader for SSAORasterize
// WebGL compatible

#include "Common/common.sh"

void main()
{
    vec4 worldPos = mul(a_position, u_model[0]);
    worldPos.w = 1.0;
    gl_Position = mul(mul(worldPos, u_view), u_proj);

    // Compute texture coordinates with platform-specific Y handling
    // D3D: UV.y=0 at top, so negate clipPos.y
    // OpenGL: UV.y=0 at bottom, so use clipPos.y directly
#if BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC
    v_texcoord0 = hvec2_init(
        gl_Position.x / gl_Position.w * 0.5 + 0.5,
        gl_Position.y / gl_Position.w * 0.5 + 0.5);
#else
    v_texcoord0 = hvec2_init(
        gl_Position.x / gl_Position.w * 0.5 + 0.5,
        -gl_Position.y / gl_Position.w * 0.5 + 0.5);
#endif

    // Screen position (normalized device coordinates)
    v_screenPos = gl_Position.xy / gl_Position.w;
}
