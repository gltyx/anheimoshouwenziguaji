#ifdef BGFX_SHADER
#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"

#ifdef COMPILEVS
    $input a_position _TEXCOORD1
#ifdef VOLUMETRIC_DEPTHMASK
    $output vWorldPos, vScreenPos, vDepthVec
#else
    $output vWorldPos
#endif
#endif
#ifdef COMPILEPS

#ifdef SPOT_LIGHT
#define VL_WORLD_POS vWorldPos,
#else
#define VL_WORLD_POS vWorldPos, 
#endif

#ifdef VOLUMETRIC_DEPTHMASK
    $input VL_WORLD_POS vScreenPos, vDepthVec
#else
    $input VL_WORLD_POS
#endif
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "Volumetric/VolumetricCommon.sh"

#endif // BGFX_SHADER

#ifdef COMPILEPS
#include "Common/bgfx_compute.sh"
#ifndef SPOT_LIGHT
BUFFER_RO(b_lutBuffer, hvec4, 11);
#endif

#ifdef VOLUMETRIC_DEPTHMASK
SAMPLER2D(u_DepthBuffer0, 0);
#endif

#endif
uniform hvec4 u_LightDirAndRange;
uniform hvec4 u_BlendAndConeAngles;

#ifdef SPOT_LIGHT
uniform hvec3 u_LightSpotDirection;
uniform hvec4 u_QuadSizeRange;
uniform hvec2 u_LightClipZW;
uniform hmat4 u_InvViewProj;

#ifdef COMPILEVS
void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    vec2 clipOffset = lerp(u_QuadSizeRange.xy, u_QuadSizeRange.zw, saturate(a_texcoord1));
    hvec4 clipPos = hvec4(clipOffset * u_LightClipZW.y, u_LightClipZW.xy);
    vWorldPos = mul(clipPos, u_InvViewProj);
    gl_Position = clipPos;
#ifdef VOLUMETRIC_DEPTHMASK
    vScreenPos = GetScreenPosPreDiv(gl_Position);
    
    vDepthVec = hvec4_init(u_view[0].z, u_view[1].z, u_view[2].z, u_view[3].z);
#endif
}
#endif//COMPILEVS

#ifdef COMPILEPS
void PS()
{
    hvec3 screenDir = vWorldPos.xyz - cCameraPosPS;
    hvec3 viewDir = normalize(screenDir);
    hfloat range = u_LightDirAndRange.w;
    hvec3 lightPos = u_LightDirAndRange.xyz + cCameraPosPS;
    hvec3 VO = lightPos - cCameraPosPS;
    hvec3 planeNormal = normalize(cross(VO, viewDir));
    hfloat sinBeta = dot(planeNormal, u_LightSpotDirection.xyz);
    hfloat cosBeta = sqrt(1.0 - sinBeta * sinBeta);
    hfloat OCLength = u_BlendAndConeAngles.z * range;
    hvec3 OC = u_LightSpotDirection.xyz * OCLength;
    hvec3 OP = OC - planeNormal * sinBeta * OCLength;
    hvec3 norOP = normalize(OP);
    hfloat t = LineIntersectLine(cCameraPosPS, viewDir, lightPos, norOP);
    hvec3 OP1 = cCameraPosPS + t * viewDir - lightPos;
    hfloat OP1Length = sqrt(dot(OP1, OP1));
    hfloat cosAlpha = dot(norOP, viewDir);
    hfloat cosTheta = u_BlendAndConeAngles.z;
    hfloat alpha = step(OP1Length, range);
    hfloat cosTheta2 = cosTheta / cosBeta;
#ifdef SPOT_LIGHT_3DLUT
    hfloat R1 = range * cosTheta2;
    hvec3 uv = vec3(cosAlpha * 0.5 + 0.5, OP1Length / R1, (1.0 - cosBeta) / (1.0 - cosTheta + 1e-4));
    hvec4 result = texture3D(sLutMap3D, uv);
    // alpha = step(OP1Length, range);
    hfloat rangeFactor = saturate((OP1Length - R1) / (range - R1 + 1E-4));
    alpha *= Square(1.0 - rangeFactor * rangeFactor);
#else
    vec2 uv = vec2(cosAlpha * 0.5 + 0.5, OP1Length / range);
    vec4 result = texture2D(sNormalMap, uv);
    //此时没有Beta项的LUT，我们加一个衰减项尝试拟合
    alpha *= Square(1.0 - Square(1.0 - Square(cosBeta * cosBeta)));
#endif
    //Log Decode
    hfloat maxC = exp2(result.w * 16.0 - 8.0) - LOG_BLACK_POINT;
    result.rgb *= maxC;

#ifdef VOLUMETRIC_DEPTHMASK
    hfloat depth = texture2D(u_DepthBuffer0, vScreenPos).r;
    hfloat linearDepth = LinearizeDepth(depth, cNearClipPS, cFarClipPS);

    hfloat sinTheta2 = sqrt(1.0 - cosTheta2 * cosTheta2);
    hvec3 planeDir = cross(planeNormal, norOP);
    hvec3 OR = normalize(norOP - planeDir * sinTheta2);
    hvec3 OS = normalize(norOP + planeDir * sinTheta2);
    hfloat t1 = LineIntersectLine(cCameraPosPS, viewDir, lightPos, OR);
    hfloat t2 = LineIntersectLine(cCameraPosPS, viewDir, lightPos, OS);
    hvec3 minPos = cCameraPosPS + viewDir * min(t1, t2);
    hvec3 maxPos = cCameraPosPS + viewDir * max(t1, t2);
    hfloat falloff = DepthFallOff(minPos, maxPos, vDepthVec, linearDepth, u_BlendAndConeAngles.y);
    result.rgb *= falloff;
#endif

    //一些边缘case处理
    alpha *= step(cosTheta, cosBeta);
    alpha *= step(0.0, dot(OP1, u_LightSpotDirection.xyz));
    gl_FragColor = vec4(result.rgb, u_BlendAndConeAngles.x * alpha);
}
#endif //COMPILEPS

#else

#ifdef COMPILEVS
void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hfloat lightDistSqr = dot(u_LightDirAndRange.xyz, u_LightDirAndRange.xyz);
    hfloat tanLenSqr = lightDistSqr - u_LightDirAndRange.w * u_LightDirAndRange.w;
    hfloat len = sqrt(lightDistSqr * u_LightDirAndRange.w * u_LightDirAndRange.w / tanLenSqr);
    hvec3 worldPos = GetBillboardPos(a_position, len.xx * a_texcoord1, modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vWorldPos = hvec4(worldPos, len);
#ifdef VOLUMETRIC_DEPTHMASK
    vScreenPos = GetScreenPosPreDiv(gl_Position);
    
    vDepthVec = hvec4_init(u_view[0].z, u_view[1].z, u_view[2].z, u_view[3].z);
#endif
}
#endif

#ifdef COMPILEPS
void PS()
{
    hvec3 screenDir = vWorldPos.xyz - cCameraPosPS;
    hvec3 viewDir = normalize(screenDir);
    hfloat cosTheta = dot(normalize(u_LightDirAndRange.xyz), viewDir);

    //裁掉非球体内的项
    hvec3 localDir = screenDir - u_LightDirAndRange.xyz;
    hfloat alpha = step(dot(localDir, localDir) + 1e-4, vWorldPos.w * vWorldPos.w);

    hfloat lightDistSqr = dot(u_LightDirAndRange.xyz, u_LightDirAndRange.xyz);
    hfloat normalLength = sqrt(lightDistSqr * (1 - cosTheta * cosTheta));
    int idx = int(normalLength * VOLUMETRIC_WORK_GROUP / u_LightDirAndRange.w);
    idx = clamp(idx, 1, VOLUMETRIC_WORK_GROUP - 1);
    hvec4 result = b_lutBuffer[idx];
#ifdef VOLUMETRIC_DEPTHMASK
    hfloat depth = texture2D(u_DepthBuffer0, vScreenPos).r;
    hfloat halfStringLength = sqrt(u_LightDirAndRange.w * u_LightDirAndRange.w - normalLength * normalLength);

    hfloat linearDepth = LinearizeDepth(depth, cNearClipPS, cFarClipPS);
    hfloat lightDist = sqrt(lightDistSqr);
    hvec3 minPos = cCameraPosPS + (lightDist * cosTheta - halfStringLength) * viewDir;
    hvec3 maxPos = minPos + 2.0 * halfStringLength * viewDir;
    hfloat falloff = DepthFallOff(minPos, maxPos, vDepthVec, linearDepth, u_BlendAndConeAngles.y);
    result.rgb *= falloff;
    //作假的Light Shaft，暂时不开了
    // if (u_BlendAndLightShaft.z > 1e-4)
    // {
    //     const vec3 randomScale = vec3(0.33, 0.33, 0.33); 
    //     const uint sizeScale = uint(u_BlendAndLightShaft.z * 10.0);
    //     const float time = 0.5;//cElapsedTimePS / sizeScale;
    //     vec3 normalLocalDir = normalize(localDir);
    //     uvec3 testDir = uvec3(normalLocalDir * sizeScale + sizeScale);
    //     float randomFallOff = Random3DTo1D(testDir, time, randomScale);
    //     randomFallOff = clamp(randomFallOff, 0, 1);
    //     //light shaft还应该有距离衰减
    //     float shaftDistFalloff = (1.0 - ndotV);
    //     shaftDistFalloff *= shaftDistFalloff;
    //     randomFallOff = normalLocalDir.z > u_BlendAndLightShaft.w ? 1.0 : randomFallOff * shaftDistFalloff;
    //     result.rgb *= randomFallOff;
    // }
#endif
    gl_FragColor = vec4(result.rgb, u_BlendAndConeAngles.x * alpha);
}
#endif

#endif
