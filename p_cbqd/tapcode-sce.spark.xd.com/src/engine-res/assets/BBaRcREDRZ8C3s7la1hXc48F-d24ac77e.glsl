// ColorGrading.glsl - Complete color grading post-process shader
// Supports: LUT, exposure, white balance, per-range adjustments (shadows/midtones/highlights)

#ifdef BGFX_SHADER
#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position
    $output vScreenPos
#endif
#ifdef COMPILEPS
    $input vScreenPos
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"

#else

#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"

varying vec2 vScreenPos;

#endif

// ==================== ColorGrading Uniforms ====================
#ifdef COMPILEPS

// Global parameters
// x: exposure, y: temperature, z: tint, w: lutIntensity
uniform vec4 u_ColorGradingGlobal1;
// x: lutSize, y: lutBlendFactor, z: shadowsMax, w: highlightsMin
uniform vec4 u_ColorGradingGlobal2;

// Global range adjustment
// x: saturation, y: contrast, z: gamma, w: gain
uniform vec4 u_ColorGradingGlobalRange1;
// x: offset, y: tintIntensity, z: unused, w: unused
uniform vec4 u_ColorGradingGlobalRange2;
uniform vec4 u_ColorGradingGlobalTint;

// Shadows adjustment
uniform vec4 u_ColorGradingShadows1;
uniform vec4 u_ColorGradingShadows2;
uniform vec4 u_ColorGradingShadowsTint;

// Midtones adjustment
uniform vec4 u_ColorGradingMidtones1;
uniform vec4 u_ColorGradingMidtones2;
uniform vec4 u_ColorGradingMidtonesTint;

// Highlights adjustment
uniform vec4 u_ColorGradingHighlights1;
uniform vec4 u_ColorGradingHighlights2;
uniform vec4 u_ColorGradingHighlightsTint;

// Define aliases for compatibility
#define cColorGradingGlobal1 u_ColorGradingGlobal1
#define cColorGradingGlobal2 u_ColorGradingGlobal2
#define cColorGradingGlobalRange1 u_ColorGradingGlobalRange1
#define cColorGradingGlobalRange2 u_ColorGradingGlobalRange2
#define cColorGradingGlobalTint u_ColorGradingGlobalTint
#define cColorGradingShadows1 u_ColorGradingShadows1
#define cColorGradingShadows2 u_ColorGradingShadows2
#define cColorGradingShadowsTint u_ColorGradingShadowsTint
#define cColorGradingMidtones1 u_ColorGradingMidtones1
#define cColorGradingMidtones2 u_ColorGradingMidtones2
#define cColorGradingMidtonesTint u_ColorGradingMidtonesTint
#define cColorGradingHighlights1 u_ColorGradingHighlights1
#define cColorGradingHighlights2 u_ColorGradingHighlights2
#define cColorGradingHighlightsTint u_ColorGradingHighlightsTint

// ==================== Helper Functions ====================

// Calculate luminance using Rec. 709 coefficients
float GetLuminance(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// Color temperature adjustment (simplified Planckian locus approximation)
vec3 ApplyTemperature(vec3 color, float temperature)
{
    // temperature: -1 (cool/blue) to +1 (warm/orange)
    vec3 warm = vec3(1.0, 0.9, 0.8);
    vec3 cool = vec3(0.8, 0.9, 1.0);
    vec3 tintColor = mix(cool, warm, temperature * 0.5 + 0.5);
    return color * tintColor;
}

// Tint adjustment (green-magenta axis)
vec3 ApplyTintShift(vec3 color, float tintVal)
{
    // tint: -1 (green) to +1 (magenta)
    color.g -= tintVal * 0.1;
    color.r += tintVal * 0.05;
    color.b += tintVal * 0.05;
    return color;
}

// Saturation adjustment
vec3 ApplySaturation(vec3 color, float saturation)
{
    float luma = GetLuminance(color);
    return mix(vec3_splat(luma), color, saturation);
}

// Contrast adjustment
vec3 ApplyContrast(vec3 color, float contrast)
{
    return (color - vec3_splat(0.5)) * contrast + vec3_splat(0.5);
}

// Gamma adjustment
vec3 ApplyGamma(vec3 color, float gamma)
{
    return pow(max(color, vec3_splat(0.0)), vec3_splat(1.0 / gamma));
}

// Gain adjustment (multiplicative)
vec3 ApplyGain(vec3 color, float gain)
{
    return color * gain;
}

// Offset adjustment (additive)
vec3 ApplyOffset(vec3 color, float offset)
{
    return color + vec3_splat(offset);
}

// Tint color overlay
vec3 ApplyTintColor(vec3 color, vec3 tintColor, float intensity)
{
    return mix(color, color * tintColor, intensity);
}

// ==================== Per-Range Adjustment ====================

// Apply single range adjustment
vec3 ApplyRangeAdjustment(vec3 color, vec4 params1, vec4 params2, vec4 tint)
{
    float saturation = params1.x;
    float contrast = params1.y;
    float gamma = params1.z;
    float gain = params1.w;
    float offset = params2.x;
    float tintIntensity = params2.y;

    // Apply in order: Saturation -> Contrast -> Gamma -> Gain -> Offset -> Tint
    color = ApplySaturation(color, saturation);
    color = ApplyContrast(color, contrast);
    color = ApplyGamma(color, gamma);
    color = ApplyGain(color, gain);
    color = ApplyOffset(color, offset);
    color = ApplyTintColor(color, tint.rgb, tintIntensity);

    return color;
}

// Calculate range weights with smooth transitions
void GetRangeWeights(float luma, float shadowsMax, float highlightsMin,
                     out float shadowWeight, out float midtoneWeight, out float highlightWeight)
{
    // Use smoothstep for gradual transitions
    shadowWeight = 1.0 - smoothstep(0.0, shadowsMax, luma);
    highlightWeight = smoothstep(highlightsMin, 1.0, luma);
    midtoneWeight = 1.0 - shadowWeight - highlightWeight;
    midtoneWeight = max(midtoneWeight, 0.0);

    // Normalize weights
    float total = shadowWeight + midtoneWeight + highlightWeight;
    if (total > 0.0)
    {
        float invTotal = 1.0 / total;
        shadowWeight *= invTotal;
        midtoneWeight *= invTotal;
        highlightWeight *= invTotal;
    }
}

// ==================== LUT Sampling ====================

#ifndef URHO3D_MOBILE
vec3 SampleLUT3D(sampler3D lut, vec3 color, float lutSize)
{
    // Ensure input is strictly in [0,1] range
    color = clamp(color, 0.0, 1.0);

    // UE-style LUT sampling with proper edge handling
    // The LUT texture stores colors at texel centers, so we need to remap
    // For a 32-size LUT: valid range is [0.5/32, 31.5/32] = [0.015625, 0.984375]
    float invLutSize = 1.0 / lutSize;
    float halfTexel = 0.5 * invLutSize;
    float scale = 1.0 - invLutSize;  // = (lutSize - 1) / lutSize

    vec3 coord = color * scale + vec3_splat(halfTexel);

    // Force LOD 0 to avoid mipmap issues
    return texture3DLod(lut, coord, 0.0).rgb;
}

// Alternative: Manual trilinear interpolation for debugging
vec3 SampleLUT3D_Manual(sampler3D lut, vec3 color, float lutSize)
{
    // Strictly clamp to [0, 1]
    color = clamp(color, 0.0, 1.0);

    // Scale to LUT grid coordinates [0, lutSize-1]
    // Clamp to [0, lutSize-2] so we always have room for interpolation
    float maxCell = lutSize - 1.001;  // Slightly less than lutSize-1 to avoid edge
    vec3 scaled = color * (lutSize - 1.0);
    scaled = clamp(scaled, vec3_splat(0.0), vec3_splat(maxCell));

    // Get base cell and fractional part
    vec3 baseCell = floor(scaled);
    vec3 frac = scaled - baseCell;

    // Convert to texture coordinates using NEAREST sampling positions
    // Each texel center is at (i + 0.5) / lutSize
    float invLutSize = 1.0 / lutSize;

    // Sample the 8 corners using point sampling coordinates
    vec3 t0 = (baseCell + 0.5) * invLutSize;
    vec3 t1 = (baseCell + 1.5) * invLutSize;

    // Sample 8 corners with explicit coordinates
    vec3 c000 = texture3D(lut, vec3(t0.x, t0.y, t0.z)).rgb;
    vec3 c100 = texture3D(lut, vec3(t1.x, t0.y, t0.z)).rgb;
    vec3 c010 = texture3D(lut, vec3(t0.x, t1.y, t0.z)).rgb;
    vec3 c110 = texture3D(lut, vec3(t1.x, t1.y, t0.z)).rgb;
    vec3 c001 = texture3D(lut, vec3(t0.x, t0.y, t1.z)).rgb;
    vec3 c101 = texture3D(lut, vec3(t1.x, t0.y, t1.z)).rgb;
    vec3 c011 = texture3D(lut, vec3(t0.x, t1.y, t1.z)).rgb;
    vec3 c111 = texture3D(lut, vec3(t1.x, t1.y, t1.z)).rgb;

    // Trilinear interpolation
    vec3 c00 = mix(c000, c100, frac.x);
    vec3 c01 = mix(c001, c101, frac.x);
    vec3 c10 = mix(c010, c110, frac.x);
    vec3 c11 = mix(c011, c111, frac.x);

    vec3 c0 = mix(c00, c10, frac.y);
    vec3 c1 = mix(c01, c11, frac.y);

    return mix(c0, c1, frac.z);
}
#endif

// ==================== Main Color Grading ====================

vec3 ApplyColorGrading(vec3 color)
{
    // Extract parameters
    float exposure = cColorGradingGlobal1.x;
    float temperature = cColorGradingGlobal1.y;
    float tintVal = cColorGradingGlobal1.z;
    float lutIntensity = cColorGradingGlobal1.w;

    float lutSize = cColorGradingGlobal2.x;
    float lutBlendFactor = cColorGradingGlobal2.y;
    float shadowsMax = cColorGradingGlobal2.z;
    float highlightsMin = cColorGradingGlobal2.w;

    // ==================== 1. Exposure ====================
    color *= pow(2.0, exposure);

    // ==================== 2. White Balance ====================
    color = ApplyTemperature(color, temperature);
    color = ApplyTintShift(color, tintVal);

    // ==================== 3. Global Adjustment ====================
    color = ApplyRangeAdjustment(color,
        cColorGradingGlobalRange1,
        cColorGradingGlobalRange2,
        cColorGradingGlobalTint);

    // ==================== 4. Per-Range Adjustment ====================
    float luma = GetLuminance(color);
    float shadowWeight, midtoneWeight, highlightWeight;
    GetRangeWeights(luma, shadowsMax, highlightsMin,
                    shadowWeight, midtoneWeight, highlightWeight);

    // Process each range
    vec3 shadowsColor = ApplyRangeAdjustment(color,
        cColorGradingShadows1, cColorGradingShadows2, cColorGradingShadowsTint);
    vec3 midtonesColor = ApplyRangeAdjustment(color,
        cColorGradingMidtones1, cColorGradingMidtones2, cColorGradingMidtonesTint);
    vec3 highlightsColor = ApplyRangeAdjustment(color,
        cColorGradingHighlights1, cColorGradingHighlights2, cColorGradingHighlightsTint);

    // Blend ranges
    color = shadowsColor * shadowWeight +
            midtonesColor * midtoneWeight +
            highlightsColor * highlightWeight;

    // ==================== 5. LUT Application ====================
#ifndef URHO3D_MOBILE
    if (lutIntensity > 0.0 && lutSize > 0.0)
    {
        vec3 lutColor = SampleLUT3D(sVolumeMap, color, lutSize);
        color = mix(color, lutColor, lutIntensity);
    }
#endif

    // Ensure output is in valid range
    return clamp(color, 0.0, 1.0);
}

#endif // COMPILEPS

// ==================== Vertex Shader ====================

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

// ==================== Pixel Shader ====================

void PS()
{
    vec3 color = texture2D(sDiffMap, vScreenPos).rgb;
    color = ApplyColorGrading(color);

    // Apply dithering to reduce color banding (UE-style)
    // Use gl_FragCoord.xy (pixel coordinates) for proper noise distribution
    float noise = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
    color += (noise - 0.5) / 255.0;

    #if GAMMA_IN_SHADERING
        gl_FragColor = vec4(LinearToGammaSpace(color), 1.0);
    #else
        gl_FragColor = vec4(color, 1.0);
    #endif
}
