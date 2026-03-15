/*
 * HiZ Copy Shader
 * Copies separate HiZ generation RTs into the final mipmapped HiZ texture.
 * Uses MRT to copy both ClosestHiZ and FarthestHiZ in a single pass.
 *
 * Output 0: ClosestHiZ mip N
 * Output 1: FarthestHiZ mip N
 */

#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"

#ifdef COMPILEVS
    $input a_position
    $output vTexCoord, vScreenPos
#endif
#ifdef COMPILEPS
    $input vTexCoord, vScreenPos
#endif

#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS

// Source ClosestHiZ RT (register 0)
SAMPLER2D(u_Source0, 0);
// Source FarthestHiZ RT (register 1)
SAMPLER2D(u_Source1, 1);

void PS()
{
    vec2 uv = vTexCoord;
    // Use full precision (hvec4) for depth values
    gl_FragData[0] = hvec4_init(texture2D(u_Source0, uv).r, 0.0, 0.0, 1.0);
    gl_FragData[1] = hvec4_init(texture2D(u_Source1, uv).r, 0.0, 0.0, 1.0);
}

#endif
