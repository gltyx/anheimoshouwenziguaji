#if defined(CEG_ANIMATION) || defined(CEGX_ANIMATION)

#include "Quaternion.glsl"



#ifdef COMPILEVS
SAMPLER2D(s_tex3, 3);
#define sBoneMtxMap s_tex3
#endif

SAMPLER2D(s_Animation1, 5);
#define sAnimation1 s_Animation1
SAMPLER2D(s_Animation2, 6);
#define sAnimation2 s_Animation2

uniform hmat4 u_CEGShaderUniform;
#define cCEGShaderUniform u_CEGShaderUniform

#define cBoneTextureSize    cCEGShaderUniform[0].x
#define cAnimationCount     cCEGShaderUniform[0].y
#define cAnimationSize1     cCEGShaderUniform[0].z
#define cAnimationSize2     cCEGShaderUniform[0].w
#define cAnimationTime1     cCEGShaderUniform[1].x
#define cAnimationTime2     cCEGShaderUniform[1].y
#define cAnimationWeight1   cCEGShaderUniform[1].z
#define cAnimationWeight2   cCEGShaderUniform[1].w
#define cComputeTextureSize cCEGShaderUniform[2].x

#define red vec4(1.0, 0.0, 0.0, 1.0)
#define green vec4(0.0, 1.0, 0.0, 1.0)
#define blue vec4(0.0, 0.0, 1.0, 1.0)
#define yellow vec4(1.0, 1.0, 0.0, 1.0)

#include "ReadDataFromTexture.glsl"

hmat4 GetBoneLocalMat(hfloat index, sampler2D boneTexture)
{
    hfloat row = index + 1.0;
    hfloat col = 0.0;
    hvec3 position = ReadVec3(boneTexture, cBoneTextureSize, row, col);
    col += 3.0;
    hvec4 rotation = ReadVec4(boneTexture, cBoneTextureSize, row, col);
    col += 4.0;
    hvec3 scale = ReadVec3(boneTexture, cBoneTextureSize, row, col);

    position = ExpandVec3(position, POSITION_RANGE);
    rotation = ExpandVec4(rotation, QUSTERNION_RANGE);
    scale = ExpandVec3(scale, SCALE_RANGE);

    return GetTransformMat(position, rotation, scale);
}

hmat4 GetBoneOffsetMat(hfloat index, sampler2D boneTexture)
{
    hfloat row = index + 1.0;
    hfloat col = 10.0;
    hmat4 offsetMatrix = ReadMat4(boneTexture, cBoneTextureSize, row, col);
    return ExpandMat4(offsetMatrix, BONE_OFFSET_MATRIX_RANGE);
}

hfloat GetBoneDepth(hfloat index, sampler2D boneTexture)
{
    hfloat row = index + 1.0;
    hfloat col = 10.0 + 12.0;
    hfloat depth = ReadFloat(boneTexture, cBoneTextureSize, row, col);
    return depth * UNSIGNED_INT_ZIP_FACTOR;
}

hfloat GetAncestorIndex(hfloat index, sampler2D boneTexture, hfloat ancestorIndex)
{
    hfloat row = index + 1.0;
    hfloat col = 10.0 + 12.0 + 1.0 + ancestorIndex;
    hfloat o = ReadFloat(boneTexture, cBoneTextureSize, row, col);
    return o * UNSIGNED_INT_ZIP_FACTOR;
}

hmat4 GetAnimationInfo(hfloat boneIndex, hfloat time, sampler2D animationTexture, hfloat animationTextureSize)
{
    hfloat frame = floor(time / ANIMATION_INTERVAL + 0.5);
    hfloat frameCount = floor(ReadFloat(animationTexture, animationTextureSize, 0.0, 2.0) * UNSIGNED_INT_ZIP_FACTOR + 0.5);
    frame = clamp(frame, 0.0, frameCount - 1.0);
    hfloat frameCountPerRow = floor(ReadFloat(animationTexture, animationTextureSize, 0.0, 4.0) * UNSIGNED_INT_ZIP_FACTOR + 0.5);
    hfloat boneRowCount = floor(ReadFloat(animationTexture, animationTextureSize, 0.0, 5.0) * UNSIGNED_INT_ZIP_FACTOR + 0.5);
    hfloat subRow = floor((frame + 0.01) / frameCountPerRow);
    subRow = clamp(subRow, 0.0, boneRowCount - 1.0);
    hfloat row = floor(1.0 + boneIndex * boneRowCount + subRow + 0.5);
    hfloat col = floor(frame - subRow * frameCountPerRow + 0.5);
    col = clamp(col, 0.0, frameCountPerRow - 1.0);
    col = col * 10.0;

    hvec3 position = ReadVec3(animationTexture, animationTextureSize, row, col);
    col += 3.0;
    hvec4 rotation = ReadVec4(animationTexture, animationTextureSize, row, col);
    col += 4.0;
    hvec3 scale = ReadVec3(animationTexture, animationTextureSize, row, col);

    position = ExpandVec3(position, POSITION_RANGE);
    rotation = ExpandVec4(rotation, QUSTERNION_RANGE);
    scale = ExpandVec3(scale, SCALE_RANGE);

    return mat4(
        vec4(position, 0.0),
        rotation,
        vec4(scale, 0.0),
        vec4(0.0)
    );
}

hmat4 GetAnimationMat(hfloat boneIndex, hfloat time, sampler2D animationTexture, hfloat animationTextureSize)
{
    hmat4 info = GetAnimationInfo(boneIndex, time, animationTexture, animationTextureSize);
    hvec3 position = info[0].xyz;
    hvec4 rotation = info[1];
    hvec3 scale = info[2].xyz;
    return GetTransformMat(position, rotation, scale);
}

hmat4 BlendAnimation(hfloat index, sampler2D boneTexture)
{
    hmat4 localMat = mat4(1.0);
    if (IsEqual(cAnimationCount, 0.0))
        localMat = GetBoneLocalMat(index, boneTexture);
    else if (IsEqual(cAnimationCount, 1.0))
        localMat = GetAnimationMat(index, cAnimationTime1, sAnimation1, cAnimationSize1);
    else
    {
        hmat4 info1 = GetAnimationInfo(index, cAnimationTime1, sAnimation1, cAnimationSize1);
        hmat4 info2 = GetAnimationInfo(index, cAnimationTime2, sAnimation2, cAnimationSize2);
        hvec3 position1 = info1[0].xyz;
        hvec4 rotation1 = info1[1];
        hvec3 scale1 = info1[2].xyz;
        hvec3 position2 = info2[0].xyz;
        hvec4 rotation2 = info2[1];
        hvec3 scale2 = info2[2].xyz;
        hvec3 position = position1 * cAnimationWeight1 + position2 * (1.0 - cAnimationWeight1);
        hvec4 rotation = Q_SLerp(rotation1, rotation2, cAnimationWeight2);
        hvec3 scale = scale1 * cAnimationWeight1 + scale2 * (1.0 - cAnimationWeight1);
        localMat = GetTransformMat(position, rotation, scale);
    }
    return localMat;
}

hmat4 GetBoneMat(hfloat index, sampler2D boneTexture)
{
    hmat4 offsetMatrix = GetBoneOffsetMat(index, boneTexture);
    hmat4 localMat = BlendAnimation(index, boneTexture);
    hmat4 result = offsetMatrix * localMat;
    hfloat depth = GetBoneDepth(index, boneTexture);
    hfloat upperBound = depth - 0.01;

    // float i = 0.0;
    for (hfloat i = 0.0; i < upperBound; i += 1.0)
    {
        hfloat ancestorIndex = GetAncestorIndex(index, boneTexture, i);
        hmat4 ancestorLocalMat = BlendAnimation(ancestorIndex, boneTexture);
        result = result * ancestorLocalMat;
    }

    return result;
    // return mat4(1.0);
}

hmat4 GetSkinMatrixFromAnimationTexture(hvec4 blendWeights, hvec4 boneIndices)
{
    // return mat4(1.0);
    hmat4 boneMatrix0 = GetBoneMat(boneIndices.x, sBoneMtxMap);
    hmat4 boneMatrix1 = GetBoneMat(boneIndices.y, sBoneMtxMap);
    hmat4 boneMatrix2 = GetBoneMat(boneIndices.z, sBoneMtxMap);
    // mat4 boneMatrix3 = GetBoneMat(boneIndices[3], sBoneMtxMap);
    return boneMatrix0 * blendWeights.x + boneMatrix1 * blendWeights.y + boneMatrix2 * blendWeights.z;
    // return boneMatrix0 * blendWeights.x + boneMatrix1 * blendWeights.y + boneMatrix2 * blendWeights.z + boneMatrix3 * blendWeights.w;
}

vec4 DebugGPU(vec4 i)
{
    // return texture2D(sAnimation1, vTexCoord.xy);
    return i;
}

#endif