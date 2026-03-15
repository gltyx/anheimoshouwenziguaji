/*
 * SSR HiZ Trace Shader
 * Performs screen-space ray marching accelerated by Hierarchical-Z buffer.
 *
 * Algorithm: AMD FidelityFX SSSR (ffx_sssr.h) cell traversal, adapted for
 * HALF-RESOLUTION tracing via mip bias.
 *
 * Reference: https://github.com/GPUOpen-Effects/FidelityFX-SSSR
 *            ffx_sssr.h (InitialAdvanceRay, AdvanceRay, HierarchicalRaymarch)
 *            sample/src/Shaders/Intersect.hlsl (caller, mostDetailedMip logic)
 *
 * Half-resolution adaptation:
 *   SSR runs at sizedivisor="2 2", so HiZ mip 0 (full-res) doesn't align with
 *   the SSR pixel grid. We add HIZ_MIP_BIAS=1 to all HiZ texture samples, making
 *   mip 1 (= half-res = SSR resolution) the effective base level. The algorithm
 *   logic (cell traversal, mip up/down, exit condition) is UNCHANGED from FidelityFX.
 *   screenSize = 1/cGBufferInvSize = SSR resolution, matching the biased mip grid.
 *
 * Combined with stochastic GGX importance sampling (same as SSRLinearTrace).
 * Each pixel traces ONE ray per frame; temporal filter accumulates results.
 *
 * Output:
 *   RGB = Reflected color (pre-multiplied by confidence)
 *   A   = Confidence (0 = no hit/use IBL fallback, 1 = perfect hit)
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
#include "ScreenSpace/SSR/SSRCommon.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS

// Depth buffer (register 0)
SAMPLER2D(u_Depth0, 0);

// GBufferA - normal (register 1)
SAMPLER2D(u_Normal1, 1);

// GBufferB - metallic, specular, roughness (register 2)
SAMPLER2D(u_GBufferB2, 2);

// ClosestHiZ mipmapped texture (register 3)
SAMPLER2D(u_ClosestHiZ3, 3);

// Scene lighting: direct_all + IBL_diffuse (register 5)
SAMPLER2D(u_SceneLighting5, 5);

// Render path parameters
uniform hfloat u_MaxDistance;
uniform hfloat u_MaxSteps;
uniform hfloat u_Thickness;
uniform hfloat u_FrameIndex;

#define MAX_ROUGHNESS_FOR_SSR 0.5
#define MIN_SSR_ROUGHNESS 0.014

// HiZ mip bias: shift all HiZ samples by +1 mip so that the effective base
// level matches SSR half-resolution. See design doc for derivation.
#define HIZ_MIP_BIAS 1

// Maximum LOGICAL mip level (physical mip = logical + HIZ_MIP_BIAS).
// HiZ has 5 physical levels (0-4). With bias=1, logical range is 0-3.
#define MAX_MIP 3

// FidelityFX constants
#define HIZ_CROSS_EPSILON 0.005
#define FFX_FLOAT_MAX 3.402823466e+38

hfloat SampleLinearDepth(hvec2 uv)
{
    hfloat rawDepth = texture2D(u_Depth0, uv).r;
    return LinearizeDepth(rawDepth, cNearClipPS, cFarClipPS);
}

// ============================================================
// FidelityFX SSSR: InitialAdvanceRay
// Reference: FFX_SSSR_InitialAdvanceRay in ffx_sssr.h
// UNCHANGED from original — operates on logical mip coordinates.
// ============================================================
void InitialAdvanceRay(hvec3 origin, hvec3 direction, hvec3 invDirection,
                       hvec2 currentMipResolution, hvec2 currentMipResolutionInv,
                       hvec2 floorOffset, hvec2 uvOffset,
                       out hvec3 position, out hfloat currentT)
{
    hvec2 currentMipPosition = currentMipResolution * origin.xy;

    hvec2 xyPlane = floor(currentMipPosition) + floorOffset;
    xyPlane = xyPlane * currentMipResolutionInv + uvOffset;

    hvec2 t = (xyPlane - origin.xy) * invDirection.xy;
    currentT = min(t.x, t.y);
    position = origin + currentT * direction;
}

// ============================================================
// FidelityFX SSSR: AdvanceRay
// Reference: FFX_SSSR_AdvanceRay in ffx_sssr.h
// UNCHANGED from original.
// ============================================================
bool AdvanceRay(hvec3 origin, hvec3 direction, hvec3 invDirection,
                hvec2 currentMipPosition, hvec2 currentMipResolutionInv,
                hvec2 floorOffset, hvec2 uvOffset,
                hfloat surfaceZ,
                inout hvec3 position, inout hfloat currentT)
{
    hvec2 xyPlane = floor(currentMipPosition) + floorOffset;
    xyPlane = xyPlane * currentMipResolutionInv + uvOffset;

    hvec3 boundaryPlanes = hvec3_init(xyPlane.x, xyPlane.y, surfaceZ);
    hvec3 t = (boundaryPlanes - origin) * invDirection;

    // Standard Z (0=near, 1=far): only use depth plane when ray goes deeper
    t.z = direction.z > 0.0 ? t.z : FFX_FLOAT_MAX;

    hfloat tMin = min(min(t.x, t.y), t.z);

    // Standard Z: above surface when surface is farther than ray position
    bool aboveSurface = surfaceZ > position.z;

    bool skippedTile = (min(t.x, t.y) < t.z) && aboveSurface;

    currentT = aboveSurface ? tMin : currentT;
    position = origin + currentT * direction;

    return skippedTile;
}

// ============================================================
// FidelityFX SSSR: HierarchicalRaymarch
// Reference: FFX_SSSR_HierarchicalRaymarch in ffx_sssr.h
//
// Modification from original:
//   Mip level + HIZ_MIP_BIAS to align with half-resolution SSR grid.
//   HiZ texture uses point sampling (no filter) → texture2DLod gives exact cell values.
// ============================================================
hvec3 HierarchicalRaymarch(hvec3 origin, hvec3 direction, hvec2 screenSize,
                          int mostDetailedMip, int maxTraversalIntersections,
                          out bool validHit)
{
    hvec3 invDirection = hvec3_init(
        direction.x != 0.0 ? 1.0 / direction.x : FFX_FLOAT_MAX,
        direction.y != 0.0 ? 1.0 / direction.y : FFX_FLOAT_MAX,
        direction.z != 0.0 ? 1.0 / direction.z : FFX_FLOAT_MAX
    );

    int currentMip = mostDetailedMip;

    hvec2 currentMipResolution = screenSize / exp2(hfloat(currentMip));
    hvec2 currentMipResolutionInv = exp2(hfloat(currentMip)) / screenSize;

    // UV offset to cross into next cell
    hvec2 uvOffset = HIZ_CROSS_EPSILON * exp2(hfloat(mostDetailedMip)) / screenSize;
    uvOffset.x = direction.x < 0.0 ? -uvOffset.x : uvOffset.x;
    uvOffset.y = direction.y < 0.0 ? -uvOffset.y : uvOffset.y;

    // Floor offset: which cell edge to target
    hvec2 floorOffset = hvec2_init(
        direction.x < 0.0 ? 0.0 : 1.0,
        direction.y < 0.0 ? 0.0 : 1.0
    );

    hfloat currentT;
    hvec3 position;
    InitialAdvanceRay(origin, direction, invDirection,
                      currentMipResolution, currentMipResolutionInv,
                      floorOffset, uvOffset,
                      position, currentT);

    int i = 0;
    while (i < maxTraversalIntersections && currentMip >= mostDetailedMip)
    {
        hvec2 currentMipPosition = currentMipResolution * position.xy;

        // HiZ texture uses point sampling (filter="false") → exact cell value, no bilinear
        hfloat surfaceZ = texture2DLod(u_ClosestHiZ3, position.xy, hfloat(currentMip + HIZ_MIP_BIAS)).r;

        bool skippedTile = AdvanceRay(origin, direction, invDirection,
                                      currentMipPosition, currentMipResolutionInv,
                                      floorOffset, uvOffset,
                                      surfaceZ,
                                      position, currentT);

        currentMip += skippedTile ? 1 : -1;

        // Update mip resolution
        if (skippedTile)
        {
            currentMipResolution *= 0.5;
            currentMipResolutionInv *= 2.0;
        }
        else
        {
            currentMipResolution *= 2.0;
            currentMipResolutionInv *= 0.5;
        }

        // Clamp to max available logical mip level
        if (currentMip > MAX_MIP)
        {
            currentMip = MAX_MIP;
            currentMipResolution = screenSize / exp2(hfloat(MAX_MIP));
            currentMipResolutionInv = exp2(hfloat(MAX_MIP)) / screenSize;
        }

        i++;
    }

    validHit = (i < maxTraversalIntersections);
    return position;
}

// ============================================================
// Main HiZ trace entry point
//
// FidelityFX Intersect.hlsl approach:
//   - Origin UV from vTexCoord (SSR pixel center)
//   - Origin depth from HiZ at (mostDetailedMip + HIZ_MIP_BIAS)
//   - Direction via ProjectDirection (project endpoint, subtract origin)
//   - mostDetailedMip: 0 for mirror (roughness < 0.001), 1 for glossy
// ============================================================
bool HiZTrace(hvec3 viewOrigin, hvec3 rayDir, hfloat roughness,
              out hvec2 hitUV, out hfloat hitDepth, out hfloat confidence)
{
    hfloat thickness = u_Thickness;
    int maxSteps = int(u_MaxSteps);
    hfloat maxDist = u_MaxDistance;

    // FidelityFX mostDetailedMip logic (Intersect.hlsl)
    int mostDetailedMip = (roughness < 0.001) ? 0 : 1;

    // screenSize = SSR resolution (half-res), from cGBufferInvSize
    hvec2 screenSize = hvec2_init(1.0, 1.0) / cGBufferInvSize;

    // Origin UV (SSR pixel center, already correct at half-res)
    hvec2 originUV = vTexCoord;

    // Origin depth from HiZ (point sampling → exact cell value)
    hfloat originRawDepth = texture2DLod(u_ClosestHiZ3, originUV, hfloat(mostDetailedMip + HIZ_MIP_BIAS)).r;

    // Ray end in view space
    hvec3 rayEnd = viewOrigin + rayDir * maxDist;

    // Clip to near plane (left-handed: z > 0 is forward)
    if (rayEnd.z < cNearClipPS)
    {
        if (abs(rayDir.z) < 0.0001)
            return false;
        hfloat tClip = (cNearClipPS - viewOrigin.z) / rayDir.z;
        if (tClip <= 0.0)
            return false;
        rayEnd = viewOrigin + rayDir * tClip;
    }

    // Project ray endpoint to screen space (FidelityFX ProjectDirection approach)
    hvec4 hEnd = mul(hvec4_init(rayEnd.x, rayEnd.y, rayEnd.z, 1.0), cProj);

    if (hEnd.w <= 0.0)
        return false;

    hvec2 uvEnd = hEnd.xy / hEnd.w * 0.5 + 0.5;
    hfloat zEnd = hEnd.z / hEnd.w;
#if !(BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC)
    uvEnd.y = 1.0 - uvEnd.y;
#endif
#if (BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC)
    zEnd = zEnd * 0.5 + 0.5;
#endif

    // Screen-space ray: origin from HiZ (exact), direction = projected endpoint - origin
    hvec3 ssOrigin = hvec3_init(originUV.x, originUV.y, originRawDepth);
    hvec3 ssEnd = hvec3_init(uvEnd.x, uvEnd.y, zEnd);
    hvec3 ssDir = ssEnd - ssOrigin;

    // Clip to visible screen bounds [0,1]
    {
        hvec2 uvDir = ssDir.xy;
        hfloat tScreen = 1.0;

        if (uvDir.x > 0.0001)
            tScreen = min(tScreen, (1.0 - ssOrigin.x) / uvDir.x);
        else if (uvDir.x < -0.0001)
            tScreen = min(tScreen, -ssOrigin.x / uvDir.x);

        if (uvDir.y > 0.0001)
            tScreen = min(tScreen, (1.0 - ssOrigin.y) / uvDir.y);
        else if (uvDir.y < -0.0001)
            tScreen = min(tScreen, -ssOrigin.y / uvDir.y);

        tScreen = clamp(tScreen, 0.0, 1.0);
        ssDir *= tScreen;
    }

    // Ray must cover at least a few pixels
    hfloat pixelDist = max(abs(ssDir.x) * screenSize.x, abs(ssDir.y) * screenSize.y);
    if (pixelDist < 1.0)
        return false;

    // FidelityFX hierarchical ray march
    bool validHit;
    hvec3 hitPos = HierarchicalRaymarch(ssOrigin, ssDir, screenSize,
                                       mostDetailedMip, maxSteps,
                                       validHit);

    if (!validHit)
        return false;

    // Out of screen?
    if (any(lessThan(hitPos.xy, vec2_splat(0.0))) || any(greaterThan(hitPos.xy, vec2_splat(1.0))))
        return false;

    // Self-reflection rejection (FidelityFX ValidateHit: manhattan distance < 2 pixels)
    hvec2 manhattanDist = abs(hitPos.xy - originUV) * screenSize;
    if (manhattanDist.x < 2.0 && manhattanDist.y < 2.0)
        return false;

    // ================================================================
    // FidelityFX ValidateHit (ffx_sssr.h: FFX_SSSR_ValidateHit)
    //
    // Key differences from linear march validation:
    //   1. Surface depth from HiZ mip (not full-res depth buffer)
    //   2. Unsigned 3D view-space distance (not signed Z diff)
    //   3. smoothstep soft falloff (not hard binary threshold)
    // ================================================================

    // Background rejection (standard Z: far plane ~= 1.0)
    // FidelityFX: surface from LoadDepth(hit/2, 1), hit from LoadDepth(hit, 0).
    // Half-res: surface at physical mip (1+BIAS)=2, hit at physical mip (0+BIAS)=1.
    hfloat surfaceZ = texture2DLod(u_ClosestHiZ3, hitPos.xy, hfloat(1 + HIZ_MIP_BIAS)).r;
    if (surfaceZ >= 0.9999)
        return false;

    // Actual hit depth at finest mip (FidelityFX: LoadDepth(hit, 0))
    hfloat hitActualZ = texture2DLod(u_ClosestHiZ3, hitPos.xy, hfloat(0 + HIZ_MIP_BIAS)).r;

    // View-space distance (FidelityFX: InvProjectPosition both, then length())
    hvec3 viewSpaceSurface = ReconstructViewPos(hitPos.xy, surfaceZ);
    hvec3 viewSpaceHit = ReconstructViewPos(hitPos.xy, hitActualZ);
    hfloat hitDistance = length(viewSpaceSurface - viewSpaceHit);

    // Soft confidence falloff (FidelityFX: smoothstep + square)
    hfloat thicknessConfidence = 1.0 - smoothstep(0.0, thickness, hitDistance);
    thicknessConfidence *= thicknessConfidence;

    if (thicknessConfidence <= 0.0)
        return false;

    hitUV = hitPos.xy;
    hitDepth = surfaceZ;

    // Screen border vignette (FidelityFX: smoothstep border fade)
    hfloat edgeFade = CalculateEdgeFade(hitPos.xy);

    // Self-intersection distance fade
    hfloat screenDistPx = length((hitPos.xy - originUV) * screenSize);
    hfloat selfIntFade = saturate((screenDistPx - 2.0) / 4.0);

    hfloat roughnessFade = CalculateRoughnessFade(roughness, MAX_ROUGHNESS_FOR_SSR);

    confidence = thicknessConfidence * edgeFade * selfIntFade * roughnessFade;
    return true;
}

void PS()
{
    hvec2 uv = vTexCoord;

    hfloat depth = texture2D(u_Depth0, uv).r;
    hvec3 worldNormal = DecodeGBufferNormal(texture2D(u_Normal1, uv).rgb);
    hvec3 normal = normalize(mul(hvec4_init(worldNormal.x, worldNormal.y, worldNormal.z, 0.0), cView).xyz);
    hvec4 gbufferB = texture2D(u_GBufferB2, uv);
    hfloat roughness = gbufferB.b;
    hfloat metallic = gbufferB.r;

    if (roughness > MAX_ROUGHNESS_FOR_SSR)
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 0.0);
        return;
    }

    hfloat specular = gbufferB.g;
    if (metallic < 0.01 && specular < 0.1)
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // Reconstruct view-space position from depth buffer
    hvec3 viewPos = ReconstructViewPos(uv, depth);
    hvec3 viewDir = normalize(viewPos);

    // Per-frame noise for GGX importance sampling
    hvec2 pixelCoord = uv / cGBufferInvSize;
    hfloat noise1 = InterleavedGradientNoise(pixelCoord + u_FrameIndex * 5.588238);
    hfloat noise2 = InterleavedGradientNoise(pixelCoord.yx * 1.4142135 + u_FrameIndex * 7.238917);

    // Stochastic SSR: GGX importance sampling
    hfloat ssrRoughness = max(roughness, MIN_SSR_ROUGHNESS);

    hvec2 xi = hvec2_init(noise1, noise2);

    hvec3 H_tangent = ImportanceSampleGGX(xi, ssrRoughness);
    hvec3 H = TangentToWorld(H_tangent, normal);
    H = normalize(H);

    hvec3 reflectDir = reflect(viewDir, H);

    if (dot(reflectDir, normal) <= 0.0)
        reflectDir = reflect(viewDir, normal);

    hvec2 hitUV;
    hfloat hitDepth;
    hfloat confidence;

    if (HiZTrace(viewPos, reflectDir, roughness, hitUV, hitDepth, confidence))
    {
        hfloat NdotV = saturate(dot(normal, -viewDir));
        hfloat grazingFade = saturate(NdotV * 4.0);
        confidence *= grazingFade;

        hvec3 reflectColor = texture2D(u_SceneLighting5, hitUV).rgb;
        gl_FragColor = hvec4_init(reflectColor.x * confidence, reflectColor.y * confidence, reflectColor.z * confidence, confidence);
    }
    else
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 0.0);
    }
}

#endif
