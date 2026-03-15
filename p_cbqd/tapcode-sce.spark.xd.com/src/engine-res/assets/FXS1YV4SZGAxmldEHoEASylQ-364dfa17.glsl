#include "SSAORasterize/varying.def.sc"
$input v_texcoord0, v_screenPos

// Generate AO - main SSAO calculation
// WebGL compatible, supports QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH

#include "Common/common.sh"
#include "SSAORasterize/uniforms.sh"

SAMPLER2D(u_DepthBuffer0, 0);   // Half-resolution linear depth
SAMPLER2D(s_normalSource1, 1);  // View-space normals

// Sample pattern - progressive poisson-like distribution
// x, y are in [-1, 1] range, z is length, w is log2(length)
#define SAMPLE_COUNT 12

// Helper function to get sample pattern (WebGL compatible)
hvec4 GetSamplePattern(int index)
{
    if (index == 0)  return hvec4_init( 0.78488064,  0.56661671, 1.500, -0.126);
    if (index == 1)  return hvec4_init( 0.26022232, -0.29575172, 1.500, -1.064);
    if (index == 2)  return hvec4_init( 0.10459357,  0.08372527, 1.110, -2.730);
    if (index == 3)  return hvec4_init(-0.68286800,  0.04963045, 1.090, -0.498);
    if (index == 4)  return hvec4_init(-0.13570161, -0.64190155, 1.250, -0.532);
    if (index == 5)  return hvec4_init(-0.26193795, -0.08205118, 0.670, -1.783);
    if (index == 6)  return hvec4_init(-0.61177456,  0.66664219, 0.710, -0.044);
    if (index == 7)  return hvec4_init( 0.43675563,  0.25119025, 0.610, -1.167);
    if (index == 8)  return hvec4_init( 0.07884444,  0.86618668, 0.640, -0.459);
    if (index == 9)  return hvec4_init(-0.12790935, -0.29869005, 0.600, -1.729);
    if (index == 10) return hvec4_init(-0.04031125,  0.02413622, 0.600, -4.792);
    return hvec4_init( 0.16201244, -0.52851415, 0.790, -1.067);
}

// Convert UV [0,1] to viewspace position
// NOTE: Despite the name, this function expects UV coordinates, not NDC!
// This matches the original ASSAO implementation.
hvec3 UVToViewspace(hvec2 uv, hfloat viewspaceDepth)
{
    hvec3 pos;
    pos.xy = (u_ndcToViewMul * uv + u_ndcToViewAdd) * viewspaceDepth;
    pos.z = viewspaceDepth;
    return pos;
}

// Decode normal from packed format
hvec3 DecodeNormal(hvec3 encoded)
{
    return encoded * u_normalsUnpackMul + u_normalsUnpackAdd;
}

// Calculate pixel obscurance from a hit point
hfloat CalculatePixelObscurance(hvec3 pixelNormal, hvec3 hitDelta, hfloat falloffCalcMulSq)
{
    hfloat lengthSq = dot(hitDelta, hitDelta);
    hfloat NdotD = dot(pixelNormal, hitDelta) / sqrt(lengthSq);

    hfloat falloffMult = max(0.0, lengthSq * falloffCalcMulSq + 1.0);

    return max(0.0, NdotD - u_effectHorizonAngleThreshold) * falloffMult;
}

// Pack edges for blur pass (2 bits per edge = 4 gradient values)
hfloat PackEdges(hvec4 edgesLRTB)
{
    edgesLRTB = round(saturate(edgesLRTB) * 3.05);
    return dot(edgesLRTB, hvec4_init(64.0/255.0, 16.0/255.0, 4.0/255.0, 1.0/255.0));
}

// Calculate edge weights from depth differences
hvec4 CalculateEdges(hfloat centerZ, hfloat leftZ, hfloat rightZ, hfloat topZ, hfloat bottomZ)
{
    hvec4 edgesLRTB = hvec4_init(leftZ, rightZ, topZ, bottomZ) - centerZ;
    hvec4 edgesLRTBSlopeAdjusted = edgesLRTB + edgesLRTB.yxwz;
    edgesLRTB = min(abs(edgesLRTB), abs(edgesLRTBSlopeAdjusted));
    return saturate(1.3 - edgesLRTB / (centerZ * 0.040));
}

void main()
{
    hvec2 uv = v_texcoord0;

    // Flip pixelSize.y for OpenGL (matching original ASSAO)
    hvec2 pixelSize = u_halfViewportPixelSize;
#if BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC
    pixelSize.y = -pixelSize.y;
#endif

    // Get depth at center and neighbors
    hfloat pixZ = texture2D(u_DepthBuffer0, uv).x;
    hfloat pixLZ = texture2D(u_DepthBuffer0, uv + hvec2_init(-pixelSize.x, 0.0)).x;
    hfloat pixRZ = texture2D(u_DepthBuffer0, uv + hvec2_init( pixelSize.x, 0.0)).x;
    hfloat pixTZ = texture2D(u_DepthBuffer0, uv + hvec2_init(0.0, -pixelSize.y)).x;
    hfloat pixBZ = texture2D(u_DepthBuffer0, uv + hvec2_init(0.0,  pixelSize.y)).x;

    // Early out for sky/far plane
    if (pixZ >= u_cameraFarClip * 0.99)
    {
        gl_FragColor = hvec4_init(1.0, PackEdges(hvec4_init(1.0, 1.0, 1.0, 1.0)), 0.0, 1.0);
        return;
    }

    // Compute viewspace position
    hvec3 pixCenterPos = UVToViewspace(uv, pixZ);

    // Get normal (sample from full-res normal buffer)
    hvec3 encodedNormal = texture2D(s_normalSource1, uv).xyz;
    hvec3 pixelNormal = DecodeNormal(encodedNormal);

    // Calculate effect radius
    hfloat effectRadius = u_effectRadius;
    hfloat tooCloseLimitMod = saturate(length(pixCenterPos) * u_effectSamplingRadiusNearLimitRec) * 0.8 + 0.2;
    effectRadius *= tooCloseLimitMod;

    hvec2 pixelDirRBViewspaceSizeAtCenterZ = pixCenterPos.z * u_ndcToViewMul * u_viewport2xPixelSize;
    hfloat pixLookupRadiusMod = (0.85 * effectRadius) / pixelDirRBViewspaceSizeAtCenterZ.x;

    // Falloff calculation
    hfloat falloffCalcMulSq = -1.0 / (effectRadius * effectRadius);

    // Calculate edges for blur
    hvec4 edgesLRTB = CalculateEdges(pixZ, pixLZ, pixRZ, pixTZ, pixBZ);

    // Move center slightly towards camera
    pixCenterPos *= u_depthPrecisionOffsetMod;

    // Accumulate obscurance
    hfloat obscuranceSum = 0.0;
    hfloat weightSum = 0.0;

    // Determine number of taps based on quality
#ifdef QUALITY_LOW
    int numTaps = 3;
#elif defined(QUALITY_HIGH)
    int numTaps = 12;
#else // QUALITY_MEDIUM (default)
    int numTaps = 5;
#endif

    // Rotation based on pixel position for noise (matching original ASSAO pattern)
    // Original uses 5 rotation matrices indexed by (y*2 + x) % 5
    hvec2 pixPos = gl_FragCoord.xy;
    int pseudoRandomIndex = int(mod(pixPos.y * 2.0 + pixPos.x, 5.0));

    // Precomputed rotation angles matching original ASSAO
    // angle = (pass + subpass/5) * PI * 0.5, with pass=0 for rasterize version
    hfloat angle;
    if (pseudoRandomIndex == 0) angle = 0.0;
    else if (pseudoRandomIndex == 1) angle = 0.6283185;  // PI * 0.5 * 0.4
    else if (pseudoRandomIndex == 2) angle = 1.2566371;  // PI * 0.5 * 0.8
    else if (pseudoRandomIndex == 3) angle = 0.9424778;  // PI * 0.5 * 0.6
    else angle = 0.3141593;                              // PI * 0.5 * 0.2

    hfloat cosR = cos(angle);
    hfloat sinR = sin(angle);

    // Scale factor with slight variation (matching original)
    hfloat scale = 1.0 + (hfloat(pseudoRandomIndex) - 2.0) * 0.014;
    hfloat scaledRadius = scale * pixLookupRadiusMod;

    // Original matrix form: [ca, -sa; -sa, -ca] (rotation + Y reflection)
    mat2 rotScale = mat2(scaledRadius * cosR, scaledRadius * -sinR,
                        -scaledRadius * sinR, -scaledRadius * cosR);

    // Sample loop
    for (int i = 0; i < numTaps; ++i)
    {
        hvec4 sampleData = GetSamplePattern(i);
        hvec2 sampleOffset = mul(rotScale, sampleData.xy);
        hfloat weightMod = sampleData.z;

        // Snap to pixel center
        sampleOffset = round(sampleOffset);

        // Flip Y for OpenGL (matching original ASSAO)
#if BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC
        sampleOffset.y = -sampleOffset.y;
#endif

        hvec2 samplingUV = sampleOffset * u_viewport2xPixelSize + uv;

        // Sample depth and compute hit position
        hfloat sampleZ = texture2D(u_DepthBuffer0, samplingUV).x;
        hvec3 hitPos = UVToViewspace(samplingUV, sampleZ);
        hvec3 hitDelta = hitPos - pixCenterPos;

        // Calculate obscurance
        hfloat obscurance = CalculatePixelObscurance(pixelNormal, hitDelta, falloffCalcMulSq);

        // Haloing reduction
        hfloat reduct = max(0.0, -hitDelta.z);
        reduct = saturate(reduct * u_negRecEffectRadius + 2.0);
        hfloat weight = SSAO_HALOING_REDUCTION_AMOUNT * reduct + (1.0 - SSAO_HALOING_REDUCTION_AMOUNT);
        weight *= weightMod;

        obscuranceSum += obscurance * weight;
        weightSum += weight;

        // Mirror sample for symmetry
        hvec2 mirrorOffset = -sampleOffset;
        hvec2 mirrorUV = mirrorOffset * u_viewport2xPixelSize + uv;

        hfloat mirrorZ = texture2D(u_DepthBuffer0, mirrorUV).x;
        hvec3 mirrorHitPos = UVToViewspace(mirrorUV, mirrorZ);
        hvec3 mirrorHitDelta = mirrorHitPos - pixCenterPos;

        hfloat mirrorObscurance = CalculatePixelObscurance(pixelNormal, mirrorHitDelta, falloffCalcMulSq);

        hfloat mirrorReduct = max(0.0, -mirrorHitDelta.z);
        mirrorReduct = saturate(mirrorReduct * u_negRecEffectRadius + 2.0);
        hfloat mirrorWeight = SSAO_HALOING_REDUCTION_AMOUNT * mirrorReduct + (1.0 - SSAO_HALOING_REDUCTION_AMOUNT);
        mirrorWeight *= weightMod;

        obscuranceSum += mirrorObscurance * mirrorWeight;
        weightSum += mirrorWeight;
    }

    // Detail AO using neighbors
#ifndef QUALITY_LOW
    hvec3 viewspaceDirZNormalized = hvec3_init(pixCenterPos.xy / pixCenterPos.z, 1.0);
    hvec3 pixLDelta = hvec3_init(-pixelDirRBViewspaceSizeAtCenterZ.x, 0.0, 0.0) + viewspaceDirZNormalized * (pixLZ - pixCenterPos.z);
    hvec3 pixRDelta = hvec3_init( pixelDirRBViewspaceSizeAtCenterZ.x, 0.0, 0.0) + viewspaceDirZNormalized * (pixRZ - pixCenterPos.z);
#if BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC
    hvec3 pixTDelta = hvec3_init(0.0,  pixelDirRBViewspaceSizeAtCenterZ.y, 0.0) + viewspaceDirZNormalized * (pixTZ - pixCenterPos.z);
    hvec3 pixBDelta = hvec3_init(0.0, -pixelDirRBViewspaceSizeAtCenterZ.y, 0.0) + viewspaceDirZNormalized * (pixBZ - pixCenterPos.z);
#else
    hvec3 pixTDelta = hvec3_init(0.0, -pixelDirRBViewspaceSizeAtCenterZ.y, 0.0) + viewspaceDirZNormalized * (pixTZ - pixCenterPos.z);
    hvec3 pixBDelta = hvec3_init(0.0,  pixelDirRBViewspaceSizeAtCenterZ.y, 0.0) + viewspaceDirZNormalized * (pixBZ - pixCenterPos.z);
#endif

    hfloat modifiedFalloffCalcMulSq = 4.0 * falloffCalcMulSq;

    hvec4 additionalObscurance;
    additionalObscurance.x = CalculatePixelObscurance(pixelNormal, pixLDelta, modifiedFalloffCalcMulSq);
    additionalObscurance.y = CalculatePixelObscurance(pixelNormal, pixRDelta, modifiedFalloffCalcMulSq);
    additionalObscurance.z = CalculatePixelObscurance(pixelNormal, pixTDelta, modifiedFalloffCalcMulSq);
    additionalObscurance.w = CalculatePixelObscurance(pixelNormal, pixBDelta, modifiedFalloffCalcMulSq);

    obscuranceSum += u_detailAOStrength * dot(additionalObscurance, edgesLRTB);
#endif

    // Calculate final AO value
    // Note: Rasterize version produces stronger AO than original 4-pass deinterleaved compute version
    // Apply intensity reduction to approximate original visual result
    hfloat obscurance = obscuranceSum / max(weightSum, 0.0001);
    obscurance *= 0.5;  // Compensate for single-pass vs 4-pass difference

    // Distance fadeout
    hfloat fadeOut = saturate(pixCenterPos.z * u_effectFadeOutMul + u_effectFadeOutAdd);

    // Edge fadeout
    hfloat edgeFadeoutFactor = saturate((1.0 - edgesLRTB.x - edgesLRTB.y) * 0.35) +
                              saturate((1.0 - edgesLRTB.z - edgesLRTB.w) * 0.35);
    fadeOut *= saturate(1.0 - edgeFadeoutFactor);

    // Apply strength and clamp
    obscurance = u_effectShadowStrength * obscurance;
    obscurance = min(obscurance, u_effectShadowClamp);
    obscurance *= fadeOut;

    // Convert to occlusion (1 = fully lit, 0 = fully occluded)
    hfloat occlusion = 1.0 - obscurance;
    occlusion = pow(saturate(occlusion), u_effectShadowPow);

    // Output: R = AO, G = packed edges
    gl_FragColor = hvec4_init(occlusion, PackEdges(edgesLRTB), 0.0, 1.0);
}
