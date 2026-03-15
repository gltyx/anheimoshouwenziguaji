#include "SSAORasterize/varying.def.sc"
$input v_texcoord0, v_screenPos

// Prepare normals - reconstructs view-space normals from depth buffer
// WebGL compatible, using ASSAO algorithm

#include "Common/common.sh"
#include "SSAORasterize/uniforms.sh"

SAMPLER2D(u_DepthBuffer0, 0);

// Convert depth buffer value to linear viewspace depth
hfloat ScreenSpaceToViewSpaceDepth(hfloat screenDepth)
{
    hfloat depthLinearizeMul = u_depthUnpackConsts.x;
    hfloat depthLinearizeAdd = u_depthUnpackConsts.y;

    hfloat denom = depthLinearizeAdd - screenDepth;
    if (abs(denom) < 0.00001)
        return u_cameraFarClip;

    hfloat linearDepth = depthLinearizeMul / denom;
    return clamp(linearDepth, 0.0, u_cameraFarClip);
}

// Convert UV [0,1] to viewspace position
hvec3 UVToViewspace(hvec2 uv, hfloat viewspaceDepth)
{
    hvec3 pos;
    pos.xy = (u_ndcToViewMul * uv + u_ndcToViewAdd) * viewspaceDepth;
    pos.z = viewspaceDepth;
    return pos;
}

// Slope-sensitive edge detection (from ASSAO)
hvec4 CalculateEdges(hfloat centerZ, hfloat leftZ, hfloat rightZ, hfloat topZ, hfloat bottomZ)
{
    hvec4 edgesLRTB = hvec4(leftZ, rightZ, topZ, bottomZ) - centerZ;
    hvec4 edgesLRTBSlopeAdjusted = edgesLRTB + edgesLRTB.yxwz;
    edgesLRTB = min(abs(edgesLRTB), abs(edgesLRTBSlopeAdjusted));
    // Use a minimum divisor to prevent edge weights from going to zero at close range
    hfloat divisor = centerZ * 0.040 + 0.001;
    return saturate(1.3 - edgesLRTB / divisor);
}

// Calculate normal using 4-direction weighted cross products (from ASSAO)
hvec3 CalculateNormal(hvec4 edgesLRTB, hvec3 pixCenterPos, hvec3 pixLPos, hvec3 pixRPos, hvec3 pixTPos, hvec3 pixBPos)
{
    // Weight for each quadrant based on edge connectivity
    hvec4 acceptedNormals = hvec4(
        edgesLRTB.x * edgesLRTB.z,  // left-top
        edgesLRTB.z * edgesLRTB.y,  // top-right
        edgesLRTB.y * edgesLRTB.w,  // right-bottom
        edgesLRTB.w * edgesLRTB.x   // bottom-left
    );

    // Normalize direction vectors
    pixLPos = normalize(pixLPos - pixCenterPos);
    pixRPos = normalize(pixRPos - pixCenterPos);
    pixTPos = normalize(pixTPos - pixCenterPos);
    pixBPos = normalize(pixBPos - pixCenterPos);

    // Blend 4 normals with edge weights
    hvec3 pixelNormal = hvec3_init(0.0, 0.0, -0.0005);
    pixelNormal += acceptedNormals.x * cross(pixLPos, pixTPos);
    pixelNormal += acceptedNormals.y * cross(pixTPos, pixRPos);
    pixelNormal += acceptedNormals.z * cross(pixRPos, pixBPos);
    pixelNormal += acceptedNormals.w * cross(pixBPos, pixLPos);
    pixelNormal = normalize(pixelNormal);

    return pixelNormal;
}

// Sample depth at integer pixel offset from center
hfloat SampleDepthAt(hvec2 centerUV, hvec2 pixelSize, int offsetX, int offsetY)
{
    hvec2 uv = centerUV + hvec2_init(hfloat(offsetX), hfloat(offsetY)) * pixelSize;
    return ScreenSpaceToViewSpaceDepth(texture2DLod(u_DepthBuffer0, uv, 0.0).x);
}

void main()
{
    hvec2 uv = v_texcoord0;

    // Flip pixelSize.y for OpenGL (matching original ASSAO)
    hvec2 pixelSize = u_viewportPixelSize;
#if BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC
    pixelSize.y = -pixelSize.y;
#endif

    // Sample center depth
    hfloat depthCenter = ScreenSpaceToViewSpaceDepth(texture2DLod(u_DepthBuffer0, uv, 0.0).x);

    // Early out for sky/far plane
    if (depthCenter >= u_cameraFarClip * 0.99)
    {
        gl_FragColor = hvec4_init(0.5, 0.5, 1.0, 1.0);
        return;
    }

    // Sample neighbor depths
    hfloat depthLeft   = ScreenSpaceToViewSpaceDepth(texture2DLod(u_DepthBuffer0, uv + hvec2_init(-pixelSize.x, 0.0), 0.0).x);
    hfloat depthRight  = ScreenSpaceToViewSpaceDepth(texture2DLod(u_DepthBuffer0, uv + hvec2_init( pixelSize.x, 0.0), 0.0).x);
    hfloat depthTop    = ScreenSpaceToViewSpaceDepth(texture2DLod(u_DepthBuffer0, uv + hvec2_init(0.0, -pixelSize.y), 0.0).x);
    hfloat depthBottom = ScreenSpaceToViewSpaceDepth(texture2DLod(u_DepthBuffer0, uv + hvec2_init(0.0,  pixelSize.y), 0.0).x);

    // Calculate edges
    hvec4 edges = CalculateEdges(depthCenter, depthLeft, depthRight, depthTop, depthBottom);

    // Reconstruct positions
    hvec3 posCenter = UVToViewspace(uv, depthCenter);
    hvec3 posLeft   = UVToViewspace(uv + hvec2_init(-pixelSize.x, 0.0), depthLeft);
    hvec3 posRight  = UVToViewspace(uv + hvec2_init( pixelSize.x, 0.0), depthRight);
    hvec3 posTop    = UVToViewspace(uv + hvec2_init(0.0, -pixelSize.y), depthTop);
    hvec3 posBottom = UVToViewspace(uv + hvec2_init(0.0,  pixelSize.y), depthBottom);

    // Calculate normal
    hvec3 normal = CalculateNormal(edges, posCenter, posLeft, posRight, posTop, posBottom);

    // Pack normal to [0, 1] range
    hvec3 packedNormal = normal * 0.5 + 0.5;

    gl_FragColor = hvec4_init(packedNormal, 1.0);
}
