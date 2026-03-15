/*
 * SSR Reflection Composite Shader
 * Implements reflection hierarchy system for energy-conserving reflections.
 *
 * Reflection Hierarchy (priority high to low):
 *   1. SSR (Screen Space Reflections)
 *   2. IBL Specular (global environment fallback)
 *
 * Key principle: SSR REPLACES IBL specular (not adds to it) for energy conservation.
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

// Scene lighting: direct_all + IBL_diffuse + emissive (register 0)
SAMPLER2D(u_SceneLighting0, 0);
// Environment specular: IBL_specular only, SSR fallback (register 1)
SAMPLER2D(u_EnvSpecular1, 1);
// SSR Buffer (register 2)
SAMPLER2D(u_SSRBuffer2, 2);

// Render path parameter (name must match XML <parameter name="..."> with u_ prefix)
uniform hfloat u_SSRIntensity;

void PS()
{
    hvec2 uv = vTexCoord;

    hvec3 sceneLighting = texture2D(u_SceneLighting0, uv).rgb;
    hvec3 envSpecular = texture2D(u_EnvSpecular1, uv).rgb;

    hvec4 ssrResult = texture2D(u_SSRBuffer2, uv);

    hfloat ssrAlpha = saturate(ssrResult.a * u_SSRIntensity);

    // Pre-multiplied alpha composite: SSR RGB is already color * confidence.
    // env * (1 - alpha) + premultiplied_rgb * intensity
    hvec3 finalReflection = envSpecular * (1.0 - ssrAlpha) + ssrResult.rgb * u_SSRIntensity;

    hvec3 finalColor = sceneLighting + finalReflection;

    gl_FragColor = hvec4_init(finalColor.x, finalColor.y, finalColor.z, 1.0);
}

#endif
