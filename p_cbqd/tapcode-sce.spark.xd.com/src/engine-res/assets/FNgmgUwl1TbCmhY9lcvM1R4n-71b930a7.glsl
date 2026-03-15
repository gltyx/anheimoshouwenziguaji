/*
 * HiZ Downsample Shader
 * Generates hierarchical depth buffer by downsampling previous mip level.
 * Uses 2x2 sampling with min/max operations for conservative bounds.
 *
 * Reads from separate source RT (single mip), writes to next level RT.
 *
 * Output 0: ClosestHiZ - min of 4 samples (standard Z) or max (reversed Z)
 * Output 1: FarthestHiZ - max of 4 samples (standard Z) or min (reversed Z)
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
SAMPLER2D(u_ClosestHiZ0, 0);
// Source FarthestHiZ RT (register 1)
SAMPLER2D(u_FarthestHiZ1, 1);

void PS()
{
    vec2 uv = vTexCoord;
    // cGBufferInvSize is output RT's invSize
    // Input RT is 2x larger, so input texelSize = output invSize * 0.5
    vec2 texelSize = cGBufferInvSize * 0.5;

    // Use full precision (hfloat/hvec4) for depth — fp16 causes quantization stripes
    hvec4 closestSamples;
    closestSamples.x = texture2D(u_ClosestHiZ0, uv + vec2(-0.25, -0.25) * texelSize).r;
    closestSamples.y = texture2D(u_ClosestHiZ0, uv + vec2( 0.25, -0.25) * texelSize).r;
    closestSamples.z = texture2D(u_ClosestHiZ0, uv + vec2(-0.25,  0.25) * texelSize).r;
    closestSamples.w = texture2D(u_ClosestHiZ0, uv + vec2( 0.25,  0.25) * texelSize).r;

    hvec4 farthestSamples;
    farthestSamples.x = texture2D(u_FarthestHiZ1, uv + vec2(-0.25, -0.25) * texelSize).r;
    farthestSamples.y = texture2D(u_FarthestHiZ1, uv + vec2( 0.25, -0.25) * texelSize).r;
    farthestSamples.z = texture2D(u_FarthestHiZ1, uv + vec2(-0.25,  0.25) * texelSize).r;
    farthestSamples.w = texture2D(u_FarthestHiZ1, uv + vec2( 0.25,  0.25) * texelSize).r;

    hfloat closest;
    hfloat farthest;

#ifdef REVERSED_Z
    // Reversed-Z: near = 1.0, far = 0.0
    closest = max(max(closestSamples.x, closestSamples.y),
                  max(closestSamples.z, closestSamples.w));
    farthest = min(min(farthestSamples.x, farthestSamples.y),
                   min(farthestSamples.z, farthestSamples.w));
#else
    // Standard Z: near = 0.0, far = 1.0
    closest = min(min(closestSamples.x, closestSamples.y),
                  min(closestSamples.z, closestSamples.w));
    farthest = max(max(farthestSamples.x, farthestSamples.y),
                   max(farthestSamples.z, farthestSamples.w));
#endif

    // MRT output
    gl_FragData[0] = hvec4_init(closest, 0.0, 0.0, 1.0);
    gl_FragData[1] = hvec4_init(farthest, 0.0, 0.0, 1.0);
}

#endif
