#include "varying_ue3water.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position, a_texcoord0, a_normal _INSTANCED
    $output vScreenPos, vUV1, vUV2, vReflectUV, vEyeVec
#endif
#ifdef COMPILEPS
    $input vScreenPos, vUV1, vUV2, vReflectUV, vEyeVec
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "fog.sh"

#ifdef COMPILEVS
    uniform hvec4 u_WaterSpeed;
    uniform hvec4 u_WaveScaler;
    uniform hvec4 u_WaveDensity;
    #define cWaterSpeed u_WaterSpeed.x
    #define cWaveScaler u_WaveScaler.x
    #define cWaveDensity u_WaveDensity.x
#endif
#ifdef COMPILEPS
    SAMPLER2D(s_Normal1, 1);
    uniform hvec4 u_WavePower;
    uniform hvec4 u_NoiseStrength;
    uniform hvec4 u_LiquidTint;
    uniform hvec4 u_EmissiveColor;
    #define sNormal1 s_Normal1
    #define cWavePower u_WavePower.x
    #define cNoiseStrength u_NoiseStrength.x
    #define cLiquidTint u_LiquidTint
    #define cEmissiveColor u_EmissiveColor
#endif

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vScreenPos = GetScreenPos(gl_Position);
    // 按照原来UE3做法，通过世界坐标加上时间偏移换算出两个uv
    vUV1 = cWaveDensity * ((vec2(worldPos.y, 1.0 * worldPos.x) / cWaveScaler) + cWaterSpeed * cElapsedTime);
    vUV2 = cWaveDensity * ((vec2(worldPos.y, 2.0 * worldPos.x) / cWaveScaler) + cWaterSpeed * cElapsedTime);
    vReflectUV = GetQuadTexCoord(gl_Position);
    vReflectUV.y = 1.0 - vReflectUV.y;
    vReflectUV *= gl_Position.w;
    vEyeVec = vec4(cCameraPos - worldPos, GetDepth(gl_Position));
}

void PS()
{
    vec3 eyeVec = normalize(vEyeVec.xyz);
    vec3 texNormal = texture2D(sNormal1, vUV1).xyz + texture2D(sNormal1, vUV2).xyz;                 // 采样法线，这里已经是世界坐标了，不需要转换
    vec3 normal = normalize(texNormal);                                                           // 单位法线
    float fresnel = pow(1.0 - clamp(dot(normal, eyeVec), 0.0, 1.0), cWavePower);                  // 菲涅尔       

    vec2 distortion = normal.xy;                                                                  // UE3用法线的xy作为扭曲程度
    vec2 refractUV = vScreenPos.xy / vScreenPos.w;                                                // 水下环境贴图uv
    vec2 reflectUV = vReflectUV.xy / vScreenPos.w;                                                // 倒影uv

    vec2 noise = distortion * cNoiseStrength;                                                     // 乘上一个扭曲系数
    refractUV += noise;
    if (noise.y < 0.0)
        noise.y = 0.0;
    reflectUV += noise;

    // 这样调整效果最好了，倒影和高光做一个比例的混合，然后将结果和水底景色做一个混合。这个没有背离物理学。
    vec3 refractColor = mix(texture2D(sEnvMap, refractUV).rgb, cLiquidTint.rgb, cLiquidTint.a);
#ifdef REFLECT_ENV
    vec3 reflectColor = mix(texture2D(sDiffMap, reflectUV).rgb, cEmissiveColor.rgb, cEmissiveColor.a);
#else
    vec3 reflectColor = cEmissiveColor.rgb * cEmissiveColor.a;
#endif
    vec3 finalColor = mix(refractColor, reflectColor, fresnel * 0.6);

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(distance(vWorldPos.xyz, cCameraPosPS), __GET_HEIGHT__(vWorldPos));
    #else
        float fogFactor = GetFogFactor(distance(vWorldPos.xyz, cCameraPosPS));
    #endif

    gl_FragColor = vec4(GetFog(finalColor, fogFactor), 1.0);  
}
