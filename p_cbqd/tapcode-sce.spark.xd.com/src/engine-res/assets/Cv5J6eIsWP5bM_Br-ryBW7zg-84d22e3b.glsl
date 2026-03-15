/*
 * SSR Linear Trace Shader
 * Performs screen-space ray marching to find reflection hits.
 *
 * Key technique: Stochastic SSR with GGX importance sampling.
 * Each pixel traces ONE ray per frame with a direction sampled from the GGX
 * distribution (based on roughness). A temporal filter accumulates results
 * over multiple frames to converge to the correct filtered reflection.
 *
 * For roughness = 0 (perfect mirror), a minimum roughness of 0.014 (UE4 standard)
 * is enforced to provide enough per-pixel ray variation to break the deterministic
 * hit/miss staircase pattern at depth buffer edges.
 *
 * Output:
 *   RGB = Reflected color
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

// Scene lighting: direct_all + IBL_diffuse (register 5)
SAMPLER2D(u_SceneLighting5, 5);

// Render path parameters (names must match XML <parameter name="..."> with u_ prefix)
uniform hfloat u_MaxDistance;
uniform hfloat u_MaxSteps;
uniform hfloat u_Thickness;
uniform hfloat u_FrameIndex;

#define MAX_ITERATIONS 64
#define MAX_ROUGHNESS_FOR_SSR 0.5

// Minimum roughness for SSR ray sampling (UE4 standard: 0.014).
// Even "perfect mirror" surfaces get slight ray variation to break
// the deterministic staircase hit/miss pattern at depth buffer edges.
#define MIN_SSR_ROUGHNESS 0.014

// Sample linear depth at a screen UV
hfloat SampleLinearDepth(hvec2 uv)
{
    hfloat rawDepth = texture2D(u_Depth0, uv).r;
    return LinearizeDepth(rawDepth, cNearClipPS, cFarClipPS);
}

// Project view-space position to screen UV
hvec2 ProjectToUV(hvec3 viewPos)
{
    hvec4 cp = mul(hvec4_init(viewPos.x, viewPos.y, viewPos.z, 1.0), cProj);
    hvec2 uv = cp.xy / cp.w * 0.5 + 0.5;
#if !(BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC)
    uv.y = 1.0 - uv.y;
#endif
    return uv;
}

// Screen-space ray march with perspective-correct 1/z depth interpolation.
// Each step advances ~1 pixel in screen space for uniform coverage.
// Two-phase: linear march (up to 64 steps) + binary refinement (4 steps)
bool ScreenSpaceTrace(hvec3 viewOrigin, hvec3 rayDir, hfloat roughness,
                      out hvec2 hitUV, out hfloat hitDepth, out hfloat confidence)
{
    hfloat thickness = u_Thickness;
    int maxSteps = int(u_MaxSteps);
    hfloat maxDist = u_MaxDistance;

    // Ray end in view space
    hvec3 rayEnd = viewOrigin + rayDir * maxDist;

    // Clip to near plane if ray goes behind camera (left-handed: z > 0 is forward)
    if (rayEnd.z < cNearClipPS)
    {
        if (abs(rayDir.z) < 0.0001)
            return false;
        hfloat tClip = (cNearClipPS - viewOrigin.z) / rayDir.z;
        if (tClip <= 0.0)
            return false;
        rayEnd = viewOrigin + rayDir * tClip;
    }

    // Project both endpoints to clip space
    hvec4 h0 = mul(hvec4_init(viewOrigin.x, viewOrigin.y, viewOrigin.z, 1.0), cProj);
    hvec4 h1 = mul(hvec4_init(rayEnd.x, rayEnd.y, rayEnd.z, 1.0), cProj);

    if (h0.w <= 0.0 || h1.w <= 0.0)
        return false;

    // To screen UV
    hvec2 uv0 = h0.xy / h0.w * 0.5 + 0.5;
    hvec2 uv1 = h1.xy / h1.w * 0.5 + 0.5;
#if !(BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC)
    uv0.y = 1.0 - uv0.y;
    uv1.y = 1.0 - uv1.y;
#endif

    // 1/w for perspective-correct depth (compute before screen clipping)
    hfloat k0 = 1.0 / h0.w;
    hfloat k1 = 1.0 / h1.w;

    // Clip ray endpoint to visible screen bounds [0,1].
    // Critical for backward-facing rays: perspective magnification makes the
    // endpoint project far off-screen, causing each step to skip many pixels.
    {
        hvec2 uvDir = uv1 - uv0;
        hfloat tScreen = 1.0;

        if (uvDir.x > 0.0001)
            tScreen = min(tScreen, (1.0 - uv0.x) / uvDir.x);
        else if (uvDir.x < -0.0001)
            tScreen = min(tScreen, -uv0.x / uvDir.x);

        if (uvDir.y > 0.0001)
            tScreen = min(tScreen, (1.0 - uv0.y) / uvDir.y);
        else if (uvDir.y < -0.0001)
            tScreen = min(tScreen, -uv0.y / uvDir.y);

        tScreen = clamp(tScreen, 0.0, 1.0);

        uv1 = uv0 + uvDir * tScreen;
        k1 = mix(k0, k1, tScreen);
    }

    // Screen-space ray length in pixels
    hvec2 screenSize = hvec2_init(1.0, 1.0) / cGBufferInvSize;
    hvec2 deltaPixels = (uv1 - uv0) * screenSize;
    hfloat pixelDist = max(abs(deltaPixels.x), abs(deltaPixels.y));

    if (pixelDist < 1.0)
        return false;

    // ~1 pixel per step, capped at maxSteps
    int numSteps = min(int(ceil(pixelDist)), maxSteps);
    hfloat stepT = 1.0 / hfloat(numSteps);

    // Temporal step jitter (UE4: InterleavedGradientNoise(SvPosition.xy, View.StateFrameIndexMod8))
    // Integer frame index guarantees uniform distribution across frames.
    // UE4 offset: FrameId * float2(47, 17) * 0.695 = FrameId * float2(32.665, 11.815)
    hvec2 pixelCoord = uv0 / cGBufferInvSize;
    hfloat jitter = InterleavedGradientNoise(pixelCoord + u_FrameIndex * hvec2_init(32.665, 11.815)) - 0.5;
    hfloat jitterOffset = jitter * stepT;

    // Phase 1: Screen-space linear march
    hfloat hitParamT = -1.0;
    hfloat hitDiff = 0.0;
    hfloat lastFrontT = 0.0;

    for (int i = 1; i <= MAX_ITERATIONS && i <= numSteps; i++)
    {
        hfloat t = stepT * hfloat(i) + jitterOffset;
        if (t > 1.0) break;
        hvec2 sampleUV = mix(uv0, uv1, t);

        if (any(lessThan(sampleUV, vec2_splat(0.0))) || any(greaterThan(sampleUV, vec2_splat(1.0))))
            break;

        hfloat rayZ = 1.0 / mix(k0, k1, t);
        hfloat sceneZ = SampleLinearDepth(sampleUV);
        hfloat depthDiff = rayZ - sceneZ;

        if (depthDiff > 0.0 && depthDiff < thickness)
        {
            // Ray is behind surface within thickness -> valid hit
            hitParamT = t;
            hitDiff = depthDiff;
            break;
        }
        else if (depthDiff <= 0.0)
        {
            // Ray in front of surface -> track last safe position
            lastFrontT = t;
        }
        // else: depthDiff > thickness -> ray passed THROUGH a thin surface,
        // continue marching to find the actual target behind the occluder
    }

    if (hitParamT < 0.0)
        return false;

    // Phase 2: Binary refinement (8 iterations for precise hit at depth edges)
    hfloat lo = lastFrontT;
    hfloat hi = hitParamT;
    hvec2 refinedUV = mix(uv0, uv1, hitParamT);
    hfloat refinedDiff = hitDiff;

    for (int j = 0; j < 8; j++)
    {
        hfloat mid = (lo + hi) * 0.5;
        hvec2 midUV = mix(uv0, uv1, mid);
        hfloat midRayZ = 1.0 / mix(k0, k1, mid);
        hfloat midSceneZ = SampleLinearDepth(midUV);
        hfloat midDiff = midRayZ - midSceneZ;

        if (midDiff > 0.0)
        {
            hi = mid;
            refinedUV = midUV;
            refinedDiff = midDiff;
        }
        else
        {
            lo = mid;
        }
    }

    hitUV = refinedUV;
    hitDepth = texture2D(u_Depth0, refinedUV).r;

    // Confidence computation
    hfloat screenDistPx = length((refinedUV - uv0) * screenSize);
    hfloat selfIntFade = saturate((screenDistPx - 2.0) / 4.0);
    hfloat edgeFade = CalculateEdgeFade(refinedUV);
    hfloat thicknessFade = 1.0 - saturate(refinedDiff / thickness);
    hfloat roughnessFade = CalculateRoughnessFade(roughness, MAX_ROUGHNESS_FOR_SSR);
    hfloat distanceFade = 1.0 - saturate(hi);

    confidence = edgeFade * thicknessFade * roughnessFade * distanceFade * selfIntFade;
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

    // ================================================================
    // Per-frame noise for GGX importance sampling
    // ================================================================
    // Two INDEPENDENT IGN evaluations with different spatial frequencies
    // and temporal offsets. This produces well-distributed 2D noise for
    // importance sampling the GGX NDF each frame.
    hvec2 pixelCoord = uv / cGBufferInvSize;
    hfloat noise1 = InterleavedGradientNoise(pixelCoord + u_FrameIndex * 5.588238);
    hfloat noise2 = InterleavedGradientNoise(pixelCoord.yx * 1.4142135 + u_FrameIndex * 7.238917);

    // ================================================================
    // Stochastic SSR: GGX importance sampling
    // ================================================================
    hfloat ssrRoughness = max(roughness, MIN_SSR_ROUGHNESS);

    hvec2 xi = hvec2_init(noise1, noise2);

    // Sample half-vector from GGX distribution in tangent space,
    // then transform to view space
    hvec3 H_tangent = ImportanceSampleGGX(xi, ssrRoughness);
    hvec3 H = TangentToWorld(H_tangent, normal);
    H = normalize(H);

    // Reflect view direction about the importance-sampled half-vector
    hvec3 reflectDir = reflect(viewDir, H);

    // If importance-sampled ray goes behind the surface, fall back to perfect reflect
    if (dot(reflectDir, normal) <= 0.0)
        reflectDir = reflect(viewDir, normal);

    hvec2 hitUV;
    hfloat hitDepth;
    hfloat confidence;

    if (ScreenSpaceTrace(viewPos, reflectDir, roughness, hitUV, hitDepth, confidence))
    {
        // Grazing angle fade (UE4 approach): reduce SSR at extreme grazing angles.
        hfloat NdotV = saturate(dot(normal, -viewDir));
        hfloat grazingFade = saturate(NdotV * 4.0);  // fades below NdotV ≈ 0.25
        confidence *= grazingFade;

        hvec3 reflectColor = texture2D(u_SceneLighting5, hitUV).rgb;
        // Pre-multiplied alpha: RGB already scaled by confidence.
        // Allows temporal filter to treat all 4 channels uniformly (matching UE4).
        gl_FragColor = hvec4_init(reflectColor.x * confidence, reflectColor.y * confidence, reflectColor.z * confidence, confidence);
    }
    else
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 0.0);
    }
}

#endif
