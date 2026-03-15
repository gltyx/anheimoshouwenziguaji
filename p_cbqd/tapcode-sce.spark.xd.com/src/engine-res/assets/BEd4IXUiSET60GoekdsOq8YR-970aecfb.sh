#ifndef __SCREENPOS_SH__
#define __SCREENPOS_SH__

#if COMPILEVS
mat3 GetCameraRot()
{
    return mat3(cViewInv[0][0], cViewInv[0][1], cViewInv[0][2],
        cViewInv[1][0], cViewInv[1][1], cViewInv[1][2],
        cViewInv[2][0], cViewInv[2][1], cViewInv[2][2]);
}

#if !(BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC)
vec4 GetScreenPos(vec4 clipPos)
{
    return vec4(
        clipPos.x * cGBufferOffsets.z + cGBufferOffsets.x * clipPos.w,
        -clipPos.y * cGBufferOffsets.w + cGBufferOffsets.y * clipPos.w,
        0.0,
        clipPos.w);
}

vec2 GetScreenPosPreDiv(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * cGBufferOffsets.z + cGBufferOffsets.x,
        -clipPos.y / clipPos.w * cGBufferOffsets.w + cGBufferOffsets.y);
}


vec2 GetQuadTexCoord(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        -clipPos.y / clipPos.w * 0.5 + 0.5);
}

vec2 GetSSAOTexCoord(vec4 clipPos)
{
    return vec2(clipPos.x, -clipPos.y);
}

hvec4 GetScreenPos(hvec4 clipPos)
{
    return hvec4(
        clipPos.x * cGBufferOffsets.z + cGBufferOffsets.x * clipPos.w,
        -clipPos.y * cGBufferOffsets.w + cGBufferOffsets.y * clipPos.w,
        0.0,
        clipPos.w);
}

hvec2 GetScreenPosPreDiv(hvec4 clipPos)
{
    return hvec2(
        clipPos.x / clipPos.w * cGBufferOffsets.z + cGBufferOffsets.x,
        -clipPos.y / clipPos.w * cGBufferOffsets.w + cGBufferOffsets.y);
}


hvec2 GetQuadTexCoord(hvec4 clipPos)
{
    return hvec2(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        -clipPos.y / clipPos.w * 0.5 + 0.5);
}

hvec2 GetSSAOTexCoord(hvec4 clipPos)
{
    return hvec2(clipPos.x, -clipPos.y);
}

#else

vec4 GetScreenPos(vec4 clipPos)
{
    return vec4(
        clipPos.x * cGBufferOffsets.z + cGBufferOffsets.x * clipPos.w,
        clipPos.y * cGBufferOffsets.w + cGBufferOffsets.y * clipPos.w,
        0.0,
        clipPos.w);
}

vec2 GetScreenPosPreDiv(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * cGBufferOffsets.z + cGBufferOffsets.x,
        clipPos.y / clipPos.w * cGBufferOffsets.w + cGBufferOffsets.y);
}

vec2 GetQuadTexCoord(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        clipPos.y / clipPos.w * 0.5 + 0.5);
}

vec2 GetSSAOTexCoord(vec4 clipPos)
{
    return vec2(clipPos.x, clipPos.y);
}

#endif


vec2 GetQuadTexCoord(hvec3 worldPos)
{
    return vec2(
        worldPos.x * 0.5 + 0.5,
        worldPos.y * 0.5 + 0.5);
}

vec2 GetQuadTexCoordNoFlip(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        -clipPos.y / clipPos.w * 0.5 + 0.5);
}

vec2 GetQuadTexCoordNoFlip(hvec3 worldPos)
{
    return vec2(
        worldPos.x * 0.5 + 0.5,
        -worldPos.y * 0.5 + 0.5);
}

hvec3 GetFarRay(hvec4 clipPos)
{
    hvec3 viewRay = hvec3_init(
        clipPos.x / clipPos.w * cFrustumSize.x,
        clipPos.y / clipPos.w * cFrustumSize.y,
        cFrustumSize.z);

    return mul(viewRay, GetCameraRot());
}

hvec3 GetNearRay(hvec4 clipPos)
{
    hvec3 viewRay = hvec3_init(
        clipPos.x / clipPos.w * cFrustumSize.x,
        clipPos.y / clipPos.w * cFrustumSize.y,
        0.0);

    return mul(viewRay, GetCameraRot()) * cDepthMode.x;
}
#endif

#if defined(DEFERRED)
#define SHADINGMODELID_PBR_LIT 1
#define SHADINGMODELID_LAMBERT_LIT 2

// vec3 diffuseColor, float metallic, float roughness, vec3 normalDirection, vec3 emissiveColor, float shadingModelID
#define EncodeGBufferPBR(diffuseColor, metallic, specular, roughness, normalDirection, emissiveColor, shadingModelID) \
    gl_FragData[0].rgb = EncodeNormal(normalDirection); \
    gl_FragData[1].r = metallic; \
    gl_FragData[1].g = specular; \
    gl_FragData[1].b = roughness; \
    gl_FragData[1].a = shadingModelID / 255.0; \
    gl_FragData[2].rgb = diffuseColor; \
    gl_FragData[2].a = 0.0; \
    gl_FragData[3].rgb = emissiveColor;

// vec3 diffColor, vec4 specColor, vec3 normalDirection, vec3 emissiveColor, float shadingModelID
#define EncodeGBufferLambert(diffColor, specColor, normalDirection, emissiveColor, shadingModelID) \
    gl_FragData[0].rgb = EncodeNormal(normalDirection); \
    gl_FragData[1].rgb = specColor.rgb; \
    gl_FragData[1].a = shadingModelID / 255.0; \
    gl_FragData[2].rgb = diffColor; \
    gl_FragData[2].a = specColor.a / 255.0; \
    gl_FragData[3].rgb = emissiveColor;

#endif
#endif