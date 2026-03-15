/*
 * TAA (Temporal Anti-Aliasing) Resolve — UE4 MainTemporalAAPS faithful port
 *
 * UE4 PostProcessTemporalCommon.usf configuration (AA_YCOCG=1 path):
 *   AA_FILTERED=1  — Blackman-Harris weighted plus-pattern spatial filter
 *   AA_YCOCG=1     — Work in YCoCg color space
 *   AA_BICUBIC=1   — Catmull-Rom bicubic history sampling (sharpness source)
 *   AA_TONE=1      — HDR perceptual weighting: 1/(Y+1) on YCoCg luminance
 *   AA_AABB=1      — But in AA_YCOCG path: simple component-wise clamp
 *   AA_CROSS=2     — X-pattern motion dilation at 2px
 *   AA_LOWPASS=0   — No wide lowpass (main TAA, not SSR temporal)
 *   AA_ALPHA=0     — Alpha not AA'd
 *   Blend=0.04     — Fixed 4% new frame (when AA_TONE=1)
 *
 * Pipeline position: after all scene rendering (HDR), before Bloom and Tonemapping.
 *
 * Sharpness comes from Catmull-Rom bicubic negative lobes in history sampling,
 * NOT from any explicit sharpening step.
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

// Current frame scene color - HDR, jittered (register 0)
SAMPLER2D(u_SceneColor0, 0);
// TAA history - previous frame's resolved output, bilinear filtered (register 1)
SAMPLER2D(u_TAAHistory1, 1);
// Motion vector buffer (register 2)
SAMPLER2D(u_MotionVector2, 2);
// Depth buffer (register 3)
SAMPLER2D(u_Depth3, 3);

// Render path parameters
uniform hfloat u_TAABlendFactor;

// TAA jitter offset in pixel space (+-0.5 pixels), set by C++ View per frame
uniform hvec2 u_JitterOffset;

// ============================================================
// YCoCg color space (UE4 AA_YCOCG=1)
// ============================================================
hvec3 RGBToYCoCg(hvec3 c)
{
    return hvec3_init(
         c.r * 0.25 + c.g * 0.5 + c.b * 0.25,
         c.r * 0.5  - c.b * 0.5,
        -c.r * 0.25 + c.g * 0.5 - c.b * 0.25
    );
}

hvec3 YCoCgToRGB(hvec3 c)
{
    hfloat tmp = c.x - c.z;
    return hvec3_init(tmp + c.y, c.x + c.z, tmp - c.y);
}

// ============================================================
// UE4 HDR perceptual weighting (AA_TONE=1, AA_YCOCG=1)
// ============================================================
// HdrWeightY: weight by YCoCg luminance (Y channel)
// With Exposure = 1.0: weight = 1 / (Y + 1)
// Suppresses bright specular highlights during blending.
hfloat HdrWeightY(hfloat y)
{
    return 1.0 / (y + 1.0);
}

// ============================================================
// UE4 Blackman-Harris kernel (PostProcessTemporalAA.cpp)
// ============================================================
// Exponential approximation to Blackman-Harris 3.3 window:
//   weight = exp(-2.29 * ||(offset - jitter) * scale||^2)
// Default Sharpness = 0 -> scale = 1.0 + 0 * 0.5 = 1.0
hfloat BhWeight(hvec2 sampleOffset, hvec2 jitter, hfloat scale)
{
    hvec2 d = (sampleOffset - jitter) * scale;
    return exp(-2.29 * dot(d, d));
}

// ============================================================
// Bicubic Catmull-Rom history sampling (UE4 AA_BICUBIC=1)
// ============================================================
// Catmull-Rom cubic filter has negative lobes in the [1,2] range,
// which subtract neighboring pixels and create a mild high-pass boost.
// This is the PRIMARY source of UE4 TAA sharpness.
//
// 5-tap optimized: collapses 4x4 separable kernel into 5 bilinear taps
// by grouping center w1+w2 pairs. Corner terms (~1.6% weight) dropped.
hvec3 SampleHistoryBicubic(hvec2 uv, hvec2 texSize, hvec2 invTexSize)
{
    hvec2 coord = uv * texSize - 0.5;
    hvec2 f = fract(coord);
    coord = coord - f;

    // Catmull-Rom weights (alpha = -0.5)
    // w0 = -0.5*t^3 + t^2 - 0.5*t
    // w1 = 1.5*t^3 - 2.5*t^2 + 1
    // w2 = -1.5*t^3 + 2*t^2 + 0.5*t
    // w3 = 0.5*t^3 - 0.5*t^2
    hvec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    hvec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    hvec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    hvec2 w3 = f * f * (-0.5 + 0.5 * f);

    // Bilinear optimization: combine center pair (w1 + w2)
    hvec2 s12 = w1 + w2;
    hvec2 f12 = w2 / s12;

    // Sample positions in UV space
    hvec2 tc0  = (coord - 0.5) * invTexSize;
    hvec2 tc12 = (coord + 0.5 + f12) * invTexSize;
    hvec2 tc3  = (coord + 2.5) * invTexSize;

    // 5-tap cross pattern
    hvec3 result =
        texture2D(u_TAAHistory1, hvec2_init(tc12.x, tc12.y)).rgb * (s12.x * s12.y) +
        texture2D(u_TAAHistory1, hvec2_init(tc0.x,  tc12.y)).rgb * (w0.x  * s12.y) +
        texture2D(u_TAAHistory1, hvec2_init(tc3.x,  tc12.y)).rgb * (w3.x  * s12.y) +
        texture2D(u_TAAHistory1, hvec2_init(tc12.x, tc0.y)).rgb  * (s12.x * w0.y)  +
        texture2D(u_TAAHistory1, hvec2_init(tc12.x, tc3.y)).rgb  * (s12.x * w3.y);

    // Normalize (compensate for dropped corner terms)
    hfloat totalW = s12.x * s12.y
                  + w0.x * s12.y + w3.x * s12.y
                  + s12.x * w0.y + s12.x * w3.y;
    return result / totalW;
}

void PS()
{
    hvec2 uv = vTexCoord;
    hvec2 texelSize = cGBufferInvSize;

    // ================================================================
    // Stage 1: X-pattern motion vector dilation (UE4 AA_CROSS=2)
    // ================================================================
    // 4 diagonal corners at 2px distance + center pixel.
    // Closest depth (smallest = nearest in standard Z) selects motion vector.
    // UE4 uses this wider pattern because TAA dilates edges beyond geometry.
    hfloat closestDepth = texture2D(u_Depth3, uv).r;
    hvec2 closestOffset = hvec2_init(0.0, 0.0);

    hfloat d0 = texture2D(u_Depth3, uv + hvec2_init(-2.0, -2.0) * texelSize).r;
    hfloat d1 = texture2D(u_Depth3, uv + hvec2_init( 2.0, -2.0) * texelSize).r;
    hfloat d2 = texture2D(u_Depth3, uv + hvec2_init(-2.0,  2.0) * texelSize).r;
    hfloat d3 = texture2D(u_Depth3, uv + hvec2_init( 2.0,  2.0) * texelSize).r;

    if (d0 < closestDepth) { closestDepth = d0; closestOffset = hvec2_init(-2.0, -2.0) * texelSize; }
    if (d1 < closestDepth) { closestDepth = d1; closestOffset = hvec2_init( 2.0, -2.0) * texelSize; }
    if (d2 < closestDepth) { closestDepth = d2; closestOffset = hvec2_init(-2.0,  2.0) * texelSize; }
    if (d3 < closestDepth) { closestDepth = d3; closestOffset = hvec2_init( 2.0,  2.0) * texelSize; }

    hvec2 motionVec = texture2D(u_MotionVector2, uv + closestOffset).rg;
    hvec2 historyUV = uv - motionVec;
    bool historyValid = all(greaterThanEqual(historyUV, vec2_splat(0.0)))
                     && all(lessThanEqual(historyUV, vec2_splat(1.0)));

    // ================================================================
    // Stage 2: Sample plus-pattern neighborhood (UE4 AA_YCOCG path)
    // ================================================================
    // UE4 AA_YCOCG=1: only plus pattern (5 taps) for filter and bounds.
    hvec3 s_top    = max(texture2D(u_SceneColor0, uv + hvec2_init( 0.0, -1.0) * texelSize).rgb, vec3_splat(0.0));
    hvec3 s_left   = max(texture2D(u_SceneColor0, uv + hvec2_init(-1.0,  0.0) * texelSize).rgb, vec3_splat(0.0));
    hvec3 s_center = max(texture2D(u_SceneColor0, uv).rgb, vec3_splat(0.0));
    hvec3 s_right  = max(texture2D(u_SceneColor0, uv + hvec2_init( 1.0,  0.0) * texelSize).rgb, vec3_splat(0.0));
    hvec3 s_bottom = max(texture2D(u_SceneColor0, uv + hvec2_init( 0.0,  1.0) * texelSize).rgb, vec3_splat(0.0));

    // ================================================================
    // Stage 3: Convert to YCoCg + HDR weight (AA_YCOCG=1, AA_TONE=1)
    // ================================================================
    hvec3 n0 = RGBToYCoCg(s_top);    n0 *= HdrWeightY(n0.x);
    hvec3 n1 = RGBToYCoCg(s_left);   n1 *= HdrWeightY(n1.x);
    hvec3 n2 = RGBToYCoCg(s_center); n2 *= HdrWeightY(n2.x);
    hvec3 n3 = RGBToYCoCg(s_right);  n3 *= HdrWeightY(n3.x);
    hvec3 n4 = RGBToYCoCg(s_bottom); n4 *= HdrWeightY(n4.x);

    // ================================================================
    // Stage 4: BH-weighted spatial filter (AA_FILTERED=1, plus pattern)
    // ================================================================
    // UE4 PostProcessTemporalAA.cpp: PlusWeights from Blackman-Harris kernel,
    // recentered each frame based on TAA jitter offset.
    // Default r.TemporalAASharpness = 0 -> scale = 1.0
    hvec2 jitter = u_JitterOffset;
    hfloat bhScale = 1.0;

    hfloat pw0 = BhWeight(hvec2_init( 0.0, -1.0), jitter, bhScale);
    hfloat pw1 = BhWeight(hvec2_init(-1.0,  0.0), jitter, bhScale);
    hfloat pw2 = BhWeight(hvec2_init( 0.0,  0.0), jitter, bhScale);
    hfloat pw3 = BhWeight(hvec2_init( 1.0,  0.0), jitter, bhScale);
    hfloat pw4 = BhWeight(hvec2_init( 0.0,  1.0), jitter, bhScale);

    hfloat totalPW = pw0 + pw1 + pw2 + pw3 + pw4;
    hvec3 filtered = (n0 * pw0 + n1 * pw1 + n2 * pw2 + n3 * pw3 + n4 * pw4) / totalPW;

    // ================================================================
    // Stage 5: Plus-pattern min/max in YCoCg (AA_YCOCG=1)
    // ================================================================
    // UE4 AA_YCOCG path: simple min/max, NOT mu+-sigma (AA_ROUND).
    hvec3 nMin = min(min(min(n0, n1), n2), min(n3, n4));
    hvec3 nMax = max(max(max(n0, n1), n2), max(n3, n4));

    // ================================================================
    // Stage 6: Bicubic Catmull-Rom history sampling (AA_BICUBIC=1)
    // ================================================================
    // Negative lobes of Catmull-Rom provide natural sharpening.
    // This is the primary source of UE4 TAA sharpness — no explicit sharpen step.
    hvec3 history;
    if (historyValid)
    {
        hvec2 texSize = 1.0 / texelSize;
        history = SampleHistoryBicubic(historyUV, texSize, texelSize);
        history = max(history, vec3_splat(0.0));

        // Convert to YCoCg + HDR weight
        history = RGBToYCoCg(history);
        history *= HdrWeightY(history.x);

        // ============================================================
        // Stage 7: Simple YCoCg clamp (AA_YCOCG=1, not ray-AABB)
        // ============================================================
        // UE4 AA_YCOCG path: component-wise clamp, simple and effective
        // because YCoCg is more perceptually uniform than RGB.
        history = clamp(history, nMin, nMax);
    }
    else
    {
        history = filtered;
    }

    // ================================================================
    // Stage 8: Fixed temporal blend (UE4 AA_TONE=1: BlendFinal = 0.04)
    // ================================================================
    hfloat blendFactor = historyValid ? u_TAABlendFactor : 1.0;
    hvec3 result = mix(history, filtered, blendFactor);

    // ================================================================
    // Stage 9: Inverse HDR weight + YCoCg to RGB
    // ================================================================
    // Karis inverse: result / (1 - weighted_Y)
    // Mathematically exact inverse of 1/(Y+1) weighting.
    // (UE4 uses an approximate inverse for variable exposure;
    //  with Exposure=1 the exact Karis inverse is strictly correct.)
    result /= max(1.0 - result.x, 0.001);

    // YCoCg to RGB
    result = YCoCgToRGB(result);

    // NaN protection
    result = max(result, vec3_splat(0.0));

    gl_FragColor = hvec4_init(result.x, result.y, result.z, 1.0);
}

#endif
