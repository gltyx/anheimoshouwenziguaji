#include "varying_deferred.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position
    $output vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif
#ifdef COMPILEPS
    $input vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "lighting.sh"
#include "fog.sh"
#include "constants.sh"
#ifdef LIGHTMAP
#include "LightMap.sh"
#endif
#ifdef COMPILEPS
#include "PBR/StandardPBR.sh"
#include "lambert.sh"
#endif

SAMPLER2D(u_GBuffer0, 0);
SAMPLER2D(u_GBuffer1, 1);
SAMPLER2D(u_GBuffer2, 2);
SAMPLER2D(u_GBuffer3, 3);
SAMPLER2D(u_GBuffer4, 4);

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    #ifdef DIRLIGHT
        vScreenPos = GetScreenPosPreDiv(gl_Position);
        vFarRay = GetFarRay(gl_Position);
        #ifdef ORTHO
            vNearRay = GetNearRay(gl_Position);
        #endif
    #else
        vScreenPos = GetScreenPos(gl_Position);
        vFarRay = GetFarRay(gl_Position) * gl_Position.w;
        #ifdef ORTHO
            vNearRay = GetNearRay(gl_Position) * gl_Position.w;
        #endif
    #endif
}

void PS()
{
    // If rendering a directional light quad, optimize out the w divide
    hfloat sourceDepth = texture2D(u_GBuffer4, vScreenPos).r;
    hfloat depth = ReconstructDepth(sourceDepth);
    #ifdef ORTHO
        hvec3 worldPos = mix(vNearRay, vFarRay, depth);
    #else
        hvec3 worldPos = vFarRay * depth;
    #endif
    vec3 normalDirection = DecodeNormal(texture2D(u_GBuffer0, vScreenPos).rgb);
    vec4 metallicSpecularRoughnessID = texture2D(u_GBuffer1, vScreenPos);
    vec4 baseColor = texture2D(u_GBuffer2, vScreenPos);
    vec3 emissiveColor = texture2D(u_GBuffer3, vScreenPos).rgb;

    // Position acquired via near/far ray is relative to camera. Bring position to world space
    hvec3 eyeVec = -worldPos;
    worldPos += cCameraPosPS;

    hvec4 projWorldPos = hvec4_init(worldPos, 1.0);

    #ifdef SHADOW
        float shadow = GetShadowDeferred(projWorldPos, normalDirection, depth);
    #else
        float shadow = 1.0;
    #endif

    vec3 viewDirection = normalize(eyeVec);
    uint shadingModelID = (uint)round(metallicSpecularRoughnessID.a * 255.0);

#ifdef SPLIT_LIGHTING
    // ========================================
    // Split output mode: Output to two RenderTargets
    // Used by reflection hierarchy system (SSR)
    // ========================================
    vec3 sceneLighting = emissiveColor;  // Emissive goes into scene lighting
    vec3 envSpecular = vec3(0.0, 0.0, 0.0);

    switch (shadingModelID)
    {
        case SHADINGMODELID_PBR_LIT:
        {
            vec3 sceneLit, envSpec;
            MetallicPBR_Split(
                baseColor.rgb,
                metallicSpecularRoughnessID.r,  // metallic
                metallicSpecularRoughnessID.g,  // specular
                metallicSpecularRoughnessID.b,  // roughness
                worldPos,
                normalDirection,
                viewDirection,
                vec3(shadow, shadow, shadow),
                1.0  // occlusion
#ifdef DEFERRED_CLUSTER
                , LinearizeDepth(sourceDepth, cNearClipPS, cFarClipPS)
#endif
                , sceneLit  // out: direct_diffuse + direct_specular + IBL_diffuse
                , envSpec   // out: IBL_specular only
            );
            sceneLighting += sceneLit;
            envSpecular = envSpec;
            break;
        }

        case SHADINGMODELID_LAMBERT_LIT:
        {
            // Lambert has no specular reflection, all goes into scene lighting
            sceneLighting += LambertBRDF(
                baseColor.rgb,
                vec4(metallicSpecularRoughnessID.rgb, baseColor.a * 255.0),
                worldPos,
                normalDirection,
                vec3(shadow, shadow, shadow),
                1.0
#ifdef DEFERRED_CLUSTER
                , LinearizeDepth(sourceDepth, cNearClipPS, cFarClipPS)
#endif
            );
            break;
        }
    }

    // MRT output for reflection hierarchy system
    // RT0: Scene lighting = direct_all + IBL_diffuse + emissive
    // RT1: Env specular = IBL_specular only (SSR replaces this when available)
    gl_FragData[0] = vec4(sceneLighting, 1.0);
    gl_FragData[1] = vec4(envSpecular, 1.0);

#else
    // ========================================
    // Traditional mode: Single output (backward compatible)
    // ========================================
    gl_FragColor = vec4(emissiveColor, 1.0);

    switch (shadingModelID)
    {
        case SHADINGMODELID_PBR_LIT:
            gl_FragColor.rgb += MetallicPBR(baseColor.rgb, metallicSpecularRoughnessID.r, metallicSpecularRoughnessID.g, metallicSpecularRoughnessID.b, worldPos, normalDirection, viewDirection, vec3(shadow, shadow, shadow), 1.0
            #ifdef DEFERRED_CLUSTER
                , LinearizeDepth(sourceDepth, cNearClipPS, cFarClipPS)
            #endif
            );
            break;

        case SHADINGMODELID_LAMBERT_LIT:
            gl_FragColor.rgb += LambertBRDF(baseColor.rgb, vec4(metallicSpecularRoughnessID.rgb, baseColor.a * 255.0), worldPos, normalDirection, vec3(shadow, shadow, shadow), 1.0
            #ifdef DEFERRED_CLUSTER
                , LinearizeDepth(sourceDepth, cNearClipPS, cFarClipPS)
            #endif
            );
            break;
    }
#endif // SPLIT_LIGHTING
}
