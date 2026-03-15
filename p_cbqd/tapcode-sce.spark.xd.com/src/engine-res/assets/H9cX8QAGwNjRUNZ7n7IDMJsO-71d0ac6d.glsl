/*
 * GTAO Temporal Filter
 *
 * Accumulates AO across frames using motion vector reprojection.
 * Neighborhood min/max clamp prevents ghosting on moving objects.
 *
 * Simpler than SSR temporal: single-channel LDR, no HDR weighting,
 * no YCoCg transform, no Blackman-Harris kernel.
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

// Current AO (half-res, after spatial denoise, point sampled)
SAMPLER2D(u_CurrentAO0, 0);

// History AO (half-res, previous frame, bilinear for sub-pixel reprojection)
SAMPLER2D(u_HistoryAO1, 1);

// Motion vectors (full-res, bilinear interpolated)
SAMPLER2D(u_MotionVector2, 2);

// x = temporal blend factor (default 0.1: 10% current, 90% history)
uniform hvec4 u_TemporalParams;

void PS()
{
    hvec2 uv = vTexCoord;
    hvec2 texel = cGBufferInvSize.xy;

    // Current AO
    hfloat currentAO = texture2D(u_CurrentAO0, uv).r;

    // Motion vector (half-res UV on full-res MV, bilinear gives smooth interpolation)
    hvec2 motion = texture2D(u_MotionVector2, uv).rg;

    // Reproject to previous frame
    hvec2 historyUV = uv - motion;

    // Out of screen: no history available
    if (any(lessThan(historyUV, vec2_splat(0.0))) ||
        any(greaterThan(historyUV, vec2_splat(1.0))))
    {
        gl_FragColor = hvec4_init(currentAO, currentAO, currentAO, 1.0);
        return;
    }

    // History AO (bilinear for sub-pixel reprojection accuracy)
    hfloat historyAO = texture2D(u_HistoryAO1, historyUV).r;

    // Neighborhood min/max clamp (plus pattern: center + 4 cardinal)
    hfloat n0 = texture2D(u_CurrentAO0, uv + hvec2_init(-texel.x, 0.0)).r;
    hfloat n1 = texture2D(u_CurrentAO0, uv + hvec2_init( texel.x, 0.0)).r;
    hfloat n2 = texture2D(u_CurrentAO0, uv + hvec2_init(0.0, -texel.y)).r;
    hfloat n3 = texture2D(u_CurrentAO0, uv + hvec2_init(0.0,  texel.y)).r;

    hfloat nmin = min(currentAO, min(min(n0, n1), min(n2, n3)));
    hfloat nmax = max(currentAO, max(max(n0, n1), max(n2, n3)));

    // Clamp history to neighborhood bounds (prevents ghosting)
    historyAO = clamp(historyAO, nmin, nmax);

    // Blend
    hfloat blendFactor = u_TemporalParams.x;
    hfloat result = mix(historyAO, currentAO, blendFactor);

    gl_FragColor = hvec4_init(result, result, result, 1.0);
}

#endif
