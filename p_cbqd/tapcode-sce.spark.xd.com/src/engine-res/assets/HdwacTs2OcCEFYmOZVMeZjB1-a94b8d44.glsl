#include "varying_scenepass.def.sc"
#if defined(ENVCUBEMAP)
    #define CLOSE_AO
#elif defined(SSAO) && !defined(AO)
    #define AO
    #define ADDITIONAL_AO
#endif
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position _NORMAL _TEXCOORD0 _COLOR0 _TEXCOORD1 _ATANGENT _SKINNED _INSTANCED _INSTANCED_EXTRA3
    #ifdef PERPIXEL
        $output vTexCoord _VTANGENT, vNormal, vWorldPos _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC _VCOLOR _AOUV _VLIGHTMAPUV
    #else
        $output vTexCoord _VTANGENT, vNormal, vWorldPos, vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2 _VCOLOR _AOUV _VLIGHTMAPUV
    #endif
#endif
#ifdef COMPILEPS
    #ifdef PERPIXEL
        $input vTexCoord _VTANGENT, vNormal, vWorldPos _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC _VCOLOR _AOUV _VLIGHTMAPUV
    #else
        $input vTexCoord _VTANGENT, vNormal, vWorldPos, vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2 _VCOLOR _AOUV _VLIGHTMAPUV
    #endif
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
#include "PBR/SimpleBRDF.sh"
#endif
#include "lambert.sh"

void VS()
{
    #ifdef NOUV
    vec2 iTexCoord = vec2(0.0, 0.0);
    #endif
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vNormal = GetWorldNormal(modelMatrix);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));

    vNormal *= cNormalOddNegativeScale;


    #ifdef VERTEXCOLOR
        vColor = iColor;
    #endif

    #ifdef NORMALMAP
        vec4 tangent = GetWorldTangent(modelMatrix);
        vec3 bitangent = cross(tangent.xyz, vNormal) * tangent.w * cBitangentOddNegativeScale;
        vTexCoord = vec4(GetTexCoord(iTexCoord), bitangent.xy);
        vTangent = vec4(tangent.xyz, bitangent.z);
    #else
        vTexCoord = GetTexCoord(iTexCoord);
    #endif

    #if defined(SSAO) && !defined(CLOSE_AO)
        vAOUV = GetSSAOTexCoord(gl_Position);
    #endif

    #ifdef PERPIXEL

        // Per-pixel forward lighting
        hvec4 projWorldPos = hvec4_init(worldPos, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            GetShadowPos(projWorldPos, vNormal, vShadowPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            vSpotPos = mul(projWorldPos, cLightMatrices[0]);
        #endif
    
        #ifdef POINTLIGHT
            vCubeMaskVec = mul(vec4(worldPos - cLightPos.xyz, 0.0), cLightMatrices[0]).xyz;
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || (defined(AO) && !defined(ADDITIONAL_AO))
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
            vVertexLight = vec3(0.0, 0.0, 0.0);
            vTexCoord2 = iTexCoord1;
        #else
            vVertexLight = GetAmbient(GetZonePos(worldPos));
        #endif
        
        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                vVertexLight += GetVertexLight(i, worldPos, vNormal) * cVertexLights[i * 3].rgb;
        #endif
        
        vScreenPos = GetScreenPos(gl_Position);

        #ifdef ENVCUBEMAP
            vReflectionVec = worldPos - cCameraPos;
        #endif
    #endif
}

void PS()
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        #ifdef NOT_SUPPORT_SRGB
            vec4 diffInput = GammaToLinearSpace(texture2D(sDiffMap, vTexCoord.xy));
        #else
            vec4 diffInput = texture2D(sDiffMap, vTexCoord.xy);
        #endif    
        #ifdef ALPHAMASK
            if (diffInput.a < 0.5)
                discard;
        #endif
        vec4 diffColor = cMatDiffColor * diffInput;
    #else
        vec4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
        diffColor *= vColor;
    #endif
    
    // Get material specular albedo
    #ifdef SPECMAP
        vec3 specColor = cMatSpecColor.rgb * texture2D(sSpecMap, vTexCoord.xy).rgb;
    #else
        vec3 specColor = cMatSpecColor.rgb;
    #endif

    // Get normal
    #ifdef NORMALMAP
        mat3 tbn = TR(mat3(vTangent.xyz, vec3(vTexCoord.zw, vTangent.w), vNormal));
        vec3 normal = normalize(mul(tbn, DecodeNormal(texture2D(sNormalMap, vTexCoord.xy))));
    #else
        vec3 normal = normalize(vNormal);
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(distance(vWorldPos.xyz, cCameraPosPS), __GET_HEIGHT__(vWorldPos));
    #else
        float fogFactor = GetFogFactor(distance(vWorldPos.xyz, cCameraPosPS));
    #endif

    #if defined(PERPIXEL)
        #ifdef SHADOW
            hvec3 shadow = GetShadow(vShadowPos, vWorldPos.w) * hvec3_init(1.0, 1.0, 1.0);
        #else
            hvec3 shadow = hvec3_init(1.0, 1.0, 1.0);
        #endif
        vec3 pixelColor = LambertBRDF(diffColor.rgb, vec4(specColor, cMatSpecColor.a), vWorldPos.xyz, normal, shadow, 1.0);
        #ifdef AMBIENT
            pixelColor += cMatEmissiveColor;
            gl_FragColor = vec4(GetFog(pixelColor, fogFactor), diffColor.a);
        #else
            gl_FragColor = vec4(GetLitFog(pixelColor, fogFactor), diffColor.a);
        #endif

        #if defined(GAMMA_IN_SHADERING) || defined(USEGAMMA)
	        gl_FragColor.rgb = LinearToGammaSpace(toAcesFilmic(gl_FragColor.rgb));
	    #endif
    #elif defined(DEFERRED)
        EncodeGBufferLambert(diffColor.rgb, vec4(specColor, cMatSpecColor.a), normal, cMatEmissiveColor, SHADINGMODELID_LAMBERT_LIT);
    #else
        // Ambient & per-vertex lighting
        vec3 finalColor = vVertexLight * diffColor.rgb;
        #if defined(AO) && !defined(ADDITIONAL_AO)
            // If using AO, the vertex light ambient is black, calculate occluded ambient here
            finalColor += texture2D(sEmissiveMap, vTexCoord2).rgb * cAmbientColor.rgb * diffColor.rgb;
        #endif
        
        #ifdef MATERIAL
            // Add light pre-pass accumulation result
            // Lights are accumulated at half intensity. Bring back to full intensity now
            vec4 lightInput = 2.0 * texture2DProj(sLightBuffer, vScreenPos);
            vec3 lightSpecColor = lightInput.a * lightInput.rgb / max(GetIntensity(lightInput.rgb), 0.001);

            finalColor += lightInput.rgb * diffColor.rgb + lightSpecColor * specColor;
        #endif

        #ifdef ENVCUBEMAP
            // finalColor += cMatEnvMapColor * textureCube(sEnvCubeMap, reflect(vReflectionVec, normal)).rgb;
            finalColor += cMatEnvMapColor;
        #endif
        #ifdef LIGHTMAP
            finalColor += texture2D(sEmissiveMap, vTexCoord2).rgb * diffColor.rgb;
        #endif
        // 避免非Cluster管线，多光源重复累加自发光
        #if !defined(POINTLIGHT) && !defined(SPOTLIGHT)
            #ifdef EMISSIVEMAP
                finalColor += cMatEmissiveColor * texture2D(sEmissiveMap, vTexCoord.xy).rgb;

                // 临时打个补丁，原来是想通过cMatEmissiveColor设置成(1,1,1,1)，cMatDiffColor设置成(0,0,0,0)来实现自发光，不计算光照但产生投影
                // 因为计算光照时cMatDiffColor.a是0，所以光照没有进行计算，详见像素着色器PERPIXEL里的内容
                // 后来发现cMatEmissiveColor是个float3，也就导致了最终算出来的oColor.a其实一直都是0，这就导致了如果最终渲出来的图片alpha都0
                // 如果被用于混合的话，就啥都看不到 ——石声威 2019年4月19日 12:18:40
                #ifdef DIFFMAP
                    diffColor.a = diffInput.a;
                #else
                    diffColor.a = 1.0;
                #endif
            #else
                finalColor += cMatEmissiveColor;
            #endif
        #endif

        gl_FragColor = vec4(GetFog(finalColor, fogFactor), diffColor.a);

        #if defined(GAMMA_IN_SHADERING) || defined(USEGAMMA)
	        gl_FragColor.rgb = LinearToGammaSpace(toAcesFilmic(gl_FragColor.rgb));
	    #endif
    #endif
}
