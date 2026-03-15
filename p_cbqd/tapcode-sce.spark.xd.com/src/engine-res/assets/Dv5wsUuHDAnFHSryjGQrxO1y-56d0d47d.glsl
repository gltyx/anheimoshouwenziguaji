/*
 * HiZ Initialize Shader (Mip 0)
 * Converts depth buffer to dual HiZ textures.
 * Output 0: ClosestHiZ - conservative closest depth
 * Output 1: FarthestHiZ - conservative farthest depth
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

// Depth buffer (register 0, matching RenderPath texture unit)
SAMPLER2D(u_Depth0, 0);

void PS()
{
    // Use full precision (hfloat) for depth to avoid fp16 quantization artifacts
    hfloat depth = texture2D(u_Depth0, vTexCoord).r;

    // For Mip 0, both closest and farthest are initialized to the same depth value
    // MRT output: gl_FragData[0] = ClosestHiZ, gl_FragData[1] = FarthestHiZ
    gl_FragData[0] = hvec4_init(depth, 0.0, 0.0, 1.0);
    gl_FragData[1] = hvec4_init(depth, 0.0, 0.0, 1.0);
}

#endif
