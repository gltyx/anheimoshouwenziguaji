/*
 * SSR Common Functions
 * Shared utilities for Screen Space Reflections
 *
 * All computations use full precision (hfloat/hvec*) to avoid fp16 artifacts.
 */

#ifndef SSR_COMMON_SH
#define SSR_COMMON_SH

#include "ScreenSpace/ScreenSpaceCommon.sh"

// Screen edge mask (UE4 ScreenSpaceReflections.usf)
// Applied to hit UV to fade reflections found near screen borders.
hfloat CalculateEdgeFade(hvec2 uv)
{
    hvec2 edgeDist = min(uv, 1.0 - uv);
    hfloat edge = min(edgeDist.x, edgeDist.y);
    return saturate(edge * 6.0);
}

// Roughness-based fade
hfloat CalculateRoughnessFade(hfloat roughness, hfloat maxRoughness)
{
    return 1.0 - saturate(roughness / maxRoughness);
}

// Spatial hash noise for temporal jitter (step offset along ray)
hfloat SsrSpatialHash(hvec2 screenPos)
{
    hvec3 p3 = fract(hvec3_init(screenPos.x, screenPos.y, screenPos.x + screenPos.y) * hvec3_init(0.1031, 0.1030, 0.0973));
    p3 += hvec3_init(dot(p3, p3.yzx + 33.33), dot(p3, p3.yzx + 33.33), dot(p3, p3.yzx + 33.33));
    return fract((p3.x + p3.y) * p3.z);
}

// ============================================================
// GGX Importance Sampling (Karis, SIGGRAPH 2013)
// ============================================================

// GGX/Trowbridge-Reitz NDF importance sampling.
// Given 2D random values xi in [0,1)^2 and roughness alpha,
// returns a half-vector H in tangent space (Z = normal).
//
// The distribution concentrates samples near the specular peak,
// so even a single sample per pixel per frame (with temporal accumulation)
// converges to the correct filtered reflection.
hvec3 ImportanceSampleGGX(hvec2 xi, hfloat roughness)
{
    hfloat a = roughness * roughness;
    hfloat a2 = a * a;

    hfloat phi = 2.0 * 3.14159265 * xi.x;
    hfloat cosTheta = sqrt((1.0 - xi.y) / (1.0 + (a2 - 1.0) * xi.y));
    hfloat sinTheta = sqrt(max(1.0 - cosTheta * cosTheta, 0.0));

    // Spherical to Cartesian in tangent space (Z-up = normal direction)
    return hvec3_init(
        cos(phi) * sinTheta,
        sin(phi) * sinTheta,
        cosTheta
    );
}

// Convert tangent-space vector to view-space given a surface normal N.
// Constructs an orthonormal tangent frame from N, then transforms H.
hvec3 TangentToWorld(hvec3 H, hvec3 N)
{
    hvec3 up = abs(N.z) < 0.999 ? hvec3_init(0.0, 0.0, 1.0) : hvec3_init(1.0, 0.0, 0.0);
    hvec3 T = normalize(cross(up, N));
    hvec3 B = cross(N, T);
    return T * H.x + B * H.y + N * H.z;
}

#endif // SSR_COMMON_SH
