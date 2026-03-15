#include "SSAORasterize/varying.def.sc"
$input v_texcoord0, v_screenPos

// Edge-sensitive blur for SSAO
// WebGL compatible

#include "Common/common.sh"
#include "SSAORasterize/uniforms.sh"

SAMPLER2D(s_blurSource0, 0);

// Unpack edges from packed format
vec4 UnpackEdges(float packedVal)
{
    uint packedBits = uint(packedVal * 255.5);
    vec4 edgesLRTB;
    edgesLRTB.x = float((packedBits >> 6u) & 0x03u) / 3.0;
    edgesLRTB.y = float((packedBits >> 4u) & 0x03u) / 3.0;
    edgesLRTB.z = float((packedBits >> 2u) & 0x03u) / 3.0;
    edgesLRTB.w = float((packedBits >> 0u) & 0x03u) / 3.0;
    return saturate(edgesLRTB + u_invSharpness);
}

void main()
{
    vec2 uv = v_texcoord0;
    vec2 pixelSize = u_halfViewportPixelSize;

    // Sample center
    vec2 centerSample = texture2D(s_blurSource0, uv).xy;
    float centerAO = centerSample.x;
    float packedEdges = centerSample.y;

    vec4 edgesLRTB = UnpackEdges(packedEdges);

    // Weighted accumulation
    float sumWeight = 0.5;
    float sum = centerAO * sumWeight;

    // Sample neighbors with edge-aware weights
    // Left
    {
        vec2 sampleUV = uv + vec2(-pixelSize.x, 0.0);
        float sampleAO = texture2D(s_blurSource0, sampleUV).x;
        float weight = edgesLRTB.x;
        sum += weight * sampleAO;
        sumWeight += weight;
    }

    // Right
    {
        vec2 sampleUV = uv + vec2(pixelSize.x, 0.0);
        float sampleAO = texture2D(s_blurSource0, sampleUV).x;
        float weight = edgesLRTB.y;
        sum += weight * sampleAO;
        sumWeight += weight;
    }

    // Top
    {
        vec2 sampleUV = uv + vec2(0.0, -pixelSize.y);
        float sampleAO = texture2D(s_blurSource0, sampleUV).x;
        float weight = edgesLRTB.z;
        sum += weight * sampleAO;
        sumWeight += weight;
    }

    // Bottom
    {
        vec2 sampleUV = uv + vec2(0.0, pixelSize.y);
        float sampleAO = texture2D(s_blurSource0, sampleUV).x;
        float weight = edgesLRTB.w;
        sum += weight * sampleAO;
        sumWeight += weight;
    }

    float blurredAO = sum / sumWeight;

    // Keep original edges for further blur passes
    gl_FragColor = vec4(blurredAO, packedEdges, 0.0, 1.0);
}
