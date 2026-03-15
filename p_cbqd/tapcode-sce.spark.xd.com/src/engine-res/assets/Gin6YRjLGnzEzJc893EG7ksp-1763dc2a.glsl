#version 430
#include "varying_quad.def.sc"
#extension GL_EXT_shader_framebuffer_fetch : enable
#extension GL_ARM_shader_framebuffer_fetch_depth_stencil : enable
#extension GL_QCOM_shader_framebuffer_fetch_noncoherent : enable
precision highp float;
precision highp int;

//要这么写，才方便设置，不然哈希对不上 >_<
uniform 	vec3 CameraPosPS;
uniform 	float NearClipPS;
uniform 	float FarClipPS;
uniform 	vec4 LightDirAndRange;
uniform 	vec4 BlendAndConeAngles;
uniform 	vec3 LightSpotDirection;
//但是编译后拷过来的shader是带u_的，那么我们define一下不就O了 =w=
#define u_LightDirAndRange LightDirAndRange
#define u_BlendAndConeAngles BlendAndConeAngles
#define u_CameraPosPS CameraPosPS
#define u_NearClipPS NearClipPS
#define u_FarClipPS FarClipPS
#define u_LightSpotDirection LightSpotDirection


layout(binding = 0) uniform highp sampler2D u_DepthBuffer0;
layout(binding = 1) uniform lowp sampler3D u_LutMap3D;

in highp vec2 vScreenPos;
in highp vec4 vWorldPos;
in highp vec4 vDepthVec;
#define vs_TEXCOORD3 vDepthVec
#define vs_TEXCOORD1 vScreenPos
#define vs_TEXCOORD2 vWorldPos
layout(location = 0) out mediump vec4 SV_TARGET0;
vec3 u_xlat0;
float u_xlat10_0;
int u_xlati0;
bool u_xlatb0;
vec3 u_xlat16_1;
vec4 u_xlat2;
vec4 u_xlat16_2;
vec3 u_xlat16_3;
vec3 u_xlat16_4;
vec4 u_xlat10_4;
vec3 u_xlat16_5;
vec3 u_xlat16_6;
vec3 u_xlat7;
bool u_xlatb7;
vec3 u_xlat16_8;
vec3 u_xlat16_9;
float u_xlat14;
bool u_xlatb14;
float u_xlat16_15;
float u_xlat16_22;
float u_xlat16_23;
float u_xlat16_24;
float u_xlat16_25;

void PS()
{
    //MUL
    u_xlat0.x = u_LightDirAndRange.w * u_BlendAndConeAngles.z;
    //ADD
    u_xlat7.xyz = vs_TEXCOORD2.xyz + (-u_CameraPosPS.xyz);
    //DP3
    u_xlat16_1.x = dot(u_xlat7.xyz, u_xlat7.xyz);
    //RSQ
    u_xlat16_1.x = inversesqrt(u_xlat16_1.x);
    //MUL
    u_xlat16_1.xyz = u_xlat7.xyz * u_xlat16_1.xxx;
    //MUL
    u_xlat16_2.xyz = u_xlat16_1.yzx * u_LightDirAndRange.zxy;
    //MAD
    u_xlat16_2.xyz = u_LightDirAndRange.yzx * u_xlat16_1.zxy + (-u_xlat16_2.xyz);
    //DP3
    u_xlat16_22 = dot(u_xlat16_2.xyz, u_xlat16_2.xyz);
    //RSQ
    u_xlat16_22 = inversesqrt(u_xlat16_22);
    //MUL
    u_xlat16_2.xyz = vec3(u_xlat16_22) * u_xlat16_2.xyz;
    //DP3
    u_xlat7.x = dot(u_xlat16_2.xyz, u_LightSpotDirection.xyz);
    //MUL
    u_xlat16_3.xyz = u_xlat7.xxx * u_xlat16_2.yzx;
    //MAD
    u_xlat16_22 = (-u_xlat7.x) * u_xlat7.x + 1.0;
    //SQRT
    u_xlat16_22 = sqrt(u_xlat16_22);
    //MUL
    u_xlat16_3.xyz = u_xlat0.xxx * u_xlat16_3.xyz;
    //MAD
    u_xlat16_3.xyz = u_LightSpotDirection.yzx * u_xlat0.xxx + (-u_xlat16_3.xyz);
    //DP3
    u_xlat16_23 = dot(u_xlat16_3.xyz, u_xlat16_3.xyz);
    //RSQ
    u_xlat16_23 = inversesqrt(u_xlat16_23);
    //MUL
    u_xlat16_4.xyz = vec3(u_xlat16_23) * u_xlat16_3.xyz;
    //MUL
    u_xlat16_5.xyz = u_xlat16_2.xyz * u_xlat16_4.yzx;
    //MAD
    u_xlat16_2.xyz = u_xlat16_2.zxy * u_xlat16_4.zxy + (-u_xlat16_5.xyz);
    //DIV
    u_xlat16_24 = u_BlendAndConeAngles.z / u_xlat16_22;
    //MAD
    u_xlat16_25 = (-u_xlat16_24) * u_xlat16_24 + 1.0;
    //SQRT
    u_xlat16_25 = sqrt(u_xlat16_25);
    //MUL
    u_xlat16_2.xyz = u_xlat16_2.xyz * vec3(u_xlat16_25);
    //MAD
    u_xlat16_5.xyz = u_xlat16_3.xyz * vec3(u_xlat16_23) + (-u_xlat16_2.xyz);
    //MAD
    u_xlat16_2.xyz = u_xlat16_3.xyz * vec3(u_xlat16_23) + u_xlat16_2.xyz;
    //DP3
    u_xlat16_23 = dot(u_xlat16_5.xyz, u_xlat16_5.xyz);
    //RSQ
    u_xlat16_23 = inversesqrt(u_xlat16_23);
    //MUL
    u_xlat16_3.xyz = vec3(u_xlat16_23) * u_xlat16_5.xyz;
    //MUL
    u_xlat16_5.xyz = u_xlat16_1.zxy * u_xlat16_3.xyz;
    //MAD
    u_xlat16_5.xyz = u_xlat16_1.yzx * u_xlat16_3.yzx + (-u_xlat16_5.xyz);
    //MUL
    u_xlat16_6.xyz = u_xlat16_3.xyz * u_LightDirAndRange.zxy;
    //MAD
    u_xlat16_3.xyz = u_LightDirAndRange.yzx * u_xlat16_3.yzx + (-u_xlat16_6.xyz);
    //DP3
    u_xlat16_23 = dot(u_xlat16_3.xyz, u_xlat16_5.xyz);
    //DP3
    u_xlat16_3.x = dot(u_xlat16_5.xyz, u_xlat16_5.xyz);
    //DIV
    u_xlat16_23 = u_xlat16_23 / u_xlat16_3.x;
    //DP3
    u_xlat16_3.x = dot(u_xlat16_2.xyz, u_xlat16_2.xyz);
    //RSQ
    u_xlat16_3.x = inversesqrt(u_xlat16_3.x);
    //MUL
    u_xlat16_2.xyz = u_xlat16_2.xyz * u_xlat16_3.xxx;
    //MUL
    u_xlat16_3.xyz = u_xlat16_1.zxy * u_xlat16_2.xyz;
    //MAD
    u_xlat16_3.xyz = u_xlat16_1.yzx * u_xlat16_2.yzx + (-u_xlat16_3.xyz);
    //MUL
    u_xlat16_5.xyz = u_xlat16_2.xyz * u_LightDirAndRange.zxy;
    //MAD
    u_xlat16_2.xyz = u_LightDirAndRange.yzx * u_xlat16_2.yzx + (-u_xlat16_5.xyz);
    //DP3
    u_xlat16_2.x = dot(u_xlat16_2.xyz, u_xlat16_3.xyz);
    //DP3
    u_xlat16_9.x = dot(u_xlat16_3.xyz, u_xlat16_3.xyz);
    //DIV
    u_xlat16_2.x = u_xlat16_2.x / u_xlat16_9.x;
    //MAX
    u_xlat16_9.x = max(u_xlat16_2.x, u_xlat16_23);
    //MIN
    u_xlat16_2.x = min(u_xlat16_2.x, u_xlat16_23);
    //MAD
    u_xlat16_2.xzw = u_xlat16_1.xyz * u_xlat16_2.xxx + u_CameraPosPS.xyz;
    //DP3
    u_xlat16_2.x = dot(u_xlat16_2.xzw, vs_TEXCOORD3.xyz);
    //MAD
    u_xlat16_9.xyz = u_xlat16_1.xyz * u_xlat16_9.xxx + u_CameraPosPS.xyz;
    //DP3
    u_xlat16_2.y = dot(u_xlat16_9.xyz, vs_TEXCOORD3.xyz);
    //ADD
    u_xlat16_2.xy = u_xlat16_2.xy + vs_TEXCOORD3.ww;
    //ADD
    u_xlat16_9.x = (-u_xlat16_2.x) + u_xlat16_2.y;
    //SAMPLE
#ifdef GL_ARM_shader_framebuffer_fetch_depth_stencil
    u_xlat10_0 = gl_LastFragDepthARM;
#else
    u_xlat10_0 = texture(u_DepthBuffer0, vs_TEXCOORD1.xy).x;
#endif
    //MAD
    u_xlat0.x = u_xlat10_0 * 2.0 + -1.0;
    //ADD
    u_xlat7.x = u_NearClipPS + u_FarClipPS;
    //ADD
    u_xlat14 = (-u_NearClipPS) + u_FarClipPS;
    //MAD
    u_xlat0.x = (-u_xlat0.x) * u_xlat14 + u_xlat7.x;
    //DP2
    u_xlat7.x = dot(vec2(vec2(u_FarClipPS, u_FarClipPS)), vec2(u_NearClipPS));
    //DIV
    u_xlat0.x = u_xlat7.x / u_xlat0.x;
    //ADD
    u_xlat16_2.x = (-u_xlat16_2.x) + u_xlat0.x;
    //DIV
    u_xlat16_2.x = u_xlat16_2.x / u_xlat16_9.x;
    u_xlat16_2.x = clamp(u_xlat16_2.x, 0.0, 1.0);
    //LOG
    u_xlat16_2.x = log2(u_xlat16_2.x);
    //MUL
    u_xlat16_2.x = u_xlat16_2.x * u_BlendAndConeAngles.y;
    //EXP
    u_xlat16_2.x = exp2(u_xlat16_2.x);
    //MUL
    u_xlat16_9.xyz = u_xlat16_1.zxy * u_xlat16_4.xyz;
    //MAD
    u_xlat16_9.xyz = u_xlat16_1.yzx * u_xlat16_4.yzx + (-u_xlat16_9.xyz);
    //MUL
    u_xlat16_3.xyz = u_xlat16_4.xyz * u_LightDirAndRange.zxy;
    //MAD
    u_xlat16_3.xyz = u_LightDirAndRange.yzx * u_xlat16_4.yzx + (-u_xlat16_3.xyz);
    //DP3
    u_xlat16_4.x = dot(u_xlat16_4.zxy, u_xlat16_1.xyz);
    //MAD
    u_xlat16_4.x = u_xlat16_4.x * 0.5 + 0.5;
    //DP3
    u_xlat16_3.x = dot(u_xlat16_3.xyz, u_xlat16_9.xyz);
    //DP3
    u_xlat16_9.x = dot(u_xlat16_9.xyz, u_xlat16_9.xyz);
    //DIV
    u_xlat16_9.x = u_xlat16_3.x / u_xlat16_9.x;
    //MAD
    u_xlat16_1.xyz = u_xlat16_9.xxx * u_xlat16_1.xyz + u_CameraPosPS.xyz;
    //ADD
    u_xlat0.xyz = u_CameraPosPS.xyz + u_LightDirAndRange.xyz;
    //ADD
    u_xlat16_1.xyz = (-u_xlat0.xyz) + u_xlat16_1.xyz;
    //DP3
    u_xlat16_9.x = dot(u_xlat16_1.xyz, u_xlat16_1.xyz);
    //DP3
    u_xlat0.x = dot(u_xlat16_1.xyz, u_LightSpotDirection.xyz);
    //GE
    u_xlatb0 = u_xlat0.x>=0.0;
    //AND
    u_xlat0.x = u_xlatb0 ? 1.0 : float(0.0);
    //SQRT
    u_xlat16_1.x = sqrt(u_xlat16_9.x);
    //MUL
    u_xlat16_8.x = u_xlat16_24 * u_LightDirAndRange.w;
    //DIV
    u_xlat16_4.y = u_xlat16_1.x / u_xlat16_8.x;
    //ADD
    u_xlat16_8.x = (-u_xlat16_22) + 1.0;
    //GE
    u_xlatb7 = u_xlat16_22>=u_BlendAndConeAngles.z;
    //ADD
    u_xlat16_15 = (-u_BlendAndConeAngles.z) + 1.00010002;
    //DIV
    u_xlat16_4.z = u_xlat16_8.x / u_xlat16_15;
    //SAMPLE
    u_xlat10_4 = texture(u_LutMap3D, u_xlat16_4.xyz);
    //MAD
    u_xlat16_8.x = u_xlat10_4.w * 16.0 + -8.0;
    //EXP
    u_xlat16_8.x = exp2(u_xlat16_8.x);
    //ADD
    u_xlat16_8.x = u_xlat16_8.x + -0.00390625;
    //MUL
    u_xlat16_8.xyz = u_xlat16_8.xxx * u_xlat10_4.xyz;
    //MUL
    u_xlat2.xyz = u_xlat16_2.xxx * u_xlat16_8.xyz;
    //MAD
    u_xlat16_8.x = (-u_LightDirAndRange.w) * u_xlat16_24 + u_xlat16_1.x;
    //GE
    u_xlatb14 = u_LightDirAndRange.w>=u_xlat16_1.x;
    //MAD
    u_xlat16_1.x = (-u_LightDirAndRange.w) * u_xlat16_24 + u_LightDirAndRange.w;
    //ADD
    u_xlat16_1.x = u_xlat16_1.x + 9.99999975e-05;
    //DIV
    u_xlat16_1.x = u_xlat16_8.x / u_xlat16_1.x;
    u_xlat16_1.x = clamp(u_xlat16_1.x, 0.0, 1.0);
    //MAD
    u_xlat16_1.x = (-u_xlat16_1.x) * u_xlat16_1.x + 1.0;
    //MUL
    u_xlat16_1.x = u_xlat16_1.x * u_xlat16_1.x;
    //MUL
    u_xlat0.x = u_xlat0.x * u_xlat16_1.x;
    //MUL
    u_xlat0.x = u_xlat0.x * u_BlendAndConeAngles.x;
    //AND
    u_xlati0 = u_xlatb7 ? floatBitsToInt(u_xlat0.x) : int(0);
    //AND
    u_xlat2.w = u_xlatb14 ? intBitsToFloat(u_xlati0) : float(0.0);
    //MOV
    SV_TARGET0 = u_xlat2;
    //RET
    return;
}
