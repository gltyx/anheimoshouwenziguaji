#include "SSAORasterize/varying.def.sc"
$input v_texcoord0, v_screenPos

// Apply/Upsample - upsamples half-resolution AO to full resolution with edge-aware filtering
// WebGL compatible

#include "Common/common.sh"
#include "SSAORasterize/uniforms.sh"

SAMPLER2D(s_aoSource0, 0);

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
    vec2 pixelPos = gl_FragCoord.xy;
    vec2 halfPixelSize = u_halfViewportPixelSize;

    // Determine which quadrant this pixel belongs to
    int mx = int(mod(pixelPos.x, 2.0));
    int my = int(mod(pixelPos.y, 2.0));

    // UV in half-resolution texture
    vec2 halfUV = (floor(pixelPos * 0.5) + 0.5) * halfPixelSize;

    // Sample center value
    vec2 centerSample = texture2D(s_aoSource0, halfUV).xy;
    float ao = centerSample.x;
    vec4 edgesLRTB = UnpackEdges(centerSample.y);

    // Bilinear upsampling with edge awareness
    float fmx = float(mx);
    float fmy = float(my);

    // Edge-adjusted sampling offsets
    float fmxe = (edgesLRTB.y - edgesLRTB.x);
    float fmye = (edgesLRTB.w - edgesLRTB.z);

    // Sample neighboring half-res pixels
    vec2 uvH = halfUV + vec2(fmx + fmxe - 0.5, 0.0) * halfPixelSize;
    float aoH = texture2D(s_aoSource0, uvH).x;

    vec2 uvV = halfUV + vec2(0.0, fmy + fmye - 0.5) * halfPixelSize;
    float aoV = texture2D(s_aoSource0, uvV).x;

    vec2 uvD = halfUV + vec2(fmx + fmxe - 0.5, fmy + fmye - 0.5) * halfPixelSize;
    float aoD = texture2D(s_aoSource0, uvD).x;

    // Edge-aware blend weights
    vec4 blendWeights;
    blendWeights.x = 1.0;
    blendWeights.y = (edgesLRTB.x + edgesLRTB.y) * 0.5;
    blendWeights.z = (edgesLRTB.z + edgesLRTB.w) * 0.5;
    blendWeights.w = (blendWeights.y + blendWeights.z) * 0.5;

    float blendWeightsSum = dot(blendWeights, vec4(1.0, 1.0, 1.0, 1.0));
    ao = dot(vec4(ao, aoH, aoV, aoD), blendWeights) / blendWeightsSum;

    // Gamma correction for display
    ao = pow(ao, 1.0 / 2.2);

    gl_FragColor = vec4(ao, ao, ao, 1.0);
}
