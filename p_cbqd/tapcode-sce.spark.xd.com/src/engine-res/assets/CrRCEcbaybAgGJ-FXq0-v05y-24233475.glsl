
#if defined(CEGP_ANIMATION)

#include "Quaternion.glsl"
#include "ReadDataFromTexture.glsl"

#ifdef COMPILEVS
SAMPLER2D(s_tex3, 3);
#define sBoneMtxMap s_tex3

#endif

#ifdef INSTANCED
#define cAnimationIndex i_data3.x
#define cAnimationFrame i_data3.y
#define cNextAnimationFrame i_data3.z
#define cNextAnimationFrameInterval i_data3.w
#else
uniform hvec4 u_CEGPAnimationInfo;
#define cAnimationIndex u_CEGPAnimationInfo.x
#define cAnimationFrame u_CEGPAnimationInfo.y
#define cNextAnimationFrame u_CEGPAnimationInfo.z
#define cNextAnimationFrameInterval u_CEGPAnimationInfo.w
#endif

hmat4 GetTranslate(hmat4 transformMat)
{
    return mat4(
        1.0, 0.0, 0.0, transformMat[0][3],
        0.0, 1.0, 0.0, transformMat[1][3],
        0.0, 0.0, 1.0, transformMat[2][3],
        0.0, 0.0, 0.0, 1.0
    );
}

hvec4 GetScale(hmat4 transformMat)
{
    float sx = sqrt(transformMat[0][0] * transformMat[0][0] + transformMat[1][0] * transformMat[1][0] + transformMat[2][0] * transformMat[2][0]);
    float sy = sqrt(transformMat[0][1] * transformMat[0][1] + transformMat[1][1] * transformMat[1][1] + transformMat[2][1] * transformMat[2][1]);
    float sz = sqrt(transformMat[0][2] * transformMat[0][2] + transformMat[1][2] * transformMat[1][2] + transformMat[2][2] * transformMat[2][2]);
    return vec4(sx, sy, sz, 1.0);
}

hmat4 GetRotate(hmat4 transformMat, hvec4 sc)
{
    return mat4(
        transformMat[0][0] / sc.x, transformMat[0][1] / sc.y, transformMat[0][2] / sc.z, 0.0,
        transformMat[1][0] / sc.x, transformMat[1][1] / sc.y, transformMat[1][2] / sc.z, 0.0,
        transformMat[2][0] / sc.x, transformMat[2][1] / sc.y, transformMat[2][2] / sc.z, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

hmat4 ToScaleMatrix(hvec4 sc)
{
    return mat4(
        sc.x, 0.0, 0.0, 0.0,
        0.0, sc.y, 0.0, 0.0,
        0.0, 0.0, sc.z, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

hmat4 LerpMatrix(hmat4 A, hmat4 B, float t)
{
    hmat4 tA = GetTranslate(A);
    hvec4 sA = GetScale(A);
    hmat4 rA = GetRotate(A, sA);

    hmat4 tB = GetTranslate(B);
    hvec4 sB = GetScale(B);
    hmat4 rB = GetRotate(B, sB);

    hmat4 tC = tA * (1.0 - t) + tB * t;
    hvec4 sC = sA * (1.0 - t) + sB * t;
    hmat4 rC = Q_toMatrix(Q_SLerp(Q_fromMatrix(rA), Q_fromMatrix(rB), t));

    return ToScaleMatrix(sB) * rC * tB;
}

hmat4 ExpandBoneMat(hmat4 zipMat)
{
    return mat4(
        ExpandFloat(zipMat[0][0], SCALE_RANGE), ExpandFloat(zipMat[0][1], SCALE_RANGE), ExpandFloat(zipMat[0][2], SCALE_RANGE), ExpandFloat(zipMat[0][3], BONE_TRANSFORM_MATRIX_RANGE),
        ExpandFloat(zipMat[1][0], SCALE_RANGE), ExpandFloat(zipMat[1][1], SCALE_RANGE), ExpandFloat(zipMat[1][2], SCALE_RANGE), ExpandFloat(zipMat[1][3], BONE_TRANSFORM_MATRIX_RANGE),
        ExpandFloat(zipMat[2][0], SCALE_RANGE), ExpandFloat(zipMat[2][1], SCALE_RANGE), ExpandFloat(zipMat[2][2], SCALE_RANGE), ExpandFloat(zipMat[2][3], BONE_TRANSFORM_MATRIX_RANGE),
        0.0, 0.0, 0.0, 1.0
    );
}

hmat4 GetBoneMatFromCEGP(hfloat index, sampler2D boneTexture, hfloat blendWeight)
{
    hfloat row = cAnimationIndex + index * 2.0;
    hfloat col = cAnimationFrame;
    bool tmp = col > 84.0;
    if (tmp) {
        row += 1.0;
        col -= 84.0;
    }
    col *= 12.0;
    hmat4 zipMatNow = ReadMat4(boneTexture, 1024.0, row, col);
    hmat4 boneMatNow = ExpandBoneMat(zipMatNow);
#ifdef CEGP_LERP
    float nextRow = cAnimationIndex + index * 2.0;
    float nextCol = cNextAnimationFrame;
    tmp = nextCol > 84.0;
    if (tmp) {
        nextRow += 1.0;
        nextCol -= 84.0;
    }
    nextCol *= 12.0;
    //先解压再插值
    hmat4 zipMatNext = ReadMat4(boneTexture, 1024.0, nextRow, nextCol);
    hmat4 boneMatNext = ExpandBoneMat(zipMatNext);
    hfloat t = cNextAnimationFrameInterval;
    hmat4 boneMat = LerpMatrix(boneMatNext, boneMatNow, t);
#else
    hmat4 boneMat = boneMatNow;
#endif
    boneMat = mul(blendWeight, boneMat);
    return boneMat;
}

hmat4 GetSkinMatrixFromCEGPTexture(hvec4 blendWeights, hvec4 boneIndices)
{
    hmat4 boneMatrix0 = GetBoneMatFromCEGP(boneIndices[0], sBoneMtxMap, blendWeights.x);
    hmat4 boneMatrix1 = GetBoneMatFromCEGP(boneIndices[1], sBoneMtxMap, blendWeights.y);
    hmat4 boneMatrix2 = GetBoneMatFromCEGP(boneIndices[2], sBoneMtxMap, blendWeights.z);
    hmat4 boneMatrix3 = GetBoneMatFromCEGP(boneIndices[3], sBoneMtxMap, blendWeights.w);
    return boneMatrix0 + boneMatrix1 + boneMatrix2 + boneMatrix3;
}

hmat4 GetCEGPWorldTransform()
{
    #ifdef INSTANCED
        hmat4 mtx = mat4(i_data0, i_data1, i_data2, vec4(0.0, 0.0, 0.0, 1.0));
        return mtx;
    #else
        return cModel;
    #endif
}

#endif