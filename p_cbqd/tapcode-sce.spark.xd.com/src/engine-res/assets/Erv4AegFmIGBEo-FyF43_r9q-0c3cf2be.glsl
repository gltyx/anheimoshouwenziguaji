#include "SSAORasterize/varying.def.sc"
$input v_texcoord0, v_screenPos

// Prepare depths - converts depth buffer to linear viewspace depth at half resolution
// WebGL compatible

#include "Common/common.sh"
#include "SSAORasterize/uniforms.sh"

SAMPLER2D(u_DepthBuffer0, 0);

// Convert depth buffer value to linear viewspace depth
hfloat ScreenSpaceToViewSpaceDepth(hfloat screenDepth)
{
    hfloat depthLinearizeMul = u_depthUnpackConsts.x;
    hfloat depthLinearizeAdd = u_depthUnpackConsts.y;

    // Avoid division by zero at far plane
    hfloat denom = depthLinearizeAdd - screenDepth;
    if (abs(denom) < 0.00001)
        return u_cameraFarClip;

    // Optimized version of: linearDepth = (clipFar * clipNear) / (clipFar - screenDepth * (clipFar - clipNear))
    hfloat linearDepth = depthLinearizeMul / denom;

    // Clamp to avoid INF/NaN
    return clamp(linearDepth, 0.0, u_cameraFarClip);
}

void main()
{
    // Sample depth at current position (using bilinear for downsampling)
    hvec2 uv = v_texcoord0;

    // Sample 4 depth values for proper downsampling
    hvec2 pixelSize = u_viewportPixelSize;

    hfloat depth0 = texture2D(u_DepthBuffer0, uv + hvec2_init(-0.25, -0.25) * pixelSize * 2.0).x;
    hfloat depth1 = texture2D(u_DepthBuffer0, uv + hvec2_init( 0.25, -0.25) * pixelSize * 2.0).x;
    hfloat depth2 = texture2D(u_DepthBuffer0, uv + hvec2_init(-0.25,  0.25) * pixelSize * 2.0).x;
    hfloat depth3 = texture2D(u_DepthBuffer0, uv + hvec2_init( 0.25,  0.25) * pixelSize * 2.0).x;

    // Convert to linear viewspace depth
    hfloat linearDepth0 = ScreenSpaceToViewSpaceDepth(depth0);
    hfloat linearDepth1 = ScreenSpaceToViewSpaceDepth(depth1);
    hfloat linearDepth2 = ScreenSpaceToViewSpaceDepth(depth2);
    hfloat linearDepth3 = ScreenSpaceToViewSpaceDepth(depth3);

    // Use closest depth (min) to avoid artifacts at edges
    hfloat linearDepth = min(min(linearDepth0, linearDepth1), min(linearDepth2, linearDepth3));

    gl_FragColor = hvec4_init(linearDepth, 0.0, 0.0, 1.0);
}
