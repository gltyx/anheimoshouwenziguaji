#include "varying_scenepass.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position, a_color0, a_normal, a_texcoord0 _INSTANCED
    #ifdef PERPIXEL
        $output vTexCoord, vWorldPos _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC
    #else
        $output vTexCoord, vWorldPos vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2
    #endif
#endif
#ifdef COMPILEPS
    #ifdef PERPIXEL
        $input vTexCoord, vWorldPos _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC
    #else
        $input vTexCoord, vWorldPos vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2
    #endif
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "lighting.sh"
#include "fog.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetTexCoord(iTexCoord);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        vec4 projWorldPos = vec4(worldPos, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            GetShadowPos(projWorldPos, vec3(0, 0, 1), vShadowPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            vSpotPos = mul(projWorldPos, cLightMatrices[0]);
        #endif
    
        #ifdef POINTLIGHT
            vCubeMaskVec = mul((worldPos - cLightPos.xyz), mat3(cLightMatrices[0][0].xyz, cLightMatrices[0][1].xyz, cLightMatrices[0][2].xyz));
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || defined(AO)
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
    #if defined(PERPIXEL)
      	// 渲染阴影的时候会进这边，diff大的是背景，小的是阴影，混合模式用的是alpha
        // 所以diff越大越接近背景色
        float diff = 1.0;

        #ifdef SHADOW
            diff *= GetShadow(vShadowPos, vWorldPos.w);
        #endif
    		
    		// 原本阴影颜色是(0.1,0.1,0.1)，由于伽马矫正颜色变亮了0.9375 0.52734375
   			// 所以这里手动ToGamma了一下，也就是取了0.1^2.2
    		vec3 finalColor =  vec3(0.00631,0.00631,0.00631);
				
				#if defined(GAMMA_IN_SHADERING) || defined(USEGAMMA)
					vec4 bgColor = texture2D(sDiffMap, vTexCoord.xy);
				#else
					vec4 bgColor = LinearColor(texture2D(sDiffMap, vTexCoord.xy));
				#endif
				vec4 shadowColor = vec4(finalColor, 1.0-diff);
				float minusSrcAlpha = 1.0 - shadowColor.a;
				gl_FragColor.r = shadowColor.r * shadowColor.a + bgColor.r * minusSrcAlpha;
				gl_FragColor.g = shadowColor.g * shadowColor.a + bgColor.g * minusSrcAlpha;
				gl_FragColor.b = shadowColor.b * shadowColor.a + bgColor.b * minusSrcAlpha;
				gl_FragColor.a = 1.0;
    #else
    		// 在base pass 的时候优先渲染，这样即能看到背景，用能剔除地面上的东西
    		gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    #endif
}
