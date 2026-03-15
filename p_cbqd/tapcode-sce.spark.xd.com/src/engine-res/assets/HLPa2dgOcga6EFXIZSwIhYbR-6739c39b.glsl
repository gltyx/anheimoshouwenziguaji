#include "varying_scenepass.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position, _COLOR0 _TEXCOORD0 _SKINNED _INSTANCED
    $output vTexCoord, vWorldPos, _VCOLOR
#endif
#ifdef COMPILEPS
    $input vTexCoord, vWorldPos, _VCOLOR
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "lighting.sh"
#include "fog.sh"

#ifdef COMPILEPS
uniform float u_Alpha;
#define cAlpha u_Alpha
#endif

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetTexCoord(iTexCoord);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));

    #ifdef VERTEXCOLOR
        vColor = iColor;
    #endif

}

void PS()
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
    		vec4 diffInput = LinearColor(texture2D(sDiffMap, vTexCoord));
        vec4 diffColor = cMatDiffColor * diffInput;
        #ifdef ALPHAMASK
            if (diffInput.a < 0.5)
                discard;
        #endif
    #else
        vec4 diffColor = cMatDiffColor;
    #endif
    
    #ifdef EMISSIVEMAP
        diffColor.rgb += cMatEmissiveColor * texture2D(sEmissiveMap, vTexCoord).rgb;
        #ifdef DIFFMAP
        	diffColor.a = diffInput.a;
        #else
        	diffColor.a = 1.0;
        #endif
    #else
        diffColor.rgb += cMatEmissiveColor;
    #endif
    
    #ifdef VERTEXCOLOR
        diffColor *= vColor;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(distance(vWorldPos.xyz, cCameraPosPS), __GET_HEIGHT__(vWorldPos));
    #else
        float fogFactor = GetFogFactor(distance(vWorldPos.xyz, cCameraPosPS));
    #endif

    #if defined(PREPASS)
        // Fill light pre-pass G-Buffer
        gl_FragData[0] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[1] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #elif defined(DEFERRED)
        gl_FragData[0] = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);
        gl_FragData[2] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[3] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #else
        gl_FragColor = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
    #endif
    
    gl_FragColor.a *= cAlpha;
}

