#version 430
#include "varying_quad.def.sc"
#extension GL_EXT_shader_framebuffer_fetch : enable
#extension GL_ARM_shader_framebuffer_fetch_depth_stencil : enable
#extension GL_QCOM_shader_framebuffer_fetch_noncoherent : enable
precision highp float;
precision highp int;

//要这么写，才方便设置，不然哈希对不上 >_<
uniform 	vec4 LightDirAndRange;
uniform 	vec4 BlendAndConeAngles;
uniform     vec3 CameraPosPS;
uniform 	float NearClipPS;
uniform 	float FarClipPS;
//但是编译后拷过来的shader是带u_的，那么我们define一下不就O了 =w=
#define u_LightDirAndRange LightDirAndRange
#define u_BlendAndConeAngles BlendAndConeAngles
#define u_CameraPosPS CameraPosPS
#define u_NearClipPS NearClipPS
#define u_FarClipPS FarClipPS

layout(binding = 0) uniform highp sampler2D u_DepthBuffer0;

struct b_lutBuffer_type {
	uint value[4];
};

layout(std430, binding = 11) readonly buffer b_lutBuffer {
	b_lutBuffer_type b_lutBuffer_buf[];
};
in highp vec2 vScreenPos;
in highp vec4 vWorldPos;
in highp vec4 vDepthVec;
#define vs_TEXCOORD3 vWorldPos
#define vs_TEXCOORD1 vScreenPos
#define vs_TEXCOORD2 vDepthVec
layout(location = 0) out mediump vec4 SV_TARGET0;

vec4 u_xlat0;
float u_xlat10_0;
vec3 u_xlat1;
bool u_xlatb1;
vec3 u_xlat2;
vec2 u_xlat16_3;
vec3 u_xlat4;
vec3 u_xlat5;
float u_xlat16_7;
float u_xlat8;
int u_xlati8;
float u_xlat12;
float u_xlat13;

void PS()
{
    //DP3
    u_xlat0.x = dot(u_LightDirAndRange.xyz, u_LightDirAndRange.xyz);
    //RSQ
    u_xlat4.x = inversesqrt(u_xlat0.x);
    //MUL
    u_xlat4.xyz = u_xlat4.xxx * u_LightDirAndRange.xyz;
    //ADD
    u_xlat1.xyz = vs_TEXCOORD2.xyz + (-u_CameraPosPS.xyz);
    //DP3
    u_xlat13 = dot(u_xlat1.xyz, u_xlat1.xyz);
    //RSQ
    u_xlat13 = inversesqrt(u_xlat13);
    //MUL
    u_xlat2.xyz = vec3(u_xlat13) * u_xlat1.xyz;
    //ADD
    u_xlat1.xyz = u_xlat1.xyz + (-u_LightDirAndRange.xyz);
    //DP3
    u_xlat1.x = dot(u_xlat1.xyz, u_xlat1.xyz);
    //ADD
    u_xlat1.x = u_xlat1.x + 9.99999975e-05;
    //DP3
    u_xlat4.x = dot(u_xlat4.xyz, u_xlat2.xyz);
    //MAD
    u_xlat8 = (-u_xlat4.x) * u_xlat4.x + 1.0;
    //MUL
    u_xlat0.z = u_xlat8 * u_xlat0.x;
    //SQRT
    u_xlat0.xz = sqrt(u_xlat0.xz);
    //MUL
    u_xlat12 = u_xlat0.z * u_xlat0.z;
    //MUL
    u_xlat8 = u_xlat0.z * 128.0;
    //DIV
    u_xlat8 = u_xlat8 / u_LightDirAndRange.w;
    //FTOI
    u_xlati8 = int(u_xlat8);
    //IMAX
    u_xlati8 = max(u_xlati8, 1);
    //IMIN
    u_xlati8 = min(u_xlati8, 127);
    //LD_STRUCTURED
    u_xlat5.xyz = vec3(uintBitsToFloat(b_lutBuffer_buf[u_xlati8].value[(0 >> 2) + 0]), uintBitsToFloat(b_lutBuffer_buf[u_xlati8].value[(0 >> 2) + 1]), uintBitsToFloat(b_lutBuffer_buf[u_xlati8].value[(0 >> 2) + 2]));
    //MAD
    u_xlat8 = u_LightDirAndRange.w * u_LightDirAndRange.w + (-u_xlat12);
    //SQRT
    u_xlat8 = sqrt(u_xlat8);
    //MAD
    u_xlat0.x = u_xlat0.x * u_xlat4.x + (-u_xlat8);
    //ADD
    u_xlat4.x = u_xlat8 + u_xlat8;
    //MAD
    u_xlat0.xzw = u_xlat0.xxx * u_xlat2.xyz + u_CameraPosPS.xyz;
    //MAD
    u_xlat2.xyz = u_xlat4.xxx * u_xlat2.xyz + u_xlat0.xzw;
    //DP3
    u_xlat16_3.x = dot(u_xlat0.xzw, vs_TEXCOORD3.xyz);
    //DP3
    u_xlat16_3.y = dot(u_xlat2.xyz, vs_TEXCOORD3.xyz);
    //ADD
    u_xlat16_3.xy = u_xlat16_3.xy + vs_TEXCOORD3.ww;
    //ADD
    u_xlat16_7 = (-u_xlat16_3.x) + u_xlat16_3.y;
    //SAMPLE
#ifdef GL_ARM_shader_framebuffer_fetch_depth_stencil
    u_xlat10_0 = gl_LastFragDepthARM;
#else
    u_xlat10_0 = texture(u_DepthBuffer0, vs_TEXCOORD1.xy).x;
#endif
    //MAD
    u_xlat0.x = u_xlat10_0 * 2.0 + -1.0;
    //ADD
    u_xlat4.x = u_NearClipPS + u_FarClipPS;
    //ADD
    u_xlat8 = (-u_NearClipPS) + u_FarClipPS;
    //MAD
    u_xlat0.x = (-u_xlat0.x) * u_xlat8 + u_xlat4.x;
    //DP2
    u_xlat4.x = dot(vec2(vec2(u_FarClipPS, u_FarClipPS)), vec2(u_NearClipPS));
    //DIV
    u_xlat0.x = u_xlat4.x / u_xlat0.x;
    //ADD
    u_xlat16_3.x = (-u_xlat16_3.x) + u_xlat0.x;
    //DIV
    u_xlat16_3.x = u_xlat16_3.x / u_xlat16_7;
    u_xlat16_3.x = clamp(u_xlat16_3.x, 0.0, 1.0);
    //LOG
    u_xlat16_3.x = log2(u_xlat16_3.x);
    //MUL
    u_xlat16_3.x = u_xlat16_3.x * u_BlendAndConeAngles.y;
    //EXP
    u_xlat16_3.x = exp2(u_xlat16_3.x);
    //MUL
    u_xlat0.xyz = u_xlat5.xyz * u_xlat16_3.xxx;
    //MUL
    u_xlat5.x = vs_TEXCOORD2.w * vs_TEXCOORD2.w;
    //GE
    u_xlatb1 = u_xlat5.x>=u_xlat1.x;
    //AND
    u_xlat1.x = u_xlatb1 ? 1.0 : float(0.0);
    //MUL
    u_xlat0.w = u_xlat1.x * u_BlendAndConeAngles.x;
    //MOV
    SV_TARGET0 = u_xlat0;
    //RET
    return;
}
