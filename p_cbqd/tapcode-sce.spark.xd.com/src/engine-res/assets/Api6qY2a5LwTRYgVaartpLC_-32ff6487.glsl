#version 430
#include "varying_quad.def.sc"
precision highp float;
precision highp int;

uniform 	vec4 LightDirAndRange;
uniform 	mat3x3 BillboardRot;
#define u_LightDirAndRange LightDirAndRange
#define u_BillboardRot BillboardRot

uniform 	mat4x4 u_view;
uniform 	mat4x4 u_proj;
uniform 	mat4x4 u_model[128];
uniform 	vec4 u_GBufferOffsets;

#define cGBufferOffsets u_GBufferOffsets

in  vec4 a_position;
in  vec2 a_texcoord1;
out vec2 vScreenPos;
out vec4 vWorldPos;
out vec4 vDepthVec;

#define in_POSITION0 a_position
#define in_TEXCOORD1 a_texcoord1
#define vs_TEXCOORD3 vWorldPos
#define vs_TEXCOORD1 vScreenPos
#define vs_TEXCOORD2 vDepthVec

vec4 u_xlat0;
vec4 u_xlat1;
vec2 u_xlat16_2;
vec2 u_xlat3;

void VS()
{
    //MUL
    u_xlat0.x = u_LightDirAndRange.w * u_LightDirAndRange.w;
    //DP3
    u_xlat3.x = dot(u_LightDirAndRange.xyz, u_LightDirAndRange.xyz);
    //MUL
    u_xlat0.x = u_xlat3.x * u_xlat0.x;
    //MAD
    u_xlat3.x = (-u_LightDirAndRange.w) * u_LightDirAndRange.w + u_xlat3.x;
    //DIV
    u_xlat0.x = u_xlat0.x / u_xlat3.x;
    //SQRT
    u_xlat0.x = sqrt(u_xlat0.x);
    //MUL
    u_xlat3.xy = u_xlat0.xx * in_TEXCOORD1.xy;
    //MOV
    vs_TEXCOORD2.w = u_xlat0.x;
    //DP2
    u_xlat1.x = dot(u_xlat3.xy, u_BillboardRot[0].xy);
    //DP2
    u_xlat1.y = dot(u_xlat3.xy, u_BillboardRot[1].xy);
    //DP2
    u_xlat1.z = dot(u_xlat3.xy, u_BillboardRot[2].xy);
    //DP4
    u_xlat0.x = dot(in_POSITION0, u_model[0 / 4][0 % 4]);
    //DP4
    u_xlat0.y = dot(in_POSITION0, u_model[1 / 4][1 % 4]);
    //DP4
    u_xlat0.z = dot(in_POSITION0, u_model[2 / 4][2 % 4]);
    //ADD
    u_xlat0.xyz = u_xlat1.xyz + u_xlat0.xyz;
    //MOV
    u_xlat0.w = 1.0;
    //DP4
    u_xlat1.x = dot(u_xlat0, u_view[0]);
    //DP4
    u_xlat1.y = dot(u_xlat0, u_view[1]);
    //DP4
    u_xlat1.z = dot(u_xlat0, u_view[2]);
    //DP4
    u_xlat1.w = dot(u_xlat0, u_view[3]);
    //MOV
    vs_TEXCOORD2.xyz = u_xlat0.xyz;
    //DP4
    u_xlat0.x = dot(u_xlat1, u_proj[0]);
    //DP4
    u_xlat0.y = dot(u_xlat1, u_proj[1]);
    //DP4
    u_xlat0.w = dot(u_xlat1, u_proj[3]);
    //DP4
    gl_Position.z = dot(u_xlat1, u_proj[2]);
    //MOV
    gl_Position.xyw = u_xlat0.xyw;
    //DIV
    u_xlat16_2.xy = u_xlat0.xy / u_xlat0.ww;
    //MAD
    u_xlat16_2.xy = u_xlat16_2.xy * u_GBufferOffsets.zw + u_GBufferOffsets.xy;
    //MOV
    vs_TEXCOORD1.xy = u_xlat16_2.xy;
    //MOV
    vs_TEXCOORD3 = u_view[2];
    //RET
    return;
}
