#ifdef COMPILECS
#ifdef BGFX_SHADER
#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh"
#include "Volumetric/VolumetricCommon.sh"

hfloat Square(hfloat a)
{
    return  a * a;
}
#include "PBR/GI.sh"

#ifdef SPOT_LIGHT

#ifdef SPOT_LIGHT_3DLUT
// IMAGE3D_WR(s_lutTexture, rgba8, 0);
IMAGE3D_WR(s_lut3D, rgba8, 0);
#else//SPOT_LIGHT_3DLUT
IMAGE2D_WR(s_lut2D, rgba8, 0);
#endif//SPOT_LIGHT_3DLUT

uniform hvec4 u_LightConeAngles;
#else//SPOT_LIGHT
BUFFER_WR(s_lutBuffer, hvec4, 0);
#endif//SPOT_LIGHT
uniform hvec4 u_LightColorRange;

struct AccumulateInfo
{
    hvec3 luminance;
    hvec3 transmittance;
};

#ifdef SPOT_LIGHT
#define gl_WorkGroupSize uvec3(16, 8, 1)
NUM_THREADS(16, 8, 1)
#else
#define gl_WorkGroupSize uvec3(VOLUMETRIC_WORK_GROUP, 1, 1)
NUM_THREADS(VOLUMETRIC_WORK_GROUP, 1, 1)
#endif

//考虑底部的半球，这样能在顶视角也有一个OK的效果。
#define CONE_AND_HEMISPHERE 1
#define NUM_SAMPLES 64

#ifdef SPOT_LIGHT
void main()
{
    const float cosTheta = u_LightConeAngles.x;
    vec3 uv = vec3(gl_GlobalInvocationID.xyz) / vec3(VOLUMETRIC_WORK_GROUP, VOLUMETRIC_WORK_GROUP, 8.0);
    float cosAlpha = 2.0 * uv.x - 1.0;
    float sinAlpha = sqrt(1.0 - cosAlpha * cosAlpha);
    const float lenRate = uv.y;
#if CONE_AND_HEMISPHERE
    const float R = u_LightColorRange.w;
#else//CONE_AND_HEMISPHERE
    const float R = u_LightColorRange.w * cosTheta;
#endif//CONE_AND_HEMISPHERE
    float VPLength = lenRate * R;
    vec3 VP = vec3(0.0, -VPLength, 0.0);
    const float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    vec3 lightDirection = vec3(0.0, -1.0, 0.0);
    vec3 dir = vec3(sinAlpha, -cosAlpha, 0.0);
    vec3 dir1 = vec3(-sinTheta, -cosTheta, 0.0);
    vec3 dir2 = vec3(sinTheta, -cosTheta, 0.0);
#ifdef SPOT_LIGHT_3DLUT
    //射线平面与聚光方向的夹角，不会超过Theta
    float cosBeta = 1.0 - ((1.0 - cosTheta) * uv.z);
    // float sinBeta = sqrt(1.0 - cosBeta * cosBeta);
    float R1 = R * cosTheta / cosBeta;
    VPLength = lenRate * R1;
    // VP = vec3(0.0, -VPLength * cosBeta, VPLength * sinBeta);
    VP = vec3(0.0, -VPLength, 0.0);
    float cosTheta2 = R1 / R;
    float sinTheta2 = sqrt(1.0 - cosTheta2 * cosTheta2);
    dir1 = vec3(-sinTheta2, -cosTheta2, 0.0);
    dir2 = vec3(sinTheta2, -cosTheta2, 0.0);
#endif
    //t on cone
    float t11 = LineIntersectLine(VP, dir, vec3(0.0, 0.0, 0.0), dir1);
    float t21 = LineIntersectLine(VP, dir, vec3(0.0, 0.0, 0.0), dir2);

#if CONE_AND_HEMISPHERE
    //t on sphere
    float bb = dot(dir, VP);
    float dd = dot(dir, dir);
    float determinant = bb * bb - dd * (dot(VP, VP) - R * R);
    float sqrtDeterminant = sqrt(determinant); 
    float t12 = (-bb - sqrtDeterminant) / dd;
    float t22 = (-bb + sqrtDeterminant) / dd;
    //一定角度下t11会算出正向交点，这是我们要舍弃的case，此时必定会和弧面相交，t21同理
    t11 = t11 > 0.0 ? t12 : t11;
    t21 = t21 < 0.0 ? t22 : t21;
    float t1 = max(t11, t12);
    float t2 = min(t21, t22);
#else
    //t on bottom Line
    float t31 = LineIntersectLine(VP, dir, dir1 * u_LightColorRange.w, vec3(1.0, 0.0, 0.0));
    float t1 = min(t11, t21);
    float t2 = max(t11, t21);
    float halfBottomLength = sqrt(u_LightColorRange.w * u_LightColorRange.w - R * R);
    if (t31 > 0.0 && t31 * sinAlpha < halfBottomLength)
    {
        t2 = t31;
    }
    if (t31 < 0.0 && t31 * sinAlpha > -halfBottomLength)
    {
        t1 = t31;
    }
#endif
    float len = t2 - t1;
    const float step = 1.0 / NUM_SAMPLES;
    hvec3 lightPos = hvec3_init(0.0, 0.0, 0.0);
    hvec3 lightDir;
    const hfloat stepLength = step * len;

    AccumulateInfo info;
    info.luminance = hvec3_init(0.0, 0.0, 0.0);
    info.transmittance = hvec3_init(1.0, 1.0, 1.0);
    hvec3 startP = VP + dir * t1;
    for (int i = 0; i <= NUM_SAMPLES; ++i)
    {
        hvec3 samplePos = startP + dir * stepLength * i;
        hfloat atten = GI_PointLight_GetAttenAndLightDir(hvec3(samplePos.xyz) , lightPos, u_LightColorRange.w, lightDir);

        atten *= GetLightDirectionFalloff(normalize(-hvec3(samplePos.xyz)), lightDirection, cosTheta, u_LightConeAngles.y);

        hvec3 intensity = atten * u_LightColorRange.rgb * HGPhase(dot(lightDir, -dir), u_ScatteringAndG.w);
        info.luminance = ScatterStep(info.luminance, info.transmittance, intensity, stepLength, info.transmittance);
    }

    //按RGBM编码
    float maxC = max(info.luminance.r, max(info.luminance.b, info.luminance.b));
    float logLum = log2(maxC + LOG_BLACK_POINT) / 16.0 + 0.5;
#ifdef SPOT_LIGHT_3DLUT
	imageStore(s_lut3D, ivec3(gl_GlobalInvocationID.xyz), vec4(info.luminance / maxC, logLum));
#else
	imageStore(s_lut2D, ivec2(gl_GlobalInvocationID.xy), vec4(info.luminance / maxC, logLum));
#endif
}
#else
void main()
{
    const float ndotV = float(gl_GlobalInvocationID.x) / VOLUMETRIC_WORK_GROUP;
    const float y = u_LightColorRange.w * ndotV;
    const float x = sqrt(u_LightColorRange.w * u_LightColorRange.w - y * y);
    const float step = 1.0 / NUM_SAMPLES;
    hvec3 lightPos = hvec3_init(0.0, 0.0, 0.0);
    hvec3 lightDir;
    const hfloat stepLength = step * 2.0 * x;

    AccumulateInfo info;
    info.luminance = hvec3_init(0.0, 0.0, 0.0);
    info.transmittance = hvec3_init(1.0, 1.0, 1.0);
    for (int i = 0; i <= NUM_SAMPLES; ++i)
    {
        float sampleX = -x + i * stepLength;
        hfloat atten = GI_PointLight_GetAttenAndLightDir(hvec3(sampleX, y, 0.0) , lightPos, u_LightColorRange.w, lightDir);
        hvec3 intensity = atten * u_LightColorRange.rgb * HGPhase(dot(lightDir, vec3(-1.0, 0.0, 0.0)), u_ScatteringAndG.w);
        info.luminance = ScatterStep(info.luminance, info.transmittance, intensity, stepLength, info.transmittance);
    }
    s_lutBuffer[gl_GlobalInvocationID.x] = vec4(info.luminance, ndotV);
}
#endif

#endif
#endif