#version 430
#include "varying_quad.def.sc"
precision highp float;
precision highp int;

uniform 	mat4x4 u_view;
uniform 	mediump vec4 u_GBufferOffsets;
uniform 	vec4 QuadSizeRange;
uniform 	vec2 LightClipZW;
uniform 	mat4x4 InvViewProj;
uniform 	vec4 LightDirAndRange;
#define u_QuadSizeRange QuadSizeRange
#define u_LightDirAndRange LightDirAndRange
#define u_LightClipZW LightClipZW
#define u_InvViewProj InvViewProj

in  vec4 a_position;
in  vec2 a_texcoord1;
out vec2 vScreenPos;
out vec4 vWorldPos;
out vec4 vDepthVec;

#define in_POSITION0 a_position
#define in_TEXCOORD1 a_texcoord1
#define vs_TEXCOORD3 vDepthVec
#define vs_TEXCOORD1 vScreenPos
#define vs_TEXCOORD2 vWorldPos
vec4 u_xlat0;
vec2 u_xlat16_1;
vec2 u_xlat4;

void VS()
{
    //MOV
    u_xlat0.xy = in_TEXCOORD1.xy;
    u_xlat0.xy = clamp(u_xlat0.xy, 0.0, 1.0);
    //ADD
    u_xlat4.xy = (-u_QuadSizeRange.xy) + u_QuadSizeRange.zw;
    //MAD
    u_xlat0.xy = u_xlat0.xy * u_xlat4.xy + u_QuadSizeRange.xy;
    //MUL
    u_xlat0.xy = u_xlat0.xy * u_LightClipZW.yy;
    //MOV
    u_xlat0.zw = u_LightClipZW.xy;
    //MOV
    gl_Position = u_xlat0;
    //MOV
    vs_TEXCOORD3 = u_view[2];
    //DIV
    u_xlat16_1.xy = u_xlat0.xy / u_LightClipZW.yy;
    //MAD
    u_xlat16_1.xy = u_xlat16_1.xy * u_GBufferOffsets.zw + u_GBufferOffsets.xy;
    //MOV
    vs_TEXCOORD1.xy = u_xlat16_1.xy;
    //DP4
    vs_TEXCOORD2.x = dot(u_xlat0, u_InvViewProj[0]);
    //DP4
    vs_TEXCOORD2.y = dot(u_xlat0, u_InvViewProj[1]);
    //DP4
    vs_TEXCOORD2.z = dot(u_xlat0, u_InvViewProj[2]);
    //DP4
    vs_TEXCOORD2.w = dot(u_xlat0, u_InvViewProj[3]);
    //RET
    return;
}
